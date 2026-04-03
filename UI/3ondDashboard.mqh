//+------------------------------------------------------------------+
//|                                          adDashboard.mqh         |
//|           TerzaOnda EA v1.6.1 — Dashboard Display               |
//|                                                                  |
//|  Ocean theme dashboard — Pragmatic approach.                     |
//|                                                                  |
//|  LAYOUT VERTICALE (top → bottom, ogni pannello ha altezza fissa):|
//|    1. Header     (36px) — Logo TERZAONDA + versione + ENGINE    |
//|    2. TitleBar   (32px) — Pair + prezzo + spread + TF + state    |
//|    3. SysStatus  (80px) — 3x3 grid: session/uptime/margin/etc.  |
//|    4. EnginePanel(88px) — Bande + width + regime + SmartCD       |
//|    5. FilterBar  (22px) — Pills colorate per ogni filtro attivo  |
//|    6. LastSignals(76px) — Ultimi 3 segnali con direzione + TBS   |
//|    7. ActiveCycles(100px)— Fino a 4 cicli con P&L floating      |
//|    8. PLSession  (90px) — P&L, WinRate, MaxDD, Float, Daily     |
//|    9. Controls   (52px) — Titolo + ora + button feedback         |
//|   10. StatusBar  (20px) — Barra riassuntiva EA state + features  |
//|                                                                  |
//|  SIDE PANEL (a destra del dashboard, offset +10px):              |
//|    - Engine Monitor (13 righe): DPC Engine, ATR, SmartCD, etc.   |
//|    - Signal Feed (6 righe): ultime azioni EA in tempo reale      |
//|                                                                  |
//|  CORNICE PERIMETRALE (stile SugamaraPivot):                      |
//|    - Sfondo scuro (TOND_BG_DEEP) creato PRIMO (sotto tutto)        |
//|    - 4 rettangoli solidi (T/B/L/R) creati ULTIMI (sopra tutto)   |
//|    - Titoli decorativi "────── TERZAONDA ──────" top/bottom      |
//|                                                                  |
//|  Z-ORDER e VISUAL STACKING:                                      |
//|    - TOND_Z_RECT (adVisualTheme): Z-order per rettangoli pannello  |
//|    - TOND_Z_LABEL: Z-order per etichette testo (sopra rettangoli)  |
//|    - Frame border Z = TOND_Z_LABEL + 1000: sempre in primo piano   |
//|    - BACK=false su tutti: dashboard SOPRA il chart (foreground)   |
//|    - Overlay (adChannelOverlay) usa BACK=true: DIETRO le candele |
//|                                                                  |
//|  THEME COLORS (da adVisualTheme.mqh):                            |
//|    TOND_BIOLUM      — cyan brillante C'0,212,255' (accento)        |
//|    TOND_BIOLUM_DIM  — cyan attenuato (titoli secondari)            |
//|    TOND_BUY/TOND_SELL — lime/rosso (P&L positivo/negativo)           |
//|    TOND_AMBER       — giallo/ambra (warning, TWS, pending)         |
//|    TOND_HEDGE       — fucsia (stato HEDG e H1)                     |
//|    TOND_BG_DEEP     — blu scuro profondo (sfondo pannelli)         |
//|    TOND_PANEL_BG    — grigio scuro (sfondo sezioni alternate)      |
//|    TOND_TEXT_HI/MID/LO/MUTED — gerarchia testo (bianco→grigio)     |
//|                                                                  |
//|  v1.4.0: Integrazione hedge nel dashboard (6 punti)              |
//|    DrawActiveCycles — stato "HEDG" fucsia + P&L combinato        |
//|    DrawPLSession    — FLOAT include CYCLE_HEDGING (entrambe)     |
//|    DrawFilterBar    — pill [+Hedge]/[_Hedge] in fucsia           |
//|    DrawStatusBar    — Hedge:ON/OFF nella barra inferiore         |
//|    UpdateSidePanel  — riga 13 "Hedge" con conteggio attivi       |
//+------------------------------------------------------------------+
#property copyright "TerzaOnda (C) 2026"

//+------------------------------------------------------------------+
//| DashRectangle — Crea/aggiorna un pannello rettangolare           |
//|                                                                  |
//| Helper: ogni pannello del dashboard e' un OBJ_RECTANGLE_LABEL.  |
//| Alla prima chiamata crea l'oggetto; le successive aggiornano     |
//| solo posizione, dimensione e colori (no delete+recreate).        |
//|                                                                  |
//| NAMING: Tutti i rettangoli hanno prefisso "TOND_" (per cleanup).   |
//| STACKING: BACK=false + ZORDER=TOND_Z_RECT → foreground chart,     |
//|           ma sotto le etichette testo (TOND_Z_LABEL > TOND_Z_RECT).  |
//| BORDER: BORDER_FLAT = bordo 1px piatto (colore borderClr).       |
//+------------------------------------------------------------------+
void DashRectangle(string name, int x, int y, int width, int height,
                   color bgClr, color borderClr)
{
   string objName = "TOND_" + name;

   if(ObjectFind(0, objName) < 0)
   {
      ObjectCreate(0, objName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, objName, OBJPROP_BACK, false);
      ObjectSetInteger(0, objName, OBJPROP_ZORDER, TOND_Z_RECT);
      ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, objName, OBJPROP_HIDDEN, true);
   }

   ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, objName, OBJPROP_XSIZE, width);
   ObjectSetInteger(0, objName, OBJPROP_YSIZE, height);
   ObjectSetInteger(0, objName, OBJPROP_BGCOLOR, bgClr);
   ObjectSetInteger(0, objName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, objName, OBJPROP_BORDER_COLOR, borderClr);
}

//+------------------------------------------------------------------+
//| DashLabel — Crea/aggiorna un'etichetta testo                     |
//|                                                                  |
//| NAMING: Prefisso "TOND_DASH_" + id univoco (es. "TOND_DASH_H_PAIR").|
//| STACKING: ZORDER=TOND_Z_LABEL → sopra i rettangoli pannello.      |
//| Font default: TOND_FONT_BODY / TOND_FONT_SIZE_BODY (adVisualTheme). |
//| Testo vuoto: sostituito con " " per evitare artefatti MT5.       |
//+------------------------------------------------------------------+
void DashLabel(string id, int x, int y, string text, color clr,
               int fontSize = TOND_FONT_SIZE_BODY, string fontName = "")
{
   if(fontName == "") fontName = TOND_FONT_BODY;
   string name = "TOND_DASH_" + id;

   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, name, OBJPROP_ZORDER, TOND_Z_LABEL);
   }

   ObjectSetString(0, name, OBJPROP_FONT, fontName);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetString(0, name, OBJPROP_TEXT, text == "" ? " " : text);
}

