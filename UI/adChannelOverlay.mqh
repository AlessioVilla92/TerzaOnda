//+------------------------------------------------------------------+
//|                                      adChannelOverlay.mqh        |
//|           AcquaDulza EA v1.0.0 — Channel Overlay                 |
//|                                                                  |
//|  Replica esatta dell'indicatore DonchianPredictiveChannel.mq5    |
//|  Upper/Lower bands (blue) + Fill trasparente (CCanvas)           |
//|  Midline 3 colori (lime/red/cyan) + MA line (teal)               |
//|  NOTE: Calls DPC functions directly for historical bars.         |
//+------------------------------------------------------------------+
#property copyright "AcquaDulza (C) 2026"

#include <Canvas/Canvas.mqh>

CCanvas g_canvasFill;
string  g_canvasName = "AD_OVL_CANVAS";
bool    g_canvasCreated = false;

//+------------------------------------------------------------------+
//| DrawChannelOverlay — Full overlay: bands + fill + midline + MA   |
//+------------------------------------------------------------------+
void DrawChannelOverlay()
{
   if(!ShowChannelOverlay) return;

   int depth = MathMax(1, OverlayDepth);
   int totalBars = iBars(_Symbol, PERIOD_CURRENT);
   if(totalBars < depth + 2) return;

   int dcLen = (g_dpc_dcLen > 0) ? g_dpc_dcLen : 20;

   // Arrays for band data (used by fill)
   double arrU[], arrL[], arrM[], arrMA[];
   datetime arrT[];
   ArrayResize(arrU, depth + 1);
   ArrayResize(arrL, depth + 1);
   ArrayResize(arrM, depth + 1);
   ArrayResize(arrMA, depth + 1);
   ArrayResize(arrT, depth + 1);

   // Compute bands for all bars
   for(int i = 0; i <= depth && i < totalBars; i++)
   {
      int barIdx = i + 1;  // bar[1] to bar[depth+1]
      arrT[i] = iTime(_Symbol, PERIOD_CURRENT, barIdx);
      DPCComputeBands(barIdx, dcLen, arrU[i], arrL[i], arrM[i]);
      arrMA[i] = DPCGetMAValue(barIdx);
   }

   // === DRAW BAND LINES + MIDLINE + MA ===
   for(int i = 0; i < depth && i < totalBars - 1; i++)
   {
      if(arrU[i] <= 0 || arrL[i] <= 0) continue;

      datetime t1 = arrT[i];
      datetime t2 = arrT[i + 1];
      string prefix = StringFormat("AD_OVL_%d_", i);

      // Upper band (blue)
      DrawOverlayLine(prefix + "U", t2, arrU[i + 1], t1, arrU[i],
                      AD_CHAN_UPPER_CLR, AD_CHAN_STYLE, AD_CHAN_WIDTH);

      // Lower band (blue)
      DrawOverlayLine(prefix + "L", t2, arrL[i + 1], t1, arrL[i],
                      AD_CHAN_LOWER_CLR, AD_CHAN_STYLE, AD_CHAN_WIDTH);

      // Midline (3 colors: lime/red/cyan)
      int midState = DPCGetMidlineColor(i + 1);
      color midClr = AD_CHAN_MID_FLAT_CLR;
      if(midState == 0) midClr = AD_CHAN_MID_UP_CLR;
      else if(midState == 1) midClr = AD_CHAN_MID_DN_CLR;
      DrawOverlayLine(prefix + "M", t2, arrM[i + 1], t1, arrM[i],
                      midClr, AD_CHAN_MID_STYLE, AD_CHAN_WIDTH);

      // MA line (teal, width 2)
      if(arrMA[i] > 0 && arrMA[i + 1] > 0)
      {
         DrawOverlayLine(prefix + "A", t2, arrMA[i + 1], t1, arrMA[i],
                         AD_CHAN_MA_CLR, STYLE_SOLID, 2);
      }
   }

   // === DRAW CANVAS FILL ===
   DrawBandFill(arrU, arrL, arrT, depth);
}

