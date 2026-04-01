//+------------------------------------------------------------------+
//| DonchianPredictiveChannel.mq5                                    |
//| Donchian Predictive Channel - MQ5 Port                           |
//| Original Pine Script v6 by Zeiierman (CC BY-NC-SA 4.0)           |
//| MQ5 Port by TIVANIO                                              |
//+------------------------------------------------------------------+
#property copyright   "TIVANIO - Donchian Predictive Channel (MQ5 Port)"
#property version     "7.19"   // v7.19 — FlatTol per-TF preset, TBS/TWS colori separati, LTF Entry Signal (Buffer 20)
#property description "Donchian Predictive Channel con proiezione forecast e segnali BUY/SELL"
#property description "Basato sull'indicatore Pine Script v6 di Zeiierman"
#property description "Portato su MQ5 da TIVANIO"
#property description "Per il Donchian Multi-Timeframe: usare DonchianChannelMTF.mq5"
#property indicator_chart_window
#property indicator_buffers 21     // v7.19: 21 buffer (era 20 in v7.18) — Buffer 20 = LTF Entry Signal
#property indicator_plots   11     // 11 plot invariati (Buffer 16-20 sono tutti INDICATOR_CALCULATIONS)
//
//+------------------------------------------------------------------+
//| CHANGELOG v7.19 — Novità rispetto a v7.18                        |
//+------------------------------------------------------------------+
//
//  NUOVA FUNZIONALITÀ #1: g_flatTol_eff — Tolleranza Flatness per TF
//  ─────────────────────────────────────────────────────────────────
//    PROBLEMA v7.18: InpFlatnessTolerance era FISSO (0.55) per tutti i TF.
//      Su M5 (ATR~8pip): soglia 4.4pip → troppo permissiva, segnali in trend passano
//      Su H4 (ATR~50pip): soglia 27.5pip → quasi tutto è flat, filtro quasi inutile
//
//    SOLUZIONE v7.19: g_flatTol_eff calibrato per TF via Auto TF Preset (MOD-03/04).
//      Il moltiplicatore DECRESCE con il TF perché i trend su TF alti sono più persistenti.
//      L'utente in modalità MANUALE mantiene pieno controllo via InpFlatnessTolerance.
//
//    VALORI PRESET:
//      M5:  0.40  (ATR~8pip  → soglia 3.2pip  — filtra micro-trend scalping)
//      M15: 0.50  (ATR~12pip → soglia 6.0pip  — standard intraday)
//      M30: 0.50  (ATR~15pip → soglia 7.5pip  — standard swing corto)
//      H1:  0.38  (ATR~25pip → soglia 9.5pip  — filtra trend H1 marcati)
//      H4:  0.35  (ATR~50pip → soglia 17.5pip — solo flat netti, trend H4 bloccati)
//      MAN: InpFlatnessTolerance (default 0.55 — retrocompatibile v7.18)
//
//  NUOVA FUNZIONALITÀ #2: Colori TBS/TWS separati (MOD-08/14)
//  ─────────────────────────────────────────────────────────────────
//    PROBLEMA v7.18: TBS e TWS avevano lo stesso colore freccia (InpColSignalUp/Dn).
//      L'utente non poteva distinguere visivamente la qualità del segnale.
//
//    SOLUZIONE v7.19: 4 input colore separati (InpColTBS_Buy/Sell, InpColTWS_Buy/Sell).
//      TBS (corpo sfonda) = colore pieno (lime/red) → segnale forte, va preso.
//      TWS (solo wick)    = colore attenuato (verde scuro/rosso scuro) → cautela.
//      CreateSignalArrow usa ternario signalPattern→colore (nessun impatto su Buffer 18/19).
//
//    FILTRO OPZIONALE (InpShowTWSSignals):
//      TRUE  (default) = mostra tutte le frecce come prima.
//      FALSE = nasconde frecce TWS + label OBJ_TEXT + trigger candle.
//              Buffer 18/19 restano scritti → l'EA riceve tutti i segnali.
//              TP Target, Entry Dot, Alert restano attivi anche per TWS nascosti.
//
//  NUOVA FUNZIONALITÀ #3: LTF Entry Signal — Buffer 20 (MOD-07/09/10/11/12/16)
//  ─────────────────────────────────────────────────────────────────
//    SCOPO: Fornire all'EA una conferma ANTICIPATA della rejection sulla banda,
//    basata su una candela del TF inferiore (LTF) chiusa che tocca il livello banda
//    del TF principale e chiude dentro il canale (rejection confermata su LTF).
//
//    TRIGGER: Section 5b emette Buffer 18 (touch trigger) → apre finestra LTF.
//    CONFERMA: Prima barra LTF chiusa (shift=1) con high/low >= band E close dentro.
//    DURATA: La finestra scade dopo 1 barra del TF principale (PeriodSeconds).
//    PERSISTENZA: BufLTFEntry[0] = ±1 mantenuto per tutti i tick della barra confermata
//                 (pattern identico a BufTouchTrigger con g_lastTouchDirection).
//    ANTI-RIAPERTURA: g_ltfConfirmedBar impedisce apertura multipla sulla stessa barra.
//
//    BUFFER 20 (INDICATOR_CALCULATIONS):
//      +1.0 = BUY confermato LTF  |  -1.0 = SELL confermato LTF  |  0.0 = nessuno
//      L'EA legge: CopyBuffer(handle, 20, 0, 1, val)
//      NOTA: CopyBuffer FUNZIONA con INDICATOR_CALCULATIONS (verificato MQL5 docs).
//
//    TF MAPPING: M5→M1, M15→M5, M30→M5, H1→M15, H4→M30
//
//  MIGLIORAMENTO #4: MinWidth M5 alzato da 5.0 a 7.0 pip (MOD-02)
//  ─────────────────────────────────────────────────────────────────
//    Con minWidth=5.0, il TP target (metà canale) = 2.5 pip ≤ spread EURUSD M5 (~1.5-2 pip).
//    Con 7.0: TP minimo = 3.5 pip > spread → trade potenzialmente profittevoli.
//
//  IMPATTO EA:
//    Buffer 0-19: ZERO modifiche ai valori o al significato.
//    Buffer 20: NUOVO (opt-in). EA v7.18 che legge solo Buffer 18-19 funziona identico.
//    Segnali: potenzialmente -10-15% su H1/H4 per flatTol più restrittivo.
//

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
//| ARCHITETTURA INDICATORE v7.18 — Guida Completa                   |
//+------------------------------------------------------------------+
//
// ╔═══════════════════════════════════════════════════════════════════╗
// ║               DONCHIAN PREDICTIVE CHANNEL v7.18                  ║
// ║        Indicatore Turtle Soup per MetaTrader 5 (MQL5)            ║
// ╠═══════════════════════════════════════════════════════════════════╣
// ║                                                                   ║
// ║  STRATEGIA: Turtle Soup (Linda Bradford Raschke, 1995)           ║
// ║  Il prezzo tocca la banda Donchian (massimo/minimo di 20 barre)  ║
// ║  ma CHIUDE DENTRO il canale → i breakout trader sono intrappolati║
// ║  → il prezzo torna verso la midline (mean reversion).            ║
// ║                                                                   ║
// ║  FUNZIONALITA' PRINCIPALI:                                        ║
// ║  1. Canale Donchian (20 barre) con bande, midline, fill ARGB    ║
// ║  2. Segnali BUY/SELL non-repainting (BAR_CLOSE mode)            ║
// ║  3. Classificazione pattern TBS/TWS (corpo vs wick)              ║
// ║  4. 6 sistemi di filtro indipendenti e combinabili               ║
// ║  5. SmartCooldown direction-aware con tocco midline              ║
// ║  6. Proiezione forecast (cono basato su regressione lineare)     ║
// ║  7. TP Target multi-target con backtest visivo                   ║
// ║  8. Candele trigger evidenziate (DRAW_COLOR_CANDLES)             ║
// ║  9. Auto TF Preset per M5/M15/M30/H1/H4                        ║
// ║  10. Tema chart scuro con salvataggio/ripristino automatico      ║
// ║  11. Buffer 18+19 per comunicazione con EA                       ║
// ║                                                                   ║
// ║  6 SISTEMI DI FILTRO:                                             ║
// ║  ┌──────────────────┬─────────────────────────────────────────┐  ║
// ║  │ Filtro            │ Cosa blocca                             │  ║
// ║  ├──────────────────┼─────────────────────────────────────────┤  ║
// ║  │ Band Flatness     │ Segnali su bande in espansione (trend) │  ║
// ║  │ Trend Context     │ Segnali contro macro-trend (20 barre)  │  ║
// ║  │ Level Age         │ Segnali su livelli troppo recenti      │  ║
// ║  │ Channel Width     │ Segnali su canali troppo stretti       │  ║
// ║  │ Time Block        │ Segnali in fasce orarie volatili       │  ║
// ║  │ MA Filter         │ Segnali overextended (solo BAR_CLOSE)  │  ║
// ║  └──────────────────┴─────────────────────────────────────────┘  ║
// ║                                                                   ║
// ║  ELEMENTI VISIVI:                                                 ║
// ║  - Bande Donchian (DRAW_LINE, blu)                               ║
// ║  - Midline color-switch (DRAW_COLOR_LINE, lime/red)              ║
// ║  - Fill canale trasparente (CCanvas, ARGB)                       ║
// ║  - Frecce segnale (DRAW_ARROW, sempre visibili)                  ║
// ║  - Label "TRIGGER BUY/SELL [TBS/TWS]" (OBJ_TEXT + tooltip)      ║
// ║  - Candele trigger gialle (DRAW_COLOR_CANDLES)                   ║
// ║  - Entry Dot blu (OBJ_ARROW diamante)                            ║
// ║  - TP Target Line tratteggiata + stella gialla al hit            ║
// ║  - Forecast a cono (OBJ_TREND tratteggiato)                     ║
// ║  - MA opzionale (DRAW_LINE, nascondibile)                        ║
// ║                                                                   ║
// ║  COMUNICAZIONE CON EA:                                            ║
// ║  Buffer 18 (BufTouchTrigger): +1=BUY, -1=SELL, 0=nessuno       ║
// ║  Buffer 19 (BufSignalType): 3.0=TBS, 1.0=TWS, 0.0=nessuno     ║
// ║  L'EA legge con CopyBuffer(handle, 18/19, 0, 1, val)           ║
// ║                                                                   ║
// ╚═══════════════════════════════════════════════════════════════════╝
//
//
// ┌─────────────────────────────────────────────────────────────────┐
// │                   MAPPA DEI 20 BUFFER (v7.18)                 │
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
// │ 19      │ BufSignalType   — Pattern segnale (CALCULATIONS)   │
// │         │                   3.0=TBS, 1.0=TWS, 0.0=nessuno   │
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
// │    5b. Touch Trigger    — Buffer 18 per EA (INTRABAR/BAR_CLOSE)│
// │ 6. Forecast Projection  — Linee proiezione (solo bar 0)       │
// │ 7. Canvas Redraw        — Fill trasparenti CCanvas             │
// └─────────────────────────────────────────────────────────────────┘
//
// ┌─────────────────────────────────────────────────────────────────┐
// │     MODALITÀ TRIGGER: INTRABAR / BAR_CLOSE (v7.18)             │
// ├─────────────────────────────────────────────────────────────────┤
// │                                                                 │
// │ v7.18: Due modalità trigger (ENUM_TRIGGER_MODE_V2):            │
// │                                                                 │
// │ INTRABAR (legacy FIRST_CANDLE):                                │
// │   - Segnale IMMEDIATO al TOCCO della banda Donchian            │
// │   - bearBase = high[i] >= BufUpper[i] (tocco diretto)          │
// │   - Repaint possibile su barra live (i=0)                      │
// │   - MA filter disattivato (close instabile intrabar)           │
// │                                                                 │
// │ BAR_CLOSE (raccomandato, default v7.18):                       │
// │   - Segnale solo alla CHIUSURA della barra (i>=1)              │
// │   - bearBase = high>=upper AND close<upper (rejection)         │
// │   - bullBase = low<=lower AND close>lower (rejection)          │
// │   - Zero repaint: close[i] è definitivo per i>=1               │
// │   - MA filter riattivato (close stabile su barra chiusa)       │
// │   - TBS/TWS classification: Buffer 19 (3.0=TBS, 1.0=TWS)     │
// │                                                                 │
// │ EA legge: Buffer 18 (+1 BUY, -1 SELL), Buffer 19 (pattern)    │
// │                                                                 │
// │ GUARDIE (3 Fix, valide per entrambe le modalità):               │
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

//--- v7.18: Modalità Trigger V2 — due modalità di generazione segnali
//
//    Sostituisce il vecchio ENUM_TRIGGER_MODE (v7.13, solo FIRST_CANDLE).
//    Controlla QUANDO il segnale viene generato rispetto alla vita della barra:
//
//    INTRABAR (= legacy FIRST_CANDLE v6.01-v7.17):
//      Segnale IMMEDIATO non appena high/low tocca la banda Donchian.
//      → Veloce, ma PUÒ REPAINTARE: se la barra poi chiude oltre la banda
//        (breakout vero), il segnale scompare retroattivamente.
//      → Il filtro MA è DISATTIVATO (close[0] cambia ad ogni tick → inaffidabile).
//      → La classificazione TBS/TWS NON è disponibile (body non definito su barra aperta).
//      → Usato da EA che vogliono entrare PRIMA della chiusura (scalping aggressivo).
//
//    BAR_CLOSE (★ raccomandato, default v7.18):
//      Segnale SOLO alla CHIUSURA della barra (i >= 1 nel main loop).
//      → Zero repaint: il close è DEFINITIVO, il segnale non cambia mai.
//      → Richiede rejection: tocco banda + chiusura DENTRO il canale (non breakout).
//        SELL: high[i] >= upper AND close[i] < upper
//        BUY:  low[i]  <= lower AND close[i] > lower
//      → Il filtro MA è ATTIVO (close stabile → confronto affidabile con MA).
//      → La classificazione TBS/TWS è ATTIVA (body definitivo → pattern leggibile).
//      → Usato da EA che vogliono segnali confermati (swing trading, posizionale).
//
enum ENUM_TRIGGER_MODE_V2
{
   TRIGGER_INTRABAR   = 0,  // Intrabar (segnale immediato al tocco — repaints su barra live)
   TRIGGER_BAR_CLOSE  = 1   // Chiusura Barra (segnale confermato — zero repaint, raccomandato)
};

//--- v7.18: Preset parametri per timeframe — dropdown nelle impostazioni
//
//    Seleziona quale preset applicare ai parametri chiave dell'indicatore.
//    AUTO = rileva automaticamente il TF del chart e applica il preset corrispondente.
//    M5/M15/M30/H1/H4 = forza un preset specifico indipendentemente dal TF del chart.
//      Utile per: testare preset di un TF diverso, ottimizzazione, chart offline.
//    MANUALE = nessun preset, tutti i parametri controllati dall'utente.
//      Utile per: Strategy Tester, coppie esotiche, TF non standard (M1, D1, etc.).
//
//    Parametri sovrascritti dal preset:
//      Periodo MA, Larghezza Minima Canale, Barre Stesso/Opposto Verso, Lookback Flatness.
//    Il Periodo Donchian (20) NON viene sovrascritto — è universale.
//
enum ENUM_TF_PRESET
{
   TF_PRESET_AUTO    = 0,  // AUTO — rileva TF dal chart (raccomandato)
   TF_PRESET_M1      = 7,  // M1   — preset backtest/entry precision (disabilitare LTF Entry!)
   TF_PRESET_M5      = 1,  // M5   — preset scalping (MA=50, MinW=7pip)
   TF_PRESET_M15     = 2,  // M15  — preset intraday ottimale (MA=34, MinW=10pip)
   TF_PRESET_M30     = 3,  // M30  — preset intraday lento (MA=24, MinW=12pip)
   TF_PRESET_H1      = 4,  // H1   — preset swing (MA=18, MinW=18pip)
   TF_PRESET_H4      = 5,  // H4   — preset posizionale (MA=12, MinW=30pip)
   TF_PRESET_MANUAL  = 6   // MANUALE — tutti i parametri dall'utente
};

