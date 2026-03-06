//+------------------------------------------------------------------+
//|                                            carnDPCReader.mqh     |
//|                Carneval EA - DPC Indicator Reader               |
//|  iCustom connection, anti-repaint signals, health check          |
//|  Buffer map allineato a DPC v7.13 (19 buffer)                   |
//+------------------------------------------------------------------+
#property copyright "Sugamara Ribelle (C) 2026"

//+------------------------------------------------------------------+
//| BUFFER INDEX MAP — DonchianPredictiveChannel v7.13               |
//|                                                                  |
//| Buf  0 = BufMid          (INDICATOR_DATA)         Midline        |
//| Buf  1 = BufMidColor     (INDICATOR_COLOR_INDEX)  0=bull 1=bear  |
//| Buf  2 = BufMidOffset    (INDICATOR_DATA)         Midline shift  |
//| Buf  3 = BufUpper        (INDICATOR_DATA)         Upper band     |
//| Buf  4 = BufLower        (INDICATOR_DATA)         Lower band     |
//| Buf  5 = BufFillUp       (INDICATOR_DATA)         Fill upper     |
//| Buf  6 = BufMA           (INDICATOR_DATA)         Moving Average |
//| Buf  7 = BufSignalUp     (INDICATOR_DATA)         BUY arrow      |
//| Buf  8 = BufSignalDn     (INDICATOR_DATA)         SELL arrow     |
//| Buf  9 = BufSignalUpBig  (INDICATOR_DATA)         BUY big arrow  |
//| Buf 10 = BufSignalDnBig  (INDICATOR_DATA)         SELL big arrow |
//| Buf 11 = BufCandleO      (INDICATOR_DATA)         Trigger Open   |
//| Buf 12 = BufCandleH      (INDICATOR_DATA)         Trigger High   |
//| Buf 13 = BufCandleL      (INDICATOR_DATA)         Trigger Low    |
//| Buf 14 = BufCandleC      (INDICATOR_DATA)         Trigger Close  |
//| Buf 15 = BufCandleColor  (INDICATOR_COLOR_INDEX)  Trigger color  |
//| Buf 16 = BufFillDn       (INDICATOR_CALCULATIONS)  Fill lower    |
//| Buf 17 = BufATR          (INDICATOR_CALCULATIONS)  ATR(14)       |
//| Buf 18 = BufTouchTrigger (INDICATOR_CALCULATIONS)  Touch Trigger |
//+------------------------------------------------------------------+
#define DPC_BUF_MID            0
#define DPC_BUF_MID_COLOR      1
#define DPC_BUF_UPPER          3
#define DPC_BUF_LOWER          4
#define DPC_BUF_MA             6
#define DPC_BUF_SIGNAL_UP      7
#define DPC_BUF_SIGNAL_DN      8
#define DPC_BUF_ATR           17
#define DPC_BUF_TOUCH_TRIGGER 18