// ApplyChartTheme() definita in adVisualTheme.mqh

//+------------------------------------------------------------------+
//| DrawHeaderRow — Title header: TERZAONDA + version + ENGINE (36px)|
//+------------------------------------------------------------------+
void DrawHeaderRow(int x, int y, int w)
{
   DashRectangle("HDR_PANEL", x, y, w, TOND_H_HEADER, TOND_BG_SECTION_A, TOND_BIOLUM_DIM);

   // TERZAONDA — grande, font title
   DashLabel("HDR_LOGO", x + TOND_PAD, y + 7, "TERZAONDA", TOND_BIOLUM, 14, TOND_FONT_TITLE);

   // Versione
   DashLabel("HDR_VER", x + TOND_PAD + 175, y + 12, "v" + EA_VERSION, TOND_TEXT_MUTED, 9);

   // ENGINE: KPC v1.0
   DashLabel("HDR_ENG", x + w - 280, y + 12, "ENGINE: KPC v1.0", TOND_BIOLUM_DIM, 9, TOND_FONT_SECTION);
}

//+------------------------------------------------------------------+
//| DrawTitleBar — Pair + Price + Spread + State (32px)             |
//+------------------------------------------------------------------+
void DrawTitleBar(int x, int y, int w)
{
   int pad = TOND_PAD;
   DashRectangle("TITLE_PANEL", x, y, w, TOND_H_TOPBAR, TOND_BG_SECTION_A, TOND_PANEL_BORDER);

   // Pair + price + spread
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   DashLabel("H_PAIR", x + pad, y + 8, _Symbol, TOND_TEXT_HI, 11, TOND_FONT_SECTION);
   DashLabel("H_PRICE", x + pad + 90, y + 8, DoubleToString(bid, _Digits), TOND_BIOLUM, 11);
   DashLabel("H_SPREAD", x + pad + 200, y + 10, StringFormat("Spread:%.1f", GetSpreadPips()), TOND_TEXT_MUTED, 8);

   // TF preset badge
   string tfBadge = "KPC v1.0";
   if(InpKPC_TFPreset == TF_PRESET_KC_AUTO)
      tfBadge += " " + EnumToString(Period());
   DashLabel("H_TF", x + pad + 310, y + 10, tfBadge, TOND_BIOLUM_DIM, 8);

   // State badge with dot
   string stateStr = "IDLE"; color stateClr = TOND_TEXT_MUTED;
   switch(g_systemState)
   {
      case STATE_ACTIVE:       stateStr = "ACTIVE";       stateClr = TOND_BUY; break;
      case STATE_PAUSED:       stateStr = "PAUSED";       stateClr = TOND_AMBER; break;
      case STATE_ERROR:        stateStr = "ERROR";        stateClr = TOND_SELL; break;
      case STATE_INITIALIZING: stateStr = "INIT...";      stateClr = TOND_BIOLUM; break;
   }
   DashLabel("H_STATE", x + w - 100, y + 8, ShortToString(0x25CF) + " " + stateStr, stateClr, 11, TOND_FONT_SECTION);
}

//+------------------------------------------------------------------+
//| DrawSystemStatus — 2x3 grid: Session|Uptime|Spread|ATR|Bal|Eq  |
//+------------------------------------------------------------------+
void DrawSystemStatus(int x, int y, int w)
{
   int pad = TOND_PAD;
   DashRectangle("SYS_PANEL", x, y, w, TOND_H_SYSSTATUS, TOND_PANEL_BG, TOND_PANEL_BORDER);
   DashLabel("SYS_TITLE", x + pad, y + 4, "SYSTEM STATUS", TOND_BIOLUM_DIM, 9, TOND_FONT_SECTION);

   // Grid: 3 rows x 2 columns, labels + values
   int col1 = x + pad;
   int col3 = x + pad + 220;
   int col5 = x + pad + 440;
   int row1 = y + 22;
   int row2 = y + 40;
   int row3 = y + 58;

   // Row 1: Session | Uptime | Free Margin
   DashLabel("SY_L1", col1, row1, "SESSION", TOND_TEXT_LO, 7);
   DashLabel("SY_V1", col1, row1 + 10, GetSessionStatus(), TOND_TEXT_HI, 10, TOND_FONT_SECTION);

   DashLabel("SY_L2", col3, row1, "UPTIME", TOND_TEXT_LO, 7);
   int upSec = (int)(TimeCurrent() - g_systemStartTime);
   int upH = upSec / 3600; int upM = (upSec % 3600) / 60; int upS = upSec % 60;
   DashLabel("SY_V2", col3, row1 + 10,
             StringFormat("%02d:%02d:%02d", upH, upM, upS), TOND_TEXT_HI, 10);

   double freeMargin = GetFreeMargin();
   double marginLvl  = GetMarginLevel();
   DashLabel("SY_L3", col5, row1, "FREE MARGIN", TOND_TEXT_LO, 7);
   DashLabel("SY_V3", col5, row1 + 10, FormatMoney(freeMargin),
             marginLvl > 500 ? TOND_BUY : (marginLvl > 200 ? TOND_AMBER : TOND_SELL), 10);

   // Row 2: Spread | ATR | Balance
   double spread = GetSpreadPips();
   DashLabel("SY_L4", col1, row2, "SPREAD", TOND_TEXT_LO, 7);
   DashLabel("SY_V4", col1, row2 + 10,
             StringFormat("%.1f pip", spread),
             spread > g_inst_maxSpread ? TOND_SELL : TOND_BUY, 10);

   DashLabel("SY_L5", col3, row2, "ATR(14)", TOND_TEXT_LO, 7);
   DashLabel("SY_V5", col3, row2 + 10,
             StringFormat("%.1f pip", g_atrCache.valuePips), TOND_BIOLUM, 10);

   DashLabel("SY_L6", col5, row2, "BALANCE", TOND_TEXT_LO, 7);
   DashLabel("SY_V6", col5, row2 + 10, FormatMoney(GetBalance()), TOND_TEXT_HI, 10);

   // Row 3: Equity | Margin Level
   double equity = GetEquity();
   double balance = GetBalance();
   DashLabel("SY_L7", col1, row3, "EQUITY", TOND_TEXT_LO, 7);
   DashLabel("SY_V7", col1, row3 + 10, FormatMoney(equity),
             equity >= balance ? TOND_BUY : TOND_SELL, 10, TOND_FONT_SECTION);

   DashLabel("SY_L8", col3, row3, "MARGIN LVL", TOND_TEXT_LO, 7);
   DashLabel("SY_V8", col3, row3 + 10,
             marginLvl > 0 ? StringFormat("%.0f%%", marginLvl) : "---",
             marginLvl > 500 ? TOND_BUY : (marginLvl > 200 ? TOND_AMBER : TOND_SELL), 10);
}

