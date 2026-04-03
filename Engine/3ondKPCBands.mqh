//+------------------------------------------------------------------+
//|                                          3ondKPCBands.mqh          |
//|           TerzaOnda EA — KPC Band Calculation                    |
//|                                                                  |
//|  KAMA (Kaufman Adaptive MA) + ATR-based Keltner Channel bands.   |
//|  Extracted from KeltnerPredictiveChannel.mq5 v1.09.              |
//|                                                                  |
//|  KAMA recursion:                                                 |
//|    ER = |close[0]-close[N]| / sum|close[k]-close[k+1]|          |
//|    SC = (ER*(fastSC-slowSC)+slowSC)^2                            |
//|    KAMA = prev_KAMA + SC*(close - prev_KAMA)                     |
//|                                                                  |
//|  KC Bands: upper = KAMA + ATR*mult, lower = KAMA - ATR*mult     |
//+------------------------------------------------------------------+
#property copyright "TerzaOnda (C) 2026"

//+------------------------------------------------------------------+
//| KPC Engine internal state                                        |
//+------------------------------------------------------------------+
double g_kpcKAMA           = 0;     // Current KAMA value (recursive)
double g_kpcLastER         = 0;     // Last computed Efficiency Ratio
double g_kpcEmaATR         = 0;     // EMA(ATR, 200)
double g_kpcLastATR        = 0;     // Last ATR value
double g_kpcLastUpper      = 0;     // Last upper band
double g_kpcLastLower      = 0;     // Last lower band
double g_kpcLastUpperHalf  = 0;     // Last upper half band
double g_kpcLastLowerHalf  = 0;     // Last lower half band
bool   g_kpcKAMASeeded     = false; // Whether KAMA has been seeded
int    g_kpcBarsProcessed  = 0;     // Track bars for seeding

//+------------------------------------------------------------------+
//| KPCCreateHandles — Create ATR indicator handle                   |
//| No MA handle needed — KAMA is computed from raw close prices.    |
//+------------------------------------------------------------------+
bool KPCCreateHandles()
{
   // ATR handle — uses framework g_atrHandle
   // Created by InitializeATR in adATRCalculator.mqh with period from preset
   // No additional handles needed for KPC (KAMA is computed, not from iMA)
   return true;
}

//+------------------------------------------------------------------+
//| KPCReleaseHandles — Release all indicator handles                |
//+------------------------------------------------------------------+
void KPCReleaseHandles()
{
   // No engine-specific handles to release (ATR is framework-managed)
   AdLogI(LOG_CAT_ENGINE, "KPC indicator handles released (none engine-specific)");
}

//+------------------------------------------------------------------+
//| KPCGetATR — Read ATR from framework handle                       |
//+------------------------------------------------------------------+
double KPCGetATR(int barShift)
{
   if(g_atrHandle == INVALID_HANDLE) return 0;

   double atrBuf[];
   ArrayResize(atrBuf, 1);
   ArraySetAsSeries(atrBuf, true);

   if(CopyBuffer(g_atrHandle, 0, barShift, 1, atrBuf) < 1) return 0;
   return atrBuf[0];
}

//+------------------------------------------------------------------+
//| KPCUpdateEmaATR — EMA(ATR, 200) for smooth volatility reference  |
//+------------------------------------------------------------------+
void KPCUpdateEmaATR(double atr)
{
   if(atr <= 0) return;

   double alpha = 2.0 / (200.0 + 1.0);
   if(g_kpcEmaATR > 0)
      g_kpcEmaATR = alpha * atr + (1.0 - alpha) * g_kpcEmaATR;
   else
      g_kpcEmaATR = atr;
}

//+------------------------------------------------------------------+
//| KPCComputeKAMA — Recursive KAMA update for given bar             |
//|                                                                  |
//| Returns Efficiency Ratio via reference parameter.                |
//| Stores KAMA in g_kpcKAMA for next call.                          |
//+------------------------------------------------------------------+
double KPCComputeKAMA(int barShift, double &er)
{
   er = 0;
   int period = g_kpc_kamaPeriod_eff;

   // Compute Efficiency Ratio
   double close0 = iClose(_Symbol, PERIOD_CURRENT, barShift);
   double closeN = iClose(_Symbol, PERIOD_CURRENT, barShift + period);

   if(close0 == 0 || closeN == 0) { er = 0; return g_kpcKAMA; }

   double direction_val = MathAbs(close0 - closeN);
   double volatility = 0;
   for(int k = 0; k < period; k++)
   {
      double c1 = iClose(_Symbol, PERIOD_CURRENT, barShift + k);
      double c2 = iClose(_Symbol, PERIOD_CURRENT, barShift + k + 1);
      if(c1 > 0 && c2 > 0)
         volatility += MathAbs(c1 - c2);
   }
   er = (volatility > 1e-10) ? direction_val / volatility : 0;

   // Smoothing Constant
   double fastSC = 2.0 / (InpKPC_KAMA_Fast + 1.0);
   double slowSC = 2.0 / (InpKPC_KAMA_Slow + 1.0);
   double sc = MathPow(er * (fastSC - slowSC) + slowSC, 2.0);

   // Seed KAMA on first call
   if(!g_kpcKAMASeeded)
   {
      g_kpcKAMA = close0;
      g_kpcKAMASeeded = true;
   }
   else
   {
      g_kpcKAMA = g_kpcKAMA + sc * (close0 - g_kpcKAMA);
   }

   return g_kpcKAMA;
}

