//+------------------------------------------------------------------+
//|                                      adInputParameters.mqh       |
//|           AcquaDulza EA v1.4.0 — Input Parameters                |
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

input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  ⚙️ SYSTEM CONFIGURATION                                  ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    🔧 CORE SETTINGS"
input bool           EnableSystem           = true;        // ✅ Enable EA
input int            MagicNumber            = 88401;       // 🆔 Magic Number (Unique EA ID)
input int            Slippage               = 3;           // 📏 Slippage (points, auto-scaled per prodotto)
input bool           VirtualMode            = false;       // 🔮 Virtual Mode (paper trading)

input group "    🌐 INSTRUMENT CLASS"
input ENUM_INSTRUMENT_CLASS InstrumentClass = INSTRUMENT_AUTO; // 📋 Prodotto CFD ▼ (Auto = rileva dal simbolo)

//+------------------------------------------------------------------+
//| 2. RISK MANAGEMENT                                               |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  💰 RISK MANAGEMENT                                       ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    📊 POSITION SIZING"
input ENUM_RISK_MODE RiskMode               = RISK_PERCENT;  // 📋 Risk Mode ▼
input double         LotSize                = 0.01;          // 📏 Fixed Lot Size (if FIXED_LOT)
input double         RiskPercent            = 1.0;           // 📊 Risk % Equity (if RISK_PCT)
input double         RiskCashPerTrade       = 50.0;          // 💵 Risk Cash per Trade (if FIXED_CASH)

input group "    📐 SIGNAL QUALITY LOT SIZING"
//  TBS (Turtle Body Soup) = segnale FORTE: il corpo della candela penetra la banda
//  TWS (Turtle Wick Soup) = segnale DEBOLE: solo la shadow/wick tocca la banda
//  Il lotto base viene moltiplicato per questi fattori in base alla qualita' del segnale.
//  Esempio: LotSize=0.01, TBS_mult=2.0, TWS_mult=1.0 → TBS apre 0.02, TWS apre 0.01
input double         TBSLotMultiplier       = 2.0;           // 📈 TBS (segnale forte): moltiplicatore lotti (es. 2.0 = doppio)
input double         TWSLotMultiplier       = 1.0;           // 📉 TWS (segnale debole): moltiplicatore lotti (es. 1.0 = invariato)

input group "    🛡️ RISK LIMITS"
input int            MaxConcurrentTrades    = 3;             // 📊 Max Concurrent Trades
input double         MaxSpreadPips          = 3.0;           // 📏 Max Spread (pip)
input double         DailyLossLimitPct      = 2.0;           // 🛑 Daily Loss Limit (% equity, 0=off)

//+------------------------------------------------------------------+
//| 3. TRADE PARAMETERS                                              |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  📈 TRADE PARAMETERS                                      ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    🎯 ENTRY MODE"
input ENUM_ENTRY_MODE  EntryMode            = ENTRY_STOP;    // 📋 Entry Mode (MARKET/LIMIT/STOP) ▼
input double           LimitOffsetPips      = 2.0;           // 📏 Limit Offset (pip, se LIMIT mode)
input double           StopOffsetPips       = 2.5;           // 📏 Stop Offset from trigger (pip, se STOP mode)
input int              PendingExpiryBars    = 8;             // ⏱️ Expiry Pending (barre, 0=mai)

// [MOD] Rimosso gruppo "STOP LOSS" con i parametri SLMode (ENUM_SL_MODE) e SLValue (double).
// Il calcolo SL era buggato (SL_BAND_OPPOSITE invertiva la direzione) e causava
// il rifiuto di tutti gli ordini pendenti. SL ora disattivato: ordini senza stop loss.

input group "    ✅ TAKE PROFIT"
input ENUM_TP_MODE     TPMode               = TP_MIDLINE;    // 📋 TP Mode ▼
input double           TPValue              = 2.0;           // 📏 TP Value (ATR mult o pip, in base a TPMode)

//+------------------------------------------------------------------+
//| 4. SESSION FILTER                                                |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  ⏰ SESSION FILTER                                        ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    🌍 SESSION WINDOWS"
input bool           EnableSessionFilter    = false;         // ❌ Session Filter OFF (crypto 24/7, Forex tutte le sessioni)
input bool           SessionLondon          = true;          // 🇬🇧 London Session (08:00-16:30 UTC)
input bool           SessionNewYork         = true;          // 🇺🇸 New York Session (13:00-21:00 UTC)
input bool           SessionAsian           = false;         // 🇯🇵 Asian Session (00:00-08:00 UTC)

input group "    🚫 BLOCKED TIME"
input string         BlockedTimeStart       = "00:00";       // ⏱️ Blocked Time Start (HH:MM server)
input string         BlockedTimeEnd         = "00:00";       // ⏱️ Blocked Time End (HH:MM server)

