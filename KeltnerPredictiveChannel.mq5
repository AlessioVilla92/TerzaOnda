//+------------------------------------------------------------------+
//| KeltnerPredictiveChannel.mq5                                     |
//| Keltner Predictive Channel - Mean-Reversion Orchestrator         |
//| Based on DonchianPredictiveChannel v7.19 structure                |
//| Developed by TIVANIO                                              |
//+------------------------------------------------------------------+
//
//  PRINCIPIO OPERATIVO (Mean-Reversion su Keltner Channel):
//  ═══════════════════════════════════════════════════════
//  Segnala rimbalzi quando il prezzo respinge una banda KC con wick di rejection.
//
//  CONDIZIONE BASE (sufficiente per il segnale):
//    ✓ Il prezzo BUCA la banda KC (high > upper o low < lower)
//    ✓ Il prezzo CHIUDE DENTRO la banda (rejection confermata)
//    ✓ Lo stoppino di rifiuto è ≥ 25% della candela (InpWickRatio)
//  Il TP target è la KAMA (mediana adattiva del canale).
//
//  FILTRI ATTIVI (safety net con parametri larghi — v1.05):
//    F1 ER Regime  (ON)  — blocca solo trend estremi (ER > 0.60)
//    F2 Squeeze    (ON)  — richiede minima compressione (1-2 barre)
//    F4 Fire       (ON)  — blocco breakout rapido (2 barre cooldown)
//    F6 Width      (ON)  — canale min 10 pip = TP min ~5 pip (tutti i TF)
//
//  FILTRI DISATTIVATI (ridondanti — v1.05):
//    F3 DCW Slope  (OFF) — coperto da F2 decay + F4 spike
//    F5 Williams%R (OFF) — ~90% correlato con band touch + F1
//    F7 Time Block (OFF) — preferenza utente
//
//  Tutti i filtri togglabili in real-time dalla dashboard.
//
//  COMPONENTI VISIVE:
//    - KAMA midline (colore adattivo: verde=up, rosso=down, grigio=range)
//    - Bande Primary (moltiplicatore pieno) e Half (metà moltiplicatore)
//    - Fill colorato tra bande Primary
//    - Frecce SELL (rosse) e BUY (verdi), Primary (grandi) e Half (piccole)
//    - Candele trigger colorate (evidenziano la barra del segnale)
//    - TP target lines (linea tratteggiata sulla KAMA con pallino)
//    - Entry dots (punto d'ingresso sulla banda)
//    - Dashboard interattiva con toggle filtri e visuals
//
//  CHANGELOG:
//    v1.09 — VERIFICA STABILITÀ + FIX COMMENTI:
//            Verifica completa post v1.06/v1.07/v1.08:
//              tutti i fix grafici (dashboard, anti-flash, canvas throttle,
//              ObjectsDeleteAll) confermati integri e compatibili.
//            Logica segnali (Fasi 1-4) invariata — nessun impatto funzionale.
//            Fix commento "8 filtri" → "7 filtri" (F8 rimosso in v1.08).
//            Fix soglie F1 nel commento: 0.40 → 0.60 (allineato a v1.05 preset).
//    v1.08 — RIMOZIONE F8 SESSION FILTER:
//            Rimossi: InpUseSessionFilter, InpSessionStart, InpSessionEnd,
//              g_sessionStartMin/EndMin, g_dash_F8_session, IsOutsideSession(),
//              bottone dashboard F8, toggle OnChartEvent F8.
//            Motivazione: filtro sempre OFF di fatto (dashboard forzava false),
//              mai attivato in produzione — codice morto eliminato.
//            Dashboard: 13 bottoni (7 filtri + 6 visuals) da 14.
//    v1.07 — DUAL TP SYSTEM:
//            ── TP1: KAMA Midline (fisso) ──
//            Prezzo KAMA congelato al momento del segnale (come prima).
//              Parametri dedicati: InpEnableTP1, InpShowTP1Line, InpColTP1Buy/Sell, InpTP1Expiry.
//              CalcTPConservative() preservato per offset pip verso entry.
//            ── TP2: Touch Banda Opposta (dinamico) ──
//            Nuovo target: prezzo raggiunge la banda KC opposta (upper per BUY, lower per SELL).
//              La linea TP2 si aggiorna ogni barra seguendo la banda corrente.
//              Guardia minProfitLevel: close deve superare bandLevel ± InpTP2MinProfitPips.
//              Fire kill switch: TP2 annullato automaticamente se g_fireActive (breakout).
//              Expiry breve: InpTP2MaxExpiry=20 barre (non lascia target fantasma).
//              Parametri: InpEnableTP2, InpShowTP2Line, InpColTP2Buy/Sell, InpTP2MinProfitPips.
//            ── Struct TPTargetInfo estesa ──
//            +tp_type (1=TP1, 2=TP2), +minProfitLevel, +entryBandLevel.
//            ── Section 4.6 riscritta ──
//            Loop dual TP: hit/update/expiry differenziati per tipo.
//            CloseTPTarget: tooltip e colori distinti TP1/TP2.
//            ── Retrocompatibilità ──
//            Buffer EA (26/27) invariati. 28 buffer/12 plot invariati.
//            Vecchi param rimossi: InpShowTPTargetLine, InpColTPTargetBuy/Sell, InpTPTargetExpiry.
//    v1.06 — ROBUSTEZZA GRAFICA + PERFORMANCE TF SWITCH:
//            ── Dashboard immediata ──
//            UpdateKPCDashboard(true) in OnInit + pre-return OnCalculate:
//              la dashboard appare subito senza attendere CopyBuffer (iATR).
//            ── Anti-flash tema ──
//            GlobalVariableSet/Get per persistere colori originali chart tra
//              istanze (TF switch). Skip restore per REASON_CHARTCHANGE:
//              elimina flash scuro→chiaro→scuro al cambio timeframe.
//            ── Performance ObjectsDeleteAll ──
//            DeleteSignal/TP/EntryDot Objects: loop manuale → ObjectsDeleteAll.
//              Prefix matching nativo C++ (10-15× più veloce su 200+ oggetti).
//            ── Canvas throttle ──
//            RedrawCanvas(force): max 10 FPS da tick, immediato da user scroll.
//              ChartTimePriceToXY dedup: 6→4 calls per coppia barre visibili.
//            (Session filter F8 rimosso in v1.07)
//    v1.05 — RISTRUTTURAZIONE FILTRI: analisi ridondanza completa.
//            Filosofia: parametri larghi come "safety net" invece di filtri rigidi.
//            ── Filtri mantenuti ON con soglie permissive ──
//            F1 ER: soglia alzata a 0.60-0.65 (era 0.35-0.45).
//              Permette segnali in trend moderato, blocca solo trend estremi.
//            F2 Squeeze: minBars ridotto a 1-2 (era 3-10).
//              Qualsiasi compressione recente è sufficiente (decay già smart).
//            F4 Fire: cooldown ridotto a 2-3 barre (era 4-8).
//              Protezione breakout minima senza blocco prolungato.
//            F6 Width: canale min 10 pip per TUTTI i TF (TP min ~5 pip).
//              Logica DPC v7.19: misura (upper-lower) in pip, blocca se troppo stretto.
//              NOTA: rapporto ATR non funziona per KC (upper-KAMA = mult×ATR = costante).
//            ── Filtri disattivati (OFF default) ──
//            F3 DCW Slope: RIDONDANTE — espansione graduale catturata da F2 decay,
//              espansione esplosiva catturata da F4 fire.
//            F5 WPR: RIDONDANTE — il prezzo alla banda è già overbought/oversold
//              per definizione (~90%), il wick ratio conferma già il momentum,
//              i casi residui sono coperti da F1 (ER).
//            F7: preferenza utente, non qualità segnale. (F8 rimosso in v1.07)
//            ── Fix bug ──
//            Fire block hardcoded (riga cooldown): era SEMPRE attivo anche con F4 OFF.
//              Fix: condizionato a g_dash_F4_fire per rispettare toggle dashboard.
//            ── Parametri base ──
//            InpWickRatio: 0.40 → 0.25 (più candele qualificate come rejection).
//            DCW Percentile: 15-25 → 25-35 (squeeze si attiva prima).
//            WPR zone: -25/-75 → -40/-60 (raddoppiate, per i TF dove F5 è attivato).
//            Cooldown: same 2-5→2, opposite 1-3→1 (meno anti-spam).
//    v1.04 — FIX CRITICO: DCW percentile invertito dalla v1.00.
//            g_dcwRing[r] > BufDCW[i] contava valori SOPRA il corrente,
//            ma il confronto < 0.20 trattava il risultato come "bottom 20%".
//            Effetto: squeeze rilevata durante ALTA volatilità (opposto).
//            Fix: cambiato > in < → ora percentile = valori SOTTO il corrente.
//            Squeeze attiva correttamente quando DCW è nel bottom 20%.
//            Dashboard con toggle ON/OFF per 8 filtri + 6 visuals.
//    v1.03 — SimpleCooldown: rimosso SmartCooldown (MidTouch gate troppo restrittivo).
//            Nuova logica: N barre fisso stesso verso, M barre verso opposto (da preset).
//            Fire per TF: g_kc_fireDCWThresh_eff impostato per TF nel switch preset.
//            TP conservativo: InpTPConservativePips via CalcTPConservative().
//            ATR Ratio opzionale: InpUseATRRatioFilter (default=false).
//            Preset M1: aggiunto TF_PRESET_KC_M1.
//    v1.02 — Fix critico buffer-to-plot mapping:
//            BufFillLow e BufSqueezeHistColor da DATA → CALCULATIONS
//            (buffer DATA extra shiftavano il mapping: BufFillLow veniva
//            assegnato a Plot 6 DRAW_ARROW → frecce rosse su ogni barra)
//    v1.01 — Fix DRAW_COLOR_HISTOGRAM in chart_window (→ DRAW_NONE)
//            MinTPDistPips per-TF preset (M30=6.0, H1=8.0)
//    v1.00 — Creazione iniziale da DPC v7.19
//
//  BUFFER EA (CopyBuffer):
//    17: BufFillLow         — fill lower per CCanvas
//    18: BufSqueezeHistColor — colore squeeze (0=norm, 1=squeeze, 2=fire)
//    19: BufERValue         — Efficiency Ratio (0.0-1.0)
//    20: BufSqueezeState    — 1.0=squeeze attiva, 0.0=libero
//    21: BufFireSignal      — +1=fire bull, -1=fire bear, 0=nessuno
//    22: BufWPR             — Williams %R (-100..0)
//    23: BufDCW             — DCW normalizzato (larghezza/ATR)
//    24: BufATRRatio        — ATR fast/slow ratio
//    25: BufATR             — ATR(N) interno
//    26: BufEASigBuy        — +1.0=Primary, 0.5=Half, 0=nessun segnale
//    27: BufEASigSell       — +1.0=Primary, 0.5=Half, 0=nessun segnale
//
#property copyright   "TIVANIO - Keltner Predictive Channel v1.09"
#property version     "1.09"   // v1.09: verifica stabilità completa, fix commenti obsoleti
#property description "KC Mean-Reversion Orchestrator: KAMA + Keltner Channel + Anti-Fire Squeeze Timing"
#property description "Segnali BUY/SELL su band rejection con wick ratio, ER regime filter, squeeze state"
#property description "Dual TP: TP1 KAMA midline (fisso) + TP2 banda opposta (dinamico) con hit/miss tracking"
#property indicator_chart_window
#property indicator_buffers 28
#property indicator_plots   12

//--- Plot 0: KAMA Midline (3 colori: verde=bull, rosso=bear, grigio=ranging)
#property indicator_label1  "KAMA"
#property indicator_type1   DRAW_COLOR_LINE
#property indicator_color1  clrLime,clrRed,clrGray
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Plot 1: Upper Primary Band
#property indicator_label2  "Upper Primary"
#property indicator_type2   DRAW_LINE
#property indicator_color2  C'70,130,180'
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

//--- Plot 2: Lower Primary Band
#property indicator_label3  "Lower Primary"
#property indicator_type3   DRAW_LINE
#property indicator_color3  C'70,130,180'
#property indicator_style3  STYLE_SOLID
#property indicator_width3  1

//--- Plot 3: Upper Half Band
#property indicator_label4  "Upper Half"
#property indicator_type4   DRAW_LINE
#property indicator_color4  C'100,149,237'
#property indicator_style4  STYLE_DOT
#property indicator_width4  1

//--- Plot 4: Lower Half Band
#property indicator_label5  "Lower Half"
#property indicator_type5   DRAW_LINE
#property indicator_color5  C'100,149,237'
#property indicator_style5  STYLE_DOT
#property indicator_width5  1

//--- Plot 5: Fill between Primary bands (CCanvas, DRAW_NONE placeholder)
#property indicator_label6  "KC Fill"
#property indicator_type6   DRAW_NONE
#property indicator_color6  clrDodgerBlue

//--- Plot 6: SELL Primary Arrow
#property indicator_label7  "Sell Primary"
#property indicator_type7   DRAW_ARROW
#property indicator_color7  clrRed
#property indicator_width7  5

//--- Plot 7: BUY Primary Arrow
#property indicator_label8  "Buy Primary"
#property indicator_type8   DRAW_ARROW
#property indicator_color8  clrLime
#property indicator_width8  5

//--- Plot 8: SELL Half Arrow
#property indicator_label9  "Sell Half"
#property indicator_type9   DRAW_ARROW
#property indicator_color9  C'180,60,60'
#property indicator_width9  3

//--- Plot 9: BUY Half Arrow
#property indicator_label10 "Buy Half"
#property indicator_type10  DRAW_ARROW
#property indicator_color10 C'0,160,90'
#property indicator_width10 3

//--- Plot 10: Candele trigger (4 colori: bull/bear/trigger_primary/trigger_half)
#property indicator_label11 "Candles"
#property indicator_type11  DRAW_COLOR_CANDLES
#property indicator_color11 C'38,166,154',C'239,83,80',clrYellow,clrOrange
#property indicator_style11 STYLE_SOLID
#property indicator_width11 1

//--- Plot 11: Squeeze State (DRAW_NONE — dati solo per EA via CopyBuffer)
//    DRAW_COLOR_HISTOGRAM NON usabile in indicator_chart_window:
//    disegna da prezzo 0 al valore, schiacciando il chart e creando
//    barre rosse visibili nella zona prezzo. Squeeze state visibile
//    tramite colore KAMA (grigio=ranging) e buffer EA (20/21).
#property indicator_label12 "Squeeze"
#property indicator_type12  DRAW_NONE
#property indicator_color12 clrNONE

//+------------------------------------------------------------------+
//| Includes                                                         |
//+------------------------------------------------------------------+
#include <Canvas/Canvas.mqh>

//+------------------------------------------------------------------+
//| Enums                                                            |
//+------------------------------------------------------------------+
enum ENUM_TRIGGER_MODE_V2
{
   TRIGGER_INTRABAR   = 0,  // Intrabar (segnale immediato — repaints)
   TRIGGER_BAR_CLOSE  = 1   // Chiusura Barra (zero repaint, raccomandato)
};

enum ENUM_TF_PRESET_KC
{
   TF_PRESET_KC_AUTO   = 0,  // AUTO — rileva TF dal chart (raccomandato)
   TF_PRESET_KC_M1     = 6,  // M1 — solo per entry di precisione su segnale HTF
   TF_PRESET_KC_M5     = 1,  // M5
   TF_PRESET_KC_M15    = 2,  // M15
   TF_PRESET_KC_M30    = 3,  // M30
   TF_PRESET_KC_H1     = 4,  // H1
   TF_PRESET_KC_MANUAL = 5   // MANUALE — tutti i parametri dall'utente
};

//+------------------------------------------------------------------+
//| INPUTS — Organizzati per modulo (stile DPC v7.19)                |
//+------------------------------------------------------------------+

input group "                                                               "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  📊 KELTNER PREDICTIVE CHANNEL                           ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input ENUM_TF_PRESET_KC InpTFPreset   = TF_PRESET_KC_AUTO;  // ⚙ Preset Timeframe
input int    InpKAMA_ER    = 10;    // Periodo KAMA ER (Perry Kaufman)
input int    InpKAMA_Fast  = 2;     // KAMA Fast SC
input int    InpKAMA_Slow  = 30;    // KAMA Slow SC
input int    InpATRPeriod  = 14;    // ATR Period (auto-preset)
input double InpMultiplier = 2.0;   // KC Multiplier Primary (auto-preset)
input bool   InpShowHalf   = true;  // Mostra Bande Half

input group "                                                               "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  ⚡ TRIGGER E SEGNALI                                    ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input ENUM_TRIGGER_MODE_V2 InpTriggerModeV2 = TRIGGER_BAR_CLOSE;  // Modalità Trigger
input double InpWickRatio       = 0.25;  // Wick Ratio minimo (0.25 = 25%)
input double InpArrowOffsetMult = 1.5;   // Distanza Frecce (x EMA ATR)

input group "    🔄 COOLDOWN"
input int    InpNSameBars   = 2;   // Cooldown stesso verso (barre, auto-preset)
input int    InpNOppositeBars = 1; // Cooldown verso opposto (barre, auto-preset)

input group "                                                               "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  🛡️ FILTRI QUALITÀ SEGNALE                               ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    📊 REGIME FILTER (Efficiency Ratio)"
input double InpERRanging  = 0.25;  // ER < soglia = Ranging (MR abilitata)
input double InpERTrending = 0.40;  // ER > soglia = Trending (segnali bloccati)

input group "    🔥 SQUEEZE STATE (DCW + ATR Ratio)"
input int    InpDCWLookback     = 100;  // DCW Lookback (barre per percentile)
input int    InpDCWPercentile   = 20;   // DCW Percentile soglia (auto-preset)
input int    InpATRFastPeriod   = 5;    // ATR Fast Period
input int    InpATRSlowPeriod   = 20;   // ATR Slow Period
input double InpATRRatioThresh  = 0.80; // ATR Ratio Threshold (auto-preset)
input int    InpMinSqueezeBars  = 4;    // Barre Minime Squeeze (auto-preset)
input bool   InpUseATRRatioFilter = false;  // AND ATR Ratio nella squeeze (false=solo DCW percentile)

input group "    📉 MOMENTUM (Williams %R)"
input bool   InpUseMomentum = true;  // Abilita Filtro Williams %R
input int    InpWPRPeriod   = 5;     // Williams %R Period (auto-preset)
input double InpWPR_OB      = -20.0; // Overbought threshold (SELL)
input double InpWPR_OS      = -80.0; // Oversold threshold (BUY)

input group "    📏 CHANNEL WIDTH (larghezza minima TP in pip)"
input bool   InpUseWidthFilter = true;  // Abilita Width Minima TP
input double InpMinWidthPips   = 10.0;  // Larghezza minima canale (pip) — 10 pip = TP min ~5 pip

input group "                                                               "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  🕐 FILTRO ORARIO E SESSIONE                             ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    ⏰ BLOCCO ORARIO"
input bool   InpUseTimeFilter    = false;  // Abilita Blocco Orario
input string InpTimeBlockStart   = "15:20"; // Inizio Blocco (HH:MM locale)
input string InpTimeBlockEnd     = "16:20"; // Fine Blocco (HH:MM locale)
input int    InpBrokerOffset     = 1;       // Differenza Broker - Tuo Orario (ore)

