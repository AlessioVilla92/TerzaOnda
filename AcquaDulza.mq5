//+------------------------------------------------------------------+
//|                                            AcquaDulza.mq5        |
//|  "L'acqua dolce che scorre tra le bande."                        |
//+------------------------------------------------------------------+
//|  Copyright (C) 2026 - AcquaDulza Development                    |
//|  Version: 1.3.0                                                  |
//|  Engine: DPC (Donchian Predictive Channel) — swappable           |
//+------------------------------------------------------------------+
//|                                                                  |
//|  AcquaDulza EA — Framework di trading modulare a 7 livelli       |
//|                                                                  |
//|  ARCHITETTURA:                                                   |
//|    Layer 0: Config    — Enums, parametri input, interfaccia eng.  |
//|    Layer 1: Core      — Variabili globali, helpers, sessioni      |
//|    Layer 2: Engine    — DPC (Donchian Predictive Channel)         |
//|             ↳ Bande Donchian + 7 filtri qualita' + SmartCooldown  |
//|             ↳ Classificazione TBS/TWS (qualita' segnale)          |
//|             ↳ LTF Entry (conferma su timeframe inferiore)         |
//|             ↳ Auto TF Preset (parametri adattivi per TF)          |
//|    Layer 3: Orders    — Risk manager, lot sizing, order placement |
//|             ↳ 3 risk modes (Fixed/Percent/Cash)                   |
//|             ↳ Moltiplicatore TBS/TWS lotti (TBS=2x, TWS=1x)      |
//|    Layer 4: Persistence — Auto-save/recovery GlobalVariables      |
//|    Layer 5: Filters   — HTF Direction Filter (multi-timeframe)    |
//|    Layer 6: Virtual   — Paper trading con P&L tracking            |
//|    Layer 7: UI        — Dashboard, overlay canale, frecce segnale |
//|                                                                  |
//|  SEGNALI:                                                        |
//|    Turtle Soup (Raschke) — mean reversion su false breakout       |
//|    TBS = Turtle Body Soup: corpo penetra banda (forte, lotto 2x)  |
//|    TWS = Turtle Wick Soup: solo wick tocca (debole, lotto 1x)     |
//|                                                                  |
//|  STRUMENTI SUPPORTATI:                                           |
//|    Forex, Crypto (BTC/ETH), Gold, Silver, Oil, Indices            |
//|    Auto-detection della classe strumento dal nome simbolo          |
//|                                                                  |
//|  CHANGELOG v1.3.0:                                               |
//|    - Allineamento filtri M5/M15 a Carneval (flatTol, cooldown)    |
//|    - Session Filter OFF di default (crypto 24/7)                  |
//|    - Level Age OFF di default (impossibile su M5)                 |
//|    - Moltiplicatore lotti TBS/TWS (TBS=2x default)                |
//|    - Indicatore DPC allineato ai nuovi preset                     |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "AcquaDulza (C) 2026"
#property version   "1.30"
#property description "AcquaDulza EA v1.3.0 — Reusable Trading Framework"
#property description "Engine: DPC v7.19 (Donchian Predictive Channel)"
#property description "Segnali: Turtle Soup (TBS forte 2x / TWS debole 1x)"
#property description "Anti-repaint: bar[1] signals only"
#property strict

//+------------------------------------------------------------------+
//| INCLUDE MODULES — Ordine di dipendenza rigoroso                  |
//+------------------------------------------------------------------+

// === Layer 0: Config ===
#include "Config/adEnums.mqh"
#include "Config/adEngineInterface.mqh"
#include "Config/adInputParameters.mqh"

// === Layer 1: Core + Utilities ===
#include "Core/adGlobalVariables.mqh"
#include "Utilities/adHelpers.mqh"
#include "Config/adInstrumentConfig.mqh"    // Multi-prodotto: detect + preset strumento
#include "Core/adBrokerValidation.mqh"
#include "Core/adSessionManager.mqh"

