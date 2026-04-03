//+------------------------------------------------------------------+
//|                                        adKPCFilters.mqh          |
//|           AcquaDulza EA — KPC Quality Filters                     |
//|                                                                  |
//|  7 filtri indipendenti + Squeeze/Fire state machine.              |
//|  Extracted from KeltnerPredictiveChannel.mq5 v1.09.              |
//|                                                                  |
//|  FILTRI ATTIVI (ON default):                                     |
//|    F1 ER Regime  — blocca trend estremi (ER > 0.60)              |
//|    F2 Squeeze    — richiede minima compressione (1-2 barre)      |
//|    F4 Fire       — blocco breakout rapido (2 barre cooldown)     |
//|    F6 Width      — canale min 10 pip = TP min ~5 pip             |
//|  FILTRI OFF default:                                             |
//|    F3 DCW Slope  — coperto da F2 decay + F4 spike                |
//|    F5 Williams%R — ~90% correlato con band touch + F1            |
//|    F7 Time Block — preferenza utente                             |
//+------------------------------------------------------------------+
#property copyright "AcquaDulza (C) 2026"

//+------------------------------------------------------------------+
//| Squeeze / Fire state variables                                   |
//+------------------------------------------------------------------+
int    g_kpcSqueezeBarsCount       = 0;
bool   g_kpcSqueezeWasActive       = false;
bool   g_kpcFireActive             = false;
int    g_kpcFireCooldownRemaining  = 0;

//--- DCW ring buffer for percentile
double g_kpcDcwRing[];
int    g_kpcDcwRingIdx    = 0;
bool   g_kpcDcwRingFilled = false;

//--- Last DCW values for fire detection
double g_kpcLastDCW     = 0;
double g_kpcPrevDCW     = 0;    // DCW[i+1]
double g_kpcPrev2DCW    = 0;    // DCW[i+2]

//--- Last WPR value
double g_kpcLastWPR     = 0;

//+------------------------------------------------------------------+
//| KPCFiltersInit — Allocate ring buffer, reset state               |
//+------------------------------------------------------------------+
void KPCFiltersInit()
{
   int dcwLookback = InpKPC_F2_DCWLookback;
   if(dcwLookback < 10) dcwLookback = 100;
   ArrayResize(g_kpcDcwRing, dcwLookback);
   ArrayInitialize(g_kpcDcwRing, 0);

   g_kpcDcwRingIdx    = 0;
   g_kpcDcwRingFilled = false;

   KPCResetSqueezeState();
}

//+------------------------------------------------------------------+
//| KPCResetSqueezeState — Reset squeeze/fire state                  |
//+------------------------------------------------------------------+
void KPCResetSqueezeState()
{
   g_kpcSqueezeBarsCount      = 0;
   g_kpcSqueezeWasActive      = false;
   g_kpcFireActive            = false;
   g_kpcFireCooldownRemaining = 0;
   g_kpcLastDCW               = 0;
   g_kpcPrevDCW               = 0;
   g_kpcPrev2DCW              = 0;
   g_kpcLastWPR               = 0;
}

//+------------------------------------------------------------------+
//| KPCCalcWPR — Williams %R for given bar                           |
//+------------------------------------------------------------------+
double KPCCalcWPR(int barShift)
{
   int period = g_kpc_wprPeriod_eff;
   int totalBars = iBars(_Symbol, PERIOD_CURRENT);
   if(barShift + period >= totalBars) return -50.0;

   double hh = iHigh(_Symbol, PERIOD_CURRENT, barShift);
   double ll = iLow(_Symbol, PERIOD_CURRENT, barShift);
   for(int k = 1; k < period; k++)
   {
      double h = iHigh(_Symbol, PERIOD_CURRENT, barShift + k);
      double l = iLow(_Symbol, PERIOD_CURRENT, barShift + k);
      if(h > hh) hh = h;
      if(l < ll) ll = l;
   }
   double range = hh - ll;
   double closeVal = iClose(_Symbol, PERIOD_CURRENT, barShift);
   return (range > 1e-10) ? (hh - closeVal) / range * (-100.0) : -50.0;
}

