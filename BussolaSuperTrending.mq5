//+------------------------------------------------------------------+
//|                                         BussolaSuperTrending.mq5 |
//|                     BUSSOLA SUPERTRENDING — Indicatore Direzionale|
//|                     Versione 2.07                                  |
//+------------------------------------------------------------------+
//|                                                                  |
//|  ARCHITETTURA A 7 COMPONENTI (anti-overfitting):                 |
//|                                                                  |
//|  1. ST LENTO (KAMA-based default)                                |
//|     - Compito UNICO: direzione DOMINANTE del mercato             |
//|     - KAMA si adatta: ranging=fermo, trending=reattivo           |
//|     - Genera il filtro primario per ENTRY                        |
//|                                                                  |
//|  2. ST VELOCE (HMA-based default)                                |
//|     - Compito UNICO: micro-trend + timing EXIT                   |
//|     - HMA ha lag quasi zero (3-5 barre vs 8-12 EMA)              |
//|     - Flip = segnale EXIT primario                               |
//|                                                                  |
//|  3. KELTNER CHANNEL                                              |
//|     - Compito UNICO: filtro FORZA movimento                      |
//|     - Prezzo FUORI Keltner = movimento con forza reale           |
//|     - NON ridondante con ATR (ATR gia' incluso nel Keltner)      |
//|                                                                  |
//|  4. DONCHIAN CHANNEL                                             |
//|     - Compito UNICO: trigger BREAKOUT oggettivo                  |
//|     - Close > Upper[i+1] = breakout confermato (barra precedente)|
//|     - Midline color-switch = orientamento immediato              |
//|     - Canvas fill semitrasparente colorato da stato ST Lento     |
//|                                                                  |
//|  5. EFFICIENCY RATIO (ER) — ex Choppiness Index                  |
//|     - Compito UNICO: qualita' trend (ranging vs trending)        |
//|     - ER > 0.40 = trend forte, ER < 0.18 = ranging/caos         |
//|     - Calcolato nativamente dalla KAMA (zero overhead)           |
//|                                                                  |
//|  6. FISHER TRANSFORM                                             |
//|     - Compito UNICO: picco momentum (allerta precoce EXIT)       |
//|     - Anticipa di 1-4 barre il flip del ST Veloce                |
//|     - NON ridondante (momentum vs prezzo)                        |
//|                                                                  |
//|  7. MTF SUPERTREND OVERLAY (v1.20)                               |
//|     - SuperTrend KAMA Lento calcolato su TF superiore (es. M15)  |
//|     - Proiettato sul chart corrente (M5) con effetto gradino     |
//|     - Gate entry opzionale: blocca segnali contro trend MTF      |
//|     - Zero repaint: usa solo barre MTF chiuse (shift >= 1)       |
//|                                                                  |
//|  REGOLA ANTI-REPAINTING:                                         |
//|  Tutti i segnali vengono generati SOLO su bar[1] (barra chiusa). |
//|  Bar[0] mostra solo le linee in tempo reale, MAI frecce.         |
//|                                                                  |
//|  CHANGELOG v2.06-v2.07:                                          |
//|  FIX-E: riordino buffer→plot (indici 17-23 allineati ai plot)   |
//|  FIX-A: canvas fill rispetta toggle dashboard g_vis_donchian     |
//|  FIX-B: RedrawCanvas(true) nel handler toggle per update istant. |
//|  FIX-C: toggle MTF SuperTrend nella dashboard (7° bottone)      |
//|  FIX-F: Donchian breakout usa [i+1] (barra precedente) non [i]  |
//|  FIX-G: dashboard visibile durante warmup sub-indicatori         |
//|                                                                  |
//+------------------------------------------------------------------+
#include <Canvas/Canvas.mqh>

#property copyright   "TIVANIO — Bussola SuperTrending"
#property version     "2.07"
#property description "Bussola direzionale intraday: SuperTrend KAMA+HMA, Keltner,"
#property description "Donchian, Choppiness Index, Fisher Transform (Ehlers)"
#property description "Segnali ENTRY frecce e EXIT stella senza repaint"

//--- L'indicatore si disegna nella finestra principale del grafico (sui prezzi)
//    NON in una subchart separata. Tutti i componenti si sovrappongono alle candele.
#property indicator_chart_window

//--- 28 buffer totali:
//    - Buffer 0-23: INDICATOR_DATA e INDICATOR_COLOR_INDEX (visibili, plots 0-17)
//    - Buffer 24-31: INDICATOR_CALCULATIONS (invisibili, per EA via CopyBuffer)
#property indicator_buffers 32   // v1.20: +4 MTF (BufMTFBull, Bear, Dir, Value)

//--- 18 plot visibili nella finestra dati (Data Window):
//    Plot 0-3: ST Lento/Veloce Bull/Bear (4 x DRAW_LINE)
//    Plot 4-6: Keltner Up/Low/Mid (3 x DRAW_LINE)
//    Plot 7-9: Donchian Up/Low/Mid (2 x DRAW_LINE + 1 x DRAW_COLOR_LINE)
//    Plot 10-13: Frecce Entry/Exit (4 x DRAW_ARROW)
//    Plot 14: Fisher Band (DRAW_COLOR_LINE)
//    Plot 15-16: MTF SuperTrend Bull/Bear (2 x DRAW_LINE) — v1.20
//    Plot 17: Candele colorate (DRAW_COLOR_CANDLES) — SEMPRE ULTIMO
#property indicator_plots   18

// ═══════════════════════════════════════════════════════════════════
// PLOT DECLARATIONS
// Ogni plot definisce tipo, colore, stile e spessore della linea/freccia.
// L'ordine dei plot e' CRITICO: DRAW_COLOR_CANDLES deve essere ULTIMO
// per essere disegnato SOPRA tutte le altre linee.
// ═══════════════════════════════════════════════════════════════════

// ─────────────────────────────────────────────────────────────────
// PLOT 0: ST LENTO BULL — Linea sotto il prezzo in uptrend
// Visibile quando il SuperTrend Lento e' in stato BULLISH.
// Colore blu (DodgerBlue) per indicare direzione dominante LONG.
// Spessore 2: linea principale, ben visibile.
// ─────────────────────────────────────────────────────────────────
#property indicator_label1  "ST Lento Bull"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

// ─────────────────────────────────────────────────────────────────
// PLOT 1: ST LENTO BEAR — Linea sopra il prezzo in downtrend
// Visibile quando il SuperTrend Lento e' in stato BEARISH.
// Colore arancio-rosso per indicare direzione dominante SHORT.
// ─────────────────────────────────────────────────────────────────
#property indicator_label2  "ST Lento Bear"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrOrangeRed
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2

// ─────────────────────────────────────────────────────────────────
// PLOT 2: ST VELOCE BULL — Trailing stop in uptrend
// Spessore 1 (piu' sottile del ST Lento) per distinzione visiva.
// Colore lime vivace per contrasto immediato.
// ─────────────────────────────────────────────────────────────────
#property indicator_label3  "ST Veloce Bull"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrLime
#property indicator_style3  STYLE_SOLID
#property indicator_width3  1

// ─────────────────────────────────────────────────────────────────
// PLOT 3: ST VELOCE BEAR — Trailing stop in downtrend
// ─────────────────────────────────────────────────────────────────
#property indicator_label4  "ST Veloce Bear"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrRed
#property indicator_style4  STYLE_SOLID
#property indicator_width4  1

// ─────────────────────────────────────────────────────────────────
// PLOT 4: KELTNER UPPER — Banda superiore del canale
// Stile DOT (punteggiato) per non invadere la lettura del grafico.
// Colore blu scuro neutro C'60,100,180'.
// ─────────────────────────────────────────────────────────────────
#property indicator_label5  "Keltner Upper"
#property indicator_type5   DRAW_LINE
#property indicator_color5  C'60,100,180'
#property indicator_style5  STYLE_DOT
#property indicator_width5  1

// ─────────────────────────────────────────────────────────────────
// PLOT 5: KELTNER LOWER — Banda inferiore del canale
// ─────────────────────────────────────────────────────────────────
#property indicator_label6  "Keltner Lower"
#property indicator_type6   DRAW_LINE
#property indicator_color6  C'60,100,180'
#property indicator_style6  STYLE_DOT
#property indicator_width6  1

// ─────────────────────────────────────────────────────────────────
// PLOT 6: KELTNER MID — EMA centrale del canale
// ─────────────────────────────────────────────────────────────────
#property indicator_label7  "Keltner Mid"
#property indicator_type7   DRAW_LINE
#property indicator_color7  clrSteelBlue
#property indicator_style7  STYLE_SOLID
#property indicator_width7  1

// ─────────────────────────────────────────────────────────────────
// PLOT 7: DONCHIAN UPPER — Massimo delle ultime N barre
// ─────────────────────────────────────────────────────────────────
#property indicator_label8  "Donchian Upper"
#property indicator_type8   DRAW_LINE
#property indicator_color8  clrBlue
#property indicator_style8  STYLE_SOLID
#property indicator_width8  1

// ─────────────────────────────────────────────────────────────────
// PLOT 8: DONCHIAN LOWER — Minimo delle ultime N barre
// ─────────────────────────────────────────────────────────────────
#property indicator_label9  "Donchian Lower"
#property indicator_type9   DRAW_LINE
#property indicator_color9  clrBlue
#property indicator_style9  STYLE_SOLID
#property indicator_width9  1

// ─────────────────────────────────────────────────────────────────
// PLOT 9: DONCHIAN MIDLINE — Media (Upper+Lower)/2 con color-switch
// Tipo DRAW_COLOR_LINE: colore dinamico in base alla direzione.
// Colore 0 (lime) = Mid[i] >= Mid[i-1] = orientamento rialzista
// Colore 1 (red)  = Mid[i] <  Mid[i-1] = orientamento ribassista
// ─────────────────────────────────────────────────────────────────
#property indicator_label10 "Donchian Mid"
#property indicator_type10  DRAW_COLOR_LINE
#property indicator_color10 clrLime,clrRed
#property indicator_style10 STYLE_SOLID
#property indicator_width10 1

// ─────────────────────────────────────────────────────────────────
// PLOT 10: ENTRY BUY — Freccia triangolo su (Wingdings 233)
// Posizione: sotto la candela (Low - offset ATR)
// Colore lime vivace per segnale LONG.
// Width 5 = dimensione grande per visibilita'.
// ─────────────────────────────────────────────────────────────────
#property indicator_label11 "Entry Buy"
#property indicator_type11  DRAW_ARROW
#property indicator_color11 clrLime
#property indicator_width11 5

// ─────────────────────────────────────────────────────────────────
// PLOT 11: ENTRY SELL — Freccia triangolo giu (Wingdings 234)
// Posizione: sopra la candela (High + offset ATR)
// ─────────────────────────────────────────────────────────────────
#property indicator_label12 "Entry Sell"
#property indicator_type12  DRAW_ARROW
#property indicator_color12 clrRed
#property indicator_width12 5

// ─────────────────────────────────────────────────────────────────
// PLOT 12: EXIT LONG — Stella (Wingdings 171)
// Segnale di chiusura posizione LONG.
// Colore giallo per contrasto su sfondo scuro.
// Width 4 = leggermente piu' piccola delle frecce entry.
// ─────────────────────────────────────────────────────────────────
#property indicator_label13 "Exit Long"
#property indicator_type13  DRAW_ARROW
#property indicator_color13 clrYellow
#property indicator_width13 4

// ─────────────────────────────────────────────────────────────────
// PLOT 13: EXIT SHORT — Stella (Wingdings 171)
// Segnale di chiusura posizione SHORT.
// Colore arancione per distinguerlo da EXIT LONG.
// ─────────────────────────────────────────────────────────────────
#property indicator_label14 "Exit Short"
#property indicator_type14  DRAW_ARROW
#property indicator_color14 clrOrange
#property indicator_width14 4

// ─────────────────────────────────────────────────────────────────
// PLOT 14: FISHER BAND — Linea spessa sotto il Donchian
// Segue il profilo del Donchian Lower staccata verso il basso.
// Colore dinamico in base al Fisher Transform:
//   [0] = Verde lime (Fisher bullish: Fisher > FisherSignal)
//   [1] = Rosso vivo (Fisher bearish: Fisher < FisherSignal)
//   [2] = Giallo     (Fisher in zona picco/inversione EXIT)
// ─────────────────────────────────────────────────────────────────
#property indicator_label15 "Fisher Band"
#property indicator_type15  DRAW_COLOR_LINE
#property indicator_color15 C'0,140,70',C'200,100,30',C'180,160,50'
#property indicator_style15 STYLE_SOLID
#property indicator_width15 5

// ─────────────────────────────────────────────────────────────────
// PLOT 15: MTF ST BULL — SuperTrend KAMA del TF superiore, lato BULL (v1.20)
// Linea tratteggiata piu' scura del ST Lento M5 per distinzione visiva.
// Si aggiorna ogni N barre M5 (N = barsRatio) = "effetto gradino".
// ─────────────────────────────────────────────────────────────────
#property indicator_label16 "MTF ST Bull"
#property indicator_type16  DRAW_LINE
#property indicator_color16 C'0,80,160'
#property indicator_style16 STYLE_DASH
#property indicator_width16 2

// ─────────────────────────────────────────────────────────────────
// PLOT 16: MTF ST BEAR — SuperTrend KAMA del TF superiore, lato BEAR (v1.20)
// ─────────────────────────────────────────────────────────────────
#property indicator_label17 "MTF ST Bear"
#property indicator_type17  DRAW_LINE
#property indicator_color17 C'180,60,0'
#property indicator_style17 STYLE_DASH
#property indicator_width17 2

// ─────────────────────────────────────────────────────────────────
// PLOT 17: DRAW_COLOR_CANDLES — Candele colorate
// DEVE essere l'ULTIMO plot per essere disegnato SOPRA le linee.
// Richiede CHART_FOREGROUND=false per funzionare correttamente.
// 4 colori:
//   [0] = candela bull (verde-teal #26A69A = C'38,166,154')
//   [1] = candela bear (rosso-corallo #EF5350 = C'239,83,80')
//   [2] = candela segnale ENTRY (giallo)
//   [3] = candela segnale EXIT (grigio)
// ─────────────────────────────────────────────────────────────────
#property indicator_label18 "Candles"
#property indicator_type18  DRAW_COLOR_CANDLES
#property indicator_color18 C'38,166,154',C'239,83,80',clrYellow,clrGray
#property indicator_style18 STYLE_SOLID
#property indicator_width18 1

// ═══════════════════════════════════════════════════════════════════
// ENUMERAZIONI CUSTOM
// Definiscono le opzioni selezionabili nel pannello proprieta'.
// ═══════════════════════════════════════════════════════════════════

//--- ENUM_BST_TF_PRESET: configurazioni pre-ottimizzate per timeframe.
//    AUTO rileva il TF del chart e applica i parametri corrispondenti.
//    MANUAL permette controllo totale dei parametri.
//    ATTENZIONE: usare preset diverso dal TF del chart puo' causare
//    comportamenti inattesi (es. parametri H1 su chart M5).
enum ENUM_BST_TF_PRESET
{
   BST_TF_AUTO   = 0,  // AUTO — rileva TF dal chart
   BST_TF_M1     = 1,  // M1  — parametri ottimizzati M1
   BST_TF_M5     = 2,  // M5  — parametri ottimizzati M5
   BST_TF_M15    = 3,  // M15 — parametri ottimizzati M15
   BST_TF_M30    = 4,  // M30 — parametri ottimizzati M30
   BST_TF_H1     = 5,  // H1  — parametri ottimizzati H1
   BST_TF_MANUAL = 6   // MANUALE — controllo totale utente
};

//--- ENUM_BST_MA_SLOW: tipo di media mobile per il SuperTrend Lento.
//    KAMA e' il default perche' si adatta automaticamente:
//    - In ranging l'Efficiency Ratio -> 0 -> KAMA quasi ferma
//    - In trending l'ER -> 1 -> KAMA segue rapidamente
enum ENUM_BST_MA_SLOW
{
   BST_MA_SLOW_KAMA = 0,  // KAMA — Kaufman Adaptive (calcolata nativa)
   BST_MA_SLOW_HMA  = 1,  // HMA — Hull Moving Average (vera, con WMA finale)
   BST_MA_SLOW_EMA  = 2   // EMA  — fallback/debug
};

//--- ENUM_BST_MA_FAST: tipo di media mobile per il SuperTrend Veloce.
//    HMA e' il default perche' ha lag quasi zero (3-5 barre).
//    Cattura l'exit precocemente rispetto a EMA/DEMA.
enum ENUM_BST_MA_FAST
{
   BST_MA_FAST_HMA  = 0,  // HMA — Hull Moving Average (vera, con WMA finale)
   BST_MA_FAST_DEMA = 1,  // DEMA — Double EMA (lag -50%)
   BST_MA_FAST_EMA  = 2   // EMA  — fallback/debug
};


// ═══════════════════════════════════════════════════════════════════
// INPUT PARAMETERS
// Organizzati in 11 gruppi con separatori visivi nel pannello proprieta'.
// Ogni parametro ha commenti esplicativi che appaiono nel tooltip.
// ═══════════════════════════════════════════════════════════════════

// ╔═══════════════════════════════════════════════════════════════╗
// ║  SEZIONE 0 — PRESET TIMEFRAME                                 ║
// ╚═══════════════════════════════════════════════════════════════╝
input group "                                                               "
input group "========== PRESET TIMEFRAME =========="

input ENUM_BST_TF_PRESET InpTFPreset = BST_TF_AUTO;
// AUTO rileva automaticamente il TF del chart corrente.
// I parametri vengono sovrascritti con valori ottimizzati:
// | TF  | STSlwP | MultSlw | STFstP | MultFst | KeltMult | DC  | CI  | Fisher |
// | M1  |  10    |   3.0   |   5    |   2.0   |   2.0    | 10  | 10  |   5    |
// | M5  |  10    |   3.0   |   5    |   2.0   |   2.0    | 20  | 14  |   9    |
// | M15 |  10    |   3.0   |   5    |   2.0   |   2.0    | 25  | 16  |   9    |
// | M30 |  10    |   2.5   |   5    |   1.8   |   2.0    | 20  | 14  |   9    |
// | H1  |  10    |   2.8   |   5    |   1.8   |   2.5    | 20  | 14  |  13    |
// MANUALE: tutti i parametri delle sezioni 1-6 vengono usati come impostati.

// ╔═══════════════════════════════════════════════════════════════╗
// ║  SEZIONE 1 — SUPERTREND LENTO                                 ║
// ╚═══════════════════════════════════════════════════════════════╝
input group "                                                               "
input group "========== SUPERTREND LENTO (Direzione Dominante) =========="

input bool   InpSTSlowEnable = true;
// TRUE = SuperTrend Lento attivo. Fornisce la direzione dominante del mercato.
// FALSE = disabilitato. I segnali ENTRY ignorano il filtro di direzione.
// NON RACCOMANDATO: senza ST Lento la bussola perde la componente principale.

input ENUM_BST_MA_SLOW InpSTSlowMAType = BST_MA_SLOW_KAMA;
// KAMA RACCOMANDATO: calcolata nativamente (non usa iMA).
// L'Efficiency Ratio si avvicina a zero in ranging -> ST quasi fermo.
// In trend l'ER si avvicina a 1 -> ST segue rapidamente il prezzo.

input int    InpSTSlowPeriod = 10;
// Periodo ATR del SuperTrend Lento. Preset automatico (vedi Sezione 0).
// MANUALE RACCOMANDATO: 10 su tutti i TF (l'ATR si scala con la durata barre).

input double InpSTSlowMult = 3.0;
// Moltiplicatore ATR per la banda ST Lento. Preset automatico.
// Piu' alto = banda piu' larga = meno flip = piu' stabile.
// MANUALE: 3.0 per M1/M5/M15, 2.5 per M30/H1.

input group "    --- Colori ST Lento ---"
input color  InpSTSlowBullColor = clrDodgerBlue;
// Linea ST Lento rialzista (sotto il prezzo in uptrend).

input color  InpSTSlowBearColor = clrOrangeRed;
// Linea ST Lento ribassista (sopra il prezzo in downtrend).

input int    InpSTSlowWidth = 2;
// Spessore 2 = visibile. Piu' spesso del ST Veloce (1) per distinzione.

input group "    --- KAMA Tuning (solo se MA = KAMA) ---"
input int    InpKAMAFastPeriod = 2;
// Periodo EMA veloce della KAMA. Default Kaufman = 2.
// Quando ER → 1 (trend puro), SC → fastSC² = (2/(fast+1))².
// Con fast=2: SC=0.444 → equivale a EMA(~3.5) = reattivissima.
// Valori tipici: 2 (standard), 3 (leggermente piu' lenta).

input int    InpKAMASlowPeriod = 30;
// Periodo EMA lenta della KAMA. Default Kaufman = 30.
// Quando ER → 0 (range), SC → slowSC² = (2/(slow+1))².
// Con slow=30: SC=0.004 → equivale a EMA(~480) = quasi congelata.
// TUNING v1.04: abbassare a 15 riduce il lag transizione range→trend
// da 5-8 barre a 3-4 barre, al costo di leggero oscillamento in range.
// I filtri CI + Keltner compensano la perdita di stabilita'.
// Valori: 30=standard, 20=bilanciato, 15=reattivo, 10=aggressivo.

// ╔═══════════════════════════════════════════════════════════════╗
// ║  SEZIONE 2 — SUPERTREND VELOCE                                ║
// ╚═══════════════════════════════════════════════════════════════╝
input group "                                                               "
input group "========== SUPERTREND VELOCE (Exit Timing) =========="

input bool   InpSTFastEnable = true;
// TRUE = SuperTrend Veloce attivo. Genera il segnale primario di EXIT.
// FALSE = segnale EXIT dipende solo dal Fisher Transform.

input ENUM_BST_MA_FAST InpSTFastMAType = BST_MA_FAST_HMA;
// HMA RACCOMANDATO: Hull MA con lag quasi zero (3-5 barre vs 8-12 EMA).
// Cattura l'exit precocemente.

input int    InpSTFastPeriod = 5;
// Periodo ATR del SuperTrend Veloce. SEMPRE < InpSTSlowPeriod.

input double InpSTFastMult = 2.0;
// Moltiplicatore ATR banda ST Veloce. SEMPRE < InpSTSlowMult.
// MANUALE: 2.0 per M1/M5/M15, 1.8 per M30/H1.

input group "    --- Colori ST Veloce ---"
input color  InpSTFastBullColor = clrLime;
// Colore piu' vivace del ST Lento per distinzione immediata.

input color  InpSTFastBearColor = clrRed;

input int    InpSTFastWidth = 1;
// Spessore 1 = piu' sottile del ST Lento (2).

// ╔═══════════════════════════════════════════════════════════════╗
// ║  SEZIONE 3 — KELTNER CHANNEL                                  ║
// ╚═══════════════════════════════════════════════════════════════╝
input group "                                                               "
input group "========== KELTNER CHANNEL (Filtro Forza) =========="

// NOTA TECNICA: il Keltner Channel calcola le bande come:
// Upper = EMA(period) + ATR(14) * mult
// Lower = EMA(period) - ATR(14) * mult
// L'ATR e' GIA' INCLUSO nel Keltner. NON serve ATR separato.
// UTILIZZO:
// Prezzo DENTRO Keltner = movimento debole -> ENTRY bloccato
// Prezzo FUORI Keltner  = movimento con forza reale -> ENTRY abilitato

input bool   InpKeltnerEnable = true;
// TRUE = Keltner attivo come filtro forza. RACCOMANDATO.

