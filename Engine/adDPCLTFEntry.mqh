//+------------------------------------------------------------------+
//|                                        adDPCLTFEntry.mqh         |
//|           AcquaDulza EA v1.5.0 — DPC LTF Entry Confirmation      |
//|                                                                  |
//|  Lower TimeFrame entry confirmation for precise timing.          |
//|  Based on DPC0404 v7.19 Section 5c.                              |
//|                                                                  |
//|  Flow:                                                           |
//|    1. Main TF signal opens LTF window                            |
//|    2. Monitor LTF closed bars (shift=1, zero repaint)            |
//|    3. Confirm: LTF candle touches band AND closes inside         |
//|    4. Window expires after 1 main TF bar                         |
//+------------------------------------------------------------------+
#property copyright "AcquaDulza (C) 2026"

//+------------------------------------------------------------------+
//| LTF State Variables (DPC Engine scoped)                          |
//+------------------------------------------------------------------+
bool     g_ltfWindowOpen     = false;
int      g_ltfDirection      = 0;       // +1=BUY, -1=SELL
double   g_ltfBandLevel      = 0.0;     // Band level to monitor
datetime g_ltfWindowExpiry   = 0;       // Window expiry time
datetime g_ltfLastProcessed  = 0;       // Last LTF bar processed (anti-duplicate)
datetime g_ltfConfirmedBar   = 0;       // Bar where LTF was confirmed (anti-reopen)

//+------------------------------------------------------------------+
//| DPCGetLTFTimeframe — Auto-adaptive LTF mapping                  |
//+------------------------------------------------------------------+
ENUM_TIMEFRAMES DPCGetLTFTimeframe()
{
   switch(Period())
   {
      case PERIOD_M5:  return PERIOD_M1;
      case PERIOD_M15: return PERIOD_M5;
      case PERIOD_M30: return PERIOD_M5;
      case PERIOD_H1:  return PERIOD_M15;
      case PERIOD_H4:  return PERIOD_M30;
      default:         return PERIOD_M1;
   }
}

//+------------------------------------------------------------------+
//| DPCResetLTF — Reset all LTF state                               |
//+------------------------------------------------------------------+
void DPCResetLTF()
{
   g_ltfWindowOpen    = false;
   g_ltfDirection     = 0;
   g_ltfBandLevel     = 0.0;
   g_ltfWindowExpiry  = 0;
   g_ltfLastProcessed = 0;
   g_ltfConfirmedBar  = 0;
}

//+------------------------------------------------------------------+
//| DPCLTFOpenWindow — Open LTF confirmation window                 |
//|  Called when main TF signal fires                                |
//|  direction: +1=BUY, -1=SELL                                     |
//|  bandLevel: lower (BUY) or upper (SELL)                          |
//|  barTime: current bar[0] open time                               |
//+------------------------------------------------------------------+
void DPCLTFOpenWindow(int direction, double bandLevel, datetime barTime)
{
   if(!InpUseLTFEntry) return;

   // Don't reopen on already-confirmed bar
   if(barTime == g_ltfConfirmedBar) return;

   g_ltfWindowOpen    = true;
   g_ltfDirection     = direction;
   g_ltfBandLevel     = bandLevel;
   g_ltfWindowExpiry  = barTime + PeriodSeconds();
   g_ltfLastProcessed = 0;

   AdLogI(LOG_CAT_DPC, StringFormat("LTF window opened: %s | Band=%s | Expiry=%s",
          direction > 0 ? "BUY" : "SELL",
          DoubleToString(bandLevel, _Digits),
          TimeToString(g_ltfWindowExpiry, TIME_MINUTES)));
}

//+------------------------------------------------------------------+
//| DPCLTFCheckConfirmation — Check LTF closed bar for confirmation |
//|  Returns: +1=BUY confirmed, -1=SELL confirmed, 0=no confirmation |
//|                                                                  |
//|  BUY: LTF candle touches lower band AND closes above it         |
//|  SELL: LTF candle touches upper band AND closes below it         |
//|  Zero repaint: reads LTF bar[1] only (closed bar)               |
//+------------------------------------------------------------------+
int DPCLTFCheckConfirmation()
{
   if(!InpUseLTFEntry) return 0;
   if(!g_ltfWindowOpen) return 0;

   // Check expiry
   if(TimeCurrent() >= g_ltfWindowExpiry)
   {
      g_ltfWindowOpen = false;
      AdLogI(LOG_CAT_DPC, "LTF window expired — no confirmation");
      return 0;
   }

   ENUM_TIMEFRAMES ltfPeriod = DPCGetLTFTimeframe();

   // Read most recent CLOSED LTF bar (shift=1)
   datetime ltfBarTime = iTime(_Symbol, ltfPeriod, 1);
   if(ltfBarTime <= 0) return 0;

   // Anti-duplicate: process each LTF bar only once
   if(ltfBarTime == g_ltfLastProcessed) return 0;
   g_ltfLastProcessed = ltfBarTime;

   double ltfHigh  = iHigh(_Symbol, ltfPeriod, 1);
   double ltfLow   = iLow(_Symbol, ltfPeriod, 1);
   double ltfClose = iClose(_Symbol, ltfPeriod, 1);

   bool ltfConfirmed = false;

   if(g_ltfDirection == -1)
   {
      // SELL LTF: candle touches upper band AND closes below (rejection)
      ltfConfirmed = (ltfHigh >= g_ltfBandLevel) && (ltfClose < g_ltfBandLevel);
   }
   else if(g_ltfDirection == +1)
   {
      // BUY LTF: candle touches lower band AND closes above (rejection)
      ltfConfirmed = (ltfLow <= g_ltfBandLevel) && (ltfClose > g_ltfBandLevel);
   }

   if(ltfConfirmed)
   {
      g_ltfWindowOpen   = false;
      g_ltfConfirmedBar = iTime(_Symbol, PERIOD_CURRENT, 0);

      AdLogI(LOG_CAT_DPC, StringFormat("LTF CONFIRMED %s | LTF bar: H=%s L=%s C=%s | Band=%s",
             g_ltfDirection > 0 ? "BUY" : "SELL",
             DoubleToString(ltfHigh, _Digits), DoubleToString(ltfLow, _Digits),
             DoubleToString(ltfClose, _Digits), DoubleToString(g_ltfBandLevel, _Digits)));

      return g_ltfDirection;
   }

   return 0;
}

//+------------------------------------------------------------------+
//| DPCLTFIsWaiting — Check if LTF window is active                 |
//+------------------------------------------------------------------+
bool DPCLTFIsWaiting()
{
   return g_ltfWindowOpen;
}

//+------------------------------------------------------------------+
//| DPCLTFShouldFilter — Should signal wait for LTF confirmation?   |
//|  Returns true if LTF is enabled and applicable to this signal    |
//|  quality: PATTERN_TBS or PATTERN_TWS                             |
//+------------------------------------------------------------------+
bool DPCLTFShouldFilter(int quality)
{
   if(!InpUseLTFEntry) return false;

   // If LTFOnlyTBS, only filter TBS signals
   if(InpLTFOnlyTBS && quality != PATTERN_TBS)
      return false;

   return true;
}
