//+------------------------------------------------------------------+
//|                                        adDPCCooldown.mqh         |
//|           AcquaDulza EA v1.5.0 — DPC SmartCooldown               |
//|                                                                  |
//|  SmartCooldown state machine:                                    |
//|    - First signal: always accepted                               |
//|    - Same direction: requires midline touch + N bars             |
//|    - Opposite direction: only minimum bars                       |
//+------------------------------------------------------------------+
#property copyright "AcquaDulza (C) 2026"

//+------------------------------------------------------------------+
//| SmartCooldown State Variables (DPC Engine scoped)                |
//+------------------------------------------------------------------+
int      g_dpcLastSignalBarIdx   = 0;
int      g_dpcLastDirection_cd   = 0;      // +1=BUY, -1=SELL, 0=none
bool     g_dpcMidlineTouched_cd  = false;
int      g_dpcMidlineTouchBarIdx = 0;
bool     g_dpcWaitingForMidTouch = false;

//+------------------------------------------------------------------+
//| DPCResetCooldown — Reset all cooldown state                      |
//+------------------------------------------------------------------+
void DPCResetCooldown()
{
   g_dpcLastSignalBarIdx   = 0;
   g_dpcLastDirection_cd   = 0;
   g_dpcMidlineTouched_cd  = false;
   g_dpcMidlineTouchBarIdx = 0;
   g_dpcWaitingForMidTouch = false;
}

//+------------------------------------------------------------------+
//| DPCCheckSmartCooldown_Sell — Cooldown check for SELL signals     |
//|  SmartCooldown OFF: fixed cooldown of dcLen bars                 |
//|  SmartCooldown ON:                                               |
//|    - First signal: always accepted                               |
//|    - Same dir (SELL after SELL): midline touch + N bars          |
//|    - Opposite (SELL after BUY): only N bars minimum              |
//+------------------------------------------------------------------+
bool DPCCheckSmartCooldown_Sell(int currentBarIdx)
{
   int barsFromLast = currentBarIdx - g_dpcLastSignalBarIdx;

   if(!InpUseSmartCooldown)
      return (barsFromLast >= g_dpc_dcLen);

   // First signal always accepted
   if(g_dpcLastDirection_cd == 0)
      return true;

   if(g_dpcLastDirection_cd == -1)
   {
      // Same direction (SELL after SELL): require midline touch + N bars
      if(InpRequireMidTouch)
         return g_dpcMidlineTouched_cd &&
                (currentBarIdx - g_dpcMidlineTouchBarIdx >= g_dpc_nSame);
      else
         return (barsFromLast >= g_dpc_nSame);
   }
   else
   {
      // Opposite direction (SELL after BUY): only minimum bars
      return (barsFromLast >= g_dpc_nOpp);
   }
}

//+------------------------------------------------------------------+
//| DPCCheckSmartCooldown_Buy — Cooldown check for BUY signals      |
//|  Mirror logic of Sell                                            |
//+------------------------------------------------------------------+
bool DPCCheckSmartCooldown_Buy(int currentBarIdx)
{
   int barsFromLast = currentBarIdx - g_dpcLastSignalBarIdx;

   if(!InpUseSmartCooldown)
      return (barsFromLast >= g_dpc_dcLen);

   if(g_dpcLastDirection_cd == 0)
      return true;

   if(g_dpcLastDirection_cd == +1)
   {
      // Same direction (BUY after BUY)
      if(InpRequireMidTouch)
         return g_dpcMidlineTouched_cd &&
                (currentBarIdx - g_dpcMidlineTouchBarIdx >= g_dpc_nSame);
      else
         return (barsFromLast >= g_dpc_nSame);
   }
   else
   {
      // Opposite direction (BUY after SELL)
      return (barsFromLast >= g_dpc_nOpp);
   }
}

//+------------------------------------------------------------------+
//| DPCUpdateCooldownState — Update after confirmed signal           |
//|  Save bar index and direction, reset midline touch flag          |
//+------------------------------------------------------------------+
void DPCUpdateCooldownState(int direction, int currentBarIdx)
{
   g_dpcLastSignalBarIdx   = currentBarIdx;
   g_dpcLastDirection_cd   = direction;
   g_dpcMidlineTouched_cd  = false;
   g_dpcMidlineTouchBarIdx = 0;
   g_dpcWaitingForMidTouch = true;
}

//+------------------------------------------------------------------+
//| DPCCheckMidlineTouch — Detect midline touch (SmartCooldown)     |
//|  After BUY signal: wait for high to reach midline               |
//|  After SELL signal: wait for low to reach midline               |
//|  Midline touch unlocks new signals in same direction            |
//+------------------------------------------------------------------+
void DPCCheckMidlineTouch(int barShift, int currentBarIdx, double midline)
{
   if(!g_dpcWaitingForMidTouch || g_dpcLastDirection_cd == 0)
      return;

   double high1 = iHigh(_Symbol, PERIOD_CURRENT, barShift);
   double low1  = iLow(_Symbol, PERIOD_CURRENT, barShift);

   bool midlineCrossed = false;
   if(g_dpcLastDirection_cd == +1 && high1 >= midline)
      midlineCrossed = true;
   else if(g_dpcLastDirection_cd == -1 && low1 <= midline)
      midlineCrossed = true;

   if(midlineCrossed)
   {
      if(InpUseSmartCooldown)
      {
         g_dpcMidlineTouched_cd  = true;
         g_dpcMidlineTouchBarIdx = currentBarIdx;
      }
      g_dpcWaitingForMidTouch = false;
   }
}
