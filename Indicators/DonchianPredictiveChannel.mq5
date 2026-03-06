//+------------------------------------------------------------------+
//| DonchianPredictiveChannel.mq5                                    |
//| Donchian Predictive Channel - MQ5 Port                           |
//| Original Pine Script v6 by Zeiierman (CC BY-NC-SA 4.0)           |
//| MQ5 Port by TIVANIO                                              |
//+------------------------------------------------------------------+
#property copyright   "TIVANIO - Donchian Predictive Channel (MQ5 Port)"
#property version     "7.18"   // v7.18 — Auto-detect iCustom sub-indicator mode, disable visual output to prevent object collision
#property description "Donchian Predictive Channel con proiezione forecast e segnali BUY/SELL"
#property description "Basato sull'indicatore Pine Script v6 di Zeiierman"
#property description "Portato su MQ5 da TIVANIO"
#property description "Per il Donchian Multi-Timeframe: usare DonchianChannelMTF.mq5"
#property indicator_chart_window
#property indicator_buffers 19
#property indicator_plots   11

//--- Plot 0: Midline (color-switching lime/red)
#property indicator_label1  "Midline"
#property indicator_type1   DRAW_COLOR_LINE
#property indicator_color1  clrLime,clrRed
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- Plot 1: MidOffset (invisible)
#property indicator_label2  "MidOffset"
#property indicator_type2   DRAW_NONE
#property indicator_color2  clrNONE

//--- Plot 2: Upper Donchian
#property indicator_label3  "Upper DC"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrBlue
#property indicator_style3  STYLE_SOLID
#property indicator_width3  1

//--- Plot 3: Lower Donchian
#property indicator_label4  "Lower DC"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrBlue
#property indicator_style4  STYLE_SOLID
#property indicator_width4  1

//--- Plot 4: Fill between Upper and Lower
#property indicator_label5  "DC Fill"
#property indicator_type5   DRAW_NONE
#property indicator_color5  clrBlue,clrBlue

//--- Plot 5: Moving Average (optional)
#property indicator_label6  "Signal MA"
#property indicator_type6   DRAW_LINE
#property indicator_color6  clrTeal
#property indicator_style6  STYLE_SOLID
#property indicator_width6  2

//--- Plot 6-7: DRAW_ARROW per frecce segnale (rendering garantito via buffer)
//    v7.11: Le frecce buffer sono SEMPRE visibili (parte dei dati indicatore).
//    OBJ_ARROW sovrapposti forniscono tooltip e label "TRIGGER BUY/SELL".
#property indicator_label7  "Signal Up"
#property indicator_type7   DRAW_ARROW
#property indicator_color7  clrLime
#property indicator_width7  3
#property indicator_label8  "Signal Down"
#property indicator_type8   DRAW_ARROW
#property indicator_color8  clrRed
#property indicator_width8  3

//--- Plot 8-9: Glow (DRAW_NONE — non usati, valori mantenuti per compatibilità buffer)
#property indicator_label9  "Signal Up Big"
#property indicator_type9   DRAW_NONE
#property indicator_label10 "Signal Down Big"
#property indicator_type10  DRAW_NONE

//--- Plot 10: Candele chart con evidenziazione trigger (DRAW_COLOR_CANDLES)
//    Ultimo plot → disegnato sopra bands/fill/MA. Con CHART_FOREGROUND=false,
//    le candele dell'indicatore sono davanti alle candele chart native.
//    3 colori: 0=bull (tema), 1=bear (tema), 2=trigger (giallo)
#property indicator_label11  "Candles"
#property indicator_type11   DRAW_COLOR_CANDLES
#property indicator_color11  C'38,166,154',C'239,83,80',clrYellow
#property indicator_style11  STYLE_SOLID
#property indicator_width11  1

//+------------------------------------------------------------------+
//| Includes                                                         |
//+------------------------------------------------------------------+
#include <Canvas/Canvas.mqh>

//+------------------------------------------------------------------+
//| ARCHITETTURA INDICATORE — Guida alla Manutenzione                |
//+------------------------------------------------------------------+
//
// ┌─────────────────────────────────────────────────────────────────┐
// │                   MAPPA DEI 19 BUFFER (v7.13)                 │
// ├─────────┬──────────────────────────────────────────────────────┤
// │ Buffer  │ Contenuto                                            │
// ├─────────┼──────────────────────────────────────────────────────┤
// │  0 (P0) │ BufMid          — Midline Donchian (color-switching)│
// │  1 (P0) │ BufMidColor     — Indice colore Midline (0=up 1=dn)│
// │  2 (P1) │ BufMidOffset    — Midline 2 barre fa (per fill)    │
// │  3 (P2) │ BufUpper        — Banda superiore Donchian         │
// │  4 (P3) │ BufLower        — Banda inferiore Donchian         │
// │  5 (P4) │ BufFillUp       — Fill canale (=Upper, DRAW_NONE)  │
// │  6 (P5) │ BufMA           — Media Mobile filtro (opzionale)  │
// │  7 (P6) │ BufSignalUp     — Freccia BUY ⬆ (DRAW_ARROW v7.11)│
// │  8 (P7) │ BufSignalDn     — Freccia SELL ⬇ (DRAW_ARROW)    │
// │  9 (P8) │ BufSignalUpBig  — Freccia BUY glow (DRAW_NONE)    │
// │ 10 (P9) │ BufSignalDnBig  — Freccia SELL glow (DRAW_NONE)   │
// │ 11(P10) │ BufCandleO      — OHLC Open  (DRAW_COLOR_CANDLES) │
// │ 12(P10) │ BufCandleH      — OHLC High                       │
// │ 13(P10) │ BufCandleL      — OHLC Low                        │
// │ 14(P10) │ BufCandleC      — OHLC Close                      │
// │ 15(P10) │ BufCandleColor  — Colore (0=bull 1=bear 2=trigger)│
// │ 16      │ BufFillDn       — Fill canale (CALCULATIONS)       │
// │ 17      │ BufATR          — ATR(14) interno (CALCULATIONS)   │
// │ 18      │ BufTouchTrigger — Touch Trigger EA (CALCULATIONS)  │
// │         │                   +1=BUY, -1=SELL, 0=nessuno       │
// └─────────┴──────────────────────────────────────────────────────┘
// P0-P9 = Plot 0-9. Plot 6-7 = DRAW_ARROW (frecce segnale, sempre visibili).
// Plot 8-9 = DRAW_NONE (glow). OBJ_ARROW overlay per tooltip e label.
// P10 = DRAW_COLOR_CANDLES: disegna tutte le candele con colori dal tema.
//   Le candele trigger vengono colorate con color index 2 (giallo).
//   CHART_FOREGROUND=false → Plot 10 (ultimo) è SOPRA bands/fill/MA.
// Il fill trasparente del canale è gestito da CCanvas (non DRAW_FILLING,
// che non supporta trasparenza ARGB in MQL5).
//
// NOTA v7.08: Il Donchian Multi-Timeframe è stato RIMOSSO da questo indicatore
// e spostato in un indicatore separato: DonchianChannelMTF.mq5
// Motivo: l'MTF interno usava un'approssimazione (moltiplicatore barre) mentre
// il nuovo indicatore separato usa dati HTF reali (iHighest/iLowest).
// I 4 buffer rimossi (14-17: BufHTFUpper, BufHTFLower, BufHTFMid, BufSignalQuality)
// e il sistema di grading A-Grade/B-Grade non esistono più in questo file.
// Per il Donchian HTF, usare DonchianChannelMTF.mq5 come indicatore aggiuntivo.
//
// ┌─────────────────────────────────────────────────────────────────┐
// │               FLUSSO OnCalculate (7 Sezioni)                   │
// ├─────────────────────────────────────────────────────────────────┤
// │ 1. Donchian Channel     — Upper, Lower, Mid, MidOffset, Fill  │
// │ 2. Midline Color        — 0=lime (up) o 1=red (down)          │
// │ 3. Moving Average       — SMA/EMA/WMA/HMA per filtro segnali  │
// │ 4. ATR EMA(200)         — Offset frecce (g_emaATR)            │
// │ 4.5 SmartCooldown Check — Tocco midline + TP Dot              │
// │ 4.6 TP Target Line      — Detection tocco livello TP fisso    │
// │ 5. Signal Detection     — bearBase/bullBase → bearCond/bullCond│
// │    5a. Fix #1 Reset     — Anti-duplicato Touch Trigger         │
// │    5b. Touch Trigger    — Buffer 18 per EA (solo FIRST_CANDLE)│
// │ 6. Forecast Projection  — Linee proiezione (solo bar 0)       │
// │ 7. Canvas Redraw        — Fill trasparenti CCanvas             │
// └─────────────────────────────────────────────────────────────────┘
//
// ┌─────────────────────────────────────────────────────────────────┐
// │          MODALITÀ TRIGGER: FIRST_CANDLE (v7.13)                │
// ├─────────────────────────────────────────────────────────────────┤
// │                                                                 │
// │ v7.13: CLASSIC mode rimosso (codice commentato in Section 5).  │
// │   Il CLASSIC usava: rejection + close>midline alla chiusura.   │
// │   Non compatibile con EA che legge Buffer 18 in tempo reale.   │
// │                                                                 │
// │ FIRST_CANDLE (unica modalità):                                 │
// │   - Segnale IMMEDIATO al TOCCO della banda Donchian            │
// │   - bearBase = high[i] >= BufUpper[i] (tocco diretto)          │
// │   - Filtri: Cooldown (MA e close<mid delegati all'EA)          │
// │   - EA legge: Buffer 18 ad ogni tick (+1 BUY, -1 SELL)        │
// │   - EA conferma: BufSignalUp[1]/BufSignalDn[1] alla chiusura  │
// │                                                                 │
// │ GUARDIE FIRST_CANDLE (3 Fix):                                   │
// │   Fix #1: Reset g_lastTouchDirection su nuova barra             │
// │   Fix #2: Stato (g_lastMarkerBar etc.) NON aggiornato per i=0  │
// │           → si aggiorna quando la barra chiude (i=1)           │
// │   Fix #3: Anti-ambiguità se entrambe le bande toccate → skip   │
// │                                                                 │
// │ GUARDIA TP/ENTRY (anti-duplicazione tick):                      │
// │   bearCond/bullCond si attiva ad OGNI tick per i=0              │
// │   (Fix #2 impedisce il blocco cooldown).                        │
// │   → TP Target, Entry Dot e TP tracking vars sono creati SOLO   │
// │     quando la barra chiude (i>0), evitando accumulo oggetti.   │
// │   → La freccia è creata ogni tick (ObjectCreate sovrascrive).  │
// └─────────────────────────────────────────────────────────────────┘
//

//+------------------------------------------------------------------+
//| Enums                                                            |
//+------------------------------------------------------------------+
enum ENUM_MA_TYPE
{
   MA_SMA = 0,  // SMA
   MA_EMA = 1,  // EMA
   MA_WMA = 2,  // WMA
   MA_HMA = 3   // HMA
};

//--- v7.13: CLASSIC rimosso. Enum mantenuto per const InpTriggerMode.
enum ENUM_TRIGGER_MODE
{
   TRIGGER_CLASSIC      = 0,  // Classico (v7.13: RIMOSSO — codice commentato in Section 5)
   TRIGGER_FIRST_CANDLE = 1   // Prima Candela (unica modalità attiva)
};

enum ENUM_MA_FILTER_MODE
{
   MA_FILTER_CLASSIC  = 0,  // Classico (BUY se close > MA — trend following)
   MA_FILTER_INVERTED = 1   // Invertito (BUY se close < MA — mean reversion Soup)
};



//+------------------------------------------------------------------+
//| Inputs                                                           |
//+------------------------------------------------------------------+

//═══════════════════════════════════════════════════════════════════
//  SEZIONE 1: DONCHIAN PREDICTIVE CHANNEL
//═══════════════════════════════════════════════════════════════════
input group "                                                               "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  📊 DONCHIAN PREDICTIVE CHANNEL                          ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input int             InpLenDC          = 20;          // Periodo Donchian (alto=meno segnali, basso=più reattivo)
input int             InpProjLen        = 30;          // Barre Proiezione (alto=cono ampio, basso=breve termine)

//═══════════════════════════════════════════════════════════════════
//  SEZIONE 2: FILTRO SEGNALI (Media Mobile direzionale)
//═══════════════════════════════════════════════════════════════════
input group "                                                               "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  📈 MEDIA MOBILE (visiva + configurazione EA)             ║"
input group "╚═══════════════════════════════════════════════════════════╝"
//    L'indicatore DISEGNA la MA sul chart ma NON filtra i propri segnali.
//    L'EA legge questi valori e applica il filtro alla chiusura barra.

input bool            InpSignalFilter   = true;        // Filtra Segnali con MA (solo EA)
// ↑ L'indicatore NON usa questo filtro (if(false) a riga ~2535).
// ↑ L'EA legge questo input e applica il filtro alla conferma (chiusura barra).
// ↑ ON = l'EA filtra BUY/SELL con la MA. OFF = l'EA accetta tutti i segnali.

input ENUM_MA_FILTER_MODE InpMAFilterMode = MA_FILTER_INVERTED;  // Modalità Filtro MA
// ↑ CLASSICO (trend-following): BUY solo se close > MA, SELL solo se close < MA.
//   Logica originale Zeiierman. Funziona per trend-following, ma BLOCCA i segnali Soup migliori.
// ↑ INVERTITO (mean-reversion/Soup): BUY solo se close < MA, SELL solo se close > MA.
//   ★ RACCOMANDATO per Turtle Soup.
//   Logica: se il prezzo è OVEREXTENDED rispetto alla MA, è maturo per un ritorno al centro.
// ↑ NOTA: in FIRST_CANDLE mode questo parametro non ha effetto (MA filter skippato).

input ENUM_MA_TYPE    InpMAType         = MA_HMA;      // Tipo Media Mobile
// ↑ ══ GUIDA AI 4 TIPI DI MEDIA MOBILE ══
// ↑ SMA (Simple): Media aritmetica semplice. Ogni barra pesa uguale.
// ↑   PRO: stabile, pochi falsi segnali. CONTRO: molto lenta, blocca rimbalzi forti.
// ↑   USO: trend-following puro su timeframe alti (H4/Daily). NON ideale per Soup intraday.
// ↑
// ↑ EMA (Exponential): Pesa di più i dati recenti (decadimento esponenziale).
// ↑   PRO: più reattiva della SMA, buon compromesso. CONTRO: ancora lenta su inversioni veloci.
// ↑   USO: buona scelta conservativa per intraday. Fallback se HMA genera troppi segnali.
// ↑
// ↑ WMA (Weighted): Ponderazione lineare (barra recente=peso N, vecchia=peso 1).
// ↑   PRO: leggermente più reattiva della SMA. CONTRO: nessun vantaggio chiaro vs EMA.
// ↑   USO: alternativa all'EMA, differenze pratiche minime.
// ↑
// ↑ HMA (Hull): Formula speciale che elimina quasi tutto il lag.
// ↑   HMA(N) = WMA(√N) di [2×WMA(N/2) − WMA(N)]
// ↑   PRO: reattività quasi istantanea (3-5 barre), ideale per segnali di inversione Soup.
// ↑   CONTRO: può generare qualche segnale in più.
// ↑   USO: ★ RACCOMANDATO per trading Soup intraday M5/M15/M30.
// ↑
// ↑ ★ RACCOMANDAZIONE: HMA per Turtle Soup intraday, EMA come alternativa conservativa.

input int             InpMALen          = 30;          // Periodo MA
// ↑ ══ PERIODI RACCOMANDATI PER TIMEFRAME ══
// ↑
// ↑ ── M5 ──
// ↑ EURUSD:  HMA 50 (copre ~4h, canale tipico 25-40 pips, lag ~20min)
// ↑ GBPUSD:  HMA 40 (copre ~3.3h, coppia più volatile, serve MA meno reattiva)
// ↑          oppure HMA 50 se si vogliono meno segnali (più conservativo)
// ↑ USDCAD:  HMA 50 (simile a EURUSD, volatilità media)
// ↑ AUDNZD:  HMA 50 (bassa volatilità, canale stretto ~15-25 pips)
// ↑ US500:   HMA 34 (indici più veloci, sessione concentrata in 6.5h)
// ↑ US100:   HMA 34 (come US500)
// ↑
// ↑ ── M15 ──
// ↑ EURUSD:  HMA 34 (copre ~8.5h = una sessione)
// ↑ GBPUSD:  HMA 30 (copre ~7.5h, più reattiva per la volatilità GBP)
// ↑ Indici:  HMA 24 (copre ~6h = sessione cash)
// ↑
// ↑ ── M30 ──
// ↑ Forex:   HMA 24 (copre ~12h = mezza giornata)
// ↑ Indici:  HMA 16 (copre ~8h = sessione estesa)
// ↑
// ↑ PRINCIPIO GENERALE:
// ↑ La MA deve coprire circa MEZZA SESSIONE di trading del mercato specifico.
// ↑ Coppie più volatili (GBPUSD, indici) → periodo leggermente PIÙ BASSO
// ↑ Coppie meno volatili (AUDNZD, EURUSD) → periodo standard o PIÙ ALTO
// ↑ In caso di dubbio: usa 50 su M5, 34 su M15, 24 su M30.

//═══════════════════════════════════════════════════════════════════
//  SEZIONE 2B: MODO SUB-INDICATORE (uso interno EA via iCustom)
//═══════════════════════════════════════════════════════════════════
input bool            InpSubIndicatorMode = false;     // Sub-Indicator Mode (EA internal — disabilita oggetti grafici)
// ↑ v7.18: Quando TRUE, l'indicatore calcola SOLO i buffer (segnali, bande, ATR)
//   senza creare oggetti grafici (frecce, TP lines, forecast, canvas, tema chart).
//   Usato dall'EA per evitare collisioni con l'istanza visiva a grafico.
//   L'utente NON deve mai attivare questo manualmente.

//═══════════════════════════════════════════════════════════════════
//  SEZIONE 3: FILTRO SEGNALI AVANZATO (SmartCooldown + Detection)
//═══════════════════════════════════════════════════════════════════
input group "                                                               "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  ⚡ FILTRO SEGNALI AVANZATO (SmartCooldown)              ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    🔄 SMARTCOOLDOWN"
input bool            InpUseSmartCooldown = true;      // Abilita SmartCooldown (OFF=cooldown originale Zeiierman)
// ↑ TRUE = logica intelligente: distingue segnale stesso verso da segnale opposto,
//   richiede tocco midline per confermare completamento ciclo precedente.
//   Raccomandato per intraday M5/M15 dove il cooldown fisso di 20 barre è troppo lungo.
// ↑ FALSE = cooldown ORIGINALE Zeiierman: blocco fisso di LenDC barre (default 20) dopo ogni segnale.

input group "    🎯 STESSO VERSO (es. BUY dopo BUY)"
input bool            InpRequireMidTouch  = true;      // Stesso Verso: Richiedi Tocco Midline
// ↑ TRUE = prima di accettare un nuovo segnale NELLA STESSA DIREZIONE, il prezzo deve aver
//   raggiunto la midline del canale. Se NON tocca la midline = il trade precedente è in loss
//   = NON accettare un altro segnale nella stessa direzione (evita accumulo perdente).
// ↑ FALSE = usa solo il contatore barre per lo stesso verso.
input int             InpNSameBars        = 3;         // Stesso Verso: Barre Attesa dopo Midline (1-10)
// ↑ DOPO che il prezzo ha toccato la midline, quante barre attendere prima di accettare
//   un nuovo segnale nella stessa direzione. Su M15: 3 barre = 45 min. Su M5: 3 barre = 15 min.

input group "    ↔️ DIREZIONE OPPOSTA (es. SELL dopo BUY)"
input int             InpNOppositeBars    = 2;         // Segnale Opposto: Barre Minime di Attesa (1-10)
// ↑ Barre minime tra l'ultimo segnale e un nuovo segnale di DIREZIONE OPPOSTA.
//   Solo filtro anti-rumore (il prezzo deve attraversare tutto il canale, ~5-15+ barre).
//   Su M15: 2 barre = 30 min. Su M5: 2 barre = 10 min.

