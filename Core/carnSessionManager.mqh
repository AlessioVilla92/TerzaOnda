//+------------------------------------------------------------------+
//|                                      carnSessionManager.mqh      |
//|                     Carneval EA - Session Manager               |
//|                          Trading Hour Control                     |
//+------------------------------------------------------------------+
#property copyright "Carneval (C) 2026"
#property link      "https://carnivalle.com"

//+------------------------------------------------------------------+
//| Global Session Variables                                          |
//+------------------------------------------------------------------+
bool   sessionStartTriggered = false;      // Has session start been triggered today?
bool   sessionCloseTriggered = false;      // Has session close been triggered today?
int    lastSessionDay = -1;                // Last day we checked (for daily reset)

//+------------------------------------------------------------------+
//| Parse Time String to Minutes                                      |
//| Converts "HH:MM" format to total minutes from midnight            |
//+------------------------------------------------------------------+
int ParseTimeToMinutes(string timeStr) {
    // Handle empty or invalid input
    if(StringLen(timeStr) < 4) return -1;

    // Find the colon separator
    int colonPos = StringFind(timeStr, ":");
    if(colonPos < 0) return -1;

    // Extract hours and minutes
    string hourStr = StringSubstr(timeStr, 0, colonPos);
    string minStr = StringSubstr(timeStr, colonPos + 1);

    int hours = (int)StringToInteger(hourStr);
    int mins = (int)StringToInteger(minStr);

    // Validate ranges
    if(hours < 0 || hours > 23 || mins < 0 || mins > 59) return -1;

    return hours * 60 + mins;
}

//+------------------------------------------------------------------+
//| Check if Within Trading Session                                   |
//| Returns true if trading is allowed based on session times         |
//+------------------------------------------------------------------+
bool IsWithinSession() {
    // If session filter is disabled, always allow trading
    if(!EnableSessionFilter) return true;

    // Get current broker time
    datetime now = TimeCurrent();
    MqlDateTime dt;
    TimeToStruct(now, dt);

    int currentMinutes = dt.hour * 60 + dt.min;

    // Parse start and close times
    int startMinutes = ParseTimeToMinutes(SessionStart_UTC);
    int closeMinutes = ParseTimeToMinutes(SessionEnd_UTC);

    if(startMinutes < 0 || closeMinutes < 0) {
        Log_SystemWarning("Session", "Invalid time format, using 09:30-17:00");
        startMinutes = 9 * 60 + 30;
        closeMinutes = 17 * 60;
    }

    // Check if before session start
    if(currentMinutes < startMinutes) {
        return false;  // Before session start - don't trade
    }

    // Check if after session end
    if(currentMinutes >= closeMinutes) {
        return false;  // After session end - don't trade
    }

    return true;  // Within trading session
}

//+------------------------------------------------------------------+
//| Reset Daily Session Flags                                         |
//| Call this at the start of each day                                |
//+------------------------------------------------------------------+
void ResetDailySessionFlags() {
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);

    if(dt.day_of_year != lastSessionDay) {
        sessionStartTriggered = false;
        sessionCloseTriggered = false;
        lastSessionDay = dt.day_of_year;

        if(EnableSessionFilter) {
            Log_SessionDailyReset();
        }
    }
}

