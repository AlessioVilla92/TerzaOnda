//+------------------------------------------------------------------+
//|                                    adStatePersistence.mqh        |
//|           AcquaDulza EA v1.5.0 — State Persistence               |
//|                                                                  |
//|  Auto-save & restore CycleRecord array via GlobalVariables       |
//|                                                                  |
//|  v1.5.0: Two-Tier hedge persistence                               |
//|    Save/Restore: H1 (6 campi) + H1 tracking (2) + H2 (6 campi)  |
//|    Validazione: Soup + H1 + H2 — 3 magic numbers                 |
//+------------------------------------------------------------------+
#property copyright "AcquaDulza (C) 2026"

//+------------------------------------------------------------------+
//| Global Variable Prefix                                           |
//+------------------------------------------------------------------+
#define AD_GV_PREFIX "AD_STATE_"

//+------------------------------------------------------------------+
//| Persistence State Variables                                      |
//+------------------------------------------------------------------+
datetime g_lastAutoSaveTime    = 0;
int      g_savedVariableCount  = 0;
int      g_saveErrors          = 0;

//+------------------------------------------------------------------+
//| GetStateKey — Unique key for symbol + magic                     |
//+------------------------------------------------------------------+
string GetStateKey(string varName)
{
   return AD_GV_PREFIX + _Symbol + "_" + IntegerToString(MagicNumber) + "_" + varName;
}

//+------------------------------------------------------------------+
//| Save/Restore Helpers                                             |
//+------------------------------------------------------------------+
bool SaveStateDouble(string name, double value)
{
   datetime result = GlobalVariableSet(GetStateKey(name), value);
   if(result == 0) { g_saveErrors++; return false; }
   g_savedVariableCount++;
   return true;
}

bool SaveStateInt(string name, int value)       { return SaveStateDouble(name, (double)value); }
bool SaveStateUlong(string name, ulong value)   { return SaveStateDouble(name, (double)value); }
bool SaveStateBool(string name, bool value)     { return SaveStateDouble(name, value ? 1.0 : 0.0); }

double RestoreStateDouble(string name, double defaultValue = 0)
{
   string key = GetStateKey(name);
   if(!GlobalVariableCheck(key)) return defaultValue;
   return GlobalVariableGet(key);
}

int   RestoreStateInt(string name, int defaultValue = 0)       { return (int)RestoreStateDouble(name, (double)defaultValue); }
ulong RestoreStateUlong(string name, ulong defaultValue = 0)   { return (ulong)RestoreStateDouble(name, (double)defaultValue); }
bool  RestoreStateBool(string name, bool defaultValue = false)  { return RestoreStateDouble(name, defaultValue ? 1.0 : 0.0) > 0.5; }

//+------------------------------------------------------------------+
//| HasSavedState — Check for valid saved state                     |
//+------------------------------------------------------------------+
bool HasSavedState()
{
   if(!EnableAutoRecovery) return false;

   string key = GetStateKey("lastSaveTime");
   if(!GlobalVariableCheck(key)) return false;

   // Max 7 day age
   datetime lastSave = (datetime)GlobalVariableGet(key);
   if(TimeCurrent() - lastSave > 7 * 86400)
   {
      AdLogW(LOG_CAT_PERSIST, "Saved state too old — clearing");
      ClearSavedState();
      return false;
   }

   int savedCount = (int)RestoreStateDouble("cycleCount", 0);
   if(savedCount <= 0) return false;

   // Fresh start detection: no actual positions = orphan state
   bool hasOrders = false;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      long posMagic = PositionGetInteger(POSITION_MAGIC);
      if(posMagic == MagicNumber || posMagic == MagicNumber + 1)
      { hasOrders = true; break; }
   }
   if(!hasOrders)
   {
      for(int i = OrdersTotal() - 1; i >= 0; i--)
      {
         ulong ticket = OrderGetTicket(i);
         if(ticket == 0) continue;
         if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
         long ordMagic = OrderGetInteger(ORDER_MAGIC);
         if(ordMagic == MagicNumber || ordMagic == MagicNumber + 1)
         { hasOrders = true; break; }
      }
   }

   if(!hasOrders)
   {
      AdLogI(LOG_CAT_PERSIST, "Fresh start — no AcquaDulza orders. Clearing orphan state.");
      ClearSavedState();
      return false;
   }

   AdLogI(LOG_CAT_PERSIST, StringFormat("Valid saved state found — %d cycles, last save: %s",
          savedCount, TimeToString(lastSave, TIME_DATE|TIME_SECONDS)));
   return true;
}