//═══════════════════════════════════════════════════════════════════
//  SEZIONE 3a: FILTRI QUALITÀ SEGNALE (v7.00)
//═══════════════════════════════════════════════════════════════════
input group "                                                               "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  🛡️ FILTRI QUALITÀ SEGNALE                               ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    📊 BAND FLATNESS (stabilità livello)"
//
// ╔═══════════════════════════════════════════════════════════════════════╗
// ║  BAND FLATNESS FILTER — Cos'è e perché serve                        ║
// ╠═══════════════════════════════════════════════════════════════════════╣
// ║                                                                     ║
// ║  OBIETTIVO:                                                         ║
// ║  La strategia Turtle Soup è mean-reversion: scommette che il        ║
// ║  prezzo TORNERÀ indietro dopo aver toccato la banda Donchian.       ║
// ║  Funziona bene quando il mercato è in RANGE (banda piatta).         ║
// ║  Funziona MALE quando il mercato è in TREND (banda in espansione).  ║
// ║                                                                     ║
// ║  LOGICA:                                                            ║
// ║  Il filtro confronta il livello ATTUALE della banda con il livello  ║
// ║  che aveva nelle barre precedenti. Se la banda si è mossa più di    ║
// ║  una soglia (proporzionale all'ATR) → il mercato è in trend →       ║
// ║  il segnale viene BLOCCATO.                                         ║
// ║                                                                     ║
// ║  ESEMPIO (SELL alla upper band, M15, ATR=12 pip):                   ║
// ║    Tolleranza = 0.25 × 12 = 3 pip                                  ║
// ║    Se BufUpper[i] > BufUpper[i-k] + 3 pip → BLOCCA                 ║
// ║    (la upper è salita di più di 3 pip → trend rialzista attivo)     ║
// ║                                                                     ║
// ║  ESEMPIO (BUY alla lower band, M15, ATR=12 pip):                    ║
// ║    Se BufLower[i] < BufLower[i-k] - 3 pip → BLOCCA                 ║
// ║    (la lower è scesa di più di 3 pip → trend ribassista attivo)     ║
// ║                                                                     ║
// ║  VERSIONI:                                                          ║
// ║  v7.01: confronto strict (>) → bloccava il 95% dei segnali su M5   ║
// ║         perché ogni micro-nuovo-massimo (0.1 pip) era "espansione"  ║
// ║  v7.03: tolleranza ATR-proporzionale → risolve micro-espansioni     ║
// ║         MA confronto solo [i] vs [i+1] → effetto binario on/off    ║
// ║  v7.07: lookback multi-barra → confronto con le ultime N barre     ║
// ║         elimina l'effetto on/off su espansioni intermittenti        ║
// ║                                                                     ║
// ║  INTERAZIONE TRA I DUE PARAMETRI:                                   ║
// ║  • Tolleranza ALTA + Lookback BASSO = filtro permissivo             ║
// ║    (blocca solo espansioni enormi sulla barra immediatamente prima) ║
// ║  • Tolleranza BASSA + Lookback ALTO = filtro restrittivo            ║
// ║    (blocca anche micro-espansioni fino a N barre fa)                ║
// ║  • Combinazione raccomandata: Tolleranza 0.25 + Lookback 3         ║
// ║                                                                     ║
// ║  APPLICAZIONE:                                                      ║
// ║  Il filtro è applicato in DUE punti del codice:                     ║
// ║  1. SEZIONE 5 (main loop) — filtra segnali sulle barre storiche    ║
// ║     Usa indice [i] (barra corrente nel loop) vs [i+k] (precedenti) ║
// ║  2. SEZIONE 5b (Touch Trigger) — filtra segnali real-time          ║
// ║     Usa indice [1] (ultima barra chiusa) vs [1+k] (precedenti)     ║
// ║     NON usa [0] perché cambia ad ogni tick (dato instabile)         ║
// ║                                                                     ║
// ╚═══════════════════════════════════════════════════════════════════════╝
//
input bool            InpUseBandFlatness    = true;      // Abilita Band Flatness Filter
// ↑ TRUE  = il filtro è attivo. I segnali in trend forte vengono bloccati.
// ↑ FALSE = il filtro è disabilitato. TUTTI i tocchi della banda generano segnale
// ↑         (soggetto agli altri filtri: MA, cooldown, Level Age).
// ↑
// ↑ CONSIGLIO: tenere sempre TRUE. L'unico motivo per disabilitarlo è
// ↑ se si vuole studiare quanti segnali vengono filtrati (confronto on/off).

input double          InpFlatnessTolerance  = 0.55;      // Tolleranza espansione banda (multiplo ATR)
// ↑ Quanto la banda Donchian può espandersi senza bloccare il segnale.
// ↑ Il valore è un MOLTIPLICATORE dell'ATR(14) della barra corrente.
// ↑
// ↑ FORMULA (per SELL alla upper band):
// ↑   soglia = InpFlatnessTolerance × ATR(14)
// ↑   Per ogni k da 1 a Lookback:
// ↑     SE BufUpper[barra_corrente] > BufUpper[barra_corrente + k] + soglia
// ↑     → la upper è salita troppo → BLOCCA segnale SELL
// ↑
// ↑ FORMULA (per BUY alla lower band):
// ↑   Per ogni k da 1 a Lookback:
// ↑     SE BufLower[barra_corrente] < BufLower[barra_corrente + k] - soglia
// ↑     → la lower è scesa troppo → BLOCCA segnale BUY
// ↑
// ↑ PERCHÉ PROPORZIONALE ALL'ATR:
// ↑   Su EURUSD M15 (ATR ~12 pip): soglia = 0.55 × 12 = 6.6 pip
// ↑   Su GBPJPY M15 (ATR ~25 pip): soglia = 0.55 × 25 = 13.75 pip
// ↑   → Si adatta automaticamente alla volatilità dello strumento.
// ↑
// ↑ VALORI:
// ↑   0.00 = strict equality (NON usare — blocca per differenze di 0.1 pip)
// ↑   0.10 = molto stretto — blocca espansioni > 10% dell'ATR (~1.2 pip su EURUSD)
// ↑   0.25 = stretto — blocca espansioni > 25% ATR (~3 pip su EURUSD)
// ↑   0.55 = ★ RACCOMANDATO con lookback 3 — bilanciato (~6.6 pip su EURUSD)
// ↑   1.00 = quasi disabilitato — serve espansione pari a 1 ATR intero
// ↑
// ↑ NOTA: Aumentando il Lookback, conviene aumentare leggermente anche la
// ↑ Tolleranza per evitare di bloccare troppi segnali. Combinazione consigliata:
// ↑   Lookback 1 → Tolleranza 0.15-0.25
// ↑   Lookback 3 → Tolleranza 0.55 (default)
// ↑   Lookback 5 → Tolleranza 0.60-0.80

input int             InpFlatLookback       = 3;         // Lookback barre filtro flatness (1-10)
// ↑ Quante barre indietro controllare per rilevare un'espansione della banda.
// ↑ Il filtro confronta la barra corrente con OGNUNA delle N barre precedenti.
// ↑ Se l'espansione supera la tolleranza rispetto ad ALMENO UNA → BLOCCA.
// ↑
// ↑ PERCHÉ SERVE IL LOOKBACK MULTI-BARRA:
// ↑
// ↑   La banda Donchian si muove "a step" (a gradini): cambia SOLO quando
// ↑   un nuovo massimo/minimo entra o esce dalla finestra di 20 barre.
// ↑   Tra un gradino e l'altro, la banda resta PIATTA per più candele.
// ↑
// ↑   Con lookback = 1 (v7.03), il filtro confrontava solo [i] vs [i+1]:
// ↑   ┌─────────────────────────────────────────────────────┐
// ↑   │  Barra 5: Upper salta +3 pip → [5] vs [6]: BLOCCA  │
// ↑   │  Barra 4: Upper invariata   → [4] vs [5]: 0 = PASSA│ ← BUG!
// ↑   │  Barra 3: Upper invariata   → [3] vs [4]: 0 = PASSA│ ← BUG!
// ↑   │  Barra 2: Upper salta +2 pip → [2] vs [3]: BLOCCA  │
// ↑   │  Barra 1: Upper invariata   → [1] vs [2]: 0 = PASSA│ ← BUG!
// ↑   └─────────────────────────────────────────────────────┘
// ↑   Il filtro bloccava SOLO la barra dell'espansione, non le successive.
// ↑   Un trend con espansioni intermittenti (1 su 3-4) passava nei gap.
// ↑
// ↑   Con lookback = 3 (v7.07), il filtro confronta con le ultime 3:
// ↑   ┌─────────────────────────────────────────────────────────────┐
// ↑   │  Barra 4: Upper invariata                                  │
// ↑   │    vs [5]: 0 pip            → sotto soglia                 │
// ↑   │    vs [6]: 3 pip (+3 dal salto a barra 5) → BLOCCA! ✓     │
// ↑   │  Barra 3: Upper invariata                                  │
// ↑   │    vs [4]: 0 pip            → sotto soglia                 │
// ↑   │    vs [5]: 0 pip            → sotto soglia                 │
// ↑   │    vs [6]: 3 pip (+3 dal salto a barra 5) → BLOCCA! ✓     │
// ↑   │  Barra 2: Upper salta +2 pip                               │
// ↑   │    vs [3]: 0 pip            → sotto soglia                 │
// ↑   │    vs [4]: 0 pip            → sotto soglia                 │
// ↑   │    vs [5]: 5 pip (+3+2 cumulato) → BLOCCA! ✓              │
// ↑   └─────────────────────────────────────────────────────────────┘
// ↑   Il trend viene rilevato anche nelle barre "piatte" tra due espansioni.
// ↑
// ↑ VALORI:
// ↑   1  = come v7.03 (solo barra precedente — soggetto a effetto on/off)
// ↑   3  = ★ RACCOMANDATO — M15: 3×15min = 45 min di lookback
// ↑   5  = aggressivo — M15: 75 min, blocca la maggior parte dei trend
// ↑   10 = molto restrittivo — M15: 150 min, quasi ogni segnale in trend bloccato
// ↑
// ↑ RELAZIONE CON IL TIMEFRAME:
// ↑   M5:  lookback 3 = 15 min  |  M15: lookback 3 = 45 min
// ↑   M30: lookback 3 = 90 min  |  H1:  lookback 3 = 3 ore
// ↑   Su timeframe più alti, considerare lookback più bassi (2-3)
// ↑   per evitare di bloccare troppo.

input group "    ⏳ LEVEL AGE (maturità livello — Regola Raschke)"
input bool                 InpUseLevelAge      = false;      // Abilita Level Age Filter
// ↑ TRUE  = il filtro è attivo. Blocca segnali su livelli troppo recenti/freschi.
// ↑ FALSE = disabilitato. Comportamento identico alle versioni precedenti.
// ↑ Conta barre consecutive di banda piatta (FLAT_BARS) — Regola Raschke.

input int                  InpMinLevelAge      = 3;          // Barre minime banda piatta (1-10)
// ↑ Quante barre consecutive la banda deve essere piatta prima del segnale.
// ↑   M5:  3 barre = 15 minuti di livello stabilizzato  ★ RACCOMANDATO
// ↑   M15: 2 barre = 30 minuti (meno segnali ma più affidabili)
// ↑   M5:  5 barre = 25 minuti (conservativo, pochi segnali)
// ↑ Range valido: 1-10. NON ottimizzare oltre questo range.

input group "    📉 TREND CONTEXT (filtro macro-trend su finestra DC)"
//
// ╔═══════════════════════════════════════════════════════════════════════╗
// ║  TREND CONTEXT FILTER — Cos'è e perché serve                        ║
// ╠═══════════════════════════════════════════════════════════════════════╣
// ║                                                                     ║
// ║  PROBLEMA RISOLTO:                                                  ║
// ║  Il Band Flatness guarda solo 3 barre (15 min su M5). Un downtrend  ║
// ║  "a gradini" (la lower scende 5 pip ogni 5-8 barre) ha periodi      ║
// ║  di flatness tra un gradino e l'altro → Band Flatness dice "ok"    ║
// ║  e accetta BUY controtendenza durante il trend macro.               ║
// ║                                                                     ║
// ║  SOLUZIONE:                                                         ║
// ║  Controlla lo spostamento della MIDLINE nelle ultime InpLenDC barre.║
// ║  La midline è la media aritmetica (Upper+Lower)/2 del Donchian.     ║
// ║  Se scende di N×ATR in 20 barre → macro-trend ribassista → blocca  ║
// ║  il segnale BUY controtendenza.                                     ║
// ║                                                                     ║
// ║  COMPLEMENTARITÀ CON BAND FLATNESS:                                  ║
// ║   Band Flatness: finestra 3 barre   → trend locale (15 min su M5)  ║
// ║   Trend Context: finestra 20 barre  → trend macro  (100 min su M5) ║
// ║   Insieme: copertura completa da breve a medio termine.             ║
// ║                                                                     ║
// ║  FORMULA:                                                           ║
// ║   threshold = InpTrendContextMultiple × ATR(14)[barra_corrente]    ║
// ║   Blocca BUY:  se MidLine[20 barre fa] - MidLine[ora] > threshold  ║
// ║   Blocca SELL: se MidLine[ora] - MidLine[20 barre fa] > threshold  ║
// ║                                                                     ║
// ║  ESEMPIO GBPUSD M5 (ATR ~7 pip, Multiple=1.5):                     ║
// ║   Threshold = 1.5 × 7 = 10.5 pip                                   ║
// ║   Downtrend 200 pip in 4 giorni: midline scende ~50 pip in 20 bar  ║
// ║   → 50 >> 10.5 → BLOCCA tutti i BUY controtendenza. ✓             ║
// ║   Range laterale: midline si sposta 2-3 pip in 20 barre            ║
// ║   → 2-3 < 10.5 → PASSA il segnale BUY. ✓                          ║
// ║                                                                     ║
// ╚═══════════════════════════════════════════════════════════════════════╝
//
input bool   InpUseTrendContext      = false;   // Abilita Trend Context Filter
// ↑ TRUE  = attivo. Agisce DOPO il Band Flatness (filtro aggiuntivo, non sostitutivo).
// ↑ FALSE = disabilitato. Comportamento identico alle versioni precedenti.
// ↑ ★ CONSIGLIO: abilitare insieme al Band Flatness per copertura completa.

input double InpTrendContextMultiple = 1.5;    // Soglia Trend Context (multiplo ATR)
// ↑ Quanto deve spostarsi la midline in InpLenDC barre per bloccare il segnale.
// ↑ Il valore è un MOLTIPLICATORE dell'ATR(14) della barra corrente.
// ↑
// ↑ CALIBRAZIONE PER COPPIA / TIMEFRAME:
// ↑   GBPUSD M5  (ATR ~7 pip):  1.5 → soglia 10.5 pip   ★ RACCOMANDATO
// ↑   EURUSD M5  (ATR ~6 pip):  1.5 → soglia  9.0 pip
// ↑   GBPUSD M15 (ATR ~12 pip): 1.5 → soglia 18.0 pip
// ↑   EURUSD M15 (ATR ~10 pip): 1.5 → soglia 15.0 pip
// ↑
// ↑ VALORI:
// ↑   1.0 = stretto  — blocca anche trend lievi (pochi segnali)
// ↑   1.5 = ★ RACCOMANDATO — bilanciato
// ↑   2.0 = permissivo — blocca solo trend forti
// ↑   3.0 = quasi disabilitato
// ↑
// ↑ NOTA: NON ottimizzare aggressivamente. La semplicità del valore 1.5 è la sua forza.

input group "    📏 CHANNEL WIDTH (larghezza minima canale in PIP)"
input bool            InpUseWidthFilter   = true;      // Abilita Channel Width Filter
// ↑ TRUE = blocca TUTTI i segnali quando il canale Donchian è troppo stretto.
//   Canale stretto = poco spazio per il TP (midline = metà canale).
//   Se il canale è 4 pip, il TP è ~2 pip. Con commissioni di 1 pip, il netto è solo 1 pip.
// ↑ FALSE = nessun filtro larghezza, come v6.01.

input double          InpMinWidthPips     = 8.0;       // Larghezza minima canale (pip)
// ↑ Il canale (upper - lower) deve essere largo ALMENO questo valore in pip.
//   8.0 = canale minimo 8 pip → TP ~4 pip (margine sufficiente per commissioni).
//   8.0 = conservativo (TP ~4 pip, margine ampio).
//   3.0 = aggressivo (TP ~1.5 pip, attenzione commissioni!).
//   NOTA: valore in PIP (non in punti). Su EURUSD 5 pip = 50 punti = 0.00050.

input group "    🕐 FILTRO ORARIO (blocco fasce orarie)"
input bool            InpUseTimeFilter    = false;     // Abilita Filtro Orario
// ↑ TRUE = NON genera segnali nella fascia oraria specificata.
//   I TP Target già aperti CONTINUANO a essere monitorati (chiusi se raggiunti).
//   Solo NUOVI trigger vengono bloccati.
// ↑ Tipico uso: bloccare 15:20-16:20 (apertura mercati US, alta volatilità e spread).

input string          InpTimeBlockStart   = "15:20";   // Inizio Blocco (tuo orario locale HH:MM)
input string          InpTimeBlockEnd     = "16:20";   // Fine Blocco (tuo orario locale HH:MM)
// ↑ Formato: "HH:MM" (24 ore). Esempi: "15:20", "23:00", "07:30".
// ↑ Gli orari sono nel TUO fuso orario locale.
// ↑ L'indicatore converte automaticamente in orario broker usando l'offset sotto.
// ↑ Supporta range overnight: "23:00" → "07:00" blocca dalle 23 alle 7.

input int             InpBrokerOffset     = 1;         // Differenza Broker - Tuo Orario (ore)
// ↑ Quante ore il broker è AVANTI rispetto al tuo orario locale.
// ↑ Esempio: tu sei GMT+1 (Roma), broker è GMT+2 → inserisci 1.
// ↑ Esempio: tu sei GMT+1 (Roma), broker è GMT+3 → inserisci 2.
// ↑ Se non sei sicuro: apri un trade, confronta l'ora nel journal MT5
// ↑ con il tuo orologio. La differenza è questo valore.
// ↑ 0 = broker usa il tuo stesso fuso orario.

//═══════════════════════════════════════════════════════════════════
//  SEZIONE 3b: MODALITÀ TRIGGER (v6.01)
//═══════════════════════════════════════════════════════════════════
input group "                                                               "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  ⚡ MODALITÀ TRIGGER                                     ║"
input group "╚═══════════════════════════════════════════════════════════╝"

//--- v7.13: CLASSIC mode rimosso. Solo FIRST_CANDLE supportato.
//    L'input è stato sostituito con una COSTANTE: l'utente non può più selezionare
//    il trigger mode dal pannello impostazioni dell'indicatore.
//    Tutte le referenze a InpTriggerMode nel codice continuano a compilare
//    perché la const ha lo stesso nome del vecchio input.
//    Il compilatore MQL5 ottimizza automaticamente via i branch morti
//    (dead code elimination: if(TRIGGER_FIRST_CANDLE == TRIGGER_FIRST_CANDLE) → true).
//
// input ENUM_TRIGGER_MODE InpTriggerMode = TRIGGER_FIRST_CANDLE;  // (v7.13: rimosso)
const ENUM_TRIGGER_MODE InpTriggerMode = TRIGGER_FIRST_CANDLE;  // v7.13: fisso FIRST_CANDLE
//
// ┌─────────────────────────────────────────────────────────────────────┐
// │  COME FUNZIONA FIRST_CANDLE (flusso segnale indicatore → EA):     │
// │                                                                     │
// │  1. Il prezzo tocca la banda Donchian (high >= upper o low <= lower)│
// │  2. L'indicatore verifica 5 filtri intra-barra:                    │
// │     - SmartCooldown (distanza dall'ultimo segnale)                  │
// │     - Detection Window (finestra di N barre)                        │
// │     - Midline Touch (reset cooldown se prezzo tocca midline)       │
// │     - Band Flatness (la banda non si sta espandendo)               │
// │     - Level Age (il livello è stabilizzato da N barre)             │
// │     - Trend Context (nessun macro-trend contro il segnale)         │
// │     - Channel Width (il canale è abbastanza largo per il TP)       │
// │  3. Se tutti i filtri passano → Buffer 18 = +1 (BUY) o -1 (SELL)  │
// │  4. L'EA legge Buffer 18 ad ogni tick con CopyBuffer(handle,18,0,1)│
// │  5. L'EA apre la posizione MA deve confermare:                     │
// │     - Filtro MA (close > MA per BUY, close < MA per SELL)          │
// │     - Close oltre midline (close < mid per BUY, close > mid SELL)  │
// │  6. Alla chiusura della barra, l'EA controlla BufSignalUp[1]/Dn[1] │
// │     Se NON confermato → l'EA chiude la posizione (falso trigger)   │
// └─────────────────────────────────────────────────────────────────────┘

