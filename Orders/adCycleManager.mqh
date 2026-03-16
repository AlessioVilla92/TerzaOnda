//+------------------------------------------------------------------+
//|                                        adCycleManager.mqh        |
//|           AcquaDulza EA v1.3.0 — Cycle Manager                   |
//|                                                                  |
//|  Manages trade cycles: create, monitor, expire, detect fills     |
//|  Absorbed from carnTriggerSystem + Carneval.mq5 cycle logic      |
//+------------------------------------------------------------------+
#property copyright "AcquaDulza (C) 2026"

//+------------------------------------------------------------------+
//| IsPositionOpen — Check if position ticket still exists          |
//+------------------------------------------------------------------+
bool IsPositionOpen(ulong ticket)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetTicket(i) == ticket)
         return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| GetClosedPositionProfit — Get realized P&L from history         |
//+------------------------------------------------------------------+
double GetClosedPositionProfit(ulong posTicket)
{
   // Search in deal history
   datetime from = TimeCurrent() - 86400 * 7;  // Last 7 days
   if(!HistorySelect(from, TimeCurrent()))
   {
      AdLogW(LOG_CAT_CYCLE, StringFormat("GetClosedPositionProfit: HistorySelect failed for ticket=%d", posTicket));
   }

   double totalProfit = 0;
   for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
   {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(dealTicket == 0) continue;
      if(HistoryDealGetInteger(dealTicket, DEAL_MAGIC) != MagicNumber) continue;
      if(HistoryDealGetString(dealTicket, DEAL_SYMBOL) != _Symbol) continue;

      long entry = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
      if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_OUT_BY)
      {
         // Match by position ID
         ulong posId = (ulong)HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);
         if(posId == posTicket)
         {
            totalProfit += HistoryDealGetDouble(dealTicket, DEAL_PROFIT)
                         + HistoryDealGetDouble(dealTicket, DEAL_SWAP)
                         + HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
         }
      }
   }
   return totalProfit;
}

//+------------------------------------------------------------------+
//| GetFloatingProfit — Get unrealized P&L of open position         |
//+------------------------------------------------------------------+
double GetFloatingProfit(ulong ticket)
{
   if(!PositionSelectByTicket(ticket)) return 0;
   return PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
}

//+------------------------------------------------------------------+
//| CountActiveCycles — Count non-CLOSED cycles                     |
//+------------------------------------------------------------------+
int CountActiveCycles()
{
   int count = 0;
   for(int i = 0; i < ArraySize(g_cycles); i++)
   {
      if(g_cycles[i].state != CYCLE_IDLE && g_cycles[i].state != CYCLE_CLOSED)
         count++;
   }
   return count;
}

//+------------------------------------------------------------------+
//| FindFreeCycleSlot — Find first IDLE/CLOSED slot                 |
//+------------------------------------------------------------------+
int FindFreeCycleSlot()
{
   for(int i = 0; i < ArraySize(g_cycles); i++)
   {
      if(g_cycles[i].state == CYCLE_IDLE || g_cycles[i].state == CYCLE_CLOSED)
         return i;
   }
   return -1;
}