//+------------------------------------------------------------------+
//| InitializeDPC — Connessione a DonchianPredictiveChannel          |
//+------------------------------------------------------------------+
bool InitializeDPC()
{
    // Release previous handle if any
    if(g_dpcHandle != INVALID_HANDLE)
    {
        IndicatorRelease(g_dpcHandle);
        g_dpcHandle = INVALID_HANDLE;
    }

    g_dpcHandle = iCustom(
        _Symbol,
        PERIOD_CURRENT,
        "DonchianPredictiveChannel",
        DPC_Period,                    // Pos 1: InpLenDC
        DPC_ForecastBars,              // Pos 2: InpProjLen
        DPC_SignalFilter,              // Pos 3: InpSignalFilter
        (int)DPC_MAFilterMode,         // Pos 4: InpMAFilterMode (INVERTED=1 per Soup)
        (int)DPC_MAType,               // Pos 5: InpMAType (HMA=3 raccomandato)
        DPC_MALength,                  // Pos 6: InpMALen
        true                           // Pos 7: InpSubIndicatorMode (v7.18 — no visual output)
    );

    if(g_dpcHandle == INVALID_HANDLE)
    {
        CarnLogE(LOG_CAT_DPC, "CRITICAL: DonchianPredictiveChannel NOT FOUND!");
        CarnLogE(LOG_CAT_DPC, "Il file .ex5 deve trovarsi in MQL5/Indicators/");
        CarnLogE(LOG_CAT_DPC, "1. Copiare DonchianPredictiveChannel.mq5 in MQL5/Indicators/");
        CarnLogE(LOG_CAT_DPC, "2. Compilare con F7 in MetaEditor");
        CarnLogE(LOG_CAT_DPC, "3. Riavviare l'EA");
        Alert("CARNEVAL: INDICATORE ERRATO o NON TROVATO! ",
              "DonchianPredictiveChannel.ex5 non presente in MQL5/Indicators/. ",
              "Compilare l'indicatore e riavviare l'EA.");
        return false;
    }

    CarnLogI(LOG_CAT_DPC, StringFormat("Handle creato: %d", g_dpcHandle));
    CarnLogI(LOG_CAT_DPC, StringFormat("Params: Period=%d Forecast=%d Filter=%s MAFilterMode=%s MA=%s MALen=%d",
             DPC_Period, DPC_ForecastBars, DPC_SignalFilter ? "true" : "false",
             EnumToString(DPC_MAFilterMode), EnumToString(DPC_MAType), DPC_MALength));

    // Initial health check
    g_dpcConnected = false;
    g_dpcHealthFailures = 0;
    g_lastDPCHealthCheck = 0;  // Force first check

    // Try to read initial data
    double testUpper[], testLower[], testMid[];
    ArrayResize(testUpper, 1);
    ArrayResize(testLower, 1);
    ArrayResize(testMid, 1);
    ArraySetAsSeries(testUpper, true);
    ArraySetAsSeries(testLower, true);
    ArraySetAsSeries(testMid, true);

    int c1 = CopyBuffer(g_dpcHandle, DPC_BUF_UPPER, 1, 1, testUpper);
    int c2 = CopyBuffer(g_dpcHandle, DPC_BUF_LOWER, 1, 1, testLower);
    int c3 = CopyBuffer(g_dpcHandle, DPC_BUF_MID,   1, 1, testMid);

    if(c1 > 0 && c2 > 0 && c3 > 0 &&
       testUpper[0] > 0 && testLower[0] > 0 && testMid[0] > 0)
    {
        g_dpcConnected = true;
        CarnLog(LOG_SUCCESS, LOG_CAT_DPC, StringFormat("INDICATORE LETTO CORRETTAMENTE — Upper:%s | Lower:%s | Mid:%s",
                DoubleToString(testUpper[0], _Digits), DoubleToString(testLower[0], _Digits),
                DoubleToString(testMid[0], _Digits)));
        Alert("CARNEVAL: INDICATORE LETTO CORRETTAMENTE! ",
              "DonchianPredictiveChannel connesso. ",
              "Upper: ", DoubleToString(testUpper[0], _Digits),
              " | Lower: ", DoubleToString(testLower[0], _Digits),
              " | Mid: ", DoubleToString(testMid[0], _Digits));
    }
    else
    {
        CarnLogW(LOG_CAT_DPC, "Handle valido ma buffer non rispondono ancora");
        CarnLogD(LOG_CAT_DPC, StringFormat("CopyBuffer results — Upper:%d Lower:%d Mid:%d", c1, c2, c3));
        if(c1 > 0) CarnLogD(LOG_CAT_DPC, StringFormat("testUpper[0] = %s", DoubleToString(testUpper[0], _Digits)));
        if(c2 > 0) CarnLogD(LOG_CAT_DPC, StringFormat("testLower[0] = %s", DoubleToString(testLower[0], _Digits)));
        if(c3 > 0) CarnLogD(LOG_CAT_DPC, StringFormat("testMid[0] = %s", DoubleToString(testMid[0], _Digits)));
        Alert("CARNEVAL: INDICATORE TROVATO ma dati non ancora pronti. ",
              "L'EA ritentera' la lettura al primo tick. ",
              "Se persiste, verificare che l'indicatore sia compilato correttamente.");
    }

    return true;
}

