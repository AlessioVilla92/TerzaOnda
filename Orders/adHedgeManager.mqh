//+------------------------------------------------------------------+
//|                                      adHedgeManager.mqh          |
//|           AcquaDulza EA v1.5.0 — Two-Tier Hedge Manager          |
//|                                                                  |
//|  Two-Tier Hedge System:                                          |
//|    H1 (Recovery): incassa profitto dal dip, NON chiude Soup      |
//|    H2 (Protezione): chiude Soup al raggiungimento del suo TP     |
//|                                                                  |
//|  LOGICA CORE:                                                    |
//|    SELL Soup → BUY STOP H1 @ upper + H1ATRMult × ATR             |
//|             → BUY STOP H2 @ upper + H2ATRMult × ATR             |
//|    BUY  Soup → SELL STOP H1 @ lower - H1ATRMult × ATR            |
//|             → SELL STOP H2 @ lower - H2ATRMult × ATR            |
//|                                                                  |
//|  RISOLUZIONE:                                                    |
//|    H1 TP colpito → bank profit, Soup resta aperta                |
//|    H2 TP colpito → chiudi Soup, ciclo CLOSED                     |
//|    Soup TP colpito → cancella/chiudi H1+H2                       |
//|                                                                  |
//|  MAGIC NUMBERS:                                                  |
//|    Soup = MagicNumber                                            |
//|    H1   = MagicNumber + 1                                        |
//|    H2   = MagicNumber + 2                                        |
//|                                                                  |
//|  API PUBBLICA:                                                   |
//|    HedgeInit()                                                   |
//|    Hedge1PlaceOrder(slot, sig)                                    |
//|    Hedge2PlaceOrder(slot, sig)                                    |
//|    HedgeMonitor(slot)                                            |
//|    HedgeDeinit()                                                 |
//+------------------------------------------------------------------+
#property copyright "AcquaDulza (C) 2026"

// Prefix oggetti grafici hedge
#define HEDGE_LINE_PREFIX   "AD_HEDGE_LINE_"
#define HEDGE2_LINE_PREFIX  "AD_HEDGE2_LINE_"

//+------------------------------------------------------------------+
//| GetClosedHedgeProfit — P&L realizzato H1 (MagicNumber + 1)       |
//+------------------------------------------------------------------+
double GetClosedHedgeProfit(ulong posTicket)
{
   datetime from = TimeCurrent() - 86400 * 7;
   if(!HistorySelect(from, TimeCurrent())) return 0;

   double totalProfit = 0;
   for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
   {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(dealTicket == 0) continue;
      if(HistoryDealGetInteger(dealTicket, DEAL_MAGIC) != MagicNumber + 1) continue;
      if(HistoryDealGetString(dealTicket, DEAL_SYMBOL) != _Symbol) continue;

      long entry = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
      if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_OUT_BY)
      {
         ulong posId = (ulong)HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);
         if(posId == posTicket)
         {
            totalProfit += HistoryDealGetDouble(dealTicket, DEAL_PROFIT)
                         + HistoryDealGetDouble(dealTicket, DEAL_SWAP)
                         + HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
         }
      }
   }
   return totalProfit;
}

//+------------------------------------------------------------------+
//| GetClosedHedge2Profit — P&L realizzato H2 (MagicNumber + 2)      |
//+------------------------------------------------------------------+
double GetClosedHedge2Profit(ulong posTicket)
{
   datetime from = TimeCurrent() - 86400 * 7;
   if(!HistorySelect(from, TimeCurrent())) return 0;

   double totalProfit = 0;
   for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
   {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(dealTicket == 0) continue;
      if(HistoryDealGetInteger(dealTicket, DEAL_MAGIC) != MagicNumber + 2) continue;
      if(HistoryDealGetString(dealTicket, DEAL_SYMBOL) != _Symbol) continue;

      long entry = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
      if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_OUT_BY)
      {
         ulong posId = (ulong)HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);
         if(posId == posTicket)
         {
            totalProfit += HistoryDealGetDouble(dealTicket, DEAL_PROFIT)
                         + HistoryDealGetDouble(dealTicket, DEAL_SWAP)
                         + HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
         }
      }
   }
   return totalProfit;
}

//+------------------------------------------------------------------+
//| HedgeInit — Inizializzazione modulo hedge                        |
//+------------------------------------------------------------------+
void HedgeInit()
{
   AdLogI(LOG_CAT_HEDGE, StringFormat(
      "HedgeManager INIT Two-Tier | H1: %s ATR=%.1f TP=%.1f | H2: %s ATR=%.1f TP=%.1f Lot=%.1fx BE=%s",
      Hedge1Enabled ? "ON" : "OFF", Hedge1ATRMult, Hedge1TPAtrMult,
      Hedge2Enabled ? "ON" : "OFF", Hedge2ATRMult, Hedge2TPAtrMult,
      Hedge2LotRatio, Hedge2BreakevenSL ? "YES" : "NO"));
}

//+------------------------------------------------------------------+
//| HedgeDeinit — Cleanup: rimuovi tutte le linee hedge              |
//+------------------------------------------------------------------+
void HedgeDeinit()
{
   int removed = 0;
   for(int i = ObjectsTotal(0) - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i);
      if(StringFind(name, HEDGE_LINE_PREFIX) == 0 ||
         StringFind(name, HEDGE2_LINE_PREFIX) == 0)
      {
         ObjectDelete(0, name);
         removed++;
      }
   }
   AdLogI(LOG_CAT_HEDGE, StringFormat("HedgeManager DEINIT — %d linee rimosse", removed));
}

