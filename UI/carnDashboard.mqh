//+------------------------------------------------------------------+
//|                                          carnDashboard.mqh       |
//|           El Carnevaal de Schignan v3.40 - Dashboard Display      |
//|                                                                  |
//|  Visual dashboard (SugamaraFlow structure)                       |
//|  Color Scheme: ARLECCHINO - Losanghe colorate vivaci             |
//|                                                                  |
//|  Pannelli principali:                                            |
//|    Title — Mode & Status — DPC Engine — Signals & Channel        |
//|    Active Cycles — P&L Session — Market — Controls               |
//|  Side panels: DPC Engine status, ATR Monitor, Equity             |
//|                                                                  |
//|  Tutti i dati DPC letti da variabili globali del DPC Engine:     |
//|    g_dpcUpper/Lower/Mid, g_dpcChannelWidth, g_dpcMidColor        |
//|    g_dpcEngineReady, g_dpcATRHandle, g_dpcEmaATR                 |
//|                                                                  |
//|  SugamaraFlow pattern: DashRectangle + DashLabel, x/y pos       |
//|  Z-order: rectangles 15000, labels 16000, buttons 16001          |
//+------------------------------------------------------------------+
#property copyright "Sugamara Ribelle (C) 2026"

//+------------------------------------------------------------------+
//| DASHBOARD CONSTANTS                                              |
//+------------------------------------------------------------------+
#define DASH_PANEL_WIDTH  640
#define DASH_LINE_HEIGHT  18
#define DASH_FONT_SIZE    9      // Body default (invariato per retrocompatibilita')
#define DASH_FONT         "Consolas"
#define DASH_FONT_TITLE   "Arial Black"
#define DASH_FONT_SECTION "Arial Bold"
#define DASH_X_START      10
#define DASH_Y_START      25
#define DASH_PADDING      15
#define DASH_SECTION_PAD  20     // Spacing after section title (SugamaraFlow)
#define DASH_PANEL_GAP    4      // Gap between panels (chart BG shows through)

// Panel heights
#define DASH_TITLE_H      70
#define DASH_MODE_H       62
#define DASH_DPC_VALID_H  80     // DPC Validation panel
#define DASH_SIGNALS_H    100    // Signals & Channel panel (expanded for filters + TP mode)
#define DASH_CYCLE_ROWS   5
#define DASH_CYCLE_ROW_H  16
#define DASH_CYCLE_H      (28 + DASH_CYCLE_ROWS * DASH_CYCLE_ROW_H + 4)
#define DASH_PL_H         92     // Expanded for winrate + drawdown row
#define DASH_MKT_H        46
#define DASH_CTRL_H       90     // Controls panel (status + 2 rows of buttons)
#define DASH_TOTAL_H      (DASH_TITLE_H + DASH_MODE_H + DASH_DPC_VALID_H + DASH_SIGNALS_H + DASH_CYCLE_H + DASH_PL_H + DASH_MKT_H + DASH_CTRL_H + 7 * DASH_PANEL_GAP)

// Side panel constants
#define SIDE_PANEL_GAP    10
#define SIDE_PANEL_W      180
#define SIDE_DPC_H        50
#define SIDE_ATR_H        50
#define SIDE_EQUITY_H     70

//+------------------------------------------------------------------+
//| DashRectangle — Pannello sfondo con bordo colorato               |
//| Crea solo se non esiste, altrimenti aggiorna proprieta'          |
//| IMPORTANTE: NON fare delete+create — rompe z-order delle label!  |
//+------------------------------------------------------------------+
void DashRectangle(string name, int x, int y, int width, int height,
                   color bgClr, color borderClr)
{
    string objName = "CARN_" + name;

    if(ObjectFind(0, objName) < 0)
    {
        ObjectCreate(0, objName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
        ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, objName, OBJPROP_BACK, false);
        ObjectSetInteger(0, objName, OBJPROP_ZORDER, 15000);
        ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, objName, OBJPROP_HIDDEN, true);
    }

    ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);
    ObjectSetInteger(0, objName, OBJPROP_XSIZE, width);
    ObjectSetInteger(0, objName, OBJPROP_YSIZE, height);
    ObjectSetInteger(0, objName, OBJPROP_BGCOLOR, bgClr);
    ObjectSetInteger(0, objName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
    ObjectSetInteger(0, objName, OBJPROP_BORDER_COLOR, borderClr);
}

