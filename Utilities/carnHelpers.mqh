//+------------------------------------------------------------------+
//|                                                 carnHelpers.mqh  |
//|                   Carneval - Helper Functions                   |
//|                                                                  |
//|  Common utility functions for Carneval EA                      |
//+------------------------------------------------------------------+
#property copyright "Carneval (C) 2026"
#property link      "https://sugamara.com"

//+------------------------------------------------------------------+
//| PRICE CONVERSION FUNCTIONS                                       |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Convert Points to Pips                                           |
//| Handles both 4-digit and 5-digit brokers                         |
//| v13.2.5: Added division by zero protection                       |
//+------------------------------------------------------------------+
double PointsToPips(double points) {
    // v13.2.5 FIX: Prevent division by zero
    if(symbolPoint <= 0) return 0;

    if(symbolDigits == 3 || symbolDigits == 5) {
        return points / (10 * symbolPoint);
    } else {
        return points / symbolPoint;
    }
}

//+------------------------------------------------------------------+
//| Convert Pips to Points                                           |
//+------------------------------------------------------------------+
double PipsToPoints(double pips) {
    if(symbolDigits == 3 || symbolDigits == 5) {
        return pips * 10 * symbolPoint;
    } else {
        return pips * symbolPoint;
    }
}

//+------------------------------------------------------------------+
//| Convert Pips to Price Distance (wrapper)                         |
//+------------------------------------------------------------------+
double PipsToPrice(double pips) {
    return PipsToPoints(pips);
}

//+------------------------------------------------------------------+
//| IsNewBar - Detects new bar on current timeframe                  |
//| Returns true only once per new bar                               |
//+------------------------------------------------------------------+
datetime g_lastBarTime = 0;
bool IsNewBar() {
    datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
    if(currentBarTime != g_lastBarTime) {
        g_lastBarTime = currentBarTime;
        return true;
    }
    return false;
}

//+------------------------------------------------------------------+
//| Get Current Spread in Pips                                       |
//+------------------------------------------------------------------+
double GetSpreadPips() {
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

    // v5.x FIX: Strategy Tester compatibility - return default if no price
    if(ask <= 0 || bid <= 0) {
        return 1.0;  // Default 1 pip spread
    }

    return PointsToPips(ask - bid);
}

//+------------------------------------------------------------------+
//| FORMAT & STRING FUNCTIONS                                        |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Format Price with Correct Digits                                 |
//+------------------------------------------------------------------+
string FormatPrice(double price) {
    return DoubleToString(price, symbolDigits);
}

//+------------------------------------------------------------------+
//| Format Money Value                                               |
//+------------------------------------------------------------------+
string FormatMoney(double amount) {
    if(amount >= 0) {
        return "$" + DoubleToString(amount, 2);
    } else {
        return "-$" + DoubleToString(MathAbs(amount), 2);
    }
}

//+------------------------------------------------------------------+
//| Format Percentage                                                |
//+------------------------------------------------------------------+
string FormatPercent(double percent) {
    return DoubleToString(percent, 2) + "%";
}

//+------------------------------------------------------------------+
//| LOGGING SYSTEM — CENTRALIZED v3.40                                |
//+------------------------------------------------------------------+
//| Central function: CarnLog(level, category, message)               |
//| Format: TIMESTAMP [LEVEL] [CATEGORY] message                      |
//| Filters: MinLogLevel, DetailedLogging, LogOrderExecution,         |
//|          LogHedgeStatus, LogDPCBuffers                            |
//+------------------------------------------------------------------+

// Log Categories
#define LOG_CAT_INIT      "[INIT]"
#define LOG_CAT_ORDER     "[ORDER]"
#define LOG_CAT_POSITION  "[POSITION]"
#define LOG_CAT_SESSION   "[SESSION]"
#define LOG_CAT_SYSTEM    "[SYSTEM]"
#define LOG_CAT_RECOVERY  "[RECOVERY]"
#define LOG_CAT_DEBUG     "[DEBUG]"
#define LOG_CAT_TRIGGER   "[TRIGGER]"
#define LOG_CAT_SOUP      "[SOUP]"
#define LOG_CAT_BREAKOUT  "[BREAKOUT]"
#define LOG_CAT_HEDGE     "[HEDGE]"
#define LOG_CAT_DPC       "[DPC]"
#define LOG_CAT_PERSIST   "[PERSIST]"
#define LOG_CAT_UI        "[UI]"
#define LOG_CAT_FILTER    "[FILTER]"
#define LOG_CAT_ATR       "[ATR]"
#define LOG_CAT_BROKER    "[BROKER]"