//═══════════════════════════════════════════════════════════════════
//  SEZIONE 4: COLORI E STILE
//═══════════════════════════════════════════════════════════════════
input group "                                                               "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  🎨 COLORI E STILE                                       ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    📐 PROIEZIONE FORECAST"
input color           InpColForecastUp  = clrGreen;    // Proiezione Rialzista
input color           InpColForecastDn  = clrRed;      // Proiezione Ribassista
input int             InpForecastWidth  = 2;           // Spessore Linee Proiezione

input group "    📐 CANALE DONCHIAN"
input color           InpColDonchianUp  = clrBlue;     // Bordo Superiore Canale
input color           InpColDonchianDn  = clrBlue;     // Bordo Inferiore Canale
input color           InpColDonchianFill= clrDodgerBlue; // Colore Sfondo Canale
input int             InpFillAlpha      = 30;          // Trasparenza Sfondo (0=invisibile, 255=solido)

input group "    📐 LINEA MEDIANA"
input color           InpColMidUp       = clrLime;     // Linea Mediana Rialzo
input color           InpColMidDn       = clrRed;      // Linea Mediana Ribasso

input group "    📐 SEGNALI"
input color           InpColSignalUp    = clrLime;     // Freccia BUY (verde)
input color           InpColSignalDn    = clrRed;      // Freccia SELL (rossa)
input double          InpArrowOffsetMult= 1.5;         // Distanza Frecce dal Canale (x ATR)

input group "    🔦 CANDELA TRIGGER"
input bool            InpShowTriggerCandle = true;     // Evidenzia Candela Trigger
// ↑ TRUE = colora il CORPO della candela dove scatta il segnale.
// ↑ Un rettangolo del colore scelto viene disegnato SOPRA il corpo della candela
// ↑ (da open a close). Le ombre (wick) restano visibili sopra e sotto.
// ↑ Permette di identificare visivamente quale candela ha generato il trigger.
// ↑ FALSE = solo frecce e etichette, nessun highlight sulla candela.
input color           InpColTriggerCandle  = clrYellow; // Colore Candela Trigger
// ↑ Colore con cui viene colorato il corpo della candela trigger.
// ↑ Default: giallo canarino (clrYellow) — visibile su sfondo scuro e chiaro.

//═══════════════════════════════════════════════════════════════════
//  SEZIONE 5: MEDIA MOBILE (Visualizzazione)
//═══════════════════════════════════════════════════════════════════
input group "                                                               "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  📉 MEDIA MOBILE (Visualizzazione)                       ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input bool            InpShowMA         = false;       // Mostra MA sul Grafico (solo visivo)
input color           InpColMA          = clrTeal;     // Colore Linea MA

//═══════════════════════════════════════════════════════════════════
//  SEZIONE 6: NOTIFICHE E ALERT
//═══════════════════════════════════════════════════════════════════
input group "                                                               "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  🔔 NOTIFICHE E ALERT                                    ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input bool            InpAlertPopup     = true;        // Popup Alert (finestra MT5)

//═══════════════════════════════════════════════════════════════════
//  SEZIONE 7: DEBUG
//═══════════════════════════════════════════════════════════════════
input group "                                                               "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  🔧 DEBUG                                                ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input bool            InpDebugCooldown    = true;      // Debug: Mostra Cooldown nel Journal
input string          InpInstanceID       = "";         // ID Istanza (per più DPC sullo stesso chart)
// ↑ VUOTO = default ("DPC_SIG_...", "DPC_CANVAS", ecc.)
// ↑ "13" = prefissi unici ("DPC13_SIG_...", "DPC13_CANVAS")
// ↑ Necessario SOLO se usi 2+ istanze DPC sulla stessa finestra chart.
// ↑ Ogni istanza deve avere un ID diverso, altrimenti OnDeinit di una cancella gli oggetti dell'altra.

//═══════════════════════════════════════════════════════════════════
//  SEZIONE 8: TP VISIVO (Backtest Grafico)
//═══════════════════════════════════════════════════════════════════
input group "                                                               "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  🎯 TP VISIVO (Backtest Grafico)                         ║"
input group "╚═══════════════════════════════════════════════════════════╝"

// v7.14c: Sistema "TP Dot" (midline MOBILE) RIMOSSO — era confusionario per BUY
//    in canali espansi (pallino driftava verso upper band). Ora SOLO TP Target (midline FISSA).
//    Input InpShowTPDots, InpShowTPLines, InpColTPDotBuy/Sell eliminati.

input group "    📏 TP TARGET (Backtest Visivo)"
input bool            InpShowTPTargetLine = true;      // Mostra Linea TP Target Orizzontale
// → Appena appare un segnale BUY/SELL:
//   1. Piazza un PALLINO TARGET colorato sulla midline (livello TP)
//   2. Tira una LINEA ORIZZONTALE tratteggiata che si estende a destra
//   3. Quando il prezzo TOCCA il livello TP → linea si FERMA + pallino bianco vuoto
//   4. Se il prezzo NON tocca mai → linea e pallino diventano grigi (mancato)
//   Backtest: linee con pallino bianco = vincenti. Linee grigie = perdenti.

input color           InpColTPTargetBuy   = clrLime;   // Colore Target TP BUY
input color           InpColTPTargetSell  = clrRed;    // Colore Target TP SELL
input int             InpTPTargetExpiry   = 300;       // Scadenza TP Target (barre, 0=mai)

input group "    🔵 ENTRY DOT (Punto di Ingresso)"
input bool            InpShowEntryDot     = true;      // Mostra Pallino Entry
// → Un pallino BLU piazzato al prezzo di CHIUSURA della candela segnale (= entry realistico).
//   Permette di confrontare visivamente Entry vs TP → come si chiude ogni operazione.
input color           InpColEntryDot      = clrDodgerBlue; // Colore Pallino Entry

//═══════════════════════════════════════════════════════════════════
//  SEZIONE 9: TEMA CHART (v7.03 — Applica tema visivo al trascinamento)
//═══════════════════════════════════════════════════════════════════
input group "                                                               "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  🎭 TEMA CHART (applicato al trascinamento)              ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input bool            InpApplyChartTheme  = true;              // Applica Tema Scuro al Grafico
// ↑ TRUE = al trascinamento dell'indicatore, il chart adotta uno schema colori scuro
//   ottimizzato per la lettura dei segnali Donchian. I colori originali vengono
//   RIPRISTINATI automaticamente alla rimozione dell'indicatore (OnDeinit).
// ↑ FALSE = il chart mantiene il suo tema corrente, nessuna modifica ai colori.

input bool            InpShowGrid         = false;             // Mostra Griglia
// ↑ FALSE = la griglia del chart viene nascosta per un aspetto più pulito.
//   TRUE = la griglia resta visibile (con colore tema se tema attivo).

input group "    🎨 COLORI TEMA"
input color           InpThemeBG          = C'19,23,34';       // Sfondo Chart
input color           InpThemeFG          = C'131,137,150';    // Testo, Assi, Scale
input color           InpThemeGrid        = C'42,46,57';       // Griglia (se visibile)
input color           InpThemeBullCandle  = C'38,166,154';     // Candela Rialzista (bull)
input color           InpThemeBearCandle  = C'239,83,80';      // Candela Ribassista (bear)

//+------------------------------------------------------------------+
//| Global Buffers                                                   |
//+------------------------------------------------------------------+
double BufMid[];          //  0 - Midline data (P0)
double BufMidColor[];     //  1 - Midline color index (P0)
double BufMidOffset[];    //  2 - Midline offset (P1)
double BufUpper[];        //  3 - Upper Donchian (P2)
double BufLower[];        //  4 - Lower Donchian (P3)
double BufFillUp[];       //  5 - Fill upper (P4)
double BufMA[];           //  6 - Moving Average (P5)
double BufSignalUp[];     //  7 - Signal Up tiny (P6)
double BufSignalDn[];     //  8 - Signal Down tiny (P7)
double BufSignalUpBig[];  //  9 - Signal Up big (P8)
double BufSignalDnBig[];  // 10 - Signal Down big (P9)
double BufCandleO[];      // 11 - Candle Open  (P10 DRAW_COLOR_CANDLES)
double BufCandleH[];      // 12 - Candle High  (P10)
double BufCandleL[];      // 13 - Candle Low   (P10)
double BufCandleC[];      // 14 - Candle Close (P10)
double BufCandleColor[];  // 15 - Candle Color (P10: 0=bull 1=bear 2=trigger)
double BufFillDn[];       // 16 - Fill lower (CALCULATIONS)
double BufATR[];          // 17 - ATR internal (CALCULATIONS)
double BufTouchTrigger[]; // 18 - Touch Trigger (CALCULATIONS: +1 BUY, -1 SELL)

//+------------------------------------------------------------------+
//| Global Variables                                                 |
//+------------------------------------------------------------------+
//
// CICLO DI VITA: Tutte le variabili globali vengono resettate in due casi:
//   1. prev_calculated == 0 (primo calcolo, cambio TF, ricalcolo completo)
//   2. OnInit() / dichiarazione con valore iniziale
//
// STATO SEGNALI (usato da Section 5 per cooldown):
//   g_lastMarkerBar   → bar_index (rates_total-1-i) dell'ultimo segnale CONFERMATO
//   g_lastDirection    → direzione dell'ultimo segnale CONFERMATO (+1 BUY, -1 SELL)
//   g_midlineTouched   → true se il prezzo ha toccato la midline dopo l'ultimo segnale
//   g_midlineTouchBar  → bar_index del tocco midline (per contare barre dopo)
//
//   NOTA CRITICA (Fix #2): In FIRST_CANDLE mode, queste 4 variabili NON vengono
//   aggiornate per i=0 (barra live). Si aggiornano solo quando la barra chiude
//   e viene riprocessata con i=1. Questo evita che un segnale provvisorio
//   corrompa lo stato del cooldown.
//

int    g_maHandle        = INVALID_HANDLE;  // Handle MA (SMA/EMA/WMA) — creato in OnInit
int    g_hmaHalfHandle   = INVALID_HANDLE;  // Handle WMA(n/2) per calcolo HMA — creato in OnInit
int    g_hmaFullHandle   = INVALID_HANDLE;  // Handle WMA(n) per calcolo HMA — creato in OnInit
int    g_atrHandle       = INVALID_HANDLE;  // Handle ATR(14) — creato in OnInit

//--- Stato segnali e cooldown (resettati in prev_calculated==0)
int    g_lastMarkerBar   = 0;       // bar_index dell'ultimo segnale confermato (per calcolo barsFromLast)
int    g_lastDirection   = 0;       // Direzione ultimo segnale: +1=BUY, -1=SELL, 0=nessuno (primo segnale)
bool   g_midlineTouched  = false;   // SmartCooldown: prezzo ha raggiunto la midline dopo l'ultimo segnale?
int    g_midlineTouchBar = 0;       // SmartCooldown: bar_index del tocco midline (per contare barre dopo)
int    g_nSameBars       = 3;       // Barre attesa stesso verso (validato 1-10 in OnInit)
int    g_nOppositeBars   = 2;       // Barre attesa direzione opposta (validato 1-10 in OnInit)
//--- Filtro Orario (v7.05): range orario bloccato in minuti dall'inizio del giorno (orario BROKER)
int    g_timeBlockStartMin = 0;    // Inizio blocco in minuti-del-giorno broker (0-1439)
int    g_timeBlockEndMin   = 0;    // Fine blocco in minuti-del-giorno broker (0-1439)
int    g_minLevelAge     = 3;       // Barre minime età livello Donchian (validato 1-10 in OnInit, v7.03)

//--- Chart Theme: salvataggio colori originali per ripristino in OnDeinit (v7.03)
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
bool   g_origShowGrid    = true;     // Stato griglia originale
int    g_origShowVolumes = 0;        // Stato volumi originale (CHART_VOLUME_HIDE/TICK/REAL)
bool   g_origForeground  = true;     // v7.10: Stato CHART_FOREGROUND originale
bool   g_chartThemeApplied = false;  // true se i colori chart sono stati modificati

//--- Touch Trigger tracking (v6.01, solo FIRST_CANDLE mode)
//    g_lastTouchDirection: memorizza il trigger emesso sulla barra corrente.
//    Serve come anti-duplicato: un solo trigger per barra, mantenuto per tutti i tick.
//    g_lastTouchTriggerBar: timestamp della barra dove l'ultimo trigger è stato emesso.
//    g_prevBarTimeTT: detector nuova barra per resettare g_lastTouchDirection (Fix #1).
int      g_lastTouchDirection    = 0;       // +1=BUY emesso, -1=SELL emesso, 0=nessun trigger questa barra
datetime g_lastTouchTriggerBar   = 0;       // time[0] quando l'ultimo trigger è stato emesso
datetime g_prevBarTimeTT         = 0;       // time[0] della barra precedente (per detect nuova barra)

//--- TP Dot tracking (pallini TP sulla midline — Section 4.5)
//    Queste variabili collegano il segnale (freccia) al suo TP (midline).
//    Quando g_waitingForTP == true, Section 4.5 monitora se il prezzo tocca la midline.
//    Al tocco: crea pallino colorato + linea connessione, poi g_waitingForTP = false.
double g_lastSignalPrice    = 0;       // Prezzo Y della freccia dell'ultimo segnale (per linea connessione)
double g_lastSignalBandPrice = 0;      // Prezzo della banda al segnale (BufLower per BUY, BufUpper per SELL — per guardia direzione TP)
datetime g_lastSignalTime   = 0;       // Tempo X della freccia dell'ultimo segnale (per linea connessione)
bool   g_waitingForTP       = false;   // Flag: in attesa che il prezzo tocchi la midline (SmartCooldown)

//--- TP Target tracking (v7.02 multi-target, v7.14c unico sistema TP)
//    Livello FISSO (BufMid al segnale). Linea orizzontale → stella gialla ★ al hit.
//    Linea diagonale tratteggiata da freccia a stella (CloseTPTarget).
//    Multi-target: ogni segnale crea un target indipendente, restano attivi fino a hit.
struct TPTargetInfo
{
   string   lineName;      // Nome OBJ_TREND (linea orizzontale)
   string   dotName;       // Nome OBJ_ARROW (pallino target)
   double   price;         // Livello prezzo target (BufMid al segnale)
   bool     isBuy;         // Direzione: true=BUY, false=SELL
   datetime signalTime;    // Tempo segnale (per calcolo barsToTP)
   double   signalPrice;   // Prezzo segnale (per calcolo pipsMove)
};
TPTargetInfo g_activeTPTargets[];   // Array di TP target attivi (multi-target v7.02)
int    g_tpTargetCounter        = 0;       // Contatore progressivo per nomi univoci target
int    g_tpHitCounter           = 0;       // Contatore dedicato per stelle hit TP (evita collisioni nome)

//--- Entry Dot tracking (v5.90 — pallino blu al prezzo di ingresso)
//    Piazzato al close[i] della candela segnale. Permette backtest visivo: entry vs TP.
int    g_entryDotCounter        = 0;       // Contatore progressivo per nomi univoci entry dot

//--- v7.18: Auto-detect iCustom sub-indicator mode
//    Quando l'indicatore è caricato via iCustom (dall'EA), NON è visibile nella
//    lista ChartIndicatorsTotal(). In quel caso, disabilitiamo TUTTI gli oggetti
//    grafici per evitare collisioni con l'istanza a grafico.
bool   g_isSubIndicator         = false;

double g_emaATR[];            // EMA(ATR, 200) computed manually
double g_rngArray[];          // dcHi - dcLo for slope calculation
double g_maValues[];          // MA values from handle
double g_hmaHalfValues[];     // WMA(n/2) for HMA
double g_hmaFullValues[];     // WMA(n) for HMA
double g_hmaIntermediate[];   // 2*WMA(n/2) - WMA(n) for HMA

//--- v7.04: Prefissi oggetti come variabili globali (non più #define)
//    Inizializzati in OnInit con InpInstanceID per supporto multi-istanza.
//    Default (InpInstanceID=""): "DPC_SIG_...", "DPC_CANVAS" (identico a v7.03)
//    Con ID (es. "13"):          "DPC13_SIG_...", "DPC13_CANVAS" (nessun conflitto)
string FORECAST_PREFIX;     // es. "DPC_FORECAST_" o "DPC13_FORECAST_"
string SIGNAL_PREFIX;       // es. "DPC_SIG_"
string TP_TARGET_PREFIX;    // es. "DPC_TPTGT_" — Linee orizzontali TP target
string TP_TGTDOT_PREFIX;    // es. "DPC_TPDOT_" — Pallini TP target
string ENTRY_DOT_PREFIX;    // es. "DPC_ENT_"   — Pallini entry (punto di ingresso)
string CANVAS_NAME;         // es. "DPC_CANVAS"

//--- Canvas for transparent fills
CCanvas  g_canvas;
bool     g_canvasCreated = false;