//+------------------------------------------------------------------+
//| ReadDPCSignals — Lettura anti-repaint                            |
//| REGOLA ASSOLUTA: leggere SOLO barra [1] (chiusa e definitiva)    |
//| Barra [0] e' in formazione e puo' repaintare                    |
//+------------------------------------------------------------------+
bool ReadDPCSignals(bool &newBuySignal, bool &newSellSignal)
{
    newBuySignal = false;
    newSellSignal = false;

    double signalUp[], signalDn[];
    double upper[], lower[], mid[], midColor[], maValue[];
    ArrayResize(signalUp, 3);  ArrayResize(signalDn, 3);
    ArrayResize(upper, 2);     ArrayResize(lower, 2);
    ArrayResize(mid, 2);       ArrayResize(midColor, 2);
    ArrayResize(maValue, 2);

    ArraySetAsSeries(signalUp, true);
    ArraySetAsSeries(signalDn, true);
    ArraySetAsSeries(upper, true);
    ArraySetAsSeries(lower, true);
    ArraySetAsSeries(mid, true);
    ArraySetAsSeries(midColor, true);
    ArraySetAsSeries(maValue, true);

    int copiedSigUp = CopyBuffer(g_dpcHandle, DPC_BUF_SIGNAL_UP, 0, 3, signalUp);
    int copiedSigDn = CopyBuffer(g_dpcHandle, DPC_BUF_SIGNAL_DN, 0, 3, signalDn);
    int copiedUp    = CopyBuffer(g_dpcHandle, DPC_BUF_UPPER,     0, 2, upper);
    int copiedLo    = CopyBuffer(g_dpcHandle, DPC_BUF_LOWER,     0, 2, lower);
    int copiedMid   = CopyBuffer(g_dpcHandle, DPC_BUF_MID,       0, 2, mid);
    int copiedColor = CopyBuffer(g_dpcHandle, DPC_BUF_MID_COLOR, 0, 2, midColor);
    int copiedMA    = CopyBuffer(g_dpcHandle, DPC_BUF_MA,        0, 2, maValue);

    if(copiedSigUp < 3 || copiedSigDn < 3 || copiedUp < 2 ||
       copiedLo < 2 || copiedMid < 2)
    {
        CarnLogW(LOG_CAT_DPC, StringFormat("CopyBuffer failed — SigUp:%d SigDn:%d Up:%d Lo:%d Mid:%d",
                 copiedSigUp, copiedSigDn, copiedUp, copiedLo, copiedMid));
        return false;
    }

    // Aggiorna variabili globali con valori CONFERMATI (barra [1])
    g_dpcUpper = upper[1];
    g_dpcLower = lower[1];
    g_dpcMid   = mid[1];
    g_dpcMidColor = (int)midColor[1];
    g_dpcMA    = (copiedMA >= 2) ? maValue[1] : 0;
    g_dpcChannelWidth = PointsToPips(upper[1] - lower[1]);

    CarnLogD(LOG_CAT_DPC, StringFormat("Bar[1] — Upper=%s | Mid=%s | Lower=%s | Width=%.1fp | MA=%s",
             DoubleToString(g_dpcUpper, _Digits), DoubleToString(g_dpcMid, _Digits),
             DoubleToString(g_dpcLower, _Digits), g_dpcChannelWidth,
             DoubleToString(g_dpcMA, _Digits)));

    // === TRIGGER PRICE EXTRACTION ===
    g_dpcTriggerBuyPrice  = 0;
    g_dpcTriggerSellPrice = 0;
    if(signalUp[1] != EMPTY_VALUE && signalUp[1] != 0)
        g_dpcTriggerBuyPrice = signalUp[1];
    if(signalDn[1] != EMPTY_VALUE && signalDn[1] != 0)
        g_dpcTriggerSellPrice = signalDn[1];

    // ANTI-REPAINT
    bool sigUpOnBar1 = (signalUp[1] != EMPTY_VALUE && signalUp[1] != 0);
    bool sigUpOnBar2 = (signalUp[2] != EMPTY_VALUE && signalUp[2] != 0);
    bool sigDnOnBar1 = (signalDn[1] != EMPTY_VALUE && signalDn[1] != 0);
    bool sigDnOnBar2 = (signalDn[2] != EMPTY_VALUE && signalDn[2] != 0);

    newBuySignal  = (sigUpOnBar1 && !sigUpOnBar2);
    newSellSignal = (sigDnOnBar1 && !sigDnOnBar2);

    // DOPPIO CHECK: anti-duplicate sulla stessa barra
    datetime currentBar1Time = iTime(_Symbol, PERIOD_CURRENT, 1);

    if(newBuySignal && currentBar1Time == g_lastProcessedSignalBar)
    {
        CarnLogD(LOG_CAT_DPC, StringFormat("BUY duplicato IGNORATO (anti-repaint) — Bar=%s",
                 TimeToString(currentBar1Time, TIME_MINUTES)));
        newBuySignal = false;
    }
    if(newSellSignal && currentBar1Time == g_lastProcessedSignalBar)
    {
        CarnLogD(LOG_CAT_DPC, StringFormat("SELL duplicato IGNORATO (anti-repaint) — Bar=%s",
                 TimeToString(currentBar1Time, TIME_MINUTES)));
        newSellSignal = false;
    }

    if(newBuySignal || newSellSignal)
    {
        g_lastProcessedSignalBar = currentBar1Time;
    }

    // === DIAGNOSTIC LOG: ogni nuova barra, mostra stato buffer segnali ===
    // Permette di diagnosticare perche' segnali non vengono rilevati
    {
        string diagBuy = signalUp[1] == EMPTY_VALUE ? "EMPTY" : DoubleToString(signalUp[1], _Digits);
        string diagSell = signalDn[1] == EMPTY_VALUE ? "EMPTY" : DoubleToString(signalDn[1], _Digits);
        string diagBuy2 = signalUp[2] == EMPTY_VALUE ? "EMPTY" : DoubleToString(signalUp[2], _Digits);
        string diagSell2 = signalDn[2] == EMPTY_VALUE ? "EMPTY" : DoubleToString(signalDn[2], _Digits);

        if(sigUpOnBar1 || sigDnOnBar1)
        {
            // Segnale presente su bar[1] ma non rilevato come "nuovo" → mostra perche'
            CarnLogI(LOG_CAT_DPC, StringFormat("DIAG Bar[1]=%s | BUY:%s(bar2:%s) SELL:%s(bar2:%s) | New: BUY=%s SELL=%s",
                     TimeToString(currentBar1Time, TIME_MINUTES),
                     diagBuy, diagBuy2, diagSell, diagSell2,
                     newBuySignal ? "YES" : "no", newSellSignal ? "YES" : "no"));
            if(!newBuySignal && sigUpOnBar1)
                CarnLogW(LOG_CAT_DPC, StringFormat("BUY SIGNAL IGNORATO: presente anche su bar[2] (%s) — gia' processato o EA avviato dopo il segnale", diagBuy2));
            if(!newSellSignal && sigDnOnBar1)
                CarnLogW(LOG_CAT_DPC, StringFormat("SELL SIGNAL IGNORATO: presente anche su bar[2] (%s) — gia' processato o EA avviato dopo il segnale", diagSell2));
        }
        else
        {
            // Nessun segnale su bar[1] — log periodico (ogni 6 barre ~ 6h su H1)
            static int noSignalCount = 0;
            noSignalCount++;
            if(noSignalCount % 6 == 1)
                CarnLogD(LOG_CAT_DPC, StringFormat("DIAG no signal — Bar[1]=%s | BUY:%s SELL:%s | Barre senza segnale: %d",
                         TimeToString(currentBar1Time, TIME_MINUTES), diagBuy, diagSell, noSignalCount));
        }
    }

    // Log dettagliato — SEGNALE NUOVO
    if(DetailedLogging && (newBuySignal || newSellSignal))
    {
        string dir = newBuySignal ? "BUY" : "SELL";
        CarnLogI(LOG_CAT_DPC, StringFormat("=== NEW %s SIGNAL DETECTED ===", dir));
        CarnLogD(LOG_CAT_DPC, StringFormat("Bar[1] time: %s", TimeToString(currentBar1Time)));
        CarnLogD(LOG_CAT_DPC, StringFormat("Bands: Upper=%s | Lower=%s | Mid=%s",
                 DoubleToString(g_dpcUpper, _Digits), DoubleToString(g_dpcLower, _Digits),
                 DoubleToString(g_dpcMid, _Digits)));
        CarnLogD(LOG_CAT_DPC, StringFormat("Channel Width: %.1f pips", g_dpcChannelWidth));
        CarnLogD(LOG_CAT_DPC, StringFormat("Mid Trend: %s", g_dpcMidColor == 0 ? "BULLISH" : "BEARISH"));
        CarnLogD(LOG_CAT_DPC, StringFormat("Raw Buffers: sigUp[1]=%s sigUp[2]=%s | sigDn[1]=%s sigDn[2]=%s",
                 signalUp[1] == EMPTY_VALUE ? "EMPTY" : DoubleToString(signalUp[1], _Digits),
                 signalUp[2] == EMPTY_VALUE ? "EMPTY" : DoubleToString(signalUp[2], _Digits),
                 signalDn[1] == EMPTY_VALUE ? "EMPTY" : DoubleToString(signalDn[1], _Digits),
                 signalDn[2] == EMPTY_VALUE ? "EMPTY" : DoubleToString(signalDn[2], _Digits)));
        CarnLogD(LOG_CAT_DPC, StringFormat("Anti-repaint: sigUpBar1=%s sigUpBar2=%s | sigDnBar1=%s sigDnBar2=%s",
                 sigUpOnBar1 ? "true" : "false", sigUpOnBar2 ? "true" : "false",
                 sigDnOnBar1 ? "true" : "false", sigDnOnBar2 ? "true" : "false"));
        if(TradingMode == MODE_TRIGGER_INDICATOR)
        {
            CarnLogD(LOG_CAT_DPC, "MODE: TRIGGER INDICATOR");
            CarnLogD(LOG_CAT_DPC, StringFormat("Trigger BUY (buf7): %s | Dist from Lower: %s",
                     g_dpcTriggerBuyPrice > 0 ? DoubleToString(g_dpcTriggerBuyPrice, _Digits) : "NONE",
                     g_dpcTriggerBuyPrice > 0 ? DoubleToString(PointsToPips(g_dpcTriggerBuyPrice - g_dpcLower), 1) + "p" : "N/A"));
            CarnLogD(LOG_CAT_DPC, StringFormat("Trigger SELL (buf8): %s | Dist from Upper: %s",
                     g_dpcTriggerSellPrice > 0 ? DoubleToString(g_dpcTriggerSellPrice, _Digits) : "NONE",
                     g_dpcTriggerSellPrice > 0 ? DoubleToString(PointsToPips(g_dpcUpper - g_dpcTriggerSellPrice), 1) + "p" : "N/A"));
            CarnLogD(LOG_CAT_DPC, StringFormat("Current: Ask=%s | Bid=%s | Spread=%.1fp",
                     DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits),
                     DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits),
                     GetSpreadPips()));
        }
        else
        {
            CarnLogD(LOG_CAT_DPC, "MODE: CLASSIC TURTLE SOUP");
        }
    }

    // Log buffer DPC se abilitato (periodico ogni 5 min)
    if(LogDPCBuffers)
    {
        static datetime lastBufferLog = 0;
        if(TimeCurrent() - lastBufferLog > 300)
        {
            lastBufferLog = TimeCurrent();
            CarnLogD(LOG_CAT_DPC, StringFormat("BUF Upper:%s Lower:%s Mid:%s Width:%.1fp Trend:%s",
                     DoubleToString(g_dpcUpper, _Digits), DoubleToString(g_dpcLower, _Digits),
                     DoubleToString(g_dpcMid, _Digits), g_dpcChannelWidth,
                     g_dpcMidColor == 0 ? "BULL" : "BEAR"));
            if(TradingMode == MODE_TRIGGER_INDICATOR)
            {
                CarnLogD(LOG_CAT_DPC, StringFormat("BUF TrigBuy(buf7):%s TrigSell(buf8):%s",
                         g_dpcTriggerBuyPrice > 0 ? DoubleToString(g_dpcTriggerBuyPrice, _Digits) : "NONE",
                         g_dpcTriggerSellPrice > 0 ? DoubleToString(g_dpcTriggerSellPrice, _Digits) : "NONE"));
            }
        }
    }

    return true;
}

