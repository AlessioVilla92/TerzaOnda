//+------------------------------------------------------------------+
//|                                        carnGlobalVariables.mqh   |
//|                    Carneval EA v3.40 - Global Variables           |
//+------------------------------------------------------------------+
#property copyright "Sugamara Ribelle (C) 2026"

#include <Trade/Trade.mqh>

//+------------------------------------------------------------------+
//| TRADE OBJECT                                                     |
//+------------------------------------------------------------------+
CTrade trade;

//+------------------------------------------------------------------+
//| SYSTEM STATE                                                     |
//+------------------------------------------------------------------+
ENUM_SYSTEM_STATE systemState = STATE_INIT;
datetime systemStartTime = 0;

//+------------------------------------------------------------------+
//| BROKER SPECIFICATIONS                                            |
//+------------------------------------------------------------------+
int    symbolStopsLevel = 0;
int    symbolFreezeLevel = 0;
double symbolMinLot = 0;
double symbolMaxLot = 0;
double symbolLotStep = 0;
long   symbolSpreadPoints = 0;
double symbolPoint = 0;
int    symbolDigits = 0;

//+------------------------------------------------------------------+
//| ATR & VOLATILITY                                                 |
//+------------------------------------------------------------------+
int    atrHandle = INVALID_HANDLE;
double ATR = 0;                         // ATR in distanza prezzo
double ATR_Pips = 0;                    // ATR in pips
double currentATR_Pips = 0;             // ATR corrente in pips (cache)
ENUM_ATR_CONDITION currentATR_Condition = ATR_NORMAL;
datetime lastATRRecalc = 0;

// ATR Cache struct
struct ATRCacheData
{
    double   valuePips;
    datetime lastFullUpdate;
    datetime lastBarTime;
    bool     isValid;

    void Reset()
    {
        valuePips = 0;
        lastFullUpdate = 0;
        lastBarTime = 0;
        isValid = false;
    }
};
ATRCacheData g_atrCache;

//+------------------------------------------------------------------+
//| DPC ENGINE — Handle indicatori interni                             |
//|  Leggeri: solo iATR(14) + iMA (no Canvas, no oggetti grafici)      |
//|  Creati da InitializeDPCEngine(), rilasciati da DeinitDPCEngine()  |
//+------------------------------------------------------------------+
int      g_dpcATRHandle     = INVALID_HANDLE;
int      g_adxHandle        = INVALID_HANDLE;   // [v3.4] Handle iADX per filtro segnali
double   g_adxValue         = 0;                // [v3.4] Valore ADX corrente (diagnostica)
int      g_dpcMAHandle      = INVALID_HANDLE;   // SMA/EMA/WMA
int      g_dpcHMAHalfHandle = INVALID_HANDLE;   // WMA(n/2) per HMA
int      g_dpcHMAFullHandle = INVALID_HANDLE;   // WMA(n) per HMA
bool     g_dpcEngineReady   = false;

//+------------------------------------------------------------------+
//| DPC ENGINE — SmartCooldown State                                   |
//|  Gestisce frequenza segnali: stesso verso vs direzione opposta     |
//|  Aggiornato da UpdateCooldownState() e CheckMidlineTouch_Engine()  |
//+------------------------------------------------------------------+
int      g_dpcLastSignalBarIdx   = 0;       // Bar index dell'ultimo segnale confermato
int      g_dpcLastDirection_cd   = 0;       // +1=BUY, -1=SELL, 0=nessuno
bool     g_dpcMidlineTouched_cd  = false;   // Prezzo ha raggiunto midline dopo ultimo segnale
int      g_dpcMidlineTouchBarIdx = 0;       // Bar index del tocco midline
bool     g_dpcWaitingForMidTouch = false;   // Attesa tocco midline

//+------------------------------------------------------------------+
//| DPC ENGINE — EMA ATR                                               |
//+------------------------------------------------------------------+
double   g_dpcEmaATR = 0;                  // EMA(200) ATR — diagnostica visuale in dashboard (non usata per trading)

