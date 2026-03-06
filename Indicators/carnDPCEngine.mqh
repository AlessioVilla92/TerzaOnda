//+------------------------------------------------------------------+
//|                                            carnDPCEngine.mqh      |
//|              Carneval EA v3.40 — DPC Signal Engine                 |
//|                                                                    |
//|  Motore interno di calcolo segnali Donchian Predictive Channel.    |
//|  Calcola bande Donchian via iHighest/iLowest (built-in MQL5),      |
//|  applica 8 filtri qualita' e SmartCooldown, genera trigger prices.  |
//|                                                                    |
//|  Pipeline segnali (ogni nuova barra, bar[1] confermata):           |
//|    1. ComputeDonchianBands — Upper/Lower/Mid                       |
//|    2. GetDPCMAValue — MA filtro (SMA/EMA/WMA/HMA)                  |
//|    3. Signal Detection — bearBase/bullBase (touch bande)            |
//|    4. Quality Filters — Spread, ADX, Flatness, Trend, LevelAge,    |
//|       Width, Time                                                  |
//|    5. SmartCooldown — frequenza segnali intelligente                |
//|    6. Trigger Prices — entry point con offset EMA ATR               |
//|                                                                    |
//|  Touch Trigger (ogni tick, bar[0] live):                            |
//|    Rileva tocco bande in tempo reale per MODE_TRIGGER_INDICATOR     |
//+------------------------------------------------------------------+
#property copyright "Sugamara Ribelle (C) 2026"

//+------------------------------------------------------------------+
//| FORWARD DECLARATIONS                                              |
//+------------------------------------------------------------------+
void    ComputeDonchianBands(int barShift, int lookback, double &upper, double &lower, double &mid);
double  GetDPCMAValue(int barShift);
double  GetDPCATR(int barShift);
int     GetMidlineColor(int barShift);
bool    CheckBandFlatness_Sell(int barShift, double atr);
bool    CheckBandFlatness_Buy(int barShift, double atr);
bool    CheckTrendContext_Sell(int barShift, double atr);
bool    CheckTrendContext_Buy(int barShift, double atr);
bool    CheckLevelAge_Sell(int barShift);
bool    CheckLevelAge_Buy(int barShift);
bool    CheckChannelWidthFilter(double upper, double lower);
bool    IsInBlockedTime_Engine(datetime barTime);
bool    CheckSmartCooldown_Sell(int currentBarIdx);
bool    CheckSmartCooldown_Buy(int currentBarIdx);
void    UpdateCooldownState(int direction, int currentBarIdx);
void    CheckMidlineTouch_Engine(int barShift, int currentBarIdx);
int     ParseTimeToMinutes_Engine(string timeStr);
double  ManualWMA(const double &src[], int startIdx, int period);