input int    InpKeltnerEMAPeriod = 20;
// Periodo EMA centrale Keltner. 20 e' universale su tutti i TF.

input double InpKeltnerATRMult = 2.0;
// Moltiplicatore ATR bande Keltner. Preset automatico.
// 1.5 = bande strette (piu' segnali). 2.5 = bande larghe (solo breakout forti).

input int    InpKeltnerATRPeriod = 14;
// Periodo ATR interno Keltner. 14 = standard.

input group "    --- Colori Keltner ---"
input color  InpKeltnerBandColor = C'255,165,0';
// Colore bande superiore e inferiore. Arancione.

input color  InpKeltnerMidColor  = C'210,140,0';
// Colore EMA centrale Keltner. Arancione scuro.

input bool   InpKeltnerShowMid   = true;
// TRUE = mostra EMA centrale. FALSE = solo bande esterne.

input int    InpKeltnerWidth     = 1;

// ╔═══════════════════════════════════════════════════════════════╗
// ║  SEZIONE 4 — DONCHIAN CHANNEL                                 ║
// ╚═══════════════════════════════════════════════════════════════╝
input group "                                                               "
input group "========== DONCHIAN CHANNEL (Breakout Trigger) =========="

// IMPLEMENTAZIONE:
// Upper = massimo di High nelle ultime N barre
// Lower = minimo di Low nelle ultime N barre
// Midline = (Upper + Lower) / 2
// TRIGGER INGRESSO (Bar Close mode):
// BUY:  Close[1] > Upper[2] (breakout superiore confermato)
// SELL: Close[1] < Lower[2] (breakout inferiore confermato)

input bool   InpDonchianEnable = true;
// TRUE = Donchian attivo come trigger. RACCOMANDATO.

input int    InpDonchianPeriod = 20;
// Periodo Donchian. Preset automatico: 10 su M1, 20 su M5-H1 (standard Turtle).

input group "    --- Midline Donchian ---"
input bool   InpDonShowMid = true;
// TRUE = mostra midline con cambio colore direzionale (DRAW_COLOR_LINE).

input color  InpDonMidUpColor = clrLime;
input color  InpDonMidDnColor = clrRed;
input int    InpDonWidth = 1;
input color  InpDonchianColor = clrBlue;

input group "    --- Fill Canale Donchian ---"
input bool   InpShowDCFill      = true;
// TRUE = colora lo sfondo tra Donchian Upper e Lower in base al SuperTrend.

input color  InpFillBullColor   = clrGreen;
// Colore fill quando ST Lento = BULL.

input color  InpFillBearColor   = clrRed;
// Colore fill quando ST Lento = BEAR.

input color  InpFillNeutralColor= clrDodgerBlue;
// Colore fill quando ST Lento = neutro/chop.

input int    InpFillAlpha       = 30;
// Trasparenza fill (0=invisibile, 255=solido). 30 = semitrasparente.

// ╔═══════════════════════════════════════════════════════════════╗
// ║  SEZIONE 5 — EFFICIENCY RATIO (ER) — ex Choppiness Index       ║
// ╚═══════════════════════════════════════════════════════════════╝
input group "                                                               "
input group "========== EFFICIENCY RATIO (Qualita' Trend) =========="

// v1.20: il Choppiness Index e' stato sostituito dall'Efficiency Ratio (ER),
// gia' calcolato internamente dalla KAMA. Zero overhead aggiuntivo.
// FORMULA: ER = |prezzo[0] - prezzo[N]| / somma(|prezzo[i] - prezzo[i+1]|)
// Range: 0.0 (ranging puro) → 1.0 (trend perfetto, linea retta)
// BufCI contiene ER*100 per compatibilita' display (0=choppy, 100=trend).
// USO NELLA BUSSOLA:
// ER > 0.40 = trend forte → EXIT richiede conferma doppia (AND)
// ER > 0.30 = trend sufficiente → ENTRY abilitato
// ER 0.18-0.30 = zona neutra → ENTRY bloccato (prudenza)
// ER < 0.18 = ranging/caos → contribuisce a EXIT
// ER < 0.15 = laterale pieno → EXIT soppresse

input bool   InpCIEnable = true;
// TRUE = CI attivo come filtro qualita'.

input int    InpCIPeriod = 14;
// Periodo CI. Preset automatico: 10 su M1, 14 su M5-H1.

input double InpCIThresholdHigh = 61.8;
// LEGACY v1.20: parametro mantenuto per compatibilita' ma NON usato nella logica ER.
// La soglia exit ER e' hardcoded a 0.18 (ER < 0.18 = choppy → allerta exit).

input double InpCIThresholdLow  = 38.2;
// LEGACY v1.20: parametro mantenuto per compatibilita' ma NON usato nella logica ER.
// La soglia entry ER e' hardcoded a 0.30 (ER < 0.30 = troppo choppy → blocca entry).

// ╔═══════════════════════════════════════════════════════════════╗
// ║  SEZIONE 6 — FISHER TRANSFORM                                 ║
// ╚═══════════════════════════════════════════════════════════════╝
input group "                                                               "
input group "========== FISHER TRANSFORM (Allerta EXIT Precoce) =========="

// FORMULA EHLERS (calcolata NATIVAMENTE):
// value[i] = 0.33 * 2 * ((HL2-LowestLow)/(HighestHigh-LowestLow) - 0.5) + 0.67*value[i-1]
// value[i] = clamp(-0.999, 0.999)
// fisher[i] = 0.5 * log((1+value)/(1-value)) + 0.5 * fisher[i-1]
// PICCO RILEVATO (su bar[1]):
// Picco RIALZISTA: fisher[1] > threshold AND fisher[1] < fisher[2]
// -> momentum al massimo e che inizia a scendere -> EXIT LONG allertato

input bool   InpFisherEnable = false;
// TRUE = Fisher attivo come allerta precoce EXIT.

input int    InpFisherPeriod = 9;
// Periodo lookback per HighestHigh e LowestLow. Preset automatico.
// 5 = velocissimo su M1. 9 = standard Ehlers. 13 = stabile su H1.

input double InpFisherPeakThreshold = 1.5;
// Soglia assoluta picco estremo. Intervallo tipico Fisher: +/-3.0.
// 1.5 = zona statistica estrema (~1.5 sigma).

input bool   InpShowFisherBand = true;
// TRUE = mostra banda colorata sotto il Donchian che visualizza lo stato del Fisher.
// Verde = momentum bullish, Rosso = bearish, Giallo = picco/inversione.

input double InpFisherBandOffset = 4.0;
// Distanza della Fisher Band dal Donchian Lower (in multipli di ATR).

// ╔═══════════════════════════════════════════════════════════════╗
// ║  SEZIONE 7 — SEGNALI ENTRY / EXIT                             ║
// ╚═══════════════════════════════════════════════════════════════╝
input group "                                                               "
input group "========== SEGNALI ENTRY / EXIT =========="

// Segnali generati SOLO alla CHIUSURA della barra (zero repaint garantito).

input group "    --- Filtri ENTRY ---"
// Il segnale ENTRY viene emesso SOLO se TUTTE le condizioni attive sono soddisfatte:
// [1] ST Lento = BULL/BEAR (direzione concordante) — se InpSTSlowEnable
// [2] Donchian breakout nella stessa direzione — se InpDonchianEnable
// [3] Prezzo fuori dal Keltner Channel — se InpEntryRequireKeltner
// [4] CI < InpCIThresholdLow (trend pulito) — se InpEntryRequireCI
// [5] ST Veloce concorda con ST Lento — se InpEntryRequireFastST
// [6] Orario nella sessione operativa — se InpUseTimeFilter

input bool InpEntryRequireKeltner = true;
// TRUE = prezzo deve essere FUORI dal Keltner per emettere ENTRY.

input bool InpEntryRequireCI = false;
// TRUE = CI deve essere < InpCIThresholdLow per emettere ENTRY.
// DEFAULT false: KAMA gia' filtra ranging vs trending (ER-based), CI ridondante per entry.

input bool InpEntryRequireFastST = true;
// TRUE = ST Veloce deve concordare con ST Lento per emettere ENTRY.

input group "    --- Logica EXIT ---"
// Il segnale EXIT viene emesso quando si verificano le condizioni di uscita.
// Non e' il contrario dell'ENTRY: e' un sistema SEPARATO e INDIPENDENTE.
// CONDIZIONE PRIMARIA: ST Veloce flippa (da BULL a BEAR = EXIT LONG)
// CONDIZIONE SECONDARIA: Fisher picco (anticipa 1-4 barre)
// CONDIZIONE AGGIUNTIVA: CI sale sopra InpCIThresholdHigh

input bool InpExitRequireBoth = false;
// FALSE RACCOMANDATO: EXIT al primo segnale disponibile (OR).
// TRUE: EXIT conservativo (solo quando ST Veloce E Fisher concordano).

input bool InpExitRequireContext = true;
// TRUE RACCOMANDATO: Exit Long emesso SOLO se ST Lento era/e' BULL (c'era un long da chiudere).
// Exit Short emesso SOLO se ST Lento era/e' BEAR (c'era uno short da chiudere).
// BUG FIX v1.03: senza questo filtro, un crossover CI genera Exit Long anche in trend BEAR
// (nessun long aperto da cui uscire) → stelle fuori contesto che confondono la lettura.
// FALSE = comportamento v1.02 (exit emesso in qualsiasi direzione, puo' generare stelle spurie).

input bool InpExitFilterChoppy = true;
// TRUE RACCOMANDATO: sopprime le stelle EXIT quando il Choppiness Index indica mercato laterale.
// v1.04: in fase laterale (CI > InpExitChoppyThreshold) il SuperTrend oscilla frequentemente,
// generando flip continui del ST Veloce → cascata di stelle EXIT inutili.
// Il CI e' GIA' calcolato dall'indicatore: lo riutilizziamo come filtro regime.
// FALSE = comportamento pre-v1.04 (exit emesso anche in laterale pieno).

input double InpExitChoppyThreshold = 61.8;
// LEGACY v1.20: parametro mantenuto per compatibilita' ma NON usato nella logica ER.
// La soglia choppy ER e' hardcoded a 0.15 (ER < 0.15 = choppy → sopprime exit).
// Attivo solo con KAMA + InpExitFilterChoppy=true + InpCIEnable=true.

input bool InpExitStrongTrendAND = true;
// TRUE RACCOMANDATO: in trend forte (CI < InpExitStrongTrendCI), la logica EXIT
// passa da OR ad AND — richiede sia ST Fast flip CHE Fisher per emettere la stella.
// v1.04: in trend forte il ST Veloce flippa su ogni micro-pullback generando
// EXIT premature. Con AND, serve la conferma del Fisher (picco momentum) per uscire.
// Questo lascia il trader in posizione durante i pullback normali di un trend forte.
// FALSE = logica OR sempre (exit al primo segnale, anche in trend forte).

input double InpExitStrongTrendCI = 40.0;
// v1.20: usato come soglia ER (valore / 100). Default 40 → ER > 0.40 = trend forte.
// Quando ER > questa soglia/100, la logica EXIT diventa AND (ST Fast + Fisher).
// 40.0 = ER > 0.40 (trend forte confermato).
// 50.0 = ER > 0.50 (piu' conservativo, AND solo in trend molto forte).
// 35.0 = ER > 0.35 (piu' aggressivo, AND anche in trend moderato).
// Attivo solo con KAMA + InpExitStrongTrendAND=true + InpCIEnable=true.

input bool InpEntryAntiDuplicate = true;
// TRUE RACCOMANDATO: blocca Entry BUY/SELL se nelle ultime N barre c'era gia' lo stesso segnale.
// FIX v1.03: in trend forte con CI < 45 e prezzo fuori Keltner, OGNI barra che chiude sopra
// il Donchian Upper genera un Entry BUY → cluster di 5-10 frecce consecutive illeggibili.
// v1.04: lookback esteso a N barre (InpEntryAntiDupLookback) invece di solo 1 barra.
// Con lookback=5, massimo 1 freccia ogni 5 barre (riduce il rumore del ~80-90%).
// FALSE = comportamento v1.02 (frecce su ogni barra che soddisfa i filtri, anche consecutive).

input int InpEntryAntiDupLookback = 5;
// Numero di barre precedenti da controllare per il filtro anti-duplicato Entry.
// Valore 1 = comportamento v1.03 (solo barra adiacente).
// Valore 5 = RACCOMANDATO: in trend forte, 1 freccia ogni ~5 barre minimo.
// Valore 10 = aggressivo, utile su M1 dove il noise genera molti falsi breakout.
// Attivo solo se InpEntryAntiDuplicate = true.

input group "    --- Frecce e Stelle ---"
// CODICI FRECCIA:
// ENTRY BUY  -> code 233 (triangolo su)
// ENTRY SELL -> code 234 (triangolo giu)
// EXIT       -> code 171 (stella Wingdings)
// POSIZIONE FRECCE (v1.03):
// Base = min/max tra candela e bande canale (Keltner/Donchian) visibili
// ENTRY BUY:  min(Low, KeltnerLow, DonchianLow) - offset (sotto canale)
// ENTRY SELL: max(High, KeltnerUp, DonchianUp)   + offset (sopra canale)
// EXIT:       come ENTRY ma con offset * 0.7 (piu' vicina al canale)

input double InpArrowOffsetMult = 1.5;
// Distanza freccia dal bordo canale in multipli di g_emaATR (EMA(200) di ATR(14)).

input color  InpColorEntryBuy  = clrLime;
input color  InpColorEntrySell = clrRed;
input color  InpColorExitLong  = clrYellow;
// Stella EXIT LONG — giallo = "esci dal rialzo".
input color  InpColorExitShort = clrOrange;
// Stella EXIT SHORT — arancione = "esci dal ribasso".
input int    InpArrowSize = 5;
// Dimensione frecce DRAW_ARROW.

input group "    --- Candela Segnale ---"
input bool   InpShowSignalCandle = true;
// TRUE = colora la candela dove scatta ENTRY con colore trigger (giallo).

input color  InpColSignalCandle = clrYellow;
// Colore candela ENTRY (index 2 del DRAW_COLOR_CANDLES).

input color  InpColExitCandle = C'180,130,255';  // Viola chiaro per candele EXIT
// Colore candela EXIT (index 3 del DRAW_COLOR_CANDLES).

// ╔═══════════════════════════════════════════════════════════════╗
// ║  SEZIONE 8 — TEMA CHART                                       ║
// ╚═══════════════════════════════════════════════════════════════╝
input group "                                                               "
input group "========== TEMA CHART =========="

// MECCANISMO TEMA:
// OnInit: salva TUTTI i colori originali del chart in variabili g_orig*.
// OnInit: applica tema scuro se InpApplyChartTheme=true.
// OnDeinit: RIPRISTINA i colori originali (SEMPRE, tranne REASON_PARAMETERS).
// CHART_FOREGROUND=false: impostato SEMPRE (obbligatorio per DRAW_COLOR_CANDLES).

input bool   InpApplyChartTheme = true;
// TRUE = applica tema scuro ottimizzato. I colori originali vengono
// RIPRISTINATI automaticamente alla rimozione dell'indicatore.

input bool   InpShowGrid = false;
// FALSE = griglia nascosta (aspetto piu' pulito, raccomandato).

input bool   InpShowVolumes = false;
// TRUE = mostra volumi tick in basso al grafico (CHART_VOLUME_TICK).

input group "    --- Colori Tema ---"
input color  InpThemeBG         = C'19,23,34';
// Sfondo chart — blu notte scurissimo.

input color  InpThemeFG         = C'131,137,150';
// Testo, assi, scale. Grigio neutro.

input color  InpThemeGrid       = C'42,46,57';
// Griglia (se InpShowGrid=true). Grigio-blu molto scuro.

input color  InpThemeBullCandle = C'38,166,154';
// Candela rialzista — verde-teal (#26A69A).

input color  InpThemeBearCandle = C'239,83,80';
// Candela ribassista — rosso-corallo (#EF5350).

// ╔═══════════════════════════════════════════════════════════════╗
// ║  SEZIONE 9 — FILTRO ORARIO                                    ║
// ╚═══════════════════════════════════════════════════════════════╝
input group "                                                               "
input group "========== FILTRO ORARIO =========="

// SESSIONI RACCOMANDATE per Forex intraday:
// Londra:       08:00 - 17:00 CET
// New York:     14:00 - 22:00 CET
// Overlap L+NY: 14:00 - 17:00 CET (liquidita' peak)
// Fuori sessioni: ranging, spread allargato -> NON entrare.

input bool   InpUseTimeFilter = false;
// TRUE = blocca ENTRY fuori dalla finestra operativa.
// EXIT rimane SEMPRE attivo (protegge posizioni aperte).

input string InpSessionStart = "08:00";
// Inizio sessione operativa (tuo orario locale, formato HH:MM).

input string InpSessionEnd   = "20:00";
// Fine sessione. Dopo quest'ora: nessun nuovo ENTRY.

input int    InpBrokerOffset  = 1;
// Differenza ore tra tuo orario locale e orario broker MT5.
// Roma (GMT+1) con broker GMT+2 -> inserisci 1.

// ╔═══════════════════════════════════════════════════════════════╗
// ║  SEZIONE 10 — ANALISI MULTI-TIMEFRAME (MTF Overlay)  v1.20    ║
// ╚═══════════════════════════════════════════════════════════════╝
input group "                                                               "
input group "========== ANALISI MULTI-TIMEFRAME ==========="

// Calcola il SuperTrend KAMA Lento su un TF superiore configurabile
// e lo plotta sul grafico corrente come linea tratteggiata.
// La linea rimane ORIZZONTALE per N barre del TF corrente
// (N = TF_superiore / TF_corrente, es. M15/M5 = 3).
// Si aggiorna SOLO a barra MTF chiusa → ZERO REPAINT garantito.

input bool   InpMTF_Enable = true;
// TRUE = attiva calcolo e plot del SuperTrend KAMA sul TF superiore.
// FALSE = nessun calcolo aggiuntivo (zero impatto performance).

input ENUM_TIMEFRAMES InpMTF_TF = PERIOD_M15;
// Timeframe superiore su cui calcolare il SuperTrend MTF.
// RACCOMANDATO operativita' M5: PERIOD_M15 (ratio 3 barre)
// RACCOMANDATO operativita' M15: PERIOD_H1 (ratio 4 barre)

input int    InpMTF_BarsRatio = 0;
// Barre del TF corrente per ogni barra del TF superiore.
// 0 = AUTOMATICO: calcolato da (InpMTF_TF / Period()).
// Esempi: M5→M15=3, M5→M30=6, M5→H1=12, M15→H1=4.

input group "    --- Parametri SuperTrend MTF ---"

input bool   InpMTF_UseOwnParams = true;
// TRUE = usa i parametri dedicati MTF sotto (RACCOMANDATO).
// FALSE = usa gli stessi parametri del ST Lento M5 corrente.

input int    InpMTF_KAMAPeriod = 10;
// Periodo ER per il KAMA del SuperTrend MTF. Default 10 = standard.

input double InpMTF_STMult = 3.5;
// Moltiplicatore ATR bande ST MTF.
// RACCOMANDATO: 3.5 per M15, 4.0 per H1.

input int    InpMTF_KAMASlowPeriod = 38;
// Periodo EMA lenta KAMA per il SuperTrend MTF.
// 38 su M15 = KAMA non si muove durante pullback di 4-6 barre M5.

input group "    --- Visuale MTF ---"

input color  InpMTF_BullColor = C'0,80,160';
// Colore linea MTF in uptrend (blu scuro).

input color  InpMTF_BearColor = C'180,60,0';
// Colore linea MTF in downtrend (arancio scuro).

input int    InpMTF_Width = 2;
// Spessore linea MTF. 2 = visibile senza invadere il grafico.

input bool   InpMTF_GateEntry = false;
// TRUE = blocca fisicamente le entry quando il segnale M5 e' contro MTF.
// FALSE = le frecce appaiono comunque, solo visivo per backtest manuale.
// RACCOMANDATO per EA: TRUE. Per backtest visivo manuale: FALSE.

// ╔═══════════════════════════════════════════════════════════════╗
// ║  SEZIONE 11 — NOTIFICHE E DEBUG                               ║
// ╚═══════════════════════════════════════════════════════════════╝
input group "                                                               "
input group "========== NOTIFICHE E DEBUG =========="

input bool   InpAlertEntry  = true;
// TRUE = popup MT5 al segnale ENTRY.

input bool   InpAlertExit   = true;
// TRUE = popup MT5 al segnale EXIT.

input bool   InpDebugMode   = false;
// TRUE = stampa nel Journal MT5 ogni decisione filtro.
// Essenziale per diagnosticare "perche' il segnale non appare".

input bool   InpShowDashboard = true;
// TRUE = mostra mini dashboard top-left con stato indicatore.

input string InpInstanceID  = "";
// ID istanza per prefissi univoci OBJ_ARROW (evita conflitti con 2+ BST).
// VUOTO = prefisso "BST_". "A" = prefisso "BSTA_".

// ═══════════════════════════════════════════════════════════════════
// BUFFER DECLARATIONS
// Layout: 28 buffer in ordine sequenziale.
// REGOLA MQL5 CRITICA: INDICATOR_DATA e INDICATOR_COLOR_INDEX
// DEVONO precedere INDICATOR_CALCULATIONS.
// ═══════════════════════════════════════════════════════════════════

//--- Buffer INDICATOR_DATA (visibili come plot)
double BufSTSlowBull[];    // Buffer 0:  ST Lento lato BULL
double BufSTSlowBear[];    // Buffer 1:  ST Lento lato BEAR
double BufSTFastBull[];    // Buffer 2:  ST Veloce lato BULL
double BufSTFastBear[];    // Buffer 3:  ST Veloce lato BEAR
double BufKeltnerUp[];     // Buffer 4:  Banda superiore Keltner
double BufKeltnerLow[];    // Buffer 5:  Banda inferiore Keltner
double BufKeltnerMid[];    // Buffer 6:  EMA centrale Keltner
double BufDonchianUp[];    // Buffer 7:  Banda superiore Donchian
double BufDonchianLow[];   // Buffer 8:  Banda inferiore Donchian
double BufDonchianMid[];   // Buffer 9:  Midline Donchian (col-switch)
double BufDonMidColor[];   // Buffer 10: Indice colore midline (0=up, 1=dn)
double BufEntryBuy[];      // Buffer 11: Freccia ENTRY BUY (DRAW_ARROW)
double BufEntrySell[];     // Buffer 12: Freccia ENTRY SELL (DRAW_ARROW)
double BufExitLong[];      // Buffer 13: Stella EXIT LONG (DRAW_ARROW)
double BufExitShort[];     // Buffer 14: Stella EXIT SHORT (DRAW_ARROW)
double BufFisherBand[];     // Buffer 15: Fisher Band valore (DRAW_COLOR_LINE)
double BufFisherBandClr[]; // Buffer 16: Fisher Band indice colore (0=green, 1=red, 2=yellow)
double BufCandleO[];       // Buffer 19: OHLC Open  (DRAW_COLOR_CANDLES plot 17) — FIX-E: era indice 17
double BufCandleH[];       // Buffer 20: OHLC High  — FIX-E: era indice 18
double BufCandleL[];       // Buffer 21: OHLC Low   — FIX-E: era indice 19
double BufCandleC[];       // Buffer 22: OHLC Close — FIX-E: era indice 20
double BufCandleColor[];   // Buffer 23: Indice colore candele (0=bull, 1=bear, 2=signal) — FIX-E: era indice 21

