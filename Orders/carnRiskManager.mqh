//+------------------------------------------------------------------+
//|                                           carnRiskManager.mqh    |
//|                     Carneval EA - Risk Management               |
//|                                                                  |
//|  Comprehensive risk management for Carneval EA                 |
//+------------------------------------------------------------------+
#property copyright "Carneval (C) 2026"
#property link      "https://carnivalle.com"

//+------------------------------------------------------------------+
//| THROTTLING VARIABLES FOR LOG OPTIMIZATION                         |
//+------------------------------------------------------------------+
datetime g_lastMarginWarning = 0;       // Last margin warning log time
datetime g_lastMarginLevelWarning = 0;  // Last margin level warning log time
datetime g_lastVolatilityWarning = 0;   // Last volatility warning log time
int      g_warningThrottleSec = 300;    // Warning throttle: 5 minutes

//+------------------------------------------------------------------+
//| RISK MANAGER INITIALIZATION                                      |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Initialize Risk Manager                                          |
//+------------------------------------------------------------------+
bool InitializeRiskManager() {
    // Store initial equity
    startingEquity = GetEquity();
    startingBalance = GetBalance();

    // Initialize tracking variables
    maxDrawdownReached = 0;
    maxEquityReached = startingEquity;

    LogMessage(LOG_SUCCESS, "Risk Manager initialized");
    LogMessage(LOG_INFO, "Starting Equity: " + FormatMoney(startingEquity));

    return true;
}

//+------------------------------------------------------------------+
//| MAIN RISK CHECK FUNCTION                                         |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Perform All Risk Checks                                          |
//| Returns: true if trading is allowed, false if blocked            |
//+------------------------------------------------------------------+
bool PerformRiskChecks() {
    // 1. Margin Check (logging throttled inside HasSufficientMargin)
    if(!HasSufficientMargin()) {
        CarnLogW(LOG_CAT_ORDER, StringFormat("RISK BLOCKED — Margin insufficiente | Free=%s | Level=%s%%",
                 DoubleToString(AccountInfoDouble(ACCOUNT_MARGIN_FREE), 2),
                 DoubleToString(AccountInfoDouble(ACCOUNT_MARGIN_LEVEL), 1)));
        return false;
    }

    CalculateTotalExposure();
    CarnLogD(LOG_CAT_ORDER, StringFormat("RISK OK — Free=%s | Level=%s%% | Long=%s | Short=%s | NetExp=%s",
             DoubleToString(AccountInfoDouble(ACCOUNT_MARGIN_FREE), 2),
             DoubleToString(AccountInfoDouble(ACCOUNT_MARGIN_LEVEL), 1),
             DoubleToString(totalLongLots, 2),
             DoubleToString(totalShortLots, 2),
             DoubleToString(netExposure, 2)));

    return true;
}

//+------------------------------------------------------------------+
//| Reset Daily Stats (Call at start of new day)                     |
//+------------------------------------------------------------------+
void ResetDailyFlags() {
    dailyRealizedProfit = 0;
    dailyWins = 0;
    dailyLosses = 0;

    LogMessage(LOG_INFO, "Daily stats reset for new trading day");
}

//+------------------------------------------------------------------+
//| MARGIN MANAGEMENT                                                |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Check if Sufficient Margin Available                             |
//+------------------------------------------------------------------+
bool HasSufficientMargin() {
    double freeMargin = GetFreeMargin();
    double marginLevel = GetMarginLevel();

    // Dynamic margin check based on equity (1% minimum, at least $50)
    double minMarginRequired = AccountInfoDouble(ACCOUNT_EQUITY) * 0.01;
    if(minMarginRequired < 50) minMarginRequired = 50;  // Minimum absolute $50

    if(freeMargin < minMarginRequired) {
        // Throttled logging - 1x every 5 minutes if condition persists
        if(TimeCurrent() - g_lastMarginWarning >= g_warningThrottleSec) {
            LogMessage(LOG_WARNING, "Free margin too low: " + FormatMoney(freeMargin) + " (min: " + FormatMoney(minMarginRequired) + ")");
            g_lastMarginWarning = TimeCurrent();
        }
        return false;
    }

    // Margin level check (if positions open)
    if(marginLevel > 0 && marginLevel < 200) {
        // Throttled logging - 1x every 5 minutes if condition persists
        if(TimeCurrent() - g_lastMarginLevelWarning >= g_warningThrottleSec) {
            LogMessage(LOG_WARNING, "Margin level too low: " + FormatPercent(marginLevel));
            g_lastMarginLevelWarning = TimeCurrent();
        }
        return false;
    }

    return true;
}

