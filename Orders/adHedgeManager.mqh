//+------------------------------------------------------------------+
//|                                      adHedgeManager.mqh          |
//|           AcquaDulza EA v1.7.0 — Hedge Smart Manager             |
//|                                                                   |
//|  Hedge Smart: hedge non invasivo a lotto fisso.                   |
//|  La Soup NON viene mai chiusa o modificata da questo modulo.     |
//|                                                                   |
//|  LOGICA:                                                          |
//|   BUY Soup  → SELL STOP @ lower_band − (cw × HsTriggerPct)      |
//|   SELL Soup → BUY STOP  @ upper_band + (cw × HsTriggerPct)      |
//|                                                                   |
//|  EXIT (priorità decrescente):                                     |
//|   1. Prossimo segnale DPC stesso senso Soup (≥ HsAntiWhipsawBars)|
//|   2. Soup floating ≥ 0 (se HsCloseOnSoupProfit=true)            |
//|   3. Timeout N barre (se HsTimeoutBars > 0)                       |
//|   4. Soup chiusa dal broker → cleanup HS automatico              |
//|                                                                   |
//|  MAGIC: HS = MagicNumber + 1                                      |
//|  COMMENT FORMAT: "AD_HS_SELL_#12" / "AD_HS_BUY_#12"             |
//|                                                                   |
//|  API PUBBLICA:                                                     |
//|    HedgeInit()                                                    |
//|    HedgeDeinit()                                                   |
//|    HsPlaceOrder(slot, sig)                                        |
//|    HsMonitor(slot, sig, hasNewSignal)                             |
//+------------------------------------------------------------------+
#property copyright "AcquaDulza (C) 2026"

#define HS_LINE_PREFIX    "AD_HS_LINE_"
#define HS_ZONE_TRIGGER   "AD_HS_ZONE_TRG"
#define HS_ZONE_TP        "AD_HS_ZONE_TP"

//+------------------------------------------------------------------+
//| HedgeInit                                                         |
//+------------------------------------------------------------------+
void HedgeInit()
{
   AdLogI(LOG_CAT_HEDGE, StringFormat(
      "HedgeSmart INIT | Enabled=%s | Lot=%.2f | TriggerPct=%.2f | "
      "AntiWhipsaw=%d | CloseOnProfit=%s | Timeout=%d | "
      "BodyFilter=%s(%.2f) | Zones=%s",
      HsEnabled ? "YES" : "NO", HsLot, HsTriggerPct,
      HsAntiWhipsawBars, HsCloseOnSoupProfit ? "YES" : "NO",
      HsTimeoutBars, HsBodyFilter ? "YES" : "NO", HsBodyRatioMin,
      HsShowZones ? "YES" : "NO"));
}

//+------------------------------------------------------------------+
//| HedgeDeinit — Rimuove tutti gli oggetti grafici HS               |
//+------------------------------------------------------------------+
void HedgeDeinit()
{
   int removed = 0;
   for(int i = ObjectsTotal(0) - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i);
      if(StringFind(name, HS_LINE_PREFIX)  >= 0 ||
         StringFind(name, HS_ZONE_TRIGGER) >= 0 ||
         StringFind(name, HS_ZONE_TP)      >= 0)
      {
         ObjectDelete(0, name);
         removed++;
      }
   }
   AdLogI(LOG_CAT_HEDGE, StringFormat("HedgeSmart DEINIT — %d oggetti rimossi", removed));
}

//+------------------------------------------------------------------+
//| GetClosedHsProfit — P&L realizzato HS da deal history            |
//+------------------------------------------------------------------+
double GetClosedHsProfit(ulong posTicket)
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
         if((ulong)HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID) == posTicket)
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
//| HsBodyFilterOK — Verifica body/wick ratio sulla candela [1]      |
//|                                                                   |
//| Legge la candela che ha generato il segnale DPC (barra [1]).     |
//| body_ratio = |close-open| / (high-low)                           |
//| Ritorna true se filtro disabilitato o body_ratio >= HsBodyRatioMin|
//+------------------------------------------------------------------+
bool HsBodyFilterOK()
{
   if(!HsBodyFilter) return true;

   double o = iOpen (_Symbol, PERIOD_CURRENT, 1);
   double h = iHigh (_Symbol, PERIOD_CURRENT, 1);
   double l = iLow  (_Symbol, PERIOD_CURRENT, 1);
   double c = iClose(_Symbol, PERIOD_CURRENT, 1);

   double range = h - l;
   if(range < g_symbolPoint) return true;   // candela degenere → skip filtro

   double bodyRatio = MathAbs(c - o) / range;

   AdLogD(LOG_CAT_HEDGE, StringFormat(
      "HS BodyFilter: ratio=%.2f threshold=%.2f → %s",
      bodyRatio, HsBodyRatioMin,
      bodyRatio >= HsBodyRatioMin ? "PASS" : "FAIL"));

   return (bodyRatio >= HsBodyRatioMin);
}

