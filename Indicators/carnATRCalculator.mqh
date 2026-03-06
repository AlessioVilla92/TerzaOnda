//+------------------------------------------------------------------+
//|                                         carnATRCalculator.mqh    |
//|                     Carneval EA - ATR Calculator Module         |
//|                                                                  |
//|  ATR indicator for volatility monitoring and DPC support          |
//|  Consolidated from flowATRCalculator + GetATRPips from ModeLogic |
//+------------------------------------------------------------------+
#property copyright "Carneval (C) 2026"
#property link      "https://carnivalle.com"

//+------------------------------------------------------------------+
//| ATR CONDITION THRESHOLDS (hardcoded for monitoring)              |
//| These are used for dashboard display and condition checks        |
//+------------------------------------------------------------------+
#define ATR_THRESHOLD_CALM      8.0   // Below 8 pips = CALM
#define ATR_THRESHOLD_NORMAL    15.0  // 8-15 pips = NORMAL
#define ATR_THRESHOLD_VOLATILE  30.0  // 15-30 pips = VOLATILE
                                       // Above 30 pips = EXTREME

//+------------------------------------------------------------------+
//| ATR CORE FUNCTIONS                                               |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Get ATR in Pips (consolidated from ModeLogic)                    |
//| Uses atrHandle, ATR_Period input, symbolPoint, symbolDigits      |
//| Fallback: 10.0 pips if ATR not available                         |
//+------------------------------------------------------------------+
double GetATRPips() {
    if(atrHandle == INVALID_HANDLE)
    {
        CarnLogD(LOG_CAT_ATR, "GetATRPips: handle INVALID — returning fallback 10.0 pips");
        return 10.0;
    }

    // Verify indicator has calculated enough bars
    int calculated = BarsCalculated(atrHandle);
    if(calculated < 0) {
        static bool errorShown = false;
        if(!errorShown) {
            CarnLogE(LOG_CAT_ATR, StringFormat("BarsCalculated() returned error: %d", GetLastError()));
            errorShown = true;
        }
        return 10.0;
    }
    if(calculated < ATR_Period + 1) {
        static bool warningShown = false;
        if(!warningShown) {
            CarnLogW(LOG_CAT_ATR, StringFormat("Not ready. Bars calculated: %d, Required: %d", calculated, ATR_Period + 1));
            warningShown = true;
        }
        return 10.0;
    }

    double atrBuffer[];
    ArraySetAsSeries(atrBuffer, true);

    if(CopyBuffer(atrHandle, 0, 0, 1, atrBuffer) <= 0) {
        static bool copyErrorShown = false;
        if(!copyErrorShown) {
            CarnLogE(LOG_CAT_ATR, StringFormat("CopyBuffer failed, error: %d", GetLastError()));
            copyErrorShown = true;
        }
        return 10.0;  // Fallback
    }

    // Convert to pips
    double atrPips = atrBuffer[0] / symbolPoint;

    // Correct for 5/3 digit pairs (JPY, etc)
    if(symbolDigits == 5 || symbolDigits == 3)
        atrPips /= 10.0;

    return atrPips;
}

//+------------------------------------------------------------------+
//| Get ATR Condition Based on Value (for monitoring)                |
//+------------------------------------------------------------------+
ENUM_ATR_CONDITION GetATRCondition(double atrPips) {
    if(atrPips < ATR_THRESHOLD_CALM) {
        return ATR_CALM;
    } else if(atrPips < ATR_THRESHOLD_NORMAL) {
        return ATR_NORMAL;
    } else if(atrPips < ATR_THRESHOLD_VOLATILE) {
        return ATR_VOLATILE;
    } else {
        return ATR_EXTREME;
    }
}

//+------------------------------------------------------------------+
//| Get ATR Condition (wrapper using current ATR)                    |
//+------------------------------------------------------------------+
ENUM_ATR_CONDITION GetATRCondition() {
    return GetATRCondition(GetATRPips());
}

