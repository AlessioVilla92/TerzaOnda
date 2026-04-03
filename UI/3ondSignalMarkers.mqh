//+------------------------------------------------------------------+
//|                                       adSignalMarkers.mqh        |
//|           TerzaOnda EA v1.6.1 — Signal Markers                  |
//|                                                                  |
//|  Visualizzazione segnali DPC sul chart — frecce, dot e labels.   |
//|                                                                  |
//|  DUE MODALITA' DI DISEGNO:                                       |
//|                                                                  |
//|  1. REAL-TIME (DrawSignalMarkers) — segnali nuovi in tempo reale |
//|     Chiamata da OnTick() quando engine genera un nuovo segnale.  |
//|     Oggetti: TOND_SIG_*, TOND_DOT_*, TOND_LBL_*, TOND_TRIG_*            |
//|                                                                  |
//|  2. SCAN STORICO (ScanHistoricalSignals) — frecce passate        |
//|     Chiamata su ogni nuova barra (pre-gate, indipendente dallo   |
//|     stato EA). Replica la pipeline COMPLETA di EngineCalculate() |
//|     per allineare frecce storiche ai trigger reali.              |
//|     Oggetti: TOND_HSIG_*, TOND_HDOT_*, TOND_HLBL_*                    |
//|                                                                  |
//|  COLORI FRECCE:                                                   |
//|     TBS (Turtle Breakout Soup): lime/rosso brillante             |
//|     TWS (Turtle Wick Soup): verde/rosso scuro (attenuato)        |
//|                                                                  |
//|  ARROW PLACEMENT (offset verticale):                              |
//|     offset = ATR * TOND_ARROW_OFFSET (0.15)                        |
//|     BUY: sotto la lower band (bandPrice - offset)                |
//|     SELL: sopra la upper band (bandPrice + offset)                |
//|     Con ATR scaling l'offset e' proporzionale alla volatilita'.   |
//|                                                                  |
//|  Z-ORDER LAYERING:                                                |
//|     Signal arrows: Z=400 (sotto trigger)                          |
//|     Trigger arrows: Z=600 (sopra signal, cyan brillante)          |
//|     Entry dots: default Z (centro sulla banda)                    |
//|                                                                  |
//|  DIPENDENZE:                                                      |
//|     Config/adVisualTheme.mqh: TOND_ARROW_*, TOND_ENTRY_*_CLR         |
//|     Engine/adDPCBands.mqh: KPCComputeOverlayBands, KPCGetATR, etc.      |
//|     Engine/3ondKPCFilters.mqh: KPCCheckF1, KPCClassifySignal |
//+------------------------------------------------------------------+
#property copyright "TerzaOnda (C) 2026"

//+------------------------------------------------------------------+
//| GetSignalArrowColor — TBS bright / TWS muted                     |
//+------------------------------------------------------------------+
color GetSignalArrowColor(bool isBuy, int quality)
{
   if(quality >= PATTERN_TBS)
      return isBuy ? TOND_ARROW_TBS_BUY : TOND_ARROW_TBS_SELL;
   else
      return isBuy ? TOND_ARROW_TWS_BUY : TOND_ARROW_TWS_SELL;
}

//+------------------------------------------------------------------+
//| DrawSignalArrow — TBS/TWS arrow with ATR offset                  |
//|  arrowCode 233=up (BUY), 234=down (SELL)                         |
//+------------------------------------------------------------------+
void DrawSignalArrow(const EngineSignal &sig)
{
   if(!ShowSignalArrows) return;
   if(sig.direction == 0 || !sig.isNewSignal) return;

   bool isBuy = (sig.direction > 0);
   string name = StringFormat("TOND_SIG_%s_%d_%s",
                 isBuy ? "BUY" : "SELL", sig.quality,
                 TimeToString(sig.barTime, TIME_DATE|TIME_MINUTES));

   int arrowCode = isBuy ? 233 : 234;
   color clr = GetSignalArrowColor(isBuy, sig.quality);

   // Arrow placement: band level with ATR offset
   double atr = (sig.extraValues[0] > 0) ? sig.extraValues[0] : 0;
   double offset = atr * TOND_ARROW_OFFSET;
   double bandPrice = isBuy ? sig.lowerBand : sig.upperBand;
   if(bandPrice <= 0) bandPrice = sig.entryPrice;
   double price = isBuy ? (bandPrice - offset) : (bandPrice + offset);
   if(price <= 0) price = bandPrice;

   ObjectCreate(0, name, OBJ_ARROW, 0, sig.barTime, price);
   ObjectSetInteger(0, name, OBJPROP_ARROWCODE, arrowCode);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, TOND_ARROW_SIZE);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, isBuy ? ANCHOR_TOP : ANCHOR_BOTTOM);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 400);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);

   string patternName = (sig.quality >= PATTERN_TBS) ? "TBS" : "TWS";
   ObjectSetString(0, name, OBJPROP_TOOLTIP,
       StringFormat("%s %s | Entry: %s | SL: %s | TP: %s",
                    patternName, isBuy ? "BUY" : "SELL",
                    DoubleToString(sig.entryPrice, _Digits),
                    DoubleToString(sig.slPrice, _Digits),
                    DoubleToString(sig.tpPrice, _Digits)));
}