//+------------------------------------------------------------------+
//| CreateCycle — Create new trade cycle from EngineSignal          |
//|  Returns: slot index, or -1 if full                              |
//+------------------------------------------------------------------+
int CreateCycle(const EngineSignal &sig)
{
   string dirStr = sig.direction > 0 ? "BUY" : "SELL";

   // ── DIAG: Log ingresso in CreateCycle ──
   AdLogI(LOG_CAT_CYCLE, StringFormat("DIAG CreateCycle: %s | Entry=%s | TP=%s | Quality=%d",
          dirStr, FormatPrice(sig.entryPrice), FormatPrice(sig.tpPrice), sig.quality));

   // Check max concurrent
   int activeCycles = CountActiveCycles();
   if(activeCycles >= MaxConcurrentTrades)
   {
      AdLogW(LOG_CAT_CYCLE, StringFormat("DIAG BLOCCATO: Max concurrent trades raggiunto: %d/%d — ordine NON creato",
             activeCycles, MaxConcurrentTrades));
      return -1;
   }
   AdLogI(LOG_CAT_CYCLE, StringFormat("DIAG: Cicli attivi %d/%d — OK, procedo", activeCycles, MaxConcurrentTrades));

   int slot = FindFreeCycleSlot();
   if(slot < 0)
   {
      AdLogW(LOG_CAT_CYCLE, "DIAG BLOCCATO: Nessuno slot libero nel cycle array — ordine NON creato");
      return -1;
   }
   AdLogI(LOG_CAT_CYCLE, StringFormat("DIAG: Slot libero trovato: %d", slot));

   // Initialize cycle
   g_nextCycleID++;
   g_cycles[slot].cycleID         = g_nextCycleID;
   g_cycles[slot].direction       = sig.direction;
   g_cycles[slot].state           = CYCLE_PENDING;
   g_cycles[slot].ticket          = 0;
   g_cycles[slot].entryPrice      = sig.entryPrice;
   g_cycles[slot].slPrice         = sig.slPrice;
   g_cycles[slot].tpPrice         = sig.tpPrice;
   g_cycles[slot].lotSize         = 0;
   g_cycles[slot].signalTime      = sig.barTime;
   g_cycles[slot].placedTime      = iTime(_Symbol, PERIOD_CURRENT, 0);
   g_cycles[slot].quality         = sig.quality;
   g_cycles[slot].profit          = 0;

   // [MOD] SL rimosso — CalculateLotSize(0, quality) usa il LotSize fisso come fallback.
   // Il secondo parametro (sig.quality) applica il moltiplicatore TBS/TWS:
   //   TBS (corpo penetra banda) → TBSLotMultiplier (default 2.0x = doppio lotto)
   //   TWS (solo wick tocca)     → TWSLotMultiplier (default 1.0x = lotto standard)
   g_cycles[slot].lotSize = CalculateLotSize(0, sig.quality);
   AdLogI(LOG_CAT_CYCLE, StringFormat("DIAG: LotSize calcolato=%.4f (RiskMode=%s, Quality=%s, Mult=%.1fx)",
          g_cycles[slot].lotSize, EnumToString(RiskMode),
          sig.quality == PATTERN_TBS ? "TBS" : "TWS",
          sig.quality == PATTERN_TBS ? TBSLotMultiplier : TWSLotMultiplier));

   // ── DIAG: Log pre-OrderPlace ──
   AdLogI(LOG_CAT_CYCLE, StringFormat("DIAG: Invoco OrderPlace() — CycleID=#%d | %s | Lot=%.4f | Entry=%s | TP=%s",
          g_nextCycleID, dirStr, g_cycles[slot].lotSize, FormatPrice(sig.entryPrice), FormatPrice(sig.tpPrice)));

   // Place order
   ulong ticket = OrderPlace(sig, g_cycles[slot].lotSize, g_nextCycleID);

   if(ticket > 0)
   {
      g_cycles[slot].ticket = ticket;

      // For MARKET mode, position is immediately active
      if(EntryMode == ENTRY_MARKET)
         g_cycles[slot].state = CYCLE_ACTIVE;

      AdLogI(LOG_CAT_CYCLE, StringFormat("CYCLE #%d CREATED | %s %s | Ticket=%d | Lot=%.2f | Entry=%s | SL=%s | TP=%s",
             g_nextCycleID, dirStr,
             sig.quality == PATTERN_TBS ? "TBS" : "TWS",
             ticket, g_cycles[slot].lotSize,
             FormatPrice(sig.entryPrice), FormatPrice(sig.slPrice), FormatPrice(sig.tpPrice)));

      // Update signal counters
      g_totalSignals++;
      if(sig.direction > 0) g_buySignals++;
      else g_sellSignals++;
      g_lastSignalTime = TimeCurrent();
      g_dailyCyclesCount++;

      return slot;
   }
   else
   {
      g_cycles[slot].state = CYCLE_CLOSED;
      AdLogW(LOG_CAT_CYCLE, StringFormat("CYCLE #%d FAILED — OrderPlace() ha ritornato 0 — ordine NON piazzato", g_nextCycleID));
      AdLogW(LOG_CAT_CYCLE, "DIAG: Controlla i log [ORDER] sopra per il motivo specifico del fallimento");
      return -1;
   }
}