//+------------------------------------------------------------------+
//| KPCCalcATRSimple — Manual ATR for fast/slow ratio                |
//+------------------------------------------------------------------+
double KPCCalcATRSimple(int barShift, int period)
{
   int totalBars = iBars(_Symbol, PERIOD_CURRENT);
   if(barShift + period >= totalBars) return 0;

   double sum = 0;
   for(int k = 0; k < period; k++)
   {
      int idx = barShift + k;
      double h = iHigh(_Symbol, PERIOD_CURRENT, idx);
      double l = iLow(_Symbol, PERIOD_CURRENT, idx);
      double tr;
      if(idx + 1 < totalBars)
      {
         double prevClose = iClose(_Symbol, PERIOD_CURRENT, idx + 1);
         tr = MathMax(h - l, MathMax(MathAbs(h - prevClose), MathAbs(l - prevClose)));
      }
      else
         tr = h - l;
      sum += tr;
   }
   return sum / period;
}

//+------------------------------------------------------------------+
//| KPCUpdateSqueezeState — Update squeeze + fire detection          |
//|                                                                  |
//| Called once per new bar from EngineCalculate.                     |
//| Uses bar[1] data (KAMA, ATR, price) already computed.            |
//+------------------------------------------------------------------+
void KPCUpdateSqueezeState(int barShift)
{
   double atr = g_kpcLastATR;
   if(atr <= 0) return;

   int totalBars = iBars(_Symbol, PERIOD_CURRENT);

   // DCW (Donchian Channel Width / ATR — normalized volatility measure)
   double hh20 = iHigh(_Symbol, PERIOD_CURRENT, barShift);
   double ll20 = iLow(_Symbol, PERIOD_CURRENT, barShift);
   for(int k = 1; k < 20 && (barShift + k) < totalBars; k++)
   {
      double h = iHigh(_Symbol, PERIOD_CURRENT, barShift + k);
      double l = iLow(_Symbol, PERIOD_CURRENT, barShift + k);
      if(h > hh20) hh20 = h;
      if(l < ll20) ll20 = l;
   }
   double dcwRaw = hh20 - ll20;
   double dcw = dcwRaw / atr;

   // Shift DCW history
   g_kpcPrev2DCW = g_kpcPrevDCW;
   g_kpcPrevDCW  = g_kpcLastDCW;
   g_kpcLastDCW  = dcw;

   // Ring buffer for percentile
   int dcwLookback = ArraySize(g_kpcDcwRing);
   if(dcwLookback > 0)
   {
      g_kpcDcwRing[g_kpcDcwRingIdx] = dcw;
      g_kpcDcwRingIdx++;
      if(g_kpcDcwRingIdx >= dcwLookback)
      {
         g_kpcDcwRingIdx = 0;
         g_kpcDcwRingFilled = true;
      }
   }

   // Calculate percentile
   int ringCount = g_kpcDcwRingFilled ? dcwLookback : g_kpcDcwRingIdx;
   double dcwPercentile = 0.5;
   if(ringCount > 0)
   {
      int countBelow = 0;
      for(int r = 0; r < ringCount; r++)
         if(g_kpcDcwRing[r] < dcw) countBelow++;
      dcwPercentile = (double)countBelow / (double)ringCount;
   }

   // ATR fast/slow ratio
   double atrFast = KPCCalcATRSimple(barShift, 5);
   double atrSlow = KPCCalcATRSimple(barShift, 20);
   double atrRatio = (atrSlow > 1e-10) ? atrFast / atrSlow : 1.0;

   // Squeeze detection
   bool squeezeNow = (dcwPercentile < (double)g_kpc_dcwPercentile_eff / 100.0) &&
                     (!InpKPC_F2_UseATRRatio || atrRatio < g_kpc_atrRatioThresh_eff);

   // Decay graduale (non hard reset)
   if(squeezeNow)
      g_kpcSqueezeBarsCount++;
   else if(g_kpcSqueezeBarsCount > 0)
      g_kpcSqueezeBarsCount--;

   // Track squeeze was active
   if(g_kpcSqueezeBarsCount >= 3)
      g_kpcSqueezeWasActive = true;

   // Fire detection
   KPCCheckFire();

   // WPR
   g_kpcLastWPR = KPCCalcWPR(barShift);
}