//+------------------------------------------------------------------+
//| Get ATR Condition Name                                           |
//+------------------------------------------------------------------+
string GetATRConditionName(ENUM_ATR_CONDITION condition) {
    switch(condition) {
        case ATR_CALM:     return "CALM";
        case ATR_NORMAL:   return "NORMAL";
        case ATR_VOLATILE: return "VOLATILE";
        case ATR_EXTREME:  return "EXTREME";
        default:           return "UNKNOWN";
    }
}

//+------------------------------------------------------------------+
//| ATR VOLATILITY CHECKS                                            |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Check if Market is Too Volatile (for info display only)          |
//+------------------------------------------------------------------+
bool IsMarketTooVolatile() {
    return false;  // Pause on high ATR not used in Carneval
}

//+------------------------------------------------------------------+
//| Check if Market is Calm Enough for Trading                       |
//+------------------------------------------------------------------+
bool IsMarketCalm() {
    double atrPips = GetATRPips();
    ENUM_ATR_CONDITION condition = GetATRCondition(atrPips);
    return (condition == ATR_CALM || condition == ATR_NORMAL);
}

//+------------------------------------------------------------------+
//| Get Volatility Description                                       |
//+------------------------------------------------------------------+
string GetVolatilityDescription() {
    ENUM_ATR_CONDITION condition = GetATRCondition(GetATRPips());

    switch(condition) {
        case ATR_CALM:     return "Low volatility - Calm market";
        case ATR_NORMAL:   return "Normal volatility - Standard conditions";
        case ATR_VOLATILE: return "High volatility - Wider moves expected";
        case ATR_EXTREME:  return "Extreme volatility - Consider pausing";
        default:           return "Unknown";
    }
}

//+------------------------------------------------------------------+
//| ATR INDICATOR MANAGEMENT                                         |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Create ATR Indicator Handle                                      |
//+------------------------------------------------------------------+
bool CreateATRHandle() {
    // Release existing handle if any
    if(atrHandle != INVALID_HANDLE) {
        IndicatorRelease(atrHandle);
    }

    // Create new ATR handle
    atrHandle = iATR(_Symbol, ATR_Timeframe, ATR_Period);

    if(atrHandle == INVALID_HANDLE) {
        LogMessage(LOG_ERROR, "Failed to create ATR indicator, error: " + IntegerToString(GetLastError()));
        return false;
    }

    LogMessage(LOG_SUCCESS, "ATR indicator created: Period=" + IntegerToString(ATR_Period) +
               ", TF=" + EnumToString(ATR_Timeframe));

    return true;
}

//+------------------------------------------------------------------+
//| Release ATR Indicator Handle                                     |
//+------------------------------------------------------------------+
void ReleaseATRHandle() {
    if(atrHandle != INVALID_HANDLE) {
        IndicatorRelease(atrHandle);
        atrHandle = INVALID_HANDLE;
        LogMessage(LOG_INFO, "ATR indicator released");
    }
}

//+------------------------------------------------------------------+
//| Wait for ATR Data to be Ready                                    |
//| In Strategy Tester: uses Sleep() to wait                         |
//| In Live Trading: returns immediately, retries on next tick       |
//+------------------------------------------------------------------+
bool WaitForATRData(int maxWaitMs = 5000) {
    if(atrHandle == INVALID_HANDLE) return false;

    bool isTester = MQLInfoInteger(MQL_TESTER);

    // Immediate check (no Sleep)
    double atrBuffer[];
    ArraySetAsSeries(atrBuffer, true);

    // Check BarsCalculated first
    int calculated = BarsCalculated(atrHandle);
    if(calculated >= ATR_Period + 1) {
        if(CopyBuffer(atrHandle, 0, 0, 1, atrBuffer) > 0 && atrBuffer[0] > 0) {
            return true;  // Data already ready
        }
    }

    // In Live Trading, return immediately without blocking
    if(!isTester) {
        static bool liveWarningShown = false;
        if(!liveWarningShown) {
            CarnLogI(LOG_CAT_ATR, "Live trading — ATR not ready yet, will retry on next tick");
            liveWarningShown = true;
        }
        return false;
    }

    // Strategy Tester: use Sleep() to wait
    int waitCount = 0;
    int waitInterval = 100;  // ms

    while(waitCount * waitInterval < maxWaitMs) {
        calculated = BarsCalculated(atrHandle);
        if(calculated >= ATR_Period + 1) {
            if(CopyBuffer(atrHandle, 0, 0, 1, atrBuffer) > 0 && atrBuffer[0] > 0) {
                CarnLogI(LOG_CAT_ATR, StringFormat("Data ready after %dms", waitCount * waitInterval));
                return true;
            }
        }

        Sleep(waitInterval);
        waitCount++;
    }

    LogMessage(LOG_WARNING, "Timeout waiting for ATR data after " + IntegerToString(maxWaitMs) + "ms");
    return false;
}

