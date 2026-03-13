//+------------------------------------------------------------------+
//|                                          adVisualTheme.mqh       |
//|           AcquaDulza EA v1.1.0 — Palette "Deep Ocean"            |
//|                                                                  |
//|  Colori hardcodati — editabili SOLO via codice sorgente          |
//|  NON visibili nelle impostazioni EA                              |
//|                                                                  |
//|  Palette: Deep Ocean — da AcquaDulza_Dashboard_Ocean_v3.html     |
//+------------------------------------------------------------------+
#property copyright "AcquaDulza (C) 2026"

//+------------------------------------------------------------------+
//| SFONDI — Deep Ocean                                              |
//+------------------------------------------------------------------+
#define AD_BG_DEEP         C'20,10,35'       // #140a23 — deep violet, chart bg
#define AD_BG_PANEL        C'9,21,37'        // #091525 — panel background
#define AD_BG_SECTION_A    C'13,30,53'       // #0d1e35 — sezioni alternate A
#define AD_BG_SECTION_B    C'18,37,64'       // #122540 — sezioni alternate B
#define AD_BG_CELL         C'26,51,80'       // #1a3350 — sfondo celle griglia

//+------------------------------------------------------------------+
//| BORDI                                                            |
//+------------------------------------------------------------------+
#define AD_BORDER          C'30,61,92'       // #1e3d5c — bordo pannello
#define AD_BORDER_GLOW     C'42,85,128'      // #2a5580 — bordo attivo / hover

// Alias dashboard
#define AD_PANEL_BG        AD_BG_PANEL
#define AD_PANEL_BORDER    AD_BORDER
#define AD_SIDE_BORDER     C'100,200,230'    // Azzurro chiaro per side panels

//+------------------------------------------------------------------+
//| ACCENT — Bioluminescenza                                         |
//+------------------------------------------------------------------+
#define AD_BIOLUM          C'0,212,255'      // #00d4ff — cyan luminoso
#define AD_BIOLUM_DIM      C'0,136,170'      // #0088aa — cyan smorzato

//+------------------------------------------------------------------+
//| SEGNALI — Acquamarina / Corallo                                  |
//+------------------------------------------------------------------+
#define AD_BUY             C'0,232,176'      // #00e8b0 — acquamarina profonda
#define AD_BUY_DIM         C'0,122,92'       // #007a5c — BUY smorzato
#define AD_SELL            C'255,77,109'     // #ff4d6d — corallo
#define AD_SELL_DIM        C'136,34,51'      // #882233 — SELL smorzato
#define AD_AMBER           C'255,179,71'     // #ffb347 — ambra marina
#define AD_AMBER_DIM       C'136,85,0'       // #885500 — ambra smorzato

//+------------------------------------------------------------------+
//| TESTO                                                            |
//+------------------------------------------------------------------+
#define AD_TEXT_HI         C'221,238,255'    // #ddeeff — testo principale
#define AD_TEXT_MID        C'122,154,184'    // #7a9ab8 — testo secondario
#define AD_TEXT_LO         C'42,74,101'      // #2a4a65 — testo disabilitato

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
#define AD_CANDLE_BULL     C'0,232,176'      // #00e8b0 — acquamarina
#define AD_CANDLE_BEAR     C'255,77,109'     // #ff4d6d — corallo

//+------------------------------------------------------------------+
//| OVERLAY CANALE — Replica DonchianPredictiveChannel.mq5           |
//+------------------------------------------------------------------+
#define AD_CHAN_UPPER_CLR   C'100,160,255'   // Blu chiaro (allineato Carneval, piu' visibile)
#define AD_CHAN_LOWER_CLR   C'100,160,255'   // Blu chiaro
#define AD_CHAN_MID_UP_CLR  clrLime          // Midline bullish
#define AD_CHAN_MID_DN_CLR  clrRed           // Midline bearish
#define AD_CHAN_MID_FLAT_CLR C'0,212,255'    // Midline flat (= AD_BIOLUM)
#define AD_CHAN_FILL_CLR    C'30,144,255'    // DodgerBlue fill
#define AD_CHAN_FILL_ALPHA  40               // Trasparenza fill (piu visibile su nero)
#define AD_CHAN_MA_CLR      clrTeal          // MA line
#define AD_CHAN_WIDTH       2                // Spessore 2 (allineato Carneval)
#define AD_CHAN_STYLE       STYLE_SOLID
#define AD_CHAN_MID_STYLE   STYLE_DOT

