//+------------------------------------------------------------------+
//|                                          carnPairPresets.mqh     |
//|                     Carneval EA - Pair Presets                  |
//|                                                                  |
//|  Optimized presets for Carneval EA pairs                       |
//+------------------------------------------------------------------+
#property copyright "Carneval (C) 2026"
#property link      "https://carnivalle.com"

//+------------------------------------------------------------------+
//| ACTIVE PAIR PARAMETERS - Set by ApplyPairPresets()               |
//+------------------------------------------------------------------+

// Pair Characteristics
double activePair_Spread = 0;               // Typical spread (pips)
double activePair_DailyRange = 0;           // Average daily range (pips)
double activePair_ATR_Typical = 0;          // Typical ATR H4 (pips)
double activePair_MinBrokerDistance = 0;    // Minimum broker distance (pips)

// Recommended Settings
double activePair_RecommendedSpacing = 0;   // Recommended spacing (pips)
double activePair_RecommendedBaseLot = 0;   // Base lot (always 0.01)

// Performance Targets
double activePair_TargetROI = 0;            // Monthly target ROI (%)
double activePair_MaxDrawdown = 0;          // Expected max drawdown (%)

// Trading Sessions
string activePair_BestSessions = "";        // Best sessions for trading

//+------------------------------------------------------------------+
//| Apply Pair Presets based on Selection                            |
//| Uses global InstrumentPreset from carnInputParameters.mqh        |
//+------------------------------------------------------------------+
void ApplyPairPresets() {
    // Use global InstrumentPreset input parameter (ENUM_FOREX_PAIR)
    ENUM_FOREX_PAIR pair = InstrumentPreset;

    switch(pair) {

        //==============================================================
        // EUR/USD - Most Liquid Forex Pair
        //==============================================================
        case PAIR_EURUSD:
            // Characteristics
            activePair_Spread = EURUSD_EstimatedSpread;
            activePair_DailyRange = EURUSD_DailyRange;
            activePair_ATR_Typical = EURUSD_ATR_Typical;
            activePair_MinBrokerDistance = 10.0;

            // Recommended Settings
            activePair_RecommendedSpacing = EURUSD_DefaultSpacing;
            activePair_RecommendedBaseLot = 0.01;

            // Performance Targets
            activePair_TargetROI = 12.0;
            activePair_MaxDrawdown = 10.0;

            // Sessions
            activePair_BestSessions = "London (08:00-16:00 GMT), NY (13:00-21:00 GMT)";

            Log_InitConfig("Preset", "EUR/USD - Standard Configuration");
            break;

        //==============================================================
        // USD/CAD - North American Pair
        //==============================================================
        case PAIR_USDCAD:
            // Characteristics
            activePair_Spread = USDCAD_EstimatedSpread;
            activePair_DailyRange = USDCAD_DailyRange;
            activePair_ATR_Typical = USDCAD_ATR_Typical;
            activePair_MinBrokerDistance = 10.0;

            // Recommended Settings
            activePair_RecommendedSpacing = USDCAD_DefaultSpacing;
            activePair_RecommendedBaseLot = 0.01;

            // Performance Targets
            activePair_TargetROI = 10.0;
            activePair_MaxDrawdown = 10.0;

            // Sessions
            activePair_BestSessions = "NY (13:00-21:00 GMT), London-NY Overlap";

            Log_InitConfig("Preset", "USD/CAD - North American Configuration");
            break;

        //==============================================================
        // AUD/NZD - Best for Range Trading (Highly Correlated)
        //==============================================================
        case PAIR_AUDNZD:
            // Characteristics
            activePair_Spread = AUDNZD_EstimatedSpread;
            activePair_DailyRange = AUDNZD_DailyRange;
            activePair_ATR_Typical = AUDNZD_ATR_Typical;
            activePair_MinBrokerDistance = 15.0;

            // Recommended Settings
            activePair_RecommendedSpacing = AUDNZD_DefaultSpacing;
            activePair_RecommendedBaseLot = 0.01;

            // Performance Targets
            activePair_TargetROI = 10.0;
            activePair_MaxDrawdown = 8.0;

            // Sessions
            activePair_BestSessions = "Asia (22:00-08:00 GMT), Sydney overlap";

            Log_InitConfig("Preset", "AUD/NZD - BEST FOR RANGE");
            break;

        //==============================================================
        // EUR/CHF - Very Low Volatility
        //==============================================================
        case PAIR_EURCHF:
            // Characteristics
            activePair_Spread = EURCHF_EstimatedSpread;
            activePair_DailyRange = EURCHF_DailyRange;
            activePair_ATR_Typical = EURCHF_ATR_Typical;
            activePair_MinBrokerDistance = 10.0;

            // Recommended Settings
            activePair_RecommendedSpacing = EURCHF_DefaultSpacing;
            activePair_RecommendedBaseLot = 0.01;

            // Performance Targets
            activePair_TargetROI = 8.0;
            activePair_MaxDrawdown = 6.0;

            // Sessions
            activePair_BestSessions = "London (08:00-16:00 GMT)";

            Log_InitConfig("Preset", "EUR/CHF - Ultra-Low Volatility");
            break;

        //==============================================================
        // AUD/CAD - Medium Volatility Commodity Pair
        //==============================================================
        case PAIR_AUDCAD:
            // Characteristics
            activePair_Spread = AUDCAD_EstimatedSpread;
            activePair_DailyRange = AUDCAD_DailyRange;
            activePair_ATR_Typical = AUDCAD_ATR_Typical;
            activePair_MinBrokerDistance = 12.0;

            // Recommended Settings
            activePair_RecommendedSpacing = AUDCAD_DefaultSpacing;
            activePair_RecommendedBaseLot = 0.01;

            // Performance Targets
            activePair_TargetROI = 10.0;
            activePair_MaxDrawdown = 10.0;

            // Sessions
            activePair_BestSessions = "Asia-London overlap, NY session";

            Log_InitConfig("Preset", "AUD/CAD - Commodity Pair");
            break;

        //==============================================================
        // NZD/CAD - Similar to AUD/CAD
        //==============================================================
        case PAIR_NZDCAD:
            // Characteristics
            activePair_Spread = NZDCAD_EstimatedSpread;
            activePair_DailyRange = NZDCAD_DailyRange;
            activePair_ATR_Typical = NZDCAD_ATR_Typical;
            activePair_MinBrokerDistance = 15.0;

            // Recommended Settings
            activePair_RecommendedSpacing = NZDCAD_DefaultSpacing;
            activePair_RecommendedBaseLot = 0.01;

            // Performance Targets
            activePair_TargetROI = 9.0;
            activePair_MaxDrawdown = 9.0;

            // Sessions
            activePair_BestSessions = "Asia session, early London";

            Log_InitConfig("Preset", "NZD/CAD - Secondary Range Pair");
            break;

        //==============================================================
        // EUR/GBP - Excellent Mean Reverting European Cross
        //==============================================================
        case PAIR_EURGBP:
            // Characteristics
            activePair_Spread = EURGBP_EstimatedSpread;
            activePair_DailyRange = EURGBP_DailyRange;
            activePair_ATR_Typical = EURGBP_ATR_Typical;
            activePair_MinBrokerDistance = 10.0;

            // Recommended Settings
            activePair_RecommendedSpacing = EURGBP_DefaultSpacing;
            activePair_RecommendedBaseLot = 0.01;

            // Performance Targets
            activePair_TargetROI = 10.0;
            activePair_MaxDrawdown = 7.0;

            // Sessions
            activePair_BestSessions = "London (08:00-16:00 GMT)";

            Log_InitConfig("Preset", "EUR/GBP - Excellent Mean Reverting");
            break;

        //==============================================================
        // GBP/USD - Currently Mean Reverting
        //==============================================================
        case PAIR_GBPUSD:
            // Characteristics
            activePair_Spread = GBPUSD_EstimatedSpread;
            activePair_DailyRange = GBPUSD_DailyRange;
            activePair_ATR_Typical = GBPUSD_ATR_Typical;
            activePair_MinBrokerDistance = 10.0;

            // Recommended Settings
            activePair_RecommendedSpacing = GBPUSD_DefaultSpacing;
            activePair_RecommendedBaseLot = 0.01;

            // Performance Targets
            activePair_TargetROI = 12.0;
            activePair_MaxDrawdown = 12.0;

            // Sessions
            activePair_BestSessions = "London (08:00-16:00 GMT), London-NY Overlap";

            Log_InitConfig("Preset", "GBP/USD - Mean Reverting");
            break;

        //==============================================================
        // USD/CHF - Safe Haven Pair
        //==============================================================
        case PAIR_USDCHF:
            // Characteristics
            activePair_Spread = USDCHF_EstimatedSpread;
            activePair_DailyRange = USDCHF_DailyRange;
            activePair_ATR_Typical = USDCHF_ATR_Typical;
            activePair_MinBrokerDistance = 10.0;

            // Recommended Settings
            activePair_RecommendedSpacing = USDCHF_DefaultSpacing;
            activePair_RecommendedBaseLot = 0.01;

            // Performance Targets
            activePair_TargetROI = 10.0;
            activePair_MaxDrawdown = 8.0;

            // Sessions
            activePair_BestSessions = "London (08:00-16:00 GMT), NY session";

            Log_InitConfig("Preset", "USD/CHF - Safe Haven");
            break;

        //==============================================================
        // USD/JPY - High Volatility Sessions
        //==============================================================
        case PAIR_USDJPY:
            // Characteristics
            activePair_Spread = USDJPY_EstimatedSpread;
            activePair_DailyRange = USDJPY_DailyRange;
            activePair_ATR_Typical = USDJPY_ATR_Typical;
            activePair_MinBrokerDistance = 10.0;

            // Recommended Settings
            activePair_RecommendedSpacing = USDJPY_DefaultSpacing;
            activePair_RecommendedBaseLot = 0.01;

            // Performance Targets
            activePair_TargetROI = 15.0;
            activePair_MaxDrawdown = 15.0;

            // Sessions
            activePair_BestSessions = "Tokyo (00:00-08:00 GMT), London-NY Overlap (13:00-17:00 GMT)";

            Log_InitConfig("Preset", "USD/JPY - High Volatility");
            break;

        //==============================================================
        // EUR/JPY - Cross Major
        //==============================================================
        case PAIR_EURJPY:
            // Characteristics
            activePair_Spread = EURJPY_EstimatedSpread;
            activePair_DailyRange = EURJPY_DailyRange;
            activePair_ATR_Typical = EURJPY_ATR_Typical;
            activePair_MinBrokerDistance = 10.0;

            // Recommended Settings
            activePair_RecommendedSpacing = EURJPY_DefaultSpacing;
            activePair_RecommendedBaseLot = 0.01;

            // Performance Targets
            activePair_TargetROI = 12.0;
            activePair_MaxDrawdown = 12.0;

            // Sessions
            activePair_BestSessions = "Tokyo-London Overlap (07:00-09:00 GMT), London (08:00-16:00 GMT)";

            Log_InitConfig("Preset", "EUR/JPY - Cross Major Configuration");
            break;

        //==============================================================
        // AUD/USD - Commodity Major
        //==============================================================
        case PAIR_AUDUSD:
            // Characteristics
            activePair_Spread = AUDUSD_EstimatedSpread;
            activePair_DailyRange = AUDUSD_DailyRange;
            activePair_ATR_Typical = AUDUSD_ATR_Typical;
            activePair_MinBrokerDistance = 10.0;

            // Recommended Settings
            activePair_RecommendedSpacing = AUDUSD_DefaultSpacing;
            activePair_RecommendedBaseLot = 0.01;

            // Performance Targets
            activePair_TargetROI = 11.0;
            activePair_MaxDrawdown = 10.0;

            // Sessions
            activePair_BestSessions = "Sydney (22:00-07:00 GMT), London (08:00-16:00 GMT)";

            Log_InitConfig("Preset", "AUD/USD - Commodity Major Configuration");
            break;

        //==============================================================
        // NZD/USD - Commodity Pair
        //==============================================================
        case PAIR_NZDUSD:
            // Characteristics
            activePair_Spread = NZDUSD_EstimatedSpread;
            activePair_DailyRange = NZDUSD_DailyRange;
            activePair_ATR_Typical = NZDUSD_ATR_Typical;
            activePair_MinBrokerDistance = 10.0;

            // Recommended Settings
            activePair_RecommendedSpacing = NZDUSD_DefaultSpacing;
            activePair_RecommendedBaseLot = 0.01;

            // Performance Targets
            activePair_TargetROI = 10.0;
            activePair_MaxDrawdown = 10.0;

            // Sessions
            activePair_BestSessions = "Wellington-Sydney (21:00-07:00 GMT), London (08:00-16:00 GMT)";

            Log_InitConfig("Preset", "NZD/USD - Commodity Pair Configuration");
            break;

        //==============================================================
        // BTC/USD - Bitcoin vs USD
        // ⚠️ ATTENZIONE: pip = symbolPoint del broker (può variare)
        // ⚠️ Usare LotSize piccolo! (es. 0.001) — 0.05 BTC = ~$4000 exposure
        //==============================================================
        case PAIR_BTCUSD:
            // Characteristics (valori in "pip sistema" ≈ $1 su broker digits=0)
            activePair_Spread = BTCUSD_EstimatedSpread;
            activePair_DailyRange = BTCUSD_DailyRange;
            activePair_ATR_Typical = BTCUSD_ATR_Typical;
            activePair_MinBrokerDistance = 100.0;

            // Recommended Settings
            activePair_RecommendedSpacing = BTCUSD_DefaultSpacing;
            activePair_RecommendedBaseLot = 0.001;

            // Performance Targets
            activePair_TargetROI = 8.0;
            activePair_MaxDrawdown = 12.0;

            // Sessions
            activePair_BestSessions = "24/7 — Picco volatilita': NY Open (13:00-17:00 GMT), Asia (00:00-08:00 GMT)";

            Log_InitConfig("Preset", "BTC/USD - Crypto Configuration");
            Log_SystemWarning("Crypto", "Verifica LotSize! 0.05 BTC ~= $4000 exposure. Usa 0.001-0.01");
            Log_SystemWarning("Crypto", "Aggiusta Hedge_Distance_Pips, TP, Trigger per crypto");
            break;

        //==============================================================
        // ETH/USD - Ethereum vs USD
        // ⚠️ ATTENZIONE: pip = symbolPoint del broker (può variare)
        // ⚠️ Verifica LotSize in base al prezzo corrente ETH
        //==============================================================
        case PAIR_ETHUSD:
            // Characteristics (valori in "pip sistema" ≈ $0.01 su broker digits=2)
            activePair_Spread = ETHUSD_EstimatedSpread;
            activePair_DailyRange = ETHUSD_DailyRange;
            activePair_ATR_Typical = ETHUSD_ATR_Typical;
            activePair_MinBrokerDistance = 10.0;

            // Recommended Settings
            activePair_RecommendedSpacing = ETHUSD_DefaultSpacing;
            activePair_RecommendedBaseLot = 0.01;

            // Performance Targets
            activePair_TargetROI = 10.0;
            activePair_MaxDrawdown = 12.0;

            // Sessions
            activePair_BestSessions = "24/7 — Picco volatilita': NY Open (13:00-17:00 GMT), Asia (00:00-08:00 GMT)";

            Log_InitConfig("Preset", "ETH/USD - Crypto Configuration");
            Log_SystemWarning("Crypto", "Verifica LotSize! Aggiusta parametri pip per crypto");
            break;

        //==============================================================
        // CUSTOM - User Manual Settings
        //==============================================================
        case PAIR_CUSTOM:
            // Use manual input parameters
            activePair_Spread = Custom_Spread;
            activePair_DailyRange = Custom_DailyRange;
            activePair_ATR_Typical = Custom_ATR_Typical;
            activePair_MinBrokerDistance = 10.0;

            // Use input parameters directly
            activePair_RecommendedSpacing = Custom_DefaultSpacing;
            activePair_RecommendedBaseLot = 0.01;

            // Generic targets
            activePair_TargetROI = 10.0;
            activePair_MaxDrawdown = 12.0;

            activePair_BestSessions = "Verify manually for your pair";

            Log_InitConfig("Preset", "CUSTOM - Manual Configuration");
            Log_SystemWarning("Pair", "Verify all parameters manually");
            break;
    }

    // Log final configuration
    Log_Header("PAIR PRESET SUMMARY");
    Log_KeyValueNum("Spread", activePair_Spread, 1);
    Log_KeyValueNum("Daily Range", activePair_DailyRange, 1);
    Log_KeyValueNum("ATR Typical", activePair_ATR_Typical, 1);
    Log_KeyValueNum("Recommended Spacing", activePair_RecommendedSpacing, 1);
    Log_KeyValueNum("Base Lot", activePair_RecommendedBaseLot, 2);
    Log_KeyValueNum("Target ROI", activePair_TargetROI, 1);
    Log_KeyValueNum("Max Drawdown", activePair_MaxDrawdown, 1);
    Log_KeyValue("Best Sessions", activePair_BestSessions);
    Log_Separator();
}