input group "                                                               "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  🎨 COLORI E STILE                                       ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    📐 KAMA MIDLINE"
input color  InpColKAMAUp         = clrLime;           // KAMA Bull (trending up)
input color  InpColKAMADn         = clrRed;            // KAMA Bear (trending down)
input color  InpColKAMARanging    = clrGray;           // KAMA Ranging

input group "    📐 BANDE KELTNER"
input color  InpColBandPrimary    = C'70,130,180';     // Bande Primary
input color  InpColBandHalf       = C'100,149,237';    // Bande Half
input color  InpColFill           = clrDodgerBlue;     // Colore Sfondo KC
input int    InpFillAlpha         = 30;                // Trasparenza Sfondo (0-255)

input group "    📐 FRECCE SEGNALE"
input color  InpColSignalSellPrim = clrRed;            // Freccia SELL Primary
input color  InpColSignalBuyPrim  = clrLime;           // Freccia BUY Primary
input color  InpColSignalSellHalf = C'180,60,60';      // Freccia SELL Half
input color  InpColSignalBuyHalf  = C'0,160,90';       // Freccia BUY Half

input group "    🔦 CANDELA TRIGGER"
input bool   InpShowTriggerCandle = true;              // Evidenzia Candela Trigger
input color  InpColTriggerPrimary = clrYellow;         // Colore Trigger Primary
input color  InpColTriggerHalf    = clrOrange;         // Colore Trigger Half

input group "                                                               "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  🎯 TP VISIVO (Backtest Grafico)                         ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    📏 TP1 — KAMA Midline (fisso al segnale)"
input bool   InpEnableTP1         = true;          // [TP1] Abilita TP1 — KAMA midline
input bool   InpShowTP1Line       = true;          // [TP1] Mostra linea visiva
input color  InpColTP1Buy         = clrLime;       // [TP1] Colore linea BUY
input color  InpColTP1Sell        = clrRed;        // [TP1] Colore linea SELL
input int    InpTP1Expiry         = 300;           // [TP1] Scadenza (barre, 0=mai)
input double InpTPConservativePips = 1.0;          // [TP1] TP conservativo: pip verso entry (0=KAMA esatta)

input group "    🎯 TP2 — Touch Banda Opposta (dinamico)"
input bool   InpEnableTP2         = true;                // [TP2] Abilita TP2 — touch banda opposta
input bool   InpShowTP2Line       = true;                // [TP2] Mostra linea visiva
input color  InpColTP2Buy         = clrAqua;             // [TP2] Colore linea BUY
input color  InpColTP2Sell        = C'255,165,0';        // [TP2] Colore linea SELL (arancione)
input double InpTP2MinProfitPips  = 3.0;                 // [TP2] Profitto minimo richiesto (pip)
input int    InpTP2MaxExpiry      = 20;                  // [TP2] Max barre prima expiry forzata

input group "    🔵 ENTRY DOT (Punto di Ingresso)"
input bool   InpShowEntryDot      = true;     // Mostra Pallino Entry
input color  InpColEntryDot       = clrDodgerBlue; // Colore Pallino Entry

input group "    🔥 SQUEEZE VISUALIZATION"
input bool   InpShowSqueezeHist   = true;     // Mostra Histogram Squeeze
input color  InpColSqueezeNormal  = clrGray;  // Normale (no squeeze)
input color  InpColSqueezeActive  = clrRed;   // Squeeze Attiva
input color  InpColFireDetected   = clrLime;  // Fire Rilevato

input group "                                                               "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  🎭 TEMA CHART                                           ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input bool   InpApplyChartTheme   = true;          // Applica Tema Scuro
input bool   InpShowGrid          = false;         // Mostra Griglia

input group "    🎨 COLORI TEMA"
input color  InpThemeBG           = C'19,23,34';   // Sfondo Chart
input color  InpThemeFG           = C'131,137,150'; // Testo, Assi
input color  InpThemeGrid         = C'42,46,57';    // Griglia
input color  InpThemeBullCandle   = C'38,166,154';  // Candela Rialzista
input color  InpThemeBearCandle   = C'239,83,80';   // Candela Ribassista

input group "                                                               "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  🔔 NOTIFICHE E ALERT                                    ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input bool   InpAlertPopup  = true;    // Popup Alert

input group "                                                               "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  🔧 DEBUG                                                ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input bool   InpDebugMode   = false;   // Debug: Mostra nel Journal
input string InpInstanceID  = "";      // ID Istanza (per multi-chart)

//+------------------------------------------------------------------+
//| Buffer declarations (28 buffers — PARTE E)                       |
//+------------------------------------------------------------------+
// INDICATOR_DATA / COLOR_INDEX (17 buffer visibili → 12 plot)
//
// MQL5 assegna i buffer ai plot SEQUENZIALMENTE in base al tipo di plot:
//   DRAW_COLOR_LINE=2, DRAW_LINE=1, DRAW_NONE=1, DRAW_ARROW=1,
//   DRAW_COLOR_CANDLES=5. Totale 12 plot = 17 buffer visibili.
//   OGNI buffer INDICATOR_DATA/COLOR_INDEX extra shifta il mapping!
//
double BufKAMA[];              //  0  Plot 0: KAMA midline (DRAW_COLOR_LINE)
double BufKAMAColor[];         //  1  Plot 0: color index (0=green,1=red,2=gray)
double BufUpperPrimary[];      //  2  Plot 1: banda superiore Primary
double BufLowerPrimary[];      //  3  Plot 2: banda inferiore Primary
double BufUpperHalf[];         //  4  Plot 3: banda superiore Half
double BufLowerHalf[];         //  5  Plot 4: banda inferiore Half
double BufFillHigh[];          //  6  Plot 5: fill upper (DRAW_NONE — per CCanvas)
double BufSigSellPrim[];       //  7  Plot 6: freccia SELL Primary (DRAW_ARROW)
double BufSigBuyPrim[];        //  8  Plot 7: freccia BUY Primary
double BufSigSellHalf[];       //  9  Plot 8: freccia SELL Half
double BufSigBuyHalf[];        // 10  Plot 9: freccia BUY Half
double BufCandleO[];           // 11  Plot 10: OHLC Open (DRAW_COLOR_CANDLES)
double BufCandleH[];           // 12  Plot 10: High
double BufCandleL[];           // 13  Plot 10: Low
double BufCandleC[];           // 14  Plot 10: Close
double BufCandleColor[];       // 15  Plot 10: colore candela
double BufSqueezeHist[];       // 16  Plot 11: squeeze data (DRAW_NONE)

// INDICATOR_CALCULATIONS (11 buffer per EA — leggibili con CopyBuffer)
double BufFillLow[];           // 17: fill lower (per CCanvas, NON un plot — come DPC BufFillDn)
double BufSqueezeHistColor[];  // 18: squeeze color (dato per EA, non plot)
double BufERValue[];           // 19: ER corrente (0.0-1.0)
double BufSqueezeState[];      // 20: squeeze state (1.0=squeeze, 0.0=libero)
double BufFireSignal[];        // 21: fire direction (+1/-1/0)
double BufWPR[];               // 22: Williams %R
double BufDCW[];               // 23: DCW normalizzato
double BufATRRatio[];          // 24: ATR fast/slow ratio
double BufATR[];               // 25: ATR interno
double BufEASigBuy[];          // 26: EA BUY signal (+1=Primary, 0.5=Half, 0=none)
double BufEASigSell[];         // 27: EA SELL signal

//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+
//--- Indicator handles
int    g_atrHandle = INVALID_HANDLE;

//--- Signal state & SimpleCooldown
int    g_lastMarkerBar   = 0;
int    g_lastDirection   = 0;       // +1=BUY, -1=SELL, 0=nessuno
int    g_nSameBars       = 2;
int    g_nOppositeBars   = 1;

//--- Time filter
int    g_timeBlockStartMin = 0;
int    g_timeBlockEndMin   = 0;

//--- Effective preset globals (g_kc_*_eff)
//    Sovrascrirti per TF nel switch preset in OnInit().
//    v1.05: tutti i parametri filtro impostati come "safety net" larghi.
//    Filosofia: bloccare solo i casi estremi, non filtrare aggressivamente.
int    g_kc_atrPeriod_eff       = 14;
double g_kc_multiplier_eff      = 2.0;
double g_kc_halfMultiplier_eff  = 1.0;
int    g_kc_wprPeriod_eff       = 5;
int    g_kc_kamaPeriod_eff      = 10;
double g_kc_erRanging_eff       = 0.25;  // ER < soglia = ranging (usato per colore KAMA)
double g_kc_erTrending_eff      = 0.60;  // F1: ER > soglia = trending → BLOCCA (v1.05: era 0.40)
int    g_kc_dcwPercentile_eff   = 30;    // F2: DCW nel bottom N% = squeeze (v1.05: era 20)
double g_kc_atrRatioThresh_eff  = 0.80;  // Squeeze opzionale: ATR fast/slow ratio
int    g_kc_minSqueezeBars_eff  = 1;     // F2: barre minime in squeeze (v1.05: era 4)
int    g_kc_nSameBars_eff       = 2;     // Cooldown: barre tra segnali stesso verso
int    g_kc_nOppositeBars_eff   = 1;     // Cooldown: barre tra segnali verso opposto
int    g_kc_fireCooldown_eff    = 2;     // F4: barre blocco post-breakout (v1.05: era 4)
double g_kc_fireDCWThresh_eff   = 5.0;   // F4: DCW minimo per attivare fire
double g_kc_minWidthPips_eff    = 10.0;  // F6: canale min 10 pip = TP min ~5 pip per tutti i TF
double g_kc_wprOB_eff           = -40.0; // F5: WPR overbought (v1.05: era -20, OFF default)
double g_kc_wprOS_eff           = -60.0; // F5: WPR oversold (v1.05: era -80, OFF default)

//--- Squeeze state
int    g_squeezeBarsCount       = 0;
bool   g_squeezeWasActive       = false;
bool   g_fireActive             = false;
int    g_fireCooldownRemaining  = 0;

//--- DCW ring buffer for percentile
double g_dcwRing[];
int    g_dcwRingIdx    = 0;
bool   g_dcwRingFilled = false;

//--- Chart theme
color  g_origBG          = clrBlack;
color  g_origFG          = clrWhite;
color  g_origGrid        = clrGray;
color  g_origChartUp     = clrBlack;
color  g_origChartDown   = clrBlack;
color  g_origChartLine   = clrBlack;
color  g_origCandleBull  = clrWhite;
color  g_origCandleBear  = clrBlack;
color  g_origBid         = clrGray;
color  g_origAsk         = clrGray;
color  g_origVolume      = clrGray;
bool   g_origShowGrid    = true;
int    g_origShowVolumes = 0;
bool   g_origForeground  = true;
bool   g_chartThemeApplied = false;

//--- Touch Trigger tracking (Fix #1)
int      g_lastTouchDirection    = 0;
datetime g_lastTouchTriggerBar   = 0;
datetime g_prevBarTimeTT         = 0;

//--- TP tracking
double   g_lastSignalPrice       = 0;
double   g_lastSignalBandPrice   = 0;
datetime g_lastSignalTime        = 0;

//--- TP Target multi-target
struct TPTargetInfo
{
   string   lineName;
   string   dotName;
   double   price;          // TP1: KAMA congelata | TP2: 0.0 (non usato, check è dinamico)
   bool     isBuy;
   datetime signalTime;
   double   signalPrice;
   int      tp_type;        // 1=TP1 (KAMA midline fisso), 2=TP2 (banda opposta dinamica)
   double   minProfitLevel; // TP2: soglia close minima per exit (entryBandPrice ± buffer)
   double   entryBandLevel; // TP2: prezzo banda di entry (upper/lower al momento segnale)
};
TPTargetInfo g_activeTPTargets[];
int    g_tpTargetCounter = 0;
int    g_tpHitCounter    = 0;

//--- Entry Dot
int    g_entryDotCounter = 0;

//--- Computational arrays
double g_emaATR[];

//--- Object name prefixes
string SIGNAL_PREFIX;
string TP_TARGET_PREFIX;
string TP_TGTDOT_PREFIX;
string ENTRY_DOT_PREFIX;
string CANVAS_NAME;

//--- Canvas
CCanvas  g_canvas;
bool     g_canvasCreated = false;

//--- Alert deduplication
datetime s_lastAlertBar = 0;

//--- Dashboard toggle states (v1.05)
//    Filtri: ON=filtro attivo (blocca segnali), OFF=filtro disattivato (più segnali)
//    v1.05: solo F1/F2/F4/F6 ON default (assi indipendenti), F3/F5 OFF (ridondanti)
bool   g_dash_F1_erRegime  = true;   // F1: ER Regime — ESSENZIALE: blocca segnali MR in trend forti
bool   g_dash_F2_squeeze   = true;   // F2: Squeeze Duration — safety net: richiede minima compressione
bool   g_dash_F3_dcwSlope  = false;  // F3: DCW Slope — RIDONDANTE con F2+F4, eliminato
bool   g_dash_F4_fire      = true;   // F4: Fire Kill Switch — safety net: protezione breakout rapida
bool   g_dash_F5_wpr       = false;  // F5: Williams %R — RIDONDANTE con Base+F1, eliminato
bool   g_dash_F6_width     = true;   // F6: Width Minima TP — safety net: blocca canali assurdi (<1 pip)
bool   g_dash_F7_time      = false;  // F7: Time Block — preferenza utente, OFF default
//    Visuals: ON=visibile, OFF=nascosto
bool   g_dash_vis_kama     = true;   // KAMA midline
bool   g_dash_vis_bands    = true;   // Bande Primary
bool   g_dash_vis_half     = true;   // Bande Half
bool   g_dash_vis_fill     = true;   // KC Fill (CCanvas)
bool   g_dash_vis_arrows   = true;   // Frecce segnale
bool   g_dash_vis_candles  = true;   // Candele trigger
//--- Dashboard objects
string KPC_DASH_PREFIX;
#define KPC_DASH_MAX_ROWS 30
//--- Force recalculation flag (set by dashboard toggle, read by OnCalculate)
bool   g_forceRecalc = false;

//+------------------------------------------------------------------+
//| KCPresetsInit — Inizializzazione preset parametri per Timeframe  |
//|                                                                    |
//| SCOPO: Seleziona automaticamente i parametri operativi ottimali   |
//|   per il TF corrente del chart. Ogni TF ha volatilità diversa:    |
//|   M5 usa bande strette (mult=1.5) e squeeze lunga (5 barre),     |
//|   H1 usa bande larghe (mult=2.0) e squeeze corta (3 barre).      |
//|                                                                    |
//| AUTO DETECTION: se InpTFPreset=AUTO, rileva _Period e mappa al    |
//|   preset corrispondente. TF non mappati (M1,H4,D1) → MANUAL.     |
//|                                                                    |
//| PARAMETRI SETTATI (12 variabili g_kc_*_eff):                      |
//|   - atrPeriod, multiplier, halfMultiplier (canale KC)             |
//|   - wprPeriod (momentum Williams %R)                              |
//|   - dcwPercentile, atrRatioThresh, minSqueezeBars (squeeze L3)   |
//|   - nSameBars, nOppositeBars (SimpleCooldown)                      |
//|   - fireCooldown (kill switch post-squeeze)                       |
//|   - minTPDistPips (distanza minima TP per filtro width)           |
//|                                                                    |
//| KAMA: parametri canonici Perry Kaufman (period=10, fast=2, slow=30)|
//|   Non variano per TF — la KAMA si adatta da sola via ER.          |
//|                                                                    |
//| CHIAMATA: OnInit(), PRIMA della creazione ATR handle (il periodo  |
//|   ATR dipende dal preset: 10 per M5, 14 per M15/M30/H1).          |
//+------------------------------------------------------------------+
void KCPresetsInit()
{
   ENUM_TF_PRESET_KC preset = InpTFPreset;
   if(preset == TF_PRESET_KC_AUTO)
   {
      switch(_Period)
      {
         case PERIOD_M1:  preset = TF_PRESET_KC_M1;  break;
         case PERIOD_M5:  preset = TF_PRESET_KC_M5;  break;
         case PERIOD_M15: preset = TF_PRESET_KC_M15; break;
         case PERIOD_M30: preset = TF_PRESET_KC_M30; break;
         case PERIOD_H1:  preset = TF_PRESET_KC_H1;  break;
         default:         preset = TF_PRESET_KC_MANUAL; break;
      }
   }

   switch(preset)
   {
      case TF_PRESET_KC_M5:
         g_kc_atrPeriod_eff      = 10;
         g_kc_multiplier_eff     = 1.5;
         g_kc_halfMultiplier_eff = 0.75;
         g_kc_wprPeriod_eff      = 5;
         g_kc_dcwPercentile_eff  = 30;
         g_kc_atrRatioThresh_eff = 0.80;
         g_kc_minSqueezeBars_eff = 2;
         g_kc_nSameBars_eff      = 2;
         g_kc_nOppositeBars_eff  = 1;
         g_kc_fireCooldown_eff   = 2;
         g_kc_fireDCWThresh_eff  = 5.5;
         g_kc_minWidthPips_eff   = 10.0;            // M5: canale min 10 pip → TP min ~5 pip
         g_kc_erTrending_eff     = 0.60;          // M5: permissivo per trend moderato
         g_kc_wprOB_eff          = -40.0;          // M5: WPR zone molto allargate
         g_kc_wprOS_eff          = -60.0;          // M5: WPR zone molto allargate
         break;
      case TF_PRESET_KC_M15:
         g_kc_atrPeriod_eff      = 14;
         g_kc_multiplier_eff     = 2.0;
         g_kc_halfMultiplier_eff = 1.0;
         g_kc_wprPeriod_eff      = 5;
         g_kc_dcwPercentile_eff  = 30;
         g_kc_atrRatioThresh_eff = 0.80;
         g_kc_minSqueezeBars_eff = 2;
         g_kc_nSameBars_eff      = 2;
         g_kc_nOppositeBars_eff  = 1;
         g_kc_fireCooldown_eff   = 2;
         g_kc_fireDCWThresh_eff  = 5.0;
         g_kc_minWidthPips_eff   = 10.0;            // M15: canale min 10 pip → TP min ~5 pip
         g_kc_erTrending_eff     = 0.60;          // M15: permissivo per trend moderato
         g_kc_wprOB_eff          = -40.0;          // M15: WPR zone molto allargate
         g_kc_wprOS_eff          = -60.0;          // M15: WPR zone molto allargate
         break;
      case TF_PRESET_KC_M30:
         g_kc_atrPeriod_eff      = 14;
         g_kc_multiplier_eff     = 2.0;
         g_kc_halfMultiplier_eff = 1.0;
         g_kc_wprPeriod_eff      = 7;
         g_kc_dcwPercentile_eff  = 35;
         g_kc_atrRatioThresh_eff = 0.75;
         g_kc_minSqueezeBars_eff = 2;
         g_kc_nSameBars_eff      = 2;
         g_kc_nOppositeBars_eff  = 1;
         g_kc_fireCooldown_eff   = 2;
         g_kc_fireDCWThresh_eff  = 4.5;
         g_kc_minWidthPips_eff   = 10.0;            // M30: canale min 10 pip → TP min ~5 pip
         g_kc_erTrending_eff     = 0.62;          // M30: permissivo
         g_kc_wprOB_eff          = -40.0;
         g_kc_wprOS_eff          = -60.0;
         break;
      case TF_PRESET_KC_H1:
         g_kc_atrPeriod_eff      = 14;
         g_kc_multiplier_eff     = 2.0;
         g_kc_halfMultiplier_eff = 1.0;
         g_kc_wprPeriod_eff      = 9;
         g_kc_dcwPercentile_eff  = 35;
         g_kc_atrRatioThresh_eff = 0.75;
         g_kc_minSqueezeBars_eff = 2;
         g_kc_nSameBars_eff      = 1;
         g_kc_nOppositeBars_eff  = 1;
         g_kc_fireCooldown_eff   = 2;
         g_kc_fireDCWThresh_eff  = 4.0;
         g_kc_minWidthPips_eff   = 10.0;            // H1: canale min 10 pip → TP min ~5 pip
         g_kc_erTrending_eff     = 0.65;          // H1: permissivo per trend persistenti
         g_kc_wprOB_eff          = -40.0;
         g_kc_wprOS_eff          = -60.0;
         break;
      case TF_PRESET_KC_M1:
         // M1: solo per entry di precisione su segnale HTF — non usare come TF primario
         g_kc_atrPeriod_eff      = 7;
         g_kc_multiplier_eff     = 1.2;
         g_kc_halfMultiplier_eff = 0.6;
         g_kc_wprPeriod_eff      = 3;
         g_kc_dcwPercentile_eff  = 25;
         g_kc_atrRatioThresh_eff = 0.75;
         g_kc_minSqueezeBars_eff = 3;
         g_kc_nSameBars_eff      = 2;
         g_kc_nOppositeBars_eff  = 1;
         g_kc_fireCooldown_eff   = 3;
         g_kc_fireDCWThresh_eff  = 7.0;
         g_kc_minWidthPips_eff   = 10.0;            // M1: canale min 10 pip → TP min ~5 pip
         g_kc_erTrending_eff     = 0.60;          // M1: permissivo
         g_kc_wprOB_eff          = -40.0;
         g_kc_wprOS_eff          = -60.0;
         break;
      default: // MANUAL
         g_kc_atrPeriod_eff      = InpATRPeriod;
         g_kc_multiplier_eff     = InpMultiplier;
         g_kc_halfMultiplier_eff = InpMultiplier * 0.5;
         g_kc_wprPeriod_eff      = InpWPRPeriod;
         g_kc_dcwPercentile_eff  = InpDCWPercentile;
         g_kc_atrRatioThresh_eff = InpATRRatioThresh;
         g_kc_minSqueezeBars_eff = InpMinSqueezeBars;
         g_kc_nSameBars_eff      = InpNSameBars;
         g_kc_nOppositeBars_eff  = InpNOppositeBars;
         g_kc_fireCooldown_eff   = 4;
         g_kc_fireDCWThresh_eff  = 5.0;          // MANUAL: default invariato
         g_kc_minWidthPips_eff   = InpMinWidthPips;   // MANUAL: dall'input utente
         g_kc_erTrending_eff     = InpERTrending;  // MANUAL: dall'input utente
         g_kc_wprOB_eff          = InpWPR_OB;      // MANUAL: dall'input utente
         g_kc_wprOS_eff          = InpWPR_OS;       // MANUAL: dall'input utente
         break;
   }

   // KAMA params — always Perry Kaufman canonical
   g_kc_kamaPeriod_eff = InpKAMA_ER;
   g_kc_erRanging_eff  = InpERRanging;
   // g_kc_erTrending_eff: impostato per TF nel switch sopra (M5=0.38, M15=0.40, H1=0.45)
   // g_kc_fireDCWThresh_eff: impostato per TF nel switch sopra
   // g_kc_wprOB/OS_eff: impostato per TF nel switch sopra

   // Cooldown clamped
   g_nSameBars     = (int)MathMax(1, MathMin(10, g_kc_nSameBars_eff));
   g_nOppositeBars = (int)MathMax(1, MathMin(10, g_kc_nOppositeBars_eff));
}

