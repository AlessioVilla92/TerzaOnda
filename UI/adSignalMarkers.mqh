//+------------------------------------------------------------------+
//|                                       adSignalMarkers.mqh        |
//|           AcquaDulza EA v1.0.0 — Signal Markers                  |
//|                                                                  |
//|  Draws signal arrows (TBS/TWS), entry dots on chart.             |
//|  TBS = green (AD_BUY), TWS = amber (AD_AMBER).                  |
//|  Engine-agnostic: reads EngineSignal only.                       |
//+------------------------------------------------------------------+
#property copyright "AcquaDulza (C) 2026"

//+------------------------------------------------------------------+
//| DrawSignalArrow — Signal arrow (TBS green / TWS amber)           |
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

   // TBS (quality >= 3) = green, TWS (quality < 3) = amber
   color clr = (sig.quality >= PATTERN_TBS) ? AD_BUY : AD_AMBER;

   double price = isBuy ? sig.lowerBand : sig.upperBand;
   if(price <= 0) price = sig.entryPrice;

   ObjectCreate(0, name, OBJ_ARROW, 0, sig.barTime, price);
   ObjectSetInteger(0, name, OBJPROP_ARROWCODE, arrowCode);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
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

   color clr = isBuy ? AD_BUY : AD_SELL;

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
//| DrawTriggerArrow — Trigger placement arrow (yellow overlay)      |
//|  Drawn when order is placed, above signal arrows (z=600)         |
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
//| DrawSignalMarkers — Combined: arrow + entry dot                  |
//+------------------------------------------------------------------+
void DrawSignalMarkers(const EngineSignal &sig)
{
   DrawSignalArrow(sig);
   DrawEntryDot(sig);
}

//+------------------------------------------------------------------+
//| CleanupSignalMarkers — Remove all signal marker objects          |
//+------------------------------------------------------------------+
void CleanupSignalMarkers()
{
   ObjectsDeleteAll(0, "AD_SIG_");
   ObjectsDeleteAll(0, "AD_DOT_");
   ObjectsDeleteAll(0, "AD_TRIG_");
}
