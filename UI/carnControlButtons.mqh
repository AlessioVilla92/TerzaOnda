//+------------------------------------------------------------------+
//|                                      carnControlButtons.mqh      |
//|           El Carnevaal de Schignan v3.40 - Control Buttons        |
//|                                                                  |
//|  Layout integrato nel pannello CONTROLS della dashboard:          |
//|  Row 1: START | PAUSE | CLOSE ALL                                |
//|  Row 2: CLOSE SOUPS | CLOSE BKOUTS | RECOVER                    |
//|  + Status Label (right of CONTROLS title)                        |
//|                                                                  |
//|  Based on SugamaraFlow ControlButtons pattern:                   |
//|  - CtrlObjName() for multi-chart support                         |
//|  - Arial Bold font, uniform width buttons                        |
//|  - Z-order 16001 (above dashboard labels at 16000)               |
//+------------------------------------------------------------------+
#property copyright "Sugamara Ribelle (C) 2026"

//+------------------------------------------------------------------+
//| BUTTON NAME CONSTANTS                                            |
//+------------------------------------------------------------------+
#define BTN_START       "CARN_BTN_START"
#define BTN_PAUSE       "CARN_BTN_PAUSE"
#define BTN_CLOSE       "CARN_BTN_CLOSE"
#define BTN_CLOSE_SOUPS "CARN_BTN_CLOSE_SOUPS"
#define BTN_CLOSE_BKO   "CARN_BTN_CLOSE_BKO"
#define BTN_RECOVER     "CARN_BTN_RECOVER"
#define BTN_STATUS      "CARN_BTN_STATUS"

//+------------------------------------------------------------------+
//| Multi-chart support: append _SYMBOL to object names              |
//| Prevents conflicts when running multiple EAs on different charts  |
//+------------------------------------------------------------------+
string CtrlObjName(string baseName)
{
    return baseName + "_" + _Symbol;
}

//+------------------------------------------------------------------+
//| BUTTON COLORS (Arlecchino Palette)                               |
//+------------------------------------------------------------------+
#define CLR_BTN_START     C'0,150,80'         // Verde scuro (default)
#define CLR_BTN_ACTIVE    C'0,200,100'        // Verde brillante (running)
#define CLR_BTN_PAUSE     C'180,120,0'        // Ambra (pause)
#define CLR_BTN_RESUME    ARLECCHINO_BLUE     // Blu azure (resume)
#define CLR_BTN_CLOSE     C'180,30,30'        // Rosso scuro
#define CLR_BTN_RECOVER   C'0,140,140'        // Cyan/Teal (recovery)

//+------------------------------------------------------------------+
//| CreateControlButton — Crea un bottone (stile SugamaraFlow)       |
//| Arial Bold, 28px, clrBlack border, zorder 16001                  |
//+------------------------------------------------------------------+
void CreateControlButton(string name, int x, int y, int width, int height,
                         string text, color bgColor)
{
    string objName = CtrlObjName(name);
    ObjectDelete(0, objName);

    if(!ObjectCreate(0, objName, OBJ_BUTTON, 0, 0, 0))
    {
        CarnLogE(LOG_CAT_UI, "Failed to create button " + objName);
        return;
    }

    ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);
    ObjectSetInteger(0, objName, OBJPROP_XSIZE, width);
    ObjectSetInteger(0, objName, OBJPROP_YSIZE, height);
    ObjectSetString(0, objName, OBJPROP_TEXT, text);
    ObjectSetInteger(0, objName, OBJPROP_COLOR, clrWhite);
    ObjectSetInteger(0, objName, OBJPROP_BGCOLOR, bgColor);
    ObjectSetInteger(0, objName, OBJPROP_BORDER_COLOR, clrBlack);
    ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, 9);
    ObjectSetString(0, objName, OBJPROP_FONT, "Arial Bold");
    ObjectSetInteger(0, objName, OBJPROP_BACK, false);
    ObjectSetInteger(0, objName, OBJPROP_STATE, false);
    ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, objName, OBJPROP_HIDDEN, true);
    ObjectSetInteger(0, objName, OBJPROP_ZORDER, 16001);
}