//+------------------------------------------------------------------+
//| DrawEnginePanel — Band Stack + Width + SmartCD (88px)           |
//+------------------------------------------------------------------+
void DrawEnginePanel(int x, int y, int w)
{
   int pad = TOND_PAD;
   DashRectangle("ENG_PANEL", x, y, w, TOND_H_ENGINE, TOND_BG_DEEP, TOND_PANEL_BORDER);
   DashLabel("ENG_TITLE", x + pad, y + 6, "KPC ENGINE", TOND_BIOLUM, 10, TOND_FONT_SECTION);

   bool ready = g_engineReady;
   DashLabel("ENG_STATUS", x + w - 100, y + 6,
             ready ? "ACTIVE" : "INIT...", ready ? TOND_BUY : TOND_AMBER, 10, TOND_FONT_SECTION);

   // TP Mode label — centrato tra titolo e status
   string tpStr = "";
   switch(TPMode)
   {
      case TP_MIDLINE:       tpStr = "TP: MIDLINE";                         break;
      case TP_OPPOSITE_BAND: tpStr = "TP: OPP.BAND";                       break;
      case TP_150_PERCENT:   tpStr = "TP: 150%";                            break;
      case TP_ATR_MULTIPLE:  tpStr = "TP: ATR" + ShortToString(0x00D7) + StringFormat("%.1f", TPValue); break;
      case TP_FIXED_PIPS:    tpStr = StringFormat("TP: %.0f pip", TPValue);  break;
   }
   DashLabel("ENG_TP", x + w / 2, y + 6, tpStr, TOND_AMBER, 9, TOND_FONT_SECTION);

   if(g_lastSignal.upperBand > 0)
   {
      DashLabel("ENG_UPPER", x + pad, y + 26,
                StringFormat("Upper  %s", DoubleToString(g_lastSignal.upperBand, _Digits)),
                TOND_SELL, 9);
      DashLabel("ENG_MID", x + pad + 180, y + 26,
                StringFormat("Mid    %s", DoubleToString(g_lastSignal.midline, _Digits)),
                TOND_BIOLUM, 9);
      DashLabel("ENG_LOWER", x + pad + 360, y + 26,
                StringFormat("Lower  %s", DoubleToString(g_lastSignal.lowerBand, _Digits)),
                TOND_BUY, 9);

      // Channel width + regime
      string regime = g_lastSignal.isFlat ? "FLAT" : "TRENDING";
      color regClr = g_lastSignal.isFlat ? TOND_BUY : TOND_AMBER;
      DashLabel("ENG_WIDTH", x + pad, y + 44,
                StringFormat("Width: %.1f pip", g_lastSignal.channelWidthPip),
                TOND_BIOLUM, 9, TOND_FONT_SECTION);
      DashLabel("ENG_REGIME", x + pad + 140, y + 44, regime, regClr, 9, TOND_FONT_SECTION);

      // SmartCooldown (reads engine config from extraValues[5-9])
      int eDcLen  = (int)g_lastSignal.extraValues[5];
      int eMaLen  = (int)g_lastSignal.extraValues[6];
      double eMinW = g_lastSignal.extraValues[7];
      int eNSame  = (int)g_lastSignal.extraValues[8];
      int eNOpp   = (int)g_lastSignal.extraValues[9];

      string cdStr = StringFormat("SmartCD ON (S%d/O%d)", eNSame, eNOpp);
      DashLabel("ENG_CD", x + pad + 280, y + 44, cdStr, TOND_TEXT_SECONDARY, 9);

      // Engine config summary
      DashLabel("ENG_CFG", x + pad, y + 62,
                StringFormat("Period:%d | MA:KAMA(%d) | MinW:%.0f",
                eDcLen, eMaLen, eMinW),
                TOND_TEXT_MUTED, 8);
   }
   else
   {
      DashLabel("ENG_UPPER", x + pad, y + 26, "Waiting for data...", TOND_TEXT_MUTED, 9);
      DashLabel("ENG_MID", x + pad + 180, y + 26, " ", TOND_TEXT_MUTED, 9);
      DashLabel("ENG_LOWER", x + pad + 360, y + 26, " ", TOND_TEXT_MUTED, 9);
      DashLabel("ENG_WIDTH", x + pad, y + 44, " ", TOND_TEXT_MUTED, 9);
      DashLabel("ENG_REGIME", x + pad + 140, y + 44, " ", TOND_TEXT_MUTED, 9);
      DashLabel("ENG_CD", x + pad + 280, y + 44, " ", TOND_TEXT_MUTED, 9);
      DashLabel("ENG_CFG", x + pad, y + 62, " ", TOND_TEXT_MUTED, 8);
   }
}

//+------------------------------------------------------------------+
//| DrawFilterBar — Individual colored pills (22px)                 |
//+------------------------------------------------------------------+
void DrawFilterBar(int x, int y, int w)
{
   DashRectangle("FILT_PANEL", x, y, w, TOND_H_FILTERS, TOND_PANEL_BG, TOND_PANEL_BORDER);

   int px = x + TOND_PAD;
   for(int f = 0; f < g_lastSignal.filterCount && f < 8; f++)
   {
      string state = "";
      color  clr   = TOND_TEXT_MUTED;

      if(g_lastSignal.filterStates[f] == 1)
      {  state = "+"; clr = TOND_BUY; }
      else if(g_lastSignal.filterStates[f] == -1)
      {  state = "!"; clr = TOND_SELL; }
      else
      {  state = "_"; clr = TOND_TEXT_LO; }

      string pill = "[" + state + g_lastSignal.filterNames[f] + "]";
      DashLabel(StringFormat("FP%d", f), px, y + 3, pill, clr, 8);
      px += StringLen(pill) * 6 + 4;
   }

   // Session pill
   bool inSession = IsWithinSession();
   DashLabel("FP_SESS", px, y + 3,
             inSession ? "[+Sess]" : "[!Sess]",
             inSession ? TOND_BUY : TOND_SELL, 8);
   px += 48;

   // Hedge pill
   DashLabel("FP_HEDGE", px, y + 3,
             EnableHedge ? "[+Hedge]" : "[_Hedge]",
             EnableHedge ? TOND_HEDGE : TOND_TEXT_LO, 8);
}

