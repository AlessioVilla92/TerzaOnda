//+------------------------------------------------------------------+
//|                                      adInputParameters.mqh       |
//|           AcquaDulza EA v1.0.0 — Input Parameters                |
//|                                                                  |
//|  Sezione FRAMEWORK: parametri stabili (non cambiano con engine)  |
//|  Sezione ENGINE:    parametri DPC-specifici (da sostituire)       |
//+------------------------------------------------------------------+
#property copyright "AcquaDulza (C) 2026"

#include "adVisualTheme.mqh"

//+------------------------------------------------------------------+
//|                                                                  |
//|  ╔═════════════════════════════════════════════════════════════╗  |
//|  ║          === FRAMEWORK INPUTS ===                           ║  |
//|  ║  Questi parametri NON cambiano quando si swappa engine      ║  |
//|  ╚═════════════════════════════════════════════════════════════╝  |
//|                                                                  |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| 1. SYSTEM CONFIGURATION                                          |
//+------------------------------------------------------------------+

input group "                                                           "
input group "   SYSTEM CONFIGURATION"
input group "                                                           "

input bool           EnableSystem           = true;        // Enable EA
input int            MagicNumber            = 88401;       // Magic Number
input int            Slippage               = 3;           // Slippage (points)
input bool           VirtualMode            = false;       // Virtual Mode (paper trading)

//+------------------------------------------------------------------+
//| 2. RISK MANAGEMENT                                               |
//+------------------------------------------------------------------+

input group "                                                           "
input group "   RISK MANAGEMENT"
input group "                                                           "

input ENUM_RISK_MODE RiskMode               = RISK_PERCENT;  // Risk Mode
input double         LotSize                = 0.01;          // Fixed Lot Size (if FIXED_LOT)
input double         RiskPercent            = 1.0;           // Risk % Equity (if RISK_PCT)
input double         RiskCashPerTrade       = 50.0;          // Risk Cash per Trade (if FIXED_CASH)
input int            MaxConcurrentTrades    = 3;             // Max Concurrent Trades
input double         MaxSpreadPips          = 3.0;           // Max Spread (pip)
input double         DailyLossLimitPct      = 2.0;           // Daily Loss Limit (% equity, 0=off)

//+------------------------------------------------------------------+
//| 3. TRADE PARAMETERS                                              |
//+------------------------------------------------------------------+

input group "                                                           "
input group "   TRADE PARAMETERS"
input group "                                                           "

input ENUM_ENTRY_MODE  EntryMode            = ENTRY_STOP;    // Entry Mode (MARKET/LIMIT/STOP)
input double           LimitOffsetPips      = 2.0;           // Limit Offset (pip, se LIMIT mode)
input double           StopOffsetPips       = 2.5;           // Stop Offset from trigger (pip, se STOP mode)
input int              PendingExpiryBars    = 8;             // Expiry Pending (barre, 0=mai)

input group "   STOP LOSS"
input ENUM_SL_MODE     SLMode               = SL_BAND_OPPOSITE; // SL Mode
input double           SLValue              = 1.5;           // SL Value (ATR mult o pip, in base a SLMode)

input group "   TAKE PROFIT"
input ENUM_TP_MODE     TPMode               = TP_MIDLINE;    // TP Mode
input double           TPValue              = 2.0;           // TP Value (ATR mult o pip, in base a TPMode)

//+------------------------------------------------------------------+
//| 4. SESSION FILTER                                                |
//+------------------------------------------------------------------+

input group "                                                           "
input group "   SESSION FILTER"
input group "                                                           "

input bool           EnableSessionFilter    = true;          // Enable Session Filter
input bool           SessionLondon          = true;          // London Session (08:00-16:30 UTC)
input bool           SessionNewYork         = true;          // New York Session (13:00-21:00 UTC)
input bool           SessionAsian           = false;         // Asian Session (00:00-08:00 UTC)
input string         BlockedTimeStart       = "00:00";       // Blocked Time Start (HH:MM server)
input string         BlockedTimeEnd         = "00:00";       // Blocked Time End (HH:MM server)

//+------------------------------------------------------------------+
//| 5. MTF DIRECTION FILTER                                          |
//+------------------------------------------------------------------+

input group "                                                           "
input group "   MTF DIRECTION FILTER"
input group "                                                           "

input bool           UseHTFFilter           = false;         // Enable HTF Filter
input ENUM_TIMEFRAMES HTFTimeframe          = PERIOD_H1;     // HTF Timeframe
input int            HTFPeriod              = 20;            // HTF Donchian Period

//+------------------------------------------------------------------+
//| 6. VISUAL                                                        |
//+------------------------------------------------------------------+

input group "                                                           "
input group "   VISUAL"
input group "                                                           "

input bool           ShowChannelOverlay     = true;          // Show Channel Overlay on Chart
input bool           ShowSignalArrows       = true;          // Show Signal Arrows
input bool           ShowTPTargetLines      = true;          // Show TP Target Lines
input int            OverlayDepth           = 100;           // Channel Overlay Depth (bars, 0=arrows only)

//+------------------------------------------------------------------+
//| 7. ADVANCED                                                      |
//+------------------------------------------------------------------+