//+------------------------------------------------------------------+
//| HedgeDrawTriggerLine — Linea fucsia tratteggiata (H1)            |
//+------------------------------------------------------------------+
void HedgeDrawTriggerLine(int slot, double triggerLevel, datetime barTime)
{
   if(!ShowHedgeLine) return;

   string lineName = HEDGE_LINE_PREFIX + IntegerToString(g_cycles[slot].cycleID);
   g_cycles[slot].hedgeLineName = lineName;

   ObjectDelete(0, lineName);

   datetime t1 = barTime;
   datetime t2 = barTime + (datetime)(HedgeLineBarWidth * PeriodSeconds());

   if(ObjectCreate(0, lineName, OBJ_TREND, 0, t1, triggerLevel, t2, triggerLevel))
   {
      ObjectSetInteger(0, lineName, OBJPROP_COLOR,     clrFuchsia);
      ObjectSetInteger(0, lineName, OBJPROP_STYLE,     STYLE_DASH);
      ObjectSetInteger(0, lineName, OBJPROP_WIDTH,     1);
      ObjectSetInteger(0, lineName, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, lineName, OBJPROP_BACK,      true);
      ObjectSetString(0,  lineName, OBJPROP_TOOLTIP,
         StringFormat("H1 TRIGGER #%d @ %s | %.1f×ATR",
            g_cycles[slot].cycleID,
            DoubleToString(triggerLevel, _Digits),
            Hedge1ATRMult));
   }
}

//+------------------------------------------------------------------+
//| Hedge2DrawTriggerLine — Linea arancione tratteggiata (H2)        |
//+------------------------------------------------------------------+
void Hedge2DrawTriggerLine(int slot, double triggerLevel, datetime barTime)
{
   if(!ShowHedge2Line) return;

   string lineName = HEDGE2_LINE_PREFIX + IntegerToString(g_cycles[slot].cycleID);
   g_cycles[slot].hedge2LineName = lineName;

   ObjectDelete(0, lineName);

   datetime t1 = barTime;
   datetime t2 = barTime + (datetime)(HedgeLineBarWidth * PeriodSeconds());

   if(ObjectCreate(0, lineName, OBJ_TREND, 0, t1, triggerLevel, t2, triggerLevel))
   {
      ObjectSetInteger(0, lineName, OBJPROP_COLOR,     AD_HEDGE2);
      ObjectSetInteger(0, lineName, OBJPROP_STYLE,     STYLE_DASH);
      ObjectSetInteger(0, lineName, OBJPROP_WIDTH,     1);
      ObjectSetInteger(0, lineName, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, lineName, OBJPROP_BACK,      true);
      ObjectSetString(0,  lineName, OBJPROP_TOOLTIP,
         StringFormat("H2 TRIGGER #%d @ %s | %.1f×ATR",
            g_cycles[slot].cycleID,
            DoubleToString(triggerLevel, _Digits),
            Hedge2ATRMult));
   }
}

//+------------------------------------------------------------------+
//| HedgeRemoveLine — Rimuovi linea H1 di un ciclo specifico         |
//+------------------------------------------------------------------+
void HedgeRemoveLine(int slot)
{
   if(g_cycles[slot].hedgeLineName != "")
   {
      ObjectDelete(0, g_cycles[slot].hedgeLineName);
      g_cycles[slot].hedgeLineName = "";
   }
}

//+------------------------------------------------------------------+
//| Hedge2RemoveLine — Rimuovi linea H2 di un ciclo specifico         |
//+------------------------------------------------------------------+
void Hedge2RemoveLine(int slot)
{
   if(g_cycles[slot].hedge2LineName != "")
   {
      ObjectDelete(0, g_cycles[slot].hedge2LineName);
      g_cycles[slot].hedge2LineName = "";
   }
}