//+------------------------------------------------------------------+
//| DrawLastSignals — Last 3 signals with direction + route (76px) |
//+------------------------------------------------------------------+
void DrawLastSignals(int x, int y, int w)
{
   int pad = TOND_PAD;
   DashRectangle("SIG_PANEL", x, y, w, TOND_H_LASTSIG, TOND_BG_SECTION_B, TOND_PANEL_BORDER);
   DashLabel("SIG_TITLE", x + pad, y + 4, "LAST SIGNALS", TOND_AMBER_DIM, 9, TOND_FONT_SECTION);
   DashLabel("SIG_CNT", x + w - 120, y + 5,
             StringFormat("B:%d S:%d Tot:%d", g_buySignals, g_sellSignals, g_totalSignals),
             TOND_TEXT_MUTED, 8);

   int ly = y + 22;
   for(int i = 0; i < 3; i++)
   {
      if(i < g_signalHistCount)
      {
         string arrow = g_signalHist[i].dir > 0 ? "\x25B2" : "\x25BC";
         string dirStr = g_signalHist[i].dir > 0 ? "BUY " : "SELL";
         color dirClr = g_signalHist[i].dir > 0 ? TOND_BUY : TOND_SELL;
         string qStr = g_signalHist[i].quality == PATTERN_TBS ? "[TBS]" : "[TWS]";
         color qClr = g_signalHist[i].quality == PATTERN_TBS ? TOND_BUY : TOND_AMBER;

         DashLabel(StringFormat("SH%d_DIR", i), x + pad, ly,
                   arrow + " " + dirStr + FormatPrice(g_signalHist[i].entry) +
                   " -> " + FormatPrice(g_signalHist[i].tp),
                   dirClr, 9);
         DashLabel(StringFormat("SH%d_Q", i), x + pad + 350, ly, qStr, qClr, 9, TOND_FONT_SECTION);
         DashLabel(StringFormat("SH%d_T", i), x + w - 80, ly,
                   TimeToString(g_signalHist[i].time, TIME_MINUTES),
                   TOND_TEXT_MUTED, 8);
         DashLabel(StringFormat("SH%d_S", i), x + w - 40, ly,
                   g_signalHist[i].status, TOND_TEXT_MID, 8);
      }
      else
      {
         DashLabel(StringFormat("SH%d_DIR", i), x + pad, ly, " ", TOND_TEXT_MUTED, 9);
         DashLabel(StringFormat("SH%d_Q", i), x + pad + 350, ly, " ", TOND_TEXT_MUTED, 9);
         DashLabel(StringFormat("SH%d_T", i), x + w - 80, ly, " ", TOND_TEXT_MUTED, 8);
         DashLabel(StringFormat("SH%d_S", i), x + w - 40, ly, " ", TOND_TEXT_MUTED, 8);
      }
      ly += 16;
   }
}

//+------------------------------------------------------------------+
//| DrawActiveCycles — Header + max 4 cycle rows (100px)             |
//|                                                                  |
//| Mostra fino a 4 cicli attivi con: ID Dir State Lot Entry toTP PL |
//| STATI CICLO (colori):                                            |
//|   PEND (TOND_AMBER) — ordine pending stop, in attesa di fill       |
//|   LIVE (TOND_BUY/TOND_SELL) — posizione aperta, colore per direzione |
//|   HEDG (TOND_HEDGE/fucsia) — hedge attivo, P&L separato S: e H:   |
//|                                                                  |
//| P&L DISPLAY (HEDGING):                                           |
//|   Quando state=HEDG, mostra "S:+12 H:-8" con colori separati    |
//|   per Soup e Hedge. GetFloatingProfit legge dal broker in RT.    |
//|   Nota: hsPL NON e' incluso nel float display —                  |
//|   e' gia' conteggiato nel P&L SESSION da HsClose().              |
//+------------------------------------------------------------------+
void DrawActiveCycles(int x, int y, int w)
{
   int pad = TOND_PAD;
   int cycH = TOND_H_CYCLES;
   DashRectangle("CYCLE_PANEL", x, y, w, cycH, TOND_BG_DEEP, TOND_PANEL_BORDER);
   DashLabel("CY_TITLE", x + pad, y + 4, "ACTIVE CYCLES", TOND_BUY_DIM, 9, TOND_FONT_SECTION);

   int activeCycles = CountActiveCycles();
   DashLabel("CY_CNT", x + w - 70, y + 5,
             StringFormat("%d/%d", activeCycles, MaxConcurrentTrades), TOND_BUY, 9, TOND_FONT_SECTION);

   // Column header
   DashLabel("CY_HDR", x + pad, y + 20,
             "#   Dir  State  Lot    Entry         toTP     P&L", TOND_TEXT_LO, 7);

   int cy = y + 34;
   int displayed = 0;
   for(int i = 0; i < ArraySize(g_cycles) && displayed < 4; i++)
   {
      if(g_cycles[i].state == CYCLE_IDLE || g_cycles[i].state == CYCLE_CLOSED) continue;

      string dirStr = g_cycles[i].direction > 0 ? "BUY " : "SELL";
      string stStr = "LIVE";
      color  rowClr = g_cycles[i].direction > 0 ? TOND_BUY : TOND_SELL;
      if(g_cycles[i].state == CYCLE_PENDING)      { stStr = "PEND"; rowClr = TOND_AMBER; }
      else if(g_cycles[i].state == CYCLE_HEDGING) { stStr = "HEDG"; rowClr = TOND_HEDGE; }

      // Lot size display
      string lotStr = StringFormat("%.2f", g_cycles[i].lotSize);

      // Distance to TP in pips
      string tpDistStr = "---";
      if(g_cycles[i].tpPrice > 0 && g_cycles[i].state != CYCLE_PENDING)
      {
         double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double distToTP = 0;
         if(g_cycles[i].direction > 0)
            distToTP = g_cycles[i].tpPrice - currentBid;  // BUY: TP sopra
         else
            distToTP = currentBid - g_cycles[i].tpPrice;  // SELL: TP sotto
         double pipDist = PointsToPips(distToTP);
         tpDistStr = StringFormat("%+.0f", pipDist);
      }

      // Floating P&L — separato per HEDG
      double soupPL  = 0;
      double hedgePL = 0;
      double floatPL = 0;
      if(g_cycles[i].state == CYCLE_ACTIVE && g_cycles[i].ticket > 0)
      {
         soupPL = GetFloatingProfit(g_cycles[i].ticket);
         floatPL = soupPL;
      }
      else if(g_cycles[i].state == CYCLE_HEDGING)
      {
         if(g_cycles[i].ticket > 0)
            soupPL = GetFloatingProfit(g_cycles[i].ticket);
         if(g_cycles[i].hsActive && g_cycles[i].hsTicket > 0)
            hedgePL = GetFloatingProfit(g_cycles[i].hsTicket);
         floatPL = soupPL + hedgePL;
      }
      color plClr = floatPL >= 0 ? TOND_BUY : TOND_SELL;

      // Riga principale: ID Dir State Lot Entry toTP
      DashLabel(StringFormat("CY%d", displayed), x + pad, cy,
                StringFormat("%02d  %s  %s  %s  %s",
                g_cycles[i].cycleID, dirStr, stStr, lotStr, FormatPrice(g_cycles[i].entryPrice)),
                rowClr, 9);

      // TP distance (colonna separata per allineamento)
      DashLabel(StringFormat("CY%d_TP", displayed), x + w - 150, cy,
                tpDistStr, TOND_BIOLUM_DIM, 9);

      // P&L — se HEDG mostra "S:+12 H:-8" altrimenti solo totale
      if(g_cycles[i].state == CYCLE_HEDGING)
      {
         color splClr = soupPL >= 0 ? TOND_BUY : TOND_SELL;
         color hplClr = hedgePL >= 0 ? TOND_BUY : TOND_SELL;
         DashLabel(StringFormat("CY%d_PL", displayed), x + w - 100, cy,
                   StringFormat("S:%+.0f", soupPL), splClr, 8);
         DashLabel(StringFormat("CY%d_HPL", displayed), x + w - 50, cy,
                   StringFormat("H:%+.0f", hedgePL), hplClr, 8);
      }
      else
      {
         DashLabel(StringFormat("CY%d_PL", displayed), x + w - 80, cy,
                   StringFormat("%+.2f", floatPL), plClr, 9);
         DashLabel(StringFormat("CY%d_HPL", displayed), x + w - 50, cy,
                   " ", TOND_TEXT_MUTED, 8);
      }

      cy += 16;
      displayed++;
   }
   for(int c = displayed; c < 4; c++)
   {
      DashLabel(StringFormat("CY%d", c), x + pad, cy, " ", TOND_TEXT_MUTED, 9);
      DashLabel(StringFormat("CY%d_TP", c), x + w - 150, cy, " ", TOND_TEXT_MUTED, 9);
      DashLabel(StringFormat("CY%d_PL", c), x + w - 80, cy, " ", TOND_TEXT_MUTED, 9);
      DashLabel(StringFormat("CY%d_HPL", c), x + w - 50, cy, " ", TOND_TEXT_MUTED, 8);
      cy += 16;
   }
}