//+------------------------------------------------------------------+
//| DetectFill — Layer 1: OnTradeTransaction (reactive)             |
//|  Instant detection when STOP/LIMIT fills                         |
//+------------------------------------------------------------------+
void DetectFill(const MqlTradeTransaction& trans,
                const MqlTradeRequest& request,
                const MqlTradeResult& result)
{
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD) return;

   ulong dealTicket = trans.deal;
   if(dealTicket == 0) return;
   if(!HistoryDealSelect(dealTicket)) return;

   long dealMagic = HistoryDealGetInteger(dealTicket, DEAL_MAGIC);
   long dealEntry = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);

   if(dealMagic != MagicNumber || dealEntry != DEAL_ENTRY_IN) return;

   double dealPrice = HistoryDealGetDouble(dealTicket, DEAL_PRICE);
   string dealComment = HistoryDealGetString(dealTicket, DEAL_COMMENT);

   if(StringFind(dealComment, "AD_") < 0) return;

   for(int i = 0; i < ArraySize(g_cycles); i++)
   {
      if(g_cycles[i].state != CYCLE_PENDING) continue;

      if(StringFind(dealComment, StringFormat("#%d", g_cycles[i].cycleID)) >= 0)
      {
         double slippage = PointsToPips(MathAbs(dealPrice - g_cycles[i].entryPrice));

         g_cycles[i].entryPrice = dealPrice;
         g_cycles[i].state      = CYCLE_ACTIVE;

         AdLogI(LOG_CAT_CYCLE, StringFormat("=== FILLED #%d === %s @ %s | Slippage=%.1fp",
                g_cycles[i].cycleID,
                g_cycles[i].direction > 0 ? "BUY" : "SELL",
                FormatPrice(dealPrice), slippage));
         break;
      }
   }
}

//+------------------------------------------------------------------+
//| PollFills — Layer 2: Polling backup for missed fills            |
//+------------------------------------------------------------------+
void PollFills()
{
   for(int i = 0; i < ArraySize(g_cycles); i++)
   {
      if(g_cycles[i].state != CYCLE_PENDING) continue;

      // Check if pending order still exists
      bool pendingExists = false;
      for(int j = OrdersTotal() - 1; j >= 0; j--)
      {
         if(OrderGetTicket(j) == g_cycles[i].ticket)
         {
            pendingExists = true;
            break;
         }
      }

      if(!pendingExists)
      {
         // Search in positions
         bool foundAsPosition = false;
         for(int j = PositionsTotal() - 1; j >= 0; j--)
         {
            ulong posTicket = PositionGetTicket(j);
            if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
            if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

            string comment = PositionGetString(POSITION_COMMENT);
            if(StringFind(comment, StringFormat("#%d", g_cycles[i].cycleID)) >= 0)
            {
               g_cycles[i].ticket     = posTicket;
               g_cycles[i].entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
               g_cycles[i].state      = CYCLE_ACTIVE;
               foundAsPosition = true;

               AdLogI(LOG_CAT_CYCLE, StringFormat("POLL FILLED #%d | Ticket=%d @ %s",
                      g_cycles[i].cycleID, posTicket, FormatPrice(g_cycles[i].entryPrice)));
               break;
            }
         }

         if(!foundAsPosition)
         {
            g_cycles[i].state = CYCLE_CLOSED;
            AdLogW(LOG_CAT_CYCLE, StringFormat("POLL DISAPPEARED #%d — closing cycle", g_cycles[i].cycleID));
         }
      }
   }
}

//+------------------------------------------------------------------+
//| CheckExpiry — Cancel pending orders after N bars                |
//+------------------------------------------------------------------+
void CheckExpiry()
{
   if(PendingExpiryBars <= 0) return;

   for(int i = 0; i < ArraySize(g_cycles); i++)
   {
      if(g_cycles[i].state != CYCLE_PENDING) continue;
      if(g_cycles[i].placedTime == 0) continue;

      int barsElapsed = iBarShift(_Symbol, PERIOD_CURRENT, g_cycles[i].placedTime);
      if(barsElapsed >= PendingExpiryBars)
      {
         AdLogI(LOG_CAT_CYCLE, StringFormat("EXPIRING #%d after %d/%d bars",
                g_cycles[i].cycleID, barsElapsed, PendingExpiryBars));

         DeletePendingOrder(g_cycles[i].ticket);
         g_cycles[i].state = CYCLE_CLOSED;
         g_totalExpiredOrders++;
      }
   }
}