//+------------------------------------------------------------------+
//| Hedge1PlaceOrder — Piazza BUY/SELL STOP H1 (Recovery)            |
//| H1 NON chiude la Soup. Incassa profitto dal dip.                 |
//+------------------------------------------------------------------+
void Hedge1PlaceOrder(int slot, const EngineSignal &sig)
{
   if(!EnableHedge || !Hedge1Enabled) return;
   if(slot < 0 || slot >= ArraySize(g_cycles)) return;
   if(g_cycles[slot].state != CYCLE_ACTIVE && g_cycles[slot].state != CYCLE_PENDING) return;

   if(g_atrPips <= 0)
   {
      AdLogW(LOG_CAT_HEDGE, StringFormat("ATR non disponibile (%.4f) — H1 SKIPPED #%d",
             g_atrPips, g_cycles[slot].cycleID));
      return;
   }

   // Calcola lotto H1
   double hedgeLot;
   if(Hedge1UseSameLot)
      hedgeLot = g_cycles[slot].lotSize;
   else
      hedgeLot = NormalizeLotSize(Hedge1LotFixed);
   if(hedgeLot <= 0) hedgeLot = g_symbolMinLot;

   // Calcola trigger e TP
   double atrPrice   = PipsToPrice(g_atrPips);
   double hedgeDist  = Hedge1ATRMult  * atrPrice;
   double hedgeTpDist= Hedge1TPAtrMult * atrPrice;

   double triggerLevel = 0;
   double tpLevel      = 0;

   if(g_cycles[slot].direction < 0)
   {
      // Soup SELL -> H1 BUY STOP sopra upper band
      triggerLevel = sig.upperBand + hedgeDist;
      tpLevel      = triggerLevel  + hedgeTpDist;
   }
   else
   {
      // Soup BUY -> H1 SELL STOP sotto lower band
      triggerLevel = sig.lowerBand - hedgeDist;
      tpLevel      = triggerLevel  - hedgeTpDist;
   }

   triggerLevel = NormalizeDouble(triggerLevel, _Digits);
   tpLevel      = NormalizeDouble(tpLevel,      _Digits);

   // Verifica distanza minima broker
   double minDist = g_symbolStopsLevel * g_symbolPoint;
   double currentPrice = (g_cycles[slot].direction < 0)
                         ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);

   if(g_cycles[slot].direction < 0)
   {
      if(triggerLevel <= currentPrice + minDist)
      {
         triggerLevel = currentPrice + minDist + g_symbolPoint;
         triggerLevel = NormalizeDouble(triggerLevel, _Digits);
         tpLevel      = NormalizeDouble(triggerLevel + hedgeTpDist, _Digits);
         AdLogW(LOG_CAT_HEDGE, StringFormat("H1 BUY STOP troppo vicino — aggiustato a %s",
                DoubleToString(triggerLevel, _Digits)));
      }
   }
   else
   {
      if(triggerLevel >= currentPrice - minDist)
      {
         triggerLevel = currentPrice - minDist - g_symbolPoint;
         triggerLevel = NormalizeDouble(triggerLevel, _Digits);
         tpLevel      = NormalizeDouble(triggerLevel - hedgeTpDist, _Digits);
         AdLogW(LOG_CAT_HEDGE, StringFormat("H1 SELL STOP troppo vicino — aggiustato a %s",
                DoubleToString(triggerLevel, _Digits)));
      }
   }

   // Piazza ordine pendente H1
   string comment = StringFormat("AD_HEDGE1_%s_#%d",
      g_cycles[slot].direction < 0 ? "BUY" : "SELL",
      g_cycles[slot].cycleID);

   g_trade.SetExpertMagicNumber(MagicNumber + 1);

   bool placed = false;
   if(g_cycles[slot].direction < 0)
      placed = g_trade.BuyStop(hedgeLot, triggerLevel, _Symbol, 0, tpLevel, ORDER_TIME_GTC, 0, comment);
   else
      placed = g_trade.SellStop(hedgeLot, triggerLevel, _Symbol, 0, tpLevel, ORDER_TIME_GTC, 0, comment);

   if(placed)
   {
      g_cycles[slot].hedgeTicket      = g_trade.ResultOrder();
      g_cycles[slot].hedgeTriggerPrice= triggerLevel;
      g_cycles[slot].hedgeTPPrice     = tpLevel;
      g_cycles[slot].hedgeLotSize     = hedgeLot;
      g_cycles[slot].hedgePending     = true;
      g_cycles[slot].hedgeActive      = false;
      g_cycles[slot].hedge1BankedProfit = 0;
      g_cycles[slot].hedge1TPHit      = false;

      AdLogI(LOG_CAT_HEDGE, StringFormat(
         "H1 PLACED #%d | %s STOP @ %s | TP=%s | Lot=%.2f | %.1f×ATR",
         g_cycles[slot].cycleID,
         g_cycles[slot].direction < 0 ? "BUY" : "SELL",
         DoubleToString(triggerLevel, _Digits),
         DoubleToString(tpLevel, _Digits),
         hedgeLot, Hedge1ATRMult));

      Alert(StringFormat("AcquaDulza H1 PIAZZATO #%d %s STOP | Lot=%.2f | Trigger=%s | TP=%s | %s",
            g_cycles[slot].cycleID,
            g_cycles[slot].direction < 0 ? "BUY" : "SELL",
            hedgeLot, DoubleToString(triggerLevel, _Digits),
            DoubleToString(tpLevel, _Digits), _Symbol));

      if(ShowHedgeLine)
         HedgeDrawTriggerLine(slot, triggerLevel, sig.barTime);
   }
   else
   {
      AdLogE(LOG_CAT_HEDGE, StringFormat(
         "H1 PLACE FAILED #%d | Error: %s",
         g_cycles[slot].cycleID, g_trade.ResultRetcodeDescription()));
   }
}

