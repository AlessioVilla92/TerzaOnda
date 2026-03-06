//+------------------------------------------------------------------+
//|                                    carnRecoveryManager.mqh       |
//|                Carneval EA - Recovery Manager                   |
//|  Position recovery after restart via broker scan + comment parse  |
//+------------------------------------------------------------------+
#property copyright "Sugamara Ribelle (C) 2026"

//+------------------------------------------------------------------+
//| RECOVERY VARIABLES                                               |
//+------------------------------------------------------------------+
bool     g_recoveryPerformed = false;
int      g_recoveredPositions = 0;
int      g_recoveredPendings = 0;
datetime g_lastRecoveryTime = 0;

//+------------------------------------------------------------------+
//| ParseCycleIDFromComment — Estrae cycle ID dal commento ordine    |
//| Formati: "CARN_SOUP_BUY_#12", "CARN_BKO_SELL_#3",              |
//|          "CARN_TRIG_BUY_#5", "CARN_TRIG_SELL_#7"              |
//| Ritorna cycle ID o -1 se non riconosciuto                        |
//+------------------------------------------------------------------+
int ParseCycleIDFromComment(string comment)
{
    // Cerca "#" nel commento
    int hashPos = StringFind(comment, "#");
    if(hashPos < 0) return -1;

    // Estrai la parte dopo "#"
    string idStr = StringSubstr(comment, hashPos + 1);

    // Rimuovi eventuali caratteri non numerici dopo l'ID
    int len = StringLen(idStr);
    for(int i = 0; i < len; i++)
    {
        int ch = StringGetCharacter(idStr, i);
        if(ch < '0' || ch > '9')
        {
            idStr = StringSubstr(idStr, 0, i);
            break;
        }
    }

    if(StringLen(idStr) == 0) return -1;
    return (int)StringToInteger(idStr);
}

//+------------------------------------------------------------------+
//| ParseOrderType — Determina tipo (SOUP/BKO/TRIG) e direzione      |
//| Ritorna: true se parsato con successo                            |
//+------------------------------------------------------------------+
bool ParseOrderType(string comment, bool &isSoup, bool &isTrigger, int &direction)
{
    isSoup = false;
    isTrigger = false;
    direction = 0;

    if(StringFind(comment, "CARN_SOUP_BUY") >= 0)
    {
        isSoup = true;
        direction = 1;
        return true;
    }
    if(StringFind(comment, "CARN_SOUP_SELL") >= 0)
    {
        isSoup = true;
        direction = -1;
        return true;
    }
    if(StringFind(comment, "CARN_BKO_BUY") >= 0)
    {
        direction = 1;
        return true;
    }
    if(StringFind(comment, "CARN_BKO_SELL") >= 0)
    {
        direction = -1;
        return true;
    }
    if(StringFind(comment, "CARN_TRIG_BUY") >= 0)
    {
        isTrigger = true;
        direction = 1;
        return true;
    }
    if(StringFind(comment, "CARN_TRIG_SELL") >= 0)
    {
        isTrigger = true;
        direction = -1;
        return true;
    }

    return false;
}

//+------------------------------------------------------------------+
//| FindOrCreateCycleSlot — Trova slot per cycleID o crea nuovo      |
//+------------------------------------------------------------------+
int FindOrCreateCycleSlot(int cycleID)
{
    // Cerca slot esistente con questo cycleID
    for(int i = 0; i < ArraySize(g_cycles); i++)
    {
        if(g_cycles[i].cycleID == cycleID)
            return i;
    }

    // Non trovato — crea nuovo slot
    int newSize = ArraySize(g_cycles) + 1;
    ArrayResize(g_cycles, newSize);
    int slot = newSize - 1;
    g_cycles[slot].Reset();
    g_cycles[slot].cycleID = cycleID;
    return slot;
}