//+------------------------------------------------------------------+
//| HsDrawTriggerLine — Linea tratteggiata arancione al trigger      |
//+------------------------------------------------------------------+
void HsDrawTriggerLine(int slot, double triggerLevel, datetime barTime)
{
   if(!HsShowTriggerLine) return;

   string name = HS_LINE_PREFIX + IntegerToString(g_cycles[slot].cycleID);
   g_cycles[slot].hsLineName = name;
   ObjectDelete(0, name);

   datetime t1 = barTime;
   datetime t2 = barTime + (datetime)(HsTriggerLineWidth * PeriodSeconds());

   if(ObjectCreate(0, name, OBJ_TREND, 0, t1, triggerLevel, t2, triggerLevel))
   {
      ObjectSetInteger(0, name, OBJPROP_COLOR,     AD_HS_TRIGGER_CLR);
      ObjectSetInteger(0, name, OBJPROP_STYLE,     STYLE_DASH);
      ObjectSetInteger(0, name, OBJPROP_WIDTH,     1);
      ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, name, OBJPROP_BACK,      true);
      ObjectSetString(0,  name, OBJPROP_TOOLTIP,
         StringFormat("HS TRIGGER #%d @ %s | %.0f%% cw",
            g_cycles[slot].cycleID,
            DoubleToString(triggerLevel, _Digits),
            HsTriggerPct * 100));
   }
}

//+------------------------------------------------------------------+
//| HsRemoveLine — Rimuove linea trigger HS                          |
//+------------------------------------------------------------------+
void HsRemoveLine(int slot)
{
   if(g_cycles[slot].hsLineName == "") return;
   ObjectDelete(0, g_cycles[slot].hsLineName);
   g_cycles[slot].hsLineName = "";
}