//+------------------------------------------------------------------+
//| UpdatePending — Modify pending if bands moved (STOP mode)       |
//+------------------------------------------------------------------+
void UpdatePending(const EngineSignal &sig)
{
   if(EntryMode != ENTRY_STOP) return;

   for(int i = 0; i < ArraySize(g_cycles); i++)
   {
      if(g_cycles[i].state != CYCLE_PENDING) continue;
      if(!OrderSelect(g_cycles[i].ticket)) continue;

      double newEntry = sig.entryPrice;
      double newTP    = sig.tpPrice;

      // Only modify if difference > 1 pip
      double entryDiff = MathAbs(newEntry - g_cycles[i].entryPrice);
      double tpDiff    = MathAbs(newTP - g_cycles[i].tpPrice);

      if(entryDiff > PipsToPrice(1.0) || tpDiff > PipsToPrice(1.0))
      {
         // [MOD] SL rimosso: terzo parametro (sl) impostato a 0.
         // Prima si passava g_cycles[i].slPrice, ora sempre 0 (nessun stop loss).
         if(ModifyPendingOrder(g_cycles[i].ticket, newEntry, 0, newTP))
         {
            AdLogI(LOG_CAT_CYCLE, StringFormat("UPD #%d | Entry: %s->%s | TP: %s->%s",
                   g_cycles[i].cycleID,
                   FormatPrice(g_cycles[i].entryPrice), FormatPrice(newEntry),
                   FormatPrice(g_cycles[i].tpPrice), FormatPrice(newTP)));
            g_cycles[i].entryPrice = newEntry;
            g_cycles[i].tpPrice    = newTP;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| MonitorActive — Monitor active positions, detect closes         |
//+------------------------------------------------------------------+
void MonitorActive()
{
   for(int i = 0; i < ArraySize(g_cycles); i++)
   {
      if(g_cycles[i].state != CYCLE_ACTIVE) continue;

      if(!IsPositionOpen(g_cycles[i].ticket))
      {
         // Position closed (TP/SL hit or manual close)
         double profit = GetClosedPositionProfit(g_cycles[i].ticket);
         g_cycles[i].profit = profit;
         g_cycles[i].state  = CYCLE_CLOSED;

         // Update counters
         g_sessionRealizedProfit += profit;
         g_dailyRealizedProfit   += profit;
         if(profit > 0) { g_sessionWins++; g_dailyWins++; }
         else           { g_sessionLosses++; g_dailyLosses++; }

         string result = profit > 0 ? "WIN" : "LOSS";
         AdLogI(LOG_CAT_CYCLE, StringFormat("=== CLOSED #%d — %s === %s | Profit=%.2f | Session: W=%d L=%d PL=%.2f",
                g_cycles[i].cycleID, result,
                g_cycles[i].direction > 0 ? "BUY" : "SELL", profit,
                g_sessionWins, g_sessionLosses, g_sessionRealizedProfit));

         // Feed item for dashboard
         if(profit > 0)
            AddFeedItem("TP hit " + FormatPrice(g_cycles[i].tpPrice) + " +$" + DoubleToString(profit, 2), AD_BUY);
         else
            AddFeedItem("SL hit -$" + DoubleToString(MathAbs(profit), 2), AD_SELL);

         Log_PositionClosed(g_cycles[i].ticket, result, profit,
                           g_cycles[i].entryPrice);
      }
   }
}

//+------------------------------------------------------------------+
//| MonitorCycles — Full cycle monitoring (call each tick/new bar)  |
//+------------------------------------------------------------------+
void MonitorCycles(const EngineSignal &sig)
{
   PollFills();
   CheckExpiry();
   UpdatePending(sig);
   MonitorActive();
}

//+------------------------------------------------------------------+
//| InitializeCycles — Reset all cycle slots                        |
//+------------------------------------------------------------------+
void InitializeCycles()
{
   ArrayResize(g_cycles, MAX_CYCLES);
   for(int i = 0; i < MAX_CYCLES; i++)
   {
      g_cycles[i].state     = CYCLE_IDLE;
      g_cycles[i].cycleID   = 0;
      g_cycles[i].ticket    = 0;
      g_cycles[i].direction = 0;
      g_cycles[i].entryPrice = 0;
      g_cycles[i].slPrice   = 0;
      g_cycles[i].tpPrice   = 0;
      g_cycles[i].lotSize   = 0;
      g_cycles[i].signalTime = 0;
      g_cycles[i].placedTime = 0;
      g_cycles[i].quality   = 0;
      g_cycles[i].profit    = 0;
   }

   Log_InitComplete("Cycle Manager");
}