//--- Buffer INDICATOR_CALCULATIONS (invisibili, per EA via CopyBuffer) — indici 24-31 (FIX-E: erano 22-27,30-31)
double BufCI[];            // Buffer 24: ER*100 (valore 0-100) — FIX-E: era indice 22
double BufFisher[];        // Buffer 25: Fisher Transform — FIX-E: era indice 23
double BufFisherSig[];     // Buffer 26: Fisher Signal (Fisher[i-1]) — FIX-E: era indice 24
double BufATRInt[];        // Buffer 27: ATR(14) interno — FIX-E: era indice 25
double BufSignalEntry[];   // Buffer 28: Segnale ENTRY per EA (+1=BUY, -1=SELL, 0=no) — FIX-E: era indice 26
double BufSignalExit[];    // Buffer 29: Segnale EXIT per EA (+1=ExL, -1=ExS, 0=no) — FIX-E: era indice 27

//--- Buffer MTF Overlay (v1.20)
double BufMTFBull[];       // Buffer 17: ST MTF lato BULL (INDICATOR_DATA plot 15) — FIX-E: era indice 28
double BufMTFBear[];       // Buffer 18: ST MTF lato BEAR (INDICATOR_DATA plot 16) — FIX-E: era indice 29
double BufMTFDir[];        // Buffer 30: Direzione MTF (+1.0=BULL, -1.0=BEAR, 0=n/a) (CALCULATIONS)
double BufMTFValue[];      // Buffer 31: Valore numerico banda MTF attiva (CALCULATIONS)

// ═══════════════════════════════════════════════════════════════════
// GLOBAL VARIABLES
// ═══════════════════════════════════════════════════════════════════

//--- Handle indicatori (creati in OnInit, rilasciati in OnDeinit)
int    g_atrHandle      = INVALID_HANDLE;   // iATR(14) per Keltner e g_emaATR
int    g_keltnerEMAHnd  = INVALID_HANDLE;   // iMA per EMA centrale Keltner
int    g_hmaFastHalf    = INVALID_HANDLE;   // iMA(period/2, LWMA) per HMA veloce
int    g_hmaFastFull    = INVALID_HANDLE;   // iMA(period, LWMA) per HMA veloce
int    g_hmaSlowHalf    = INVALID_HANDLE;   // iMA(period/2, LWMA) per HMA lento
int    g_hmaSlowFull    = INVALID_HANDLE;   // iMA(period, LWMA) per HMA lento
int    g_emaSlowHnd     = INVALID_HANDLE;   // iMA(stSlowPeriod, EMA) per ST Lento fallback
int    g_emaFastHnd     = INVALID_HANDLE;   // iMA(stFastPeriod, EMA) per ST Veloce fallback

//--- Parametri effettivi (applicati da ApplyTFPreset in OnInit)
//    Se InpTFPreset != MANUAL, questi vengono sovrascritti.
int    g_stSlowPeriod_eff  = 10;
double g_stSlowMult_eff    = 3.0;
int    g_stFastPeriod_eff  = 5;
double g_stFastMult_eff    = 2.0;
int    g_keltnerEMA_eff    = 20;
double g_keltnerMult_eff   = 2.0;
int    g_dcLen_eff         = 20;
int    g_ciPeriod_eff      = 14;
int    g_fisherPeriod_eff  = 9;

//--- EMA(200) dell'ATR per offset frecce
//    Calcolata manualmente ogni barra.
double g_emaATR[];

//--- KAMA state (per calcolo nativo)
double g_kamaSlowBuf[];

//--- Efficiency Ratio array (sostituisce CI come regime filter — FIX-03 v1.20)
double g_erSlow[];   // range [0,1]: 0=ranging puro, 1=trend puro

//--- Fisher state (per calcolo nativo)
double g_fisherValue[];

//--- DEMA: seconda passata EMA per ST Veloce (EMA di EMA)
double g_demaFastEma2[];

//--- HMA vera (v1.04): serie intermedia per WMA finale
//    rawHMA[i] = 2*LWMA(n/2) - LWMA(n) → poi WMA(sqrt(n)) su questa serie
double g_rawHmaSlow[];
double g_rawHmaFast[];

//--- SuperTrend state
double g_stSlowUpper[], g_stSlowLower[];
double g_stFastUpper[], g_stFastLower[];
int    g_stSlowState[];   // +1=BULL, -1=BEAR, 0=non inizializzato
int    g_stFastState[];

//--- Anti-duplicato segnali
datetime s_lastEntryBar  = 0;
datetime s_lastExitBar   = 0;
datetime s_lastDebugBar  = 0;

//--- Direzione corrente SuperTrend (aggiornati ogni barra)
int    g_stSlowDir  = 0;   // +1=BULL, -1=BEAR
int    g_stFastDir  = 0;   // +1=BULL, -1=BEAR

//--- CCanvas per fill trasparente Donchian
string   g_canvasName;
CCanvas  g_canvas;
bool     g_canvasCreated = false;

//--- Chart Theme: colori originali per ripristino in OnDeinit
color  g_origBG, g_origFG, g_origGrid;
color  g_origChartUp, g_origChartDown, g_origChartLine;
color  g_origCandleBull, g_origCandleBear;
color  g_origBid, g_origAsk, g_origVolume;
bool   g_origShowGrid    = true;
long   g_origShowVolumes = 0;
bool   g_origForeground  = true;
bool   g_chartThemeApplied = false;

//--- Dashboard toggle runtime (modificabili via bottoni dashboard)
//    Questi flag controllano la VISIBILITA' grafica dei componenti a runtime,
//    senza richiedere la ricarica dell'indicatore. Il calcolo interno dei buffer
//    resta sempre attivo (es. BufMTFDir per gate entry anche con g_vis_mtf=false).
//    Quando un flag e' false, i plot corrispondenti vengono impostati a DRAW_NONE
//    tramite PlotIndexSetInteger() in OnChartEvent.
bool   g_vis_stSlow    = true;   // ST Lento Bull/Bear (plots 0-1)
bool   g_vis_stFast    = true;   // ST Veloce Bull/Bear (plots 2-3)
bool   g_vis_keltner   = true;   // Keltner Up/Low/Mid (plots 4-6)
bool   g_vis_donchian  = true;   // Donchian Up/Low/Mid (plots 7-9) + canvas fill CCanvas (FIX-A)
bool   g_vis_ci        = true;   // ER/Choppiness nella dashboard (nessun plot grafico)
bool   g_vis_fisher    = true;   // Fisher Band (plot 14)
bool   g_vis_mtf       = true;   // FIX-C (v2.06): MTF SuperTrend Bull/Bear (plots 15-16)
string DASH_PREFIX;   // "BST_DASH_" + InpInstanceID

//--- Prefissi oggetti (inizializzati in OnInit con InpInstanceID)
string SIGNAL_PREFIX;

//--- Filtro orario (in minuti del giorno, orario broker)
int    g_sessionStartMin = 0;
int    g_sessionEndMin   = 0;

//--- MTF Overlay: stato interno calcolato su TF superiore (v1.20)
double g_mtfKAMABuf[];       // KAMA calcolato sulle barre del TF superiore
double g_mtfSTUpper[];       // Banda superiore SuperTrend MTF
double g_mtfSTLower[];       // Banda inferiore SuperTrend MTF
int    g_mtfSTState[];       // Stato direzione (+1=BULL, -1=BEAR, 0=uninit)
int    g_mtfBarsRatio_eff;   // Rapporto barre effettivo (automatico o manuale)

// ═══════════════════════════════════════════════════════════════════
// FORWARD DECLARATIONS
// ═══════════════════════════════════════════════════════════════════
void ApplyTFPreset();
void CalculateMTFOverlay(const int rates_total, const int prev_calculated,
                         const int limit, const datetime &time[]);
void CreateEntryArrow(datetime t, double price, int dir);
void CreateExitArrow(datetime t, double price, int dir);
void DeleteSignalObjects();
bool IsInSession(datetime t);
int  ParseTimeToMinutes(string timeStr);

// ═══════════════════════════════════════════════════════════════════
// OnInit — Inizializzazione indicatore
// ═══════════════════════════════════════════════════════════════════
int OnInit()
{
   //--- 1. Prefissi oggetti: permette multipli indicatori sullo stesso chart
   SIGNAL_PREFIX = "BST" + InpInstanceID + "_SIG_";
   g_canvasName  = "BST" + InpInstanceID + "_CANVAS";
   DASH_PREFIX   = "BST" + InpInstanceID + "_DASH_";

   //--- 2. SetIndexBuffer per tutti i 32 buffer
   //
   //  ╔══════════════════════════════════════════════════════════════════╗
   //  ║  FIX-E (v2.06) — RIORDINO CRITICO INDICI BUFFER → PLOT        ║
   //  ╠══════════════════════════════════════════════════════════════════╣
   //  ║                                                                ║
   //  ║  REGOLA MQL5: l'assegnazione buffer→plot e' determinata       ║
   //  ║  dall'INDICE NUMERICO del buffer (primo parametro di           ║
   //  ║  SetIndexBuffer), NON dall'ordine delle chiamate.              ║
   //  ║  Ogni plot consuma N buffer consecutivi per indice:            ║
   //  ║    DRAW_LINE = 1 DATA                                         ║
   //  ║    DRAW_COLOR_LINE = 1 DATA + 1 COLOR_INDEX                   ║
   //  ║    DRAW_ARROW = 1 DATA                                        ║
   //  ║    DRAW_COLOR_CANDLES = 4 DATA + 1 COLOR_INDEX                ║
   //  ║                                                                ║
   //  ║  BUG PRECEDENTE: i buffer MTF erano agli indici 28-29,        ║
   //  ║  ma il plot system aspettava i dati di plot 15-16 agli        ║
   //  ║  indici 17-18. I buffer candele (17-21) venivano letti        ║
   //  ║  come dati MTF, e DRAW_COLOR_CANDLES (plot 17) leggeva        ║
   //  ║  BufCandleColor (valori 0-3) come prezzo Low, creando        ║
   //  ║  candele da prezzo ~0 a prezzo reale = barre verticali        ║
   //  ║  a tutta altezza chart (il bug visivo dei 2 giorni).          ║
   //  ║                                                                ║
   //  ║  Ref: MQL5 Book "Buffer and chart mapping rules"              ║
   //  ║  https://www.mql5.com/en/book/applications/indicators_make/   ║
   //  ║  indicators_buffer_to_plot_mapping                            ║
   //  ╚══════════════════════════════════════════════════════════════════╝
   //
   //  MAPPING COMPLETO BUFFER → PLOT (dopo fix):
   //
   //  Indice  Tipo              Buffer           Plot  Tipo Plot
   //  ──────  ────────────────  ───────────────  ────  ──────────────────
   //   0      INDICATOR_DATA    BufSTSlowBull     0    DRAW_LINE
   //   1      INDICATOR_DATA    BufSTSlowBear     1    DRAW_LINE
   //   2      INDICATOR_DATA    BufSTFastBull     2    DRAW_LINE
   //   3      INDICATOR_DATA    BufSTFastBear     3    DRAW_LINE
   //   4      INDICATOR_DATA    BufKeltnerUp      4    DRAW_LINE
   //   5      INDICATOR_DATA    BufKeltnerLow     5    DRAW_LINE
   //   6      INDICATOR_DATA    BufKeltnerMid     6    DRAW_LINE
   //   7      INDICATOR_DATA    BufDonchianUp     7    DRAW_LINE
   //   8      INDICATOR_DATA    BufDonchianLow    8    DRAW_LINE
   //   9      INDICATOR_DATA    BufDonchianMid    9    DRAW_COLOR_LINE (data)
   //  10      COLOR_INDEX       BufDonMidColor    9    DRAW_COLOR_LINE (color)
   //  11      INDICATOR_DATA    BufEntryBuy      10    DRAW_ARROW
   //  12      INDICATOR_DATA    BufEntrySell     11    DRAW_ARROW
   //  13      INDICATOR_DATA    BufExitLong      12    DRAW_ARROW
   //  14      INDICATOR_DATA    BufExitShort     13    DRAW_ARROW
   //  15      INDICATOR_DATA    BufFisherBand    14    DRAW_COLOR_LINE (data)
   //  16      COLOR_INDEX       BufFisherBandClr 14    DRAW_COLOR_LINE (color)
   //  17      INDICATOR_DATA    BufMTFBull       15    DRAW_LINE  ← FIX (era 28)
   //  18      INDICATOR_DATA    BufMTFBear       16    DRAW_LINE  ← FIX (era 29)
   //  19      INDICATOR_DATA    BufCandleO       17    DRAW_COLOR_CANDLES (Open)  ← FIX (era 17)
   //  20      INDICATOR_DATA    BufCandleH       17    DRAW_COLOR_CANDLES (High)  ← FIX (era 18)
   //  21      INDICATOR_DATA    BufCandleL       17    DRAW_COLOR_CANDLES (Low)   ← FIX (era 19)
   //  22      INDICATOR_DATA    BufCandleC       17    DRAW_COLOR_CANDLES (Close) ← FIX (era 20)
   //  23      COLOR_INDEX       BufCandleColor   17    DRAW_COLOR_CANDLES (color) ← FIX (era 21)
   //  24      CALCULATIONS      BufCI            --    (ER*100, per EA)   ← FIX (era 22)
   //  25      CALCULATIONS      BufFisher        --    (Fisher Transform) ← FIX (era 23)
   //  26      CALCULATIONS      BufFisherSig     --    (Fisher Signal)    ← FIX (era 24)
   //  27      CALCULATIONS      BufATRInt        --    (ATR interno)      ← FIX (era 25)
   //  28      CALCULATIONS      BufSignalEntry   --    (segnale entry EA) ← FIX (era 26)
   //  29      CALCULATIONS      BufSignalExit    --    (segnale exit EA)  ← FIX (era 27)
   //  30      CALCULATIONS      BufMTFDir        --    (direzione MTF)
   //  31      CALCULATIONS      BufMTFValue      --    (valore banda MTF)
   //
   //  Totale: 24 buffer per plot (indici 0-23) + 8 CALCULATIONS (24-31) = 32

   // Plots 0-6: SuperTrend Lento/Veloce + Keltner (7 x DRAW_LINE = 7 buffer)
   SetIndexBuffer(0,  BufSTSlowBull,   INDICATOR_DATA);      // plot 0
   SetIndexBuffer(1,  BufSTSlowBear,   INDICATOR_DATA);      // plot 1
   SetIndexBuffer(2,  BufSTFastBull,   INDICATOR_DATA);      // plot 2
   SetIndexBuffer(3,  BufSTFastBear,   INDICATOR_DATA);      // plot 3
   SetIndexBuffer(4,  BufKeltnerUp,    INDICATOR_DATA);      // plot 4
   SetIndexBuffer(5,  BufKeltnerLow,   INDICATOR_DATA);      // plot 5
   SetIndexBuffer(6,  BufKeltnerMid,   INDICATOR_DATA);      // plot 6

   // Plots 7-9: Donchian (2 x DRAW_LINE + 1 x DRAW_COLOR_LINE = 4 buffer)
   SetIndexBuffer(7,  BufDonchianUp,   INDICATOR_DATA);      // plot 7
   SetIndexBuffer(8,  BufDonchianLow,  INDICATOR_DATA);      // plot 8
   SetIndexBuffer(9,  BufDonchianMid,  INDICATOR_DATA);      // plot 9  (data)
   SetIndexBuffer(10, BufDonMidColor,  INDICATOR_COLOR_INDEX);// plot 9  (color)

   // Plots 10-13: Frecce Entry/Exit (4 x DRAW_ARROW = 4 buffer)
   SetIndexBuffer(11, BufEntryBuy,     INDICATOR_DATA);      // plot 10
   SetIndexBuffer(12, BufEntrySell,    INDICATOR_DATA);      // plot 11
   SetIndexBuffer(13, BufExitLong,     INDICATOR_DATA);      // plot 12
   SetIndexBuffer(14, BufExitShort,    INDICATOR_DATA);      // plot 13

   // Plot 14: Fisher Band (DRAW_COLOR_LINE = 1 data + 1 color = 2 buffer)
   SetIndexBuffer(15, BufFisherBand,   INDICATOR_DATA);      // plot 14 (data)
   SetIndexBuffer(16, BufFisherBandClr,INDICATOR_COLOR_INDEX);// plot 14 (color)

   // Plots 15-16: MTF SuperTrend (2 x DRAW_LINE = 2 buffer) — FIX-E: spostati a indici 17-18
   SetIndexBuffer(17, BufMTFBull,      INDICATOR_DATA);      // plot 15
   SetIndexBuffer(18, BufMTFBear,      INDICATOR_DATA);      // plot 16

   // Plot 17: Candele colorate (DRAW_COLOR_CANDLES = 4 data + 1 color = 5 buffer) — FIX-E: spostati a indici 19-23
   SetIndexBuffer(19, BufCandleO,      INDICATOR_DATA);      // plot 17 (Open)
   SetIndexBuffer(20, BufCandleH,      INDICATOR_DATA);      // plot 17 (High)
   SetIndexBuffer(21, BufCandleL,      INDICATOR_DATA);      // plot 17 (Low)
   SetIndexBuffer(22, BufCandleC,      INDICATOR_DATA);      // plot 17 (Close)
   SetIndexBuffer(23, BufCandleColor,  INDICATOR_COLOR_INDEX);// plot 17 (color)

   // Buffer nascosti (INDICATOR_CALCULATIONS) — leggibili da EA via CopyBuffer — FIX-E: spostati a indici 24-31
   SetIndexBuffer(24, BufCI,           INDICATOR_CALCULATIONS);
   SetIndexBuffer(25, BufFisher,       INDICATOR_CALCULATIONS);
   SetIndexBuffer(26, BufFisherSig,    INDICATOR_CALCULATIONS);
   SetIndexBuffer(27, BufATRInt,       INDICATOR_CALCULATIONS);
   SetIndexBuffer(28, BufSignalEntry,  INDICATOR_CALCULATIONS);
   SetIndexBuffer(29, BufSignalExit,   INDICATOR_CALCULATIONS);
   SetIndexBuffer(30, BufMTFDir,       INDICATOR_CALCULATIONS);
   SetIndexBuffer(31, BufMTFValue,     INDICATOR_CALCULATIONS);

   //--- 3. ArraySetAsSeries per tutti i buffer
   ArraySetAsSeries(BufSTSlowBull,  true);
   ArraySetAsSeries(BufSTSlowBear,  true);
   ArraySetAsSeries(BufSTFastBull,  true);
   ArraySetAsSeries(BufSTFastBear,  true);
   ArraySetAsSeries(BufKeltnerUp,   true);
   ArraySetAsSeries(BufKeltnerLow,  true);
   ArraySetAsSeries(BufKeltnerMid,  true);
   ArraySetAsSeries(BufDonchianUp,  true);
   ArraySetAsSeries(BufDonchianLow, true);
   ArraySetAsSeries(BufDonchianMid, true);
   ArraySetAsSeries(BufDonMidColor, true);
   ArraySetAsSeries(BufEntryBuy,    true);
   ArraySetAsSeries(BufEntrySell,   true);
   ArraySetAsSeries(BufExitLong,    true);
   ArraySetAsSeries(BufExitShort,   true);
   ArraySetAsSeries(BufFisherBand,  true);
   ArraySetAsSeries(BufFisherBandClr, true);
   ArraySetAsSeries(BufCandleO,     true);
   ArraySetAsSeries(BufCandleH,     true);
   ArraySetAsSeries(BufCandleL,     true);
   ArraySetAsSeries(BufCandleC,     true);
   ArraySetAsSeries(BufCandleColor, true);
   ArraySetAsSeries(BufCI,          true);
   ArraySetAsSeries(BufFisher,      true);
   ArraySetAsSeries(BufFisherSig,   true);
   ArraySetAsSeries(BufATRInt,      true);
   ArraySetAsSeries(BufSignalEntry, true);
   ArraySetAsSeries(BufSignalExit,  true);
   ArraySetAsSeries(BufMTFBull,     true);
   ArraySetAsSeries(BufMTFBear,     true);
   ArraySetAsSeries(BufMTFDir,      true);
   ArraySetAsSeries(BufMTFValue,    true);

   //--- 4. PlotIndexSetInteger per colori/stili/frecce

   // Plot 0-3: ST Lento/Veloce — colori runtime (override dalle properties)
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, InpSTSlowBullColor);
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, InpSTSlowWidth);
   PlotIndexSetInteger(1, PLOT_LINE_COLOR, InpSTSlowBearColor);
   PlotIndexSetInteger(1, PLOT_LINE_WIDTH, InpSTSlowWidth);
   PlotIndexSetInteger(2, PLOT_LINE_COLOR, InpSTFastBullColor);
   PlotIndexSetInteger(2, PLOT_LINE_WIDTH, InpSTFastWidth);
   PlotIndexSetInteger(3, PLOT_LINE_COLOR, InpSTFastBearColor);
   PlotIndexSetInteger(3, PLOT_LINE_WIDTH, InpSTFastWidth);

   // Plot 4-6: Keltner — colore e spessore da input (v1.04: InpKeltnerWidth ora applicato)
   PlotIndexSetInteger(4, PLOT_LINE_COLOR, InpKeltnerBandColor);
   PlotIndexSetInteger(4, PLOT_LINE_WIDTH, InpKeltnerWidth);
   PlotIndexSetInteger(5, PLOT_LINE_COLOR, InpKeltnerBandColor);
   PlotIndexSetInteger(5, PLOT_LINE_WIDTH, InpKeltnerWidth);
   PlotIndexSetInteger(6, PLOT_LINE_COLOR, InpKeltnerMidColor);
   PlotIndexSetInteger(6, PLOT_LINE_WIDTH, InpKeltnerWidth);
   if(!InpKeltnerShowMid)
      PlotIndexSetInteger(6, PLOT_DRAW_TYPE, DRAW_NONE);

   // Plot 7-9: Donchian — colore e spessore da input (v1.04: InpDonWidth ora applicato)
   PlotIndexSetInteger(7, PLOT_LINE_COLOR, InpDonchianColor);
   PlotIndexSetInteger(7, PLOT_LINE_WIDTH, InpDonWidth);
   PlotIndexSetInteger(8, PLOT_LINE_COLOR, InpDonchianColor);
   PlotIndexSetInteger(8, PLOT_LINE_WIDTH, InpDonWidth);

   // Plot 9: Donchian Midline (DRAW_COLOR_LINE con 2 colori)
   PlotIndexSetInteger(9, PLOT_COLOR_INDEXES, 2);
   PlotIndexSetInteger(9, PLOT_LINE_COLOR, 0, InpDonMidUpColor);
   PlotIndexSetInteger(9, PLOT_LINE_COLOR, 1, InpDonMidDnColor);
   PlotIndexSetInteger(9, PLOT_LINE_WIDTH, InpDonWidth);
   if(!InpDonShowMid)
      PlotIndexSetInteger(9, PLOT_DRAW_TYPE, DRAW_NONE);

   // Plot 10: ENTRY BUY — freccia triangolo su (code 233)
   PlotIndexSetInteger(10, PLOT_ARROW, 233);
   PlotIndexSetInteger(10, PLOT_LINE_COLOR, InpColorEntryBuy);
   PlotIndexSetInteger(10, PLOT_LINE_WIDTH, InpArrowSize);

   // Plot 11: ENTRY SELL — freccia triangolo giu (code 234)
   PlotIndexSetInteger(11, PLOT_ARROW, 234);
   PlotIndexSetInteger(11, PLOT_LINE_COLOR, InpColorEntrySell);
   PlotIndexSetInteger(11, PLOT_LINE_WIDTH, InpArrowSize);

   // Plot 12: EXIT LONG — stella (code 171)
   PlotIndexSetInteger(12, PLOT_ARROW, 171);
   PlotIndexSetInteger(12, PLOT_LINE_COLOR, InpColorExitLong);
   PlotIndexSetInteger(12, PLOT_LINE_WIDTH, InpArrowSize - 1);

   // Plot 13: EXIT SHORT — stella (code 171)
   PlotIndexSetInteger(13, PLOT_ARROW, 171);
   PlotIndexSetInteger(13, PLOT_LINE_COLOR, InpColorExitShort);
   PlotIndexSetInteger(13, PLOT_LINE_WIDTH, InpArrowSize - 1);

   // Plot 14: Fisher Band — DRAW_COLOR_LINE, 3 colori
   PlotIndexSetInteger(14, PLOT_COLOR_INDEXES, 3);
   PlotIndexSetInteger(14, PLOT_LINE_COLOR, 0, C'0,140,70');    // Fisher bullish (verde scuro)
   PlotIndexSetInteger(14, PLOT_LINE_COLOR, 1, C'200,100,30');  // Fisher bearish (arancione)
   PlotIndexSetInteger(14, PLOT_LINE_COLOR, 2, C'180,160,50');  // Fisher picco/inversione (giallo smorzato)
   PlotIndexSetInteger(14, PLOT_LINE_WIDTH, 5);
   if(!InpShowFisherBand)
      PlotIndexSetInteger(14, PLOT_DRAW_TYPE, DRAW_NONE);

   // Plot 15-16: MTF Overlay (v1.20)
   PlotIndexSetInteger(15, PLOT_LINE_COLOR, InpMTF_BullColor);
   PlotIndexSetInteger(15, PLOT_LINE_WIDTH, InpMTF_Width);
   PlotIndexSetInteger(15, PLOT_LINE_STYLE, STYLE_DASH);
   PlotIndexSetInteger(16, PLOT_LINE_COLOR, InpMTF_BearColor);
   PlotIndexSetInteger(16, PLOT_LINE_WIDTH, InpMTF_Width);
   PlotIndexSetInteger(16, PLOT_LINE_STYLE, STYLE_DASH);

   // Nasconde i plot MTF se disabilitati
   if(!InpMTF_Enable)
   {
      PlotIndexSetInteger(15, PLOT_DRAW_TYPE, DRAW_NONE);
      PlotIndexSetInteger(16, PLOT_DRAW_TYPE, DRAW_NONE);
   }

   // Plot 17: DRAW_COLOR_CANDLES — 4 colori (era plot 15, rinumerato v1.20)
   PlotIndexSetInteger(17, PLOT_COLOR_INDEXES, 4);
   PlotIndexSetInteger(17, PLOT_LINE_COLOR, 0, InpThemeBullCandle);
   PlotIndexSetInteger(17, PLOT_LINE_COLOR, 1, InpThemeBearCandle);
   PlotIndexSetInteger(17, PLOT_LINE_COLOR, 2, InpColSignalCandle);
   PlotIndexSetInteger(17, PLOT_LINE_COLOR, 3, InpColExitCandle);

   // PLOT_EMPTY_VALUE per tutti i plot che possono avere buchi
   for(int p = 0; p < 18; p++)
      PlotIndexSetDouble(p, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   //--- 5. ApplyTFPreset — imposta g_*_eff in base a InpTFPreset + Period()
   ApplyTFPreset();

   //--- 5b. Calcolo rapporto barre MTF (v1.20)
   if(InpMTF_Enable)
   {
      if(InpMTF_BarsRatio > 0)
      {
         g_mtfBarsRatio_eff = InpMTF_BarsRatio;
      }
      else
      {
         int currentTFmin = (int)Period();
         int upperTFmin   = (int)InpMTF_TF;
         if(upperTFmin <= 0 || currentTFmin <= 0)
            g_mtfBarsRatio_eff = 3;
         else
         {
            g_mtfBarsRatio_eff = upperTFmin / currentTFmin;
            if(g_mtfBarsRatio_eff < 1) g_mtfBarsRatio_eff = 1;
         }
      }

      Print("[BST] MTF Overlay: TF=", EnumToString(InpMTF_TF),
            " BarsRatio=", g_mtfBarsRatio_eff,
            " KAMAPeriod=", InpMTF_UseOwnParams ? InpMTF_KAMAPeriod : g_stSlowPeriod_eff,
            " Mult=", InpMTF_UseOwnParams ? InpMTF_STMult : g_stSlowMult_eff,
            " SlowPeriod=", InpMTF_UseOwnParams ? InpMTF_KAMASlowPeriod : InpKAMASlowPeriod);

      if((int)InpMTF_TF <= (int)Period())
         Print("[BST] ATTENZIONE: InpMTF_TF <= TF corrente. MTF non aggiunge filtro direzionale.");
   }

   //--- 6. Crea handle iMA/iATR (usa g_*_eff, NON i valori input diretti)
   g_atrHandle = iATR(_Symbol, PERIOD_CURRENT, InpKeltnerATRPeriod);
   if(g_atrHandle == INVALID_HANDLE)
   {
      Print("[BST] ERRORE: impossibile creare handle iATR");
      return(INIT_FAILED);
   }

   g_keltnerEMAHnd = iMA(_Symbol, PERIOD_CURRENT, g_keltnerEMA_eff, 0, MODE_EMA, PRICE_CLOSE);
   if(g_keltnerEMAHnd == INVALID_HANDLE)
   {
      Print("[BST] ERRORE: impossibile creare handle iMA per Keltner EMA");
      return(INIT_FAILED);
   }

   // HMA handle per ST Veloce (se tipo = HMA)
   if(InpSTFastMAType == BST_MA_FAST_HMA)
   {
      int halfPeriod = (int)MathMax(1, g_stFastPeriod_eff / 2);
      g_hmaFastHalf = iMA(_Symbol, PERIOD_CURRENT, halfPeriod, 0, MODE_LWMA, PRICE_CLOSE);
      g_hmaFastFull = iMA(_Symbol, PERIOD_CURRENT, g_stFastPeriod_eff, 0, MODE_LWMA, PRICE_CLOSE);
   }

   // HMA handle per ST Lento (se tipo = HMA)
   if(InpSTSlowMAType == BST_MA_SLOW_HMA)
   {
      int halfPeriod = (int)MathMax(1, g_stSlowPeriod_eff / 2);
      g_hmaSlowHalf = iMA(_Symbol, PERIOD_CURRENT, halfPeriod, 0, MODE_LWMA, PRICE_CLOSE);
      g_hmaSlowFull = iMA(_Symbol, PERIOD_CURRENT, g_stSlowPeriod_eff, 0, MODE_LWMA, PRICE_CLOSE);
   }

   // EMA handle per ST Lento (se tipo = EMA)
   if(InpSTSlowMAType == BST_MA_SLOW_EMA)
   {
      g_emaSlowHnd = iMA(_Symbol, PERIOD_CURRENT, g_stSlowPeriod_eff, 0, MODE_EMA, PRICE_CLOSE);
   }

   // EMA handle per ST Veloce (se tipo = DEMA o EMA)
   if(InpSTFastMAType == BST_MA_FAST_DEMA || InpSTFastMAType == BST_MA_FAST_EMA)
   {
      g_emaFastHnd = iMA(_Symbol, PERIOD_CURRENT, g_stFastPeriod_eff, 0, MODE_EMA, PRICE_CLOSE);
   }

   //--- 7. Parsing filtro orario
   g_sessionStartMin = ParseTimeToMinutes(InpSessionStart) + InpBrokerOffset * 60;
   g_sessionEndMin   = ParseTimeToMinutes(InpSessionEnd) + InpBrokerOffset * 60;

   //--- 8. Chart Theme
   // 8a. Salva colori originali
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
   g_origShowVolumes= ChartGetInteger(0, CHART_SHOW_VOLUMES);
   g_origForeground = (bool)ChartGetInteger(0, CHART_FOREGROUND);

   // 8b. Applica tema se abilitato
   if(InpApplyChartTheme)
   {
      ChartSetInteger(0, CHART_COLOR_BACKGROUND,  InpThemeBG);
      ChartSetInteger(0, CHART_COLOR_FOREGROUND,  InpThemeFG);
      ChartSetInteger(0, CHART_COLOR_GRID,        InpThemeGrid);
      ChartSetInteger(0, CHART_COLOR_CANDLE_BULL, InpThemeBullCandle);
      ChartSetInteger(0, CHART_COLOR_CANDLE_BEAR, InpThemeBearCandle);
      ChartSetInteger(0, CHART_COLOR_CHART_UP,    InpThemeBullCandle);
      ChartSetInteger(0, CHART_COLOR_CHART_DOWN,  InpThemeBearCandle);
      ChartSetInteger(0, CHART_COLOR_CHART_LINE,  InpThemeFG);
      ChartSetInteger(0, CHART_COLOR_BID,         InpThemeBullCandle);
      ChartSetInteger(0, CHART_COLOR_ASK,         InpThemeBearCandle);
      ChartSetInteger(0, CHART_COLOR_VOLUME,      InpThemeFG);
      ChartSetInteger(0, CHART_SHOW_GRID,         InpShowGrid);

      // Volumi: CHART_VOLUME_TICK se abilitati, HIDE altrimenti
      if(InpShowVolumes)
         ChartSetInteger(0, CHART_SHOW_VOLUMES, CHART_VOLUME_TICK);
      else
         ChartSetInteger(0, CHART_SHOW_VOLUMES, CHART_VOLUME_HIDE);

      g_chartThemeApplied = true;
   }

   //--- 9. CHART_FOREGROUND=false SEMPRE (obbligatorio per DRAW_COLOR_CANDLES)
   ChartSetInteger(0, CHART_FOREGROUND, false);

   //--- 10. Se !InpApplyChartTheme: usa colori candele native per Plot 14
   if(!InpApplyChartTheme)
   {
      PlotIndexSetInteger(14, PLOT_LINE_COLOR, 0, g_origCandleBull);
      PlotIndexSetInteger(14, PLOT_LINE_COLOR, 1, g_origCandleBear);
   }

   //--- 11. Modalita' candele
   ChartSetInteger(0, CHART_MODE, CHART_CANDLES);

   //--- 12. ChartRedraw
   ChartRedraw();

   //--- 13. Short name
   string tfStr = "";
   switch(Period())
   {
      case PERIOD_M1:  tfStr = "M1";  break;
      case PERIOD_M5:  tfStr = "M5";  break;
      case PERIOD_M15: tfStr = "M15"; break;
      case PERIOD_M30: tfStr = "M30"; break;
      case PERIOD_H1:  tfStr = "H1";  break;
      case PERIOD_H4:  tfStr = "H4";  break;
      case PERIOD_D1:  tfStr = "D1";  break;
      default:         tfStr = "??";  break;
   }

   string maSlowStr = (InpSTSlowMAType == BST_MA_SLOW_KAMA) ? "KAMA" :
                      (InpSTSlowMAType == BST_MA_SLOW_HMA)  ? "HMA"  : "EMA";
   string maFastStr = (InpSTFastMAType == BST_MA_FAST_HMA)  ? "HMA"  :
                      (InpSTFastMAType == BST_MA_FAST_DEMA) ? "DEMA" : "EMA";

   IndicatorSetString(INDICATOR_SHORTNAME,
      "BST(" + tfStr + "," + maSlowStr + "/" + maFastStr +
      (InpMTF_Enable ? ",MTF:" + EnumToString(InpMTF_TF) : "") + ")");

   Print("[BST v1.20] Inizializzato: ", tfStr, " preset=", EnumToString(InpTFPreset),
         " STslow=", g_stSlowPeriod_eff, "/", g_stSlowMult_eff,
         " STfast=", g_stFastPeriod_eff, "/", g_stFastMult_eff,
         " DC=", g_dcLen_eff, " ER_period=", g_ciPeriod_eff, " Fisher=", g_fisherPeriod_eff,
         " MTF=", InpMTF_Enable ? "ON" : "OFF");

   return(INIT_SUCCEEDED);
}