//+------------------------------------------------------------------+
//| OnInit — Inizializzazione indicatore                              |
//|                                                                    |
//| FLUSSO:                                                            |
//|   1. Prefissi oggetti grafici (con InpInstanceID per multi-chart) |
//|   2. KCPresetsInit() — PRIMA di iATR (periodo dipende dal preset)|
//|   3. SetIndexBuffer × 28 — mapping buffer→plot (17 DATA + 11 CALC)|
//|      CRITICO: l'ordine dei buffer DATA determina l'assegnazione   |
//|      ai plot. Un buffer DATA extra shifta TUTTO il mapping.       |
//|   4. ArraySetAsSeries × 28 — indice 0 = barra più recente       |
//|   5. PlotIndexSet — colori, arrow codes, EMPTY_VALUE per frecce  |
//|   6. iATR handle — con periodo dal preset                        |
//|   7. Ring buffer DCW — allocato per percentile squeeze            |
//|   8. Time filter — parsing "HH:MM" + offset broker               |
//|   9. Chart theme — salva originali, applica Ocean dark palette    |
//|  10. CHART_FOREGROUND=false — candele Plot 10 davanti alle native|
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Object prefixes
   string instSuffix = (InpInstanceID != "") ? "_" + InpInstanceID : "";
   SIGNAL_PREFIX    = "KPC_SIG_" + instSuffix;
   TP_TARGET_PREFIX = "KPC_TPTGT_" + instSuffix;
   TP_TGTDOT_PREFIX = "KPC_TPDOT_" + instSuffix;
   ENTRY_DOT_PREFIX = "KPC_ENT_" + instSuffix;
   CANVAS_NAME      = "KPC_CANVAS" + instSuffix;
   KPC_DASH_PREFIX  = "KPC" + instSuffix + "_DASH_";

   //--- Preset initialization (MUST be before ATR handle creation)
   KCPresetsInit();

   //--- Buffer mapping (28 buffers: 17 visibili + 11 CALCULATIONS)
   //    CRITICO: i primi 17 buffer DATA/COLOR_INDEX vengono assegnati
   //    sequenzialmente ai 12 plot. Buffer extra come DATA shiftano il mapping!
   //    BufFillLow e BufSqueezeHistColor sono CALCULATIONS (come DPC BufFillDn).
   SetIndexBuffer(0,  BufKAMA,             INDICATOR_DATA);          // Plot 0 data
   SetIndexBuffer(1,  BufKAMAColor,        INDICATOR_COLOR_INDEX);   // Plot 0 color
   SetIndexBuffer(2,  BufUpperPrimary,     INDICATOR_DATA);          // Plot 1
   SetIndexBuffer(3,  BufLowerPrimary,     INDICATOR_DATA);          // Plot 2
   SetIndexBuffer(4,  BufUpperHalf,        INDICATOR_DATA);          // Plot 3
   SetIndexBuffer(5,  BufLowerHalf,        INDICATOR_DATA);          // Plot 4
   SetIndexBuffer(6,  BufFillHigh,         INDICATOR_DATA);          // Plot 5 (DRAW_NONE)
   SetIndexBuffer(7,  BufSigSellPrim,      INDICATOR_DATA);          // Plot 6 (DRAW_ARROW)
   SetIndexBuffer(8,  BufSigBuyPrim,       INDICATOR_DATA);          // Plot 7 (DRAW_ARROW)
   SetIndexBuffer(9,  BufSigSellHalf,      INDICATOR_DATA);          // Plot 8 (DRAW_ARROW)
   SetIndexBuffer(10, BufSigBuyHalf,       INDICATOR_DATA);          // Plot 9 (DRAW_ARROW)
   SetIndexBuffer(11, BufCandleO,          INDICATOR_DATA);          // Plot 10 Open
   SetIndexBuffer(12, BufCandleH,          INDICATOR_DATA);          // Plot 10 High
   SetIndexBuffer(13, BufCandleL,          INDICATOR_DATA);          // Plot 10 Low
   SetIndexBuffer(14, BufCandleC,          INDICATOR_DATA);          // Plot 10 Close
   SetIndexBuffer(15, BufCandleColor,      INDICATOR_COLOR_INDEX);   // Plot 10 color
   SetIndexBuffer(16, BufSqueezeHist,      INDICATOR_DATA);          // Plot 11 (DRAW_NONE)
   //--- CALCULATIONS (non assegnati a nessun plot)
   SetIndexBuffer(17, BufFillLow,          INDICATOR_CALCULATIONS);  // fill lower (per CCanvas)
   SetIndexBuffer(18, BufSqueezeHistColor, INDICATOR_CALCULATIONS);  // squeeze color (per EA)
   SetIndexBuffer(19, BufERValue,          INDICATOR_CALCULATIONS);
   SetIndexBuffer(20, BufSqueezeState,     INDICATOR_CALCULATIONS);
   SetIndexBuffer(21, BufFireSignal,       INDICATOR_CALCULATIONS);
   SetIndexBuffer(22, BufWPR,              INDICATOR_CALCULATIONS);
   SetIndexBuffer(23, BufDCW,              INDICATOR_CALCULATIONS);
   SetIndexBuffer(24, BufATRRatio,         INDICATOR_CALCULATIONS);
   SetIndexBuffer(25, BufATR,              INDICATOR_CALCULATIONS);
   SetIndexBuffer(26, BufEASigBuy,         INDICATOR_CALCULATIONS);
   SetIndexBuffer(27, BufEASigSell,        INDICATOR_CALCULATIONS);

   //--- ArraySetAsSeries for ALL buffers
   ArraySetAsSeries(BufKAMA, true);
   ArraySetAsSeries(BufKAMAColor, true);
   ArraySetAsSeries(BufUpperPrimary, true);
   ArraySetAsSeries(BufLowerPrimary, true);
   ArraySetAsSeries(BufUpperHalf, true);
   ArraySetAsSeries(BufLowerHalf, true);
   ArraySetAsSeries(BufFillHigh, true);
   ArraySetAsSeries(BufFillLow, true);
   ArraySetAsSeries(BufSigSellPrim, true);
   ArraySetAsSeries(BufSigBuyPrim, true);
   ArraySetAsSeries(BufSigSellHalf, true);
   ArraySetAsSeries(BufSigBuyHalf, true);
   ArraySetAsSeries(BufCandleO, true);
   ArraySetAsSeries(BufCandleH, true);
   ArraySetAsSeries(BufCandleL, true);
   ArraySetAsSeries(BufCandleC, true);
   ArraySetAsSeries(BufCandleColor, true);
   ArraySetAsSeries(BufSqueezeHist, true);
   ArraySetAsSeries(BufSqueezeHistColor, true);
   ArraySetAsSeries(BufERValue, true);
   ArraySetAsSeries(BufSqueezeState, true);
   ArraySetAsSeries(BufFireSignal, true);
   ArraySetAsSeries(BufWPR, true);
   ArraySetAsSeries(BufDCW, true);
   ArraySetAsSeries(BufATRRatio, true);
   ArraySetAsSeries(BufATR, true);
   ArraySetAsSeries(BufEASigBuy, true);
   ArraySetAsSeries(BufEASigSell, true);

   //--- Plot 0: KAMA (3 colori)
   PlotIndexSetInteger(0, PLOT_COLOR_INDEXES, 3);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 0, InpColKAMAUp);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 1, InpColKAMADn);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 2, InpColKAMARanging);

   //--- Plot 1-2: Primary bands
   PlotIndexSetInteger(1, PLOT_LINE_COLOR, InpColBandPrimary);
   PlotIndexSetInteger(2, PLOT_LINE_COLOR, InpColBandPrimary);

   //--- Plot 3-4: Half bands
   PlotIndexSetInteger(3, PLOT_LINE_COLOR, InpColBandHalf);
   PlotIndexSetInteger(4, PLOT_LINE_COLOR, InpColBandHalf);
   if(!InpShowHalf)
   {
      PlotIndexSetInteger(3, PLOT_DRAW_TYPE, DRAW_NONE);
      PlotIndexSetInteger(4, PLOT_DRAW_TYPE, DRAW_NONE);
   }

   //--- Plot 6: SELL Primary arrow
   PlotIndexSetInteger(6, PLOT_ARROW, 234);
   PlotIndexSetInteger(6, PLOT_LINE_COLOR, InpColSignalSellPrim);
   PlotIndexSetInteger(6, PLOT_LINE_WIDTH, 5);
   PlotIndexSetDouble(6, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   //--- Plot 7: BUY Primary arrow
   PlotIndexSetInteger(7, PLOT_ARROW, 233);
   PlotIndexSetInteger(7, PLOT_LINE_COLOR, InpColSignalBuyPrim);
   PlotIndexSetInteger(7, PLOT_LINE_WIDTH, 5);
   PlotIndexSetDouble(7, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   //--- Plot 8: SELL Half arrow
   PlotIndexSetInteger(8, PLOT_ARROW, 234);
   PlotIndexSetInteger(8, PLOT_LINE_COLOR, InpColSignalSellHalf);
   PlotIndexSetInteger(8, PLOT_LINE_WIDTH, 3);
   PlotIndexSetDouble(8, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   //--- Plot 9: BUY Half arrow
   PlotIndexSetInteger(9, PLOT_ARROW, 233);
   PlotIndexSetInteger(9, PLOT_LINE_COLOR, InpColSignalBuyHalf);
   PlotIndexSetInteger(9, PLOT_LINE_WIDTH, 3);
   PlotIndexSetDouble(9, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   //--- Plot 10: Candles (4 colori)
   PlotIndexSetInteger(10, PLOT_COLOR_INDEXES, 4);
   PlotIndexSetInteger(10, PLOT_LINE_COLOR, 0, InpThemeBullCandle);
   PlotIndexSetInteger(10, PLOT_LINE_COLOR, 1, InpThemeBearCandle);
   PlotIndexSetInteger(10, PLOT_LINE_COLOR, 2, InpColTriggerPrimary);
   PlotIndexSetInteger(10, PLOT_LINE_COLOR, 3, InpColTriggerHalf);
   PlotIndexSetDouble(10, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   //--- Plot 11: Squeeze State (DRAW_NONE — dati solo via buffer EA)
   //    DRAW_COLOR_HISTOGRAM incompatibile con chart_window (disegna da 0)
   PlotIndexSetInteger(11, PLOT_DRAW_TYPE, DRAW_NONE);

   //--- ATR handle (periodo da preset)
   g_atrHandle = iATR(_Symbol, PERIOD_CURRENT, g_kc_atrPeriod_eff);
   if(g_atrHandle == INVALID_HANDLE)
   {
      Print("[KPC] ERRORE: iATR handle non valido");
      return INIT_FAILED;
   }

   //--- DCW ring buffer
   ArrayResize(g_dcwRing, InpDCWLookback);
   ArrayInitialize(g_dcwRing, 0);

   //--- Time filter parsing
   if(InpUseTimeFilter)
   {
      int localStart = ParseTimeToMinutes(InpTimeBlockStart);
      int localEnd   = ParseTimeToMinutes(InpTimeBlockEnd);
      g_timeBlockStartMin = localStart + InpBrokerOffset * 60;
      g_timeBlockEndMin   = localEnd   + InpBrokerOffset * 60;
      if(g_timeBlockStartMin < 0)    g_timeBlockStartMin += 1440;
      if(g_timeBlockEndMin < 0)      g_timeBlockEndMin   += 1440;
      if(g_timeBlockStartMin >= 1440) g_timeBlockStartMin -= 1440;
      if(g_timeBlockEndMin >= 1440)   g_timeBlockEndMin   -= 1440;
   }

   //--- Chart theme (anti-flash: recupera originali da GV se disponibili)
   if(InpApplyChartTheme)
   {
      string gvKey = "KPC_" + IntegerToString(ChartID()) + "_";
      if(GlobalVariableCheck(gvKey + "BG"))
      {
         //--- TF switch: recupera colori originali salvati dall'istanza precedente
         g_origBG         = (color)(long)GlobalVariableGet(gvKey + "BG");
         g_origFG         = (color)(long)GlobalVariableGet(gvKey + "FG");
         g_origGrid       = (color)(long)GlobalVariableGet(gvKey + "GRID");
         g_origChartUp    = (color)(long)GlobalVariableGet(gvKey + "CU");
         g_origChartDown  = (color)(long)GlobalVariableGet(gvKey + "CD");
         g_origChartLine  = (color)(long)GlobalVariableGet(gvKey + "CL");
         g_origCandleBull = (color)(long)GlobalVariableGet(gvKey + "CB");
         g_origCandleBear = (color)(long)GlobalVariableGet(gvKey + "CE");
         g_origBid        = (color)(long)GlobalVariableGet(gvKey + "BID");
         g_origAsk        = (color)(long)GlobalVariableGet(gvKey + "ASK");
         g_origVolume     = (color)(long)GlobalVariableGet(gvKey + "VOL");
         g_origShowGrid   = (bool)(long)GlobalVariableGet(gvKey + "GRD");
         g_origShowVolumes = (int)(long)GlobalVariableGet(gvKey + "VLS");
         g_origForeground = (bool)(long)GlobalVariableGet(gvKey + "FRG");
         //--- Pulisci GV (usate una sola volta)
         GlobalVariableDel(gvKey + "BG");  GlobalVariableDel(gvKey + "FG");
         GlobalVariableDel(gvKey + "GRID"); GlobalVariableDel(gvKey + "CU");
         GlobalVariableDel(gvKey + "CD");  GlobalVariableDel(gvKey + "CL");
         GlobalVariableDel(gvKey + "CB");  GlobalVariableDel(gvKey + "CE");
         GlobalVariableDel(gvKey + "BID"); GlobalVariableDel(gvKey + "ASK");
         GlobalVariableDel(gvKey + "VOL"); GlobalVariableDel(gvKey + "GRD");
         GlobalVariableDel(gvKey + "VLS"); GlobalVariableDel(gvKey + "FRG");
      }
      else
      {
         //--- Prima volta: salva colori originali dal chart
         g_origBG         = (color)ChartGetInteger(0, CHART_COLOR_BACKGROUND);
         g_origFG         = (color)ChartGetInteger(0, CHART_COLOR_FOREGROUND);
         g_origGrid       = (color)ChartGetInteger(0, CHART_COLOR_GRID);
         g_origChartUp    = (color)ChartGetInteger(0, CHART_COLOR_CHART_UP);
         g_origChartDown  = (color)ChartGetInteger(0, CHART_COLOR_CHART_DOWN);
         g_origChartLine  = (color)ChartGetInteger(0, CHART_COLOR_CHART_LINE);
         g_origCandleBull = (color)ChartGetInteger(0, CHART_COLOR_CANDLE_BULL);
         g_origCandleBear = (color)ChartGetInteger(0, CHART_COLOR_CANDLE_BEAR);
         g_origBid        = (color)ChartGetInteger(0, CHART_COLOR_BID);
         g_origAsk        = (color)ChartGetInteger(0, CHART_COLOR_ASK);
         g_origVolume     = (color)ChartGetInteger(0, CHART_COLOR_VOLUME);
         g_origShowGrid   = (bool)ChartGetInteger(0, CHART_SHOW_GRID);
         g_origShowVolumes = (int)ChartGetInteger(0, CHART_SHOW_VOLUMES);
         g_origForeground = (bool)ChartGetInteger(0, CHART_FOREGROUND);
      }

      ChartSetInteger(0, CHART_COLOR_BACKGROUND,  InpThemeBG);
      ChartSetInteger(0, CHART_COLOR_FOREGROUND,  InpThemeFG);
      ChartSetInteger(0, CHART_COLOR_GRID,        InpThemeGrid);
      ChartSetInteger(0, CHART_COLOR_CHART_UP,    InpThemeBG);
      ChartSetInteger(0, CHART_COLOR_CHART_DOWN,  InpThemeBG);
      ChartSetInteger(0, CHART_COLOR_CHART_LINE,  InpThemeBG);
      ChartSetInteger(0, CHART_COLOR_CANDLE_BULL, InpThemeBullCandle);
      ChartSetInteger(0, CHART_COLOR_CANDLE_BEAR, InpThemeBearCandle);
      ChartSetInteger(0, CHART_COLOR_BID,         C'80,80,80');
      ChartSetInteger(0, CHART_COLOR_ASK,         C'80,80,80');
      ChartSetInteger(0, CHART_COLOR_VOLUME,      C'80,80,80');
      ChartSetInteger(0, CHART_SHOW_GRID,         InpShowGrid);
      ChartSetInteger(0, CHART_SHOW_VOLUMES,      0);
      g_chartThemeApplied = true;
   }

   //--- CHART_FOREGROUND = false (Plot 10 candles davanti alle native)
   //    Se InpApplyChartTheme=true, g_origForeground è già stato salvato
   //    nel branch GV (riga 926) o nel branch else (prima volta).
   //    Solo se tema OFF serve leggere dal chart qui.
   if(!InpApplyChartTheme)
      g_origForeground = (bool)ChartGetInteger(0, CHART_FOREGROUND);
   ChartSetInteger(0, CHART_FOREGROUND, false);

   ChartRedraw();

   //--- Dashboard (v1.04)
   InitKPCDashboard();

   //--- Sync dashboard toggles con input defaults
   g_dash_F5_wpr     = false;   // RIDONDANTE — OFF permanente
   g_dash_F6_width   = true;    // Safety net: canali troppo stretti
   g_dash_F7_time    = false;   // Preferenza utente
   g_dash_vis_half   = InpShowHalf;
   g_dash_vis_candles = InpShowTriggerCandle;

   //--- Dashboard visibile SUBITO (non attendere OnCalculate/CopyBuffer)
   UpdateKPCDashboard(true);

   Print("[KPC] OnInit completato | Preset=", EnumToString(InpTFPreset),
         " | ATR=", g_kc_atrPeriod_eff, " | Mult=", g_kc_multiplier_eff,
         " | WPR=", g_kc_wprPeriod_eff, " | Squeeze=", g_kc_minSqueezeBars_eff);

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| OnDeinit — Deinizializzazione indicatore                          |
//|                                                                    |
//| OPERAZIONI:                                                        |
//|   1. Log diagnostico (reason + stato)                             |
//|   2. Pulizia oggetti grafici (label, TP line, entry dot)          |
//|   3. Distruzione CCanvas (bitmap overlay trasparente)             |
//|   4. Rilascio handle iATR                                         |
//|   5. Ripristino condizionale colori chart:                        |
//|      - REASON_PARAMETERS/CHARTCHANGE: skip (OnInit segue subito,  |
//|        colori originali persistiti via GlobalVariables per evitare |
//|        flash visivo tema scuro→chiaro→scuro al cambio TF)         |
//|      - REASON_REMOVE/RECOMPILE: ripristino obbligatorio           |
//|   6. Ripristino CHART_FOREGROUND                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   string reasonText = "";
   switch(reason)
   {
      case REASON_PROGRAM:     reasonText = "PROGRAM"; break;
      case REASON_REMOVE:      reasonText = "REMOVE"; break;
      case REASON_RECOMPILE:   reasonText = "RECOMPILE"; break;
      case REASON_CHARTCHANGE: reasonText = "CHARTCHANGE"; break;
      case REASON_CHARTCLOSE:  reasonText = "CHARTCLOSE"; break;
      case REASON_PARAMETERS:  reasonText = "PARAMETERS"; break;
      case REASON_ACCOUNT:     reasonText = "ACCOUNT"; break;
      case REASON_TEMPLATE:    reasonText = "TEMPLATE"; break;
      default:                 reasonText = "UNKNOWN"; break;
   }
   Print("[KPC] OnDeinit reason=", reason, " → ", reasonText);

   //--- Dashboard
   DestroyKPCDashboard();

   //--- Pulizia oggetti grafici
   DeleteSignalObjects();
   DeleteTPTargetObjects();
   DeleteEntryDotObjects();

   //--- Canvas
   if(g_canvasCreated)
   {
      g_canvas.Destroy();
      g_canvasCreated = false;
   }

   //--- Release ATR handle
   if(g_atrHandle != INVALID_HANDLE) { IndicatorRelease(g_atrHandle); g_atrHandle = INVALID_HANDLE; }

   //--- Ripristino chart theme (anti-flash: skip per CHARTCHANGE, salva in GV)
   bool skipRestore = (reason == REASON_PARAMETERS || reason == REASON_CHARTCHANGE);

   //--- CHARTCHANGE: salva originali in GlobalVariables per la prossima istanza
   if(reason == REASON_CHARTCHANGE && g_chartThemeApplied)
   {
      string gvKey = "KPC_" + IntegerToString(ChartID()) + "_";
      GlobalVariableSet(gvKey + "BG",   (double)(long)g_origBG);
      GlobalVariableSet(gvKey + "FG",   (double)(long)g_origFG);
      GlobalVariableSet(gvKey + "GRID", (double)(long)g_origGrid);
      GlobalVariableSet(gvKey + "CU",   (double)(long)g_origChartUp);
      GlobalVariableSet(gvKey + "CD",   (double)(long)g_origChartDown);
      GlobalVariableSet(gvKey + "CL",   (double)(long)g_origChartLine);
      GlobalVariableSet(gvKey + "CB",   (double)(long)g_origCandleBull);
      GlobalVariableSet(gvKey + "CE",   (double)(long)g_origCandleBear);
      GlobalVariableSet(gvKey + "BID",  (double)(long)g_origBid);
      GlobalVariableSet(gvKey + "ASK",  (double)(long)g_origAsk);
      GlobalVariableSet(gvKey + "VOL",  (double)(long)g_origVolume);
      GlobalVariableSet(gvKey + "GRD",  (double)(long)g_origShowGrid);
      GlobalVariableSet(gvKey + "VLS",  (double)(long)g_origShowVolumes);
      GlobalVariableSet(gvKey + "FRG",  (double)(long)g_origForeground);
   }

   if(g_chartThemeApplied && !skipRestore)
   {
      ChartSetInteger(0, CHART_COLOR_BACKGROUND,  g_origBG);
      ChartSetInteger(0, CHART_COLOR_FOREGROUND,  g_origFG);
      ChartSetInteger(0, CHART_COLOR_GRID,        g_origGrid);
      ChartSetInteger(0, CHART_COLOR_CHART_UP,    g_origChartUp);
      ChartSetInteger(0, CHART_COLOR_CHART_DOWN,  g_origChartDown);
      ChartSetInteger(0, CHART_COLOR_CHART_LINE,  g_origChartLine);
      ChartSetInteger(0, CHART_COLOR_CANDLE_BULL, g_origCandleBull);
      ChartSetInteger(0, CHART_COLOR_CANDLE_BEAR, g_origCandleBear);
      ChartSetInteger(0, CHART_COLOR_BID,         g_origBid);
      ChartSetInteger(0, CHART_COLOR_ASK,         g_origAsk);
      ChartSetInteger(0, CHART_COLOR_VOLUME,      g_origVolume);
      ChartSetInteger(0, CHART_SHOW_GRID,         g_origShowGrid);
      ChartSetInteger(0, CHART_SHOW_VOLUMES,      g_origShowVolumes);
      g_chartThemeApplied = false;
   }
   if(!skipRestore)
      ChartSetInteger(0, CHART_FOREGROUND, g_origForeground);

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| ParseTimeToMinutes — Converte "HH:MM" in minuti (0-1439)         |
//| Usata per filtro orario. Clamp: ore 0-23, minuti 0-59.           |
//+------------------------------------------------------------------+
int ParseTimeToMinutes(string timeStr)
{
   int h = 0, m = 0;
   int colonPos = StringFind(timeStr, ":");
   if(colonPos > 0)
   {
      h = (int)StringToInteger(StringSubstr(timeStr, 0, colonPos));
      m = (int)StringToInteger(StringSubstr(timeStr, colonPos + 1));
   }
   h = (int)MathMax(0, MathMin(23, h));
   m = (int)MathMax(0, MathMin(59, m));
   return h * 60 + m;
}

//+------------------------------------------------------------------+
//| CalcTPConservative — Sposta il TP di N pip verso l'entry         |
//| BUY:  TP = KAMA - N pip  (raggiunto prima della KAMA esatta)    |
//| SELL: TP = KAMA + N pip  (raggiunto prima della KAMA esatta)    |
//| Effetto: elimina near-miss senza cambiare la struttura segnale.  |
//| Con InpTPConservativePips=0 si comporta come prima (KAMA esatta).|
//+------------------------------------------------------------------+
double CalcTPConservative(double kamaPrice, bool isBuy)
{
   if(InpTPConservativePips <= 0.0) return kamaPrice;
   double pipSize = (_Digits == 5 || _Digits == 3) ? _Point * 10.0 : _Point;
   double offset  = InpTPConservativePips * pipSize;
   return isBuy ? kamaPrice - offset : kamaPrice + offset;
}

//+------------------------------------------------------------------+
//| IsInBlockedTime — Verifica se barra è nella fascia oraria bloccata|
//| barTime in orario broker. Confronta con g_timeBlockStartMin/EndMin|
//| già convertiti in orario broker in OnInit. Supporta overnight.    |
//+------------------------------------------------------------------+
bool IsInBlockedTime(datetime barTime)
{
   if(!InpUseTimeFilter) return false;
   MqlDateTime dt;
   TimeToStruct(barTime, dt);
   int barMin = dt.hour * 60 + dt.min;
   if(g_timeBlockStartMin <= g_timeBlockEndMin)
      return (barMin >= g_timeBlockStartMin && barMin < g_timeBlockEndMin);
   else
      return (barMin >= g_timeBlockStartMin || barMin < g_timeBlockEndMin);
}

//+------------------------------------------------------------------+
//| KPC DASHBOARD — Pannello con toggle ON/OFF per filtri e visuals  |
//| Architettura identica a BussolaSuperTrending v2.07:              |
//|   - Object pool creato una volta (zero flicker)                  |
//|   - OBJ_RECTANGLE_LABEL border + background                     |
//|   - OBJ_LABEL per righe status                                  |
//|   - OBJ_BUTTON per toggle ON/OFF                                |
//|   - OnChartEvent click → toggle state → forceRecalc             |
//+------------------------------------------------------------------+

//--- Helper: setta una riga di testo nella dashboard
void KPCSetRow(int row, string text, color clr, int fontSize = 8)
{
   if(row >= KPC_DASH_MAX_ROWS) return;
   string name = KPC_DASH_PREFIX + "R" + IntegerToString(row, 2, '0');
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
}

//--- Helper: setta un bottone toggle ON/OFF
void KPCSetBtn(string id, bool is_on, int y)
{
   string name = KPC_DASH_PREFIX + "BTN_" + id;
   int btn_x = 10 + 280;
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, btn_x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, name, OBJPROP_TEXT, is_on ? "ON" : "OFF");
   ObjectSetInteger(0, name, OBJPROP_COLOR,        is_on ? C'220,255,220' : C'180,120,120');
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR,      is_on ? C'25,80,40'   : C'70,25,25');
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, is_on ? C'40,120,60'  : C'100,40,40');
   ObjectSetInteger(0, name, OBJPROP_STATE, false);
   ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
}

//--- Helper: nasconde un bottone
void KPCHideBtn(string id)
{
   string name = KPC_DASH_PREFIX + "BTN_" + id;
   ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
}

//--- Ridimensiona il background della dashboard
void KPCResizeBG(int totalRows)
{
   int y_step = 16;
   int panel_h = 28 + totalRows * y_step + 8;
   string border = KPC_DASH_PREFIX + "BORDER";
   string bg     = KPC_DASH_PREFIX + "BG";
   ObjectSetInteger(0, border, OBJPROP_YSIZE, panel_h);
   ObjectSetInteger(0, bg,     OBJPROP_YSIZE, panel_h - 6);
}

//--- Crea tutti gli oggetti dashboard (chiamata una volta in OnInit)
void InitKPCDashboard()
{
   int x_base = 10, y_base = 20;
   int panel_w = 340;

   // Border (gold)
   string border = KPC_DASH_PREFIX + "BORDER";
   ObjectCreate(0, border, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, border, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, border, OBJPROP_XDISTANCE, x_base);
   ObjectSetInteger(0, border, OBJPROP_YDISTANCE, y_base);
   ObjectSetInteger(0, border, OBJPROP_XSIZE, panel_w);
   ObjectSetInteger(0, border, OBJPROP_YSIZE, 400);
   ObjectSetInteger(0, border, OBJPROP_BGCOLOR, C'200,180,50');
   ObjectSetInteger(0, border, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, border, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, border, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, border, OBJPROP_ZORDER, 16000);

   // Background (dark blue)
   string bg = KPC_DASH_PREFIX + "BG";
   ObjectCreate(0, bg, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, bg, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, bg, OBJPROP_XDISTANCE, x_base + 3);
   ObjectSetInteger(0, bg, OBJPROP_YDISTANCE, y_base + 3);
   ObjectSetInteger(0, bg, OBJPROP_XSIZE, panel_w - 6);
   ObjectSetInteger(0, bg, OBJPROP_YSIZE, 394);
   ObjectSetInteger(0, bg, OBJPROP_BGCOLOR, C'12,20,45');
   ObjectSetInteger(0, bg, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, bg, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, bg, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, bg, OBJPROP_ZORDER, 16001);

   // Label pool
   for(int i = 0; i < KPC_DASH_MAX_ROWS; i++)
   {
      string name = KPC_DASH_PREFIX + "R" + IntegerToString(i, 2, '0');
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x_base + 10);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y_base + 6 + i * 16);
      ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
      ObjectSetInteger(0, name, OBJPROP_COLOR, C'150,165,185');
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, name, OBJPROP_ZORDER, 16100);
      ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
   }

   // Button pool (13 bottoni: 7 filtri + 6 visuals)
   string btnIds[] = {"F1","F2","F3","F4","F5","F6","F7",
                      "KAMA","BANDS","HALF","FILL","ARROWS","CANDLES"};
   for(int i = 0; i < ArraySize(btnIds); i++)
   {
      string name = KPC_DASH_PREFIX + "BTN_" + btnIds[i];
      ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, name, OBJPROP_ZORDER, 17000);
      ObjectSetInteger(0, name, OBJPROP_XSIZE, 36);
      ObjectSetInteger(0, name, OBJPROP_YSIZE, 15);
      ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 7);
      ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
   }
}

