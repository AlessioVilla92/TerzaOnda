//+------------------------------------------------------------------+
//|                                          adDPCEngine.mqh         |
//|           AcquaDulza EA v1.0.0 — DPC Engine Orchestrator         |
//|                                                                  |
//|  Implements the 3 contract functions from adEngineInterface.mqh: |
//|    EngineInit()      — Create handles, init state                |
//|    EngineDeinit()    — Release handles, cleanup                  |
//|    EngineCalculate() — Read bar[1], populate EngineSignal         |
//|                                                                  |
//|  Calls sub-modules:                                              |
//|    adDPCPresets  — TF auto-preset                                |
//|    adDPCBands    — Band calculation, ATR, MA                     |
//|    adDPCFilters  — Quality filters                               |
//|    adDPCCooldown — SmartCooldown state machine                   |
//|    adDPCLTFEntry — LTF entry confirmation                        |
//+------------------------------------------------------------------+
#property copyright "AcquaDulza (C) 2026"

//+------------------------------------------------------------------+
//| DPC Engine State Variables                                       |
//+------------------------------------------------------------------+
datetime g_dpcLastProcessedBuyBar  = 0;
datetime g_dpcLastProcessedSellBar = 0;
int      g_dpcTimeBlockStartMin    = 0;
int      g_dpcTimeBlockEndMin      = 0;

//+------------------------------------------------------------------+
//| EngineInit — Contract function 1/3                               |
//|  1. Apply TF auto-preset                                        |
//|  2. Create indicator handles (ATR, MA)                           |
//|  3. Parse time filter                                            |
//|  4. Reset cooldown + LTF state                                   |
//|  5. Validate initial bands on bar[1]                             |
//+------------------------------------------------------------------+
bool EngineInit()
{
   // 1. Apply TF preset (sets g_dpc_dcLen, g_dpc_maLen, etc.)
   DPCPresetsInit();

   // 2. Create handles
   if(!DPCCreateHandles())
   {
      AdLogE(LOG_CAT_DPC, "CRITICAL: Failed to create DPC handles!");
      return false;
   }

   // 3. Parse time filter
   if(InpUseTimeFilter)
   {
      g_dpcTimeBlockStartMin = ParseTimeToMinutes(InpTimeBlockStart);
      g_dpcTimeBlockEndMin   = ParseTimeToMinutes(InpTimeBlockEnd);

      AdLogI(LOG_CAT_DPC, StringFormat("Time Filter: %02d:%02d - %02d:%02d (server)",
               g_dpcTimeBlockStartMin / 60, g_dpcTimeBlockStartMin % 60,
               g_dpcTimeBlockEndMin / 60, g_dpcTimeBlockEndMin % 60));
   }

   // 4. Reset state
   DPCResetCooldown();
   DPCResetLTF();
   g_dpcLastProcessedBuyBar  = 0;
   g_dpcLastProcessedSellBar = 0;

   // 5. Validate first read
   double testU, testL, testM;
   DPCComputeBands(1, g_dpc_dcLen, testU, testL, testM);

   if(testU > 0 && testL > 0 && testM > 0)
   {
      AdLogI(LOG_CAT_DPC, StringFormat("DPC ENGINE READY — Upper:%s | Lower:%s | Mid:%s | Width:%.1fp",
              DoubleToString(testU, _Digits), DoubleToString(testL, _Digits),
              DoubleToString(testM, _Digits), PointsToPips(testU - testL)));
   }
   else
   {
      AdLogW(LOG_CAT_DPC, "Engine handles ready but data not yet available (normal on first load)");
   }

   // Log configuration
   AdLogI(LOG_CAT_DPC, StringFormat("Params: Period=%d MAType=%s MALen=%d",
            g_dpc_dcLen, EnumToString(InpMAType), g_dpc_maLen));
   AdLogI(LOG_CAT_DPC, StringFormat("SmartCooldown=%s MidTouch=%s SameDir=%d OppDir=%d",
            InpUseSmartCooldown ? "ON" : "OFF", InpRequireMidTouch ? "YES" : "NO",
            g_dpc_nSame, g_dpc_nOpp));
   AdLogI(LOG_CAT_DPC, StringFormat("Filters: Flatness=%s Trend=%s LevelAge=%s Width=%s Time=%s",
            InpUseBandFlatness ? "ON" : "OFF", InpUseTrendContext ? "ON" : "OFF",
            InpUseLevelAge ? "ON" : "OFF", InpUseWidthFilter ? "ON" : "OFF",
            InpUseTimeFilter ? "ON" : "OFF"));
   AdLogI(LOG_CAT_DPC, StringFormat("LTF Entry=%s (OnlyTBS=%s) | TriggerMode=%s",
            InpUseLTFEntry ? "ON" : "OFF", InpLTFOnlyTBS ? "YES" : "NO",
            EnumToString(InpTriggerMode)));

   Log_InitComplete("DPC Engine");
   return true;
}