//+------------------------------------------------------------------+
//| DrawPLSession — 3x2 grid: P&L|WinRate|MaxDD|Trades|Float|Daily  |
//|                                                                  |
//| Grid 3 colonne x 2 righe (90px):                                 |
//|   Row 1: P&L (realized + %) | Win Rate (W·L) | Max DD (% + $)   |
//|   Row 2: Trades (total)     | Float (open)    | Daily (today)    |
//|                                                                  |
//| P&L SOURCES:                                                     |
//|   g_sessionRealizedProfit — profitto realizzato (chiusure cicli)  |
//|   totalFloat — somma floating P&L di tutte le posizioni aperte   |
//|     Include Soup tickets + Hedge tickets (H1/H2) se CYCLE_HEDGING|
//|   g_dailyRealizedProfit — solo profitti del giorno corrente      |
//|                                                                  |
//| COLORI CONDIZIONALI:                                              |
//|   P&L >= 0 → TOND_BUY (lime), < 0 → TOND_SELL (rosso)               |
//|   WinRate >= 50% → TOND_BUY, < 50% → TOND_SELL                      |
//|   MaxDD > 3% → TOND_SELL (allarme), altrimenti TOND_TEXT_HI          |
//+------------------------------------------------------------------+
void DrawPLSession(int x, int y, int w)
{
   int pad = TOND_PAD;
   DashRectangle("PL_PANEL", x, y, w, TOND_H_PL, TOND_PANEL_BG, TOND_PANEL_BORDER);
   DashLabel("PL_TITLE", x + pad, y + 4, "P&L SESSION", TOND_SELL_DIM, 9, TOND_FONT_SECTION);

   int colW = (w - 2 * pad) / 3;
   int c1 = x + pad;
   int c2 = x + pad + colW;
   int c3 = x + pad + 2 * colW;
   int r1 = y + 22;
   int r2 = y + 54;

   // Row 1: P&L | Win Rate | Max DD
   color plClr = g_sessionRealizedProfit >= 0 ? TOND_BUY : TOND_SELL;
   DashLabel("PL_L1", c1, r1, "P&L", TOND_TEXT_LO, 7);
   DashLabel("PL_V1", c1, r1 + 10, StringFormat("%+.2f", g_sessionRealizedProfit), plClr, 11, TOND_FONT_SECTION);
   double pnlPct = GetBalance() > 0 ? (g_sessionRealizedProfit / GetBalance() * 100) : 0;
   DashLabel("PL_S1", c1, r1 + 24, StringFormat("%+.2f%%", pnlPct), TOND_TEXT_MID, 8);

   int totalT = g_sessionWins + g_sessionLosses;
   double winrate = totalT > 0 ? (double)g_sessionWins / totalT * 100.0 : 0;
   DashLabel("PL_L2", c2, r1, "WIN RATE", TOND_TEXT_LO, 7);
   DashLabel("PL_V2", c2, r1 + 10, StringFormat("%.0f%%", winrate),
             winrate >= 50 ? TOND_BUY : TOND_SELL, 11, TOND_FONT_SECTION);
   DashLabel("PL_S2", c2, r1 + 24,
             StringFormat("%dW · %dL", g_sessionWins, g_sessionLosses), TOND_TEXT_MID, 8);

   DashLabel("PL_L3", c3, r1, "MAX DD", TOND_TEXT_LO, 7);
   DashLabel("PL_V3", c3, r1 + 10, StringFormat("%.1f%%", g_maxDrawdownPct),
             g_maxDrawdownPct > 3.0 ? TOND_SELL : TOND_TEXT_HI, 11, TOND_FONT_SECTION);
   double ddMoney = GetBalance() * g_maxDrawdownPct / 100.0;
   DashLabel("PL_S3", c3, r1 + 24, StringFormat("-$%.0f", ddMoney), TOND_TEXT_MID, 8);

   // Row 2: Trades | Float | Daily Loss
   DashLabel("PL_L4", c1, r2, "TRADES", TOND_TEXT_LO, 7);
   DashLabel("PL_V4", c1, r2 + 10, IntegerToString(totalT), TOND_TEXT_HI, 11, TOND_FONT_SECTION);
   DashLabel("PL_S4", c1, r2 + 24, "total", TOND_TEXT_MID, 8);

   double totalFloat = 0;
   for(int fi = 0; fi < ArraySize(g_cycles); fi++)
   {
      if((g_cycles[fi].state == CYCLE_ACTIVE || g_cycles[fi].state == CYCLE_HEDGING)
         && g_cycles[fi].ticket > 0)
         totalFloat += GetFloatingProfit(g_cycles[fi].ticket);
      if(g_cycles[fi].state == CYCLE_HEDGING
         && g_cycles[fi].hsActive && g_cycles[fi].hsTicket > 0)
         totalFloat += GetFloatingProfit(g_cycles[fi].hsTicket);
   }
   color fClr = totalFloat >= 0 ? TOND_BUY : TOND_SELL;
   DashLabel("PL_L5", c2, r2, "FLOAT", TOND_TEXT_LO, 7);
   DashLabel("PL_V5", c2, r2 + 10, StringFormat("%+.2f", totalFloat), fClr, 11, TOND_FONT_SECTION);
   DashLabel("PL_S5", c2, r2 + 24, "open", TOND_TEXT_MID, 8);

   color dClr = g_dailyRealizedProfit >= 0 ? TOND_BUY : TOND_SELL;
   DashLabel("PL_L6", c3, r2, "DAILY", TOND_TEXT_LO, 7);
   DashLabel("PL_V6", c3, r2 + 10, StringFormat("%+.2f", g_dailyRealizedProfit), dClr, 11, TOND_FONT_SECTION);
   DashLabel("PL_S6", c3, r2 + 24, "today", TOND_TEXT_MID, 8);
}

