//+------------------------------------------------------------------+
//|                                        adOrderManager.mqh        |
//|           AcquaDulza EA v1.0.0 — Order Manager                   |
//|                                                                  |
//|  3 entry modes: MARKET, LIMIT, STOP                              |
//|  Single magic number. Retry logic.                               |
//|  Absorbed from carnOrderManager + carnTriggerSystem              |
//+------------------------------------------------------------------+
#property copyright "AcquaDulza (C) 2026"

//+------------------------------------------------------------------+
//| GetOrderTypeString — Order type to string                       |
//+------------------------------------------------------------------+
string GetOrderTypeString(ENUM_ORDER_TYPE orderType)
{
   switch(orderType)
   {
      case ORDER_TYPE_BUY:             return "BUY";
      case ORDER_TYPE_SELL:            return "SELL";
      case ORDER_TYPE_BUY_LIMIT:       return "BUY_LIMIT";
      case ORDER_TYPE_SELL_LIMIT:      return "SELL_LIMIT";
      case ORDER_TYPE_BUY_STOP:        return "BUY_STOP";
      case ORDER_TYPE_SELL_STOP:       return "SELL_STOP";
      case ORDER_TYPE_BUY_STOP_LIMIT:  return "BUY_STOP_LIMIT";
      case ORDER_TYPE_SELL_STOP_LIMIT: return "SELL_STOP_LIMIT";
      default:                         return "UNKNOWN";
   }
}

//+------------------------------------------------------------------+
//| RefreshRates — Validate symbol tick data                        |
//+------------------------------------------------------------------+
bool RefreshRates()
{
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick)) return false;
   return (tick.ask > 0 && tick.bid > 0);
}

//+------------------------------------------------------------------+
//| OrderPlaceMarket — Market BUY/SELL                              |
//+------------------------------------------------------------------+
ulong OrderPlaceMarket(int direction, double lots, double sl, double tp, string comment)
{
   lots = NormalizeLotSize(lots);
   sl   = NormalizeDouble(sl, (int)g_symbolDigits);
   tp   = NormalizeDouble(tp, (int)g_symbolDigits);

   g_trade.SetExpertMagicNumber(MagicNumber);

   int retries = 0;
   while(retries < MaxRetries)
   {
      if(!RefreshRates()) { retries++; Sleep(RetryDelayMs); continue; }

      bool result = false;
      if(direction > 0)
         result = g_trade.Buy(lots, _Symbol, 0, sl, tp, comment);
      else
         result = g_trade.Sell(lots, _Symbol, 0, sl, tp, comment);

      if(result)
      {
         ulong ticket = g_trade.ResultOrder();
         if(ticket > 0)
         {
            AdLogI(LOG_CAT_ORDER, StringFormat("MARKET %s #%d | Lot=%.2f | SL=%s | TP=%s",
                   direction > 0 ? "BUY" : "SELL", ticket, lots,
                   DoubleToString(sl, (int)g_symbolDigits), DoubleToString(tp, (int)g_symbolDigits)));
            return ticket;
         }
      }

      uint errorCode = g_trade.ResultRetcode();
      if(errorCode == 10033 || errorCode == 10034 || errorCode == 10040)
         return 0;  // Broker limit — don't retry

      AdLogW(LOG_CAT_ORDER, StringFormat("Market order failed: %s (code %d), retry %d",
             g_trade.ResultRetcodeDescription(), errorCode, retries + 1));
      retries++;
      if(retries < MaxRetries) Sleep(RetryDelayMs);
   }

   AdLogE(LOG_CAT_ORDER, StringFormat("Market order FAILED after %d retries", MaxRetries));
   return 0;
}