//+------------------------------------------------------------------+
//| FRECCE SEGNALE — Replica indicatore TBS/TWS                      |
//+------------------------------------------------------------------+
#define AD_ARROW_TBS_BUY   clrLime           // TBS BUY — bright green
#define AD_ARROW_TBS_SELL  clrRed            // TBS SELL — bright red
#define AD_ARROW_TWS_BUY   C'0,160,90'      // TWS BUY — dark green
#define AD_ARROW_TWS_SELL  C'180,60,60'     // TWS SELL — dark red
#define AD_ARROW_SIZE      5                 // Arrow width (come indicatore)
#define AD_ARROW_OFFSET    1.5               // Offset multiplier x ATR

//+------------------------------------------------------------------+
//| ENTRY/EXIT                                                       |
//+------------------------------------------------------------------+
#define AD_ENTRY_BUY_CLR   AD_BUY
#define AD_ENTRY_SELL_CLR  AD_SELL
#define AD_EXIT_TP_CLR     C'255,255,255'   // Bianco — TP hit
#define AD_EXIT_SL_CLR     AD_SELL          // Corallo — SL hit
#define AD_ENTRY_DOT_SIZE  3

//+------------------------------------------------------------------+
//| TP TARGET — Replica indicatore                                   |
//+------------------------------------------------------------------+
#define AD_TP_DOT_BUY      clrLime          // TP dot BUY
#define AD_TP_DOT_SELL     clrRed           // TP dot SELL
#define AD_TP_HIT_CLR      clrYellow        // TP hit star
#define AD_TP_LINE_CLR     AD_BIOLUM_DIM
#define AD_TP_LINE_STYLE   STYLE_DASH
#define AD_TP_LINE_WIDTH   1

//+------------------------------------------------------------------+
//| TRIGGER CANDLE (VLine rimossa — colore mantenuto per eventuale   |
//| riattivazione futura di DrawTriggerVLine in adChannelOverlay)    |
//+------------------------------------------------------------------+
#define AD_TRIGGER_CLR     clrYellow         // VLine sulla candela trigger (non attiva)

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

#define AD_H_HEADER        36                // Header: ACQUADULZA + versione + ENGINE
#define AD_H_TOPBAR        32                // TitleBar: Pair + Price + Spread + State
#define AD_H_SYSSTATUS     76
#define AD_H_ENGINE        88
#define AD_H_FILTERS       22
#define AD_H_LASTSIG       76
#define AD_H_CYCLES        (26 + 4 * 16 + 4)
#define AD_H_PL            88
#define AD_H_CONTROLS      52
#define AD_H_STATUSBAR     20
#define AD_SIDE_W          210

//+------------------------------------------------------------------+
//| ApplyChartTheme() — Applica palette Deep Ocean al chart          |
//+------------------------------------------------------------------+
void ApplyChartTheme()
{
   ChartSetInteger(0, CHART_COLOR_BACKGROUND,   AD_BG_DEEP);
   ChartSetInteger(0, CHART_COLOR_FOREGROUND,   AD_TEXT_HI);
   ChartSetInteger(0, CHART_COLOR_GRID,         C'35,20,55');
   ChartSetInteger(0, CHART_COLOR_CANDLE_BULL,  AD_CANDLE_BULL);
   ChartSetInteger(0, CHART_COLOR_CANDLE_BEAR,  AD_CANDLE_BEAR);
   ChartSetInteger(0, CHART_COLOR_CHART_UP,     AD_CANDLE_BULL);
   ChartSetInteger(0, CHART_COLOR_CHART_DOWN,   AD_CANDLE_BEAR);
   ChartSetInteger(0, CHART_COLOR_ASK,          AD_BUY);
   ChartSetInteger(0, CHART_COLOR_BID,          AD_SELL);
   ChartSetInteger(0, CHART_SHOW_GRID,          false);
   ChartSetInteger(0, CHART_SHOW_VOLUMES,       CHART_VOLUME_HIDE);
}