//+------------------------------------------------------------------+
//| Handle Session End                                                |
//| Closes positions based on session end rules:                      |
//| - CloseSingleAtSessionEnd: close Soup positions without hedge     |
//| - CloseHedgedAtSessionEnd: close hedged pairs too                 |
//+------------------------------------------------------------------+
void HandleSessionEnd() {
    // Skip if session filter is disabled
    if(!EnableSessionFilter) return;

    // Reset daily flags if needed
    ResetDailySessionFlags();

    // Skip if already triggered today
    if(sessionCloseTriggered) return;

    // Check if we are at or past session end
    datetime now = TimeCurrent();
    MqlDateTime dt;
    TimeToStruct(now, dt);
    int currentMinutes = dt.hour * 60 + dt.min;
    int closeMinutes = ParseTimeToMinutes(SessionEnd_UTC);
    if(closeMinutes < 0) return;
    if(currentMinutes < closeMinutes) return;

    sessionCloseTriggered = true;

    int closedSingle = 0;
    int closedHedged = 0;
    int deletedOrders = 0;

    // Close single (unhedged) Soup positions if enabled
    if(CloseSingleAtSessionEnd) {
        // Iterate backwards through positions - close Soup (MagicNumber) that have no active hedge
        for(int i = PositionsTotal() - 1; i >= 0; i--) {
            ulong ticket = PositionGetTicket(i);
            if(ticket == 0) continue;

            // Only our Soup positions (MagicNumber)
            if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
            if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

            // Check if this Soup position has an active hedge (MagicNumber+1)
            bool hasHedge = false;
            for(int j = PositionsTotal() - 1; j >= 0; j--) {
                ulong hedgeTicket = PositionGetTicket(j);
                if(hedgeTicket == 0 || hedgeTicket == ticket) continue;
                if(PositionSelectByTicket(hedgeTicket)) {
                    if(PositionGetInteger(POSITION_MAGIC) == MagicNumber + 1 &&
                       PositionGetString(POSITION_SYMBOL) == _Symbol) {
                        hasHedge = true;
                        break;
                    }
                }
            }
            // Re-select the original ticket after scanning
            PositionSelectByTicket(ticket);

            if(!hasHedge) {
                // No active hedge - close this single Soup position
                double closeProfit = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
                double closePrice = PositionGetDouble(POSITION_PRICE_CURRENT);
                if(trade.PositionClose(ticket)) {
                    closedSingle++;
                    Log_PositionClosed(ticket, "SESSION_END_SINGLE", closeProfit, closePrice);
                } else {
                    Log_SystemError("Session", GetLastError(), StringFormat("Close single position #%d failed", ticket));
                }
            }
        }
    }

    // Close hedged pairs too if enabled
    if(CloseHedgedAtSessionEnd) {
        // Close all Soup positions (MagicNumber)
        for(int i = PositionsTotal() - 1; i >= 0; i--) {
            ulong ticket = PositionGetTicket(i);
            if(ticket == 0) continue;
            if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
            if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

            double profitH = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
            double priceH = PositionGetDouble(POSITION_PRICE_CURRENT);
            if(trade.PositionClose(ticket)) {
                closedHedged++;
                Log_PositionClosed(ticket, "SESSION_END_HEDGED", profitH, priceH);
            } else {
                Log_SystemError("Session", GetLastError(), StringFormat("Close hedged position #%d failed", ticket));
            }
        }

        // Close all Hedge positions (MagicNumber+1)
        for(int i = PositionsTotal() - 1; i >= 0; i--) {
            ulong ticket = PositionGetTicket(i);
            if(ticket == 0) continue;
            if(PositionGetInteger(POSITION_MAGIC) != MagicNumber + 1) continue;
            if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

            double profitL = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
            double priceL = PositionGetDouble(POSITION_PRICE_CURRENT);
            if(trade.PositionClose(ticket)) {
                closedHedged++;
                Log_PositionClosed(ticket, "SESSION_END_HEDGE_LEG", profitL, priceL);
            } else {
                Log_SystemError("Session", GetLastError(), StringFormat("Close hedge position #%d failed", ticket));
            }
        }
    }

    // Delete pending orders for both magic numbers
    deletedOrders = DeleteAllPendingOrdersForSession();

    int totalClosed = closedSingle + closedHedged;
    Log_SessionEnd(totalClosed, deletedOrders, sessionRealizedProfit, 0);

    if(EnableAlerts && !MQLInfoInteger(MQL_TESTER)) {
        Alert("CARNEVAL: Session closed - single=", closedSingle,
              " hedged=", closedHedged, " orders=", deletedOrders);
    }
}