//+------------------------------------------------------------------+
//| DrawSignalLabel — Text label "TRIGGER BUY [TBS]" at arrow pos    |
//+------------------------------------------------------------------+
void DrawSignalLabel(const EngineSignal &sig)
{
   if(!ShowSignalArrows) return;
   if(sig.direction == 0 || !sig.isNewSignal) return;

   bool isBuy = (sig.direction > 0);
   string name = StringFormat("TOND_LBL_%s_%s",
                 isBuy ? "BUY" : "SELL",
                 TimeToString(sig.barTime, TIME_DATE|TIME_MINUTES));

   string patternName = (sig.quality >= PATTERN_TBS) ? "TBS" : "TWS";
   string text = StringFormat("TRIGGER %s [%s]", isBuy ? "BUY" : "SELL", patternName);
   color clr = GetSignalArrowColor(isBuy, sig.quality);

   // Place near arrow
   double atr = (sig.extraValues[0] > 0) ? sig.extraValues[0] : 0;
   double offset = atr * (TOND_ARROW_OFFSET + 0.5);
   double bandPrice = isBuy ? sig.lowerBand : sig.upperBand;
   if(bandPrice <= 0) bandPrice = sig.entryPrice;
   double price = isBuy ? (bandPrice - offset) : (bandPrice + offset);

   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_TEXT, 0, sig.barTime, price);

   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 7);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, isBuy ? ANCHOR_UPPER : ANCHOR_LOWER);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

//+------------------------------------------------------------------+
//| DrawEntryDot — Circle marker at band touch point                 |
//|  arrowCode 159 = filled circle                                   |
//+------------------------------------------------------------------+
void DrawEntryDot(const EngineSignal &sig)
{
   if(!ShowSignalArrows) return;
   if(sig.direction == 0 || !sig.isNewSignal) return;

   bool isBuy = (sig.direction > 0);
   double bandPrice = isBuy ? sig.lowerBand : sig.upperBand;
   if(bandPrice <= 0) return;

   string name = StringFormat("TOND_DOT_%s_%s",
                 isBuy ? "BUY" : "SELL",
                 TimeToString(sig.barTime, TIME_DATE|TIME_MINUTES));

   color clr = isBuy ? TOND_ENTRY_BUY_CLR : TOND_ENTRY_SELL_CLR;

   ObjectCreate(0, name, OBJ_ARROW, 0, sig.barTime, bandPrice);
   ObjectSetInteger(0, name, OBJPROP_ARROWCODE, 159);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_CENTER);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);

   ObjectSetString(0, name, OBJPROP_TOOLTIP,
       StringFormat("Entry dot %s | Band: %s",
                    isBuy ? "BUY" : "SELL",
                    DoubleToString(bandPrice, _Digits)));
}

