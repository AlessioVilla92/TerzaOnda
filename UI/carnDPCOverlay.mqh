//+------------------------------------------------------------------+
//|                                         carnDPCOverlay.mqh       |
//|           Carneval EA v3.40 - DPC Channel Overlay                 |
//|                                                                  |
//|  Visualizzazione grafica del DPC Engine sul chart:                |
//|    - Canale Donchian storico a "scalini" (N barre)                |
//|    - Midline con colore bull/bear per segmento                    |
//|    - MA filtro (lavanda, solo se DPC_SignalFilter=ON)             |
//|    - Frecce segnale BUY/SELL (solo a barra chiusa)                |
//|    - Label "TRIGGER BUY/SELL" con prezzo entry                    |
//|                                                                  |
//|  Dati calcolati da ComputeDonchianBands() per ogni barra.         |
//|  Segnali letti da g_dpcTriggerBuyPrice/SellPrice.                 |
//|                                                                  |
//|  Funziona in QUALSIASI stato EA (IDLE/ACTIVE/PAUSED).             |
//+------------------------------------------------------------------+
#property copyright "Sugamara Ribelle (C) 2026"

//+------------------------------------------------------------------+
//| COSTANTI E STATO OVERLAY                                          |
//+------------------------------------------------------------------+
#define OVL_PREFIX          "CARN_OVL_"
#define OVL_CH_PREFIX       "CARN_OVL_CH_"
#define OVL_MAX_SIGNALS     200

datetime g_ovlLastSignalBar = 0;
int      g_ovlSignalCount   = 0;
int      g_ovlLastDepth     = 0;       // Profondita' effettiva ultimo disegno

#define OVL_FC_PREFIX       "CARN_OVL_FC_"

// Arrays per slope calculation (salvati da ComputeAndDrawChannel)
double   g_ovlMidValues[];
double   g_ovlRangeValues[];
int      g_ovlMidRangeCount = 0;

//+------------------------------------------------------------------+
//| IsNewBarOverlay — Detection nuova barra INDIPENDENTE              |
//| Separata da IsNewBar() per non interferire con trading logic      |
//+------------------------------------------------------------------+
bool IsNewBarOverlay()
{
    static datetime lastBar = 0;
    datetime cur = iTime(_Symbol, PERIOD_CURRENT, 0);
    if(cur == lastBar) return false;
    lastBar = cur;
    return true;
}

//+------------------------------------------------------------------+
//| DrawChannelSegment — Crea o aggiorna un segmento OBJ_TREND       |
//| Se l'oggetto esiste gia', aggiorna coordinate e colore.           |
//| Se non esiste, lo crea con tutte le proprieta'.                   |
//+------------------------------------------------------------------+
void DrawChannelSegment(string name, datetime t1, double p1,
                        datetime t2, double p2,
                        color clr, int width, int style)
{
    if(ObjectFind(0, name) < 0)
    {
        ObjectCreate(0, name, OBJ_TREND, 0, t1, p1, t2, p2);
        ObjectSetInteger(0, name, OBJPROP_RAY_LEFT, false);
        ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
        ObjectSetInteger(0, name, OBJPROP_BACK, true);
        ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
        ObjectSetInteger(0, name, OBJPROP_ZORDER, 50);
    }

    // Aggiorna coordinate (spostate ad ogni nuova barra)
    ObjectSetInteger(0, name, OBJPROP_TIME, 0, t1);
    ObjectSetDouble(0, name, OBJPROP_PRICE, 0, p1);
    ObjectSetInteger(0, name, OBJPROP_TIME, 1, t2);
    ObjectSetDouble(0, name, OBJPROP_PRICE, 1, p2);

    // Aggiorna stile (midline cambia colore)
    ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
    ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
    ObjectSetInteger(0, name, OBJPROP_STYLE, style);
}