//+------------------------------------------------------------------+
//| DashLabel — Crea/aggiorna etichetta con posizionamento XY        |
//| Se l'oggetto esiste gia', aggiorna solo testo/colore (efficiente)|
//| Fix: testo vuoto "" diventa " " per evitare "Label" di default  |
//+------------------------------------------------------------------+
void DashLabel(string id, int x, int y, string text, color clr,
               int fontSize = DASH_FONT_SIZE, string fontName = "")
{
    if(fontName == "") fontName = DASH_FONT;
    string name = "CARN_DASH_" + id;

    if(ObjectFind(0, name) < 0)
    {
        ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
        ObjectSetInteger(0, name, OBJPROP_ZORDER, 16000);
    }

    ObjectSetString(0, name, OBJPROP_FONT, fontName);
    ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
    ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
    ObjectSetString(0, name, OBJPROP_TEXT, text == "" ? " " : text);
}

//+------------------------------------------------------------------+
//| GetControlsPanelY — Y del pannello CONTROLS                      |
//+------------------------------------------------------------------+
int GetControlsPanelY()
{
    return DASH_Y_START + DASH_TITLE_H + DASH_PANEL_GAP
                        + DASH_MODE_H + DASH_PANEL_GAP
                        + DASH_DPC_VALID_H + DASH_PANEL_GAP
                        + DASH_SIGNALS_H + DASH_PANEL_GAP
                        + DASH_CYCLE_H + DASH_PANEL_GAP
                        + DASH_PL_H + DASH_PANEL_GAP
                        + DASH_MKT_H + DASH_PANEL_GAP;
}

//+------------------------------------------------------------------+
//| ApplyChartTheme — Applica tema Arlecchino al grafico             |
//| Nasconde griglia e volumi per chart pulito                       |
//+------------------------------------------------------------------+
void ApplyChartTheme()
{
    // Chart colors
    ChartSetInteger(0, CHART_COLOR_BACKGROUND, CHART_BG_COLOR);
    ChartSetInteger(0, CHART_COLOR_FOREGROUND, CHART_FG_COLOR);
    ChartSetInteger(0, CHART_COLOR_GRID, CHART_GRID_COLOR);
    ChartSetInteger(0, CHART_COLOR_CANDLE_BULL, CHART_CANDLE_BULL);
    ChartSetInteger(0, CHART_COLOR_CANDLE_BEAR, CHART_CANDLE_BEAR);
    ChartSetInteger(0, CHART_COLOR_CHART_UP, CHART_CANDLE_BULL);
    ChartSetInteger(0, CHART_COLOR_CHART_DOWN, CHART_CANDLE_BEAR);
    ChartSetInteger(0, CHART_COLOR_CHART_LINE, CHART_CANDLE_LINE);
    ChartSetInteger(0, CHART_COLOR_VOLUME, CHART_CANDLE_LINE);
    ChartSetInteger(0, CHART_COLOR_ASK, COLOR_CONNECTED);
    ChartSetInteger(0, CHART_COLOR_BID, COLOR_LOSS);

    // Hide grid and volumes
    ChartSetInteger(0, CHART_SHOW_GRID, false);
    ChartSetInteger(0, CHART_SHOW_VOLUMES, CHART_VOLUME_HIDE);

    CarnLogI(LOG_CAT_UI, "Arlecchino theme applied (grid hidden)");
}

//+------------------------------------------------------------------+
//| CreateDashboard — Crea pannelli, contenuto e bottoni integrati   |
//+------------------------------------------------------------------+
void CreateDashboard()
{
    UpdateDashboard();

    // Create buttons inside CONTROLS panel
    int ctrlY = GetControlsPanelY();
    CreateControlButtons(DASH_X_START, ctrlY, DASH_PANEL_WIDTH);

    CarnLogI(LOG_CAT_UI, "Dashboard created (Arlecchino v3.40)");
}

