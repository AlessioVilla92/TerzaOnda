//+------------------------------------------------------------------+
//|                                       3ondKPCCooldown.mqh          |
//|           TerzaOnda EA — KPC SimpleCooldown                      |
//|                                                                  |
//|  SimpleCooldown: N barre stesso verso, M barre verso opposto.    |
//|  No midline touch gate (removed in KPC v1.03).                   |
//|  Fire block integrato quando g_kpcFireActive = true.              |
//+------------------------------------------------------------------+
#property copyright "TerzaOnda (C) 2026"

//+------------------------------------------------------------------+
//| SimpleCooldown state                                             |
//+------------------------------------------------------------------+
int    g_kpcCDLastDirection    = 0;   // +1=BUY, -1=SELL, 0=none
int    g_kpcCDLastSignalBarIdx = 0;   // Bar index of last signal

//+------------------------------------------------------------------+
//| KPCResetCooldown — Full reset                                    |
//+------------------------------------------------------------------+
void KPCResetCooldown()
{
   g_kpcCDLastDirection    = 0;
   g_kpcCDLastSignalBarIdx = 0;
}

//+------------------------------------------------------------------+
//| KPCCheckCooldown_Sell — Can we emit a SELL signal?               |
//+------------------------------------------------------------------+
bool KPCCheckCooldown_Sell(int currentBarIdx)
{
   // Fire block
   if(g_kpcFireActive) return false;

   // First signal ever: no cooldown
   if(g_kpcCDLastDirection == 0) return true;

   int barsFromLast = currentBarIdx - g_kpcCDLastSignalBarIdx;

   if(g_kpcCDLastDirection == -1)
      return (barsFromLast >= g_kpc_nSameBars_eff);     // SELL->SELL: same direction
   else
      return (barsFromLast >= g_kpc_nOppositeBars_eff);  // BUY->SELL: opposite direction
}

//+------------------------------------------------------------------+
//| KPCCheckCooldown_Buy — Can we emit a BUY signal?                 |
//+------------------------------------------------------------------+
bool KPCCheckCooldown_Buy(int currentBarIdx)
{
   // Fire block
   if(g_kpcFireActive) return false;

   // First signal ever: no cooldown
   if(g_kpcCDLastDirection == 0) return true;

   int barsFromLast = currentBarIdx - g_kpcCDLastSignalBarIdx;

   if(g_kpcCDLastDirection == +1)
      return (barsFromLast >= g_kpc_nSameBars_eff);     // BUY->BUY: same direction
   else
      return (barsFromLast >= g_kpc_nOppositeBars_eff);  // SELL->BUY: opposite direction
}

//+------------------------------------------------------------------+
//| KPCUpdateCooldownState — Record signal emission                  |
//+------------------------------------------------------------------+
void KPCUpdateCooldownState(int direction, int currentBarIdx)
{
   g_kpcCDLastDirection    = direction;
   g_kpcCDLastSignalBarIdx = currentBarIdx;
}