//+------------------------------------------------------------------+
//| CreateButtonLabel — Crea etichetta status (stile SugamaraFlow)   |
//| Arial Bold size 9, zorder 16002                                  |
//+------------------------------------------------------------------+
void CreateButtonLabel(string name, int x, int y, int width,
                       string text, color clr)
{
    string objName = CtrlObjName(name);
    ObjectDelete(0, objName);

    if(!ObjectCreate(0, objName, OBJ_LABEL, 0, 0, 0))
    {
        CarnLogE(LOG_CAT_UI, "Failed to create label " + objName);
        return;
    }

    ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);
    ObjectSetString(0, objName, OBJPROP_TEXT, text);
    ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
    ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, 9);
    ObjectSetString(0, objName, OBJPROP_FONT, "Arial Bold");
    ObjectSetInteger(0, objName, OBJPROP_BACK, false);
    ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, objName, OBJPROP_HIDDEN, true);
    ObjectSetInteger(0, objName, OBJPROP_ZORDER, 16002);
}

//+------------------------------------------------------------------+
//| CreateControlButtons — Crea bottoni dentro pannello CONTROLS     |
//| Chiamata da CreateDashboard() con coordinate del pannello        |
//| Tutti i bottoni hanno larghezza uniforme                         |
//+------------------------------------------------------------------+
void CreateControlButtons(int startX, int startY, int panelWidth)
{
    int pad = 15;
    int btnGap = 8;
    int btnW = (panelWidth - 2 * pad - 2 * btnGap) / 3;   // ~198px uniform
    int btnH = 28;
    int x = startX + pad;

    // === STATUS LABEL (right of CONTROLS title) ===
    CreateButtonLabel(BTN_STATUS, startX + 120, startY + 7, panelWidth - 130,
                      "READY — Click START", THEME_DASHBOARD_TEXT);

    // === Row 1: START | PAUSE | CLOSE ALL ===
    int y = startY + 26;
    CreateControlButton(BTN_START, x, y,
                        btnW, btnH, "START", CLR_BTN_START);

    CreateControlButton(BTN_PAUSE, x + btnW + btnGap, y,
                        btnW, btnH, "PAUSE", CLR_BTN_PAUSE);

    CreateControlButton(BTN_CLOSE, x + 2 * (btnW + btnGap), y,
                        btnW, btnH, "CLOSE ALL", CLR_BTN_CLOSE);

    // === Row 2: CLOSE SOUPS | CLOSE BKOUTS | RECOVER ===
    y += btnH + 4;

    CreateControlButton(BTN_CLOSE_SOUPS, x, y,
                        btnW, btnH, "CLOSE SOUPS", SOUP_COLOR);

    CreateControlButton(BTN_CLOSE_BKO, x + btnW + btnGap, y,
                        btnW, btnH, "CLOSE BKOUTS", BREAKOUT_COLOR);

    CreateControlButton(BTN_RECOVER, x + 2 * (btnW + btnGap), y,
                        btnW, btnH, "RECOVER", CLR_BTN_RECOVER);

    // Set initial visual state
    UpdateButtonFeedback();

    CarnLogI(LOG_CAT_UI, "Control buttons created (6 buttons + status label)");
}

//+------------------------------------------------------------------+
//| HighlightActiveButton — Evidenzia il bottone attivo              |
//| Resetta START al default e poi evidenzia quello richiesto        |
//+------------------------------------------------------------------+
void HighlightActiveButton(string activeBtn)
{
    // Reset START to default
    ObjectSetInteger(0, CtrlObjName(BTN_START), OBJPROP_BGCOLOR, CLR_BTN_START);

    // Highlight the active button
    ObjectSetInteger(0, CtrlObjName(activeBtn), OBJPROP_BGCOLOR, CLR_BTN_ACTIVE);
}

//+------------------------------------------------------------------+
//| ResetButtonHighlights — Resetta tutti i bottoni ai colori default|
//+------------------------------------------------------------------+
void ResetButtonHighlights()
{
    ObjectSetInteger(0, CtrlObjName(BTN_START), OBJPROP_BGCOLOR, CLR_BTN_START);
    ObjectSetInteger(0, CtrlObjName(BTN_PAUSE), OBJPROP_BGCOLOR, CLR_BTN_PAUSE);
}