//+------------------------------------------------------------------+
//| GetLogTimestamp — ISO-like timestamp                               |
//+------------------------------------------------------------------+
string GetLogTimestamp() {
    datetime now = TimeCurrent();
    return TimeToString(now, TIME_DATE|TIME_SECONDS);
}

//+------------------------------------------------------------------+
//| LogLevelToString — Convert ENUM_LOG_LEVEL to fixed-width string   |
//+------------------------------------------------------------------+
string LogLevelToString(ENUM_LOG_LEVEL level) {
    switch(level) {
        case LOG_DEBUG:   return "DEBUG";
        case LOG_INFO:    return "INFO ";
        case LOG_WARNING: return "WARN ";
        case LOG_ERROR:   return "ERROR";
        case LOG_SUCCESS: return "OK   ";
    }
    return "?????";
}

//+------------------------------------------------------------------+
//| IsModuleLoggingEnabled — Per-module filter                        |
//| WARNING and ERROR always pass. DEBUG/INFO filtered per-module.    |
//+------------------------------------------------------------------+
bool IsModuleLoggingEnabled(string category, ENUM_LOG_LEVEL level) {
    // WARNING, ERROR, SUCCESS always pass
    if(level >= LOG_WARNING) return true;

    // Global debug gate
    if(level == LOG_DEBUG && !DetailedLogging) return false;

    // Per-module filters (only block DEBUG and INFO)
    if(category == LOG_CAT_ORDER && !LogOrderExecution) return false;
    if(category == LOG_CAT_HEDGE && !LogHedgeStatus) return false;
    if(category == LOG_CAT_DPC && level == LOG_DEBUG && !LogDPCBuffers) return false;

    return true;
}

//+------------------------------------------------------------------+
//| LogToCSV_V2 — CSV with header row and Level column                |
//+------------------------------------------------------------------+
void LogToCSV_V2(ENUM_LOG_LEVEL level, string category, string message) {
    string filename = "Carneval_" + _Symbol + "_" +
                      TimeToString(TimeCurrent(), TIME_DATE) + ".csv";
    int handle = FileOpen(filename, FILE_WRITE|FILE_READ|FILE_CSV|FILE_SHARE_WRITE, ',');
    if(handle == INVALID_HANDLE) return;

    // Write header if new/empty file
    if(FileSize(handle) == 0)
    {
        FileWrite(handle, "Time", "Level", "Category", "Message",
                  "Bid", "Upper", "Lower", "Mid", "Cycles", "TotalProfit");
    }

    FileSeek(handle, 0, SEEK_END);
    FileWrite(handle,
              TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS),
              LogLevelToString(level),
              category,
              message,
              DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits),
              DoubleToString(g_dpcUpper, _Digits),
              DoubleToString(g_dpcLower, _Digits),
              DoubleToString(g_dpcMid, _Digits),
              IntegerToString(CountActiveCycles()),
              DoubleToString(g_totalSoupProfit + g_totalBreakoutProfit, 2)
    );
    FileClose(handle);
}

//+------------------------------------------------------------------+
//| CarnLog — Central logging function                                |
//| All logging flows through here for uniform filtering and output   |
//+------------------------------------------------------------------+
void CarnLog(ENUM_LOG_LEVEL level, string category, string message) {
    // 1. Minimum level filter
    if(level < MinLogLevel) return;

    // 2. Per-module filter
    if(!IsModuleLoggingEnabled(category, level)) return;

    // 3. Print to terminal
    PrintFormat("%s [%s] %s %s", GetLogTimestamp(), LogLevelToString(level),
                category, message);

    // 4. CSV output (if enabled)
    if(LogToCSVFile)
        LogToCSV_V2(level, category, message);
}