//+------------------------------------------------------------------+
//| Validate Pair Symbol Match                                       |
//| Ensures selected pair matches chart symbol                       |
//+------------------------------------------------------------------+
bool ValidatePairSymbolMatch() {
    string chartSymbol = _Symbol;
    string expectedSymbol = "";

    switch(InstrumentPreset) {
        case PAIR_EURUSD:
            expectedSymbol = "EURUSD";
            break;
        case PAIR_USDCAD:
            expectedSymbol = "USDCAD";
            break;
        case PAIR_AUDNZD:
            expectedSymbol = "AUDNZD";
            break;
        case PAIR_EURCHF:
            expectedSymbol = "EURCHF";
            break;
        case PAIR_AUDCAD:
            expectedSymbol = "AUDCAD";
            break;
        case PAIR_NZDCAD:
            expectedSymbol = "NZDCAD";
            break;
        case PAIR_EURGBP:
            expectedSymbol = "EURGBP";
            break;
        case PAIR_GBPUSD:
            expectedSymbol = "GBPUSD";
            break;
        case PAIR_USDCHF:
            expectedSymbol = "USDCHF";
            break;
        case PAIR_USDJPY:
            expectedSymbol = "USDJPY";
            break;
        case PAIR_EURJPY:
            expectedSymbol = "EURJPY";
            break;
        case PAIR_AUDUSD:
            expectedSymbol = "AUDUSD";
            break;
        case PAIR_NZDUSD:
            expectedSymbol = "NZDUSD";
            break;
        case PAIR_BTCUSD:
            expectedSymbol = "BTCUSD";
            break;
        case PAIR_ETHUSD:
            expectedSymbol = "ETHUSD";
            break;
        case PAIR_CUSTOM:
            // Custom pair - no validation
            return true;
    }

    // Check if chart symbol contains expected pair
    // Handles broker suffixes like "EURUSDm", "EURUSD.raw", etc.
    if(StringFind(chartSymbol, expectedSymbol) >= 0) {
        Log_Debug("Pair", StringFormat("Chart %s matches %s", chartSymbol, expectedSymbol));
        return true;
    }

    // Mismatch detected
    Log_Header("ERROR: PAIR MISMATCH");
    Log_KeyValue("Selected Pair", expectedSymbol);
    Log_KeyValue("Chart Symbol", chartSymbol);
    Log_KeyValue("Fix Option 1", "Attach EA to " + expectedSymbol);
    Log_KeyValue("Fix Option 2", "Change InstrumentPreset to match chart");
    Log_KeyValue("Fix Option 3", "Use PAIR_CUSTOM for manual config");
    Log_Separator();

    if(EnableAlerts) {
        Alert("CARNEVAL: Pair mismatch! Selected ", expectedSymbol, " but chart is ", chartSymbol);
    }

    return false;
}