//+------------------------------------------------------------------+
//| ComputeAndDrawChannel — Calcola e disegna canale storico          |
//| Chiamata ad ogni nuova barra. Calcola bande per bar[0..DEPTH],    |
//| poi disegna segmenti OBJ_TREND collegando punti adiacenti.        |
//| Se DPC_SignalFilter=ON, disegna anche la linea MA.                |
//+------------------------------------------------------------------+
void ComputeAndDrawChannel()
{
    if(!g_dpcEngineReady) return;

    int depth = DPC_OverlayDepth;
    if(depth <= 0) return;

    // Limita alla quantita' di barre disponibili
    int totalBars = Bars(_Symbol, PERIOD_CURRENT);
    if(depth > totalBars - DPC_Period - 5)
        depth = totalBars - DPC_Period - 5;
    if(depth < 2) return;

    // Se la profondita' e' diminuita, pulisci segmenti extra
    if(g_ovlLastDepth > depth)
    {
        for(int i = depth; i < g_ovlLastDepth; i++)
        {
            ObjectDelete(0, StringFormat("CARN_OVL_CH_U_%d", i));
            ObjectDelete(0, StringFormat("CARN_OVL_CH_L_%d", i));
            ObjectDelete(0, StringFormat("CARN_OVL_CH_M_%d", i));
            ObjectDelete(0, StringFormat("CARN_OVL_CH_MA_%d", i));
        }
    }
    g_ovlLastDepth = depth;

    // === STEP 1: Calcola valori per tutti i punti ===
    double upper[], lower[], mid[], maVal[];
    int    midColor[];
    datetime barTime[];
    int points = depth + 1;

    ArrayResize(upper, points);
    ArrayResize(lower, points);
    ArrayResize(mid, points);
    ArrayResize(midColor, points);
    ArrayResize(barTime, points);
    ArrayResize(maVal, points);

    for(int i = 0; i < points; i++)
    {
        ComputeDonchianBands(i, DPC_Period, upper[i], lower[i], mid[i]);
        midColor[i] = GetMidlineColor(i);
        barTime[i] = iTime(_Symbol, PERIOD_CURRENT, i);

        if(DPC_SignalFilter)
            maVal[i] = GetDPCMAValue(i);
    }

    // === STEP 2: Disegna segmenti ===
    for(int i = 0; i < depth; i++)
    {
        // Ogni segmento collega bar[i+1] (piu' vecchia) a bar[i] (piu' recente)
        datetime tOld = barTime[i + 1];
        datetime tNew = barTime[i];

        // [v3.4] Bande colorate in base al trend mid corrente
        color bandClr = (midColor[i] == 0) ? C'60,180,60' : C'200,80,80';
        // Bullish = verde, Bearish = rosso per entrambe le bande

        DrawChannelSegment(
            StringFormat("CARN_OVL_CH_U_%d", i),
            tOld, upper[i + 1], tNew, upper[i],
            bandClr, OVL_CHANNEL_WIDTH, OVL_CHANNEL_STYLE);

        DrawChannelSegment(
            StringFormat("CARN_OVL_CH_L_%d", i),
            tOld, lower[i + 1], tNew, lower[i],
            bandClr, OVL_CHANNEL_WIDTH, OVL_CHANNEL_STYLE);

        // Midline — colore bull/bear per segmento, punteggiata
        color mClr = (midColor[i] == 0) ? OVL_MID_BULL_COLOR : OVL_MID_BEAR_COLOR;
        DrawChannelSegment(
            StringFormat("CARN_OVL_CH_M_%d", i),
            tOld, mid[i + 1], tNew, mid[i],
            mClr, OVL_MID_WIDTH, OVL_MID_STYLE);

        // MA filtro — lavanda, punteggiata (solo se filtro attivo)
        if(DPC_SignalFilter && maVal[i] > 0 && maVal[i + 1] > 0)
        {
            DrawChannelSegment(
                StringFormat("CARN_OVL_CH_MA_%d", i),
                tOld, maVal[i + 1], tNew, maVal[i],
                OVL_MA_COLOR, OVL_MA_WIDTH, OVL_MA_STYLE);
        }
    }

    // === STEP 3: Salva mid[] e range[] per forecast slope ===
    g_ovlMidRangeCount = points;
    ArrayResize(g_ovlMidValues, points);
    ArrayResize(g_ovlRangeValues, points);
    for(int i = 0; i < points; i++)
    {
        g_ovlMidValues[i] = mid[i];
        g_ovlRangeValues[i] = upper[i] - lower[i];
    }

    CarnLogD(LOG_CAT_UI, StringFormat("Channel drawn: %d segments | Mid[0]=%s | Range[0]=%.1fp",
             depth, DoubleToString(mid[0], _Digits), PointsToPips(upper[0] - lower[0])));

    // Disegna forecast projection
    DrawOverlayForecast();
}

