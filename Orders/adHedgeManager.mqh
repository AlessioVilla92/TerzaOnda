//+------------------------------------------------------------------+
//|                                      adHedgeManager.mqh          |
//|           AcquaDulza EA v1.4.0 — Hedge Manager                   |
//|                                                                  |
//|  Gestisce ordine hedge (BUY/SELL STOP) opposto alla Soup.        |
//|                                                                  |
//|  LOGICA CORE:                                                    |
//|    SELL Soup → BUY STOP @ upperBand + HedgeATRMult × ATR(14)    |
//|    BUY  Soup → SELL STOP @ lowerBand - HedgeATRMult × ATR(14)   |
//|                                                                  |
//|  RISOLUZIONE (CLOSE_ON_FIRST_TP):                                |
//|    Se Soup TP colpito → cancella/chiudi hedge + ciclo CLOSED     |
//|    Se Hedge TP colpito → chiudi Soup + ciclo CLOSED              |
//|                                                                  |
//|  DISTANZA ATR:                                                   |
//|    g_atrPips = ATR(14) in pip, aggiornato ogni barra da          |
//|    UpdateATR() in adATRCalculator. Si adatta automaticamente     |
//|    al timeframe corrente. Nessuna parametrizzazione manuale.     |
//|                                                                  |
//|  API PUBBLICA:                                                   |
//|    HedgeInit()                                                   |
//|    HedgePlaceOrder(slot, sig)                                    |
//|    HedgeMonitor(slot)                                            |
//|    HedgeDeinit()                                                 |
//+------------------------------------------------------------------+
#property copyright "AcquaDulza (C) 2026"

// Prefix oggetti grafici hedge
#define HEDGE_LINE_PREFIX  "AD_HEDGE_LINE_"