//+------------------------------------------------------------------+
//| SaveState — Save complete state (called from OnTimer)           |
//+------------------------------------------------------------------+
void SaveState()
{
   if(!EnableAutoSave) return;
   if(g_systemState != STATE_ACTIVE && g_systemState != STATE_PAUSED) return;

   g_savedVariableCount = 0;
   g_saveErrors = 0;

   // Core state
   SaveStateInt("systemState", (int)g_systemState);
   SaveStateInt("nextCycleID", g_nextCycleID);

   // P&L
   SaveStateDouble("sessionProfit", g_sessionRealizedProfit);
   SaveStateInt("sessionWins", g_sessionWins);
   SaveStateInt("sessionLosses", g_sessionLosses);

   // Signal tracking
   SaveStateInt("totalSignals", g_totalSignals);
   SaveStateInt("buySignals", g_buySignals);
   SaveStateInt("sellSignals", g_sellSignals);

   // Equity
   SaveStateDouble("maxEquity", g_maxEquity);
   SaveStateDouble("maxDrawdown", g_maxDrawdownPct);

   // Daily tracking
   SaveStateDouble("dailyProfit", g_dailyRealizedProfit);
   SaveStateInt("dailyWins", g_dailyWins);
   SaveStateInt("dailyLosses", g_dailyLosses);

   // Cycles array
   int cycleCount = ArraySize(g_cycles);
   SaveStateInt("cycleCount", cycleCount);

   for(int i = 0; i < cycleCount; i++)
   {
      string p = "cy" + IntegerToString(i) + "_";

      SaveStateInt(p + "id", g_cycles[i].cycleID);
      SaveStateInt(p + "dir", g_cycles[i].direction);
      SaveStateInt(p + "state", (int)g_cycles[i].state);
      SaveStateUlong(p + "ticket", g_cycles[i].ticket);
      SaveStateDouble(p + "entry", g_cycles[i].entryPrice);
      SaveStateDouble(p + "sl", g_cycles[i].slPrice);
      SaveStateDouble(p + "tp", g_cycles[i].tpPrice);
      SaveStateDouble(p + "lot", g_cycles[i].lotSize);
      SaveStateInt(p + "sigTime", (int)g_cycles[i].signalTime);
      SaveStateInt(p + "placTime", (int)g_cycles[i].placedTime);
      SaveStateInt(p + "quality", g_cycles[i].quality);
      SaveStateDouble(p + "profit", g_cycles[i].profit);
      // Hedge 1 fields
      SaveStateUlong(p + "hedgeTkt", g_cycles[i].hedgeTicket);
      SaveStateDouble(p + "hedgeTrig", g_cycles[i].hedgeTriggerPrice);
      SaveStateDouble(p + "hedgeTP", g_cycles[i].hedgeTPPrice);
      SaveStateDouble(p + "hedgeLot", g_cycles[i].hedgeLotSize);
      SaveStateBool(p + "hedgePend", g_cycles[i].hedgePending);
      SaveStateBool(p + "hedgeAct", g_cycles[i].hedgeActive);
      SaveStateDouble(p + "h1Banked", g_cycles[i].hedge1BankedProfit);
      SaveStateBool(p + "h1TPHit", g_cycles[i].hedge1TPHit);
      // Hedge 2 fields
      SaveStateUlong(p + "h2Tkt", g_cycles[i].hedge2Ticket);
      SaveStateDouble(p + "h2Trig", g_cycles[i].hedge2TriggerPrice);
      SaveStateDouble(p + "h2TP", g_cycles[i].hedge2TPPrice);
      SaveStateDouble(p + "h2Lot", g_cycles[i].hedge2LotSize);
      SaveStateBool(p + "h2Pend", g_cycles[i].hedge2Pending);
      SaveStateBool(p + "h2Act", g_cycles[i].hedge2Active);
   }

   // Timestamp
   SaveStateInt("lastSaveTime", (int)TimeCurrent());
   GlobalVariablesFlush();

   g_lastAutoSaveTime = TimeCurrent();
   AdLogI(LOG_CAT_PERSIST, StringFormat("State saved — %d vars | %d cycles | %d errors",
          g_savedVariableCount, cycleCount, g_saveErrors));
}