//+------------------------------------------------------------------+
//| EngineDeinit — Contract function 2/3                             |
//+------------------------------------------------------------------+
void EngineDeinit()
{
   DPCReleaseHandles();
   DPCResetCooldown();
   DPCResetLTF();
   AdLogI(LOG_CAT_DPC, "DPC Engine deinitialized");
}

//+------------------------------------------------------------------+
//| EngineCalculate — Contract function 3/3                          |
//|                                                                  |
//|  Pipeline (every new bar, bar[1] confirmed):                     |
//|    1. Compute Donchian bands                                     |
//|    2. Compute ATR + EMA ATR                                      |
//|    3. Compute MA                                                 |
//|    4. Check midline touch (SmartCooldown state)                  |
//|    5. Signal detection: bearBase/bullBase                        |
//|    6. Quality filters (6 filters)                                |
//|    7. SmartCooldown check                                        |
//|    8. Classify signal (TBS/TWS)                                  |
//|    9. Entry/SL/TP price calculation                              |
//|   10. Populate EngineSignal                                      |
//|   11. LTF entry (if enabled)                                     |
//|   12. Anti-repaint guard                                         |
//|                                                                  |
//|  Returns: true if signal populated (direction != 0)              |
//+------------------------------------------------------------------+
bool EngineCalculate(EngineSignal &sig)
{
   sig.Reset();

   int totalBars = iBars(_Symbol, PERIOD_CURRENT);
   if(totalBars < g_dpc_dcLen + 5) return false;

   // === 1. COMPUTE DONCHIAN BANDS for bar[1] ===
   double upper1, lower1, mid1;
   DPCComputeBands(1, g_dpc_dcLen, upper1, lower1, mid1);

   if(upper1 <= 0 || lower1 <= 0 || mid1 <= 0) return false;

   // === 2. ATR + EMA ATR ===
   double atr1 = DPCGetATR(1);
   if(atr1 > 0)
      DPCUpdateEmaATR(atr1);

   // === 3. MA ===
   double ma1 = (InpMAFilterMode != MA_FILTER_DISABLED) ? DPCGetMAValue(1) : 0;

   // === Populate band data in signal (always, for dashboard) ===
   sig.upperBand      = upper1;
   sig.lowerBand      = lower1;
   sig.midline        = mid1;
   sig.channelWidthPip = PointsToPips(upper1 - lower1);
   sig.barTime        = iTime(_Symbol, PERIOD_CURRENT, 1);

   // === Populate extra values for dashboard ===
   sig.extraCount = 4;
   sig.extraLabels[0] = "ATR";        sig.extraValues[0] = atr1;
   sig.extraLabels[1] = "EMA ATR";    sig.extraValues[1] = g_dpcEmaATR;
   sig.extraLabels[2] = "MA";         sig.extraValues[2] = ma1;
   sig.extraLabels[3] = "Mid Color";  sig.extraValues[3] = (double)DPCGetMidlineColor(1);

   if(InpUseLTFEntry)
   {
      sig.extraLabels[4] = "LTF";
      sig.extraValues[4] = g_ltfWindowOpen ? 1.0 : 0.0;
   }

   // === Engine config values for dashboard (engine-specific) ===
   sig.extraLabels[5] = "Period";     sig.extraValues[5] = (double)g_dpc_dcLen;
   sig.extraLabels[6] = "MA Len";    sig.extraValues[6] = (double)g_dpc_maLen;
   sig.extraLabels[7] = "MinWidth";  sig.extraValues[7] = g_dpc_minWidth;
   sig.extraLabels[8] = "CD Same";   sig.extraValues[8] = (double)g_dpc_nSame;
   sig.extraLabels[9] = "CD Opp";    sig.extraValues[9] = (double)g_dpc_nOpp;
   sig.extraCount = 10;

   // === 4. CHECK MIDLINE TOUCH (SmartCooldown) ===
   int currentBarIdx = totalBars - 2;  // bar[1] index
   DPCCheckMidlineTouch(1, currentBarIdx, mid1);

   // === 5. SIGNAL DETECTION on bar[1] ===
   double high1  = iHigh(_Symbol, PERIOD_CURRENT, 1);
   double low1   = iLow(_Symbol, PERIOD_CURRENT, 1);
   double open1  = iOpen(_Symbol, PERIOD_CURRENT, 1);
   double close1 = iClose(_Symbol, PERIOD_CURRENT, 1);

   bool bearBase = (high1 >= upper1);   // Price touches upper -> SELL candidate
   bool bullBase = (low1 <= lower1);    // Price touches lower -> BUY candidate

   // Anti-ambiguity: both bands touched simultaneously
   if(bearBase && bullBase)
   {
      bearBase = false;
      bullBase = false;
   }

   // === 6. QUALITY FILTERS ===

   // Register filter states for dashboard
   sig.filterCount = 0;

   // --- Filter 1: Band Flatness ---
   bool flatPass_sell = true, flatPass_buy = true;
   if(InpUseBandFlatness && atr1 > 0)
   {
      if(bearBase) flatPass_sell = DPCCheckFlatness_Sell(1, atr1);
      if(bullBase) flatPass_buy  = DPCCheckFlatness_Buy(1, atr1);
      if(bearBase && !flatPass_sell) bearBase = false;
      if(bullBase && !flatPass_buy)  bullBase = false;
   }
   sig.filterNames[sig.filterCount]  = "Flat";
   sig.filterStates[sig.filterCount] = InpUseBandFlatness ? ((flatPass_sell || flatPass_buy) ? 1 : -1) : 0;
   sig.filterCount++;

   // --- Filter 2: Trend Context ---
   bool trendPass_sell = true, trendPass_buy = true;
   if(InpUseTrendContext && atr1 > 0)
   {
      if(bearBase) trendPass_sell = DPCCheckTrendContext_Sell(1, atr1);
      if(bullBase) trendPass_buy  = DPCCheckTrendContext_Buy(1, atr1);
      if(bearBase && !trendPass_sell) bearBase = false;
      if(bullBase && !trendPass_buy)  bullBase = false;
   }
   sig.filterNames[sig.filterCount]  = "Trend";
   sig.filterStates[sig.filterCount] = InpUseTrendContext ? ((trendPass_sell || trendPass_buy) ? 1 : -1) : 0;
   sig.filterCount++;

   // --- Filter 3: Level Age ---
   bool agePass_sell = true, agePass_buy = true;
   if(InpUseLevelAge)
   {
      if(bearBase) agePass_sell = DPCCheckLevelAge_Sell(1);
      if(bullBase) agePass_buy  = DPCCheckLevelAge_Buy(1);
      if(bearBase && !agePass_sell) bearBase = false;
      if(bullBase && !agePass_buy)  bullBase = false;
   }
   sig.filterNames[sig.filterCount]  = "Age";
   sig.filterStates[sig.filterCount] = InpUseLevelAge ? ((agePass_sell || agePass_buy) ? 1 : -1) : 0;
   sig.filterCount++;

   // --- Filter 4: Channel Width ---
   bool widthPass = true;
   if(InpUseWidthFilter)
   {
      widthPass = DPCCheckChannelWidth(upper1, lower1);
      if(!widthPass)
      {
         bearBase = false;
         bullBase = false;
      }
   }
   sig.filterNames[sig.filterCount]  = "Width";
   sig.filterStates[sig.filterCount] = InpUseWidthFilter ? (widthPass ? 1 : -1) : 0;
   sig.filterCount++;

   // --- Filter 5: Time Filter ---
   bool timePass = true;
   if(InpUseTimeFilter)
   {
      timePass = !IsInBlockedTime(g_dpcTimeBlockStartMin, g_dpcTimeBlockEndMin);
      if(!timePass)
      {
         bearBase = false;
         bullBase = false;
      }
   }
   sig.filterNames[sig.filterCount]  = "Time";
   sig.filterStates[sig.filterCount] = InpUseTimeFilter ? (timePass ? 1 : -1) : 0;
   sig.filterCount++;

   // --- Filter 6: MA Filter ---
   bool maPass_sell = true, maPass_buy = true;
   if(InpMAFilterMode != MA_FILTER_DISABLED && ma1 > 0)
   {
      if(bearBase) maPass_sell = DPCCheckMAFilter(close1, ma1, -1);
      if(bullBase) maPass_buy  = DPCCheckMAFilter(close1, ma1, +1);
      if(bearBase && !maPass_sell) bearBase = false;
      if(bullBase && !maPass_buy)  bullBase = false;
   }
   sig.filterNames[sig.filterCount]  = "MA";
   sig.filterStates[sig.filterCount] = (InpMAFilterMode != MA_FILTER_DISABLED) ? ((bearBase || bullBase) ? 1 : -1) : 0;
   sig.filterCount++;

   // === 7. SMARTCOOLDOWN (filter 6/6: signal frequency) ===
   bool bearCooldownOK = DPCCheckSmartCooldown_Sell(currentBarIdx);
   bool bullCooldownOK = DPCCheckSmartCooldown_Buy(currentBarIdx);

   bool bearCond = bearBase && bearCooldownOK;
   bool bullCond = bullBase && bullCooldownOK;

   sig.filterNames[sig.filterCount]  = "CD";
   sig.filterStates[sig.filterCount] = InpUseSmartCooldown ?
      ((bearCond || bullCond) ? 1 : ((bearBase || bullBase) ? -1 : 0)) : 0;
   sig.filterCount++;

   // === Determine regime ===
   sig.isFlat = widthPass && (InpUseBandFlatness ? (flatPass_sell || flatPass_buy) : true);

   // === No signal ===
   if(!bearCond && !bullCond)
   {
      // Check LTF window if still open
      if(InpUseLTFEntry && g_ltfWindowOpen)
         sig.ltfConfirm = DPCLTFCheckConfirmation();
      return true;  // Return true (data populated) but direction=0
   }

   // === 8. CLASSIFY SIGNAL (TBS/TWS) ===
   int direction = bullCond ? +1 : -1;
   int quality   = DPCClassifySignal(direction, open1, close1, upper1, lower1);

   // Skip TWS signals if disabled
   if(!InpShowTWSSignals && quality == PATTERN_TWS)
      return true;  // Data populated but no signal emitted

   // === 9. ANTI-REPAINT GUARD ===
   datetime bar1Time = iTime(_Symbol, PERIOD_CURRENT, 1);
   bool isNew = false;

   if(direction == -1 && bar1Time != g_dpcLastProcessedSellBar)
   {
      isNew = true;
      g_dpcLastProcessedSellBar = bar1Time;
   }
   else if(direction == +1 && bar1Time != g_dpcLastProcessedBuyBar)
   {
      isNew = true;
      g_dpcLastProcessedBuyBar = bar1Time;
   }

   if(!isNew) return true;  // Duplicate blocked

   // === Update cooldown after anti-repaint confirmation ===
   DPCUpdateCooldownState(direction, currentBarIdx);

   // === 10. POPULATE SIGNAL ===
   sig.direction   = direction;
   sig.quality     = quality;
   sig.isNewSignal = true;

   // Band level (the band that was touched)
   sig.bandLevel = (direction > 0) ? lower1 : upper1;

   // Entry price (band +/- offset using StopOffsetPips)
   double triggerOffset = PipsToPrice(StopOffsetPips);
   if(direction > 0)
      sig.entryPrice = lower1 + triggerOffset;   // BUY STOP above lower band
   else
      sig.entryPrice = upper1 - triggerOffset;   // SELL STOP below upper band

   // SL price (depends on SLMode — computed by framework, but suggest band opposite)
   if(SLMode == SL_BAND_OPPOSITE)
   {
      if(direction > 0)
         sig.slPrice = upper1;   // BUY SL at upper band (opposite)
      else
         sig.slPrice = lower1;   // SELL SL at lower band (opposite)
   }
   else if(SLMode == SL_ATR_MULTIPLE && atr1 > 0)
   {
      double slDist = SLValue * atr1;
      if(direction > 0)
         sig.slPrice = sig.entryPrice - slDist;
      else
         sig.slPrice = sig.entryPrice + slDist;
   }
   else if(SLMode == SL_FIXED_PIPS)
   {
      double slDist = PipsToPrice(SLValue);
      if(direction > 0)
         sig.slPrice = sig.entryPrice - slDist;
      else
         sig.slPrice = sig.entryPrice + slDist;
   }

   // TP price (depends on TPMode)
   if(TPMode == TP_MIDLINE)
   {
      sig.tpPrice = mid1;
   }
   else if(TPMode == TP_ATR_MULTIPLE && atr1 > 0)
   {
      double tpDist = TPValue * atr1;
      if(direction > 0)
         sig.tpPrice = sig.entryPrice + tpDist;
      else
         sig.tpPrice = sig.entryPrice - tpDist;
   }
   else if(TPMode == TP_FIXED_PIPS)
   {
      double tpDist = PipsToPrice(TPValue);
      if(direction > 0)
         sig.tpPrice = sig.entryPrice + tpDist;
      else
         sig.tpPrice = sig.entryPrice - tpDist;
   }

   // === 11. LTF ENTRY ===
   sig.ltfConfirm = 0;
   if(InpUseLTFEntry && DPCLTFShouldFilter(quality))
   {
      // Open LTF window for this signal
      DPCLTFOpenWindow(direction, sig.bandLevel, iTime(_Symbol, PERIOD_CURRENT, 0));
   }

   // === LOG ===
   string patternName = (quality == PATTERN_TBS) ? "TBS" : ((quality == PATTERN_TWS) ? "TWS" : "???");
   AdLogI(LOG_CAT_DPC, StringFormat("=== NEW %s %s SIGNAL === Entry=%s SL=%s TP=%s Width=%.1fp",
          direction > 0 ? "BUY" : "SELL", patternName,
          DoubleToString(sig.entryPrice, _Digits),
          DoubleToString(sig.slPrice, _Digits),
          DoubleToString(sig.tpPrice, _Digits),
          sig.channelWidthPip));

   return true;
}