//+------------------------------------------------------------------+
//| UpdateSidePanels — [v3.4] Pannello laterale unificato ENGINE MON |
//| DPC Status + ATR + Spread + ADX + Equity + Segnali in 1 box     |
//+------------------------------------------------------------------+
void UpdateSidePanels()
{
    int sx = DASH_X_START + DASH_PANEL_WIDTH + SIDE_PANEL_GAP;
    int sy = DASH_Y_START;
    int sw = SIDE_PANEL_W;

    // === PANNELLO UNIFICATO "ENGINE MONITOR" ===
    int unifiedH = SIDE_DPC_H + SIDE_ATR_H + SIDE_EQUITY_H + 2 * DASH_PANEL_GAP;
    DashRectangle("SIDE_ENGINE_MON", sx, sy, sw, unifiedH, THEME_BG_DARK, THEME_PANEL_BORDER);

    // Titolo
    DashLabel("SEM_TITLE", sx + 10, sy + 5,
              "ENGINE MONITOR", THEME_STATE_INFO, 9, DASH_FONT_SECTION);

    // --- DPC Status ---
    color dpcClr = g_dpcEngineReady ? THEME_STATE_OK : THEME_STATE_WARN;
    string dpcStr = g_dpcEngineReady ? "DPC  ACTIVE" : "DPC  STARTING";
    DashLabel("SEM_DPC", sx + 10, sy + 22, dpcStr, dpcClr, 9, DASH_FONT_SECTION);

    // --- ATR ---
    string atrStr = StringFormat("ATR  %.1f pip", GetATRPips());
    color atrClr = THEME_DASHBOARD_TEXT;
    if(currentATR_Condition == ATR_EXTREME)  atrClr = THEME_STATE_ERR;
    else if(currentATR_Condition == ATR_VOLATILE) atrClr = THEME_STATE_WARN;
    DashLabel("SEM_ATR", sx + 10, sy + 38, atrStr, atrClr, 9);

    // --- Spread ---
    double spd = GetSpreadPips();
    color spdClr = (Filter_Spread_Enable && spd > Filter_MaxSpreadPips)
                  ? THEME_STATE_ERR : THEME_DASHBOARD_TEXT;
    DashLabel("SEM_SPRD", sx + 10, sy + 52,
              StringFormat("SPD  %.1f pip", spd), spdClr, 9);

    // --- ADX ---
    if(Filter_ADX_Enable && g_adxHandle != INVALID_HANDLE)
    {
        bool adxOK = (g_adxValue >= Filter_ADX_MinLevel && g_adxValue <= Filter_ADX_MaxLevel);
        DashLabel("SEM_ADX", sx + 10, sy + 66,
                  StringFormat("ADX  %.0f  %s", g_adxValue, adxOK ? "OK" : "OUT"),
                  adxOK ? THEME_STATE_OK : THEME_STATE_WARN, 9);
    }
    else
    {
        DashLabel("SEM_ADX", sx + 10, sy + 66, "ADX  OFF", THEME_STATE_INACTIVE, 8);
    }

    // --- Separatore ---
    DashLabel("SEM_SEP", sx + 10, sy + 80,
              "────────────────", THEME_PANEL_BORDER, 7);

    // --- Equity ---
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double equity  = AccountInfoDouble(ACCOUNT_EQUITY);
    double dd = (maxEquityReached > 0) ? MathMax(0, (maxEquityReached - equity) / maxEquityReached * 100) : 0;
    color eqClr = (equity >= balance) ? THEME_STATE_OK : THEME_STATE_ERR;
    color ddClr = (dd > 3.0) ? THEME_STATE_ERR : (dd > 1.5) ? THEME_STATE_WARN : THEME_STATE_INACTIVE;

    DashLabel("SEM_BAL", sx + 10, sy + 92,
              StringFormat("Bal  %.0f", balance), THEME_DASHBOARD_TEXT, 8);
    DashLabel("SEM_EQ", sx + 10, sy + 106,
              StringFormat("Eq   %.0f", equity), eqClr, 9, DASH_FONT_SECTION);
    DashLabel("SEM_DD", sx + 10, sy + 120,
              StringFormat("DD   %.1f%%", dd), ddClr, 8);

    // --- Segnali oggi ---
    DashLabel("SEM_SEP2", sx + 10, sy + 136,
              "────────────────", THEME_PANEL_BORDER, 7);
    DashLabel("SEM_SIGS", sx + 10, sy + 148,
              StringFormat("Sig  B:%d S:%d Tot:%d", g_buySignals, g_sellSignals, g_totalSignals),
              THEME_DASHBOARD_TEXT, 8);
}