//+------------------------------------------------------------------+
//| ReadTouchTrigger_Intrabar — Lettura Buffer 18 ad ogni tick       |
//+------------------------------------------------------------------+
bool ReadTouchTrigger_Intrabar(int &triggerDirection)
{
    triggerDirection = 0;

    if(g_dpcHandle == INVALID_HANDLE || !g_dpcConnected)
        return false;

    double touchBuf[];
    ArrayResize(touchBuf, 1);
    ArraySetAsSeries(touchBuf, true);

    int copied = CopyBuffer(g_dpcHandle, DPC_BUF_TOUCH_TRIGGER, 0, 1, touchBuf);
    if(copied < 1)
        return false;

    double val = touchBuf[0];

    if(val == EMPTY_VALUE || val == 0)
    {
        g_touchTriggerValue = 0;
        return true;
    }

    int dir = (val > 0) ? +1 : -1;
    g_touchTriggerValue = dir;

    // Anti-duplicate
    datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
    if(currentBarTime == g_lastTouchTriggerBar && dir == g_touchTriggerDirection)
        return true;

    g_lastTouchTriggerBar = currentBarTime;
    g_touchTriggerDirection = dir;
    g_touchTriggerPendingConfirm = true;
    triggerDirection = dir;

    if(DetailedLogging)
    {
        CarnLogD(LOG_CAT_DPC, StringFormat("TOUCH_TRIGGER INTRABAR: %s | Bar[0]=%s | Buf18=%.2f | Attesa conferma...",
                 dir > 0 ? "BUY" : "SELL", TimeToString(currentBarTime, TIME_MINUTES), val));
    }

    return true;
}