//+------------------------------------------------------------------+
//| HsPlaceOrder — Valuta e piazza l'ordine HS                       |
//|                                                                   |
//| Chiamato da AcquaDulza.mq5 dopo CreateCycle().                   |
//| Non invia TP al broker: la chiusura è sempre programmata.        |
//|                                                                   |
//| FORMULA TRIGGER:                                                  |
//|   cw = upperBand - lowerBand                                     |
//|   BUY Soup  → SELL STOP @ lowerBand - (cw × HsTriggerPct)       |
//|   SELL Soup → BUY STOP  @ upperBand + (cw × HsTriggerPct)       |
//+------------------------------------------------------------------+
void HsPlaceOrder(int slot, const EngineSignal &sig)
{
   if(!EnableHedge || !HsEnabled) return;
   if(slot < 0 || slot >= ArraySize(g_cycles)) return;
   if(g_cycles[slot].state == CYCLE_CLOSED) return;
   if(g_cycles[slot].hsPending || g_cycles[slot].hsActive)
   {
      AdLogD(LOG_CAT_HEDGE, StringFormat("HS già attivo #%d — skip", g_cycles[slot].cycleID));
      return;
   }

   // Body/wick filter
   if(!HsBodyFilterOK())
   {
      AdLogI(LOG_CAT_HEDGE, StringFormat(
         "HS SKIP #%d — body filter: candela wick-dominante (falso breakout probabile)",
         g_cycles[slot].cycleID));
      return;
   }

   // Channel width
   double cw = sig.upperBand - sig.lowerBand;
   if(cw < g_symbolPoint * 10)
   {
      AdLogW(LOG_CAT_HEDGE, StringFormat("HS SKIP #%d — channel width troppo piccolo %.5f",
             g_cycles[slot].cycleID, cw));
      return;
   }

   // Calcola livelli
   double triggerDist = cw * HsTriggerPct;
   double tpRefDist   = cw * 0.60;
   double triggerLevel, tpRefLevel;

   if(g_cycles[slot].direction > 0)   // BUY Soup → SELL STOP
   {
      triggerLevel = sig.lowerBand - triggerDist;
      tpRefLevel   = triggerLevel  - tpRefDist;
   }
   else                                // SELL Soup → BUY STOP
   {
      triggerLevel = sig.upperBand + triggerDist;
      tpRefLevel   = triggerLevel  + tpRefDist;
   }
   triggerLevel = NormalizeDouble(triggerLevel, _Digits);
   tpRefLevel   = NormalizeDouble(tpRefLevel,   _Digits);

   // Verifica distanza minima broker
   double minDist = (g_symbolStopsLevel + 2) * g_symbolPoint;
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   if(g_cycles[slot].direction > 0)   // SELL STOP: deve essere sotto bid
   {
      if(triggerLevel >= bid - minDist)
      {
         triggerLevel = NormalizeDouble(bid - minDist - g_symbolPoint, _Digits);
         tpRefLevel   = NormalizeDouble(triggerLevel - tpRefDist, _Digits);
         AdLogW(LOG_CAT_HEDGE, StringFormat("HS SELL STOP aggiustato → %s", DoubleToString(triggerLevel, _Digits)));
      }
   }
   else                                // BUY STOP: deve essere sopra ask
   {
      if(triggerLevel <= ask + minDist)
      {
         triggerLevel = NormalizeDouble(ask + minDist + g_symbolPoint, _Digits);
         tpRefLevel   = NormalizeDouble(triggerLevel + tpRefDist, _Digits);
         AdLogW(LOG_CAT_HEDGE, StringFormat("HS BUY STOP aggiustato → %s", DoubleToString(triggerLevel, _Digits)));
      }
   }

   // Lotto
   double hsLot = NormalizeLotSize(HsLot);
   if(hsLot <= 0) hsLot = g_symbolMinLot;

   // Comment per recovery
   string comment = StringFormat("AD_HS_%s_#%d",
      g_cycles[slot].direction > 0 ? "SELL" : "BUY",
      g_cycles[slot].cycleID);

   // Piazza STOP senza TP (gestito programmaticamente)
   g_trade.SetExpertMagicNumber(MagicNumber + 1);
   bool placed = false;
   if(g_cycles[slot].direction > 0)
      placed = g_trade.SellStop(hsLot, triggerLevel, _Symbol, 0, 0, ORDER_TIME_GTC, 0, comment);
   else
      placed = g_trade.BuyStop(hsLot, triggerLevel, _Symbol, 0, 0, ORDER_TIME_GTC, 0, comment);

   if(placed)
   {
      g_cycles[slot].hsTicket       = g_trade.ResultOrder();
      g_cycles[slot].hsTriggerPrice = triggerLevel;
      g_cycles[slot].hsTpRefLevel   = tpRefLevel;
      g_cycles[slot].hsLotSize      = hsLot;
      g_cycles[slot].hsPending      = true;
      g_cycles[slot].hsActive       = false;
      g_cycles[slot].hsFillTime     = 0;
      g_cycles[slot].hsPL           = 0;

      double cwPip = cw / PipsToPrice(1);
      AdLogI(LOG_CAT_HEDGE, StringFormat(
         "HS PLACED #%d | %s STOP @ %s | Lot=%.2f | TrigPct=%.0f%% | cw=%.1fpip",
         g_cycles[slot].cycleID,
         g_cycles[slot].direction > 0 ? "SELL" : "BUY",
         DoubleToString(triggerLevel, _Digits),
         hsLot, HsTriggerPct * 100, cwPip));

      Alert(StringFormat("AcquaDulza HS PIAZZATO #%d %s STOP @ %s | Lot=%.2f | %s",
            g_cycles[slot].cycleID,
            g_cycles[slot].direction > 0 ? "SELL" : "BUY",
            DoubleToString(triggerLevel, _Digits), hsLot, _Symbol));

      if(HsShowTriggerLine)
         HsDrawTriggerLine(slot, triggerLevel, sig.barTime);
   }
   else
   {
      AdLogE(LOG_CAT_HEDGE, StringFormat("HS PLACE FAILED #%d | Error: %s",
             g_cycles[slot].cycleID, g_trade.ResultRetcodeDescription()));
   }
}