//+------------------------------------------------------------------+
//| Initialize ATR - Wrapper                                          |
//| Creates ATR handle and waits for initial data                     |
//| Call this during OnInit()                                         |
//+------------------------------------------------------------------+
bool InitializeATR() {
    if(!CreateATRHandle()) {
        return false;
    }

    if(!WaitForATRData()) {
        LogMessage(LOG_WARNING, "ATR data not immediately available - will be ready on next tick");
        // Don't fail init - data will arrive on next tick
    }

    // Initialize cache
    InitializeATRCache();

    return true;
}

//+------------------------------------------------------------------+
//| Update ATR - Refreshes global ATR and ATR_Pips variables          |
//| Call this on each tick or periodically                             |
//+------------------------------------------------------------------+
void UpdateATR() {
    double newATR = GetATRPips();
    if(newATR > 0) {
        currentATR_Pips = newATR;
        ATR_Pips = newATR;
    }
}

//+------------------------------------------------------------------+
//| ATR HISTORICAL ANALYSIS                                          |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Get Average ATR Over Period                                      |
//+------------------------------------------------------------------+
double GetAverageATR(int periods) {
    if(periods <= 0) return 0;
    if(atrHandle == INVALID_HANDLE) return 0;

    double atrBuffer[];
    ArraySetAsSeries(atrBuffer, true);

    if(CopyBuffer(atrHandle, 0, 0, periods, atrBuffer) <= 0) {
        return 0;
    }

    double sum = 0;
    for(int i = 0; i < periods; i++) {
        sum += atrBuffer[i];
    }

    double avgATR = sum / periods;
    return PointsToPips(avgATR);
}

//+------------------------------------------------------------------+
//| Get ATR Trend (Increasing/Decreasing)                            |
//+------------------------------------------------------------------+
int GetATRTrend(int lookback = 5) {
    if(atrHandle == INVALID_HANDLE) return 0;

    double atrBuffer[];
    ArraySetAsSeries(atrBuffer, true);

    if(CopyBuffer(atrHandle, 0, 0, lookback, atrBuffer) < lookback) {
        return 0;
    }

    // Compare first half average to second half
    double firstHalf = 0, secondHalf = 0;
    int halfPoint = lookback / 2;

    for(int i = 0; i < halfPoint; i++) {
        firstHalf += atrBuffer[i];  // Recent
    }
    for(int i = halfPoint; i < lookback; i++) {
        secondHalf += atrBuffer[i];  // Older
    }

    firstHalf /= halfPoint;
    secondHalf /= (lookback - halfPoint);

    if(firstHalf > secondHalf * 1.1) return 1;   // Increasing
    if(firstHalf < secondHalf * 0.9) return -1;  // Decreasing
    return 0;  // Stable
}

//+------------------------------------------------------------------+
//| Get ATR Trend Description                                        |
//+------------------------------------------------------------------+
string GetATRTrendDescription() {
    int trend = GetATRTrend();

    if(trend > 0) return "INCREASING";
    if(trend < 0) return "DECREASING";
    return "STABLE";
}