//+------------------------------------------------------------------+
//| CheckTouchTriggerConfirmation — Chiamata a nuova barra           |
//+------------------------------------------------------------------+
bool CheckTouchTriggerConfirmation(bool barSignalUp, bool barSignalDn)
{
    if(!g_touchTriggerPendingConfirm)
        return false;

    g_touchTriggerPendingConfirm = false;

    bool confirmed = false;
    if(g_touchTriggerDirection > 0 && barSignalUp)
        confirmed = true;
    else if(g_touchTriggerDirection < 0 && barSignalDn)
        confirmed = true;

    if(DetailedLogging)
    {
        if(confirmed)
        {
            CarnLogD(LOG_CAT_DPC, StringFormat("TOUCH_TRIGGER CONFERMATO — Dir=%s",
                     g_touchTriggerDirection > 0 ? "BUY" : "SELL"));
        }
        else
        {
            CarnLogD(LOG_CAT_DPC, StringFormat("TOUCH_TRIGGER NON CONFERMATO — Dir=%s sigUp=%s sigDn=%s",
                     g_touchTriggerDirection > 0 ? "BUY" : "SELL",
                     barSignalUp ? "true" : "false", barSignalDn ? "true" : "false"));
        }
    }

    return confirmed;
}

//+------------------------------------------------------------------+
//| CheckDPCHealth — Verifica oraria connessione indicatore          |
//+------------------------------------------------------------------+
void CheckDPCHealth()
{
    if(TimeCurrent() - g_lastDPCHealthCheck < 3600)
        return;

    g_lastDPCHealthCheck = TimeCurrent();

    if(g_dpcHandle == INVALID_HANDLE)
    {
        g_dpcConnected = false;
        g_dpcHealthFailures++;
        CarnLogE(LOG_CAT_DPC, "HEALTH: Handle INVALID!");
        Alert("CARNEVAL: INDICATORE PERSO! Handle DPC invalido. Riavviare l'EA.");
        return;
    }

    double testUpper[], testLower[], testMid[];
    ArrayResize(testUpper, 1);
    ArrayResize(testLower, 1);
    ArrayResize(testMid, 1);
    ArraySetAsSeries(testUpper, true);
    ArraySetAsSeries(testLower, true);
    ArraySetAsSeries(testMid, true);

    int c1 = CopyBuffer(g_dpcHandle, DPC_BUF_UPPER, 1, 1, testUpper);
    int c2 = CopyBuffer(g_dpcHandle, DPC_BUF_LOWER, 1, 1, testLower);
    int c3 = CopyBuffer(g_dpcHandle, DPC_BUF_MID,   1, 1, testMid);

    if(c1 > 0 && c2 > 0 && c3 > 0 &&
       testUpper[0] > 0 && testLower[0] > 0 && testMid[0] > 0 &&
       testUpper[0] != EMPTY_VALUE)
    {
        g_dpcConnected = true;
        g_dpcHealthFailures = 0;
        CarnLogI(LOG_CAT_DPC, StringFormat("HEALTH OK — Upper:%s | Lower:%s | Mid:%s | Width:%.1fp",
                 DoubleToString(testUpper[0], _Digits), DoubleToString(testLower[0], _Digits),
                 DoubleToString(testMid[0], _Digits),
                 PointsToPips(testUpper[0] - testLower[0])));
    }
    else
    {
        g_dpcHealthFailures++;
        CarnLogW(LOG_CAT_DPC, StringFormat("HEALTH CHECK FAILED! Failures: %d", g_dpcHealthFailures));
        if(g_dpcHealthFailures >= 3)
        {
            g_dpcConnected = false;
            CarnLogE(LOG_CAT_DPC, "DPC DISCONNECTED — 3+ consecutive failures");
            Alert("CARNEVAL: INDICATORE DISCONNESSO! ",
                  "3 health check falliti consecutivi. ",
                  "Verificare che DonchianPredictiveChannel sia ancora attivo.");
        }
    }
}

//+------------------------------------------------------------------+
//| UpdateSignalCounter — Incrementa contatori segnali               |
//+------------------------------------------------------------------+
void UpdateSignalCounter(int direction)
{
    g_totalSignals++;
    if(direction > 0) g_buySignals++;
    else g_sellSignals++;
    g_lastSignalTime = TimeCurrent();
    g_lastSignalDirection = (direction > 0) ? "BUY" : "SELL";

    CarnLogI(LOG_CAT_DPC, StringFormat("SIGNAL %s #%d", g_lastSignalDirection, g_totalSignals));
}