//--- Aggiorna contenuto dashboard (chiamata ogni tick, throttled)
void UpdateKPCDashboard(bool forceUpdate = false)
{
   static uint s_lastUpdate = 0;
   uint now = GetTickCount();
   if(!forceUpdate && now - s_lastUpdate < 500) return;
   s_lastUpdate = now;

   int x_base = 10, y_base = 20, y_step = 16;
   int row = 0;

   // --- HEADER ---
   KPCSetRow(row++, "KPC v1.09 | " + _Symbol + " | " + EnumToString(_Period), C'70,130,255', 10);
   KPCSetRow(row++, "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━", C'60,70,100', 7);

   // --- STATO SQUEEZE ---
   string sqzSt = (g_squeezeBarsCount >= g_kc_minSqueezeBars_eff)
                  ? "ATTIVA (" + IntegerToString(g_squeezeBarsCount) + ")"
                  : IntegerToString(g_squeezeBarsCount) + "/" + IntegerToString(g_kc_minSqueezeBars_eff);
   color sqzClr = (g_squeezeBarsCount >= g_kc_minSqueezeBars_eff) ? C'50,220,120' : C'255,180,50';
   KPCSetRow(row++, "Squeeze: " + sqzSt + (g_fireActive ? "  | FIRE!" : ""), sqzClr);

   // --- FILTRI (sezione con toggle) ---
   KPCSetRow(row++, "━━━ FILTRI ━━━━━━━━━━━━━━━━━━━━━━━━", C'60,70,100', 7);

   // F1: ER Regime
   string f1st = g_dash_F1_erRegime ? "● ON" : "○ OFF";
   color  f1cl = g_dash_F1_erRegime ? C'70,130,255' : C'50,70,120';
   KPCSetRow(row, "F1 ER Regime       " + f1st, f1cl);
   KPCSetBtn("F1", g_dash_F1_erRegime, y_base + 6 + row * y_step);
   row++;

   // F2: Squeeze Duration
   string f2st = g_dash_F2_squeeze ? "● ON" : "○ OFF";
   color  f2cl = g_dash_F2_squeeze ? C'70,130,255' : C'50,70,120';
   KPCSetRow(row, "F2 Squeeze Bars    " + f2st, f2cl);
   KPCSetBtn("F2", g_dash_F2_squeeze, y_base + 6 + row * y_step);
   row++;

   // F3: DCW Slope
   string f3st = g_dash_F3_dcwSlope ? "● ON" : "○ OFF";
   color  f3cl = g_dash_F3_dcwSlope ? C'70,130,255' : C'50,70,120';
   KPCSetRow(row, "F3 DCW Slope       " + f3st, f3cl);
   KPCSetBtn("F3", g_dash_F3_dcwSlope, y_base + 6 + row * y_step);
   row++;

   // F4: Fire Kill Switch
   string f4st = g_dash_F4_fire ? "● ON" : "○ OFF";
   color  f4cl = g_dash_F4_fire ? C'70,130,255' : C'50,70,120';
   KPCSetRow(row, "F4 Fire KillSwitch " + f4st, f4cl);
   KPCSetBtn("F4", g_dash_F4_fire, y_base + 6 + row * y_step);
   row++;

   // F5: WPR Momentum
   string f5st = g_dash_F5_wpr ? "● ON" : "○ OFF";
   color  f5cl = g_dash_F5_wpr ? C'70,130,255' : C'50,70,120';
   KPCSetRow(row, "F5 WPR Momentum    " + f5st, f5cl);
   KPCSetBtn("F5", g_dash_F5_wpr, y_base + 6 + row * y_step);
   row++;

   // F6: Width Minima
   string f6st = g_dash_F6_width ? "● ON" : "○ OFF";
   color  f6cl = g_dash_F6_width ? C'70,130,255' : C'50,70,120';
   KPCSetRow(row, "F6 Width Min TP    " + f6st, f6cl);
   KPCSetBtn("F6", g_dash_F6_width, y_base + 6 + row * y_step);
   row++;

   // F7: Time Block
   string f7st = g_dash_F7_time ? "● ON" : "○ OFF";
   color  f7cl = g_dash_F7_time ? C'70,130,255' : C'50,70,120';
   KPCSetRow(row, "F7 Time Block      " + f7st, f7cl);
   KPCSetBtn("F7", g_dash_F7_time, y_base + 6 + row * y_step);
   row++;

   // --- VISUALS (sezione con toggle) ---
   KPCSetRow(row++, "━━━ VISUALS ━━━━━━━━━━━━━━━━━━━━━━━", C'60,70,100', 7);

   // KAMA
   string vkst = g_dash_vis_kama ? "● ON" : "○ OFF";
   color  vkcl = g_dash_vis_kama ? C'70,200,130' : C'50,70,120';
   KPCSetRow(row, "KAMA Midline       " + vkst, vkcl);
   KPCSetBtn("KAMA", g_dash_vis_kama, y_base + 6 + row * y_step);
   row++;

   // Bands
   string vbst = g_dash_vis_bands ? "● ON" : "○ OFF";
   color  vbcl = g_dash_vis_bands ? C'70,200,130' : C'50,70,120';
   KPCSetRow(row, "Bande Primary      " + vbst, vbcl);
   KPCSetBtn("BANDS", g_dash_vis_bands, y_base + 6 + row * y_step);
   row++;

   // Half
   string vhst = g_dash_vis_half ? "● ON" : "○ OFF";
   color  vhcl = g_dash_vis_half ? C'70,200,130' : C'50,70,120';
   KPCSetRow(row, "Bande Half         " + vhst, vhcl);
   KPCSetBtn("HALF", g_dash_vis_half, y_base + 6 + row * y_step);
   row++;

   // Fill
   string vfst = g_dash_vis_fill ? "● ON" : "○ OFF";
   color  vfcl = g_dash_vis_fill ? C'70,200,130' : C'50,70,120';
   KPCSetRow(row, "KC Fill            " + vfst, vfcl);
   KPCSetBtn("FILL", g_dash_vis_fill, y_base + 6 + row * y_step);
   row++;

   // Arrows
   string vast = g_dash_vis_arrows ? "● ON" : "○ OFF";
   color  vacl = g_dash_vis_arrows ? C'70,200,130' : C'50,70,120';
   KPCSetRow(row, "Frecce Segnale     " + vast, vacl);
   KPCSetBtn("ARROWS", g_dash_vis_arrows, y_base + 6 + row * y_step);
   row++;

   // Candles
   string vcst = g_dash_vis_candles ? "● ON" : "○ OFF";
   color  vccl = g_dash_vis_candles ? C'70,200,130' : C'50,70,120';
   KPCSetRow(row, "Candele Trigger    " + vcst, vccl);
   KPCSetBtn("CANDLES", g_dash_vis_candles, y_base + 6 + row * y_step);
   row++;

   // Hide unused rows
   for(int r = row; r < KPC_DASH_MAX_ROWS; r++)
   {
      string name = KPC_DASH_PREFIX + "R" + IntegerToString(r, 2, '0');
      ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
   }

   KPCResizeBG(row);
}

