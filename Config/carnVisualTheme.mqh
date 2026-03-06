//+------------------------------------------------------------------+
//|                                         carnVisualTheme.mqh      |
//|           El Carnevaal de Schignan v3.40 - "Arlecchino"          |
//|                                                                  |
//|  Colori hardcodati - editabili SOLO via codice sorgente          |
//|  NON visibili nelle impostazioni EA                              |
//|                                                                  |
//|  Palette: Nero maschera + Rosso/Giallo/Blu/Verde losanghe       |
//+------------------------------------------------------------------+
#property copyright "Sugamara Ribelle (C) 2026"

//+------------------------------------------------------------------+
//| CHART THEME — Sfondo + Candele (INVARIATI)                       |
//| Viola scurissimo + Verde/Rosso vivaci                            |
//+------------------------------------------------------------------+
#define THEME_CHART_BACKGROUND    C'20,18,30'           // Viola scurissimo (notte veneziana)
#define THEME_CHART_FOREGROUND    C'220,215,230'        // Testo chiaro lavanda
#define THEME_CANDLE_BULL         C'0,200,120'          // Verde smeraldo (Arlecchino)
#define THEME_CANDLE_BEAR         C'220,50,80'          // Rosso veneziano (maschera)

//+------------------------------------------------------------------+
//| ARLECCHINO PALETTE — I 4 colori delle losanghe                   |
//| Rosso Carmine + Giallo Oro + Blu Azure + Verde Arlecchino       |
//+------------------------------------------------------------------+
#define ARLECCHINO_RED            C'220,20,60'          // Rosso carmine (losanga)
#define ARLECCHINO_YELLOW         C'255,215,0'          // Giallo oro (losanga)
#define ARLECCHINO_BLUE           C'0,127,255'          // Blu azure (losanga)
#define ARLECCHINO_GREEN          C'70,203,24'          // Verde arlecchino (losanga)

//+------------------------------------------------------------------+
//| DASHBOARD COLORS — Tema Arlecchino                               |
//| Sfondo nero maschera + accenti losanga                           |
//+------------------------------------------------------------------+
#define THEME_DASHBOARD_BG        C'28,25,42'           // Viola profondo (sfondo dash)
#define THEME_DASHBOARD_TEXT      C'235,235,240'        // Bianco crema (testo)
#define THEME_DASHBOARD_ACCENT    ARLECCHINO_BLUE       // Blu azure (accento)

// === [v3.4] COLORI SEMANTICI MODERNI — 3 stati: OK / WARN / ERR ===
#define THEME_STATE_OK            C'70,203,24'    // Verde: tutto bene
#define THEME_STATE_WARN          C'255,193,7'    // Giallo ambra: attenzione
#define THEME_STATE_ERR           C'220,53,69'    // Rosso: errore/critico
#define THEME_STATE_INFO          C'79,195,247'   // Azzurro: informazione neutra
#define THEME_STATE_INACTIVE      C'108,117,125'  // Grigio: inattivo
// Font sizes moderni
#define DASH_FONT_SIZE_TITLE      11
#define DASH_FONT_SIZE_SECTION    10
#define DASH_FONT_SIZE_BODY       9
#define DASH_FONT_SIZE_DETAIL     8

//+------------------------------------------------------------------+
//| PANEL BACKGROUND TIERS (alternating A/B like SugamaraFlow)       |
//| Chart BG = C'20,18,30' — pannelli alternano DARK/LIGHT           |
//| Gap tra pannelli mostra chart BG come separatore naturale        |
//+------------------------------------------------------------------+
#define THEME_BG_DARK             C'20,17,32'           // Pannello A — scuro (title,DPC,cycles,market)
#define THEME_BG_MEDIUM           C'30,26,44'           // Unused (kept for compatibility)
#define THEME_BG_LIGHT            C'40,36,56'           // Pannello B — chiaro (status,signals,P&L)
#define THEME_BORDER              ARLECCHINO_BLUE       // Unused (kept for compatibility)
#define THEME_PANEL_BORDER        C'55,50,75'           // Bordino scuro uniforme tutti i pannelli

//+------------------------------------------------------------------+
//| STATUS COLORS — Arlecchino                                       |
//+------------------------------------------------------------------+
#define THEME_PROFIT              C'70,203,24'          // Verde arlecchino profit
#define THEME_LOSS                C'220,20,60'          // Rosso carmine loss
#define THEME_NEUTRAL             C'140,140,155'        // Grigio neutro
#define THEME_ACTIVE              ARLECCHINO_BLUE       // Blu azure attivo

//+------------------------------------------------------------------+
//| CHART ELEMENT COLORS                                             |
//+------------------------------------------------------------------+
#define CHART_BG_COLOR            C'20,18,30'           // Sfondo chart (invariato)
#define CHART_FG_COLOR            THEME_CHART_FOREGROUND
#define CHART_GRID_COLOR          C'35,35,45'           // Grid sottile scura
#define CHART_CANDLE_BULL         THEME_CANDLE_BULL
#define CHART_CANDLE_BEAR         THEME_CANDLE_BEAR
#define CHART_CANDLE_LINE         C'180,175,200'        // Contorno candele

//+------------------------------------------------------------------+
//| DASHBOARD PANEL COLORS — Arlecchino                              |
//| Ogni sezione ha un accento di colore diverso (losanga)           |
//+------------------------------------------------------------------+
#define DASH_BG_COLOR             THEME_DASHBOARD_BG
#define DASH_BORDER_COLOR         THEME_BORDER
#define DASH_HEADER_BG            C'34,30,48'           // Header viola scuro
#define DASH_HEADER_TEXT          ARLECCHINO_YELLOW     // Titoli ORO losanga
#define DASH_TEXT_COLOR            THEME_DASHBOARD_TEXT
#define DASH_SECTION_BG           THEME_BG_LIGHT