//+------------------------------------------------------------------+
//| Convenience shortcuts                                              |
//+------------------------------------------------------------------+
void CarnLogD(string cat, string msg) { CarnLog(LOG_DEBUG,   cat, msg); }
void CarnLogI(string cat, string msg) { CarnLog(LOG_INFO,    cat, msg); }
void CarnLogW(string cat, string msg) { CarnLog(LOG_WARNING, cat, msg); }
void CarnLogE(string cat, string msg) { CarnLog(LOG_ERROR,   cat, msg); }

//+------------------------------------------------------------------+
//| STRUCTURED WRAPPERS — High-level logging for common events        |
//+------------------------------------------------------------------+

void Log_OrderCancelled(ulong ticket, string reason) {
    CarnLog(LOG_INFO, LOG_CAT_ORDER,
            StringFormat("CANCELLED ticket=%d reason=%s", ticket, reason));
}

void Log_PositionClosed(ulong ticket, string reason, double profit, double closePrice) {
    CarnLog(LOG_INFO, LOG_CAT_POSITION,
            StringFormat("CLOSED ticket=%d reason=%s profit=%.2f price=%s",
                        ticket, reason, profit, DoubleToString(closePrice, _Digits)));
}

void Log_SessionEnd(int wins, int losses, double profit, int duration) {
    CarnLog(LOG_INFO, LOG_CAT_SESSION,
            StringFormat("END wins=%d losses=%d profit=%.2f duration=%ds",
                        wins, losses, profit, duration));
}

void Log_SessionDailyReset() {
    CarnLog(LOG_INFO, LOG_CAT_SESSION, "DAILY_RESET");
}

void Log_SystemError(string component, int code, string message) {
    CarnLog(LOG_ERROR, LOG_CAT_SYSTEM,
            StringFormat("component=%s code=%d message=%s", component, code, message));
}

void Log_SystemWarning(string component, string message) {
    CarnLog(LOG_WARNING, LOG_CAT_SYSTEM,
            StringFormat("component=%s message=%s", component, message));
}

//+------------------------------------------------------------------+
//| DEBUG LOGGING — Only when DetailedLogging=true (via CarnLog)      |
//+------------------------------------------------------------------+

void Log_Debug(string component, string message) {
    CarnLog(LOG_DEBUG, LOG_CAT_DEBUG,
            StringFormat("%s: %s", component, message));
}

//+------------------------------------------------------------------+
//| INITIALIZATION LOGGING                                             |
//+------------------------------------------------------------------+

void Log_InitConfig(string key, string value) {
    CarnLog(LOG_INFO, LOG_CAT_INIT,
            StringFormat("CONFIG %s=%s", key, value));
}

void Log_InitComplete(string component) {
    CarnLog(LOG_INFO, LOG_CAT_INIT,
            StringFormat("COMPLETE component=%s", component));
}

//+------------------------------------------------------------------+
//| REPORT FUNCTIONS — Visual formatting for summaries                 |
//+------------------------------------------------------------------+

void Log_Separator() {
    CarnLog(LOG_INFO, LOG_CAT_SYSTEM,
            "------------------------------------------------------------------------");
}

void Log_Header(string title) {
    CarnLog(LOG_INFO, LOG_CAT_SYSTEM,
            "========================================================================");
    CarnLog(LOG_INFO, LOG_CAT_SYSTEM, StringFormat("  %s", title));
    CarnLog(LOG_INFO, LOG_CAT_SYSTEM,
            "========================================================================");
}

void Log_SubHeader(string title) {
    CarnLog(LOG_INFO, LOG_CAT_SYSTEM,
            "------------------------------------------------------------------------");
    CarnLog(LOG_INFO, LOG_CAT_SYSTEM, StringFormat("  %s", title));
    CarnLog(LOG_INFO, LOG_CAT_SYSTEM,
            "------------------------------------------------------------------------");
}

void Log_KeyValue(string key, string value) {
    CarnLog(LOG_INFO, LOG_CAT_SYSTEM,
            StringFormat("  %-30s %s", key + ":", value));
}

void Log_KeyValueNum(string key, double value, int decimals = 2) {
    CarnLog(LOG_INFO, LOG_CAT_SYSTEM,
            StringFormat("  %-30s %.*f", key + ":", decimals, value));
}