//+------------------------------------------------------------------+
//| KPCCheckFire — Detect post-squeeze volatility explosion          |
//+------------------------------------------------------------------+
void KPCCheckFire()
{
   if(!g_kpcSqueezeWasActive) return;

   bool fireNow = (g_kpcLastDCW > g_kpc_fireDCWThresh_eff) &&
                  ((g_kpcPrevDCW > 0 && g_kpcLastDCW > g_kpcPrevDCW * 1.20) ||
                   (g_kpcPrev2DCW > 0 && g_kpcLastDCW > g_kpcPrev2DCW * 1.15));

   if(fireNow)
   {
      g_kpcFireActive = true;
      g_kpcFireCooldownRemaining = g_kpc_fireCooldown_eff;
      return;
   }

   if(g_kpcFireActive && g_kpcFireCooldownRemaining > 0)
   {
      g_kpcFireCooldownRemaining--;
      if(g_kpcFireCooldownRemaining == 0)
      {
         g_kpcFireActive = false;
         g_kpcSqueezeWasActive = false;
      }
   }
}

//+------------------------------------------------------------------+
//| KPCCheckF1_ERRegime — F1: Block if ER > trending threshold       |
//+------------------------------------------------------------------+
bool KPCCheckF1_ERRegime(double er)
{
   return (er <= g_kpc_erTrending_eff);  // true = PASS
}

//+------------------------------------------------------------------+
//| KPCCheckF2_Squeeze — F2: Require minimum squeeze duration        |
//+------------------------------------------------------------------+
bool KPCCheckF2_Squeeze()
{
   return (g_kpcSqueezeBarsCount >= g_kpc_minSqueezeBars_eff);  // true = PASS
}

//+------------------------------------------------------------------+
//| KPCCheckF3_DCWSlope — F3: Block if DCW expanding fast (OFF dflt) |
//+------------------------------------------------------------------+
bool KPCCheckF3_DCWSlope()
{
   if(g_kpcPrev2DCW <= 0) return true;
   return !(g_kpcLastDCW > g_kpcPrev2DCW * 1.25);  // true = PASS
}

//+------------------------------------------------------------------+
//| KPCCheckF4_Fire — F4: Block if fire active                       |
//+------------------------------------------------------------------+
bool KPCCheckF4_Fire()
{
   return !g_kpcFireActive;  // true = PASS
}

//+------------------------------------------------------------------+
//| KPCCheckF5_WPR — F5: Block if WPR not at extremes (OFF default)  |
//| direction: +1=BUY, -1=SELL                                       |
//+------------------------------------------------------------------+
bool KPCCheckF5_WPR(int direction)
{
   if(direction == -1)
      return (g_kpcLastWPR > g_kpc_wprOB_eff);  // SELL: WPR must be above OB (less negative)
   else
      return (g_kpcLastWPR < g_kpc_wprOS_eff);  // BUY: WPR must be below OS (more negative)
}

//+------------------------------------------------------------------+
//| KPCCheckF6_Width — F6: Minimum channel width in pips             |
//+------------------------------------------------------------------+
bool KPCCheckF6_Width(double upper, double lower)
{
   double channelWidthPips = PointsToPips(upper - lower);
   return (channelWidthPips >= g_kpc_minWidthPips_eff);
}

//+------------------------------------------------------------------+
//| KPCCheckF7_Time — F7: Time block filter                          |
//+------------------------------------------------------------------+
bool KPCCheckF7_Time(int timeBlockStartMin, int timeBlockEndMin)
{
   MqlDateTime dt;
   TimeToStruct(iTime(_Symbol, PERIOD_CURRENT, 1), dt);
   int barMin = dt.hour * 60 + dt.min;
   if(timeBlockStartMin <= timeBlockEndMin)
      return !(barMin >= timeBlockStartMin && barMin < timeBlockEndMin);
   else
      return !(barMin >= timeBlockStartMin || barMin < timeBlockEndMin);
}

//+------------------------------------------------------------------+
//| KPCClassifySignal — Primary (2=TBS) vs Half (1=TWS) quality      |
//+------------------------------------------------------------------+
int KPCClassifySignal(int direction, double open1, double close1,
                      double upperPrimary, double lowerPrimary,
                      double upperHalf, double lowerHalf)
{
   if(direction == -1)
   {
      // SELL: check if body penetrates upper primary band
      double bodyHigh = MathMax(open1, close1);
      if(bodyHigh > upperPrimary) return PATTERN_TBS;  // Body penetrates = strong
      return PATTERN_TWS;  // Only wick = weak
   }
   else
   {
      // BUY: check if body penetrates lower primary band
      double bodyLow = MathMin(open1, close1);
      if(bodyLow < lowerPrimary) return PATTERN_TBS;
      return PATTERN_TWS;
   }
}