//+------------------------------------------------------------------+
//| GetClosedHedgeProfit — P&L realizzato di una posizione hedge     |
//| Come GetClosedPositionProfit ma filtra MagicNumber + 1           |
//+------------------------------------------------------------------+
double GetClosedHedgeProfit(ulong posTicket)
{
   datetime from = TimeCurrent() - 86400 * 7;
   if(!HistorySelect(from, TimeCurrent())) return 0;

   double totalProfit = 0;
   for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
   {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(dealTicket == 0) continue;
      if(HistoryDealGetInteger(dealTicket, DEAL_MAGIC) != MagicNumber + 1) continue;
      if(HistoryDealGetString(dealTicket, DEAL_SYMBOL) != _Symbol) continue;

      long entry = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
      if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_OUT_BY)
      {
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
//| HedgeInit — Inizializzazione modulo hedge                        |
//+------------------------------------------------------------------+
void HedgeInit()
{
   AdLogI(LOG_CAT_HEDGE, StringFormat(
      "HedgeManager INIT | ATRMult=%.1f | TPMult=%.1f | SameLot=%s | LineWidth=%d bars",
      HedgeATRMult, HedgeTPAtrMult,
      HedgeUseSameLot ? "YES" : "NO", HedgeLineBarWidth));
}

//+------------------------------------------------------------------+
//| HedgeDeinit — Cleanup: rimuovi tutte le linee fucsia             |
//+------------------------------------------------------------------+
void HedgeDeinit()
{
   // Cancella tutti gli oggetti grafici hedge
   int removed = 0;
   for(int i = ObjectsTotal(0) - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i);
      if(StringFind(name, HEDGE_LINE_PREFIX) == 0)
      {
         ObjectDelete(0, name);
         removed++;
      }
   }
   AdLogI(LOG_CAT_HEDGE, StringFormat("HedgeManager DEINIT — %d linee rimosse", removed));
}

//+------------------------------------------------------------------+
//| HedgeDrawTriggerLine — Linea fucsia tratteggiata                 |
//| Mostra il livello del trigger hedge per HedgeLineBarWidth barre  |
//+------------------------------------------------------------------+
void HedgeDrawTriggerLine(int slot, double triggerLevel, datetime barTime)
{
   if(!ShowHedgeLine) return;

   string lineName = HEDGE_LINE_PREFIX + IntegerToString(g_cycles[slot].cycleID);
   g_cycles[slot].hedgeLineName = lineName;

   // Rimuovi eventuale linea precedente sullo stesso ciclo
   ObjectDelete(0, lineName);

   datetime t1 = barTime;
   datetime t2 = barTime + (datetime)(HedgeLineBarWidth * PeriodSeconds());

   if(ObjectCreate(0, lineName, OBJ_TREND, 0, t1, triggerLevel, t2, triggerLevel))
   {
      ObjectSetInteger(0, lineName, OBJPROP_COLOR,     clrFuchsia);
      ObjectSetInteger(0, lineName, OBJPROP_STYLE,     STYLE_DASH);
      ObjectSetInteger(0, lineName, OBJPROP_WIDTH,     1);
      ObjectSetInteger(0, lineName, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, lineName, OBJPROP_BACK,      true);
      ObjectSetString(0,  lineName, OBJPROP_TOOLTIP,
         StringFormat("HEDGE TRIGGER #%d @ %s | +%.1f pip (%.1f×ATR)",
            g_cycles[slot].cycleID,
            DoubleToString(triggerLevel, _Digits),
            PointsToPips(MathAbs(triggerLevel - g_cycles[slot].entryPrice)),
            HedgeATRMult));
   }
   else
   {
      AdLogW(LOG_CAT_HEDGE, StringFormat(
         "DrawTriggerLine FAILED #%d | Error=%d", g_cycles[slot].cycleID, GetLastError()));
   }
}

//+------------------------------------------------------------------+
//| HedgeRemoveLine — Rimuovi linea fucsia di un ciclo specifico     |
//+------------------------------------------------------------------+
void HedgeRemoveLine(int slot)
{
   if(g_cycles[slot].hedgeLineName != "")
   {
      ObjectDelete(0, g_cycles[slot].hedgeLineName);
      g_cycles[slot].hedgeLineName = "";
   }
}

//+------------------------------------------------------------------+
//| HedgePlaceOrder — Piazza BUY/SELL STOP hedge                     |
//| Chiamata subito dopo CreateCycle() su ogni nuovo segnale         |
//|                                                                  |
//| SELL Soup (direction=-1): BUY STOP @ upperBand + ATRMult×ATR    |
//| BUY  Soup (direction=+1): SELL STOP @ lowerBand - ATRMult×ATR   |
//+------------------------------------------------------------------+
void HedgePlaceOrder(int slot, const EngineSignal &sig)
{
   if(!EnableHedge) return;
   if(slot < 0 || slot >= ArraySize(g_cycles)) return;
   if(g_cycles[slot].state != CYCLE_ACTIVE && g_cycles[slot].state != CYCLE_PENDING) return;

   // Controllo ATR disponibile
   if(g_atrPips <= 0)
   {
      AdLogW(LOG_CAT_HEDGE, StringFormat("ATR non disponibile (%.4f) — hedge SKIPPED #%d",
             g_atrPips, g_cycles[slot].cycleID));
      return;
   }

   // Calcola lotto hedge
   double hedgeLot;
   if(HedgeUseSameLot)
      hedgeLot = g_cycles[slot].lotSize;
   else
      hedgeLot = NormalizeLotSize(HedgeLotFixed);

   if(hedgeLot <= 0) hedgeLot = g_symbolMinLot;

   // Calcola trigger e TP
   double atrPrice   = PipsToPrice(g_atrPips);
   double hedgeDist  = HedgeATRMult  * atrPrice;
   double hedgeTpDist= HedgeTPAtrMult * atrPrice;

   double triggerLevel = 0;
   double tpLevel      = 0;

   if(g_cycles[slot].direction < 0)
   {
      // Soup SELL → hedge BUY STOP sopra la upper band
      triggerLevel = sig.upperBand + hedgeDist;
      tpLevel      = triggerLevel  + hedgeTpDist;
   }
   else
   {
      // Soup BUY → hedge SELL STOP sotto la lower band
      triggerLevel = sig.lowerBand - hedgeDist;
      tpLevel      = triggerLevel  - hedgeTpDist;
   }

   triggerLevel = NormalizeDouble(triggerLevel, _Digits);
   tpLevel      = NormalizeDouble(tpLevel,      _Digits);

   // Verifica distanza minima broker (stop level)
   double minDist = g_symbolStopsLevel * g_symbolPoint;
   double currentPrice = (g_cycles[slot].direction < 0)
                         ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);

   if(g_cycles[slot].direction < 0)
   {
      // BUY STOP: deve essere sopra Ask
      if(triggerLevel <= currentPrice + minDist)
      {
         triggerLevel = currentPrice + minDist + g_symbolPoint;
         triggerLevel = NormalizeDouble(triggerLevel, _Digits);
         tpLevel      = NormalizeDouble(triggerLevel + hedgeTpDist, _Digits);
         AdLogW(LOG_CAT_HEDGE, StringFormat(
            "BUY STOP troppo vicino — trigger aggiustato a %s", DoubleToString(triggerLevel, _Digits)));
      }
   }
   else
   {
      // SELL STOP: deve essere sotto Bid
      if(triggerLevel >= currentPrice - minDist)
      {
         triggerLevel = currentPrice - minDist - g_symbolPoint;
         triggerLevel = NormalizeDouble(triggerLevel, _Digits);
         tpLevel      = NormalizeDouble(triggerLevel - hedgeTpDist, _Digits);
         AdLogW(LOG_CAT_HEDGE, StringFormat(
            "SELL STOP troppo vicino — trigger aggiustato a %s", DoubleToString(triggerLevel, _Digits)));
      }
   }

   // Piazza ordine pendente
   string comment = StringFormat("AD_HEDGE_%s_#%d",
      g_cycles[slot].direction < 0 ? "BUY" : "SELL",
      g_cycles[slot].cycleID);

   g_trade.SetExpertMagicNumber(MagicNumber + 1);  // Magic separato per hedge

   bool placed = false;
   if(g_cycles[slot].direction < 0)
      placed = g_trade.BuyStop(hedgeLot, triggerLevel, _Symbol, 0, tpLevel, ORDER_TIME_GTC, 0, comment);
   else
      placed = g_trade.SellStop(hedgeLot, triggerLevel, _Symbol, 0, tpLevel, ORDER_TIME_GTC, 0, comment);

   if(placed)
   {
      g_cycles[slot].hedgeTicket      = g_trade.ResultOrder();
      g_cycles[slot].hedgeTriggerPrice= triggerLevel;
      g_cycles[slot].hedgeTPPrice     = tpLevel;
      g_cycles[slot].hedgeLotSize     = hedgeLot;
      g_cycles[slot].hedgePending     = true;
      g_cycles[slot].hedgeActive      = false;

      AdLogI(LOG_CAT_HEDGE, StringFormat(
         "HEDGE PLACED #%d | %s STOP @ %s | TP=%s | Lot=%.2f | ATR=%.1fpip | Dist=%.1fpip",
         g_cycles[slot].cycleID,
         g_cycles[slot].direction < 0 ? "BUY" : "SELL",
         DoubleToString(triggerLevel, _Digits),
         DoubleToString(tpLevel, _Digits),
         hedgeLot,
         g_atrPips,
         PointsToPips(hedgeDist)));

      // Disegna linea fucsia
      if(ShowHedgeLine)
         HedgeDrawTriggerLine(slot, triggerLevel, sig.barTime);
   }
   else
   {
      AdLogE(LOG_CAT_HEDGE, StringFormat(
         "HEDGE PLACE FAILED #%d | Error: %s",
         g_cycles[slot].cycleID, g_trade.ResultRetcodeDescription()));
   }
}

