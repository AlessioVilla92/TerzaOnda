//+------------------------------------------------------------------+
//|                                         adRiskManager.mqh        |
//|           AcquaDulza EA v1.1.0 — Risk Manager                    |
//|                                                                  |
//|  3 lot sizing modes: FIXED_LOT, RISK_PCT, FIXED_CASH            |
//|  Circuit breaker, daily loss limit, spread check                 |
//|  Drawdown tracking, margin validation                            |
//+------------------------------------------------------------------+
#property copyright "AcquaDulza (C) 2026"

//+------------------------------------------------------------------+
//| Throttling Variables                                             |
//+------------------------------------------------------------------+
datetime g_lastMarginWarning      = 0;
datetime g_lastMarginLevelWarning = 0;
int      g_warningThrottleSec     = 300;  // 5 minutes

//+------------------------------------------------------------------+
//| InitializeRiskManager                                            |
//+------------------------------------------------------------------+
bool InitializeRiskManager()
{
   g_startingEquity  = GetEquity();
   g_startingBalance = GetBalance();
   g_maxEquity       = g_startingEquity;
   g_maxDrawdownPct  = 0;

   AdLogI(LOG_CAT_RISK, StringFormat("Risk Manager initialized | Equity=%s | Mode=%s",
          FormatMoney(g_startingEquity), EnumToString(RiskMode)));
   Log_InitComplete("Risk Manager");
   return true;
}

//+------------------------------------------------------------------+
//| CalculateLotSize — 3 modes: FIXED_LOT, RISK_PCT, FIXED_CASH    |
//|  slDistancePrice: SL distance in price units (not pips)          |
//|  Returns: normalized lot size                                    |
//+------------------------------------------------------------------+
double CalculateLotSize(double slDistancePrice)
{
   double lots = LotSize;  // Default: fixed lot

   if(RiskMode == RISK_PERCENT && slDistancePrice > 0)
   {
      // Risk % of equity
      double equity   = GetEquity();
      double riskAmt  = equity * (RiskPercent / 100.0);
      double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

      if(tickValue > 0 && tickSize > 0)
         lots = (riskAmt * tickSize) / (slDistancePrice * tickValue);
      else
         AdLogW(LOG_CAT_RISK, StringFormat("CalculateLotSize: invalid tick data (tickVal=%.5f tickSize=%.5f) — using fixed lot %.2f",
            tickValue, tickSize, lots));
   }
   else if(RiskMode == RISK_FIXED_CASH && slDistancePrice > 0)
   {
      // Fixed cash per trade
      double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

      if(tickValue > 0 && tickSize > 0)
         lots = (RiskCashPerTrade * tickSize) / (slDistancePrice * tickValue);
      else
         AdLogW(LOG_CAT_RISK, StringFormat("CalculateLotSize: invalid tick data (tickVal=%.5f tickSize=%.5f) — using fixed lot %.2f",
            tickValue, tickSize, lots));
   }
   // RISK_FIXED_LOT: use LotSize directly

   double finalLot = NormalizeLotSize(lots);
   AdLogI(LOG_CAT_RISK, StringFormat("LotSize: mode=%s raw=%.4f final=%.4f slDist=%.5f",
      EnumToString(RiskMode), lots, finalLot, slDistancePrice));
   return finalLot;
}

//+------------------------------------------------------------------+
//| PerformRiskChecks — All pre-trade risk checks                   |
//|  Returns: true if trading is allowed                             |
//+------------------------------------------------------------------+
bool PerformRiskChecks()
{
   // 1. Margin check
   if(!HasSufficientMargin())
   {
      AdLogW(LOG_CAT_RISK, StringFormat("BLOCKED — Margin insufficient | Free=%s | Level=%s%%",
             FormatMoney(GetFreeMargin()), FormatPercent(GetMarginLevel())));
      return false;
   }

   // 2. Daily loss limit
   if(DailyLossLimitPct > 0)
   {
      double dailyLossPct = 0;
      if(g_startingEquity > 0)
         dailyLossPct = (g_dailyRealizedProfit / g_startingEquity) * 100.0;

      if(dailyLossPct < -DailyLossLimitPct)
      {
         AdLogW(LOG_CAT_RISK, StringFormat("DAILY LOSS LIMIT HIT — Loss=%.2f%% | Limit=%.2f%%",
                MathAbs(dailyLossPct), DailyLossLimitPct));
         return false;
      }
   }

   // 3. Spread check (usa g_inst_maxSpread, scalato per classe strumento)
   double currentSpread = GetSpreadPips();
   if(currentSpread > g_inst_maxSpread)
   {
      AdLogI(LOG_CAT_RISK, StringFormat("SPREAD BLOCKED — %.1fp > MAX %.1fp", currentSpread, g_inst_maxSpread));
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| HasSufficientMargin — Check free margin + margin level          |
//+------------------------------------------------------------------+
bool HasSufficientMargin()
{
   double freeMargin = GetFreeMargin();
   double marginLevel = GetMarginLevel();

   // Dynamic: min 1% of equity, at least $50
   double minMargin = MathMax(50.0, GetEquity() * 0.01);

   if(freeMargin < minMargin)
   {
      if(TimeCurrent() - g_lastMarginWarning >= g_warningThrottleSec)
      {
         AdLogW(LOG_CAT_RISK, StringFormat("Free margin low: %s (min: %s)",
                FormatMoney(freeMargin), FormatMoney(minMargin)));
         g_lastMarginWarning = TimeCurrent();
      }
      return false;
   }

   if(marginLevel > 0 && marginLevel < 200)
   {
      if(TimeCurrent() - g_lastMarginLevelWarning >= g_warningThrottleSec)
      {
         AdLogW(LOG_CAT_RISK, StringFormat("Margin level low: %s%%", FormatPercent(marginLevel)));
         g_lastMarginLevelWarning = TimeCurrent();
      }
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| CalculateMarginRequired — Margin for a potential order          |
//+------------------------------------------------------------------+
double CalculateMarginRequired(double lots, ENUM_ORDER_TYPE orderType)
{
   double margin = 0;
   if(!OrderCalcMargin(orderType, _Symbol, lots, SymbolInfoDouble(_Symbol, SYMBOL_ASK), margin))
   {
      AdLogE(LOG_CAT_RISK, StringFormat("OrderCalcMargin failed: lots=%.4f type=%s err=%d",
         lots, EnumToString(orderType), GetLastError()));
      return -1;
   }
   return margin;
}

//+------------------------------------------------------------------+
//| UpdateEquityTracking — Track high water mark + max drawdown     |
//+------------------------------------------------------------------+
void UpdateEquityTracking()
{
   double equity = GetEquity();

   if(equity > g_maxEquity)
      g_maxEquity = equity;

   double ddFromPeak = 0;
   if(g_maxEquity > 0)
      ddFromPeak = ((g_maxEquity - equity) / g_maxEquity) * 100.0;

   if(ddFromPeak > g_maxDrawdownPct)
      g_maxDrawdownPct = ddFromPeak;
}

//+------------------------------------------------------------------+
//| GetDrawdownFromPeak — Current drawdown from peak equity         |
//+------------------------------------------------------------------+
double GetDrawdownFromPeak()
{
   double equity = GetEquity();
   if(g_maxEquity <= 0 || equity >= g_maxEquity) return 0;
   return ((g_maxEquity - equity) / g_maxEquity) * 100.0;
}