// ═══════════════════════════════════════════════════════════════════
// OnDeinit — Pulizia e ripristino
// ═══════════════════════════════════════════════════════════════════
void OnDeinit(const int reason)
{
   //--- 1. Log
   Print("[BST] OnDeinit reason=", reason, " objects=", ObjectsTotal(0),
         " themeApplied=", g_chartThemeApplied);

   //--- 2. Elimina tutti gli OBJ_ARROW e dashboard creati dall'indicatore
   DeleteSignalObjects();
   ObjectsDeleteAll(0, DASH_PREFIX);

   //--- FIX v1.05: resetta il flag g_dashCreated dopo ObjectsDeleteAll.
   //    PROBLEMA: g_dashCreated e' una variabile globale che PERSISTE tra
   //    cicli OnDeinit/OnInit (MQL5 re-inizializza i globali SOLO al primo
   //    caricamento del programma, non al cambio TF).
   //    Senza questo reset, dopo cambio TF:
   //    1. OnDeinit cancella tutti gli oggetti DASH_PREFIX
   //    2. g_dashCreated rimane TRUE
   //    3. OnCalculate chiama UpdateBSTDashboard()
   //    4. InitBSTDashboard() viene SALTATA (g_dashCreated == true)
   //    5. BSTSetRow/BSTSetBtn operano su oggetti INESISTENTI → dashboard invisibile
   g_dashCreated = false;
   g_dashLastRowUsed = 0;

   //--- 2b. Distruggi CCanvas
   if(g_canvasCreated)
   {
      g_canvas.Destroy();
      g_canvasCreated = false;
   }

   //--- 3. Rilascia handle
   if(g_atrHandle != INVALID_HANDLE)
   {
      IndicatorRelease(g_atrHandle);
      g_atrHandle = INVALID_HANDLE;
   }
   if(g_keltnerEMAHnd != INVALID_HANDLE)
   {
      IndicatorRelease(g_keltnerEMAHnd);
      g_keltnerEMAHnd = INVALID_HANDLE;
   }
   if(g_hmaFastHalf != INVALID_HANDLE)
   {
      IndicatorRelease(g_hmaFastHalf);
      g_hmaFastHalf = INVALID_HANDLE;
   }
   if(g_hmaFastFull != INVALID_HANDLE)
   {
      IndicatorRelease(g_hmaFastFull);
      g_hmaFastFull = INVALID_HANDLE;
   }
   if(g_hmaSlowHalf != INVALID_HANDLE)
   {
      IndicatorRelease(g_hmaSlowHalf);
      g_hmaSlowHalf = INVALID_HANDLE;
   }
   if(g_hmaSlowFull != INVALID_HANDLE)
   {
      IndicatorRelease(g_hmaSlowFull);
      g_hmaSlowFull = INVALID_HANDLE;
   }
   if(g_emaSlowHnd != INVALID_HANDLE)
   {
      IndicatorRelease(g_emaSlowHnd);
      g_emaSlowHnd = INVALID_HANDLE;
   }
   if(g_emaFastHnd != INVALID_HANDLE)
   {
      IndicatorRelease(g_emaFastHnd);
      g_emaFastHnd = INVALID_HANDLE;
   }

   //--- 4. Determina se saltare il ripristino
   //       (se cambio parametri, OnInit viene chiamato subito dopo)
   bool skipRestore = (reason == REASON_PARAMETERS);

   //--- 5. Ripristina tema chart
   if(g_chartThemeApplied && !skipRestore)
   {
      ChartSetInteger(0, CHART_COLOR_BACKGROUND,  g_origBG);
      ChartSetInteger(0, CHART_COLOR_FOREGROUND,  g_origFG);
      ChartSetInteger(0, CHART_COLOR_GRID,        g_origGrid);
      ChartSetInteger(0, CHART_COLOR_CANDLE_BULL, g_origCandleBull);
      ChartSetInteger(0, CHART_COLOR_CANDLE_BEAR, g_origCandleBear);
      ChartSetInteger(0, CHART_COLOR_CHART_UP,    g_origChartUp);
      ChartSetInteger(0, CHART_COLOR_CHART_DOWN,  g_origChartDown);
      ChartSetInteger(0, CHART_COLOR_CHART_LINE,  g_origChartLine);
      ChartSetInteger(0, CHART_COLOR_BID,         g_origBid);
      ChartSetInteger(0, CHART_COLOR_ASK,         g_origAsk);
      ChartSetInteger(0, CHART_COLOR_VOLUME,      g_origVolume);
      ChartSetInteger(0, CHART_SHOW_GRID,         g_origShowGrid);
      ChartSetInteger(0, CHART_SHOW_VOLUMES,      g_origShowVolumes);
      g_chartThemeApplied = false;
   }

   //--- 6. Ripristina CHART_FOREGROUND
   if(!skipRestore)
      ChartSetInteger(0, CHART_FOREGROUND, g_origForeground);

   //--- 7. ChartRedraw
   ChartRedraw();
}

// ═══════════════════════════════════════════════════════════════════
// ApplyTFPreset — Applica parametri ottimizzati per timeframe
// ═══════════════════════════════════════════════════════════════════
void ApplyTFPreset()
{
   ENUM_TIMEFRAMES presetTF = PERIOD_CURRENT;

   //--- Determina il TF da usare per il preset
   switch(InpTFPreset)
   {
      case BST_TF_AUTO:
         // Rileva dal chart corrente
         switch(Period())
         {
            case PERIOD_M1:  presetTF = PERIOD_M1;  break;
            case PERIOD_M5:  presetTF = PERIOD_M5;  break;
            case PERIOD_M15: presetTF = PERIOD_M15; break;
            case PERIOD_M30: presetTF = PERIOD_M30; break;
            case PERIOD_H1:  presetTF = PERIOD_H1;  break;
            default:         presetTF = PERIOD_H1;  break; // fallback
         }
         break;
      case BST_TF_M1:     presetTF = PERIOD_M1;  break;
      case BST_TF_M5:     presetTF = PERIOD_M5;  break;
      case BST_TF_M15:    presetTF = PERIOD_M15; break;
      case BST_TF_M30:    presetTF = PERIOD_M30; break;
      case BST_TF_H1:     presetTF = PERIOD_H1;  break;
      case BST_TF_MANUAL:
         // Usa i parametri input direttamente
         g_stSlowPeriod_eff  = InpSTSlowPeriod;
         g_stSlowMult_eff    = InpSTSlowMult;
         g_stFastPeriod_eff  = InpSTFastPeriod;
         g_stFastMult_eff    = InpSTFastMult;
         g_keltnerEMA_eff    = InpKeltnerEMAPeriod;
         g_keltnerMult_eff   = InpKeltnerATRMult;
         g_dcLen_eff         = InpDonchianPeriod;
         g_ciPeriod_eff      = InpCIPeriod;
         g_fisherPeriod_eff  = InpFisherPeriod;
         return;
   }

   //--- Applica valori preset in base al TF
   switch(presetTF)
   {
      case PERIOD_M1:
         g_stSlowPeriod_eff = 10;  g_stSlowMult_eff = 3.0;
         g_stFastPeriod_eff = 5;   g_stFastMult_eff = 2.0;
         g_keltnerEMA_eff   = 20;  g_keltnerMult_eff = 2.0;  // v1.03: era 1.5, troppo stretto su M1 (noise alto → troppi falsi breakout)
         g_dcLen_eff        = 10;
         g_ciPeriod_eff     = 10;
         g_fisherPeriod_eff = 5;
         break;

      case PERIOD_M5:
         g_stSlowPeriod_eff = 10;  g_stSlowMult_eff = 3.0;
         g_stFastPeriod_eff = 7;   g_stFastMult_eff = 2.0;   // v1.20: period 5→7: meno rumore
         g_keltnerEMA_eff   = 15;  g_keltnerMult_eff = 2.0;  // v1.20: EMA 20→15: piu' reattivo su M5
         g_dcLen_eff        = 20;                             // standard Turtle 20 periodi
         g_ciPeriod_eff     = 12;                             // v1.20: piu' reattivo su M5 (usato per ER period)
         g_fisherPeriod_eff = 9;
         break;

      case PERIOD_M15:
         g_stSlowPeriod_eff = 10;  g_stSlowMult_eff = 3.5;   // v1.20: 3.0→3.5: riduce whipsaw BTC
         g_stFastPeriod_eff = 7;   g_stFastMult_eff = 2.5;   // v1.20: mult 2.0→2.5: evita exit prematuri
         g_keltnerEMA_eff   = 20;  g_keltnerMult_eff = 2.5;  // v1.20: 2.0→2.5: banda adeguata crypto M15
         g_dcLen_eff        = 20;                             // standard Turtle 20 periodi
         g_ciPeriod_eff     = 14;                             // v1.20: invariato (periodo ER)
         g_fisherPeriod_eff = 13;                             // v1.20: 9→13: meno rumore su M15
         break;

      case PERIOD_M30:
         g_stSlowPeriod_eff = 10;  g_stSlowMult_eff = 2.5;
         g_stFastPeriod_eff = 5;   g_stFastMult_eff = 1.8;
         g_keltnerEMA_eff   = 20;  g_keltnerMult_eff = 2.0;
         g_dcLen_eff        = 20;
         g_ciPeriod_eff     = 14;
         g_fisherPeriod_eff = 9;
         break;

      case PERIOD_H1:
      default:
         g_stSlowPeriod_eff = 10;  g_stSlowMult_eff = 2.8;   // v1.04: era 2.5, leggermente aggressivo.
                                                               // 2.8 riduce i falsi flip mantenendo reattivita'.
                                                               // Fonti web consigliano mult 3.0 su H1 — 2.8 è un compromesso.
         g_stFastPeriod_eff = 5;   g_stFastMult_eff = 1.8;
         g_keltnerEMA_eff   = 20;  g_keltnerMult_eff = 2.5;
         g_dcLen_eff        = 20;
         g_ciPeriod_eff     = 14;
         g_fisherPeriod_eff = 13;
         break;
   }
}