//+------------------------------------------------------------------+
//| UpdateChannelLiveEdge — Aggiorna solo il bordo live (bar[0])      |
//| Chiamata ogni 500ms. Aggiorna SOLO il segmento index=0 che       |
//| collega bar[1] a bar[0] con i valori correnti del DPC Engine.     |
//+------------------------------------------------------------------+
void UpdateChannelLiveEdge()
{
    if(!g_dpcEngineReady) return;
    if(DPC_OverlayDepth <= 0) return;
    if(g_dpcUpper <= 0 || g_dpcLower <= 0 || g_dpcMid <= 0) return;

    // Il segmento index=0 ha estremo destro = bar[0]
    // Aggiorna solo il punto finale (bar[0]) con valori live
    datetime t0 = iTime(_Symbol, PERIOD_CURRENT, 0);

    string nameU = "CARN_OVL_CH_U_0";
    if(ObjectFind(0, nameU) >= 0)
    {
        ObjectSetInteger(0, nameU, OBJPROP_TIME, 1, t0);
        ObjectSetDouble(0, nameU, OBJPROP_PRICE, 1, g_dpcUpper);
    }

    string nameL = "CARN_OVL_CH_L_0";
    if(ObjectFind(0, nameL) >= 0)
    {
        ObjectSetInteger(0, nameL, OBJPROP_TIME, 1, t0);
        ObjectSetDouble(0, nameL, OBJPROP_PRICE, 1, g_dpcLower);
    }

    string nameM = "CARN_OVL_CH_M_0";
    if(ObjectFind(0, nameM) >= 0)
    {
        ObjectSetInteger(0, nameM, OBJPROP_TIME, 1, t0);
        ObjectSetDouble(0, nameM, OBJPROP_PRICE, 1, g_dpcMid);
        color mClr = (g_dpcMidColor == 0) ? OVL_MID_BULL_COLOR : OVL_MID_BEAR_COLOR;
        ObjectSetInteger(0, nameM, OBJPROP_COLOR, mClr);
    }

    if(DPC_SignalFilter && g_dpcMA > 0)
    {
        string nameMA = "CARN_OVL_CH_MA_0";
        if(ObjectFind(0, nameMA) >= 0)
        {
            ObjectSetInteger(0, nameMA, OBJPROP_TIME, 1, t0);
            ObjectSetDouble(0, nameMA, OBJPROP_PRICE, 1, g_dpcMA);
        }
    }
}

//+------------------------------------------------------------------+
//| InitDPCOverlay — Calcolo iniziale canale + reset segnali          |
//| Chiamata in OnInit dopo InitializeDPCEngine success               |
//+------------------------------------------------------------------+
void InitDPCOverlay()
{
    g_ovlSignalCount = 0;
    g_ovlLastSignalBar = 0;
    g_ovlLastDepth = 0;

    // Disegna canale storico iniziale
    ComputeAndDrawChannel();

    CarnLogI(LOG_CAT_UI, StringFormat("DPC Overlay initialized (depth=%d, MA=%s)",
             DPC_OverlayDepth, DPC_SignalFilter ? "ON" : "OFF"));
}