//+------------------------------------------------------------------+
//| HedgeCancelPending — Cancella ordine hedge pendente              |
//| Chiamata quando la Soup chiude prima che il trigger venga colpito |
//+------------------------------------------------------------------+
void HedgeCancelPending(int slot)
{
   if(!g_cycles[slot].hedgePending) return;
   if(g_cycles[slot].hedgeTicket == 0) return;

   g_trade.SetExpertMagicNumber(MagicNumber + 1);

   if(g_trade.OrderDelete(g_cycles[slot].hedgeTicket))
   {
      AdLogI(LOG_CAT_HEDGE, StringFormat(
         "HEDGE CANCELLED (Soup chiusa) #%d | Ticket=%d",
         g_cycles[slot].cycleID, g_cycles[slot].hedgeTicket));
   }
   else
   {
      AdLogE(LOG_CAT_HEDGE, StringFormat(
         "HEDGE CANCEL FAILED #%d | Error: %s",
         g_cycles[slot].cycleID, g_trade.ResultRetcodeDescription()));
   }

   g_cycles[slot].hedgePending = false;
   g_cycles[slot].hedgeTicket  = 0;
   HedgeRemoveLine(slot);
}

//+------------------------------------------------------------------+
//| HedgeClosePosition — Chiudi posizione hedge aperta (se attiva)  |
//+------------------------------------------------------------------+
void HedgeClosePosition(int slot)
{
   if(!g_cycles[slot].hedgeActive) return;
   if(g_cycles[slot].hedgeTicket == 0) return;

   g_trade.SetExpertMagicNumber(MagicNumber + 1);

   if(PositionSelectByTicket(g_cycles[slot].hedgeTicket))
   {
      if(g_trade.PositionClose(g_cycles[slot].hedgeTicket))
      {
         AdLogI(LOG_CAT_HEDGE, StringFormat(
            "HEDGE CLOSED (Soup TP hit) #%d | Ticket=%d",
            g_cycles[slot].cycleID, g_cycles[slot].hedgeTicket));
      }
      else
      {
         AdLogE(LOG_CAT_HEDGE, StringFormat(
            "HEDGE CLOSE FAILED #%d | Error: %s",
            g_cycles[slot].cycleID, g_trade.ResultRetcodeDescription()));
      }
   }
   g_cycles[slot].hedgeActive  = false;
   g_cycles[slot].hedgeTicket  = 0;
}