//+------------------------------------------------------------------+
//| Calculate Margin Required for Order                              |
//+------------------------------------------------------------------+
double CalculateMarginRequired(double lots, ENUM_ORDER_TYPE orderType) {
    double margin = 0;

    if(!OrderCalcMargin(orderType, _Symbol, lots, SymbolInfoDouble(_Symbol, SYMBOL_ASK), margin)) {
        CarnLogE(LOG_CAT_ORDER, StringFormat("OrderCalcMargin FAILED | Lots=%.2f | Type=%s | Error=%d",
                 lots, EnumToString(orderType), GetLastError()));
        return -1;
    }

    return margin;
}

//+------------------------------------------------------------------+
//| EXPOSURE MANAGEMENT                                              |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Calculate Total Exposure (Long vs Short lots)                    |
//+------------------------------------------------------------------+
void CalculateTotalExposure() {
    totalLongLots = 0;
    totalShortLots = 0;

    for(int i = PositionsTotal() - 1; i >= 0; i--) {
        ulong ticket = PositionGetTicket(i);
        if(!PositionSelectByTicket(ticket)) continue;
        if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

        long magic = PositionGetInteger(POSITION_MAGIC);
        if(magic != MagicNumber && magic != MagicNumber + 1) continue;

        double lots = PositionGetDouble(POSITION_VOLUME);
        ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

        if(posType == POSITION_TYPE_BUY)
            totalLongLots += lots;
        else
            totalShortLots += lots;
    }

    netExposure = totalLongLots - totalShortLots;
    isNeutral = (MathAbs(netExposure) < 0.005);
}

//+------------------------------------------------------------------+
//| Check Exposure Balance                                           |
//+------------------------------------------------------------------+
bool CheckExposureBalance() {
    CalculateTotalExposure();

    if(!isNeutral) {
        double absExposure = MathAbs(netExposure);

        if(absExposure > 0.15) {
            LogMessage(LOG_WARNING, "Critical exposure imbalance: " +
                       DoubleToString(absExposure, 2) + " lot");
            return false;
        }
    }

    return true;
}

//+------------------------------------------------------------------+
//| Get Exposure Risk Level                                          |
//| Returns: 0=Safe, 1=Warning, 2=Critical                           |
//+------------------------------------------------------------------+
int GetExposureRiskLevel() {
    CalculateTotalExposure();
    double absExposure = MathAbs(netExposure);

    if(absExposure <= 0.05) return 0;   // Safe
    if(absExposure <= 0.10) return 1;   // Warning
    return 2;  // Critical
}

//+------------------------------------------------------------------+
//| VOLATILITY MANAGEMENT                                            |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Check Volatility Risk                                            |
//+------------------------------------------------------------------+
int GetVolatilityRiskLevel() {
    ENUM_ATR_CONDITION condition = GetATRCondition(GetATRPips());

    switch(condition) {
        case ATR_CALM:     return 0;  // Low risk
        case ATR_NORMAL:   return 1;  // Normal risk
        case ATR_VOLATILE: return 2;  // High risk
        case ATR_EXTREME:  return 3;  // Extreme risk
    }

    return 1;
}