//+------------------------------------------------------------------+
//| UpdateDashboard — Aggiorna tutti i valori della dashboard        |
//+------------------------------------------------------------------+
void UpdateDashboard()
{
    int x = DASH_X_START;
    int y = DASH_Y_START;
    int w = DASH_PANEL_WIDTH;

    //=================================================================
    // TITLE PANEL — 70px
    // "EL CARNEVAAL DE SCHIGNAN" centered, 20px Arial Black
    //=================================================================
    DashRectangle("TITLE_PANEL", x, y, w, DASH_TITLE_H, THEME_BG_DARK, THEME_PANEL_BORDER);

    DashLabel("H1", x + w/2 - 195, y + 14,
              "EL CARNEVAAL DE SCHIGNAN", ARLECCHINO_YELLOW, 20, DASH_FONT_TITLE);
    DashLabel("H2", x + w/2 + 105, y + 20,
              "v3.40", ARLECCHINO_BLUE, 10, DASH_FONT_SECTION);
    DashLabel("H_SUB", x + w/2 - 140, y + 46,
              "DPC Engine + Turtle Soup + Breakout Hedge", C'180,175,200', 9, DASH_FONT);
    y += DASH_TITLE_H + DASH_PANEL_GAP;

    //=================================================================
    // MODE & STATUS PANEL — 62px
    // Section title: "SYSTEM STATUS" in Giallo
    //=================================================================
    DashRectangle("MODE_PANEL", x, y, w, DASH_MODE_H, THEME_BG_LIGHT, THEME_PANEL_BORDER);

    DashLabel("MS_TITLE", x + DASH_PADDING, y + 6,
              "SYSTEM STATUS", ARLECCHINO_YELLOW, 10, DASH_FONT_SECTION);

    string modeStr = (TradingMode == MODE_CLASSIC_TURTLE) ? "CLASSIC TURTLE" : "TRIGGER INDICATOR";
    color modeColor = (TradingMode == MODE_CLASSIC_TURTLE) ? ARLECCHINO_GREEN : ARLECCHINO_BLUE;

    DashLabel("M_MODE", x + DASH_PADDING, y + 24,
              "Mode: " + modeStr, modeColor, 9, DASH_FONT_SECTION);

    DashLabel("M_SYM", x + DASH_PADDING, y + 40,
              StringFormat("%s | %s | Spread: %.1f | Lot: %.2f",
              _Symbol, EnumToString(Period()), GetSpreadPips(), LotSize),
              THEME_DASHBOARD_TEXT, 9);

    // State badge on right side
    string stateStr = "IDLE";
    color stateColor = COLOR_NEUTRAL;
    switch(systemState)
    {
        case STATE_ACTIVE:       stateStr = "ACTIVE";       stateColor = ARLECCHINO_GREEN; break;
        case STATE_PAUSED:       stateStr = "PAUSED";       stateColor = ARLECCHINO_YELLOW; break;
        case STATE_INITIALIZING: stateStr = "INIT...";      stateColor = ARLECCHINO_BLUE; break;
        case STATE_IDLE:         stateStr = "IDLE";         stateColor = COLOR_NEUTRAL; break;
        case STATE_CLOSING:      stateStr = "CLOSING";      stateColor = ARLECCHINO_RED; break;
        case STATE_ERROR:        stateStr = "ERROR";        stateColor = ARLECCHINO_RED; break;
        case STATE_EMERGENCY:    stateStr = "EMERGENCY";    stateColor = ARLECCHINO_RED; break;
    }
    DashLabel("M_STATE", x + w - 110, y + 6,
              stateStr, stateColor, 11, DASH_FONT_SECTION);
    y += DASH_MODE_H + DASH_PANEL_GAP;

    //=================================================================
    // DPC ENGINE PANEL — 80px
    // Section title: "DPC ENGINE" in Blu
    //=================================================================
    DashRectangle("DPC_PANEL", x, y, w, DASH_DPC_VALID_H, THEME_BG_DARK, THEME_PANEL_BORDER);

    DashLabel("DV_TITLE", x + DASH_PADDING, y + 6,
              "DPC ENGINE", ARLECCHINO_BLUE, 10, DASH_FONT_SECTION);

    // Engine status badge
    if(g_dpcEngineReady)
    {
        DashLabel("DV_STATUS", x + w - 130, y + 6,
                  "ACTIVE", ARLECCHINO_GREEN, 10, DASH_FONT_SECTION);
    }
    else
    {
        DashLabel("DV_STATUS", x + w - 155, y + 6,
                  "STARTING...", ARLECCHINO_YELLOW, 10, DASH_FONT_SECTION);
    }

    // Engine info
    string engineStr = g_dpcEngineReady
        ? StringFormat("ATR: #%d | MA: %s", g_dpcATRHandle, EnumToString(DPC_MAType))
        : "Handles: initializing...";
    color engineClr = g_dpcEngineReady ? ARLECCHINO_GREEN : ARLECCHINO_YELLOW;
    DashLabel("DV_HANDLE", x + DASH_PADDING, y + 26,
              engineStr, engineClr, 9);

    // SmartCooldown status
    string cdStr = DPC_UseSmartCooldown
        ? StringFormat("Cooldown: SMART (S%d/O%d)", DPC_SameDirBars, DPC_OppositeDirBars)
        : StringFormat("Cooldown: FIXED (%d bars)", DPC_Period);
    DashLabel("DV_HEALTH", x + DASH_PADDING + 150, y + 26,
              cdStr, DPC_UseSmartCooldown ? ARLECCHINO_GREEN : ARLECCHINO_YELLOW, 9);

    // DPC Parameters
    DashLabel("DV_PARAMS", x + DASH_PADDING, y + 44,
              StringFormat("Period: %d | MA: %s(%d) | Offset: %.1fp",
              DPC_Period,
              EnumToString(DPC_MAType), DPC_MALength,
              Trigger_Offset_Pips),
              C'180,175,200', 8);

    // Active filters count
    int activeFilters = 0;
    if(DPC_SignalFilter)     activeFilters++;
    if(DPC_UseBandFlatness)  activeFilters++;
    if(DPC_UseLevelAge)      activeFilters++;
    if(DPC_UseTrendContext)   activeFilters++;
    if(DPC_UseWidthFilter)   activeFilters++;
    if(DPC_UseTimeFilter)    activeFilters++;
    DashLabel("DV_LASTCHK", x + DASH_PADDING, y + 60,
              StringFormat("Active filters: %d/6", activeFilters),
              activeFilters > 0 ? C'180,175,200' : ARLECCHINO_YELLOW, 8);

    // Signal filter status
    DashLabel("DV_FILTER", x + DASH_PADDING + 220, y + 60,
              DPC_SignalFilter ? "Filter: ON" : "Filter: OFF",
              DPC_SignalFilter ? ARLECCHINO_GREEN : ARLECCHINO_YELLOW, 8);

    // [v3.4] EMA ATR diagnostica (solo se disponibile)
    if(g_dpcEmaATR > 0)
    {
        DashLabel("DV_EMA_ATR", x + DASH_PADDING + 380, y + 60,
                  StringFormat("EMA_ATR: %.1fp", PointsToPips(g_dpcEmaATR)),
                  THEME_STATE_INFO, 8);
    }
    y += DASH_DPC_VALID_H + DASH_PANEL_GAP;

    //=================================================================
    // SIGNALS & CHANNEL PANEL — 72px
    // Section title: "SIGNALS & CHANNEL" in Giallo
    //=================================================================
    DashRectangle("SIG_PANEL", x, y, w, DASH_SIGNALS_H, THEME_BG_LIGHT, THEME_PANEL_BORDER);

    DashLabel("SC_TITLE", x + DASH_PADDING, y + 6,
              "SIGNALS & CHANNEL", ARLECCHINO_YELLOW, 10, DASH_FONT_SECTION);

    // Signal counts on right
    DashLabel("SC_COUNT", x + w - 210, y + 7,
              StringFormat("BUY: %d | SELL: %d | Tot: %d",
              g_buySignals, g_sellSignals, g_totalSignals),
              THEME_DASHBOARD_TEXT, 9);

    // Channel bands
    if(g_dpcUpper > 0)
    {
        DashLabel("SC_BANDS", x + DASH_PADDING, y + 26,
                  StringFormat("Upper: %s    Mid: %s    Lower: %s",
                  DoubleToString(g_dpcUpper, _Digits),
                  DoubleToString(g_dpcMid, _Digits),
                  DoubleToString(g_dpcLower, _Digits)),
                  THEME_DASHBOARD_TEXT, 9);

        // Channel width + trend
        color trendColor = (g_dpcMidColor == 0) ? ARLECCHINO_GREEN : ARLECCHINO_RED;
        string trendStr = (g_dpcMidColor == 0) ? "BULLISH" : "BEARISH";

        DashLabel("SC_WIDTH", x + DASH_PADDING, y + 44,
                  StringFormat("Width: %.1f pips", g_dpcChannelWidth),
                  ARLECCHINO_BLUE, 9, DASH_FONT_SECTION);

        DashLabel("SC_TREND", x + DASH_PADDING + 160, y + 44,
                  "Trend: " + trendStr, trendColor, 9, DASH_FONT_SECTION);
    }
    else
    {
        DashLabel("SC_BANDS", x + DASH_PADDING, y + 26,
                  "Waiting for DPC data...", COLOR_NEUTRAL, 9);
        DashLabel("SC_WIDTH", x + DASH_PADDING, y + 44, "", COLOR_NEUTRAL, 9);
        DashLabel("SC_TREND", x + DASH_PADDING + 160, y + 44, "", COLOR_NEUTRAL, 9);
    }

    // Last signal info
    string lastSigStr = "Last signal: None";
    color lastSigClr = COLOR_NEUTRAL;
    if(g_lastSignalTime > 0)
    {
        int barsAgo = (int)((TimeCurrent() - g_lastSignalTime) / PeriodSeconds());
        lastSigStr = StringFormat("Last: %s @ %s (%d bars ago)",
                     g_lastSignalDirection,
                     TimeToString(g_lastSignalTime, TIME_MINUTES),
                     barsAgo);
        lastSigClr = (g_lastSignalDirection == "BUY") ? ARLECCHINO_GREEN : ARLECCHINO_RED;
    }
    DashLabel("SC_LAST", x + DASH_PADDING, y + 58,
              lastSigStr, lastSigClr, 8);

    // === [v3.4] FILTER STATUS BAR — icone compatte stato filtri ===
    {
        string fFlat  = DPC_UseBandFlatness  ? "[+Flat]" : "[_Flat]";
        string fWidth = DPC_UseWidthFilter   ? (g_dpcChannelWidth >= DPC_MinWidthPips_Int ? "[+W]" : "[!W]") : "[_W]";
        string fTrend = DPC_UseTrendContext  ? "[+Trd]" : "[_Trd]";
        string fAge   = DPC_UseLevelAge      ? "[+Age]" : "[_Age]";
        string fTime  = DPC_UseTimeFilter    ? "[+Time]" : "[_Time]";
        string fADX   = Filter_ADX_Enable    ? StringFormat("[+ADX:%.0f]", g_adxValue) : "[_ADX]";
        string fSprd  = Filter_Spread_Enable ? (GetSpreadPips() <= Filter_MaxSpreadPips ? "[+Sprd]" : "[!Sprd]") : "[_Sprd]";

        string filterBar = fFlat + " " + fWidth + " " + fTrend + " " + fAge + " " + fTime + " " + fADX + " " + fSprd;

        // Colore rosso se spread o width in blocco
        bool anyBlocking = (DPC_UseWidthFilter && g_dpcUpper > 0 && g_dpcChannelWidth < DPC_MinWidthPips_Int)
                        || (Filter_Spread_Enable && GetSpreadPips() > Filter_MaxSpreadPips);
        color filterBarClr = anyBlocking ? THEME_STATE_ERR : THEME_STATE_INFO;

        DashLabel("SC_FILTERS", x + DASH_PADDING, y + 74,
                  filterBar, filterBarClr, DASH_FONT_SIZE_DETAIL);
    }

    // TP Mode (solo in Trigger mode)
    if(TradingMode == MODE_TRIGGER_INDICATOR)
    {
        string tpModeStr = "";
        switch(Trigger_TP_Mode)
        {
            case TRIGGER_TP_MIDLINE:          tpModeStr = "TP: Midline"; break;
            case TRIGGER_TP_OPPOSITE_BAND:    tpModeStr = "TP: Opp.Band"; break;
            case TRIGGER_TP_OPPOSITE_TRIGGER: tpModeStr = "TP: Opp.Trigger"; break;
        }
        DashLabel("SC_TPMODE", x + DASH_PADDING + 430, y + 74, tpModeStr, ARLECCHINO_YELLOW, 8);
    }
    else
    {
        DashLabel("SC_TPMODE", x + DASH_PADDING + 430, y + 74, "", COLOR_NEUTRAL, 8);
    }
    y += DASH_SIGNALS_H + DASH_PANEL_GAP;

    //=================================================================
    // ACTIVE CYCLES PANEL
    // Section title: "ACTIVE CYCLES" in Verde
    //=================================================================
    int activeCycles = CountActiveCycles();
    int cyclesHeight = DASH_CYCLE_H;
    DashRectangle("CYCLE_PANEL", x, y, w, cyclesHeight, THEME_BG_DARK, THEME_PANEL_BORDER);

    DashLabel("CY_TITLE", x + DASH_PADDING, y + 6,
              "ACTIVE CYCLES", ARLECCHINO_GREEN, 10, DASH_FONT_SECTION);

    DashLabel("CY_CNT", x + w - 80, y + 7,
              StringFormat("%d / %d", activeCycles, Max_ConcurrentCycles),
              ARLECCHINO_GREEN, 9, DASH_FONT_SECTION);

    int cy = y + 28;
    int cycleDisplayCount = 0;
    for(int i = 0; i < ArraySize(g_cycles) && cycleDisplayCount < DASH_CYCLE_ROWS; i++)
    {
        if(g_cycles[i].state == CYCLE_IDLE || g_cycles[i].state == CYCLE_CLOSED)
            continue;

        string dirStr = g_cycles[i].direction > 0 ? "LONG" : "SHORT";
        string stStr = "";
        color cycleColor = clrWhite;

        switch(g_cycles[i].state)
        {
            case CYCLE_SOUP_ACTIVE:
                stStr = "SOUP";
                cycleColor = ARLECCHINO_GREEN;
                break;
            case CYCLE_TRIGGER_PENDING:
                stStr = "TRIG-PEND";
                cycleColor = ARLECCHINO_YELLOW;
                break;
            case CYCLE_TRIGGER_ACTIVE:
                stStr = "TRIG-LIVE";
                cycleColor = ARLECCHINO_GREEN;
                break;
            case CYCLE_HEDGING:
                stStr = "HEDGE";
                cycleColor = ARLECCHINO_YELLOW;
                break;
        }

        double floatPL = 0;
        if(g_cycles[i].soupActive)
            floatPL += GetFloatingProfit(g_cycles[i].soupTicket);
        if(g_cycles[i].breakoutActive)
            floatPL += GetFloatingProfit(g_cycles[i].breakoutTicket);
        if(g_cycles[i].triggerActive)
            floatPL += GetFloatingProfit(g_cycles[i].triggerTicket);

        color plColor = floatPL >= 0 ? ARLECCHINO_GREEN : ARLECCHINO_RED;

        DashLabel(StringFormat("CY%d", cycleDisplayCount),
                  x + DASH_PADDING, cy,
                  StringFormat("#%d  %s  %s", g_cycles[i].cycleID, dirStr, stStr),
                  cycleColor, 9);

        DashLabel(StringFormat("CY%d_PL", cycleDisplayCount),
                  x + w - 120, cy,
                  StringFormat("P/L: %+.2f", floatPL),
                  plColor, 9);

        cy += DASH_CYCLE_ROW_H;
        cycleDisplayCount++;
    }

    // Clear unused cycle rows
    for(int c = cycleDisplayCount; c < DASH_CYCLE_ROWS; c++)
    {
        DashLabel(StringFormat("CY%d", c), x + DASH_PADDING, cy, "", clrWhite, 9);
        DashLabel(StringFormat("CY%d_PL", c), x + w - 120, cy, "", clrWhite, 9);
        cy += DASH_CYCLE_ROW_H;
    }
    y += cyclesHeight + DASH_PANEL_GAP;

    //=================================================================
    // P&L SESSION PANEL — 76px
    // Section title: "P&L SESSION" in Rosso
    //=================================================================
    DashRectangle("PL_PANEL", x, y, w, DASH_PL_H, THEME_BG_LIGHT, THEME_PANEL_BORDER);

    DashLabel("PL_TITLE", x + DASH_PADDING, y + 6,
              "P&L SESSION", ARLECCHINO_RED, 10, DASH_FONT_SECTION);

    color soupPLColor = g_totalSoupProfit >= 0 ? ARLECCHINO_GREEN : ARLECCHINO_RED;
    color bkoPLColor = g_totalBreakoutProfit >= 0 ? ARLECCHINO_GREEN : ARLECCHINO_RED;
    double combined = g_totalSoupProfit + g_totalBreakoutProfit;
    color combColor = combined >= 0 ? ARLECCHINO_GREEN : ARLECCHINO_RED;

    DashLabel("PL_SOUP", x + DASH_PADDING, y + 26,
              StringFormat("Soup:    %+.2f  (W:%d  L:%d)",
              g_totalSoupProfit, g_totalSoupWins, g_totalSoupLosses), soupPLColor, 9);
    DashLabel("PL_BKO", x + DASH_PADDING, y + 42,
              StringFormat("Bkout:   %+.2f  (W:%d  L:%d)",
              g_totalBreakoutProfit, g_totalBreakoutWins, g_totalBreakoutLosses), bkoPLColor, 9);
    DashLabel("PL_TOTAL", x + DASH_PADDING, y + 58,
              StringFormat("Total:   %+.2f  |  Hedges: %d",
              combined, g_totalHedgeActivations), combColor, 10, DASH_FONT_SECTION);

    // Winrate + Drawdown
    int totalTrades = g_totalSoupWins + g_totalSoupLosses;
    double winrate = totalTrades > 0 ? (double)g_totalSoupWins / totalTrades * 100.0 : 0;
    DashLabel("PL_WR", x + DASH_PADDING, y + 76,
              StringFormat("Winrate: %.0f%%  |  DD: %.1f%%",
              winrate, GetDrawdownFromPeak()),
              winrate >= 50 ? ARLECCHINO_GREEN : ARLECCHINO_RED, 9);
    y += DASH_PL_H + DASH_PANEL_GAP;

    //=================================================================
    // MARKET PANEL — 46px
    // Section title: "MARKET" in Blu
    //=================================================================
    DashRectangle("MKT_PANEL", x, y, w, DASH_MKT_H, THEME_BG_DARK, THEME_PANEL_BORDER);

    DashLabel("MK_TITLE", x + DASH_PADDING, y + 6,
              "MARKET", ARLECCHINO_BLUE, 10, DASH_FONT_SECTION);

    // Floating P&L totale di tutte le posizioni aperte
    double totalFloat = 0;
    for(int fi = 0; fi < ArraySize(g_cycles); fi++)
    {
        if(g_cycles[fi].soupActive)
            totalFloat += GetFloatingProfit(g_cycles[fi].soupTicket);
        if(g_cycles[fi].breakoutActive)
            totalFloat += GetFloatingProfit(g_cycles[fi].breakoutTicket);
        if(g_cycles[fi].triggerActive)
            totalFloat += GetFloatingProfit(g_cycles[fi].triggerTicket);
    }
    color floatClr = totalFloat >= 0 ? ARLECCHINO_GREEN : ARLECCHINO_RED;

    DashLabel("MK_ATR", x + DASH_PADDING + 80, y + 7,
              StringFormat("ATR: %.1f pip  |  Bal: %.0f  |  Eq: %.0f",
              GetATRPips(), AccountInfoDouble(ACCOUNT_BALANCE), AccountInfoDouble(ACCOUNT_EQUITY)),
              THEME_DASHBOARD_TEXT, 9);

    DashLabel("MK_FLOAT", x + w - 150, y + 7,
              StringFormat("Float: %+.2f", totalFloat), floatClr, 9);

    string sessStr = GetSessionStatus();
    DashLabel("MK_SESS", x + DASH_PADDING, y + 27,
              "Session: " + sessStr, THEME_DASHBOARD_TEXT, 9);

    DashLabel("MK_TIME", x + w - 150, y + 27,
              "Server: " + TimeToString(TimeCurrent(), TIME_MINUTES),
              C'140,140,155', 8);
    y += DASH_MKT_H + DASH_PANEL_GAP;

    //=================================================================
    // CONTROLS PANEL — 90px (buttons inside)
    // Section title: "CONTROLS" in Giallo + status text
    // Buttons created once by CreateControlButtons, updated here
    //=================================================================
    DashRectangle("CTRL_PANEL", x, y, w, DASH_CTRL_H, THEME_BG_LIGHT, THEME_PANEL_BORDER);

    DashLabel("CT_TITLE", x + DASH_PADDING, y + 6,
              "CONTROLS", ARLECCHINO_YELLOW, 10, DASH_FONT_SECTION);

    // Sync button feedback with current state (solo se bottoni gia' creati)
    // NOTA: non usare BTN_START (#define in carnControlButtons, incluso DOPO questo file)
    // Usiamo il nome oggetto diretto per evitare dipendenza da preprocessor
    if(ObjectFind(0, "CARN_BTN_START_" + _Symbol) >= 0)
        UpdateButtonFeedback();

    // Side panels
    UpdateSidePanels();
}

//+------------------------------------------------------------------+
//| DestroyDashboard — Rimuovi tutti gli oggetti dashboard + bottoni |
//| Il prefisso "CARN_" copre dashboard, side panels e bottoni      |
//+------------------------------------------------------------------+
void DestroyDashboard()
{
    ObjectsDeleteAll(0, "CARN_");
}