//+------------------------------------------------------------------+
//| Custom indicator initialization                                  |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- v7.18: Sub-indicator mode (parametro esplicito dall'EA)
   g_isSubIndicator = InpSubIndicatorMode;
   if(g_isSubIndicator)
      Print("[DPC] Sub-indicator mode ACTIVE — visual output DISABLED (buffer-only)");

   //--- v7.04: Inizializzazione prefissi oggetti con ID istanza
   //    Se InpInstanceID="" → "DPC_" (comportamento identico a v7.03)
   //    Se InpInstanceID="13" → "DPC13_" (prefissi unici per multi-istanza)
   string pfx = "DPC" + InpInstanceID + "_";
   FORECAST_PREFIX  = pfx + "FORECAST_";
   SIGNAL_PREFIX    = pfx + "SIG_";
   TP_TARGET_PREFIX = pfx + "TPTGT_";
   TP_TGTDOT_PREFIX = pfx + "TPDOT_";
   ENTRY_DOT_PREFIX    = pfx + "ENT_";
   CANVAS_NAME         = pfx + "CANVAS";

   //--- Buffer mapping
   //    REGOLA MQL5: tutti i buffer di plot (INDICATOR_DATA + INDICATOR_COLOR_INDEX)
   //    DEVONO precedere i buffer INDICATOR_CALCULATIONS. Violazione = malfunzionamento silenzioso.
   //    Plot 0-9: buffer 0-10 (11 buf), Plot 10 DRAW_COLOR_CANDLES: buffer 11-15 (5 buf)
   //    CALCULATIONS: buffer 16-18 (3 buf, alla fine)
   SetIndexBuffer(0,  BufMid,         INDICATOR_DATA);           // Plot 0 data
   SetIndexBuffer(1,  BufMidColor,    INDICATOR_COLOR_INDEX);    // Plot 0 color
   SetIndexBuffer(2,  BufMidOffset,   INDICATOR_DATA);           // Plot 1 data
   SetIndexBuffer(3,  BufUpper,       INDICATOR_DATA);           // Plot 2 data
   SetIndexBuffer(4,  BufLower,       INDICATOR_DATA);           // Plot 3 data
   SetIndexBuffer(5,  BufFillUp,      INDICATOR_DATA);           // Plot 4 data
   SetIndexBuffer(6,  BufMA,          INDICATOR_DATA);           // Plot 5 data
   SetIndexBuffer(7,  BufSignalUp,    INDICATOR_DATA);           // Plot 6 data
   SetIndexBuffer(8,  BufSignalDn,    INDICATOR_DATA);           // Plot 7 data
   SetIndexBuffer(9,  BufSignalUpBig, INDICATOR_DATA);           // Plot 8 data
   SetIndexBuffer(10, BufSignalDnBig, INDICATOR_DATA);           // Plot 9 data
   SetIndexBuffer(11, BufCandleO,     INDICATOR_DATA);           // Plot 10 data (Open)
   SetIndexBuffer(12, BufCandleH,     INDICATOR_DATA);           // Plot 10 data (High)
   SetIndexBuffer(13, BufCandleL,     INDICATOR_DATA);           // Plot 10 data (Low)
   SetIndexBuffer(14, BufCandleC,     INDICATOR_DATA);           // Plot 10 data (Close)
   SetIndexBuffer(15, BufCandleColor, INDICATOR_COLOR_INDEX);    // Plot 10 color
   //--- INDICATOR_CALCULATIONS alla fine (regola MQL5: DEVONO essere ultimi)
   SetIndexBuffer(16, BufFillDn,      INDICATOR_CALCULATIONS);   // Fill lower (per CCanvas)
   SetIndexBuffer(17, BufATR,         INDICATOR_CALCULATIONS);   // ATR(14) interno
   SetIndexBuffer(18, BufTouchTrigger, INDICATOR_CALCULATIONS);  // Touch Trigger per EA
   //--- Set as series
   ArraySetAsSeries(BufMid, true);
   ArraySetAsSeries(BufMidColor, true);
   ArraySetAsSeries(BufMidOffset, true);
   ArraySetAsSeries(BufUpper, true);
   ArraySetAsSeries(BufLower, true);
   ArraySetAsSeries(BufFillUp, true);
   ArraySetAsSeries(BufFillDn, true);
   ArraySetAsSeries(BufMA, true);
   ArraySetAsSeries(BufSignalUp, true);
   ArraySetAsSeries(BufSignalDn, true);
   ArraySetAsSeries(BufSignalUpBig, true);
   ArraySetAsSeries(BufSignalDnBig, true);
   ArraySetAsSeries(BufATR, true);
   ArraySetAsSeries(BufTouchTrigger, true);
   ArraySetAsSeries(BufCandleO, true);
   ArraySetAsSeries(BufCandleH, true);
   ArraySetAsSeries(BufCandleL, true);
   ArraySetAsSeries(BufCandleC, true);
   ArraySetAsSeries(BufCandleColor, true);
   //--- Midline color-switching (Plot 0)
   PlotIndexSetInteger(0, PLOT_COLOR_INDEXES, 2);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 0, InpColMidUp);   // index 0 = lime
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 1, InpColMidDn);   // index 1 = red

   //--- Upper/Lower Donchian colors
   PlotIndexSetInteger(2, PLOT_LINE_COLOR, InpColDonchianUp);
   PlotIndexSetInteger(3, PLOT_LINE_COLOR, InpColDonchianDn);

   //--- Plot 4 (DC Fill) is DRAW_NONE - fill is handled by CCanvas in RedrawCanvas()

   //--- MA color (Plot 5)
   PlotIndexSetInteger(5, PLOT_LINE_COLOR, InpColMA);
   if(!InpShowMA)
      PlotIndexSetInteger(5, PLOT_DRAW_TYPE, DRAW_NONE);

   //--- Plot 6-7: DRAW_ARROW per frecce segnale (v7.11+, v7.14: unica fonte frecce)
   //    Le frecce buffer sono SEMPRE renderizzate da MT5 come parte dei dati indicatore.
   //    Non spariscono durante scroll/zoom/ricalcoli.
   //    v7.14: OBJ_ARROW rimosso (creava frecce doppie). Solo OBJ_TEXT label+tooltip rimane.
   PlotIndexSetInteger(6, PLOT_ARROW, 233);                   // ⬆ up arrow (BUY)
   PlotIndexSetInteger(6, PLOT_LINE_COLOR, InpColSignalUp);   // colore BUY da input
   PlotIndexSetInteger(6, PLOT_LINE_WIDTH, 5);
   PlotIndexSetDouble(6, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   PlotIndexSetInteger(7, PLOT_ARROW, 234);                   // ⬇ down arrow (SELL)
   PlotIndexSetInteger(7, PLOT_LINE_COLOR, InpColSignalDn);   // colore SELL da input
   PlotIndexSetInteger(7, PLOT_LINE_WIDTH, 5);
   PlotIndexSetDouble(7, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   //--- Plot 10: DRAW_COLOR_CANDLES — colori dal tema + trigger (v7.10)
   //    3 colori: 0=bull (InpThemeBullCandle), 1=bear (InpThemeBearCandle), 2=trigger (InpColTriggerCandle)
   //    Ultimo plot → disegnato sopra bands/fill/MA con CHART_FOREGROUND=false
   PlotIndexSetInteger(10, PLOT_COLOR_INDEXES, 3);
   PlotIndexSetInteger(10, PLOT_LINE_COLOR, 0, InpThemeBullCandle);  // index 0 = bull
   PlotIndexSetInteger(10, PLOT_LINE_COLOR, 1, InpThemeBearCandle);  // index 1 = bear
   PlotIndexSetInteger(10, PLOT_LINE_COLOR, 2, InpColTriggerCandle); // index 2 = trigger (giallo)
   PlotIndexSetDouble(10, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   //--- Create MA handles
   if(InpMAType == MA_SMA)
      g_maHandle = iMA(_Symbol, PERIOD_CURRENT, InpMALen, 0, MODE_SMA, PRICE_CLOSE);
   else if(InpMAType == MA_EMA)
      g_maHandle = iMA(_Symbol, PERIOD_CURRENT, InpMALen, 0, MODE_EMA, PRICE_CLOSE);
   else if(InpMAType == MA_WMA)
      g_maHandle = iMA(_Symbol, PERIOD_CURRENT, InpMALen, 0, MODE_LWMA, PRICE_CLOSE);
   else if(InpMAType == MA_HMA)
   {
      int halfLen = (int)MathFloor(InpMALen / 2.0);
      if(halfLen < 1) halfLen = 1;
      g_hmaHalfHandle = iMA(_Symbol, PERIOD_CURRENT, halfLen, 0, MODE_LWMA, PRICE_CLOSE);
      g_hmaFullHandle = iMA(_Symbol, PERIOD_CURRENT, InpMALen, 0, MODE_LWMA, PRICE_CLOSE);
   }

   //--- Create ATR handle
   g_atrHandle = iATR(_Symbol, PERIOD_CURRENT, 14);

   if(g_atrHandle == INVALID_HANDLE ||
      (InpMAType != MA_HMA && g_maHandle == INVALID_HANDLE) ||
      (InpMAType == MA_HMA && (g_hmaHalfHandle == INVALID_HANDLE || g_hmaFullHandle == INVALID_HANDLE)))
   {
      Print("Error creating indicator handles!");
      return INIT_FAILED;
   }

   //--- Validate SmartCooldown inputs (clamp 1-10)
   g_nSameBars      = (int)MathMax(1, MathMin(10, InpNSameBars));
   g_nOppositeBars  = (int)MathMax(1, MathMin(10, InpNOppositeBars));
   //--- Validate Level Age input (clamp 1-10) — v7.03
   g_minLevelAge = (int)MathMax(1, MathMin(10, InpMinLevelAge));

   //--- Filtro Orario: parsing e conversione in orario broker — v7.05
   if(InpUseTimeFilter)
   {
      int localStartMin = ParseTimeToMinutes(InpTimeBlockStart);
      int localEndMin   = ParseTimeToMinutes(InpTimeBlockEnd);

      //--- Converti da orario locale a orario broker (+ offset ore)
      g_timeBlockStartMin = (localStartMin + InpBrokerOffset * 60) % 1440;
      g_timeBlockEndMin   = (localEndMin   + InpBrokerOffset * 60) % 1440;
      if(g_timeBlockStartMin < 0) g_timeBlockStartMin += 1440;
      if(g_timeBlockEndMin < 0)   g_timeBlockEndMin   += 1440;

      int startH = g_timeBlockStartMin / 60;
      int startM = g_timeBlockStartMin % 60;
      int endH   = g_timeBlockEndMin / 60;
      int endM   = g_timeBlockEndMin % 60;
      Print("[DPC] Filtro Orario ATTIVO: blocco ",
            StringFormat("%02d:%02d", startH, startM), " - ",
            StringFormat("%02d:%02d", endH, endM), " (orario broker) | ",
            "Input locale: ", InpTimeBlockStart, " - ", InpTimeBlockEnd,
            " + offset ", InpBrokerOffset, "h");
   }
   else
   {
      g_timeBlockStartMin = 0;
      g_timeBlockEndMin   = 0;
   }

   //--- Chart Theme: salva colori originali e applica tema — v7.03
   //    v7.18: skip tema se siamo un sub-indicatore (iCustom)
   g_chartThemeApplied = false;
   if(InpApplyChartTheme && !g_isSubIndicator)
   {
      //--- Salva colori originali (per ripristino in OnDeinit)
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
      g_chartThemeApplied = true;

      //--- Applica tema scuro
      ChartSetInteger(0, CHART_COLOR_BACKGROUND,  InpThemeBG);
      ChartSetInteger(0, CHART_COLOR_FOREGROUND,  InpThemeFG);
      ChartSetInteger(0, CHART_COLOR_GRID,        InpThemeGrid);
      ChartSetInteger(0, CHART_COLOR_CHART_LINE,  InpThemeFG);
      ChartSetInteger(0, CHART_COLOR_CANDLE_BULL, InpThemeBullCandle);
      ChartSetInteger(0, CHART_COLOR_CANDLE_BEAR, InpThemeBearCandle);
      ChartSetInteger(0, CHART_COLOR_CHART_UP,    InpThemeBullCandle);
      ChartSetInteger(0, CHART_COLOR_CHART_DOWN,  InpThemeBearCandle);
      ChartSetInteger(0, CHART_COLOR_BID,         InpThemeBullCandle);
      ChartSetInteger(0, CHART_COLOR_ASK,         InpThemeBearCandle);
      ChartSetInteger(0, CHART_COLOR_VOLUME,      InpThemeFG);
      ChartSetInteger(0, CHART_SHOW_GRID,         InpShowGrid);
      ChartSetInteger(0, CHART_SHOW_VOLUMES,      CHART_VOLUME_HIDE);

      ChartSetInteger(0, CHART_MODE, CHART_CANDLES);
      ChartRedraw();
   }

   //--- v7.10: CHART_FOREGROUND=false SEMPRE (indipendente dal tema)
   //    Necessario perché DRAW_COLOR_CANDLES (Plot 10, ultimo) deve essere SOPRA
   //    le candele chart native. Con FOREGROUND=true, le candele native coprirebbero
   //    il plot → candele trigger gialle invisibili.
   g_origForeground = (bool)ChartGetInteger(0, CHART_FOREGROUND);
   ChartSetInteger(0, CHART_FOREGROUND, false);

   //--- v7.10: Se tema NON applicato, leggi colori candele native dal chart
   //    e applicali a Plot 10 (DRAW_COLOR_CANDLES) così le candele normali
   //    hanno lo stesso aspetto delle candele chart native.
   if(!InpApplyChartTheme)
   {
      PlotIndexSetInteger(10, PLOT_LINE_COLOR, 0, (color)ChartGetInteger(0, CHART_COLOR_CANDLE_BULL));
      PlotIndexSetInteger(10, PLOT_LINE_COLOR, 1, (color)ChartGetInteger(0, CHART_COLOR_CANDLE_BEAR));
   }

   ChartRedraw();

   //--- Indicator name — v7.03
   string trigMode = "T1";  // v7.13: solo FIRST_CANDLE
   IndicatorSetString(INDICATOR_SHORTNAME,
      "DPC (" + IntegerToString(InpLenDC) + "," +
      IntegerToString(InpProjLen) + "," + trigMode + ")");

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   //--- v7.04: Log diagnostico — stampa SEMPRE il motivo del deinit
   //    Fondamentale per debuggare sparizioni di frecce/tema.
   string reasonText = "";
   switch(reason)
   {
      case REASON_PROGRAM:     reasonText = "PROGRAM (indicator stopped)"; break;
      case REASON_REMOVE:      reasonText = "REMOVE (indicator removed from chart)"; break;
      case REASON_RECOMPILE:   reasonText = "RECOMPILE (source recompiled)"; break;
      case REASON_CHARTCHANGE: reasonText = "CHARTCHANGE (symbol/TF changed)"; break;
      case REASON_CHARTCLOSE:  reasonText = "CHARTCLOSE (chart closed)"; break;
      case REASON_PARAMETERS:  reasonText = "PARAMETERS (inputs changed)"; break;
      case REASON_ACCOUNT:     reasonText = "ACCOUNT (account changed)"; break;
      case REASON_TEMPLATE:    reasonText = "TEMPLATE (chart template applied)"; break;
      default:                 reasonText = "UNKNOWN (" + IntegerToString(reason) + ")"; break;
   }
   Print("[DPC] OnDeinit reason=", reason, " → ", reasonText,
         " | objects=", ObjectsTotal(0),
         " | themeApplied=", g_chartThemeApplied);

   //--- Pulizia oggetti grafici (sempre necessaria)
   //    v7.18: skip se sub-indicatore — NON toccare oggetti dell'istanza chart
   if(!g_isSubIndicator)
   {
      DeleteForecastObjects();
      DeleteSignalObjects();
      DeleteTPTargetObjects();
      DeleteEntryDotObjects();

      //--- Destroy canvas
      if(g_canvasCreated)
      {
         g_canvas.Destroy();
         g_canvasCreated = false;
      }
   }

   //--- Release handles (OnInit li ricrea)
   if(g_maHandle != INVALID_HANDLE)       { IndicatorRelease(g_maHandle);      g_maHandle = INVALID_HANDLE; }
   if(g_hmaHalfHandle != INVALID_HANDLE)  { IndicatorRelease(g_hmaHalfHandle); g_hmaHalfHandle = INVALID_HANDLE; }
   if(g_hmaFullHandle != INVALID_HANDLE)  { IndicatorRelease(g_hmaFullHandle); g_hmaFullHandle = INVALID_HANDLE; }
   if(g_atrHandle != INVALID_HANDLE)      { IndicatorRelease(g_atrHandle);     g_atrHandle = INVALID_HANDLE; }

   //--- Ripristina colori chart SOLO se l'indicatore viene RIMOSSO definitivamente (v7.04)
   //
   //    REASON_PARAMETERS: OnInit segue IMMEDIATAMENTE con globali preservate.
   //      Se ripristinassimo qui, OnInit salverebbe i colori ORIGINALI (bene) ma ci sarebbe
   //      un FLASH visivo (tema scuro → tema chiaro → tema scuro in <100ms).
   //      Skip: nessun flash, OnInit riapplica il tema, g_orig* sono ancora validi.
   //
   //    REASON_CHARTCHANGE / REASON_RECOMPILE: full reload, globali resettate.
   //      DOBBIAMO ripristinare qui, altrimenti OnInit salverebbe i colori SCURI come "originali"
   //      e alla rimozione dell'indicatore il chart resterebbe scuro per sempre.
   //
   //    REASON_REMOVE / REASON_CHARTCLOSE: rimozione definitiva → ripristino obbligatorio.
   //
   bool skipRestore = (reason == REASON_PARAMETERS);

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

   //--- v7.10: Ripristina CHART_FOREGROUND SEMPRE (impostato fuori dal tema)
   if(!skipRestore)
      ChartSetInteger(0, CHART_FOREGROUND, g_origForeground);

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| ParseTimeToMinutes — Converte "HH:MM" in minuti (0-1439)         |
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
//| IsInBlockedTime — Controlla se una barra è nella fascia bloccata  |
//|                                                                    |
//| barTime = datetime della barra (orario broker/server)              |
//| Confronta con g_timeBlockStartMin / g_timeBlockEndMin (già in      |
//| orario broker, convertiti in OnInit).                              |
//|                                                                    |
//| Supporta range overnight: es. 23:00 → 07:00 (start > end)         |
//+------------------------------------------------------------------+
bool IsInBlockedTime(datetime barTime)
{
   if(!InpUseTimeFilter) return false;

   MqlDateTime dt;
   TimeToStruct(barTime, dt);
   int barMin = dt.hour * 60 + dt.min;

   if(g_timeBlockStartMin <= g_timeBlockEndMin)
   {
      // Range normale: es. 16:20 → 17:20
      return (barMin >= g_timeBlockStartMin && barMin < g_timeBlockEndMin);
   }
   else
   {
      // Range overnight: es. 23:00 → 07:00 (start > end)
      return (barMin >= g_timeBlockStartMin || barMin < g_timeBlockEndMin);
   }
}

//+------------------------------------------------------------------+
//| Linear Regression Slope                                          |
//| Returns the slope matching Pine's:                               |
//|   ta.linreg(src, length, 0) - ta.linreg(src, length, 1)         |
//+------------------------------------------------------------------+
double LinearRegressionSlope(const double &src[], int bar, int length, int total)
{
   if(bar + length > total) return 0.0;

   double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
   int n = length;

   for(int k = 0; k < n; k++)
   {
      // x = 0 for oldest bar in window, x = n-1 for newest (matching Pine convention)
      double x = (double)(n - 1 - k);
      double y = src[bar + k];  // bar+0 = newest, bar+k = older
      sumX  += x;
      sumY  += y;
      sumXY += x * y;
      sumX2 += x * x;
   }

   double denom = (n * sumX2 - sumX * sumX);
   if(MathAbs(denom) < 1e-10) return 0.0;

   double slope = (n * sumXY - sumX * sumY) / denom;

   // slope = linreg(src,len,0) - linreg(src,len,1) = b
   return slope;
}

//+------------------------------------------------------------------+
//| Manual Weighted Moving Average on custom array                   |
//+------------------------------------------------------------------+
double ManualWMA(const double &src[], int bar, int period, int total)
{
   if(bar + period > total) return 0.0;

   double weightSum = 0;
   double valSum = 0;

   for(int k = 0; k < period; k++)
   {
      double weight = (double)(period - k);  // newest = highest weight
      valSum    += src[bar + k] * weight;
      weightSum += weight;
   }

   if(weightSum == 0) return 0.0;
   return valSum / weightSum;
}

//+------------------------------------------------------------------+
//| Delete all forecast graphical objects                            |
//+------------------------------------------------------------------+
void DeleteForecastObjects()
{
   int total = ObjectsTotal(0);
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i);
      if(StringFind(name, FORECAST_PREFIX) >= 0)
         ObjectDelete(0, name);
   }
}

//+------------------------------------------------------------------+
//| Delete all signal arrow/label graphical objects                   |
//+------------------------------------------------------------------+
void DeleteSignalObjects()
{
   int total = ObjectsTotal(0);
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i);
      if(StringFind(name, SIGNAL_PREFIX) >= 0)
         ObjectDelete(0, name);
   }
}

// v7.14c: DeleteTPObjects rimossa — sistema TP Dot eliminato

//+------------------------------------------------------------------+
//| DeleteTPTargetObjects – Rimuove tutte le linee e pallini target   |
//+------------------------------------------------------------------+
void DeleteTPTargetObjects()
{
   int totalObjects = ObjectsTotal(0);
   for(int i = totalObjects - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i);
      if(StringFind(name, TP_TARGET_PREFIX) == 0 || StringFind(name, TP_TGTDOT_PREFIX) == 0)
         ObjectDelete(0, name);
   }
}

//+------------------------------------------------------------------+
//| DeleteEntryDotObjects – Rimuove tutti i pallini entry              |
//+------------------------------------------------------------------+
void DeleteEntryDotObjects()
{
   int totalObjects = ObjectsTotal(0);
   for(int i = totalObjects - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i);
      if(StringFind(name, ENTRY_DOT_PREFIX) == 0)
         ObjectDelete(0, name);
   }
}



