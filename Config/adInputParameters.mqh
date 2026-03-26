//+------------------------------------------------------------------+
//|                                      adInputParameters.mqh       |
//|           AcquaDulza EA v1.6.1 — Input Parameters                |
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
//| E9. HEDGING — Two-Tier Hedge System                              |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  🛡️ HEDGING — Protezione Two-Tier su Turtle Soup        ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    ⚙️ ATTIVAZIONE"
input bool   EnableHedge             = true;    // ✅ Master switch: abilita sistema hedge
// ↑ Se true: ogni segnale TBS/TWS puo' generare fino a 2 ordini stop opposti.
//   H1 (Recovery) = incassa profitto dal dip, NON chiude la Soup.
//   H2 (Protezione) = chiude la Soup al raggiungimento del suo TP.
//   false = nessun hedge, sistema identico a v1.3.0.

input group "    📐 HEDGE 1 — Recovery (non chiude Soup)"
input bool   Hedge1Enabled           = false;   // ✅ Abilita Hedge 1 (default OFF)
// ↑ H1 piazzato piu' vicino alla banda. Quando il suo TP viene colpito,
//   il profitto viene incassato ma la Soup resta aperta per recuperare alla midline.
input double Hedge1ATRMult           = 1.0;     // 📏 Trigger: banda ± X × ATR(14)
// ↑ Distanza del trigger H1 dalla banda Donchian.
//   Valori: 0.5 (aggressivo) | 1.0 (standard) | 2.0 (conservativo)
input double Hedge1TPAtrMult         = 2.0;     // 🎯 TP: trigger ± X × ATR(14)
// ↑ TP del H1 calcolato dal trigger. Con ATRMult=1.0, TPMult=2.0: R:R = 2:1
input bool   Hedge1UseSameLot        = true;    // ✅ Usa lotto Soup (TBS=2x, TWS=1x)
input double Hedge1LotFixed          = 0.01;    // 📊 Lotto fisso H1 (se UseSameLot=false)

input group "    📐 HEDGE 2 — Protezione (chiude Soup al TP)"
input bool   Hedge2Enabled           = true;    // ✅ Abilita Hedge 2
// ↑ H2 piazzato piu' lontano dalla banda. Quando il suo TP viene colpito,
//   CHIUDE la Soup. Trigger consigliato: >= H1 trigger + H1 TP (default: 3.0).
input double Hedge2ATRMult           = 3.0;     // 📏 Trigger: banda ± X × ATR(14)
// ↑ Con default 3.0 e H1 default (1.0+2.0=3.0): H2 trigger = H1 TP level.
//   Questo crea un "passaggio di consegne" pulito tra H1 e H2.
input double Hedge2TPAtrMult         = 3.0;     // 🎯 TP: trigger ± X × ATR(14)
// ↑ TP del H2. Con lotto 1.5x e questi default: NET breakout = +0.5×ATR
input double Hedge2LotRatio          = 1.5;     // 📊 Lotto: X × lotto Soup
// ↑ 1.5 = 150% del lotto Soup. Compensa il gap matematico entry→trigger.
//   Valori: 1.0 (breakeven) | 1.5 (standard) | 2.0 (aggressivo)
input bool   Hedge2BreakevenSL       = true;    // 🛡️ SL breakeven dopo fill
// ↑ Dopo il fill di H2, imposta SL al prezzo di entry + buffer minimo broker.
//   Se il prezzo reversa, H2 si chiude a ~zero perdita.

input group "    🎨 VISUALIZZAZIONE HEDGE"
input bool   ShowHedgeLine           = true;    // ✅ Linea tratteggiata fucsia (trigger H1)
input bool   ShowHedge2Line          = true;    // ✅ Linea tratteggiata arancione (trigger H2)
input int    HedgeLineBarWidth       = 6;       // 📏 Durata linee trigger (barre)
input bool   ShowHedgeZone           = true;    // ✅ Zone continue fucsia (canale H1)
input bool   ShowHedge2Zone          = true;    // ✅ Zone continue arancioni (canale H2)
