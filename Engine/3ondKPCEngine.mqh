//+------------------------------------------------------------------+
//|                                         3ondKPCEngine.mqh          |
//|           TerzaOnda EA — KPC Engine Orchestrator                 |
//|                                                                  |
//|  Implements the 3 contract functions from adEngineInterface.mqh: |
//|    EngineInit()      — Create handles, init state                |
//|    EngineDeinit()    — Release handles, cleanup                  |
//|    EngineCalculate() — Read bar[1], populate EngineSignal         |
//|                                                                  |
//|  Calls sub-modules:                                              |
//|    3ondKPCPresets  — TF auto-preset                                |
//|    3ondKPCBands    — KAMA + KC band calculation                    |
//|    3ondKPCFilters  — 7 quality filters + squeeze/fire              |
//|    3ondKPCCooldown — SimpleCooldown                                |
//|    3ondKPCLTFEntry — LTF entry confirmation                        |
//+------------------------------------------------------------------+
#property copyright "TerzaOnda (C) 2026"

//+------------------------------------------------------------------+
//| KPC Engine State Variables                                       |
//+------------------------------------------------------------------+
datetime g_kpcLastProcessedBuyBar  = 0;
datetime g_kpcLastProcessedSellBar = 0;
int      g_kpcTimeBlockStartMin    = 0;
int      g_kpcTimeBlockEndMin      = 0;

//+------------------------------------------------------------------+
//| EngineInit — Contract function 1/3                               |
//+------------------------------------------------------------------+
bool EngineInit()
{
   // NOTE: KPCPresetsInit() è già invocata dal main (TerzaOnda.mq5) PRIMA di InitializeATR,
   // perché ATR handle creation necessita g_kpc_atrPeriod_eff. Non la richiamiamo qui
   // per evitare doppia esecuzione (idempotente ma inutile overhead).

   // v1.6.1: Avviso loop LTF su M1
   if(Period() == PERIOD_M1 && g_kpc_useLTFEntry)
      AdLogW(LOG_CAT_ENGINE, "AVVISO: LTF Entry=true su M1 — disabilitare (LTF mapping M1->M1 = loop)");

   // 2. Create handles (KPC: no engine-specific handles needed)
   if(!KPCCreateHandles())
   {
      AdLogE(LOG_CAT_ENGINE, "CRITICAL: Failed to create KPC handles!");
      return false;
   }

   // 3. Parse time filter
   if(InpKPC_UseTimeFilter)
   {
      g_kpcTimeBlockStartMin = ParseTimeToMinutes(InpKPC_TimeBlockStart);
      g_kpcTimeBlockEndMin   = ParseTimeToMinutes(InpKPC_TimeBlockEnd);

      AdLogI(LOG_CAT_ENGINE, StringFormat("Time Filter: %02d:%02d - %02d:%02d (server)",
               g_kpcTimeBlockStartMin / 60, g_kpcTimeBlockStartMin % 60,
               g_kpcTimeBlockEndMin / 60, g_kpcTimeBlockEndMin % 60));
   }

   // 4. Reset state
   KPCResetBands();
   KPCFiltersInit();
   KPCResetCooldown();
   KPCResetLTF();
   g_kpcLastProcessedBuyBar  = 0;
   g_kpcLastProcessedSellBar = 0;
   g_lastSignal.Reset();

   // 5. Seed KAMA with initial bars (process bars from oldest to newest)
   int totalBars = iBars(_Symbol, PERIOD_CURRENT);
   int seedBars = g_kpc_kamaPeriod_eff + 20;
   if(totalBars > seedBars)
   {
      for(int i = seedBars; i >= 1; i--)
      {
         double er;
         KPCComputeKAMA(i, er);
      }
   }

   // 6. Validate first read
   if(g_kpcKAMA > 0 && g_kpcLastATR == 0)
   {
      // ATR not yet available, compute bands anyway for validation
      KPCComputeBands(1);
   }
   else if(totalBars > seedBars)
   {
      KPCComputeBands(1);
   }

   if(g_kpcKAMA > 0)
   {
      AdLogI(LOG_CAT_ENGINE, StringFormat("KPC ENGINE READY — KAMA:%s | Upper:%s | Lower:%s | Width:%.1fp",
              DoubleToString(g_kpcKAMA, _Digits),
              DoubleToString(g_kpcLastUpper, _Digits),
              DoubleToString(g_kpcLastLower, _Digits),
              PointsToPips(g_kpcLastUpper - g_kpcLastLower)));
   }
   else
   {
      AdLogW(LOG_CAT_ENGINE, "Engine handles ready but data not yet available (normal on first load)");
   }

   // Log configuration
   AdLogI(LOG_CAT_ENGINE, StringFormat("Params: KAMA_ER=%d ATR=%d Mult=%.1f Half=%.1f",
            g_kpc_kamaPeriod_eff, g_kpc_atrPeriod_eff, g_kpc_multiplier_eff, g_kpc_halfMultiplier_eff));
   AdLogI(LOG_CAT_ENGINE, StringFormat("Cooldown: Same=%d Opp=%d | WickRatio=%.2f",
            g_kpc_nSameBars_eff, g_kpc_nOppositeBars_eff, InpKPC_WickRatio));
   AdLogI(LOG_CAT_ENGINE, StringFormat("Filters: F1_ER=%.2f F2_Squeeze=%d F4_Fire=%d F6_Width=%.1f",
            g_kpc_erTrending_eff, g_kpc_minSqueezeBars_eff, g_kpc_fireCooldown_eff, g_kpc_minWidthPips_eff));
   AdLogI(LOG_CAT_ENGINE, StringFormat("LTF Entry=%s (OnlyPrimary=%s) | TriggerMode=%s",
            g_kpc_useLTFEntry ? "ON" : "OFF", g_kpc_ltfOnlyTBS ? "YES" : "NO",
            EnumToString(InpKPC_TriggerMode)));

   Log_InitComplete("KPC Engine");
   return true;
}