//--- Elimina tutti gli oggetti dashboard
void DestroyKPCDashboard()
{
   ObjectsDeleteAll(0, KPC_DASH_PREFIX);
}

//+------------------------------------------------------------------+
//| CalcWPR — Williams %R manuale per barra i                        |
//|                                                                    |
//| Formula: WPR = (HighestHigh - close) / (HH - LL) × (-100)       |
//| Range: -100 (oversold/bottom) a 0 (overbought/top)               |
//|   WPR > -20 = OB (prezzo vicino al max del range → SELL zone)    |
//|   WPR < -80 = OS (prezzo vicino al min del range → BUY zone)     |
//| Scrive direttamente in BufWPR[i]. Se range=0 → -50 (neutro).    |
//| Periodo auto-preset: M5/M15=5, M30=7, H1=9.                      |
//+------------------------------------------------------------------+
void CalcWPR(const double &high[], const double &low[], const double &close[],
             int i, int period, int rates_total)
{
   if(i + period >= rates_total) { BufWPR[i] = -50.0; return; }
   double hh = high[i];
   double ll = low[i];
   for(int k = 1; k < period; k++)
   {
      if(high[i + k] > hh) hh = high[i + k];
      if(low[i + k] < ll)  ll = low[i + k];
   }
   double range = hh - ll;
   BufWPR[i] = (range > 1e-10) ? (hh - close[i]) / range * (-100.0) : -50.0;
}

//+------------------------------------------------------------------+
//| CalcATRSimple — ATR manuale per calcolo ratio fast/slow           |
//|                                                                    |
//| Usato per calcolare ATR(5) e ATR(20) separatamente dall'handle    |
//| iATR (che è occupato col periodo preset). Il ratio ATR(5)/ATR(20) |
//| misura se la volatilità recente è bassa rispetto alla media:      |
//|   ratio < 0.80 → volatilità compressa → squeeze candidata.       |
//| True Range = max(H-L, |H-prevClose|, |L-prevClose|).             |
//| Ritorna la media semplice su N barre.                             |
//+------------------------------------------------------------------+
double CalcATRSimple(const double &high[], const double &low[], const double &close[],
                     int i, int period, int rates_total)
{
   if(i + period >= rates_total) return 0;
   double sum = 0;
   for(int k = 0; k < period; k++)
   {
      int idx = i + k;
      double tr;
      if(idx + 1 < rates_total)
         tr = MathMax(high[idx] - low[idx],
              MathMax(MathAbs(high[idx] - close[idx + 1]),
                      MathAbs(low[idx] - close[idx + 1])));
      else
         tr = high[idx] - low[idx];
      sum += tr;
   }
   return sum / period;
}

//+------------------------------------------------------------------+
//| KCCheckFire — Rileva esplosione volatilità post-squeeze (fire)    |
//|                                                                    |
//| PRINCIPIO ANTI-FIRE: l'indicatore opera in mean-reversion DURANTE |
//|   la squeeze. Quando la squeeze esplode (fire), il mercato entra  |
//|   in trend e la MR non funziona più → BLOCCA tutti i segnali.    |
//|                                                                    |
//| CONDIZIONI FIRE:                                                   |
//|   1. g_squeezeWasActive = true (prerequisito: squeeze >= 3 barre)|
//|   2. DCW > soglia fireDCW (la larghezza Donchian è grande)        |
//|   3. DCW espanso > 20% rispetto alla barra precedente            |
//|                                                                    |
//| AL FIRE: g_fireActive=true, avvia cooldown (N barre per TF).     |
//|   BufFireSignal[i] = +1/-1 (direzione basata su KAMA slope).     |
//|   Tutti i segnali bloccati durante il fire (Filtro 4 + cooldown). |
//|                                                                    |
//| COOLDOWN: decrementa ad ogni barra. A zero → fire spento,        |
//|   g_squeezeWasActive=false (richiede nuova squeeze per riarmare). |
//+------------------------------------------------------------------+
bool KCCheckFire(int i, int rates_total)
{
   if(!g_squeezeWasActive) return false;
   if(i + 1 >= rates_total) return false;

   // Fire esplosivo (1 barra, +20%) OPPURE fire graduale (2 barre, +15%)
   bool fireNow = (BufDCW[i] > g_kc_fireDCWThresh_eff) &&
                  ((BufDCW[i] > BufDCW[i + 1] * 1.20) ||
                   (i + 2 < rates_total && BufDCW[i] > BufDCW[i + 2] * 1.15));

   if(fireNow)
   {
      g_fireActive = true;
      g_fireCooldownRemaining = g_kc_fireCooldown_eff;
      BufFireSignal[i] = (BufKAMA[i] > BufKAMA[i + 1]) ? 1.0 : -1.0;
      return true;
   }

   if(g_fireActive && g_fireCooldownRemaining > 0)
   {
      g_fireCooldownRemaining--;
      if(g_fireCooldownRemaining == 0)
      {
         g_fireActive = false;
         g_squeezeWasActive = false;
      }
   }

   return false;
}

//+------------------------------------------------------------------+
//| LinearRegressionSlope — Pendenza OLS su N barre                   |
//| Ereditata dal DPC per il forecast. NON chiamata in KPC v1.        |
//| Mantenuta per compatibilità futura (roadmap v2 forecast).         |
//| slope > 0 = rialzista, slope < 0 = ribassista.                    |
//+------------------------------------------------------------------+
double LinearRegressionSlope(const double &src[], int bar, int length, int total)
{
   if(bar + length > total) return 0.0;
   double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
   int n = length;
   for(int k = 0; k < n; k++)
   {
      double x = (double)(n - 1 - k);
      double y = src[bar + k];
      sumX  += x;
      sumY  += y;
      sumXY += x * y;
      sumX2 += x * x;
   }
   double denom = (n * sumX2 - sumX * sumX);
   if(MathAbs(denom) < 1e-10) return 0.0;
   return (n * sumXY - sumX * sumY) / denom;
}

//+------------------------------------------------------------------+
//| Delete*Objects — Pulizia oggetti grafici per prefisso nome        |
//| Loop inverso (total-1→0) perché ObjectDelete shifta gli indici.  |
//| Chiamate da OnDeinit e dal reset prev_calculated==0.             |
//+------------------------------------------------------------------+
void DeleteSignalObjects()
{
   ObjectsDeleteAll(0, SIGNAL_PREFIX);
}

void DeleteTPTargetObjects()
{
   ObjectsDeleteAll(0, TP_TARGET_PREFIX);
   ObjectsDeleteAll(0, TP_TGTDOT_PREFIX);
}

void DeleteEntryDotObjects()
{
   ObjectsDeleteAll(0, ENTRY_DOT_PREFIX);
}