// ═══════════════════════════════════════════════════════════════════
// CalculateMTFOverlay — SuperTrend KAMA Lento su TF superiore (v1.20)
// Proietta i valori su ogni barra del TF corrente (effetto gradino).
// ANTI-REPAINT: usa solo barre chiuse del TF superiore (shift >= 1).
// ═══════════════════════════════════════════════════════════════════
void CalculateMTFOverlay(const int rates_total,
                         const int prev_calculated,
                         const int limit,
                         const datetime &time[])
{
   if(!InpMTF_Enable) return;

   //--- Parametri effettivi (propri o dal TF corrente)
   int    kamaPeriod = InpMTF_UseOwnParams ? InpMTF_KAMAPeriod     : g_stSlowPeriod_eff;
   double stMult     = InpMTF_UseOwnParams ? InpMTF_STMult         : g_stSlowMult_eff;
   int    slowEMAP   = InpMTF_UseOwnParams ? InpMTF_KAMASlowPeriod : InpKAMASlowPeriod;

   double fastSC_mtf = 2.0 / (2.0 + 1.0);
   double slowSC_mtf = 2.0 / ((double)slowEMAP + 1.0);

   //--- Numero barre MTF da richiedere
   int mtfBarsNeeded = (rates_total / MathMax(1, g_mtfBarsRatio_eff)) + kamaPeriod + 20;
   if(mtfBarsNeeded < 100) mtfBarsNeeded = 100;

   //--- Copia dati OHLC del TF superiore
   double mtfHigh[], mtfLow[], mtfClose[], mtfATR[];
   datetime mtfTime[];
   ArraySetAsSeries(mtfHigh,  true);
   ArraySetAsSeries(mtfLow,   true);
   ArraySetAsSeries(mtfClose, true);
   ArraySetAsSeries(mtfTime,  true);

   int copied = CopyHigh(_Symbol, InpMTF_TF, 0, mtfBarsNeeded, mtfHigh);
   if(copied <= 5) return;
   if(CopyLow  (_Symbol, InpMTF_TF, 0, mtfBarsNeeded, mtfLow)   <= 0) return;
   if(CopyClose(_Symbol, InpMTF_TF, 0, mtfBarsNeeded, mtfClose) <= 0) return;
   if(CopyTime (_Symbol, InpMTF_TF, 0, mtfBarsNeeded, mtfTime)  <= 0) return;

   //--- Calcola ATR(14) manuale sul TF superiore (Wilder smoothing)
   ArraySetAsSeries(mtfATR, true);
   ArrayResize(mtfATR, copied);
   int atrPeriod = 14;
   for(int k = copied - 2; k >= 0; k--)
   {
      double tr = mtfHigh[k] - mtfLow[k];
      if(k + 1 < copied)
      {
         double hc = MathAbs(mtfHigh[k]  - mtfClose[k + 1]);
         double lc = MathAbs(mtfLow[k]   - mtfClose[k + 1]);
         if(hc > tr) tr = hc;
         if(lc > tr) tr = lc;
      }
      if(k >= copied - 2)
         mtfATR[k] = tr;
      else
         mtfATR[k] = (mtfATR[k + 1] * (atrPeriod - 1) + tr) / (double)atrPeriod;
   }

   //--- Ridimensiona array MTF interni se necessario
   if(ArraySize(g_mtfKAMABuf) < copied + 5)
   {
      ArrayResize(g_mtfKAMABuf, copied + 10);
      ArrayResize(g_mtfSTUpper, copied + 10);
      ArrayResize(g_mtfSTLower, copied + 10);
      ArrayResize(g_mtfSTState, copied + 10);
      ArrayInitialize(g_mtfSTState, 0);
   }

   //--- Calcola KAMA + SuperTrend sul TF superiore
   for(int k = copied - 2; k >= 1; k--)  // MAI k=0 (barra MTF in formazione)
   {
      double hl2_k = (mtfHigh[k] + mtfLow[k]) / 2.0;

      //--- KAMA
      if(k >= copied - kamaPeriod - 2)
      {
         g_mtfKAMABuf[k] = hl2_k;  // warmup
      }
      else
      {
         double dir_k = MathAbs(hl2_k - (mtfHigh[k + kamaPeriod] + mtfLow[k + kamaPeriod]) / 2.0);
         double vol_k = 0;
         for(int jj = 0; jj < kamaPeriod; jj++)
         {
            double a = (mtfHigh[k+jj]   + mtfLow[k+jj])   / 2.0;
            double b = (mtfHigh[k+jj+1] + mtfLow[k+jj+1]) / 2.0;
            vol_k += MathAbs(a - b);
         }
         double ER_k = (vol_k > 0) ? dir_k / vol_k : 0;
         double SC_k = MathPow(ER_k * (fastSC_mtf - slowSC_mtf) + slowSC_mtf, 2);
         g_mtfKAMABuf[k] = g_mtfKAMABuf[k+1] + SC_k * (hl2_k - g_mtfKAMABuf[k+1]);
      }

      //--- Bande SuperTrend MTF
      double atr_k   = mtfATR[k];
      double upper_k = g_mtfKAMABuf[k] + stMult * atr_k;
      double lower_k = g_mtfKAMABuf[k] - stMult * atr_k;

      //--- Cricchetto CORRETTO (upper scende, lower sale)
      if(k < copied - 2)
      {
         g_mtfSTUpper[k] = (upper_k < g_mtfSTUpper[k+1] || mtfClose[k+1] > g_mtfSTUpper[k+1])
                           ? upper_k : g_mtfSTUpper[k+1];
         g_mtfSTLower[k] = (lower_k > g_mtfSTLower[k+1] || mtfClose[k+1] < g_mtfSTLower[k+1])
                           ? lower_k : g_mtfSTLower[k+1];
      }
      else
      {
         g_mtfSTUpper[k] = upper_k;
         g_mtfSTLower[k] = lower_k;
      }

      //--- Direzione MTF
      if(k < copied - 2 && g_mtfSTState[k+1] != 0)
      {
         if(g_mtfSTState[k+1] == -1)
            g_mtfSTState[k] = (mtfClose[k] > g_mtfSTUpper[k]) ? 1 : -1;
         else
            g_mtfSTState[k] = (mtfClose[k] < g_mtfSTLower[k]) ? -1 : 1;
      }
      else
      {
         g_mtfSTState[k] = (mtfClose[k] > g_mtfKAMABuf[k]) ? 1 : -1;
      }
   }

   //--- Proietta valori MTF su ogni barra del TF corrente
   for(int i = limit; i >= 1; i--)  // MAI i=0
   {
      datetime t_curr = time[i];

      //--- Trova barra MTF chiusa corrispondente
      int k_mtf = iBarShift(_Symbol, InpMTF_TF, t_curr, false);

      //--- Gestione errori iBarShift
      if(k_mtf < 0)
      {
         BufMTFBull[i] = EMPTY_VALUE; BufMTFBear[i] = EMPTY_VALUE;
         BufMTFDir[i] = 0; BufMTFValue[i] = 0;
         continue;
      }

      //--- Se la barra MTF trovata e' ancora aperta, usare la precedente (chiusa)
      if(k_mtf < copied && mtfTime[k_mtf] > t_curr)
         k_mtf++;

      //--- Bounds check
      if(k_mtf < 1 || k_mtf >= copied - 1)
      {
         BufMTFBull[i] = EMPTY_VALUE; BufMTFBear[i] = EMPTY_VALUE;
         BufMTFDir[i] = 0; BufMTFValue[i] = 0;
         continue;
      }

      //--- Scrivi sul grafico corrente
      int dir = g_mtfSTState[k_mtf];

      if(dir == 1)  // MTF BULL
      {
         BufMTFBull[i]  = g_mtfSTLower[k_mtf];
         BufMTFBear[i]  = EMPTY_VALUE;
         BufMTFDir[i]   = 1.0;
         BufMTFValue[i] = g_mtfSTLower[k_mtf];
      }
      else if(dir == -1)  // MTF BEAR
      {
         BufMTFBear[i]  = g_mtfSTUpper[k_mtf];
         BufMTFBull[i]  = EMPTY_VALUE;
         BufMTFDir[i]   = -1.0;
         BufMTFValue[i] = g_mtfSTUpper[k_mtf];
      }
      else
      {
         BufMTFBull[i]  = EMPTY_VALUE;
         BufMTFBear[i]  = EMPTY_VALUE;
         BufMTFDir[i]   = 0;
         BufMTFValue[i] = 0;
      }
   }
}

