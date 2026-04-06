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
//|     NOTA KPC: i filtri F2 (Squeeze) e F4 (Fire) sono STATEFUL   |
//|     e richiedono stato accumulato per-bar. Lo scan ricostruisce  |
//|     questo stato LOCALMENTE (hsSqueezeBarsCount, hsFireActive)   |
//|     senza toccare le variabili globali g_kpc* dell'engine.       |
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
//| [MOD v2.0] RISCRITTA per KPC (Keltner Predictive Channel).       |
//| I filtri DPC (Flatness/LevelAge) erano stateless. I filtri KPC  |
//| (F2 Squeeze, F4 Fire) sono STATEFUL e richiedono ricostruzione  |
//| dello stato accumulato per-bar. Pipeline allineata a             |
//| EngineCalculate() + KPCUpdateSqueezeState():                     |
//|   1. Base Turtle Soup (Primary + Half band + wick ratio)         |
//|   2. Anti-ambiguita' (skip se entrambe le bande toccate)         |
//|   3. F1 ER Regime — trend estremo (ER inline, no KAMA side eff) |
//|   4. F2 Squeeze   — DCW percentile + decay (stato locale)       |
//|   5. F6 Width     — canale largo almeno g_kpc_minWidthPips_eff  |
//|   6. F4 Fire      — post-squeeze DCW spike (stato locale)       |
//|   7. F7 Time      — finestra oraria bloccata                    |
//|   8. SimpleCooldown — conteggio barre + fire block (no midTouch) |
//|   9. Classifica TBS/TWS + filtro TWS                             |
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

   // ── LOCAL squeeze/fire state (per-bar, replica di KPCUpdateSqueezeState) ──
   // I filtri F2 (Squeeze) e F4 (Fire) di KPC sono STATEFUL: richiedono
   // stato accumulato barra per barra. A differenza di DPC (Flatness/LevelAge
   // stateless), dobbiamo ricostruire lo stato localmente senza toccare
   // le variabili globali g_kpc* usate dall'engine real-time.
   int    hsSqueezeBarsCount      = 0;
   bool   hsSqueezeWasActive      = false;
   bool   hsFireActive            = false;
   int    hsFireCooldownRemaining = 0;
   double hsLastDCW               = 0;
   double hsPrevDCW               = 0;
   double hsPrev2DCW              = 0;

   // ── LOCAL DCW ring buffer per percentile (F2 Squeeze) ──
   int    hsDcwLookback = MathMax(10, InpKPC_F2_DCWLookback);
   double hsDcwRing[];
   ArrayResize(hsDcwRing, hsDcwLookback);
   ArrayInitialize(hsDcwRing, 0);
   int    hsDcwRingIdx    = 0;
   bool   hsDcwRingFilled = false;

   // ── LOCAL SimpleCooldown (allineato a 3ondKPCCooldown.mqh) ──
   // KPC v1.03: rimosso midline touch gate. Solo conteggio barre + fire block.
   int    hsCDLastDirection    = 0;   // +1=BUY, -1=SELL, 0=nessuno
   int    hsCDLastSignalBarIdx = 0;   // indice barra ultimo segnale

   int signalCount = 0;
   int filteredCount = 0;
   int baseDetected = 0;
   int erBlocked = 0, sqzBlocked = 0, widthBlocked = 0;
   int fireBlocked = 0, timeBlocked = 0, cdBlocked = 0, twsBlocked = 0;

   // Loop da barra piu' vecchia (depth) a piu' recente (1)
   for(int i = depth; i >= 1; i--)
   {
      // ── Lookback guard: servono kpcPeriod barre di storia ──
      if(i >= totalBars - kpcPeriod) continue;

      // ── Calcolo bande Keltner per barra [i] ──
      double upper, lower, mid;
      KPCComputeOverlayBands(i, upper, lower, mid);
      if(upper <= 0 || lower <= 0) continue;

      // ── ATR per barra [i] ──
      double atrI = KPCGetATR(i);

      // ── Dati OHLC della barra [i] ──
      double high1  = iHigh(_Symbol, PERIOD_CURRENT, i);
      double low1   = iLow(_Symbol, PERIOD_CURRENT, i);
      double open1  = iOpen(_Symbol, PERIOD_CURRENT, i);
      double close1 = iClose(_Symbol, PERIOD_CURRENT, i);
      datetime barTime = iTime(_Symbol, PERIOD_CURRENT, i);

      // ── currentBarIdx: indice assoluto della barra (per cooldown) ──
      int currentBarIdx = totalBars - 1 - i;

      // ══════════════════════════════════════════════════════════
      // ══ PER-BAR: Aggiorna stato squeeze/fire locale ═══════════
      // ══════════════════════════════════════════════════════════
      // Replica KPCUpdateSqueezeState() di 3ondKPCFilters.mqh (linee 128-201)
      // e KPCCheckFire() (linee 206-230) con variabili locali.
      // Eseguito su OGNI barra (non solo segnali) perche' lo stato e' cumulativo.
      if(atrI > 0)
      {
         // DCW: range Donchian 20 barre / ATR (normalizzato)
         double hh20 = iHigh(_Symbol, PERIOD_CURRENT, i);
         double ll20 = iLow(_Symbol, PERIOD_CURRENT, i);
         for(int k = 1; k < 20 && (i + k) < totalBars; k++)
         {
            double h = iHigh(_Symbol, PERIOD_CURRENT, i + k);
            double l = iLow(_Symbol, PERIOD_CURRENT, i + k);
            if(h > hh20) hh20 = h;
            if(l < ll20) ll20 = l;
         }
         double dcwRaw = hh20 - ll20;
         double dcw = dcwRaw / atrI;

         // Shift storia DCW
         hsPrev2DCW = hsPrevDCW;
         hsPrevDCW  = hsLastDCW;
         hsLastDCW  = dcw;

         // Ring buffer per percentile
         hsDcwRing[hsDcwRingIdx] = dcw;
         hsDcwRingIdx++;
         if(hsDcwRingIdx >= hsDcwLookback)
         {
            hsDcwRingIdx = 0;
            hsDcwRingFilled = true;
         }

         // Calcolo percentile DCW
         int ringCount = hsDcwRingFilled ? hsDcwLookback : hsDcwRingIdx;
         double dcwPercentile = 0.5;
         if(ringCount > 0)
         {
            int countBelow = 0;
            for(int r = 0; r < ringCount; r++)
               if(hsDcwRing[r] < dcw) countBelow++;
            dcwPercentile = (double)countBelow / (double)ringCount;
         }

         // ATR fast/slow ratio (opzionale per squeeze)
         double atrFast = KPCCalcATRSimple(i, 5);
         double atrSlow = KPCCalcATRSimple(i, 20);
         double atrRatio = (atrSlow > 1e-10) ? atrFast / atrSlow : 1.0;

         // Squeeze detection con decay graduale
         bool squeezeNow = (dcwPercentile < (double)g_kpc_dcwPercentile_eff / 100.0) &&
                           (!InpKPC_F2_UseATRRatio || atrRatio < g_kpc_atrRatioThresh_eff);

         if(squeezeNow)
            hsSqueezeBarsCount++;
         else if(hsSqueezeBarsCount > 0)
            hsSqueezeBarsCount--;

         if(hsSqueezeBarsCount >= 3)
            hsSqueezeWasActive = true;

         // Fire detection (post-squeeze DCW spike)
         if(hsSqueezeWasActive)
         {
            bool fireNow = (hsLastDCW > g_kpc_fireDCWThresh_eff) &&
                           ((hsPrevDCW > 0 && hsLastDCW > hsPrevDCW * 1.20) ||
                            (hsPrev2DCW > 0 && hsLastDCW > hsPrev2DCW * 1.15));
            if(fireNow)
            {
               hsFireActive = true;
               hsFireCooldownRemaining = g_kpc_fireCooldown_eff;
            }
            else if(hsFireActive && hsFireCooldownRemaining > 0)
            {
               hsFireCooldownRemaining--;
               if(hsFireCooldownRemaining == 0)
               {
                  hsFireActive = false;
                  hsSqueezeWasActive = false;
               }
            }
         }
      }

      // ══════════════════════════════════════════════════════════
      // ══ STEP 1: Condizione base Turtle Soup ═══════════════════
      // ══════════════════════════════════════════════════════════
      // Allineata a EngineCalculate() linee 206-228:
      // Controlla tocco Primary E Half band con wick ratio.
      double upperHalf = mid + atrI * g_kpc_halfMultiplier_eff;
      double lowerHalf = mid - atrI * g_kpc_halfMultiplier_eff;

      bool touchUpperPrimary = (high1 > upper) && (close1 < upper);
      bool touchUpperHalf    = (high1 > upperHalf) && (close1 < upperHalf) && (high1 <= upper);
      bool touchLowerPrimary = (low1 < lower) && (close1 > lower);
      bool touchLowerHalf    = (low1 < lowerHalf) && (close1 > lowerHalf) && (low1 >= lower);

      // Wick ratio: stoppino di rejection / dimensione candela
      double upperWick  = high1 - MathMax(open1, close1);
      double lowerWick  = MathMin(open1, close1) - low1;
      double candleSize = high1 - low1;
      bool wickOK = (candleSize > _Point * 2);

      double wickRatioUpper = wickOK ? upperWick / candleSize : 0;
      double wickRatioLower = wickOK ? lowerWick / candleSize : 0;

      bool bearBase = (touchUpperPrimary || touchUpperHalf) && (wickRatioUpper >= InpKPC_WickRatio);
      bool bullBase = (touchLowerPrimary || touchLowerHalf) && (wickRatioLower >= InpKPC_WickRatio);

      // Qualita': 2=Primary (TBS), 1=Half (TWS)
      int bearQuality = touchUpperPrimary ? 2 : 1;
      int bullQuality = touchLowerPrimary ? 2 : 1;

      // ── Anti-ambiguita': entrambe le bande toccate → skip ──
      if(bearBase && bullBase) { bearBase = false; bullBase = false; }
      if(!bearBase && !bullBase) continue;
      baseDetected++;

      // ══════════════════════════════════════════════════════════
      // ══ STEP 2: Filtro F1 ER Regime (trend estremo) ═══════════
      // ══════════════════════════════════════════════════════════
      // Calcolo ER inline senza modificare g_kpcKAMA (BUG 5 fix).
      // ER = |close[i]-close[i+N]| / sum|close[k]-close[k+1]|
      {
         int period = g_kpc_kamaPeriod_eff;
         double close0_er = iClose(_Symbol, PERIOD_CURRENT, i);
         double closeN_er = iClose(_Symbol, PERIOD_CURRENT, i + period);
         double er_i = 0;
         if(close0_er > 0 && closeN_er > 0)
         {
            double dir_val = MathAbs(close0_er - closeN_er);
            double vol = 0;
            for(int k = 0; k < period; k++)
            {
               double c1 = iClose(_Symbol, PERIOD_CURRENT, i + k);
               double c2 = iClose(_Symbol, PERIOD_CURRENT, i + k + 1);
               if(c1 > 0 && c2 > 0) vol += MathAbs(c1 - c2);
            }
            er_i = (vol > 1e-10) ? dir_val / vol : 0;
         }

         if(!KPCCheckF1_ERRegime(er_i))
         { bearBase = false; bullBase = false; }
      }
      if(!bearBase && !bullBase) { filteredCount++; erBlocked++; continue; }

      // ══════════════════════════════════════════════════════════
      // ══ STEP 3: Filtro F2 Squeeze (stato locale per-bar) ══════
      // ══════════════════════════════════════════════════════════
      // Usa hsSqueezeBarsCount locale (accumulato sopra), non g_kpc* globale.
      if(hsSqueezeBarsCount < g_kpc_minSqueezeBars_eff)
      { bearBase = false; bullBase = false; }
      if(!bearBase && !bullBase) { filteredCount++; sqzBlocked++; continue; }

      // ══════════════════════════════════════════════════════════
      // ══ STEP 4: Filtro F6 Width (larghezza canale) ════════════
      // ══════════════════════════════════════════════════════════
      if(InpKPC_UseWidthFilter)
      {
         if(!KPCCheckF6_Width(upper, lower))
         {
            filteredCount++; widthBlocked++;
            continue;
         }
      }

      // ══════════════════════════════════════════════════════════
      // ══ STEP 5: Filtro F4 Fire (stato locale per-bar) ═════════
      // ══════════════════════════════════════════════════════════
      // Usa hsFireActive locale (accumulato sopra), non g_kpc* globale.
      if(hsFireActive)
      { bearBase = false; bullBase = false; }
      if(!bearBase && !bullBase) { filteredCount++; fireBlocked++; continue; }

      // ══════════════════════════════════════════════════════════
      // ══ STEP 6: Filtro Time (finestra oraria bloccata) ════════
      // ══════════════════════════════════════════════════════════
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
      // ══ STEP 7: SimpleCooldown (frequenza segnali) ════════════
      // ══════════════════════════════════════════════════════════
      // Replica 3ondKPCCooldown.mqh (linee 29-62):
      //   - Primo segnale: sempre accettato
      //   - Stessa direzione: barsFromLast >= g_kpc_nSameBars_eff
      //   - Direzione opposta: barsFromLast >= g_kpc_nOppositeBars_eff
      //   - Fire block: se hsFireActive → cooldown non passa
      // KPC v1.03: NO midline touch gate (rimosso).
      int direction = bullBase ? +1 : -1;
      bool cooldownOK = false;

      if(hsFireActive)
      {
         cooldownOK = false;  // Fire block integrato nel cooldown
      }
      else if(hsCDLastDirection == 0)
      {
         cooldownOK = true;   // Primo segnale: nessun cooldown
      }
      else
      {
         int barsFromLast = currentBarIdx - hsCDLastSignalBarIdx;
         if(direction == hsCDLastDirection)
            cooldownOK = (barsFromLast >= g_kpc_nSameBars_eff);     // Stessa direzione
         else
            cooldownOK = (barsFromLast >= g_kpc_nOppositeBars_eff); // Direzione opposta
      }

      if(!cooldownOK) { filteredCount++; cdBlocked++; continue; }

      // ══════════════════════════════════════════════════════════
      // ══ STEP 8: Classifica TBS/TWS + filtro TWS ═══════════════
      // ══════════════════════════════════════════════════════════
      // Usa bearQuality/bullQuality da STEP 1 (come EngineCalculate linee 358-361):
      // Primary touch (quality=2) → TBS, Half touch (quality=1) → TWS
      int quality;
      if(direction == -1)
         quality = (bearQuality == 2) ? PATTERN_TBS : PATTERN_TWS;
      else
         quality = (bullQuality == 2) ? PATTERN_TBS : PATTERN_TWS;

      if(!InpKPC_ShowHalfSignals && quality == PATTERN_TWS) { filteredCount++; twsBlocked++; continue; }

      // ══════════════════════════════════════════════════════════
      // ══ SEGNALE CONFERMATO — aggiorna cooldown + disegna ══════
      // ══════════════════════════════════════════════════════════
      hsCDLastDirection    = direction;
      hsCDLastSignalBarIdx = currentBarIdx;

      // === DISEGNO MARKER STORICI ===
      bool isBuy = (direction > 0);
      color clr = GetSignalArrowColor(isBuy, quality);
      string patternName = (quality >= PATTERN_TBS) ? "TBS" : "TWS";
      string timeStr = TimeToString(barTime, TIME_DATE|TIME_MINUTES);
      // bandPrice: la banda toccata (Primary o Half)
      double bandPrice;
      if(isBuy)
         bandPrice = (bullQuality == 2) ? lower : lowerHalf;
      else
         bandPrice = (bearQuality == 2) ? upper : upperHalf;

      // ATR per offset verticale della freccia
      double atrPrice = (atrI > 0) ? atrI : 0;
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
            "DIAG Arrow #%d: %s %s @ bar=%d | band=%.5f | sqz=%d | atr=%.5f",
            signalCount + 1, patternName, isBuy ? "BUY" : "SELL", i,
            bandPrice, hsSqueezeBarsCount, atrPrice));

      signalCount++;
   }

   // Log con conteggio segnali trovati e breakdown per-filtro
   AdLogI(LOG_CAT_UI, StringFormat(
      "ScanHist: depth=%d | base=%d | blocked: er=%d sqz=%d width=%d fire=%d time=%d cd=%d tws=%d | PASSED=%d",
      depth, baseDetected, erBlocked, sqzBlocked, widthBlocked,
      fireBlocked, timeBlocked, cdBlocked, twsBlocked, signalCount));
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
