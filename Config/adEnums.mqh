//+------------------------------------------------------------------+
//|                                                adEnums.mqh       |
//|           AcquaDulza EA v1.0.0 — Enumerations & Structs          |
//|                                                                  |
//|  Enum FRAMEWORK (stabili, non cambiano con engine swap)          |
//|  + struct CycleRecord                                            |
//|  + costanti globali                                              |
//+------------------------------------------------------------------+
#property copyright "AcquaDulza (C) 2026"

//+------------------------------------------------------------------+
//| === FRAMEWORK ENUMS (engine-agnostici) ===                       |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| SYSTEM STATE — Stato globale del sistema                         |
//+------------------------------------------------------------------+
enum ENUM_SYSTEM_STATE
{
   STATE_INIT          = 0,   // Inizializzazione
   STATE_IDLE          = 1,   // Inattivo (premi START)
   STATE_ACTIVE        = 2,   // Operativo
   STATE_PAUSED        = 3,   // In pausa
   STATE_INITIALIZING  = 4,   // Inizializzazione in corso
   STATE_CLOSING       = 5,   // Chiusura posizioni
   STATE_EMERGENCY     = 90,  // Emergency stop
   STATE_ERROR         = 99   // Errore critico
};

//+------------------------------------------------------------------+
//| CYCLE STATE — Stato di ogni ciclo di trading                     |
//+------------------------------------------------------------------+
enum ENUM_CYCLE_STATE
{
   CYCLE_IDLE,              // Slot disponibile
   CYCLE_PENDING,           // Ordine pendente (STOP/LIMIT)
   CYCLE_ACTIVE,            // Posizione attiva
   CYCLE_CLOSED             // Ciclo completato
};

//+------------------------------------------------------------------+
//| RISK MODE — Modalita' calcolo lotto                              |
//+------------------------------------------------------------------+
enum ENUM_RISK_MODE
{
   RISK_FIXED_LOT  = 0,     // Lotto fisso
   RISK_PERCENT    = 1,     // % equity per trade
   RISK_FIXED_CASH = 2      // Cash fisso per trade
};

//+------------------------------------------------------------------+
//| ENTRY MODE — Tipo ordine di ingresso                             |
//+------------------------------------------------------------------+
enum ENUM_ENTRY_MODE
{
   ENTRY_MARKET = 0,        // Market (esecuzione immediata)
   ENTRY_LIMIT  = 1,        // Limit (prezzo migliore)
   ENTRY_STOP   = 2         // Stop (breakout/trigger)
};

//+------------------------------------------------------------------+
//| SL MODE — Modalita' calcolo Stop Loss                            |
//+------------------------------------------------------------------+
enum ENUM_SL_MODE
{
   SL_BAND_OPPOSITE = 0,    // SL = banda opposta
   SL_ATR_MULTIPLE  = 1,    // SL = N * ATR dalla entry
   SL_FIXED_PIPS    = 2     // SL = N pips fissi
};

//+------------------------------------------------------------------+
//| TP MODE — Modalita' calcolo Take Profit                          |
//+------------------------------------------------------------------+
enum ENUM_TP_MODE
{
   TP_MIDLINE       = 0,    // TP alla midline
   TP_ATR_MULTIPLE  = 1,    // TP = N * ATR dalla entry
   TP_FIXED_PIPS    = 2     // TP = N pips fissi
};

//+------------------------------------------------------------------+
//| LOG LEVEL — Livello di logging                                   |
//+------------------------------------------------------------------+
enum ENUM_LOG_LEVEL
{
   LOG_INFO,                // Info — standard
   LOG_WARNING,             // Warning — avvisi
   LOG_ERROR                // Error — errori
};

//+------------------------------------------------------------------+
//| === ENGINE-SPECIFIC ENUMS (DPC) ===                              |
//| Questi enum cambiano quando si swappa engine                     |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| DPC MA TYPE — Tipo media mobile per filtro                       |
//+------------------------------------------------------------------+
enum ENUM_DPC_MA_TYPE
{
   DPC_MA_SMA = 0,          // SMA - Simple Moving Average
   DPC_MA_EMA = 1,          // EMA - Exponential Moving Average
   DPC_MA_WMA = 2,          // WMA - Weighted Moving Average
   DPC_MA_HMA = 3           // HMA - Hull Moving Average
};