//+------------------------------------------------------------------+
//| DrawBandFill — CCanvas transparent fill between bands            |
//+------------------------------------------------------------------+
void DrawBandFill(double &upper[], double &lower[], datetime &times[],
                  int count)
{
   int chartW = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   int chartH = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
   if(chartW < 10 || chartH < 10) return;

   // Recreate canvas if size changed
   if(g_canvasCreated)
   {
      int oldW = (int)ObjectGetInteger(0, g_canvasName, OBJPROP_XSIZE);
      int oldH = (int)ObjectGetInteger(0, g_canvasName, OBJPROP_YSIZE);
      if(oldW != chartW || oldH != chartH)
      {
         g_canvasFill.Destroy();
         g_canvasCreated = false;
      }
   }

   if(!g_canvasCreated)
   {
      if(!g_canvasFill.CreateBitmapLabel(0, 0, g_canvasName, 0, 0, chartW, chartH, COLOR_FORMAT_ARGB_NORMALIZE))
         return;
      ObjectSetInteger(0, g_canvasName, OBJPROP_BACK, true);
      ObjectSetInteger(0, g_canvasName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, g_canvasName, OBJPROP_HIDDEN, true);
      g_canvasCreated = true;
   }

   // Clear canvas (fully transparent)
   g_canvasFill.Erase(0x00000000);

   // Fill color with alpha (ColorToARGB handles BGR→ARGB conversion)
   uint fillARGB = ColorToARGB(AD_CHAN_FILL_CLR, AD_CHAN_FILL_ALPHA);

   // Draw filled quads between each bar pair
   for(int i = 0; i < count - 1; i++)
   {
      if(upper[i] <= 0 || lower[i] <= 0) continue;
      if(upper[i + 1] <= 0 || lower[i + 1] <= 0) continue;

      int x1, y1U, y1L, x2, y2U, y2L;
      ChartTimePriceToXY(0, 0, times[i], upper[i], x1, y1U);
      ChartTimePriceToXY(0, 0, times[i], lower[i], x1, y1L);
      ChartTimePriceToXY(0, 0, times[i + 1], upper[i + 1], x2, y2U);
      ChartTimePriceToXY(0, 0, times[i + 1], lower[i + 1], x2, y2L);

      // Skip if off-screen
      if(x1 < -50 || x1 > chartW + 50) continue;
      if(x2 < -50 || x2 > chartW + 50) continue;

      // Fill quad as two triangles
      g_canvasFill.FillTriangle(x1, y1U, x2, y2U, x1, y1L, fillARGB);
      g_canvasFill.FillTriangle(x2, y2U, x2, y2L, x1, y1L, fillARGB);
   }

   g_canvasFill.Update(false);
}

//+------------------------------------------------------------------+
//| RedrawFill — Redraw canvas on chart scroll/zoom                  |
//+------------------------------------------------------------------+
void RedrawOverlayFill()
{
   if(!ShowChannelOverlay || !g_canvasCreated) return;

   int depth = MathMax(1, OverlayDepth);
   int totalBars = iBars(_Symbol, PERIOD_CURRENT);
   if(totalBars < depth + 2) return;

   int dcLen = (g_dpc_dcLen > 0) ? g_dpc_dcLen : 20;

   double arrU[], arrL[];
   datetime arrT[];
   ArrayResize(arrU, depth + 1);
   ArrayResize(arrL, depth + 1);
   ArrayResize(arrT, depth + 1);

   for(int i = 0; i <= depth && i < totalBars; i++)
   {
      int barIdx = i + 1;
      arrT[i] = iTime(_Symbol, PERIOD_CURRENT, barIdx);
      double m;
      DPCComputeBands(barIdx, dcLen, arrU[i], arrL[i], m);
   }

   DrawBandFill(arrU, arrL, arrT, depth);
}