//+------------------------------------------------------------------+
//| AttemptRecovery — Scansiona posizioni/ordini broker e ricostruisce|
//| l'array g_cycles[] senza bisogno di stato salvato                |
//+------------------------------------------------------------------+
void AttemptRecovery()
{
    CarnLogI(LOG_CAT_RECOVERY, "=== STARTING BROKER SCAN ===");

    g_recoveredPositions = 0;
    g_recoveredPendings = 0;

    int maxCycleID = 0;

    // === SCAN OPEN POSITIONS ===
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket == 0) continue;
        if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

        long magic = PositionGetInteger(POSITION_MAGIC);
        if(magic != MagicNumber && magic != MagicNumber + 1) continue;

        string comment = PositionGetString(POSITION_COMMENT);
        int cycleID = ParseCycleIDFromComment(comment);
        if(cycleID < 0)
        {
            CarnLogW(LOG_CAT_RECOVERY, "Cannot parse comment: " + comment + " — skipping");
            continue;
        }

        bool isSoup = false;
        bool isTrigger = false;
        int direction = 0;
        if(!ParseOrderType(comment, isSoup, isTrigger, direction))
        {
            CarnLogW(LOG_CAT_RECOVERY, "Cannot determine order type: " + comment);
            continue;
        }

        int slot = FindOrCreateCycleSlot(cycleID);

        // Aggiorna dati comuni
        g_cycles[slot].direction = direction;
        g_cycles[slot].signalTime = (datetime)PositionGetInteger(POSITION_TIME);

        if(isSoup)
        {
            g_cycles[slot].soupTicket = ticket;
            g_cycles[slot].soupEntryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            g_cycles[slot].soupTP = PositionGetDouble(POSITION_TP);
            g_cycles[slot].soupLotSize = PositionGetDouble(POSITION_VOLUME);
            g_cycles[slot].soupActive = true;

            CarnLogI(LOG_CAT_RECOVERY, StringFormat("SOUP position found — Cycle #%d | Ticket: %s | Entry: %s | Lot: %s",
                     cycleID, IntegerToString(ticket),
                     DoubleToString(g_cycles[slot].soupEntryPrice, _Digits),
                     DoubleToString(g_cycles[slot].soupLotSize, 2)));
        }
        else if(isTrigger)
        {
            g_cycles[slot].triggerTicket = ticket;
            g_cycles[slot].triggerEntryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            g_cycles[slot].triggerTP = PositionGetDouble(POSITION_TP);
            g_cycles[slot].triggerLotSize = PositionGetDouble(POSITION_VOLUME);
            g_cycles[slot].triggerActive = true;
            g_cycles[slot].triggerPending = false;

            CarnLogI(LOG_CAT_RECOVERY, StringFormat("TRIGGER position found — Cycle #%d | Ticket: %s | Entry: %s | Lot: %s",
                     cycleID, IntegerToString(ticket),
                     DoubleToString(g_cycles[slot].triggerEntryPrice, _Digits),
                     DoubleToString(g_cycles[slot].triggerLotSize, 2)));
        }
        else
        {
            g_cycles[slot].breakoutTicket = ticket;
            g_cycles[slot].breakoutEntryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            g_cycles[slot].breakoutTP = PositionGetDouble(POSITION_TP);
            g_cycles[slot].breakoutLotSize = PositionGetDouble(POSITION_VOLUME);
            g_cycles[slot].breakoutActive = true;
            g_cycles[slot].breakoutPending = false;

            CarnLogI(LOG_CAT_RECOVERY, StringFormat("BREAKOUT position found — Cycle #%d | Ticket: %s | Entry: %s | Lot: %s",
                     cycleID, IntegerToString(ticket),
                     DoubleToString(g_cycles[slot].breakoutEntryPrice, _Digits),
                     DoubleToString(g_cycles[slot].breakoutLotSize, 2)));
        }

        if(cycleID > maxCycleID) maxCycleID = cycleID;
        g_recoveredPositions++;
    }

    // === SCAN PENDING ORDERS ===
    for(int i = OrdersTotal() - 1; i >= 0; i--)
    {
        ulong ticket = OrderGetTicket(i);
        if(ticket == 0) continue;
        if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;

        long magic = OrderGetInteger(ORDER_MAGIC);
        if(magic != MagicNumber && magic != MagicNumber + 1) continue;

        string comment = OrderGetString(ORDER_COMMENT);
        int cycleID = ParseCycleIDFromComment(comment);
        if(cycleID < 0)
        {
            CarnLogW(LOG_CAT_RECOVERY, "Cannot parse pending comment: " + comment);
            continue;
        }

        bool isSoup = false;
        bool isTrigger = false;
        int direction = 0;
        if(!ParseOrderType(comment, isSoup, isTrigger, direction))
        {
            CarnLogW(LOG_CAT_RECOVERY, "Cannot determine pending type: " + comment);
            continue;
        }

        int slot = FindOrCreateCycleSlot(cycleID);
        g_cycles[slot].direction = direction;

        if(isTrigger)
        {
            // Trigger pending STOP order
            g_cycles[slot].triggerTicket = ticket;
            g_cycles[slot].triggerEntryPrice = OrderGetDouble(ORDER_PRICE_OPEN);
            g_cycles[slot].triggerTP = OrderGetDouble(ORDER_TP);
            g_cycles[slot].triggerLotSize = OrderGetDouble(ORDER_VOLUME_CURRENT);
            g_cycles[slot].triggerPending = true;
            g_cycles[slot].triggerActive = false;

            CarnLogI(LOG_CAT_RECOVERY, StringFormat("TRIGGER pending found — Cycle #%d | Ticket: %s | Price: %s",
                     cycleID, IntegerToString(ticket),
                     DoubleToString(g_cycles[slot].triggerEntryPrice, _Digits)));
        }
        else if(!isSoup)
        {
            // Breakout pending order
            g_cycles[slot].breakoutTicket = ticket;
            g_cycles[slot].breakoutEntryPrice = OrderGetDouble(ORDER_PRICE_OPEN);
            g_cycles[slot].breakoutTP = OrderGetDouble(ORDER_TP);
            g_cycles[slot].breakoutLotSize = OrderGetDouble(ORDER_VOLUME_CURRENT);
            g_cycles[slot].breakoutPending = true;
            g_cycles[slot].breakoutActive = false;

            CarnLogI(LOG_CAT_RECOVERY, StringFormat("BREAKOUT pending found — Cycle #%d | Ticket: %s | Price: %s",
                     cycleID, IntegerToString(ticket),
                     DoubleToString(g_cycles[slot].breakoutEntryPrice, _Digits)));
        }

        if(cycleID > maxCycleID) maxCycleID = cycleID;
        g_recoveredPendings++;
    }

    // === DETERMINA STATO DI OGNI CICLO ===
    for(int i = 0; i < ArraySize(g_cycles); i++)
    {
        if(g_cycles[i].cycleID == 0) continue;

        // --- Trigger mode cycles ---
        if(g_cycles[i].triggerActive)
        {
            g_cycles[i].state = CYCLE_TRIGGER_ACTIVE;
            CarnLogI(LOG_CAT_RECOVERY, StringFormat("Cycle #%d -> TRIGGER_ACTIVE", g_cycles[i].cycleID));
        }
        else if(g_cycles[i].triggerPending)
        {
            g_cycles[i].state = CYCLE_TRIGGER_PENDING;
            CarnLogI(LOG_CAT_RECOVERY, StringFormat("Cycle #%d -> TRIGGER_PENDING", g_cycles[i].cycleID));
        }
        // --- Classic mode cycles ---
        else if(g_cycles[i].soupActive && g_cycles[i].breakoutActive)
        {
            // Entrambe aperte → HEDGING
            g_cycles[i].state = CYCLE_HEDGING;
            g_totalHedgeActivations++;
            CarnLogI(LOG_CAT_RECOVERY, StringFormat("Cycle #%d -> HEDGING (soup+breakout open)", g_cycles[i].cycleID));
        }
        else if(g_cycles[i].soupActive && (g_cycles[i].breakoutPending || !g_cycles[i].breakoutActive))
        {
            // Solo soup aperta → SOUP_ACTIVE
            g_cycles[i].state = CYCLE_SOUP_ACTIVE;
            CarnLogI(LOG_CAT_RECOVERY, StringFormat("Cycle #%d -> SOUP_ACTIVE", g_cycles[i].cycleID));
        }
        else if(!g_cycles[i].soupActive && g_cycles[i].breakoutActive)
        {
            // Solo breakout aperta (soup chiusa durante crash) → HEDGING
            g_cycles[i].state = CYCLE_HEDGING;
            CarnLogI(LOG_CAT_RECOVERY, StringFormat("Cycle #%d -> HEDGING (breakout only, soup lost)", g_cycles[i].cycleID));
        }
        else
        {
            // Nessuna posizione attiva ma ordini pendenti
            if(g_cycles[i].breakoutPending)
            {
                g_cycles[i].state = CYCLE_SOUP_ACTIVE;
                CarnLogI(LOG_CAT_RECOVERY, StringFormat("Cycle #%d -> SOUP_ACTIVE (pending only)", g_cycles[i].cycleID));
            }
            else
            {
                g_cycles[i].state = CYCLE_CLOSED;
            }
        }
    }

    // === AGGIORNA NEXT CYCLE ID ===
    g_nextCycleID = maxCycleID + 1;

    // === RIDISEGNA LINEE TP PER TRIGGER ATTIVI (v2.3) ===
    for(int i = 0; i < ArraySize(g_cycles); i++)
    {
        if(g_cycles[i].triggerActive && g_cycles[i].triggerTP > 0)
        {
            DrawTriggerTPLine(g_cycles[i].cycleID, g_cycles[i].triggerTP,
                              g_cycles[i].direction > 0);
            CarnLogI(LOG_CAT_RECOVERY, StringFormat("Redrawn TP line for Cycle #%d @ %s",
                     g_cycles[i].cycleID, DoubleToString(g_cycles[i].triggerTP, _Digits)));
        }
    }

    // === SUMMARY ===
    int activeCycles = CountActiveCycles();
    g_recoveryPerformed = (g_recoveredPositions > 0 || g_recoveredPendings > 0);
    g_lastRecoveryTime = TimeCurrent();

    CarnLogI(LOG_CAT_RECOVERY, StringFormat("=== SCAN COMPLETE === Positions: %d | Pendings: %d | Active cycles: %d | Next ID: %d",
             g_recoveredPositions, g_recoveredPendings, activeCycles, g_nextCycleID));

    if(g_recoveryPerformed)
    {
        systemState = STATE_ACTIVE;
        CarnLogI(LOG_CAT_RECOVERY, StringFormat("System set to ACTIVE — recovered %d cycle(s)", activeCycles));
    }
    else
    {
        CarnLogI(LOG_CAT_RECOVERY, "No Carneval orders found — clean start");
    }
}

//+------------------------------------------------------------------+
//| IsSoftRestart — Detecta riavvio soft (recompile, params change)  |
//+------------------------------------------------------------------+
bool IsSoftRestart(int reason)
{
    return (reason == REASON_CHARTCHANGE ||
            reason == REASON_PARAMETERS ||
            reason == REASON_RECOMPILE);
}