//+------------------------------------------------------------------+
//| Get Pair Display Name                                            |
//+------------------------------------------------------------------+
string GetPairDisplayName(ENUM_FOREX_PAIR pair) {
    switch(pair) {
        case PAIR_EURUSD: return "EUR/USD";
        case PAIR_USDCAD: return "USD/CAD";
        case PAIR_AUDNZD: return "AUD/NZD";
        case PAIR_EURCHF: return "EUR/CHF";
        case PAIR_AUDCAD: return "AUD/CAD";
        case PAIR_NZDCAD: return "NZD/CAD";
        case PAIR_EURGBP: return "EUR/GBP";
        case PAIR_GBPUSD: return "GBP/USD";
        case PAIR_USDCHF: return "USD/CHF";
        case PAIR_USDJPY: return "USD/JPY";
        case PAIR_EURJPY: return "EUR/JPY";
        case PAIR_AUDUSD: return "AUD/USD";
        case PAIR_NZDUSD: return "NZD/USD";
        case PAIR_BTCUSD: return "BTC/USD";
        case PAIR_ETHUSD: return "ETH/USD";
        case PAIR_CUSTOM: return "CUSTOM";
        default: return "UNKNOWN";
    }
}

//+------------------------------------------------------------------+
//| Get Pair Risk Level                                              |
//+------------------------------------------------------------------+
string GetPairRiskLevel(ENUM_FOREX_PAIR pair) {
    switch(pair) {
        case PAIR_EURUSD: return "MEDIUM";
        case PAIR_USDCAD: return "MEDIUM";
        case PAIR_AUDNZD: return "LOW";
        case PAIR_EURCHF: return "LOW";
        case PAIR_AUDCAD: return "MEDIUM";
        case PAIR_NZDCAD: return "MEDIUM";
        case PAIR_EURGBP: return "LOW";
        case PAIR_GBPUSD: return "MEDIUM-HIGH";
        case PAIR_USDCHF: return "LOW-MEDIUM";
        case PAIR_USDJPY: return "MEDIUM-HIGH";
        case PAIR_EURJPY: return "MEDIUM-HIGH";
        case PAIR_AUDUSD: return "MEDIUM";
        case PAIR_NZDUSD: return "MEDIUM";
        case PAIR_BTCUSD: return "VERY HIGH";
        case PAIR_ETHUSD: return "HIGH";
        case PAIR_CUSTOM: return "VARIABLE";
        default: return "UNKNOWN";
    }
}