enum ENUM_MA_FILTER_MODE
{
   MA_FILTER_CLASSIC  = 0,  // Classico (BUY se close > MA — trend following)
   MA_FILTER_INVERTED = 1   // Invertito (BUY se close < MA — mean reversion Soup)
};

//--- v7.18: Classificazione pattern candela segnale (Turtle Soup)
//
//    Classifica la QUALITÀ del tocco banda in base alla penetrazione del corpo vs wick.
//    Scritto nel Buffer 19 come valore double: 3.0 (TBS), 1.0 (TWS), 0.0 (nessuno).
//    L'EA può leggere: CopyBuffer(handle, 19, shift, count, val) per filtrare per qualità.
//    Classificazione possibile SOLO su barre chiuse (close definitivo → body definito).
//
//    TBS (Turtle Bar Soup) — valore 3:
//      Il CORPO della candela sfonda la banda e poi la barra chiude DENTRO il canale.
//      → SELL: MathMax(open, close) > upper (body high sopra upper)
//      → BUY:  MathMin(open, close) < lower (body low sotto lower)
//      → Pattern FORTE: il prezzo ha avuto una escursione significativa oltre la banda
//        ma i trader sono rimasti intrappolati (trapped), il mercato ha rifiutato il breakout.
//      → Storicamente associato a inversioni più nette e target raggiunti con più frequenza.
//
//    TWS (Turtle Wick Soup) — valore 1:
//      SOLO lo wick (shadow) sfonda la banda, il corpo resta DENTRO il canale.
//      → SELL: high >= upper ma MathMax(open, close) <= upper (solo shadow sopra)
//      → BUY:  low <= lower ma MathMin(open, close) >= lower (solo shadow sotto)
//      → Pattern DEBOLE: sondaggio timido della banda, rejection meno convincente.
//      → Segnale valido ma con probabilità di successo inferiore al TBS.
//
//    I valori sono NON consecutivi (1, 3) per permettere future estensioni intermedie
//    (es. PATTERN_PINBAR = 2 per pin bar con wick molto lungo).
//
enum ENUM_SIGNAL_PATTERN
{
   PATTERN_NONE = 0,  // Nessun pattern (barra live o nessun segnale)
   PATTERN_TWS  = 1,  // TWS — solo wick sfonda la banda, corpo dentro (debole)
   PATTERN_TBS  = 3   // TBS — corpo sfonda la banda e rientra (forte, raccomandato)
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

input ENUM_TF_PRESET  InpTFPreset       = TF_PRESET_AUTO;  // ⚙ Preset Timeframe
// ↑ v7.18: SELEZIONA IL PRESET PARAMETRI PER IL TIMEFRAME
//
// ↑ PROBLEMA RISOLTO: I parametri espressi in "barre" (MALen=30, NSameBars=3, etc.)
//   hanno effetti DRASTICAMENTE diversi su timeframe diversi.
//   Esempio: MALen=30 su M5 = 30×5min = 2.5 ore, su H1 = 30×60min = 30 ore!
//
// ↑ AUTO (★ raccomandato) = rileva il TF del chart e applica il preset corrispondente.
//   Se il TF del chart non ha un preset (M1, D1, etc.) → fallback a MANUALE.
//
// ↑ M5 / M15 / M30 / H1 / H4 = forza un preset specifico indipendentemente dal chart.
//   Utile per testare preset di un TF diverso, chart offline, o ottimizzazione.
//
// ↑ MANUALE = nessun preset. L'utente controlla TUTTI i parametri.
//   Utile per: Strategy Tester, coppie esotiche, TF non standard.
//
//   Parametri sovrascritti dal preset:
//     Periodo MA, Larghezza Minima, Barre Stesso/Opposto, Lookback Flatness.
//     Il Periodo Donchian (20) NON viene modificato.
//
//   ┌──────┬──────┬────────┬───────┬───────┬────────┐
//   │  TF  │ MA   │MinWidth│nSame  │nOpp   │FlatLook│
//   │      │(barre)│(pip)   │(barre)│(barre)│(barre) │
//   ├──────┼──────┼────────┼───────┼───────┼────────┤
//   │ M5   │  50  │  5.0   │   3   │   2   │   3    │
//   │ M15  │  34  │ 10.0   │   2   │   2   │   3    │
//   │ M30  │  24  │ 14.0   │   2   │   1   │   2    │
//   │ H1   │  18  │ 18.0   │   1   │   1   │   2    │
//   │ H4   │  12  │ 30.0   │   1   │   1   │   1    │
//   └──────┴──────┴────────┴───────┴───────┴────────┘

input int             InpLenDC          = 20;          // Periodo Donchian (alto=meno segnali, basso=più reattivo)
input int             InpProjLen        = 30;          // Barre Proiezione (alto=cono ampio, basso=breve termine)

//═══════════════════════════════════════════════════════════════════
//  SEZIONE 2: FILTRO SEGNALI (Media Mobile direzionale)
//═══════════════════════════════════════════════════════════════════
input group "                                                               "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  📈 MEDIA MOBILE (visiva + configurazione EA)             ║"
input group "╚═══════════════════════════════════════════════════════════╝"
//    L'indicatore DISEGNA la MA sul chart.
//    v7.18: In BAR_CLOSE mode, il filtro MA è ATTIVO nell'indicatore (close stabile).
//    In INTRABAR mode, il filtro è DELEGATO all'EA (close[0] provvisorio).

input bool            InpSignalFilter   = true;        // Filtra Segnali con MA
// ↑ v7.18: Comportamento diverso in base alla modalità trigger:
//   BAR_CLOSE: il filtro MA è ATTIVO NELL'INDICATORE (close stabile → confronto affidabile).
//     L'indicatore blocca i segnali che non passano il filtro MA PRIMA di scriverli nei buffer.
//     L'EA riceve SOLO segnali già filtrati (riduzione falsi segnali a monte).
//   INTRABAR: il filtro MA è DISATTIVATO nell'indicatore (close[0] provvisorio).
//     L'EA deve applicare il filtro MA autonomamente alla conferma (chiusura barra).
// ↑ ON = filtra BUY/SELL con la MA. OFF = tutti i segnali passano (nessun filtro MA).

input ENUM_MA_FILTER_MODE InpMAFilterMode = MA_FILTER_INVERTED;  // Modalità Filtro MA
// ↑ CLASSICO (trend-following): BUY solo se close > MA, SELL solo se close < MA.
//   Logica originale Zeiierman. Funziona per trend-following, ma BLOCCA i segnali Soup migliori.
// ↑ INVERTITO (mean-reversion/Soup): BUY solo se close < MA, SELL solo se close > MA.
//   ★ RACCOMANDATO per Turtle Soup.
//   Logica: se il prezzo è OVEREXTENDED rispetto alla MA, è maturo per un ritorno al centro.
// ↑ NOTA v7.18: in modalità INTRABAR il filtro MA è DISATTIVATO dall'indicatore (close instabile).
//   In modalità BAR_CLOSE il filtro MA è ATTIVO nell'indicatore (close definitivo su barra chiusa).

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
input int             InpNSameBars        = 2;         // Stesso Verso: Barre Attesa dopo Midline (1-10)
// ↑ DOPO che il prezzo ha toccato la midline, quante barre attendere prima di accettare
//   un nuovo segnale nella stessa direzione. Su M15: 3 barre = 45 min. Su M5: 3 barre = 15 min.

input group "    ↔️ DIREZIONE OPPOSTA (es. SELL dopo BUY)"
input int             InpNOppositeBars    = 1;         // Segnale Opposto: Barre Minime di Attesa (1-10)
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

input double          InpFlatnessTolerance  = 0.85;      // Tolleranza espansione banda (multiplo ATR)
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

input int             InpFlatLookback       = 2;         // Lookback barre filtro flatness (1-10)
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

input double          InpMinWidthPips     = 7.0;       // Larghezza minima canale (pip)
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
//  SEZIONE 3b: MODALITÀ TRIGGER E CLASSIFICAZIONE (v7.18)
//═══════════════════════════════════════════════════════════════════
input group "                                                               "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  ⚡ MODALITÀ TRIGGER                                     ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input ENUM_TRIGGER_MODE_V2 InpTriggerModeV2 = TRIGGER_BAR_CLOSE;  // Modalità Trigger
// ↑ v7.18: Seleziona QUANDO l'indicatore genera il segnale BUY/SELL.
//   Impatto diretto su: repaint, affidabilità, classificazione pattern, filtro MA.
//
// ↑ INTRABAR: segnale al tocco della banda Donchian (high>=upper o low<=lower).
//   Il segnale appare DURANTE la formazione della barra, al primo tick che tocca.
//   ⚠ REPAINT: se la barra poi chiude OLTRE la banda (breakout vero),
//   il segnale scompare quando la barra successiva ricalcola i=1.
//   → Filtro MA: DISATTIVATO (close[0] provvisorio, cambierebbe ogni tick).
//   → TBS/TWS: NON disponibile (corpo della candela non ancora definito).
//   → EA via Buffer 18: riceve il segnale AD OGNI TICK finché il tocco persiste.
//   → Comportamento identico a FIRST_CANDLE delle versioni v6.01-v7.17.
//   → Caso d'uso: scalping aggressivo dove la velocità di ingresso è prioritaria.
//
// ↑ BAR_CLOSE (★ raccomandato): segnale SOLO alla CHIUSURA della barra.
//   Il segnale compare quando la barra chiude e viene processata con i=1.
//   ✓ ZERO REPAINT: il segnale non cambia mai dopo la comparsa.
//   Condizioni di attivazione (Turtle Soup rejection):
//     SELL: high[i] >= BufUpper[i] AND close[i] < BufUpper[i]
//           → il prezzo ha TOCCATO/SFONDATO la upper band, ma ha CHIUSO DENTRO.
//     BUY:  low[i]  <= BufLower[i] AND close[i] > BufLower[i]
//           → il prezzo ha TOCCATO/SFONDATO la lower band, ma ha CHIUSO DENTRO.
//   Se il close è OLTRE la banda = breakout vero → NESSUN segnale (corretto).
//   → Filtro MA: ATTIVO (close[i] definitivo → confronto con MA affidabile).
//   → TBS/TWS: ATTIVO (corpo definitivo → classificazione pattern possibile).
//   → EA via Buffer 18: riceve il segnale sulla barra [1] (chiusa), stabile.
//   → Caso d'uso: swing trading, posizionale, EA che confermano alla chiusura.
//
// ┌─────────────────────────────────────────────────────────────────────┐
// │  FLUSSO SEGNALE v7.18 (indicatore → EA):                          │
// │                                                                     │
// │  1. Il prezzo tocca la banda Donchian (high >= upper o low <= lower)│
// │  2. BAR_CLOSE: verifica close dentro canale (rejection, non break) │
// │  3. L'indicatore verifica i filtri:                                 │
// │     - SmartCooldown (distanza dall'ultimo segnale)                  │
// │     - Band Flatness (la banda non si sta espandendo)               │
// │     - Level Age (il livello è stabilizzato da N barre)             │
// │     - Trend Context (nessun macro-trend contro il segnale)         │
// │     - Channel Width (il canale è abbastanza largo per il TP)       │
// │     - MA Filter (solo BAR_CLOSE: close stabile su barra chiusa)   │
// │  4. Se tutti i filtri passano → Buffer 18 = +1 (BUY) o -1 (SELL)  │
// │  5. Buffer 19 = tipo pattern (3.0=TBS, 1.0=TWS, 0.0=generico)    │
// │  6. L'EA legge Buffer 18+19 con CopyBuffer(handle,18/19,0,1)     │
// │  7. L'EA conferma: BufSignalUp[1]/Dn[1] alla chiusura barra      │
// └─────────────────────────────────────────────────────────────────────┘

//═══════════════════════════════════════════════════════════════════
//  SEZIONE 4: COLORI E STILE
//═══════════════════════════════════════════════════════════════════
input group "                                                               "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  🎨 COLORI E STILE                                       ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    🎯 PATTERN TBS / TWS (v7.19)"
// v7.19: Colori separati per pattern TBS (corpo sfonda banda) vs TWS (solo wick).
// TBS = segnale forte, alta probabilità di mean reversion (74-82% win rate).
// TWS = segnale debole, solo wick tocca la banda (58-62% win rate).
// I buffer 18 e 19 restano invariati — la distinzione colore è solo visiva.
input color InpColTBS_Buy       = clrLime;          // BUY TBS: corpo sotto banda (forte) — verde acceso
input color InpColTWS_Buy       = C'0,160,90';      // BUY TWS: solo wick (debole) — verde scuro
input color InpColTBS_Sell      = clrRed;           // SELL TBS: corpo sopra banda (forte) — rosso acceso
input color InpColTWS_Sell      = C'180,60,60';     // SELL TWS: solo wick (debole) — rosso scuro
input bool  InpShowTWSSignals   = true;             // Mostra frecce TWS sul chart
// ↑ TRUE  = mostra TUTTE le frecce (TBS e TWS) — comportamento default
// ↑ FALSE = nasconde le frecce TWS visivamente (Buffer 18/19 rimangono scritti per l'EA)
//   Utile se vuoi vedere solo i segnali forti sul chart ma lasciare l'EA decidere su tutti.

input group "    📡 LTF ENTRY (v7.19)"
// v7.19: LTF Entry Signal — il Buffer 20 segnala la prima candela del TF inferiore
// che tocca il livello banda del TF principale E chiude dentro il canale.
// L'EA usa Buffer 20 per entrare con timing più preciso rispetto alla chiusura bar TF principale.
input bool  InpEnableLTFEntry   = true;             // Abilita rilevamento LTF Entry (Buffer 20)
// ↑ TRUE  = Buffer 20 attivo. L'EA può leggere il segnale LTF confermato.
// ↑ FALSE = Buffer 20 = 0 sempre. Risparmio CPU minimo, utile per debug.
input bool  InpShowLTFMark      = true;             // Mostra marcatore visivo conferma LTF sul chart
// ↑ TRUE  = disegna un piccolo triangolo (▼ o ▲) sulla barra LTF di conferma.
//   Il marcatore è distinto dalla freccia principale DPC (più piccolo, stessa zona).
// ↑ FALSE = nessun disegno LTF. Buffer 20 rimane attivo se InpEnableLTFEntry=true.

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
double BufSignalType[];   // 19 - Pattern segnale (CALCULATIONS: 3.0=TBS, 1.0=TWS, 0.0=nessuno)
double BufLTFEntry[];     // 20 - v7.19: LTF Entry Signal (CALCULATIONS: +1=BUY confermato LTF, -1=SELL, 0=nessuno)
                          //      L'EA legge: CopyBuffer(handle, 20, 0, 1, val)
                          //      Segnale valido solo nella barra dove si apre la finestra LTF.
                          //      Basato su close di barre LTF chiuse (shift=1) → zero repaint.
                          //      TF inferiore usato: M5→M1, M15→M5, M30→M5, H1→M15, H4→M30
//    v7.18: Buffer INDICATOR_CALCULATIONS — NON visibile come plot sul chart.
//    Contiene la classificazione del pattern candela per ogni segnale:
//      3.0 = PATTERN_TBS → corpo ha sfondato la banda (forte rejection, trapped traders)
//      1.0 = PATTERN_TWS → solo wick ha sfondato (debole rejection, sondaggio)
//      0.0 = PATTERN_NONE → nessun segnale su questa barra, o barra live (i=0)
//    L'EA può leggerlo con CopyBuffer(indicatorHandle, 19, shift, count, buffer).
//    Buffer 18 (BufTouchTrigger) resta invariato per retrocompatibilità EA.

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
int    g_nSameBars       = 2;       // Barre attesa stesso verso (validato 1-10 in OnInit) — allineato EA+Carneval
int    g_nOppositeBars   = 1;       // Barre attesa direzione opposta (validato 1-10 in OnInit) — allineato EA+Carneval
//--- Filtro Orario (v7.05): range orario bloccato in minuti dall'inizio del giorno (orario BROKER)
int    g_timeBlockStartMin = 0;    // Inizio blocco in minuti-del-giorno broker (0-1439)
int    g_timeBlockEndMin   = 0;    // Fine blocco in minuti-del-giorno broker (0-1439)
int    g_minLevelAge     = 3;       // Barre minime età livello Donchian (usato runtime)
int    g_minLevelAge_eff = 3;       // v7.19+: valore preset per TF (M1=1,M5=3,M15=3,M30=4,H1=5,H4=3)

//--- v7.18: Parametri Effettivi (Auto TF Preset)
//
//    PATTERN "EFFECTIVE GLOBALS": Questi 4 valori sostituiscono i rispettivi Input
//    in TUTTE le referenze nel codice (main loop, Section 5, Section 5b, OnInit, etc.).
//    L'indirezione permette al Preset TF (ENUM_TF_PRESET) di sovrascrivere i valori senza
//    modificare gli Input originali (che restano visibili nel pannello parametri MT5).
//
//    Ciclo di vita:
//      1. Dichiarati qui con valori di default ragionevoli
//      2. Sovrascritti in OnInit() dal Preset TF (AUTO/M5/M15/M30/H1/H4)
//         oppure copiati dagli Input (se MANUALE o TF non coperto in AUTO)
//      3. Usati in tutto il codice al posto di InpLenDC, InpMALen, InpMinWidthPips, InpFlatLookback
//
//    NOTA: g_nSameBars e g_nOppositeBars NON sono in questa lista perché erano già
//    variabili globali (non Input diretti) — vengono comunque sovrascritti dall'Auto TF.
//
int    g_dcLen_eff       = 20;      // Effective Donchian period (da InpLenDC o preset TF)
int    g_maLen_eff       = 30;      // Effective MA period (da InpMALen o preset TF)
double g_minWidth_eff    = 8.0;     // Effective min channel width in pip (da InpMinWidthPips o preset TF)
int    g_flatLook_eff    = 2;       // Effective flatness lookback (da InpFlatLookback o preset TF) — allineato EA+Carneval
double g_flatTol_eff     = 0.85;    // v1.3: Effective flatness tolerance per TF (da InpFlatnessTolerance o preset)
                                    //   M5=0.85, M15=0.65, M30=0.50, H1=0.38, H4=0.35, MANUALE=InpFlatnessTolerance

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

//--- v7.19: LTF Entry Signal state — stato finestra di ascolto LTF
//    Ciclo di vita:
//      1. g_ltfWindowOpen = false (default)
//      2. Quando Buffer 18 emette segnale → g_ltfWindowOpen = true, finestra aperta
//      3. Monitora barre LTF chiuse (shift=1): prima che tocca banda + chiude dentro → Buffer 20
//      4. Dopo prima conferma O scadenza finestra → g_ltfWindowOpen = false
bool     g_ltfWindowOpen     = false;   // finestra LTF attiva (apertura attiva dal segnale Buffer18)
int      g_ltfDirection      = 0;       // direzione attesa: +1=BUY, -1=SELL
double   g_ltfBandLevel      = 0.0;     // livello banda da monitorare (upper per SELL, lower per BUY)
datetime g_ltfWindowExpiry   = 0;       // scadenza finestra (= apertura barra TF principale + PeriodSeconds())
datetime g_ltfLastProcessed  = 0;       // ultima barra LTF già processata (anti-duplicato per-tick)
datetime g_ltfConfirmedBar   = 0;       // v7.19 FIX: barra su cui LTF è stata confermata (anti-riapertura + persistenza)

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
//| OnInit — Inizializzazione indicatore                              |
//|                                                                    |
//| Eseguita una volta al primo caricamento e ad ogni cambio parametri.|
//| ORDINE OPERAZIONI (critico, non modificare):                       |
//|                                                                    |
//|   1. Prefissi oggetti (InpInstanceID → FORECAST_PREFIX, etc.)    |
//|   2. Buffer mapping (SetIndexBuffer × 20 + ArraySetAsSeries)     |
//|   3. Plot configuration (colori, arrow codes, DRAW_NONE)          |
//|   4. Validazione input (SmartCooldown clamp 1-10, LevelAge)      |
//|   5. Auto TF Preset (ENUM_TF_PRESET → g_*_eff globali)           |
//|      ★ DEVE precedere iMA handles (g_maLen_eff usato come periodo)|
//|   6. Creazione iMA/iATR handles (con g_maLen_eff dal preset)     |
//|   7. Filtro Orario parsing (InpTimeBlockStart/End → minuti broker)|
//|   8. Chart Theme (salva originali → applica tema scuro)           |
//|   9. CHART_FOREGROUND=false (per DRAW_COLOR_CANDLES visibilita') |
//|  10. IndicatorSetString (short name con preset/trigger mode)      |
//|                                                                    |
//| NOTA: Le variabili globali di stato (g_lastMarkerBar etc.) NON    |
//| vengono resettate qui — il reset è in OnCalculate (prev_calc==0). |
//| Questo perchè OnInit segue OnDeinit(REASON_PARAMETERS) dove le   |
//| globali sono preservate, e OnCalculate gestisce il full reset.    |
//+------------------------------------------------------------------+
int OnInit()
{
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
   SetIndexBuffer(19, BufSignalType,   INDICATOR_CALCULATIONS);  // v7.18: Pattern tipo segnale (TBS/TWS)
   SetIndexBuffer(20, BufLTFEntry,     INDICATOR_CALCULATIONS);  // v7.19: LTF Entry Signal (+1 BUY, -1 SELL, 0 nessuno)
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
   ArraySetAsSeries(BufSignalType, true);
   ArraySetAsSeries(BufLTFEntry,   true);   // v7.19: LTF Entry buffer
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

   //--- v7.18: Validazione SmartCooldown — clamp 1-10 (anticipata prima di Auto TF Preset)
   //    ORDINE CRITICO: La validazione DEVE avvenire PRIMA dell'Auto TF Preset.
   //    Se Auto TF è attivo, g_nSameBars e g_nOppositeBars vengono SOVRASCRITTI dal preset.
   //    Se Auto TF è disattivo, i valori validati qui vengono usati come parametri effettivi.
   g_nSameBars      = (int)MathMax(1, MathMin(10, InpNSameBars));
   g_nOppositeBars  = (int)MathMax(1, MathMin(10, InpNOppositeBars));
   g_minLevelAge    = (int)MathMax(1, MathMin(10, InpMinLevelAge));

   //--- v7.18: AUTO TF PRESET — Adattamento automatico parametri al timeframe corrente
   //
   //    SCOPO: I parametri espressi in "barre" (MALen, NSameBars, FlatLookback, etc.) e in "pip"
   //    (MinWidthPips) hanno effetti radicalmente diversi su timeframe diversi.
   //    Esempio pratico: MALen=30 su M5 = 2.5h, ma su H1 = 30h (12 volte più lento!).
   //    Questo blocco sovrascrive i parametri con valori calibrati per il TF corrente.
   //
   //    POSIZIONAMENTO: DEVE venire PRIMA della creazione handle MA (sotto), perché
   //    g_maLen_eff viene usato come periodo per iMA() / iMA(halfLen) per HMA.
   //    Se fosse DOPO, la MA verrebbe creata con il valore input (sbagliato) anziché il preset.
   //
   //    PARAMETRI SOVRASCRITTI (6 totali):
   //      g_dcLen_eff    ← InpLenDC (ma resta 20 per tutti i TF — il Donchian è stabile)
   //      g_maLen_eff    ← InpMALen (scalato: M5=50 barre ~4h, H4=12 barre ~2gg)
   //      g_minWidth_eff ← InpMinWidthPips (scalato: M5=5pip canali stretti, H4=30pip canali larghi)
   //      g_nSameBars    ← InpNSameBars (scalato: M5=3 barre 15min, H4=1 barra 4h)
   //      g_nOppositeBars ← InpNOppositeBars (scalato: M5=2 barre 10min, H4=1 barra 4h)
   //      g_flatLook_eff ← InpFlatLookback (scalato: M5=3 barre 15min, H4=1 barra 4h)
   //
   //    LOGICA CALIBRAZIONE:
   //      - MALen: copre ~4-18 ore di dati (mezza sessione su M5, 2 sessioni su H4)
   //      - MinWidth: sale con il TF perché candele più ampie = canali più larghi
   //      - Cooldown (nSame/nOpp): scende con il TF perché ogni barra copre più tempo
   //      - FlatLookback: scende con il TF (1 barra H4 = 4 ore, già significativa)
   //
   //--- Determina quale preset applicare:
   //    AUTO → usa Period() per rilevare il TF del chart
   //    M5/M15/M30/H1/H4 → forza il preset selezionato (ignora TF chart)
   //    MANUALE → nessun preset, parametri dall'utente
   //
   //    presetTF contiene il "TF target" del preset da applicare.
   //    Se è 0, significa MANUALE (nessun preset).
   //
   ENUM_TIMEFRAMES presetTF = PERIOD_CURRENT;  // TF target del preset (0 = manuale)

   switch(InpTFPreset)
   {
      case TF_PRESET_AUTO:
         //--- AUTO: rileva il TF del chart. Se non è coperto → fallback manuale.
         switch(Period())
         {
            case PERIOD_M1:  presetTF = PERIOD_M1;  break;  // v7.19+: M1 ora coperto
            case PERIOD_M5:  presetTF = PERIOD_M5;  break;
            case PERIOD_M15: presetTF = PERIOD_M15; break;
            case PERIOD_M30: presetTF = PERIOD_M30; break;
            case PERIOD_H1:  presetTF = PERIOD_H1;  break;
            case PERIOD_H4:  presetTF = PERIOD_H4;  break;
            default:         presetTF = PERIOD_CURRENT; break;  // TF non coperto → manuale
         }
         break;
      case TF_PRESET_M1:      presetTF = PERIOD_M1;      break;  // v7.19+: aggiunto
      case TF_PRESET_M5:      presetTF = PERIOD_M5;      break;
      case TF_PRESET_M15:     presetTF = PERIOD_M15;     break;
      case TF_PRESET_M30:     presetTF = PERIOD_M30;     break;
      case TF_PRESET_H1:      presetTF = PERIOD_H1;      break;
      case TF_PRESET_H4:      presetTF = PERIOD_H4;      break;
      case TF_PRESET_MANUAL:  presetTF = PERIOD_CURRENT; break;  // MANUALE
   }

   //--- Applica il preset selezionato (o fallback manuale se presetTF == PERIOD_CURRENT)
   //
   //    v7.19: CALIBRAZIONE g_flatTol_eff PER TIMEFRAME
   //    ─────────────────────────────────────────────────
   //    La tolleranza flatness (g_flatTol_eff) controlla il filtro Band Flatness (Section 5 + 5b).
   //    Formula: soglia = g_flatTol_eff × ATR(14). Se la banda si espande oltre la soglia
   //    rispetto a N barre precedenti → il segnale è bloccato (mercato in trend, non in range).
   //
   //    PRINCIPIO DI CALIBRAZIONE:
   //      TF BASSI (M5) → tolleranza MODERATA (0.40): ATR piccolo, candele rapide, necessario
   //        filtrare i micro-trend scalping che generano falsi mean-reversion.
   //      TF MEDI (M15/M30) → tolleranza MEDIA (0.50-0.65): equilibrio tra filtro e sensibilità.
   //      TF ALTI (H1/H4) → tolleranza BASSA (0.35-0.38): i trend su TF alti sono più
   //        persistenti e direzionali, il filtro deve essere più aggressivo per bloccare
   //        segnali contro-trend che su H1/H4 hanno bassa probabilità di reversal.
   //
   //    v1.3 ALLINEAMENTO CARNEVAL: M5 e M15 allineati ai valori Carneval EA che
   //    generavano più operazioni con buoni risultati. flatTol alzata, lookback ridotto,
   //    cooldown più reattivo. H1/H4 invariati (parametri già ragionevoli).
   //
   //    NOTA MinWidth M5 (v7.19): alzato 5.0→7.0 pip per eliminare canali troppo stretti
   //    dove il TP target (metà canale = 2.5 pip) non copre lo spread (~1.5-2 pip).
   //
   //    v7.19+ MODIFICHE PARAMETRIZZAZIONE MULTI-TF:
   //    ─────────────────────────────────────────────
   //    NUOVO PRESET M1 (backtest/precision entry):
   //      maLen=200 (3h20 bias sessione), minWidth=4pip, flatTol=0.95 (quasi disabilitato),
   //      cooldown 1/1 bar, flatLook=1. LTF Entry inutile su M1 (conferma su se stesso).
   //
   //    M15 POTENZIATO: flatTol 0.65→0.70 (+8-12% segnali stimati)
   //      Soglia effettiva: 0.70 × 12pip ATR = 8.4pip (era 7.8pip)
   //      NOTA: aggiornare adDPCPresets.mqh nell'EA per mantenere allineamento.
   //
   //    M30 RICALIBRATO: flatTol 0.50→0.60 e minWidth 14.0→12.0pip (+15-20% segnali)
   //      flatTol era non calibrato dalla v1.3. minWidth 14pip era eccessivamente restrittivo.
   //      TP minimo con canale 12pip = 6pip > spread M30 (~1.5-2pip).
   //
   //    g_minLevelAge_eff (NUOVO): Level Age ora preset-driven per TF.
   //      M1=1 (1min), M5=3 (15min), M15=3 (45min), M30=4 (2h), H1=5 (5h), H4=3 (12h).
   //      Override applicato DOPO questo blocco: if(!=MANUAL) g_minLevelAge = g_minLevelAge_eff
   //      In modalità MANUALE, g_minLevelAge resta dal valore input utente (InpMinLevelAge).
   //
   //    TABELLA COMPLETA PRESET:
   //    ┌──────┬──────┬───────┬─────────┬──────┬──────┬─────────┬─────────┬────────────┐
   //    │  TF  │dcLen │ maLen │minWidth │nSame │ nOpp │flatLook │ flatTol │minLevelAge │
   //    ├──────┼──────┼───────┼─────────┼──────┼──────┼─────────┼─────────┼────────────┤
   //    │  M1  │  20  │  200  │   4.0   │  1   │  1   │    1    │  0.95   │     1      │
   //    │  M5  │  20  │   50  │   7.0   │  2   │  1   │    2    │  0.85   │     3      │
   //    │ M15  │  20  │   34  │  10.0   │  2   │  1   │    2    │  0.70   │     3      │
   //    │ M30  │  20  │   24  │  12.0   │  2   │  1   │    2    │  0.60   │     4      │
   //    │  H1  │  20  │   18  │  18.0   │  1   │  1   │    2    │  0.38   │     5      │
   //    │  H4  │  20  │   12  │  30.0   │  1   │  1   │    1    │  0.35   │     3      │
   //    │ MAN  │ inp  │  inp  │   inp   │ inp  │ inp  │   inp   │   inp   │    inp     │
   //    └──────┴──────┴───────┴─────────┴──────┴──────┴─────────┴─────────┴────────────┘
   //
   if(presetTF == PERIOD_M1)
   {
      //--- M1: preset backtest e entry precision
      //    ATR~2pip: minWidth 4pip (TP=2pip > spread M1~1.5pip)
      //    maLen=200: 200min=3h20 di bias sessione
      //    flatTol 0.95: M1 molto noisy, filtro quasi disabilitato (uso backtest)
      //    cooldown minimo: 1bar=1min. flatLook=1: confronto solo barra precedente
      //    NOTA UTENTE: impostare InpEnableLTFEntry=false su M1
      //    (il mapping default→M1 creerebbe finestra LTF su se stesso)
      g_dcLen_eff=20; g_maLen_eff=200; g_minWidth_eff=4.0;
      g_nSameBars=1;  g_nOppositeBars=1; g_flatLook_eff=1;
      g_flatTol_eff=0.95;
      g_minLevelAge_eff=1;  // 1 barra piatta su M1
   }
   else if(presetTF == PERIOD_M5)
   {
      //--- M5: preset principale scalping/intraday — allineato EA v1.3
      g_dcLen_eff=20; g_maLen_eff=50; g_minWidth_eff=7.0;   // MA=50×5min=250min≈4h | minWidth alzato 5→7 pip (v7.19)
      g_nSameBars=2;  g_nOppositeBars=1; g_flatLook_eff=2;  // cooldown 10min/5min (allineato EA+Carneval v1.3)
      g_flatTol_eff=0.85;  // v1.3: tolleranza allineata Carneval (ATR~8pip → soglia 6.8pip)
      g_minLevelAge_eff=3;  // 3×5min = 15min banda piatta
   }
   else if(presetTF == PERIOD_M15)
   {
      //--- M15: preset intraday ottimale — flatTol alzato 0.65→0.70 per +8-12% segnali
      //    NOTA: aggiornare adDPCPresets.mqh EA alla stessa riga per mantenere allineamento
      g_dcLen_eff=20; g_maLen_eff=34; g_minWidth_eff=10.0;  // MA=34×15min=510min≈8.5h
      g_nSameBars=2;  g_nOppositeBars=1; g_flatLook_eff=2;  // cooldown 30min/15min (allineato EA v1.3)
      g_flatTol_eff=0.70;  // v7.19+: era 0.65, alzato per aumentare segnali M15
      g_minLevelAge_eff=3;  // 3×15min = 45min banda piatta
   }
   else if(presetTF == PERIOD_M30)
   {
      //--- M30: preset intraday lento — ricalibrato v7.19+
      //    flatTol 0.50→0.60: era non calibrato v1.3, ora allineato alla scala ATR M30
      //    minWidth 14.0→12.0: 14pip era troppo restrittivo, TP=6pip ancora > spread
      g_dcLen_eff=20; g_maLen_eff=24; g_minWidth_eff=12.0;  // era 14.0
      g_nSameBars=2;  g_nOppositeBars=1; g_flatLook_eff=2;  // cooldown 1h/30min
      g_flatTol_eff=0.60;  // v7.19+: era 0.50, alzato per calibrare su scala ATR M30
      g_minLevelAge_eff=4;  // 4×30min = 120min banda piatta
   }
   else if(presetTF == PERIOD_H1)
   {
      g_dcLen_eff=20; g_maLen_eff=18; g_minWidth_eff=18.0;  // MA=18×60min=1080min=18h
      g_nSameBars=1;  g_nOppositeBars=1; g_flatLook_eff=2;  // cooldown 1h/1h
      g_flatTol_eff=0.38;  // v7.19: tolleranza ridotta H1 (ATR~25pip → soglia 9.5pip, più filtrante)
      g_minLevelAge_eff=5;  // 5×60min = 5h di banda piatta su H1
   }
   else if(presetTF == PERIOD_H4)
   {
      g_dcLen_eff=20; g_maLen_eff=12; g_minWidth_eff=30.0;  // MA=12×240min=2880min≈2gg
      g_nSameBars=1;  g_nOppositeBars=1; g_flatLook_eff=1;  // cooldown 4h/4h
      g_flatTol_eff=0.35;  // v7.19: tolleranza più restrittiva H4 (trend pesanti, filtro forte)
      g_minLevelAge_eff=3;  // 3×240min = 12h di banda piatta su H4
   }
   else  // MANUALE o TF non coperto in AUTO
   {
      //--- Modalità manuale: copia valori dagli input senza modifiche
      //    L'utente è responsabile della calibrazione per il TF corrente.
      g_dcLen_eff    = InpLenDC;
      g_maLen_eff    = InpMALen;
      g_minWidth_eff = InpMinWidthPips;
      g_flatLook_eff = InpFlatLookback;
      g_flatTol_eff  = InpFlatnessTolerance;  // v7.19: modalità manuale usa input diretto
      g_minLevelAge_eff = (int)MathMax(1, MathMin(10, InpMinLevelAge));  // v7.19+: manuale usa input
   }

   //--- v7.19+: OVERRIDE g_minLevelAge con valore preset-driven
   //    In AUTO/FORCED mode: g_minLevelAge = g_minLevelAge_eff (dal blocco preset sopra)
   //    In MANUAL mode: g_minLevelAge resta = InpMinLevelAge (riga 1362, non sovrascritto)
   //    Usato in: Section 5 Level Age (righe ~3399,3414) e Section 5b Touch (righe ~4199,4217)
   if(InpTFPreset != TF_PRESET_MANUAL)
      g_minLevelAge = g_minLevelAge_eff;

   //--- Log nel Journal per verifica visiva del preset applicato
   string presetName = (presetTF == PERIOD_M1)  ? "M1"  :
                       (presetTF == PERIOD_M5)  ? "M5"  :
                       (presetTF == PERIOD_M15) ? "M15" :
                       (presetTF == PERIOD_M30) ? "M30" :
                       (presetTF == PERIOD_H1)  ? "H1"  :
                       (presetTF == PERIOD_H4)  ? "H4"  : "MANUALE";
   Print("[DPC] Preset TF: ", presetName, " (chart=", EnumToString(Period()), ")",
         " dcLen=", g_dcLen_eff, " maLen=", g_maLen_eff,
         " minWidth=", DoubleToString(g_minWidth_eff, 1),
         " nSame=", g_nSameBars, " nOpp=", g_nOppositeBars,
         " flatLook=", g_flatLook_eff,
         " flatTol=", DoubleToString(g_flatTol_eff, 2),
         " minLevelAge=", g_minLevelAge_eff);  // v7.19+

   //--- Create MA handles — usano g_maLen_eff (NON InpMALen) per supportare Auto TF Preset
   //    Se Auto TF è attivo, g_maLen_eff contiene il preset (es. 50 su M5, 18 su H1).
   //    Se disattivo, g_maLen_eff = InpMALen (invariato).
   if(InpMAType == MA_SMA)
      g_maHandle = iMA(_Symbol, PERIOD_CURRENT, g_maLen_eff, 0, MODE_SMA, PRICE_CLOSE);
   else if(InpMAType == MA_EMA)
      g_maHandle = iMA(_Symbol, PERIOD_CURRENT, g_maLen_eff, 0, MODE_EMA, PRICE_CLOSE);
   else if(InpMAType == MA_WMA)
      g_maHandle = iMA(_Symbol, PERIOD_CURRENT, g_maLen_eff, 0, MODE_LWMA, PRICE_CLOSE);
   else if(InpMAType == MA_HMA)
   {
      int halfLen = (int)MathFloor(g_maLen_eff / 2.0);
      if(halfLen < 1) halfLen = 1;
      g_hmaHalfHandle = iMA(_Symbol, PERIOD_CURRENT, halfLen, 0, MODE_LWMA, PRICE_CLOSE);
      g_hmaFullHandle = iMA(_Symbol, PERIOD_CURRENT, g_maLen_eff, 0, MODE_LWMA, PRICE_CLOSE);
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

   //--- v7.18: SmartCooldown/LevelAge validation spostata PRIMA di Auto TF Preset (sopra).

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
   g_chartThemeApplied = false;
   if(InpApplyChartTheme)
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

   //--- Indicator short name (visibile nella finestra dati e nella lista indicatori)
   //    v7.18: aggiunta modalità trigger (BC=Bar Close, IB=Intrabar) e preset (AUTO/MAN)
   //    Formato: "DPC (dcLen, projLen, trigMode, presetMode)"
   //    Esempio M5 Auto+BC: "DPC (20,30,BC,AUTO)" | Esempio H1 Manual+IB: "DPC (20,30,IB,MAN)"
   string trigMode = (InpTriggerModeV2 == TRIGGER_BAR_CLOSE) ? "BC" : "IB";
   string presetMode = (InpTFPreset == TF_PRESET_AUTO) ? "AUTO" :
                       (InpTFPreset == TF_PRESET_MANUAL) ? "MAN" :
                       (InpTFPreset == TF_PRESET_M1) ? "M1" :
                       (InpTFPreset == TF_PRESET_M5) ? "M5" :
                       (InpTFPreset == TF_PRESET_M15) ? "M15" :
                       (InpTFPreset == TF_PRESET_M30) ? "M30" :
                       (InpTFPreset == TF_PRESET_H1) ? "H1" : "H4";
   IndicatorSetString(INDICATOR_SHORTNAME,
      "DPC (" + IntegerToString(g_dcLen_eff) + "," +
      IntegerToString(InpProjLen) + "," + trigMode + "," + presetMode + ")");

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| OnDeinit — Deinizializzazione indicatore                          |
//|                                                                    |
//| Eseguita alla rimozione dell'indicatore, cambio TF, ricompilazione,|
//| cambio parametri, chiusura chart, e altri eventi di terminazione. |
//|                                                                    |
//| OPERAZIONI:                                                        |
//|   1. Log diagnostico (reason + conteggio oggetti + stato tema)    |
//|   2. Pulizia oggetti grafici (forecast, segnali, TP, entry dot)  |
//|   3. Distruzione CCanvas (bitmap overlay)                         |
//|   4. Rilascio handle indicatori (iMA, iATR)                       |
//|   5. Ripristino colori chart (condizionale — vedi sotto)          |
//|   6. Ripristino CHART_FOREGROUND                                   |
//|                                                                    |
//| RIPRISTINO CONDIZIONALE DEL TEMA (v7.04):                         |
//|   REASON_PARAMETERS: skip ripristino (OnInit segue immediatamente |
//|     con globali preservate → ripristino causerebbe flash visivo). |
//|   REASON_CHARTCHANGE/RECOMPILE: ripristino obbligatorio (globali  |
//|     resettate → senza ripristino, OnInit salverebbe i colori     |
//|     scuri come "originali" → tema scuro permanente).              |
//|   REASON_REMOVE/CHARTCLOSE: ripristino obbligatorio (definitivo). |
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
//| LinearRegressionSlope — Pendenza regressione lineare (OLS)       |
//|                                                                    |
//| SCOPO: Calcola la pendenza della retta di regressione lineare    |
//|   su una finestra di N barre. Usata dal forecast (Section 6)     |
//|   per proiettare la direzione futura della midline e del range   |
//|   del canale Donchian.                                            |
//|                                                                    |
//| FORMULA: Ordinary Least Squares (OLS)                             |
//|   slope = (N * sum(x*y) - sum(x) * sum(y))                       |
//|           / (N * sum(x^2) - sum(x)^2)                             |
//|   Dove x = posizione nella finestra (0=più vecchio, N-1=più nuovo)|
//|                                                                    |
//| EQUIVALENZA PINE SCRIPT:                                          |
//|   ta.linreg(src, length, 0) - ta.linreg(src, length, 1) = slope  |
//|   Il Pine Script non ha una funzione slope diretta; la ottiene    |
//|   come differenza tra forecast offset 0 e offset 1.               |
//|                                                                    |
//| PARAMETRI:                                                         |
//|   src[]  — array as-series dei dati (BufMid per midSlope,         |
//|            g_rngArray per range slope)                             |
//|   bar    — indice di partenza (0 = barra più recente)             |
//|   length — finestra (= g_dcLen_eff, default 20 barre)             |
//|   total  — rates_total (per boundary check)                       |
//|                                                                    |
//| RETURN: slope positivo = trend rialzista, negativo = ribassista   |
//|   Usata due volte in Section 6:                                    |
//|   1. midSlope = LinearRegressionSlope(BufMid, 0, dcLen, total)   |
//|      → pendenza della midline → direzione del cono forecast       |
//|   2. rngSlope = LinearRegressionSlope(g_rngArray, 0, dcLen, total)|
//|      → pendenza del range → espansione/contrazione del cono       |
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
//| ManualWMA — Media Mobile Ponderata su array custom               |
//|                                                                    |
//| SCOPO: Calcola la WMA su un array arbitrario (non un buffer      |
//|   indicatore). Necessaria per il terzo step del calcolo HMA:     |
//|   HMA(N) = WMA(sqrt(N)) applicata al vettore intermedio          |
//|   2*WMA(N/2) - WMA(N).                                            |
//|                                                                    |
//| PERCHE' NON USARE iMA():                                          |
//|   iMA() opera su dati OHLC del simbolo, non su array custom.     |
//|   Il vettore intermedio HMA non è un prezzo ma un valore         |
//|   calcolato (2*WMA(N/2) - WMA(N)) → serve WMA manuale.          |
//|                                                                    |
//| FORMULA: WMA = sum(src[i+k] * (period-k)) / sum(period-k)        |
//|   Peso decrescente: barra più recente = peso N, più vecchia = 1   |
//|                                                                    |
//| PARAMETRI:                                                         |
//|   src[]  — array as-series (g_hmaIntermediate per HMA)            |
//|   bar    — indice di partenza (bar=0 per barra più recente)       |
//|   period — finestra WMA (= sqrt(g_maLen_eff) per step 3 HMA)     |
//|   total  — rates_total (per boundary check)                       |
//|                                                                    |
//| CHIAMATA: Section 3 di OnCalculate (calcolo HMA finale)           |
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
//| FUNZIONI DI PULIZIA OGGETTI GRAFICI                               |
//|                                                                    |
//| Ogni tipo di oggetto ha il suo prefisso univoco (inizializzato   |
//| in OnInit con InpInstanceID) e la sua funzione di cancellazione.  |
//| Chiamate tutte in OnDeinit e selettivamente in prev_calc==0.      |
//|                                                                    |
//| DeleteForecastObjects  — FORECAST_PREFIX (linee proiezione)       |
//| DeleteSignalObjects    — SIGNAL_PREFIX   (label TRIGGER BUY/SELL) |
//| DeleteTPTargetObjects  — TP_TARGET_PREFIX + TP_TGTDOT_PREFIX      |
//| DeleteEntryDotObjects  — ENTRY_DOT_PREFIX (diamanti entry)        |
//|                                                                    |
//| NOTA: Loop al contrario (i = total-1..0) per safe ObjectDelete   |
//| durante l'iterazione — rimuovere un oggetto sposta gli indici.   |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| DeleteForecastObjects — Rimuove linee proiezione forecast         |
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
//| CreateSignalArrow — Crea etichetta "TRIGGER BUY/SELL" + tooltip  |
//|                                                                    |
//| v7.14: Le frecce visive sono gestite da DRAW_ARROW (Plot 6-7).   |
//|   Questa funzione crea SOLO l'OBJ_TEXT con etichetta e tooltip.   |
//|   L'OBJ_TEXT fornisce il tooltip al passaggio del mouse e mostra  |
//|   "TRIGGER BUY" o "TRIGGER SELL" sotto/sopra la freccia.          |
//|                                                                    |
//| v7.18: Aggiunto parametro signalPattern per TBS/TWS.             |
//|   L'etichetta mostra [TBS] o [TWS] dopo il testo TRIGGER.        |
//|   Il tooltip mostra "Pattern: TBS/TWS/-" per diagnosi rapida.    |
//|   Esempi:                                                          |
//|     Label: "TRIGGER SELL [TBS]" → forte rejection (corpo sfonda) |
//|     Label: "TRIGGER BUY [TWS]"  → debole rejection (solo wick)   |
//|     Label: "TRIGGER SELL"        → pattern non classificato (IB)  |
//|                                                                    |
//| v7.19: Colore freccia differenziato TBS/TWS (MOD-14).            |
//|   Il colore OBJ_TEXT e le future plot DRAW_ARROW vengono scelti   |
//|   in base al pattern classificato:                                 |
//|     PATTERN_TBS → InpColTBS_Buy/Sell (colori pieni, forti)        |
//|     PATTERN_TWS → InpColTWS_Buy/Sell (colori attenuati, deboli)   |
//|     PATTERN_NONE → InpColSignalUp/Dn (colori default, INTRABAR)   |
//|   NOTA: il colore dell'OBJ_TEXT corrisponde alla freccia DRAW_ARROW|
//|   perché PlotIndexSetInteger(PLOT_LINE_COLOR) è single-color.      |
//|   La distinzione TBS/TWS è quindi solo via OBJ_TEXT color,         |
//|   non via buffer plot (DRAW_ARROW non supporta colore per barra).  |
//|                                                                    |
//| Parametri:                                                         |
//|   t            — datetime della barra segnale                     |
//|   price        — prezzo freccia (banda ± offset)                  |
//|   isBuy        — true=BUY (verde ⬆), false=SELL (rosso ⬇)       |
//|   glowOffset   — distanza freccia dalla banda (per label offset)  |
//|   entryPrice   — prezzo close (per tooltip "Prezzo:")             |
//|   tpMidline    — midline target (per tooltip "TP Midline:")       |
//|   widthRatio   — (upper-lower)/ATR (per tooltip "Width/ATR:")     |
//|   bandFlat     — true se banda era piatta (per tooltip)           |
//|   signalPattern— PATTERN_TBS=3, PATTERN_TWS=1, PATTERN_NONE=0   |
//+------------------------------------------------------------------+
void CreateSignalArrow(datetime t, double price, bool isBuy, double glowOffset, double entryPrice, double tpMidline,
                       double widthRatio = 0.0,     // v7.00: channelWidth / ATR
                       bool bandFlat = true,         // v7.00: banda era piatta?
                       int signalPattern = 0)        // v7.18: PATTERN_TBS=3, PATTERN_TWS=1, PATTERN_NONE=0
{
   string suffix = IntegerToString((long)t);

   //--- v7.14: OBJ_ARROW rimosso (frecce visive = solo DRAW_ARROW Plot 6-7)
   //--- v7.19: Colore freccia differenziato per pattern TBS/TWS
   //    TBS (corpo sfonda) = colore pieno (lime/red)
   //    TWS (solo wick)    = colore attenuato (verde scuro/rosso scuro)
   //    INTRABAR (pattern=0) = usa colore default (TBS non disponibile su barra live)
   color arrowColor;
   if(isBuy)
      arrowColor = (signalPattern == PATTERN_TBS) ? InpColTBS_Buy :
                   (signalPattern == PATTERN_TWS) ? InpColTWS_Buy : InpColSignalUp;
   else
      arrowColor = (signalPattern == PATTERN_TBS) ? InpColTBS_Sell :
                   (signalPattern == PATTERN_TWS) ? InpColTWS_Sell : InpColSignalDn;
   string priceStr  = DoubleToString(entryPrice, _Digits);
   string tpStr     = DoubleToString(tpMidline, _Digits);

   //--- v7.18: Stringa pattern per tooltip — converte valore numerico in testo leggibile
   //    TBS = forte (corpo sfonda), TWS = debole (solo wick), "-" = non classificato (INTRABAR)
   string patternStr = (signalPattern == PATTERN_TBS) ? "TBS" :
                       (signalPattern == PATTERN_TWS) ? "TWS" : "-";

   //--- Tooltip multi-riga: visibile al passaggio del mouse sulla freccia/label
   //    v7.18: aggiunta riga "Pattern: TBS/TWS/-" per identificazione rapida qualità segnale
   string tooltip   = (isBuy ? "▲ TRIGGER BUY - Segnale Rialzista\nApertura posizione LONG" :
                                "▼ TRIGGER SELL - Segnale Ribassista\nApertura posizione SHORT") +
                      "\nPrezzo: " + priceStr +
                      "\nTP Midline: " + tpStr +
                      "\nWidth/ATR: " + DoubleToString(widthRatio, 1) + "x" +
                      "\nBand Flat: " + (bandFlat ? "OK" : "NO") +
                      "\nPattern: " + patternStr;

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
   //--- v7.18: Etichetta con suffisso pattern [TBS]/[TWS]
   //    Esempi risultanti: "TRIGGER SELL [TBS]", "TRIGGER BUY [TWS]", "TRIGGER SELL" (senza pattern)
   //    Il suffisso appare SOLO se signalPattern != PATTERN_NONE (0).
   //    In modalità INTRABAR signalPattern è sempre 0 → label senza suffisso (come v7.17).
   string trigLabel = isBuy ? "TRIGGER BUY" : "TRIGGER SELL";
   if(signalPattern == PATTERN_TBS)      trigLabel += " [TBS]";   // corpo sfondava → forte
   else if(signalPattern == PATTERN_TWS) trigLabel += " [TWS]";   // solo wick → debole
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
//| GenerateForecastPoints — Genera punti proiezione forecast        |
//|                                                                    |
//| Port diretto di f_generatePoints() dal Pine Script v6 Zeiierman. |
//|                                                                    |
//| SCOPO: Proietta le bande Donchian e la midline nel futuro usando |
//|   la pendenza (slope) della regressione lineare calcolata sulle  |
//|   ultime g_dcLen_eff barre. Il risultato è un "cono" di          |
//|   proiezione che mostra la direzione attesa del canale.           |
//|                                                                    |
//| ALGORITMO (3 segmenti):                                           |
//|   Il forecast è diviso in 3 segmenti di uguale lunghezza         |
//|   (steps/3 barre ciascuno). Ad ogni barra del forecast:          |
//|   1. mdProj = md0 + midSlp * b  → midline proiettata linearmente|
//|   2. rngProj = range + rngSlp * b → range espanso/contratto      |
//|   3. hiTemp/loTemp: vincoli asimmetrici per evitare inversioni   |
//|      - Se midSlp >= 0 (up): hi = max(curHi, mid + rng/2)        |
//|      - Se midSlp < 0 (down): hi = min(curHi, mid + rng/2)       |
//|   4. Ai confini di segmento (b % segBars == 0), i valori cur*    |
//|      vengono aggiornati → crea i "gradini" tipici del forecast.  |
//|                                                                    |
//| PARAMETRI:                                                         |
//|   hi0, md0, lo0 — valori attuali Upper, Mid, Lower (barra 0)    |
//|   steps          — barre di proiezione (InpProjLen, default 30)  |
//|   midSlp         — pendenza midline (da LinearRegressionSlope)   |
//|   rngSlp         — pendenza range (da LinearRegressionSlope)     |
//|   hiPts/mdPts/loPts — array di output [steps+1] con i punti     |
//|                                                                    |
//| CHIAMATA: DrawForecast() → Section 6 di OnCalculate              |
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
//| DrawForecast — Disegna proiezione forecast con oggetti grafici   |
//|                                                                    |
//| SCOPO: Visualizza il "cono" di proiezione Donchian a destra      |
//|   della barra corrente. Mostra dove il canale si sta dirigendo   |
//|   in base alla regressione lineare delle ultime g_dcLen_eff barre.|
//|                                                                    |
//| IMPLEMENTAZIONE:                                                   |
//|   Usa OBJ_TREND (segmenti di linea) per disegnare il forecast.   |
//|   Per ogni coppia di barre consecutive (b, b+1) crea 3 segmenti: |
//|   - HI: upper forecast (tratteggiato verde, InpColForecastUp)    |
//|   - LO: lower forecast (tratteggiato rosso, InpColForecastDn)    |
//|   - MD: midline forecast (puntinato, colore basato su midSlp)    |
//|   + 2 etichette di prezzo agli endpoint (hi e lo finali).        |
//|                                                                    |
//| TEMPISTICA:                                                        |
//|   Le datetime dei punti sono calcolate come:                      |
//|   t = lastBarTime + b * PeriodSeconds()                           |
//|   → il forecast appare nello spazio futuro a destra del chart.   |
//|                                                                    |
//| CHIAMATA: Section 6 di OnCalculate (solo su nuova barra).         |
//|   I vecchi oggetti vengono cancellati (DeleteForecastObjects)     |
//|   e ricreati ad ogni nuova barra per riflettere le nuove slope.  |
//|                                                                    |
//| PARAMETRI:                                                         |
//|   time[]       — array datetime as-series (per lastBarTime)       |
//|   rates_total  — numero totale barre                              |
//|   hi0/md0/lo0  — valori attuali barra 0 (Upper/Mid/Lower)        |
//|   midSlp       — pendenza midline (positiva = cono sale)          |
//|   rngSlp       — pendenza range (positiva = cono si espande)      |
//+------------------------------------------------------------------+
void DrawForecast(const datetime &time[], int rates_total,
                  double hi0, double md0, double lo0,
                  double midSlp, double rngSlp)
{
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
//| RedrawCanvas — Disegna fill trasparenti via CCanvas (ARGB)       |
//|                                                                    |
//| SCOPO: Disegnare il riempimento semitrasparente del canale        |
//|   Donchian (area tra upper e lower band) con alpha channel.       |
//|                                                                    |
//| PERCHE' CCANVAS:                                                   |
//|   MQL5 DRAW_FILLING NON supporta trasparenza ARGB: l'alpha       |
//|   viene completamente ignorato dalla piattaforma. Qualsiasi      |
//|   valore alpha produce fill 100% opaco.                           |
//|   OBJPROP_COLOR per OBJ_RECTANGLE ignora anch'esso l'alpha       |
//|   (interpreta il valore ARGB come BGR, causando colori sbagliati).|
//|   CCanvas con COLOR_FORMAT_ARGB_NORMALIZE è l'UNICA soluzione    |
//|   per ottenere fill realmente trasparenti in MQL5.                |
//|                                                                    |
//| IMPLEMENTAZIONE:                                                   |
//|   1. Crea/ridimensiona un BitmapLabel (bitmap overlay sul chart)  |
//|   2. Erase con 0x00000000 (completamente trasparente)             |
//|   3. Per ogni coppia di barre visibili consecutive:               |
//|      - Converte i prezzi Upper/Lower in coordinate pixel (X,Y)   |
//|      - Disegna 2 triangoli con FillTriangle() per riempire       |
//|        il quadrilatero tra (upper1,lower1) e (upper2,lower2)     |
//|      - Colore: InpColDonchianFill con alpha InpFillAlpha          |
//|   4. Update() per committare la bitmap sul chart                  |
//|                                                                    |
//| BITMAP: OBJPROP_BACK=true → disegnato DIETRO le candele.          |
//|   OBJPROP_TOOLTIP="\n" → trasparente al mouse (non cattura hover).|
//|                                                                    |
//| PERFORMANCE:                                                       |
//|   Solo le barre visibili vengono processate (firstVisible..       |
//|   firstVisible-visibleBars). ChartTimePriceToXY per conversione. |
//|                                                                    |
//| CHIAMATA:                                                          |
//|   - Section 7 di OnCalculate (ad ogni tick)                       |
//|   - OnChartEvent(CHARTEVENT_CHART_CHANGE) (scroll/zoom/resize)   |
//|                                                                    |
//| NOTA v7.06: Il midline fill (area tra midline e mid-offset) è     |
//|   stato rimosso. L'utente ha preferito solo la linea colorata     |
//|   DRAW_COLOR_LINE. Resta solo il DC channel fill.                 |
//+------------------------------------------------------------------+
void RedrawCanvas()
{
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
//| OnChartEvent — Gestione eventi chart (scroll, zoom, resize)      |
//|                                                                    |
//| SCOPO: Ridisegnare il canvas trasparente quando la vista cambia.  |
//|   Il CCanvas è un bitmap statico in pixel: quando l'utente        |
//|   scrolla, zooma o ridimensiona il chart, le coordinate pixel     |
//|   dei livelli Upper/Lower cambiano → il fill non corrisponde più.|
//|   RedrawCanvas() ricalcola le coordinate e ridisegna il fill.    |
//|                                                                    |
//| CHARTEVENT_CHART_CHANGE:                                          |
//|   Scatta per: scroll orizzontale, zoom in/out, resize finestra,  |
//|   cambio scala verticale, drag del chart, cambio TF (parziale).  |
//|                                                                    |
//| CHARTREDRAW (v7.11):                                              |
//|   Dopo RedrawCanvas() (che chiama g_canvas.Update()), è          |
//|   necessario un ChartRedraw() esplicito per forzare il ridisegno |
//|   degli oggetti grafici OBJ_ARROW e OBJ_TEXT. Senza ChartRedraw(),|
//|   le frecce e le label possono scomparire temporaneamente dopo   |
//|   scroll/zoom (comportamento documentato della piattaforma MT5). |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   if(id == CHARTEVENT_CHART_CHANGE)
   {
      RedrawCanvas();
      ChartRedraw();  // v7.11: forza ridisegno oggetti grafici dopo scroll/zoom
   }
}

//+------------------------------------------------------------------+
//| OnCalculate — Funzione di calcolo principale (eseguita ad ogni tick)|
//|                                                                    |
//| ARCHITETTURA: 7 sezioni eseguite in sequenza per ogni barra.     |
//|                                                                    |
//|   ┌─────────────────────────────────────────────────────────────┐ |
//|   │ PRE-LOOP: Copy ATR/MA, determinazione start, reset globali  │ |
//|   ├─────────────────────────────────────────────────────────────┤ |
//|   │ MAIN LOOP (i = start..0, as-series):                        │ |
//|   │  1. Donchian Channel  — Upper, Lower, Mid, OHLC candles    │ |
//|   │  2. Midline Color     — lime (up) / red (down)              │ |
//|   │  3. Moving Average    — buffer visivo (InpShowMA)           │ |
//|   │  4. ATR + EMA(200)    — volatilita' e offset frecce        │ |
//|   │  4.5 SmartCooldown    — check tocco midline per cooldown   │ |
//|   │  4.6 TP Target Line   — detection multi-target TP fisso    │ |
//|   │  5. Signal Detection  — 4 fasi: base→cooldown→MA→esecuzione│ |
//|   │     (6 filtri: Flatness, TrendCtx, LevelAge, Width, Time, MA)│|
//|   ├─────────────────────────────────────────────────────────────┤ |
//|   │ POST-LOOP (eseguiti una volta per tick):                     │ |
//|   │  5a. Fix #1 Reset     — anti-duplicato Touch Trigger        │ |
//|   │  5b. Touch Trigger    — Buffer 18 per EA (+1/-1)            │ |
//|   │  6. Forecast          — cono di proiezione (solo nuova barra)│|
//|   │  7. Canvas Redraw     — fill trasparenti CCanvas            │ |
//|   └─────────────────────────────────────────────────────────────┘ |
//|                                                                    |
//| COMPORTAMENTO INCREMENTALE:                                        |
//|   prev_calculated==0: full recalc (tutte le barre + reset stati) |
//|   Nuovo tick stessa barra: start=1 (i=1 e i=0)                   |
//|   Nuova barra: start=2 (i=2, i=1=appena chiusa, i=0=nuova)      |
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
   //    g_dcLen_eff per Donchian, g_maLen_eff per MA, +200 per EMA(ATR,200), +10 di margine
   int minBars = MathMax(g_dcLen_eff, g_maLen_eff) + 210;
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
      int sqrtLen = (int)MathRound(MathSqrt((double)g_maLen_eff));
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
      start = rates_total - g_dcLen_eff - 3;
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

      //--- v7.19: Reset stato LTF Entry (Section 5c)
      //    Riporta la macchina a stati LTF al suo stato iniziale.
      //    Necessario quando prev_calculated==0 (cambio TF, ricalcolo completo, primo avvio)
      //    per evitare che una finestra rimasta aperta da un TF precedente generi
      //    conferme spurie sul nuovo TF. Il Buffer 20 viene resettato sotto (ArrayInitialize).
      g_ltfWindowOpen    = false;    // chiudi qualsiasi finestra LTF aperta
      g_ltfDirection     = 0;        // nessuna direzione attesa
      g_ltfBandLevel     = 0.0;      // livello banda da monitorare
      g_ltfWindowExpiry  = 0;        // nessuna scadenza
      g_ltfLastProcessed = 0;        // nessuna barra LTF già processata
      g_ltfConfirmedBar  = 0;        // nessuna barra confermata (anti-riapertura + persistenza)
      g_prevBarTimeTT       = 0;

      //--- Pulisci SOLO oggetti TP stateful (dipendono da variabili globali resettate sopra)
      //    Le frecce segnale e gli entry dot NON vengono cancellati qui:
      //    i loro nomi sono basati su time[i], quindi il loop li sovrascrive senza flickering.
      //    La pulizia completa è in OnDeinit() (cambio TF, rimozione indicatore, parametri).
      //    MOTIVO: prev_calculated==0 scatta anche per scroll/resize/nuovi dati broker,
      //    e cancellare+ricreare causa flickering visibile (frecce compaiono e spariscono).
      DeleteTPTargetObjects();

      //--- Initialize EMA ATR array
      ArrayInitialize(g_emaATR, 0);
      ArrayInitialize(BufTouchTrigger, 0);   // Buffer 18: Touch Trigger EA
      ArrayInitialize(BufSignalType, 0);    // Buffer 19: v7.18 Pattern TBS/TWS (reset a PATTERN_NONE=0)
      ArrayInitialize(BufLTFEntry, 0);      // Buffer 20: v7.19 LTF Entry Signal (reset a 0=nessuno)
   }
   else
   {
      start = rates_total - prev_calculated + 1;
   }
   if(start < 0) start = 0;
   if(start > rates_total - g_dcLen_eff - 3) start = rates_total - g_dcLen_eff - 3;

   //--- Static variable for alert deduplication
   static datetime s_lastAlertBar = 0;

   //--- Main calculation loop (from oldest to newest in as-series)
   for(int i = start; i >= 0; i--)
   {
      //=== 1. DONCHIAN CHANNEL — Calcolo bande e midline ===
      //
      //    Il canale Donchian è il FONDAMENTO dell'indicatore.
      //    Definisce i livelli dove il prezzo viene considerato "estremo"
      //    e dove la strategia Turtle Soup cerca le inversioni.
      //
      //    FORMULA:
      //      Upper = massimo degli HIGH delle ultime g_dcLen_eff barre
      //      Lower = minimo dei LOW delle ultime g_dcLen_eff barre
      //      Mid   = (Upper + Lower) / 2 = centro del canale
      //
      //    OUTPUT BUFFER (scritti qui per ogni barra [i]):
      //      BufUpper[i]    — banda superiore (livello di resistenza Donchian)
      //      BufLower[i]    — banda inferiore (livello di supporto Donchian)
      //      BufMid[i]      — midline (target TP per la strategia Soup)
      //      BufMidOffset[i]— midline di 2 barre fa (per fill color-switch)
      //      BufFillUp[i]   — = BufUpper (per CCanvas fill, DRAW_NONE)
      //      BufFillDn[i]   — = BufLower (per CCanvas fill, CALCULATIONS)
      //      g_rngArray[i]  — upper-lower = ampiezza canale (per slope forecast)
      //      BufCandleOHLC  — copia OHLC per DRAW_COLOR_CANDLES (Plot 10)
      //
      double highest = high[i];
      for(int k = 1; k < g_dcLen_eff && (i + k) < rates_total; k++)
         if(high[i + k] > highest) highest = high[i + k];

      double lowest = low[i];
      for(int k = 1; k < g_dcLen_eff && (i + k) < rates_total; k++)
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

      //=== 2. MIDLINE COLOR — Colore dinamico della linea mediana ===
      //
      //    La midline cambia colore in base alla direzione:
      //      BufMidColor[i] = 0 → lime (midline in salita = canale bullish)
      //      BufMidColor[i] = 1 → red  (midline in discesa = canale bearish)
      //
      //    CONFRONTO: BufMid[i] vs BufMid[i+2] (midline di 2 barre fa)
      //      Perche' [i+2] e non [i+1]: riduce il rumore dei micro-movimenti
      //      (il Donchian si muove a "step", un confronto troppo ravvicinato
      //      oscillerebbe troppo tra lime e red).
      //
      //    SE uguali: eredita il colore dalla barra precedente [i+1]
      //      → evita il flickering quando la midline e' piatta.
      //
      //    Usato da: DRAW_COLOR_LINE (Plot 0) con 2 color indexes.
      //
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

      //=== 3. MOVING AVERAGE — Buffer visivo MA (Plot 5) ===
      //
      //    Copia il valore MA calcolato (g_maValues[i]) nel buffer di plot.
      //    La MA viene calcolata PRIMA del main loop (CopyBuffer + HMA manual).
      //    Qui si decide solo SE mostrarla nel buffer visivo.
      //
      //    LOGICA:
      //      InpShowMA=true: BufMA[i] = valore MA (linea visibile sul chart)
      //      InpShowMA=false AND InpSignalFilter=true: BufMA=EMPTY_VALUE
      //        (MA calcolata ma non visibile — usata SOLO dal filtro in Section 5)
      //      Entrambi false: BufMA=EMPTY_VALUE (MA non calcolata ne' mostrata)
      //
      //    TIPI DI MA (calcolati prima del loop):
      //      SMA/EMA/WMA: via iMA() handle → CopyBuffer in g_maValues
      //      HMA: 3-step manuale:
      //        1. WMA(N/2) via iMA handle → g_hmaHalfValues
      //        2. WMA(N) via iMA handle → g_hmaFullValues
      //        3. WMA(sqrt(N)) su 2*WMA(N/2)-WMA(N) → g_maValues (ManualWMA)
      //
      if(InpShowMA || InpSignalFilter)
         BufMA[i] = InpShowMA ? g_maValues[i] : EMPTY_VALUE;
      else
         BufMA[i] = EMPTY_VALUE;

      //=== 4. ATR E EMA(ATR, 200) — Volatilita' e offset frecce ===
      //
      //    Due valori calcolati qui per ogni barra:
      //
      //    BufATR[i] = ATR(14) grezzo (Buffer 17, CALCULATIONS)
      //      Usato da: Band Flatness (soglia), Trend Context (threshold),
      //      Channel Width (in pip), tooltip (Width/ATR).
      //
      //    g_emaATR[i] = EMA(ATR, 200) calcolata manualmente
      //      Formula: EMA = alpha * val + (1-alpha) * EMA_prev
      //      con alpha = 2/(200+1) = 0.00995
      //      Usato da: offset frecce segnale (freccia a distanza 1.5x EMA ATR
      //      dalla banda → posizionamento stabile indipendente dalla volatilita'
      //      del singolo tick). L'EMA(200) è più liscia dell'ATR(14) grezzo.
      //
      //    NOTA: g_emaATR NON è un buffer indicatore — è un array globale.
      //      Non può essere letto dall'EA, serve solo per il calcolo interno.
      //
      double atrVal = atrTemp[i];
      BufATR[i] = atrVal;
      double alpha = 2.0 / (200.0 + 1.0);
      if(i + 1 < rates_total && g_emaATR[i + 1] > 0)
         g_emaATR[i] = alpha * atrVal + (1.0 - alpha) * g_emaATR[i + 1];
      else
         g_emaATR[i] = atrVal;

      //=== 4.5 SMARTCOOLDOWN: Check Midline Touch ===
      //
      //    SCOPO: Monitorare se il prezzo ha raggiunto la midline MOBILE (BufMid[i])
      //    dopo l'ultimo segnale. Questo è il CUORE del sistema SmartCooldown
      //    per i segnali nella STESSA direzione (es. BUY dopo BUY).
      //
      //    LOGICA (attiva solo se g_waitingForTP == true):
      //      BUY precedente (g_lastDirection=+1): high[i] >= BufMid[i] → tocco midline
      //      SELL precedente (g_lastDirection=-1): low[i]  <= BufMid[i] → tocco midline
      //
      //    AL TOCCO MIDLINE:
      //      1. g_midlineTouched = true  → sblocca il cooldown stesso-verso in Section 5
      //      2. g_midlineTouchBar = bar_index → per contare N barre dopo il tocco
      //      3. g_waitingForTP = false → smette di monitorare (fino al prossimo segnale)
      //
      //    PERCHE' SERVE:
      //      Se il prezzo tocca la lower band (BUY) e poi NON raggiunge la midline,
      //      significa che il trade è in loss (il prezzo non è tornato al centro).
      //      In questo caso NON accettare un secondo BUY identico (accumulo perdente).
      //      La midline MOBILE (BufMid[i]) segue il canale in tempo reale.
      //
      //    v7.14c: Semplificato — solo logica SmartCooldown, nessun elemento visivo.
      //    Il TP visivo è gestito SOLO da Section 4.6 (TP Target, midline FISSA).

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

      //=== 4.6 TP TARGET LINE — Detection multi-target su livello FISSO (v7.02) ===
      //
      //    SCOPO: Verificare ad ogni barra se il prezzo ha raggiunto uno dei
      //    livelli TP attivi. Ogni TP è una linea orizzontale piazzata sulla
      //    MIDLINE al momento del segnale (livello FISSO, non si muove).
      //
      //    DIFFERENZA CON SECTION 4.5:
      //      Section 4.5: midline MOBILE (BufMid[i]) → per SmartCooldown (logica)
      //      Section 4.6: midline FISSA (salvata in g_activeTPTargets[].price) → per TP visivo
      //
      //    MULTI-TARGET (v7.02):
      //      Ogni segnale crea un target indipendente (CreateTPTarget).
      //      I target precedenti NON vengono invalidati da nuovi segnali.
      //      Piu' TP possono essere attivi contemporaneamente.
      //      Loop al contrario (t = n-1..0) per safe ArrayRemove.
      //
      //    LOGICA PER-TARGET:
      //      BUY:  high[i] >= target price → prezzo ha raggiunto il TP
      //      SELL: low[i]  <= target price → prezzo ha raggiunto il TP
      //      → CloseTPTarget: ferma linea, piazza stella gialla, linea connessione
      //
      //    SCADENZA (v7.15, InpTPTargetExpiry):
      //      Se un target non viene raggiunto entro N barre (default 300),
      //      diventa grigio e viene rimosso → evita accumulo infinito di linee.
      //
      //    RISULTATO VISIVO:
      //      TP raggiunto: linea solida → ★ gialla + linea tratteggiata freccia→stella
      //      TP mancato:   linea grigia puntinata (scaduto) → pallino grigio

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
      //      bearCond = bearBase && bearCooldownOK
      //      v7.18: + MA filter (solo in BAR_CLOSE mode, close stabile)
      //
      //    FASE 4 — Esecuzione Segnale:
      //      Freccia, buffer, TP Target, Entry Dot, Alert
      //      v7.18: + classificazione TBS/TWS (Buffer 19) e label [TBS]/[TWS]
      //      i=0: solo freccia e buffer (TP/Entry alla chiusura barra)
      //
      BufSignalUp[i]    = EMPTY_VALUE;
      BufSignalDn[i]    = EMPTY_VALUE;
      BufSignalUpBig[i] = EMPTY_VALUE;
      BufSignalDnBig[i] = EMPTY_VALUE;
      BufTouchTrigger[i] = 0;
      BufSignalType[i]   = 0;   // v7.18: reset pattern TBS/TWS (verrà scritto in bearCond/bullCond se segnale)

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

         //--- v7.18: BAR_CLOSE vs INTRABAR signal detection
         //
         //    Questo è il CUORE della logica anti-repaint v7.18.
         //    La modalità trigger determina QUANDO e COME si attiva bearBase/bullBase.
         //
         //    ╔══════════════════════════════════════════════════════════════════════╗
         //    ║  BAR_CLOSE (i >= 1, barra chiusa):                                ║
         //    ║                                                                     ║
         //    ║  Condizione: tocco + rejection (Turtle Soup pattern)               ║
         //    ║    SELL: high[i] >= upper[i]  →  prezzo ha raggiunto/sfondato upper║
         //    ║          AND close[i] < upper[i]  →  ma ha CHIUSO sotto (rejection)║
         //    ║    BUY:  low[i] <= lower[i]   →  prezzo ha raggiunto/sfondato lower║
         //    ║          AND close[i] > lower[i]  →  ma ha CHIUSO sopra (rejection)║
         //    ║                                                                     ║
         //    ║  Se close è OLTRE la banda = breakout vero → bearBase/bullBase=false║
         //    ║  → Zero repaint: i>=1 ha close definitivo, il segnale non cambia.  ║
         //    ║  → i==0 (barra live): SKIP totale (bearBase=false, bullBase=false). ║
         //    ╚══════════════════════════════════════════════════════════════════════╝
         //
         //    ╔══════════════════════════════════════════════════════════════════════╗
         //    ║  INTRABAR (qualsiasi i, incluso barra live i=0):                   ║
         //    ║                                                                     ║
         //    ║  Condizione: solo tocco (nessun check close, legacy FIRST_CANDLE)  ║
         //    ║    SELL: high[i] >= upper[i]  →  high È il massimo del periodo DC  ║
         //    ║    BUY:  low[i] <= lower[i]   →  low È il minimo del periodo DC    ║
         //    ║                                                                     ║
         //    ║  Nota: high=upper è vera SOLO quando high[i] ha CREATO il massimo  ║
         //    ║  del periodo Donchian, quindi il prezzo è ESATTAMENTE sulla banda. ║
         //    ║  → Repaint possibile: se la barra poi chiude oltre, il segnale     ║
         //    ║    sparisce al ricalcolo successivo.                                ║
         //    ╚══════════════════════════════════════════════════════════════════════╝
         //
         if(InpTriggerModeV2 == TRIGGER_BAR_CLOSE)
         {
            //--- BAR_CLOSE: segnale confermato alla chiusura (zero repaint)
            //    i>=1: barra chiusa, close definitivo → condizione stabile e irreversibile
            //    i==0: barra live → skip totale (bearBase e bullBase restano false)
            if(i >= 1)
            {
               bearBase = (high[i] >= BufUpper[i]) && (close[i] < BufUpper[i]);   // tocco upper + chiusura dentro canale
               bullBase = (low[i]  <= BufLower[i]) && (close[i] > BufLower[i]);   // tocco lower + chiusura dentro canale
            }
            // else: i == 0 → bearBase=false, bullBase=false (nessun segnale su barra live → zero repaint)
         }
         else  // TRIGGER_INTRABAR
         {
            //--- INTRABAR (legacy FIRST_CANDLE): segnale immediato al tocco
            //    Nessun check su close → il segnale appare appena high/low raggiunge la banda
            //    ⚠ Può repaintare: il segnale apparso su i=0 potrebbe sparire dopo la chiusura
            bearBase = (high[i] >= BufUpper[i]);   // high tocca/sfonda upper → candidato SELL
            bullBase = (low[i]  <= BufLower[i]);    // low tocca/sfonda lower → candidato BUY
         }

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
         //    soglia = g_flatTol_eff × ATR(14)[i]        (v7.19: preset per TF, vedi MOD-03/04)
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
            //    v7.19: g_flatTol_eff è calibrato per TF (M5=0.40, M15=0.50, H1=0.38, H4=0.35)
            //    Esempio EURUSD M15: ATR(14) ≈ 12 pip → soglia = 0.50 × 12 = 6 pip
            //    Se la upper è salita di più di 6 pip → trend attivo → blocca SELL
            double flatTolerance = g_flatTol_eff * BufATR[i];  // v7.19: usa preset per TF invece di input fisso

            //--- Clamp del lookback: forza nel range [1, 10]
            int flatLookback = (int)MathMax(1, MathMin(10, g_flatLook_eff));

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
         if(InpUseTrendContext && BufATR[i] > 0 && (i + g_dcLen_eff) < rates_total)
         {
            double trendThreshold = InpTrendContextMultiple * BufATR[i];
            double midNow  = BufMid[i];              // midline della barra corrente
            double midThen = BufMid[i + g_dcLen_eff];   // midline g_dcLen_eff barre fa

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
               for(int k = 1; k < g_dcLen_eff && (i + k) < rates_total; k++)
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
               for(int k = 1; k < g_dcLen_eff && (i + k) < rates_total; k++)
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
            if(channelWidthPips < g_minWidth_eff)
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
            bearCooldownOK = (barsFromLast >= g_dcLen_eff);
            bullCooldownOK = (barsFromLast >= g_dcLen_eff);
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
         //--- v7.18: FILTRO MA CONDIZIONALE — riattivato SOLO in BAR_CLOSE mode
         //
         //    STORICO: Nelle versioni v7.13-v7.17 questo blocco era disattivato con if(false).
         //    Motivo: in modalità FIRST_CANDLE (ora INTRABAR), close[0] è PROVVISORIO
         //    (cambia ad ogni tick) → confrontarlo con la MA genera segnali instabili.
         //    Il filtro veniva delegato interamente all'EA alla conferma (chiusura barra).
         //
         //    v7.18 NOVITÀ: In BAR_CLOSE mode, close[i] per i>=1 è DEFINITIVO (barra chiusa).
         //    Il confronto close vs MA è AFFIDABILE → il filtro può essere applicato
         //    DIRETTAMENTE nell'indicatore, riducendo i falsi segnali PRIMA che l'EA li legga.
         //
         //    CONDIZIONI DI ATTIVAZIONE (tutte e 3 devono essere vere):
         //      1. InpSignalFilter = true (l'utente ha abilitato il filtro MA)
         //      2. InpTriggerModeV2 == TRIGGER_BAR_CLOSE (close stabile e definitivo)
         //      3. i >= 1 (barra chiusa — ridondante con BAR_CLOSE ma esplicita per sicurezza)
         //
         //    Se INTRABAR: questo blocco viene SALTATO → il filtro MA resta delegato all'EA.
         //    Se InpSignalFilter=false: blocco saltato → tutti i segnali passano.
         //
         //    MODALITÀ CLASSICA vs INVERTITA (InpMAFilterMode):
         //      CLASSIC: SELL se close < MA, BUY se close > MA (trend-following Zeiierman)
         //      INVERTED: SELL se close > MA, BUY se close < MA (mean-reversion Turtle Soup)
         //
         if(InpSignalFilter && InpTriggerModeV2 == TRIGGER_BAR_CLOSE && i >= 1)
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

            //--- v7.18: CLASSIFICAZIONE PATTERN TBS/TWS — Segnale SELL
            //
            //    Classifica la QUALITÀ della rejection sulla upper band analizzando
            //    quanto il CORPO della candela è penetrato oltre la banda.
            //    Il risultato viene scritto in BufSignalType[i] (Buffer 19) per l'EA.
            //
            //    TBS (Turtle Bar Soup) — BufSignalType = 3.0:
            //      Il BODY HIGH (= max(open, close)) è SOPRA la upper band.
            //      → Il corpo della candela ha effettivamente sfondato la banda.
            //      → Forte rejection: i trader che hanno comprato il breakout
            //        sono ora INTRAPPOLATI sopra la banda con stop ravvicinati.
            //      → La candela ha chiuso DENTRO il canale (close < upper, già verificato da bearBase).
            //
            //      Esempio visivo SELL TBS (candela ribassista):
            //        ─── upper band ────────
            //           │    │ ← wick sopra (irrilevante per TBS)
            //           ┌────┐ ← OPEN sopra upper = corpo sfonda → TBS!
            //        ───┤    │───────────────
            //           └────┘ ← CLOSE sotto upper (rejection confermata)
            //
            //    TWS (Turtle Wick Soup) — BufSignalType = 1.0:
            //      Il BODY HIGH è SOTTO o UGUALE alla upper band.
            //      → Solo lo WICK (shadow superiore) ha toccato/sfondato la banda.
            //      → Debole rejection: sondaggio timido, meno trader intrappolati.
            //
            //      Esempio visivo SELL TWS (candela ribassista):
            //           │    │ ← wick sfonda upper → TWS
            //        ───┬────┬───────────────
            //           ┌────┐ ← OPEN sotto upper
            //           └────┘ ← CLOSE sotto upper (corpo interamente dentro)
            //        ─── lower band ────────
            //
            //    GUARDIA i>=1: su barra live (i=0) il corpo non è definito → skip.
            //
            if(i >= 1)
            {
               if(MathMax(open[i], close[i]) > BufUpper[i])
                  BufSignalType[i] = (double)PATTERN_TBS;   // 3.0 — corpo sfondava upper (forte)
               else
                  BufSignalType[i] = (double)PATTERN_TWS;   // 1.0 — solo wick sfondava (debole)
            }

            //--- v7.19: Filtro visivo TWS — nasconde freccia + label + candela trigger
            //
            //    QUANDO ATTIVO (InpShowTWSSignals=false E pattern classificato come TWS):
            //      Nasconde tutti gli elementi visivi del segnale TWS dal chart:
            //        1. BufSignalDn[i] = EMPTY_VALUE → DRAW_ARROW Plot 7 non renderizza freccia
            //        2. CreateSignalArrow skippata → nessun OBJ_TEXT "TRIGGER SELL [TWS]" orfano
            //        3. BufCandleColor non toccata → candela NON colorata di giallo
            //
            //    COSA RESTA INVARIATO (per l'EA):
            //      - BufSignalType[i] = PATTERN_TWS (1.0) → Buffer 19 scritto sopra (blocco classificazione)
            //      - BufTouchTrigger[0] → scritto in Section 5b indipendentemente
            //      - TP Target, Entry Dot, Alert → ancora creati (blocco if(i>=1) sotto)
            //      L'EA riceve il segnale completo anche se il chart non mostra nulla.
            //
            //    FIX: inserito DOPO classificazione TBS/TWS (BufSignalType[i] scritto nel blocco sopra).
            //    Se fosse PRIMA, BufSignalType[i] sarebbe 0 (PATTERN_NONE) → filtro mai attivo.
            //
            bool twsFiltered_s = (!InpShowTWSSignals && BufSignalType[i] == (double)PATTERN_TWS);
            if(twsFiltered_s)
               BufSignalDn[i] = EMPTY_VALUE;  // nascondi freccia SELL TWS dal DRAW_ARROW

            //--- Calcola dati tooltip (v7.00)
            double wRatio_s = (BufATR[i] > 0) ? (BufUpper[i] - BufLower[i]) / BufATR[i] : 0;

            //--- Crea freccia SELL rossa ⬇ con etichetta e tooltip
            //    v7.19: skip completo se TWS filtrato — evita label OBJ_TEXT orfano e candela gialla
            //    senza freccia associata (incoerenza visiva confusa per l'utente).
            if(!twsFiltered_s)
            {
               CreateSignalArrow(time[i], sellPrice, false, offset, close[i], BufMid[i],
                                wRatio_s, true, (int)BufSignalType[i]);

               //--- Candela Trigger: colora la candela di giallo via DRAW_COLOR_CANDLES (v7.10)
               //    BufCandleColor[i] = 2.0 → color index 2 = InpColTriggerCandle (giallo)
               //    La candela viene disegnata dal Plot 10 con lo stesso rendering engine di MT5
               //    → larghezza pixel-perfect, identica alle altre candele a qualsiasi zoom.
               if(InpShowTriggerCandle)
                  BufCandleColor[i] = 2.0;
            }

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
               if(InpShowEntryDot)
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
               if(InpAlertPopup) Alert(msg);
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

            //--- v7.18: CLASSIFICAZIONE PATTERN TBS/TWS — Segnale BUY
            //
            //    Classifica la QUALITÀ della rejection sulla lower band analizzando
            //    quanto il CORPO della candela è penetrato oltre la banda.
            //    Logica SPECULARE al blocco SELL (vedi commenti dettagliati sopra).
            //
            //    TBS (Turtle Bar Soup) — BufSignalType = 3.0:
            //      Il BODY LOW (= min(open, close)) è SOTTO la lower band.
            //      → Il corpo della candela ha sfondato la banda verso il basso.
            //      → Forte rejection: trader short intrappolati sotto la banda.
            //
            //      Esempio visivo BUY TBS (candela rialzista):
            //        ─── upper band ────────
            //           ┌────┐ ← CLOSE sopra lower (rejection confermata)
            //        ───┤    │───────────────
            //           └────┘ ← OPEN sotto lower = corpo sfonda → TBS!
            //           │    │ ← wick sotto (irrilevante per TBS)
            //        ─── lower band ────────
            //
            //    TWS (Turtle Wick Soup) — BufSignalType = 1.0:
            //      Il BODY LOW è SOPRA o UGUALE alla lower band.
            //      → Solo lo wick inferiore ha toccato/sfondato la banda.
            //      → Debole rejection: sondaggio timido.
            //
            //    GUARDIA i>=1: su barra live (i=0) il corpo non è definito → skip.
            //
            if(i >= 1)
            {
               if(MathMin(open[i], close[i]) < BufLower[i])
                  BufSignalType[i] = (double)PATTERN_TBS;   // 3.0 — corpo sfondava lower (forte)
               else
                  BufSignalType[i] = (double)PATTERN_TWS;   // 1.0 — solo wick sfondava (debole)
            }

            //--- v7.19: Filtro visivo TWS — nasconde freccia + label + candela trigger
            //
            //    QUANDO ATTIVO (InpShowTWSSignals=false E pattern classificato come TWS):
            //      Nasconde tutti gli elementi visivi del segnale TWS dal chart:
            //        1. BufSignalUp[i] = EMPTY_VALUE → DRAW_ARROW Plot 6 non renderizza freccia
            //        2. CreateSignalArrow skippata → nessun OBJ_TEXT "TRIGGER BUY [TWS]" orfano
            //        3. BufCandleColor non toccata → candela NON colorata di giallo
            //
            //    COSA RESTA INVARIATO (per l'EA):
            //      - BufSignalType[i] = PATTERN_TWS (1.0) → Buffer 19 scritto sopra (blocco classificazione)
            //      - BufTouchTrigger[0] → scritto in Section 5b indipendentemente
            //      - TP Target, Entry Dot, Alert → ancora creati (blocco if(i>=1) sotto)
            //      L'EA riceve il segnale completo anche se il chart non mostra nulla.
            //
            //    FIX: inserito DOPO classificazione TBS/TWS (BufSignalType[i] scritto nel blocco sopra).
            //    Se fosse PRIMA, BufSignalType[i] sarebbe 0 (PATTERN_NONE) → filtro mai attivo.
            //
            bool twsFiltered_b = (!InpShowTWSSignals && BufSignalType[i] == (double)PATTERN_TWS);
            if(twsFiltered_b)
               BufSignalUp[i] = EMPTY_VALUE;  // nascondi freccia BUY TWS dal DRAW_ARROW

            //--- Calcola dati tooltip (v7.00)
            double wRatio_b = (BufATR[i] > 0) ? (BufUpper[i] - BufLower[i]) / BufATR[i] : 0;

            //--- Crea freccia BUY verde ⬆ con etichetta e tooltip
            //    v7.19: skip completo se TWS filtrato — evita label OBJ_TEXT orfano e candela gialla
            //    senza freccia associata (incoerenza visiva confusa per l'utente).
            if(!twsFiltered_b)
            {
               CreateSignalArrow(time[i], buyPrice, true, offset, close[i], BufMid[i],
                                wRatio_b, true, (int)BufSignalType[i]);

               //--- Candela Trigger: colora la candela di giallo via DRAW_COLOR_CANDLES (v7.10)
               //    BufCandleColor[i] = 2.0 → color index 2 = InpColTriggerCandle (giallo)
               if(InpShowTriggerCandle)
                  BufCandleColor[i] = 2.0;
            }

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
               if(InpShowEntryDot)
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
               if(InpAlertPopup) Alert(msg);
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

   //=== 5b. TOUCH TRIGGER — Buffer 18 per EA (INTRABAR/BAR_CLOSE, v7.18) ===
   //
   //    SCOPO: Scrivere +1 (BUY) o -1 (SELL) nel Buffer 18 per comunicare
   //    il segnale all'EA. L'EA legge CopyBuffer(handle, 18, 0, 1, val) ad ogni tick.
   //
   //    DIFFERENZA CON SECTION 5:
   //    - Section 5 (main loop): crea frecce visive e buffer dati per TUTTE le barre (i=0..start)
   //    - Section 5b: scrive SOLO nel Buffer 18, processa SOLO barra live/recente
   //    - Section 5b usa lo stato CONFERMATO (g_lastMarkerBar non corrotto da Fix #2)
   //
   //    v7.18: ADATTAMENTO PER BAR_CLOSE / INTRABAR
   //    ┌──────────────┬────────────────────────────────────────────────────┐
   //    │ INTRABAR     │ Controlla barra [0] (live) ad ogni tick.          │
   //    │              │ Fallback su [1] se [0] non tocca.                 │
   //    │              │ Buffer 18 scritto IMMEDIATAMENTE al tocco.        │
   //    │              │ L'EA può entrare PRIMA della chiusura barra.      │
   //    │              │ MA filter DELEGATO all'EA (close instabile).      │
   //    ├──────────────┼────────────────────────────────────────────────────┤
   //    │ BAR_CLOSE    │ Controlla SOLO barra [1] (ultima chiusa).         │
   //    │              │ Richiede close-based rejection (close dentro).    │
   //    │              │ Buffer 18 stabile: cambia solo a nuova chiusura.  │
   //    │              │ L'EA entra DOPO la chiusura (segnale confermato). │
   //    │              │ MA filter ATTIVO nell'indicatore (close stabile). │
   //    └──────────────┴────────────────────────────────────────────────────┘
   //
   //    ANTI-DUPLICATO:
   //    - g_lastTouchTriggerBar = time[0] del trigger emesso
   //    - g_lastTouchDirection = direzione del trigger (+1 o -1)
   //    - Tick successivi: alreadyTriggeredThisBar = TRUE → else mantiene valore
   //    - Nuova barra: Fix #1 resetta g_lastTouchDirection → nuovo trigger possibile
   //
   //    FILTRI APPLICATI: Cooldown, Detection Window, Midline Touch, Anti-ambiguità
   //    FILTRI DELEGATI ALL'EA (in INTRABAR): MA filter, close<midline
   //
   //    PRIORITÀ EMISSIONE (Fix #3):
   //    1. Entrambe bande toccate → ambiguo → BufTouchTrigger = 0
   //    2. Tocco corrente Lower + cooldown → BUY (+1)
   //    3. Tocco corrente Upper + cooldown → SELL (-1)
   //    4. Tocco da window Lower + cooldown → BUY (fallback)
   //    5. Tocco da window Upper + cooldown → SELL (fallback)
   //
   if(rates_total > g_dcLen_eff + 3)  // v7.13: guard semplificato (CLASSIC rimosso)
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
            bearCooldownOK_touch = (barsFromLast_touch >= g_dcLen_eff);
            bullCooldownOK_touch = (barsFromLast_touch >= g_dcLen_eff);
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

         //--- v7.18: DETECTION TOCCO BANDE — BAR_CLOSE vs INTRABAR
         //
         //    Questo blocco determina se c'è stato un tocco VALIDO delle bande Donchian
         //    per il Touch Trigger (Buffer 18). La logica è DIVERSA in base alla modalità trigger.
         //
         //    ╔══════════════════════════════════════════════════════════════════════╗
         //    ║  BAR_CLOSE: usa barra [1] (ultima barra CHIUSA)                    ║
         //    ║                                                                     ║
         //    ║  Tocco valido = tocco banda + close DENTRO il canale (rejection).   ║
         //    ║  La barra [0] (live) viene COMPLETAMENTE IGNORATA:                 ║
         //    ║    - currentBarTouch* si riferisce alla [1], non alla [0]           ║
         //    ║    - Il Buffer 18 cambia valore SOLO quando una NUOVA barra chiude  ║
         //    ║    - L'EA legge un valore stabile, non soggetto a repaint tick      ║
         //    ║                                                                     ║
         //    ║  SELL: high[1]>=upper[1] AND close[1]<upper[1] (rejection upper)   ║
         //    ║  BUY:  low[1]<=lower[1]  AND close[1]>lower[1] (rejection lower)   ║
         //    ╚══════════════════════════════════════════════════════════════════════╝
         //
         //    ╔══════════════════════════════════════════════════════════════════════╗
         //    ║  INTRABAR: logica originale v6.01-v7.17                            ║
         //    ║                                                                     ║
         //    ║  Prima check: barra [0] (live) — segnale immediato al tick.        ║
         //    ║  Fallback [1]: se [0] non tocca, controlla [1] (ultima chiusa).    ║
         //    ║  Il fallback copre il caso in cui l'EA non legge Buffer 18 prima   ║
         //    ║  della chiusura barra (il tocco su [0] sarebbe perso).             ║
         //    ║                                                                     ║
         //    ║  SELL: high[0]>=upper[0] → tocco immediato (o fallback high[1])    ║
         //    ║  BUY:  low[0]<=lower[0]  → tocco immediato (o fallback low[1])     ║
         //    ║  Nessun check su close → ⚠ può includere breakout veri.            ║
         //    ╚══════════════════════════════════════════════════════════════════════╝
         //
         bool currentBarTouchLower = false;
         bool currentBarTouchUpper = false;
         bool bullTouched_touch = false;
         bool bearTouched_touch = false;

         if(InpTriggerModeV2 == TRIGGER_BAR_CLOSE)
         {
            //--- BAR_CLOSE: barra [1] chiusa con close-based rejection (zero repaint)
            if(rates_total >= 2)
            {
               currentBarTouchLower = (low[1] <= BufLower[1]) && (close[1] > BufLower[1]);   // tocco lower + close dentro
               currentBarTouchUpper = (high[1] >= BufUpper[1]) && (close[1] < BufUpper[1]);  // tocco upper + close dentro
            }
            bullTouched_touch = currentBarTouchLower;   // tocco lower → candidato BUY
            bearTouched_touch = currentBarTouchUpper;    // tocco upper → candidato SELL
         }
         else  // TRIGGER_INTRABAR: logica originale v6.01-v7.17
         {
            //--- Prima check: barra [0] (live) per segnale immediato
            currentBarTouchLower = (low[0] <= BufLower[0]);    // low raggiunge/sfonda lower
            currentBarTouchUpper = (high[0] >= BufUpper[0]);   // high raggiunge/sfonda upper
            bullTouched_touch = currentBarTouchLower;
            bearTouched_touch = currentBarTouchUpper;
            //--- Fallback [1]: se [0] non tocca, controlla ultima barra chiusa
            if(!bullTouched_touch && rates_total >= 2)
            {
               if(low[1] <= BufLower[1])
                  bullTouched_touch = true;   // la barra precedente aveva toccato lower
            }
            if(!bearTouched_touch && rates_total >= 2)
            {
               if(high[1] >= BufUpper[1])
                  bearTouched_touch = true;   // la barra precedente aveva toccato upper
            }
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
         //    soglia = g_flatTol_eff × ATR(14)[1]          (v7.19: preset per TF, vedi MOD-03/04)
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
         if(InpUseBandFlatness && ((1 + g_flatLook_eff) < rates_total) && BufATR[1] > 0)
         {
            //--- Soglia basata su ATR della barra [1] (chiusa, stabile)
            double flatTolerance_t = g_flatTol_eff * BufATR[1];  // v7.19: usa preset per TF invece di input fisso
            int flatLookback_t = (int)MathMax(1, MathMin(10, g_flatLook_eff));

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
         if(InpUseTrendContext && BufATR[1] > 0 && (1 + g_dcLen_eff) < rates_total)
         {
            double trendThreshold_t = InpTrendContextMultiple * BufATR[1];
            double midNow_t  = BufMid[1];
            double midThen_t = BufMid[1 + g_dcLen_eff];

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
               for(int k = 1; k < g_dcLen_eff && (1 + k) < rates_total; k++)
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
               for(int k = 1; k < g_dcLen_eff && (1 + k) < rates_total; k++)
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
            if(channelWidthPips_t < g_minWidth_eff)
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

   //=== 5c. LTF ENTRY SIGNAL — Buffer 20 (v7.19) ===
   //
   //   SCOPO: Rilevare la conferma sul TF inferiore (LTF) per un'entry temporalmente
   //   più precisa rispetto all'attesa della chiusura della barra del TF principale.
   //
   //   PRINCIPIO "Low TimeFrame Entry":
   //     Il canale Donchian del TF principale (es. M5) identifica il LIVELLO di entry.
   //     Il TF inferiore (es. M1) fornisce la CONFERMA temporale della rejection.
   //     Risultato: entry 2-4 min prima della chiusura barra M5, stessa qualità segnale.
   //
   //   ZERO REPAINT: usa iHigh/iLow/iClose con shift=1 (barra LTF chiusa, definitiva).
   //   Il Buffer 20 è scritto solo sulla barra corrente [0] — l'EA legge shift=0.
   //
   //   TF INFERIORI USATI (auto-adattivo):
   //     M5  → M1  (conferma in max 1 min invece di 5 min)
   //     M15 → M5  (conferma in max 5 min invece di 15 min)
   //     M30 → M5  (conferma in max 5 min invece di 30 min)
   //     H1  → M15 (conferma in max 15 min invece di 60 min)
   //     H4  → M30 (conferma in max 30 min invece di 4 ore)
   //
   //   FLUSSO:
   //     1. Buffer 18 emette segnale (Section 5b) → finestra LTF aperta
   //     2. Ogni tick: controlla se esiste una nuova barra LTF chiusa
   //     3. Se barra LTF: high/low tocca g_ltfBandLevel E close è dentro → Buffer 20 = ±1
   //     4. Dopo prima conferma O scadenza finestra → finestra chiusa, Buffer 20 = 0
   //
   //   L'EA legge: CopyBuffer(handle, 20, 0, 1, val)
   //     val == +1 → BUY LTF confermato → apri BUY ora (sul LTF, non aspettare M5)
   //     val == -1 → SELL LTF confermato → apri SELL ora
   //     val == 0  → nessuna conferma LTF ancora (continua ad aspettare o usa BAR_CLOSE standard)
   //
   //   FIX v7.19: persistenza segnale + anti-riapertura finestra
   //     g_ltfConfirmedBar evita che la finestra si riapra sulla stessa barra dopo conferma
   //     e mantiene BufLTFEntry[0] = ±1 per tutti i tick della barra confermata.
   //
   //   NOTA SINCRONIZZAZIONE CROSS-TF:
   //     Al primo caricamento dell'indicatore, i dati del TF inferiore (es. M1 su chart M5)
   //     potrebbero non essere ancora nella cache del terminale MT5.
   //     iTime/iHigh/iLow/iClose restituiranno 0 fino a quando i dati non arrivano.
   //     Il check ltfBarTime > 0 previene crash, ma la prima finestra LTF potrebbe
   //     scadere senza conferma. I segnali successivi funzioneranno normalmente.
   //
   {
      BufLTFEntry[0] = 0;  // default: nessuna conferma LTF attiva su questa barra

      if(InpEnableLTFEntry)
      {
         //--- Determina il TF inferiore da usare (auto-adattivo al TF del chart)
         ENUM_TIMEFRAMES ltfPeriod;
         switch(Period())
         {
            case PERIOD_M1:  ltfPeriod = PERIOD_M1;  break;  // v7.19+: M1 esplicito
                                                               // ATTENZIONE: LTF Entry su M1 non ha senso
                                                               // → impostare InpEnableLTFEntry=false su chart M1
            case PERIOD_M5:  ltfPeriod = PERIOD_M1;  break;
            case PERIOD_M15: ltfPeriod = PERIOD_M5;  break;
            case PERIOD_M30: ltfPeriod = PERIOD_M5;  break;
            case PERIOD_H1:  ltfPeriod = PERIOD_M15; break;
            case PERIOD_H4:  ltfPeriod = PERIOD_M30; break;
            default:         ltfPeriod = PERIOD_M1;  break;
         }

         //--- FIX v7.19: Persistenza segnale LTF confermato
         //    Se la conferma è avvenuta su questa barra, mantieni BufLTFEntry[0] = ±1
         //    per tutti i tick rimanenti (stessa logica di Section 5b per Buffer 18).
         if(g_ltfConfirmedBar == time[0] && g_ltfDirection != 0)
         {
            BufLTFEntry[0] = (double)g_ltfDirection;
         }
         else
         {
            //--- Apertura finestra LTF quando Buffer 18 emette un segnale
            //    NOTA: BufTouchTrigger[0] è già stato scritto in Section 5b (sopra).
            //    Apriamo la finestra solo se non è già aperta (un segnale per volta).
            //    FIX v7.19: && time[0] != g_ltfConfirmedBar → non riaprire sulla barra già confermata
            if(!g_ltfWindowOpen && BufTouchTrigger[0] != 0 && time[0] != g_ltfConfirmedBar)
            {
               g_ltfWindowOpen   = true;
               g_ltfDirection    = (int)BufTouchTrigger[0];  // +1 o -1
               g_ltfBandLevel    = (g_ltfDirection == -1) ? BufUpper[0] : BufLower[0];
               g_ltfWindowExpiry = time[0] + PeriodSeconds();  // valida per 1 barra del TF principale
               g_ltfLastProcessed = 0;

               Print("[DPC LTF] Finestra aperta | dir=", g_ltfDirection,
                     " banda=", DoubleToString(g_ltfBandLevel, _Digits),
                     " scade=", TimeToString(g_ltfWindowExpiry),
                     " LTF=", EnumToString(ltfPeriod));
            }

            //--- Monitoraggio finestra LTF attiva
            if(g_ltfWindowOpen)
            {
               //--- Controllo scadenza: se la barra principale è finita, reset finestra
               if(TimeCurrent() >= g_ltfWindowExpiry)
               {
                  Print("[DPC LTF] Finestra scaduta senza conferma LTF — reset.");
                  g_ltfWindowOpen = false;
               }
               else
               {
                  //--- Leggi la barra LTF più recente CHIUSA (shift=1 → zero repaint)
                  datetime ltfBarTime = iTime(_Symbol, ltfPeriod, 1);

                  //--- Anti-duplicato: processa ogni barra LTF UNA SOLA VOLTA
                  if(ltfBarTime > 0 && ltfBarTime != g_ltfLastProcessed)
                  {
                     g_ltfLastProcessed = ltfBarTime;

                     double ltfHigh  = iHigh(_Symbol,  ltfPeriod, 1);
                     double ltfLow   = iLow(_Symbol,   ltfPeriod, 1);
                     double ltfClose = iClose(_Symbol,  ltfPeriod, 1);

                     bool ltfConfirmed = false;

                     if(g_ltfDirection == -1)
                     {
                        //--- SELL LTF: candela LTF tocca upper band M5 E chiude dentro (rejection)
                        ltfConfirmed = (ltfHigh >= g_ltfBandLevel) && (ltfClose < g_ltfBandLevel);
                     }
                     else if(g_ltfDirection == +1)
                     {
                        //--- BUY LTF: candela LTF tocca lower band M5 E chiude dentro (rejection)
                        ltfConfirmed = (ltfLow <= g_ltfBandLevel) && (ltfClose > g_ltfBandLevel);
                     }

                     if(ltfConfirmed)
                     {
                        BufLTFEntry[0] = (double)g_ltfDirection;  // +1 o -1
                        g_ltfWindowOpen = false;  // chiudi finestra dopo prima conferma
                        g_ltfConfirmedBar = time[0];  // FIX v7.19: memorizza barra confermata per persistenza

                        Print("[DPC LTF] Conferma! dir=", g_ltfDirection,
                              " ltfBar=", TimeToString(ltfBarTime),
                              " high=", DoubleToString(ltfHigh, _Digits),
                              " close=", DoubleToString(ltfClose, _Digits),
                              " band=", DoubleToString(g_ltfBandLevel, _Digits));

                        //--- Disegna marcatore visivo opzionale
                        if(InpShowLTFMark)
                        {
                           string mName = SIGNAL_PREFIX + "LTF_" + IntegerToString((long)ltfBarTime);
                           //--- Offset piccolo per non sovrapporre la freccia principale DPC
                           double mPrice = (g_ltfDirection == -1)
                                          ? g_ltfBandLevel + g_emaATR[0] * 0.4
                                          : g_ltfBandLevel - g_emaATR[0] * 0.4;

                           if(ObjectFind(0, mName) < 0)  // crea solo se non esiste
                           {
                              ObjectCreate(0, mName, OBJ_ARROW, 0, ltfBarTime, mPrice);
                              //--- Triangoli piccoli: 242=▼ (sell), 241=▲ (buy)
                              ObjectSetInteger(0, mName, OBJPROP_ARROWCODE,
                                              (g_ltfDirection == -1) ? 242 : 241);
                              ObjectSetInteger(0, mName, OBJPROP_COLOR,
                                              (g_ltfDirection == -1) ? InpColTBS_Sell : InpColTBS_Buy);
                              ObjectSetInteger(0, mName, OBJPROP_WIDTH, 1);
                              ObjectSetInteger(0, mName, OBJPROP_BACK, false);
                              ObjectSetInteger(0, mName, OBJPROP_SELECTABLE, false);
                              ObjectSetInteger(0, mName, OBJPROP_HIDDEN, true);
                              ObjectSetString(0, mName, OBJPROP_TOOLTIP,
                                              "LTF Entry Confirmed (" + EnumToString(ltfPeriod) + ")\n" +
                                              "Band level: " + DoubleToString(g_ltfBandLevel, _Digits) + "\n" +
                                              "Close: " + DoubleToString(ltfClose, _Digits) + "\n" +
                                              "Direction: " + (g_ltfDirection == -1 ? "SELL" : "BUY"));
                           }
                        }
                     }
                  }
               }
            }
         }
      }  // end if(InpEnableLTFEntry)
   }

   //=== 6. FORECAST PROJECTION — Cono di proiezione Donchian ===
   //
   //    SCOPO: Proiettare il canale Donchian nel futuro a destra del chart.
   //    Mostra la direzione attesa del canale basata sulla regressione lineare
   //    delle ultime g_dcLen_eff barre (pendenza midline + pendenza range).
   //
   //    CALCOLO (eseguito solo su nuova barra, per performance):
   //      1. midSlope = LinearRegressionSlope(BufMid) → direzione del cono
   //      2. rngSlope = LinearRegressionSlope(g_rngArray) → espansione/contrazione
   //      3. DrawForecast() → genera InpProjLen punti e li disegna come OBJ_TREND
   //
   //    EQUIVALENZA PINE SCRIPT:
   //      Pine usa `barstate.islast` per eseguire il forecast una sola volta.
   //      In MQL5 non esiste barstate.islast → usiamo s_lastForecastBar per
   //      deduplicare: il forecast viene ricalcolato SOLO alla prima nuova barra.
   //
   //    OUTPUT VISIVO:
   //      3 serie di segmenti OBJ_TREND nel futuro del chart:
   //      - Upper forecast (verde tratteggiato)
   //      - Lower forecast (rosso tratteggiato)
   //      - Midline forecast (colore basato su midSlope, puntinato)
   //      + 2 etichette di prezzo agli endpoint finali
   //
   {
      static datetime s_lastForecastBar = 0;
      if(time[0] != s_lastForecastBar)
      {
         s_lastForecastBar = time[0];

         double midSlope = LinearRegressionSlope(BufMid, 0, g_dcLen_eff, rates_total);
         double rngSlope = LinearRegressionSlope(g_rngArray, 0, g_dcLen_eff, rates_total);

         DrawForecast(time, rates_total,
                      BufUpper[0], BufMid[0], BufLower[0],
                      midSlope, rngSlope);
      }
   }

   //=== 7. Redraw transparent canvas fills ===
   //    CCanvas disegna i fill ARGB trasparenti (canale DC + midline).
   //    DRAW_FILLING di MQL5 NON supporta trasparenza ARGB (alpha ignorato).
   //    CCanvas è l'UNICA soluzione per fill trasparenti.
   //    Viene chiamato sia qui che in OnChartEvent(CHARTEVENT_CHART_CHANGE).
   RedrawCanvas();

   return rates_total;
}
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