//+------------------------------------------------------------------+
//| DrawTriggerArrow — Freccia cyan quando ordine piazzato            |
//|                                                                  |
//| Sovrapposta alla freccia segnale (Z=600 > Z=400) per indicare    |
//| che l'ordine e' stato effettivamente piazzato dal CycleManager.  |
//| Colore TOND_BIOLUM (cyan brillante), spessore 3 — risalta sopra    |
//| le frecce TBS/TWS piu' piccole.                                  |
//|                                                                  |
//| CHIAMATA DA: TerzaOnda.mq5 OnTick() dopo CreateCycle()          |
//+------------------------------------------------------------------+
void DrawTriggerArrow(int cycleID, double price, datetime barTime, bool isBuy)
{
   if(!ShowSignalArrows) return;

   string name = StringFormat("TOND_TRIG_%s_%d_%s",
                 isBuy ? "BUY" : "SELL", cycleID,
                 TimeToString(barTime, TIME_DATE|TIME_MINUTES));

   int arrowCode = isBuy ? 233 : 234;

   ObjectCreate(0, name, OBJ_ARROW, 0, barTime, price);
   ObjectSetInteger(0, name, OBJPROP_ARROWCODE, arrowCode);
   ObjectSetInteger(0, name, OBJPROP_COLOR, TOND_BIOLUM);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 3);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, isBuy ? ANCHOR_TOP : ANCHOR_BOTTOM);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 600);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);

   ObjectSetString(0, name, OBJPROP_TOOLTIP,
       StringFormat("TRIGGER #%d %s @ %s",
                    cycleID, isBuy ? "BUY STOP" : "SELL STOP",
                    DoubleToString(price, _Digits)));
}

//+------------------------------------------------------------------+
//| DrawSignalMarkers — Combined: arrow + dot + label               |
//+------------------------------------------------------------------+
void DrawSignalMarkers(const EngineSignal &sig)
{
   DrawSignalArrow(sig);
   DrawEntryDot(sig);
   DrawSignalLabel(sig);
}

