//+------------------------------------------------------------------+
//|                                    carnStatePersistence.mqh      |
//|                Carneval EA - State Persistence                  |
//|  Auto-save & restore SignalCycle array via GlobalVariables        |
//+------------------------------------------------------------------+
#property copyright "Sugamara Ribelle (C) 2026"

//+------------------------------------------------------------------+
//| GLOBAL VARIABLE PREFIX                                           |
//+------------------------------------------------------------------+
#define CARN_GV_PREFIX "CARN_STATE_"

//+------------------------------------------------------------------+
//| STATE PERSISTENCE VARIABLES                                      |
//+------------------------------------------------------------------+
datetime g_lastAutoSaveTime = 0;
int      g_savedVariableCount = 0;
int      g_saveErrors = 0;

//+------------------------------------------------------------------+
//| GetStateKey — Genera chiave univoca per simbolo + MagicNumber    |
//+------------------------------------------------------------------+
string GetStateKey(string varName)
{
    return CARN_GV_PREFIX + _Symbol + "_" + IntegerToString(MagicNumber) + "_" + varName;
}

//+------------------------------------------------------------------+
//| SaveStateDouble / Int / Ulong / Bool — Helpers                   |
//+------------------------------------------------------------------+
bool SaveStateDouble(string name, double value)
{
    datetime result = GlobalVariableSet(GetStateKey(name), value);
    if(result == 0)
    {
        g_saveErrors++;
        return false;
    }
    g_savedVariableCount++;
    return true;
}

bool SaveStateInt(string name, int value)
{
    return SaveStateDouble(name, (double)value);
}

bool SaveStateUlong(string name, ulong value)
{
    return SaveStateDouble(name, (double)value);
}

bool SaveStateBool(string name, bool value)
{
    return SaveStateDouble(name, value ? 1.0 : 0.0);
}

//+------------------------------------------------------------------+
//| RestoreStateDouble / Int / Ulong / Bool — Helpers                |
//+------------------------------------------------------------------+
double RestoreStateDouble(string name, double defaultValue = 0)
{
    string key = GetStateKey(name);
    if(!GlobalVariableCheck(key))
        return defaultValue;
    return GlobalVariableGet(key);
}

int RestoreStateInt(string name, int defaultValue = 0)
{
    return (int)RestoreStateDouble(name, (double)defaultValue);
}

ulong RestoreStateUlong(string name, ulong defaultValue = 0)
{
    return (ulong)RestoreStateDouble(name, (double)defaultValue);
}

bool RestoreStateBool(string name, bool defaultValue = false)
{
    return RestoreStateDouble(name, defaultValue ? 1.0 : 0.0) > 0.5;
}

//+------------------------------------------------------------------+
//| HasSavedState — Controlla se esiste stato salvato valido         |
//+------------------------------------------------------------------+
bool HasSavedState()
{
    if(!Enable_AutoRecovery) return false;

    // Controlla se esiste timestamp ultimo salvataggio
    string key = GetStateKey("lastSaveTime");
    if(!GlobalVariableCheck(key))
        return false;

    // Controlla eta' stato salvato (max 7 giorni)
    datetime lastSave = (datetime)GlobalVariableGet(key);
    datetime now = TimeCurrent();
    if(now - lastSave > 7 * 24 * 60 * 60)
    {
        CarnLogW(LOG_CAT_PERSIST, StringFormat("Saved state too old (%d days) — clearing",
                 (now - lastSave) / 86400));
        ClearSavedState();
        return false;
    }

    // Verifica che ci siano cicli salvati
    int savedCycleCount = (int)RestoreStateDouble("cycleCount", 0);
    if(savedCycleCount <= 0)
        return false;

    // Fresh start detection: se non ci sono posizioni/ordini reali, ignora stato orfano
    bool hasPositions = false;
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket == 0) continue;
        if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
        long magic = PositionGetInteger(POSITION_MAGIC);
        if(magic == MagicNumber || magic == MagicNumber + 1)
        {
            hasPositions = true;
            break;
        }
    }
    if(!hasPositions)
    {
        for(int i = OrdersTotal() - 1; i >= 0; i--)
        {
            ulong ticket = OrderGetTicket(i);
            if(ticket == 0) continue;
            if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
            long magic = OrderGetInteger(ORDER_MAGIC);
            if(magic == MagicNumber || magic == MagicNumber + 1)
            {
                hasPositions = true;
                break;
            }
        }
    }

    if(!hasPositions)
    {
        CarnLogI(LOG_CAT_PERSIST, "Fresh start — no Carneval orders on broker. Clearing orphan state.");
        ClearSavedState();
        return false;
    }

    CarnLogI(LOG_CAT_PERSIST, StringFormat("Valid saved state found — %d cycles, last save: %s",
             savedCycleCount, TimeToString(lastSave, TIME_DATE|TIME_SECONDS)));
    return true;
}

