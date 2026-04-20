//+------------------------------------------------------------------+
//|                                            TerzaOnda.mq5        |
//|  "L'acqua dolce che scorre tra le bande."                        |
//+------------------------------------------------------------------+
//|  Copyright (C) 2026 - TerzaOnda Development                    |
//|  Version: 1.7.3                                                  |
//|  Engine: KPC v1.0 (Keltner Predictive Channel) — swappable      |
//+------------------------------------------------------------------+
//|                                                                  |
//|  TerzaOnda EA — Framework di trading modulare a 7 livelli       |
//|                                                                  |
//|  ARCHITETTURA:                                                   |
//|    Layer 0: Config    — Enums, parametri input, interfaccia eng.  |
//|    Layer 1: Core      — Variabili globali, helpers, sessioni      |
//|    Layer 2: Engine    — KPC v1.0 (Keltner Predictive Channel)    |
//|             ↳ KAMA + Keltner Bands + 7 filtri qualita' + SimpleCooldown  |
//|             ↳ Classificazione TBS/TWS (qualita' segnale)          |
//|             ↳ LTF Entry (conferma su timeframe inferiore)         |
//|             ↳ Auto TF Preset (parametri adattivi per TF)          |
//|    Layer 3: Orders    — Risk manager, lot sizing, order placement |
//|             ↳ 3 risk modes (Fixed/Percent/Cash)                   |
//|             ↳ Moltiplicatore TBS/TWS lotti (TBS=2x, TWS=1x)      |
//|             ↳ Hedge Smart (HS=Magic+1, non invasivo v1.7.0)       |
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
//|    Forex, Crypto (BTC/ETH), Gold, Silver, Oil, Indices, Stock CFD |
//|    Auto-detection della classe strumento dal nome simbolo          |
//|                                                                  |
//|  CHANGELOG v1.7.3:                                               |
//|    - FIX: HandleSessionEnd ora chiude anche HS (MagicNumber+1)   |
//|      Prima chiudeva solo Soup, lasciando HS orfane a fine sessione|
//|                                                                  |
//|  CHANGELOG v1.7.2:                                               |
//|    - HEDGE SMART v2: Step1 BE + Step2 TP programmato              |
//|      SL iniziale = midline (SoupTP): perdita HS definita          |
//|      Step1: dopo HsStep1Pct×cw profitto → SL a fill (BE)        |
//|      Step2: prezzo raggiunge tpRefLevel → chiudi con profitto    |
//|      Nuovi input: HsMidlineSL, HsStep1Pct, HsTpPct, HsBE/Step2   |
//|    - FIX: MonitorActive ora processa CYCLE_HEDGING                |
//|      soupPL non più perso quando Soup chiude con HS attiva        |
//|    - FIX: HsCleanup contestuale in MonitorActive (→SoupClosed)   |
//|    - FIX: hsFillPrice salvato in HsDetectFill (per BE accurato)  |
//|    - FIX: tpRefDist parametrizzato (HsTpPct, era hardcoded 0.60) |
//|    - FIX: HsTimeoutBars default 32 (era 0=disattivato)           |
//|    - RIMOSSO: Exit 2 (HsCloseOnSoupProfit) — prematuro           |
//|    - HsCloseOnSoupProfit deprecato (default false)                |
//|                                                                  |
//|  CHANGELOG v1.7.0:                                               |
//|    - HEDGE SMART: sostituisce Two-Tier H1+H2                     |
//|      Lotto fisso (HsLot, default 0.01)                           |
//|      Trigger: banda ± channel_width × HsTriggerPct               |
//|      Exit 1: next DPC signal (stessa dir, anti-whipsaw N barre)  |
//|      Exit 2: Soup floating >= 0 (HsCloseOnSoupProfit)            |
//|      Exit 3: timeout (HsTimeoutBars, 0=off)                      |
//|      Body/wick filter opzionale (HsBodyFilter, HsBodyRatioMin)   |
//|      Zone grafiche colorate (trigger + TP reference)             |
//|      Magic: HS = MagicNumber+1 (H1/H2 rimossi)                  |
//|    - Recovery: cleanup automatico legacy H2 (Magic+2)            |
//|    - adCycleManager: P&L = soupPL + hsPL (era hedge1Banked)     |
//|                                                                  |
//|  CHANGELOG v1.6.1:                                               |
//|    - FIX: Frecce storiche non mostrate al cambio TF (M15/M30)    |
//|      static initialDrawDone non resettava su REASON_CHARTCHANGE   |
//|      → g_initialDrawDone globale, resettata in OnInit             |
//|    - FIX: LevelAge M15/M30 da hardcoded ON → InpUseLevelAge      |
//|      Il preset forzava LevelAge=true, bloccando quasi tutti i     |
//|      segnali storici. Ora controllato da input (default OFF)      |
//|    - Commenti dettagliati + logging sistematico su 12 file        |
//|      Engine filters, Orders, Persistence, Config, UI              |
//|                                                                  |
//|  CHANGELOG v1.6.0:                                               |
//|    - ALLINEATO a KPC v1.0 (v7.19) — preset ricalibrati           |
//|    - M15 flatTol 0.65→0.70 (+8-12% segnali)                      |
//|    - M30 minWidth 14→12, flatTol 0.50→0.60, minLevelAge 2→4     |
//|    - NUOVO preset M1: maLen=200, minWidth=4.0, flatTol=0.95      |
//|    - H1/H4 minLevelAge hardcoded (5/3) da KPC v1.0 calibrati     |
//|    - Warning M1 + LTF Entry (loop M1→M1)                         |
//|    - Log Params include MinLevelAge                               |
//|    - INSTRUMENT_STOCK: auto-detect Stock CFD via MT5 API          |
//|      SYMBOL_TRADE_CALC_MODE + digits<=2 → preset dedicato         |
//|      pipSize=_Point, widthFactor=3.0, maxSpread=15 pip            |
//|                                                                  |
//|  CHANGELOG v1.5.2:                                               |
//|    - PRESET TF-AWARE: LTFEntry, LevelAge, PendingExpiry          |
//|      M5/M15/M30 hanno valori preset automatici (InpEngineAutoTF)  |
//|      H1/H4 usano valori input (comportamento invariato)           |
//|    - Nuove globals: g_kpc_useLTFEntry, g_kpc_ltfOnlyTBS,         |
//|      g_kpc_useLTFEntry, g_kpc_pendingExpiry   |
//|    - Framework code usa globals instead of inputs diretti          |
//|                                                                  |
//|  CHANGELOG v1.5.1:                                               |
//|    - FIX: H2 BE SL hit distingue da TP (h2PL>0 = TP, <=0 = SL)  |
//|      Soup resta aperta quando H2 breakeven SL viene colpito       |
//|    - FIX: hedge1BankedProfit double-counting in session P&L       |
//|      Session contabilizza h1Banked solo quando bankato, non ripete|
//|    - FIX: HasSavedState ora controlla anche MagicNumber+2 (H2)    |
//|    - FIX: MonitorActive usava variabile 'profit' rinominata       |
//|    - FIX: Recovery ripristina H1 banked profit da deal history    |
//|    - FIX: g_nextCycleID off-by-one dopo recovery (maxID+1→maxID) |
//|                                                                  |
//|  CHANGELOG v1.5.0:                                               |
//|    - TWO-TIER HEDGE SYSTEM: H1 Recovery + H2 Protezione          |
//|      H1: banda +/- Hedge1ATRMult*ATR, TP=Hedge1TPAtrMult*ATR    |
//|          NON chiude Soup — incassa profitto (bank)                |
//|      H2: banda +/- Hedge2ATRMult*ATR, TP=Hedge2TPAtrMult*ATR    |
//|          CHIUDE Soup al raggiungimento TP, lotto 1.5x compensato  |
//|          SL breakeven dopo fill (Hedge2BreakevenSL)               |
//|      Magic: Soup=MagicNumber, H1=+1, H2=+2                       |
//|    - Parametri HEDGING unificati con attivazione indipendente     |
//|    - Zone arancioni H2 su overlay canale (ShowHedge2Zone)         |
//|    - Linea arancione tratteggiata trigger H2 (ShowHedge2Line)     |
//|    - Recovery: scan 3 magic numbers + ripristino BE SL su H2      |
//|                                                                  |
//|  CHANGELOG v1.4.0:                                               |
//|    - HEDGE SYSTEM v1: ordine opposto BUY/SELL STOP automatico     |
//|                                                                  |
//|  CHANGELOG v1.3.0:                                               |
//|    - Allineamento filtri M5/M15 a Carneval (flatTol, cooldown)    |
//|    - Session Filter OFF di default (crypto 24/7)                  |
//|    - Level Age OFF di default (impossibile su M5)                 |
//|    - Moltiplicatore lotti TBS/TWS (TBS=2x default)                |
//|    - Indicatore DPC allineato ai nuovi preset                     |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "TerzaOnda (C) 2026"
#property version   "2.00"
#property description "TerzaOnda EA v2.0.0 — Reusable Trading Framework"
#property description "Engine: KPC v1.0 (Keltner Predictive Channel v7.19)"
#property description "Segnali: Turtle Soup (TBS forte 2x / TWS debole 1x)"
#property description "Hedge: Hedge Smart v1.7.3 — Step1 BE + Step2 TP"
#property description "Anti-repaint: bar[1] signals only"
#property strict