//+------------------------------------------------------------------+
//| DrawControls — Title + session + time (52px)                    |
//+------------------------------------------------------------------+
void DrawControls(int x, int y, int w)
{
   int pad = TOND_PAD;
   DashRectangle("CTRL_PANEL", x, y, w, TOND_H_CONTROLS, TOND_PANEL_BG, TOND_PANEL_BORDER);
   DashLabel("CT_TITLE", x + pad, y + 4, "CONTROLS", TOND_AMBER_DIM, 9, TOND_FONT_SECTION);

   DashLabel("CT_TIME", x + w - 80, y + 5,
             TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES), TOND_TEXT_MUTED, 8);

   // Button feedback
   if(ObjectFind(0, "TOND_BTN_START_" + _Symbol) >= 0)
      UpdateButtonFeedback();
}

//+------------------------------------------------------------------+
//| DrawStatusBar — Bottom summary bar (20px)                       |
//+------------------------------------------------------------------+
void DrawStatusBar(int x, int y, int w)
{
   DashRectangle("SBAR_PANEL", x, y, w, TOND_H_STATUSBAR, TOND_BG_SECTION_A, TOND_PANEL_BORDER);

   string stateStr = "IDLE";
   switch(g_systemState)
   {
      case STATE_ACTIVE:       stateStr = "ACTIVE"; break;
      case STATE_PAUSED:       stateStr = "PAUSED"; break;
      case STATE_ERROR:        stateStr = "ERROR";  break;
      case STATE_INITIALIZING: stateStr = "INIT";   break;
   }

   string cdMode = "SmartCD:ON";
   string twsMode = InpKPC_ShowHalfSignals ? "TWS:ON" : "TWS:HID";
   string ltfMode = g_kpc_useLTFEntry ? "LTF:ON" : "";
   string hedgeMode = EnableHedge ? "Hedge:ON" : "Hedge:OFF";

   string bar = ShortToString(0x25CF) + " " + stateStr
              + "  KPC v1.0"
              + "  " + cdMode
              + "  TBS:ON " + twsMode
              + (ltfMode != "" ? "  " + ltfMode : "")
              + "  " + hedgeMode
              + "  v" + EA_VERSION
              + "  M:" + IntegerToString(MagicNumber);

   DashLabel("SBAR_TXT", x + TOND_PAD, y + 3, bar, TOND_TEXT_MID, 8);
}