//+------------------------------------------------------------------+
//| HedgeDetectFill — Rileva se ordine hedge è stato riempito        |
//| Controlla se il ticket hedge non è più negli ordini pendenti     |
//| ma è diventato una posizione attiva.                             |
//| Chiamata da HedgeMonitor() ad ogni tick per cicli ACTIVE.        |
//+------------------------------------------------------------------+
bool HedgeDetectFill(int slot)
{
   if(!g_cycles[slot].hedgePending) return false;
   if(g_cycles[slot].hedgeTicket == 0) return false;

   // L'ordine esiste ancora tra i pendenti?
   bool stillPending = false;
   for(int j = OrdersTotal() - 1; j >= 0; j--)
   {
      if(OrderGetTicket(j) == g_cycles[slot].hedgeTicket)
      {
         stillPending = true;
         break;
      }
   }

   if(!stillPending)
   {
      // Non è più pendente — è diventato posizione?
      for(int j = PositionsTotal() - 1; j >= 0; j--)
      {
         ulong posTkt = PositionGetTicket(j);
         if(PositionGetInteger(POSITION_MAGIC) == MagicNumber + 1 &&
            PositionGetString(POSITION_SYMBOL) == _Symbol)
         {
            string posComment = PositionGetString(POSITION_COMMENT);
            if(StringFind(posComment, StringFormat("#%d", g_cycles[slot].cycleID)) >= 0)
            {
               g_cycles[slot].hedgeTicket  = posTkt;
               g_cycles[slot].hedgePending = false;
               g_cycles[slot].hedgeActive  = true;
               g_cycles[slot].state        = CYCLE_HEDGING;
               HedgeRemoveLine(slot);

               AdLogI(LOG_CAT_HEDGE, StringFormat(
                  "=== HEDGE ACTIVATED #%d === Fill @ %s | Soup %s + Hedge %s OPEN",
                  g_cycles[slot].cycleID,
                  DoubleToString(PositionGetDouble(POSITION_PRICE_OPEN), _Digits),
                  g_cycles[slot].direction > 0 ? "BUY" : "SELL",
                  g_cycles[slot].direction > 0 ? "SELL" : "BUY"));
               return true;
            }
         }
      }

      // Non trovato tra le posizioni → ordine cancellato/scaduto esternamente
      AdLogW(LOG_CAT_HEDGE, StringFormat(
         "Hedge order #%d SCOMPARSO (cancellato/scaduto?) — reset pending",
         g_cycles[slot].cycleID));
      g_cycles[slot].hedgePending = false;
      g_cycles[slot].hedgeTicket  = 0;
      HedgeRemoveLine(slot);
   }
   return false;
}