//+------------------------------------------------------------------+
//| INCLUDE MODULES — Ordine di dipendenza rigoroso                  |
//+------------------------------------------------------------------+

// === Layer 0: Config ===
#include "Config/3ondEnums.mqh"
#include "Config/3ondEngineInterface.mqh"
#include "Config/3ondInputParameters.mqh"

// === Layer 1: Core + Utilities ===
#include "Core/3ondGlobalVariables.mqh"
#include "Utilities/3ondHelpers.mqh"
#include "Config/3ondInstrumentConfig.mqh"    // Multi-prodotto: detect + preset strumento
#include "Core/3ondBrokerValidation.mqh"
#include "Core/3ondSessionManager.mqh"

// === Layer 2: Engine (SWAPPABLE — sostituire solo queste righe) ===
#include "Engine/3ondKPCPresets.mqh"
#include "Engine/3ondKPCBands.mqh"
#include "Engine/3ondKPCFilters.mqh"
#include "Engine/3ondKPCCooldown.mqh"
#include "Engine/3ondKPCLTFEntry.mqh"
#include "Engine/3ondKPCEngine.mqh"

// === Layer 3: Orders ===
#include "Orders/3ondATRCalculator.mqh"
#include "Orders/3ondRiskManager.mqh"
#include "Orders/3ondOrderManager.mqh"
#include "Orders/3ondCycleManager.mqh"
#include "Orders/3ondHedgeManager.mqh"   // Layer 3.5: Hedge Smart Engine (v1.7.0)

