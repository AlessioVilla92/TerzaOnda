//+------------------------------------------------------------------+
//|                                        carnInputParameters.mqh   |
//|           Carneval EA v3.40 - Input Parameters                    |
//|                                                                  |
//|  Parametri configurabili da pannello Strategy Tester / Properties |
//|  Turtle Soup + Breakout Hedge + Trigger Mode + DPC Engine         |
//+------------------------------------------------------------------+
#property copyright "Sugamara Ribelle (C) 2026"

#include "carnVisualTheme.mqh"

//+------------------------------------------------------------------+
//| 1. SYSTEM CONFIGURATION                                          |
//+------------------------------------------------------------------+

input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  ⚙️ SYSTEM CONFIGURATION                                  ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    🔧 CORE SETTINGS"
input bool    EnableSystem           = true;              // ✅ Abilita EA
input int     MagicNumber            = 20260216;          // 🆔 Magic Soup (Breakout = Magic+1)
input int     Slippage               = 30;                // 📊 Slippage (points)

input group "    ╔═ SELEZIONA STRUMENTO ══════════════════════════════════🔽🔽🔽"
input ENUM_FOREX_PAIR InstrumentPreset = PAIR_EURUSD;     // 📋 Preset Strumento ▼

input group "    💵 LOT SIZE (valido per tutte le strategie)"
input double  LotSize                = 0.02;             // 💵 Lotto Operazioni (Soup, Breakout, Trigger)

//+------------------------------------------------------------------+
//| 2. TRADING MODE                                                  |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  🎭 TRADING MODE                                          ║"
input group "║      Classic Turtle Soup / Trigger Indicator              ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    ╔═ SELEZIONA MODALITA' ═══════════════════════════════════🔽🔽🔽"
input ENUM_TRADING_MODE TradingMode    = MODE_TRIGGER_INDICATOR; // 🎭 Modalita' Trading ▼

input group "    🎯 TRIGGER INDICATOR SETTINGS"
input double  Trigger_Offset_Pips      = 2.5;                // 📏 Offset STOP da trigger (pips) [min consigliato: 2.0p]
input int     Trigger_Expiry_Bars      = 8;                  // ⏳ Scadenza STOP pending (barre, 0=mai)

input group "    🛡️ STOP LOSS (Trigger Mode)"
input bool    Trigger_UseSL            = false;              // 🛡️ Abilita Stop Loss (RACCOMANDATO)
input ENUM_TRIGGER_SL_MODE Trigger_SL_Mode = TRIGGER_SL_OPPOSITE_BAND;  // 🎯 Modalita' SL ▼
// OPPOSITE_BAND   = SL alla banda opposta (es. BUY: SL a upper + spread)
// ATR_MULTIPLE    = SL = N x ATR(14) dalla entry
// FIXED_PIPS      = SL fisso in pip
input double  Trigger_SL_ATR_Multiple  = 1.5;               // 📊 SL come multiplo ATR (se ATR_MULTIPLE)
input double  Trigger_SL_Fixed_Pips    = 15.0;              // 📏 SL fisso in pips (se FIXED_PIPS)

//+------------------------------------------------------------------+
//| 3. SIGNAL FILTERS                                                |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  🔍 SIGNAL FILTERS                                        ║"
input group "║      Filtraggio segnali DPC prima del piazzamento ordine  ║"
input group "╚═══════════════════════════════════════════════════════════╝"

// NOTA: Il filtro larghezza canale e' gestito SOLO dal DPC Engine (DPC_UseWidthFilter + DPC_MinWidthPips_Int)
// per evitare duplicazioni e disallineamento parametri.

// NOTA: Il cooldown tra segnali e' gestito SOLO dal DPC Engine (SmartCooldown)
// per evitare doppio filtraggio. Rimosso Filter_SignalCooldown in v3.3.

input group "    📡 SPREAD FILTER"
input bool    Filter_Spread_Enable       = true;             // 📡 Blocca segnali con spread elevato
input double  Filter_MaxSpreadPips       = 2.5;              // 📡 Spread massimo ammesso (pip)
// Su GBPUSD M5: spread normale 1-2p, spike a news fino a 10p+
// Raccomandato: 2.5-3.0p per GBPUSD | 2.0p per EURUSD

