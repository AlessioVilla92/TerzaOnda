//+------------------------------------------------------------------+
//|                                       adSignalMarkers.mqh        |
//|           AcquaDulza EA v1.0.0 — Signal Markers                  |
//|                                                                  |
//|  Replica indicatore DonchianPredictiveChannel.mq5:               |
//|  TBS arrows (bright lime/red) + TWS arrows (dark green/red)      |
//|  ATR offset, signal text labels, entry dots                      |
//|  Engine-agnostic: reads EngineSignal only.                       |
//+------------------------------------------------------------------+
#property copyright "AcquaDulza (C) 2026"

//+------------------------------------------------------------------+
//| GetSignalArrowColor — TBS bright / TWS muted                     |
//+------------------------------------------------------------------+
color GetSignalArrowColor(bool isBuy, int quality)
{
   if(quality >= PATTERN_TBS)
      return isBuy ? AD_ARROW_TBS_BUY : AD_ARROW_TBS_SELL;
   else
      return isBuy ? AD_ARROW_TWS_BUY : AD_ARROW_TWS_SELL;
}

//+------------------------------------------------------------------+
//| DrawSignalArrow — TBS/TWS arrow with ATR offset                  |
//|  arrowCode 233=up (BUY), 234=down (SELL)                         |
//+------------------------------------------------------------------+
void DrawSignalArrow(const EngineSignal &sig)
{
   if(!ShowSignalArrows) return;
   if(sig.direction == 0 || !sig.isNewSignal) return;

   bool isBuy = (sig.direction > 0);
   string name = StringFormat("AD_SIG_%s_%d_%s",
                 isBuy ? "BUY" : "SELL", sig.quality,
                 TimeToString(sig.barTime, TIME_DATE|TIME_MINUTES));

   int arrowCode = isBuy ? 233 : 234;
   color clr = GetSignalArrowColor(isBuy, sig.quality);

   // Arrow placement: band level with ATR offset (like indicator)
   double atr = (sig.extraValues[0] > 0) ? sig.extraValues[0] * g_symbolPoint * 10 : 0;
   double offset = atr * AD_ARROW_OFFSET;
   double bandPrice = isBuy ? sig.lowerBand : sig.upperBand;
   if(bandPrice <= 0) bandPrice = sig.entryPrice;
   double price = isBuy ? (bandPrice - offset) : (bandPrice + offset);
   if(price <= 0) price = bandPrice;

   ObjectCreate(0, name, OBJ_ARROW, 0, sig.barTime, price);
   ObjectSetInteger(0, name, OBJPROP_ARROWCODE, arrowCode);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, AD_ARROW_SIZE);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, isBuy ? ANCHOR_TOP : ANCHOR_BOTTOM);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 400);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);

   string patternName = (sig.quality >= PATTERN_TBS) ? "TBS" : "TWS";
   ObjectSetString(0, name, OBJPROP_TOOLTIP,
       StringFormat("%s %s | Entry: %s | SL: %s | TP: %s",
                    patternName, isBuy ? "BUY" : "SELL",
                    DoubleToString(sig.entryPrice, _Digits),
                    DoubleToString(sig.slPrice, _Digits),
                    DoubleToString(sig.tpPrice, _Digits)));
}

//+------------------------------------------------------------------+
//| DrawSignalLabel — Text label "TRIGGER BUY [TBS]" at arrow pos    |
//+------------------------------------------------------------------+
void DrawSignalLabel(const EngineSignal &sig)
{
   if(!ShowSignalArrows) return;
   if(sig.direction == 0 || !sig.isNewSignal) return;

   bool isBuy = (sig.direction > 0);
   string name = StringFormat("AD_LBL_%s_%s",
                 isBuy ? "BUY" : "SELL",
                 TimeToString(sig.barTime, TIME_DATE|TIME_MINUTES));

   string patternName = (sig.quality >= PATTERN_TBS) ? "TBS" : "TWS";
   string text = StringFormat("TRIGGER %s [%s]", isBuy ? "BUY" : "SELL", patternName);
   color clr = GetSignalArrowColor(isBuy, sig.quality);

   // Place near arrow
   double atr = (sig.extraValues[0] > 0) ? sig.extraValues[0] * g_symbolPoint * 10 : 0;
   double offset = atr * (AD_ARROW_OFFSET + 0.5);
   double bandPrice = isBuy ? sig.lowerBand : sig.upperBand;
   if(bandPrice <= 0) bandPrice = sig.entryPrice;
   double price = isBuy ? (bandPrice - offset) : (bandPrice + offset);

   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_TEXT, 0, sig.barTime, price);

   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 7);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, isBuy ? ANCHOR_UPPER : ANCHOR_LOWER);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