// === Layer 4: Persistence ===
#include "Persistence/3ondStatePersistence.mqh"
#include "Persistence/3ondRecoveryManager.mqh"

// === Layer 5: Filters ===
#include "Filters/3ondHTFFilter.mqh"

// === Layer 6: Virtual ===
#include "Virtual/3ondVirtualTrader.mqh"

// === Layer 7: UI ===
#include "UI/3ondDashboard.mqh"
#include "UI/3ondControlButtons.mqh"
#include "UI/3ondChannelOverlay.mqh"
#include "UI/3ondSignalMarkers.mqh"

//+------------------------------------------------------------------+
//| Expert initialization                                            |
//+------------------------------------------------------------------+
int OnInit()
{
   if(_UninitReason == REASON_CHARTCHANGE)
      AdLogI(LOG_CAT_INIT, StringFormat("RE-INIT: TF changed -> %s", EnumToString(Period())));

   AdLogI(LOG_CAT_INIT, "=======================================================");
   AdLogI(LOG_CAT_INIT, StringFormat("TERZAONDA EA v%s — Symbol: %s | TF: %s",
          EA_VERSION, _Symbol, EnumToString(Period())));
   AdLogI(LOG_CAT_INIT, "Engine: KPC v1.0 (Keltner Predictive Channel)");
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
      UpdateDashboard();
      return INIT_SUCCEEDED;
   }

   // 1. Broker specifications
   if(!LoadBrokerSpecifications())
   {
      AdLogE(LOG_CAT_INIT, "FAILED: LoadBrokerSpecifications");
      g_systemState = STATE_ERROR;
      UpdateDashboard();
      Alert(StringFormat("TerzaOnda INIT FAILED — LoadBrokerSpecifications | %s", _Symbol));
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
      UpdateDashboard();
      Alert(StringFormat("TerzaOnda INIT FAILED — ValidateInputParameters | %s", _Symbol));
      return INIT_SUCCEEDED;
   }

   // 4. Engine preset (DEVE girare PRIMA di InitializeATR perche'
   //    KPCPresetsInit imposta g_kpc_atrPeriod_eff usato da CreateATRHandle.
   //    Senza questo, M1 userebbe ATR(14) invece di ATR(7), M5 ATR(14) invece di ATR(10).)
   KPCPresetsInit();

   // 4b. ATR (usa g_kpc_atrPeriod_eff gia' impostato dal preset)
   if(!InitializeATR())
   {
      AdLogE(LOG_CAT_INIT, "FAILED: InitializeATR");
      g_systemState = STATE_ERROR;
      UpdateDashboard();
      Alert(StringFormat("TerzaOnda INIT FAILED — InitializeATR | %s", _Symbol));
      return INIT_SUCCEEDED;
   }

   // 5. Engine init (KPC: KAMA seeding, bande iniziali, filtri, cooldown)
   //    NOTA: EngineInit NON richiama più KPCPresetsInit internamente (v2.0.1)
   //    — i preset vengono applicati una sola volta alla riga 250.
   if(!EngineInit())
   {
      AdLogE(LOG_CAT_INIT, "FAILED: EngineInit");
      g_systemState = STATE_ERROR;
      UpdateDashboard();
      Alert(StringFormat("TerzaOnda INIT FAILED — EngineInit | %s", _Symbol));
      return INIT_SUCCEEDED;
   }
   g_engineReady = true;
   g_initialDrawDone = false;  // Reset retry timer per TF change

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

   // 8b. Hedge Engine
   if(EnableHedge) HedgeInit();

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
   // Schedule a 1s timer per il retry iniziale dell'overlay (timeseries non sempre
   // pronto a OnInit / REASON_CHARTCHANGE). Appena il draw riesce, OnTimer passa
   // a 60s per l'auto-save. Questa transizione è gestita in OnTimer (riga ~626).
   EventSetTimer(1);

   // Fresh start: sistema parte IDLE — utente deve premere START
   if(!g_recoveryPerformed && g_systemState == STATE_INITIALIZING)
   {
      g_systemState = STATE_IDLE;
      AdLogI(LOG_CAT_INIT, "State: INITIALIZING -> IDLE (press START)");
   }

   UpdateDashboard();

   // Feed: engine ready
   if(_UninitReason == REASON_CHARTCHANGE)
      AddFeedItem("TF changed -> " + EnumToString(Period()), TOND_BIOLUM);
   AddFeedItem("Engine KPC ready · " + EnumToString(Period()), TOND_BIOLUM);
   if(g_systemState == STATE_IDLE)
      AddFeedItem("Press START to begin trading", TOND_AMBER);

   AdLogI(LOG_CAT_INIT, StringFormat("TERZAONDA ready — %s",
          g_recoveryPerformed ? "RECOVERED" : "IDLE (press START)"));
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

   if(EnableHedge) HedgeDeinit();
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
   // DELIBERATO: viene eseguito PRIMA del gate STATE_ACTIVE e PRIMA del new bar
   // gate — così il P&L virtuale e le chiusure virtuali (TP/SL) si aggiornano
   // anche in IDLE/PAUSED e intrabar per visualizzazione realistica.
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
         AdLogD(LOG_CAT_SESSION, StringFormat("DIAG SESSION BLOCKED: %s | h=%02d:%02d",
                g_currentSessionName, dtSess.hour, dtSess.min));
         lastSessBlockLog = nowDT;
      }
      // ATTENZIONE: HandleSessionEnd è DISTRUTTIVO — chiude Soup (Magic) e HS
      // (Magic+1) e cancella pending. Idempotente via g_sessionCloseTriggered.
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

   // ── 6b. DAILY LOSS LIMIT — check continuo (v2.0.1) ──────────────
   // Verifica il limite di perdita giornaliera anche senza un nuovo segnale.
   // Se superato, chiude tutte le posizioni e mette l'EA in PAUSED.
   if(IsDailyLossLimitBreached() && !g_dailyShutdownTriggered)
   {
      EnforceDailyLossShutdown();
      return;
   }

   // ── 7. ENGINE: calcola bande + segnali su bar[1] (anti-repaint) ─
   EngineSignal sig;
   sig.Reset();
   bool hasSignal = EngineCalculate(sig);
   g_lastSignal = sig;

   // ── 8. LTF CHECK (ogni barra, se finestra aperta) ────────────────
   if(g_kpc_useLTFEntry && KPCLTFIsWaiting())
   {
      int ltfResult = KPCLTFCheckConfirmation();
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
         color  dirClr = sig.direction > 0 ? TOND_BUY : TOND_SELL;
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
         AdLogD(LOG_CAT_TRIGGER, StringFormat("  Mercato: Bid=%s | Ask=%s | Spread=%.1fp", FormatPrice(diagBid), FormatPrice(diagAsk), PointsToPips(diagAsk - diagBid)));
         AdLogI(LOG_CAT_TRIGGER, StringFormat("  EntryMode=%s | Cicli attivi=%d/%d", EnumToString(EntryMode), CountActiveCycles(), MaxConcurrentTrades));
         AdLogI(LOG_CAT_TRIGGER, StringFormat("  BarTime=%s | VirtualMode=%s", TimeToString(sig.barTime, TIME_DATE|TIME_MINUTES), VirtualMode ? "ON" : "OFF"));
         AdLogI(LOG_CAT_TRIGGER, "════════════════════════════════════════════════════");

         // Alert popup per il trigger
         Alert(StringFormat("TerzaOnda TRIGGER %s %s | Entry=%s | TP=%s | %s",
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
         AdLogD(LOG_CAT_TRIGGER, StringFormat("DIAG TP: Mode=%s | Value=%.2f | TP calcolato=%s",
                EnumToString(TPMode), TPValue, FormatPrice(sig.tpPrice)));

         // TP invalido → blocca CreateCycle preventivamente
         // (v2.0.1: evita round-trip broker su ordine certamente rifiutato)
         bool tpInvalid = (sig.direction > 0 && sig.tpPrice <= sig.entryPrice)
                       || (sig.direction < 0 && sig.tpPrice >= sig.entryPrice);
         if(tpInvalid)
         {
            AdLogE(LOG_CAT_TRIGGER, StringFormat("TP INVALIDO — %s Entry=%s TP=%s: ordine NON piazzato",
                   dirStr, FormatPrice(sig.entryPrice), FormatPrice(sig.tpPrice)));
            Alert(StringFormat("TerzaOnda ORDINE SKIPPED — TP invalido %s | Entry=%s TP=%s | %s",
                  dirStr, FormatPrice(sig.entryPrice), FormatPrice(sig.tpPrice), _Symbol));
         }
         else if(VirtualMode)
         {
            AdLogD(LOG_CAT_TRIGGER, "DIAG: VirtualMode ON — creo trade virtuale (nessun ordine reale)");
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
            AdLogD(LOG_CAT_TRIGGER, "DIAG: Invoco CreateCycle() per piazzare ordine reale...");
            int slot = CreateCycle(sig);
            // v2.0.1 defensive upper-bound check: CreateCycle dovrebbe ritornare -1 o
            // un indice valido, ma verifichiamo esplicitamente per evitare accessi OOB
            if(slot >= 0 && slot < ArraySize(g_cycles))
            {
               AdLogD(LOG_CAT_TRIGGER, StringFormat("DIAG: CreateCycle OK — slot=%d | CycleID=#%d | Ticket=%d",
                      slot, g_cycles[slot].cycleID, g_cycles[slot].ticket));
               AdLogD(LOG_CAT_TRIGGER, StringFormat("DIAG: Ordine PIAZZATO — %s Lot=%.2f | Entry=%s | TP=%s",
                      dirStr, g_cycles[slot].lotSize, FormatPrice(g_cycles[slot].entryPrice), FormatPrice(g_cycles[slot].tpPrice)));
               Alert(StringFormat("TerzaOnda ORDINE PIAZZATO #%d %s | Lot=%.2f | %s",
                     g_cycles[slot].cycleID, dirStr, g_cycles[slot].lotSize, _Symbol));

               DrawTriggerArrow(g_cycles[slot].cycleID, sig.entryPrice,
                               sig.barTime, sig.direction > 0);
               DrawTPLine(g_cycles[slot].cycleID, sig.tpPrice, sig.direction > 0);
               DrawTPDot(g_cycles[slot].cycleID, sig.tpPrice, sig.barTime, sig.direction > 0);

               // === Hedge Smart: piazza HS contestualmente al ciclo ===
               if(EnableHedge && HsEnabled && !VirtualMode)
                  HsPlaceOrder(slot, sig);
            }
            else
            {
               AdLogW(LOG_CAT_TRIGGER, StringFormat("DIAG: CreateCycle FALLITO — slot=%d non valido (size=%d) — NESSUN ORDINE PIAZZATO",
                      slot, ArraySize(g_cycles)));
               AdLogW(LOG_CAT_TRIGGER, "DIAG: Controlla i log [CYCLE] e [ORDER] sopra per il motivo del fallimento");
               Alert(StringFormat("TerzaOnda ORDINE FALLITO %s %s — controlla log Experts | %s",
                     qStr, dirStr, _Symbol));
            }
         }
      }
   }

   // ── 11. MONITOR CYCLES ────────────────────────────────────────────
   MonitorCycles(sig);

   // ── 11b. HEDGE SMART MONITOR ──────────────────────────────────────
   if(EnableHedge && HsEnabled)
   {
      for(int _hi = 0; _hi < ArraySize(g_cycles); _hi++)
         HsMonitor(_hi, sig, hasSignal);
   }

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
   // Retry initial overlay draw (timeseries not ready during OnInit/TF change)
   // g_initialDrawDone e' globale — resettata in OnInit ad ogni init/TF change
   // cosi' il retry funziona anche dopo REASON_CHARTCHANGE
   if(!g_initialDrawDone && g_engineReady)
   {
      int bars = iBars(_Symbol, PERIOD_CURRENT);
      if(bars > 50)
      {
         if(ShowChannelOverlay) DrawChannelOverlay();
         if(ShowSignalArrows) ScanHistoricalSignals();
         UpdateDashboard();
         ChartRedraw();
         g_initialDrawDone = true;
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