//+------------------------------------------------------------------+
//| InitializeDPCEngine — Inizializzazione motore DPC                  |
//|   1. Crea handle iATR(14) per calcolo volatilita'                  |
//|   2. Crea handle iMA per filtro MA (SMA/EMA/WMA/HMA)              |
//|   3. Parsa filtro orario (se attivo)                               |
//|   4. Reset stato SmartCooldown                                     |
//|   5. Valida prime bande Donchian su bar[1]                         |
//+------------------------------------------------------------------+
bool InitializeDPCEngine()
{
    // --- Release previous handles if any ---
    DeinitDPCEngine();

    // --- Create ATR(14) handle ---
    g_dpcATRHandle = iATR(_Symbol, PERIOD_CURRENT, 14);
    if(g_dpcATRHandle == INVALID_HANDLE)
    {
        CarnLogE(LOG_CAT_DPC, "CRITICAL: Failed to create iATR(14) handle!");
        return false;
    }

    // --- Create MA handle(s) based on type ---
    if(DPC_MAType == DPC_MA_HMA)
    {
        int halfLen = (int)MathFloor(DPC_MALength / 2.0);
        if(halfLen < 1) halfLen = 1;
        g_dpcHMAHalfHandle = iMA(_Symbol, PERIOD_CURRENT, halfLen, 0, MODE_LWMA, PRICE_CLOSE);
        g_dpcHMAFullHandle = iMA(_Symbol, PERIOD_CURRENT, DPC_MALength, 0, MODE_LWMA, PRICE_CLOSE);

        if(g_dpcHMAHalfHandle == INVALID_HANDLE || g_dpcHMAFullHandle == INVALID_HANDLE)
        {
            CarnLogE(LOG_CAT_DPC, "CRITICAL: Failed to create HMA handles!");
            return false;
        }
        CarnLogI(LOG_CAT_DPC, StringFormat("HMA handles created: half=%d full=%d (halfLen=%d fullLen=%d)",
                 g_dpcHMAHalfHandle, g_dpcHMAFullHandle, halfLen, DPC_MALength));
    }
    else
    {
        ENUM_MA_METHOD maMethod = MODE_SMA;
        if(DPC_MAType == DPC_MA_EMA) maMethod = MODE_EMA;
        else if(DPC_MAType == DPC_MA_WMA) maMethod = MODE_LWMA;

        g_dpcMAHandle = iMA(_Symbol, PERIOD_CURRENT, DPC_MALength, 0, maMethod, PRICE_CLOSE);
        if(g_dpcMAHandle == INVALID_HANDLE)
        {
            CarnLogE(LOG_CAT_DPC, StringFormat("CRITICAL: Failed to create iMA handle (type=%s, period=%d)!",
                     EnumToString(DPC_MAType), DPC_MALength));
            return false;
        }
        CarnLogI(LOG_CAT_DPC, StringFormat("MA handle created: %d (type=%s, period=%d)",
                 g_dpcMAHandle, EnumToString(DPC_MAType), DPC_MALength));
    }

    // --- Parse Time Filter ---
    if(DPC_UseTimeFilter)
    {
        int localStartMin = ParseTimeToMinutes_Engine(DPC_TimeBlockStart);
        int localEndMin   = ParseTimeToMinutes_Engine(DPC_TimeBlockEnd);
        g_dpcTimeBlockStartMin = (localStartMin + DPC_BrokerOffset * 60) % 1440;
        g_dpcTimeBlockEndMin   = (localEndMin   + DPC_BrokerOffset * 60) % 1440;
        if(g_dpcTimeBlockStartMin < 0) g_dpcTimeBlockStartMin += 1440;
        if(g_dpcTimeBlockEndMin < 0)   g_dpcTimeBlockEndMin   += 1440;

        CarnLogI(LOG_CAT_DPC, StringFormat("Time Filter: %02d:%02d - %02d:%02d (broker) | Input: %s - %s + %dh offset",
                 g_dpcTimeBlockStartMin / 60, g_dpcTimeBlockStartMin % 60,
                 g_dpcTimeBlockEndMin / 60, g_dpcTimeBlockEndMin % 60,
                 DPC_TimeBlockStart, DPC_TimeBlockEnd, DPC_BrokerOffset));
    }

    // --- Reset state ---
    g_dpcLastSignalBarIdx   = 0;
    g_dpcLastDirection_cd   = 0;
    g_dpcMidlineTouched_cd  = false;
    g_dpcMidlineTouchBarIdx = 0;
    g_dpcWaitingForMidTouch = false;
    g_dpcEmaATR             = 0;
    // --- Validate first read ---
    double testUpper, testLower, testMid;
    ComputeDonchianBands(1, DPC_Period, testUpper, testLower, testMid);

    if(testUpper > 0 && testLower > 0 && testMid > 0)
    {
        g_dpcEngineReady = true;
        CarnLog(LOG_SUCCESS, LOG_CAT_DPC, StringFormat("DPC ENGINE READY — Upper:%s | Lower:%s | Mid:%s | Width:%.1fp",
                DoubleToString(testUpper, _Digits), DoubleToString(testLower, _Digits),
                DoubleToString(testMid, _Digits), PointsToPips(testUpper - testLower)));
        // [v3.4] Rimosso Alert() bloccante — informazione visibile in dashboard e log
        Comment("CARNEVAL DPC ENGINE ATTIVO | Upper: " + DoubleToString(testUpper, _Digits) +
                " | Lower: " + DoubleToString(testLower, _Digits));
        // Il Comment si cancella automaticamente al primo aggiornamento dashboard
    }
    else
    {
        CarnLogW(LOG_CAT_DPC, "Engine handles ready but data not yet available (normal on first load)");
        g_dpcEngineReady = false;
    }

    CarnLogI(LOG_CAT_DPC, StringFormat("Params: Period=%d Filter=%s MAMode=%s MA=%s MALen=%d",
             DPC_Period, DPC_SignalFilter ? "true" : "false",
             EnumToString(DPC_MAFilterMode), EnumToString(DPC_MAType), DPC_MALength));
    CarnLogI(LOG_CAT_DPC, StringFormat("SmartCooldown=%s MidTouch=%s SameDir=%d OppDir=%d",
             DPC_UseSmartCooldown ? "ON" : "OFF", DPC_RequireMidTouch ? "YES" : "NO",
             DPC_SameDirBars, DPC_OppositeDirBars));
    CarnLogI(LOG_CAT_DPC, StringFormat("Filters: Flatness=%s Trend=%s LevelAge=%s Width=%s Time=%s",
             DPC_UseBandFlatness ? "ON" : "OFF", DPC_UseTrendContext ? "ON" : "OFF",
             DPC_UseLevelAge ? "ON" : "OFF", DPC_UseWidthFilter ? "ON" : "OFF",
             DPC_UseTimeFilter ? "ON" : "OFF"));

    // === [v3.4] ADX Filter: crea handle se filtro abilitato ===
    if(Filter_ADX_Enable)
    {
        g_adxHandle = iADX(_Symbol, PERIOD_CURRENT, Filter_ADX_Period);
        if(g_adxHandle == INVALID_HANDLE)
        {
            CarnLogW(LOG_CAT_DPC, "[v3.4] ADX handle failed — filtro ADX disabilitato");
        }
        else
        {
            CarnLogI(LOG_CAT_DPC, StringFormat("[v3.4] ADX filter attivo: handle=%d | Min=%.0f | Max=%.0f",
                     g_adxHandle, Filter_ADX_MinLevel, Filter_ADX_MaxLevel));
        }
    }

    return true;
}

//+------------------------------------------------------------------+
//| DeinitDPCEngine — Rilascia handle iATR + iMA, reset stato          |
//+------------------------------------------------------------------+
void DeinitDPCEngine()
{
    if(g_dpcATRHandle != INVALID_HANDLE) { IndicatorRelease(g_dpcATRHandle); g_dpcATRHandle = INVALID_HANDLE; }
    if(g_dpcMAHandle != INVALID_HANDLE) { IndicatorRelease(g_dpcMAHandle); g_dpcMAHandle = INVALID_HANDLE; }
    if(g_dpcHMAHalfHandle != INVALID_HANDLE) { IndicatorRelease(g_dpcHMAHalfHandle); g_dpcHMAHalfHandle = INVALID_HANDLE; }
    if(g_dpcHMAFullHandle != INVALID_HANDLE) { IndicatorRelease(g_dpcHMAFullHandle); g_dpcHMAFullHandle = INVALID_HANDLE; }
    if(g_adxHandle != INVALID_HANDLE) { IndicatorRelease(g_adxHandle); g_adxHandle = INVALID_HANDLE; }
    g_dpcEngineReady = false;
}