// === Layer 2: Engine (SWAPPABLE — sostituire solo queste righe) ===
#include "Engine/adDPCPresets.mqh"
#include "Engine/adDPCBands.mqh"
#include "Engine/adDPCFilters.mqh"
#include "Engine/adDPCCooldown.mqh"
#include "Engine/adDPCLTFEntry.mqh"
#include "Engine/adDPCEngine.mqh"

// === Layer 3: Orders ===
#include "Orders/adATRCalculator.mqh"
#include "Orders/adRiskManager.mqh"
#include "Orders/adOrderManager.mqh"
#include "Orders/adCycleManager.mqh"

// === Layer 4: Persistence ===
#include "Persistence/adStatePersistence.mqh"
#include "Persistence/adRecoveryManager.mqh"

// === Layer 5: Filters ===
#include "Filters/adHTFFilter.mqh"

// === Layer 6: Virtual ===
#include "Virtual/adVirtualTrader.mqh"

// === Layer 7: UI ===
#include "UI/adDashboard.mqh"
#include "UI/adControlButtons.mqh"
#include "UI/adChannelOverlay.mqh"
#include "UI/adSignalMarkers.mqh"

//+------------------------------------------------------------------+
//| PopulateDashboardData — Copia dati framework in DashboardData    |
//+------------------------------------------------------------------+
void PopulateDashboardData()
{
   g_dashData.systemState     = g_systemState;
   g_dashData.symbolName      = _Symbol;
   g_dashData.timeframeName   = EnumToString(Period());
   g_dashData.magicNumber     = MagicNumber;
   g_dashData.engineName      = "DPC v7.19";

   // Band data (da ultimo segnale)
   g_dashData.upperBand       = g_lastSignal.upperBand;
   g_dashData.midline         = g_lastSignal.midline;
   g_dashData.lowerBand       = g_lastSignal.lowerBand;
   g_dashData.channelWidthPip = g_lastSignal.channelWidthPip;
   g_dashData.isFlat          = g_lastSignal.isFlat;
   g_dashData.lastDirection   = g_lastSignal.direction;
   g_dashData.lastQuality     = g_lastSignal.quality;

   // Engine extras
   g_dashData.extraCount = g_lastSignal.extraCount;
   for(int i = 0; i < g_lastSignal.extraCount && i < 12; i++)
   {
      g_dashData.extraValues[i] = g_lastSignal.extraValues[i];
      g_dashData.extraLabels[i] = g_lastSignal.extraLabels[i];
   }

   // Filters
   g_dashData.filterCount = g_lastSignal.filterCount;
   for(int i = 0; i < g_lastSignal.filterCount && i < 12; i++)
   {
      g_dashData.filterStates[i] = g_lastSignal.filterStates[i];
      g_dashData.filterNames[i]  = g_lastSignal.filterNames[i];
   }

   // Cycles
   g_dashData.activeCycles  = CountActiveCycles();
   g_dashData.maxCycles     = MaxConcurrentTrades;
   int pending = 0;
   for(int i = 0; i < ArraySize(g_cycles); i++)
      if(g_cycles[i].state == CYCLE_PENDING) pending++;
   g_dashData.pendingCycles = pending;

   // P&L
   g_dashData.sessionPnL    = g_sessionRealizedProfit;
   g_dashData.totalTrades   = g_sessionWins + g_sessionLosses;
   g_dashData.wins          = g_sessionWins;
   g_dashData.losses        = g_sessionLosses;
   g_dashData.winRate       = (g_dashData.totalTrades > 0) ?
      (g_sessionWins * 100.0 / g_dashData.totalTrades) : 0.0;
   g_dashData.maxDrawdown   = g_maxDrawdownPct;
   g_dashData.floatingPnL   = 0;
   for(int i = 0; i < ArraySize(g_cycles); i++)
   {
      if(g_cycles[i].state == CYCLE_ACTIVE && g_cycles[i].ticket > 0)
         g_dashData.floatingPnL += GetFloatingProfit(g_cycles[i].ticket);
   }
   g_dashData.dailyLoss = g_dailyRealizedProfit;

   // Market
   g_dashData.atrValue    = g_atrPips;
   g_dashData.spreadPips  = GetSpreadPips();
   g_dashData.balance     = GetBalance();
   g_dashData.equity      = GetEquity();

   // Signals
   g_dashData.buySignals    = g_buySignals;
   g_dashData.sellSignals   = g_sellSignals;
   g_dashData.totalSignals  = g_totalSignals;

   // LTF
   g_dashData.ltfConfirm    = g_lastSignal.ltfConfirm;
   g_dashData.ltfTimeframe  = InpUseLTFEntry ? EnumToString(DPCGetLTFTimeframe()) : "OFF";

   // Session
   g_dashData.sessionName = GetSessionStatus();

   // AutoSave
   g_dashData.lastSaveTime = 0;  // Updated by SaveState
}