//+------------------------------------------------------------------+
//| Hedge2PlaceOrder — Piazza BUY/SELL STOP H2 (Protezione)          |
//| H2 CHIUDE la Soup quando il suo TP viene colpito.                |
//+------------------------------------------------------------------+
void Hedge2PlaceOrder(int slot, const EngineSignal &sig)
{
   if(!EnableHedge || !Hedge2Enabled) return;
   if(slot < 0 || slot >= ArraySize(g_cycles)) return;
   if(g_cycles[slot].state != CYCLE_ACTIVE && g_cycles[slot].state != CYCLE_PENDING) return;

   if(g_atrPips <= 0)
   {
      AdLogW(LOG_CAT_HEDGE, StringFormat("ATR non disponibile (%.4f) — H2 SKIPPED #%d",
             g_atrPips, g_cycles[slot].cycleID));
      return;
   }

   // Calcola lotto H2 = Soup lot * Hedge2LotRatio
   double hedgeLot = NormalizeLotSize(g_cycles[slot].lotSize * Hedge2LotRatio);
   if(hedgeLot <= 0) hedgeLot = g_symbolMinLot;

   // Calcola trigger e TP
   double atrPrice    = PipsToPrice(g_atrPips);
   double hedgeDist   = Hedge2ATRMult  * atrPrice;
   double hedgeTpDist = Hedge2TPAtrMult * atrPrice;

   double triggerLevel = 0;
   double tpLevel      = 0;

   if(g_cycles[slot].direction < 0)
   {
      // Soup SELL -> H2 BUY STOP sopra upper band
      triggerLevel = sig.upperBand + hedgeDist;
      tpLevel      = triggerLevel  + hedgeTpDist;
   }
   else
   {
      // Soup BUY -> H2 SELL STOP sotto lower band
      triggerLevel = sig.lowerBand - hedgeDist;
      tpLevel      = triggerLevel  - hedgeTpDist;
   }

   triggerLevel = NormalizeDouble(triggerLevel, _Digits);
   tpLevel      = NormalizeDouble(tpLevel,      _Digits);

   // Verifica distanza minima broker
   double minDist = g_symbolStopsLevel * g_symbolPoint;
   double currentPrice = (g_cycles[slot].direction < 0)
                         ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);

   if(g_cycles[slot].direction < 0)
   {
      if(triggerLevel <= currentPrice + minDist)
      {
         triggerLevel = currentPrice + minDist + g_symbolPoint;
         triggerLevel = NormalizeDouble(triggerLevel, _Digits);
         tpLevel      = NormalizeDouble(triggerLevel + hedgeTpDist, _Digits);
         AdLogW(LOG_CAT_HEDGE, StringFormat("H2 BUY STOP troppo vicino — aggiustato a %s",
                DoubleToString(triggerLevel, _Digits)));
      }
   }
   else
   {
      if(triggerLevel >= currentPrice - minDist)
      {
         triggerLevel = currentPrice - minDist - g_symbolPoint;
         triggerLevel = NormalizeDouble(triggerLevel, _Digits);
         tpLevel      = NormalizeDouble(triggerLevel - hedgeTpDist, _Digits);
         AdLogW(LOG_CAT_HEDGE, StringFormat("H2 SELL STOP troppo vicino — aggiustato a %s",
                DoubleToString(triggerLevel, _Digits)));
      }
   }

   // Piazza ordine pendente H2 (SL=0, aggiunto dopo fill se BreakevenSL)
   string comment = StringFormat("AD_HEDGE2_%s_#%d",
      g_cycles[slot].direction < 0 ? "BUY" : "SELL",
      g_cycles[slot].cycleID);

   g_trade.SetExpertMagicNumber(MagicNumber + 2);

   bool placed = false;
   if(g_cycles[slot].direction < 0)
      placed = g_trade.BuyStop(hedgeLot, triggerLevel, _Symbol, 0, tpLevel, ORDER_TIME_GTC, 0, comment);
   else
      placed = g_trade.SellStop(hedgeLot, triggerLevel, _Symbol, 0, tpLevel, ORDER_TIME_GTC, 0, comment);

   if(placed)
   {
      g_cycles[slot].hedge2Ticket      = g_trade.ResultOrder();
      g_cycles[slot].hedge2TriggerPrice= triggerLevel;
      g_cycles[slot].hedge2TPPrice     = tpLevel;
      g_cycles[slot].hedge2LotSize     = hedgeLot;
      g_cycles[slot].hedge2Pending     = true;
      g_cycles[slot].hedge2Active      = false;

      AdLogI(LOG_CAT_HEDGE, StringFormat(
         "H2 PLACED #%d | %s STOP @ %s | TP=%s | Lot=%.2f (%.1fx) | %.1f×ATR | BE_SL=%s",
         g_cycles[slot].cycleID,
         g_cycles[slot].direction < 0 ? "BUY" : "SELL",
         DoubleToString(triggerLevel, _Digits),
         DoubleToString(tpLevel, _Digits),
         hedgeLot, Hedge2LotRatio, Hedge2ATRMult,
         Hedge2BreakevenSL ? "YES" : "NO"));

      Alert(StringFormat("AcquaDulza H2 PIAZZATO #%d %s STOP | Lot=%.2f | Trigger=%s | TP=%s | %s",
            g_cycles[slot].cycleID,
            g_cycles[slot].direction < 0 ? "BUY" : "SELL",
            hedgeLot, DoubleToString(triggerLevel, _Digits),
            DoubleToString(tpLevel, _Digits), _Symbol));

      if(ShowHedge2Line)
         Hedge2DrawTriggerLine(slot, triggerLevel, sig.barTime);
   }
   else
   {
      AdLogE(LOG_CAT_HEDGE, StringFormat(
         "H2 PLACE FAILED #%d | Error: %s",
         g_cycles[slot].cycleID, g_trade.ResultRetcodeDescription()));
   }
}

//+------------------------------------------------------------------+
//| Hedge1CancelPending — Cancella ordine H1 pendente                |
//+------------------------------------------------------------------+
void Hedge1CancelPending(int slot)
{
   if(!g_cycles[slot].hedgePending) return;
   if(g_cycles[slot].hedgeTicket == 0) return;

   g_trade.SetExpertMagicNumber(MagicNumber + 1);
   if(g_trade.OrderDelete(g_cycles[slot].hedgeTicket))
   {
      AdLogI(LOG_CAT_HEDGE, StringFormat("H1 CANCELLED #%d | Ticket=%d",
             g_cycles[slot].cycleID, g_cycles[slot].hedgeTicket));
   }
   else
   {
      AdLogE(LOG_CAT_HEDGE, StringFormat("H1 CANCEL FAILED #%d | Error: %s",
             g_cycles[slot].cycleID, g_trade.ResultRetcodeDescription()));
   }
   g_cycles[slot].hedgePending = false;
   g_cycles[slot].hedgeTicket  = 0;
   HedgeRemoveLine(slot);
}

