//+------------------------------------------------------------------+
//|                                         adDPCFilters.mqh         |
//|           AcquaDulza EA v1.0.0 — DPC Quality Filters             |
//|                                                                  |
//|  Flatness + TrendContext + LevelAge + ChannelWidth + MA Filter   |
//+------------------------------------------------------------------+
#property copyright "AcquaDulza (C) 2026"

//+------------------------------------------------------------------+
//| CheckBandFlatness_Sell — Block SELL if upper band expanded up    |
//+------------------------------------------------------------------+
bool DPCCheckFlatness_Sell(int barShift, double atr)
{
   double flatTolerance = g_dpc_flatTol * atr;
   int flatLookback = (int)MathMax(1, MathMin(10, g_dpc_flatLook));

   double uC, lC, mC;
   DPCComputeBands(barShift, g_dpc_dcLen, uC, lC, mC);

   for(int k = 1; k <= flatLookback; k++)
   {
      double uK, lK, mK;
      DPCComputeBands(barShift + k, g_dpc_dcLen, uK, lK, mK);

      if(uC > uK + flatTolerance)
         return false;  // Upper expanded -> block SELL
   }
   return true;
}

//+------------------------------------------------------------------+
//| CheckBandFlatness_Buy — Block BUY if lower band expanded down   |
//+------------------------------------------------------------------+
bool DPCCheckFlatness_Buy(int barShift, double atr)
{
   double flatTolerance = g_dpc_flatTol * atr;
   int flatLookback = (int)MathMax(1, MathMin(10, g_dpc_flatLook));

   double uC, lC, mC;
   DPCComputeBands(barShift, g_dpc_dcLen, uC, lC, mC);

   for(int k = 1; k <= flatLookback; k++)
   {
      double uK, lK, mK;
      DPCComputeBands(barShift + k, g_dpc_dcLen, uK, lK, mK);

      if(lC < lK - flatTolerance)
         return false;  // Lower expanded down -> block BUY
   }
   return true;
}

//+------------------------------------------------------------------+
//| CheckTrendContext_Sell — Block SELL if macro uptrend              |
//+------------------------------------------------------------------+
bool DPCCheckTrendContext_Sell(int barShift, double atr)
{
   int totalBars = iBars(_Symbol, PERIOD_CURRENT);
   if((barShift + g_dpc_dcLen) >= totalBars) return true;

   double trendThreshold = InpTrendContextMult * atr;

   double uNow, lNow, mNow;
   double uThen, lThen, mThen;
   DPCComputeBands(barShift, g_dpc_dcLen, uNow, lNow, mNow);
   DPCComputeBands(barShift + g_dpc_dcLen, g_dpc_dcLen, uThen, lThen, mThen);

   if((mNow - mThen) > trendThreshold)
      return false;  // Midline rose -> macro uptrend -> block SELL
   return true;
}

//+------------------------------------------------------------------+
//| CheckTrendContext_Buy — Block BUY if macro downtrend             |
//+------------------------------------------------------------------+
bool DPCCheckTrendContext_Buy(int barShift, double atr)
{
   int totalBars = iBars(_Symbol, PERIOD_CURRENT);
   if((barShift + g_dpc_dcLen) >= totalBars) return true;

   double trendThreshold = InpTrendContextMult * atr;

   double uNow, lNow, mNow;
   double uThen, lThen, mThen;
   DPCComputeBands(barShift, g_dpc_dcLen, uNow, lNow, mNow);
   DPCComputeBands(barShift + g_dpc_dcLen, g_dpc_dcLen, uThen, lThen, mThen);

   if((mThen - mNow) > trendThreshold)
      return false;  // Midline fell -> macro downtrend -> block BUY
   return true;
}

//+------------------------------------------------------------------+
//| CheckLevelAge_Sell — Require upper band flat for N bars          |
//+------------------------------------------------------------------+
bool DPCCheckLevelAge_Sell(int barShift)
{
   int minAge = (int)MathMax(1, MathMin(10, InpMinLevelAge));
   int totalBars = iBars(_Symbol, PERIOD_CURRENT);

   double uC, lC, mC;
   DPCComputeBands(barShift, g_dpc_dcLen, uC, lC, mC);

   int flatBars = 0;
   for(int k = 1; k < g_dpc_dcLen && (barShift + k) < totalBars; k++)
   {
      double uK, lK, mK;
      DPCComputeBands(barShift + k, g_dpc_dcLen, uK, lK, mK);

      if(MathAbs(uK - uC) <= 2 * _Point)
         flatBars++;
      else
         break;
   }
   return (flatBars >= minAge);
}

//+------------------------------------------------------------------+
//| CheckLevelAge_Buy — Require lower band flat for N bars           |
//+------------------------------------------------------------------+
bool DPCCheckLevelAge_Buy(int barShift)
{
   int minAge = (int)MathMax(1, MathMin(10, InpMinLevelAge));
   int totalBars = iBars(_Symbol, PERIOD_CURRENT);

   double uC, lC, mC;
   DPCComputeBands(barShift, g_dpc_dcLen, uC, lC, mC);

   int flatBars = 0;
   for(int k = 1; k < g_dpc_dcLen && (barShift + k) < totalBars; k++)
   {
      double uK, lK, mK;
      DPCComputeBands(barShift + k, g_dpc_dcLen, uK, lK, mK);

      if(MathAbs(lK - lC) <= 2 * _Point)
         flatBars++;
      else
         break;
   }
   return (flatBars >= minAge);
}

//+------------------------------------------------------------------+
//| CheckChannelWidth — Min channel width in pips                    |
//+------------------------------------------------------------------+
bool DPCCheckChannelWidth(double upper, double lower)
{
   double widthPips = PointsToPips(upper - lower);
   return (widthPips >= g_dpc_minWidth);
}

//+------------------------------------------------------------------+
//| CheckMAFilter — MA direction filter                              |
//| BUG FIX from DPC0404: was dead code `if(false &&`               |
//| Now properly checks close vs MA based on InpMAFilterMode         |
//+------------------------------------------------------------------+
bool DPCCheckMAFilter(double close1, double ma1, int direction)
{
   if(InpMAFilterMode == MA_FILTER_DISABLED) return true;
   if(ma1 <= 0) return true;

   if(direction > 0)  // BUY
   {
      if(InpMAFilterMode == MA_FILTER_ABOVE || InpMAFilterMode == MA_FILTER_BOTH)
         return (close1 > ma1);
   }
   else if(direction < 0)  // SELL
   {
      if(InpMAFilterMode == MA_FILTER_BELOW || InpMAFilterMode == MA_FILTER_BOTH)
         return (close1 < ma1);
   }

   return true;
}

//+------------------------------------------------------------------+
//| ClassifySignal — TBS vs TWS pattern                              |
//| TBS: body breaks band (quality=3)                                |
//| TWS: only wick breaks band (quality=1)                           |
//+------------------------------------------------------------------+
int DPCClassifySignal(int direction, double open1, double close1, double upper, double lower)
{
   if(direction > 0) // BUY — lower band touched
   {
      // TBS: close <= lower (body breaks below)
      if(close1 <= lower) return PATTERN_TBS;
      // TWS: only wick broke (low <= lower but close > lower)
      return PATTERN_TWS;
   }
   else if(direction < 0) // SELL — upper band touched
   {
      // TBS: close >= upper (body breaks above)
      if(close1 >= upper) return PATTERN_TBS;
      // TWS: only wick broke
      return PATTERN_TWS;
   }
   return PATTERN_NONE;
}
