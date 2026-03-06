//+------------------------------------------------------------------+
//|                                      adChannelOverlay.mqh        |
//|           AcquaDulza EA v1.0.0 — Channel Overlay                 |
//|                                                                  |
//|  Draws Donchian channel bands on chart.                          |
//|  Upper/Mid/Lower lines with Ocean colors.                        |
//|  NOTE: Calls DPCComputeBands()/DPCGetMidlineColor() directly     |
//|  for historical bar rendering. This is an engine coupling that   |
//|  would need an overlay interface to fully decouple.              |
//+------------------------------------------------------------------+
#property copyright "AcquaDulza (C) 2026"

//+------------------------------------------------------------------+
//| DrawChannelOverlay — Draw/update channel lines for bar range    |
//+------------------------------------------------------------------+
void DrawChannelOverlay(const EngineSignal &sig)
{
   if(!ShowChannelOverlay) return;
   if(sig.upperBand <= 0 || sig.lowerBand <= 0) return;

   int depth = MathMax(1, OverlayDepth);
   int totalBars = iBars(_Symbol, PERIOD_CURRENT);
   if(totalBars < depth + 2) return;

   // Draw lines for visible bars
   for(int i = 1; i <= depth && i < totalBars; i++)
   {
      datetime t1 = iTime(_Symbol, PERIOD_CURRENT, i);
      datetime t2 = iTime(_Symbol, PERIOD_CURRENT, MathMax(0, i - 1));

      // Compute bands for this bar (engine-coupled: calls DPCComputeBands directly)
      double u, l, m;
      int dcLen = (g_lastSignal.extraValues[5] > 0) ? (int)g_lastSignal.extraValues[5] : 20;
      DPCComputeBands(i, dcLen, u, l, m);
      if(u <= 0 || l <= 0) continue;

      string prefix = StringFormat("AD_OVL_%d_", i);

      // Upper line
      DrawOverlayLine(prefix + "U", t1, u, t2, u, AD_SELL, STYLE_SOLID, 1);
      // Lower line
      DrawOverlayLine(prefix + "L", t1, l, t2, l, AD_BUY, STYLE_SOLID, 1);
      // Midline
      int midColor = DPCGetMidlineColor(i);
      color midClr = (midColor == 0) ? AD_BUY : AD_SELL;
      DrawOverlayLine(prefix + "M", t1, m, t2, m, midClr, STYLE_DOT, 1);
   }
}

//+------------------------------------------------------------------+
//| DrawOverlayLine — Create/update a trend line segment            |
//+------------------------------------------------------------------+
void DrawOverlayLine(string name, datetime t1, double p1, datetime t2, double p2,
                     color clr, ENUM_LINE_STYLE style, int width)
{
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_TREND, 0, t1, p1, t2, p2);
      ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, name, OBJPROP_BACK, true);
   }

   ObjectSetInteger(0, name, OBJPROP_TIME, 0, t1);
   ObjectSetDouble(0, name, OBJPROP_PRICE, 0, p1);
   ObjectSetInteger(0, name, OBJPROP_TIME, 1, t2);
   ObjectSetDouble(0, name, OBJPROP_PRICE, 1, p2);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, style);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
}

//+------------------------------------------------------------------+
//| CleanupOverlay — Remove all overlay objects                     |
//+------------------------------------------------------------------+
void CleanupOverlay()
{
   ObjectsDeleteAll(0, "AD_OVL_");
}

//+------------------------------------------------------------------+
//| DrawTPLine — Horizontal dashed TP line for active cycle         |
//+------------------------------------------------------------------+
void DrawTPLine(int cycleID, double tpPrice, bool isBuy)
{
   if(!ShowTPTargetLines) return;
   string name = StringFormat("AD_TP_LINE_%d", cycleID);
   CreateHLine(name, tpPrice, AD_BIOLUM, 1, STYLE_DASH);
   ObjectSetString(0, name, OBJPROP_TOOLTIP,
       StringFormat("TP #%d %s @ %s", cycleID, isBuy ? "BUY" : "SELL",
                    DoubleToString(tpPrice, _Digits)));
}

//+------------------------------------------------------------------+
//| RemoveTPLine — Remove TP line on cycle close                    |
//+------------------------------------------------------------------+
void RemoveTPLine(int cycleID)
{
   string name = StringFormat("AD_TP_LINE_%d", cycleID);
   if(ObjectFind(0, name) >= 0)
      ObjectDelete(0, name);
}