input group "                                                           "
input group "   ADVANCED"
input group "                                                           "

input bool           ClearStateOnRemove     = true;          // Clear State when EA Removed
input bool           EnableAutoSave         = true;          // Enable Auto-Save (GlobalVariables)
input int            AutoSaveIntervalMin    = 5;             // Auto-Save Interval (minutes)
input bool           EnableAutoRecovery     = true;          // Enable Auto-Recovery on Restart

input group "   LOGGING"
input ENUM_LOG_LEVEL MinLogLevel            = LOG_INFO;      // Minimum Log Level
input bool           LogToCSVFile           = false;         // Write Log to CSV File
input int            MaxRetries             = 3;             // Max Order Retries
input int            RetryDelayMs           = 500;           // Retry Delay (ms)

//+------------------------------------------------------------------+
//|                                                                  |
//|  ╔═════════════════════════════════════════════════════════════╗  |
//|  ║          === ENGINE INPUTS (DPC) ===                        ║  |
//|  ║  Questi parametri sono specifici del DPC Engine.            ║  |
//|  ║  Quando si swappa engine, sostituire SOLO questo blocco.    ║  |
//|  ╚═════════════════════════════════════════════════════════════╝  |
//|                                                                  |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| E1. DONCHIAN CHANNEL                                             |
//+------------------------------------------------------------------+

input group "                                                           "
input group "   ENGINE: DONCHIAN CHANNEL"
input group "                                                           "

input bool              InpEngineAutoTFPreset  = true;       // Auto TF Preset (sovrascrive valori sotto)
input int               InpLenDC               = 20;         // Donchian Period (bars lookback)
input ENUM_TRIGGER_MODE InpTriggerMode         = TRIGGER_BAR_CLOSE; // Trigger Mode (BAR_CLOSE = anti-repaint)

//+------------------------------------------------------------------+
//| E2. MA FILTER                                                    |
//+------------------------------------------------------------------+

input group "   ENGINE: MA FILTER"

input ENUM_DPC_MA_TYPE     InpMAType           = DPC_MA_EMA;       // MA Type
input ENUM_MA_FILTER_MODE  InpMAFilterMode     = MA_FILTER_DISABLED; // MA Filter Mode
input int                  InpMALen            = 30;                // MA Period

//+------------------------------------------------------------------+
//| E3. SMART COOLDOWN                                               |
//+------------------------------------------------------------------+

input group "   ENGINE: SMART COOLDOWN"

input bool           InpUseSmartCooldown    = true;          // Enable SmartCooldown
input bool           InpRequireMidTouch     = true;          // Require Midline Touch (same dir)
input int            InpNSameBars           = 3;             // Same Direction: Wait Bars after Midline
input int            InpNOppositeBars       = 2;             // Opposite Direction: Min Bars

//+------------------------------------------------------------------+
//| E4. FILTERS                                                      |
//+------------------------------------------------------------------+

input group "   ENGINE: BAND FILTERS"

input bool           InpUseBandFlatness     = true;          // Enable Band Flatness Filter
input double         InpFlatnessTolerance   = 0.55;          // Flatness Tolerance (ATR mult)
input int            InpFlatLookback        = 3;             // Flatness Lookback (bars)

input bool           InpUseLevelAge         = true;          // Enable Level Age Filter
input int            InpMinLevelAge         = 3;             // Min Level Age (flat bars)

input bool           InpUseTrendContext     = false;         // Enable Trend Context Filter
input double         InpTrendContextMult    = 1.5;           // Trend Context Threshold (ATR mult)

input bool           InpUseWidthFilter      = true;          // Enable Channel Width Filter
input double         InpMinWidthPips        = 8.0;           // Min Channel Width (pip)

//+------------------------------------------------------------------+
//| E5. TIME FILTER (DPC Engine interno)                             |
//+------------------------------------------------------------------+

input group "   ENGINE: TIME FILTER"

input bool           InpUseTimeFilter       = false;         // Enable DPC Time Filter
input string         InpTimeBlockStart      = "15:20";       // Block Start (HH:MM server)
input string         InpTimeBlockEnd        = "16:20";       // Block End (HH:MM server)

//+------------------------------------------------------------------+
//| E6. SIGNAL OPTIONS                                               |
//+------------------------------------------------------------------+

input group "   ENGINE: SIGNAL OPTIONS"

input bool           InpShowTWSSignals      = true;          // Show TWS Signals (weaker)

//+------------------------------------------------------------------+
//| E7. LTF ENTRY SIGNAL                                             |
//+------------------------------------------------------------------+

input group "   ENGINE: LTF ENTRY SIGNAL"

input bool           InpUseLTFEntry         = false;         // Enable LTF Entry Confirmation
input bool           InpLTFOnlyTBS          = true;          // LTF Only for TBS Signals

//+------------------------------------------------------------------+
//| E8. ATR SETTINGS                                                 |
//+------------------------------------------------------------------+

input group "   ENGINE: ATR"

input ENUM_TIMEFRAMES InpATR_Timeframe      = PERIOD_CURRENT; // ATR Timeframe
input int             InpATR_Period          = 14;             // ATR Period