//+------------------------------------------------------------------+
//| HedgeMonitor — Monitor principale, chiamata ad ogni tick        |
//| Gestisce: fill detection, risoluzione TP, cleanup                |
//|                                                                  |
//| CLOSE_ON_FIRST_TP:                                               |
//|   Soup TP colpito   → cancella/chiudi hedge → CYCLE_CLOSED       |
//|   Hedge TP colpito  → chiudi Soup          → CYCLE_CLOSED        |
//|                                                                  |
//| CLEANUP:                                                         |
//|   Ciclo CLOSED con hedge ancora attivo/pendente → pulisci        |
//|   (MonitorActive() chiude Soup → CLOSED prima di HedgeMonitor)   |
//+------------------------------------------------------------------+
void HedgeMonitor(int slot)
{
   if(!EnableHedge) return;
   if(slot < 0 || slot >= ArraySize(g_cycles)) return;

   ENUM_CYCLE_STATE st = g_cycles[slot].state;

   // ── Cleanup: Soup chiusa da MonitorActive ma hedge ancora vivo ──
   if(st == CYCLE_CLOSED)
   {
      if(g_cycles[slot].hedgePending)
         HedgeCancelPending(slot);
      if(g_cycles[slot].hedgeActive)
      {
         ulong hedgeTkt = g_cycles[slot].hedgeTicket;
         HedgeClosePosition(slot);
         // Aggiungi P&L hedge al profitto combinato del ciclo
         double hedgePL = GetClosedHedgeProfit(hedgeTkt);
         g_cycles[slot].profit += hedgePL;
         g_sessionRealizedProfit += hedgePL;
         g_dailyRealizedProfit   += hedgePL;
         AdLogI(LOG_CAT_HEDGE, StringFormat(
            "HEDGE P&L added #%d | Hedge=%.2f | Combined=%.2f",
            g_cycles[slot].cycleID, hedgePL, g_cycles[slot].profit));
      }
      return;
   }

   // ── Ciclo ACTIVE con hedge pendente: controlla fill ──
   if(st == CYCLE_ACTIVE && g_cycles[slot].hedgePending)
   {
      HedgeDetectFill(slot);
      // Se riempito → stato è già CYCLE_HEDGING, gestito al prossimo tick
      return;
   }

   // ── Ciclo HEDGING: entrambe le gambe aperte ──
   if(st == CYCLE_HEDGING)
   {
      bool soupOpen  = (g_cycles[slot].ticket > 0)
                       && PositionSelectByTicket(g_cycles[slot].ticket);
      bool hedgeOpen = (g_cycles[slot].hedgeTicket > 0)
                       && PositionSelectByTicket(g_cycles[slot].hedgeTicket);

      // Caso 1: Soup ha chiuso (TP broker) → chiudi anche hedge
      if(!soupOpen && g_cycles[slot].ticket > 0)
      {
         AdLogI(LOG_CAT_HEDGE, StringFormat(
            "SOUP CLOSED (TP broker) #%d → chiudo hedge", g_cycles[slot].cycleID));

         double soupPL = GetClosedPositionProfit(g_cycles[slot].ticket);
         ulong hedgeTkt = g_cycles[slot].hedgeTicket;
         HedgeClosePosition(slot);
         double hedgePL = GetClosedHedgeProfit(hedgeTkt);

         g_cycles[slot].profit = soupPL + hedgePL;
         g_sessionRealizedProfit += g_cycles[slot].profit;
         g_dailyRealizedProfit   += g_cycles[slot].profit;
         if(g_cycles[slot].profit > 0) { g_sessionWins++; g_dailyWins++; }
         else { g_sessionLosses++; g_dailyLosses++; }

         AdLogI(LOG_CAT_HEDGE, StringFormat(
            "=== HEDGED CLOSED #%d === SoupPL=%.2f | HedgePL=%.2f | Net=%.2f",
            g_cycles[slot].cycleID, soupPL, hedgePL, g_cycles[slot].profit));

         g_cycles[slot].state = CYCLE_CLOSED;
         return;
      }

      // Caso 2: Hedge ha chiuso (TP broker) → chiudi anche Soup
      if(!hedgeOpen && g_cycles[slot].hedgeActive)
      {
         AdLogI(LOG_CAT_HEDGE, StringFormat(
            "HEDGE CLOSED (TP broker) #%d → chiudo Soup", g_cycles[slot].cycleID));

         double hedgePL = GetClosedHedgeProfit(g_cycles[slot].hedgeTicket);
         g_cycles[slot].hedgeActive = false;
         g_cycles[slot].hedgeTicket = 0;

         double soupPL = 0;
         if(soupOpen)
         {
            g_trade.SetExpertMagicNumber(MagicNumber);
            if(g_trade.PositionClose(g_cycles[slot].ticket))
            {
               AdLogI(LOG_CAT_HEDGE, StringFormat(
                  "Soup CLOSED (hedge TP hit) #%d | Ticket=%d",
                  g_cycles[slot].cycleID, g_cycles[slot].ticket));
               soupPL = GetClosedPositionProfit(g_cycles[slot].ticket);
            }
            else
            {
               AdLogE(LOG_CAT_HEDGE, StringFormat(
                  "Soup CLOSE FAILED #%d | Error: %s",
                  g_cycles[slot].cycleID, g_trade.ResultRetcodeDescription()));
            }
         }

         g_cycles[slot].profit = soupPL + hedgePL;
         g_sessionRealizedProfit += g_cycles[slot].profit;
         g_dailyRealizedProfit   += g_cycles[slot].profit;
         if(g_cycles[slot].profit > 0) { g_sessionWins++; g_dailyWins++; }
         else { g_sessionLosses++; g_dailyLosses++; }

         AdLogI(LOG_CAT_HEDGE, StringFormat(
            "=== HEDGED CLOSED #%d === SoupPL=%.2f | HedgePL=%.2f | Net=%.2f",
            g_cycles[slot].cycleID, soupPL, hedgePL, g_cycles[slot].profit));

         g_cycles[slot].state = CYCLE_CLOSED;
         return;
      }

      // Caso 3: Entrambe chiuse (raro ma possibile)
      if(!soupOpen && !hedgeOpen)
      {
         double soupPL  = GetClosedPositionProfit(g_cycles[slot].ticket);
         double hedgePL = GetClosedHedgeProfit(g_cycles[slot].hedgeTicket);
         g_cycles[slot].hedgeActive = false;
         g_cycles[slot].profit = soupPL + hedgePL;
         g_sessionRealizedProfit += g_cycles[slot].profit;
         g_dailyRealizedProfit   += g_cycles[slot].profit;
         if(g_cycles[slot].profit > 0) { g_sessionWins++; g_dailyWins++; }
         else { g_sessionLosses++; g_dailyLosses++; }

         g_cycles[slot].state = CYCLE_CLOSED;
         AdLogI(LOG_CAT_HEDGE, StringFormat(
            "BOTH CLOSED simultaneously #%d | Net=%.2f", g_cycles[slot].cycleID, g_cycles[slot].profit));
      }
   }
}