//+------------------------------------------------------------------+
//| CreateTP1Target — TP1: KAMA midline (prezzo fisso congelato)      |
//|                                                                    |
//| Al momento del segnale, il TP viene piazzato sul valore KAMA      |
//| CORRENTE (fisso — non si muove mai). Visualmente:                  |
//|   1. Pallino colorato ● (code 159) al prezzo KAMA                |
//|   2. Linea tratteggiata orizzontale verde/rossa verso destra      |
//| tp_type=1 nel tracking array.                                      |
//+------------------------------------------------------------------+
void CreateTP1Target(datetime signalTime, double tpPrice, bool isBuy, double signalPrice)
{
   if(!InpEnableTP1 || !InpShowTP1Line) return;

   g_tpTargetCounter++;
   color targetColor = isBuy ? InpColTP1Buy : InpColTP1Sell;
   string direction  = isBuy ? "BUY" : "SELL";

   // Pallino target
   string dotName = TP_TGTDOT_PREFIX + "T1_" + IntegerToString(g_tpTargetCounter);
   ObjectCreate(0, dotName, OBJ_ARROW, 0, signalTime, tpPrice);
   ObjectSetInteger(0, dotName, OBJPROP_ARROWCODE, 159);
   ObjectSetInteger(0, dotName, OBJPROP_COLOR, targetColor);
   ObjectSetInteger(0, dotName, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, dotName, OBJPROP_BACK, false);
   ObjectSetInteger(0, dotName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, dotName, OBJPROP_HIDDEN, true);
   ObjectSetString(0, dotName, OBJPROP_TOOLTIP,
                   "TP1 KAMA " + direction + "\nLivello: " + DoubleToString(tpPrice, _Digits) +
                   "\nIn attesa di tocco KAMA...");

   // Linea orizzontale fissa
   string lineName = TP_TARGET_PREFIX + "T1_" + IntegerToString(g_tpTargetCounter);
   ObjectCreate(0, lineName, OBJ_TREND, 0,
                signalTime, tpPrice,
                signalTime + PeriodSeconds() * 500, tpPrice);
   ObjectSetInteger(0, lineName, OBJPROP_COLOR, targetColor);
   ObjectSetInteger(0, lineName, OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(0, lineName, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, lineName, OBJPROP_RAY_RIGHT, true);
   ObjectSetInteger(0, lineName, OBJPROP_RAY_LEFT, false);
   ObjectSetInteger(0, lineName, OBJPROP_BACK, false);
   ObjectSetInteger(0, lineName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, lineName, OBJPROP_HIDDEN, true);
   ObjectSetString(0, lineName, OBJPROP_TOOLTIP,
                   "TP1 KAMA " + direction + " | Livello: " + DoubleToString(tpPrice, _Digits));

   int n = ArraySize(g_activeTPTargets);
   ArrayResize(g_activeTPTargets, n + 1);
   g_activeTPTargets[n].lineName       = lineName;
   g_activeTPTargets[n].dotName        = dotName;
   g_activeTPTargets[n].price          = tpPrice;
   g_activeTPTargets[n].isBuy          = isBuy;
   g_activeTPTargets[n].signalTime     = signalTime;
   g_activeTPTargets[n].signalPrice    = signalPrice;
   g_activeTPTargets[n].tp_type        = 1;
   g_activeTPTargets[n].minProfitLevel = 0.0;
   g_activeTPTargets[n].entryBandLevel = 0.0;
}

//+------------------------------------------------------------------+
//| CreateTP2Target — TP2: touch banda opposta (dinamico)             |
//|                                                                    |
//| NON ha prezzo fisso: la condizione hit viene verificata ogni barra |
//| confrontando con BufUpperPrimary[i] (BUY) o BufLowerPrimary[i]   |
//| (SELL) + guardia profitto minimo su close.                         |
//| La linea visiva si sposta ogni barra seguendo la banda corrente.   |
//| tp_type=2 nel tracking array.                                      |
//+------------------------------------------------------------------+
void CreateTP2Target(datetime signalTime, bool isBuy, double signalPrice,
                     double entryBandLevel, double minProfitLevel,
                     double initialBandPrice)
{
   if(!InpEnableTP2 || !InpShowTP2Line) return;

   g_tpTargetCounter++;
   color targetColor = isBuy ? InpColTP2Buy : InpColTP2Sell;
   string direction  = isBuy ? "BUY" : "SELL";

   // Pallino entry banda (stesso time del segnale, al livello della banda)
   string dotName = TP_TGTDOT_PREFIX + "T2_" + IntegerToString(g_tpTargetCounter);
   ObjectCreate(0, dotName, OBJ_ARROW, 0, signalTime, entryBandLevel);
   ObjectSetInteger(0, dotName, OBJPROP_ARROWCODE, 159);
   ObjectSetInteger(0, dotName, OBJPROP_COLOR, targetColor);
   ObjectSetInteger(0, dotName, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, dotName, OBJPROP_BACK, false);
   ObjectSetInteger(0, dotName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, dotName, OBJPROP_HIDDEN, true);
   ObjectSetString(0, dotName, OBJPROP_TOOLTIP,
                   "TP2 BANDA " + direction + "\nDinamico: segue banda opposta" +
                   "\nMin profitto: " + DoubleToString(InpTP2MinProfitPips, 1) + " pip");

   // Linea dinamica — parte al valore corrente della banda opposta
   string lineName = TP_TARGET_PREFIX + "T2_" + IntegerToString(g_tpTargetCounter);
   ObjectCreate(0, lineName, OBJ_TREND, 0,
                signalTime, initialBandPrice,
                signalTime + PeriodSeconds() * 500, initialBandPrice);
   ObjectSetInteger(0, lineName, OBJPROP_COLOR, targetColor);
   ObjectSetInteger(0, lineName, OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(0, lineName, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, lineName, OBJPROP_RAY_RIGHT, true);
   ObjectSetInteger(0, lineName, OBJPROP_RAY_LEFT, false);
   ObjectSetInteger(0, lineName, OBJPROP_BACK, false);
   ObjectSetInteger(0, lineName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, lineName, OBJPROP_HIDDEN, true);
   ObjectSetString(0, lineName, OBJPROP_TOOLTIP,
                   "TP2 BANDA " + direction + " | Dinamico (segue KC band)");

   int n = ArraySize(g_activeTPTargets);
   ArrayResize(g_activeTPTargets, n + 1);
   g_activeTPTargets[n].lineName       = lineName;
   g_activeTPTargets[n].dotName        = dotName;
   g_activeTPTargets[n].price          = 0.0;          // non usato per TP2
   g_activeTPTargets[n].isBuy          = isBuy;
   g_activeTPTargets[n].signalTime     = signalTime;
   g_activeTPTargets[n].signalPrice    = signalPrice;
   g_activeTPTargets[n].tp_type        = 2;
   g_activeTPTargets[n].minProfitLevel = minProfitLevel;
   g_activeTPTargets[n].entryBandLevel = entryBandLevel;
}

//+------------------------------------------------------------------+
//| CloseTPTarget — Chiude un TP target al raggiungimento prezzo      |
//|                                                                    |
//| Chiamata quando high >= target (BUY) o low <= target (SELL).      |
//| Azioni visive:                                                     |
//|   1. Ferma la linea (RAY_RIGHT=false, stile SOLID = "raggiunto") |
//|   2. Stella gialla ★ (code 169) al punto esatto del tocco        |
//|   3. Linea tratteggiata di connessione freccia→stella             |
//|   4. Tooltip aggiornato con barsToTP e pipsMove                   |
//|   5. Rimuove target dall'array g_activeTPTargets[]                |
//+------------------------------------------------------------------+
void CloseTPTarget(int targetIdx, datetime touchTime, int barsToTP, double pipsMove, double hitPrice=0.0)
{
   if(targetIdx < 0 || targetIdx >= ArraySize(g_activeTPTargets)) return;

   string lineName  = g_activeTPTargets[targetIdx].lineName;
   string dotName   = g_activeTPTargets[targetIdx].dotName;
   bool   isBuyTP   = g_activeTPTargets[targetIdx].isBuy;
   int    tpType    = g_activeTPTargets[targetIdx].tp_type;
   string direction = isBuyTP ? "BUY" : "SELL";
   string tpLabel   = (tpType == 1) ? "TP1 KAMA" : "TP2 BANDA";
   // Per TP1 usa prezzo fisso dallo struct, per TP2 usa hitPrice passato dal caller
   double displayPrice = (tpType == 2 && hitPrice > 0.0) ? hitPrice : g_activeTPTargets[targetIdx].price;

   if(ObjectFind(0, lineName) >= 0)
   {
      ObjectSetInteger(0, lineName, OBJPROP_RAY_RIGHT, false);
      ObjectMove(0, lineName, 1, touchTime, displayPrice);
      ObjectSetInteger(0, lineName, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, lineName, OBJPROP_WIDTH, 1);
      ObjectSetString(0, lineName, OBJPROP_TOOLTIP,
                      tpLabel + " " + direction + " RAGGIUNTO | " +
                      IntegerToString(barsToTP) + " barre | " +
                      DoubleToString(pipsMove, 1) + " pips");
   }

   g_tpHitCounter++;
   string hitDotName = TP_TGTDOT_PREFIX + "HIT_" + IntegerToString(g_tpHitCounter);
   ObjectCreate(0, hitDotName, OBJ_ARROW, 0, touchTime, displayPrice);
   ObjectSetInteger(0, hitDotName, OBJPROP_ARROWCODE, 169);
   ObjectSetInteger(0, hitDotName, OBJPROP_COLOR, clrYellow);
   ObjectSetInteger(0, hitDotName, OBJPROP_WIDTH, 3);
   ObjectSetInteger(0, hitDotName, OBJPROP_BACK, false);
   ObjectSetInteger(0, hitDotName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, hitDotName, OBJPROP_HIDDEN, true);
   ObjectSetString(0, hitDotName, OBJPROP_TOOLTIP,
                   "★ " + tpLabel + " " + direction + " RAGGIUNTO!\nBarre: " + IntegerToString(barsToTP) +
                   "\nMove: " + DoubleToString(pipsMove, 1) + " pips");

   // Connection line
   datetime sigTime  = g_activeTPTargets[targetIdx].signalTime;
   double   sigPrice = g_activeTPTargets[targetIdx].signalPrice;
   if(sigTime > 0 && sigPrice > 0)
   {
      color connColor;
      if(tpType == 1)
         connColor = isBuyTP ? InpColTP1Buy : InpColTP1Sell;
      else
         connColor = isBuyTP ? InpColTP2Buy : InpColTP2Sell;
      string connName = TP_TARGET_PREFIX + "CONN_" + IntegerToString(g_tpHitCounter);
      ObjectCreate(0, connName, OBJ_TREND, 0, sigTime, sigPrice, touchTime, displayPrice);
      ObjectSetInteger(0, connName, OBJPROP_COLOR, connColor);
      ObjectSetInteger(0, connName, OBJPROP_STYLE, STYLE_DOT);
      ObjectSetInteger(0, connName, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, connName, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, connName, OBJPROP_RAY_LEFT, false);
      ObjectSetInteger(0, connName, OBJPROP_BACK, false);
      ObjectSetInteger(0, connName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, connName, OBJPROP_HIDDEN, true);
      ObjectSetString(0, connName, OBJPROP_TOOLTIP,
                      direction + " → " + tpLabel + " ★ | " + IntegerToString(barsToTP) + " barre | " +
                      DoubleToString(pipsMove, 1) + " pips");
   }

   if(dotName != "" && ObjectFind(0, dotName) >= 0)
   {
      ObjectSetString(0, dotName, OBJPROP_TOOLTIP,
                      tpLabel + " " + direction + " RAGGIUNTO!\nBarre: " + IntegerToString(barsToTP) +
                      "\nMove: " + DoubleToString(pipsMove, 1) + " pips");
   }

   ArrayRemove(g_activeTPTargets, targetIdx, 1);
}

//+------------------------------------------------------------------+
//| CreateSignalArrow — Etichetta OBJ_TEXT "TRIGGER BUY/SELL"         |
//|                                                                    |
//| Le frecce visive sono gestite da DRAW_ARROW (Plot 6-9).           |
//| Questa funzione crea SOLO l'etichetta OBJ_TEXT con:               |
//|   - Testo: "TRIGGER SELL [PRIMARY]" o "TRIGGER BUY [HALF]" etc.  |
//|   - Colore: corrisponde al tipo freccia (Primary=pieno, Half=scuro)|
//|   - Tooltip: prezzo entry, TP KAMA, qualità segnale               |
//|   - Posizione: sopra la freccia (SELL) o sotto (BUY)             |
//|                                                                    |
//| quality: 2=PRIMARY (frecce grandi), 1=HALF (frecce piccole)       |
//+------------------------------------------------------------------+
void CreateSignalArrow(datetime t, double price, bool isBuy, double glowOffset,
                       double entryPrice, double tpKAMA, int quality)
{
   string suffix = IntegerToString((long)t);
   string qualStr = (quality == 2) ? "PRIMARY" : "HALF";

   color arrowColor;
   if(isBuy)
      arrowColor = (quality == 2) ? InpColSignalBuyPrim : InpColSignalBuyHalf;
   else
      arrowColor = (quality == 2) ? InpColSignalSellPrim : InpColSignalSellHalf;

   string tooltip = (isBuy ? "▲ TRIGGER BUY [" + qualStr + "]" :
                             "▼ TRIGGER SELL [" + qualStr + "]") +
                    "\nPrezzo: " + DoubleToString(entryPrice, _Digits) +
                    "\nTP KAMA: " + DoubleToString(tpKAMA, _Digits) +
                    "\nQualita: " + qualStr;

   string labelName = SIGNAL_PREFIX + (isBuy ? "BUY_LBL_" : "SELL_LBL_") + suffix;
   double labelPrice = isBuy ? price - glowOffset * 1.5 : price + glowOffset * 1.5;

   ObjectCreate(0, labelName, OBJ_TEXT, 0, t, labelPrice);
   string trigLabel = isBuy ? "TRIGGER BUY [" + qualStr + "]" : "TRIGGER SELL [" + qualStr + "]";
   ObjectSetString(0, labelName, OBJPROP_TEXT, trigLabel);
   ObjectSetInteger(0, labelName, OBJPROP_COLOR, arrowColor);
   ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 7);
   ObjectSetString(0, labelName, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, isBuy ? ANCHOR_UPPER : ANCHOR_LOWER);
   ObjectSetInteger(0, labelName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, labelName, OBJPROP_HIDDEN, true);
   ObjectSetString(0, labelName, OBJPROP_TOOLTIP, tooltip);
}

//+------------------------------------------------------------------+
//| RedrawCanvas — Fill semitrasparente tra bande Primary via CCanvas |
//|                                                                    |
//| MQL5 DRAW_FILLING NON supporta alpha reale (ignora il canale A). |
//| CCanvas con COLOR_FORMAT_ARGB_NORMALIZE è l'UNICA soluzione per  |
//| fill trasparenti in MQL5.                                          |
//|                                                                    |
//| IMPLEMENTAZIONE:                                                   |
//|   1. Crea/ridimensiona BitmapLabel (OBJPROP_BACK=true → dietro)  |
//|   2. Erase con 0x00000000 (totalmente trasparente)                |
//|   3. Per ogni coppia di barre visibili consecutive:               |
//|      - Converte prezzi UpperPrimary/LowerPrimary in pixel X,Y    |
//|      - Disegna 2 FillTriangle() per riempire il quadrilatero     |
//|   4. Update() per committare la bitmap                            |
//|                                                                    |
//| PERFORMANCE: solo barre visibili sullo schermo (non tutta la storia)|
//| CHIAMATA: ad ogni tick (OnCalculate) + OnChartEvent(scroll/zoom)  |
//+------------------------------------------------------------------+
void RedrawCanvas(bool force = false)
{
   //--- Toggle visibilità fill (dashboard)
   if(!g_dash_vis_fill)
   {
      if(g_canvasCreated) { g_canvas.Erase(0x00000000); g_canvas.Update(); }
      return;
   }

   //--- Throttle: max 10 FPS da tick, immediato da CHARTEVENT_CHART_CHANGE
   static uint s_lastCanvasRedraw = 0;
   uint now = GetTickCount();
   if(!force && now - s_lastCanvasRedraw < 100) return;
   s_lastCanvasRedraw = now;

   int chartW = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   int chartH = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
   if(chartW <= 0 || chartH <= 0) return;

   if(!g_canvasCreated)
   {
      if(!g_canvas.CreateBitmapLabel(0, 0, CANVAS_NAME, 0, 0, chartW, chartH, COLOR_FORMAT_ARGB_NORMALIZE))
         return;
      ObjectSetInteger(0, CANVAS_NAME, OBJPROP_BACK, true);
      ObjectSetInteger(0, CANVAS_NAME, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, CANVAS_NAME, OBJPROP_HIDDEN, true);
      ObjectSetString(0, CANVAS_NAME, OBJPROP_TOOLTIP, "\n");
      g_canvasCreated = true;
   }
   else if(g_canvas.Width() != chartW || g_canvas.Height() != chartH)
   {
      g_canvas.Resize(chartW, chartH);
   }

   g_canvas.Erase(0x00000000);

   double priceMax = ChartGetDouble(0, CHART_PRICE_MAX);
   double priceMin = ChartGetDouble(0, CHART_PRICE_MIN);
   if(priceMax <= priceMin) { g_canvas.Update(); return; }

   int firstVisible = (int)ChartGetInteger(0, CHART_FIRST_VISIBLE_BAR);
   int visibleBars  = (int)ChartGetInteger(0, CHART_VISIBLE_BARS);
   int totalBars    = ArraySize(BufUpperPrimary);
   if(totalBars == 0) { g_canvas.Update(); return; }

   uchar dcAlpha = (uchar)MathMax(0, MathMin(255, InpFillAlpha));
   uint  dcARGB  = ColorToARGB(InpColFill, dcAlpha);

   for(int v = 0; v < visibleBars - 1; v++)
   {
      int shift1 = firstVisible - v;
      int shift2 = firstVisible - v - 1;
      if(shift1 < 0 || shift2 < 0 || shift1 >= totalBars || shift2 >= totalBars) continue;
      if(BufUpperPrimary[shift1] == EMPTY_VALUE || BufLowerPrimary[shift1] == EMPTY_VALUE ||
         BufUpperPrimary[shift2] == EMPTY_VALUE || BufLowerPrimary[shift2] == EMPTY_VALUE) continue;

      datetime t1 = iTime(_Symbol, PERIOD_CURRENT, shift1);
      datetime t2 = iTime(_Symbol, PERIOD_CURRENT, shift2);
      if(t1 == 0 || t2 == 0) continue;

      int x1, yHi1, yLo1, x2, yHi2, yLo2;
      if(!ChartTimePriceToXY(0, 0, t1, BufUpperPrimary[shift1], x1, yHi1)) continue;
      if(!ChartTimePriceToXY(0, 0, t2, BufUpperPrimary[shift2], x2, yHi2)) continue;
      ChartTimePriceToXY(0, 0, t1, BufLowerPrimary[shift1], x1, yLo1);
      ChartTimePriceToXY(0, 0, t2, BufLowerPrimary[shift2], x2, yLo2);

      g_canvas.FillTriangle(x1, yHi1, x1, yLo1, x2, yHi2, dcARGB);
      g_canvas.FillTriangle(x1, yLo1, x2, yHi2, x2, yLo2, dcARGB);
   }

   g_canvas.Update();
}

//+------------------------------------------------------------------+
//| OnChartEvent — Ridisegna canvas su scroll/zoom/resize chart       |
//| Il CCanvas è bitmap statica: le coordinate pixel cambiano quando  |
//| l'utente interagisce col chart → il fill va ridisegnato.          |
//| ChartRedraw() forza il refresh degli OBJ_TEXT e OBJ_ARROW.       |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(id == CHARTEVENT_CHART_CHANGE)
   {
      RedrawCanvas(true);   // force=true: utente scroll/zoom → redraw immediato
      ChartRedraw();
   }

   //--- Dashboard button click handler
   if(id == CHARTEVENT_OBJECT_CLICK)
   {
      string btn_prefix = KPC_DASH_PREFIX + "BTN_";
      if(StringFind(sparam, btn_prefix) == 0)
      {
         string btn_id = StringSubstr(sparam, StringLen(btn_prefix));
         bool filterChanged = false;

         // FILTRI (richiedono ricalcolo completo)
         if(btn_id == "F1") { g_dash_F1_erRegime = !g_dash_F1_erRegime; filterChanged = true; }
         if(btn_id == "F2") { g_dash_F2_squeeze  = !g_dash_F2_squeeze;  filterChanged = true; }
         if(btn_id == "F3") { g_dash_F3_dcwSlope = !g_dash_F3_dcwSlope; filterChanged = true; }
         if(btn_id == "F4") { g_dash_F4_fire     = !g_dash_F4_fire;     filterChanged = true; }
         if(btn_id == "F5") { g_dash_F5_wpr      = !g_dash_F5_wpr;      filterChanged = true; }
         if(btn_id == "F6") { g_dash_F6_width    = !g_dash_F6_width;    filterChanged = true; }
         if(btn_id == "F7") { g_dash_F7_time     = !g_dash_F7_time;     filterChanged = true; }

         // VISUALS (aggiornamento immediato via PlotIndexSetInteger)
         if(btn_id == "KAMA")
         {
            g_dash_vis_kama = !g_dash_vis_kama;
            PlotIndexSetInteger(0, PLOT_DRAW_TYPE, g_dash_vis_kama ? DRAW_COLOR_LINE : DRAW_NONE);
         }
         if(btn_id == "BANDS")
         {
            g_dash_vis_bands = !g_dash_vis_bands;
            PlotIndexSetInteger(1, PLOT_DRAW_TYPE, g_dash_vis_bands ? DRAW_LINE : DRAW_NONE);
            PlotIndexSetInteger(2, PLOT_DRAW_TYPE, g_dash_vis_bands ? DRAW_LINE : DRAW_NONE);
         }
         if(btn_id == "HALF")
         {
            g_dash_vis_half = !g_dash_vis_half;
            PlotIndexSetInteger(3, PLOT_DRAW_TYPE, g_dash_vis_half ? DRAW_LINE : DRAW_NONE);
            PlotIndexSetInteger(4, PLOT_DRAW_TYPE, g_dash_vis_half ? DRAW_LINE : DRAW_NONE);
         }
         if(btn_id == "FILL")
         {
            g_dash_vis_fill = !g_dash_vis_fill;
            if(!g_dash_vis_fill && g_canvasCreated)
            {
               g_canvas.Erase(0x00000000);
               g_canvas.Update();
            }
            else
               RedrawCanvas(true);   // force: feedback immediato al click
         }
         if(btn_id == "ARROWS")
         {
            g_dash_vis_arrows = !g_dash_vis_arrows;
            PlotIndexSetInteger(6, PLOT_DRAW_TYPE, g_dash_vis_arrows ? DRAW_ARROW : DRAW_NONE);
            PlotIndexSetInteger(7, PLOT_DRAW_TYPE, g_dash_vis_arrows ? DRAW_ARROW : DRAW_NONE);
            PlotIndexSetInteger(8, PLOT_DRAW_TYPE, g_dash_vis_arrows ? DRAW_ARROW : DRAW_NONE);
            PlotIndexSetInteger(9, PLOT_DRAW_TYPE, g_dash_vis_arrows ? DRAW_ARROW : DRAW_NONE);
         }
         if(btn_id == "CANDLES")
         {
            g_dash_vis_candles = !g_dash_vis_candles;
            PlotIndexSetInteger(10, PLOT_DRAW_TYPE, g_dash_vis_candles ? DRAW_COLOR_CANDLES : DRAW_NONE);
         }

         // Se un filtro è cambiato → forza ricalcolo completo
         if(filterChanged)
            g_forceRecalc = true;

         UpdateKPCDashboard(true);
         ChartRedraw();
      }
   }
}