//+------------------------------------------------------------------+
//| UpdateButtonFeedback — Aggiorna colori/testi in base allo stato  |
//| Chiamata dopo ogni click E da UpdateDashboard                    |
//+------------------------------------------------------------------+
void UpdateButtonFeedback()
{
    // === START button: RUNNING (green bright) / START (green dark) ===
    if(systemState == STATE_ACTIVE)
    {
        ObjectSetInteger(0, CtrlObjName(BTN_START), OBJPROP_BGCOLOR, CLR_BTN_ACTIVE);
        ObjectSetString(0, CtrlObjName(BTN_START), OBJPROP_TEXT, "RUNNING");
    }
    else
    {
        ObjectSetInteger(0, CtrlObjName(BTN_START), OBJPROP_BGCOLOR, CLR_BTN_START);
        ObjectSetString(0, CtrlObjName(BTN_START), OBJPROP_TEXT, "START");
    }

    // === PAUSE/RESUME toggle ===
    if(systemState == STATE_PAUSED)
    {
        ObjectSetString(0, CtrlObjName(BTN_PAUSE), OBJPROP_TEXT, "RESUME");
        ObjectSetInteger(0, CtrlObjName(BTN_PAUSE), OBJPROP_BGCOLOR, CLR_BTN_RESUME);
    }
    else
    {
        ObjectSetString(0, CtrlObjName(BTN_PAUSE), OBJPROP_TEXT, "PAUSE");
        ObjectSetInteger(0, CtrlObjName(BTN_PAUSE), OBJPROP_BGCOLOR, CLR_BTN_PAUSE);
    }

    // === Context-aware button labels ===
    if(TradingMode == MODE_TRIGGER_INDICATOR)
    {
        ObjectSetString(0, CtrlObjName(BTN_CLOSE_SOUPS), OBJPROP_TEXT, "CLOSE TRIG");
        ObjectSetString(0, CtrlObjName(BTN_CLOSE_BKO), OBJPROP_TEXT, "CLOSE PEND");
    }
    else
    {
        ObjectSetString(0, CtrlObjName(BTN_CLOSE_SOUPS), OBJPROP_TEXT, "CLOSE SOUPS");
        ObjectSetString(0, CtrlObjName(BTN_CLOSE_BKO), OBJPROP_TEXT, "CLOSE BKOUTS");
    }

    // === STATUS LABEL ===
    string statusText = "";
    color statusColor = COLOR_NEUTRAL;

    switch(systemState)
    {
        case STATE_IDLE:
            statusText = "READY — Click START";
            statusColor = COLOR_NEUTRAL;
            break;
        case STATE_ACTIVE:
            statusText = "ACTIVE — Strategy Running";
            statusColor = ARLECCHINO_GREEN;
            break;
        case STATE_PAUSED:
            statusText = "PAUSED — Click RESUME";
            statusColor = ARLECCHINO_YELLOW;
            break;
        case STATE_INITIALIZING:
            statusText = "INITIALIZING...";
            statusColor = ARLECCHINO_BLUE;
            break;
        case STATE_CLOSING:
            statusText = "CLOSING ALL...";
            statusColor = ARLECCHINO_RED;
            break;
        case STATE_EMERGENCY:
            statusText = "EMERGENCY STOP";
            statusColor = ARLECCHINO_RED;
            break;
        case STATE_ERROR:
            statusText = "ERROR — Check Log";
            statusColor = ARLECCHINO_RED;
            break;
        default:
            statusText = "Status: " + IntegerToString(systemState);
            statusColor = COLOR_NEUTRAL;
            break;
    }

    ObjectSetString(0, CtrlObjName(BTN_STATUS), OBJPROP_TEXT, statusText);
    ObjectSetInteger(0, CtrlObjName(BTN_STATUS), OBJPROP_COLOR, statusColor);
}