//+------------------------------------------------------------------+
//| ATR LOGGING AND REPORTING                                        |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Log Full ATR Report                                              |
//+------------------------------------------------------------------+
void LogATRReport() {
    Log_Header("ATR ANALYSIS REPORT");

    double currentATR = GetATRPips();
    double avgATR = GetAverageATR(20);
    ENUM_ATR_CONDITION condition = GetATRCondition(currentATR);

    Log_KeyValueNum("Current ATR (pips)", currentATR, 1);
    Log_KeyValueNum("Average ATR 20 (pips)", avgATR, 1);
    Log_KeyValue("Condition", GetATRConditionName(condition));
    Log_KeyValue("Trend", GetATRTrendDescription());
    Log_Separator();
}

//+------------------------------------------------------------------+
//| Get ATR Summary String for Dashboard                             |
//+------------------------------------------------------------------+
string GetATRSummary() {
    double atrPips = GetATRPips();
    ENUM_ATR_CONDITION condition = GetATRCondition(atrPips);

    return DoubleToString(atrPips, 1) + " pips (" + GetATRConditionName(condition) + ")";
}

//+------------------------------------------------------------------+
//| ATR UNIFIED CACHE SYSTEM - Simplified (monitoring only)          |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Get ATR Unified - Single Source of Truth                          |
//| updateMode: 0=cache only, 1=force update, 2=if new bar            |
//+------------------------------------------------------------------+
double GetATRPipsUnified(int updateMode = 0) {
    if(atrHandle == INVALID_HANDLE) {
        static bool handleWarningShown = false;
        if(!handleWarningShown) {
            CarnLogW(LOG_CAT_ATR, "Handle invalid, using fallback value");
            handleWarningShown = true;
        }
        return g_atrCache.valuePips > 0 ? g_atrCache.valuePips : 10.0;
    }

    datetime currentBarTime = iTime(_Symbol, ATR_Timeframe, 0);

    // Mode 0: Cache only (for dashboard - fast)
    if(updateMode == 0) {
        if(g_atrCache.isValid) {
            return g_atrCache.valuePips;
        } else {
            updateMode = 1;  // Force update
        }
    }

    // Mode 2: Update only on new candle
    if(updateMode == 2 && g_atrCache.lastBarTime == currentBarTime && g_atrCache.isValid) {
        return g_atrCache.valuePips;
    }

    // Check BarsCalculated
    int calculated = BarsCalculated(atrHandle);
    if(calculated < ATR_Period + 1) {
        return g_atrCache.valuePips > 0 ? g_atrCache.valuePips : 10.0;
    }

    // Force update from indicator
    double atrBuffer[];
    ArraySetAsSeries(atrBuffer, true);

    if(CopyBuffer(atrHandle, 0, 0, 1, atrBuffer) <= 0) {
        return g_atrCache.valuePips > 0 ? g_atrCache.valuePips : 10.0;
    }

    // Convert to pips
    double atrValue = atrBuffer[0];
    double atrPips = atrValue / symbolPoint;

    // JPY pair correction (3 or 5 digits)
    if(symbolDigits == 3 || symbolDigits == 5) {
        atrPips /= 10.0;
    }

    // Update cache
    g_atrCache.valuePips = atrPips;
    g_atrCache.lastFullUpdate = TimeCurrent();
    g_atrCache.lastBarTime = currentBarTime;
    g_atrCache.isValid = true;

    return g_atrCache.valuePips;
}

//+------------------------------------------------------------------+
//| Initialize ATR Cache                                              |
//+------------------------------------------------------------------+
void InitializeATRCache() {
    if(atrHandle != INVALID_HANDLE) {
        GetATRPipsUnified(1);  // Force update
        CarnLogI(LOG_CAT_ATR, StringFormat("ATR Initialized: %s pips", DoubleToString(g_atrCache.valuePips, 1)));
    }
}