//+------------------------------------------------------------------+
//| CreateTPTarget – Piazza pallino + linea orizzontale TP target     |
//|                                                                    |
//| Chiamata IMMEDIATAMENTE al momento del segnale (non al tocco).    |
//| v7.02: Multi-target — la linea resta attiva (colorata, RAY_RIGHT) |
//| finché il prezzo non tocca il livello TP. I target precedenti     |
//| NON vengono invalidati da nuovi segnali.                          |
//+------------------------------------------------------------------+
void CreateTPTarget(datetime signalTime, double tpPrice, bool isBuy, double signalPrice)
{
   if(g_isSubIndicator) return;  // v7.18: no visual objects in iCustom mode
   if(!InpShowTPTargetLine) return;

   //--- v7.02: NESSUN grey-out del target precedente — resta attivo fino a hit

   g_tpTargetCounter++;

   color targetColor = isBuy ? InpColTPTargetBuy : InpColTPTargetSell;
   string direction  = isBuy ? "BUY" : "SELL";

   //=== 1. PALLINO TARGET COLORATO (pieno) sulla midline ===
   string dotName = TP_TGTDOT_PREFIX + IntegerToString(g_tpTargetCounter);

   ObjectCreate(0, dotName, OBJ_ARROW, 0, signalTime, tpPrice);
   ObjectSetInteger(0, dotName, OBJPROP_ARROWCODE, 159);  // ● cerchio pieno
   ObjectSetInteger(0, dotName, OBJPROP_COLOR, targetColor);
   ObjectSetInteger(0, dotName, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, dotName, OBJPROP_BACK, false);
   ObjectSetInteger(0, dotName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, dotName, OBJPROP_HIDDEN, true);
   ObjectSetString(0, dotName, OBJPROP_TOOLTIP,
                   "TP TARGET " + direction + "\nLivello: " + DoubleToString(tpPrice, _Digits) +
                   "\nIn attesa di tocco...");

   //=== 2. LINEA ORIZZONTALE dal pallino verso destra ===
   string lineName = TP_TARGET_PREFIX + IntegerToString(g_tpTargetCounter);

   ObjectCreate(0, lineName, OBJ_TREND, 0,
                signalTime, tpPrice,
                signalTime + PeriodSeconds() * 500, tpPrice);

   ObjectSetInteger(0, lineName, OBJPROP_COLOR, targetColor);
   ObjectSetInteger(0, lineName, OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(0, lineName, OBJPROP_WIDTH, 1);  // v7.15: WIDTH=1 obbligatorio per STYLE_DASH (WIDTH>1 forza SOLID)
   ObjectSetInteger(0, lineName, OBJPROP_RAY_RIGHT, true);
   ObjectSetInteger(0, lineName, OBJPROP_RAY_LEFT, false);
   ObjectSetInteger(0, lineName, OBJPROP_BACK, false);
   ObjectSetInteger(0, lineName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, lineName, OBJPROP_HIDDEN, true);
   ObjectSetString(0, lineName, OBJPROP_TOOLTIP,
                   "TP TARGET " + direction + " | Livello: " + DoubleToString(tpPrice, _Digits));

   //--- Aggiungi al array multi-target (v7.02)
   int n = ArraySize(g_activeTPTargets);
   ArrayResize(g_activeTPTargets, n + 1);
   g_activeTPTargets[n].lineName    = lineName;
   g_activeTPTargets[n].dotName     = dotName;
   g_activeTPTargets[n].price       = tpPrice;
   g_activeTPTargets[n].isBuy       = isBuy;
   g_activeTPTargets[n].signalTime  = signalTime;
   g_activeTPTargets[n].signalPrice = signalPrice;
}

//+------------------------------------------------------------------+
//| CloseTPTarget – Ferma la linea + piazza pallino bianco vuoto ○    |
//|                                                                    |
//| Chiamata quando il prezzo raggiunge il livello TP target.         |
//| Risultato visivo: linea solida che termina con ○ bianco.          |
//+------------------------------------------------------------------+
void CloseTPTarget(int targetIdx, datetime touchTime, int barsToTP, double pipsMove)
{
   if(g_isSubIndicator) return;  // v7.18: no visual objects in iCustom mode
   if(!InpShowTPTargetLine) return;
   if(targetIdx < 0 || targetIdx >= ArraySize(g_activeTPTargets)) return;

   //--- Leggi dati dal array (v7.02)
   string lineName  = g_activeTPTargets[targetIdx].lineName;
   string dotName   = g_activeTPTargets[targetIdx].dotName;
   double tpPrice   = g_activeTPTargets[targetIdx].price;
   bool   isBuyTP   = g_activeTPTargets[targetIdx].isBuy;
   string direction = isBuyTP ? "BUY" : "SELL";

   //--- Ferma la linea: RAY_RIGHT = false e punto 2 = tempo del tocco
   if(ObjectFind(0, lineName) >= 0)
   {
      ObjectSetInteger(0, lineName, OBJPROP_RAY_RIGHT, false);
      ObjectMove(0, lineName, 1, touchTime, tpPrice);

      // Cambia stile a SOLIDO per indicare "raggiunto"
      ObjectSetInteger(0, lineName, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, lineName, OBJPROP_WIDTH, 1);  // v7.15: coerenza con CreateTPTarget

      ObjectSetString(0, lineName, OBJPROP_TOOLTIP,
                      "TP " + direction + " RAGGIUNTO | " +
                      IntegerToString(barsToTP) + " barre | " +
                      DoubleToString(pipsMove, 1) + " pips");
   }

   //--- STELLA GIALLA ★ al punto esatto dove il prezzo tocca il TP
   //    Contatore dedicato g_tpHitCounter (non g_tpTargetCounter) per evitare
   //    collisioni nome quando più target vengono chiusi con lo stesso counter globale.
   g_tpHitCounter++;
   string hitDotName = TP_TGTDOT_PREFIX + "HIT_" + IntegerToString(g_tpHitCounter);

   ObjectCreate(0, hitDotName, OBJ_ARROW, 0, touchTime, tpPrice);
   ObjectSetInteger(0, hitDotName, OBJPROP_ARROWCODE, 169);  // ★ stella 5 punte piena
   ObjectSetInteger(0, hitDotName, OBJPROP_COLOR, clrYellow);
   ObjectSetInteger(0, hitDotName, OBJPROP_WIDTH, 3);
   ObjectSetInteger(0, hitDotName, OBJPROP_BACK, false);
   ObjectSetInteger(0, hitDotName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, hitDotName, OBJPROP_HIDDEN, true);
   ObjectSetString(0, hitDotName, OBJPROP_TOOLTIP,
                   "★ TP " + direction + " RAGGIUNTO!\n" +
                   "Barre: " + IntegerToString(barsToTP) + "\n" +
                   "Move: " + DoubleToString(pipsMove, 1) + " pips\n" +
                   "Durata: " + IntegerToString(barsToTP * PeriodSeconds() / 60) + " min");

   //--- LINEA TRATTEGGIATA dalla freccia segnale alla stellina gialla ★
   //    Collega visivamente il punto di ingresso (freccia) al punto di uscita (TP).
   //    BUY = verde (successo long), SELL = rosso (successo short).
   datetime sigTime  = g_activeTPTargets[targetIdx].signalTime;
   double   sigPrice = g_activeTPTargets[targetIdx].signalPrice;

   if(sigTime > 0 && sigPrice > 0)
   {
      color connColor = isBuyTP ? InpColTPTargetBuy : InpColTPTargetSell;
      string connName = TP_TARGET_PREFIX + "CONN_" + IntegerToString(g_tpHitCounter);

      ObjectCreate(0, connName, OBJ_TREND, 0,
                   sigTime, sigPrice,
                   touchTime, tpPrice);

      ObjectSetInteger(0, connName, OBJPROP_COLOR, connColor);
      ObjectSetInteger(0, connName, OBJPROP_STYLE, STYLE_DOT);
      ObjectSetInteger(0, connName, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, connName, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, connName, OBJPROP_RAY_LEFT, false);
      ObjectSetInteger(0, connName, OBJPROP_BACK, false);
      ObjectSetInteger(0, connName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, connName, OBJPROP_HIDDEN, true);
      ObjectSetString(0, connName, OBJPROP_TOOLTIP,
                      direction + " → TP ★ | " + IntegerToString(barsToTP) + " barre | "
                      + DoubleToString(pipsMove, 1) + " pips");
   }

   //--- Aggiorna tooltip del pallino target originale (colorato)
   if(dotName != "" && ObjectFind(0, dotName) >= 0)
   {
      ObjectSetString(0, dotName, OBJPROP_TOOLTIP,
                      "TP TARGET " + direction + " RAGGIUNTO!\n" +
                      "Barre: " + IntegerToString(barsToTP) + "\n" +
                      "Move: " + DoubleToString(pipsMove, 1) + " pips\n" +
                      "Durata: " + IntegerToString(barsToTP * PeriodSeconds() / 60) + " min");
   }

   //--- Rimuovi target dall'array (v7.02)
   ArrayRemove(g_activeTPTargets, targetIdx, 1);
}

// v7.14c: CreateTPDot rimossa — sistema TP Dot (midline mobile) eliminato.
// Il TP visivo è ora SOLO TP Target (midline FISSA) in Section 4.6.

//+------------------------------------------------------------------+
//| Create signal arrow + label as graphical objects                  |
//| Garantisce colori corretti e tooltip al passaggio del mouse       |
//+------------------------------------------------------------------+
void CreateSignalArrow(datetime t, double price, bool isBuy, double glowOffset, double entryPrice, double tpMidline,
                       double widthRatio = 0.0,     // v7.00: channelWidth / ATR
                       bool bandFlat = true)         // v7.00: banda era piatta?
{
   if(g_isSubIndicator) return;  // v7.18: no visual objects in iCustom mode
   string suffix = IntegerToString((long)t);

   //--- v7.14: OBJ_ARROW rimosso (frecce visive = solo DRAW_ARROW Plot 6-7)
   color arrowColor = isBuy ? InpColSignalUp : InpColSignalDn;
   string priceStr  = DoubleToString(entryPrice, _Digits);
   string tpStr     = DoubleToString(tpMidline, _Digits);

   string tooltip   = (isBuy ? "▲ TRIGGER BUY - Segnale Rialzista\nApertura posizione LONG" :
                                "▼ TRIGGER SELL - Segnale Ribassista\nApertura posizione SHORT") +
                      "\nPrezzo: " + priceStr +
                      "\nTP Midline: " + tpStr +
                      "\nWidth/ATR: " + DoubleToString(widthRatio, 1) + "x" +
                      "\nBand Flat: " + (bandFlat ? "OK" : "NO");

   //--- v7.14: OBJ_ARROW rimosso — le frecce visive sono ora SOLO da DRAW_ARROW (Plot 6-7).
   //    DRAW_ARROW è un buffer dati: sempre renderizzato da MT5, non sparisce mai.
   //    L'OBJ_ARROW sovrapposto creava un effetto "freccia doppia" (due frecce identiche
   //    sovrapposte alla stessa posizione, stesso codice/colore/larghezza).
   //    Il tooltip viene fornito dall'OBJ_TEXT sottostante ("TRIGGER BUY/SELL").

   //--- Etichetta "TRIGGER BUY/SELL" posizionata al retro (coda) della freccia
   //--- SELL (⬇): testo SOPRA la coda della freccia (prezzo + offset)
   //--- BUY  (⬆): testo SOTTO la coda della freccia (prezzo - offset)
   string labelName = SIGNAL_PREFIX + (isBuy ? "BUY_LBL_" : "SELL_LBL_") + suffix;
   double labelPrice = isBuy ? price - glowOffset * 1.5 : price + glowOffset * 1.5;
   //    v7.15: moltiplicatore 3.0 → 1.5 per avvicinare il testo alla freccia DRAW_ARROW

   ObjectCreate(0, labelName, OBJ_TEXT, 0, t, labelPrice);
   ObjectSetString(0, labelName, OBJPROP_TEXT, isBuy ? "TRIGGER BUY" : "TRIGGER SELL");
   ObjectSetInteger(0, labelName, OBJPROP_COLOR, arrowColor);
   ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 7);
   ObjectSetString(0, labelName, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, isBuy ? ANCHOR_UPPER : ANCHOR_LOWER);
   ObjectSetInteger(0, labelName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, labelName, OBJPROP_HIDDEN, true);
   ObjectSetString(0, labelName, OBJPROP_TOOLTIP, tooltip);
}

//+------------------------------------------------------------------+
//| Generate forecast projection points                              |
//| Direct port of Pine's f_generatePoints()                         |
//+------------------------------------------------------------------+
void GenerateForecastPoints(double hi0, double md0, double lo0,
                            int steps, double midSlp, double rngSlp,
                            double &hiPts[], double &mdPts[], double &loPts[])
{
   ArrayResize(hiPts, steps + 1);
   ArrayResize(mdPts, steps + 1);
   ArrayResize(loPts, steps + 1);

   double curHi  = hi0;
   double curLo  = lo0;
   double curMid = md0;

   int segBars = (int)MathFloor(steps / 3.0);
   if(segBars < 1) segBars = 1;

   for(int b = 0; b <= steps; b++)
   {
      double mdProj    = md0 + midSlp * b;
      double prevRange = curHi - curLo;
      double rngProj   = prevRange + rngSlp * b;

      double hiTemp, loTemp;

      if(midSlp >= 0)
      {
         hiTemp = MathMax(curHi, mdProj + rngProj * 0.5);
         loTemp = MathMax(curLo, mdProj - rngProj * 0.5);
      }
      else
      {
         hiTemp = MathMin(curHi, mdProj + rngProj * 0.5);
         loTemp = MathMin(curLo, mdProj - rngProj * 0.5);
      }

      double hiProj = (hiTemp < mdProj) ? curHi : hiTemp;
      double loProj = (loTemp > mdProj) ? curLo : loTemp;

      if(b % segBars == 0)
      {
         curHi  = hiProj;
         curLo  = loProj;
         curMid = mdProj;
      }

      hiPts[b] = curHi;
      mdPts[b] = curMid;
      loPts[b] = curLo;
   }
}

//+------------------------------------------------------------------+
//| Draw forecast projection using graphical objects                  |
//+------------------------------------------------------------------+
void DrawForecast(const datetime &time[], int rates_total,
                  double hi0, double md0, double lo0,
                  double midSlp, double rngSlp)
{
   if(g_isSubIndicator) return;  // v7.18: no visual objects in iCustom mode
   DeleteForecastObjects();

   double hiPts[], mdPts[], loPts[];
   GenerateForecastPoints(hi0, md0, lo0, InpProjLen, midSlp, rngSlp,
                          hiPts, mdPts, loPts);

   datetime lastBarTime = time[0];  // as-series: [0] = most recent
   int periodSec = PeriodSeconds(PERIOD_CURRENT);

   //--- Determine midline forecast color based on slope sign
   color midForecastColor = (midSlp > 0) ? InpColMidUp :
                            (midSlp < 0) ? InpColMidDn : clrGray;

   //--- Draw trend line segments between consecutive forecast points
   for(int b = 0; b < InpProjLen; b++)
   {
      datetime t1 = lastBarTime + b * periodSec;
      datetime t2 = lastBarTime + (b + 1) * periodSec;

      //--- Upper forecast line (dashed)
      string nameHi = FORECAST_PREFIX + "HI_" + IntegerToString(b);
      ObjectCreate(0, nameHi, OBJ_TREND, 0, t1, hiPts[b], t2, hiPts[b + 1]);
      ObjectSetInteger(0, nameHi, OBJPROP_COLOR, InpColForecastUp);
      ObjectSetInteger(0, nameHi, OBJPROP_WIDTH, InpForecastWidth);
      ObjectSetInteger(0, nameHi, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, nameHi, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, nameHi, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, nameHi, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, nameHi, OBJPROP_BACK, false);

      //--- Lower forecast line (dashed)
      string nameLo = FORECAST_PREFIX + "LO_" + IntegerToString(b);
      ObjectCreate(0, nameLo, OBJ_TREND, 0, t1, loPts[b], t2, loPts[b + 1]);
      ObjectSetInteger(0, nameLo, OBJPROP_COLOR, InpColForecastDn);
      ObjectSetInteger(0, nameLo, OBJPROP_WIDTH, InpForecastWidth);
      ObjectSetInteger(0, nameLo, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, nameLo, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, nameLo, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, nameLo, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, nameLo, OBJPROP_BACK, false);

      //--- Midline forecast (dotted)
      string nameMd = FORECAST_PREFIX + "MD_" + IntegerToString(b);
      ObjectCreate(0, nameMd, OBJ_TREND, 0, t1, mdPts[b], t2, mdPts[b + 1]);
      ObjectSetInteger(0, nameMd, OBJPROP_COLOR, midForecastColor);
      ObjectSetInteger(0, nameMd, OBJPROP_WIDTH, InpForecastWidth);
      ObjectSetInteger(0, nameMd, OBJPROP_STYLE, STYLE_DOT);
      ObjectSetInteger(0, nameMd, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, nameMd, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, nameMd, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, nameMd, OBJPROP_BACK, false);
   }

   //--- Price labels at the forecast endpoints
   datetime endTime = lastBarTime + InpProjLen * periodSec;

   string labelHi = FORECAST_PREFIX + "LABEL_HI";
   ObjectCreate(0, labelHi, OBJ_TEXT, 0, endTime, hiPts[InpProjLen]);
   ObjectSetString(0, labelHi, OBJPROP_TEXT, " " + DoubleToString(hiPts[InpProjLen], _Digits));
   ObjectSetInteger(0, labelHi, OBJPROP_COLOR, (color)ChartGetInteger(0, CHART_COLOR_FOREGROUND));
   ObjectSetInteger(0, labelHi, OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, labelHi, OBJPROP_ANCHOR, ANCHOR_LEFT);
   ObjectSetInteger(0, labelHi, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, labelHi, OBJPROP_HIDDEN, true);

   string labelLo = FORECAST_PREFIX + "LABEL_LO";
   ObjectCreate(0, labelLo, OBJ_TEXT, 0, endTime, loPts[InpProjLen]);
   ObjectSetString(0, labelLo, OBJPROP_TEXT, " " + DoubleToString(loPts[InpProjLen], _Digits));
   ObjectSetInteger(0, labelLo, OBJPROP_COLOR, (color)ChartGetInteger(0, CHART_COLOR_FOREGROUND));
   ObjectSetInteger(0, labelLo, OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, labelLo, OBJPROP_ANCHOR, ANCHOR_LEFT);
   ObjectSetInteger(0, labelLo, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, labelLo, OBJPROP_HIDDEN, true);

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Redraw transparent fills using CCanvas                           |
//| - DC channel fill (Upper-Lower): InpColDonchianFill + InpFillAlpha|
//+------------------------------------------------------------------+
void RedrawCanvas()
{
   if(g_isSubIndicator) return;  // v7.18: no visual objects in iCustom mode
   int chartW = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   int chartH = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);

   if(chartW <= 0 || chartH <= 0) return;

   //--- Create or resize canvas
   if(!g_canvasCreated)
   {
      if(!g_canvas.CreateBitmapLabel(0, 0, CANVAS_NAME, 0, 0, chartW, chartH, COLOR_FORMAT_ARGB_NORMALIZE))
         return;
      ObjectSetInteger(0, CANVAS_NAME, OBJPROP_BACK, true);       // behind candles
      ObjectSetInteger(0, CANVAS_NAME, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, CANVAS_NAME, OBJPROP_HIDDEN, true);
      ObjectSetString(0, CANVAS_NAME, OBJPROP_TOOLTIP, "\n");   // trasparente al mouse (passa eventi agli oggetti sotto)
      g_canvasCreated = true;
   }
   else if(g_canvas.Width() != chartW || g_canvas.Height() != chartH)
   {
      g_canvas.Resize(chartW, chartH);
   }

   //--- Clear canvas (fully transparent)
   g_canvas.Erase(0x00000000);

   //--- Get chart scale info
   double priceMax = ChartGetDouble(0, CHART_PRICE_MAX);
   double priceMin = ChartGetDouble(0, CHART_PRICE_MIN);
   if(priceMax <= priceMin) { g_canvas.Update(); return; }

   int firstVisible = (int)ChartGetInteger(0, CHART_FIRST_VISIBLE_BAR);
   int visibleBars  = (int)ChartGetInteger(0, CHART_VISIBLE_BARS);
   int totalBars    = ArraySize(BufUpper);

   if(totalBars == 0) { g_canvas.Update(); return; }

   //--- ARGB colors for fills
   uchar dcAlpha = (uchar)MathMax(0, MathMin(255, InpFillAlpha));
   uint  dcARGB  = ColorToARGB(InpColDonchianFill, dcAlpha);
   //--- Midline fill rimosso in v7.06 (utente preferisce solo linea colorata)

   //--- Draw fills for each pair of consecutive visible bars
   for(int v = 0; v < visibleBars - 1; v++)
   {
      int shift1 = firstVisible - v;
      int shift2 = firstVisible - v - 1;

      if(shift1 < 0 || shift2 < 0 || shift1 >= totalBars || shift2 >= totalBars)
         continue;

      //--- Check valid data
      if(BufUpper[shift1] == EMPTY_VALUE || BufLower[shift1] == EMPTY_VALUE ||
         BufUpper[shift2] == EMPTY_VALUE || BufLower[shift2] == EMPTY_VALUE)
         continue;

      //--- Convert bar shift to X pixel using ChartTimePriceToXY
      int x1, y_dummy1, x2, y_dummy2;
      datetime t1 = iTime(_Symbol, PERIOD_CURRENT, shift1);
      datetime t2 = iTime(_Symbol, PERIOD_CURRENT, shift2);
      if(t1 == 0 || t2 == 0) continue;

      if(!ChartTimePriceToXY(0, 0, t1, BufUpper[shift1], x1, y_dummy1)) continue;
      if(!ChartTimePriceToXY(0, 0, t2, BufUpper[shift2], x2, y_dummy2)) continue;

      //--- DC Channel fill (Upper-Lower)
      int yHi1, yLo1, yHi2, yLo2;
      ChartTimePriceToXY(0, 0, t1, BufUpper[shift1], x1, yHi1);
      ChartTimePriceToXY(0, 0, t1, BufLower[shift1], x1, yLo1);
      ChartTimePriceToXY(0, 0, t2, BufUpper[shift2], x2, yHi2);
      ChartTimePriceToXY(0, 0, t2, BufLower[shift2], x2, yLo2);

      g_canvas.FillTriangle(x1, yHi1, x1, yLo1, x2, yHi2, dcARGB);
      g_canvas.FillTriangle(x1, yLo1, x2, yHi2, x2, yLo2, dcARGB);

      //--- Midline fill rimosso in v7.06 (solo linea DRAW_COLOR_LINE)
   }

   g_canvas.Update();
}

