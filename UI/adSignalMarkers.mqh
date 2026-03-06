//+------------------------------------------------------------------+
//|                                       adSignalMarkers.mqh        |
//|           AcquaDulza EA v1.0.0 — Signal Markers                  |
//|                                                                  |
//|  Replica indicatore DonchianPredictiveChannel.mq5:               |
//|  TBS arrows (bright lime/red) + TWS arrows (dark green/red)      |
//|  ATR offset, signal text labels, trigger VLine                   |
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
//| DrawSignalMarkers — Combined: arrow + dot + label + trigger VL   |
//+------------------------------------------------------------------+
void DrawSignalMarkers(const EngineSignal &sig)
{
   DrawSignalArrow(sig);
   DrawEntryDot(sig);
   DrawSignalLabel(sig);

   // Trigger candle VLine (yellow dotted behind candles)
   if(sig.direction != 0 && sig.isNewSignal)
      DrawTriggerVLine(sig.barTime, sig.direction > 0);
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
}