//+------------------------------------------------------------------+
//| SaveState — Salva stato completo (chiamata da OnTimer)           |
//+------------------------------------------------------------------+
void SaveState()
{
    if(!Enable_AutoSave) return;
    if(systemState != STATE_ACTIVE && systemState != STATE_PAUSED) return;

    g_savedVariableCount = 0;
    g_saveErrors = 0;

    // === CORE STATE ===
    SaveStateInt("systemState", (int)systemState);
    SaveStateInt("systemStartTime", (int)systemStartTime);
    SaveStateInt("nextCycleID", g_nextCycleID);

    // === P&L COUNTERS ===
    SaveStateDouble("totalSoupProfit", g_totalSoupProfit);
    SaveStateDouble("totalBreakoutProfit", g_totalBreakoutProfit);
    SaveStateInt("totalSoupWins", g_totalSoupWins);
    SaveStateInt("totalSoupLosses", g_totalSoupLosses);
    SaveStateInt("totalBreakoutWins", g_totalBreakoutWins);
    SaveStateInt("totalBreakoutLosses", g_totalBreakoutLosses);
    SaveStateInt("totalHedgeActivations", g_totalHedgeActivations);

    // === SIGNAL TRACKING ===
    SaveStateInt("totalSignals", g_totalSignals);
    SaveStateInt("buySignals", g_buySignals);
    SaveStateInt("sellSignals", g_sellSignals);

    // === EQUITY ===
    SaveStateDouble("maxEquityReached", maxEquityReached);
    SaveStateDouble("maxDrawdownReached", maxDrawdownReached);

    // === DAILY TRACKING ===
    SaveStateDouble("dailyRealizedProfit", dailyRealizedProfit);
    SaveStateInt("dailyWins", dailyWins);
    SaveStateInt("dailyLosses", dailyLosses);

    // === SESSION TRACKING ===
    SaveStateDouble("sessionRealizedProfit", sessionRealizedProfit);
    SaveStateInt("sessionWins", sessionWins);
    SaveStateInt("sessionLosses", sessionLosses);

    // === SIGNAL CYCLES ARRAY ===
    int cycleCount = ArraySize(g_cycles);
    SaveStateInt("cycleCount", cycleCount);

    for(int i = 0; i < cycleCount; i++)
    {
        string prefix = "cy" + IntegerToString(i) + "_";

        SaveStateInt(prefix + "cycleID", g_cycles[i].cycleID);
        SaveStateInt(prefix + "signalTime", (int)g_cycles[i].signalTime);
        SaveStateInt(prefix + "direction", g_cycles[i].direction);
        SaveStateInt(prefix + "state", (int)g_cycles[i].state);

        // Soup
        SaveStateUlong(prefix + "soupTicket", g_cycles[i].soupTicket);
        SaveStateDouble(prefix + "soupEntry", g_cycles[i].soupEntryPrice);
        SaveStateDouble(prefix + "soupTP", g_cycles[i].soupTP);
        SaveStateDouble(prefix + "soupLot", g_cycles[i].soupLotSize);
        SaveStateBool(prefix + "soupActive", g_cycles[i].soupActive);

        // Breakout
        SaveStateUlong(prefix + "bkoTicket", g_cycles[i].breakoutTicket);
        SaveStateDouble(prefix + "bkoEntry", g_cycles[i].breakoutEntryPrice);
        SaveStateDouble(prefix + "bkoTP", g_cycles[i].breakoutTP);
        SaveStateDouble(prefix + "bkoLot", g_cycles[i].breakoutLotSize);
        SaveStateBool(prefix + "bkoPending", g_cycles[i].breakoutPending);
        SaveStateBool(prefix + "bkoActive", g_cycles[i].breakoutActive);

        // Trigger
        SaveStateUlong(prefix + "trigTicket", g_cycles[i].triggerTicket);
        SaveStateDouble(prefix + "trigEntry", g_cycles[i].triggerEntryPrice);
        SaveStateDouble(prefix + "trigTP", g_cycles[i].triggerTP);
        SaveStateDouble(prefix + "trigLot", g_cycles[i].triggerLotSize);
        SaveStateBool(prefix + "trigPending", g_cycles[i].triggerPending);
        SaveStateBool(prefix + "trigActive", g_cycles[i].triggerActive);
        SaveStateDouble(prefix + "trigSignalPrice", g_cycles[i].triggerSignalPrice);
        SaveStateInt(prefix + "trigPlacedBar", (int)g_cycles[i].triggerPlacedBar);

        // P&L
        SaveStateDouble(prefix + "soupProfit", g_cycles[i].soupProfit);
        SaveStateDouble(prefix + "bkoProfit", g_cycles[i].breakoutProfit);
    }

    // === TIMESTAMP ===
    SaveStateInt("lastSaveTime", (int)TimeCurrent());

    // Flush to disk
    GlobalVariablesFlush();

    g_lastAutoSaveTime = TimeCurrent();

    CarnLogD(LOG_CAT_PERSIST, StringFormat("State saved — %d variables | Cycles: %d | Errors: %d",
             g_savedVariableCount, cycleCount, g_saveErrors));
}