//+------------------------------------------------------------------+
//| OrderPlacePending — Place LIMIT or STOP order                   |
//+------------------------------------------------------------------+
ulong OrderPlacePending(ENUM_ORDER_TYPE orderType, double lots, double price,
                         double sl, double tp, string comment)
{
   price = NormalizeDouble(price, (int)g_symbolDigits);
   sl    = NormalizeDouble(sl, (int)g_symbolDigits);
   tp    = NormalizeDouble(tp, (int)g_symbolDigits);
   lots  = NormalizeLotSize(lots);

   // Broker order limit check
   int currentOrders = OrdersTotal() + PositionsTotal();
   int brokerLimit = (int)AccountInfoInteger(ACCOUNT_LIMIT_ORDERS);
   if(brokerLimit <= 0) brokerLimit = 200;
   if(currentOrders >= brokerLimit - 2)
   {
      AdLogW(LOG_CAT_ORDER, StringFormat("Broker order limit: %d/%d", currentOrders, brokerLimit));
      return 0;
   }

   // Price validity check
   if(!IsValidPendingPrice(price, orderType))
   {
      AdLogI(LOG_CAT_ORDER, StringFormat("Price not valid for %s @ %s — will retry",
             GetOrderTypeString(orderType), FormatPrice(price)));
      return 0;
   }

   g_trade.SetExpertMagicNumber(MagicNumber);

   int retries = 0;
   while(retries < MaxRetries)
   {
      if(!RefreshRates()) { retries++; Sleep(RetryDelayMs); continue; }

      bool result = false;
      switch(orderType)
      {
         case ORDER_TYPE_BUY_LIMIT:
            result = g_trade.BuyLimit(lots, price, _Symbol, sl, tp, ORDER_TIME_GTC, 0, comment); break;
         case ORDER_TYPE_SELL_LIMIT:
            result = g_trade.SellLimit(lots, price, _Symbol, sl, tp, ORDER_TIME_GTC, 0, comment); break;
         case ORDER_TYPE_BUY_STOP:
            result = g_trade.BuyStop(lots, price, _Symbol, sl, tp, ORDER_TIME_GTC, 0, comment); break;
         case ORDER_TYPE_SELL_STOP:
            result = g_trade.SellStop(lots, price, _Symbol, sl, tp, ORDER_TIME_GTC, 0, comment); break;
         default:
            AdLogE(LOG_CAT_ORDER, "Invalid order type: " + IntegerToString(orderType));
            return 0;
      }

      if(result)
      {
         ulong ticket = g_trade.ResultOrder();
         if(ticket > 0)
         {
            AdLogI(LOG_CAT_ORDER, StringFormat("%s #%d | Lot=%.2f | Entry=%s | SL=%s | TP=%s",
                   GetOrderTypeString(orderType), ticket, lots,
                   FormatPrice(price), FormatPrice(sl), FormatPrice(tp)));
            return ticket;
         }
      }

      uint errorCode = g_trade.ResultRetcode();
      if(errorCode == 10033 || errorCode == 10034 || errorCode == 10040)
         return 0;

      AdLogW(LOG_CAT_ORDER, StringFormat("Pending failed: %s (code %d), retry %d",
             g_trade.ResultRetcodeDescription(), errorCode, retries + 1));
      retries++;
      if(retries < MaxRetries) Sleep(RetryDelayMs);
   }

   AdLogE(LOG_CAT_ORDER, StringFormat("Pending order FAILED after %d retries", MaxRetries));
   return 0;
}

//+------------------------------------------------------------------+
//| OrderPlace — Unified entry: routes by EntryMode                 |
//|  sig: EngineSignal with entry/sl/tp prices                       |
//|  lots: pre-calculated lot size                                   |
//|  Returns: order ticket (0 if failed)                             |
//+------------------------------------------------------------------+
ulong OrderPlace(const EngineSignal &sig, double lots, int cycleID)
{
   string comment = StringFormat("AD_%s_#%d", sig.direction > 0 ? "BUY" : "SELL", cycleID);

   // Validate entry/SL/TP consistency
   if(sig.direction > 0)
   {
      if(sig.tpPrice > 0 && sig.tpPrice <= sig.entryPrice)
      {
         AdLogW(LOG_CAT_ORDER, StringFormat("REJECTED: BUY TP (%s) <= Entry (%s)",
                FormatPrice(sig.tpPrice), FormatPrice(sig.entryPrice)));
         return 0;
      }
   }
   else
   {
      if(sig.tpPrice > 0 && sig.tpPrice >= sig.entryPrice)
      {
         AdLogW(LOG_CAT_ORDER, StringFormat("REJECTED: SELL TP (%s) >= Entry (%s)",
                FormatPrice(sig.tpPrice), FormatPrice(sig.entryPrice)));
         return 0;
      }
   }

   // Route by entry mode
   switch(EntryMode)
   {
      case ENTRY_MARKET:
         return OrderPlaceMarket(sig.direction, lots, sig.slPrice, sig.tpPrice, comment);

      case ENTRY_LIMIT:
      {
         double limitOffset = PipsToPrice(LimitOffsetPips);
         double limitPrice = 0;
         ENUM_ORDER_TYPE type;

         if(sig.direction > 0)
         {
            limitPrice = sig.entryPrice - limitOffset;  // BUY LIMIT below entry
            type = ORDER_TYPE_BUY_LIMIT;
         }
         else
         {
            limitPrice = sig.entryPrice + limitOffset;  // SELL LIMIT above entry
            type = ORDER_TYPE_SELL_LIMIT;
         }
         return OrderPlacePending(type, lots, limitPrice, sig.slPrice, sig.tpPrice, comment);
      }

      case ENTRY_STOP:
      {
         ENUM_ORDER_TYPE type;
         double entryPrice = sig.entryPrice;

         // BUY STOP: must be above Ask + min distance
         // SELL STOP: must be below Bid - min distance
         double minDistance = g_symbolStopsLevel * g_symbolPoint;
         if(minDistance < g_symbolPoint * 10)
            minDistance = g_symbolPoint * 30;  // Min 3 pips

         if(sig.direction > 0)
         {
            type = ORDER_TYPE_BUY_STOP;
            double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            if(entryPrice <= ask + minDistance)
            {
               double old = entryPrice;
               entryPrice = NormalizeDouble(ask + minDistance + g_symbolPoint, (int)g_symbolDigits);
               AdLogW(LOG_CAT_ORDER, StringFormat("BUY STOP adjusted: %s -> %s (too close to Ask)",
                      FormatPrice(old), FormatPrice(entryPrice)));
            }
         }
         else
         {
            type = ORDER_TYPE_SELL_STOP;
            double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            if(entryPrice >= bid - minDistance)
            {
               double old = entryPrice;
               entryPrice = NormalizeDouble(bid - minDistance - g_symbolPoint, (int)g_symbolDigits);
               AdLogW(LOG_CAT_ORDER, StringFormat("SELL STOP adjusted: %s -> %s (too close to Bid)",
                      FormatPrice(old), FormatPrice(entryPrice)));
            }
         }
         return OrderPlacePending(type, lots, entryPrice, sig.slPrice, sig.tpPrice, comment);
      }
   }

   return 0;
}