//+------------------------------------------------------------------+
//| DrawEntryDot — Circle marker at band touch point                 |
//|  arrowCode 159 = filled circle                                   |
//+------------------------------------------------------------------+
void DrawEntryDot(const EngineSignal &sig)
{
   if(!ShowSignalArrows) return;
   if(sig.direction == 0 || !sig.isNewSignal) return;

   bool isBuy = (sig.direction > 0);
   double bandPrice = isBuy ? sig.lowerBand : sig.upperBand;
   if(bandPrice <= 0) return;

   string name = StringFormat("AD_DOT_%s_%s",
                 isBuy ? "BUY" : "SELL",
                 TimeToString(sig.barTime, TIME_DATE|TIME_MINUTES));

   color clr = isBuy ? AD_ENTRY_BUY_CLR : AD_ENTRY_SELL_CLR;

   ObjectCreate(0, name, OBJ_ARROW, 0, sig.barTime, bandPrice);
   ObjectSetInteger(0, name, OBJPROP_ARROWCODE, 159);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_CENTER);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);

   ObjectSetString(0, name, OBJPROP_TOOLTIP,
       StringFormat("Entry dot %s | Band: %s",
                    isBuy ? "BUY" : "SELL",
                    DoubleToString(bandPrice, _Digits)));
}

//+------------------------------------------------------------------+
//| DrawTriggerArrow — Cyan overlay arrow when order is placed        |
//|  Above signal arrows (z=600)                                     |
//+------------------------------------------------------------------+
void DrawTriggerArrow(int cycleID, double price, datetime barTime, bool isBuy)
{
   if(!ShowSignalArrows) return;

   string name = StringFormat("AD_TRIG_%s_%d_%s",
                 isBuy ? "BUY" : "SELL", cycleID,
                 TimeToString(barTime, TIME_DATE|TIME_MINUTES));

   int arrowCode = isBuy ? 233 : 234;

   ObjectCreate(0, name, OBJ_ARROW, 0, barTime, price);
   ObjectSetInteger(0, name, OBJPROP_ARROWCODE, arrowCode);
   ObjectSetInteger(0, name, OBJPROP_COLOR, AD_BIOLUM);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 3);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, isBuy ? ANCHOR_TOP : ANCHOR_BOTTOM);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 600);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);

   ObjectSetString(0, name, OBJPROP_TOOLTIP,
       StringFormat("TRIGGER #%d %s @ %s",
                    cycleID, isBuy ? "BUY STOP" : "SELL STOP",
                    DoubleToString(price, _Digits)));
}

//+------------------------------------------------------------------+
//| DrawSignalMarkers — Combined: arrow + dot + label               |
//+------------------------------------------------------------------+
void DrawSignalMarkers(const EngineSignal &sig)
{
   DrawSignalArrow(sig);
   DrawEntryDot(sig);
   DrawSignalLabel(sig);
}