//+------------------------------------------------------------------+
//| UpdateSidePanel — Engine Monitor (13 righe) + Signal Feed (6)    |
//|                                                                  |
//| Posizionato a destra del dashboard (offset TOND_DASH_W + 10px).    |
//| Due sezioni:                                                     |
//|                                                                  |
//| ENGINE MONITOR (235px, 13 righe da lh=15px):                     |
//|   1.  DPC Engine — ACTIVE/INIT (g_engineReady)                   |
//|   2.  ATR(14) — da extraValues[0] o g_atrCache                   |
//|   3.  EMA ATR — da extraValues[1]                                |
//|   4.  Daily Trades — W/L odierni                                 |
//|   5.  TF Preset — timeframe corrente                             |
//|   6.  DC Period — da extraValues[5]                               |
//|   7.  MA Value — da extraValues[2]                                |
//|   8.  SmartCD — ON (S/O counts) o OFF                            |
//|   9.  LTF Entry — TF usato o OFF                                 |
//|  10.  Expired — ordini pending scaduti                            |
//|  11.  AutoSave — tempo dall'ultimo salvataggio GV                 |
//|  12.  HTF Filter — stato filtro higher timeframe                  |
//|  13.  Hedge — ON (count) o OFF                                   |
//|  [14.] VIRTUAL MODE — badge arancio se VirtualMode=true          |
//|                                                                  |
//| SIGNAL FEED (110px, MAX_FEED_ITEMS righe):                       |
//|   Feed cronologico delle ultime azioni EA (g_feedLines[]).        |
//|   Colori per tipo: TOND_BUY, TOND_SELL, TOND_AMBER, TOND_TEXT_MUTED.     |
//+------------------------------------------------------------------+
void UpdateSidePanel()
{
   int sx = TOND_DASH_X + TOND_DASH_W + 10;
   int sy = TOND_DASH_Y;
   int sw = TOND_SIDE_W;

   // === ENGINE MONITOR ===
   DashRectangle("SIDE_MON", sx, sy, sw, 235, TOND_BG_DEEP, TOND_SIDE_BORDER);
   DashLabel("SM_TITLE", sx + 10, sy + 5, "ENGINE MONITOR", TOND_BIOLUM_DIM, 9, TOND_FONT_SECTION);

   int ly = sy + 22;
   int lh = 15;
   int valX = sx + 100;

   // 1. Engine status
   DashLabel("SM_R01L", sx + 10, ly, "KPC Engine", TOND_TEXT_MID, 8);
   DashLabel("SM_R01V", valX, ly, g_engineReady ? "ACTIVE" : "INIT", g_engineReady ? TOND_BUY : TOND_AMBER, 8, TOND_FONT_SECTION);
   ly += lh;

   // 2. ATR
   DashLabel("SM_R02L", sx + 10, ly, "ATR(14)", TOND_TEXT_MID, 8);
   DashLabel("SM_R02V", valX, ly,
             StringFormat("%.1f pip", g_lastSignal.extraValues[0] > 0 ? PointsToPips(g_lastSignal.extraValues[0]) : g_atrCache.valuePips),
             TOND_BIOLUM, 8);
   ly += lh;

   // 3. EMA ATR
   DashLabel("SM_R03L", sx + 10, ly, "EMA ATR", TOND_TEXT_MID, 8);
   DashLabel("SM_R03V", valX, ly,
             StringFormat("%.1f pip", g_lastSignal.extraValues[1] > 0 ? PointsToPips(g_lastSignal.extraValues[1]) : 0),
             TOND_TEXT_SECONDARY, 8);
   ly += lh;

   // 4. Daily Trades (sostituisce Spread — gia' in System Status)
   DashLabel("SM_R04L", sx + 10, ly, "Daily Trades", TOND_TEXT_MID, 8);
   DashLabel("SM_R04V", valX, ly,
             StringFormat("%dW %dL", g_dailyWins, g_dailyLosses),
             g_dailyWins >= g_dailyLosses ? TOND_BUY : TOND_SELL, 8);
   ly += lh;

   // 5. TF Preset
   DashLabel("SM_R05L", sx + 10, ly, "TF Preset", TOND_TEXT_MID, 8);
   DashLabel("SM_R05V", valX, ly, EnumToString(Period()), TOND_TEXT_SECONDARY, 8);
   ly += lh;

   // 6. DC Period
   int dcLen = (int)g_lastSignal.extraValues[5];
   DashLabel("SM_R06L", sx + 10, ly, "DC Period", TOND_TEXT_MID, 8);
   DashLabel("SM_R06V", valX, ly, IntegerToString(dcLen > 0 ? dcLen : 20), TOND_TEXT_SECONDARY, 8);
   ly += lh;

   // 7. MA value
   DashLabel("SM_R07L", sx + 10, ly, "MA Value", TOND_TEXT_MID, 8);
   DashLabel("SM_R07V", valX, ly,
             g_lastSignal.extraValues[2] > 0 ? DoubleToString(g_lastSignal.extraValues[2], _Digits) : "---",
             TOND_TEXT_SECONDARY, 8);
   ly += lh;

   // 8. SmartCD
   int nS = (int)g_lastSignal.extraValues[8];
   int nO = (int)g_lastSignal.extraValues[9];
   DashLabel("SM_R08L", sx + 10, ly, "SmartCD", TOND_TEXT_MID, 8);
   DashLabel("SM_R08V", valX, ly,
             StringFormat("ON S%d/O%d", nS, nO),
             TOND_BUY, 8);
   ly += lh;

   // 9. LTF
   DashLabel("SM_R09L", sx + 10, ly, "LTF Entry", TOND_TEXT_MID, 8);
   DashLabel("SM_R09V", valX, ly,
             g_kpc_useLTFEntry ? EnumToString(KPCGetLTFTimeframe()) : "OFF",
             g_kpc_useLTFEntry ? TOND_BIOLUM : TOND_TEXT_MUTED, 8);
   ly += lh;

   // 10. Expired Orders (sostituisce Session — gia' in System Status)
   DashLabel("SM_R10L", sx + 10, ly, "Expired", TOND_TEXT_MID, 8);
   DashLabel("SM_R10V", valX, ly,
             g_totalExpiredOrders > 0 ? IntegerToString(g_totalExpiredOrders) : "0",
             g_totalExpiredOrders > 0 ? TOND_AMBER : TOND_TEXT_MUTED, 8);
   ly += lh;

   // 11. AutoSave
   DashLabel("SM_R11L", sx + 10, ly, "AutoSave", TOND_TEXT_MID, 8);
   string saveStr = "---";
   if(g_lastAutoSaveTime > 0)
   {
      int ago = (int)(TimeCurrent() - g_lastAutoSaveTime);
      saveStr = IntegerToString(ago) + "s ago";
   }
   DashLabel("SM_R11V", valX, ly, saveStr, TOND_TEXT_MUTED, 8);
   ly += lh;

   // 12. HTF
   DashLabel("SM_R12L", sx + 10, ly, "HTF Filter", TOND_TEXT_MID, 8);
   DashLabel("SM_R12V", valX, ly, HTFGetStatusString(), TOND_TEXT_SECONDARY, 8);
   ly += lh;

   // 13. Hedge
   DashLabel("SM_R13L", sx + 10, ly, "Hedge", TOND_TEXT_MID, 8);
   if(EnableHedge)
   {
      int hedgeCount = 0;
      for(int hi = 0; hi < ArraySize(g_cycles); hi++)
      {
         if(g_cycles[hi].hsPending || g_cycles[hi].hsActive) hedgeCount++;
      }
      DashLabel("SM_R13V", valX, ly,
                hedgeCount > 0 ? StringFormat("ON (%d)", hedgeCount) : "ON",
                TOND_HEDGE, 8, TOND_FONT_SECTION);
   }
   else
      DashLabel("SM_R13V", valX, ly, "OFF", TOND_TEXT_MUTED, 8);
   ly += lh;

   // Virtual mode indicator
   if(VirtualMode)
   {
      ly += 4;
      DashLabel("SM_VIRT", sx + 10, ly, "VIRTUAL MODE", TOND_AMBER, 9, TOND_FONT_SECTION);
   }
   else
      DashLabel("SM_VIRT", sx + 10, ly + 4, " ", TOND_TEXT_MUTED, 8);

   // === SIGNAL FEED ===
   int feedY = sy + 245;
   DashRectangle("SIDE_FEED", sx, feedY, sw, 110, TOND_BG_PANEL, TOND_SIDE_BORDER);
   DashLabel("SF_TITLE", sx + 10, feedY + 5, "SIGNAL FEED", TOND_AMBER_DIM, 9, TOND_FONT_SECTION);

   int fy = feedY + 22;
   for(int i = 0; i < MAX_FEED_ITEMS; i++)
   {
      if(i < g_feedCount)
         DashLabel(StringFormat("SF%d", i), sx + 10, fy, g_feedLines[i], g_feedColors[i], 8);
      else
         DashLabel(StringFormat("SF%d", i), sx + 10, fy, " ", TOND_TEXT_MUTED, 8);
      fy += 15;
   }
}