input group "    📈 ADX FILTER (conferma forza trend)"
input bool    Filter_ADX_Enable          = false;            // 📈 Abilita Filtro ADX
input int     Filter_ADX_Period          = 14;               // 📊 ADX Period (default: 14)
input double  Filter_ADX_MinLevel        = 15.0;             // 📊 ADX minimo per segnale valido (evita ranging)
input double  Filter_ADX_MaxLevel        = 30.0;             // 📊 ADX massimo per Turtle Soup (sopra = trend troppo forte per reversal)
// Logica: ADX < MinLevel -> mercato flat (segnale Soup debole)
//         ADX > MaxLevel -> trend troppo forte (Soup contro-tendenza rischioso)
//         MinLevel <= ADX <= MaxLevel -> zona ottimale Turtle Soup

//+------------------------------------------------------------------+
//| 4. TAKE PROFIT MODE                                              |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  🎯 TAKE PROFIT MODE                                      ║"
input group "║      Modalita' calcolo TP per Trigger Mode                ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    ╔═ SELEZIONA TP MODE ═════════════════════════════════════🔽🔽🔽"
input ENUM_TRIGGER_TP_MODE Trigger_TP_Mode = TRIGGER_TP_MIDLINE; // 🎯 Modalita' TP Trigger ▼
// MIDLINE        = TP alla linea centrale Donchian (bilanciato, consigliato)
// OPPOSITE_BAND  = TP alla banda opposta del canale (target piu' alto, piu' rischio)
// OPPOSITE_TRIGGER= TP al trigger opposto (massimo rendimento, usare con canali >15p)

// TP posizionato esattamente al livello calcolato (midline, banda opposta, o trigger opposto)

//+------------------------------------------------------------------+
//| 5. DPC ENGINE — Motore Segnali Interno                           |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  🔮 DPC ENGINE — MOTORE SEGNALI INTERNO                   ║"
input group "║      Calcolo diretto Donchian + 8 filtri + SmartCooldown  ║"
input group "║      Modifica questi parametri per controllare i segnali  ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    📊 DONCHIAN CHANNEL"
input int              DPC_Period         = 20;            // 📈 Periodo Donchian (barre lookback)
input bool             DPC_SignalFilter   = true;          // 🛡️ Filtra Segnali con MA

input group "    ╔═ SELEZIONA FILTRO MA ═══════════════════════════════════🔽🔽🔽"
input ENUM_MA_FILTER_MODE DPC_MAFilterMode = MA_FILTER_INVERTED; // 🔄 Modalita' Filtro MA ▼
input group "    ╔═ SELEZIONA TIPO MA ═════════════════════════════════════🔽🔽🔽"
input ENUM_DPC_MA_TYPE DPC_MAType         = DPC_MA_HMA;   // 📊 Tipo MA ▼
input int              DPC_MALength       = 30;            // 📏 Periodo MA

input group "    ⚡ SMARTCOOLDOWN (filtro frequenza segnali)"
input bool             DPC_UseSmartCooldown   = true;      // ⚡ SmartCooldown (OFF=cooldown fisso Zeiierman)
input bool             DPC_RequireMidTouch    = true;      // 🎯 Stesso Verso: Richiedi Tocco Midline
input int              DPC_SameDirBars        = 2;         // 🎯 Stesso Verso: Barre Attesa dopo Midline (1-10)
input int              DPC_OppositeDirBars    = 1;         // ↔️ Direzione Opposta: Barre Minime (1-10)

input group "    📊 BAND FLATNESS (stabilita' livello)"
input bool             DPC_UseBandFlatness    = true;      // 📊 Abilita Band Flatness Filter
input double           DPC_FlatnessTolerance  = 0.85;      // 📊 Tolleranza espansione (multiplo ATR)
input int              DPC_FlatLookback       = 2;         // 📊 Lookback barre filtro (1-10)

input group "    ⏳ LEVEL AGE (maturita' livello — Regola Raschke)"
input bool             DPC_UseLevelAge        = false;     // ⏳ Abilita Level Age Filter
input int              DPC_MinLevelAge        = 3;         // ⏳ Barre minime banda piatta (1-10)

input group "    📉 TREND CONTEXT (filtro macro-trend)"
input bool             DPC_UseTrendContext      = false;   // 📉 Abilita Trend Context Filter
input double           DPC_TrendContextMultiple = 1.5;     // 📉 Soglia (multiplo ATR)

input group "    📏 CHANNEL WIDTH (larghezza minima canale)"
input bool             DPC_UseWidthFilter     = true;      // 📏 Abilita Channel Width Filter
input double           DPC_MinWidthPips_Int   = 8.0;       // 📏 Larghezza minima canale (pip)