//+------------------------------------------------------------------+
//| ScanHistoricalSignals — Scansione storica segnali allineata      |
//|                         con EngineCalculate()                     |
//|                                                                  |
//| [MOD] RISCRITTA per allineare le frecce storiche ai trigger      |
//| reali dell'engine. Prima usava solo la condizione base Turtle    |
//| Soup (touch banda + close inside) SENZA alcun filtro avanzato.   |
//| Ora applica la stessa pipeline completa di EngineCalculate():    |
//|   1. Condizione base Turtle Soup (touch banda + close inside)    |
//|   2. Anti-ambiguita' (skip se entrambe le bande toccate)         |
//|   3. Filtro Flatness  — banda stabile (non in espansione)        |
//|   4. Filtro LevelAge  — banda allo stesso livello per N barre   |
//|   5. Filtro Width     — canale largo almeno g_kpc_minWidthPips_eff pip   |
//|   6. Filtro TrendCtx  — blocca segnali contro-trend forte       |
//|   7. Filtro TimeFilter — blocca in finestra oraria bloccata      |
//|   8. Filtro MA         — direzionale su media mobile             |
//|   9. SmartCooldown    — stato midline touch + spacing barre      |
//|  10. Classifica TBS/TWS + filtro TWS                             |
//|                                                                  |
//| Risultato: le frecce nel grafico corrispondono esattamente ai    |
//| segnali che l'engine avrebbe generato in tempo reale.            |
//+------------------------------------------------------------------+
void ScanHistoricalSignals()
{
   if(!ShowSignalArrows) return;

   int depth = MathMax(1, OverlayDepth);
   int totalBars = iBars(_Symbol, PERIOD_CURRENT);
   int kpcPeriod = g_kpc_kamaPeriod_eff;
   if(totalBars < kpcPeriod + 5)
   {
      AdLogW(LOG_CAT_UI, StringFormat("ScanHistoricalSignals: insufficient bars (%d < %d)", totalBars, kpcPeriod + 5));
      return;
   }
   depth = MathMin(depth, totalBars - 2);

   // Pulizia vecchi marker storici
   ObjectsDeleteAll(0, "TOND_HSIG_");
   ObjectsDeleteAll(0, "TOND_HDOT_");
   ObjectsDeleteAll(0, "TOND_HLBL_");

   // ── SmartCooldown state machine (replica di adDPCCooldown.mqh) ──
   // Simuliamo lo stato del cooldown barra per barra, come fa l'engine
   // in tempo reale. Variabili locali per non interferire con lo stato globale.
   int    hsLastSignalBarIdx   = 0;      // indice barra dell'ultimo segnale emesso
   int    hsLastDirection      = 0;      // +1=BUY, -1=SELL, 0=nessuno
   bool   hsMidlineTouched     = false;  // prezzo ha toccato la midline dopo l'ultimo segnale
   int    hsMidlineTouchBarIdx = 0;      // indice barra del tocco midline
   bool   hsWaitingForMidTouch = false;  // in attesa di midline touch

   int signalCount = 0;
   int filteredCount = 0;  // contatore segnali base filtrati (per log diagnostico)
   int baseDetected = 0;   // contatore segnali base rilevati
   int flatBlocked = 0, ageBlocked = 0, widthBlocked = 0;
   int trendBlocked = 0, timeBlocked = 0, maBlocked = 0, cdBlocked = 0, twsBlocked = 0;

   // Loop da barra più vecchia (depth) a più recente (1)
   for(int i = depth; i >= 1; i--)
   {
      // ── Lookback guard: servono kpcPeriod barre di storia ──
      if(i >= totalBars - kpcPeriod) continue;

      // ── Calcolo bande Keltner per barra [i] ──
      double upper, lower, mid;
      KPCComputeOverlayBands(i, upper, lower, mid);
      if(upper <= 0 || lower <= 0) continue;

      // ── Dati OHLC della barra [i] ──
      double high1  = iHigh(_Symbol, PERIOD_CURRENT, i);
      double low1   = iLow(_Symbol, PERIOD_CURRENT, i);
      double open1  = iOpen(_Symbol, PERIOD_CURRENT, i);
      double close1 = iClose(_Symbol, PERIOD_CURRENT, i);
      datetime barTime = iTime(_Symbol, PERIOD_CURRENT, i);

      // ── currentBarIdx: indice assoluto della barra (per SmartCooldown) ──
      int currentBarIdx = totalBars - 1 - i;

      // ── SmartCooldown: aggiorna stato midline touch ad ogni barra ──
      // Replica la logica di logica KPC SimpleCooldown.mqh.
      // Dopo un segnale, monitora se il prezzo ha raggiunto la midline
      // (high >= mid dopo BUY, low <= mid dopo SELL). Quando la midline
      // viene toccata, sblocca i segnali nella stessa direzione.
      if(hsWaitingForMidTouch && hsLastDirection != 0 && mid > 0)
      {
         bool midCrossed = false;
         if(hsLastDirection == +1 && high1 >= mid)
            midCrossed = true;
         else if(hsLastDirection == -1 && low1 <= mid)
            midCrossed = true;

         if(midCrossed)
         {
            hsMidlineTouched     = true;
            hsMidlineTouchBarIdx = currentBarIdx;
            hsWaitingForMidTouch = false;
         }
      }

      // ══════════════════════════════════════════════════════════
      // ══ STEP 1: Condizione base Turtle Soup ═══════════════════
      // ══════════════════════════════════════════════════════════
      // Identica a EngineCalculate() linee 189-190:
      // SELL (bearBase): wick/body tocca upper band, close DENTRO il canale
      // BUY  (bullBase): wick/body tocca lower band, close DENTRO il canale
      bool bearBase = (high1 >= upper) && (close1 < upper);
      bool bullBase = (low1 <= lower)  && (close1 > lower);

      // ── Anti-ambiguita': entrambe le bande toccate → skip ──
      if(bearBase && bullBase) continue;
      if(!bearBase && !bullBase) continue;
      baseDetected++;

      // ══════════════════════════════════════════════════════════
      // ══ STEP 2: Filtro Flatness (banda stabile) ═══════════════
      // ══════════════════════════════════════════════════════════
      // Replica KPCCheckF1_ERRegime/Buy() di adDPCFilters.mqh.
      // Blocca il segnale se la banda toccata si e' espansa oltre
      // flatTolerance (= g_kpc_erTrending_eff * ATR) nelle ultime g_kpc_minSqueezeBars_eff barre.
      // Una banda in espansione indica un breakout in corso, non un rejection.
      {
         double er_i = 0;
         KPCComputeKAMA(i, er_i);
         if(bearBase)
         {
            if(!KPCCheckF1_ERRegime(er_i)) bearBase = false;
         }
         if(bullBase)
         {
            if(!KPCCheckF1_ERRegime(er_i)) bullBase = false;
         }
      }
      if(!bearBase && !bullBase) { filteredCount++; flatBlocked++; continue; }

      // ══════════════════════════════════════════════════════════
      // ══ STEP 3: Filtro LevelAge (banda matura) ════════════════
      // ══════════════════════════════════════════════════════════
      // Replica KPCCheckF2_Squeeze/Buy() di adDPCFilters.mqh.
      // Richiede che la banda toccata sia allo stesso prezzo esatto
      // (±2 points) per almeno g_kpc_minSqueezeBars_eff barre consecutive.
      // Una banda "giovane" (appena formata da un nuovo max/min)
      // non e' un livello affidabile per il pattern Turtle Soup.
      {
         if(bearBase)
         {
            if(!KPCCheckF2_Squeeze()) bearBase = false;
         }
         if(bullBase)
         {
            if(!KPCCheckF2_Squeeze()) bullBase = false;
         }
      }
      if(!bearBase && !bullBase) { filteredCount++; ageBlocked++; continue; }

      // ══════════════════════════════════════════════════════════
      // ══ STEP 4: Filtro Width (larghezza canale) ═══════════════
      // ══════════════════════════════════════════════════════════
      // Replica KPCCheckF6_Width() di adDPCFilters.mqh.
      // Il canale deve essere largo almeno g_kpc_minWidthPips_eff pips
      // (scalato per strumento e timeframe tramite preset).
      // Un canale troppo stretto genera segnali inaffidabili.
      if(InpKPC_UseWidthFilter)
      {
         if(!KPCCheckF6_Width(upper, lower))
         {
            filteredCount++; widthBlocked++;
            continue;
         }
      }

      // ══════════════════════════════════════════════════════════
      // ══ STEP 5: Filtro TrendContext (trend macro) ═════════════
      // ══════════════════════════════════════════════════════════
      // Replica KPCCheckF4_Fire/Buy() di adDPCFilters.mqh.
      // Blocca segnali contro-trend: se la midline si e' spostata
      // oltre InpTrendContextMult * ATR in un periodo dcLen.
      // Attualmente OFF di default (InpUseTrendContext = false).
      if(!KPCCheckF4_Fire())
      {
         if(bearBase) bearBase = false;
         if(bullBase) bullBase = false;
      }
      if(!bearBase && !bullBase) { filteredCount++; trendBlocked++; continue; }

      // ══════════════════════════════════════════════════════════
      // ══ STEP 6: Filtro Time (finestra oraria bloccata) ════════
      // ══════════════════════════════════════════════════════════
      // Replica IsInBlockedTime() di adSessionManager.mqh.
      // Per lo scan storico usiamo l'ora della barra (non TimeCurrent).
      // Attualmente OFF di default (InpUseTimeFilter = false).
      if(InpKPC_UseTimeFilter)
      {
         MqlDateTime barDT;
         TimeToStruct(barTime, barDT);
         int barMinutes = barDT.hour * 60 + barDT.min;
         if(g_kpcTimeBlockStartMin < g_kpcTimeBlockEndMin)
         {
            if(barMinutes >= g_kpcTimeBlockStartMin && barMinutes < g_kpcTimeBlockEndMin)
            { filteredCount++; timeBlocked++; continue; }
         }
         else if(g_kpcTimeBlockStartMin > g_kpcTimeBlockEndMin)
         {
            if(barMinutes >= g_kpcTimeBlockStartMin || barMinutes < g_kpcTimeBlockEndMin)
            { filteredCount++; timeBlocked++; continue; }
         }
      }

      // ══════════════════════════════════════════════════════════
      // ══ STEP 7: Filtro MA (direzione media mobile) ════════════
      // ══════════════════════════════════════════════════════════
      // Replica KPCCheckF5_WPR() di adDPCFilters.mqh.
      // Filtra in base alla posizione del close rispetto alla MA.
      // CLASSIC: trend-following (SELL solo sotto MA, BUY solo sopra).
      // INVERTED: mean-reversion Soup (SELL sopra MA, BUY sotto MA).
      {
         int dir_tmp = bearBase ? -1 : +1;
         if(!KPCCheckF5_WPR(dir_tmp))
         {
            if(bearBase) bearBase = false;
            if(bullBase) bullBase = false;
         }
      }
      if(!bearBase && !bullBase) { filteredCount++; maBlocked++; continue; }

      // ══════════════════════════════════════════════════════════
      // ══ STEP 8: SmartCooldown (frequenza segnali) ═════════════
      // ══════════════════════════════════════════════════════════
      // Replica KPCCheckCooldown di 3ondKPCCooldown.mqh.
      // Controlla il tempo minimo tra segnali:
      //   - SmartCooldown OFF: cooldown fisso di dcLen barre
      //   - SmartCooldown ON, primo segnale: sempre accettato
      //   - SmartCooldown ON, stessa direzione: richiede midline touch
      //     + g_kpc_nSameBars_eff barre dopo il touch
      //   - SmartCooldown ON, direzione opposta: solo g_kpc_nOppositeBars_eff barre
      int direction = bullBase ? +1 : -1;
      bool cooldownOK = false;

      if(hsLastDirection == 0)
      {
         // Primo segnale in assoluto: sempre accettato
         cooldownOK = true;
      }
      else if(direction == hsLastDirection)
      {
         // Stessa direzione (es. SELL dopo SELL):
         // richiede midline touch + g_kpc_nSameBars_eff barre dopo il touch
         cooldownOK = hsMidlineTouched &&
                      (currentBarIdx - hsMidlineTouchBarIdx >= g_kpc_nSameBars_eff);
      }
      else
      {
         // Direzione opposta (es. SELL dopo BUY):
         // solo minimum barre
         cooldownOK = (currentBarIdx - hsLastSignalBarIdx >= g_kpc_nOppositeBars_eff);
      }

      if(!cooldownOK) { filteredCount++; cdBlocked++; continue; }

      // ══════════════════════════════════════════════════════════
      // ══ STEP 9: Classifica TBS/TWS + filtro TWS ═══════════════
      // ══════════════════════════════════════════════════════════
      // Replica KPCClassifySignal() di adDPCFilters.mqh.
      // TBS (Turtle Breakout Soup): body penetra la banda — segnale forte
      // TWS (Turtle Wick Soup): solo wick penetra — segnale debole
      // Se InpShowTWSSignals e' false, i TWS vengono scartati.
      double atrI = KPCGetATR(i);
      double upperHalf = mid + atrI * g_kpc_halfMultiplier_eff;
      double lowerHalf = mid - atrI * g_kpc_halfMultiplier_eff;
      int quality = KPCClassifySignal(direction, open1, close1, upper, lower, upperHalf, lowerHalf);

      if(!InpKPC_ShowHalfSignals && quality == PATTERN_TWS) { filteredCount++; twsBlocked++; continue; }

      // ══════════════════════════════════════════════════════════
      // ══ SEGNALE CONFERMATO — aggiorna SmartCooldown + disegna ═
      // ══════════════════════════════════════════════════════════
      // Aggiorna lo stato del cooldown (replica KPCUpdateCooldownState).
      // Resetta il flag midline touch, registra direzione e indice barra.
      hsLastSignalBarIdx   = currentBarIdx;
      hsLastDirection      = direction;
      hsMidlineTouched     = false;
      hsMidlineTouchBarIdx = 0;
      hsWaitingForMidTouch = true;

      // === DISEGNO MARKER STORICI ===
      bool isBuy = (direction > 0);
      color clr = GetSignalArrowColor(isBuy, quality);
      string patternName = (quality >= PATTERN_TBS) ? "TBS" : "TWS";
      string timeStr = TimeToString(barTime, TIME_DATE|TIME_MINUTES);
      double bandPrice = isBuy ? lower : upper;

      // ATR per offset verticale della freccia
      double atr = KPCGetATR(i);
      double atrPrice = (atr > 0) ? atr : 0;
      double offset = atrPrice * TOND_ARROW_OFFSET;

      // Freccia direzionale (su=BUY, giu'=SELL)
      {
         string name = StringFormat("TOND_HSIG_%s_%d_%s",
                       isBuy ? "BUY" : "SELL", quality, timeStr);
         int arrowCode = isBuy ? 233 : 234;
         double price = isBuy ? (bandPrice - offset) : (bandPrice + offset);
         if(price <= 0) price = bandPrice;

         ObjectCreate(0, name, OBJ_ARROW, 0, barTime, price);
         ObjectSetInteger(0, name, OBJPROP_ARROWCODE, arrowCode);
         ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
         ObjectSetInteger(0, name, OBJPROP_WIDTH, TOND_ARROW_SIZE);
         ObjectSetInteger(0, name, OBJPROP_ANCHOR, isBuy ? ANCHOR_TOP : ANCHOR_BOTTOM);
         ObjectSetInteger(0, name, OBJPROP_BACK, false);
         ObjectSetInteger(0, name, OBJPROP_ZORDER, 400);
         ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
         ObjectSetString(0, name, OBJPROP_TOOLTIP,
             StringFormat("%s %s | Band: %s | Mid: %s",
                          patternName, isBuy ? "BUY" : "SELL",
                          DoubleToString(bandPrice, _Digits),
                          DoubleToString(mid, _Digits)));
      }

      // Punto d'ingresso (cerchio pieno) sulla banda
      {
         string name = StringFormat("TOND_HDOT_%s_%s",
                       isBuy ? "BUY" : "SELL", timeStr);
         ObjectCreate(0, name, OBJ_ARROW, 0, barTime, bandPrice);
         ObjectSetInteger(0, name, OBJPROP_ARROWCODE, 159);
         ObjectSetInteger(0, name, OBJPROP_COLOR, isBuy ? TOND_ENTRY_BUY_CLR : TOND_ENTRY_SELL_CLR);
         ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_CENTER);
         ObjectSetInteger(0, name, OBJPROP_BACK, false);
         ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
      }

      // Etichetta testo "TRIGGER BUY [TBS]"
      {
         string name = StringFormat("TOND_HLBL_%s_%s",
                       isBuy ? "BUY" : "SELL", timeStr);
         string text = StringFormat("TRIGGER %s [%s]", isBuy ? "BUY" : "SELL", patternName);
         double labelOffset = atrPrice * (TOND_ARROW_OFFSET + 0.5);
         double price = isBuy ? (bandPrice - labelOffset) : (bandPrice + labelOffset);

         ObjectCreate(0, name, OBJ_TEXT, 0, barTime, price);
         ObjectSetString(0, name, OBJPROP_TEXT, text);
         ObjectSetString(0, name, OBJPROP_FONT, "Arial");
         ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 7);
         ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
         ObjectSetInteger(0, name, OBJPROP_ANCHOR, isBuy ? ANCHOR_UPPER : ANCHOR_LOWER);
         ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      }

      // DIAG: Log posizionamento freccia (solo prime 3 per non inondare il log)
      if(signalCount < 3)
         AdLogD(LOG_CAT_UI, StringFormat(
            "DIAG Arrow #%d: %s @ bar=%d | band=%.2f | atr=%.2f | offset=%.2f | arrowPrice=%.2f",
            signalCount + 1, isBuy ? "BUY" : "SELL", i, bandPrice, atrPrice, offset,
            isBuy ? (bandPrice - offset) : (bandPrice + offset)));

      signalCount++;
   }

   // Log con conteggio segnali trovati e breakdown per-filtro
   AdLogI(LOG_CAT_UI, StringFormat(
      "ScanHist: depth=%d | base=%d | blocked: flat=%d age=%d width=%d trend=%d time=%d ma=%d cd=%d tws=%d | PASSED=%d",
      depth, baseDetected, flatBlocked, ageBlocked, widthBlocked,
      trendBlocked, timeBlocked, maBlocked, cdBlocked, twsBlocked, signalCount));
}