//+------------------------------------------------------------------+
//| KPCComputeBands — Full band computation for given bar             |
//|                                                                  |
//| Updates all internal state: KAMA, bands, ER, ATR.                |
//| Called once per new bar from EngineCalculate.                     |
//+------------------------------------------------------------------+
void KPCComputeBands(int barShift)
{
   double er = 0;
   double kama = KPCComputeKAMA(barShift, er);
   g_kpcLastER = er;

   double atr = KPCGetATR(barShift);
   g_kpcLastATR = atr;
   KPCUpdateEmaATR(atr);

   g_kpcLastUpper     = kama + atr * g_kpc_multiplier_eff;
   g_kpcLastLower     = kama - atr * g_kpc_multiplier_eff;
   g_kpcLastUpperHalf = kama + atr * g_kpc_halfMultiplier_eff;
   g_kpcLastLowerHalf = kama - atr * g_kpc_halfMultiplier_eff;

   g_kpcBarsProcessed++;
}

//+------------------------------------------------------------------+
//| KPCComputeOverlayBands — For UI overlay (any barShift)           |
//|                                                                  |
//| Computes KAMA + KC bands for an arbitrary bar without updating   |
//| the engine's recursive KAMA state. Uses a local forward pass.    |
//|                                                                  |
//| For performance: only computes the minimal KAMA approximation.   |
//| For bars near bar[1], uses the engine's cached values.           |
//+------------------------------------------------------------------+
void KPCComputeOverlayBands(int barShift, double &upper, double &lower, double &kama)
{
   int period = g_kpc_kamaPeriod_eff;
   int totalBars = iBars(_Symbol, PERIOD_CURRENT);

   if(totalBars < period + barShift + 5)
   {
      upper = 0; lower = 0; kama = 0;
      return;
   }

   // Compute KAMA for this bar from scratch (simplified: seed at barShift+period, iterate forward)
   int seedBar = barShift + period + 10;
   if(seedBar >= totalBars) seedBar = totalBars - 1;

   double kamaVal = iClose(_Symbol, PERIOD_CURRENT, seedBar);
   double fastSC = 2.0 / (InpKPC_KAMA_Fast + 1.0);
   double slowSC = 2.0 / (InpKPC_KAMA_Slow + 1.0);

   for(int i = seedBar - 1; i >= barShift; i--)
   {
      double closeI  = iClose(_Symbol, PERIOD_CURRENT, i);
      double closeN  = iClose(_Symbol, PERIOD_CURRENT, i + period);
      if(closeI == 0 || closeN == 0) continue;

      double dir_val = MathAbs(closeI - closeN);
      double vol = 0;
      for(int k = 0; k < period; k++)
      {
         double c1 = iClose(_Symbol, PERIOD_CURRENT, i + k);
         double c2 = iClose(_Symbol, PERIOD_CURRENT, i + k + 1);
         if(c1 > 0 && c2 > 0) vol += MathAbs(c1 - c2);
      }
      double er = (vol > 1e-10) ? dir_val / vol : 0;
      double sc = MathPow(er * (fastSC - slowSC) + slowSC, 2.0);
      kamaVal = kamaVal + sc * (closeI - kamaVal);
   }

   double atr = KPCGetATR(barShift);
   kama  = kamaVal;
   upper = kamaVal + atr * g_kpc_multiplier_eff;
   lower = kamaVal - atr * g_kpc_multiplier_eff;
}

//+------------------------------------------------------------------+
//| KPCGetOverlayMA — For UI overlay (KPC has no separate MA)        |
//| Returns 0.0 — KAMA is the midline, no separate MA to draw.      |
//+------------------------------------------------------------------+
double KPCGetOverlayMA(int barShift)
{
   return 0.0;
}

//+------------------------------------------------------------------+
//| KPCGetMidlineColorState — KAMA trend direction for overlay       |
//| 0=bullish (up), 1=bearish (down), 2=flat/ranging                 |
//+------------------------------------------------------------------+
int KPCGetMidlineColorState(int barShift)
{
   // Compute KAMA at barShift and barShift+2 for direction
   double upper1, lower1, kama1;
   double upper3, lower3, kama3;
   KPCComputeOverlayBands(barShift, upper1, lower1, kama1);
   KPCComputeOverlayBands(barShift + 2, upper3, lower3, kama3);

   // Also compute ER for ranging check
   int period = g_kpc_kamaPeriod_eff;
   double close0 = iClose(_Symbol, PERIOD_CURRENT, barShift);
   double closeN = iClose(_Symbol, PERIOD_CURRENT, barShift + period);
   double dir_val = MathAbs(close0 - closeN);
   double vol = 0;
   for(int k = 0; k < period; k++)
   {
      double c1 = iClose(_Symbol, PERIOD_CURRENT, barShift + k);
      double c2 = iClose(_Symbol, PERIOD_CURRENT, barShift + k + 1);
      if(c1 > 0 && c2 > 0) vol += MathAbs(c1 - c2);
   }
   double er = (vol > 1e-10) ? dir_val / vol : 0;

   if(er < g_kpc_erRanging_eff) return 2;     // ranging/flat
   if(kama1 > kama3)            return 0;      // bullish
   if(kama1 < kama3)            return 1;      // bearish
   return 2;                                    // flat
}

//+------------------------------------------------------------------+
//| KPCResetBands — Reset all band state (called from EngineInit)    |
//+------------------------------------------------------------------+
void KPCResetBands()
{
   g_kpcKAMA           = 0;
   g_kpcLastER         = 0;
   g_kpcEmaATR         = 0;
   g_kpcLastATR        = 0;
   g_kpcLastUpper      = 0;
   g_kpcLastLower      = 0;
   g_kpcLastUpperHalf  = 0;
   g_kpcLastLowerHalf  = 0;
   g_kpcKAMASeeded     = false;
   g_kpcBarsProcessed  = 0;
}