//+------------------------------------------------------------------+
//| CheckDPCOverlaySignals — Rileva segnali e disegna frecce/labels   |
//| Anti-repaint INDIPENDENTE: legge solo bar[1] confermata           |
//| Chiamata ad ogni nuova barra, funziona in QUALSIASI stato         |
//+------------------------------------------------------------------+
void CheckDPCOverlaySignals()
{
    if(!g_dpcEngineReady) return;

    // Legge trigger prices dalle variabili globali (popolate da CalculateDPC)
    bool newBuy  = (g_dpcTriggerBuyPrice > 0);
    bool newSell = (g_dpcTriggerSellPrice > 0);

    if(!newBuy && !newSell) return;

    // Anti-duplicato
    datetime barTime = iTime(_Symbol, PERIOD_CURRENT, 1);
    if(barTime == g_ovlLastSignalBar) return;
    g_ovlLastSignalBar = barTime;

    // Disegna freccia + label + entry dot
    if(newBuy)
    {
        double price = g_dpcTriggerBuyPrice;
        DrawOverlayArrow(price, barTime, true);
        DrawOverlayLabel(price, barTime, true);
        DrawEntryDot(g_dpcLower, barTime, true);
        g_ovlSignalCount++;

        CarnLogI(LOG_CAT_UI, StringFormat("OVL BUY arrow @ %s | Dot @ Lower=%s | Bar=%s | Signals=%d",
                 DoubleToString(price, _Digits), DoubleToString(g_dpcLower, _Digits),
                 TimeToString(barTime, TIME_MINUTES), g_ovlSignalCount));
    }
    if(newSell)
    {
        double price = g_dpcTriggerSellPrice;
        DrawOverlayArrow(price, barTime, false);
        DrawOverlayLabel(price, barTime, false);
        DrawEntryDot(g_dpcUpper, barTime, false);
        g_ovlSignalCount++;

        CarnLogI(LOG_CAT_UI, StringFormat("OVL SELL arrow @ %s | Dot @ Upper=%s | Bar=%s | Signals=%d",
                 DoubleToString(price, _Digits), DoubleToString(g_dpcUpper, _Digits),
                 TimeToString(barTime, TIME_MINUTES), g_ovlSignalCount));
    }

    // Pruning: limita numero oggetti segnale
    if(g_ovlSignalCount > OVL_MAX_SIGNALS)
        PruneOverlaySignals();
}

//+------------------------------------------------------------------+
//| DrawOverlayArrow — Freccia segnale DPC                            |
//+------------------------------------------------------------------+
void DrawOverlayArrow(double price, datetime time, bool isBuy)
{
    string name = StringFormat("CARN_OVL_SIG_%s_%s",
                  isBuy ? "BUY" : "SELL",
                  TimeToString(time, TIME_DATE|TIME_MINUTES));

    int arrowCode = isBuy ? 233 : 234;

    ObjectCreate(0, name, OBJ_ARROW, 0, time, price);
    ObjectSetInteger(0, name, OBJPROP_ARROWCODE, arrowCode);
    ObjectSetInteger(0, name, OBJPROP_COLOR, isBuy ? OVL_SIGNAL_BUY_COLOR : OVL_SIGNAL_SELL_COLOR);
    ObjectSetInteger(0, name, OBJPROP_WIDTH, OVL_ARROW_SIZE);
    ObjectSetInteger(0, name, OBJPROP_ANCHOR, isBuy ? ANCHOR_TOP : ANCHOR_BOTTOM);
    ObjectSetInteger(0, name, OBJPROP_BACK, false);
    ObjectSetInteger(0, name, OBJPROP_ZORDER, 400);
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);

    ObjectSetString(0, name, OBJPROP_TOOLTIP,
        StringFormat("DPC %s Signal | %s | %s",
                     isBuy ? "BUY" : "SELL",
                     DoubleToString(price, _Digits),
                     TimeToString(time, TIME_MINUTES)));
}

//+------------------------------------------------------------------+
//| DrawOverlayLabel — Testo "TRIGGER BUY/SELL" vicino alla freccia   |
//+------------------------------------------------------------------+
void DrawOverlayLabel(double price, datetime time, bool isBuy)
{
    string name = StringFormat("CARN_OVL_LBL_%s_%s",
                  isBuy ? "BUY" : "SELL",
                  TimeToString(time, TIME_DATE|TIME_MINUTES));

    string text = isBuy ? "TRIGGER BUY" : "TRIGGER SELL";
    color  clr  = isBuy ? OVL_SIGNAL_BUY_COLOR : OVL_SIGNAL_SELL_COLOR;

    // OBJ_TEXT: ancorato a price/time (si muove col grafico)
    ObjectCreate(0, name, OBJ_TEXT, 0, time, price);
    ObjectSetString(0, name, OBJPROP_TEXT, text);
    ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
    ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
    ObjectSetInteger(0, name, OBJPROP_FONTSIZE, OVL_LABEL_FONT_SIZE);
    ObjectSetInteger(0, name, OBJPROP_ANCHOR,
        isBuy ? ANCHOR_LEFT_UPPER : ANCHOR_LEFT_LOWER);
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
}

