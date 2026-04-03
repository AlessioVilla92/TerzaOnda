//+------------------------------------------------------------------+
//|                                       3ondKPCLTFEntry.mqh          |
//|           TerzaOnda EA — KPC LTF Entry Confirmation              |
//|                                                                  |
//|  Lower TimeFrame entry confirmation for precise timing.          |
//|  Adapted from adDPCLTFEntry.mqh with KPC function names.         |
//|                                                                  |
//|  LOGICA: Dopo un segnale sul TF principale, apre una "finestra"  |
//|  di conferma sul TF inferiore. Se una candela LTF chiusa mostra  |
//|  un rejection dalla banda (touch + close inside), il segnale     |
//|  viene confermato con timing piu' preciso.                       |
//+------------------------------------------------------------------+
#property copyright "TerzaOnda (C) 2026"

//+------------------------------------------------------------------+
//| LTF State Variables (KPC Engine scoped)                          |
//+------------------------------------------------------------------+
bool     g_kpcLtfWindowOpen     = false;
int      g_kpcLtfDirection      = 0;
double   g_kpcLtfBandLevel      = 0.0;
datetime g_kpcLtfWindowExpiry   = 0;
datetime g_kpcLtfLastProcessed  = 0;
datetime g_kpcLtfConfirmedBar   = 0;

//+------------------------------------------------------------------+
//| KPCGetLTFTimeframe — Auto-adaptive LTF mapping                   |
//+------------------------------------------------------------------+
ENUM_TIMEFRAMES KPCGetLTFTimeframe()
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
//| KPCResetLTF — Reset completo stato LTF                           |
//+------------------------------------------------------------------+
void KPCResetLTF()
{
   g_kpcLtfWindowOpen    = false;
   g_kpcLtfDirection     = 0;
   g_kpcLtfBandLevel     = 0.0;
   g_kpcLtfWindowExpiry  = 0;
   g_kpcLtfLastProcessed = 0;
   g_kpcLtfConfirmedBar  = 0;
}

//+------------------------------------------------------------------+
//| KPCLTFOpenWindow — Open LTF confirmation window                  |
//+------------------------------------------------------------------+
void KPCLTFOpenWindow(int direction, double bandLevel, datetime barTime)
{
   if(!g_kpc_useLTFEntry) return;
   if(barTime == g_kpcLtfConfirmedBar) return;

   g_kpcLtfWindowOpen    = true;
   g_kpcLtfDirection     = direction;
   g_kpcLtfBandLevel     = bandLevel;
   g_kpcLtfWindowExpiry  = barTime + PeriodSeconds();
   g_kpcLtfLastProcessed = 0;

   AdLogI(LOG_CAT_ENGINE, StringFormat("KPC LTF window opened: %s | Band=%s | Expiry=%s | LTF=%s",
          direction > 0 ? "BUY" : "SELL",
          DoubleToString(bandLevel, _Digits),
          TimeToString(g_kpcLtfWindowExpiry, TIME_MINUTES),
          EnumToString(KPCGetLTFTimeframe())));
}

//+------------------------------------------------------------------+
//| KPCLTFCheckConfirmation — Check LTF closed bar for confirmation  |
//+------------------------------------------------------------------+
int KPCLTFCheckConfirmation()
{
   if(!g_kpc_useLTFEntry) return 0;
   if(!g_kpcLtfWindowOpen) return 0;

   if(TimeCurrent() >= g_kpcLtfWindowExpiry)
   {
      g_kpcLtfWindowOpen = false;
      AdLogI(LOG_CAT_ENGINE, "KPC LTF window expired");
      return 0;
   }

   ENUM_TIMEFRAMES ltfPeriod = KPCGetLTFTimeframe();
   datetime ltfBarTime = iTime(_Symbol, ltfPeriod, 1);
   if(ltfBarTime <= 0) return 0;
   if(ltfBarTime == g_kpcLtfLastProcessed) return 0;
   g_kpcLtfLastProcessed = ltfBarTime;

   double ltfHigh  = iHigh(_Symbol, ltfPeriod, 1);
   double ltfLow   = iLow(_Symbol, ltfPeriod, 1);
   double ltfClose = iClose(_Symbol, ltfPeriod, 1);

   bool ltfConfirmed = false;
   if(g_kpcLtfDirection == -1)
      ltfConfirmed = (ltfHigh >= g_kpcLtfBandLevel) && (ltfClose < g_kpcLtfBandLevel);
   else if(g_kpcLtfDirection == +1)
      ltfConfirmed = (ltfLow <= g_kpcLtfBandLevel) && (ltfClose > g_kpcLtfBandLevel);

   if(ltfConfirmed)
   {
      g_kpcLtfWindowOpen   = false;
      g_kpcLtfConfirmedBar = iTime(_Symbol, PERIOD_CURRENT, 0);
      AdLogI(LOG_CAT_ENGINE, StringFormat("KPC LTF CONFIRMED %s",
             g_kpcLtfDirection > 0 ? "BUY" : "SELL"));
      return g_kpcLtfDirection;
   }
   return 0;
}

//+------------------------------------------------------------------+
//| KPCLTFIsWaiting — Check if LTF window is active                  |
//+------------------------------------------------------------------+
bool KPCLTFIsWaiting()
{
   return g_kpcLtfWindowOpen;
}

//+------------------------------------------------------------------+
//| KPCLTFShouldFilter — Should signal wait for LTF confirmation?    |
//+------------------------------------------------------------------+
bool KPCLTFShouldFilter(int quality)
{
   if(!g_kpc_useLTFEntry) return false;
   if(g_kpc_ltfOnlyTBS && quality != PATTERN_TBS) return false;
   return true;
}
