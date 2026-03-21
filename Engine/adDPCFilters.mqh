//+------------------------------------------------------------------+
//|                                         adDPCFilters.mqh         |
//|           AcquaDulza EA v1.5.0 — DPC Quality Filters             |
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

   // Tolleranza: crypto usa g_pipSize (es. $2 per BTCUSD), altri strumenti usano _Point
   double levelTol = (g_instrumentClass == INSTRUMENT_CRYPTO) ? (2 * g_pipSize) : (2 * _Point);

   AdLogI(LOG_CAT_FILTER, StringFormat(
      "DIAG LevelAge SELL: bar=%d | upper=%.2f | tolerance=%.5f (%s) | minAge=%d",
      barShift, uC, levelTol,
      (g_instrumentClass == INSTRUMENT_CRYPTO) ? "crypto/pipSize" : "point",
      minAge));

   int flatBars = 0;
   double firstDelta = -1;
   for(int k = 1; k < g_dpc_dcLen && (barShift + k) < totalBars; k++)
   {
      double uK, lK, mK;
      DPCComputeBands(barShift + k, g_dpc_dcLen, uK, lK, mK);

      if(k == 1) firstDelta = MathAbs(uK - uC);

      if(MathAbs(uK - uC) <= levelTol)
         flatBars++;
      else
         break;
   }

   if(flatBars < minAge)
      AdLogI(LOG_CAT_FILTER, StringFormat(
         "DIAG LevelAge SELL BLOCKED: flatBars=%d < minAge=%d | firstDelta=%.5f vs tol=%.5f",
         flatBars, minAge, firstDelta, levelTol));

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

   // Tolleranza: crypto usa g_pipSize (es. $2 per BTCUSD), altri strumenti usano _Point
   double levelTol = (g_instrumentClass == INSTRUMENT_CRYPTO) ? (2 * g_pipSize) : (2 * _Point);

   AdLogI(LOG_CAT_FILTER, StringFormat(
      "DIAG LevelAge BUY: bar=%d | lower=%.2f | tolerance=%.5f (%s) | minAge=%d",
      barShift, lC, levelTol,
      (g_instrumentClass == INSTRUMENT_CRYPTO) ? "crypto/pipSize" : "point",
      minAge));

   int flatBars = 0;
   double firstDelta = -1;
   for(int k = 1; k < g_dpc_dcLen && (barShift + k) < totalBars; k++)
   {
      double uK, lK, mK;
      DPCComputeBands(barShift + k, g_dpc_dcLen, uK, lK, mK);

      if(k == 1) firstDelta = MathAbs(lK - lC);

      if(MathAbs(lK - lC) <= levelTol)
         flatBars++;
      else
         break;
   }

   if(flatBars < minAge)
      AdLogI(LOG_CAT_FILTER, StringFormat(
         "DIAG LevelAge BUY BLOCKED: flatBars=%d < minAge=%d | firstDelta=%.5f vs tol=%.5f",
         flatBars, minAge, firstDelta, levelTol));

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
//| Aligned with DPC indicator v7.19 (lines 3509-3520)               |
//|                                                                  |
//| CLASSIC:  trend-following — SELL se close < MA, BUY se close > MA|
//| INVERTED: mean-reversion Soup — SELL se close > MA (overextended)|
//|           BUY se close < MA (oversold) ← DEFAULT in DPC          |
//+------------------------------------------------------------------+
bool DPCCheckMAFilter(double close1, double ma1, int direction)
{
   if(InpMAFilterMode == MA_FILTER_DISABLED) return true;
   if(ma1 <= 0) return true;

   if(InpMAFilterMode == MA_FILTER_CLASSIC)
   {
      // Trend-following: SELL sotto MA, BUY sopra MA
      if(direction > 0)  return (close1 > ma1);  // BUY only above MA
      if(direction < 0)  return (close1 < ma1);  // SELL only below MA
   }
   else if(InpMAFilterMode == MA_FILTER_INVERTED)
   {
      // Mean-reversion Soup: SELL quando overextended SOPRA MA, BUY quando SOTTO MA
      if(direction > 0)  return (close1 < ma1);  // BUY when below MA (oversold)
      if(direction < 0)  return (close1 > ma1);  // SELL when above MA (overextended)
   }

   return true;
}

//+------------------------------------------------------------------+
//| ClassifySignal — TBS vs TWS pattern                              |
//| Aligned with DPC indicator v7.19 (lines 3636-3642, 3769-3775)   |
//| TBS: BODY penetrates band (quality=3) — MathMax/MathMin logic   |
//| TWS: only WICK penetrates band (quality=1)                       |
//+------------------------------------------------------------------+
int DPCClassifySignal(int direction, double open1, double close1, double upper, double lower)
{
   if(direction > 0) // BUY — lower band touched
   {
      // TBS: body LOW (min of open/close) breaks below lower band
      if(MathMin(open1, close1) < lower) return PATTERN_TBS;
      // TWS: only wick broke (low <= lower but body stayed inside)
      return PATTERN_TWS;
   }
   else if(direction < 0) // SELL — upper band touched
   {
      // TBS: body HIGH (max of open/close) breaks above upper band
      if(MathMax(open1, close1) > upper) return PATTERN_TBS;
      // TWS: only wick broke (high >= upper but body stayed inside)
      return PATTERN_TWS;
   }
   return PATTERN_NONE;
}