//+------------------------------------------------------------------+
//| PruneOverlaySignals — Rimuove segnali piu' vecchi                 |
//| Mantiene max OVL_MAX_SIGNALS oggetti freccia+label               |
//+------------------------------------------------------------------+
void PruneOverlaySignals()
{
    // Conta e rimuovi i piu' vecchi (quelli con timestamp minore)
    int totalSig = ObjectsTotal(0, 0, OBJ_ARROW);
    int removed = 0;

    for(int i = totalSig - 1; i >= 0 && removed < 50; i--)
    {
        string objName = ObjectName(0, i, 0, OBJ_ARROW);
        // Prendi solo gli oggetti overlay signal (non trigger arrows)
        if(StringFind(objName, "CARN_OVL_SIG_") == 0)
        {
            // Rimuovi anche label + entry dot corrispondenti
            string lblName = objName;
            StringReplace(lblName, "CARN_OVL_SIG_", "CARN_OVL_LBL_");
            string dotName = objName;
            StringReplace(dotName, "CARN_OVL_SIG_", "CARN_OVL_DOT_");
            ObjectDelete(0, objName);
            ObjectDelete(0, lblName);
            ObjectDelete(0, dotName);
            removed++;
        }
    }

    g_ovlSignalCount -= removed;
    if(g_ovlSignalCount < 0) g_ovlSignalCount = 0;

    CarnLogI(LOG_CAT_UI, StringFormat("OVL pruned %d old signals (arrows+labels+dots) | Remaining: %d/%d",
             removed, g_ovlSignalCount, OVL_MAX_SIGNALS));
}

//+------------------------------------------------------------------+
//| LinearRegressionSlope_OVL — Slope regressione lineare             |
//| Portata da DonchianPredictiveChannel v7.18                        |
//+------------------------------------------------------------------+
double LinearRegressionSlope_OVL(const double &src[], int bar, int length)
{
    int total = ArraySize(src);
    if(bar + length > total) return 0.0;

    double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
    int n = length;

    for(int k = 0; k < n; k++)
    {
        double x = (double)(n - 1 - k);
        double y = src[bar + k];
        sumX  += x;
        sumY  += y;
        sumXY += x * y;
        sumX2 += x * x;
    }

    double denom = (n * sumX2 - sumX * sumX);
    if(MathAbs(denom) < 1e-10) return 0.0;

    return (n * sumXY - sumX * sumY) / denom;
}

//+------------------------------------------------------------------+
//| GenerateForecastPoints_OVL — Genera punti proiezione              |
//| Portata da DonchianPredictiveChannel v7.18                        |
//+------------------------------------------------------------------+
void GenerateForecastPoints_OVL(double hi0, double md0, double lo0,
                                int steps, double midSlp, double rngSlp,
                                double &hiPts[], double &mdPts[], double &loPts[])
{
    ArrayResize(hiPts, steps + 1);
    ArrayResize(mdPts, steps + 1);
    ArrayResize(loPts, steps + 1);

    double curHi  = hi0;
    double curLo  = lo0;
    double curMid = md0;

    int segBars = (int)MathFloor(steps / 3.0);
    if(segBars < 1) segBars = 1;

    for(int b = 0; b <= steps; b++)
    {
        double mdProj    = md0 + midSlp * b;
        double prevRange = curHi - curLo;
        double rngProj   = prevRange + rngSlp * b;

        double hiTemp, loTemp;
        if(midSlp >= 0)
        {
            hiTemp = MathMax(curHi, mdProj + rngProj * 0.5);
            loTemp = MathMax(curLo, mdProj - rngProj * 0.5);
        }
        else
        {
            hiTemp = MathMin(curHi, mdProj + rngProj * 0.5);
            loTemp = MathMin(curLo, mdProj - rngProj * 0.5);
        }

        double hiProj = (hiTemp < mdProj) ? curHi : hiTemp;
        double loProj = (loTemp > mdProj) ? curLo : loTemp;

        if(b % segBars == 0)
        {
            curHi  = hiProj;
            curLo  = loProj;
            curMid = mdProj;
        }

        hiPts[b] = curHi;
        mdPts[b] = curMid;
        loPts[b] = curLo;
    }
}