//+------------------------------------------------------------------+
//| EngineDeinit — Contract function 2/3                             |
//+------------------------------------------------------------------+
void EngineDeinit()
{
   KPCReleaseHandles();
   KPCResetCooldown();
   KPCResetLTF();
   KPCResetSqueezeState();
   AdLogI(LOG_CAT_ENGINE, "KPC Engine deinitialized");
}

//+------------------------------------------------------------------+
//| EngineCalculate — Contract function 3/3                          |
//|                                                                  |
//|  Pipeline (every new bar, bar[1] confirmed):                     |
//|    1. Update KAMA + KC bands for bar[1]                          |
//|    2. Update squeeze/fire state                                  |
//|    3. Signal detection: band touch + wick rejection               |
//|    4. 7 quality filters (F1-F7)                                  |
//|    5. SimpleCooldown check                                       |
//|    6. Classify signal (Primary/Half -> TBS/TWS)                  |
//|    7. Entry/TP/SL price calculation                              |
//|    8. Populate EngineSignal                                      |
//|    9. LTF entry (if enabled)                                     |
//|   10. Anti-repaint guard                                         |
//+------------------------------------------------------------------+
bool EngineCalculate(EngineSignal &sig)
{
   sig.Reset();

   int totalBars = iBars(_Symbol, PERIOD_CURRENT);
   if(totalBars < g_kpc_kamaPeriod_eff + 25) return false;

   // === 1. COMPUTE KAMA + KC BANDS for bar[1] ===
   KPCComputeBands(1);

   double upper1 = g_kpcLastUpper;
   double lower1 = g_kpcLastLower;
   double kama1  = g_kpcKAMA;
   double atr1   = g_kpcLastATR;
   double er1    = g_kpcLastER;

   if(upper1 <= 0 || lower1 <= 0 || kama1 <= 0) return false;

   // === 2. UPDATE SQUEEZE/FIRE STATE ===
   KPCUpdateSqueezeState(1);

   // === Populate band data in signal (always, for dashboard) ===
   sig.upperBand      = upper1;
   sig.lowerBand      = lower1;
   sig.midline        = kama1;
   sig.channelWidthPip = PointsToPips(upper1 - lower1);
   sig.barTime        = iTime(_Symbol, PERIOD_CURRENT, 1);

   // === Populate extra values for dashboard ===
   sig.extraCount = 10;
   sig.extraLabels[0] = "ATR";         sig.extraValues[0] = atr1;
   sig.extraLabels[1] = "EMA ATR";     sig.extraValues[1] = g_kpcEmaATR;
   sig.extraLabels[2] = "ER";          sig.extraValues[2] = er1;
   sig.extraLabels[3] = "KAMA Dir";    sig.extraValues[3] = (double)KPCGetMidlineColorState(1);
   sig.extraLabels[4] = "Squeeze";     sig.extraValues[4] = (double)g_kpcSqueezeBarsCount;
   sig.extraLabels[5] = "Fire";        sig.extraValues[5] = g_kpcFireActive ? 1.0 : 0.0;
   sig.extraLabels[6] = "DCW";         sig.extraValues[6] = g_kpcLastDCW;
   sig.extraLabels[7] = "WPR";         sig.extraValues[7] = g_kpcLastWPR;
   sig.extraLabels[8] = "Mult";        sig.extraValues[8] = g_kpc_multiplier_eff;
   sig.extraLabels[9] = "MinWidth";    sig.extraValues[9] = g_kpc_minWidthPips_eff;

   if(g_kpc_useLTFEntry)
   {
      sig.extraLabels[10] = "LTF";
      sig.extraValues[10] = g_kpcLtfWindowOpen ? 1.0 : 0.0;
      sig.extraCount = 11;
   }

   // === 3. SIGNAL DETECTION on bar[1] ===
   double high1  = iHigh(_Symbol, PERIOD_CURRENT, 1);
   double low1   = iLow(_Symbol, PERIOD_CURRENT, 1);
   double open1  = iOpen(_Symbol, PERIOD_CURRENT, 1);
   double close1 = iClose(_Symbol, PERIOD_CURRENT, 1);

   int currentBarIdx = totalBars - 2;  // bar[1] index

   bool bearBase = false;
   bool bullBase = false;
   int  bearQuality = 0;
   int  bullQuality = 0;

   // Band touch + close inside (rejection confirmed) + wick ratio
   if(InpKPC_TriggerMode == TRIGGER_BAR_CLOSE)
   {
      double upperHalf1 = g_kpcLastUpperHalf;
      double lowerHalf1 = g_kpcLastLowerHalf;

      bool touchUpperPrimary = (high1 > upper1) && (close1 < upper1);
      bool touchUpperHalf    = (high1 > upperHalf1) && (close1 < upperHalf1) && (high1 <= upper1);
      bool touchLowerPrimary = (low1 < lower1) && (close1 > lower1);
      bool touchLowerHalf    = (low1 < lowerHalf1) && (close1 > lowerHalf1) && (low1 >= lower1);

      double upperWick  = high1 - MathMax(open1, close1);
      double lowerWick  = MathMin(open1, close1) - low1;
      double candleSize = high1 - low1;
      bool wickOK = (candleSize > _Point * 2);

      double wickRatioUpper = wickOK ? upperWick / candleSize : 0;
      double wickRatioLower = wickOK ? lowerWick / candleSize : 0;

      bearBase = (touchUpperPrimary || touchUpperHalf) && (wickRatioUpper >= InpKPC_WickRatio);
      bullBase = (touchLowerPrimary || touchLowerHalf) && (wickRatioLower >= InpKPC_WickRatio);
      bearQuality = touchUpperPrimary ? 2 : 1;
      bullQuality = touchLowerPrimary ? 2 : 1;
   }

   // Anti-ambiguity
   if(bearBase && bullBase) { bearBase = false; bullBase = false; }

   // === DIAG ===
   bool origBear = bearBase;
   bool origBull = bullBase;
   string rejectedBy = "";

   if(bearBase || bullBase)
   {
      AdLogD(LOG_CAT_ENGINE, StringFormat("KPC BASE SIGNAL: %s | H=%s L=%s C=%s | Upper=%s Lower=%s KAMA=%s",
             bearBase ? "SELL" : "BUY",
             DoubleToString(high1, _Digits), DoubleToString(low1, _Digits), DoubleToString(close1, _Digits),
             DoubleToString(upper1, _Digits), DoubleToString(lower1, _Digits), DoubleToString(kama1, _Digits)));
   }

   // === 4. QUALITY FILTERS (7 filters) ===
   sig.filterCount = 0;

   // --- F1: ER Regime ---
   bool f1Pass = KPCCheckF1_ERRegime(er1);
   if(!f1Pass && (bearBase || bullBase))
   {
      rejectedBy += "F1_ER ";
      bearBase = false; bullBase = false;
   }
   sig.filterNames[sig.filterCount] = "ER";
   sig.filterStates[sig.filterCount] = f1Pass ? 1 : -1;
   sig.filterCount++;

   // --- F2: Squeeze Duration ---
   bool f2Pass = KPCCheckF2_Squeeze();
   if(!f2Pass && (bearBase || bullBase))
   {
      rejectedBy += "F2_Squeeze ";
      bearBase = false; bullBase = false;
   }
   sig.filterNames[sig.filterCount] = "Sqz";
   sig.filterStates[sig.filterCount] = f2Pass ? 1 : -1;
   sig.filterCount++;

   // --- F3: DCW Slope (OFF default) ---
   bool f3Pass = KPCCheckF3_DCWSlope();
   sig.filterNames[sig.filterCount] = "DCW";
   sig.filterStates[sig.filterCount] = 0;  // OFF default
   sig.filterCount++;

   // --- F4: Fire Kill Switch ---
   bool f4Pass = KPCCheckF4_Fire();
   if(!f4Pass && (bearBase || bullBase))
   {
      rejectedBy += "F4_Fire ";
      bearBase = false; bullBase = false;
   }
   sig.filterNames[sig.filterCount] = "Fire";
   sig.filterStates[sig.filterCount] = f4Pass ? 1 : -1;
   sig.filterCount++;

   // --- F5: Williams %R (OFF default) ---
   sig.filterNames[sig.filterCount] = "WPR";
   sig.filterStates[sig.filterCount] = 0;  // OFF default
   sig.filterCount++;

   // --- F6: Width ---
   bool f6Pass = true;
   if(InpKPC_UseWidthFilter)
   {
      f6Pass = KPCCheckF6_Width(upper1, lower1);
      if(!f6Pass && (bearBase || bullBase))
      {
         rejectedBy += "F6_Width ";
         bearBase = false; bullBase = false;
      }
   }
   sig.filterNames[sig.filterCount] = "Width";
   sig.filterStates[sig.filterCount] = InpKPC_UseWidthFilter ? (f6Pass ? 1 : -1) : 0;
   sig.filterCount++;

   // --- F7: Time Filter ---
   bool f7Pass = true;
   if(InpKPC_UseTimeFilter)
   {
      f7Pass = KPCCheckF7_Time(g_kpcTimeBlockStartMin, g_kpcTimeBlockEndMin);
      if(!f7Pass && (bearBase || bullBase))
      {
         rejectedBy += "F7_Time ";
         bearBase = false; bullBase = false;
      }
   }
   sig.filterNames[sig.filterCount] = "Time";
   sig.filterStates[sig.filterCount] = InpKPC_UseTimeFilter ? (f7Pass ? 1 : -1) : 0;
   sig.filterCount++;

   // === 5. SIMPLECOOLDOWN ===
   bool bearCooldownOK = KPCCheckCooldown_Sell(currentBarIdx);
   bool bullCooldownOK = KPCCheckCooldown_Buy(currentBarIdx);

   bool bearCond = bearBase && bearCooldownOK;
   bool bullCond = bullBase && bullCooldownOK;

   if(bearBase && !bearCooldownOK) rejectedBy += "Cooldown ";
   if(bullBase && !bullCooldownOK) rejectedBy += "Cooldown ";

   // === Determine regime ===
   sig.isFlat = (er1 < g_kpc_erTrending_eff);

   // === No signal ===
   if(!bearCond && !bullCond)
   {
      if(origBear || origBull)
      {
         AdLogD(LOG_CAT_ENGINE, StringFormat("KPC SIGNAL REJECTED: %s | BLOCKED BY: %s",
                origBear ? "SELL" : "BUY", rejectedBy));
      }

      // Check LTF window
      if(g_kpc_useLTFEntry && g_kpcLtfWindowOpen)
         sig.ltfConfirm = KPCLTFCheckConfirmation();
      return true;
   }

   // === 6. CLASSIFY SIGNAL (Primary/Half -> TBS/TWS) ===
   int direction = bullCond ? +1 : -1;
   int quality = KPCClassifySignal(direction, open1, close1,
                                    upper1, lower1,
                                    g_kpcLastUpperHalf, g_kpcLastLowerHalf);

   // Map Half quality: Primary touch -> TBS (3), Half only -> TWS (1)
   if(direction == -1)
      quality = (bearQuality == 2) ? PATTERN_TBS : PATTERN_TWS;
   else
      quality = (bullQuality == 2) ? PATTERN_TBS : PATTERN_TWS;

   // Skip Half signals if disabled
   if(!InpKPC_ShowHalfSignals && quality == PATTERN_TWS)
      return true;

   // === 7. ANTI-REPAINT GUARD ===
   datetime bar1Time = iTime(_Symbol, PERIOD_CURRENT, 1);
   bool isNew = false;

   if(direction == -1 && bar1Time != g_kpcLastProcessedSellBar)
   {
      isNew = true;
      g_kpcLastProcessedSellBar = bar1Time;
   }
   else if(direction == +1 && bar1Time != g_kpcLastProcessedBuyBar)
   {
      isNew = true;
      g_kpcLastProcessedBuyBar = bar1Time;
   }

   if(!isNew) return true;

   // Update cooldown after anti-repaint confirmation
   KPCUpdateCooldownState(direction, currentBarIdx);

   // === 8. POPULATE SIGNAL ===
   sig.direction   = direction;
   sig.quality     = quality;
   sig.isNewSignal = true;

   // Band level (the band that was touched)
   if(direction > 0)
      sig.bandLevel = (bullQuality == 2) ? lower1 : g_kpcLastLowerHalf;
   else
      sig.bandLevel = (bearQuality == 2) ? upper1 : g_kpcLastUpperHalf;

   // Entry price
   double triggerOffset = PipsToPrice(g_inst_stopOffset);
   if(direction > 0)
      sig.entryPrice = sig.bandLevel + triggerOffset;
   else
      sig.entryPrice = sig.bandLevel - triggerOffset;

   // SL disabled (same as DPC v1.7.3)
   sig.slPrice = 0;

   // TP price (depends on TPMode — KAMA replaces Donchian midline)
   if(TPMode == TP_MIDLINE)
   {
      sig.tpPrice = kama1;  // KAMA midline = mean reversion target
   }
   else if(TPMode == TP_OPPOSITE_BAND)
   {
      sig.tpPrice = (direction > 0) ? upper1 : lower1;
   }
   else if(TPMode == TP_150_PERCENT)
   {
      if(direction > 0)
         sig.tpPrice = (kama1 + upper1) * 0.5;
      else
         sig.tpPrice = (kama1 + lower1) * 0.5;
   }
   else if(TPMode == TP_ATR_MULTIPLE && atr1 > 0)
   {
      double tpDist = TPValue * atr1;
      sig.tpPrice = (direction > 0) ? sig.entryPrice + tpDist : sig.entryPrice - tpDist;
   }
   else if(TPMode == TP_FIXED_PIPS)
   {
      double tpDist = PipsToPrice(TPValue);
      sig.tpPrice = (direction > 0) ? sig.entryPrice + tpDist : sig.entryPrice - tpDist;
   }

   // === 9. LTF ENTRY ===
   sig.ltfConfirm = 0;
   if(g_kpc_useLTFEntry && KPCLTFShouldFilter(quality))
      KPCLTFOpenWindow(direction, sig.bandLevel, iTime(_Symbol, PERIOD_CURRENT, 0));

   // === LOG ===
   string patternName = (quality == PATTERN_TBS) ? "TBS(Primary)" : "TWS(Half)";
   AdLogI(LOG_CAT_ENGINE, StringFormat("=== NEW %s %s SIGNAL === Entry=%s TP=%s Width=%.1fp ER=%.3f Sqz=%d",
          direction > 0 ? "BUY" : "SELL", patternName,
          DoubleToString(sig.entryPrice, _Digits),
          DoubleToString(sig.tpPrice, _Digits),
          sig.channelWidthPip, er1, g_kpcSqueezeBarsCount));

   return true;
}