//+------------------------------------------------------------------+
//| CalculateDPC — Pipeline principale segnali (ogni nuova barra)      |
//|                                                                    |
//|  Chiamata: OnTick -> IsNewBar() -> CalculateDPC()                  |
//|  Anti-repaint: legge SOLO bar[1] (barra confermata chiusa)         |
//|                                                                    |
//|  Pipeline:                                                         |
//|    1. Compute Donchian bands (iHighest/iLowest su N barre)         |
//|    2. Update variabili globali (g_dpcUpper/Lower/Mid/Width)        |
//|    3. EMA ATR(200) per calcolo offset trigger                      |
//|    4. Check midline touch (SmartCooldown state)                    |
//|    5. Signal detection: bearBase/bullBase + 5 quality filters      |
//|    6. SmartCooldown check (frequenza + direzione)                  |
//|    7. Trigger price extraction (band +/- offset EMA ATR)           |
//|    8. Anti-repaint guard (g_lastProcessedSignalBar)                |
//|                                                                    |
//|  Output: newBuySignal/newSellSignal + g_dpcTriggerBuy/SellPrice    |
//+------------------------------------------------------------------+
bool CalculateDPC(bool &newBuySignal, bool &newSellSignal)
{
    newBuySignal = false;
    newSellSignal = false;

    int totalBars = iBars(_Symbol, PERIOD_CURRENT);
    if(totalBars < DPC_Period + 5)
    {
        CarnLogW(LOG_CAT_DPC, StringFormat("Not enough bars: %d (need %d)", totalBars, DPC_Period + 5));
        return false;
    }

    // --- Ensure engine data is available ---
    if(!g_dpcEngineReady)
    {
        // Retry readiness check
        double testU, testL, testM;
        ComputeDonchianBands(1, DPC_Period, testU, testL, testM);
        if(testU > 0 && testL > 0 && testM > 0)
        {
            g_dpcEngineReady = true;
            CarnLog(LOG_SUCCESS, LOG_CAT_DPC, "DPC ENGINE: dati ora disponibili");
        }
        else
            return false;
    }

    // === 1. COMPUTE DONCHIAN BANDS for bar[1] (confirmed) ===
    double upper1, lower1, mid1;
    ComputeDonchianBands(1, DPC_Period, upper1, lower1, mid1);

    if(upper1 <= 0 || lower1 <= 0 || mid1 <= 0)
    {
        CarnLogW(LOG_CAT_DPC, "Donchian bands invalid (zero/negative)");
        return false;
    }

    // === 2. UPDATE GLOBAL VARIABLES ===
    g_dpcUpper = upper1;
    g_dpcLower = lower1;
    g_dpcMid   = mid1;
    g_dpcMidColor = GetMidlineColor(1);
    g_dpcMA    = (DPC_SignalFilter || DPC_MAType != DPC_MA_SMA) ? GetDPCMAValue(1) : 0;
    g_dpcChannelWidth = PointsToPips(upper1 - lower1);

    CarnLogD(LOG_CAT_DPC, StringFormat("Bar[1] — Upper=%s | Mid=%s | Lower=%s | Width=%.1fp | MA=%s",
             DoubleToString(g_dpcUpper, _Digits), DoubleToString(g_dpcMid, _Digits),
             DoubleToString(g_dpcLower, _Digits), g_dpcChannelWidth,
             DoubleToString(g_dpcMA, _Digits)));

    // === 3. ATR + EMA ATR ===
    double atr1 = GetDPCATR(1);
    if(atr1 > 0)
    {
        double alpha = 2.0 / (200.0 + 1.0);
        if(g_dpcEmaATR > 0)
            g_dpcEmaATR = alpha * atr1 + (1.0 - alpha) * g_dpcEmaATR;
        else
            g_dpcEmaATR = atr1;
    }

    // === [v3.4] SPREAD FILTER: blocca segnali con spread eccessivo ===
    if(Filter_Spread_Enable)
    {
        double currentSpread = GetSpreadPips();
        if(currentSpread > Filter_MaxSpreadPips)
        {
            CarnLogD(LOG_CAT_DPC, StringFormat("[v3.4] SPREAD FILTER: %.1fp > MAX %.1fp — CalculateDPC abortito",
                     currentSpread, Filter_MaxSpreadPips));
            return false;  // Nessun segnale durante spread elevato
        }
    }

    // === 4. CHECK MIDLINE TOUCH (SmartCooldown) ===
    int currentBarIdx = totalBars - 2;  // bar[1] index
    CheckMidlineTouch_Engine(1, currentBarIdx);

    // === 5. SIGNAL DETECTION on bar[1] — Fase 1: Base Conditions ===
    double high1 = iHigh(_Symbol, PERIOD_CURRENT, 1);
    double low1  = iLow(_Symbol, PERIOD_CURRENT, 1);

    bool bearBase = (high1 >= upper1);   // price touches upper -> SELL candidate
    bool bullBase = (low1 <= lower1);     // price touches lower -> BUY candidate

    // Anti-ambiguita' (Fix #3)
    if(bearBase && bullBase)
    {
        bearBase = false;
        bullBase = false;
    }

    // === Fase 2: Quality Filters ===

    // --- Filtro 1/6: Band Flatness ---
    if(DPC_UseBandFlatness && atr1 > 0)
    {
        if(bearBase && !CheckBandFlatness_Sell(1, atr1))
            bearBase = false;
        if(bullBase && !CheckBandFlatness_Buy(1, atr1))
            bullBase = false;
    }

    // --- Filtro 2/6: Trend Context ---
    if(DPC_UseTrendContext && atr1 > 0)
    {
        if(bearBase && !CheckTrendContext_Sell(1, atr1))
            bearBase = false;
        if(bullBase && !CheckTrendContext_Buy(1, atr1))
            bullBase = false;
    }

    // --- Filtro 3/6: Level Age (Raschke) ---
    if(DPC_UseLevelAge)
    {
        if(bearBase && !CheckLevelAge_Sell(1))
            bearBase = false;
        if(bullBase && !CheckLevelAge_Buy(1))
            bullBase = false;
    }

    // --- [v3.4] Filtro ADX: zona ottimale Turtle Soup ---
    if(Filter_ADX_Enable && g_adxHandle != INVALID_HANDLE)
    {
        double adxBuf[];
        ArrayResize(adxBuf, 2);
        ArraySetAsSeries(adxBuf, true);
        if(CopyBuffer(g_adxHandle, 0, 1, 2, adxBuf) >= 2)
        {
            g_adxValue = adxBuf[0];  // ADX di bar[1]

            bool adxInZone = (g_adxValue >= Filter_ADX_MinLevel &&
                              g_adxValue <= Filter_ADX_MaxLevel);

            if(!adxInZone)
            {
                if(bearBase || bullBase)
                    CarnLogD(LOG_CAT_DPC, StringFormat("[v3.4] ADX FILTRO: %.1f fuori zona [%.0f-%.0f] — segnale bloccato",
                             g_adxValue, Filter_ADX_MinLevel, Filter_ADX_MaxLevel));
                bearBase = false;
                bullBase = false;
            }
        }
    }

    // --- Filtro 4/6: Channel Width ---
    if(DPC_UseWidthFilter)
    {
        if(!CheckChannelWidthFilter(upper1, lower1))
        {
            bearBase = false;
            bullBase = false;
        }
    }

    // --- Filtro 5/6: Time Filter ---
    if(DPC_UseTimeFilter)
    {
        datetime bar1Time = iTime(_Symbol, PERIOD_CURRENT, 1);
        if(IsInBlockedTime_Engine(bar1Time))
        {
            bearBase = false;
            bullBase = false;
        }
    }

    // === Fase 3: SmartCooldown (filtro 6/6: frequenza segnali) ===
    bool bearCooldownOK = CheckSmartCooldown_Sell(currentBarIdx);
    bool bullCooldownOK = CheckSmartCooldown_Buy(currentBarIdx);

    bool bearCond = bearBase && bearCooldownOK;
    bool bullCond = bullBase && bullCooldownOK;

    // NOTE: MA filter applicato a livello strategia (close vs MA), non qui nel motore

    // === Fase 4: Trigger Price Extraction ===
    g_dpcTriggerBuyPrice  = 0;
    g_dpcTriggerSellPrice = 0;

    // Offset allineato a PlaceTriggerStop: freccia = entry price effettivo
    double triggerOffset = PipsToPrice(Trigger_Offset_Pips);

    if(bearCond)
    {
        g_dpcTriggerSellPrice = upper1 - triggerOffset;  // SELL STOP sotto upper band
        CarnLogD(LOG_CAT_DPC, StringFormat("TRIGGER SELL: Upper=%s - Offset=%.1fp = Entry=%s",
                 DoubleToString(upper1, _Digits), Trigger_Offset_Pips,
                 DoubleToString(g_dpcTriggerSellPrice, _Digits)));
    }
    if(bullCond)
    {
        g_dpcTriggerBuyPrice = lower1 + triggerOffset;   // BUY STOP sopra lower band
        CarnLogD(LOG_CAT_DPC, StringFormat("TRIGGER BUY: Lower=%s + Offset=%.1fp = Entry=%s",
                 DoubleToString(lower1, _Digits), Trigger_Offset_Pips,
                 DoubleToString(g_dpcTriggerBuyPrice, _Digits)));
    }

    // === [v3.4] Anti-repaint: variabili SEPARATE per BUY e SELL (fix guard asimmetrico) ===
    datetime currentBar1Time = iTime(_Symbol, PERIOD_CURRENT, 1);

    if(bearCond && currentBar1Time != g_lastProcessedSellBar)
        newSellSignal = true;
    else if(bearCond)
        CarnLogD(LOG_CAT_DPC, StringFormat("SELL duplicato IGNORATO (anti-repaint) — Bar=%s",
                 TimeToString(currentBar1Time, TIME_MINUTES)));

    if(bullCond && currentBar1Time != g_lastProcessedBuyBar)
        newBuySignal = true;
    else if(bullCond)
        CarnLogD(LOG_CAT_DPC, StringFormat("BUY duplicato IGNORATO (anti-repaint) — Bar=%s",
                 TimeToString(currentBar1Time, TIME_MINUTES)));

    if(newSellSignal)
        g_lastProcessedSellBar = currentBar1Time;
    if(newBuySignal)
        g_lastProcessedBuyBar = currentBar1Time;

    // Mantieni legacy per compatibilita' recovery
    if(newBuySignal || newSellSignal)
        g_lastProcessedSignalBar = currentBar1Time;

    // === Cooldown: aggiorna SOLO dopo conferma anti-repaint ===
    if(newSellSignal)
        UpdateCooldownState(-1, currentBarIdx);
    if(newBuySignal)
        UpdateCooldownState(+1, currentBarIdx);

    // === DIAGNOSTIC LOG ===
    {
        bool sigUp = bullCond;
        bool sigDn = bearCond;

        if(sigUp || sigDn)
        {
            CarnLogI(LOG_CAT_DPC, StringFormat("DIAG Bar[1]=%s | BUY:%s SELL:%s | New: BUY=%s SELL=%s",
                     TimeToString(currentBar1Time, TIME_MINUTES),
                     sigUp ? "COND" : "no", sigDn ? "COND" : "no",
                     newBuySignal ? "YES" : "no", newSellSignal ? "YES" : "no"));
        }
        else
        {
            static int noSignalCount = 0;
            noSignalCount++;
            if(noSignalCount % 6 == 1)
                CarnLogD(LOG_CAT_DPC, StringFormat("DIAG no signal — Bar[1]=%s | bearBase=%s bullBase=%s | Barre senza segnale: %d",
                         TimeToString(currentBar1Time, TIME_MINUTES),
                         bearBase ? "true" : "false", bullBase ? "true" : "false", noSignalCount));
        }
    }

    // === Detailed log for new signals ===
    if(DetailedLogging && (newBuySignal || newSellSignal))
    {
        string dir = newBuySignal ? "BUY" : "SELL";
        CarnLogI(LOG_CAT_DPC, StringFormat("=== NEW %s SIGNAL DETECTED (ENGINE) ===", dir));
        CarnLogD(LOG_CAT_DPC, StringFormat("Bar[1] time: %s", TimeToString(currentBar1Time)));
        CarnLogD(LOG_CAT_DPC, StringFormat("Bands: Upper=%s | Lower=%s | Mid=%s",
                 DoubleToString(g_dpcUpper, _Digits), DoubleToString(g_dpcLower, _Digits),
                 DoubleToString(g_dpcMid, _Digits)));
        CarnLogD(LOG_CAT_DPC, StringFormat("Channel Width: %.1f pips", g_dpcChannelWidth));
        CarnLogD(LOG_CAT_DPC, StringFormat("Mid Trend: %s", g_dpcMidColor == 0 ? "BULLISH" : "BEARISH"));
        CarnLogD(LOG_CAT_DPC, StringFormat("ATR(14): %s | EMA ATR: %s",
                 DoubleToString(atr1, _Digits), DoubleToString(g_dpcEmaATR, _Digits)));
        if(TradingMode == MODE_TRIGGER_INDICATOR)
        {
            CarnLogD(LOG_CAT_DPC, "MODE: TRIGGER INDICATOR");
            CarnLogD(LOG_CAT_DPC, StringFormat("Trigger BUY: %s | Trigger SELL: %s",
                     g_dpcTriggerBuyPrice > 0 ? DoubleToString(g_dpcTriggerBuyPrice, _Digits) : "NONE",
                     g_dpcTriggerSellPrice > 0 ? DoubleToString(g_dpcTriggerSellPrice, _Digits) : "NONE"));
            CarnLogD(LOG_CAT_DPC, StringFormat("Current: Ask=%s | Bid=%s | Spread=%.1fp",
                     DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits),
                     DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits),
                     GetSpreadPips()));
        }
    }

    // === Periodic buffer log ===
    if(LogDPCBuffers)
    {
        static datetime lastBufferLog = 0;
        if(TimeCurrent() - lastBufferLog > 300)
        {
            lastBufferLog = TimeCurrent();
            CarnLogD(LOG_CAT_DPC, StringFormat("ENGINE Upper:%s Lower:%s Mid:%s Width:%.1fp Trend:%s",
                     DoubleToString(g_dpcUpper, _Digits), DoubleToString(g_dpcLower, _Digits),
                     DoubleToString(g_dpcMid, _Digits), g_dpcChannelWidth,
                     g_dpcMidColor == 0 ? "BULL" : "BEAR"));
            if(TradingMode == MODE_TRIGGER_INDICATOR)
            {
                CarnLogD(LOG_CAT_DPC, StringFormat("ENGINE TrigBuy:%s TrigSell:%s",
                         g_dpcTriggerBuyPrice > 0 ? DoubleToString(g_dpcTriggerBuyPrice, _Digits) : "NONE",
                         g_dpcTriggerSellPrice > 0 ? DoubleToString(g_dpcTriggerSellPrice, _Digits) : "NONE"));
            }
        }
    }

    return true;
}