//+------------------------------------------------------------------+
//| ScanHistoricalSignals — Backtest-style scan: draws arrows/labels |
//|  for all past signals within OverlayDepth bars.                  |
//|  Uses DPCComputeBands + DPCClassifySignal (same as indicator).   |
//+------------------------------------------------------------------+
void ScanHistoricalSignals()
{
   if(!ShowSignalArrows) return;

   int depth = MathMax(1, OverlayDepth);
   int totalBars = iBars(_Symbol, PERIOD_CURRENT);
   int dcLen = (g_dpc_dcLen > 0) ? g_dpc_dcLen : 20;
   if(totalBars < dcLen + 5)
   {
      AdLogW(LOG_CAT_UI, StringFormat("ScanHistoricalSignals: insufficient bars (%d < %d)", totalBars, dcLen + 5));
      return;
   }
   depth = MathMin(depth, totalBars - 2);

   // Cleanup old historical markers
   ObjectsDeleteAll(0, "AD_HSIG_");
   ObjectsDeleteAll(0, "AD_HDOT_");
   ObjectsDeleteAll(0, "AD_HLBL_");

   // Simple cooldown tracking: last signal bar index per direction
   int lastBuyBar  = -999;
   int lastSellBar = -999;
   int minSpacing  = MathMax(2, dcLen / 4);  // minimum bars between same-dir signals

   int signalCount = 0;
   for(int i = depth; i >= 1; i--)
   {
      if(i >= totalBars - dcLen) continue;  // need lookback

      double upper, lower, mid;
      DPCComputeBands(i, dcLen, upper, lower, mid);
      if(upper <= 0 || lower <= 0) continue;

      double high1  = iHigh(_Symbol, PERIOD_CURRENT, i);
      double low1   = iLow(_Symbol, PERIOD_CURRENT, i);
      double open1  = iOpen(_Symbol, PERIOD_CURRENT, i);
      double close1 = iClose(_Symbol, PERIOD_CURRENT, i);
      datetime barTime = iTime(_Symbol, PERIOD_CURRENT, i);

      bool bearBase = (high1 >= upper);
      bool bullBase = (low1 <= lower);

      // Anti-ambiguity
      if(bearBase && bullBase) continue;

      if(!bearBase && !bullBase) continue;

      int direction = bullBase ? +1 : -1;

      // Simple cooldown: skip if too close to last same-dir signal
      if(direction > 0 && lastBuyBar > 0 && (lastBuyBar - i) < minSpacing) continue;
      if(direction < 0 && lastSellBar > 0 && (lastSellBar - i) < minSpacing) continue;

      // Classify TBS/TWS
      int quality = DPCClassifySignal(direction, open1, close1, upper, lower);

      // Skip TWS if disabled
      if(!InpShowTWSSignals && quality == PATTERN_TWS) continue;

      // Update cooldown
      if(direction > 0) lastBuyBar = i;
      else              lastSellBar = i;

      // === DRAW HISTORICAL MARKERS ===
      bool isBuy = (direction > 0);
      color clr = GetSignalArrowColor(isBuy, quality);
      string patternName = (quality >= PATTERN_TBS) ? "TBS" : "TWS";
      string timeStr = TimeToString(barTime, TIME_DATE|TIME_MINUTES);
      double bandPrice = isBuy ? lower : upper;

      // ATR for offset
      double atr = DPCGetATR(i);
      double atrPrice = (atr > 0) ? atr : 0;
      double offset = atrPrice * AD_ARROW_OFFSET;

      // Arrow
      {
         string name = StringFormat("AD_HSIG_%s_%d_%s",
                       isBuy ? "BUY" : "SELL", quality, timeStr);
         int arrowCode = isBuy ? 233 : 234;
         double price = isBuy ? (bandPrice - offset) : (bandPrice + offset);
         if(price <= 0) price = bandPrice;

         ObjectCreate(0, name, OBJ_ARROW, 0, barTime, price);
         ObjectSetInteger(0, name, OBJPROP_ARROWCODE, arrowCode);
         ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
         ObjectSetInteger(0, name, OBJPROP_WIDTH, AD_ARROW_SIZE);
         ObjectSetInteger(0, name, OBJPROP_ANCHOR, isBuy ? ANCHOR_TOP : ANCHOR_BOTTOM);
         ObjectSetInteger(0, name, OBJPROP_BACK, false);
         ObjectSetInteger(0, name, OBJPROP_ZORDER, 400);
         ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
         ObjectSetString(0, name, OBJPROP_TOOLTIP,
             StringFormat("%s %s | Band: %s | Mid: %s",
                          patternName, isBuy ? "BUY" : "SELL",
                          DoubleToString(bandPrice, _Digits),
                          DoubleToString(mid, _Digits)));
      }

      // Entry dot at band
      {
         string name = StringFormat("AD_HDOT_%s_%s",
                       isBuy ? "BUY" : "SELL", timeStr);
         ObjectCreate(0, name, OBJ_ARROW, 0, barTime, bandPrice);
         ObjectSetInteger(0, name, OBJPROP_ARROWCODE, 159);
         ObjectSetInteger(0, name, OBJPROP_COLOR, isBuy ? AD_ENTRY_BUY_CLR : AD_ENTRY_SELL_CLR);
         ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_CENTER);
         ObjectSetInteger(0, name, OBJPROP_BACK, false);
         ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
      }

      // Text label "TRIGGER BUY [TBS]"
      {
         string name = StringFormat("AD_HLBL_%s_%s",
                       isBuy ? "BUY" : "SELL", timeStr);
         string text = StringFormat("TRIGGER %s [%s]", isBuy ? "BUY" : "SELL", patternName);
         double labelOffset = atrPrice * (AD_ARROW_OFFSET + 0.5);
         double price = isBuy ? (bandPrice - labelOffset) : (bandPrice + labelOffset);

         ObjectCreate(0, name, OBJ_TEXT, 0, barTime, price);
         ObjectSetString(0, name, OBJPROP_TEXT, text);
         ObjectSetString(0, name, OBJPROP_FONT, "Arial");
         ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 7);
         ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
         ObjectSetInteger(0, name, OBJPROP_ANCHOR, isBuy ? ANCHOR_UPPER : ANCHOR_LOWER);
         ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      }

      signalCount++;
   }

   AdLogI(LOG_CAT_UI, StringFormat("ScanHistoricalSignals: depth=%d, found=%d signals", depth, signalCount));
}

//+------------------------------------------------------------------+
//| CleanupSignalMarkers — Remove all signal marker objects          |
//+------------------------------------------------------------------+
void CleanupSignalMarkers()
{
   ObjectsDeleteAll(0, "AD_SIG_");
   ObjectsDeleteAll(0, "AD_DOT_");
   ObjectsDeleteAll(0, "AD_LBL_");
   ObjectsDeleteAll(0, "AD_TRIG_");
   ObjectsDeleteAll(0, "AD_HSIG_");
   ObjectsDeleteAll(0, "AD_HDOT_");
   ObjectsDeleteAll(0, "AD_HLBL_");
}