//+------------------------------------------------------------------+
//| RestoreState — Ripristina stato completo                         |
//+------------------------------------------------------------------+
bool RestoreState()
{
    CarnLogI(LOG_CAT_PERSIST, "=== RESTORING STATE ===");

    // === CORE STATE ===
    systemState = (ENUM_SYSTEM_STATE)RestoreStateInt("systemState", (int)STATE_IDLE);
    systemStartTime = (datetime)RestoreStateInt("systemStartTime", 0);
    g_nextCycleID = RestoreStateInt("nextCycleID", 1);

    // === P&L COUNTERS ===
    g_totalSoupProfit = RestoreStateDouble("totalSoupProfit");
    g_totalBreakoutProfit = RestoreStateDouble("totalBreakoutProfit");
    g_totalSoupWins = RestoreStateInt("totalSoupWins");
    g_totalSoupLosses = RestoreStateInt("totalSoupLosses");
    g_totalBreakoutWins = RestoreStateInt("totalBreakoutWins");
    g_totalBreakoutLosses = RestoreStateInt("totalBreakoutLosses");
    g_totalHedgeActivations = RestoreStateInt("totalHedgeActivations");

    // === SIGNAL TRACKING ===
    g_totalSignals = RestoreStateInt("totalSignals");
    g_buySignals = RestoreStateInt("buySignals");
    g_sellSignals = RestoreStateInt("sellSignals");

    // === EQUITY ===
    maxEquityReached = RestoreStateDouble("maxEquityReached");
    maxDrawdownReached = RestoreStateDouble("maxDrawdownReached");

    // === DAILY TRACKING ===
    dailyRealizedProfit = RestoreStateDouble("dailyRealizedProfit");
    dailyWins = RestoreStateInt("dailyWins");
    dailyLosses = RestoreStateInt("dailyLosses");

    // === SESSION TRACKING ===
    sessionRealizedProfit = RestoreStateDouble("sessionRealizedProfit");
    sessionWins = RestoreStateInt("sessionWins");
    sessionLosses = RestoreStateInt("sessionLosses");

    // === SIGNAL CYCLES ARRAY ===
    int cycleCount = RestoreStateInt("cycleCount", 0);
    if(cycleCount > 0)
    {
        ArrayResize(g_cycles, cycleCount);

        for(int i = 0; i < cycleCount; i++)
        {
            string prefix = "cy" + IntegerToString(i) + "_";

            g_cycles[i].Reset();
            g_cycles[i].cycleID = RestoreStateInt(prefix + "cycleID");
            g_cycles[i].signalTime = (datetime)RestoreStateInt(prefix + "signalTime");
            g_cycles[i].direction = RestoreStateInt(prefix + "direction");
            g_cycles[i].state = (ENUM_CYCLE_STATE)RestoreStateInt(prefix + "state");

            // Soup
            g_cycles[i].soupTicket = RestoreStateUlong(prefix + "soupTicket");
            g_cycles[i].soupEntryPrice = RestoreStateDouble(prefix + "soupEntry");
            g_cycles[i].soupTP = RestoreStateDouble(prefix + "soupTP");
            g_cycles[i].soupLotSize = RestoreStateDouble(prefix + "soupLot");
            g_cycles[i].soupActive = RestoreStateBool(prefix + "soupActive");

            // Breakout
            g_cycles[i].breakoutTicket = RestoreStateUlong(prefix + "bkoTicket");
            g_cycles[i].breakoutEntryPrice = RestoreStateDouble(prefix + "bkoEntry");
            g_cycles[i].breakoutTP = RestoreStateDouble(prefix + "bkoTP");
            g_cycles[i].breakoutLotSize = RestoreStateDouble(prefix + "bkoLot");
            g_cycles[i].breakoutPending = RestoreStateBool(prefix + "bkoPending");
            g_cycles[i].breakoutActive = RestoreStateBool(prefix + "bkoActive");

            // Trigger
            g_cycles[i].triggerTicket = RestoreStateUlong(prefix + "trigTicket");
            g_cycles[i].triggerEntryPrice = RestoreStateDouble(prefix + "trigEntry");
            g_cycles[i].triggerTP = RestoreStateDouble(prefix + "trigTP");
            g_cycles[i].triggerLotSize = RestoreStateDouble(prefix + "trigLot");
            g_cycles[i].triggerPending = RestoreStateBool(prefix + "trigPending");
            g_cycles[i].triggerActive = RestoreStateBool(prefix + "trigActive");
            g_cycles[i].triggerSignalPrice = RestoreStateDouble(prefix + "trigSignalPrice");
            g_cycles[i].triggerPlacedBar = (datetime)RestoreStateInt(prefix + "trigPlacedBar");

            // P&L
            g_cycles[i].soupProfit = RestoreStateDouble(prefix + "soupProfit");
            g_cycles[i].breakoutProfit = RestoreStateDouble(prefix + "bkoProfit");
        }
    }

    // Validate restored cycles against broker
    int validated = 0;
    int invalidated = 0;
    for(int i = 0; i < ArraySize(g_cycles); i++)
    {
        if(g_cycles[i].state == CYCLE_IDLE || g_cycles[i].state == CYCLE_CLOSED)
            continue;

        // Verifica che i ticket siano ancora validi
        if(g_cycles[i].soupActive && !IsPositionOpen(g_cycles[i].soupTicket))
        {
            CarnLogW(LOG_CAT_PERSIST, StringFormat("Cycle #%d — Soup ticket %s no longer open",
                     g_cycles[i].cycleID, IntegerToString(g_cycles[i].soupTicket)));
            g_cycles[i].soupActive = false;
            invalidated++;
        }

        if(g_cycles[i].breakoutActive && !IsPositionOpen(g_cycles[i].breakoutTicket))
        {
            CarnLogW(LOG_CAT_PERSIST, StringFormat("Cycle #%d — Breakout ticket %s no longer open",
                     g_cycles[i].cycleID, IntegerToString(g_cycles[i].breakoutTicket)));
            g_cycles[i].breakoutActive = false;
            invalidated++;
        }

        if(g_cycles[i].triggerActive && !IsPositionOpen(g_cycles[i].triggerTicket))
        {
            CarnLogW(LOG_CAT_PERSIST, StringFormat("Cycle #%d — Trigger ticket %s no longer open",
                     g_cycles[i].cycleID, IntegerToString(g_cycles[i].triggerTicket)));
            g_cycles[i].triggerActive = false;
            invalidated++;
        }

        // Se nessuna posizione/pendente attiva, il ciclo e' chiuso
        if(!g_cycles[i].soupActive && !g_cycles[i].breakoutActive && !g_cycles[i].breakoutPending
           && !g_cycles[i].triggerActive && !g_cycles[i].triggerPending)
        {
            CarnLogW(LOG_CAT_PERSIST, StringFormat("State: %s -> CLOSED #%d (no active positions after restore validation)",
                     EnumToString(g_cycles[i].state), g_cycles[i].cycleID));
            g_cycles[i].state = CYCLE_CLOSED;
        }
        else
        {
            validated++;
        }
    }

    // === RIDISEGNA LINEE TP PER TRIGGER ATTIVI (v2.3) ===
    // Gli oggetti grafico non persistono tra sessioni MT5 — vanno ricreati
    for(int i = 0; i < ArraySize(g_cycles); i++)
    {
        if(g_cycles[i].triggerActive && g_cycles[i].triggerTP > 0)
        {
            DrawTriggerTPLine(g_cycles[i].cycleID, g_cycles[i].triggerTP,
                              g_cycles[i].direction > 0);
            CarnLogI(LOG_CAT_PERSIST, StringFormat("Redrawn TP line for Cycle #%d @ %s",
                     g_cycles[i].cycleID, DoubleToString(g_cycles[i].triggerTP, _Digits)));
        }
    }

    CarnLogI(LOG_CAT_PERSIST, StringFormat("=== RESTORE COMPLETE === Cycles: %d restored, %d validated, %d invalidated | P&L: Soup=%s Bko=%s Hedges=%d",
             cycleCount, validated, invalidated,
             DoubleToString(g_totalSoupProfit, 2),
             DoubleToString(g_totalBreakoutProfit, 2),
             g_totalHedgeActivations));

    return (cycleCount > 0);
}