//+------------------------------------------------------------------+
//| Hedge2CancelPending — Cancella ordine H2 pendente                |
//+------------------------------------------------------------------+
void Hedge2CancelPending(int slot)
{
   if(!g_cycles[slot].hedge2Pending) return;
   if(g_cycles[slot].hedge2Ticket == 0) return;

   g_trade.SetExpertMagicNumber(MagicNumber + 2);
   if(g_trade.OrderDelete(g_cycles[slot].hedge2Ticket))
   {
      AdLogI(LOG_CAT_HEDGE, StringFormat("H2 CANCELLED #%d | Ticket=%d",
             g_cycles[slot].cycleID, g_cycles[slot].hedge2Ticket));
   }
   else
   {
      AdLogE(LOG_CAT_HEDGE, StringFormat("H2 CANCEL FAILED #%d | Error: %s",
             g_cycles[slot].cycleID, g_trade.ResultRetcodeDescription()));
   }
   g_cycles[slot].hedge2Pending = false;
   g_cycles[slot].hedge2Ticket  = 0;
   Hedge2RemoveLine(slot);
}

//+------------------------------------------------------------------+
//| Hedge1ClosePosition — Chiudi posizione H1 aperta                 |
//+------------------------------------------------------------------+
void Hedge1ClosePosition(int slot)
{
   if(!g_cycles[slot].hedgeActive) return;
   if(g_cycles[slot].hedgeTicket == 0) return;

   g_trade.SetExpertMagicNumber(MagicNumber + 1);
   if(PositionSelectByTicket(g_cycles[slot].hedgeTicket))
   {
      if(g_trade.PositionClose(g_cycles[slot].hedgeTicket))
      {
         AdLogI(LOG_CAT_HEDGE, StringFormat("H1 CLOSED #%d | Ticket=%d",
                g_cycles[slot].cycleID, g_cycles[slot].hedgeTicket));
      }
      else
      {
         AdLogE(LOG_CAT_HEDGE, StringFormat("H1 CLOSE FAILED #%d | Error: %s",
                g_cycles[slot].cycleID, g_trade.ResultRetcodeDescription()));
      }
   }
   g_cycles[slot].hedgeActive  = false;
   g_cycles[slot].hedgeTicket  = 0;
}

//+------------------------------------------------------------------+
//| Hedge2ClosePosition — Chiudi posizione H2 aperta                 |
//+------------------------------------------------------------------+
void Hedge2ClosePosition(int slot)
{
   if(!g_cycles[slot].hedge2Active) return;
   if(g_cycles[slot].hedge2Ticket == 0) return;

   g_trade.SetExpertMagicNumber(MagicNumber + 2);
   if(PositionSelectByTicket(g_cycles[slot].hedge2Ticket))
   {
      if(g_trade.PositionClose(g_cycles[slot].hedge2Ticket))
      {
         AdLogI(LOG_CAT_HEDGE, StringFormat("H2 CLOSED #%d | Ticket=%d",
                g_cycles[slot].cycleID, g_cycles[slot].hedge2Ticket));
      }
      else
      {
         AdLogE(LOG_CAT_HEDGE, StringFormat("H2 CLOSE FAILED #%d | Error: %s",
                g_cycles[slot].cycleID, g_trade.ResultRetcodeDescription()));
      }
   }
   g_cycles[slot].hedge2Active  = false;
   g_cycles[slot].hedge2Ticket  = 0;
}

//+------------------------------------------------------------------+
//| Hedge1DetectFill — Rileva se H1 e' stato riempito                |
//+------------------------------------------------------------------+
bool Hedge1DetectFill(int slot)
{
   if(!g_cycles[slot].hedgePending) return false;
   if(g_cycles[slot].hedgeTicket == 0) return false;

   bool stillPending = false;
   for(int j = OrdersTotal() - 1; j >= 0; j--)
   {
      if(OrderGetTicket(j) == g_cycles[slot].hedgeTicket)
      {
         stillPending = true;
         break;
      }
   }

   if(!stillPending)
   {
      for(int j = PositionsTotal() - 1; j >= 0; j--)
      {
         ulong posTkt = PositionGetTicket(j);
         if(PositionGetInteger(POSITION_MAGIC) == MagicNumber + 1 &&
            PositionGetString(POSITION_SYMBOL) == _Symbol)
         {
            string posComment = PositionGetString(POSITION_COMMENT);
            if(StringFind(posComment, StringFormat("#%d", g_cycles[slot].cycleID)) >= 0)
            {
               g_cycles[slot].hedgeTicket  = posTkt;
               g_cycles[slot].hedgePending = false;
               g_cycles[slot].hedgeActive  = true;
               g_cycles[slot].state        = CYCLE_HEDGING;
               HedgeRemoveLine(slot);

               AdLogI(LOG_CAT_HEDGE, StringFormat(
                  "=== H1 ACTIVATED #%d === Fill @ %s",
                  g_cycles[slot].cycleID,
                  DoubleToString(PositionGetDouble(POSITION_PRICE_OPEN), _Digits)));
               return true;
            }
         }
      }

      AdLogW(LOG_CAT_HEDGE, StringFormat("H1 order #%d SCOMPARSO — reset pending",
             g_cycles[slot].cycleID));
      g_cycles[slot].hedgePending = false;
      g_cycles[slot].hedgeTicket  = 0;
      HedgeRemoveLine(slot);
   }
   return false;
}

