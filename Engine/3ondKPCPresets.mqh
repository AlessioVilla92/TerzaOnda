//+------------------------------------------------------------------+
//|                                        3ondKPCPresets.mqh          |
//|           TerzaOnda EA — KPC Engine TF Auto-Presets              |
//|                                                                  |
//|  Inizializza parametri effettivi (g_kpc_*_eff) in base al TF.    |
//|  Estratto da KeltnerPredictiveChannel.mq5 v1.09 KCPresetsInit(). |
//|                                                                  |
//|  KAMA: parametri canonici Perry Kaufman (period=10, fast=2,      |
//|  slow=30) — non variano per TF, la KAMA si adatta via ER.        |
//|                                                                  |
//|  CHIAMATA: EngineInit(), PRIMA della creazione ATR handle.        |
//+------------------------------------------------------------------+
#property copyright "TerzaOnda (C) 2026"

//+------------------------------------------------------------------+
//| KPC Engine effective parameters (set by preset or input)         |
//+------------------------------------------------------------------+
int    g_kpc_atrPeriod_eff       = 14;
double g_kpc_multiplier_eff      = 2.0;
double g_kpc_halfMultiplier_eff  = 1.0;
int    g_kpc_wprPeriod_eff       = 5;
int    g_kpc_kamaPeriod_eff      = 10;
double g_kpc_erRanging_eff       = 0.25;   // ER < soglia = ranging (colore KAMA)
double g_kpc_erTrending_eff      = 0.60;   // F1: ER > soglia = trending -> BLOCCA
int    g_kpc_dcwPercentile_eff   = 30;     // F2: DCW nel bottom N% = squeeze
double g_kpc_atrRatioThresh_eff  = 0.80;   // Squeeze opzionale: ATR fast/slow
int    g_kpc_minSqueezeBars_eff  = 1;      // F2: barre minime in squeeze
int    g_kpc_nSameBars_eff       = 2;      // Cooldown: barre stesso verso
int    g_kpc_nOppositeBars_eff   = 1;      // Cooldown: barre verso opposto
int    g_kpc_fireCooldown_eff    = 2;      // F4: barre blocco post-breakout
double g_kpc_fireDCWThresh_eff   = 5.0;    // F4: DCW minimo per fire
double g_kpc_minWidthPips_eff    = 10.0;   // F6: canale min pip
double g_kpc_wprOB_eff           = -40.0;  // F5: WPR overbought
double g_kpc_wprOS_eff           = -60.0;  // F5: WPR oversold

//--- Engine control flags (referenced by UI and framework)
bool   g_kpc_useLTFEntry   = false;
bool   g_kpc_ltfOnlyTBS    = true;
int    g_kpc_pendingExpiry  = 8;     // Pending order expiry (bars, TF-aware)