//+------------------------------------------------------------------+
//| UpdateSignalCounter — Aggiorna contatori segnali globali           |
//|  Incrementa g_totalSignals/g_buySignals/g_sellSignals              |
//|  Aggiorna g_lastSignalTime e g_lastSignalDirection                 |
//+------------------------------------------------------------------+
void UpdateSignalCounter(int direction)
{
    g_totalSignals++;
    if(direction > 0) g_buySignals++;
    else g_sellSignals++;
    g_lastSignalTime = TimeCurrent();
    g_lastSignalDirection = (direction > 0) ? "BUY" : "SELL";

    CarnLogI(LOG_CAT_DPC, StringFormat("SIGNAL %s #%d (ENGINE)", g_lastSignalDirection, g_totalSignals));
}

//+------------------------------------------------------------------+
//|                    HELPER FUNCTIONS                                |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| ComputeDonchianBands — Calcola Upper/Lower/Mid Donchian            |
//|  Usa iHighest/iLowest (funzioni native MQL5, O(n) per chiamata)    |
//|  barShift: indice barra di partenza (0=corrente, 1=chiusa)         |
//|  lookback: numero barre finestra (tipicamente DPC_Period)           |
//|  Scansione: barre [barShift, barShift+1, ..., barShift+lookback-1] |
//+------------------------------------------------------------------+
void ComputeDonchianBands(int barShift, int lookback, double &upper, double &lower, double &mid)
{
    int highestBar = iHighest(_Symbol, PERIOD_CURRENT, MODE_HIGH, lookback, barShift);
    int lowestBar  = iLowest(_Symbol, PERIOD_CURRENT, MODE_LOW, lookback, barShift);

    if(highestBar < 0 || lowestBar < 0)
    {
        upper = 0;
        lower = 0;
        mid = 0;
        return;
    }

    upper = iHigh(_Symbol, PERIOD_CURRENT, highestBar);
    lower = iLow(_Symbol, PERIOD_CURRENT, lowestBar);
    mid   = (upper + lower) * 0.5;
}