//+------------------------------------------------------------------+
//| Get Pair Recommendation                                          |
//+------------------------------------------------------------------+
string GetPairRecommendation(ENUM_FOREX_PAIR pair) {
    switch(pair) {
        case PAIR_EURUSD:
            return "Good for Soup+Breakout. High liquidity, tight spreads.";
        case PAIR_USDCAD:
            return "Good for Soup cycles. Stable during NY session.";
        case PAIR_AUDNZD:
            return "BEST for range-bound Soup! Tight range, highest win rate.";
        case PAIR_EURCHF:
            return "Good for Soup. Very stable, low volatility.";
        case PAIR_AUDCAD:
            return "Good for Soup+Hedge. Commodity correlation adds stability.";
        case PAIR_NZDCAD:
            return "Similar to AUD/CAD. Good backup pair.";
        case PAIR_EURGBP:
            return "EXCELLENT for Soup! European economies correlate. Tight range.";
        case PAIR_GBPUSD:
            return "Good for mean reversion. Higher volatility - use wider hedge distance.";
        case PAIR_USDCHF:
            return "Good for Soup. Safe haven - stable, beware risk-off events.";
        case PAIR_USDJPY:
            return "Good for Breakout legs. High volatility - ideal for momentum.";
        case PAIR_EURJPY:
            return "Good for Soup+Breakout. Cross major with good liquidity.";
        case PAIR_AUDUSD:
            return "Good for all strategies. Commodity major - correlated with AUD/NZD.";
        case PAIR_NZDUSD:
            return "Good for Soup. Commodity pair - ranges well during Asian session.";
        case PAIR_BTCUSD:
            return "Crypto: alta volatilita'. Usa LotSize piccolo (0.001-0.01). Aggiusta tutti i pip params.";
        case PAIR_ETHUSD:
            return "Crypto: volatilita' media-alta. Usa LotSize adeguato (0.01-0.1). Aggiusta pip params.";
        case PAIR_CUSTOM:
            return "Verify all parameters manually before live trading.";
        default:
            return "Unknown pair";
    }
}