//+------------------------------------------------------------------+
//| DrawOverlayForecast — Disegna proiezione forecast nel futuro      |
//| Upper/Lower dashed + Midline dotted, con price labels endpoint    |
//| Portata da DonchianPredictiveChannel v7.18                        |
//+------------------------------------------------------------------+
void DrawOverlayForecast()
{
    DeleteOverlayForecast();

    if(g_ovlMidRangeCount < DPC_Period || DPC_Period < 2)
    {
        CarnLogD(LOG_CAT_UI, StringFormat("FORECAST skipped: data=%d < period=%d",
                 g_ovlMidRangeCount, DPC_Period));
        return;
    }

    // Slope della midline e del range
    int slopeLen = (int)MathMin(DPC_Period, g_ovlMidRangeCount);
    double midSlope = LinearRegressionSlope_OVL(g_ovlMidValues, 0, slopeLen);
    double rngSlope = LinearRegressionSlope_OVL(g_ovlRangeValues, 0, slopeLen);

    // Valori correnti (bar[0])
    double hi0 = g_dpcUpper;
    double md0 = g_dpcMid;
    double lo0 = g_dpcLower;
    if(hi0 <= 0 || lo0 <= 0 || md0 <= 0)
    {
        CarnLogD(LOG_CAT_UI, "FORECAST skipped: DPC bands not ready");
        return;
    }

    // Genera punti forecast
    int steps = OVL_FORECAST_BARS;
    double hiPts[], mdPts[], loPts[];
    GenerateForecastPoints_OVL(hi0, md0, lo0, steps, midSlope, rngSlope,
                               hiPts, mdPts, loPts);

    datetime lastBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
    int periodSec = PeriodSeconds(PERIOD_CURRENT);

    // Colore midline forecast in base allo slope
    color midFcColor = (midSlope > 0) ? OVL_MID_BULL_COLOR :
                       (midSlope < 0) ? OVL_MID_BEAR_COLOR : clrGray;

    // Disegna segmenti trend tra punti consecutivi
    for(int b = 0; b < steps; b++)
    {
        datetime t1 = lastBarTime + b * periodSec;
        datetime t2 = lastBarTime + (b + 1) * periodSec;

        // Upper forecast (dashed verde)
        string nameHi = OVL_FC_PREFIX + "HI_" + IntegerToString(b);
        ObjectCreate(0, nameHi, OBJ_TREND, 0, t1, hiPts[b], t2, hiPts[b + 1]);
        ObjectSetInteger(0, nameHi, OBJPROP_COLOR, OVL_FORECAST_UP_COLOR);
        ObjectSetInteger(0, nameHi, OBJPROP_WIDTH, OVL_FORECAST_WIDTH);
        ObjectSetInteger(0, nameHi, OBJPROP_STYLE, STYLE_DASH);
        ObjectSetInteger(0, nameHi, OBJPROP_RAY_RIGHT, false);
        ObjectSetInteger(0, nameHi, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, nameHi, OBJPROP_HIDDEN, true);
        ObjectSetInteger(0, nameHi, OBJPROP_BACK, false);

        // Lower forecast (dashed rosso)
        string nameLo = OVL_FC_PREFIX + "LO_" + IntegerToString(b);
        ObjectCreate(0, nameLo, OBJ_TREND, 0, t1, loPts[b], t2, loPts[b + 1]);
        ObjectSetInteger(0, nameLo, OBJPROP_COLOR, OVL_FORECAST_DN_COLOR);
        ObjectSetInteger(0, nameLo, OBJPROP_WIDTH, OVL_FORECAST_WIDTH);
        ObjectSetInteger(0, nameLo, OBJPROP_STYLE, STYLE_DASH);
        ObjectSetInteger(0, nameLo, OBJPROP_RAY_RIGHT, false);
        ObjectSetInteger(0, nameLo, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, nameLo, OBJPROP_HIDDEN, true);
        ObjectSetInteger(0, nameLo, OBJPROP_BACK, false);

        // Midline forecast (dotted)
        string nameMd = OVL_FC_PREFIX + "MD_" + IntegerToString(b);
        ObjectCreate(0, nameMd, OBJ_TREND, 0, t1, mdPts[b], t2, mdPts[b + 1]);
        ObjectSetInteger(0, nameMd, OBJPROP_COLOR, midFcColor);
        ObjectSetInteger(0, nameMd, OBJPROP_WIDTH, OVL_FORECAST_WIDTH);
        ObjectSetInteger(0, nameMd, OBJPROP_STYLE, STYLE_DOT);
        ObjectSetInteger(0, nameMd, OBJPROP_RAY_RIGHT, false);
        ObjectSetInteger(0, nameMd, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, nameMd, OBJPROP_HIDDEN, true);
        ObjectSetInteger(0, nameMd, OBJPROP_BACK, false);
    }

    // Price labels agli endpoint
    datetime endTime = lastBarTime + steps * periodSec;

    string labelHi = OVL_FC_PREFIX + "LABEL_HI";
    ObjectCreate(0, labelHi, OBJ_TEXT, 0, endTime, hiPts[steps]);
    ObjectSetString(0, labelHi, OBJPROP_TEXT, " " + DoubleToString(hiPts[steps], _Digits));
    ObjectSetInteger(0, labelHi, OBJPROP_COLOR, THEME_CHART_FOREGROUND);
    ObjectSetInteger(0, labelHi, OBJPROP_FONTSIZE, 8);
    ObjectSetInteger(0, labelHi, OBJPROP_ANCHOR, ANCHOR_LEFT);
    ObjectSetInteger(0, labelHi, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, labelHi, OBJPROP_HIDDEN, true);

    string labelLo = OVL_FC_PREFIX + "LABEL_LO";
    ObjectCreate(0, labelLo, OBJ_TEXT, 0, endTime, loPts[steps]);
    ObjectSetString(0, labelLo, OBJPROP_TEXT, " " + DoubleToString(loPts[steps], _Digits));
    ObjectSetInteger(0, labelLo, OBJPROP_COLOR, THEME_CHART_FOREGROUND);
    ObjectSetInteger(0, labelLo, OBJPROP_FONTSIZE, 8);
    ObjectSetInteger(0, labelLo, OBJPROP_ANCHOR, ANCHOR_LEFT);
    ObjectSetInteger(0, labelLo, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, labelLo, OBJPROP_HIDDEN, true);

    CarnLogD(LOG_CAT_UI, StringFormat("FORECAST drawn: %d bars | MidSlope=%.6f | RngSlope=%.6f | Hi=%s->%s | Lo=%s->%s",
             steps, midSlope, rngSlope,
             DoubleToString(hi0, _Digits), DoubleToString(hiPts[steps], _Digits),
             DoubleToString(lo0, _Digits), DoubleToString(loPts[steps], _Digits)));
}