//+------------------------------------------------------------------+
//| CleanupSignalMarkers — Rimuove tutti i marker segnale            |
//|                                                                  |
//| Cancella 7 famiglie di oggetti per prefisso:                     |
//|   TOND_SIG_  — frecce segnale real-time                            |
//|   TOND_DOT_  — entry dots real-time                                |
//|   TOND_LBL_  — labels testo real-time                              |
//|   TOND_TRIG_ — frecce trigger cyan (ordine piazzato)               |
//|   TOND_HSIG_ — frecce storiche (scan)                              |
//|   TOND_HDOT_ — entry dots storici                                  |
//|   TOND_HLBL_ — labels testo storici                                |
//|                                                                  |
//| CHIAMATA DA: OnDeinit() in TerzaOnda.mq5                       |
//+------------------------------------------------------------------+
void CleanupSignalMarkers()
{
   ObjectsDeleteAll(0, "TOND_SIG_");
   ObjectsDeleteAll(0, "TOND_DOT_");
   ObjectsDeleteAll(0, "TOND_LBL_");
   ObjectsDeleteAll(0, "TOND_TRIG_");
   ObjectsDeleteAll(0, "TOND_HSIG_");
   ObjectsDeleteAll(0, "TOND_HDOT_");
   ObjectsDeleteAll(0, "TOND_HLBL_");
}
