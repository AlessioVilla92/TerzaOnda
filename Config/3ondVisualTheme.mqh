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
#define TOND_BG_DEEP         C'12,28,44'        // Deep ocean tropicale
#define TOND_BG_PANEL        C'15,38,58'        // Underwater teal
#define TOND_BG_SECTION_A    C'18,42,62'        // Sezione laguna A
#define TOND_BG_SECTION_B    C'22,50,72'        // Sezione reef B

//+------------------------------------------------------------------+
//| BORDI                                                            |
//+------------------------------------------------------------------+
#define TOND_BORDER          C'40,90,110'       // Bordo acquamarina
#define TOND_BORDER_FRAME    C'100,220,210'     // Frame turquoise tropicale

// Alias dashboard
#define TOND_PANEL_BG        TOND_BG_PANEL
#define TOND_PANEL_BORDER    TOND_BORDER
#define TOND_SIDE_BORDER     C'80,200,190'      // Side turchese

//+------------------------------------------------------------------+
//| ACCENT — Tropical Turquoise                                      |
//+------------------------------------------------------------------+
#define TOND_BIOLUM          C'0,230,210'       // Turquoise tropicale
#define TOND_BIOLUM_DIM      C'0,150,140'       // Turquoise smorzato

//+------------------------------------------------------------------+
//| SEGNALI — Sea Foam / Sunset Coral                                |
//+------------------------------------------------------------------+
#define TOND_BUY             C'0,220,170'       // Sea foam green
#define TOND_BUY_DIM         C'0,120,88'        // Sea foam dim
#define TOND_SELL            C'255,100,80'      // Sunset coral
#define TOND_SELL_DIM        C'140,50,40'       // Coral dim
#define TOND_AMBER           C'255,195,50'      // Sunset gold
#define TOND_AMBER_DIM       C'140,100,0'       // Gold smorzato
// Hedge Smart colors
#define TOND_HEDGE           C'255,160,60'       // Tropical orange
#define TOND_HEDGE_DIM       C'180,110,30'       // Tropical orange smorzato
#define TOND_HS_TRIGGER_CLR  C'255,160,60'       // Linea trigger HS
#define TOND_HS_BE_CLR       C'0,210,140'        // Tropical green — Step1 BE
#define TOND_HS_TP_CLR       C'0,170,220'        // Ocean blue — Step2 TP

//+------------------------------------------------------------------+
//| TESTO                                                            |
//+------------------------------------------------------------------+
#define TOND_TEXT_HI         C'235,245,240'     // White foam
#define TOND_TEXT_MID        C'120,170,165'     // Faded teal
#define TOND_TEXT_LO         C'50,80,80'        // Testo disabilitato

// Alias dashboard
#define TOND_TEXT_SECONDARY  TOND_TEXT_MID
#define TOND_TEXT_MUTED      TOND_TEXT_LO

//+------------------------------------------------------------------+
//| CANDELE CHART                                                    |
//+------------------------------------------------------------------+
#define TOND_CANDLE_BULL     C'0,210,160'       // Tropical green
#define TOND_CANDLE_BEAR     C'255,95,85'       // Coral

//+------------------------------------------------------------------+
//| OVERLAY CANALE — Keltner Predictive Channel                      |
//+------------------------------------------------------------------+
#define TOND_CHAN_UPPER_CLR   C'70,200,210'     // Ocean turquoise
#define TOND_CHAN_LOWER_CLR   C'70,200,210'     // Ocean turquoise
#define TOND_CHAN_MID_UP_CLR  C'0,230,210'      // Turquoise (bull KAMA)
#define TOND_CHAN_MID_DN_CLR  C'255,110,80'     // Sunset coral (bear KAMA)
#define TOND_CHAN_MID_FLAT_CLR C'190,180,150'   // Sand/driftwood (ranging)
#define TOND_CHAN_FILL_CLR    C'40,180,195'     // Tropical lagoon fill
#define TOND_CHAN_FILL_ALPHA  35                // Trasparenza fill
#define TOND_CHAN_MA_CLR      C'80,190,180'     // Teal (non usato — KAMA e' midline)
#define TOND_CHAN_WIDTH       2                 // Spessore bande
#define TOND_CHAN_STYLE       STYLE_SOLID
#define TOND_CHAN_MID_STYLE   STYLE_SOLID       // KAMA midline solida (non dot)

// Hedge Smart entry channel
#define TOND_HS_CHAN_CLR      C'255,160,60'     // Tropical orange (= TOND_HEDGE)
#define TOND_HS_CHAN_STYLE    STYLE_DOT         // Tratteggiato
#define TOND_HS_CHAN_WIDTH    1                 // Spessore 1