//+------------------------------------------------------------------+
//| DPC TRIGGER MODE — Quando scatta il segnale                      |
//+------------------------------------------------------------------+
enum ENUM_TRIGGER_MODE
{
   TRIGGER_INTRABAR  = 0,   // Intrabar (tick-based)
   TRIGGER_BAR_CLOSE = 1    // Bar Close (anti-repaint)
};

//+------------------------------------------------------------------+
//| DPC TF PRESET — Auto-preset per timeframe                        |
//+------------------------------------------------------------------+
enum ENUM_TF_PRESET
{
   TF_PRESET_AUTO   = 0,    // Auto (basato su Period())
   TF_PRESET_MANUAL = 1     // Manuale (usa input diretti)
};

//+------------------------------------------------------------------+
//| DPC MA FILTER MODE — Direzione filtro MA                         |
//+------------------------------------------------------------------+
enum ENUM_MA_FILTER_MODE
{
   MA_FILTER_DISABLED = 0,  // Disabilitato
   MA_FILTER_ABOVE    = 1,  // BUY solo se close > MA
   MA_FILTER_BELOW    = 2,  // SELL solo se close < MA
   MA_FILTER_BOTH     = 3   // Entrambi
};

//+------------------------------------------------------------------+
//| DPC SIGNAL PATTERN — TBS vs TWS                                  |
//+------------------------------------------------------------------+
enum ENUM_SIGNAL_PATTERN
{
   PATTERN_NONE = 0,
   PATTERN_TWS  = 1,        // Turtle Wick Soup (solo wick sfonda)
   PATTERN_TBS  = 3         // Turtle Bar Soup (corpo sfonda)
};

//+------------------------------------------------------------------+
//| === STRUCT CycleRecord ===                                       |
//| Record semplificato — no soup/breakout/hedge fields              |
//+------------------------------------------------------------------+
struct CycleRecord
{
   int                cycleID;         // ID univoco del ciclo
   ENUM_CYCLE_STATE   state;
   int                direction;       // +1=BUY, -1=SELL
   int                quality;         // 3=TBS, 1=TWS
   ulong              ticket;          // Ticket ordine/posizione
   double             entryPrice;
   double             tpPrice;
   double             slPrice;
   double             lotSize;
   datetime           signalTime;      // Tempo del segnale
   datetime           placedTime;      // Tempo piazzamento ordine
   double             profit;          // P&L (floating o realized)
};

//+------------------------------------------------------------------+
//| === STRUCT DashboardData ===                                     |
//| Popolata dal framework leggendo EngineSignal.                    |
//| Dashboard legge SOLO questa struct — zero dipendenza da Engine.  |
//+------------------------------------------------------------------+
struct DashboardData
{
   // System
   ENUM_SYSTEM_STATE  systemState;
   string             symbolName;
   string             timeframeName;
   int                magicNumber;
   string             engineName;       // "DPC v7.19" etc.

   // Engine signal (copiato da EngineSignal)
   double             upperBand;
   double             midline;
   double             lowerBand;
   double             channelWidthPip;
   bool               isFlat;
   int                lastDirection;
   int                lastQuality;

   // Extra engine values (da EngineSignal.extraValues)
   double             extraValues[12];
   string             extraLabels[12];
   int                extraCount;

   // Filters (da EngineSignal.filterStates)
   int                filterStates[8];
   string             filterNames[8];
   int                filterCount;

   // Cycles
   int                activeCycles;
   int                maxCycles;
   int                pendingCycles;

   // P&L
   double             sessionPnL;
   int                totalTrades;
   int                wins;
   int                losses;
   double             winRate;
   double             maxDrawdown;
   double             floatingPnL;
   double             dailyLoss;

   // Market
   double             atrValue;
   double             spreadPips;
   double             balance;
   double             equity;

   // Signals
   int                buySignals;
   int                sellSignals;
   int                totalSignals;

   // LTF
   int                ltfConfirm;
   string             ltfTimeframe;

   // Session
   string             sessionName;

   // AutoSave
   datetime           lastSaveTime;
};

//+------------------------------------------------------------------+
//| COSTANTI GLOBALI                                                 |
//+------------------------------------------------------------------+
const int    MAX_CYCLES         = 10;      // Max cicli contemporanei (array size)
const string EA_NAME            = "AcquaDulza";
const string EA_VERSION         = "1.0.0";