//+------------------------------------------------------------------+
//| DeletePendingOrder — Delete with retry logic                    |
//+------------------------------------------------------------------+
bool DeletePendingOrder(ulong ticket)
{
   if(ticket == 0) return false;
   if(!OrderSelect(ticket)) return true;  // Already gone

   int retries = 0;
   while(retries < MaxRetries)
   {
      if(g_trade.OrderDelete(ticket)) return true;

      AdLogW(LOG_CAT_ORDER, StringFormat("Delete failed #%d: %s, retry %d",
             ticket, g_trade.ResultRetcodeDescription(), retries + 1));
      retries++;
      if(retries < MaxRetries) Sleep(RetryDelayMs);
   }

   AdLogE(LOG_CAT_ORDER, StringFormat("Failed to delete order #%d", ticket));
   return false;
}

//+------------------------------------------------------------------+
//| ClosePosition — Close by ticket with retry logic                |
//+------------------------------------------------------------------+
bool ClosePosition(ulong ticket)
{
   if(ticket == 0) return false;
   if(!PositionSelectByTicket(ticket)) return true;  // Already closed

   int retries = 0;
   while(retries < MaxRetries)
   {
      if(g_trade.PositionClose(ticket, Slippage)) return true;

      AdLogW(LOG_CAT_ORDER, StringFormat("Close failed #%d: %s, retry %d",
             ticket, g_trade.ResultRetcodeDescription(), retries + 1));
      retries++;
      if(retries < MaxRetries) Sleep(RetryDelayMs);
   }

   AdLogE(LOG_CAT_ORDER, StringFormat("Failed to close position #%d", ticket));
   return false;
}

//+------------------------------------------------------------------+
//| CloseAllPositions — Close all with our magic                    |
//+------------------------------------------------------------------+
int CloseAllPositions()
{
   int closed = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

      if(ClosePosition(ticket)) closed++;
   }
   return closed;
}

//+------------------------------------------------------------------+
//| DeleteAllPendingOrders — Delete all with our magic              |
//+------------------------------------------------------------------+
int DeleteAllPendingOrders()
{
   int deleted = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(!OrderSelect(ticket)) continue;
      if(OrderGetInteger(ORDER_MAGIC) != MagicNumber) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;

      if(DeletePendingOrder(ticket)) deleted++;
   }
   return deleted;
}

//+------------------------------------------------------------------+
//| CloseAllOrders — Close everything (positions + pending)         |
//+------------------------------------------------------------------+
void CloseAllOrders()
{
   AdLogI(LOG_CAT_ORDER, "=== CLOSE ALL REQUESTED ===");
   int pos = CloseAllPositions();
   int ord = DeleteAllPendingOrders();
   AdLogI(LOG_CAT_ORDER, StringFormat("CLOSE COMPLETE — Positions=%d Orders=%d", pos, ord));
}

//+------------------------------------------------------------------+
//| ModifyPendingOrder — Update entry/SL/TP of pending order        |
//+------------------------------------------------------------------+
bool ModifyPendingOrder(ulong ticket, double newPrice, double newSL, double newTP)
{
   if(!OrderSelect(ticket)) return false;

   newPrice = NormalizeDouble(newPrice, (int)g_symbolDigits);
   newSL    = NormalizeDouble(newSL, (int)g_symbolDigits);
   newTP    = NormalizeDouble(newTP, (int)g_symbolDigits);

   g_trade.SetExpertMagicNumber(MagicNumber);
   if(g_trade.OrderModify(ticket, newPrice, newSL, newTP, ORDER_TIME_GTC, 0))
      return true;

   AdLogW(LOG_CAT_ORDER, StringFormat("Modify failed #%d: %s",
          ticket, g_trade.ResultRetcodeDescription()));
   return false;
}
