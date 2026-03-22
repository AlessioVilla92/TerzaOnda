//+------------------------------------------------------------------+
//|                                    adRecoveryManager.mqh         |
//|           AcquaDulza EA v1.5.1 — Recovery Manager                |
//|                                                                  |
//|  Broker scan recovery: reconstruct cycles from positions/orders  |
//|                                                                  |
//|  v1.5.1: H1 banked profit recovery from deal history             |
//|    Se H1 TP gia' colpito, ripristina hedge1BankedProfit/TPHit    |
//|    Fix: g_nextCycleID off-by-one (era maxCycleID+1, ora maxID)   |
//|                                                                  |
//|  v1.5.0: Two-Tier hedge scan                                     |
//|    H1 positions/orders: MagicNumber+1                             |
//|    H2 positions/orders: MagicNumber+2                             |
//|    H2 attivo: ripristina SL breakeven se Hedge2BreakevenSL=true  |
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

   // === SCAN HEDGE 2 POSITIONS (MagicNumber + 2) ===
   if(EnableHedge && Hedge2Enabled)
   {
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0) continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
         if(PositionGetInteger(POSITION_MAGIC) != MagicNumber + 2) continue;

         string comment = PositionGetString(POSITION_COMMENT);
         int cycleID = ParseCycleIDFromComment(comment);
         if(cycleID < 0) continue;

         for(int j = 0; j < ArraySize(g_cycles); j++)
         {
            if(g_cycles[j].cycleID == cycleID)
            {
               g_cycles[j].hedge2Ticket       = ticket;
               g_cycles[j].hedge2Active       = true;
               g_cycles[j].hedge2Pending      = false;
               g_cycles[j].hedge2LotSize      = PositionGetDouble(POSITION_VOLUME);
               g_cycles[j].hedge2TriggerPrice = PositionGetDouble(POSITION_PRICE_OPEN);
               g_cycles[j].hedge2TPPrice      = PositionGetDouble(POSITION_TP);
               if(g_cycles[j].state == CYCLE_ACTIVE)
                  g_cycles[j].state = CYCLE_HEDGING;

               AdLogI(LOG_CAT_RECOVERY, StringFormat(
                  "H2 position recovered — #%d | Ticket=%d | Entry=%s",
                  cycleID, ticket, DoubleToString(g_cycles[j].hedge2TriggerPrice, _Digits)));

               // Ripristina SL breakeven se assente
               if(Hedge2BreakevenSL)
               {
                  double currentSL = PositionGetDouble(POSITION_SL);
                  if(currentSL == 0)
                  {
                     double fillPrice = g_cycles[j].hedge2TriggerPrice;
                     double buffer = g_symbolStopsLevel * g_symbolPoint + g_symbolPoint;
                     double beSL;
                     if(g_cycles[j].direction > 0)
                        beSL = fillPrice + buffer;
                     else
                        beSL = fillPrice - buffer;
                     beSL = NormalizeDouble(beSL, _Digits);

                     g_trade.SetExpertMagicNumber(MagicNumber + 2);
                     if(g_trade.PositionModify(ticket, beSL, g_cycles[j].hedge2TPPrice))
                     {
                        AdLogI(LOG_CAT_RECOVERY, StringFormat(
                           "H2 BE SL restored #%d | SL=%s",
                           cycleID, DoubleToString(beSL, _Digits)));
                     }
                  }
               }
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

   // === SCAN HEDGE 2 PENDING ORDERS (MagicNumber + 2) ===
   if(EnableHedge && Hedge2Enabled)
   {
      for(int i = OrdersTotal() - 1; i >= 0; i--)
      {
         ulong ticket = OrderGetTicket(i);
         if(ticket == 0) continue;
         if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
         if(OrderGetInteger(ORDER_MAGIC) != MagicNumber + 2) continue;

         string comment = OrderGetString(ORDER_COMMENT);
         int cycleID = ParseCycleIDFromComment(comment);
         if(cycleID < 0) continue;

         for(int j = 0; j < ArraySize(g_cycles); j++)
         {
            if(g_cycles[j].cycleID == cycleID)
            {
               g_cycles[j].hedge2Ticket       = ticket;
               g_cycles[j].hedge2Pending      = true;
               g_cycles[j].hedge2Active       = false;
               g_cycles[j].hedge2LotSize      = OrderGetDouble(ORDER_VOLUME_CURRENT);
               g_cycles[j].hedge2TriggerPrice = OrderGetDouble(ORDER_PRICE_OPEN);
               g_cycles[j].hedge2TPPrice      = OrderGetDouble(ORDER_TP);

               AdLogI(LOG_CAT_RECOVERY, StringFormat(
                  "H2 pending recovered — #%d | Ticket=%d | Trigger=%s",
                  cycleID, ticket, DoubleToString(g_cycles[j].hedge2TriggerPrice, _Digits)));
               break;
            }
         }
      }
   }

   // === SCAN H1 DEAL HISTORY (banked profit recovery) ===
   // Se un ciclo ha Soup attiva ma nessun H1 (posizione o pendente),
   // H1 potrebbe aver gia' colpito il TP. Cerchiamo nei deal storici
   // per ripristinare hedge1BankedProfit e hedge1TPHit.
   if(EnableHedge && Hedge1Enabled)
   {
      datetime histFrom = TimeCurrent() - 86400 * 7;
      if(HistorySelect(histFrom, TimeCurrent()))
      {
         for(int j = 0; j < ArraySize(g_cycles); j++)
         {
            // Solo cicli attivi/hedging senza H1 recuperato
            if(g_cycles[j].state != CYCLE_ACTIVE && g_cycles[j].state != CYCLE_HEDGING) continue;
            if(g_cycles[j].hedgeActive || g_cycles[j].hedgePending) continue;
            if(g_cycles[j].hedge1BankedProfit != 0) continue;

            string searchTag = StringFormat("#%d", g_cycles[j].cycleID);
            double bankedPL = 0;
            bool found = false;

            for(int d = HistoryDealsTotal() - 1; d >= 0; d--)
            {
               ulong dealTicket = HistoryDealGetTicket(d);
               if(dealTicket == 0) continue;
               if(HistoryDealGetInteger(dealTicket, DEAL_MAGIC) != MagicNumber + 1) continue;
               if(HistoryDealGetString(dealTicket, DEAL_SYMBOL) != _Symbol) continue;

               long entry = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
               if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_OUT_BY) continue;

               string dealComment = HistoryDealGetString(dealTicket, DEAL_COMMENT);
               if(StringFind(dealComment, searchTag) >= 0)
               {
                  bankedPL += HistoryDealGetDouble(dealTicket, DEAL_PROFIT)
                            + HistoryDealGetDouble(dealTicket, DEAL_SWAP)
                            + HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
                  found = true;
               }
            }

            if(found && bankedPL != 0)
            {
               g_cycles[j].hedge1BankedProfit = bankedPL;
               g_cycles[j].hedge1TPHit = (bankedPL > 0);
               AdLogI(LOG_CAT_RECOVERY, StringFormat(
                  "H1 banked profit recovered from history — #%d | P&L=%.2f | TPHit=%s",
                  g_cycles[j].cycleID, bankedPL, bankedPL > 0 ? "YES" : "NO"));
            }
         }
      }
   }

   // Update next cycle ID
   g_nextCycleID = maxCycleID;

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