//+------------------------------------------------------------------+
//| GetDPCATR — Legge ATR(14) dal handle interno g_dpcATRHandle        |
//|  Usato per: offset trigger, EMA ATR, filtri qualita'               |
//+------------------------------------------------------------------+
double GetDPCATR(int barShift)
{
    if(g_dpcATRHandle == INVALID_HANDLE)
        return 0;

    double atrBuf[];
    ArrayResize(atrBuf, 1);
    ArraySetAsSeries(atrBuf, true);

    if(CopyBuffer(g_dpcATRHandle, 0, barShift, 1, atrBuf) < 1)
        return 0;

    return atrBuf[0];
}

//+------------------------------------------------------------------+
//| GetDPCMAValue — Calcola Moving Average per filtro segnali          |
//|  SMA/EMA/WMA: lettura diretta da handle iMA                        |
//|  HMA (Hull): formula a 3 passi:                                    |
//|    1. Legge WMA(n/2) e WMA(n) da handle                            |
//|    2. Calcola intermedio: 2*WMA(n/2) - WMA(n)                      |
//|    3. Applica WMA(sqrt(n)) sull'intermedio via ManualWMA            |
//+------------------------------------------------------------------+
double GetDPCMAValue(int barShift)
{
    if(DPC_MAType == DPC_MA_HMA)
    {
        // HMA = WMA(sqrt(n), source = 2*WMA(n/2) - WMA(n))
        int sqrtLen = (int)MathFloor(MathSqrt((double)DPC_MALength));
        if(sqrtLen < 1) sqrtLen = 1;
        int neededBars = sqrtLen + 2;

        double halfBuf[], fullBuf[];
        ArrayResize(halfBuf, neededBars);
        ArrayResize(fullBuf, neededBars);
        ArraySetAsSeries(halfBuf, true);
        ArraySetAsSeries(fullBuf, true);

        int copiedHalf = CopyBuffer(g_dpcHMAHalfHandle, 0, barShift, neededBars, halfBuf);
        int copiedFull = CopyBuffer(g_dpcHMAFullHandle, 0, barShift, neededBars, fullBuf);

        if(copiedHalf < neededBars || copiedFull < neededBars)
            return 0;

        // Intermediate: 2*WMA(n/2) - WMA(n)
        double interBuf[];
        ArrayResize(interBuf, neededBars);
        for(int k = 0; k < neededBars; k++)
            interBuf[k] = 2.0 * halfBuf[k] - fullBuf[k];

        // Apply WMA(sqrt(n)) on intermediate
        return ManualWMA(interBuf, 0, sqrtLen);
    }
    else
    {
        // SMA, EMA, WMA — single handle
        if(g_dpcMAHandle == INVALID_HANDLE)
            return 0;

        double maBuf[];
        ArrayResize(maBuf, 1);
        ArraySetAsSeries(maBuf, true);

        if(CopyBuffer(g_dpcMAHandle, 0, barShift, 1, maBuf) < 1)
            return 0;

        return maBuf[0];
    }
}