//+------------------------------------------------------------------+
//| DrawOverlayLine — Create/update a trend line segment             |
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
//| DrawTPLine — TP target dot + dashed line                         |
//+------------------------------------------------------------------+
void DrawTPLine(int cycleID, double tpPrice, bool isBuy)
{
   if(!ShowTPTargetLines) return;

   // TP horizontal line
   string lineName = StringFormat("AD_TP_LINE_%d", cycleID);
   color tpClr = isBuy ? AD_TP_DOT_BUY : AD_TP_DOT_SELL;
   CreateHLine(lineName, tpPrice, tpClr, AD_TP_LINE_WIDTH, STYLE_DASH);
   ObjectSetString(0, lineName, OBJPROP_TOOLTIP,
       StringFormat("TP #%d %s @ %s", cycleID, isBuy ? "BUY" : "SELL",
                    DoubleToString(tpPrice, _Digits)));
}

//+------------------------------------------------------------------+
//| DrawTPDot — Circle dot at TP price level                         |
//+------------------------------------------------------------------+
void DrawTPDot(int cycleID, double tpPrice, datetime signalTime, bool isBuy)
{
   if(!ShowTPTargetLines) return;

   string name = StringFormat("AD_TP_DOT_%d", cycleID);
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_ARROW, 0, signalTime, tpPrice);

   ObjectSetInteger(0, name, OBJPROP_ARROWCODE, 159);  // ●
   ObjectSetInteger(0, name, OBJPROP_COLOR, isBuy ? AD_TP_DOT_BUY : AD_TP_DOT_SELL);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
}

//+------------------------------------------------------------------+
//| DrawTPHitMarker — Star marker when TP is reached                 |
//+------------------------------------------------------------------+
void DrawTPHitMarker(int cycleID, double tpPrice, datetime hitTime)
{
   string name = StringFormat("AD_TP_HIT_%d", cycleID);
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_ARROW, 0, hitTime, tpPrice);

   ObjectSetInteger(0, name, OBJPROP_ARROWCODE, 169);  // ★
   ObjectSetInteger(0, name, OBJPROP_COLOR, AD_TP_HIT_CLR);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 3);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

//+------------------------------------------------------------------+
//| DrawTriggerVLine — Yellow VLine on trigger candle                 |
//+------------------------------------------------------------------+
void DrawTriggerVLine(datetime barTime, bool isBuy)
{
   string name = StringFormat("AD_TRIG_VL_%d", (int)barTime);
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_VLINE, 0, barTime, 0);

   ObjectSetInteger(0, name, OBJPROP_COLOR, AD_TRIGGER_CLR);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DOT);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetString(0, name, OBJPROP_TOOLTIP,
      StringFormat("TRIGGER %s", isBuy ? "BUY" : "SELL"));
}

//+------------------------------------------------------------------+
//| RemoveTPLine — Remove TP line + dot on cycle close               |
//+------------------------------------------------------------------+
void RemoveTPLine(int cycleID)
{
   string lineName = StringFormat("AD_TP_LINE_%d", cycleID);
   if(ObjectFind(0, lineName) >= 0) ObjectDelete(0, lineName);

   string dotName = StringFormat("AD_TP_DOT_%d", cycleID);
   if(ObjectFind(0, dotName) >= 0) ObjectDelete(0, dotName);
}

//+------------------------------------------------------------------+
//| CleanupOverlay — Remove all overlay objects + canvas             |
//+------------------------------------------------------------------+
void CleanupOverlay()
{
   ObjectsDeleteAll(0, "AD_OVL_");
   ObjectsDeleteAll(0, "AD_TP_");
   ObjectsDeleteAll(0, "AD_TRIG_VL_");
   if(g_canvasCreated)
   {
      g_canvasFill.Destroy();
      g_canvasCreated = false;
   }
}