//+------------------------------------------------------------------+
//| 5. MTF DIRECTION FILTER                                          |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  📊 MTF DIRECTION FILTER                                  ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    🔍 HTF SETTINGS"
input bool           UseHTFFilter           = false;         // ✅ Enable HTF Filter
input ENUM_TIMEFRAMES HTFTimeframe          = PERIOD_H1;     // 📋 HTF Timeframe ▼
input int            HTFPeriod              = 20;            // 📊 HTF Donchian Period

//+------------------------------------------------------------------+
//| 6. VISUAL                                                        |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  🎨 VISUAL SETTINGS                                       ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    🖥️ CHART DISPLAY"
input bool           ShowChannelOverlay     = true;          // ✅ Show Channel Overlay on Chart
input bool           ShowSignalArrows       = true;          // ✅ Show Signal Arrows
input bool           ShowTPTargetLines      = true;          // ✅ Show TP Target Lines
input int            OverlayDepth           = 500;           // 📊 Channel Overlay Depth (bars, 0=arrows only)

//+------------------------------------------------------------------+
//| 7. ADVANCED                                                      |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  🔧 ADVANCED SETTINGS                                     ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    💾 AUTO-SAVE & RECOVERY"
input bool           ClearStateOnRemove     = true;          // 🗑️ Clear State when EA Removed
input bool           EnableAutoSave         = true;          // ✅ Enable Auto-Save (GlobalVariables)
input int            AutoSaveIntervalMin    = 5;             // ⏱️ Auto-Save Interval (minutes)
input bool           EnableAutoRecovery     = true;          // ✅ Enable Auto-Recovery on Restart

input group "    📝 LOGGING"
input ENUM_LOG_LEVEL MinLogLevel            = LOG_INFO;      // 📋 Minimum Log Level ▼
input bool           LogToCSVFile           = false;         // 📝 Write Log to CSV File
input int            MaxRetries             = 3;             // 🔄 Max Order Retries
input int            RetryDelayMs           = 500;           // ⏱️ Retry Delay (ms)

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
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  🌊 ENGINE: DONCHIAN CHANNEL                              ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    📐 CHANNEL SETTINGS"
input bool              InpEngineAutoTFPreset  = true;       // ✅ Auto TF Preset (sovrascrive valori sotto)
input int               InpLenDC               = 20;         // 📊 Donchian Period (bars lookback)
input ENUM_TRIGGER_MODE InpTriggerMode         = TRIGGER_BAR_CLOSE; // 📋 Trigger Mode (BAR_CLOSE = anti-repaint) ▼

//+------------------------------------------------------------------+
//| E2. MA FILTER                                                    |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  📉 ENGINE: MA FILTER                                     ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    📊 MA CONFIGURATION"
input ENUM_DPC_MA_TYPE     InpMAType           = DPC_MA_HMA;       // 📋 MA Type ▼ (DPC default: HMA)
input ENUM_MA_FILTER_MODE  InpMAFilterMode     = MA_FILTER_INVERTED; // 📋 MA Filter Mode ▼ (DPC default: Invertito/Soup)
input int                  InpMALen            = 30;                // 📊 MA Period

//+------------------------------------------------------------------+
//| E3. SMART COOLDOWN                                               |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  ❄️ ENGINE: SMART COOLDOWN                                ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    ⏳ COOLDOWN RULES"
input bool           InpUseSmartCooldown    = true;          // ✅ Enable SmartCooldown
input bool           InpRequireMidTouch     = true;          // ✅ Require Midline Touch (same dir)
input int            InpNSameBars           = 2;             // 📊 Same Direction: Wait Bars after Midline
input int            InpNOppositeBars       = 1;             // 📊 Opposite Direction: Min Bars

//+------------------------------------------------------------------+
//| E4. FILTERS                                                      |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  🔬 ENGINE: BAND FILTERS                                  ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    📏 FLATNESS FILTER"
input bool           InpUseBandFlatness     = true;          // ✅ Enable Band Flatness Filter
input double         InpFlatnessTolerance   = 0.85;          // 📏 Flatness Tolerance (ATR mult) — allineato a Carneval
input int            InpFlatLookback        = 2;             // 📊 Flatness Lookback (bars)

input group "    ⏱️ LEVEL AGE FILTER"
input bool           InpUseLevelAge         = false;         // ❌ Level Age OFF (impossibile su M5, bande mai piatte)
input int            InpMinLevelAge         = 3;             // 📊 Min Level Age (flat bars) — attivare solo su H1+

input group "    📈 TREND CONTEXT FILTER"
input bool           InpUseTrendContext     = false;         // ✅ Enable Trend Context Filter
input double         InpTrendContextMult    = 1.5;           // 📏 Trend Context Threshold (ATR mult)

input group "    📐 WIDTH FILTER"
input bool           InpUseWidthFilter      = true;          // ✅ Enable Channel Width Filter
input double         InpMinWidthPips        = 8.0;           // 📏 Min Channel Width (pip)