//+------------------------------------------------------------------+
//| LEGACY WRAPPER — LogMessage compatibility                         |
//+------------------------------------------------------------------+

void LogMessage(ENUM_LOG_LEVEL type, string message) {
    CarnLog(type, LOG_CAT_SYSTEM, message);
}

//+------------------------------------------------------------------+
//| ACCOUNT FUNCTIONS                                                |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Get Account Equity                                               |
//+------------------------------------------------------------------+
double GetEquity() {
    return AccountInfoDouble(ACCOUNT_EQUITY);
}

//+------------------------------------------------------------------+
//| Get Account Balance                                              |
//+------------------------------------------------------------------+
double GetBalance() {
    return AccountInfoDouble(ACCOUNT_BALANCE);
}

//+------------------------------------------------------------------+
//| Get Account Free Margin                                          |
//+------------------------------------------------------------------+
double GetFreeMargin() {
    return AccountInfoDouble(ACCOUNT_MARGIN_FREE);
}

//+------------------------------------------------------------------+
//| Get Margin Level (%)                                             |
//+------------------------------------------------------------------+
double GetMarginLevel() {
    double margin = AccountInfoDouble(ACCOUNT_MARGIN);
    if(margin <= 0) return 0;
    return (AccountInfoDouble(ACCOUNT_EQUITY) / margin) * 100.0;
}

//+------------------------------------------------------------------+
//| Calculate Current Drawdown (%)                                   |
//+------------------------------------------------------------------+
double GetCurrentDrawdown() {
    double balance = GetBalance();
    double equity = GetEquity();

    if(balance <= 0) return 0;

    if(equity >= balance) return 0;  // No drawdown if in profit

    return ((balance - equity) / balance) * 100.0;
}

//+------------------------------------------------------------------+
//| CHART OBJECT FUNCTIONS                                           |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Create Horizontal Line                                           |
//+------------------------------------------------------------------+
void CreateHLine(string name, double price, color clr, int width = 1, ENUM_LINE_STYLE style = STYLE_SOLID) {
    if(ObjectFind(0, name) >= 0) {
        ObjectSetDouble(0, name, OBJPROP_PRICE, price);
        return;
    }

    ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);
    ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
    ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
    ObjectSetInteger(0, name, OBJPROP_STYLE, style);
    ObjectSetInteger(0, name, OBJPROP_BACK, true);
    ObjectSetInteger(0, name, OBJPROP_ZORDER, 100);
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
//| Create Exit Arrow on Chart                                        |
//| TP = Asterisco bianco | SL = Freccia rossa                        |
//+------------------------------------------------------------------+
void CreateExitArrow(double price, datetime time, bool isBuy, bool isTP, int level, string prefix) {
    if(!SHOW_EXIT_ARROWS) return;

    string name = "CARNEVAL_EXIT_" + prefix + "_" + TimeToString(time, TIME_DATE|TIME_MINUTES);

    // TP = asterisco bianco (Wingdings 171) | SL = freccia rossa
    int arrowCode;
    if(isTP)
        arrowCode = 171;                       // Wingdings asterisco
    else
        arrowCode = isBuy ? 234 : 233;        // Freccia standard

    color arrowColor = isTP ? EXIT_ARROW_TP_COLOR : EXIT_ARROW_SL_COLOR;

    ObjectCreate(0, name, OBJ_ARROW, 0, time, price);
    ObjectSetInteger(0, name, OBJPROP_ARROWCODE, arrowCode);
    ObjectSetInteger(0, name, OBJPROP_COLOR, arrowColor);
    ObjectSetInteger(0, name, OBJPROP_WIDTH, EXIT_ARROW_SIZE);
    ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_CENTER);
    ObjectSetInteger(0, name, OBJPROP_BACK, false);
    ObjectSetInteger(0, name, OBJPROP_ZORDER, 500);
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);

    string tooltip = StringFormat("%s %s L%d | %.5f", isBuy ? "BUY" : "SELL", isTP ? "TP" : "SL", level, price);
    ObjectSetString(0, name, OBJPROP_TOOLTIP, tooltip);
}