// ═══════════════════════════════════════════════════════════════════
// OnCalculate — Calcolo principale
// ═══════════════════════════════════════════════════════════════════
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
   //--- Verifica dati minimi
   if(rates_total < 50)
      return(0);

   //--- Imposta array come serie (indice 0 = barra piu' recente)
   ArraySetAsSeries(time,  true);
   ArraySetAsSeries(open,  true);
   ArraySetAsSeries(high,  true);
   ArraySetAsSeries(low,   true);
   ArraySetAsSeries(close, true);

   //--- Calcola quante barre elaborare
   int limit;
   if(prev_calculated == 0)
   {
      limit = rates_total - 50;  // Prima esecuzione: elabora tutto tranne warmup

      // Ridimensiona array interni
      ArrayResize(g_emaATR,       rates_total);
      ArrayResize(g_kamaSlowBuf,  rates_total);
      ArrayResize(g_erSlow,       rates_total);
      ArrayResize(g_fisherValue,  rates_total);
      ArrayResize(g_stSlowUpper,  rates_total);
      ArrayResize(g_stSlowLower,  rates_total);
      ArrayResize(g_stFastUpper,  rates_total);
      ArrayResize(g_stFastLower,  rates_total);
      ArrayResize(g_stSlowState,  rates_total);
      ArrayResize(g_stFastState,  rates_total);
      ArrayResize(g_demaFastEma2, rates_total);
      ArrayResize(g_rawHmaSlow,  rates_total);
      ArrayResize(g_rawHmaFast,  rates_total);

      ArraySetAsSeries(g_emaATR,        true);
      ArraySetAsSeries(g_kamaSlowBuf,   true);
      ArraySetAsSeries(g_erSlow,        true);
      ArraySetAsSeries(g_fisherValue,   true);
      ArraySetAsSeries(g_stSlowUpper,   true);
      ArraySetAsSeries(g_stSlowLower,   true);
      ArraySetAsSeries(g_stFastUpper,   true);
      ArraySetAsSeries(g_stFastLower,   true);
      ArraySetAsSeries(g_stSlowState,   true);
      ArraySetAsSeries(g_stFastState,   true);
      ArraySetAsSeries(g_demaFastEma2,  true);
      ArraySetAsSeries(g_rawHmaSlow,    true);
      ArraySetAsSeries(g_rawHmaFast,    true);

      // Inizializza a zero
      ArrayInitialize(g_stSlowState, 0);
      ArrayInitialize(g_stFastState, 0);
      ArrayInitialize(g_fisherValue, 0);
      ArrayInitialize(g_demaFastEma2, 0);
      ArrayInitialize(g_rawHmaSlow, 0);
      ArrayInitialize(g_rawHmaFast, 0);

      // Inizializza Upper/Lower per cricchetto corretto:
      // Upper inizia a DBL_MAX cosi' upperBand < DBL_MAX e' sempre TRUE alla prima barra
      // Lower inizia a 0 cosi' lowerBand > 0 e' sempre TRUE alla prima barra
      ArrayInitialize(g_stSlowUpper, DBL_MAX);
      ArrayInitialize(g_stFastUpper, DBL_MAX);
      ArrayInitialize(g_stSlowLower, 0);
      ArrayInitialize(g_stFastLower, 0);
      ArrayInitialize(g_kamaSlowBuf, 0);
      ArrayInitialize(g_erSlow, 0.5);  // neutro: ER=0.5 se KAMA non ancora calcolato
      ArrayInitialize(g_emaATR, 0);

      // MTF Overlay arrays (v1.20)
      if(InpMTF_Enable)
      {
         ArrayResize(g_mtfKAMABuf, rates_total);
         ArrayResize(g_mtfSTUpper, rates_total);
         ArrayResize(g_mtfSTLower, rates_total);
         ArrayResize(g_mtfSTState, rates_total);

         ArraySetAsSeries(g_mtfKAMABuf, true);
         ArraySetAsSeries(g_mtfSTUpper, true);
         ArraySetAsSeries(g_mtfSTLower, true);
         ArraySetAsSeries(g_mtfSTState, true);

         ArrayInitialize(g_mtfSTState, 0);
      }
   }
   else
   {
      limit = rates_total - prev_calculated + 1;

      // Ridimensiona array interni se sono arrivate nuove barre
      if(ArraySize(g_emaATR) < rates_total)
      {
         ArrayResize(g_emaATR,       rates_total);
         ArrayResize(g_kamaSlowBuf,  rates_total);
         ArrayResize(g_erSlow,       rates_total);
         ArrayResize(g_fisherValue,  rates_total);
         ArrayResize(g_stSlowUpper,  rates_total);
         ArrayResize(g_stSlowLower,  rates_total);
         ArrayResize(g_stFastUpper,  rates_total);
         ArrayResize(g_stFastLower,  rates_total);
         ArrayResize(g_stSlowState,  rates_total);
         ArrayResize(g_stFastState,  rates_total);
         ArrayResize(g_demaFastEma2, rates_total);
         ArrayResize(g_rawHmaSlow,   rates_total);
         ArrayResize(g_rawHmaFast,   rates_total);
      }
   }

   //--- ═══════════════════════════════════════════════════════════════
   //    SEZIONE 1: Copia dati da handle
   //
   //    FIX v1.05 — DIFESA A 3 LIVELLI CONTRO CRASH "ARRAY OUT OF RANGE"
   //
   //    PROBLEMA (crash su M5 e TF con molte barre):
   //    CopyBuffer() puo' restituire MENO barre di rates_total quando gli
   //    handle iMA/iATR non hanno ancora calcolato tutta la storia.
   //    Es: rates_total=500.000, CopyBuffer restituisce 200.000.
   //    Il loop partiva da limit=499.950 → accesso hmaFastHalf[499950]
   //    su un array di soli 200.000 elementi → CRASH "array out of range".
   //
   //    SOLUZIONE PROFESSIONALE (3 livelli):
   //
   //    LIVELLO 1 — BarsCalculated() gate:
   //      Prima di qualsiasi CopyBuffer, verifica che ogni sub-indicatore
   //      abbia finito di calcolare tutte le barre. Se no, return e
   //      riprova al prossimo tick. Costo zero quando i dati sono pronti.
   //
   //    LIVELLO 2 — CopyBuffer return value + clamp limit:
   //      Ogni CopyBuffer restituisce il numero REALE di barre copiate.
   //      Accumuliamo il minimo (safeBars) e clampiamo il loop limit
   //      per non superare mai i dati effettivamente disponibili.
   //      Copre edge case: gap nella storia, restart terminal, etc.
   //
   //    LIVELLO 3 — Soglia minima:
   //      Se safeBars < 50, i dati sono insufficienti per calcolare
   //      qualsiasi indicatore (KAMA, Donchian, CI hanno tutti bisogno
   //      di almeno 10-25 barre di lookback + margine). Return e riprova.
   //
   //    Ref: MQL5 docs BarsCalculated(), CopyBuffer best practices.
   //--- ═══════════════════════════════════════════════════════════════

   //--- FIX-G (v2.06): crea/aggiorna la dashboard PRIMA dei gate BarsCalculated.
   //    BUG PRECEDENTE: dopo switch TF (es. M15→M5), OnDeinit cancella tutti gli
   //    oggetti dashboard e resetta g_dashCreated=false. Ma i sub-indicatori
   //    (iATR, iMA per HMA, ecc.) non sono ancora pronti → BarsCalculated() < rates_total
   //    → OnCalculate fa return(prev_calculated) PRIMA di raggiungere
   //    UpdateBSTDashboard() alla riga ~2779. La dashboard resta invisibile
   //    per secondi (finché tutti i sub-indicatori completano il calcolo).
   //    FIX: chiamare UpdateBSTDashboard() qui, prima dei gate. La dashboard
   //    mostra informazioni statiche (versione, TF, stato toggle) che non
   //    dipendono dai buffer calcolati, quindi può essere creata/mostrata subito.
   UpdateBSTDashboard();

   //--- LIVELLO 1: BarsCalculated() gate
   //    Verifica che ogni sub-indicatore usato abbia calcolato tutte le barre.
   //    BarsCalculated() restituisce -1 se l'handle e' appena creato e non ha
   //    ancora iniziato il calcolo. Restituisce N < rates_total se il calcolo
   //    e' in corso (tipico su M5 con 500K+ barre al primo tick dopo cambio TF).
   //    In entrambi i casi: return prev_calculated → il terminale richiamera'
   //    OnCalculate al prossimo tick, quando i dati saranno pronti.
   if(BarsCalculated(g_atrHandle) < rates_total)
      return(prev_calculated);
   if(BarsCalculated(g_keltnerEMAHnd) < rates_total)
      return(prev_calculated);
   if(InpSTFastMAType == BST_MA_FAST_HMA)
   {
      if(BarsCalculated(g_hmaFastHalf) < rates_total) return(prev_calculated);
      if(BarsCalculated(g_hmaFastFull) < rates_total) return(prev_calculated);
   }
   if(InpSTSlowMAType == BST_MA_SLOW_HMA)
   {
      if(BarsCalculated(g_hmaSlowHalf) < rates_total) return(prev_calculated);
      if(BarsCalculated(g_hmaSlowFull) < rates_total) return(prev_calculated);
   }
   if(g_emaSlowHnd != INVALID_HANDLE)
   {
      if(BarsCalculated(g_emaSlowHnd) < rates_total) return(prev_calculated);
   }
   if(g_emaFastHnd != INVALID_HANDLE)
   {
      if(BarsCalculated(g_emaFastHnd) < rates_total) return(prev_calculated);
   }

   //--- LIVELLO 2: CopyBuffer con return value check + accumulo safeBars
   //    Anche dopo il gate BarsCalculated, CopyBuffer puo' restituire meno
   //    barre in edge case rari (gap storia, riconnessione broker).
   //    safeBars = numero MINIMO di barre disponibili da TUTTI i CopyBuffer.
   //    Il loop limit verra' clampato a safeBars per impedire accessi OOB.

   double atrValues[];
   ArraySetAsSeries(atrValues, true);
   int copied_atr = CopyBuffer(g_atrHandle, 0, 0, rates_total, atrValues);
   if(copied_atr <= 0)
      return(prev_calculated);
   int safeBars = copied_atr;  // inizializza con il primo CopyBuffer riuscito

   double keltnerEMA[];
   ArraySetAsSeries(keltnerEMA, true);
   int copied_kelt = CopyBuffer(g_keltnerEMAHnd, 0, 0, rates_total, keltnerEMA);
   if(copied_kelt <= 0)
      return(prev_calculated);
   safeBars = MathMin(safeBars, copied_kelt);

   // HMA Veloce (se tipo = HMA)
   //   LWMA(period/2) e LWMA(period) sono i componenti della Hull Moving Average.
   //   Se uno dei due CopyBuffer fallisce (<=0), return: HMA non calcolabile.
   double hmaFastHalf[], hmaFastFull[];
   if(InpSTFastMAType == BST_MA_FAST_HMA)
   {
      ArraySetAsSeries(hmaFastHalf, true);
      ArraySetAsSeries(hmaFastFull, true);
      int c1 = CopyBuffer(g_hmaFastHalf, 0, 0, rates_total, hmaFastHalf);
      int c2 = CopyBuffer(g_hmaFastFull, 0, 0, rates_total, hmaFastFull);
      if(c1 <= 0 || c2 <= 0)
         return(prev_calculated);  // HMA Fast non pronta, riprova al prossimo tick
      safeBars = MathMin(safeBars, MathMin(c1, c2));
   }

   // HMA Lento (se tipo = HMA)
   double hmaSlowHalf[], hmaSlowFull[];
   if(InpSTSlowMAType == BST_MA_SLOW_HMA)
   {
      ArraySetAsSeries(hmaSlowHalf, true);
      ArraySetAsSeries(hmaSlowFull, true);
      int c1 = CopyBuffer(g_hmaSlowHalf, 0, 0, rates_total, hmaSlowHalf);
      int c2 = CopyBuffer(g_hmaSlowFull, 0, 0, rates_total, hmaSlowFull);
      if(c1 <= 0 || c2 <= 0)
         return(prev_calculated);  // HMA Slow non pronta, riprova al prossimo tick
      safeBars = MathMin(safeBars, MathMin(c1, c2));
   }

   // EMA per ST Lento (se tipo = EMA)
   double emaSlowArr[];
   if(g_emaSlowHnd != INVALID_HANDLE)
   {
      ArraySetAsSeries(emaSlowArr, true);
      int c = CopyBuffer(g_emaSlowHnd, 0, 0, rates_total, emaSlowArr);
      if(c <= 0)
         return(prev_calculated);
      safeBars = MathMin(safeBars, c);
   }

   // EMA per ST Veloce (se tipo = DEMA o EMA)
   double emaFastArr[];
   if(g_emaFastHnd != INVALID_HANDLE)
   {
      ArraySetAsSeries(emaFastArr, true);
      int c = CopyBuffer(g_emaFastHnd, 0, 0, rates_total, emaFastArr);
      if(c <= 0)
         return(prev_calculated);
      safeBars = MathMin(safeBars, c);
   }

   //--- LIVELLO 3: Clamp del limit al range sicuro
   //    safeBars = barre effettive dal CopyBuffer piu' corto.
   //    Se inferiore a 50, mancano i dati minimi per KAMA (period=10+lookback),
   //    Donchian (period=20), CI (period=14), Fisher (period=9), EMA(200) warmup.
   //    limit viene ristretto per non superare mai safeBars:
   //    - safeBars - 2: margine per accessi [i+1] nel loop principale
   //    Dopo il clamp: OGNI accesso arr[i] con i <= limit e' GARANTITO in-bounds
   //    per tutti gli array locali (atrValues, keltnerEMA, hma*, ema*).
   if(safeBars < 50)
      return(prev_calculated);  // dati insufficienti, riprova al prossimo tick
   if(limit >= safeBars - 1)
      limit = safeBars - 2;     // -2: margine per accessi [i+1] nel loop

   //--- ═══════════════════════════════════════════════════════════════
   //    SEZIONE 2: Calcoli indicatori (loop dal piu' vecchio al piu' recente)
   //--- ═══════════════════════════════════════════════════════════════

   // Costanti per KAMA (v1.04: parametri configurabili via InpKAMAFastPeriod/SlowPeriod)
   double fastSC = 2.0 / ((double)MathMax(2, InpKAMAFastPeriod) + 1.0);
   double slowSC = 2.0 / ((double)MathMax(5, InpKAMASlowPeriod) + 1.0);

   for(int i = limit; i >= 0; i--)  // i=0 per linee, segnali solo su bar[1]
   {
      //--- ATR interno (copia nel buffer per EA)
      BufATRInt[i] = atrValues[i];

      //--- EMA(200) dell'ATR per offset frecce
      if(i >= rates_total - 2)
         g_emaATR[i] = atrValues[i];
      else
      {
         double alpha = 2.0 / (200.0 + 1.0);
         g_emaATR[i] = alpha * atrValues[i] + (1.0 - alpha) * g_emaATR[i + 1];
      }

      //--- HL2 per KAMA e altri calcoli
      double hl2 = (high[i] + low[i]) / 2.0;

      //--- KAMA per ST Lento (se tipo = KAMA)
      double maSlowCenter = hl2;  // default
      if(InpSTSlowMAType == BST_MA_SLOW_KAMA)
      {
         int kamaPeriod = g_stSlowPeriod_eff;
         if(i >= rates_total - kamaPeriod - 1)
         {
            g_kamaSlowBuf[i] = hl2;
         }
         else
         {
            // Efficiency Ratio
            double direction = MathAbs(hl2 - (high[i + kamaPeriod] + low[i + kamaPeriod]) / 2.0);
            double volatility = 0;
            for(int j = 0; j < kamaPeriod; j++)
            {
               double hl2_j   = (high[i + j] + low[i + j]) / 2.0;
               double hl2_j1  = (high[i + j + 1] + low[i + j + 1]) / 2.0;
               volatility += MathAbs(hl2_j - hl2_j1);
            }
            double ER = (volatility > 0) ? direction / volatility : 0;
            g_erSlow[i] = ER;   // v1.20: salva ER per uso come regime filter (FIX-03)

            // Smoothing constant adattivo
            double SC = MathPow(ER * (fastSC - slowSC) + slowSC, 2);

            // KAMA
            g_kamaSlowBuf[i] = g_kamaSlowBuf[i + 1] + SC * (hl2 - g_kamaSlowBuf[i + 1]);
         }
         maSlowCenter = g_kamaSlowBuf[i];
      }
      else if(InpSTSlowMAType == BST_MA_SLOW_HMA && ArraySize(hmaSlowHalf) > 0)
      {
         // HMA VERA (v1.04): WMA(sqrt(n)) applicata su serie intermedia
         // Step 1: serie intermedia rawHMA = 2*LWMA(n/2) - LWMA(n)
         g_rawHmaSlow[i] = 2.0 * hmaSlowHalf[i] - hmaSlowFull[i];

         // Step 2: WMA finale su floor(sqrt(period)) barre
         // Per period=10: sqrt(10)=3.16 → WMA su 3 barre
         // I valori g_rawHmaSlow[i+1], [i+2] sono gia' calcolati (loop old→new)
         int sqrtP = (int)MathMax(1, (int)MathFloor(MathSqrt((double)g_stSlowPeriod_eff)));
         if(i + sqrtP - 1 < rates_total)
         {
            double sumW = 0, sumWV = 0;
            for(int j = 0; j < sqrtP; j++)
            {
               double w = (double)(sqrtP - j);  // peso decrescente: barra piu' recente (j=0) ha peso max
               sumWV += w * g_rawHmaSlow[i + j];
               sumW  += w;
            }
            maSlowCenter = sumWV / sumW;
         }
         else
            maSlowCenter = g_rawHmaSlow[i];  // warmup: WMA non possibile, usa valore raw
      }
      else if(InpSTSlowMAType == BST_MA_SLOW_EMA && ArraySize(emaSlowArr) > 0)
      {
         maSlowCenter = emaSlowArr[i];
      }
      // else: maSlowCenter resta = hl2 (default)

      //--- MA per ST Veloce
      double maFastCenter = hl2;  // default
      if(InpSTFastMAType == BST_MA_FAST_HMA && ArraySize(hmaFastHalf) > 0)
      {
         // HMA vera = WMA(sqrt(n)) applicata su serie intermedia 2*LWMA(n/2) - LWMA(n)
         // Step 1: serie intermedia
         g_rawHmaFast[i] = 2.0 * hmaFastHalf[i] - hmaFastFull[i];

         // Step 2: WMA finale su sqrt(period) barre
         int sqrtPF = (int)MathMax(1, (int)MathFloor(MathSqrt((double)g_stFastPeriod_eff)));
         if(i + sqrtPF - 1 < rates_total)
         {
            double sumWF = 0, sumWVF = 0;
            for(int j = 0; j < sqrtPF; j++)
            {
               double w = (double)(sqrtPF - j);  // peso: piu' recente = piu' alto
               sumWVF += w * g_rawHmaFast[i + j];
               sumWF  += w;
            }
            maFastCenter = sumWVF / sumWF;
         }
         else
            maFastCenter = g_rawHmaFast[i];  // warmup: usa raw
      }
      else if(InpSTFastMAType == BST_MA_FAST_DEMA && ArraySize(emaFastArr) > 0)
      {
         // DEMA = 2*EMA(n) - EMA(EMA(n))
         double alphaFast = 2.0 / (g_stFastPeriod_eff + 1.0);
         if(i >= rates_total - 2)
            g_demaFastEma2[i] = emaFastArr[i];
         else
            g_demaFastEma2[i] = alphaFast * emaFastArr[i] + (1.0 - alphaFast) * g_demaFastEma2[i + 1];
         maFastCenter = 2.0 * emaFastArr[i] - g_demaFastEma2[i];
      }
      else if(InpSTFastMAType == BST_MA_FAST_EMA && ArraySize(emaFastArr) > 0)
      {
         maFastCenter = emaFastArr[i];
      }
      // else: maFastCenter resta = hl2 (default)

      //--- SUPERTREND LENTO (con cricchetto)
      double atr = atrValues[i];
      double upperBandSlow = maSlowCenter + g_stSlowMult_eff * atr;
      double lowerBandSlow = maSlowCenter - g_stSlowMult_eff * atr;

      // Cricchetto: upper non sale, lower non scende
      if(i < rates_total - 2)
      {
         if(upperBandSlow < g_stSlowUpper[i + 1] || close[i + 1] > g_stSlowUpper[i + 1])
            g_stSlowUpper[i] = upperBandSlow;
         else
            g_stSlowUpper[i] = g_stSlowUpper[i + 1];

         if(lowerBandSlow > g_stSlowLower[i + 1] || close[i + 1] < g_stSlowLower[i + 1])
            g_stSlowLower[i] = lowerBandSlow;
         else
            g_stSlowLower[i] = g_stSlowLower[i + 1];
      }
      else
      {
         g_stSlowUpper[i] = upperBandSlow;
         g_stSlowLower[i] = lowerBandSlow;
      }

      // Direzione ST Lento
      if(i < rates_total - 2 && g_stSlowState[i + 1] != 0)
      {
         if(g_stSlowState[i + 1] == -1)  // era BEAR
            g_stSlowState[i] = (close[i] > g_stSlowUpper[i]) ? 1 : -1;
         else  // era BULL
            g_stSlowState[i] = (close[i] < g_stSlowLower[i]) ? -1 : 1;
      }
      else
      {
         g_stSlowState[i] = (close[i] > maSlowCenter) ? 1 : -1;
      }

      // Scrivi buffer ST Lento
      if(g_stSlowState[i] == 1)
      {
         BufSTSlowBull[i] = g_stSlowLower[i];
         BufSTSlowBear[i] = EMPTY_VALUE;
      }
      else
      {
         BufSTSlowBear[i] = g_stSlowUpper[i];
         BufSTSlowBull[i] = EMPTY_VALUE;
      }

      //--- SUPERTREND VELOCE (con cricchetto)
      double upperBandFast = maFastCenter + g_stFastMult_eff * atr;
      double lowerBandFast = maFastCenter - g_stFastMult_eff * atr;

      if(i < rates_total - 2)
      {
         if(upperBandFast < g_stFastUpper[i + 1] || close[i + 1] > g_stFastUpper[i + 1])
            g_stFastUpper[i] = upperBandFast;
         else
            g_stFastUpper[i] = g_stFastUpper[i + 1];

         if(lowerBandFast > g_stFastLower[i + 1] || close[i + 1] < g_stFastLower[i + 1])
            g_stFastLower[i] = lowerBandFast;
         else
            g_stFastLower[i] = g_stFastLower[i + 1];
      }
      else
      {
         g_stFastUpper[i] = upperBandFast;
         g_stFastLower[i] = lowerBandFast;
      }

      // Direzione ST Veloce
      if(i < rates_total - 2 && g_stFastState[i + 1] != 0)
      {
         if(g_stFastState[i + 1] == -1)
            g_stFastState[i] = (close[i] > g_stFastUpper[i]) ? 1 : -1;
         else
            g_stFastState[i] = (close[i] < g_stFastLower[i]) ? -1 : 1;
      }
      else
      {
         g_stFastState[i] = (close[i] > maFastCenter) ? 1 : -1;
      }

      // Scrivi buffer ST Veloce
      if(g_stFastState[i] == 1)
      {
         BufSTFastBull[i] = g_stFastLower[i];
         BufSTFastBear[i] = EMPTY_VALUE;
      }
      else
      {
         BufSTFastBear[i] = g_stFastUpper[i];
         BufSTFastBull[i] = EMPTY_VALUE;
      }

      //--- KELTNER CHANNEL
      BufKeltnerMid[i] = keltnerEMA[i];
      BufKeltnerUp[i]  = keltnerEMA[i] + g_keltnerMult_eff * atr;
      BufKeltnerLow[i] = keltnerEMA[i] - g_keltnerMult_eff * atr;

      //--- DONCHIAN CHANNEL
      int dcPeriod = g_dcLen_eff;
      if(i + dcPeriod < rates_total)
      {
         double highestHigh = high[i];
         double lowestLow   = low[i];
         for(int j = 1; j < dcPeriod; j++)
         {
            if(high[i + j] > highestHigh) highestHigh = high[i + j];
            if(low[i + j]  < lowestLow)   lowestLow   = low[i + j];
         }
         BufDonchianUp[i]  = highestHigh;
         BufDonchianLow[i] = lowestLow;
         BufDonchianMid[i] = (highestHigh + lowestLow) / 2.0;
      }
      else
      {
         BufDonchianUp[i]  = EMPTY_VALUE;
         BufDonchianLow[i] = EMPTY_VALUE;
         BufDonchianMid[i] = EMPTY_VALUE;
      }

      //--- ER → BufCI buffer (reindirizzato a contenere ER×100 — FIX-03 v1.20)
      // g_erSlow[i] e' gia' calcolato nel blocco KAMA sopra (se KAMA attivo).
      // BufCI[i] ora contiene ER normalizzato 0-100: 0=ranging puro, 100=trend puro.
      // Scala INVERTITA rispetto al vecchio CI (dove 100=choppy).
      BufCI[i] = g_erSlow[i] * 100.0;

      //--- FISHER TRANSFORM (Ehlers)
      int fishPeriod = g_fisherPeriod_eff;
      if(i + fishPeriod < rates_total)
      {
         double fishHighest = high[i];
         double fishLowest  = low[i];
         for(int j = 1; j < fishPeriod; j++)
         {
            if(high[i + j] > fishHighest) fishHighest = high[i + j];
            if(low[i + j]  < fishLowest)  fishLowest  = low[i + j];
         }

         double fishRange = fishHighest - fishLowest;
         double ratio = (fishRange > 0) ? (hl2 - fishLowest) / fishRange : 0.5;

         // Smoothing Ehlers
         double prevValue = (i + 1 < rates_total) ? g_fisherValue[i + 1] : 0;
         double value = 0.33 * (2.0 * ratio - 1.0) + 0.67 * prevValue;

         // CLAMP obbligatorio
         value = MathMax(-0.999, MathMin(0.999, value));
         g_fisherValue[i] = value;

         // Fisher Transform
         double prevFisher = (i + 1 < rates_total) ? BufFisher[i + 1] : 0;
         BufFisher[i] = 0.5 * MathLog((1.0 + value) / (1.0 - value)) + 0.5 * prevFisher;
         BufFisherSig[i] = prevFisher;  // linea segnale = Fisher della barra precedente
      }
      else
      {
         g_fisherValue[i] = 0;
         BufFisher[i]    = 0;
         BufFisherSig[i] = 0;
      }

      //--- FISHER BAND (linea colorata sotto il Donchian)
      if(InpShowFisherBand && BufDonchianLow[i] != EMPTY_VALUE && g_emaATR[i] > 0)
      {
         BufFisherBand[i] = BufDonchianLow[i] - InpFisherBandOffset * g_emaATR[i];

         // Colore: 0=verde (bullish), 1=rosso (bearish), 2=giallo (picco)
         double fish    = BufFisher[i];
         double fishSig = BufFisherSig[i];

         // Picco rialzista: sopra soglia e inizia a scendere
         bool peakUp = (fish > InpFisherPeakThreshold && fish < fishSig);
         // Picco ribassista: sotto -soglia e inizia a salire
         bool peakDn = (fish < -InpFisherPeakThreshold && fish > fishSig);

         if(peakUp || peakDn)
            BufFisherBandClr[i] = 2;  // giallo — zona picco/inversione
         else if(fish > fishSig)
            BufFisherBandClr[i] = 0;  // verde — momentum bullish
         else
            BufFisherBandClr[i] = 1;  // rosso — momentum bearish
      }
      else
      {
         BufFisherBand[i]    = EMPTY_VALUE;
         BufFisherBandClr[i] = 0;
      }

      //--- Inizializza frecce e segnali a EMPTY
      BufEntryBuy[i]    = EMPTY_VALUE;
      BufEntrySell[i]   = EMPTY_VALUE;
      BufExitLong[i]    = EMPTY_VALUE;
      BufExitShort[i]   = EMPTY_VALUE;
      BufSignalEntry[i] = 0;
      BufSignalExit[i]  = 0;

      //--- ENTRY/EXIT evaluation per tutte le barre chiuse (i >= 1)
      if(i >= 1)
      {
         //--- ENTRY BUY
         bool buy_ok = true;

         // Filtro 0: Gate MTF — entry BUY solo se MTF non e' BEAR (v1.20)
         if(buy_ok && InpMTF_Enable && InpMTF_GateEntry)
         {
            if(BufMTFDir[i] < -0.5)
               buy_ok = false;
         }

         if(InpSTSlowEnable && g_stSlowState[i] != 1)
            buy_ok = false;

         //--- FIX-F (v2.06): Donchian breakout deve confrontare il close della barra
         //    corrente [i] con il canale della barra PRECEDENTE [i+1].
         //    BUG PRECEDENTE: usava BufDonchianUp[i] che INCLUDE high[i] della stessa
         //    barra. Siccome BufDonchianUp[i] >= high[i] >= close[i] e' SEMPRE vero,
         //    la condizione close[i] > BufDonchianUp[i] era MATEMATICAMENTE IMPOSSIBILE.
         //    Nessuna freccia entry BUY e' mai stata generata.
         //    FIX: confronta con [i+1] = canale chiuso della barra precedente.
         //    Questo e' il breakout standard (Turtle Trading): il prezzo deve chiudere
         //    FUORI dal canale precedente per confermare il breakout.
         //    Ref: BST_CompleteSpec_v1.20 FIX-04.
         if(buy_ok && InpDonchianEnable)
         {
            if(i + 1 >= rates_total || BufDonchianUp[i + 1] == EMPTY_VALUE || close[i] <= BufDonchianUp[i + 1])
               buy_ok = false;
         }

         if(buy_ok && InpEntryRequireKeltner && InpKeltnerEnable)
         {
            if(close[i] <= BufKeltnerUp[i])
               buy_ok = false;
         }

         // Filtro ER: mercato sufficientemente direzionale per entry (FIX-03 v1.20)
         if(buy_ok && InpEntryRequireCI && InpCIEnable)
         {
            if(g_erSlow[i] < 0.30)
               buy_ok = false;
         }

         if(buy_ok && InpEntryRequireFastST && InpSTFastEnable)
         {
            if(g_stFastState[i] != 1)
               buy_ok = false;
         }

         if(buy_ok && InpUseTimeFilter)
         {
            if(!IsInSession(time[i]))
               buy_ok = false;
         }

         //--- ANTI-DUPLICATO ENTRY BUY (v1.03, esteso v1.04)
         //    In un trend forte, OGNI barra consecutiva soddisfa tutti i filtri
         //    (Donchian breakout continuo, CI basso, prezzo fuori Keltner).
         //    Risultato: cluster di 5-10 frecce verdi consecutive → illeggibile.
         //    v1.04: controlla le ultime InpEntryAntiDupLookback barre (non solo 1).
         //    Il loop processa da i=limit (vecchio) a i=0 (nuovo),
         //    quindi BufSignalEntry[i+j] e' gia' stato impostato quando arriviamo a i.
         if(buy_ok && InpEntryAntiDuplicate)
         {
            int lookback = MathMax(1, InpEntryAntiDupLookback);
            for(int j = 1; j <= lookback && i + j < rates_total; j++)
            {
               if(BufSignalEntry[i + j] == 1.0)
               { buy_ok = false; break; }
            }
         }

         if(buy_ok)
         {
            // Freccia BUY sotto il canale: base = minimo tra candela e bande visibili
            double buyBase = low[i];
            if(InpKeltnerEnable && BufKeltnerLow[i] != EMPTY_VALUE && BufKeltnerLow[i] < buyBase)
               buyBase = BufKeltnerLow[i];
            if(InpDonchianEnable && BufDonchianLow[i] != EMPTY_VALUE && BufDonchianLow[i] < buyBase)
               buyBase = BufDonchianLow[i];
            BufEntryBuy[i]    = buyBase - g_emaATR[i] * InpArrowOffsetMult;
            BufSignalEntry[i] = 1.0;
         }

         //--- ENTRY SELL
         bool sell_ok = true;

         // Filtro 0: Gate MTF — entry SELL solo se MTF non e' BULL (v1.20)
         if(sell_ok && InpMTF_Enable && InpMTF_GateEntry)
         {
            if(BufMTFDir[i] > 0.5)
               sell_ok = false;
         }

         if(InpSTSlowEnable && g_stSlowState[i] != -1)
            sell_ok = false;

         //--- FIX-F (v2.06): stessa correzione del BUY — confronta con barra precedente.
         //    BUG: BufDonchianLow[i] <= low[i] <= close[i] era SEMPRE vero,
         //    quindi close[i] < BufDonchianLow[i] era IMPOSSIBILE.
         //    FIX: confronta con [i+1] = canale chiuso della barra precedente.
         if(sell_ok && InpDonchianEnable)
         {
            if(i + 1 >= rates_total || BufDonchianLow[i + 1] == EMPTY_VALUE || close[i] >= BufDonchianLow[i + 1])
               sell_ok = false;
         }

         if(sell_ok && InpEntryRequireKeltner && InpKeltnerEnable)
         {
            if(close[i] >= BufKeltnerLow[i])
               sell_ok = false;
         }

         // Filtro ER: mercato sufficientemente direzionale per entry (FIX-03 v1.20)
         if(sell_ok && InpEntryRequireCI && InpCIEnable)
         {
            if(g_erSlow[i] < 0.30)
               sell_ok = false;
         }

         if(sell_ok && InpEntryRequireFastST && InpSTFastEnable)
         {
            if(g_stFastState[i] != -1)
               sell_ok = false;
         }

         if(sell_ok && InpUseTimeFilter)
         {
            if(!IsInSession(time[i]))
               sell_ok = false;
         }

         //--- ANTI-DUPLICATO ENTRY SELL (v1.03, esteso v1.04)
         //    Speculare al filtro BUY: blocca Entry SELL se nelle ultime N barre
         //    c'era gia' un Entry SELL (BufSignalEntry == -1.0).
         //    Evita cluster di frecce rosse consecutive in downtrend sostenuto.
         if(sell_ok && InpEntryAntiDuplicate)
         {
            int lookback = MathMax(1, InpEntryAntiDupLookback);
            for(int j = 1; j <= lookback && i + j < rates_total; j++)
            {
               if(BufSignalEntry[i + j] == -1.0)
               { sell_ok = false; break; }
            }
         }

         if(sell_ok)
         {
            // Freccia SELL sopra il canale: base = massimo tra candela e bande visibili
            double sellBase = high[i];
            if(InpKeltnerEnable && BufKeltnerUp[i] != EMPTY_VALUE && BufKeltnerUp[i] > sellBase)
               sellBase = BufKeltnerUp[i];
            if(InpDonchianEnable && BufDonchianUp[i] != EMPTY_VALUE && BufDonchianUp[i] > sellBase)
               sellBase = BufDonchianUp[i];
            BufEntrySell[i]   = sellBase + g_emaATR[i] * InpArrowOffsetMult;
            BufSignalEntry[i] = -1.0;
         }

         //--- ER valido solo con KAMA (v1.20): con HMA/EMA g_erSlow=0.5 neutro → filtri ER disabilitati
         bool erValid = (InpSTSlowMAType == BST_MA_SLOW_KAMA);

         //--- EXIT LONG
         bool exitL_primary = false;
         bool exitL_secondary = false;
         bool exitL_ci = false;

         // ST Fast flip da BULL a BEAR (gia' transizione)
         if(InpSTFastEnable && g_stFastState[i] == -1 && g_stFastState[i + 1] == 1)
            exitL_primary = true;

         // Fisher: PRIMO bar di picco (inizia a scendere sopra soglia, bar precedente non scendeva)
         if(InpFisherEnable && i + 2 < rates_total)
         {
            bool peakNow  = (BufFisher[i] > InpFisherPeakThreshold && BufFisher[i] < BufFisher[i + 1]);
            bool peakPrev = (BufFisher[i + 1] > InpFisherPeakThreshold && BufFisher[i + 1] < BufFisher[i + 2]);
            if(peakNow && !peakPrev)
               exitL_secondary = true;
         }

         // ER basso = mercato troppo choppy = allerta exit (FIX-03 v1.20)
         if(InpCIEnable && erValid && g_erSlow[i] < 0.18)
            exitL_ci = true;

         bool exitL = false;
         if(InpExitRequireBoth)
            exitL = exitL_primary && exitL_secondary;
         else
         {
            //--- v1.20: in trend forte (ER alto), richiedi conferma doppia (AND)
            //    per evitare EXIT premature su micro-pullback.
            bool strongTrend = InpExitStrongTrendAND && InpCIEnable && erValid
                               && g_erSlow[i] > InpExitStrongTrendCI / 100.0;  // default 40→0.40
            if(strongTrend)
               exitL = exitL_primary && (exitL_secondary || exitL_ci);
            else
               exitL = exitL_primary || exitL_secondary || exitL_ci;
         }

         //--- FILTRO CONTESTO DIREZIONALE EXIT LONG (v1.03)
         //    Exit Long ha senso SOLO se eravamo in contesto BULL (c'era un long da chiudere).
         //    Verifica: ST Lento = BULL sulla barra corrente OPPURE sulla barra precedente
         //    (per catturare anche il caso di transizione BULL→BEAR nello stesso momento).
         //    Se InpExitRequireContext=false, il filtro e' disabilitato (comportamento v1.02).
         if(InpExitRequireContext && exitL)
         {
            if(g_stSlowState[i] != 1 && (i + 1 >= rates_total || g_stSlowState[i + 1] != 1))
               exitL = false;  // Nessun contesto BULL → sopprime Exit Long spurio
         }

         //--- FILTRO ER CHOPPY EXIT LONG (v1.20)
         //    ER < 0.15 = mercato troppo choppy → sopprime exit
         if(InpExitFilterChoppy && InpCIEnable && erValid && exitL)
         {
            if(g_erSlow[i] < 0.15)
               exitL = false;  // Mercato choppy → sopprime Exit Long
         }

         if(exitL)
         {
            double exitLBase = high[i];
            if(InpKeltnerEnable && BufKeltnerUp[i] != EMPTY_VALUE && BufKeltnerUp[i] > exitLBase)
               exitLBase = BufKeltnerUp[i];
            if(InpDonchianEnable && BufDonchianUp[i] != EMPTY_VALUE && BufDonchianUp[i] > exitLBase)
               exitLBase = BufDonchianUp[i];
            BufExitLong[i]   = exitLBase + g_emaATR[i] * InpArrowOffsetMult * 0.7;
            BufSignalExit[i] = 1.0;
         }

         //--- EXIT SHORT
         bool exitS_primary = false;
         bool exitS_secondary = false;
         bool exitS_ci = false;

         // ST Fast flip da BEAR a BULL (gia' transizione)
         if(InpSTFastEnable && g_stFastState[i] == 1 && g_stFastState[i + 1] == -1)
            exitS_primary = true;

         // Fisher: PRIMO bar di rimbalzo da minimo (inizia a salire sotto -soglia, bar prec non saliva)
         if(InpFisherEnable && i + 2 < rates_total)
         {
            bool troughNow  = (BufFisher[i] < -InpFisherPeakThreshold && BufFisher[i] > BufFisher[i + 1]);
            bool troughPrev = (BufFisher[i + 1] < -InpFisherPeakThreshold && BufFisher[i + 1] > BufFisher[i + 2]);
            if(troughNow && !troughPrev)
               exitS_secondary = true;
         }

         // ER basso = mercato troppo choppy = allerta exit (FIX-03 v1.20)
         if(InpCIEnable && erValid && g_erSlow[i] < 0.18)
            exitS_ci = true;

         bool exitS = false;
         if(InpExitRequireBoth)
            exitS = exitS_primary && exitS_secondary;
         else
         {
            //--- v1.20: speculare a Exit Long — AND in trend forte
            bool strongTrendS = InpExitStrongTrendAND && InpCIEnable && erValid
                                && g_erSlow[i] > InpExitStrongTrendCI / 100.0;  // default 40→0.40
            if(strongTrendS)
               exitS = exitS_primary && (exitS_secondary || exitS_ci);
            else
               exitS = exitS_primary || exitS_secondary || exitS_ci;
         }

         //--- FILTRO CONTESTO DIREZIONALE EXIT SHORT (v1.03)
         //    Exit Short ha senso SOLO se eravamo in contesto BEAR (c'era uno short da chiudere).
         //    Stessa logica speculare di Exit Long: ST Lento = BEAR su i o i+1.
         if(InpExitRequireContext && exitS)
         {
            if(g_stSlowState[i] != -1 && (i + 1 >= rates_total || g_stSlowState[i + 1] != -1))
               exitS = false;  // Nessun contesto BEAR → sopprime Exit Short spurio
         }

         //--- FILTRO ER CHOPPY EXIT SHORT (v1.20)
         //    ER < 0.15 = mercato troppo choppy → sopprime exit
         if(InpExitFilterChoppy && InpCIEnable && erValid && exitS)
         {
            if(g_erSlow[i] < 0.15)
               exitS = false;  // Mercato choppy → sopprime Exit Short
         }

         if(exitS && !exitL)
         {
            double exitSBase = low[i];
            if(InpKeltnerEnable && BufKeltnerLow[i] != EMPTY_VALUE && BufKeltnerLow[i] < exitSBase)
               exitSBase = BufKeltnerLow[i];
            if(InpDonchianEnable && BufDonchianLow[i] != EMPTY_VALUE && BufDonchianLow[i] < exitSBase)
               exitSBase = BufDonchianLow[i];
            BufExitShort[i]  = exitSBase - g_emaATR[i] * InpArrowOffsetMult * 0.7;
            BufSignalExit[i] = -1.0;
         }
      }
   }

   //--- ═══════════════════════════════════════════════════════════════
   //    SEZIONE 3: Midline Donchian color index
   //--- ═══════════════════════════════════════════════════════════════
   for(int i = limit; i >= 0; i--)
   {
      if(BufDonchianMid[i] != EMPTY_VALUE && BufDonchianMid[i + 1] != EMPTY_VALUE)
         BufDonMidColor[i] = (BufDonchianMid[i] >= BufDonchianMid[i + 1]) ? 0 : 1;
      else
         BufDonMidColor[i] = 0;
   }

   //--- ═══════════════════════════════════════════════════════════════
   //    SEZIONE 4: Candele DRAW_COLOR_CANDLES
   //--- ═══════════════════════════════════════════════════════════════
   for(int i = limit; i >= 0; i--)
   {
      BufCandleO[i] = open[i];
      BufCandleH[i] = high[i];
      BufCandleL[i] = low[i];
      BufCandleC[i] = close[i];

      // Colore: 0=bull, 1=bear, 2=signal entry (giallo), 3=signal exit (grigio)
      BufCandleColor[i] = (close[i] >= open[i]) ? 0 : 1;
      if(InpShowSignalCandle && BufSignalEntry[i] != 0)
         BufCandleColor[i] = 2;
      if(InpShowSignalCandle && BufSignalExit[i] != 0)
         BufCandleColor[i] = 3;
   }

   //--- ═══════════════════════════════════════════════════════════════
   //    SEZIONE 4b: MTF Overlay (calcolo + plot su TF corrente) v1.20
   //--- ═══════════════════════════════════════════════════════════════
   if(InpMTF_Enable)
      CalculateMTFOverlay(rates_total, prev_calculated, limit, time);

   //--- Aggiorna direzione corrente (per tooltip e debug)
   if(rates_total > 1)
   {
      g_stSlowDir = g_stSlowState[1];
      g_stFastDir = g_stFastState[1];
   }

   //--- ═══════════════════════════════════════════════════════════════
   //    SEZIONE 5: OBJ_ARROW tooltip + Alert (solo bar[1], real-time)
   //    I buffer frecce sono gia' popolati nel main loop (Sezione 2).
   //    Qui creiamo solo gli OBJ_ARROW per tooltip e lanciamo Alert.
   //--- ═══════════════════════════════════════════════════════════════

   if(time[1] != s_lastEntryBar)
   {
      if(BufSignalEntry[1] == 1.0)
      {
         CreateEntryArrow(time[1], BufEntryBuy[1], 1);
         if(InpAlertEntry)
            Alert("[BST] ENTRY BUY — ", _Symbol, " @ ", DoubleToString(close[1], _Digits));
         s_lastEntryBar = time[1];
      }
      else if(BufSignalEntry[1] == -1.0)
      {
         CreateEntryArrow(time[1], BufEntrySell[1], -1);
         if(InpAlertEntry)
            Alert("[BST] ENTRY SELL — ", _Symbol, " @ ", DoubleToString(close[1], _Digits));
         s_lastEntryBar = time[1];
      }
   }

   if(time[1] != s_lastExitBar)
   {
      if(BufSignalExit[1] == 1.0)
      {
         CreateExitArrow(time[1], BufExitLong[1], 1);
         if(InpAlertExit)
            Alert("[BST] EXIT LONG — ", _Symbol, " @ ", DoubleToString(close[1], _Digits));
         s_lastExitBar = time[1];
      }
      else if(BufSignalExit[1] == -1.0)
      {
         CreateExitArrow(time[1], BufExitShort[1], -1);
         if(InpAlertExit)
            Alert("[BST] EXIT SHORT — ", _Symbol, " @ ", DoubleToString(close[1], _Digits));
         s_lastExitBar = time[1];
      }
   }

   //--- ═══════════════════════════════════════════════════════════════
   //    SEZIONE 7: Debug output
   //--- ═══════════════════════════════════════════════════════════════
   if(InpDebugMode && time[1] != s_lastDebugBar)
   {
      string keltPos = (close[1] > BufKeltnerUp[1]) ? "OUT_UP" :
                       (close[1] < BufKeltnerLow[1]) ? "OUT_DN" : "INSIDE";
      string dcBreak = (close[1] > BufDonchianUp[1]) ? "UP" :
                       (close[1] < BufDonchianLow[1]) ? "DN" : "NONE";

      Print("[BST] bar=", TimeToString(time[1], TIME_DATE|TIME_MINUTES),
            " ST_slow=", g_stSlowState[1],
            " ST_fast=", g_stFastState[1],
            " CI=", DoubleToString(BufCI[1], 1),
            " Fisher=", DoubleToString(BufFisher[1], 3),
            " Keltner=", keltPos,
            " DC=", dcBreak);

      s_lastDebugBar = time[1];
   }

   //--- ═══════════════════════════════════════════════════════════════
   //    SEZIONE 8: Redraw canvas fill Donchian
   //--- ═══════════════════════════════════════════════════════════════
   RedrawCanvas();

   //--- ═══════════════════════════════════════════════════════════════
   //    SEZIONE 9: Dashboard
   //--- ═══════════════════════════════════════════════════════════════
   UpdateBSTDashboard();

   return(rates_total);
}