//+------------------------------------------------------------------+
//| E5. TIME FILTER (DPC Engine interno)                             |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  ⏰ ENGINE: TIME FILTER                                   ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    🚫 BLOCKED TIME WINDOW"
input bool           InpUseTimeFilter       = false;         // ✅ Enable DPC Time Filter
input string         InpTimeBlockStart      = "15:20";       // ⏱️ Block Start (HH:MM server)
input string         InpTimeBlockEnd        = "16:20";       // ⏱️ Block End (HH:MM server)

//+------------------------------------------------------------------+
//| E6. SIGNAL OPTIONS                                               |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  📡 ENGINE: SIGNAL OPTIONS                                ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    🔔 SIGNAL DISPLAY"
input bool           InpShowTWSSignals      = true;          // ✅ Show TWS Signals (weaker)

//+------------------------------------------------------------------+
//| E7. LTF ENTRY SIGNAL                                             |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  🔎 ENGINE: LTF ENTRY SIGNAL                              ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    📉 LTF CONFIRMATION"
input bool           InpUseLTFEntry         = false;         // ✅ Enable LTF Entry Confirmation
input bool           InpLTFOnlyTBS          = true;          // ✅ LTF Only for TBS Signals

//+------------------------------------------------------------------+
//| E8. ATR SETTINGS                                                 |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  📊 ENGINE: ATR SETTINGS                                  ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    📐 ATR CONFIGURATION"
input ENUM_TIMEFRAMES InpATR_Timeframe      = PERIOD_CURRENT; // 📋 ATR Timeframe ▼
input int             InpATR_Period          = 14;             // 📊 ATR Period

//+------------------------------------------------------------------+
//| E9. HEDGE ENGINE                                                 |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  🛡️ HEDGE ENGINE — Protezione breakout su Turtle Soup    ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    ⚙️ HEDGE ACTIVATION"
input bool   EnableHedge             = true;    // ✅ Abilita hedge automatico su ogni Soup
// ↑ Se true: ogni segnale TBS/TWS genera un ordine stop opposto (BUY STOP su SELL Soup,
//   SELL STOP su BUY Soup) piazzato a una distanza calcolata con ATR(14).
//   L'ATR si adatta automaticamente al timeframe corrente — nessuna parametrizzazione manuale.
//   false = sistema identico a v1.3.0, nessun ordine aggiuntivo.

input group "    📐 HEDGE DISTANCE"
input double HedgeATRMult            = 1.0;     // 📏 Distanza trigger hedge (× ATR14)
// ↑ Il BUY/SELL STOP viene piazzato a: banda + HedgeATRMult × ATR(14).
//   Esempio BTCUSD M5: ATR=170pip, mult=1.0 → trigger a +170pip dalla banda.
//   Esempio EURUSD M15: ATR=8pip, mult=1.0 → trigger a +8pip dalla banda.
//   Valori consigliati: 0.5 (aggressivo) | 1.0 (standard) | 2.0 (conservativo).
//   Il valore 1.0 è il livello dove la probabilità di mean-reversion scende sotto 50%.

input group "    🎯 HEDGE TAKE PROFIT"
input double HedgeTPAtrMult          = 2.0;     // 🎯 TP hedge (× ATR14 dal trigger)
// ↑ TP = hedgeTrigger + HedgeTPAtrMult × ATR(14).
//   Ratio R:R = HedgeTPAtrMult / 1.0 ATR (distanza trigger=1×, TP=2× → R:R 2:1).
//   Con HedgeATRMult=1.0 e HedgeTPAtrMult=2.0: SL implicito=1 ATR, TP=2 ATR → R:R 2:1.

input group "    💰 HEDGE LOT SIZE"
input bool   HedgeUseSameLot         = true;    // ✅ Usa stesso lotto della Soup
// ↑ true = hedgeLot = g_cycles[slot].lotSize (TBS=2x, TWS=1x come la Soup).
//   false = usa HedgeLotFixed come lotto fisso indipendente dalla Soup.
input double HedgeLotFixed           = 0.01;    // 📊 Lotto fisso hedge (se HedgeUseSameLot=false)

input group "    🎨 HEDGE VISUAL"
input bool   ShowHedgeLine           = true;    // ✅ Mostra linea fucsia trigger hedge
// ↑ Traccia un segmento tratteggiato fucsia al livello del trigger hedge.
//   La linea dura HedgeLineBarWidth barre poi scompare (se non colpita).
//   Cancellata automaticamente quando la Soup chiude o il trigger viene riempito.
input int    HedgeLineBarWidth       = 6;       // 📏 Durata linea fucsia (barre)
// ↑ Quante barre dura la visualizzazione del livello hedge sul grafico.
//   Valore consigliato: 5-8 barre. Non influenza il comportamento dell'ordine.