//+------------------------------------------------------------------+
//| Expert initialization                                            |
//+------------------------------------------------------------------+
int OnInit()
{
   if(_UninitReason == REASON_CHARTCHANGE)
      AdLogI(LOG_CAT_INIT, StringFormat("RE-INIT: TF changed -> %s", EnumToString(Period())));

   AdLogI(LOG_CAT_INIT, "=======================================================");
   AdLogI(LOG_CAT_INIT, StringFormat("ACQUADULZA EA v%s — Symbol: %s | TF: %s",
          EA_VERSION, _Symbol, EnumToString(Period())));
   AdLogI(LOG_CAT_INIT, "Engine: DPC (Donchian Predictive Channel)");
   AdLogI(LOG_CAT_INIT, StringFormat("Magic: %d | Entry: %s | Risk: %s",
          MagicNumber, EnumToString(EntryMode), EnumToString(RiskMode)));
   AdLogI(LOG_CAT_INIT, "=======================================================");

   g_systemState = STATE_INITIALIZING;
   g_systemStartTime = TimeCurrent();

   // Dashboard prima di tutto — visibile anche in caso di errore
   ApplyChartTheme();
   CreateDashboard();

   if(!EnableSystem)
   {
      g_systemState = STATE_IDLE;
      AdLogI(LOG_CAT_SYSTEM, "System DISABLED by user");
      PopulateDashboardData();
      UpdateDashboard();
      return INIT_SUCCEEDED;
   }

   // 1. Broker specifications
   if(!LoadBrokerSpecifications())
   {
      AdLogE(LOG_CAT_INIT, "FAILED: LoadBrokerSpecifications");
      g_systemState = STATE_ERROR;
      PopulateDashboardData();
      UpdateDashboard();
      return INIT_SUCCEEDED;
   }

   // 1b. Instrument classification: detect/apply pip scaling + preset parametri
   //     DEVE girare dopo LoadBrokerSpecifications (usa g_symbolPoint, g_symbolDigits)
   //     e PRIMA di SetupTradeObject (che usa g_inst_slippage)
   InstrumentPresetsInit();

   // 2. Trade object (usa g_inst_slippage per SetDeviationInPoints)
   SetupTradeObject();

   // 3. Validate inputs
   if(!ValidateInputParameters())
   {
      AdLogE(LOG_CAT_INIT, "FAILED: ValidateInputParameters");
      g_systemState = STATE_ERROR;
      PopulateDashboardData();
      UpdateDashboard();
      return INIT_SUCCEEDED;
   }

   // 4. ATR
   if(!InitializeATR())
   {
      AdLogE(LOG_CAT_INIT, "FAILED: InitializeATR");
      g_systemState = STATE_ERROR;
      PopulateDashboardData();
      UpdateDashboard();
      return INIT_SUCCEEDED;
   }

   // 5. Engine init (DPC: handle iATR + iMA, preset, bande iniziali)
   if(!EngineInit())
   {
      AdLogE(LOG_CAT_INIT, "FAILED: EngineInit");
      g_systemState = STATE_ERROR;
      PopulateDashboardData();
      UpdateDashboard();
      return INIT_SUCCEEDED;
   }
   g_engineReady = true;

   // 5b. Draw channel overlay + historical signals immediately
   if(ShowChannelOverlay)
      DrawChannelOverlay();
   if(ShowSignalArrows)
      ScanHistoricalSignals();
   ChartRedraw();  // Force immediate visual update

   // 6. Initialize cycles array
   InitializeCycles();

   // 7. Session manager
   InitializeSessionManager();

   // 8. Risk manager
   InitializeRiskManager();

   // 9. HTF filter
   if(UseHTFFilter)
      InitializeHTFFilter();

   // 10. Recovery: stato salvato, poi scan broker
   if(HasSavedState())
   {
      AdLogI(LOG_CAT_INIT, "Saved state found — restoring...");
      if(RestoreState())
         AdLogI(LOG_CAT_INIT, "State restored from GlobalVariables");
      else
      {
         AdLogW(LOG_CAT_INIT, "Restore failed — falling back to broker scan");
         AttemptRecovery();
      }
   }
   else
   {
      AttemptRecovery();
   }

   // 11. Timer per auto-save
   EventSetTimer(1);  // 1s initially for overlay retry, then 60s

   // Auto-start: sistema parte attivo senza bisogno di premere START
   if(!g_recoveryPerformed && g_systemState == STATE_INITIALIZING)
   {
      g_systemState = STATE_ACTIVE;
      AdLogI(LOG_CAT_INIT, "State: INITIALIZING -> ACTIVE (auto-start)");
   }

   PopulateDashboardData();
   UpdateDashboard();

   // Feed: engine ready
   if(_UninitReason == REASON_CHARTCHANGE)
      AddFeedItem("TF changed -> " + EnumToString(Period()), AD_BIOLUM);
   AddFeedItem("Engine DPC ready · " + EnumToString(Period()), AD_BIOLUM);

   AdLogI(LOG_CAT_INIT, StringFormat("ACQUADULZA ready — %s",
          g_recoveryPerformed ? "RECOVERED" : "ACTIVE (auto-start)"));
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(reason == REASON_CHARTCHANGE)
      AdLogI(LOG_CAT_SYSTEM, "DEINIT: Timeframe change — releasing handles");

   // Salva stato prima di uscire
   if(reason == REASON_REMOVE && ClearStateOnRemove)
   {
      ClearSavedState();
      AdLogI(LOG_CAT_SYSTEM, "State cleared (EA removed)");
   }
   else
   {
      SaveState();
      AdLogI(LOG_CAT_PERSIST, "State saved on deinit");
   }

   // Rilascio risorse
   EngineDeinit();
   g_engineReady = false;

   ReleaseATRHandle();

   // UI cleanup
   CleanupOverlay();
   CleanupSignalMarkers();
   DestroyDashboard();

   EventKillTimer();
   AdLogI(LOG_CAT_SYSTEM, StringFormat("DEINIT — Reason: %d", reason));
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // ── 1. DASHBOARD UPDATE (throttle 500ms) ─────────────────────────
   static uint lastDashUpdate = 0;
   uint now = GetTickCount();
   if(now - lastDashUpdate > 500)
   {
      lastDashUpdate = now;
      PopulateDashboardData();
      UpdateDashboard();

      // Channel overlay live edge — lightweight update (only bar[0] segment)
      if(ShowChannelOverlay && g_engineReady)
         UpdateChannelLiveEdge();
   }

   // ── 1b. CHANNEL OVERLAY + HISTORICAL ARROWS (solo nuova barra, pre-gate) ──
   if(g_engineReady && IsNewBarOverlay())
   {
      if(ShowChannelOverlay) DrawChannelOverlay();
      if(ShowSignalArrows)   ScanHistoricalSignals();
      ChartRedraw();
   }

   // ── 2. VIRTUAL MONITOR (ogni tick, qualsiasi stato) ──────────────
   if(VirtualMode)
      VirtualMonitor();

   // ── 3. GATE: solo se ACTIVE + Engine pronto ──────────────────────
   if(g_systemState != STATE_ACTIVE) return;
   if(!g_engineReady) return;

   // ── 4. SESSION FILTER ────────────────────────────────────────────
   if(EnableSessionFilter && !IsWithinSession())
   {
      // DIAG: log periodico quando sessione blocca (max 1 ogni 5 min)
      static datetime lastSessBlockLog = 0;
      datetime nowDT = TimeCurrent();
      if(nowDT - lastSessBlockLog > 300)
      {
         MqlDateTime dtSess;
         TimeToStruct(nowDT, dtSess);
         AdLogI(LOG_CAT_SESSION, StringFormat("DIAG SESSION BLOCKED: %s | h=%02d:%02d",
                g_currentSessionName, dtSess.hour, dtSess.min));
         lastSessBlockLog = nowDT;
      }
      HandleSessionEnd();
      return;
   }

   // ── 5. NEW BAR GATE ──────────────────────────────────────────────
   if(!IsNewBar()) return;

   AdLogI(LOG_CAT_SYSTEM, StringFormat("NEW BAR %s | Bid=%s | Cycles=%d/%d",
          TimeToString(iTime(_Symbol, PERIOD_CURRENT, 0), TIME_DATE|TIME_MINUTES),
          DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits),
          CountActiveCycles(), MaxConcurrentTrades));

   // ── 6. ATR UPDATE ────────────────────────────────────────────────
   UpdateATR();
   UpdateEquityTracking();

   // ── 7. ENGINE: calcola bande + segnali su bar[1] (anti-repaint) ─
   EngineSignal sig;
   sig.Reset();
   bool hasSignal = EngineCalculate(sig);
   g_lastSignal = sig;

   // ── 8. LTF CHECK (ogni barra, se finestra aperta) ────────────────
   if(InpUseLTFEntry && DPCLTFIsWaiting())
   {
      int ltfResult = DPCLTFCheckConfirmation();
      if(ltfResult != 0)
         sig.ltfConfirm = ltfResult;
   }

   // ── 10. PROCESS SIGNAL ────────────────────────────────────────────
   if(hasSignal && sig.isNewSignal && sig.direction != 0)
   {
      // Pre-trade checks (spread + daily loss checked inside PerformRiskChecks)
      bool passChecks = true;

      if(!PerformRiskChecks())
         passChecks = false;

      // HTF filter
      if(UseHTFFilter && !HTFCheckSignal(sig.direction))
      {
         AdLogI(LOG_CAT_HTF, StringFormat("HTF filter blocked %s",
                sig.direction > 0 ? "BUY" : "SELL"));
         passChecks = false;
      }

      if(passChecks)
      {
         string dirStr = sig.direction > 0 ? "BUY" : "SELL";
         color  dirClr = sig.direction > 0 ? AD_BUY : AD_SELL;
         string qStr   = sig.quality == PATTERN_TBS ? "TBS" : "TWS";

         AdLogI(LOG_CAT_ENGINE, StringFormat("*** SIGNAL %s Q=%d | Entry=%s | SL=%s | TP=%s ***",
                dirStr, sig.quality,
                FormatPrice(sig.entryPrice), FormatPrice(sig.slPrice), FormatPrice(sig.tpPrice)));

         // ── DIAG: Log diagnostico completo del trigger ──
         double diagBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double diagAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         AdLogI(LOG_CAT_TRIGGER, "════════════════════════════════════════════════════");
         AdLogI(LOG_CAT_TRIGGER, StringFormat("TRIGGER %s %s RILEVATO", qStr, dirStr));
         AdLogI(LOG_CAT_TRIGGER, StringFormat("  Direction=%d | Quality=%d (%s)", sig.direction, sig.quality, qStr));
         AdLogI(LOG_CAT_TRIGGER, StringFormat("  Entry=%s | TP=%s | SL=%s", FormatPrice(sig.entryPrice), FormatPrice(sig.tpPrice), FormatPrice(sig.slPrice)));
         AdLogI(LOG_CAT_TRIGGER, StringFormat("  Bands: Upper=%s | Mid=%s | Lower=%s", FormatPrice(sig.upperBand), FormatPrice(sig.midline), FormatPrice(sig.lowerBand)));
         AdLogI(LOG_CAT_TRIGGER, StringFormat("  Mercato: Bid=%s | Ask=%s | Spread=%.1fp", FormatPrice(diagBid), FormatPrice(diagAsk), PointsToPips(diagAsk - diagBid)));
         AdLogI(LOG_CAT_TRIGGER, StringFormat("  EntryMode=%s | Cicli attivi=%d/%d", EnumToString(EntryMode), CountActiveCycles(), MaxConcurrentTrades));
         AdLogI(LOG_CAT_TRIGGER, StringFormat("  BarTime=%s | VirtualMode=%s", TimeToString(sig.barTime, TIME_DATE|TIME_MINUTES), VirtualMode ? "ON" : "OFF"));
         AdLogI(LOG_CAT_TRIGGER, "════════════════════════════════════════════════════");

         // Alert popup per il trigger
         Alert(StringFormat("AcquaDulza TRIGGER %s %s | Entry=%s | TP=%s | %s",
               qStr, dirStr, FormatPrice(sig.entryPrice), FormatPrice(sig.tpPrice), _Symbol));

         // Feed + history
         AddFeedItem(qStr + " " + dirStr + " · " + FormatPrice(sig.entryPrice), dirClr);
         AddSignalHistory(sig.direction, sig.entryPrice, sig.tpPrice, sig.quality, "OPEN");

         // Visual markers
         DrawSignalMarkers(sig);

         // Asterisco giallo al livello TP — visibile su OGNI trigger,
         // anche se il ciclo non viene creato (es. max cicli raggiunto)
         DrawTPAsterisk(sig.tpPrice, sig.barTime, sig.direction > 0);

         // ── DIAG: Log TP diagnostico ──
         AdLogI(LOG_CAT_TRIGGER, StringFormat("DIAG TP: Mode=%s | Value=%.2f | TP calcolato=%s",
                EnumToString(TPMode), TPValue, FormatPrice(sig.tpPrice)));
         if(sig.direction > 0 && sig.tpPrice <= sig.entryPrice)
            AdLogW(LOG_CAT_TRIGGER, StringFormat("DIAG TP WARNING: BUY ma TP (%s) <= Entry (%s) — ordine sara' RIFIUTATO",
                   FormatPrice(sig.tpPrice), FormatPrice(sig.entryPrice)));
         if(sig.direction < 0 && sig.tpPrice >= sig.entryPrice)
            AdLogW(LOG_CAT_TRIGGER, StringFormat("DIAG TP WARNING: SELL ma TP (%s) >= Entry (%s) — ordine sara' RIFIUTATO",
                   FormatPrice(sig.tpPrice), FormatPrice(sig.entryPrice)));

         // Create cycle
         if(VirtualMode)
         {
            AdLogI(LOG_CAT_TRIGGER, "DIAG: VirtualMode ON — creo trade virtuale (nessun ordine reale)");
            int vSlot = VirtualCreateTrade(sig);
            if(vSlot >= 0)
            {
               AdLogI(LOG_CAT_VIRTUAL, "Virtual trade created");
               DrawTPLine(g_nextCycleID, sig.tpPrice, sig.direction > 0);
            }
            else
               AdLogW(LOG_CAT_TRIGGER, "DIAG: VirtualCreateTrade FALLITO — vSlot < 0");
         }
         else
         {
            AdLogI(LOG_CAT_TRIGGER, "DIAG: Invoco CreateCycle() per piazzare ordine reale...");
            int slot = CreateCycle(sig);
            if(slot >= 0)
            {
               AdLogI(LOG_CAT_TRIGGER, StringFormat("DIAG: CreateCycle OK — slot=%d | CycleID=#%d | Ticket=%d",
                      slot, g_cycles[slot].cycleID, g_cycles[slot].ticket));
               AdLogI(LOG_CAT_TRIGGER, StringFormat("DIAG: Ordine PIAZZATO — %s Lot=%.2f | Entry=%s | TP=%s",
                      dirStr, g_cycles[slot].lotSize, FormatPrice(g_cycles[slot].entryPrice), FormatPrice(g_cycles[slot].tpPrice)));
               Alert(StringFormat("AcquaDulza ORDINE PIAZZATO #%d %s | Lot=%.2f | %s",
                     g_cycles[slot].cycleID, dirStr, g_cycles[slot].lotSize, _Symbol));

               DrawTriggerArrow(g_cycles[slot].cycleID, sig.entryPrice,
                               sig.barTime, sig.direction > 0);
               DrawTPLine(g_cycles[slot].cycleID, sig.tpPrice, sig.direction > 0);
               DrawTPDot(g_cycles[slot].cycleID, sig.tpPrice, sig.barTime, sig.direction > 0);
            }
            else
            {
               AdLogW(LOG_CAT_TRIGGER, "DIAG: CreateCycle FALLITO — slot < 0 — NESSUN ORDINE PIAZZATO");
               AdLogW(LOG_CAT_TRIGGER, "DIAG: Controlla i log [CYCLE] e [ORDER] sopra per il motivo del fallimento");
               Alert(StringFormat("AcquaDulza ORDINE FALLITO %s %s — controlla log Experts | %s",
                     qStr, dirStr, _Symbol));
            }
         }
      }
   }

   // ── 11. MONITOR CYCLES ────────────────────────────────────────────
   MonitorCycles(sig);

   // ── 12. DAILY RESET ──────────────────────────────────────────────
   CheckDailyReset();
}