// ═══════════════════════════════════════════════════════════════════
// CreateEntryArrow — Crea OBJ_ARROW per segnale ENTRY
// ═══════════════════════════════════════════════════════════════════
void CreateEntryArrow(datetime t, double price, int dir)
{
   string name = SIGNAL_PREFIX + (dir == 1 ? "BUY_" : "SELL_") + IntegerToString((long)t);

   // Anti-duplicato: se esiste gia', non ricreare
   if(ObjectFind(0, name) >= 0)
      return;

   ObjectCreate(0, name, OBJ_ARROW, 0, t, price);
   ObjectSetInteger(0, name, OBJPROP_ARROWCODE, (dir == 1) ? 233 : 234);
   ObjectSetInteger(0, name, OBJPROP_COLOR, (dir == 1) ? InpColorEntryBuy : InpColorEntrySell);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, InpArrowSize);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);

   // Tooltip con info filtri
   string tooltip = (dir == 1 ? "ENTRY BUY" : "ENTRY SELL") + "\n" +
                    "ST Lento: " + (g_stSlowDir == 1 ? "BULL" : "BEAR") + "\n" +
                    "ST Veloce: " + (g_stFastDir == 1 ? "BULL" : "BEAR") + "\n" +
                    "CI: " + DoubleToString(BufCI[1], 1) + "\n" +
                    "Fisher: " + DoubleToString(BufFisher[1], 3);
   ObjectSetString(0, name, OBJPROP_TOOLTIP, tooltip);
}

// ═══════════════════════════════════════════════════════════════════
// CreateExitArrow — Crea OBJ_ARROW per segnale EXIT (stella)
// ═══════════════════════════════════════════════════════════════════
void CreateExitArrow(datetime t, double price, int dir)
{
   string name = SIGNAL_PREFIX + (dir == 1 ? "EXIT_LONG_" : "EXIT_SHORT_") + IntegerToString((long)t);

   if(ObjectFind(0, name) >= 0)
      return;

   ObjectCreate(0, name, OBJ_ARROW, 0, t, price);
   ObjectSetInteger(0, name, OBJPROP_ARROWCODE, 171);  // Stella Wingdings
   ObjectSetInteger(0, name, OBJPROP_COLOR, (dir == 1) ? InpColorExitLong : InpColorExitShort);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, InpArrowSize - 1);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);

   string tooltip = (dir == 1 ? "EXIT LONG" : "EXIT SHORT") + "\n" +
                    "ST Veloce flipped: " + (dir == 1 ? "BULL->BEAR" : "BEAR->BULL") + "\n" +
                    "Fisher: " + DoubleToString(BufFisher[1], 3) + "\n" +
                    "CI: " + DoubleToString(BufCI[1], 1);
   ObjectSetString(0, name, OBJPROP_TOOLTIP, tooltip);
}

// ═══════════════════════════════════════════════════════════════════
// DeleteSignalObjects — Elimina tutti gli OBJ_ARROW con prefisso
// ═══════════════════════════════════════════════════════════════════
void DeleteSignalObjects()
{
   for(int i = ObjectsTotal(0) - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i);
      if(StringFind(name, SIGNAL_PREFIX) == 0)
         ObjectDelete(0, name);
   }
}

// ═══════════════════════════════════════════════════════════════════
// ParseTimeToMinutes — Converte stringa "HH:MM" in minuti del giorno
// ═══════════════════════════════════════════════════════════════════
int ParseTimeToMinutes(string timeStr)
{
   int colonPos = StringFind(timeStr, ":");
   if(colonPos < 0)
      return(0);

   int hours   = (int)StringToInteger(StringSubstr(timeStr, 0, colonPos));
   int minutes = (int)StringToInteger(StringSubstr(timeStr, colonPos + 1));

   return(hours * 60 + minutes);
}

// ═══════════════════════════════════════════════════════════════════
// IsInSession — Verifica se il timestamp e' dentro la finestra operativa
// ═══════════════════════════════════════════════════════════════════
bool IsInSession(datetime t)
{
   MqlDateTime dt;
   TimeToStruct(t, dt);

   int currentMin = dt.hour * 60 + dt.min;

   // Gestisce sessione che attraversa la mezzanotte
   if(g_sessionStartMin < g_sessionEndMin)
   {
      // Sessione normale (es. 08:00 - 20:00)
      return(currentMin >= g_sessionStartMin && currentMin < g_sessionEndMin);
   }
   else
   {
      // Sessione attraversa mezzanotte (es. 22:00 - 06:00)
      return(currentMin >= g_sessionStartMin || currentMin < g_sessionEndMin);
   }
}

// ═══════════════════════════════════════════════════════════════════
// ═══════════════════════════════════════════════════════════════════
// RedrawCanvas — Fill semitrasparente tra bande Donchian
//
// SCOPO:
//   Disegna un fill semitrasparente tra Donchian Upper e Lower
//   per OGNI barra visibile. Il colore dipende dallo stato del
//   SuperTrend Lento: verde=BULL, rosso=BEAR, blu=NEUTRALE.
//
// TECNICA:
//   CCanvas + FillTriangle(ARGB) — l'unica via in MQL5 per avere
//   fill con VERA trasparenza alpha. DRAW_FILLING nativo non supporta
//   alpha, e OBJ_RECTANGLE non supporta trasparenza.
//   ChartTimePriceToXY usato per ENTRAMBI gli assi X e Y (v2.05).
//   Y viene clampato a [-chartH, 2*chartH] per prevenire overflow
//   int32 su prezzi fuori dal range visibile.
//
// GEOMETRIA:
//   Per ogni coppia di barre consecutive (shift1, shift2) disegniamo
//   un quadrilatero composto da 2 triangoli:
//
//     (x1,yHi1) ────── (x2,yHi2)    <- Donchian Upper
//        |  \ Tri.1  /     |
//        |    \    /       |
//        |  Tri.2 \       |
//     (x1,yLo1) ────── (x2,yLo2)    <- Donchian Lower
//
// THROTTLE:
//   Max 5 FPS (200ms) per ridurre carico CPU.
// ═══════════════════════════════════════════════════════════════════
void RedrawCanvas(bool forceRedraw = false)
{
   //--- FIX-A (v2.06): il guard originale controllava solo InpDonchianEnable
   //    (parametro input, sempre true dopo l'avvio) ma IGNORAVA g_vis_donchian
   //    (toggle runtime dalla dashboard). Risultato: quando l'utente cliccava
   //    DON → OFF, le linee Donchian (plots 7-9) sparivano via DRAW_NONE,
   //    ma il canvas fill CCanvas (bitmap sovrapposto al chart) restava visibile
   //    creando barre verticali colorate che invadevano il grafico.
   //    Aggiunto || !g_vis_donchian per cancellare il canvas quando DON e' OFF.
   //    Ref: MQL5 article "Canvas based indicators: Filling channels with transparency"
   //         conferma che CCanvas richiede gestione esplicita (Erase+Update).
   if(!InpShowDCFill || !InpDonchianEnable || !g_vis_donchian)
   {
      if(g_canvasCreated) { g_canvas.Erase(0x00000000); g_canvas.Update(); }
      return;
   }

   //--- Throttle: max 5 ridisegni/secondo (1 ogni 200ms).
   static uint s_lastRedrawMs = 0;
   if(!forceRedraw)
   {
      uint now = GetTickCount();
      if(now - s_lastRedrawMs < 200) return;
      s_lastRedrawMs = now;
   }

   int chartW = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   int chartH = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
   if(chartW <= 0 || chartH <= 0) return;

   //--- Crea/ridimensiona canvas
   if(!g_canvasCreated)
   {
      if(!g_canvas.CreateBitmapLabel(0, 0, g_canvasName, 0, 0, chartW, chartH, COLOR_FORMAT_ARGB_NORMALIZE))
         return;
      ObjectSetInteger(0, g_canvasName, OBJPROP_BACK, true);
      ObjectSetInteger(0, g_canvasName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, g_canvasName, OBJPROP_HIDDEN, true);
      ObjectSetString(0, g_canvasName, OBJPROP_TOOLTIP, "\n");
      g_canvasCreated = true;
   }
   else if(g_canvas.Width() != chartW || g_canvas.Height() != chartH)
      g_canvas.Resize(chartW, chartH);

   g_canvas.Erase(0x00000000);

   //--- Proprieta' barre visibili
   int firstVisible = (int)ChartGetInteger(0, CHART_FIRST_VISIBLE_BAR);
   int visibleBars  = (int)ChartGetInteger(0, CHART_VISIBLE_BARS);
   int totalBars    = ArraySize(BufDonchianUp);
   if(totalBars == 0) { g_canvas.Update(); return; }

   //--- Colori ARGB per i 3 stati del SuperTrend Lento
   uchar fillAlpha = (uchar)MathMax(0, MathMin(255, InpFillAlpha));
   uint argbBull    = ColorToARGB(InpFillBullColor,    fillAlpha);
   uint argbBear    = ColorToARGB(InpFillBearColor,    fillAlpha);
   uint argbNeutral = ColorToARGB(InpFillNeutralColor, fillAlpha);

   //--- Loop su coppie di barre consecutive visibili
   for(int v = 0; v < visibleBars - 1; v++)
   {
      int shift1 = firstVisible - v;
      int shift2 = firstVisible - v - 1;
      if(shift1 < 0 || shift2 < 0 || shift1 >= totalBars || shift2 >= totalBars)
         continue;

      if(BufDonchianUp[shift1] == EMPTY_VALUE || BufDonchianLow[shift1] == EMPTY_VALUE ||
         BufDonchianUp[shift2] == EMPTY_VALUE || BufDonchianLow[shift2] == EMPTY_VALUE)
         continue;

      //--- Stato ST Lento con smoothing anti-flicker (1 barra)
      int stState = 0;
      if(shift1 < ArraySize(g_stSlowState))
         stState = g_stSlowState[shift1];

      // Anti-flicker: se lo stato e' cambiato per 1 sola barra, mantieni il precedente
      if(shift1 + 1 < ArraySize(g_stSlowState) && shift1 + 2 < ArraySize(g_stSlowState))
      {
         if(g_stSlowState[shift1] != g_stSlowState[shift1 + 1] &&
            g_stSlowState[shift1 + 1] == g_stSlowState[shift1 + 2])
            stState = g_stSlowState[shift1 + 1];
      }

      uint fillARGB;
      if(stState == 1)       fillARGB = argbBull;
      else if(stState == -1) fillARGB = argbBear;
      else                   fillARGB = argbNeutral;

      //--- Coordinate pixel via ChartTimePriceToXY (approccio v2.03 provato)
      datetime t1 = iTime(_Symbol, PERIOD_CURRENT, shift1);
      datetime t2 = iTime(_Symbol, PERIOD_CURRENT, shift2);
      if(t1 == 0 || t2 == 0) continue;

      int x1, yHi1, yLo1, x2, yHi2, yLo2;
      if(!ChartTimePriceToXY(0, 0, t1, BufDonchianUp[shift1],  x1, yHi1)) continue;
      if(!ChartTimePriceToXY(0, 0, t1, BufDonchianLow[shift1], x1, yLo1)) continue;
      if(!ChartTimePriceToXY(0, 0, t2, BufDonchianUp[shift2],  x2, yHi2)) continue;
      if(!ChartTimePriceToXY(0, 0, t2, BufDonchianLow[shift2], x2, yLo2)) continue;

      //--- Clamp Y a [-chartH, 2*chartH] per evitare overflow int32
      //    (ChartTimePriceToXY puo' dare valori estremi per prezzi fuori range visibile)
      yHi1 = MathMax(-chartH, MathMin(2*chartH, yHi1));
      yLo1 = MathMax(-chartH, MathMin(2*chartH, yLo1));
      yHi2 = MathMax(-chartH, MathMin(2*chartH, yHi2));
      yLo2 = MathMax(-chartH, MathMin(2*chartH, yLo2));

      //--- 2 triangoli per riempire il quadrilatero
      g_canvas.FillTriangle(x1, yHi1, x1, yLo1, x2, yHi2, fillARGB);
      g_canvas.FillTriangle(x1, yLo1, x2, yHi2, x2, yLo2, fillARGB);
   }

   g_canvas.Update();
}

// ═══════════════════════════════════════════════════════════════════
// MINI DASHBOARD — Pannello informativo Top-Left
// Stile identico a MultiPV: sfondo blu scuro, bordo oro, Consolas.
//
// ANTI-FLICKER PATTERN (best practice MQL5):
//   - Oggetti creati UNA VOLTA (create-once), MAI cancellati durante il runtime
//   - Aggiornamento in-place con ObjectSetString/ObjectSetInteger (asincrono, zero flicker)
//   - Pool di 30 righe pre-allocate, nascoste con OBJPROP_TIMEFRAMES = OBJ_NO_PERIODS
//   - Righe mostrate con OBJ_ALL_PERIODS quando servono
//   - ObjectsDeleteAll SOLO in OnDeinit o quando dashboard viene disabilitata
//   - ChartRedraw() chiamato UNA SOLA volta alla fine di OnCalculate
// ═══════════════════════════════════════════════════════════════════

#define BST_DASH_MAX_ROWS 30

bool g_dashCreated = false;       // flag: oggetti gia' creati
int  g_dashLastRowUsed = 0;       // quante righe usate nell'ultimo update

//+------------------------------------------------------------------+
//|  InitBSTDashboard — Pre-crea tutti gli oggetti dashboard (pool)   |
//|  Chiamata UNA VOLTA. Crea BG, bordo, 30 label, 6 bottoni.        |
//|  Tutti nascosti inizialmente (OBJ_NO_PERIODS).                    |
//+------------------------------------------------------------------+
void InitBSTDashboard()
{
   if(g_dashCreated) return;

   int x_base = 10;
   int y_base = 20;
   int y_step = 16;

   // --- Sfondo: bordo oro + BG blu scuro ---
   string brd_name = DASH_PREFIX + "BORDER";
   ObjectCreate(0, brd_name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, brd_name, OBJPROP_CORNER,      CORNER_LEFT_UPPER);
   ObjectSetInteger(0, brd_name, OBJPROP_BACK,        false);
   ObjectSetInteger(0, brd_name, OBJPROP_SELECTABLE,  false);
   ObjectSetInteger(0, brd_name, OBJPROP_HIDDEN,      true);
   ObjectSetInteger(0, brd_name, OBJPROP_ZORDER,      14999);
   ObjectSetInteger(0, brd_name, OBJPROP_BGCOLOR,     C'200,180,50');
   ObjectSetInteger(0, brd_name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, brd_name, OBJPROP_BORDER_COLOR,C'200,180,50');

   string bg_name = DASH_PREFIX + "BG";
   ObjectCreate(0, bg_name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, bg_name, OBJPROP_CORNER,      CORNER_LEFT_UPPER);
   ObjectSetInteger(0, bg_name, OBJPROP_BACK,        false);
   ObjectSetInteger(0, bg_name, OBJPROP_SELECTABLE,  false);
   ObjectSetInteger(0, bg_name, OBJPROP_HIDDEN,      true);
   ObjectSetInteger(0, bg_name, OBJPROP_ZORDER,      15000);
   ObjectSetInteger(0, bg_name, OBJPROP_BGCOLOR,     C'12,20,45');
   ObjectSetInteger(0, bg_name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, bg_name, OBJPROP_BORDER_COLOR,C'12,20,45');

   // --- Pool di righe label (tutte nascoste) ---
   for(int i = 0; i < BST_DASH_MAX_ROWS; i++)
   {
      string name = DASH_PREFIX + "R" + StringFormat("%02d", i);
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER,    CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x_base);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y_base + i * y_step);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN,     true);
      ObjectSetInteger(0, name, OBJPROP_ZORDER,     16000);
      ObjectSetString(0, name, OBJPROP_FONT,        "Consolas");
      ObjectSetString(0, name, OBJPROP_TEXT,         "");
      ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);  // nascosta
   }

   // --- Bottoni toggle (tutti nascosti inizialmente) ---
   //     FIX-C (v2.06): aggiunto "MTF" come 7° bottone per toggle runtime
   //     del SuperTrend MTF (plots 15-16). Visibile solo se InpMTF_Enable=true.
   //     Prima di questo fix, l'MTF poteva essere abilitato/disabilitato
   //     solo tramite il parametro input InpMTF_Enable (richiede ricarica indicatore).
   string btnIds[7] = {"STSLOW","STFAST","KELT","DON","CI","FISHER","MTF"};
   for(int i = 0; i < 7; i++)
   {
      string name = DASH_PREFIX + "BTN_" + btnIds[i];
      ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER,     CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE,  false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN,      true);
      ObjectSetInteger(0, name, OBJPROP_ZORDER,      17000);
      ObjectSetInteger(0, name, OBJPROP_XSIZE,       36);
      ObjectSetInteger(0, name, OBJPROP_YSIZE,       15);
      ObjectSetString(0, name, OBJPROP_FONT,         "Consolas");
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE,    7);
      ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
   }

   g_dashCreated = true;
}

//+------------------------------------------------------------------+
//|  BSTSetRow — Aggiorna una riga del pool (testo, colore, Y, show) |
//|  NON crea ne' cancella oggetti — solo ObjectSet* (zero flicker).  |
//+------------------------------------------------------------------+
void BSTSetRow(int idx, string text, color clr, int fontSize)
{
   if(idx < 0 || idx >= BST_DASH_MAX_ROWS) return;
   string name = DASH_PREFIX + "R" + StringFormat("%02d", idx);

   int x_base = 10;
   int y_base = 20;
   int y_step = 16;

   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y_base + idx * y_step);
   ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);  // mostra
}

