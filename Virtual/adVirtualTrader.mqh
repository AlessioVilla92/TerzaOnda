//+------------------------------------------------------------------+
//|                                       adVirtualTrader.mqh        |
//|           AcquaDulza EA v1.0.0 — Virtual (Paper) Trader          |
//|                                                                  |
//|  Simulates trade cycles without broker orders.                   |
//|  Uses same CycleRecord structure for consistency.                |
//|  Enabled via VirtualMode input parameter.                        |
//+------------------------------------------------------------------+
#property copyright "AcquaDulza (C) 2026"

//+------------------------------------------------------------------+
//| Virtual Trade State                                              |
//+------------------------------------------------------------------+
int      g_virtualTradeCount = 0;
double   g_virtualTotalProfit = 0;
int      g_virtualWins  = 0;
int      g_virtualLosses = 0;

//+------------------------------------------------------------------+
//| VirtualCreateTrade — Simulate order placement                   |
//|  No actual OrderSend — just record the cycle                     |
//+------------------------------------------------------------------+
int VirtualCreateTrade(const EngineSignal &sig)
{
   if(CountActiveCycles() >= MaxConcurrentTrades) return -1;

   int slot = FindFreeCycleSlot();
   if(slot < 0) return -1;

   g_nextCycleID++;
   double slDist = MathAbs(sig.entryPrice - sig.slPrice);

   g_cycles[slot].cycleID    = g_nextCycleID;
   g_cycles[slot].direction  = sig.direction;
   g_cycles[slot].state      = CYCLE_ACTIVE;  // Immediately "filled"
   g_cycles[slot].ticket     = 0;             // No real ticket
   g_cycles[slot].entryPrice = sig.entryPrice;
   g_cycles[slot].slPrice    = sig.slPrice;
   g_cycles[slot].tpPrice    = sig.tpPrice;
   g_cycles[slot].lotSize    = CalculateLotSize(slDist);
   g_cycles[slot].signalTime = sig.barTime;
   g_cycles[slot].placedTime = TimeCurrent();
   g_cycles[slot].quality    = sig.quality;
   g_cycles[slot].profit     = 0;

   g_virtualTradeCount++;
   g_totalSignals++;
   if(sig.direction > 0) g_buySignals++;
   else g_sellSignals++;

   AdLogI(LOG_CAT_VIRTUAL, StringFormat("VIRTUAL #%d %s | Entry=%s | SL=%s | TP=%s | Lot=%.2f",
          g_nextCycleID, sig.direction > 0 ? "BUY" : "SELL",
          FormatPrice(sig.entryPrice), FormatPrice(sig.slPrice),
          FormatPrice(sig.tpPrice), g_cycles[slot].lotSize));

   return slot;
}

//+------------------------------------------------------------------+
//| VirtualMonitor — Check active virtual trades against price      |
//|  Simulates TP/SL hits using current bid/ask                      |
//+------------------------------------------------------------------+
void VirtualMonitor()
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   for(int i = 0; i < ArraySize(g_cycles); i++)
   {
      if(g_cycles[i].state != CYCLE_ACTIVE) continue;
      if(g_cycles[i].ticket != 0) continue;  // Skip real trades

      bool tpHit = false;
      bool slHit = false;

      if(g_cycles[i].direction > 0)  // Virtual BUY
      {
         if(g_cycles[i].tpPrice > 0 && bid >= g_cycles[i].tpPrice)
            tpHit = true;
         if(g_cycles[i].slPrice > 0 && bid <= g_cycles[i].slPrice)
            slHit = true;
      }
      else  // Virtual SELL
      {
         if(g_cycles[i].tpPrice > 0 && ask <= g_cycles[i].tpPrice)
            tpHit = true;
         if(g_cycles[i].slPrice > 0 && ask >= g_cycles[i].slPrice)
            slHit = true;
      }

      if(tpHit || slHit)
      {
         // Calculate simulated profit
         double exitPrice = tpHit ?
            g_cycles[i].tpPrice :
            g_cycles[i].slPrice;

         double priceDiff = (g_cycles[i].direction > 0) ?
            (exitPrice - g_cycles[i].entryPrice) :
            (g_cycles[i].entryPrice - exitPrice);

         double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
         double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
         double profit = 0;
         if(tickSize > 0)
            profit = (priceDiff / tickSize) * tickValue * g_cycles[i].lotSize;

         g_cycles[i].profit = profit;
         g_cycles[i].state  = CYCLE_CLOSED;

         g_virtualTotalProfit += profit;
         if(profit > 0) g_virtualWins++;
         else           g_virtualLosses++;

         g_sessionRealizedProfit += profit;
         g_dailyRealizedProfit   += profit;

         string result = tpHit ? "TP HIT" : "SL HIT";
         AdLogI(LOG_CAT_VIRTUAL, StringFormat("VIRTUAL CLOSED #%d — %s | Profit=%.2f | Total=%.2f | W=%d L=%d",
                g_cycles[i].cycleID, result, profit, g_virtualTotalProfit,
                g_virtualWins, g_virtualLosses));
      }
   }
}

//+------------------------------------------------------------------+
//| VirtualGetSummary — Dashboard summary                           |
//+------------------------------------------------------------------+
string VirtualGetSummary()
{
   return StringFormat("V:%d W:%d L:%d PL:%.2f",
          g_virtualTradeCount, g_virtualWins, g_virtualLosses, g_virtualTotalProfit);
}