//+------------------------------------------------------------------+
//| UpdateDashboard — Main dashboard update (chiamata ogni 500ms)    |
//|                                                                  |
//| ARCHITETTURA VISIVA (ordine di creazione = ordine di stacking):  |
//|   1. FRAME_BG — sfondo scuro completo (creato PRIMO → sotto)     |
//|   2. Frame titles — "────── TERZAONDA ──────" top e bottom      |
//|   3. 10 pannelli verticali — ciascuno ha Draw*() dedicata        |
//|   4. Side panel — Engine Monitor + Signal Feed                   |
//|   5. FRAME_BORDER T/B/L/R — 4 rettangoli bordo cyan 3px         |
//|      (creati ULTIMI → MT5 li disegna SOPRA tutto il resto)       |
//|                                                                  |
//| La tecnica dei 4 rettangoli bordo separati (SugamaraPivot) e'    |
//| necessaria perche' BORDER_FLAT su OBJ_RECTANGLE_LABEL produce    |
//| solo 1px, insufficiente. I 4 rettangoli sono filled (bgClr =     |
//| borderClr = TOND_BIOLUM) e spessi 3px.                             |
//+------------------------------------------------------------------+
void UpdateDashboard()
{
   int x = TOND_DASH_X;
   int y = TOND_DASH_Y;
   int w = TOND_DASH_W;

   // Altezza totale dashboard: somma pannelli + 9 gap
   int totalH = TOND_H_HEADER + TOND_H_TOPBAR + TOND_H_SYSSTATUS + TOND_H_ENGINE
              + TOND_H_FILTERS + TOND_H_LASTSIG + TOND_H_CYCLES + TOND_H_PL
              + TOND_H_CONTROLS + TOND_H_STATUSBAR + (9 * TOND_GAP);

   // ── Cornice perimetrale con bordo solido 3px (stile SugamaraPivot) ──
   int fm = 4;    // margine cornice (px tra bordo e pannelli)
   int ftH = 20;  // area titolo superiore
   int fbH = 16;  // area titolo inferiore
   int frameX = x - fm;
   int frameY = y - ftH - fm;
   int frameW = w + 2 * fm;
   int frameH = totalH + ftH + fbH + 2 * fm;

   // Sfondo completo frame (creato primo = disegnato sotto i pannelli)
   DashRectangle("FRAME_BG", frameX, frameY,
                 frameW, frameH, TOND_BG_DEEP, TOND_BG_DEEP);

   // Barra decorativa orizzontale (─────)
   string hBar = "";
   for(int b = 0; b < 6; b++) hBar += ShortToString(0x2500);

   // Titolo superiore centrato "────── TERZAONDA ──────"
   DashLabel("FRAME_TITLE", x + w / 2, frameY + 3,
             hBar + " TERZAONDA " + hBar, TOND_BORDER_FRAME, 11, TOND_FONT_TITLE);
   ObjectSetInteger(0, "TOND_DASH_FRAME_TITLE", OBJPROP_ANCHOR, ANCHOR_UPPER);
   ObjectSetInteger(0, "TOND_DASH_FRAME_TITLE", OBJPROP_ZORDER, TOND_Z_LABEL + 1000);

   // Titolo inferiore centrato "────── vX.X.X · KPC v1.0 Engine ──────" (usa EA_VERSION)
   DashLabel("FRAME_BOTTOM", x + w / 2, y + totalH + fm + 1,
             hBar + " v" + EA_VERSION + " " + ShortToString(0x00B7) + " KPC v1.0 Engine " + hBar,
             TOND_BORDER_FRAME, 8, TOND_FONT_SECTION);
   ObjectSetInteger(0, "TOND_DASH_FRAME_BOTTOM", OBJPROP_ANCHOR, ANCHOR_UPPER);
   ObjectSetInteger(0, "TOND_DASH_FRAME_BOTTOM", OBJPROP_ZORDER, TOND_Z_LABEL + 1000);

   DrawHeaderRow(x, y, w);       y += TOND_H_HEADER + TOND_GAP;
   DrawTitleBar(x, y, w);        y += TOND_H_TOPBAR + TOND_GAP;
   DrawSystemStatus(x, y, w);    y += TOND_H_SYSSTATUS + TOND_GAP;
   DrawEnginePanel(x, y, w);     y += TOND_H_ENGINE + TOND_GAP;
   DrawFilterBar(x, y, w);       y += TOND_H_FILTERS + TOND_GAP;
   DrawLastSignals(x, y, w);     y += TOND_H_LASTSIG + TOND_GAP;
   DrawActiveCycles(x, y, w);    y += TOND_H_CYCLES + TOND_GAP;
   DrawPLSession(x, y, w);       y += TOND_H_PL + TOND_GAP;
   DrawControls(x, y, w);        y += TOND_H_CONTROLS + TOND_GAP;
   DrawStatusBar(x, y, w);

   UpdateSidePanel();

   // ── Bordo solido 4 rettangoli (creati ULTIMI per stacking MT5) ──
   int bw = 3;
   color bClr = TOND_BIOLUM;  // cyan brillante C'0,212,255'
   DashRectangle("FRAME_BORDER_T", frameX - bw, frameY - bw,
                 frameW + 2*bw, bw, bClr, bClr);
   DashRectangle("FRAME_BORDER_B", frameX - bw, frameY + frameH,
                 frameW + 2*bw, bw, bClr, bClr);
   DashRectangle("FRAME_BORDER_L", frameX - bw, frameY - bw,
                 bw, frameH + 2*bw, bClr, bClr);
   DashRectangle("FRAME_BORDER_R", frameX + frameW, frameY - bw,
                 bw, frameH + 2*bw, bClr, bClr);
}

//+------------------------------------------------------------------+
//| CreateDashboard — Creazione iniziale dashboard + bottoni         |
//|                                                                  |
//| Chiamata in OnInit(). Disegna tutti i pannelli via               |
//| UpdateDashboard() poi crea i bottoni interattivi (START/STOP/    |
//| PAUSE) nella posizione calcolata del pannello Controls.          |
//|                                                                  |
//| Il calcolo ctrlY replica lo stacking verticale di UpdateDashboard|
//| per posizionare i bottoni esattamente nel pannello Controls.     |
//+------------------------------------------------------------------+
void CreateDashboard()
{
   UpdateDashboard();

   // Calculate controls Y position for buttons
   int ctrlY = TOND_DASH_Y;
   ctrlY += TOND_H_HEADER + TOND_GAP;
   ctrlY += TOND_H_TOPBAR + TOND_GAP;
   ctrlY += TOND_H_SYSSTATUS + TOND_GAP;
   ctrlY += TOND_H_ENGINE + TOND_GAP;
   ctrlY += TOND_H_FILTERS + TOND_GAP;
   ctrlY += TOND_H_LASTSIG + TOND_GAP;
   ctrlY += TOND_H_CYCLES + TOND_GAP;
   ctrlY += TOND_H_PL + TOND_GAP;

   CreateControlButtons(TOND_DASH_X, ctrlY, TOND_DASH_W);
   AdLogI(LOG_CAT_UI, "Dashboard created (Ocean Pragmatic v1.0)");
}

//+------------------------------------------------------------------+
//| DestroyDashboard — Rimuove TUTTI gli oggetti con prefisso "TOND_"  |
//|                                                                  |
//| Chiamata in OnDeinit(). ObjectsDeleteAll con prefisso "TOND_"      |
//| cancella dashboard, overlay, markers, bottoni — tutto in un colpo.|
//| Il chart torna completamente pulito.                             |
//+------------------------------------------------------------------+
void DestroyDashboard()
{
   ObjectsDeleteAll(0, "TOND_");
}