//+------------------------------------------------------------------+
//| DeleteOverlayForecast — Rimuove tutti gli oggetti forecast        |
//+------------------------------------------------------------------+
void DeleteOverlayForecast()
{
    ObjectsDeleteAll(0, OVL_FC_PREFIX);
}

//+------------------------------------------------------------------+
//| DrawEntryDot — Punto sulla banda al segnale                       |
//| DodgerBlue, codice 159 (cerchietto pieno)                         |
//| Portata da DonchianPredictiveChannel v7.18                        |
//+------------------------------------------------------------------+
void DrawEntryDot(double bandPrice, datetime time, bool isBuy)
{
    string name = StringFormat("CARN_OVL_DOT_%s_%s",
                  isBuy ? "BUY" : "SELL",
                  TimeToString(time, TIME_DATE|TIME_MINUTES));

    ObjectCreate(0, name, OBJ_ARROW, 0, time, bandPrice);
    ObjectSetInteger(0, name, OBJPROP_ARROWCODE, 159);
    ObjectSetInteger(0, name, OBJPROP_COLOR, OVL_ENTRY_DOT_COLOR);
    ObjectSetInteger(0, name, OBJPROP_WIDTH, OVL_ENTRY_DOT_SIZE);
    ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_CENTER);
    ObjectSetInteger(0, name, OBJPROP_BACK, false);
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);

    ObjectSetString(0, name, OBJPROP_TOOLTIP,
        StringFormat("Entry dot %s | Band: %s | %s",
                     isBuy ? "BUY" : "SELL",
                     DoubleToString(bandPrice, _Digits),
                     TimeToString(time, TIME_MINUTES)));
}

//+------------------------------------------------------------------+
//| DestroyDPCOverlay — Rimuove TUTTI gli oggetti overlay             |
//+------------------------------------------------------------------+
void DestroyDPCOverlay()
{
    ObjectsDeleteAll(0, OVL_PREFIX);
    g_ovlSignalCount = 0;
    g_ovlLastSignalBar = 0;
    g_ovlLastDepth = 0;
    CarnLogI(LOG_CAT_UI, "DPC Overlay destroyed");
}
