//+------------------------------------------------------------------+
//|                                          adVisualTheme.mqh       |
//|           AcquaDulza EA v1.0.0 — Palette "Ocean"                 |
//|                                                                  |
//|  Colori hardcodati — editabili SOLO via codice sorgente          |
//|  NON visibili nelle impostazioni EA                              |
//|                                                                  |
//|  Palette: Deep Navy / Bioluminescenza / Acquamarina              |
//+------------------------------------------------------------------+
#property copyright "AcquaDulza (C) 2026"

//+------------------------------------------------------------------+
//| SFONDI — Ocean Abyss                                             |
//+------------------------------------------------------------------+
#define AD_BG_DEEP         C'3,8,15'        // Ocean abyss — sfondo chart
#define AD_BG_PANEL        C'9,21,37'       // Panel dark
#define AD_BG_SECTION_A    C'13,30,53'      // Sezioni alternate A (titolo, DPC, cicli)
#define AD_BG_SECTION_B    C'18,35,60'      // Sezioni alternate B (status, signals, P&L)
#define AD_BG_CELL         C'18,37,64'      // ocean-surface — sfondo celle griglia

//+------------------------------------------------------------------+
//| BORDI                                                            |
//+------------------------------------------------------------------+
#define AD_BORDER          C'30,61,92'      // Bordo pannello
#define AD_BORDER_GLOW     C'42,85,128'     // Bordo attivo / hover

// Alias dashboard
#define AD_PANEL_BG        AD_BG_PANEL
#define AD_PANEL_BORDER    AD_BORDER

//+------------------------------------------------------------------+
//| ACCENT — Bioluminescenza                                         |
//+------------------------------------------------------------------+
#define AD_BIOLUM          C'0,212,255'     // Cyan — accent principale
#define AD_BIOLUM_DIM      C'0,136,170'     // Cyan smorzato

//+------------------------------------------------------------------+
//| SEGNALI — Acquamarina / Corallo                                  |
//+------------------------------------------------------------------+
#define AD_BUY             C'0,232,176'     // Acquamarina — BUY/profit
#define AD_BUY_DIM         C'0,122,92'      // BUY smorzato
#define AD_SELL            C'255,77,109'    // Corallo — SELL/loss
#define AD_SELL_DIM        C'136,34,68'     // SELL smorzato
#define AD_AMBER           C'255,179,71'    // Ambra marina — warning/TWS
#define AD_AMBER_DIM       C'136,85,0'      // Ambra smorzato

//+------------------------------------------------------------------+
//| TESTO                                                            |
//+------------------------------------------------------------------+
#define AD_TEXT_HI         C'221,238,255'   // Testo principale
#define AD_TEXT_MID        C'122,154,184'   // Testo secondario
#define AD_TEXT_LO         C'42,74,101'     // Testo disabilitato

// Alias dashboard
#define AD_TEXT_PRIMARY    AD_TEXT_HI
#define AD_TEXT_SECONDARY  AD_TEXT_MID
#define AD_TEXT_MUTED      AD_TEXT_LO

//+------------------------------------------------------------------+
//| STATO SEMANTICO                                                  |
//+------------------------------------------------------------------+
#define AD_STATE_OK        AD_BUY
#define AD_STATE_WARN      AD_AMBER
#define AD_STATE_ERR       AD_SELL
#define AD_STATE_INFO      AD_BIOLUM
#define AD_STATE_INACTIVE  AD_TEXT_MID

//+------------------------------------------------------------------+
//| CANDELE CHART                                                    |
//+------------------------------------------------------------------+
#define AD_CANDLE_BULL     C'0,196,122'
#define AD_CANDLE_BEAR     C'220,50,80'

//+------------------------------------------------------------------+
//| OVERLAY CANALE                                                   |
//+------------------------------------------------------------------+
#define AD_CHAN_UPPER_CLR   AD_SELL_DIM
#define AD_CHAN_LOWER_CLR   AD_BUY_DIM
#define AD_CHAN_MID_CLR     AD_BIOLUM_DIM
#define AD_CHAN_WIDTH       2
#define AD_CHAN_STYLE       STYLE_SOLID
#define AD_CHAN_MID_STYLE   STYLE_DOT