//+------------------------------------------------------------------+
//| HandleButtonClick — Gestisce click con guard + feedback          |
//| Usa CtrlObjName per confronto (multi-chart safe)                 |
//+------------------------------------------------------------------+
void HandleButtonClick(string sparam)
{
    // === START ===
    if(sparam == CtrlObjName(BTN_START))
    {
        ObjectSetInteger(0, sparam, OBJPROP_STATE, false);

        if(systemState == STATE_ACTIVE)
        {
            CarnLogI(LOG_CAT_UI, "START ignored — already ACTIVE");
            if(EnableAlerts) Alert("CARNEVAL: Sistema gia' ATTIVO!");
            return;
        }

        if(systemState == STATE_PAUSED)
        {
            // RESUME from pause via START button
            systemState = STATE_ACTIVE;
            CarnLogI(LOG_CAT_SYSTEM, "CARNEVAL RESUMED from PAUSE (via START)");
        }
        else
        {
            // Fresh start
            CarnLogI(LOG_CAT_UI, "=== START BUTTON CLICKED ===");
            StartCarneval();
        }

        HighlightActiveButton(BTN_START);
        UpdateButtonFeedback();
        UpdateDashboard();
        return;
    }

    // === PAUSE / RESUME ===
    if(sparam == CtrlObjName(BTN_PAUSE))
    {
        ObjectSetInteger(0, sparam, OBJPROP_STATE, false);

        if(systemState == STATE_PAUSED)
        {
            // Resume
            systemState = STATE_ACTIVE;
            CarnLogI(LOG_CAT_SYSTEM, "CARNEVAL RESUMED");
            HighlightActiveButton(BTN_START);
        }
        else if(systemState == STATE_ACTIVE)
        {
            // Pause
            systemState = STATE_PAUSED;
            CarnLogI(LOG_CAT_SYSTEM, "CARNEVAL PAUSED");
            ResetButtonHighlights();
        }
        else
        {
            CarnLogI(LOG_CAT_UI, StringFormat("PAUSE ignored — not active (state: %s)",
                     EnumToString(systemState)));
            return;
        }

        UpdateButtonFeedback();
        UpdateDashboard();
        return;
    }

    // === CLOSE ALL ===
    if(sparam == CtrlObjName(BTN_CLOSE))
    {
        ObjectSetInteger(0, sparam, OBJPROP_STATE, false);

        CarnLogI(LOG_CAT_UI, "=== CLOSE ALL REQUESTED ===");

        CloseAllPositions();
        systemState = STATE_IDLE;
        CarnLogI(LOG_CAT_SYSTEM, "State: -> IDLE (CLOSE ALL completed)");

        ResetButtonHighlights();
        UpdateButtonFeedback();
        UpdateDashboard();

        CarnLogI(LOG_CAT_SYSTEM, "CARNEVAL STOPPED — All closed");
        if(EnableAlerts) Alert("CARNEVAL: All positions closed");
        return;
    }

    // === CLOSE SOUPS / TRIGGERS (MagicNumber positions) ===
    if(sparam == CtrlObjName(BTN_CLOSE_SOUPS))
    {
        ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
        int closed = 0, closeFailed = 0;
        for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
            ulong ticket = PositionGetTicket(i);
            if(ticket == 0) continue;
            if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
            if(PositionGetInteger(POSITION_MAGIC) == MagicNumber)
            {
                trade.SetExpertMagicNumber(MagicNumber);
                if(trade.PositionClose(ticket))
                {
                    closed++;
                    CarnLogI(LOG_CAT_ORDER, StringFormat("CLOSE SOUPS — #%s closed OK", IntegerToString(ticket)));
                }
                else
                {
                    closeFailed++;
                    CarnLogE(LOG_CAT_ORDER, StringFormat("CLOSE SOUPS — #%s FAILED: %s",
                             IntegerToString(ticket), trade.ResultRetcodeDescription()));
                }
            }
        }
        // Cancel trigger pending orders too (same MagicNumber)
        if(TradingMode == MODE_TRIGGER_INDICATOR)
        {
            int cancelled = 0, cancelFailed = 0;
            for(int i = OrdersTotal() - 1; i >= 0; i--)
            {
                ulong ticket = OrderGetTicket(i);
                if(ticket == 0) continue;
                if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
                if(OrderGetInteger(ORDER_MAGIC) == MagicNumber)
                {
                    if(trade.OrderDelete(ticket))
                    {
                        cancelled++;
                        CarnLogI(LOG_CAT_ORDER, StringFormat("CLOSE SOUPS — Pending #%s deleted OK", IntegerToString(ticket)));
                    }
                    else
                    {
                        cancelFailed++;
                        CarnLogE(LOG_CAT_ORDER, StringFormat("CLOSE SOUPS — Pending #%s DELETE FAILED: %s",
                                 IntegerToString(ticket), trade.ResultRetcodeDescription()));
                    }
                }
            }
            CarnLogI(LOG_CAT_SYSTEM, StringFormat("Closed %d TRIGGER positions (failed: %d), cancelled %d pending STOPs (failed: %d)",
                     closed, closeFailed, cancelled, cancelFailed));
            if(EnableAlerts) Alert("CARNEVAL: Chiuse ", closed, " pos + ", cancelled, " trigger pending");
        }
        else
        {
            CarnLogI(LOG_CAT_SYSTEM, StringFormat("Closed %d SOUP positions (failed: %d)", closed, closeFailed));
            if(EnableAlerts) Alert("CARNEVAL: Chiuse ", closed, " posizioni SOUP");
        }

        UpdateDashboard();
        return;
    }

    // === CLOSE BREAKOUTS ===
    if(sparam == CtrlObjName(BTN_CLOSE_BKO))
    {
        ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
        int closed = 0, closeFailed = 0;
        for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
            ulong ticket = PositionGetTicket(i);
            if(ticket == 0) continue;
            if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
            if(PositionGetInteger(POSITION_MAGIC) == MagicNumber + 1)
            {
                trade.SetExpertMagicNumber(MagicNumber + 1);
                if(trade.PositionClose(ticket))
                {
                    closed++;
                    CarnLogI(LOG_CAT_ORDER, StringFormat("CLOSE BKOUTS — #%s closed OK", IntegerToString(ticket)));
                }
                else
                {
                    closeFailed++;
                    CarnLogE(LOG_CAT_ORDER, StringFormat("CLOSE BKOUTS — #%s FAILED: %s",
                             IntegerToString(ticket), trade.ResultRetcodeDescription()));
                }
            }
        }
        // Cancel pending orders
        int cancelled = 0, cancelFailed = 0;
        for(int i = OrdersTotal() - 1; i >= 0; i--)
        {
            ulong ticket = OrderGetTicket(i);
            if(ticket == 0) continue;
            if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
            if(OrderGetInteger(ORDER_MAGIC) == MagicNumber + 1)
            {
                if(trade.OrderDelete(ticket))
                {
                    cancelled++;
                    CarnLogI(LOG_CAT_ORDER, StringFormat("CLOSE BKOUTS — Pending #%s deleted OK", IntegerToString(ticket)));
                }
                else
                {
                    cancelFailed++;
                    CarnLogE(LOG_CAT_ORDER, StringFormat("CLOSE BKOUTS — Pending #%s DELETE FAILED: %s",
                             IntegerToString(ticket), trade.ResultRetcodeDescription()));
                }
            }
        }
        CarnLogI(LOG_CAT_SYSTEM, StringFormat("Closed %d BREAKOUT positions (failed: %d), cancelled %d orders (failed: %d)",
                 closed, closeFailed, cancelled, cancelFailed));
        if(EnableAlerts) Alert("CARNEVAL: Chiuse ", closed, " pos + ", cancelled, " ordini BREAKOUT");

        UpdateDashboard();
        return;
    }

    // === RECOVER (Manual Recovery) ===
    if(sparam == CtrlObjName(BTN_RECOVER))
    {
        ObjectSetInteger(0, sparam, OBJPROP_STATE, false);

        CarnLogI(LOG_CAT_UI, "=== MANUAL RECOVERY REQUESTED ===");

        // Reset recovery flags before attempting
        g_recoveryPerformed = false;
        g_recoveredPositions = 0;
        g_recoveredPendings = 0;

        AttemptRecovery();

        if(g_recoveryPerformed)
        {
            systemState = STATE_ACTIVE;
            HighlightActiveButton(BTN_START);
            CarnLogI(LOG_CAT_RECOVERY, StringFormat("Recovery successful — %d positions, %d pendings recovered",
                     g_recoveredPositions, g_recoveredPendings));
            if(EnableAlerts)
                Alert("CARNEVAL [", _Symbol, "]: Recovery OK — ",
                      g_recoveredPositions, " pos + ",
                      g_recoveredPendings, " pending");
        }
        else
        {
            CarnLogI(LOG_CAT_RECOVERY, "No positions found to recover");
            if(EnableAlerts)
                Alert("CARNEVAL [", _Symbol, "]: No positions found to recover");
        }

        UpdateButtonFeedback();
        UpdateDashboard();
        return;
    }

}

//+------------------------------------------------------------------+
//| RemoveControlButtons — Rimuovi tutti gli oggetti bottone         |
//| Nota: DestroyDashboard() con ObjectsDeleteAll("CARN_") copre    |
//| tutto. Questa funzione e' mantenuta per uso standalone.          |
//+------------------------------------------------------------------+
void RemoveControlButtons()
{
    ObjectDelete(0, CtrlObjName(BTN_START));
    ObjectDelete(0, CtrlObjName(BTN_PAUSE));
    ObjectDelete(0, CtrlObjName(BTN_CLOSE));
    ObjectDelete(0, CtrlObjName(BTN_CLOSE_SOUPS));
    ObjectDelete(0, CtrlObjName(BTN_CLOSE_BKO));
    ObjectDelete(0, CtrlObjName(BTN_RECOVER));
    ObjectDelete(0, CtrlObjName(BTN_STATUS));
}

//+------------------------------------------------------------------+
//| DeinitializeControlButtons — Cleanup completo                    |
//+------------------------------------------------------------------+
void DeinitializeControlButtons()
{
    RemoveControlButtons();
    CarnLogD(LOG_CAT_UI, "Control buttons deinitialized");
}