//+------------------------------------------------------------------+
//| ManualWMA — Weighted Moving Average manuale (passo HMA)            |
//|  Formula: WMA = sum(weight_k * src_k) / sum(weight_k)              |
//|  Pesi: k=0 (recente) = peso massimo, k=period-1 = peso 1          |
//|  src[]: array con index 0 = valore piu' recente                    |
//+------------------------------------------------------------------+
double ManualWMA(const double &src[], int startIdx, int period)
{
    if(period < 1) return 0;

    double weightSum = 0;
    double valueSum = 0;
    int available = ArraySize(src);

    for(int k = 0; k < period && (startIdx + k) < available; k++)
    {
        double weight = (double)(period - k);
        valueSum += src[startIdx + k] * weight;
        weightSum += weight;
    }

    return (weightSum > 0) ? valueSum / weightSum : 0;
}

//+------------------------------------------------------------------+
//| GetMidlineColor — Determina trend midline Donchian                 |
//|  Confronta mid[shift] vs mid[shift+2] (skip 1 barra per smoothing) |
//|  Return: 0=bullish (midline sale), 1=bearish (midline scende)      |
//+------------------------------------------------------------------+
int GetMidlineColor(int barShift)
{
    double upper1, lower1, mid1;
    double upper3, lower3, mid3;
    ComputeDonchianBands(barShift, DPC_Period, upper1, lower1, mid1);
    ComputeDonchianBands(barShift + 2, DPC_Period, upper3, lower3, mid3);

    if(mid1 > mid3) return 0;  // bullish (lime)
    if(mid1 < mid3) return 1;  // bearish (red)
    return 0;  // default bullish
}

//+------------------------------------------------------------------+
//| CheckBandFlatness_Sell — Filtro 1/6: espansione upper band         |
//|  Blocca SELL se upper band si e' espansa verso l'alto              |
//|  (trend rialzista attivo = non e' un buon momento per vendere)     |
//|  Soglia: espansione > DPC_FlatnessTolerance * ATR                  |
//|  Returns: true = segnale PASSA (banda piatta, ok)                  |
//+------------------------------------------------------------------+
bool CheckBandFlatness_Sell(int barShift, double atr)
{
    double flatTolerance = DPC_FlatnessTolerance * atr;
    int flatLookback = (int)MathMax(1, MathMin(10, DPC_FlatLookback));

    double upperCurrent, lowerCurrent, midCurrent;
    ComputeDonchianBands(barShift, DPC_Period, upperCurrent, lowerCurrent, midCurrent);

    for(int k = 1; k <= flatLookback; k++)
    {
        double upperK, lowerK, midK;
        ComputeDonchianBands(barShift + k, DPC_Period, upperK, lowerK, midK);

        if(upperCurrent > upperK + flatTolerance)
            return false;  // Upper band expanded -> trend up -> block SELL
    }
    return true;
}