//+------------------------------------------------------------------+
//| Hedge2DetectFill — Rileva se H2 e' stato riempito                |
//| Dopo il fill, applica SL breakeven se Hedge2BreakevenSL=true     |
//+------------------------------------------------------------------+
bool Hedge2DetectFill(int slot)
{
   if(!g_cycles[slot].hedge2Pending) return false;
   if(g_cycles[slot].hedge2Ticket == 0) return false;

   bool stillPending = false;
   for(int j = OrdersTotal() - 1; j >= 0; j--)
   {
      if(OrderGetTicket(j) == g_cycles[slot].hedge2Ticket)
      {
         stillPending = true;
         break;
      }
   }

   if(!stillPending)
   {
      for(int j = PositionsTotal() - 1; j >= 0; j--)
      {
         ulong posTkt = PositionGetTicket(j);
         if(PositionGetInteger(POSITION_MAGIC) == MagicNumber + 2 &&
            PositionGetString(POSITION_SYMBOL) == _Symbol)
         {
            string posComment = PositionGetString(POSITION_COMMENT);
            if(StringFind(posComment, StringFormat("#%d", g_cycles[slot].cycleID)) >= 0)
            {
               g_cycles[slot].hedge2Ticket  = posTkt;
               g_cycles[slot].hedge2Pending = false;
               g_cycles[slot].hedge2Active  = true;
               if(g_cycles[slot].state != CYCLE_HEDGING)
                  g_cycles[slot].state = CYCLE_HEDGING;
               Hedge2RemoveLine(slot);

               double fillPrice = PositionGetDouble(POSITION_PRICE_OPEN);
               AdLogI(LOG_CAT_HEDGE, StringFormat(
                  "=== H2 ACTIVATED #%d === Fill @ %s",
                  g_cycles[slot].cycleID,
                  DoubleToString(fillPrice, _Digits)));

               // Applica SL breakeven dopo fill
               if(Hedge2BreakevenSL)
               {
                  double buffer = g_symbolStopsLevel * g_symbolPoint + g_symbolPoint;
                  double beSL;
                  if(g_cycles[slot].direction > 0)  // Soup BUY -> H2 SELL -> SL sopra entry
                     beSL = fillPrice + buffer;
                  else                               // Soup SELL -> H2 BUY -> SL sotto entry
                     beSL = fillPrice - buffer;

                  beSL = NormalizeDouble(beSL, _Digits);
                  g_trade.SetExpertMagicNumber(MagicNumber + 2);
                  if(g_trade.PositionModify(posTkt, beSL, g_cycles[slot].hedge2TPPrice))
                  {
                     AdLogI(LOG_CAT_HEDGE, StringFormat(
                        "H2 BREAKEVEN SL #%d | SL=%s | Fill=%s | Buffer=%.1fp",
                        g_cycles[slot].cycleID,
                        DoubleToString(beSL, _Digits),
                        DoubleToString(fillPrice, _Digits),
                        PointsToPips(buffer)));
                  }
                  else
                  {
                     AdLogE(LOG_CAT_HEDGE, StringFormat(
                        "H2 BE SL FAILED #%d | Error: %s",
                        g_cycles[slot].cycleID, g_trade.ResultRetcodeDescription()));
                  }
               }
               return true;
            }
         }
      }

      AdLogW(LOG_CAT_HEDGE, StringFormat("H2 order #%d SCOMPARSO — reset pending",
             g_cycles[slot].cycleID));
      g_cycles[slot].hedge2Pending = false;
      g_cycles[slot].hedge2Ticket  = 0;
      Hedge2RemoveLine(slot);
   }
   return false;
}

//+------------------------------------------------------------------+
//| HedgeCleanupAll — Cancella/chiudi H1+H2 per un ciclo             |
//+------------------------------------------------------------------+
void HedgeCleanupAll(int slot)
{
   if(g_cycles[slot].hedgePending)
      Hedge1CancelPending(slot);
   if(g_cycles[slot].hedgeActive)
   {
      ulong h1Tkt = g_cycles[slot].hedgeTicket;
      Hedge1ClosePosition(slot);
      double h1PL = GetClosedHedgeProfit(h1Tkt);
      g_cycles[slot].profit += h1PL;
      g_sessionRealizedProfit += h1PL;
      g_dailyRealizedProfit   += h1PL;
      AdLogI(LOG_CAT_HEDGE, StringFormat("H1 P&L added #%d | H1=%.2f",
             g_cycles[slot].cycleID, h1PL));
   }
   if(g_cycles[slot].hedge2Pending)
      Hedge2CancelPending(slot);
   if(g_cycles[slot].hedge2Active)
   {
      ulong h2Tkt = g_cycles[slot].hedge2Ticket;
      Hedge2ClosePosition(slot);
      double h2PL = GetClosedHedge2Profit(h2Tkt);
      g_cycles[slot].profit += h2PL;
      g_sessionRealizedProfit += h2PL;
      g_dailyRealizedProfit   += h2PL;
      AdLogI(LOG_CAT_HEDGE, StringFormat("H2 P&L added #%d | H2=%.2f",
             g_cycles[slot].cycleID, h2PL));
   }
}

