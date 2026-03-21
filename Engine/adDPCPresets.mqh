//+------------------------------------------------------------------+
//|                                          adDPCPresets.mqh        |
//|           AcquaDulza EA v1.5.0 — DPC TF Auto-Preset             |
//|                                                                  |
//|  Inizializza parametri effettivi per il TF corrente.             |
//|  Se InpEngineAutoTFPreset=true, sovrascrive i valori input.      |
//|                                                                  |
//|  v1.3.0: M5/M15 allineati a Carneval EA (flatTol, cooldown)      |
//|  PRESET ALLINEATI a DonchianPredictiveChannel.mq5 + Carneval     |
//|  Logica: MA scala INVERSAMENTE col TF (finestra temporale ~cost) |
//|    M5=50 barre×5min=250min≈4h  |  H4=12 barre×240min=48h≈2gg   |
//|  Cooldown/flatLook scalano inversamente (1 barra H4 = 4h già)   |
//|  MinWidth scala direttamente col TF (canali più ampi su TF alti) |
//+------------------------------------------------------------------+
#property copyright "AcquaDulza (C) 2026"

//+------------------------------------------------------------------+
//| DPC Engine effective parameters (set by preset or input)         |
//+------------------------------------------------------------------+
int    g_dpc_dcLen     = 20;
int    g_dpc_maLen     = 30;
double g_dpc_minWidth  = 8.0;
int    g_dpc_flatLook  = 2;
double g_dpc_flatTol   = 0.85;
int    g_dpc_nSame     = 2;
int    g_dpc_nOpp      = 1;

//+------------------------------------------------------------------+
//| DPCPresetsInit — Auto-preset based on chart timeframe            |
//|                                                                  |
//| Values aligned with DonchianPredictiveChannel.mq5 v7.19          |
//|                                                                  |
//|  TF   | dcLen | maLen | minW  | nS | nO | flatL | flatT         |
//|  M5   |  20   |  50   |  7.0  |  2 |  1 |   2   | 0.85          |
//|  M15  |  20   |  34   | 10.0  |  2 |  1 |   2   | 0.65          |
//|  M30  |  20   |  24   | 14.0  |  2 |  1 |   2   | 0.50          |
//|  H1   |  20   |  18   | 18.0  |  1 |  1 |   2   | 0.38          |
//|  H4   |  20   |  12   | 30.0  |  1 |  1 |   1   | 0.35          |
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

      // Scala minWidth per classe strumento anche in modalità manuale
      // (es. BTCUSD con input 8.0 pip → 8.0 × 25.0 = 200.0 pip effettivi)
      if(g_inst_widthFactor > 1.0)
      {
         double origWidth = g_dpc_minWidth;
         g_dpc_minWidth *= g_inst_widthFactor;
         AdLogI(LOG_CAT_ENGINE, StringFormat("DPC MANUAL minWidth scaled by instrument factor: %.1f × %.1f = %.1f pip",
            origWidth, g_inst_widthFactor, g_dpc_minWidth));
      }

      AdLogI(LOG_CAT_ENGINE, StringFormat("DPC Preset: MANUAL — dcLen=%d maLen=%d minW=%.1f flatL=%d flatT=%.2f nS=%d nO=%d",
         g_dpc_dcLen, g_dpc_maLen, g_dpc_minWidth, g_dpc_flatLook, g_dpc_flatTol, g_dpc_nSame, g_dpc_nOpp));
      return true;
   }

   // Auto-preset based on Period() — aligned with DPC indicator v7.19
   switch(Period())
   {
      case PERIOD_M5:
         g_dpc_dcLen    = 20;
         g_dpc_maLen    = 50;       // MA=50×5min=250min≈4h
         g_dpc_minWidth = 7.0;      // minWidth alzato 5→7 pip (v7.19)
         g_dpc_flatLook = 2;        // 2 barre = 10min lookback (allineato Carneval)
         g_dpc_flatTol  = 0.85;     // tolleranza Carneval (ATR~8pip → soglia 6.8pip)
         g_dpc_nSame    = 2;        // 2 barre = 10min (allineato Carneval)
         g_dpc_nOpp     = 1;        // 1 barra = 5min (allineato Carneval)
         break;

      case PERIOD_M15:
         g_dpc_dcLen    = 20;
         g_dpc_maLen    = 34;       // MA=34×15min=510min≈8.5h
         g_dpc_minWidth = 10.0;     // canali M15 più ampi di M5
         g_dpc_flatLook = 2;        // 2 barre = 30min lookback
         g_dpc_flatTol  = 0.65;     // tolleranza intermedia M15 (ATR~12pip → soglia 7.8pip)
         g_dpc_nSame    = 2;        // 2 barre = 30min
         g_dpc_nOpp     = 1;        // 1 barra = 15min (piu' reattivo)
         break;

      case PERIOD_M30:
         g_dpc_dcLen    = 20;
         g_dpc_maLen    = 24;       // MA=24×30min=720min=12h
         g_dpc_minWidth = 14.0;     // canali M30 significativamente più ampi
         g_dpc_flatLook = 2;        // 2 barre = 1h lookback
         g_dpc_flatTol  = 0.50;     // tolleranza standard M30
         g_dpc_nSame    = 2;        // 2 barre = 1h
         g_dpc_nOpp     = 1;        // 1 barra = 30min
         break;

      case PERIOD_H1:
         g_dpc_dcLen    = 20;
         g_dpc_maLen    = 18;       // MA=18×60min=1080min=18h
         g_dpc_minWidth = 18.0;     // canali H1 ampi
         g_dpc_flatLook = 2;        // 2 barre = 2h lookback
         g_dpc_flatTol  = 0.38;     // tolleranza ridotta H1 (ATR~25pip → soglia 9.5pip)
         g_dpc_nSame    = 1;        // 1 barra = 1h
         g_dpc_nOpp     = 1;        // 1 barra = 1h
         break;

      case PERIOD_H4:
         g_dpc_dcLen    = 20;
         g_dpc_maLen    = 12;       // MA=12×240min=2880min≈2gg
         g_dpc_minWidth = 30.0;     // canali H4 molto ampi
         g_dpc_flatLook = 1;        // 1 barra = 4h lookback
         g_dpc_flatTol  = 0.35;     // tolleranza restrittiva H4 (trend pesanti, filtro forte)
         g_dpc_nSame    = 1;        // 1 barra = 4h
         g_dpc_nOpp     = 1;        // 1 barra = 4h
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

   // Scala minWidth per classe strumento (crypto=25x, indici=5-6x, oil=2x, forex/gold=1x)
   // g_inst_widthFactor è settato da InstrumentPresetsInit() che gira PRIMA di EngineInit()
   if(g_inst_widthFactor > 1.0)
   {
      double origWidth = g_dpc_minWidth;
      g_dpc_minWidth *= g_inst_widthFactor;
      AdLogI(LOG_CAT_ENGINE, StringFormat("DPC minWidth scaled by instrument factor: %.1f × %.1f = %.1f pip",
         origWidth, g_inst_widthFactor, g_dpc_minWidth));
   }

   AdLogI(LOG_CAT_ENGINE, StringFormat("DPC Preset: %s — dcLen=%d maLen=%d minW=%.1f flatL=%d flatT=%.2f nS=%d nO=%d",
      EnumToString(Period()), g_dpc_dcLen, g_dpc_maLen, g_dpc_minWidth,
      g_dpc_flatLook, g_dpc_flatTol, g_dpc_nSame, g_dpc_nOpp));
   return true;
}