//+------------------------------------------------------------------+
//| RestoreState — Restore complete state                           |
//+------------------------------------------------------------------+
bool RestoreState()
{
   AdLogI(LOG_CAT_PERSIST, "=== RESTORING STATE ===");

   // Core state
   g_systemState   = (ENUM_SYSTEM_STATE)RestoreStateInt("systemState", (int)STATE_IDLE);
   g_nextCycleID   = RestoreStateInt("nextCycleID", 1);

   // P&L
   g_sessionRealizedProfit = RestoreStateDouble("sessionProfit");
   g_sessionWins   = RestoreStateInt("sessionWins");
   g_sessionLosses = RestoreStateInt("sessionLosses");

   // Signal tracking
   g_totalSignals  = RestoreStateInt("totalSignals");
   g_buySignals    = RestoreStateInt("buySignals");
   g_sellSignals   = RestoreStateInt("sellSignals");

   // Equity
   g_maxEquity      = RestoreStateDouble("maxEquity");
   g_maxDrawdownPct = RestoreStateDouble("maxDrawdown");

   // Daily
   g_dailyRealizedProfit = RestoreStateDouble("dailyProfit");
   g_dailyWins   = RestoreStateInt("dailyWins");
   g_dailyLosses = RestoreStateInt("dailyLosses");

   // Cycles
   int cycleCount = RestoreStateInt("cycleCount", 0);
   if(cycleCount > 0)
   {
      int arraySize = MathMax(cycleCount, MAX_CYCLES);
      ArrayResize(g_cycles, arraySize);
      for(int i = 0; i < cycleCount; i++)
      {
         string p = "cy" + IntegerToString(i) + "_";

         g_cycles[i].cycleID    = RestoreStateInt(p + "id");
         g_cycles[i].direction  = RestoreStateInt(p + "dir");
         g_cycles[i].state      = (ENUM_CYCLE_STATE)RestoreStateInt(p + "state");
         g_cycles[i].ticket     = RestoreStateUlong(p + "ticket");
         g_cycles[i].entryPrice = RestoreStateDouble(p + "entry");
         g_cycles[i].slPrice    = RestoreStateDouble(p + "sl");
         g_cycles[i].tpPrice    = RestoreStateDouble(p + "tp");
         g_cycles[i].lotSize    = RestoreStateDouble(p + "lot");
         g_cycles[i].signalTime = (datetime)RestoreStateInt(p + "sigTime");
         g_cycles[i].placedTime = (datetime)RestoreStateInt(p + "placTime");
         g_cycles[i].quality    = RestoreStateInt(p + "quality");
         g_cycles[i].profit     = RestoreStateDouble(p + "profit");
         // Hedge 1 fields
         g_cycles[i].hedgeTicket       = RestoreStateUlong(p + "hedgeTkt");
         g_cycles[i].hedgeTriggerPrice = RestoreStateDouble(p + "hedgeTrig");
         g_cycles[i].hedgeTPPrice      = RestoreStateDouble(p + "hedgeTP");
         g_cycles[i].hedgeLotSize      = RestoreStateDouble(p + "hedgeLot");
         g_cycles[i].hedgePending      = RestoreStateBool(p + "hedgePend");
         g_cycles[i].hedgeActive       = RestoreStateBool(p + "hedgeAct");
         g_cycles[i].hedgeLineName     = "";  // Visual objects not persisted
         g_cycles[i].hedge1BankedProfit = RestoreStateDouble(p + "h1Banked");
         g_cycles[i].hedge1TPHit       = RestoreStateBool(p + "h1TPHit");
         // Hedge 2 fields
         g_cycles[i].hedge2Ticket       = RestoreStateUlong(p + "h2Tkt");
         g_cycles[i].hedge2TriggerPrice = RestoreStateDouble(p + "h2Trig");
         g_cycles[i].hedge2TPPrice      = RestoreStateDouble(p + "h2TP");
         g_cycles[i].hedge2LotSize      = RestoreStateDouble(p + "h2Lot");
         g_cycles[i].hedge2Pending      = RestoreStateBool(p + "h2Pend");
         g_cycles[i].hedge2Active       = RestoreStateBool(p + "h2Act");
         g_cycles[i].hedge2LineName     = "";  // Visual objects not persisted
      }
   }

   // Validate against broker
   int validated = 0, invalidated = 0;
   for(int i = 0; i < ArraySize(g_cycles); i++)
   {
      if(g_cycles[i].state == CYCLE_IDLE || g_cycles[i].state == CYCLE_CLOSED)
         continue;

      if(g_cycles[i].state == CYCLE_ACTIVE && !IsPositionOpen(g_cycles[i].ticket))
      {
         g_cycles[i].state = CYCLE_CLOSED;
         invalidated++;
      }
      else if(g_cycles[i].state == CYCLE_PENDING && !OrderSelect(g_cycles[i].ticket))
      {
         g_cycles[i].state = CYCLE_CLOSED;
         invalidated++;
      }
      else if(g_cycles[i].state == CYCLE_HEDGING)
      {
         bool soupValid  = (g_cycles[i].ticket > 0) && IsPositionOpen(g_cycles[i].ticket);

         // H1 valido?
         bool h1Valid = false;
         if(g_cycles[i].hedgeActive && g_cycles[i].hedgeTicket > 0)
            h1Valid = IsPositionOpen(g_cycles[i].hedgeTicket);
         else if(g_cycles[i].hedgePending && g_cycles[i].hedgeTicket > 0)
            h1Valid = OrderSelect(g_cycles[i].hedgeTicket);

         // H2 valido?
         bool h2Valid = false;
         if(g_cycles[i].hedge2Active && g_cycles[i].hedge2Ticket > 0)
            h2Valid = IsPositionOpen(g_cycles[i].hedge2Ticket);
         else if(g_cycles[i].hedge2Pending && g_cycles[i].hedge2Ticket > 0)
            h2Valid = OrderSelect(g_cycles[i].hedge2Ticket);

         bool anyHedgeValid = h1Valid || h2Valid;

         if(!soupValid && !anyHedgeValid)
         {
            g_cycles[i].state = CYCLE_CLOSED;
            g_cycles[i].hedgePending = false;
            g_cycles[i].hedgeActive  = false;
            g_cycles[i].hedge2Pending = false;
            g_cycles[i].hedge2Active  = false;
            invalidated++;
         }
         else if(!anyHedgeValid)
         {
            // Hedge spariti ma Soup viva — torna a CYCLE_ACTIVE
            g_cycles[i].state = CYCLE_ACTIVE;
            g_cycles[i].hedgePending = false;
            g_cycles[i].hedgeActive  = false;
            g_cycles[i].hedgeTicket  = 0;
            g_cycles[i].hedge2Pending = false;
            g_cycles[i].hedge2Active  = false;
            g_cycles[i].hedge2Ticket  = 0;
            validated++;
         }
         else if(!soupValid)
         {
            // Soup sparita ma hedge vivo — segna CLOSED, HedgeMonitor fara' cleanup
            g_cycles[i].state = CYCLE_CLOSED;
            invalidated++;
         }
         else
            validated++;
      }
      else
         validated++;
   }

   AdLogI(LOG_CAT_PERSIST, StringFormat("=== RESTORE COMPLETE === %d cycles | %d valid | %d invalidated",
          cycleCount, validated, invalidated));
   return (cycleCount > 0);
}

//+------------------------------------------------------------------+
//| ExecuteAutoSave — Periodic save (check interval)                |
//+------------------------------------------------------------------+
void ExecuteAutoSave()
{
   if(!EnableAutoSave) return;
   if(g_systemState != STATE_ACTIVE && g_systemState != STATE_PAUSED) return;

   if(g_lastAutoSaveTime == 0)
   {
      SaveState();
      return;
   }

   if(TimeCurrent() - g_lastAutoSaveTime >= AutoSaveIntervalMin * 60)
      SaveState();
}

//+------------------------------------------------------------------+
//| ClearSavedState — Delete all saved state variables              |
//+------------------------------------------------------------------+
void ClearSavedState()
{
   string prefix = AD_GV_PREFIX + _Symbol + "_" + IntegerToString(MagicNumber) + "_";
   int deleted = 0;

   for(int i = GlobalVariablesTotal() - 1; i >= 0; i--)
   {
      string name = GlobalVariableName(i);
      if(StringFind(name, prefix) == 0)
      {
         GlobalVariableDel(name);
         deleted++;
      }
   }

   GlobalVariablesFlush();
   AdLogI(LOG_CAT_PERSIST, StringFormat("Cleared %d saved state variables", deleted));
}