//+------------------------------------------------------------------+
//| DPC ENGINE — Time Filter (parsed once in Init)                     |
//+------------------------------------------------------------------+
int      g_dpcTimeBlockStartMin = 0;       // Inizio blocco in minuti broker (0-1439)
int      g_dpcTimeBlockEndMin   = 0;       // Fine blocco in minuti broker (0-1439)

//+------------------------------------------------------------------+
//| DPC ENGINE OUTPUT — Valori calcolati (aggiornati ogni nuova barra) |
//|  Scritti da CalculateDPC(), letti da strategie/overlay/dashboard   |
//+------------------------------------------------------------------+
double   g_dpcUpper = 0;
double   g_dpcLower = 0;
double   g_dpcMid = 0;
int      g_dpcMidColor = 0;        // 0=bullish, 1=bearish
double   g_dpcMA = 0;
double   g_dpcChannelWidth = 0;    // In pips

//+------------------------------------------------------------------+
//| DPC ENGINE — Trigger Prices (per MODE_TRIGGER_INDICATOR)           |
//|  Calcolati da CalculateDPC(): band +/- PipsToPrice(Trigger_Offset) |
//|  Reset a 0 ogni barra, valorizzati solo se segnale confermato      |
//+------------------------------------------------------------------+
double   g_dpcTriggerBuyPrice = 0;    // Trigger BUY: lower_band + offset
double   g_dpcTriggerSellPrice = 0;   // Trigger SELL: upper_band - offset

//+------------------------------------------------------------------+
//| SIGNAL TRACKING                                                  |
//+------------------------------------------------------------------+
int      g_totalSignals = 0;
int      g_buySignals = 0;
int      g_sellSignals = 0;
datetime g_lastSignalTime = 0;
string   g_lastSignalDirection = "NONE";
datetime g_lastProcessedBuyBar  = 0;   // [v3.4] Anti-repaint: ultima barra BUY processata
datetime g_lastProcessedSellBar = 0;   // [v3.4] Anti-repaint: ultima barra SELL processata
datetime g_lastProcessedSignalBar = 0;  // LEGACY (mantenuta per compatibilita' recovery)

//+------------------------------------------------------------------+
//| SIGNAL CYCLE STRUCT                                              |
//+------------------------------------------------------------------+
struct SignalCycle
{
    // === IDENTIFICAZIONE ===
    int       cycleID;
    datetime  signalTime;
    int       direction;              // +1 = BUY/LONG, -1 = SELL/SHORT

    // === TURTLE SOUP (ordine principale) ===
    ulong     soupTicket;
    double    soupEntryPrice;
    double    soupTP;
    double    soupLotSize;
    bool      soupActive;

    // === BREAKOUT (ordine hedge pendente) ===
    ulong     breakoutTicket;
    double    breakoutEntryPrice;
    double    breakoutTP;
    double    breakoutLotSize;
    bool      breakoutPending;
    bool      breakoutActive;

    // === TRIGGER MODE (pending STOP -> filled position) ===
    ulong     triggerTicket;           // Ticket of pending STOP or filled position
    double    triggerEntryPrice;       // STOP order price
    double    triggerTP;               // TP at midline
    double    triggerLotSize;
    bool      triggerPending;          // true = pending STOP not yet filled
    bool      triggerActive;           // true = STOP filled, position active
    double    triggerSignalPrice;      // Original DPC band level at signal time
    datetime  triggerPlacedBar;        // Bar time when STOP was placed (for expiry)
    double    triggerSL;               // [v3.4] Stop Loss price (0 = nessun SL)

    // === STATO ===
    ENUM_CYCLE_STATE state;

    // === P&L ===
    double    soupProfit;
    double    breakoutProfit;