input group "    🕐 FILTRO ORARIO (blocco fasce orarie)"
input bool             DPC_UseTimeFilter      = false;     // 🕐 Abilita Filtro Orario
input string           DPC_TimeBlockStart     = "15:20";   // 🕐 Inizio Blocco (ora locale HH:MM)
input string           DPC_TimeBlockEnd       = "16:20";   // 🕐 Fine Blocco (ora locale HH:MM)
input int              DPC_BrokerOffset       = 1;         // 🕐 Offset Broker da locale (ore)

// NOTA: DPC_ArrowOffsetMult rimosso in v3.3 (dead code).
// Il trigger offset usa Trigger_Offset_Pips (sezione TRIGGER INDICATOR SETTINGS).

input group "    🎨 DPC OVERLAY"
input bool             ShowDPCOverlay     = true;          // 🎨 Mostra Canale DPC sul grafico
input int              DPC_OverlayDepth   = 100;           // 📏 Barre storiche canale (0=solo frecce)

//+------------------------------------------------------------------+
//| 6. TURTLE SOUP — Mean Reversion Strategy                         |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  🍲 TURTLE SOUP — MEAN REVERSION                         ║"
input group "║      Entry Market al segnale DPC, TP = Midline           ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    🎯 TARGET"
input double  Soup_TP_Buffer_Pips     = 0.0;              // 🎯 Buffer TP da midline (0=esatta)

//+------------------------------------------------------------------+
//| 7. BREAKOUT — Hedge Protection                                   |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  🛡️ BREAKOUT — HEDGE PROTECTION                           ║"
input group "║      Ordine STOP pendente opposto alla Soup               ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    📏 DISTANZA & TP"
input double  Hedge_Distance_Pips     = 2.0;              // 📏 Distanza dalla banda DC (pips)

input group "    ╔═ SELEZIONA TP MODE ═════════════════════════════════════🔽🔽🔽"
input ENUM_BKO_TP_MODE Breakout_TP_Mode = BKO_TP_PIPS;   // 🎯 Tipo TP Breakout ▼
input double  Breakout_TP_Pips        = 30.0;             // 📏 TP Breakout in pips
input double  Breakout_TP_ATR         = 1.5;              // 📊 TP Breakout in xATR (se modo ATR)

//+------------------------------------------------------------------+
//| 8. HEDGING MANAGEMENT                                            |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  🔄 HEDGING MANAGEMENT                                    ║"
input group "║      Risoluzione cicli Soup + Breakout                    ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    ╔═ SELEZIONA RISOLUZIONE ═════════════════════════════════🔽🔽🔽"
input ENUM_HEDGE_RESOLUTION Hedge_Resolution_Mode = HEDGE_NET_PROFIT; // 🔄 Modalita' risoluzione ▼
input double  Hedge_NetProfit_Pips    = 5.0;              // 💰 Chiudi hedge a net profit (pips, 0=off)

input group "    🔢 LIMITI CICLI"
input int     Max_ConcurrentCycles    = 5;                // 🔢 Max cicli contemporanei
input int     Max_DailyCycles         = 8;                // 📅 [v3.4] Max cicli per giorno (0=illimitato)
input int     Max_TotalHedgeCycles    = 10;               // 🚨 Circuit breaker globale

//+------------------------------------------------------------------+
//| 9. SESSION FILTER                                                |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  ⏰ SESSION FILTER                                        ║"
input group "║      Orari operativi e azioni fine sessione               ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    ⏰ ORARI SESSIONE"
input bool    EnableSessionFilter     = false;             // ❌ Filtro sessione disabilitato
input string  SessionStart_UTC        = "06:00";           // 🕘 Inizio sessione (UTC)
input string  SessionEnd_UTC          = "22:00";           // 🕔 Fine sessione (UTC)

input group "    🔒 AZIONI FINE SESSIONE"
input bool    CloseHedgedAtSessionEnd = false;             // ❌ Chiudi hedged a fine sessione
input bool    CloseSingleAtSessionEnd = true;              // ✅ Chiudi Soup singole a fine sessione

//+------------------------------------------------------------------+
//| 10. VIRTUAL ORDERS (Reserved)                                    |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  🔮 VIRTUAL ORDERS (Reserved for Future)                  ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    🔮 VIRTUAL"
input bool    Use_VirtualOrders       = false;             // ❌ Virtual Orders (futuro)

//+------------------------------------------------------------------+
//| 11. ATR SETTINGS                                                 |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  📊 ATR SETTINGS                                          ║"
input group "║      Volatilita' e monitoraggio ATR                       ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    ⚡ ATR ACTIVATION"
input bool    UseATR                  = true;              // ✅ Usa ATR