//+------------------------------------------------------------------+
//| ExecuteAutoSave — Chiamata periodica (controlla intervallo)      |
//+------------------------------------------------------------------+
void ExecuteAutoSave()
{
    if(!Enable_AutoSave) return;
    if(systemState != STATE_ACTIVE && systemState != STATE_PAUSED) return;
    if(g_lastAutoSaveTime == 0)
    {
        // Prima volta — salva subito
        SaveState();
        return;
    }

    int intervalSeconds = AutoSave_Interval_Minutes * 60;
    if(TimeCurrent() - g_lastAutoSaveTime >= intervalSeconds)
    {
        SaveState();
    }
}

//+------------------------------------------------------------------+
//| ClearSavedState — Cancella tutto lo stato salvato                |
//+------------------------------------------------------------------+
void ClearSavedState()
{
    // Cancella tutte le GlobalVariables con prefisso CARN_STATE_
    string prefix = CARN_GV_PREFIX + _Symbol + "_" + IntegerToString(MagicNumber) + "_";
    int deleted = 0;

    // GlobalVariables non ha un DeleteByPrefix, quindi iteriamo
    int total = GlobalVariablesTotal();
    for(int i = total - 1; i >= 0; i--)
    {
        string name = GlobalVariableName(i);
        if(StringFind(name, prefix) == 0)
        {
            GlobalVariableDel(name);
            deleted++;
        }
    }

    GlobalVariablesFlush();
    CarnLogI(LOG_CAT_PERSIST, StringFormat("Cleared %d saved state variables", deleted));
}