//+------------------------------------------------------------------+
//|  BSTSetBtn — Aggiorna un bottone toggle (posizione Y, stato)      |
//+------------------------------------------------------------------+
void BSTSetBtn(string id, bool is_on, int y)
{
   string name = DASH_PREFIX + "BTN_" + id;
   int btn_x = 10 + 310;  // x_base + 310

   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, btn_x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, name, OBJPROP_TEXT, is_on ? "ON" : "OFF");
   ObjectSetInteger(0, name, OBJPROP_COLOR,      is_on ? C'220,255,220' : C'180,120,120');
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR,    is_on ? C'25,80,40' : C'70,25,25');
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, is_on ? C'40,120,60' : C'100,40,40');
   ObjectSetInteger(0, name, OBJPROP_STATE,      false);
   ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);  // mostra
}

//+------------------------------------------------------------------+
//|  BSTHideBtn — Nasconde un bottone toggle                          |
//+------------------------------------------------------------------+
void BSTHideBtn(string id)
{
   string name = DASH_PREFIX + "BTN_" + id;
   ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
}

//+------------------------------------------------------------------+
//|  BSTResizeBG — Ridimensiona sfondo al numero effettivo di righe   |
//+------------------------------------------------------------------+
void BSTResizeBG(int totalRows)
{
   int x_base = 10;
   int y_base = 20;
   int y_step = 16;
   int border_px = 3;
   int panel_width  = 370;
   int panel_height = y_base + (totalRows * y_step) + 8;
   int panel_x = x_base - 6;
   int panel_y = y_base - 6;

   string brd = DASH_PREFIX + "BORDER";
   ObjectSetInteger(0, brd, OBJPROP_XDISTANCE, panel_x - border_px);
   ObjectSetInteger(0, brd, OBJPROP_YDISTANCE, panel_y - border_px);
   ObjectSetInteger(0, brd, OBJPROP_XSIZE, panel_width + border_px * 2);
   ObjectSetInteger(0, brd, OBJPROP_YSIZE, panel_height + border_px * 2);

   string bg = DASH_PREFIX + "BG";
   ObjectSetInteger(0, bg, OBJPROP_XDISTANCE, panel_x);
   ObjectSetInteger(0, bg, OBJPROP_YDISTANCE, panel_y);
   ObjectSetInteger(0, bg, OBJPROP_XSIZE, panel_width);
   ObjectSetInteger(0, bg, OBJPROP_YSIZE, panel_height);
}

//+------------------------------------------------------------------+
//|  UpdateBSTDashboard — Aggiorna l'intera dashboard BST             |
//|  Pattern anti-flicker: SOLO ObjectSet*, ZERO delete/create.       |
//+------------------------------------------------------------------+
void UpdateBSTDashboard(bool forceUpdate = false)
{
   if(!InpShowDashboard)
   {
      if(g_dashCreated)
      {
         ObjectsDeleteAll(0, DASH_PREFIX);
         g_dashCreated = false;
      }
      return;
   }

   // Crea pool oggetti se non ancora fatto
   if(!g_dashCreated) InitBSTDashboard();

   // Throttle: aggiorna massimo 2 volte/sec per ridurre carico ObjectSet
   static uint s_lastDashMs = 0;
   if(!forceUpdate)
   {
      uint now = GetTickCount();
      if(now - s_lastDashMs < 500)
         return;
      s_lastDashMs = now;
   }
   else
      s_lastDashMs = GetTickCount();

   int row = 0;
   int y_base = 20;
   int y_step = 16;
   string sep_line = "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━";

   // --- Titolo ---
   BSTSetRow(row++, "BussolaST v2.07  |  " + _Symbol + "  |  " +
             EnumToString((ENUM_TIMEFRAMES)ChartPeriod()),
             C'70,180,255', 12);
   BSTSetRow(row++, sep_line, C'35,55,85', 8);

   // --- Direzione corrente ---
   string dir_txt;
   color  dir_clr;
   if(g_stSlowDir == 1)       { dir_txt = "DIREZIONE: BULL ▲"; dir_clr = C'50,255,100'; }
   else if(g_stSlowDir == -1) { dir_txt = "DIREZIONE: BEAR ▼"; dir_clr = C'255,70,70'; }
   else                       { dir_txt = "DIREZIONE: ---";     dir_clr = C'120,135,160'; }
   BSTSetRow(row++, dir_txt, dir_clr, 9);
   BSTSetRow(row++, sep_line, C'35,55,85', 8);

   // --- ST Lento ---
   color stsl_clr = !InpSTSlowEnable ? C'70,70,85' : (g_vis_stSlow ? C'70,130,255' : C'50,70,120');
   string stsl_st = !InpSTSlowEnable ? "○ DISAB" : (g_vis_stSlow ? "● ON" : "○ OFF");
   BSTSetRow(row, "◈ ST LENTO   " + stsl_st, stsl_clr, 8);
   if(InpSTSlowEnable) BSTSetBtn("STSLOW", g_vis_stSlow, y_base + row * y_step);
   else                BSTHideBtn("STSLOW");
   row++;
   if(InpSTSlowEnable)
   {
      string sl_dir = (g_stSlowDir == 1) ? "BULL" : (g_stSlowDir == -1) ? "BEAR" : "---";
      color  sl_clr = (g_stSlowDir == 1) ? C'50,220,120' : (g_stSlowDir == -1) ? C'255,90,80' : C'150,165,185';
      string sl_ma  = (InpSTSlowMAType == BST_MA_SLOW_KAMA) ? "KAMA" : "HMA";
      BSTSetRow(row++, "  Stato: " + sl_dir + "  |  MA: " + sl_ma +
                "  P:" + IntegerToString(g_stSlowPeriod_eff) +
                "  M:" + DoubleToString(g_stSlowMult_eff, 1), sl_clr, 8);
   }

   // --- ST Veloce ---
   color stf_clr = !InpSTFastEnable ? C'70,70,85' : (g_vis_stFast ? C'100,255,100' : C'50,120,50');
   string stf_st = !InpSTFastEnable ? "○ DISAB" : (g_vis_stFast ? "● ON" : "○ OFF");
   BSTSetRow(row, "◈ ST VELOCE  " + stf_st, stf_clr, 8);
   if(InpSTFastEnable) BSTSetBtn("STFAST", g_vis_stFast, y_base + row * y_step);
   else                BSTHideBtn("STFAST");
   row++;
   if(InpSTFastEnable)
   {
      string sf_dir = (g_stFastDir == 1) ? "BULL" : (g_stFastDir == -1) ? "BEAR" : "---";
      color  sf_clr = (g_stFastDir == 1) ? C'50,220,120' : (g_stFastDir == -1) ? C'255,90,80' : C'150,165,185';
      string sf_ma  = (InpSTFastMAType == BST_MA_FAST_HMA) ? "HMA" : "EMA";
      BSTSetRow(row++, "  Stato: " + sf_dir + "  |  MA: " + sf_ma +
                "  P:" + IntegerToString(g_stFastPeriod_eff) +
                "  M:" + DoubleToString(g_stFastMult_eff, 1), sf_clr, 8);
   }

   // --- Keltner ---
   color kl_clr = !InpKeltnerEnable ? C'70,70,85' : (g_vis_keltner ? C'255,165,0' : C'150,100,30');
   string kl_st = !InpKeltnerEnable ? "○ DISAB" : (g_vis_keltner ? "● ON" : "○ OFF");
   BSTSetRow(row, "◈ KELTNER    " + kl_st, kl_clr, 8);
   if(InpKeltnerEnable) BSTSetBtn("KELT", g_vis_keltner, y_base + row * y_step);
   else                 BSTHideBtn("KELT");
   row++;
   if(InpKeltnerEnable)
      BSTSetRow(row++, "  EMA:" + IntegerToString(g_keltnerEMA_eff) +
                "  ATRx" + DoubleToString(g_keltnerMult_eff, 1) +
                "  W:" + IntegerToString(InpKeltnerWidth), C'210,140,0', 8);

   // --- Donchian ---
   color dc_clr = !InpDonchianEnable ? C'70,70,85' : (g_vis_donchian ? C'80,140,255' : C'50,70,120');
   string dc_st = !InpDonchianEnable ? "○ DISAB" : (g_vis_donchian ? "● ON" : "○ OFF");
   BSTSetRow(row, "◈ DONCHIAN   " + dc_st, dc_clr, 8);
   if(InpDonchianEnable) BSTSetBtn("DON", g_vis_donchian, y_base + row * y_step);
   else                  BSTHideBtn("DON");
   row++;
   if(InpDonchianEnable)
      BSTSetRow(row++, "  Period: " + IntegerToString(g_dcLen_eff), C'120,170,240', 8);

   // --- Choppiness Index ---
   color ci_clr = !InpCIEnable ? C'70,70,85' : (g_vis_ci ? C'255,220,80' : C'150,130,60');
   string ci_st = !InpCIEnable ? "○ DISAB" : (g_vis_ci ? "● ON" : "○ OFF");
   BSTSetRow(row, "◈ ER (Effic.) " + ci_st, ci_clr, 8);
   if(InpCIEnable) BSTSetBtn("CI", g_vis_ci, y_base + row * y_step);
   else            BSTHideBtn("CI");
   row++;
   if(InpCIEnable)
   {
      double er_val = BufCI[1];  // ER*100: 0=ranging, 100=trend (v1.20)
      string er_regime;
      color  er_val_clr;
      if(er_val > 60.0)       { er_regime = "FORTE";    er_val_clr = C'50,255,100'; }
      else if(er_val > 40.0)  { er_regime = "TREND";    er_val_clr = C'50,220,120'; }
      else if(er_val > 25.0)  { er_regime = "NEUTRO";   er_val_clr = C'255,220,80'; }
      else if(er_val > 15.0)  { er_regime = "RANGING";  er_val_clr = C'255,160,60'; }
      else                    { er_regime = "CHOPPY";   er_val_clr = C'255,70,70'; }
      BSTSetRow(row++, "  ER: " + DoubleToString(er_val, 1) + "  " + er_regime +
                "  (P:" + IntegerToString(g_ciPeriod_eff) + ")", er_val_clr, 8);
   }

   // --- Fisher Transform ---
   color fi_clr = !InpFisherEnable ? C'70,70,85' : (g_vis_fisher ? C'200,100,255' : C'120,60,150');
   string fi_st = !InpFisherEnable ? "○ DISAB" : (g_vis_fisher ? "● ON" : "○ OFF");
   BSTSetRow(row, "◈ FISHER     " + fi_st, fi_clr, 8);
   if(InpFisherEnable) BSTSetBtn("FISHER", g_vis_fisher, y_base + row * y_step);
   else                BSTHideBtn("FISHER");
   row++;
   if(InpFisherEnable)
   {
      double fish_val = BufFisher[1];
      double fish_sig = BufFisherSig[1];
      string fish_dir = (fish_val > fish_sig) ? "▲ BULL" : "▼ BEAR";
      color  fish_clr = (fish_val > fish_sig) ? C'50,220,120' : C'255,90,80';
      bool   fish_peak = (fish_val > InpFisherPeakThreshold) || (fish_val < -InpFisherPeakThreshold);
      if(fish_peak) { fish_dir += " ★PICCO"; fish_clr = C'255,220,80'; }
      BSTSetRow(row++, "  F: " + DoubleToString(fish_val, 3) +
                "  S: " + DoubleToString(fish_sig, 3) + "  " + fish_dir, fish_clr, 8);
   }

   //--- FIX-C (v2.06): sezione dashboard per MTF SuperTrend.
   //    Prima di questo fix, il SuperTrend MTF (plots 15-16) poteva essere
   //    abilitato/disabilitato solo tramite InpMTF_Enable (parametro input,
   //    richiede ricarica dell'indicatore). Ora ha un bottone toggle nella
   //    dashboard come tutti gli altri componenti (ST Lento, ST Veloce, ecc.).
   //    Mostra: stato ON/OFF, TF superiore usato, direzione corrente, e se
   //    il gate entry e' attivo. Il bottone e' visibile solo se InpMTF_Enable=true.
   //    NOTA: il toggle nasconde solo le linee grafiche (DRAW_NONE su plots 15-16),
   //    il calcolo interno (BufMTFDir per gate entry) resta sempre attivo.
   if(InpMTF_Enable)
   {
      color mtf_clr = g_vis_mtf ? C'0,120,200' : C'40,70,110';
      string mtf_st = g_vis_mtf ? "● ON" : "○ OFF";
      BSTSetRow(row, "◈ MTF ST     " + mtf_st, mtf_clr, 8);
      BSTSetBtn("MTF", g_vis_mtf, y_base + row * y_step);
      row++;
      string mtf_dir = (BufMTFDir[1] > 0.5) ? "BULL" : (BufMTFDir[1] < -0.5) ? "BEAR" : "---";
      color  mtf_d_clr = (BufMTFDir[1] > 0.5) ? C'50,220,120' : (BufMTFDir[1] < -0.5) ? C'255,90,80' : C'150,165,185';
      BSTSetRow(row++, "  TF:" + EnumToString(InpMTF_TF) + "  Dir:" + mtf_dir +
                (InpMTF_GateEntry ? "  GATE" : ""), mtf_d_clr, 8);
   }
   else
      BSTHideBtn("MTF");

   BSTSetRow(row++, sep_line, C'35,55,85', 8);

   // --- Regime Status (basato su CI) ---
   if(InpCIEnable)
   {
      double er_now = BufCI[1];  // ER*100 (v1.20)
      string regime_txt;
      color  regime_clr;
      if(er_now > 60.0)       { regime_txt = "REGIME: STRONG TREND ▲▲";   regime_clr = C'50,255,100'; }
      else if(er_now > 40.0)  { regime_txt = "REGIME: TRENDING ▲";        regime_clr = C'50,220,120'; }
      else if(er_now > 25.0)  { regime_txt = "REGIME: TRANSITION ↔";      regime_clr = C'255,220,80'; }
      else if(er_now > 15.0)  { regime_txt = "REGIME: RANGING ↔";         regime_clr = C'255,160,60'; }
      else                    { regime_txt = "REGIME: CHOPPY / LATERAL ↔"; regime_clr = C'255,70,70'; }
      BSTSetRow(row++, regime_txt, regime_clr, 9);
   }

   // --- Ultimo segnale ---
   string last_entry = "---";
   color  last_e_clr = C'120,135,160';
   if(BufSignalEntry[1] == 1.0)       { last_entry = "BUY ▲";  last_e_clr = C'50,255,100'; }
   else if(BufSignalEntry[1] == -1.0) { last_entry = "SELL ▼"; last_e_clr = C'255,70,70'; }

   string last_exit = "---";
   color  last_x_clr = C'120,135,160';
   if(BufSignalExit[1] == 1.0)       { last_exit = "EXIT LONG ★";  last_x_clr = C'255,220,80'; }
   else if(BufSignalExit[1] == -1.0) { last_exit = "EXIT SHORT ★"; last_x_clr = C'255,160,60'; }

   BSTSetRow(row++, "  Entry: " + last_entry, last_e_clr, 8);
   BSTSetRow(row++, "  Exit:  " + last_exit,  last_x_clr, 8);
   BSTSetRow(row++, sep_line, C'35,55,85', 8);

   // --- Legenda Colori ---
   BSTSetRow(row++, "LEGENDA COLORI", C'140,165,200', 8);
   BSTSetRow(row++, "  ■ ST Lento Bull    DodgerBlue", clrDodgerBlue, 8);
   BSTSetRow(row++, "  ■ ST Lento Bear    OrangeRed", clrOrangeRed, 8);
   BSTSetRow(row++, "  ■ ST Veloce Bull   Lime", clrLime, 8);
   BSTSetRow(row++, "  ■ ST Veloce Bear   Red", clrRed, 8);
   BSTSetRow(row++, "  ■ Keltner          Arancione", C'255,165,0', 8);
   BSTSetRow(row++, "  ■ Donchian         Blu", clrBlue, 8);
   BSTSetRow(row++, "  ■ Fisher Band      Verde/Arancione", C'200,100,255', 8);
   if(InpMTF_Enable)  // FIX-C (v2.06): legenda colori MTF SuperTrend
      BSTSetRow(row++, "  ■ MTF ST           Blu/Arancio scuro", C'0,120,200', 8);

   // --- Diagnostica Canvas Fill (visibile nella dashboard) ---
   //     Mostra se il fill funziona e quanto copre del grafico.
   //     Utile per debug: se fillH% > 90% il fill sta coprendo tutto.
   if(InpShowDCFill && InpDonchianEnable && g_canvasCreated)
   {
      int dChartH = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS, 0);
      double dPrcMax = ChartGetDouble(0, CHART_PRICE_MAX, 0);
      double dPrcMin = ChartGetDouble(0, CHART_PRICE_MIN, 0);
      double dRange  = dPrcMax - dPrcMin;
      // Calcola altezza fill in pixel per bar[1] (barra corrente completata)
      int dFillH = 0;
      double dFillPct = 0;
      string dStatus = "---";
      if(dRange > 0 && ArraySize(BufDonchianUp) > 1 &&
         BufDonchianUp[1] != EMPTY_VALUE && BufDonchianLow[1] != EMPTY_VALUE)
      {
         int yTop = (int)MathRound((double)dChartH * (dPrcMax - BufDonchianUp[1])  / dRange);
         int yBot = (int)MathRound((double)dChartH * (dPrcMax - BufDonchianLow[1]) / dRange);
         yTop = MathMax(0, MathMin(dChartH - 1, yTop));
         yBot = MathMax(0, MathMin(dChartH - 1, yBot));
         dFillH = yBot - yTop;
         dFillPct = (dChartH > 0) ? (100.0 * dFillH / dChartH) : 0;
         if(dFillPct > 90.0)      dStatus = "WARN >90%!";
         else if(dFillPct < 1.0)  dStatus = "tiny";
         else                     dStatus = "OK";
      }
      BSTSetRow(row++, sep_line, C'35,55,85', 8);
      BSTSetRow(row++, "CANVAS FILL DIAG", C'140,165,200', 8);
      BSTSetRow(row++, "  Fill: " + IntegerToString(dFillH) + "px / " +
                IntegerToString(dChartH) + "px = " +
                DoubleToString(dFillPct, 1) + "%  [" + dStatus + "]",
                (dFillPct > 90.0) ? C'255,80,80' : C'100,200,130', 8);
      BSTSetRow(row++, "  DC[1]: " + DoubleToString(BufDonchianUp[1], (int)_Digits) +
                " / " + DoubleToString(BufDonchianLow[1], (int)_Digits),
                C'120,170,240', 8);
      BSTSetRow(row++, "  Range: " + DoubleToString(dPrcMin, (int)_Digits) +
                " - " + DoubleToString(dPrcMax, (int)_Digits),
                C'120,170,240', 8);
   }

   // --- Nascondi righe non usate ---
   for(int r = row; r < g_dashLastRowUsed; r++)
   {
      string name = DASH_PREFIX + "R" + StringFormat("%02d", r);
      ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
   }
   g_dashLastRowUsed = row;

   // --- Ridimensiona sfondo ---
   BSTResizeBG(row);
}

// ═══════════════════════════════════════════════════════════════════
// OnChartEvent — Ridisegna canvas su scroll/zoom/resize
// ═══════════════════════════════════════════════════════════════════
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   if(id == CHARTEVENT_CHART_CHANGE)
   {
      RedrawCanvas(true);   // forceRedraw: scroll/zoom devono aggiornare subito
      ChartRedraw();
   }

   //--- Toggle dashboard buttons
   if(id == CHARTEVENT_OBJECT_CLICK)
   {
      string btn_prefix = DASH_PREFIX + "BTN_";
      if(StringFind(sparam, btn_prefix) == 0)
      {
         string btn_id = StringSubstr(sparam, StringLen(btn_prefix));
         if(btn_id == "STSLOW")   g_vis_stSlow   = !g_vis_stSlow;
         if(btn_id == "STFAST")   g_vis_stFast   = !g_vis_stFast;
         if(btn_id == "KELT")     g_vis_keltner  = !g_vis_keltner;
         if(btn_id == "DON")      g_vis_donchian = !g_vis_donchian;
         if(btn_id == "CI")       g_vis_ci       = !g_vis_ci;
         if(btn_id == "FISHER")   g_vis_fisher   = !g_vis_fisher;
         if(btn_id == "MTF")      g_vis_mtf      = !g_vis_mtf;   // FIX-C (v2.06)

         // Aggiorna visibilita' plot in base ai toggle
         PlotIndexSetInteger(0, PLOT_DRAW_TYPE, g_vis_stSlow ? DRAW_LINE : DRAW_NONE);
         PlotIndexSetInteger(1, PLOT_DRAW_TYPE, g_vis_stSlow ? DRAW_LINE : DRAW_NONE);
         PlotIndexSetInteger(2, PLOT_DRAW_TYPE, g_vis_stFast ? DRAW_LINE : DRAW_NONE);
         PlotIndexSetInteger(3, PLOT_DRAW_TYPE, g_vis_stFast ? DRAW_LINE : DRAW_NONE);
         PlotIndexSetInteger(4, PLOT_DRAW_TYPE, g_vis_keltner ? DRAW_LINE : DRAW_NONE);
         PlotIndexSetInteger(5, PLOT_DRAW_TYPE, g_vis_keltner ? DRAW_LINE : DRAW_NONE);
         PlotIndexSetInteger(6, PLOT_DRAW_TYPE, (g_vis_keltner && InpKeltnerShowMid) ? DRAW_LINE : DRAW_NONE);
         PlotIndexSetInteger(7, PLOT_DRAW_TYPE, g_vis_donchian ? DRAW_LINE : DRAW_NONE);
         PlotIndexSetInteger(8, PLOT_DRAW_TYPE, g_vis_donchian ? DRAW_LINE : DRAW_NONE);
         PlotIndexSetInteger(9, PLOT_DRAW_TYPE, (g_vis_donchian && InpDonShowMid) ? DRAW_COLOR_LINE : DRAW_NONE);
         PlotIndexSetInteger(14, PLOT_DRAW_TYPE, (g_vis_fisher && InpShowFisherBand) ? DRAW_COLOR_LINE : DRAW_NONE);

         //--- FIX-C (v2.06): toggle visibilita' MTF SuperTrend (plots 15-16).
         //    Nasconde/mostra le linee MTF senza toccare il calcolo interno:
         //    BufMTFDir[] continua ad essere calcolato per il gate entry
         //    anche quando le linee sono nascoste graficamente.
         if(InpMTF_Enable)
         {
            PlotIndexSetInteger(15, PLOT_DRAW_TYPE, g_vis_mtf ? DRAW_LINE : DRAW_NONE);
            PlotIndexSetInteger(16, PLOT_DRAW_TYPE, g_vis_mtf ? DRAW_LINE : DRAW_NONE);
         }

         //--- FIX-B (v2.06): il handler originale non chiamava RedrawCanvas()
         //    dopo il toggle DON. Risultato: anche se g_vis_donchian cambiava,
         //    il canvas bitmap (CCanvas) restava invariato fino al prossimo
         //    CHARTEVENT_CHART_CHANGE (scroll/zoom). Con questo fix il canvas
         //    si aggiorna immediatamente al click del bottone DON.
         //    forceRedraw=true bypassa il throttle di 200ms per risposta istantanea.
         RedrawCanvas(true);
         UpdateBSTDashboard(true);   // forceUpdate per risposta immediata al click
         ChartRedraw();
      }
   }
}
//+------------------------------------------------------------------+
