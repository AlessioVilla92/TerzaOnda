//+------------------------------------------------------------------+
//|                                       3ondVisualTheme.mqh        |
//|           TerzaOnda EA v2.0.0 — Palette "Tropical Surf"          |
//|                                                                  |
//|  Colori hardcodati — editabili SOLO via codice sorgente          |
//|  NON visibili nelle impostazioni EA                              |
//|                                                                  |
//|  Palette: Tropical Surf — oceano tropicale, corallo, turquoise   |
//+------------------------------------------------------------------+
#property copyright "TerzaOnda (C) 2026"

//+------------------------------------------------------------------+
//| SFONDI — Tropical Surf                                           |
//+------------------------------------------------------------------+
#define 3OND_BG_DEEP         C'12,28,44'        // Deep ocean tropicale
#define 3OND_BG_PANEL        C'15,38,58'        // Underwater teal
#define 3OND_BG_SECTION_A    C'18,42,62'        // Sezione laguna A
#define 3OND_BG_SECTION_B    C'22,50,72'        // Sezione reef B

//+------------------------------------------------------------------+
//| BORDI                                                            |
//+------------------------------------------------------------------+
#define 3OND_BORDER          C'40,90,110'       // Bordo acquamarina
#define 3OND_BORDER_FRAME    C'100,220,210'     // Frame turquoise tropicale

// Alias dashboard
#define 3OND_PANEL_BG        3OND_BG_PANEL
#define 3OND_PANEL_BORDER    3OND_BORDER
#define 3OND_SIDE_BORDER     C'80,200,190'      // Side turchese

//+------------------------------------------------------------------+
//| ACCENT — Tropical Turquoise                                      |
//+------------------------------------------------------------------+
#define 3OND_BIOLUM          C'0,230,210'       // Turquoise tropicale
#define 3OND_BIOLUM_DIM      C'0,150,140'       // Turquoise smorzato

//+------------------------------------------------------------------+
//| SEGNALI — Sea Foam / Sunset Coral                                |
//+------------------------------------------------------------------+
#define 3OND_BUY             C'0,220,170'       // Sea foam green
#define 3OND_BUY_DIM         C'0,120,88'        // Sea foam dim
#define 3OND_SELL            C'255,100,80'      // Sunset coral
#define 3OND_SELL_DIM        C'140,50,40'       // Coral dim
#define 3OND_AMBER           C'255,195,50'      // Sunset gold
#define 3OND_AMBER_DIM       C'140,100,0'       // Gold smorzato
// Hedge Smart colors
#define 3OND_HEDGE           C'255,160,60'       // Tropical orange
#define 3OND_HEDGE_DIM       C'180,110,30'       // Tropical orange smorzato
#define 3OND_HS_TRIGGER_CLR  C'255,160,60'       // Linea trigger HS
#define 3OND_HS_BE_CLR       C'0,210,140'        // Tropical green — Step1 BE
#define 3OND_HS_TP_CLR       C'0,170,220'        // Ocean blue — Step2 TP

//+------------------------------------------------------------------+
//| TESTO                                                            |
//+------------------------------------------------------------------+
#define 3OND_TEXT_HI         C'235,245,240'     // White foam
#define 3OND_TEXT_MID        C'120,170,165'     // Faded teal
#define 3OND_TEXT_LO         C'50,80,80'        // Testo disabilitato

// Alias dashboard
#define 3OND_TEXT_SECONDARY  3OND_TEXT_MID
#define 3OND_TEXT_MUTED      3OND_TEXT_LO

//+------------------------------------------------------------------+
//| CANDELE CHART                                                    |
//+------------------------------------------------------------------+
#define 3OND_CANDLE_BULL     C'0,210,160'       // Tropical green
#define 3OND_CANDLE_BEAR     C'255,95,85'       // Coral

//+------------------------------------------------------------------+
//| OVERLAY CANALE — Keltner Predictive Channel                      |
//+------------------------------------------------------------------+
#define 3OND_CHAN_UPPER_CLR   C'70,200,210'     // Ocean turquoise
#define 3OND_CHAN_LOWER_CLR   C'70,200,210'     // Ocean turquoise
#define 3OND_CHAN_MID_UP_CLR  C'0,230,210'      // Turquoise (bull KAMA)
#define 3OND_CHAN_MID_DN_CLR  C'255,110,80'     // Sunset coral (bear KAMA)
#define 3OND_CHAN_MID_FLAT_CLR C'190,180,150'   // Sand/driftwood (ranging)
#define 3OND_CHAN_FILL_CLR    C'40,180,195'     // Tropical lagoon fill
#define 3OND_CHAN_FILL_ALPHA  35                // Trasparenza fill
#define 3OND_CHAN_MA_CLR      C'80,190,180'     // Teal (non usato — KAMA e' midline)
#define 3OND_CHAN_WIDTH       2                 // Spessore bande
#define 3OND_CHAN_STYLE       STYLE_SOLID
#define 3OND_CHAN_MID_STYLE   STYLE_SOLID       // KAMA midline solida (non dot)