//+------------------------------------------------------------------+
//| CheckBandFlatness_Buy — Filtro 1/6: espansione lower band          |
//|  Blocca BUY se lower band si e' espansa verso il basso             |
//|  (trend ribassista attivo = non e' un buon momento per comprare)   |
//|  Returns: true = segnale PASSA (banda piatta, ok)                  |
//+------------------------------------------------------------------+
bool CheckBandFlatness_Buy(int barShift, double atr)
{
    double flatTolerance = DPC_FlatnessTolerance * atr;
    int flatLookback = (int)MathMax(1, MathMin(10, DPC_FlatLookback));

    double upperCurrent, lowerCurrent, midCurrent;
    ComputeDonchianBands(barShift, DPC_Period, upperCurrent, lowerCurrent, midCurrent);

    for(int k = 1; k <= flatLookback; k++)
    {
        double upperK, lowerK, midK;
        ComputeDonchianBands(barShift + k, DPC_Period, upperK, lowerK, midK);

        if(lowerCurrent < lowerK - flatTolerance)
            return false;  // Lower band expanded down -> trend down -> block BUY
    }
    return true;
}

//+------------------------------------------------------------------+
//| CheckTrendContext_Sell — Filtro 2/6: macro-trend per SELL           |
//|  Blocca SELL se midline e' salita > soglia su finestra DPC_Period   |
//|  (macro-uptrend = non vendere controtendenza)                      |
//|  Soglia: DPC_TrendContextMultiple * ATR                            |
//+------------------------------------------------------------------+
bool CheckTrendContext_Sell(int barShift, double atr)
{
    int totalBars = iBars(_Symbol, PERIOD_CURRENT);
    if((barShift + DPC_Period) >= totalBars)
        return true;  // Not enough data, pass

    double trendThreshold = DPC_TrendContextMultiple * atr;

    double upperNow, lowerNow, midNow;
    double upperThen, lowerThen, midThen;
    ComputeDonchianBands(barShift, DPC_Period, upperNow, lowerNow, midNow);
    ComputeDonchianBands(barShift + DPC_Period, DPC_Period, upperThen, lowerThen, midThen);

    // Block SELL if midline ROSE by > threshold (macro uptrend)
    if((midNow - midThen) > trendThreshold)
        return false;

    return true;
}

//+------------------------------------------------------------------+
//| CheckTrendContext_Buy — Filtro 2/6: macro-trend per BUY            |
//|  Blocca BUY se midline e' scesa > soglia (macro-downtrend)         |
//+------------------------------------------------------------------+
bool CheckTrendContext_Buy(int barShift, double atr)
{
    int totalBars = iBars(_Symbol, PERIOD_CURRENT);
    if((barShift + DPC_Period) >= totalBars)
        return true;

    double trendThreshold = DPC_TrendContextMultiple * atr;

    double upperNow, lowerNow, midNow;
    double upperThen, lowerThen, midThen;
    ComputeDonchianBands(barShift, DPC_Period, upperNow, lowerNow, midNow);
    ComputeDonchianBands(barShift + DPC_Period, DPC_Period, upperThen, lowerThen, midThen);

    // Block BUY if midline FELL by > threshold (macro downtrend)
    if((midThen - midNow) > trendThreshold)
        return false;

    return true;
}

//+------------------------------------------------------------------+
//| CheckLevelAge_Sell — Filtro 3/6: maturita' livello (Raschke)       |
//|  Richiede che upper band sia stata piatta per N barre consecutive   |
//|  (livello maturo = piu' significativo per mean reversion)           |
//|  Tolleranza: 2 * _Point per considerare "piatto"                   |
//+------------------------------------------------------------------+
bool CheckLevelAge_Sell(int barShift)
{
    int minAge = (int)MathMax(1, MathMin(10, DPC_MinLevelAge));
    int totalBars = iBars(_Symbol, PERIOD_CURRENT);

    double upperCurrent, lowerCurrent, midCurrent;
    ComputeDonchianBands(barShift, DPC_Period, upperCurrent, lowerCurrent, midCurrent);

    int flatBars = 0;
    for(int k = 1; k < DPC_Period && (barShift + k) < totalBars; k++)
    {
        double upperK, lowerK, midK;
        ComputeDonchianBands(barShift + k, DPC_Period, upperK, lowerK, midK);

        if(MathAbs(upperK - upperCurrent) <= 2 * _Point)
            flatBars++;
        else
            break;
    }

    return (flatBars >= minAge);
}

//+------------------------------------------------------------------+
//| CheckLevelAge_Buy — Filtro 3/6: maturita' livello lower band       |
//|  Richiede che lower band sia stata piatta per N barre consecutive   |
//+------------------------------------------------------------------+
bool CheckLevelAge_Buy(int barShift)
{
    int minAge = (int)MathMax(1, MathMin(10, DPC_MinLevelAge));
    int totalBars = iBars(_Symbol, PERIOD_CURRENT);

    double upperCurrent, lowerCurrent, midCurrent;
    ComputeDonchianBands(barShift, DPC_Period, upperCurrent, lowerCurrent, midCurrent);

    int flatBars = 0;
    for(int k = 1; k < DPC_Period && (barShift + k) < totalBars; k++)
    {
        double upperK, lowerK, midK;
        ComputeDonchianBands(barShift + k, DPC_Period, upperK, lowerK, midK);

        if(MathAbs(lowerK - lowerCurrent) <= 2 * _Point)
            flatBars++;
        else
            break;
    }

    return (flatBars >= minAge);
}

//+------------------------------------------------------------------+
//| CheckChannelWidthFilter — Filtro 4/6: larghezza minima canale      |
//|  Blocca segnali se canale Donchian < DPC_MinWidthPips_Int pip      |
//|  (canali stretti = TP troppo vicino, alta probabilita' di SL)      |
//+------------------------------------------------------------------+
bool CheckChannelWidthFilter(double upper, double lower)
{
    double channelWidthPips = PointsToPips(upper - lower);
    return (channelWidthPips >= DPC_MinWidthPips_Int);
}