//+------------------------------------------------------------------+
//| FRECCE SEGNALE — Primary (TBS) / Half (TWS)                      |
//+------------------------------------------------------------------+
#define TOND_ARROW_TBS_BUY   C'0,230,170'      // Tropical green (Primary BUY)
#define TOND_ARROW_TBS_SELL  C'255,90,75'       // Coral (Primary SELL)
#define TOND_ARROW_TWS_BUY   C'0,160,120'      // Dark sea foam (Half BUY)
#define TOND_ARROW_TWS_SELL  C'180,70,55'       // Dark coral (Half SELL)
#define TOND_ARROW_SIZE      5                  // Arrow width
#define TOND_ARROW_OFFSET    0.15               // Offset multiplier x ATR

//+------------------------------------------------------------------+
//| SQUEEZE / FIRE — KPC specifici                                   |
//+------------------------------------------------------------------+
#define TOND_SQUEEZE_CLR     C'255,220,50'      // Giallo tropicale (squeeze active)
#define TOND_FIRE_CLR        C'255,60,30'       // Rosso fuoco (fire breakout)

//+------------------------------------------------------------------+
//| ENTRY/EXIT                                                       |
//+------------------------------------------------------------------+
#define TOND_ENTRY_BUY_CLR   TOND_BUY
#define TOND_ENTRY_SELL_CLR  TOND_SELL

//+------------------------------------------------------------------+
//| TP TARGET                                                        |
//+------------------------------------------------------------------+
#define TOND_TP_DOT_BUY      C'0,230,170'      // Tropical green
#define TOND_TP_DOT_SELL     C'255,90,75'       // Coral
#define TOND_TP_HIT_CLR      C'255,220,50'      // Sunset gold
#define TOND_TP_LINE_WIDTH   1

//+------------------------------------------------------------------+
//| Z-ORDER                                                          |
//+------------------------------------------------------------------+
#define TOND_ZORDER_RECT     15000
#define TOND_ZORDER_LABEL    16000
#define TOND_ZORDER_BTN      16001

// Alias brevi
#define TOND_Z_RECT          TOND_ZORDER_RECT
#define TOND_Z_LABEL         TOND_ZORDER_LABEL
#define TOND_Z_BUTTON        TOND_ZORDER_BTN

//+------------------------------------------------------------------+
//| FONT                                                             |
//+------------------------------------------------------------------+
#define TOND_FONT_MONO       "Consolas"
#define TOND_FONT_TITLE      "Arial Black"
#define TOND_FONT_SECTION    "Arial Bold"
#define TOND_FONT_SIZE       9

// Alias dashboard
#define TOND_FONT_BODY       TOND_FONT_MONO
#define TOND_FONT_SIZE_BODY  TOND_FONT_SIZE

//+------------------------------------------------------------------+
//| DASHBOARD DIMENSIONI                                             |
//+------------------------------------------------------------------+
#define TOND_DASH_X          10
#define TOND_DASH_Y          25
#define TOND_DASH_W          640
#define TOND_PAD             14
#define TOND_GAP             4

#define TOND_H_HEADER        36
#define TOND_H_TOPBAR        32
#define TOND_H_SYSSTATUS     76
#define TOND_H_ENGINE        88
#define TOND_H_FILTERS       22
#define TOND_H_LASTSIG       76
#define TOND_H_CYCLES        (26 + 4 * 16 + 4)
#define TOND_H_PL            88
#define TOND_H_CONTROLS      52
#define TOND_H_STATUSBAR     20
#define TOND_SIDE_W          210

//+------------------------------------------------------------------+
//| ApplyChartTheme() — Applica palette Tropical Surf al chart       |
//+------------------------------------------------------------------+
void ApplyChartTheme()
{
   ChartSetInteger(0, CHART_COLOR_BACKGROUND,   TOND_BG_DEEP);
   ChartSetInteger(0, CHART_COLOR_FOREGROUND,   TOND_TEXT_HI);
   ChartSetInteger(0, CHART_COLOR_GRID,         C'25,50,60');
   ChartSetInteger(0, CHART_COLOR_CANDLE_BULL,  TOND_CANDLE_BULL);
   ChartSetInteger(0, CHART_COLOR_CANDLE_BEAR,  TOND_CANDLE_BEAR);
   ChartSetInteger(0, CHART_COLOR_CHART_UP,     TOND_CANDLE_BULL);
   ChartSetInteger(0, CHART_COLOR_CHART_DOWN,   TOND_CANDLE_BEAR);
   ChartSetInteger(0, CHART_COLOR_ASK,          TOND_BUY);
   ChartSetInteger(0, CHART_COLOR_BID,          TOND_SELL);
   ChartSetInteger(0, CHART_SHOW_GRID,          false);
   ChartSetInteger(0, CHART_SHOW_VOLUMES,       CHART_VOLUME_HIDE);
}