//+------------------------------------------------------------------+
//| HedgeMonitor — Monitor principale Two-Tier                       |
//|                                                                  |
//| CASI:                                                            |
//|   CYCLE_CLOSED: cleanup H1+H2 residui                            |
//|   CYCLE_ACTIVE + H1/H2 pending: detect fill                      |
//|   CYCLE_HEDGING:                                                 |
//|     H1 TP hit  → bank profit, Soup RESTA aperta                  |
//|     H2 TP hit  → chiudi Soup, ciclo CLOSED                       |
//|     Soup chiusa → cleanup H1+H2                                  |
//|     Both closed → cleanup                                        |
//+------------------------------------------------------------------+
void HedgeMonitor(int slot)
{
   if(!EnableHedge) return;
   if(slot < 0 || slot >= ArraySize(g_cycles)) return;

   ENUM_CYCLE_STATE st = g_cycles[slot].state;

   // ── Cleanup: Soup chiusa da MonitorActive ma hedge ancora vivo ──
   if(st == CYCLE_CLOSED)
   {
      HedgeCleanupAll(slot);
      return;
   }

   // ── Ciclo ACTIVE: controlla fill H1 e H2 ──
   if(st == CYCLE_ACTIVE)
   {
      if(g_cycles[slot].hedgePending)
         Hedge1DetectFill(slot);
      if(g_cycles[slot].hedge2Pending)
         Hedge2DetectFill(slot);
      return;
   }

   // ── Ciclo HEDGING: almeno un hedge riempito ──
   if(st == CYCLE_HEDGING)
   {
      // Controlla fill pendenti rimanenti
      if(g_cycles[slot].hedgePending)
         Hedge1DetectFill(slot);
      if(g_cycles[slot].hedge2Pending)
         Hedge2DetectFill(slot);

      // Stato corrente posizioni
      bool soupOpen = (g_cycles[slot].ticket > 0)
                      && PositionSelectByTicket(g_cycles[slot].ticket);

      bool h1Open = (g_cycles[slot].hedgeActive && g_cycles[slot].hedgeTicket > 0)
                    && PositionSelectByTicket(g_cycles[slot].hedgeTicket);

      bool h2Open = (g_cycles[slot].hedge2Active && g_cycles[slot].hedge2Ticket > 0)
                    && PositionSelectByTicket(g_cycles[slot].hedge2Ticket);

      // ── CASO: H1 TP hit (H1 chiusa ma era attiva) → BANK profit, Soup resta ──
      if(!h1Open && g_cycles[slot].hedgeActive && !g_cycles[slot].hedge1TPHit)
      {
         double h1PL = GetClosedHedgeProfit(g_cycles[slot].hedgeTicket);
         g_cycles[slot].hedge1BankedProfit = h1PL;
         g_cycles[slot].hedge1TPHit = true;
         g_cycles[slot].hedgeActive = false;

         g_sessionRealizedProfit += h1PL;
         g_dailyRealizedProfit   += h1PL;

         AdLogI(LOG_CAT_HEDGE, StringFormat(
            "=== H1 BANKED #%d === Profit=%.2f | Soup RESTA APERTA",
            g_cycles[slot].cycleID, h1PL));

         Alert(StringFormat("AcquaDulza H1 BANKED #%d | Profit=%+.2f | Soup aperta | %s",
               g_cycles[slot].cycleID, h1PL, _Symbol));

         // Se Soup e' aperta senza H2, torna a CYCLE_ACTIVE
         if(soupOpen && !g_cycles[slot].hedge2Active && !g_cycles[slot].hedge2Pending)
            g_cycles[slot].state = CYCLE_ACTIVE;
         // Se Soup e' aperta con solo H2 pendente, resta HEDGING? No, torna ACTIVE
         // H2 pending non e' fill, non e' "hedging"
         else if(soupOpen && !g_cycles[slot].hedge2Active && g_cycles[slot].hedge2Pending)
            g_cycles[slot].state = CYCLE_ACTIVE;
      }

      // ── CASO: H2 TP hit (H2 chiusa ma era attiva) → CHIUDI Soup ──
      if(!h2Open && g_cycles[slot].hedge2Active)
      {
         double h2PL = GetClosedHedge2Profit(g_cycles[slot].hedge2Ticket);
         g_cycles[slot].hedge2Active = false;
         g_cycles[slot].hedge2Ticket = 0;

         AdLogI(LOG_CAT_HEDGE, StringFormat(
            "=== H2 PROTECTION #%d === H2 Profit=%.2f → CHIUDO SOUP",
            g_cycles[slot].cycleID, h2PL));

         // Chiudi Soup a mercato
         double soupPL = 0;
         if(soupOpen)
         {
            g_trade.SetExpertMagicNumber(MagicNumber);
            if(g_trade.PositionClose(g_cycles[slot].ticket))
            {
               AdLogI(LOG_CAT_HEDGE, StringFormat("Soup CLOSED (H2 TP hit) #%d",
                      g_cycles[slot].cycleID));
               soupPL = GetClosedPositionProfit(g_cycles[slot].ticket);
            }
            else
            {
               AdLogE(LOG_CAT_HEDGE, StringFormat("Soup CLOSE FAILED #%d | Error: %s",
                      g_cycles[slot].cycleID, g_trade.ResultRetcodeDescription()));
            }
         }

         // Chiudi/cancella H1 se ancora vivo
         if(g_cycles[slot].hedgePending)
            Hedge1CancelPending(slot);
         if(g_cycles[slot].hedgeActive)
         {
            ulong h1Tkt = g_cycles[slot].hedgeTicket;
            Hedge1ClosePosition(slot);
            double h1PL = GetClosedHedgeProfit(h1Tkt);
            g_cycles[slot].hedge1BankedProfit += h1PL;
            g_sessionRealizedProfit += h1PL;
            g_dailyRealizedProfit   += h1PL;
         }

         // Calcola NET = Soup + H1 banked + H2
         double netPL = soupPL + g_cycles[slot].hedge1BankedProfit + h2PL;
         g_cycles[slot].profit = netPL;
         g_sessionRealizedProfit += soupPL + h2PL;
         g_dailyRealizedProfit   += soupPL + h2PL;
         if(netPL > 0) { g_sessionWins++; g_dailyWins++; }
         else { g_sessionLosses++; g_dailyLosses++; }

         AdLogI(LOG_CAT_HEDGE, StringFormat(
            "=== HEDGED CLOSED #%d === Soup=%.2f | H1bank=%.2f | H2=%.2f | NET=%.2f",
            g_cycles[slot].cycleID, soupPL, g_cycles[slot].hedge1BankedProfit, h2PL, netPL));

         Alert(StringFormat("AcquaDulza H2 CLOSED #%d | Soup=%+.2f | H1=%+.2f | H2=%+.2f | NET=%+.2f | %s",
               g_cycles[slot].cycleID, soupPL, g_cycles[slot].hedge1BankedProfit, h2PL, netPL, _Symbol));

         g_cycles[slot].state = CYCLE_CLOSED;
         RemoveTPLine(g_cycles[slot].cycleID);
         return;
      }

      // ── CASO: Soup chiusa (TP broker) → cleanup H1+H2 ──
      if(!soupOpen && g_cycles[slot].ticket > 0)
      {
         double soupPL = GetClosedPositionProfit(g_cycles[slot].ticket);

         AdLogI(LOG_CAT_HEDGE, StringFormat(
            "SOUP CLOSED (TP broker) #%d → cleanup H1+H2 | SoupPL=%.2f",
            g_cycles[slot].cycleID, soupPL));

         // Chiudi/cancella H1
         if(g_cycles[slot].hedgePending)
            Hedge1CancelPending(slot);
         double h1ClosePL = 0;
         if(g_cycles[slot].hedgeActive)
         {
            ulong h1Tkt = g_cycles[slot].hedgeTicket;
            Hedge1ClosePosition(slot);
            h1ClosePL = GetClosedHedgeProfit(h1Tkt);
         }

         // Chiudi/cancella H2
         if(g_cycles[slot].hedge2Pending)
            Hedge2CancelPending(slot);
         double h2ClosePL = 0;
         if(g_cycles[slot].hedge2Active)
         {
            ulong h2Tkt = g_cycles[slot].hedge2Ticket;
            Hedge2ClosePosition(slot);
            h2ClosePL = GetClosedHedge2Profit(h2Tkt);
         }

         double netPL = soupPL + g_cycles[slot].hedge1BankedProfit + h1ClosePL + h2ClosePL;
         g_cycles[slot].profit = netPL;
         g_sessionRealizedProfit += netPL;
         g_dailyRealizedProfit   += netPL;
         if(netPL > 0) { g_sessionWins++; g_dailyWins++; }
         else { g_sessionLosses++; g_dailyLosses++; }

         AdLogI(LOG_CAT_HEDGE, StringFormat(
            "=== HEDGED CLOSED #%d === Soup=%.2f | H1bank=%.2f | H1close=%.2f | H2=%.2f | NET=%.2f",
            g_cycles[slot].cycleID, soupPL, g_cycles[slot].hedge1BankedProfit, h1ClosePL, h2ClosePL, netPL));

         Alert(StringFormat("AcquaDulza HEDGE CLOSED #%d (Soup TP) | NET=%+.2f | %s",
               g_cycles[slot].cycleID, netPL, _Symbol));

         g_cycles[slot].state = CYCLE_CLOSED;
         RemoveTPLine(g_cycles[slot].cycleID);
         return;
      }

      // ── CASO: Tutte chiuse simultaneamente ──
      if(!soupOpen && !h1Open && !h2Open &&
         !g_cycles[slot].hedgePending && !g_cycles[slot].hedge2Pending)
      {
         double soupPL  = GetClosedPositionProfit(g_cycles[slot].ticket);
         double h1PL    = g_cycles[slot].hedge1TPHit ? 0 : GetClosedHedgeProfit(g_cycles[slot].hedgeTicket);
         double h2PL    = GetClosedHedge2Profit(g_cycles[slot].hedge2Ticket);

         double netPL = soupPL + g_cycles[slot].hedge1BankedProfit + h1PL + h2PL;
         g_cycles[slot].hedgeActive  = false;
         g_cycles[slot].hedge2Active = false;
         g_cycles[slot].profit = netPL;
         g_sessionRealizedProfit += netPL;
         g_dailyRealizedProfit   += netPL;
         if(netPL > 0) { g_sessionWins++; g_dailyWins++; }
         else { g_sessionLosses++; g_dailyLosses++; }

         g_cycles[slot].state = CYCLE_CLOSED;
         AdLogI(LOG_CAT_HEDGE, StringFormat(
            "ALL CLOSED simultaneously #%d | NET=%.2f",
            g_cycles[slot].cycleID, netPL));
         RemoveTPLine(g_cycles[slot].cycleID);
      }
   }
}