//+------------------------------------------------------------------+
//| KPCPresetsInit — Auto-preset per timeframe                       |
//+------------------------------------------------------------------+
void KPCPresetsInit()
{
   ENUM_TF_PRESET_KC preset = InpKPC_TFPreset;
   if(preset == TF_PRESET_KC_AUTO)
   {
      switch(_Period)
      {
         case PERIOD_M1:  preset = TF_PRESET_KC_M1;     break;
         case PERIOD_M5:  preset = TF_PRESET_KC_M5;     break;
         case PERIOD_M15: preset = TF_PRESET_KC_M15;    break;
         case PERIOD_M30: preset = TF_PRESET_KC_M30;    break;
         case PERIOD_H1:  preset = TF_PRESET_KC_H1;     break;
         default:         preset = TF_PRESET_KC_MANUAL;  break;
      }
   }

   switch(preset)
   {
      case TF_PRESET_KC_M5:
         g_kpc_atrPeriod_eff      = 10;
         g_kpc_multiplier_eff     = 1.5;
         g_kpc_halfMultiplier_eff = 0.75;
         g_kpc_wprPeriod_eff      = 5;
         g_kpc_dcwPercentile_eff  = 30;
         g_kpc_atrRatioThresh_eff = 0.80;
         g_kpc_minSqueezeBars_eff = 2;
         g_kpc_nSameBars_eff      = 2;
         g_kpc_nOppositeBars_eff  = 1;
         g_kpc_fireCooldown_eff   = 2;
         g_kpc_fireDCWThresh_eff  = 5.5;
         g_kpc_minWidthPips_eff   = 10.0;
         g_kpc_erTrending_eff     = 0.60;
         g_kpc_wprOB_eff          = -40.0;
         g_kpc_wprOS_eff          = -60.0;
         g_kpc_pendingExpiry      = 8;      // 8x5min = 40min
         break;

      case TF_PRESET_KC_M15:
         g_kpc_atrPeriod_eff      = 14;
         g_kpc_multiplier_eff     = 2.0;
         g_kpc_halfMultiplier_eff = 1.0;
         g_kpc_wprPeriod_eff      = 5;
         g_kpc_dcwPercentile_eff  = 30;
         g_kpc_atrRatioThresh_eff = 0.80;
         g_kpc_minSqueezeBars_eff = 2;
         g_kpc_nSameBars_eff      = 2;
         g_kpc_nOppositeBars_eff  = 1;
         g_kpc_fireCooldown_eff   = 2;
         g_kpc_fireDCWThresh_eff  = 5.0;
         g_kpc_minWidthPips_eff   = 10.0;
         g_kpc_erTrending_eff     = 0.60;
         g_kpc_wprOB_eff          = -40.0;
         g_kpc_wprOS_eff          = -60.0;
         g_kpc_pendingExpiry      = 3;      // 3x15min = 45min
         break;

      case TF_PRESET_KC_M30:
         g_kpc_atrPeriod_eff      = 14;
         g_kpc_multiplier_eff     = 2.0;
         g_kpc_halfMultiplier_eff = 1.0;
         g_kpc_wprPeriod_eff      = 7;
         g_kpc_dcwPercentile_eff  = 35;
         g_kpc_atrRatioThresh_eff = 0.75;
         g_kpc_minSqueezeBars_eff = 2;
         g_kpc_nSameBars_eff      = 2;
         g_kpc_nOppositeBars_eff  = 1;
         g_kpc_fireCooldown_eff   = 2;
         g_kpc_fireDCWThresh_eff  = 4.5;
         g_kpc_minWidthPips_eff   = 10.0;
         g_kpc_erTrending_eff     = 0.62;
         g_kpc_wprOB_eff          = -40.0;
         g_kpc_wprOS_eff          = -60.0;
         g_kpc_pendingExpiry      = 2;      // 2x30min = 60min
         break;

      case TF_PRESET_KC_H1:
         g_kpc_atrPeriod_eff      = 14;
         g_kpc_multiplier_eff     = 2.0;
         g_kpc_halfMultiplier_eff = 1.0;
         g_kpc_wprPeriod_eff      = 9;
         g_kpc_dcwPercentile_eff  = 35;
         g_kpc_atrRatioThresh_eff = 0.75;
         g_kpc_minSqueezeBars_eff = 2;
         g_kpc_nSameBars_eff      = 1;
         g_kpc_nOppositeBars_eff  = 1;
         g_kpc_fireCooldown_eff   = 2;
         g_kpc_fireDCWThresh_eff  = 4.0;
         g_kpc_minWidthPips_eff   = 10.0;
         g_kpc_erTrending_eff     = 0.65;
         g_kpc_wprOB_eff          = -40.0;
         g_kpc_wprOS_eff          = -60.0;
         g_kpc_pendingExpiry      = PendingExpiryBars;  // H1: da input utente
         break;

      case TF_PRESET_KC_M1:
         g_kpc_atrPeriod_eff      = 7;
         g_kpc_multiplier_eff     = 1.2;
         g_kpc_halfMultiplier_eff = 0.6;
         g_kpc_wprPeriod_eff      = 3;
         g_kpc_dcwPercentile_eff  = 25;
         g_kpc_atrRatioThresh_eff = 0.75;
         g_kpc_minSqueezeBars_eff = 3;
         g_kpc_nSameBars_eff      = 2;
         g_kpc_nOppositeBars_eff  = 1;
         g_kpc_fireCooldown_eff   = 3;
         g_kpc_fireDCWThresh_eff  = 7.0;
         g_kpc_minWidthPips_eff   = 10.0;
         g_kpc_erTrending_eff     = 0.60;
         g_kpc_wprOB_eff          = -40.0;
         g_kpc_wprOS_eff          = -60.0;
         g_kpc_pendingExpiry      = 15;     // 15x1min = 15min
         break;

      default: // MANUAL
         g_kpc_atrPeriod_eff      = InpKPC_ATRPeriod;
         g_kpc_multiplier_eff     = InpKPC_Multiplier;
         g_kpc_halfMultiplier_eff = InpKPC_Multiplier * 0.5;
         g_kpc_wprPeriod_eff      = InpKPC_F5_WPRPeriod;
         g_kpc_dcwPercentile_eff  = InpKPC_F2_Percentile;
         g_kpc_atrRatioThresh_eff = InpKPC_F2_ATRRatio;
         g_kpc_minSqueezeBars_eff = InpKPC_F2_MinSqzBars;
         g_kpc_nSameBars_eff      = InpKPC_NSameBars;
         g_kpc_nOppositeBars_eff  = InpKPC_NOppBars;
         g_kpc_fireCooldown_eff   = 4;
         g_kpc_fireDCWThresh_eff  = 5.0;
         g_kpc_minWidthPips_eff   = InpKPC_F6_MinWidthPip;
         g_kpc_erTrending_eff     = InpKPC_F1_ERTrending;
         g_kpc_wprOB_eff          = (double)InpKPC_F5_OB;
         g_kpc_wprOS_eff          = (double)InpKPC_F5_OS;
         break;
   }

   // KAMA params — always Perry Kaufman canonical
   g_kpc_kamaPeriod_eff = InpKPC_KAMA_ER;
   g_kpc_erRanging_eff  = InpKPC_F1_ERRanging;

   // Width factor from instrument config
   g_kpc_minWidthPips_eff *= g_inst_widthFactor;

   // LTF entry flags
   g_kpc_useLTFEntry = InpKPC_UseLTFEntry;
   g_kpc_ltfOnlyTBS  = InpKPC_LTFOnlyPrimary;
}