//+------------------------------------------------------------------+
//| Close All Positions for Session End                               |
//| Closes positions with MagicNumber and MagicNumber+1               |
//| Returns number of positions closed                                |
//+------------------------------------------------------------------+
int CloseAllPositionsForSession() {
    int closed = 0;

    // Iterate backwards through positions
    for(int i = PositionsTotal() - 1; i >= 0; i--) {
        ulong ticket = PositionGetTicket(i);
        if(ticket == 0) continue;

        long magic = PositionGetInteger(POSITION_MAGIC);

        // Only close our EA's positions (Soup=MagicNumber, Hedge=MagicNumber+1)
        if(magic != MagicNumber && magic != MagicNumber + 1) continue;

        // Only close positions on current symbol
        if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

        double profitS = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
        double priceS = PositionGetDouble(POSITION_PRICE_CURRENT);
        if(trade.PositionClose(ticket)) {
            closed++;
            Log_PositionClosed(ticket, "SESSION_END", profitS, priceS);
        } else {
            Log_SystemError("Session", GetLastError(), StringFormat("Close position #%d failed", ticket));
        }
    }

    return closed;
}

//+------------------------------------------------------------------+
//| Delete All Pending Orders for Session End                         |
//| Deletes orders with MagicNumber and MagicNumber+1                 |
//| Returns number of orders deleted                                  |
//+------------------------------------------------------------------+
int DeleteAllPendingOrdersForSession() {
    int deleted = 0;

    // Iterate backwards through orders
    for(int i = OrdersTotal() - 1; i >= 0; i--) {
        ulong ticket = OrderGetTicket(i);
        if(ticket == 0) continue;

        long magic = OrderGetInteger(ORDER_MAGIC);

        // Only delete our EA's orders (Soup=MagicNumber, Hedge=MagicNumber+1)
        if(magic != MagicNumber && magic != MagicNumber + 1) continue;

        // Only delete orders on current symbol
        if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;

        if(trade.OrderDelete(ticket)) {
            deleted++;
            Log_OrderCancelled(ticket, "SESSION_END");
        } else {
            Log_SystemError("Session", GetLastError(), StringFormat("Delete order #%d failed", ticket));
        }
    }

    return deleted;
}

//+------------------------------------------------------------------+
//| Get Session Status String                                         |
//| Returns human-readable session status                             |
//+------------------------------------------------------------------+
string GetSessionStatus() {
    if(!EnableSessionFilter) return "DISABLED";

    if(IsWithinSession()) {
        return "ACTIVE (" + SessionStart_UTC + "-" + SessionEnd_UTC + ")";
    } else {
        MqlDateTime dt;
        TimeToStruct(TimeCurrent(), dt);
        int currentMinutes = dt.hour * 60 + dt.min;
        int startMinutes = ParseTimeToMinutes(SessionStart_UTC);

        if(currentMinutes < startMinutes) {
            return "WAITING (starts " + SessionStart_UTC + ")";
        } else {
            return "CLOSED (ended " + SessionEnd_UTC + ")";
        }
    }
}

//+------------------------------------------------------------------+
//| Initialize Session Manager                                        |
//| Call this in OnInit()                                             |
//+------------------------------------------------------------------+
void InitializeSessionManager() {
    if(!EnableSessionFilter) {
        Log_InitConfig("Session", "DISABLED");
        return;
    }

    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    lastSessionDay = dt.day_of_year;
    sessionStartTriggered = false;
    sessionCloseTriggered = false;

    int startMin = ParseTimeToMinutes(SessionStart_UTC);
    int closeMin = ParseTimeToMinutes(SessionEnd_UTC);

    if(startMin < 0 || closeMin < 0) {
        Log_SystemWarning("Session", "Invalid time format HH:MM");
    }

    Log_InitConfig("Session.Start", SessionStart_UTC);
    Log_InitConfig("Session.End", SessionEnd_UTC);
    Log_InitConfig("Session.CloseSingle", CloseSingleAtSessionEnd ? "YES" : "NO");
    Log_InitConfig("Session.CloseHedged", CloseHedgedAtSessionEnd ? "YES" : "NO");
    Log_InitComplete("Session");
}
