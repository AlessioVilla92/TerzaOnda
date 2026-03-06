//+------------------------------------------------------------------+
//|                                          carnOrderManager.mqh    |
//|                     Carneval EA - Order Manager                 |
//|                                                                  |
//|  Handles all order/position operations with retry logic          |
//+------------------------------------------------------------------+
#property copyright "Carneval (C) 2026"
#property link      "https://carnivalle.com"

// NOTE: CTrade trade is already defined in GlobalVariables.mqh
// Do NOT redeclare it here to avoid multiple definition error

//+------------------------------------------------------------------+
//| Get Order Type as String                                          |
//+------------------------------------------------------------------+
string GetOrderTypeString(ENUM_ORDER_TYPE orderType) {
    switch(orderType) {
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
//| INITIALIZATION                                                   |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| PENDING ORDER FUNCTIONS                                          |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Place Pending Order with Retry Logic                             |
//+------------------------------------------------------------------+
ulong PlacePendingOrder(ENUM_ORDER_TYPE orderType, double lot, double price,
                        double sl, double tp, string comment, int magic) {

    // Normalize values
    price = NormalizeDouble(price, symbolDigits);
    sl = NormalizeDouble(sl, symbolDigits);
    tp = NormalizeDouble(tp, symbolDigits);
    lot = NormalizeLotSize(lot);

    // Check broker order limit BEFORE attempting order
    int currentOrders = OrdersTotal() + PositionsTotal();
    int brokerLimit = (int)AccountInfoInteger(ACCOUNT_LIMIT_ORDERS);
    if(brokerLimit <= 0) brokerLimit = 200;  // Default fallback

    if(currentOrders >= brokerLimit - 2) {  // Leave 2 slots margin
        static datetime lastLimitWarning = 0;
        if(TimeCurrent() - lastLimitWarning > 60) {
            CarnLogW(LOG_CAT_ORDER, StringFormat("Broker order limit reached: %d/%d — waiting for positions to close",
                     currentOrders, brokerLimit));
            lastLimitWarning = TimeCurrent();
        }
        return 0;
    }

    // Check price validity BEFORE attempting order
    if(!IsValidPendingPrice(price, orderType)) {
        CarnLogD(LOG_CAT_ORDER, StringFormat("Skipping %s @ %s — price not yet valid (will retry)",
                 GetOrderTypeString(orderType), FormatPrice(price)));
        return 0;
    }

    // Set magic for this order
    trade.SetExpertMagicNumber(magic);

    int retries = 0;
    ulong ticket = 0;

    while(retries < MaxRetries) {
        bool result = false;

        // Refresh rates before each attempt
        if(!RefreshRates()) {
            LogMessage(LOG_WARNING, "Failed to refresh rates, retry " + IntegerToString(retries + 1));
            retries++;
            Sleep(RetryDelay_ms);
            continue;
        }

        // Execute order based on type
        switch(orderType) {
            case ORDER_TYPE_BUY_LIMIT:
                result = trade.BuyLimit(lot, price, _Symbol, sl, tp, ORDER_TIME_GTC, 0, comment);
                break;

            case ORDER_TYPE_SELL_LIMIT:
                result = trade.SellLimit(lot, price, _Symbol, sl, tp, ORDER_TIME_GTC, 0, comment);
                break;

            case ORDER_TYPE_BUY_STOP:
                result = trade.BuyStop(lot, price, _Symbol, sl, tp, ORDER_TIME_GTC, 0, comment);
                break;

            case ORDER_TYPE_SELL_STOP:
                result = trade.SellStop(lot, price, _Symbol, sl, tp, ORDER_TIME_GTC, 0, comment);
                break;

            default:
                LogMessage(LOG_ERROR, "Invalid order type for pending: " + IntegerToString(orderType));
                return 0;
        }

        if(result) {
            ticket = trade.ResultOrder();
            if(ticket > 0) {
                if(DetailedLogging) {
                    LogMessage(LOG_SUCCESS, "Pending order placed: #" + IntegerToString(ticket) +
                               " " + GetOrderTypeString(orderType) + " " + DoubleToString(lot, 2) +
                               " @ " + FormatPrice(price));
                }
                return ticket;
            }
        }

        // Log error and check if retry makes sense
        uint errorCode = trade.ResultRetcode();
        string errorDesc = trade.ResultRetcodeDescription();

        // Don't retry if it's a limit error
        if(errorCode == 10033 || errorCode == 10034 || errorCode == 10040) {
            static datetime lastLimitError = 0;
            if(TimeCurrent() - lastLimitError > 60) {
                LogMessage(LOG_WARNING, "Broker limit reached: " + errorDesc + " - will retry when slots free");
                lastLimitError = TimeCurrent();
            }
            return 0;
        }

        LogMessage(LOG_WARNING, "Order failed: " + errorDesc + " (code " + IntegerToString(errorCode) +
                   "), retry " + IntegerToString(retries + 1));

        retries++;
        if(retries < MaxRetries) {
            Sleep(RetryDelay_ms);
        }
    }

    LogMessage(LOG_ERROR, "Failed to place pending order after " + IntegerToString(MaxRetries) + " retries");
    return 0;
}

//+------------------------------------------------------------------+
//| Delete Pending Order                                             |
//+------------------------------------------------------------------+
bool DeletePendingOrder(ulong ticket) {
    if(ticket == 0) return false;

    // Check if order exists
    if(!OrderSelect(ticket)) {
        // Order may have been filled or already deleted
        return true;
    }

    int retries = 0;

    while(retries < MaxRetries) {
        if(trade.OrderDelete(ticket)) {
            if(DetailedLogging) {
                LogMessage(LOG_SUCCESS, "Order deleted: #" + IntegerToString(ticket));
            }
            return true;
        }

        uint errorCode = trade.ResultRetcode();
        string errorDesc = trade.ResultRetcodeDescription();
        LogMessage(LOG_WARNING, "Delete failed: " + errorDesc + ", retry " + IntegerToString(retries + 1));

        retries++;
        if(retries < MaxRetries) {
            Sleep(RetryDelay_ms);
        }
    }

    LogMessage(LOG_ERROR, "Failed to delete order #" + IntegerToString(ticket));
    return false;
}

//+------------------------------------------------------------------+
//| POSITION FUNCTIONS                                               |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Close Position by Ticket                                         |
//+------------------------------------------------------------------+
bool ClosePosition(ulong ticket) {
    if(ticket == 0) return false;

    if(!PositionSelectByTicket(ticket)) {
        // Position may already be closed
        return true;
    }

    int retries = 0;

    while(retries < MaxRetries) {
        if(trade.PositionClose(ticket, Slippage)) {
            if(DetailedLogging) {
                LogMessage(LOG_SUCCESS, "Position closed: #" + IntegerToString(ticket));
            }
            return true;
        }

        uint errorCode = trade.ResultRetcode();
        LogMessage(LOG_WARNING, "Close failed: " + trade.ResultRetcodeDescription() +
                   ", retry " + IntegerToString(retries + 1));

        retries++;
        if(retries < MaxRetries) {
            Sleep(RetryDelay_ms);
        }
    }

    LogMessage(LOG_ERROR, "Failed to close position #" + IntegerToString(ticket));
    return false;
}

//+------------------------------------------------------------------+
//| BATCH OPERATIONS                                                 |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Close All Positions by Magic                                     |
//+------------------------------------------------------------------+
int CloseAllPositionsByMagic(int magic) {
    int closed = 0;

    for(int i = PositionsTotal() - 1; i >= 0; i--) {
        ulong ticket = PositionGetTicket(i);
        if(PositionSelectByTicket(ticket)) {
            if(PositionGetInteger(POSITION_MAGIC) == magic &&
               PositionGetString(POSITION_SYMBOL) == _Symbol) {

                if(ClosePosition(ticket)) {
                    closed++;
                }
            }
        }
    }

    return closed;
}

//+------------------------------------------------------------------+
//| Delete All Pending Orders by Magic                               |
//+------------------------------------------------------------------+
int DeleteAllOrdersByMagic(int magic) {
    int deleted = 0;

    for(int i = OrdersTotal() - 1; i >= 0; i--) {
        ulong ticket = OrderGetTicket(i);
        if(OrderSelect(ticket)) {
            if(OrderGetInteger(ORDER_MAGIC) == magic &&
               OrderGetString(ORDER_SYMBOL) == _Symbol) {

                if(DeletePendingOrder(ticket)) {
                    deleted++;
                }
            }
        }
    }

    return deleted;
}

//+------------------------------------------------------------------+
//| Close All Carneval Orders (Soup + Hedge)                       |
//| Delegates to CloseAllPositions() in carnHedgeManager             |
//+------------------------------------------------------------------+
void CloseAllCarnevalOrders() {
    CarnLogI(LOG_CAT_ORDER, "=== CLOSE ALL REQUESTED — Closing ALL Carneval orders ===");

    // Close Soup positions (MagicNumber)
    int soupPositions = CloseAllPositionsByMagic(MagicNumber);
    int soupOrders = DeleteAllOrdersByMagic(MagicNumber);

    // Close Hedge positions (MagicNumber + 1)
    int hedgePositions = CloseAllPositionsByMagic(MagicNumber + 1);
    int hedgeOrders = DeleteAllOrdersByMagic(MagicNumber + 1);

    CarnLogI(LOG_CAT_ORDER, StringFormat("CLOSE COMPLETE — Soup: %d pos + %d ord, Hedge: %d pos + %d ord",
             soupPositions, soupOrders, hedgePositions, hedgeOrders));
}

//+------------------------------------------------------------------+
//| UTILITY FUNCTIONS                                                |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Refresh Symbol Rates                                             |
//+------------------------------------------------------------------+
bool RefreshRates() {
    MqlTick tick;
    if(!SymbolInfoTick(_Symbol, tick)) {
        return false;
    }
    return (tick.ask > 0 && tick.bid > 0);
}