    void Reset()
    {
        cycleID = 0;
        signalTime = 0;
        direction = 0;
        soupTicket = 0;
        soupEntryPrice = 0;
        soupTP = 0;
        soupLotSize = 0;
        soupActive = false;
        breakoutTicket = 0;
        breakoutEntryPrice = 0;
        breakoutTP = 0;
        breakoutLotSize = 0;
        breakoutPending = false;
        breakoutActive = false;
        triggerTicket = 0;
        triggerEntryPrice = 0;
        triggerTP = 0;
        triggerLotSize = 0;
        triggerPending = false;
        triggerActive = false;
        triggerSignalPrice = 0;
        triggerPlacedBar = 0;
        triggerSL = 0;
        state = CYCLE_IDLE;
        soupProfit = 0;
        breakoutProfit = 0;
    }
};

//+------------------------------------------------------------------+
//| MULTI-SIGNAL CYCLES                                              |
//+------------------------------------------------------------------+
SignalCycle g_cycles[];
int      g_nextCycleID = 1;

//+------------------------------------------------------------------+
//| P&L COUNTERS (globali)                                           |
//+------------------------------------------------------------------+
double   g_totalSoupProfit = 0;
double   g_totalBreakoutProfit = 0;
int      g_totalSoupWins = 0;
int      g_totalSoupLosses = 0;
int      g_totalBreakoutWins = 0;
int      g_totalBreakoutLosses = 0;
int      g_totalHedgeActivations = 0;

//+------------------------------------------------------------------+
//| EQUITY TRACKING                                                  |
//+------------------------------------------------------------------+
double maxEquityReached = 0;
double maxDrawdownReached = 0;
double startingEquity = 0;
double startingBalance = 0;

//+------------------------------------------------------------------+
//| DAILY TRACKING                                                   |
//+------------------------------------------------------------------+
double dailyRealizedProfit = 0;
int    dailyWins = 0;
int    dailyLosses = 0;

//+------------------------------------------------------------------+
//| EXPOSURE TRACKING                                                |
//+------------------------------------------------------------------+
double totalLongLots = 0;
double totalShortLots = 0;
double netExposure = 0;
bool   isNeutral = true;

//+------------------------------------------------------------------+
//| SESSION                                                          |
//+------------------------------------------------------------------+
datetime g_lastSessionEndCheck = 0;
double   sessionRealizedProfit = 0;
int      sessionWins = 0;
int      sessionLosses = 0;

//+------------------------------------------------------------------+
//| SIGNAL FILTER COUNTERS                                           |
//+------------------------------------------------------------------+
int      g_totalExpiredOrders           = 0;  // Ordini pending scaduti (trigger expiry)
int      g_dailyCyclesCount = 0;         // [v3.4] Contatore cicli del giorno corrente
datetime g_dailyCyclesDate  = 0;         // [v3.4] Data di reset del contatore giornaliero

//+------------------------------------------------------------------+
//| CheckDailyCycleLimit — [v3.4] Verifica limite cicli giornalieri  |
//+------------------------------------------------------------------+
bool CheckDailyCycleLimit()
{
    if(Max_DailyCycles <= 0) return true;  // 0 = illimitato

    // Reset contatore ad inizio nuovo giorno
    MqlDateTime now, last;
    TimeToStruct(TimeCurrent(), now);
    if(g_dailyCyclesDate > 0)
    {
        TimeToStruct(g_dailyCyclesDate, last);
        if(now.day != last.day || now.mon != last.mon)
        {
            g_dailyCyclesCount = 0;
            Print("[v3.4] Reset contatore cicli giornalieri");
        }
    }
    g_dailyCyclesDate = TimeCurrent();

    if(g_dailyCyclesCount >= Max_DailyCycles)
    {
        PrintFormat("[v3.4] DAILY LIMIT: %d/%d cicli raggiunto — nessun nuovo ciclo oggi",
                    g_dailyCyclesCount, Max_DailyCycles);
        return false;
    }
    return true;
}