// Accenti sezione (un colore losanga per sezione)
#define DASH_ACCENT_DPC           ARLECCHINO_BLUE       // DPC = Blu
#define DASH_ACCENT_SIGNALS       ARLECCHINO_YELLOW     // Signals = Giallo
#define DASH_ACCENT_CYCLES        ARLECCHINO_GREEN      // Cycles = Verde
#define DASH_ACCENT_PL            ARLECCHINO_RED        // P&L = Rosso
#define DASH_ACCENT_MARKET        ARLECCHINO_BLUE       // Market = Blu

//+------------------------------------------------------------------+
//| SOUP (Verde Arlecchino)                                          |
//+------------------------------------------------------------------+
#define SOUP_COLOR                ARLECCHINO_GREEN      // Verde losanga
#define SOUP_TEXT_COLOR            C'100,255,120'        // Verde chiaro

//+------------------------------------------------------------------+
//| BREAKOUT (Rosso Carmine)                                         |
//+------------------------------------------------------------------+
#define BREAKOUT_COLOR            ARLECCHINO_RED        // Rosso losanga
#define BREAKOUT_TEXT_COLOR       C'255,120,100'        // Rosso chiaro

//+------------------------------------------------------------------+
//| STATI                                                            |
//+------------------------------------------------------------------+
#define COLOR_PROFIT              THEME_PROFIT
#define COLOR_LOSS                THEME_LOSS
#define COLOR_NEUTRAL             THEME_NEUTRAL
#define COLOR_CONNECTED           ARLECCHINO_GREEN      // DPC OK = verde losanga
#define COLOR_DISCONNECTED        ARLECCHINO_RED        // DPC FAIL = rosso losanga
#define COLOR_HEDGING             ARLECCHINO_YELLOW     // Hedging = giallo losanga
#define COLOR_WARNING             C'255,165,0'          // Arancione warning

//+------------------------------------------------------------------+
//| ENTRY/EXIT ARROWS (INVARIATE)                                    |
//+------------------------------------------------------------------+
#define SHOW_ENTRY_ARROWS         true
#define SHOW_EXIT_ARROWS          true
#define ENTRY_ARROW_SIZE          4
#define EXIT_ARROW_SIZE           4
#define ENTRY_ARROW_BUY_COLOR     C'0,200,120'          // Verde smeraldo
#define ENTRY_ARROW_SELL_COLOR    C'220,50,80'          // Rosso veneziano
#define EXIT_ARROW_TP_COLOR       C'255,255,255'        // Bianco (asterisco TP)
#define EXIT_ARROW_SL_COLOR       C'255,60,80'          // Rosso loss

//+------------------------------------------------------------------+
//| TRIGGER ARROWS (INVARIATE)                                       |
//+------------------------------------------------------------------+
#define TRIGGER_ARROW_COLOR       C'255,255,0'          // Giallo vivo
#define TRIGGER_ARROW_SIZE        5

//+------------------------------------------------------------------+
//| DPC OVERLAY — Canale storico + frecce segnale                    |
//| v3.3: Allineato all'indicatore DonchianPredictiveChannel v7.18   |
//+------------------------------------------------------------------+
// Bande canale (upper/lower) — Blu come indicatore DPC
#define OVL_UPPER_COLOR           C'100,160,255'         // [v3.4] Blu piu' chiaro e visibile
#define OVL_LOWER_COLOR           C'100,160,255'         // [v3.4] Blu piu' chiaro e visibile
#define OVL_CHANNEL_WIDTH         2                      // [v3.4] Spessore 2 per bande principali
#define OVL_CHANNEL_STYLE         STYLE_SOLID

// Midline (colore dinamico bull/bear) — Lime/Red come indicatore DPC
#define OVL_MID_BULL_COLOR        clrLime               // Lime = trend bullish
#define OVL_MID_BEAR_COLOR        clrRed                // Red = trend bearish
#define OVL_MID_WIDTH             1
#define OVL_MID_STYLE             STYLE_SOLID           // Solido come DPC indicator

// MA filtro — Teal come indicatore DPC
#define OVL_MA_COLOR              clrTeal               // Teal (allineato a DPC indicator)
#define OVL_MA_WIDTH              2                     // Width 2 come DPC indicator
#define OVL_MA_STYLE              STYLE_SOLID           // Solido come DPC indicator

// Frecce e label segnale — Verde/Rosso come indicatore DPC
#define OVL_SIGNAL_BUY_COLOR      clrLime               // Verde BUY (allineato a DPC indicator)
#define OVL_SIGNAL_SELL_COLOR     clrRed                // Rosso SELL (allineato a DPC indicator)
#define OVL_ARROW_SIZE            4
#define OVL_LABEL_FONT_SIZE       8

// Forecast projection — Verde/Rosso dashed come indicatore DPC
#define OVL_FORECAST_UP_COLOR     clrGreen              // Upper forecast (verde)
#define OVL_FORECAST_DN_COLOR     clrRed                // Lower forecast (rosso)
#define OVL_FORECAST_WIDTH        2
#define OVL_FORECAST_BARS         30                    // Barre di proiezione

// Entry dots — Punto sulla banda al segnale
#define OVL_ENTRY_DOT_COLOR       clrDodgerBlue         // DodgerBlue come DPC indicator
#define OVL_ENTRY_DOT_SIZE        3