//+------------------------------------------------------------------+
//| Should Reduce Position Size Based on Volatility                  |
//+------------------------------------------------------------------+
double GetVolatilityLotMultiplier() {
    int riskLevel = GetVolatilityRiskLevel();

    switch(riskLevel) {
        case 0: return 1.0;    // Full size
        case 1: return 1.0;    // Full size
        case 2: return 0.75;   // 75% size
        case 3: return 0.5;    // 50% size
    }

    return 1.0;
}

//+------------------------------------------------------------------+
//| DRAWDOWN TRACKING                                                |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Update Equity High Water Mark                                    |
//+------------------------------------------------------------------+
void UpdateEquityTracking() {
    double currentEquity = GetEquity();

    // Update high water mark
    if(currentEquity > maxEquityReached) {
        maxEquityReached = currentEquity;
    }

    // Calculate current drawdown from peak
    double ddFromPeak = 0;
    if(maxEquityReached > 0) {
        ddFromPeak = ((maxEquityReached - currentEquity) / maxEquityReached) * 100.0;
    }

    // Update max drawdown
    if(ddFromPeak > maxDrawdownReached) {
        maxDrawdownReached = ddFromPeak;
    }
}

//+------------------------------------------------------------------+
//| Get Drawdown from Peak Equity                                    |
//+------------------------------------------------------------------+
double GetDrawdownFromPeak() {
    double currentEquity = GetEquity();

    if(maxEquityReached <= 0) return 0;
    if(currentEquity >= maxEquityReached) return 0;

    return ((maxEquityReached - currentEquity) / maxEquityReached) * 100.0;
}

//+------------------------------------------------------------------+
//| RISK REPORT                                                      |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Generate Risk Report                                             |
//+------------------------------------------------------------------+
void LogRiskReport() {
    Log_Header("RISK MANAGEMENT REPORT");

    // Account
    Log_SubHeader("ACCOUNT STATUS");
    Log_KeyValue("Equity", FormatMoney(GetEquity()));
    Log_KeyValue("Balance", FormatMoney(GetBalance()));
    Log_KeyValue("Free Margin", FormatMoney(GetFreeMargin()));
    Log_KeyValue("Margin Level", FormatPercent(GetMarginLevel()));

    // Drawdown
    Log_SubHeader("DRAWDOWN");
    Log_KeyValue("Current Drawdown", FormatPercent(GetCurrentDrawdown()));
    Log_KeyValue("Drawdown from Peak", FormatPercent(GetDrawdownFromPeak()));
    Log_KeyValue("Max DD (Session)", FormatPercent(maxDrawdownReached));

    // Exposure
    Log_SubHeader("EXPOSURE");
    CalculateTotalExposure();
    Log_KeyValueNum("Total Long (lot)", totalLongLots, 2);
    Log_KeyValueNum("Total Short (lot)", totalShortLots, 2);
    Log_KeyValueNum("Net Exposure (lot)", netExposure, 2);
    Log_KeyValue("Status", isNeutral ? "NEUTRAL (OK)" : "IMBALANCED (WARN)");

    // Volatility
    Log_SubHeader("VOLATILITY");
    double atrPips = GetATRPips();
    Log_KeyValueNum("ATR (pips)", atrPips, 1);
    Log_KeyValue("Condition", GetATRConditionName(GetATRCondition(atrPips)));

    Log_Separator();
}

//+------------------------------------------------------------------+
//| Get Risk Summary for Dashboard                                   |
//+------------------------------------------------------------------+
string GetRiskSummary() {
    int exposureRisk = GetExposureRiskLevel();
    int volatilityRisk = GetVolatilityRiskLevel();
    double dd = GetCurrentDrawdown();

    string status = "OK";

    if(dd > 14.0) status = "HIGH RISK";
    else if(exposureRisk > 1 || volatilityRisk > 2) status = "WARNING";
    else if(dd > 10.0) status = "CAUTION";

    return status + " (DD:" + FormatPercent(dd) + ")";
}