// Hedge Smart entry channel
#define 3OND_HS_CHAN_CLR      C'255,160,60'     // Tropical orange (= 3OND_HEDGE)
#define 3OND_HS_CHAN_STYLE    STYLE_DOT         // Tratteggiato
#define 3OND_HS_CHAN_WIDTH    1                 // Spessore 1

//+------------------------------------------------------------------+
//| FRECCE SEGNALE — Primary (TBS) / Half (TWS)                      |
//+------------------------------------------------------------------+
#define 3OND_ARROW_TBS_BUY   C'0,230,170'      // Tropical green (Primary BUY)
#define 3OND_ARROW_TBS_SELL  C'255,90,75'       // Coral (Primary SELL)
#define 3OND_ARROW_TWS_BUY   C'0,160,120'      // Dark sea foam (Half BUY)
#define 3OND_ARROW_TWS_SELL  C'180,70,55'       // Dark coral (Half SELL)
#define 3OND_ARROW_SIZE      5                  // Arrow width
#define 3OND_ARROW_OFFSET    0.15               // Offset multiplier x ATR

//+------------------------------------------------------------------+
//| SQUEEZE / FIRE — KPC specifici                                   |
//+------------------------------------------------------------------+
#define 3OND_SQUEEZE_CLR     C'255,220,50'      // Giallo tropicale (squeeze active)
#define 3OND_FIRE_CLR        C'255,60,30'       // Rosso fuoco (fire breakout)

//+------------------------------------------------------------------+
//| ENTRY/EXIT                                                       |
//+------------------------------------------------------------------+
#define 3OND_ENTRY_BUY_CLR   3OND_BUY
#define 3OND_ENTRY_SELL_CLR  3OND_SELL

//+------------------------------------------------------------------+
//| TP TARGET                                                        |
//+------------------------------------------------------------------+
#define 3OND_TP_DOT_BUY      C'0,230,170'      // Tropical green
#define 3OND_TP_DOT_SELL     C'255,90,75'       // Coral
#define 3OND_TP_HIT_CLR      C'255,220,50'      // Sunset gold
#define 3OND_TP_LINE_WIDTH   1

//+------------------------------------------------------------------+
//| Z-ORDER                                                          |
//+------------------------------------------------------------------+
#define 3OND_ZORDER_RECT     15000
#define 3OND_ZORDER_LABEL    16000
#define 3OND_ZORDER_BTN      16001

// Alias brevi
#define 3OND_Z_RECT          3OND_ZORDER_RECT
#define 3OND_Z_LABEL         3OND_ZORDER_LABEL
#define 3OND_Z_BUTTON        3OND_ZORDER_BTN

//+------------------------------------------------------------------+
//| FONT                                                             |
//+------------------------------------------------------------------+
#define 3OND_FONT_MONO       "Consolas"
#define 3OND_FONT_TITLE      "Arial Black"
#define 3OND_FONT_SECTION    "Arial Bold"
#define 3OND_FONT_SIZE       9

// Alias dashboard
#define 3OND_FONT_BODY       3OND_FONT_MONO
#define 3OND_FONT_SIZE_BODY  3OND_FONT_SIZE

//+------------------------------------------------------------------+
//| DASHBOARD DIMENSIONI                                             |
//+------------------------------------------------------------------+
#define 3OND_DASH_X          10
#define 3OND_DASH_Y          25
#define 3OND_DASH_W          640
#define 3OND_PAD             14
#define 3OND_GAP             4

#define 3OND_H_HEADER        36
#define 3OND_H_TOPBAR        32
#define 3OND_H_SYSSTATUS     76
#define 3OND_H_ENGINE        88
#define 3OND_H_FILTERS       22
#define 3OND_H_LASTSIG       76
#define 3OND_H_CYCLES        (26 + 4 * 16 + 4)
#define 3OND_H_PL            88
#define 3OND_H_CONTROLS      52
#define 3OND_H_STATUSBAR     20
#define 3OND_SIDE_W          210

//+------------------------------------------------------------------+
//| ApplyChartTheme() — Applica palette Tropical Surf al chart       |
//+------------------------------------------------------------------+
void ApplyChartTheme()
{
   ChartSetInteger(0, CHART_COLOR_BACKGROUND,   3OND_BG_DEEP);
   ChartSetInteger(0, CHART_COLOR_FOREGROUND,   3OND_TEXT_HI);
   ChartSetInteger(0, CHART_COLOR_GRID,         C'25,50,60');
   ChartSetInteger(0, CHART_COLOR_CANDLE_BULL,  3OND_CANDLE_BULL);
   ChartSetInteger(0, CHART_COLOR_CANDLE_BEAR,  3OND_CANDLE_BEAR);
   ChartSetInteger(0, CHART_COLOR_CHART_UP,     3OND_CANDLE_BULL);
   ChartSetInteger(0, CHART_COLOR_CHART_DOWN,   3OND_CANDLE_BEAR);
   ChartSetInteger(0, CHART_COLOR_ASK,          3OND_BUY);
   ChartSetInteger(0, CHART_COLOR_BID,          3OND_SELL);
   ChartSetInteger(0, CHART_SHOW_GRID,          false);
   ChartSetInteger(0, CHART_SHOW_VOLUMES,       CHART_VOLUME_HIDE);
}