//+------------------------------------------------------------------+
//| HsDetectFill — Rileva se l'ordine HS è stato riempito            |
//+------------------------------------------------------------------+
bool HsDetectFill(int slot)
{
   if(!g_cycles[slot].hsPending) return false;
   if(g_cycles[slot].hsTicket == 0) return false;

   bool stillPending = false;
   for(int j = OrdersTotal() - 1; j >= 0; j--)
   {
      if(OrderGetTicket(j) == g_cycles[slot].hsTicket)
      { stillPending = true; break; }
   }

   if(!stillPending)
   {
      for(int j = PositionsTotal() - 1; j >= 0; j--)
      {
         ulong posTkt = PositionGetTicket(j);
         if(PositionGetInteger(POSITION_MAGIC) != MagicNumber + 1) continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

         string posComment = PositionGetString(POSITION_COMMENT);
         if(StringFind(posComment, StringFormat("#%d", g_cycles[slot].cycleID)) >= 0)
         {
            g_cycles[slot].hsTicket  = posTkt;
            g_cycles[slot].hsPending = false;
            g_cycles[slot].hsActive  = true;
            g_cycles[slot].hsFillTime = TimeCurrent();
            if(g_cycles[slot].state == CYCLE_ACTIVE)
               g_cycles[slot].state = CYCLE_HEDGING;
            HsRemoveLine(slot);

            double fillPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            AdLogI(LOG_CAT_HEDGE, StringFormat(
               "=== HS ACTIVATED #%d === Fill @ %s | Lot=%.2f",
               g_cycles[slot].cycleID,
               DoubleToString(fillPrice, _Digits),
               PositionGetDouble(POSITION_VOLUME)));
            Alert(StringFormat("AcquaDulza HS ATTIVATO #%d @ %s | Lot=%.2f | %s",
                  g_cycles[slot].cycleID,
                  DoubleToString(fillPrice, _Digits),
                  PositionGetDouble(POSITION_VOLUME), _Symbol));
            return true;
         }
      }

      AdLogW(LOG_CAT_HEDGE, StringFormat("HS order #%d SCOMPARSO — reset pending", g_cycles[slot].cycleID));
      g_cycles[slot].hsPending = false;
      g_cycles[slot].hsTicket  = 0;
      HsRemoveLine(slot);
   }
   return false;
}

//+------------------------------------------------------------------+
//| HsCancel — Cancella ordine HS pendente                           |
//+------------------------------------------------------------------+
void HsCancel(int slot, string reason)
{
   if(!g_cycles[slot].hsPending) return;
   if(g_cycles[slot].hsTicket == 0) return;

   g_trade.SetExpertMagicNumber(MagicNumber + 1);
   if(g_trade.OrderDelete(g_cycles[slot].hsTicket))
   {
      AdLogI(LOG_CAT_HEDGE, StringFormat("HS CANCELLED #%d | Reason: %s | Ticket=%d",
             g_cycles[slot].cycleID, reason, g_cycles[slot].hsTicket));
   }
   else
   {
      AdLogE(LOG_CAT_HEDGE, StringFormat("HS CANCEL FAILED #%d | Error: %s",
             g_cycles[slot].cycleID, g_trade.ResultRetcodeDescription()));
   }
   g_cycles[slot].hsPending = false;
   g_cycles[slot].hsTicket  = 0;
   HsRemoveLine(slot);
}

//+------------------------------------------------------------------+
//| HsClose — Chiude posizione HS attiva a mercato                   |
//+------------------------------------------------------------------+
void HsClose(int slot, string reason)
{
   if(!g_cycles[slot].hsActive) return;
   if(g_cycles[slot].hsTicket == 0) return;

   ulong tkt = g_cycles[slot].hsTicket;
   g_trade.SetExpertMagicNumber(MagicNumber + 1);

   if(PositionSelectByTicket(tkt))
   {
      if(g_trade.PositionClose(tkt))
      {
         double hsPL = GetClosedHsProfit(tkt);
         g_cycles[slot].hsPL             += hsPL;
         g_cycles[slot].profit           += hsPL;
         g_sessionRealizedProfit         += hsPL;
         g_dailyRealizedProfit           += hsPL;

         AdLogI(LOG_CAT_HEDGE, StringFormat(
            "=== HS CLOSED #%d === Reason: %s | P&L=%.2f",
            g_cycles[slot].cycleID, reason, hsPL));
         Alert(StringFormat("AcquaDulza HS CHIUSO #%d | %s | P&L=%+.2f | %s",
               g_cycles[slot].cycleID, reason, hsPL, _Symbol));
      }
      else
      {
         AdLogE(LOG_CAT_HEDGE, StringFormat("HS CLOSE FAILED #%d | Error: %s",
                g_cycles[slot].cycleID, g_trade.ResultRetcodeDescription()));
         return;
      }
   }
   else
   {
      AdLogW(LOG_CAT_HEDGE, StringFormat("HS #%d già chiusa dal broker", g_cycles[slot].cycleID));
   }

   g_cycles[slot].hsActive   = false;
   g_cycles[slot].hsTicket   = 0;
   g_cycles[slot].hsFillTime = 0;

   if(g_cycles[slot].state == CYCLE_HEDGING)
   {
      if(g_cycles[slot].ticket > 0 && PositionSelectByTicket(g_cycles[slot].ticket))
         g_cycles[slot].state = CYCLE_ACTIVE;
   }
}