//+------------------------------------------------------------------+
//| Chart event handler - redraw canvas on scroll/zoom/resize        |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   if(id == CHARTEVENT_CHART_CHANGE)
   {
      static uint s_lastChartEvRedraw = 0;
      uint now = GetTickCount();
      if(now - s_lastChartEvRedraw > 200)  // max 5 redraws/sec
      {
         s_lastChartEvRedraw = now;
         RedrawCanvas();
         ChartRedraw();
      }
   }
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
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
   //--- Minimo di barre richieste per il calcolo
   //    InpLenDC per Donchian, InpMALen per MA, +200 per EMA(ATR,200), +10 di margine
   int minBars = MathMax(InpLenDC, InpMALen) + 210;
   if(rates_total < minBars) return 0;

   //--- Set input arrays as series
   ArraySetAsSeries(time, true);
   ArraySetAsSeries(open, true);    // v7.10: FIX — era mancante! open[] usato per DRAW_COLOR_CANDLES
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);

   //--- Resize global arrays
   if(ArraySize(g_emaATR) < rates_total)
   {
      ArrayResize(g_emaATR, rates_total);
      ArraySetAsSeries(g_emaATR, true);
   }
   if(ArraySize(g_rngArray) < rates_total)
   {
      ArrayResize(g_rngArray, rates_total);
      ArraySetAsSeries(g_rngArray, true);
   }
   if(ArraySize(g_maValues) < rates_total)
   {
      ArrayResize(g_maValues, rates_total);
      ArraySetAsSeries(g_maValues, true);
   }

   //--- Copy ATR values
   //    v7.10 FIX: se CopyBuffer fallisce DOPO il primo calcolo riuscito,
   //    NON resettare prev_calculated (return 0) — altrimenti su M5 il ciclo
   //    return 0 → full recalc → return 0 causa candele DRAW_COLOR_CANDLES
   //    che appaiono e scompaiono ripetutamente.
   //    Soluzione: return prev_calculated per mantenere il rendering precedente.
   double atrTemp[];
   ArraySetAsSeries(atrTemp, true);
   if(CopyBuffer(g_atrHandle, 0, 0, rates_total, atrTemp) <= 0)
   {
      if(prev_calculated == 0) return 0;   // prima volta: dati necessari
      return prev_calculated;              // tick successivi: mantieni rendering
   }

   //--- Copy MA values
   if(InpMAType == MA_HMA)
   {
      //--- HMA = WMA( 2*WMA(n/2) - WMA(n), sqrt(n) )
      if(ArraySize(g_hmaHalfValues) < rates_total)
      {
         ArrayResize(g_hmaHalfValues, rates_total);
         ArraySetAsSeries(g_hmaHalfValues, true);
      }
      if(ArraySize(g_hmaFullValues) < rates_total)
      {
         ArrayResize(g_hmaFullValues, rates_total);
         ArraySetAsSeries(g_hmaFullValues, true);
      }
      if(ArraySize(g_hmaIntermediate) < rates_total)
      {
         ArrayResize(g_hmaIntermediate, rates_total);
         ArraySetAsSeries(g_hmaIntermediate, true);
      }

      if(CopyBuffer(g_hmaHalfHandle, 0, 0, rates_total, g_hmaHalfValues) <= 0)
      {
         if(prev_calculated == 0) return 0;
         return prev_calculated;
      }
      if(CopyBuffer(g_hmaFullHandle, 0, 0, rates_total, g_hmaFullValues) <= 0)
      {
         if(prev_calculated == 0) return 0;
         return prev_calculated;
      }

      //--- Compute intermediate: 2*WMA(n/2) - WMA(n)
      for(int i = 0; i < rates_total; i++)
         g_hmaIntermediate[i] = 2.0 * g_hmaHalfValues[i] - g_hmaFullValues[i];

      //--- Apply WMA of period sqrt(n) to the intermediate
      int sqrtLen = (int)MathRound(MathSqrt((double)InpMALen));
      if(sqrtLen < 1) sqrtLen = 1;

      for(int i = 0; i < rates_total; i++)
      {
         if(i + sqrtLen <= rates_total)
            g_maValues[i] = ManualWMA(g_hmaIntermediate, i, sqrtLen, rates_total);
         else
            g_maValues[i] = g_hmaIntermediate[i];
      }
   }
   else
   {
      if(CopyBuffer(g_maHandle, 0, 0, rates_total, g_maValues) <= 0)
      {
         if(prev_calculated == 0) return 0;
         return prev_calculated;
      }
   }

   //--- Determinazione barra di partenza per il calcolo
   //
   //    COMPORTAMENTO TICK-PER-TICK (as-series, i=0 è la barra più recente):
   //
   //    prev_calculated == 0 (primo calcolo / cambio TF / ricalcolo):
   //      start = rates_total - InpLenDC - 3 → processa TUTTE le barre storiche
   //      Reset completo di TUTTI gli stati globali e oggetti grafici
   //
   //    Nuovo tick, stessa barra (prev_calculated == rates_total):
   //      start = 1 → loop processa i=1 (invariata) e i=0 (aggiornata)
   //
   //    Nuova barra (prev_calculated == rates_total - 1):
   //      start = 2 → loop processa i=2, i=1 (barra appena chiusa), i=0 (nuova)
   //      IMPORTANTE: i=1 è la barra che ERA i=0 al tick precedente.
   //      In FIRST_CANDLE mode, Fix #2 permette l'aggiornamento dello stato
   //      per i=1 (la barra è ora chiusa → dati definitivi).
   //
   int start;
   if(prev_calculated == 0)
   {
      Print("[DPC] prev_calculated=0 RESET | rates_total=", rates_total,
            " | themeApplied=", g_chartThemeApplied,
            " | objects=", ObjectsTotal(0));
      start = rates_total - InpLenDC - 3;
      g_lastMarkerBar  = 0;
      g_lastDirection  = 0;
      g_midlineTouched = false;
      g_midlineTouchBar = 0;

      //--- Reset SmartCooldown + TP tracking state
      g_lastSignalPrice     = 0;
      g_lastSignalBandPrice = 0;
      g_lastSignalTime      = 0;
      g_waitingForTP     = false;

      //--- Reset TP Target tracking (v7.02: multi-target)
      ArrayResize(g_activeTPTargets, 0);
      g_tpTargetCounter        = 0;
      g_tpHitCounter           = 0;

      //--- Reset Entry Dot tracking (v5.90)
      g_entryDotCounter        = 0;

      //--- Reset Touch Trigger tracking (v6.01)
      g_lastTouchDirection  = 0;
      g_lastTouchTriggerBar = 0;
      g_prevBarTimeTT       = 0;

      //--- Pulisci SOLO oggetti TP stateful (dipendono da variabili globali resettate sopra)
      //    Le frecce segnale e gli entry dot NON vengono cancellati qui:
      //    i loro nomi sono basati su time[i], quindi il loop li sovrascrive senza flickering.
      //    La pulizia completa è in OnDeinit() (cambio TF, rimozione indicatore, parametri).
      //    MOTIVO: prev_calculated==0 scatta anche per scroll/resize/nuovi dati broker,
      //    e cancellare+ricreare causa flickering visibile (frecce compaiono e spariscono).
      if(!g_isSubIndicator) DeleteTPTargetObjects();

      //--- Initialize EMA ATR array
      ArrayInitialize(g_emaATR, 0);
      ArrayInitialize(BufTouchTrigger, 0);
   }
   else
   {
      start = rates_total - prev_calculated + 1;
   }
   if(start < 0) start = 0;
   if(start > rates_total - InpLenDC - 3) start = rates_total - InpLenDC - 3;

   //--- Static variable for alert deduplication
   static datetime s_lastAlertBar = 0;

   //--- Main calculation loop (from oldest to newest in as-series)
   for(int i = start; i >= 0; i--)
   {
      //=== 1. Donchian Channel ===
      double highest = high[i];
      for(int k = 1; k < InpLenDC && (i + k) < rates_total; k++)
         if(high[i + k] > highest) highest = high[i + k];

      double lowest = low[i];
      for(int k = 1; k < InpLenDC && (i + k) < rates_total; k++)
         if(low[i + k] < lowest) lowest = low[i + k];

      BufUpper[i] = highest;
      BufLower[i] = lowest;
      BufMid[i]   = (highest + lowest) * 0.5;

      //--- MidOffset = dcMd[2] (midline 2 bars ago)
      BufMidOffset[i] = (i + 2 < rates_total) ? BufMid[i + 2] : BufMid[i];

      //--- Fill buffers
      BufFillUp[i] = BufUpper[i];
      BufFillDn[i] = BufLower[i];

      //--- Range for slope calculation
      g_rngArray[i] = BufUpper[i] - BufLower[i];

      //--- v7.10: Copia OHLC per DRAW_COLOR_CANDLES (Plot 10)
      //    Ogni barra ottiene i dati OHLC reali + colore bull/bear di default.
      //    Le candele trigger sovrascrivono BufCandleColor[i] = 2.0 più avanti.
      BufCandleO[i] = open[i];
      BufCandleH[i] = high[i];
      BufCandleL[i] = low[i];
      BufCandleC[i] = close[i];
      BufCandleColor[i] = (close[i] >= open[i]) ? 0.0 : 1.0;  // 0=bull, 1=bear

      //=== 2. Midline Color ===
      if(i + 2 < rates_total)
      {
         if(BufMid[i] > BufMid[i + 2])
            BufMidColor[i] = 0;  // lime (up)
         else if(BufMid[i] < BufMid[i + 2])
            BufMidColor[i] = 1;  // red (down)
         else
            BufMidColor[i] = (i + 1 < rates_total) ? BufMidColor[i + 1] : 0;
      }
      else
         BufMidColor[i] = 0;

      //=== 3. Moving Average ===
      if(InpShowMA || InpSignalFilter)
         BufMA[i] = InpShowMA ? g_maValues[i] : EMPTY_VALUE;
      else
         BufMA[i] = EMPTY_VALUE;

      //=== 4. ATR EMA(200) ===
      double atrVal = atrTemp[i];
      BufATR[i] = atrVal;
      double alpha = 2.0 / (200.0 + 1.0);
      if(i + 1 < rates_total && g_emaATR[i + 1] > 0)
         g_emaATR[i] = alpha * atrVal + (1.0 - alpha) * g_emaATR[i + 1];
      else
         g_emaATR[i] = atrVal;

      //=== 4.5 SmartCooldown: Check Midline Touch ===
      // v7.14c: Semplificato — solo logica SmartCooldown, nessun elemento visivo.
      // Il TP visivo è gestito SOLO da Section 4.6 (TP Target, midline FISSA).
      //
      // Controlla se il prezzo ha raggiunto la midline MOBILE dopo l'ultimo segnale.
      // Se sì: aggiorna stato SmartCooldown (g_midlineTouched) e resetta g_waitingForTP.

      if(g_waitingForTP && g_lastDirection != 0)
      {
         double midTarget = BufMid[i];

         bool midlineCrossed = false;
         if(g_lastDirection == +1 && high[i] >= midTarget)
            midlineCrossed = true;
         else if(g_lastDirection == -1 && low[i] <= midTarget)
            midlineCrossed = true;

         if(midlineCrossed)
         {
            if(InpUseSmartCooldown)
            {
               g_midlineTouched  = true;
               g_midlineTouchBar = rates_total - 1 - i;
            }
            g_waitingForTP = false;
         }
      }

      //=== 4.6 TP Target Line: Detection multi-target su livello FISSO (v7.02) ===
      // Loop al contrario su TUTTI i target attivi. Ogni target ha il suo livello
      // FISSO piazzato al momento del segnale. Quando il prezzo lo tocca, quel
      // singolo target viene chiuso (stella gialla). Gli altri restano attivi.
      //
      // Logica per-target:
      // - BUY: high[i] >= target price
      // - SELL: low[i] <= target price

      for(int t = ArraySize(g_activeTPTargets) - 1; t >= 0; t--)
      {
         bool tpTargetHit = false;

         if(g_activeTPTargets[t].isBuy && high[i] >= g_activeTPTargets[t].price)
            tpTargetHit = true;
         else if(!g_activeTPTargets[t].isBuy && low[i] <= g_activeTPTargets[t].price)
            tpTargetHit = true;

         if(tpTargetHit)
         {
            int signalBarI = iBarShift(_Symbol, PERIOD_CURRENT, g_activeTPTargets[t].signalTime);
            int barsToTP = (signalBarI >= 0) ? signalBarI - i : 0;

            double pipsMove = MathAbs(g_activeTPTargets[t].price - g_activeTPTargets[t].signalPrice) / _Point;
            if(_Digits == 5 || _Digits == 3)
               pipsMove /= 10.0;

            CloseTPTarget(t, time[i], barsToTP, pipsMove);
         }
         //--- v7.15: Scadenza TP target — dopo N barre diventa grigio e si ferma
         else if(InpTPTargetExpiry > 0)
         {
            int signalBarI_exp = iBarShift(_Symbol, PERIOD_CURRENT, g_activeTPTargets[t].signalTime);
            int barAge = (signalBarI_exp >= 0) ? signalBarI_exp - i : 0;
            if(barAge >= InpTPTargetExpiry)
            {
               string expLineName = g_activeTPTargets[t].lineName;
               string expDotName  = g_activeTPTargets[t].dotName;

               if(ObjectFind(0, expLineName) >= 0)
               {
                  ObjectSetInteger(0, expLineName, OBJPROP_COLOR, clrDarkGray);
                  ObjectSetInteger(0, expLineName, OBJPROP_STYLE, STYLE_DOT);
                  ObjectSetInteger(0, expLineName, OBJPROP_RAY_RIGHT, false);
                  ObjectMove(0, expLineName, 1, time[i], g_activeTPTargets[t].price);
               }
               if(ObjectFind(0, expDotName) >= 0)
                  ObjectSetInteger(0, expDotName, OBJPROP_COLOR, clrDarkGray);

               ArrayRemove(g_activeTPTargets, t, 1);
            }
         }
      }

      //=== 5. Signal Detection ===
      //
      //    ARCHITETTURA SEGNALI (4 fasi) — v7.13: solo FIRST_CANDLE
      //
      //    FASE 1 — Condizioni Base (bearBase / bullBase):
      //      Tocco diretto della banda: high[i] >= BufUpper[i] (SELL), low[i] <= BufLower[i] (BUY)
      //
      //    FASE 2 — Cooldown (bearCooldownOK / bullCooldownOK):
      //      SmartCooldown: differenzia stesso verso (richiede tocco midline) vs opposto
      //      Originale:     blocco fisso di InpLenDC barre dopo ogni segnale
      //
      //    FASE 3 — Condizione Finale (bearCond / bullCond):
      //      bearCond = bearBase && bearCooldownOK (MA filter delegato all'EA)
      //
      //    FASE 4 — Esecuzione Segnale:
      //      Freccia, buffer, TP Target, Entry Dot, Alert
      //      i=0: solo freccia e buffer (TP/Entry alla chiusura barra)
      //
      BufSignalUp[i]    = EMPTY_VALUE;
      BufSignalDn[i]    = EMPTY_VALUE;
      BufSignalUpBig[i] = EMPTY_VALUE;
      BufSignalDnBig[i] = EMPTY_VALUE;
      BufTouchTrigger[i] = 0;

      //--- Guard minima: accesso sicuro a [i] e [i+1] (necessari per fasi successive)
      //    v7.17: rimosso safeWindow (dead code dopo rimozione detection window)
      if(i + 2 < rates_total)
      {
         int currentBarIdx   = rates_total - 1 - i;
         int barsFromLast    = currentBarIdx - g_lastMarkerBar;

         //=== FASE 1: CONDIZIONI BASE (bearBase / bullBase) ===
         //
         //    bearBase = condizione preliminare per SELL (prezzo ha toccato upper band)
         //    bullBase = condizione preliminare per BUY  (prezzo ha toccato lower band)
         //
         //    v7.13: Solo FIRST_CANDLE — tocco DIRETTO sulla barra corrente.
         //    Il CLASSIC mode (tocco barre precedenti + rientrata + close>midline) è stato
         //    rimosso perché incompatibile con la lettura Buffer 18 da parte dell'EA.
         //    Il codice CLASSIC è commentato più sotto (/* ... */) per riferimento.
         //
         bool bearBase = false;
         bool bullBase = false;

         //--- v7.13: Solo FIRST_CANDLE (CLASSIC rimosso)
         //    Segnale sulla candela che TOCCA la banda (v6.01)
         //
         //    Matematica: BufUpper[i] = max(high[i], high[i+1], ..., high[i+N-1])
         //    Quindi high[i] >= BufUpper[i] è vera SOLO quando high[i] È il massimo
         //    del periodo Donchian → il prezzo è ESATTAMENTE sulla upper band.
         //
         //    Nessuna rientrata richiesta, nessun filtro close<midline.
         //    Questi filtri sono delegati all'EA alla conferma (chiusura barra).
         //
         bearBase = (high[i] >= BufUpper[i]);   // high tocca/sfonda upper → SELL
         bullBase = (low[i] <= BufLower[i]);     // low tocca/sfonda lower → BUY

         //--- Anti-ambiguità (Fix #3): candela che tocca ENTRAMBE le bande → skip
         //    Caso raro (flash crash / candle enorme). Coerente con Section 5b.
         if(bearBase && bullBase)
         {
            bearBase = false;
            bullBase = false;
         }

         /* v7.13: CLASSIC mode commentato — codice mantenuto per riferimento.
            In CLASSIC il segnale richiedeva: tocco banda nelle barre precedenti + rientrata + close oltre midline.
         {
            bool bearTouched = false;
            for(int k = 1; k <= safeWindow; k++)
            {
               if((i + k) < rates_total)
               {
                  if(high[i + k] >= BufUpper[i + k])
                  {
                     bearTouched = true;
                     break;
                  }
               }
            }

            bearBase = bearTouched &&
                            (high[i] < BufUpper[i]) &&
                            (close[i] > BufMid[i]);

            bool bullTouched = false;
            for(int k = 1; k <= safeWindow; k++)
            {
               if((i + k) < rates_total)
               {
                  if(low[i + k] <= BufLower[i + k])
                  {
                     bullTouched = true;
                     break;
                  }
               }
            }

            bullBase = bullTouched &&
                            (low[i] > BufLower[i]) &&
                            (close[i] < BufMid[i]);

            if(bearBase && bullBase)
            {
               bearBase = false;
               bullBase = false;
            }
         }
         Fine CLASSIC mode commentato */

         //╔═════════════════════════════════════════════════════════════════╗
         //║  BAND FLATNESS FILTER — Sezione 5 (main loop, barre storiche)   ║
         //╚═════════════════════════════════════════════════════════════════╝
         //
         //  SCOPO: Bloccare segnali mean-reversion quando il mercato è in trend.
         //
         //  COME RILEVA IL TREND:
         //    La banda Donchian è piatta in range → la upper non sale, la lower non scende.
         //    In trend rialzista → la upper band SALE (nuovi massimi entrano nella finestra 20).
         //    In trend ribassista → la lower band SCENDE (nuovi minimi entrano nella finestra 20).
         //    Se il movimento supera una soglia proporzionale all'ATR → trend rilevato → BLOCCA.
         //
         //  INDICI (array as-series, i=0 è la barra più recente):
         //    [i]     = barra corrente (quella dove il segnale potrebbe scattare)
         //    [i+1]   = 1 barra fa (la più recente delle barre precedenti)
         //    [i+k]   = k barre fa (k va da 1 a flatLookback)
         //    rates_total = numero totale di barre nel buffer
         //
         //  FORMULA SELL (bearBase → tocco della upper band):
         //    soglia = InpFlatnessTolerance × ATR(14)[i]
         //    Per k = 1, 2, ..., flatLookback:
         //      SE BufUpper[i] > BufUpper[i+k] + soglia → la upper è SALITA troppo → BLOCCA
         //    Basta che UNA SOLA delle k barre rilevi espansione → il segnale viene bloccato.
         //
         //  FORMULA BUY (bullBase → tocco della lower band):
         //    Per k = 1, 2, ..., flatLookback:
         //      SE BufLower[i] < BufLower[i+k] - soglia → la lower è SCESA troppo → BLOCCA
         //
         //  PERCHÉ ">" E NON "!=":
         //    La upper band può solo SALIRE o restare uguale (il massimo di 20 barre
         //    non può diminuire a meno che il massimo più vecchio esca dalla finestra).
         //    Quando la upper SCENDE, significa che un vecchio massimo è uscito → la banda
         //    si CONTRAE → il mercato si consolida → il segnale è VALIDO (non bloccato).
         //    Stessa logica invertita per la lower band.
         //
         //  GUARDIA BOUNDARY: (i + k) < rates_total
         //    Evita accesso fuori array quando la barra corrente è vicina alla fine
         //    del buffer (barre più vecchie del dataset caricato).
         //
         //  CLAMP: MathMax(1, MathMin(10, InpFlatLookback))
         //    Forza il lookback nell'intervallo [1, 10] anche se l'utente inserisce
         //    valori fuori range (es. 0 o 99). Previene loop infiniti o vuoti.
         //
         if(InpUseBandFlatness && BufATR[i] > 0)
         {
            //--- Calcolo soglia: proporzionale alla volatilità corrente
            //    Esempio EURUSD M15: ATR(14) ≈ 12 pip → soglia = 0.25 × 12 = 3 pip
            //    Se la upper è salita di più di 3 pip → trend attivo → blocca SELL
            double flatTolerance = InpFlatnessTolerance * BufATR[i];

            //--- Clamp del lookback: forza nel range [1, 10]
            int flatLookback = (int)MathMax(1, MathMin(10, InpFlatLookback));

            //--- SELL: verifica che la UPPER BAND non sia in espansione
            //    bearBase = true significa che il prezzo ha toccato la upper band
            //    e il segnale SELL è candidato. Il filtro lo blocca se la upper
            //    è salita oltre la soglia rispetto ad ALMENO UNA delle ultime N barre.
            if(bearBase)
            {
               for(int k = 1; k <= flatLookback && (i + k) < rates_total; k++)
               {
                  //--- BufUpper[i] = livello ATTUALE della upper band
                  //    BufUpper[i+k] = livello di k barre fa
                  //    Se la differenza supera la soglia → la banda si è ESPANSA
                  //    (nuovo massimo è entrato nella finestra 20-bar → trend rialzista)
                  if(BufUpper[i] > BufUpper[i + k] + flatTolerance)
                  {
                     bearBase = false;  // Segnale SELL bloccato: trend rialzista attivo
                     break;             // Basta una sola barra che rilevi espansione
                  }
               }
            }

            //--- BUY: verifica che la LOWER BAND non sia in espansione (discesa)
            //    bullBase = true significa che il prezzo ha toccato la lower band
            //    e il segnale BUY è candidato. Il filtro lo blocca se la lower
            //    è scesa oltre la soglia rispetto ad ALMENO UNA delle ultime N barre.
            if(bullBase)
            {
               for(int k = 1; k <= flatLookback && (i + k) < rates_total; k++)
               {
                  //--- BufLower[i] = livello ATTUALE della lower band
                  //    BufLower[i+k] = livello di k barre fa
                  //    Se la differenza supera la soglia → la banda si è ESPANSA
                  //    (nuovo minimo è entrato nella finestra 20-bar → trend ribassista)
                  if(BufLower[i] < BufLower[i + k] - flatTolerance)
                  {
                     bullBase = false;  // Segnale BUY bloccato: trend ribassista attivo
                     break;             // Basta una sola barra che rilevi espansione
                  }
               }
            }
         }

         //--- TREND CONTEXT FILTER v7.12 — Blocca segnali contro macro-trend
         //
         //    PERCHÉ SERVE:
         //    Il Band Flatness guarda solo 3 barre (15 min su M5). Un downtrend "a gradini"
         //    (lower scende 5 pip ogni 5-8 barre, con pause flat nel mezzo) bypassa il filtro:
         //    durante le pause il Flatness dice "ok" e accetta BUY controtendenza.
         //
         //    COME FUNZIONA:
         //    Misura lo spostamento della MIDLINE tra la barra corrente [i] e InpLenDC barre fa.
         //    La midline = (Upper+Lower)/2 rappresenta il "centro" del canale Donchian.
         //    Se si è spostata troppo in una direzione → macro-trend attivo → blocca il segnale
         //    nella direzione opposta (contro-trend).
         //
         //    FORMULA:
         //    threshold = InpTrendContextMultiple × ATR(14)   (default: 1.5 × ATR)
         //    BUY bloccato se: midline[InpLenDC barre fa] - midline[ora] > threshold  (scesa)
         //    SELL bloccato se: midline[ora] - midline[InpLenDC barre fa] > threshold  (salita)
         //
         //    ESEMPIO GBPUSD M5 (ATR ~7 pip, Multiple=1.5):
         //    threshold = 1.5 × 7 = 10.5 pip
         //    Downtrend forte: midline scende 50 pip in 20 barre → 50 >> 10.5 → BLOCCA BUY
         //    Range laterale: midline si sposta 2-3 pip in 20 barre → 3 < 10.5 → PASSA
         //
         //    COMPLEMENTARITÀ CON BAND FLATNESS:
         //    Band Flatness: finestra 3 barre  → trend locale  (15 min su M5)
         //    Trend Context: finestra 20 barre → trend macro   (100 min su M5)
         //    Insieme: copertura completa da breve a medio termine.
         //
         //    GUARD CONDITIONS:
         //    - InpUseTrendContext: l'utente può disabilitarlo (default OFF)
         //    - BufATR[i] > 0: evita divisione/moltiplicazione con ATR nullo (prime barre)
         //    - (i + InpLenDC) < rates_total: evita accesso fuori array
         //
         if(InpUseTrendContext && BufATR[i] > 0 && (i + InpLenDC) < rates_total)
         {
            double trendThreshold = InpTrendContextMultiple * BufATR[i];
            double midNow  = BufMid[i];              // midline della barra corrente
            double midThen = BufMid[i + InpLenDC];   // midline InpLenDC barre fa

            //--- Blocca BUY se midline SCESA di > threshold (macro-trend ribassista)
            //    midThen > midNow significa che la midline era PIÙ ALTA in passato → scesa
            if(bullBase && (midThen - midNow) > trendThreshold)
               bullBase = false;

            //--- Blocca SELL se midline SALITA di > threshold (macro-trend rialzista)
            //    midNow > midThen significa che la midline è PIÙ ALTA ora → salita
            if(bearBase && (midNow - midThen) > trendThreshold)
               bearBase = false;
         }

         //--- LEVEL AGE FILTER v7.12 — Maturità del livello Donchian (FLAT_BARS)
         //
         //    Regola Raschke ("Street Smarts" 1995): il livello deve essere "stabilito".
         //    Conta barre consecutive di banda piatta PRIMA del segnale.
         //    Banda piatta = stop-loss accumulati = Soup più probabile.
         //    Tolleranza: 2 * _Point per arrotondamenti floating-point.
         //
         //    v7.17: rimossa modalità ORIGINAL (incompatibile con FIRST_CANDLE —
         //    il tocco crea il nuovo estremo → age sempre 0 → bloccava tutto).
         //
         if(InpUseLevelAge)
         {
            if(bearBase)
            {
               int flatBars = 0;
               double upperLevel = BufUpper[i];
               for(int k = 1; k < InpLenDC && (i + k) < rates_total; k++)
               {
                  if(MathAbs(BufUpper[i + k] - upperLevel) <= 2 * _Point)
                     flatBars++;
                  else
                     break;
               }
               if(flatBars < g_minLevelAge)
                  bearBase = false;
            }

            if(bullBase)
            {
               int flatBars = 0;
               double lowerLevel = BufLower[i];
               for(int k = 1; k < InpLenDC && (i + k) < rates_total; k++)
               {
                  if(MathAbs(BufLower[i + k] - lowerLevel) <= 2 * _Point)
                     flatBars++;
                  else
                     break;
               }
               if(flatBars < g_minLevelAge)
                  bullBase = false;
            }
         }

         //--- CHANNEL WIDTH FILTER v7.05: skip se il canale è troppo stretto (in PIP)
         //    PIP = _Point × 10 per 5-digit broker (EURUSD), _Point per 4-digit.
         //    Se (upper - lower) in pip < InpMinWidthPips → blocca tutto.
         if(InpUseWidthFilter)
         {
            double pipSize = (_Digits == 5 || _Digits == 3) ? _Point * 10.0 : _Point;
            double channelWidthPips = (BufUpper[i] - BufLower[i]) / pipSize;
            if(channelWidthPips < InpMinWidthPips)
            {
               bearBase = false;
               bullBase = false;
            }
         }

         //--- FILTRO ORARIO v7.05: blocca segnali nella fascia oraria configurata
         //    I TP Target già aperti NON vengono toccati (Section 4.5 e 4.6 continuano).
         //    Solo la generazione di NUOVI segnali viene bloccata.
         if(IsInBlockedTime(time[i]))
         {
            bearBase = false;
            bullBase = false;
         }

         //=== FASE 2: COOLDOWN (bearCooldownOK / bullCooldownOK) ===
         //
         //    Il cooldown impedisce segnali troppo ravvicinati.
         //    barsFromLast = barre trascorse dall'ultimo segnale CONFERMATO.
         //
         //    SmartCooldown (InpUseSmartCooldown=true):
         //      Stesso verso (es. SELL dopo SELL): richiede tocco midline + N barre
         //      Direzione opposta (es. SELL dopo BUY): solo N barre minime
         //      Primo segnale (g_lastDirection=0): sempre accettato
         //
         //    Originale (InpUseSmartCooldown=false):
         //      Blocco fisso di InpLenDC barre dopo ogni segnale (Zeiierman originale)
         //
         bool bearCooldownOK = false;
         bool bullCooldownOK = false;

         if(!InpUseSmartCooldown)
         {
            //--- MODALITÀ ORIGINALE ZEIIERMAN: cooldown fisso di lenDC barre
            bearCooldownOK = (barsFromLast >= InpLenDC);
            bullCooldownOK = (barsFromLast >= InpLenDC);
         }
         else
         {
            //--- SMARTCOOLDOWN: logica differenziata per direzione
            if(g_lastDirection == 0)
            {
               // Nessun segnale precedente → primo segnale sempre accettato
               bearCooldownOK = true;
               bullCooldownOK = true;
            }
            else
            {
               // ── BEAR (SELL) = direzione -1 ──
               if(g_lastDirection == -1)
               {
                  // Stesso verso (SELL dopo SELL): richiede tocco midline + N barre
                  if(InpRequireMidTouch)
                     bearCooldownOK = g_midlineTouched &&
                                      (currentBarIdx - g_midlineTouchBar >= g_nSameBars);
                  else
                     bearCooldownOK = (barsFromLast >= g_nSameBars);
               }
               else  // g_lastDirection == +1
               {
                  // Direzione opposta (SELL dopo BUY): solo barre minime
                  bearCooldownOK = (barsFromLast >= g_nOppositeBars);
               }

               // ── BULL (BUY) = direzione +1 ──
               if(g_lastDirection == +1)
               {
                  // Stesso verso (BUY dopo BUY): richiede tocco midline + N barre
                  if(InpRequireMidTouch)
                     bullCooldownOK = g_midlineTouched &&
                                      (currentBarIdx - g_midlineTouchBar >= g_nSameBars);
                  else
                     bullCooldownOK = (barsFromLast >= g_nSameBars);
               }
               else  // g_lastDirection == -1
               {
                  // Direzione opposta (BUY dopo SELL): solo barre minime
                  bullCooldownOK = (barsFromLast >= g_nOppositeBars);
               }
            }
         }

         //=== FASE 3: CONDIZIONE FINALE = Base + Cooldown [+ MA] ===
         bool bearCond = bearBase && bearCooldownOK;
         bool bullCond = bullBase && bullCooldownOK;

         //--- MA filter (v7.00): supporta logica CLASSICA e INVERTITA
         //    CLASSICO: close < MA per SELL, close > MA per BUY (trend-following)
         //    INVERTITO: close > MA per SELL, close < MA per BUY (mean-reversion Soup)
         //
         //    v7.13: QUESTO BLOCCO NON VIENE MAI ESEGUITO (if(false)).
         //    Motivo: in FIRST_CANDLE il close[0] è provvisorio (cambia ad ogni tick).
         //    Il filtro MA viene delegato ALL'EA al momento della conferma (chiusura barra).
         //    L'EA deve controllare se close[1] > MA (BUY) o close[1] < MA (SELL)
         //    prima di aprire la posizione.
         //    Il blocco è mantenuto nel codice per documentare la logica che l'EA deve replicare.
         //
         if(false && InpSignalFilter)  // v7.13: CLASSIC rimosso — MA filter delegato all'EA
         {
            double maVal = g_maValues[i];
            if(InpMAFilterMode == MA_FILTER_CLASSIC)
            {
               // Trend-following: SELL sotto MA, BUY sopra MA (Zeiierman originale)
               bearCond = bearCond && (close[i] < maVal);
               bullCond = bullCond && (close[i] > maVal);
            }
            else  // MA_FILTER_INVERTED
            {
               // Mean-reversion Soup: SELL quando overextended SOPRA MA, BUY quando SOTTO MA
               bearCond = bearCond && (close[i] > maVal);
               bullCond = bullCond && (close[i] < maVal);
            }
         }

         //--- Debug: logga DOPO tutti i filtri (cooldown + MA) — v7.03: fix per modalità invertita
         if(InpDebugCooldown && (bearBase || bullBase))
         {
            string mode = InpUseSmartCooldown ? "SMART" : "ORIGINAL";
            string dir  = (g_lastDirection == +1) ? "BUY" : (g_lastDirection == -1) ? "SELL" : "NONE";
            double maVal = g_maValues[i];

            if(bearBase)
            {
               bool maOK_s = (InpMAFilterMode == MA_FILTER_CLASSIC) ? (close[i] < maVal) : (close[i] > maVal);
               Print("[DPC ", mode, "] SELL base=OK cooldown=", (bearCooldownOK ? "OK" : "BLOCK"),
                     " MA=", (InpSignalFilter ? (maOK_s ? "OK" : "BLOCK") : "OFF"),
                     " MAmode=", (InpMAFilterMode == MA_FILTER_CLASSIC ? "CL" : "INV"),
                     " FINAL=", (bearCond ? "ACCETTATO" : "BLOCCATO"),
                     " | barsFromLast=", barsFromLast, " lastDir=", dir,
                     " midTouched=", g_midlineTouched,
                     " close=", DoubleToString(close[i], _Digits),
                     " MA=", DoubleToString(maVal, _Digits),
                     " mid=", DoubleToString(BufMid[i], _Digits));
            }

            if(bullBase)
            {
               bool maOK_b = (InpMAFilterMode == MA_FILTER_CLASSIC) ? (close[i] > maVal) : (close[i] < maVal);
               Print("[DPC ", mode, "] BUY base=OK cooldown=", (bullCooldownOK ? "OK" : "BLOCK"),
                     " MA=", (InpSignalFilter ? (maOK_b ? "OK" : "BLOCK") : "OFF"),
                     " MAmode=", (InpMAFilterMode == MA_FILTER_CLASSIC ? "CL" : "INV"),
                     " FINAL=", (bullCond ? "ACCETTATO" : "BLOCCATO"),
                     " | barsFromLast=", barsFromLast, " lastDir=", dir,
                     " midTouched=", g_midlineTouched,
                     " close=", DoubleToString(close[i], _Digits),
                     " MA=", DoubleToString(maVal, _Digits),
                     " mid=", DoubleToString(BufMid[i], _Digits));
            }
         }

         double offset = g_emaATR[i] * InpArrowOffsetMult;  // v7.15: offset configurabile (default 1.5x EMA ATR)

         //=== FASE 4: ESECUZIONE SEGNALE SELL (bearCond) ===
         //
         //    Struttura del blocco (identica per bullCond):
         //
         //    1. GUARDIA FIX #2: stato cooldown — if(i >= 1)
         //       La barra live (i=0) ha dati PROVVISORI (high/low/close cambiano ogni tick).
         //       Se aggiornassimo g_lastMarkerBar a i=0, il cooldown si resetterebbe
         //       e IMPEDIREBBE il re-processing quando la barra chiude (diventa i=1).
         //       Soluzione: lo stato viene aggiornato SOLO per barre chiuse (i >= 1).
         //
         //    2. FRECCIA + BUFFER: sempre eseguiti (anche su i=0)
         //       La freccia usa time[i] come suffisso nome → ObjectCreate sovrascrive.
         //       BufSignalDn[i] è un buffer dati, sovrascritto senza accumulo.
         //       Su i=0 la freccia appare/scompare ad ogni tick (feedback visivo live).
         //
         //    3. GUARDIA TP/ENTRY: TP tracking, TP Target Line, Entry Dot — if(i >= 1)
         //       SKIP per i=0 perché bearCond si attiva ad OGNI TICK (Fix #2 non blocca
         //       il cooldown su barra live). Creare TP/Entry ad ogni tick causerebbe
         //       accumulo di centinaia di oggetti grafici.
         //       Quando la barra chiude (i=1), bearCond scatta UNA VOLTA → crea TP/Entry.
         //
         //    4. ALERT: protezione duplicati tramite s_lastAlertBar
         //
         if(bearCond)
         {
            //--- [GUARDIA FIX #2] Aggiornamento stato cooldown
            //    In FIRST_CANDLE, i=0 è la barra live con dati provvisori.
            //    Se aggiornassimo g_lastMarkerBar qui, il cooldown si resetterebbe
            //    e impedirebbe il re-processing a i=1 quando la barra chiude.
            //    La guardia salta l'aggiornamento per i=0, ma lo permette per i>=1.
            if(i >= 1)  // v7.13: FIRST_CANDLE only — skip stato per barra live (i=0)
            {
               g_lastMarkerBar     = currentBarIdx;
               g_lastDirection    = -1;
               g_midlineTouched   = false;
               g_midlineTouchBar  = 0;
            }

            double sellPrice    = BufUpper[i] + offset;
            BufSignalDn[i]      = sellPrice;

            //--- Calcola dati tooltip (v7.00)
            double wRatio_s = (BufATR[i] > 0) ? (BufUpper[i] - BufLower[i]) / BufATR[i] : 0;

            //--- Crea freccia SELL rossa ⬇ con etichetta e tooltip
            CreateSignalArrow(time[i], sellPrice, false, offset, close[i], BufMid[i],
                             wRatio_s, true);

            //--- Candela Trigger: colora la candela di giallo via DRAW_COLOR_CANDLES (v7.10)
            //    BufCandleColor[i] = 2.0 → color index 2 = InpColTriggerCandle (giallo)
            //    La candela viene disegnata dal Plot 10 con lo stesso rendering engine di MT5
            //    → larghezza pixel-perfect, identica alle altre candele a qualsiasi zoom.
            if(InpShowTriggerCandle)
               BufCandleColor[i] = 2.0;

            //--- TP, Entry Dot, TP Target: skip su barra live in FIRST_CANDLE
            //    In FIRST_CANDLE bearCond si attiva ad OGNI TICK per i=0 (Fix #2 impedisce
            //    l'aggiornamento di g_lastMarkerBar → cooldown non blocca mai).
            //    Senza questa guardia: CreateTPTarget e Entry Dot si accumulerebbero ad ogni tick.
            //    Vengono creati quando la barra chiude e viene riprocessata con i=1.
            if(i >= 1)  // v7.13: FIRST_CANDLE only — skip per barra live
            {
               //--- SmartCooldown: salva stato segnale per check midline touch (Section 4.5)
               g_lastSignalTime      = time[i];
               g_lastSignalPrice     = sellPrice;
               g_lastSignalBandPrice = BufUpper[i];
               g_waitingForTP        = true;

               //--- TP Target Line: piazza pallino + linea orizzontale sulla midline (v7.02: multi-target)
               CreateTPTarget(time[i], BufMid[i], false, sellPrice);

               //--- Entry Dot: diamante blu al prezzo di ingresso (sulla upper band = punto di tocco)
               if(InpShowEntryDot && !g_isSubIndicator)
               {
                  g_entryDotCounter++;
                  string entDotName = ENTRY_DOT_PREFIX + "SELL_" + IntegerToString(g_entryDotCounter);
                  double entryPrice_dot = BufUpper[i];  // v7.13: sempre banda (FIRST_CANDLE)
                  ObjectCreate(0, entDotName, OBJ_ARROW, 0, time[i], entryPrice_dot);
                  ObjectSetInteger(0, entDotName, OBJPROP_ARROWCODE, 164);
                  ObjectSetInteger(0, entDotName, OBJPROP_COLOR, InpColEntryDot);
                  ObjectSetInteger(0, entDotName, OBJPROP_WIDTH, 2);
                  ObjectSetInteger(0, entDotName, OBJPROP_ANCHOR, ANCHOR_BOTTOM);  // v7.03b: diamante centrato sul bordo upper band
                  ObjectSetInteger(0, entDotName, OBJPROP_BACK, false);
                  ObjectSetString(0, entDotName, OBJPROP_TOOLTIP,
                     "ENTRY SELL @ " + DoubleToString(entryPrice_dot, _Digits));
               }
            }

            //--- Alert (only on new bar, bar index 0)
            if(i == 0 && time[0] != s_lastAlertBar)
            {
               s_lastAlertBar = time[0];
               string msg = "Donchian Predictive: Segnale SELL su " + _Symbol + " " + EnumToString(_Period);
               if(InpAlertPopup && !g_isSubIndicator) Alert(msg);
            }
         }

         //=== FASE 4: ESECUZIONE SEGNALE BUY (bullCond) ===
         //    Struttura identica al blocco bearCond (vedi commenti sopra).
         //    Differenze: direzione +1, freccia BUY verde, buyPrice = BufLower - offset.
         if(bullCond)
         {
            //--- [GUARDIA FIX #2] Stato cooldown: skip per barra live i=0 (dati provvisori)
            if(i >= 1)  // v7.13: FIRST_CANDLE only — skip stato per barra live (i=0)
            {
               g_lastMarkerBar     = currentBarIdx;
               g_lastDirection    = +1;
               g_midlineTouched   = false;
               g_midlineTouchBar  = 0;
            }

            double buyPrice     = BufLower[i] - offset;
            BufSignalUp[i]      = buyPrice;

            //--- Calcola dati tooltip (v7.00)
            double wRatio_b = (BufATR[i] > 0) ? (BufUpper[i] - BufLower[i]) / BufATR[i] : 0;

            //--- Crea freccia BUY verde ⬆ con etichetta e tooltip
            CreateSignalArrow(time[i], buyPrice, true, offset, close[i], BufMid[i],
                             wRatio_b, true);

            //--- Candela Trigger: colora la candela di giallo (v7.10, stessa logica SELL)
            if(InpShowTriggerCandle)
               BufCandleColor[i] = 2.0;

            //--- TP, Entry Dot, TP Target: skip su barra live in FIRST_CANDLE
            //    (stessa guardia del blocco SELL — vedi commento sopra)
            if(i >= 1)  // v7.13: FIRST_CANDLE only — skip per barra live
            {
               //--- SmartCooldown: salva stato segnale per check midline touch (Section 4.5)
               g_lastSignalTime      = time[i];
               g_lastSignalPrice     = buyPrice;
               g_lastSignalBandPrice = BufLower[i];
               g_waitingForTP        = true;

               //--- TP Target Line: piazza pallino + linea orizzontale sulla midline (v7.02: multi-target)
               CreateTPTarget(time[i], BufMid[i], true, buyPrice);

               //--- Entry Dot: diamante blu al prezzo di ingresso (sulla lower band = punto di tocco)
               if(InpShowEntryDot && !g_isSubIndicator)
               {
                  g_entryDotCounter++;
                  string entDotName = ENTRY_DOT_PREFIX + "BUY_" + IntegerToString(g_entryDotCounter);
                  double entryPrice_dot = BufLower[i];  // v7.13: sempre banda (FIRST_CANDLE)
                  ObjectCreate(0, entDotName, OBJ_ARROW, 0, time[i], entryPrice_dot);
                  ObjectSetInteger(0, entDotName, OBJPROP_ARROWCODE, 164);
                  ObjectSetInteger(0, entDotName, OBJPROP_COLOR, InpColEntryDot);
                  ObjectSetInteger(0, entDotName, OBJPROP_WIDTH, 2);
                  ObjectSetInteger(0, entDotName, OBJPROP_BACK, false);
                  ObjectSetString(0, entDotName, OBJPROP_TOOLTIP,
                     "ENTRY BUY @ " + DoubleToString(entryPrice_dot, _Digits));
               }
            }

            //--- Alert (only on new bar, bar index 0)
            if(i == 0 && time[0] != s_lastAlertBar)
            {
               s_lastAlertBar = time[0];
               string msg = "Donchian Predictive: Segnale BUY su " + _Symbol + " " + EnumToString(_Period);
               if(InpAlertPopup && !g_isSubIndicator) Alert(msg);
            }
         }
      }
   }

   //=== 5a. Reset Touch Trigger (Fix #1) — nuova barra → azzera anti-duplicato ===
   //
   //    Quando si apre una nuova barra, g_lastTouchDirection viene resettato a 0.
   //    Questo permette a Section 5b di emettere un nuovo trigger sulla nuova barra.
   //    Senza questo reset, il trigger della barra precedente bloccherebbe la nuova.
   //
   //    NOTA: g_prevBarTimeTT è una variabile globale (non static) per permettere
   //    il reset in prev_calculated==0 (cambio TF, ricalcolo completo).
   //
   //    v7.13: con CLASSIC rimosso, Section 5b è sempre attiva → questo reset è essenziale.
   //
   {
      if(time[0] != g_prevBarTimeTT)
      {
         g_prevBarTimeTT = time[0];
         g_lastTouchDirection = 0;
      }
   }

   //=== 5b. TOUCH TRIGGER — Buffer 18 per EA (solo FIRST_CANDLE, v6.01) ===
   //
   //    SCOPO: Scrivere +1 (BUY) o -1 (SELL) nel Buffer 18 al PRIMO TICK che tocca
   //    la banda Donchian. L'EA legge CopyBuffer(handle, 18, 0, 1, val) ad ogni tick
   //    e può piazzare ordini PRIMA della chiusura della candela.
   //
   //    DIFFERENZA CON SECTION 5:
   //    - Section 5 (main loop) crea frecce visive e buffer dati per TUTTE le barre (i=0..start)
   //    - Section 5b scrive SOLO nel Buffer 18 per bar 0 (barra live)
   //    - Section 5b usa lo stato CONFERMATO (g_lastMarkerBar non corrotto da Fix #2)
   //
   //    ANTI-DUPLICATO:
   //    - g_lastTouchTriggerBar = time[0] del trigger emesso
   //    - g_lastTouchDirection = direzione del trigger (+1 o -1)
   //    - Tick successivi: alreadyTriggeredThisBar = TRUE → else mantiene valore
   //    - Nuova barra: Fix #1 resetta g_lastTouchDirection → nuovo trigger possibile
   //
   //    FILTRI APPLICATI: Cooldown, Detection Window, Midline Touch, Anti-ambiguità
   //    FILTRI DELEGATI ALL'EA: MA filter, close<midline (close[0] provvisorio)
   //
   //    PRIORITÀ EMISSIONE (Fix #3):
   //    1. Entrambe bande toccate → ambiguo → BufTouchTrigger = 0
   //    2. Tocco corrente Lower + cooldown → BUY (+1)
   //    3. Tocco corrente Upper + cooldown → SELL (-1)
   //    4. Tocco da window Lower + cooldown → BUY (fallback)
   //    5. Tocco da window Upper + cooldown → SELL (fallback)
   //
   //    v7.13: CLASSIC rimosso — Section 5b sempre attiva (solo FIRST_CANDLE).
   //
   if(rates_total > InpLenDC + 3)  // v7.13: guard semplificato (CLASSIC rimosso)
   {
      //--- Anti-duplicato: un solo trigger per barra, mantenuto per tutti i tick successivi
      bool alreadyTriggeredThisBar = (g_lastTouchTriggerBar == time[0] && g_lastTouchDirection != 0);

      if(!alreadyTriggeredThisBar)
      {
         int currentBarIdx_touch = rates_total - 1;
         int barsFromLast_touch  = currentBarIdx_touch - g_lastMarkerBar;

         //--- Cooldown (copia identica della sezione 5)
         bool bearCooldownOK_touch = false;
         bool bullCooldownOK_touch = false;

         if(!InpUseSmartCooldown)
         {
            //--- Modalità originale: cooldown fisso
            bearCooldownOK_touch = (barsFromLast_touch >= InpLenDC);
            bullCooldownOK_touch = (barsFromLast_touch >= InpLenDC);
         }
         else
         {
            //--- SmartCooldown
            if(g_lastDirection == 0)
            {
               bearCooldownOK_touch = true;
               bullCooldownOK_touch = true;
            }
            else
            {
               // BEAR (SELL) = direzione -1
               if(g_lastDirection == -1)
               {
                  if(InpRequireMidTouch)
                     bearCooldownOK_touch = g_midlineTouched &&
                                            (currentBarIdx_touch - g_midlineTouchBar >= g_nSameBars);
                  else
                     bearCooldownOK_touch = (barsFromLast_touch >= g_nSameBars);
               }
               else
               {
                  bearCooldownOK_touch = (barsFromLast_touch >= g_nOppositeBars);
               }

               // BULL (BUY) = direzione +1
               if(g_lastDirection == +1)
               {
                  if(InpRequireMidTouch)
                     bullCooldownOK_touch = g_midlineTouched &&
                                            (currentBarIdx_touch - g_midlineTouchBar >= g_nSameBars);
                  else
                     bullCooldownOK_touch = (barsFromLast_touch >= g_nSameBars);
               }
               else
               {
                  bullCooldownOK_touch = (barsFromLast_touch >= g_nOppositeBars);
               }
            }
         }

         //--- Detection: tocco bande sulla barra corrente
         bool currentBarTouchLower = (low[0] <= BufLower[0]);
         bool currentBarTouchUpper = (high[0] >= BufUpper[0]);

         //--- Detection: tocco bande su [0] (barra live) + fallback [1] (ultima chiusa)
         //    v7.17: rimosso loop multi-barra (g_detectionWindow) per allineare Section 5b a Section 5.
         //    Section 5 usa solo [i] → Section 5b deve usare solo [0] + fallback [1].
         //    Il fallback [1] copre il caso in cui l'EA non legge il buffer prima della chiusura.
         bool bullTouched_touch = currentBarTouchLower;
         bool bearTouched_touch = currentBarTouchUpper;

         if(!bullTouched_touch && rates_total >= 2)
         {
            if(low[1] <= BufLower[1])
               bullTouched_touch = true;
         }
         if(!bearTouched_touch && rates_total >= 2)
         {
            if(high[1] >= BufUpper[1])
               bearTouched_touch = true;
         }

         //╔═════════════════════════════════════════════════════════════════╗
         //║  BAND FLATNESS FILTER — Sezione 5b (Touch Trigger, real-time)   ║
         //╚═════════════════════════════════════════════════════════════════╝
         //
         //  DIFFERENZA CON SEZIONE 5:
         //    Sezione 5 processa barre STORICHE nel loop (indice [i], dove i va da start a 0).
         //    Sezione 5b processa la barra LIVE (indice [0]) ad ogni tick — solo FIRST_CANDLE.
         //
         //  PERCHÉ USA [1] E NON [0]:
         //    BufUpper[0] è la banda Donchian della barra corrente (in formazione).
         //    Ad ogni tick, il Donchian[0] può cambiare se il tick crea un nuovo high/low.
         //    Questo renderebbe il filtro instabile: BLOCCA un tick, PASSA il successivo.
         //    Usando [1] (ultima barra CHIUSA), il confronto è stabile e definitivo.
         //
         //  INDICI (as-series):
         //    [1]     = ultima barra chiusa (stabile, non cambia più)
         //    [1+k]   = k barre chiuse fa (k va da 1 a flatLookback)
         //    Con lookback=3: confronta [1] vs [2], [3], [4]
         //
         //  FORMULA: identica alla Sezione 5, ma con base [1] invece di [i]:
         //    soglia = InpFlatnessTolerance × ATR(14)[1]
         //    SELL: SE BufUpper[1] > BufUpper[1+k] + soglia → BLOCCA
         //    BUY:  SE BufLower[1] < BufLower[1+k] - soglia → BLOCCA
         //
         //  EFFETTI AGGIUNTIVI DEL BLOCCO:
         //    Quando il filtro blocca, resetta ANCHE il flag currentBarTouchUpper/Lower.
         //    Questo impedisce che il Touch Trigger scriva +1/-1 nel Buffer 18,
         //    evitando che l'EA riceva un segnale che il filtro avrebbe bloccato.
         //
         //  GUARDIA BOUNDARY: ((1 + InpFlatLookback) < rates_total)
         //    Con lookback=10, il filtro accede fino a [1+10] = [11].
         //    Se rates_total < 12, l'accesso sarebbe fuori array → guardia pre-loop.
         //    Il loop interno ha una guardia ridondante (1+k) < rates_total per sicurezza.
         //
         if(InpUseBandFlatness && ((1 + InpFlatLookback) < rates_total) && BufATR[1] > 0)
         {
            //--- Soglia basata su ATR della barra [1] (chiusa, stabile)
            double flatTolerance_t = InpFlatnessTolerance * BufATR[1];
            int flatLookback_t = (int)MathMax(1, MathMin(10, InpFlatLookback));

            //--- SELL Touch Trigger: verifica espansione upper band
            if(bearTouched_touch)
            {
               for(int k = 1; k <= flatLookback_t && (1 + k) < rates_total; k++)
               {
                  //--- Confronto: upper band chiusa [1] vs upper band [1+k] (k barre fa)
                  if(BufUpper[1] > BufUpper[1 + k] + flatTolerance_t)
                  {
                     bearTouched_touch = false;    // Blocca segnale SELL touch
                     currentBarTouchUpper = false;  // Resetta flag per Buffer 18 (EA)
                     break;
                  }
               }
            }

            //--- BUY Touch Trigger: verifica espansione (discesa) lower band
            if(bullTouched_touch)
            {
               for(int k = 1; k <= flatLookback_t && (1 + k) < rates_total; k++)
               {
                  //--- Confronto: lower band chiusa [1] vs lower band [1+k] (k barre fa)
                  if(BufLower[1] < BufLower[1 + k] - flatTolerance_t)
                  {
                     bullTouched_touch = false;    // Blocca segnale BUY touch
                     currentBarTouchLower = false;  // Resetta flag per Buffer 18 (EA)
                     break;
                  }
               }
            }
         }

         //--- TREND CONTEXT FILTER v7.12 per Touch Trigger
         //
         //    PERCHÉ USA [1] ANZICHÉ [0]:
         //    Section 5b opera sulla barra LIVE (bar 0). Il close[0], high[0], e quindi
         //    BufMid[0] cambiano ad OGNI TICK → il filtro oscillerebbe tra PASSA/BLOCCA.
         //    Usando BufMid[1] (ultima barra CHIUSA) il valore è STABILE e DEFINITIVO.
         //    BufATR[1] è stabile per lo stesso motivo.
         //    La logica è identica alla Section 5, solo gli indici cambiano.
         if(InpUseTrendContext && BufATR[1] > 0 && (1 + InpLenDC) < rates_total)
         {
            double trendThreshold_t = InpTrendContextMultiple * BufATR[1];
            double midNow_t  = BufMid[1];
            double midThen_t = BufMid[1 + InpLenDC];

            //--- Blocca BUY touch: midline scesa
            if(bullTouched_touch && (midThen_t - midNow_t) > trendThreshold_t)
            {
               bullTouched_touch  = false;
               currentBarTouchLower = false;
            }
            //--- Blocca SELL touch: midline salita
            if(bearTouched_touch && (midNow_t - midThen_t) > trendThreshold_t)
            {
               bearTouched_touch  = false;
               currentBarTouchUpper = false;
            }
         }

         //--- LEVEL AGE FILTER v7.12 per Touch Trigger (FLAT_BARS)
         //    Usa BufUpper[1]/BufLower[1] (barra chiusa, stabile).
         //    v7.17: rimossa modalità ORIGINAL (incompatibile con FIRST_CANDLE).
         //
         if(InpUseLevelAge)
         {
            if(bearTouched_touch)
            {
               int flatBars_t = 0;
               double upperLvl_t = BufUpper[1];
               for(int k = 1; k < InpLenDC && (1 + k) < rates_total; k++)
               {
                  if(MathAbs(BufUpper[1 + k] - upperLvl_t) <= 2 * _Point)
                     flatBars_t++;
                  else
                     break;
               }
               if(flatBars_t < g_minLevelAge)
               {
                  bearTouched_touch  = false;
                  currentBarTouchUpper = false;
               }
            }

            if(bullTouched_touch)
            {
               int flatBars_t = 0;
               double lowerLvl_t = BufLower[1];
               for(int k = 1; k < InpLenDC && (1 + k) < rates_total; k++)
               {
                  if(MathAbs(BufLower[1 + k] - lowerLvl_t) <= 2 * _Point)
                     flatBars_t++;
                  else
                     break;
               }
               if(flatBars_t < g_minLevelAge)
               {
                  bullTouched_touch  = false;
                  currentBarTouchLower = false;
               }
            }
         }

         //--- CHANNEL WIDTH FILTER per Touch Trigger v7.05 (in PIP)
         if(InpUseWidthFilter)
         {
            double pipSize_t = (_Digits == 5 || _Digits == 3) ? _Point * 10.0 : _Point;
            double channelWidthPips_t = (BufUpper[0] - BufLower[0]) / pipSize_t;
            if(channelWidthPips_t < InpMinWidthPips)
            {
               bearTouched_touch = false;
               bullTouched_touch = false;
               currentBarTouchUpper = false;
               currentBarTouchLower = false;
            }
         }

         //--- FILTRO ORARIO per Touch Trigger (v7.05)
         if(IsInBlockedTime(time[0]))
         {
            bearTouched_touch = false;
            bullTouched_touch = false;
            currentBarTouchUpper = false;
            currentBarTouchLower = false;
         }

         //--- Priorità emissione (Fix #3)
         //    1. Entrambe bande toccate su barra corrente → ambiguo → skip
         //    2. Tocco corrente Lower + cooldown → BUY
         //    3. Tocco corrente Upper + cooldown → SELL
         //    4. Tocco da window Lower + cooldown → BUY (fallback)
         //    5. Tocco da window Upper + cooldown → SELL (fallback)
         if(currentBarTouchLower && currentBarTouchUpper)
         {
            BufTouchTrigger[0] = 0;  // ambiguo: entrambe le bande toccate
         }
         else if(currentBarTouchLower && bullCooldownOK_touch)
         {
            BufTouchTrigger[0] = +1;
            g_lastTouchTriggerBar = time[0];
            g_lastTouchDirection  = +1;
         }
         else if(currentBarTouchUpper && bearCooldownOK_touch)
         {
            BufTouchTrigger[0] = -1;
            g_lastTouchTriggerBar = time[0];
            g_lastTouchDirection  = -1;
         }
         else if(bullTouched_touch && bullCooldownOK_touch)
         {
            BufTouchTrigger[0] = +1;
            g_lastTouchTriggerBar = time[0];
            g_lastTouchDirection  = +1;
         }
         else if(bearTouched_touch && bearCooldownOK_touch)
         {
            BufTouchTrigger[0] = -1;
            g_lastTouchTriggerBar = time[0];
            g_lastTouchDirection  = -1;
         }
      }
      else
      {
         //--- Mantenimento valore per tick successivi (alreadyTriggeredThisBar == TRUE)
         //    Il loop principale (Section 5) ha resettato BufTouchTrigger[0] = 0 (riga 1591).
         //    Qui ripristiniamo il valore del trigger già emesso su questa barra,
         //    in modo che l'EA lo trovi costante ad ogni tick fino alla chiusura.
         //    Sequenza: Tick 1 → emette +1 → Tick 2..N → mantiene +1 → nuova barra → reset (Fix #1)
         if(g_lastTouchDirection == +1)
            BufTouchTrigger[0] = +1;
         else if(g_lastTouchDirection == -1)
            BufTouchTrigger[0] = -1;
      }
   }

   //=== 6. Forecast Projection (only on last bar = barstate.islast) ===
   {
      static datetime s_lastForecastBar = 0;
      if(time[0] != s_lastForecastBar)
      {
         s_lastForecastBar = time[0];

         double midSlope = LinearRegressionSlope(BufMid, 0, InpLenDC, rates_total);
         double rngSlope = LinearRegressionSlope(g_rngArray, 0, InpLenDC, rates_total);

         DrawForecast(time, rates_total,
                      BufUpper[0], BufMid[0], BufLower[0],
                      midSlope, rngSlope);
      }
   }

   //=== 7. Redraw transparent canvas fills (throttled: new bar only) ===
   //    CCanvas disegna i fill ARGB trasparenti (canale DC + midline).
   //    DRAW_FILLING di MQL5 NON supporta trasparenza ARGB (alpha ignorato).
   //    CCanvas è l'UNICA soluzione per fill trasparenti.
   //    Scroll/zoom gestito da OnChartEvent(CHARTEVENT_CHART_CHANGE).
   {
      static datetime s_lastCanvasBar = 0;
      if(time[0] != s_lastCanvasBar)
      {
         s_lastCanvasBar = time[0];
         RedrawCanvas();
      }
   }

   return rates_total;
}
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