//+------------------------------------------------------------------+
//| OnCalculate — Funzione di calcolo principale (ogni tick)          |
//|                                                                    |
//| ARCHITETTURA 7 SEZIONI (loop da barra più vecchia a più recente): |
//|                                                                    |
//|   SEZ. 1: KAMA + KC Bands                                         |
//|     Calcolo KAMA (Perry Kaufman): ER→SC→ricorsione adattiva.      |
//|     KC Bands: KAMA ± ATR × multiplier (Primary + Half).           |
//|     KAMA Color: 3 stati ER-based (grigio/verde/rosso).            |
//|     Candle OHLC copy per DRAW_COLOR_CANDLES.                      |
//|                                                                    |
//|   SEZ. 3: Williams %R — momentum oscillatore per filtro L4.       |
//|                                                                    |
//|   SEZ. 4: ATR + EMA(200) + Squeeze Tracking                      |
//|     EMA(ATR,200): volatilità smoothed per offset frecce.          |
//|     DCW: Donchian Channel Width normalizzato (squeeze detection).  |
//|     Ring buffer percentile: DCW nel 20° percentile → squeeze.     |
//|     ATR ratio fast/slow: volatilità recente vs media.             |
//|     Squeeze state: DCW basso + ATR ratio basso per N barre.       |
//|     Fire detection: DCW esplode post-squeeze → kill switch.       |
//|                                                                    |
//|                                                                    |
//|   SEZ. 4.6: TP Target tracking — hit/miss/expiry multi-target.    |
//|                                                                    |
//|   SEZ. 5: Signal Detection — 4 fasi:                              |
//|     FASE 1: Base conditions (KC band touch + wick ratio ≥ 40%)    |
//|     FASE 2: 8 filtri in cascata (ER, squeeze, DCW slope, fire,    |
//|             WPR, width TP, time block)                             |
//|     FASE 3: SimpleCooldown (N barre fisso per TF, no KAMA touch)  |
//|     FASE 4: Esecuzione (frecce, label, candle, TP, entry dot,     |
//|             EA buffers, alert)                                     |
//|                                                                    |
//|   POST-LOOP: Fix #1 reset + CCanvas redraw.                       |
//|                                                                    |
//| ANTI-REPAINT: in BAR_CLOSE mode, segnali solo su i≥1 (barra      |
//|   chiusa). i=0 (barra live) → bearBase/bullBase restano false.    |
//|   Lo stato (g_lastMarkerBar, g_lastDirection) NON aggiornato per  |
//|   i=0 (Fix #2) per evitare corruzione da dati provvisori.        |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   //--- Minimum bars check
   int minBars = MathMax(g_kc_kamaPeriod_eff, g_kc_atrPeriod_eff) + 210;
   if(rates_total < minBars) return 0;

   //--- Input arrays as-series
   ArraySetAsSeries(time, true);
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);

   //--- Global arrays resize + as-series
   if(ArraySize(g_emaATR) != rates_total)
   {
      ArrayResize(g_emaATR, rates_total);
      ArraySetAsSeries(g_emaATR, true);
   }

   //--- Copy ATR from handle
   double atrTemp[];
   ArraySetAsSeries(atrTemp, true);
   if(CopyBuffer(g_atrHandle, 0, 0, rates_total, atrTemp) <= 0)
   {
      //--- ATR non pronto (handle appena creato post-TF switch): dashboard comunque visibile
      UpdateKPCDashboard(true);
      if(prev_calculated == 0) return 0;
      return prev_calculated;
   }

   //--- Dashboard forceRecalc: un toggle filtro richiede ricalcolo completo
   //    Impostiamo prev_calculated=0 per forzare il full reset sotto
   int prev_calc_adj = prev_calculated;
   if(g_forceRecalc)
   {
      prev_calc_adj = 0;
      g_forceRecalc = false;
   }

   //--- Start bar determination
   //    prev_calc_adj==0: ricalcolo completo (primo avvio, cambio TF, toggle filtro)
   //      → start = quasi tutta la storia, reset completo stati globali
   //    prev_calc_adj>0: incrementale (nuovo tick o nuova barra)
   //      → start = solo le barre nuove/modificate
   int start;
   if(prev_calc_adj == 0)
   {
      start = rates_total - g_kc_kamaPeriod_eff - 3;

      //--- Full reset di tutti gli stati globali
      g_lastMarkerBar     = 0;
      g_lastDirection     = 0;
      g_lastSignalPrice   = 0;
      g_lastSignalBandPrice = 0;
      g_lastSignalTime    = 0;
      ArrayResize(g_activeTPTargets, 0);
      g_tpTargetCounter   = 0;
      g_tpHitCounter      = 0;
      g_entryDotCounter   = 0;
      g_lastTouchDirection = 0;
      g_lastTouchTriggerBar = 0;
      g_prevBarTimeTT     = 0;
      s_lastAlertBar      = 0;

      // Squeeze state reset
      g_squeezeBarsCount      = 0;
      g_squeezeWasActive      = false;
      g_fireActive            = false;
      g_fireCooldownRemaining = 0;
      g_dcwRingIdx            = 0;
      g_dcwRingFilled         = false;
      ArrayInitialize(g_dcwRing, 0);

      ArrayInitialize(g_emaATR, 0);
      ArrayInitialize(BufEASigBuy, 0);
      ArrayInitialize(BufEASigSell, 0);

      DeleteTPTargetObjects();
   }
   else
   {
      start = rates_total - prev_calc_adj + 1;
   }

   // Boundary clamp
   if(start > rates_total - g_kc_kamaPeriod_eff - 3)
      start = rates_total - g_kc_kamaPeriod_eff - 3;
   if(start < 0) start = 0;

   //=================================================================
   //  MAIN LOOP
   //=================================================================
   for(int i = start; i >= 0; i--)
   {
      //--- Default EA buffers (written EVERY bar)
      BufEASigBuy[i]  = 0;
      BufEASigSell[i] = 0;
      BufFireSignal[i] = 0;

      //=== SECTION 1: KAMA + KC Bands ===
      //
      //  KAMA (Kaufman Adaptive Moving Average, Perry Kaufman 1995):
      //    ER  = |close[i] - close[i+N]| / Σ|close[k]-close[k+1]|
      //    SC  = (ER × (fastSC - slowSC) + slowSC)²
      //    KAMA[i] = KAMA[i+1] + SC × (close[i] - KAMA[i+1])
      //
      //  Proprietà chiave:
      //    ER→0 (ranging): SC→slowSC²≈0.004 → KAMA quasi ferma (ignora rumore)
      //    ER→1 (trending): SC→fastSC²≈0.444 → KAMA reattiva (segue prezzo)
      //    ER è già calcolato → zero overhead per il regime filter (Filtro 1)
      //
      double er = 0;
      if(i + g_kc_kamaPeriod_eff < rates_total)
      {
         double direction_val = MathAbs(close[i] - close[i + g_kc_kamaPeriod_eff]);
         double volatility = 0;
         for(int k = 0; k < g_kc_kamaPeriod_eff && (i + k + 1) < rates_total; k++)
            volatility += MathAbs(close[i + k] - close[i + k + 1]);
         er = (volatility > 1e-10) ? direction_val / volatility : 0;
      }
      BufERValue[i] = er;

      double fastSC = 2.0 / (InpKAMA_Fast + 1.0);
      double slowSC = 2.0 / (InpKAMA_Slow + 1.0);
      double sc = MathPow(er * (fastSC - slowSC) + slowSC, 2.0);

      if(i + g_kc_kamaPeriod_eff >= rates_total)
         BufKAMA[i] = close[i];
      else
         BufKAMA[i] = BufKAMA[i + 1] + sc * (close[i] - BufKAMA[i + 1]);

      // KC Bands
      double atrVal = atrTemp[i];
      BufATR[i] = atrVal;

      BufUpperPrimary[i] = BufKAMA[i] + atrVal * g_kc_multiplier_eff;
      BufLowerPrimary[i] = BufKAMA[i] - atrVal * g_kc_multiplier_eff;
      BufUpperHalf[i]    = BufKAMA[i] + atrVal * g_kc_halfMultiplier_eff;
      BufLowerHalf[i]    = BufKAMA[i] - atrVal * g_kc_halfMultiplier_eff;

      BufFillHigh[i] = BufUpperPrimary[i];
      BufFillLow[i]  = BufLowerPrimary[i];

      // KAMA Color (3 stati ER-based)
      if(er < g_kc_erRanging_eff)
         BufKAMAColor[i] = 2;  // grigio = ranging
      else if(i + 2 < rates_total && BufKAMA[i] > BufKAMA[i + 2])
         BufKAMAColor[i] = 0;  // verde = bull trend
      else if(i + 2 < rates_total && BufKAMA[i] < BufKAMA[i + 2])
         BufKAMAColor[i] = 1;  // rosso = bear trend
      else
         BufKAMAColor[i] = (i + 1 < rates_total) ? BufKAMAColor[i + 1] : 2;

      // Candle OHLC copy
      BufCandleO[i] = open[i];
      BufCandleH[i] = high[i];
      BufCandleL[i] = low[i];
      BufCandleC[i] = close[i];
      BufCandleColor[i] = (close[i] >= open[i]) ? 0.0 : 1.0;

      //=== SECTION 2: (Merged into Section 1 — KAMA color already calculated) ===

      //=== SECTION 3: Williams %R ===
      CalcWPR(high, low, close, i, g_kc_wprPeriod_eff, rates_total);

      //=== SECTION 4: ATR + EMA(ATR,200) + Squeeze tracking ===
      //
      //  EMA(ATR,200): volatilità smoothed per posizionare le frecce
      //    a distanza proporzionale (g_emaATR × InpArrowOffsetMult).
      //
      //  SQUEEZE DETECTION (3 condizioni simultanee):
      //    1. DCW (Donchian Channel Width / ATR) nel percentile basso
      //    2. ATR(5)/ATR(20) < soglia (volatilità recente compressa)
      //    3. Condizioni 1+2 attive per >= N barre consecutive
      //
      //  FIRE DETECTION (post-squeeze):
      //    Se DCW esplode (>20% vs barra precedente) dopo squeeze
      //    → g_fireActive=true → tutti i segnali bloccati (Filtro 4)
      //
      double alpha = 2.0 / (200.0 + 1.0);
      if(i + 1 < rates_total && g_emaATR[i + 1] > 0)
         g_emaATR[i] = alpha * atrVal + (1.0 - alpha) * g_emaATR[i + 1];
      else
         g_emaATR[i] = atrVal;

      // DCW (Donchian Channel Width normalizzato)
      double hh20 = high[i];
      double ll20 = low[i];
      for(int k = 1; k < 20 && (i + k) < rates_total; k++)
      {
         if(high[i + k] > hh20) hh20 = high[i + k];
         if(low[i + k] < ll20)  ll20 = low[i + k];
      }
      double dcwRaw = hh20 - ll20;
      BufDCW[i] = (atrVal > 1e-10) ? dcwRaw / atrVal : 0;

      // Ring buffer DCW for percentile
      g_dcwRing[g_dcwRingIdx] = BufDCW[i];
      g_dcwRingIdx++;
      if(g_dcwRingIdx >= InpDCWLookback)
      {
         g_dcwRingIdx = 0;
         g_dcwRingFilled = true;
      }

      // Calculate percentile — posizione del DCW corrente nello storico
      // countBelow = quanti valori storici sono MINORI del corrente
      // Se DCW è BASSO (squeeze): pochi sotto → percentile BASSO → squeezeNow=TRUE
      // Se DCW è ALTO (no squeeze): molti sotto → percentile ALTO → squeezeNow=FALSE
      // FIX v1.04: era invertito (usava > invece di <), la squeeze si attivava
      //   durante ALTA volatilità anziché durante compressione — bug dalla v1.00.
      int ringCount = g_dcwRingFilled ? InpDCWLookback : g_dcwRingIdx;
      double g_dcwPercentile = 0.5;  // default neutro
      if(ringCount > 0)
      {
         int countBelow = 0;
         for(int r = 0; r < ringCount; r++)
         {
            if(g_dcwRing[r] < BufDCW[i]) countBelow++;  // FIX: era > (INVERTITO)
         }
         g_dcwPercentile = (double)countBelow / (double)ringCount;
      }

      // ATR ratio (fast/slow)
      double atrFast = CalcATRSimple(high, low, close, i, InpATRFastPeriod, rates_total);
      double atrSlow = CalcATRSimple(high, low, close, i, InpATRSlowPeriod, rates_total);
      BufATRRatio[i] = (atrSlow > 1e-10) ? atrFast / atrSlow : 1.0;

      // Squeeze state
      // ATR Ratio opzionale: default false = solo DCW percentile (+30-40% segnali)
      // true = AND ATR Ratio (massima selettività, come v1.02)
      bool squeezeNow = (g_dcwPercentile < (double)g_kc_dcwPercentile_eff / 100.0) &&
                        (!InpUseATRRatioFilter || BufATRRatio[i] < g_kc_atrRatioThresh_eff);
      // Decay graduale (v1.04): una barra non-squeeze decrementa di 1 anziché
      // resettare a 0. Il DCW oscilla naturalmente attorno alla soglia percentile;
      // il reset aggressivo distruggeva squeeze valide con micro-interruzioni.
      // Con decay, 4 barre squeeze + 1 fuori → count=3, la barra dopo in squeeze
      // lo riporta a 4. Serve una rottura prolungata per azzerare il contatore.
      if(squeezeNow)
         g_squeezeBarsCount++;
      else if(g_squeezeBarsCount > 0)
         g_squeezeBarsCount--;
      // (se squeezeBarsCount era già 0, resta 0)

      BufSqueezeState[i] = squeezeNow ? 1.0 : 0.0;

      // Track squeeze was active
      if(g_squeezeBarsCount >= 3)
         g_squeezeWasActive = true;

      // Fire detection
      KCCheckFire(i, rates_total);

      // Squeeze histogram
      if(g_fireActive)
      {
         BufSqueezeHist[i] = 2.0;
         BufSqueezeHistColor[i] = 2;  // verde = fire
      }
      else if(squeezeNow)
      {
         BufSqueezeHist[i] = 1.0;
         BufSqueezeHistColor[i] = 1;  // rosso = squeeze
      }
      else
      {
         BufSqueezeHist[i] = 0.5;
         BufSqueezeHistColor[i] = 0;  // grigio = normale
      }


      //=== SECTION 4.6: TP Target tracking — Dual TP (hit/update/expiry) ===
      //
      //  TP1 (tp_type=1): prezzo fisso KAMA congelato al momento segnale
      //    Hit: high[i] >= price (BUY) oppure low[i] <= price (SELL)
      //    Expiry: barAge >= InpTP1Expiry
      //
      //  TP2 (tp_type=2): banda opposta dinamica, aggiornata ogni barra
      //    Hit: high[i] >= BufUpperPrimary[i] (BUY) oppure low[i] <= BufLowerPrimary[i] (SELL)
      //         AND close[i] oltre minProfitLevel (guardia profitto minimo)
      //    Update: linea spostata a BufUpperPrimary[i]/BufLowerPrimary[i] ogni barra
      //    Fire kill: se g_fireActive → TP2 chiuso come "annullato" (non come hit)
      //    Expiry: barAge >= InpTP2MaxExpiry (default 20, molto più breve di TP1)
      //
      for(int t_idx = ArraySize(g_activeTPTargets) - 1; t_idx >= 0; t_idx--)
      {
         bool tpTargetHit  = false;
         bool tpCancelled  = false;
         int  tpType       = g_activeTPTargets[t_idx].tp_type;

         // ── Fire kill switch: annulla solo TP2 ──
         if(tpType == 2 && g_fireActive)
         {
            tpCancelled = true;
         }

         if(tpCancelled)
         {
            ObjectSetInteger(0, g_activeTPTargets[t_idx].lineName, OBJPROP_COLOR, clrDarkGray);
            ObjectSetInteger(0, g_activeTPTargets[t_idx].lineName, OBJPROP_STYLE, STYLE_DOT);
            ObjectSetInteger(0, g_activeTPTargets[t_idx].lineName, OBJPROP_RAY_RIGHT, false);
            ObjectSetInteger(0, g_activeTPTargets[t_idx].dotName,  OBJPROP_COLOR, clrDarkGray);
            ArrayRemove(g_activeTPTargets, t_idx, 1);
            continue;
         }

         if(tpType == 1)
         {
            // TP1: check prezzo fisso KAMA
            if(g_activeTPTargets[t_idx].isBuy && high[i] >= g_activeTPTargets[t_idx].price)
               tpTargetHit = true;
            else if(!g_activeTPTargets[t_idx].isBuy && low[i] <= g_activeTPTargets[t_idx].price)
               tpTargetHit = true;
         }
         else // tpType == 2
         {
            // TP2: check dinamico banda opposta + guardia profitto minimo
            if(g_activeTPTargets[t_idx].isBuy)
            {
               if(high[i] >= BufUpperPrimary[i] &&
                  close[i] > g_activeTPTargets[t_idx].minProfitLevel)
                  tpTargetHit = true;
            }
            else
            {
               if(low[i] <= BufLowerPrimary[i] &&
                  close[i] < g_activeTPTargets[t_idx].minProfitLevel)
                  tpTargetHit = true;
            }

            // Aggiorna posizione linea TP2 ogni barra (segue banda corrente)
            if(!tpTargetHit && InpShowTP2Line)
            {
               double currentBand = g_activeTPTargets[t_idx].isBuy ?
                                    BufUpperPrimary[i] : BufLowerPrimary[i];
               ObjectMove(0, g_activeTPTargets[t_idx].lineName, 0,
                          time[i], currentBand);
               ObjectMove(0, g_activeTPTargets[t_idx].lineName, 1,
                          time[i] + PeriodSeconds() * 500, currentBand);
            }
         }

         if(tpTargetHit)
         {
            int signalBarI = iBarShift(_Symbol, PERIOD_CURRENT, g_activeTPTargets[t_idx].signalTime);
            int barsToTP = (signalBarI >= 0) ? signalBarI - i : 0;
            // Per TP2 il pipsMove è dalla entryBandLevel alla banda corrente
            double hitPrice  = (tpType == 2) ?
                               (g_activeTPTargets[t_idx].isBuy ? BufUpperPrimary[i] : BufLowerPrimary[i]) :
                               g_activeTPTargets[t_idx].price;
            double pipsMove  = MathAbs(hitPrice - g_activeTPTargets[t_idx].signalPrice) / _Point;
            if(_Digits == 5 || _Digits == 3)
               pipsMove /= 10.0;
            CloseTPTarget(t_idx, time[i], barsToTP, pipsMove, hitPrice);
         }
         else
         {
            // Expiry check: timeout diverso per TP1 e TP2
            int expiryBars = (tpType == 2 && InpTP2MaxExpiry > 0) ? InpTP2MaxExpiry : InpTP1Expiry;
            if(expiryBars > 0)
            {
               int signalBarI_exp = iBarShift(_Symbol, PERIOD_CURRENT, g_activeTPTargets[t_idx].signalTime);
               int barAge = (signalBarI_exp >= 0) ? signalBarI_exp - i : 0;
               if(barAge >= expiryBars)
               {
                  double expPrice = (tpType == 2) ?
                                    (g_activeTPTargets[t_idx].isBuy ? BufUpperPrimary[i] : BufLowerPrimary[i]) :
                                    g_activeTPTargets[t_idx].price;
                  ObjectSetInteger(0, g_activeTPTargets[t_idx].lineName, OBJPROP_COLOR, clrDarkGray);
                  ObjectSetInteger(0, g_activeTPTargets[t_idx].lineName, OBJPROP_STYLE, STYLE_DOT);
                  ObjectSetInteger(0, g_activeTPTargets[t_idx].lineName, OBJPROP_RAY_RIGHT, false);
                  ObjectMove(0, g_activeTPTargets[t_idx].lineName, 1, time[i], expPrice);
                  ObjectSetInteger(0, g_activeTPTargets[t_idx].dotName, OBJPROP_COLOR, clrDarkGray);
                  ArrayRemove(g_activeTPTargets, t_idx, 1);
               }
            }
         }
      }

      //=== SECTION 5: Signal Detection (4 fasi) ===
      //
      //  FASE 1: Base conditions — tocco KC band + wick ratio ≥ 40%
      //    touchUpperPrimary: high sfonda Upper Primary, close rientra (rejection)
      //    touchUpperHalf: high sfonda Half MA NON Primary (exclusive)
      //    Wick ratio: shadow / candleSize ≥ 0.40 (rejection genuina)
      //    bearQuality=2 (Primary, freccia grande) o 1 (Half, freccia piccola)
      //
      //  FASE 2: 7 filtri in cascata (F8 Session rimosso in v1.08)
      //    F1: ER > 0.60 → trending → BLOCCA (MR non funziona in trend)
      //    F2: squeeze < N barre → compressione non matura → BLOCCA
      //    F3: DCW in espansione → squeeze dissolving → BLOCCA (OFF default)
      //    F4: g_fireActive → breakout in corso → BLOCCA
      //    F5: WPR non a OB/OS → momentum insufficiente → BLOCCA (OFF default)
      //    F6: distanza band-KAMA < min pip → TP troppo piccolo → BLOCCA
      //    F7: fascia oraria bloccata → BLOCCA (OFF default)
      //
      //  FASE 3: SimpleCooldown
      //    Stesso verso: richiede tocco KAMA + N barre dopo tocco
      //    Verso opposto: solo N barre minime
      //    Fire block: se fireActive → cooldown non passa mai
      //
      //  FASE 4: Esecuzione segnale
      //    Freccia, label, candle trigger, EA buffer, TP target, entry dot, alert
      //
      BufSigSellPrim[i] = EMPTY_VALUE;
      BufSigBuyPrim[i]  = EMPTY_VALUE;
      BufSigSellHalf[i] = EMPTY_VALUE;
      BufSigBuyHalf[i]  = EMPTY_VALUE;

      if(i + 2 < rates_total)
      {
         int currentBarIdx = rates_total - 1 - i;
         int barsFromLast  = currentBarIdx - g_lastMarkerBar;

         //=== FASE 1: BASE CONDITIONS =====================================
         //  Condizione fondamentale per generare un segnale mean-reversion:
         //
         //  1. BAND TOUCH: il prezzo deve BUCARE la banda KC e CHIUDERE DENTRO
         //     - SELL: high > banda superiore AND close < banda superiore
         //     - BUY:  low  < banda inferiore AND close > banda inferiore
         //     Questo conferma che la banda ha agito come resistenza/supporto.
         //
         //  2. WICK RATIO: lo stoppino di rejection deve essere >= InpWickRatio
         //     della dimensione totale della candela. Esempio: wick 25% = la candela
         //     ha rifiutato almeno 1/4 del suo range nella direzione della banda.
         //     Senza wick: il prezzo ha solo "toccato" la banda senza rifiutarla.
         //
         //  3. QUALITÀ: Primary (quality=2) se tocca banda esterna (moltiplicatore pieno),
         //     Half (quality=1) se tocca solo banda interna (metà moltiplicatore).
         //     Primary = segnale più forte (prezzo ha raggiunto l'estremo).
         //
         //  4. DUE MODALITÀ:
         //     - BAR_CLOSE: valuta solo barre chiuse (i>=1), più affidabile
         //     - INTRABAR: valuta anche barra corrente, più reattivo ma meno sicuro
         //=================================================================
         bool bearBase = false;
         bool bullBase = false;
         int  bearQuality = 0;
         int  bullQuality = 0;

         if(InpTriggerModeV2 == TRIGGER_BAR_CLOSE)
         {
            if(i >= 1)
            {
               // Touch: prezzo buca banda ma chiude dentro (rejection confermata)
               bool touchUpperPrimary = (high[i] > BufUpperPrimary[i]) && (close[i] < BufUpperPrimary[i]);
               bool touchUpperHalf    = (high[i] > BufUpperHalf[i])    && (close[i] < BufUpperHalf[i])
                                        && (high[i] <= BufUpperPrimary[i]);
               bool touchLowerPrimary = (low[i] < BufLowerPrimary[i])  && (close[i] > BufLowerPrimary[i]);
               bool touchLowerHalf    = (low[i] < BufLowerHalf[i])     && (close[i] > BufLowerHalf[i])
                                        && (low[i] >= BufLowerPrimary[i]);

               // Wick: stoppino di rejection / dimensione candela
               double upperWick  = high[i] - MathMax(open[i], close[i]);
               double lowerWick  = MathMin(open[i], close[i]) - low[i];
               double candleSize = high[i] - low[i];
               bool wickOK = (candleSize > _Point * 2);  // candela non degenere

               double wickRatioUpper = wickOK ? upperWick / candleSize : 0;
               double wickRatioLower = wickOK ? lowerWick / candleSize : 0;

               bearBase = (touchUpperPrimary || touchUpperHalf) && (wickRatioUpper >= InpWickRatio);
               bullBase = (touchLowerPrimary || touchLowerHalf) && (wickRatioLower >= InpWickRatio);
               bearQuality = touchUpperPrimary ? 2 : 1;  // 2=Primary, 1=Half
               bullQuality = touchLowerPrimary ? 2 : 1;
            }
         }
         else  // TRIGGER_INTRABAR — valuta anche barra corrente (bar 0)
         {
            bool touchUpperPrimary = (high[i] > BufUpperPrimary[i]);
            bool touchUpperHalf    = (high[i] > BufUpperHalf[i]) && (high[i] <= BufUpperPrimary[i]);
            bool touchLowerPrimary = (low[i] < BufLowerPrimary[i]);
            bool touchLowerHalf    = (low[i] < BufLowerHalf[i]) && (low[i] >= BufLowerPrimary[i]);

            double upperWick  = high[i] - MathMax(open[i], close[i]);
            double lowerWick  = MathMin(open[i], close[i]) - low[i];
            double candleSize = high[i] - low[i];
            bool wickOK = (candleSize > _Point * 2);

            double wickRatioUpper = wickOK ? upperWick / candleSize : 0;
            double wickRatioLower = wickOK ? lowerWick / candleSize : 0;

            bearBase = (touchUpperPrimary || touchUpperHalf) && (wickRatioUpper >= InpWickRatio);
            bullBase = (touchLowerPrimary || touchLowerHalf) && (wickRatioLower >= InpWickRatio);
            bearQuality = touchUpperPrimary ? 2 : 1;
            bullQuality = touchLowerPrimary ? 2 : 1;
         }

         // Anti-ambiguità: se la candela tocca ENTRAMBE le bande (doji estrema),
         // il segnale è ambiguo → annulla entrambi per evitare falsi
         if(bearBase && bullBase) { bearBase = false; bullBase = false; }

         //=== FASE 2: FILTRI KPC (tutti togglabili via dashboard) ==========
         //
         //  Architettura filtri v1.05:
         //  ─────────────────────────────────────────────────────────────────
         //  ATTIVI (ON default) — ciascuno misura un asse INDIPENDENTE:
         //    F1: Regime (ER)       → trend vs range — ESSENZIALE, unico filtro regime
         //    F2: Squeeze (DCW%)    → volatilità compressa — info indipendente da F1
         //    F4: Fire (DCW spike)  → breakout istantaneo — 1-2 barre più veloce di F1
         //    F6: Width (pip/TF)    → viabilità trade — canale min pip per TF (stile DPC v7.19)
         //
         //  DISATTIVATI (OFF default) — ridondanti o preferenza utente:
         //    F3: DCW Slope         → RIDONDANTE: coperto da F2 decay + F4 spike
         //    F5: Williams %R       → RIDONDANTE: ~90% correlato con band touch + F1
         //    F7: Time Block        → preferenza utente
         //
         //  Parametri impostati come "safety net" larghi:
         //    F1: ER 0.60 (solo trend estremi), F2: minBars 1-2 (qualsiasi compressione),
         //    F4: cooldown 2 barre (protezione minima), F6: 1-2 pip (solo canali assurdi)
         //  ─────────────────────────────────────────────────────────────────

         // ── F1: ER REGIME (asse: forza del trend) ──────────────────────
         //    Efficiency Ratio = |move direzionale| / somma |move singoli|
         //    ER vicino a 1 = trend forte (prezzo va dritto)
         //    ER vicino a 0 = range/chop (prezzo oscilla)
         //    Blocca segnali MR quando ER supera soglia (trend troppo forte
         //    per aspettarsi un rimbalzo dalla banda).
         //    ESSENZIALE: senza questo, frecce suicide contro trend parabolici.
         if(g_dash_F1_erRegime && BufERValue[i] > g_kc_erTrending_eff)
         { bearBase = false; bullBase = false; }

         // ── F2: SQUEEZE DURATION (asse: compressione volatilità) ───────
         //    Conta barre consecutive con DCW nel percentile basso.
         //    Logica: in compressione le bande sono strette → il tocco banda
         //    ha più significato (confine reale, non rumore).
         //    Info INDIPENDENTE da F1: puoi avere range (ER basso) ma canale
         //    largo (no squeeze) → meno affidabile.
         //    Soglia minima: 1-2 barre (safety net, non filtro aggressivo).
         if(g_dash_F2_squeeze && g_squeezeBarsCount < g_kc_minSqueezeBars_eff)
         { bearBase = false; bullBase = false; }

         // ── F3: DCW SLOPE (OFF default — RIDONDANTE) ───────────────────
         //    Misura espansione del canale su 2 barre.
         //    RIDONDANTE perché:
         //    - Espansione graduale → F2 decade naturalmente (squeeze count -1/barra)
         //    - Espansione esplosiva → F4 (fire) la cattura in 1 barra
         //    Mantenuto come toggle opzionale per chi vuole massima selettività.
         if(g_dash_F3_dcwSlope && i + 2 < rates_total && BufDCW[i] > BufDCW[i + 2] * 1.25)
         { bearBase = false; bullBase = false; }

         // ── F4: FIRE KILL SWITCH (asse: breakout istantaneo) ───────────
         //    Rileva spike DCW post-squeeze (+20% in 1 barra o +15% in 2).
         //    Info PARZIALMENTE INDIPENDENTE da F1: ER reagisce in ~10 barre,
         //    fire cattura il breakout entro 1-2 barre → copre la finestra
         //    temporale dove F1 non ha ancora reagito.
         //    Cooldown minimo: 2 barre (protezione rapida senza blocco lungo).
         if(g_dash_F4_fire && g_fireActive)
         { bearBase = false; bullBase = false; }

         // ── F5: WILLIAMS %R (OFF default — RIDONDANTE) ─────────────────
         //    Richiede WPR a estremi (OB per sell, OS per buy).
         //    RIDONDANTE perché:
         //    - Prezzo che tocca banda superiore È già overbought (~90% dei casi)
         //    - Il wick ratio nella base condition conferma già il momentum
         //    - Nel 10% restante (prezzo "striscia" sulla banda), F1 blocca
         //    Mantenuto come toggle opzionale.
         if(g_dash_F5_wpr && InpUseMomentum)
         {
            if(bearBase && BufWPR[i] <= g_kc_wprOB_eff) bearBase = false;
            if(bullBase && BufWPR[i] >= g_kc_wprOS_eff) bullBase = false;
         }

         // ── F6: LARGHEZZA MINIMA CANALE (asse: viabilità del trade) ─────
         //    Stessa logica del DPC v7.19: misura larghezza TOTALE del canale
         //    KC (upper primary - lower primary) in pip.
         //    Il TP target è ~metà canale (distanza banda → KAMA).
         //    Se il canale è troppo stretto, il TP non copre spread + commissioni.
         //
         //    Tutti i TF: canale min 10 pip → TP min ~5 pip.
         //    Con 0.01 lot EURUSD: TP 5 pip = $0.50, netto ~$0.35 dopo spread.
         //
         //    NOTA: il rapporto ATR NON funziona per KC perché
         //    (upper - KAMA) = multiplier × ATR → rapporto costante per costruzione.
         //    Il pip-based è la soluzione corretta (testata nel DPC da v7.05).
         if(g_dash_F6_width && InpUseWidthFilter)
         {
            double pipSize = (_Digits == 5 || _Digits == 3) ? _Point * 10.0 : _Point;
            double channelWidthPips = (BufUpperPrimary[i] - BufLowerPrimary[i]) / pipSize;
            if(channelWidthPips < g_kc_minWidthPips_eff) { bearBase = false; bullBase = false; }
         }

         // ── F7: TIME BLOCK (OFF default — preferenza utente) ───────────
         if(g_dash_F7_time && IsInBlockedTime(time[i]))
         { bearBase = false; bullBase = false; }

         //=== FASE 3: COOLDOWN (anti-spam segnali) ==========================
         //  Evita raffica di frecce consecutive sulla stessa zona.
         //
         //  - Stesso verso (es. SELL→SELL): richiede g_nSameBars barre di pausa
         //  - Verso opposto (es. SELL→BUY): richiede g_nOppositeBars barre
         //  - Primo segnale in assoluto: nessun cooldown
         //
         //  Fire block (se F4 ON): durante un breakout post-squeeze attivo,
         //  blocca tutti i segnali MR. Condizionato al toggle F4 dashboard.
         //=================================================================
         bool bearCooldownOK = false;
         bool bullCooldownOK = false;

         if(g_lastDirection == 0)
         {
            bearCooldownOK = true;   // primo segnale: nessun cooldown
            bullCooldownOK = true;
         }
         else if(g_lastDirection == -1)   // ultimo segnale era SELL
         {
            bearCooldownOK = (barsFromLast >= g_nSameBars);     // SELL→SELL: stesso verso
            bullCooldownOK = (barsFromLast >= g_nOppositeBars); // SELL→BUY: inversione
         }
         else                             // ultimo segnale era BUY
         {
            bullCooldownOK = (barsFromLast >= g_nSameBars);     // BUY→BUY: stesso verso
            bearCooldownOK = (barsFromLast >= g_nOppositeBars); // BUY→SELL: inversione
         }

         // Fire block — rispetta toggle F4 dashboard (fix v1.05: era hardcoded)
         if(g_dash_F4_fire && g_fireActive)
         { bearCooldownOK = false; bullCooldownOK = false; }

         bool bearCond = bearBase && bearCooldownOK;
         bool bullCond = bullBase && bullCooldownOK;

         //--- Debug
         if(InpDebugMode && (bearBase || bullBase))
         {
            string dir = (g_lastDirection == +1) ? "BUY" : (g_lastDirection == -1) ? "SELL" : "NONE";
            if(bearBase)
               Print("[KPC] SELL base=OK cooldown=", (bearCooldownOK ? "OK" : "BLOCK"),
                     " fire=", g_fireActive, " squeeze=", g_squeezeBarsCount,
                     " ER=", DoubleToString(BufERValue[i], 3),
                     " WPR=", DoubleToString(BufWPR[i], 1),
                     " FINAL=", (bearCond ? "ACCETTATO" : "BLOCCATO"),
                     " | lastDir=", dir);
            if(bullBase)
               Print("[KPC] BUY base=OK cooldown=", (bullCooldownOK ? "OK" : "BLOCK"),
                     " fire=", g_fireActive, " squeeze=", g_squeezeBarsCount,
                     " ER=", DoubleToString(BufERValue[i], 3),
                     " WPR=", DoubleToString(BufWPR[i], 1),
                     " FINAL=", (bullCond ? "ACCETTATO" : "BLOCCATO"),
                     " | lastDir=", dir);
         }

         double offset = g_emaATR[i] * InpArrowOffsetMult;

         //=== FASE 4: ESECUZIONE SEGNALE SELL ===
         if(bearCond)
         {
            // Fix #2: stato solo su barre chiuse
            if(i >= 1)
            {
               g_lastMarkerBar  = currentBarIdx;
               g_lastDirection  = -1;
            }

            double bandLevel = (bearQuality == 2) ? BufUpperPrimary[i] : BufUpperHalf[i];
            double sellPrice = bandLevel + offset;

            if(bearQuality == 2)
               BufSigSellPrim[i] = sellPrice;
            else
               BufSigSellHalf[i] = sellPrice;

            // Label
            CreateSignalArrow(time[i], sellPrice, false, offset, close[i], BufKAMA[i], bearQuality);

            // Trigger candle
            if(InpShowTriggerCandle)
               BufCandleColor[i] = (bearQuality == 2) ? 2.0 : 3.0;

            // EA buffer
            BufEASigSell[i] = (bearQuality == 2) ? 1.0 : 0.5;

            // TP, Entry Dot (solo su barre chiuse)
            if(i >= 1)
            {
               g_lastSignalTime      = time[i];
               g_lastSignalPrice     = sellPrice;
               g_lastSignalBandPrice = bandLevel;

               // TP1: KAMA midline (fisso)
               CreateTP1Target(time[i], CalcTPConservative(BufKAMA[i], false), false, sellPrice);

               // TP2: touch banda opposta dinamico
               if(InpEnableTP2)
               {
                  double pipSz = (_Digits == 5 || _Digits == 3) ? _Point * 10.0 : _Point;
                  double minProfit2 = bandLevel - InpTP2MinProfitPips * pipSz;
                  double initBand2  = BufLowerPrimary[i];
                  CreateTP2Target(time[i], false, sellPrice, bandLevel, minProfit2, initBand2);
               }

               if(InpShowEntryDot)
               {
                  g_entryDotCounter++;
                  string entDotName = ENTRY_DOT_PREFIX + "SELL_" + IntegerToString(g_entryDotCounter);
                  ObjectCreate(0, entDotName, OBJ_ARROW, 0, time[i], bandLevel);
                  ObjectSetInteger(0, entDotName, OBJPROP_ARROWCODE, 164);
                  ObjectSetInteger(0, entDotName, OBJPROP_COLOR, InpColEntryDot);
                  ObjectSetInteger(0, entDotName, OBJPROP_WIDTH, 2);
                  ObjectSetInteger(0, entDotName, OBJPROP_ANCHOR, ANCHOR_BOTTOM);
                  ObjectSetInteger(0, entDotName, OBJPROP_BACK, false);
                  ObjectSetString(0, entDotName, OBJPROP_TOOLTIP,
                     "ENTRY SELL @ " + DoubleToString(bandLevel, _Digits));
               }
            }

            // Alert
            if(i == 0 && time[0] != s_lastAlertBar)
            {
               s_lastAlertBar = time[0];
               string qualStr = (bearQuality == 2) ? "PRIMARY" : "HALF";
               if(InpAlertPopup)
                  Alert("KPC: SELL [" + qualStr + "] su " + _Symbol + " " + EnumToString(_Period));
            }
         }

         //=== FASE 4: ESECUZIONE SEGNALE BUY ===
         if(bullCond)
         {
            if(i >= 1)
            {
               g_lastMarkerBar  = currentBarIdx;
               g_lastDirection  = +1;
            }

            double bandLevel = (bullQuality == 2) ? BufLowerPrimary[i] : BufLowerHalf[i];
            double buyPrice  = bandLevel - offset;

            if(bullQuality == 2)
               BufSigBuyPrim[i] = buyPrice;
            else
               BufSigBuyHalf[i] = buyPrice;

            CreateSignalArrow(time[i], buyPrice, true, offset, close[i], BufKAMA[i], bullQuality);

            if(InpShowTriggerCandle)
               BufCandleColor[i] = (bullQuality == 2) ? 2.0 : 3.0;

            BufEASigBuy[i] = (bullQuality == 2) ? 1.0 : 0.5;

            if(i >= 1)
            {
               g_lastSignalTime      = time[i];
               g_lastSignalPrice     = buyPrice;
               g_lastSignalBandPrice = bandLevel;

               // TP1: KAMA midline (fisso)
               CreateTP1Target(time[i], CalcTPConservative(BufKAMA[i], true), true, buyPrice);

               // TP2: touch banda opposta dinamico
               if(InpEnableTP2)
               {
                  double pipSz = (_Digits == 5 || _Digits == 3) ? _Point * 10.0 : _Point;
                  double minProfit2 = bandLevel + InpTP2MinProfitPips * pipSz;
                  double initBand2  = BufUpperPrimary[i];
                  CreateTP2Target(time[i], true, buyPrice, bandLevel, minProfit2, initBand2);
               }

               if(InpShowEntryDot)
               {
                  g_entryDotCounter++;
                  string entDotName = ENTRY_DOT_PREFIX + "BUY_" + IntegerToString(g_entryDotCounter);
                  ObjectCreate(0, entDotName, OBJ_ARROW, 0, time[i], bandLevel);
                  ObjectSetInteger(0, entDotName, OBJPROP_ARROWCODE, 164);
                  ObjectSetInteger(0, entDotName, OBJPROP_COLOR, InpColEntryDot);
                  ObjectSetInteger(0, entDotName, OBJPROP_WIDTH, 2);
                  ObjectSetInteger(0, entDotName, OBJPROP_BACK, false);
                  ObjectSetString(0, entDotName, OBJPROP_TOOLTIP,
                     "ENTRY BUY @ " + DoubleToString(bandLevel, _Digits));
               }
            }

            if(i == 0 && time[0] != s_lastAlertBar)
            {
               s_lastAlertBar = time[0];
               string qualStr = (bullQuality == 2) ? "PRIMARY" : "HALF";
               if(InpAlertPopup)
                  Alert("KPC: BUY [" + qualStr + "] su " + _Symbol + " " + EnumToString(_Period));
            }
         }
      }
   }  // end main loop

   //=== 5a. Reset Touch Trigger (Fix #1) ===
   //  Su nuova barra, g_lastTouchDirection=0 → permette nuovo trigger.
   //  Senza reset, il trigger della barra precedente bloccherebbe la nuova.
   if(time[0] != g_prevBarTimeTT)
   {
      g_prevBarTimeTT = time[0];
      g_lastTouchDirection = 0;
   }

   //=== 5b. Touch Trigger Buffer for EA (simplified KC version) ===
   // BufEASigBuy/Sell already written in main loop

   //=== Section 6: (Forecast removed — squeeze histogram updated in loop) ===

   //=== Section 7: Canvas Redraw ===
   RedrawCanvas();

   //=== Section 8: Dashboard Update ===
   UpdateKPCDashboard();

   return rates_total;
}
//+------------------------------------------------------------------+