input group "    ╔═ SELEZIONA TIMEFRAME ATR ═══════════════════════════════🔽🔽🔽"
input ENUM_TIMEFRAMES ATR_Timeframe   = PERIOD_H4;        // 📊 ATR Timeframe ▼
input int     ATR_Period              = 14;                // 📈 Periodo ATR

//+------------------------------------------------------------------+
//| 12. LOGGING & DEBUG                                              |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  📝 LOGGING & DEBUG                                       ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    📝 LOG SETTINGS"
input ENUM_LOG_LEVEL MinLogLevel     = LOG_INFO;           // 📊 Livello minimo log (DEBUG=tutto, INFO=standard)
input bool    DetailedLogging         = true;              // 📝 Log dettagliato (abilita LOG_DEBUG)
input bool    LogDPCBuffers           = true;              // 🔮 Log valori DPC Engine (bande, trigger, trend)
input bool    LogOrderExecution       = true;              // 📋 Log esecuzione ordini
input bool    LogHedgeStatus          = true;              // 🔄 Log stato hedging
input bool    LogToCSVFile            = false;             // 💾 Scrivi log su file CSV (con header)
input bool    EnableAlerts            = true;              // 🔔 Abilita Alert popup

input group "    🔧 BROKER EXECUTION"
input int     MaxRetries              = 3;                 // 🔄 Max tentativi per ordine
input int     RetryDelay_ms           = 500;               // ⏱️ Delay tra tentativi (ms)

//+------------------------------------------------------------------+
//| 13. DEBUG MODE                                                   |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  🐛 DEBUG MODE — Backtest Automation                      ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    🐛 DEBUG SETTINGS"
input bool    EnableDebugMode         = false;             // 🐛 Enable Debug Mode
input bool    DebugImmediateEntry     = true;              // ⚡ Immediate Entry (First Tick)
input string  DebugEntryTime          = "09:30";           // 🕘 Entry Time (HH:MM)
input string  DebugCloseTime          = "";                // 🕔 Close Time (HH:MM, vuoto=no close)

//+------------------------------------------------------------------+
//| 14. AUTO-SAVE & RECOVERY                                         |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  💾 AUTO-SAVE & RECOVERY SYSTEM                           ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    💾 AUTO-SAVE SETTINGS"
input bool    Enable_AutoSave         = true;              // ✅ Enable Auto-Save
input int     AutoSave_Interval_Minutes = 5;               // ⏱️ Intervallo Backup (minuti)

input group "    🔄 RECOVERY SETTINGS"
input bool    Enable_AutoRecovery     = true;              // ✅ Enable Auto-Recovery
input bool    ClearStateOnRemove      = true;              // 🗑️ Cancella Stato quando EA rimosso

//+------------------------------------------------------------------+
//|                                                                  |
//| ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓  |
//|                                                                  |
//|     💱💱💱  FOREX PAIR SETTINGS  💱💱💱                          |
//|         Impostazioni Specifiche per Pair                          |
//|                                                                  |
//| ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓  |
//|                                                                  |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| 15. CUSTOM PAIR SETTINGS                                         |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  ⚙️ CUSTOM PAIR SETTINGS (if CUSTOM selected)             ║"
input group "║      Spacing: 10 pips (default) - configurabile           ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    📐 CUSTOM PAIR PARAMETERS"
input double  Custom_Spread            = 2.0;               // 📊 Spread tipico (pips)
input double  Custom_DailyRange        = 70.0;              // 📈 Daily range (pips)
input double  Custom_ATR_Typical       = 10.0;              // 📊 ATR tipico H4 (pips)
input double  Custom_DefaultSpacing    = 10.0;              // 📏 Spacing default (pips)

//+------------------------------------------------------------------+
//| PAIR-SPECIFIC CONSTANTS (per PairPresets)                         |
//+------------------------------------------------------------------+

// 🇪🇺🇺🇸 EUR/USD — Spread: 0.8-1.5 | Range: 60-100 pips
#define EURUSD_DefaultSpacing    10.0
#define EURUSD_EstimatedSpread   1.2
#define EURUSD_DailyRange        80.0
#define EURUSD_ATR_Typical       12.0

// 🇺🇸🇨🇦 USD/CAD — Spread: 1.0-1.8 | Range: 50-80 pips
#define USDCAD_DefaultSpacing    10.0
#define USDCAD_EstimatedSpread   1.5
#define USDCAD_DailyRange        70.0
#define USDCAD_ATR_Typical       10.0

// 🇦🇺🇳🇿 AUD/NZD — Spread: 2-4 | Range: 40-70 pips — BEST RANGE
#define AUDNZD_DefaultSpacing    8.0
#define AUDNZD_EstimatedSpread   3.0
#define AUDNZD_DailyRange        50.0
#define AUDNZD_ATR_Typical       8.0