//+------------------------------------------------------------------+
//| HsCleanup — Cancella/chiudi HS quando la Soup si chiude         |
//+------------------------------------------------------------------+
void HsCleanup(int slot, string reason)
{
   if(g_cycles[slot].hsPending)
      HsCancel(slot, reason);
   if(g_cycles[slot].hsActive)
      HsClose(slot, reason);
}

//+------------------------------------------------------------------+
//| HsMonitor — Monitor principale Hedge Smart                       |
//|                                                                   |
//| Chiamato ogni nuova barra per ogni slot.                          |
//|                                                                   |
//| PARAMETRI:                                                        |
//|   slot         — indice nel g_cycles array                        |
//|   sig          — segnale DPC corrente da EngineCalculate()        |
//|   hasNewSignal — true se questa barra ha prodotto un segnale DPC |
//+------------------------------------------------------------------+
void HsMonitor(int slot, const EngineSignal &sig, bool hasNewSignal)
{
   if(!EnableHedge || !HsEnabled) return;
   if(slot < 0 || slot >= ArraySize(g_cycles)) return;

   ENUM_CYCLE_STATE st = g_cycles[slot].state;

   // Cleanup se ciclo già chiuso
   if(st == CYCLE_CLOSED)
   {
      HsCleanup(slot, "CycleAlreadyClosed");
      return;
   }

   // Detect fill se pendente
   if(g_cycles[slot].hsPending)
      HsDetectFill(slot);

   // Se non attivo, niente da fare
   if(!g_cycles[slot].hsActive) return;

   // Verifica se Soup ancora aperta
   bool soupOpen = (g_cycles[slot].ticket > 0)
                   && PositionSelectByTicket(g_cycles[slot].ticket);

   if(!soupOpen)
   {
      HsCleanup(slot, "SoupClosed_Cleanup");
      return;
   }

   // Calcola barre attive dall'attivazione
   int barsActive = 0;
   if(g_cycles[slot].hsFillTime > 0)
   {
      int periodSec = PeriodSeconds();
      if(periodSec > 0)
         barsActive = (int)((TimeCurrent() - g_cycles[slot].hsFillTime) / periodSec);
   }

   // ── EXIT 1: Prossimo segnale DPC stesso senso Soup ──
   if(hasNewSignal && sig.isNewSignal && sig.direction == g_cycles[slot].direction)
   {
      if(barsActive >= HsAntiWhipsawBars)
      {
         AdLogI(LOG_CAT_HEDGE, StringFormat(
            "HS EXIT: NextDPCSignal #%d | barsActive=%d | dir=%d",
            g_cycles[slot].cycleID, barsActive, sig.direction));
         HsClose(slot, "NextDPCSignal");
         return;
      }
      else
      {
         AdLogD(LOG_CAT_HEDGE, StringFormat(
            "HS anti-whipsaw #%d: segnale troppo presto (%d<%d barre)",
            g_cycles[slot].cycleID, barsActive, HsAntiWhipsawBars));
      }
   }

   // ── EXIT 2: Soup floating ≥ 0 ──
   if(HsCloseOnSoupProfit)
   {
      double soupFloat = GetFloatingProfit(g_cycles[slot].ticket);
      if(soupFloat >= 0)
      {
         AdLogI(LOG_CAT_HEDGE, StringFormat(
            "HS EXIT: SoupProfitable #%d | SoupFloat=%.2f",
            g_cycles[slot].cycleID, soupFloat));
         HsClose(slot, "SoupProfitable");
         return;
      }
   }

   // ── EXIT 3: Timeout ──
   if(HsTimeoutBars > 0 && barsActive >= HsTimeoutBars)
   {
      AdLogI(LOG_CAT_HEDGE, StringFormat(
         "HS EXIT: Timeout #%d | barsActive=%d >= %d",
         g_cycles[slot].cycleID, barsActive, HsTimeoutBars));
      HsClose(slot, "Timeout");
      return;
   }
}