//+------------------------------------------------------------------+
//| FRECCE SEGNALE                                                   |
//+------------------------------------------------------------------+
#define AD_ARROW_TBS_BUY   AD_BUY           // TBS BUY — acquamarina
#define AD_ARROW_TBS_SELL  AD_SELL           // TBS SELL — corallo
#define AD_ARROW_TWS_BUY   AD_BUY_DIM       // TWS BUY — acquamarina dim
#define AD_ARROW_TWS_SELL  AD_SELL_DIM       // TWS SELL — corallo dim
#define AD_ARROW_SIZE      4

//+------------------------------------------------------------------+
//| ENTRY/EXIT                                                       |
//+------------------------------------------------------------------+
#define AD_ENTRY_BUY_CLR   AD_BUY
#define AD_ENTRY_SELL_CLR  AD_SELL
#define AD_EXIT_TP_CLR     C'255,255,255'   // Bianco — TP hit
#define AD_EXIT_SL_CLR     AD_SELL          // Corallo — SL hit
#define AD_ENTRY_DOT_SIZE  3

//+------------------------------------------------------------------+
//| TP LINE                                                          |
//+------------------------------------------------------------------+
#define AD_TP_LINE_CLR     AD_BIOLUM_DIM
#define AD_TP_LINE_STYLE   STYLE_DASH
#define AD_TP_LINE_WIDTH   1

//+------------------------------------------------------------------+
//| Z-ORDER                                                          |
//+------------------------------------------------------------------+
#define AD_ZORDER_RECT     15000
#define AD_ZORDER_LABEL    16000
#define AD_ZORDER_BTN      16001

// Alias brevi usati dal dashboard
#define AD_Z_RECT          AD_ZORDER_RECT
#define AD_Z_LABEL         AD_ZORDER_LABEL
#define AD_Z_BUTTON        AD_ZORDER_BTN

//+------------------------------------------------------------------+
//| FONT                                                             |
//+------------------------------------------------------------------+
#define AD_FONT_MONO       "Consolas"
#define AD_FONT_TITLE      "Arial Black"
#define AD_FONT_SECTION    "Arial Bold"
#define AD_FONT_SIZE       9
#define AD_FONT_SIZE_TITLE 16
#define AD_FONT_SIZE_SEC   10

// Alias dashboard
#define AD_FONT_BODY       AD_FONT_MONO
#define AD_FONT_SIZE_BODY  AD_FONT_SIZE

//+------------------------------------------------------------------+
//| DASHBOARD DIMENSIONI                                             |
//+------------------------------------------------------------------+
#define AD_DASH_X          10
#define AD_DASH_Y          25
#define AD_DASH_W          640
#define AD_LINE_H          18
#define AD_PAD             14
#define AD_GAP             4

#define AD_H_TOPBAR        46
#define AD_H_SYSSTATUS     76
#define AD_H_ENGINE        88
#define AD_H_FILTERS       22
#define AD_H_LASTSIG       76
#define AD_H_CYCLES        (26 + 4 * 16 + 4)
#define AD_H_PL            88
#define AD_H_CONTROLS      52
#define AD_H_STATUSBAR     20
#define AD_SIDE_W          240

//+------------------------------------------------------------------+
//| ApplyChartTheme() — Applica palette Ocean al chart               |
//+------------------------------------------------------------------+
void ApplyChartTheme()
{
   ChartSetInteger(0, CHART_COLOR_BACKGROUND,   AD_BG_DEEP);
   ChartSetInteger(0, CHART_COLOR_FOREGROUND,   AD_TEXT_HI);
   ChartSetInteger(0, CHART_COLOR_GRID,         C'18,36,55');
   ChartSetInteger(0, CHART_COLOR_CANDLE_BULL,  AD_CANDLE_BULL);
   ChartSetInteger(0, CHART_COLOR_CANDLE_BEAR,  AD_CANDLE_BEAR);
   ChartSetInteger(0, CHART_COLOR_CHART_UP,     AD_CANDLE_BULL);
   ChartSetInteger(0, CHART_COLOR_CHART_DOWN,   AD_CANDLE_BEAR);
   ChartSetInteger(0, CHART_COLOR_ASK,          AD_BUY);
   ChartSetInteger(0, CHART_COLOR_BID,          AD_SELL);
   ChartSetInteger(0, CHART_SHOW_GRID,          false);
   ChartSetInteger(0, CHART_SHOW_VOLUMES,       CHART_VOLUME_HIDE);
}
