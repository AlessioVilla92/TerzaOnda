//+------------------------------------------------------------------+
//|                                    adRecoveryManager.mqh         |
//|           AcquaDulza EA v1.4.0 — Recovery Manager                |
//|                                                                  |
//|  Broker scan recovery: reconstruct cycles from positions/orders  |
//|                                                                  |
//|  v1.4.0: Scan hedge positions/orders (MagicNumber+1)             |
//|    Posizioni hedge attive → hedgeActive=true, CYCLE_HEDGING      |
//|    Ordini hedge pendenti → hedgePending=true                     |
//|    Entrambi protetti da guard EnableHedge                         |
//+------------------------------------------------------------------+
#property copyright "AcquaDulza (C) 2026"

//+------------------------------------------------------------------+
//| Recovery Variables                                               |
//+------------------------------------------------------------------+
bool     g_recoveryPerformed  = false;
int      g_recoveredPositions = 0;
int      g_recoveredPendings  = 0;

//+------------------------------------------------------------------+
//| ParseCycleIDFromComment — Extract cycle ID from order comment   |
//|  Format: "AD_BUY_#12", "AD_SELL_#3"                             |
//+------------------------------------------------------------------+
int ParseCycleIDFromComment(string comment)
{
   int hashPos = StringFind(comment, "#");
   if(hashPos < 0) return -1;

   string idStr = StringSubstr(comment, hashPos + 1);

   // Remove non-numeric chars after ID
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
//| ParseDirection — Determine direction from comment               |
//+------------------------------------------------------------------+
int ParseDirectionFromComment(string comment)
{
   if(StringFind(comment, "AD_BUY") >= 0)  return +1;
   if(StringFind(comment, "AD_SELL") >= 0) return -1;
   return 0;
}

//+------------------------------------------------------------------+
//| FindOrCreateCycleSlot — Find existing or create new slot        |
//+------------------------------------------------------------------+
int FindOrCreateCycleSlot(int cycleID)
{
   for(int i = 0; i < ArraySize(g_cycles); i++)
   {
      if(g_cycles[i].cycleID == cycleID)
         return i;
   }

   int newSize = ArraySize(g_cycles) + 1;
   if(newSize > MAX_CYCLES) newSize = MAX_CYCLES;
   ArrayResize(g_cycles, newSize);
   int slot = newSize - 1;
   g_cycles[slot].state   = CYCLE_IDLE;
   g_cycles[slot].cycleID = cycleID;
   return slot;
}

//+------------------------------------------------------------------+
//| AttemptRecovery — Scan broker positions/orders, rebuild cycles  |
//+------------------------------------------------------------------+
void AttemptRecovery()
{
   AdLogI(LOG_CAT_RECOVERY, "=== STARTING BROKER SCAN ===");

   g_recoveredPositions = 0;
   g_recoveredPendings  = 0;
   int maxCycleID = 0;

   // === SCAN OPEN POSITIONS ===
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;

      string comment = PositionGetString(POSITION_COMMENT);
      int cycleID = ParseCycleIDFromComment(comment);
      if(cycleID < 0) continue;

      int direction = ParseDirectionFromComment(comment);
      if(direction == 0) continue;

      int slot = FindOrCreateCycleSlot(cycleID);
      g_cycles[slot].direction  = direction;
      g_cycles[slot].ticket     = ticket;
      g_cycles[slot].entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      g_cycles[slot].tpPrice    = PositionGetDouble(POSITION_TP);
      g_cycles[slot].slPrice    = PositionGetDouble(POSITION_SL);
      g_cycles[slot].lotSize    = PositionGetDouble(POSITION_VOLUME);
      g_cycles[slot].signalTime = (datetime)PositionGetInteger(POSITION_TIME);
      g_cycles[slot].state      = CYCLE_ACTIVE;

      AdLogI(LOG_CAT_RECOVERY, StringFormat("Position recovered — #%d %s | Ticket=%d | Entry=%s",
             cycleID, direction > 0 ? "BUY" : "SELL", ticket,
             DoubleToString(g_cycles[slot].entryPrice, _Digits)));

      if(cycleID > maxCycleID) maxCycleID = cycleID;
      g_recoveredPositions++;
   }

   // === SCAN HEDGE POSITIONS (MagicNumber + 1) ===
   if(EnableHedge)
   {
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0) continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
         if(PositionGetInteger(POSITION_MAGIC) != MagicNumber + 1) continue;

         string comment = PositionGetString(POSITION_COMMENT);
         int cycleID = ParseCycleIDFromComment(comment);
         if(cycleID < 0) continue;

         for(int j = 0; j < ArraySize(g_cycles); j++)
         {
            if(g_cycles[j].cycleID == cycleID)
            {
               g_cycles[j].hedgeTicket       = ticket;
               g_cycles[j].hedgeActive       = true;
               g_cycles[j].hedgePending      = false;
               g_cycles[j].hedgeLotSize      = PositionGetDouble(POSITION_VOLUME);
               g_cycles[j].hedgeTriggerPrice = PositionGetDouble(POSITION_PRICE_OPEN);
               g_cycles[j].hedgeTPPrice      = PositionGetDouble(POSITION_TP);
               if(g_cycles[j].state == CYCLE_ACTIVE)
                  g_cycles[j].state = CYCLE_HEDGING;

               AdLogI(LOG_CAT_RECOVERY, StringFormat(
                  "Hedge position recovered — #%d | Ticket=%d | Entry=%s",
                  cycleID, ticket, DoubleToString(g_cycles[j].hedgeTriggerPrice, _Digits)));
               break;
            }
         }
      }
   }

   // === SCAN PENDING ORDERS ===
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
      if(OrderGetInteger(ORDER_MAGIC) != MagicNumber) continue;

      string comment = OrderGetString(ORDER_COMMENT);
      int cycleID = ParseCycleIDFromComment(comment);
      if(cycleID < 0) continue;

      int direction = ParseDirectionFromComment(comment);
      if(direction == 0) continue;

      int slot = FindOrCreateCycleSlot(cycleID);
      g_cycles[slot].direction  = direction;
      g_cycles[slot].ticket     = ticket;
      g_cycles[slot].entryPrice = OrderGetDouble(ORDER_PRICE_OPEN);
      g_cycles[slot].tpPrice    = OrderGetDouble(ORDER_TP);
      g_cycles[slot].slPrice    = OrderGetDouble(ORDER_SL);
      g_cycles[slot].lotSize    = OrderGetDouble(ORDER_VOLUME_CURRENT);
      g_cycles[slot].placedTime = (datetime)OrderGetInteger(ORDER_TIME_SETUP);
      g_cycles[slot].state      = CYCLE_PENDING;

      AdLogI(LOG_CAT_RECOVERY, StringFormat("Pending recovered — #%d %s | Ticket=%d | Entry=%s",
             cycleID, direction > 0 ? "BUY" : "SELL", ticket,
             DoubleToString(g_cycles[slot].entryPrice, _Digits)));

      if(cycleID > maxCycleID) maxCycleID = cycleID;
      g_recoveredPendings++;
   }

   // === SCAN HEDGE PENDING ORDERS (MagicNumber + 1) ===
   if(EnableHedge)
   {
      for(int i = OrdersTotal() - 1; i >= 0; i--)
      {
         ulong ticket = OrderGetTicket(i);
         if(ticket == 0) continue;
         if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
         if(OrderGetInteger(ORDER_MAGIC) != MagicNumber + 1) continue;

         string comment = OrderGetString(ORDER_COMMENT);
         int cycleID = ParseCycleIDFromComment(comment);
         if(cycleID < 0) continue;

         for(int j = 0; j < ArraySize(g_cycles); j++)
         {
            if(g_cycles[j].cycleID == cycleID)
            {
               g_cycles[j].hedgeTicket       = ticket;
               g_cycles[j].hedgePending      = true;
               g_cycles[j].hedgeActive       = false;
               g_cycles[j].hedgeLotSize      = OrderGetDouble(ORDER_VOLUME_CURRENT);
               g_cycles[j].hedgeTriggerPrice = OrderGetDouble(ORDER_PRICE_OPEN);
               g_cycles[j].hedgeTPPrice      = OrderGetDouble(ORDER_TP);

               AdLogI(LOG_CAT_RECOVERY, StringFormat(
                  "Hedge pending recovered — #%d | Ticket=%d | Trigger=%s",
                  cycleID, ticket, DoubleToString(g_cycles[j].hedgeTriggerPrice, _Digits)));
               break;
            }
         }
      }
   }

   // Update next cycle ID
   g_nextCycleID = maxCycleID + 1;

   // Summary
   int activeCycles = CountActiveCycles();
   g_recoveryPerformed = (g_recoveredPositions > 0 || g_recoveredPendings > 0);

   AdLogI(LOG_CAT_RECOVERY, StringFormat("=== SCAN COMPLETE === Positions=%d | Pendings=%d | Active=%d | NextID=%d",
          g_recoveredPositions, g_recoveredPendings, activeCycles, g_nextCycleID));

   if(g_recoveryPerformed)
   {
      g_systemState = STATE_ACTIVE;
      AdLogI(LOG_CAT_RECOVERY, StringFormat("System set to ACTIVE — recovered %d cycle(s)", activeCycles));
   }
   else
   {
      AdLogI(LOG_CAT_RECOVERY, "No AcquaDulza orders found — clean start");
   }
}
