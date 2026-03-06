//+------------------------------------------------------------------+
//|                                          adDPCPresets.mqh        |
//|           AcquaDulza EA v1.0.0 — DPC TF Auto-Preset             |
//|                                                                  |
//|  Inizializza parametri effettivi per il TF corrente.             |
//|  Se InpEngineAutoTFPreset=true, sovrascrive i valori input.      |
//+------------------------------------------------------------------+
#property copyright "AcquaDulza (C) 2026"

//+------------------------------------------------------------------+
//| DPC Engine effective parameters (set by preset or input)         |
//+------------------------------------------------------------------+
int    g_dpc_dcLen     = 20;
int    g_dpc_maLen     = 30;
double g_dpc_minWidth  = 8.0;
int    g_dpc_flatLook  = 3;
double g_dpc_flatTol   = 0.55;
int    g_dpc_nSame     = 3;
int    g_dpc_nOpp      = 2;

//+------------------------------------------------------------------+
//| DPCPresetsInit — Auto-preset based on chart timeframe            |
//|                                                                  |
//| Values from Architecture v3 Section 6.1 (calibrated for EA)      |
//+------------------------------------------------------------------+
bool DPCPresetsInit()
{
   if(!InpEngineAutoTFPreset)
   {
      // Manual mode: use input values directly
      g_dpc_dcLen    = InpLenDC;
      g_dpc_maLen    = InpMALen;
      g_dpc_minWidth = InpMinWidthPips;
      g_dpc_flatLook = InpFlatLookback;
      g_dpc_flatTol  = InpFlatnessTolerance;
      g_dpc_nSame    = InpNSameBars;
      g_dpc_nOpp     = InpNOppositeBars;

      AdLogI(LOG_CAT_ENGINE, StringFormat("DPC Preset: MANUAL — dcLen=%d maLen=%d minW=%.1f flatL=%d flatT=%.2f nS=%d nO=%d",
         g_dpc_dcLen, g_dpc_maLen, g_dpc_minWidth, g_dpc_flatLook, g_dpc_flatTol, g_dpc_nSame, g_dpc_nOpp));
      return true;
   }

   // Auto-preset based on Period()
   switch(Period())
   {
      case PERIOD_M5:
         g_dpc_dcLen    = 20;
         g_dpc_maLen    = 25;
         g_dpc_minWidth = 7.0;
         g_dpc_flatLook = 3;
         g_dpc_flatTol  = 0.40;
         g_dpc_nSame    = 3;
         g_dpc_nOpp     = 2;
         break;

      case PERIOD_M15:
         g_dpc_dcLen    = 20;
         g_dpc_maLen    = 30;
         g_dpc_minWidth = 8.0;
         g_dpc_flatLook = 3;
         g_dpc_flatTol  = 0.50;
         g_dpc_nSame    = 3;
         g_dpc_nOpp     = 2;
         break;

      case PERIOD_M30:
         g_dpc_dcLen    = 20;
         g_dpc_maLen    = 30;
         g_dpc_minWidth = 9.0;
         g_dpc_flatLook = 3;
         g_dpc_flatTol  = 0.50;
         g_dpc_nSame    = 4;
         g_dpc_nOpp     = 2;
         break;

      case PERIOD_H1:
         g_dpc_dcLen    = 20;
         g_dpc_maLen    = 35;
         g_dpc_minWidth = 12.0;
         g_dpc_flatLook = 4;
         g_dpc_flatTol  = 0.38;
         g_dpc_nSame    = 4;
         g_dpc_nOpp     = 3;
         break;

      case PERIOD_H4:
         g_dpc_dcLen    = 20;
         g_dpc_maLen    = 40;
         g_dpc_minWidth = 18.0;
         g_dpc_flatLook = 5;
         g_dpc_flatTol  = 0.35;
         g_dpc_nSame    = 5;
         g_dpc_nOpp     = 3;
         break;

      default:
         // Fallback to manual values for unsupported TF
         g_dpc_dcLen    = InpLenDC;
         g_dpc_maLen    = InpMALen;
         g_dpc_minWidth = InpMinWidthPips;
         g_dpc_flatLook = InpFlatLookback;
         g_dpc_flatTol  = InpFlatnessTolerance;
         g_dpc_nSame    = InpNSameBars;
         g_dpc_nOpp     = InpNOppositeBars;

         AdLogW(LOG_CAT_ENGINE, StringFormat("DPC Preset: TF %s not in preset table — using manual values",
            EnumToString(Period())));
         return true;
   }

   AdLogI(LOG_CAT_ENGINE, StringFormat("DPC Preset: %s — dcLen=%d maLen=%d minW=%.1f flatL=%d flatT=%.2f nS=%d nO=%d",
      EnumToString(Period()), g_dpc_dcLen, g_dpc_maLen, g_dpc_minWidth,
      g_dpc_flatLook, g_dpc_flatTol, g_dpc_nSame, g_dpc_nOpp));
   return true;
}