//+------------------------------------------------------------------+
//| IsInBlockedTime_Engine — Filtro 5/6: fascia oraria bloccata        |
//|  Blocca segnali durante orario ad alta volatilita' (es. news)      |
//|  Supporta intervalli che attraversano mezzanotte                    |
//|  g_dpcTimeBlockStart/EndMin: parsati una volta in Init             |
//+------------------------------------------------------------------+
bool IsInBlockedTime_Engine(datetime barTime)
{
    if(!DPC_UseTimeFilter)
        return false;

    MqlDateTime dt;
    TimeToStruct(barTime, dt);
    int barMinutes = dt.hour * 60 + dt.min;

    if(g_dpcTimeBlockStartMin <= g_dpcTimeBlockEndMin)
    {
        // Intervallo non attraversa mezzanotte
        return (barMinutes >= g_dpcTimeBlockStartMin && barMinutes < g_dpcTimeBlockEndMin);
    }
    else
    {
        // Intervallo attraversa mezzanotte
        return (barMinutes >= g_dpcTimeBlockStartMin || barMinutes < g_dpcTimeBlockEndMin);
    }
}

//+------------------------------------------------------------------+
//| CheckSmartCooldown_Sell — Filtro 6/6: cooldown intelligente SELL   |
//|  SmartCooldown OFF: cooldown fisso di DPC_Period barre             |
//|  SmartCooldown ON:                                                 |
//|    - Primo segnale: sempre accettato                               |
//|    - Stesso verso (SELL dopo SELL): richiede tocco midline + N     |
//|    - Verso opposto (SELL dopo BUY): solo N barre minime            |
//+------------------------------------------------------------------+
bool CheckSmartCooldown_Sell(int currentBarIdx)
{
    int barsFromLast = currentBarIdx - g_dpcLastSignalBarIdx;

    if(!DPC_UseSmartCooldown)
        return (barsFromLast >= DPC_Period);

    // SmartCooldown
    if(g_dpcLastDirection_cd == 0)
        return true;   // First signal always accepted

    if(g_dpcLastDirection_cd == -1)
    {
        // Same direction (SELL after SELL): require midline touch + N bars
        if(DPC_RequireMidTouch)
            return g_dpcMidlineTouched_cd &&
                   (currentBarIdx - g_dpcMidlineTouchBarIdx >= DPC_SameDirBars);
        else
            return (barsFromLast >= DPC_SameDirBars);
    }
    else
    {
        // Opposite direction (SELL after BUY): only minimum bars
        return (barsFromLast >= DPC_OppositeDirBars);
    }
}

//+------------------------------------------------------------------+
//| CheckSmartCooldown_Buy — Filtro 6/6: cooldown intelligente BUY     |
//|  Logica speculare a CheckSmartCooldown_Sell                        |
//+------------------------------------------------------------------+
bool CheckSmartCooldown_Buy(int currentBarIdx)
{
    int barsFromLast = currentBarIdx - g_dpcLastSignalBarIdx;

    if(!DPC_UseSmartCooldown)
        return (barsFromLast >= DPC_Period);

    if(g_dpcLastDirection_cd == 0)
        return true;

    if(g_dpcLastDirection_cd == +1)
    {
        // Same direction (BUY after BUY)
        if(DPC_RequireMidTouch)
            return g_dpcMidlineTouched_cd &&
                   (currentBarIdx - g_dpcMidlineTouchBarIdx >= DPC_SameDirBars);
        else
            return (barsFromLast >= DPC_SameDirBars);
    }
    else
    {
        // Opposite direction (BUY after SELL)
        return (barsFromLast >= DPC_OppositeDirBars);
    }
}

//+------------------------------------------------------------------+
//| UpdateCooldownState — Aggiorna stato SmartCooldown dopo segnale    |
//|  Salva bar index e direzione, reset flag tocco midline             |
//|  Chiamata dopo ogni segnale confermato (bearCond/bullCond)         |
//+------------------------------------------------------------------+
void UpdateCooldownState(int direction, int currentBarIdx)
{
    g_dpcLastSignalBarIdx   = currentBarIdx;
    g_dpcLastDirection_cd   = direction;
    g_dpcMidlineTouched_cd  = false;
    g_dpcMidlineTouchBarIdx = 0;
    g_dpcWaitingForMidTouch = true;
}

//+------------------------------------------------------------------+
//| CheckMidlineTouch_Engine — Rileva tocco midline (SmartCooldown)    |
//|  Dopo un segnale BUY: aspetta che high raggiunga midline           |
//|  Dopo un segnale SELL: aspetta che low raggiunga midline           |
//|  Il tocco midline sblocca nuovi segnali nella stessa direzione     |
//+------------------------------------------------------------------+
void CheckMidlineTouch_Engine(int barShift, int currentBarIdx)
{
    if(!g_dpcWaitingForMidTouch || g_dpcLastDirection_cd == 0)
        return;

    double mid1 = g_dpcMid;  // Already computed
    double high1 = iHigh(_Symbol, PERIOD_CURRENT, barShift);
    double low1  = iLow(_Symbol, PERIOD_CURRENT, barShift);

    bool midlineCrossed = false;
    if(g_dpcLastDirection_cd == +1 && high1 >= mid1)
        midlineCrossed = true;
    else if(g_dpcLastDirection_cd == -1 && low1 <= mid1)
        midlineCrossed = true;

    if(midlineCrossed)
    {
        if(DPC_UseSmartCooldown)
        {
            g_dpcMidlineTouched_cd  = true;
            g_dpcMidlineTouchBarIdx = currentBarIdx;
        }
        g_dpcWaitingForMidTouch = false;
    }
}

//+------------------------------------------------------------------+
//| ParseTimeToMinutes_Engine — Parser "HH:MM" -> minuti (0-1439)     |
//+------------------------------------------------------------------+
int ParseTimeToMinutes_Engine(string timeStr)
{
    int colonPos = StringFind(timeStr, ":");
    if(colonPos < 0) return 0;

    int hours   = (int)StringToInteger(StringSubstr(timeStr, 0, colonPos));
    int minutes = (int)StringToInteger(StringSubstr(timeStr, colonPos + 1));

    return hours * 60 + minutes;
}