//+------------------------------------------------------------------+
//| Trade transaction handler — Layer 1 fill detection               |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result)
{
   DetectFill(trans, request, result);
}

//+------------------------------------------------------------------+
//| Chart event handler                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam,
                  const double &dparam, const string &sparam)
{
   if(id == CHARTEVENT_OBJECT_CLICK)
      HandleButtonClick(sparam);

   // Redraw canvas fill on chart scroll/zoom/resize
   if(id == CHARTEVENT_CHART_CHANGE)
   {
      if(ShowChannelOverlay && g_engineReady)
      {
         UpdateChannelLiveEdge();
         RedrawOverlayFill();
      }
      ChartRedraw();
   }
}

//+------------------------------------------------------------------+
//| Timer handler — Auto-save                                        |
//+------------------------------------------------------------------+
void OnTimer()
{
   // Retry initial overlay draw (timeseries not ready during OnInit)
   static bool initialDrawDone = false;
   if(!initialDrawDone && g_engineReady)
   {
      int bars = iBars(_Symbol, PERIOD_CURRENT);
      if(bars > 50)
      {
         if(ShowChannelOverlay) DrawChannelOverlay();
         if(ShowSignalArrows) ScanHistoricalSignals();
         PopulateDashboardData();
         UpdateDashboard();
         ChartRedraw();
         initialDrawDone = true;
         EventSetTimer(60);  // Switch to 60s for auto-save
         AdLogI(LOG_CAT_UI, StringFormat("Initial overlay draw — %d bars available", bars));
      }
   }

   // DIAG: Warning periodico se sistema e' IDLE con EnableSystem=true
   static int idleWarningCount = 0;
   if(g_systemState == STATE_IDLE && EnableSystem)
   {
      if(++idleWarningCount % 10 == 1)
         AdLogW(LOG_CAT_SYSTEM, "ATTENZIONE: Sistema IDLE con EnableSystem=true — premi START per attivare");
   }
   else
      idleWarningCount = 0;

   if(EnableAutoSave)
      ExecuteAutoSave();
}
//+------------------------------------------------------------------+