// 🇪🇺🇨🇭 EUR/CHF — Spread: 1.5-2.5 | Range: 35-60 pips
#define EURCHF_DefaultSpacing    8.0
#define EURCHF_EstimatedSpread   2.0
#define EURCHF_DailyRange        45.0
#define EURCHF_ATR_Typical       7.0

// 🇦🇺🇨🇦 AUD/CAD — Spread: 2-3 | Range: 50-80 pips
#define AUDCAD_DefaultSpacing    10.0
#define AUDCAD_EstimatedSpread   2.5
#define AUDCAD_DailyRange        60.0
#define AUDCAD_ATR_Typical       10.0

// 🇳🇿🇨🇦 NZD/CAD — Spread: 2-3 | Range: 45-75 pips
#define NZDCAD_DefaultSpacing    10.0
#define NZDCAD_EstimatedSpread   2.5
#define NZDCAD_DailyRange        55.0
#define NZDCAD_ATR_Typical       9.0

// 🇪🇺🇬🇧 EUR/GBP — Spread: 1-2 | Range: 40-70 pips — EXCELLENT
#define EURGBP_DefaultSpacing    8.0
#define EURGBP_EstimatedSpread   1.5
#define EURGBP_DailyRange        50.0
#define EURGBP_ATR_Typical       7.0

// 🇬🇧🇺🇸 GBP/USD — Spread: 1-2 | Range: 80-120 pips
#define GBPUSD_DefaultSpacing    12.0
#define GBPUSD_EstimatedSpread   1.5
#define GBPUSD_DailyRange        100.0
#define GBPUSD_ATR_Typical       15.0

// 🇺🇸🇨🇭 USD/CHF — Spread: 1-2 | Range: 50-70 pips
#define USDCHF_DefaultSpacing    10.0
#define USDCHF_EstimatedSpread   1.5
#define USDCHF_DailyRange        60.0
#define USDCHF_ATR_Typical       10.0

// 🇺🇸🇯🇵 USD/JPY — Spread: 0.8-1.5 | Range: 70-120 pips
#define USDJPY_DefaultSpacing    12.0
#define USDJPY_EstimatedSpread   1.2
#define USDJPY_DailyRange        90.0
#define USDJPY_ATR_Typical       14.0

// 🇪🇺🇯🇵 EUR/JPY — Spread: 1.0-1.8 | Range: 80-120 pips
#define EURJPY_DefaultSpacing    12.0
#define EURJPY_EstimatedSpread   1.5
#define EURJPY_DailyRange        100.0
#define EURJPY_ATR_Typical       15.0

// 🇦🇺🇺🇸 AUD/USD — Spread: 0.8-1.5 | Range: 60-90 pips
#define AUDUSD_DefaultSpacing    10.0
#define AUDUSD_EstimatedSpread   1.2
#define AUDUSD_DailyRange        70.0
#define AUDUSD_ATR_Typical       11.0

// 🇳🇿🇺🇸 NZD/USD — Spread: 1.2-2.0 | Range: 50-80 pips
#define NZDUSD_DefaultSpacing    10.0
#define NZDUSD_EstimatedSpread   1.8
#define NZDUSD_DailyRange        60.0
#define NZDUSD_ATR_Typical       10.0

// ₿ BTC/USD — Valori in USD (1 pip ≈ $1 su broker con digits=0-1, ≈ $0.01 con digits=2)
// ⚠️ IMPORTANTE: usare LotSize molto piccolo per crypto (es. 0.001-0.01 BTC)
#define BTCUSD_DefaultSpacing    300.0   // ~$300 spacing raccomandato
#define BTCUSD_EstimatedSpread   30.0    // ~$30 spread tipico
#define BTCUSD_DailyRange        2000.0  // ~$2000 range giornaliero tipico
#define BTCUSD_ATR_Typical       400.0   // ~$400 ATR H4 tipico

// Ξ ETH/USD — Valori in USD (1 pip ≈ $0.01 su broker con digits=2)
// ⚠️ IMPORTANTE: usare LotSize adeguato per crypto (es. 0.01-0.1 ETH)
#define ETHUSD_DefaultSpacing    20.0    // ~$20 spacing raccomandato
#define ETHUSD_EstimatedSpread   2.0     // ~$2 spread tipico
#define ETHUSD_DailyRange        100.0   // ~$100 range giornaliero tipico
#define ETHUSD_ATR_Typical       20.0    // ~$20 ATR H4 tipico
