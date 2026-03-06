# 🌊 ACQUADULZA EA — Architettura v3.0
## Documento Definitivo per Claude Code
**04 Marzo 2026 — Versione finale di produzione**

---

## PREFAZIONE: ANALISI CRITICA DELLA v2 E CORREZIONI APPLICATE

Prima di leggere questa architettura, è fondamentale capire i **problemi strutturali identificati nella v2** e come sono stati corretti.

### Problema 1 — `adDPCEngine.mqh` sarebbe ancora 1900+ righe ❌
**v2 dichiarava**: "Estrai OnCalculate in adDPCEngine.mqh"
**Realtà**: OnCalculate di DPC0404 è ~1900 righe. Un singolo file `.mqh` da 1900 righe è lo stesso problema del monolite originale.
**Correzione v3**: L'engine DPC è spezzato in **5 file separati**, ognuno con una responsabilità atomica. `adDPCEngine.mqh` diventa solo un orchestratore di ~150 righe.

### Problema 2 — Il dashboard leggeva variabili globali DPC-specifiche ❌
**v2 dichiarava**: Dashboard legge `g_dpcUpper`, `g_dpcLower`, `g_dpcMid` ecc.
**Realtà**: Questo vincola il dashboard all'engine DPC. Se si swappa con ATR Bands, il dashboard si rompe.
**Correzione v3**: Il dashboard legge **solo** la struct `DashboardData`, popolata dall'engine tramite `EngineSignal`. Zero accoppiamento diretto dashboard↔engine.

### Problema 3 — Nessuna gestione esplicita dell'ordine degli #include ❌
**v2 dichiarava**: File separati, ma non specificava l'ordine di dipendenza.
**Realtà**: In MQL5, se `adCycleManager.mqh` usa `EngineSignal` e `EngineSignal` è definita in `adEngineInterface.mqh`, l'ordine di #include in `AcquaDulza.mq5` è critico.
**Correzione v3**: L'ordine esatto degli #include è documentato con grafo delle dipendenze.

### Problema 4 — `struct CycleRecord` non aveva una casa definita ❌
**v2 dichiarava**: CycleManager gestisce i cicli.
**Realtà**: La definizione della struct deve precedere tutti i moduli che la usano (GlobalVariables, OrderManager, RecoveryManager, Dashboard).
**Correzione v3**: `CycleRecord` è definita in `adEnums.mqh`, il primo file incluso.

### Problema 5 — MTF Filter non aveva un modulo assegnato ❌
**v2**: Citato negli input ma mai assegnato a nessun file `.mqh`.
**Correzione v3**: `adHTFFilter.mqh` — calcolo Donchian HTF via `CopyBuffer` su timeframe superiore.

### Problema 6 — `adVisualTheme.mqh` mancava completamente ❌
**v2**: Colori hardcoded nel dashboard.
**Correzione v3**: `adVisualTheme.mqh` con palette Ocean completa — tema professionale finanza.

### Problema 7 — Virtual Mode descritto ma non implementato architetturalmente ❌
**Correzione v3**: `adVirtualTrader.mqh` — cicli simulati con tutta la logica reale, zero ordini broker.

---

## 1. IDENTITÀ E PRINCIPIO

**Nome**: AcquaDulza EA
**Versione iniziale**: 1.0.0
**Engine montato**: DPC (Donchian Predictive Channel) v7.19
**Tema UI**: Ocean — professionismo finanziario, palette deep navy / bioluminescenza

### Regola assoluta di architettura
```
EngineCalculate() → EngineSignal → Framework
```
Il framework non sa com'è fatto l'engine. Riceve solo `EngineSignal`.
Swappare engine = cambiare 1 riga di #include. **Tutto il resto rimane invariato.**

---

## 2. ANALISI APPROFONDITA: COSA SI PRENDE, COSA SI RISCRIVE, COSA SI ELIMINA

### 2.A — Da `Carneval.mq5` + moduli: cosa si prende (come ispirazione/paradigma)

| Concetto | Origine | Cosa si porta in AcquaDulza | Note |
|---------|--------|---------------------------|------|
| Pattern DashRectangle + DashLabel | `carnDashboard.mqh` | ✅ Portato identico in `adDashboard.mqh` | Meccanismo provato: crea oggetto se non esiste, aggiorna se esiste. NON delete+create (rompe z-order) |
| Z-order layering (rect 15000, label 16000, btn 16001) | `carnDashboard.mqh` | ✅ Identico — `AD_ZORDER_RECT`, `AD_ZORDER_LABEL`, `AD_ZORDER_BTN` | |
| Auto-detect filling mode (FOK/IOC/RETURN) | `Carneval.mq5` OnInit | ✅ Portato in `adBrokerValidation.mqh` | Necessario su ogni broker |
| Sistema di logging categorizzato | `carnHelpers.mqh` | ✅ Semplificato: 3 livelli INFO/WARN/ERROR + categoria | Macro `AdLog()` |
| State machine (IDLE→ACTIVE→PAUSED→ERROR) | `carnGlobalVariables.mqh` | ✅ Identica struttura | |
| `OnTradeTransaction` per fill detection | `Carneval.mq5` | ✅ Unico metodo affidabile per detection istantanea | |
| `EventSetTimer(60)` → `OnTimer()` → `SaveState()` | `Carneval.mq5` | ✅ Auto-save ogni 60s | |
| GlobalVariables per persistence | `carnStatePersistence.mqh` | ✅ Stesso pattern con prefisso `AD_` | |
| Stile input parameters (sezioni + icone emoji + frecce enum) | `carnInputParameters.mqh` | ✅ Replicato con sezioni Ocean | |
| Control buttons con `HandleButtonClick()` | `carnControlButtons.mqh` | ✅ START / PAUSE / RECOVERY / STOP | +PAUSE aggiunto |
| `UpdateSidePanels()` — pannello ENGINE MONITOR | `carnDashboard.mqh` | ✅ Portato come pannello destro: ATR, spread, handles, signal feed | |
| `ApplyChartTheme()` | `carnVisualTheme.mqh` | ✅ Ricolorato con palette Ocean | |

### 2.B — Da `Carneval.mq5`: cosa si ELIMINA con motivazione

| Modulo eliminato | Motivazione |
|----------------|-------------|
| `carnTurtleSoupSystem.mqh` | Strategia hardcoded. L'engine DPC già produce segnali neutrali `direction=+1/-1`. Non esiste più il concetto di "Soup" — esiste solo "signal" |
| `carnBreakoutSystem.mqh` | Il breakout hedge diventa `UseHedge=bool` in `adRiskManager.mqh`. Non serve un modulo di 400 righe per un flag |
| `carnTriggerSystem.mqh` | La logica trigger (piazza stop order sopra/sotto banda) è ora in `adOrderManager.mqh::OrderPlaceStop()`, 30 righe |
| `carnHedgeManager.mqh` | Hedge = `OrderPlaceHedge()` in `adOrderManager.mqh`. Non un modulo separato |
| `carnPairPresets.mqh` | Sostituito dai TF Preset nel DPC Engine (più precisi: basati su ATR reale, non su pair name) |
| `carnDPCEngine.mqh` (versione Carneval) | Versione incompleta, senza TBS/TWS, senza LTF, senza flatTol per-TF. Sostituito dalla versione full estratta da DPC0404 |
| ADX filter | ADX ha lag 28-42 barre su M5 (Wilder double smoothing). Choppiness Index è superiore per regime detection. Non portato. |
| Modalità `MODE_CLASSIC_TURTLE` | Eliminata. AcquaDulza ha solo trigger mode. Il "turtle soup" era una complessità non necessaria nell'architettura EA |

### 2.C — Da `DonchianPredictiveChannel0404.mq5`: cosa si ESTRAE

| Sezione originale | Righe | → Modulo EA | Note |
|------------------|-------|------------|------|
| Enum MA_TYPE, TRIGGER_MODE, TF_PRESET, SIGNAL_PATTERN | 316–420 | `adEnums.mqh` | Portati verbatim |
| Input parameters completi (420+ righe di sezioni) | 420–1045 | `adInputParameters.mqh` | Riorganizzati per EA |
| OnInit: `switch(Period())` auto-preset | 1253–1380 | `adDPCPresets.mqh` | Estratto e pulito |
| OnInit: handle MA/ATR, validazioni parametri | 1380–1646 | `adDPCEngine.mqh::EngineInit()` | |
| `ParseTimeToMinutes()` + `IsInBlockedTime()` | 1730–1803 | `adSessionManager.mqh` | |
| `LinearRegressionSlope()` + `ManualWMA()` | 1805–1891 | `adDPCFilters.mqh` | Math puro |
| Flatness filter logic | OnCalculate sezioni 1-2 | `adDPCFilters.mqh::CheckFlatness()` | |
| MA filter (con dead-code fix: `if(false &&` → `if(i>0 &&`) | OnCalculate sezione 3 | `adDPCFilters.mqh::CheckMAFilter()` | **Bug fix incluso** |
| SmartCooldown (midline touch + same/opposite bars) | OnCalculate sezione 4 | `adDPCCooldown.mqh` | Modulo autonomo |
| Calcolo Donchian bands (dcHi/dcLo/mid) + EMA ATR | OnCalculate core | `adDPCBands.mqh` | Math puro |
| Classificazione TBS/TWS | OnCalculate sezione 3726-3850 | `adDPCEngine.mqh::ClassifySignal()` | |
| Touch Trigger BAR_CLOSE logic (Buffer 18) | OnCalculate sezione 5b | `adDPCEngine.mqh::DetectTouchTrigger()` | |
| LTF Entry Signal (Buffer 20, finestra + conferma) | OnCalculate sezione 5c | `adDPCLTFEntry.mqh` | |

### 2.D — Da DPC0404: cosa si ELIMINA (funzionalità visuale indicatore)

| Eliminato | Motivo |
|---------|--------|
| 21 buffer indicatore (`BufMid[]`, `BufUpper[]` ecc.) | In un EA i valori vivono in `EngineSignal`. Non esistono buffer |
| `DRAW_COLOR_CANDLES` con candele trigger gialle | L'EA non controlla il rendering delle candele. I trigger gialli sono sostituiti da marker `OBJ_ARROW_RIGHT` nel `adSignalMarkers.mqh` |
| `Canvas` / `RedrawCanvas()` / HUD overlay | Il dashboard EA è costruito con DashRectangle+DashLabel. Nessun canvas |
| `GenerateForecastPoints()` + `DrawForecast()` | Funzionalità visuale indicatore. Non ha senso in un EA |
| `CreateTPTarget()` / `CloseTPTarget()` (linee chart complesse) | Sostituiti da `adSignalMarkers.mqh::DrawTPLine()` — linea semplice + label |
| `CreateSignalArrow()` con OBJ_ARROW + tooltip + label OBJ_TEXT | Rifatto in `adSignalMarkers.mqh` — più pulito, senza ridondanze |
| Sezione 6 Forecast, Sezione 7 Canvas fill | Eliminati completamente |

---

## 3. STRUTTURA FILE DEFINITIVA (23 .mqh + 1 .mq5)

```
AcquaDulza/
│
├── AcquaDulza.mq5                    ← Orchestratore puro (~200 righe)
│
├── Config/
│   ├── adEnums.mqh                   ← Enum + struct CycleRecord + costanti (~120r)
│   ├── adInputParameters.mqh         ← Tutti gli input (sezioni Ocean style) (~220r)
│   ├── adEngineInterface.mqh         ← struct EngineSignal + firme contratto (~50r)
│   └── adVisualTheme.mqh             ← Palette Ocean + costanti UI MQL5 (~80r)
│
├── Core/
│   ├── adGlobalVariables.mqh         ← Stato macchina + array cicli + vars (~120r)
│   ├── adBrokerValidation.mqh        ← Specs broker, filling, digits (~80r)
│   └── adSessionManager.mqh          ← Sessioni + ParseTimeToMinutes + IsInBlockedTime (~100r)
│
├── Engine/                           ← DPC Engine (5 file, nessuno >250 righe)
│   ├── adDPCPresets.mqh              ← switch(Period()) auto-preset M5→H4 (~100r)
│   ├── adDPCBands.mqh                ← Calcolo Donchian hi/lo/mid + EMA ATR (~150r)
│   ├── adDPCFilters.mqh              ← Flatness + MA filter (fix!) + LinearReg + WMA (~200r)
│   ├── adDPCCooldown.mqh             ← SmartCooldown: midline touch + same/opp bars (~120r)
│   ├── adDPCLTFEntry.mqh             ← LTF Entry Signal: finestra + conferma bar LTF (~130r)
│   └── adDPCEngine.mqh               ← Orchestratore: chiama band+filter+cooldown+ltf → EngineSignal (~200r)
│
├── Orders/
│   ├── adATRCalculator.mqh           ← Handle ATR + CopyBuffer + GetATRPips (~60r)
│   ├── adRiskManager.mqh             ← Lot sizing + spread check + daily loss + breaker (~150r)
│   ├── adOrderManager.mqh            ← Place/Modify/Close Market/Limit/Stop (~200r)
│   └── adCycleManager.mqh            ← CreateCycle + MonitorCycles + CountActive (~180r)
│
├── Persistence/
│   ├── adStatePersistence.mqh        ← Save/Restore via GlobalVariables (~100r)
│   └── adRecoveryManager.mqh         ← Scan broker posizioni orfane (~100r)
│
├── Filters/
│   └── adHTFFilter.mqh               ← Donchian HTF direction filter (~80r)
│
├── Virtual/
│   └── adVirtualTrader.mqh           ← Paper trading: simula cicli senza ordini (~120r)
│
└── UI/
    ├── adDashboard.mqh               ← Pannello principale (DashRect+DashLabel) (~280r)
    ├── adControlButtons.mqh          ← START/PAUSE/RECOVERY/STOP + feedback (~100r)
    ├── adChannelOverlay.mqh          ← Canale DPC su chart (upper/mid/lower lines) (~120r)
    └── adSignalMarkers.mqh           ← Frecce TBS/TWS + TP lines + entry dots (~150r)
```

**Totale: 23 .mqh + 1 .mq5 | Ogni file: 50–280 righe | Nessun file supera 300 righe**

---

## 4. ORDINE INCLUDE IN `AcquaDulza.mq5` (critico per MQL5)

```cpp
//+------------------------------------------------------------------+
//|                                          AcquaDulza.mq5          |
//|  🌊 AcquaDulza Expert Advisor v1.0.0                             |
//|  Engine: DPC (Donchian Predictive Channel) v7.19                 |
//|  Architecture: modular engine-agnostic                           |
//+------------------------------------------------------------------+
#property copyright "AcquaDulza (C) 2026"
#property version   "1.00"
#property description "AcquaDulza EA — DPC Engine, Ocean Theme"
#property strict
#include <Trade/Trade.mqh>

// ── LAYER 0: Definizioni base (nessuna dipendenza) ─────────────────
#include "Config/adVisualTheme.mqh"       // Costanti colore — primo!
#include "Config/adEnums.mqh"             // Enum + CycleRecord struct
#include "Config/adEngineInterface.mqh"   // EngineSignal struct
#include "Config/adInputParameters.mqh"   // Input utente

// ── LAYER 1: Core infrastruttura ───────────────────────────────────
#include "Core/adGlobalVariables.mqh"     // g_systemState, g_cycles[], ecc.
#include "Utilities/adHelpers.mqh"        // AdLog(), PipToPoints(), ecc.

// ── LAYER 2: Engine DPC (dipende da: adEnums, adEngineInterface) ───
#include "Engine/adDPCPresets.mqh"
#include "Engine/adDPCBands.mqh"
#include "Engine/adDPCFilters.mqh"
#include "Engine/adDPCCooldown.mqh"
#include "Engine/adDPCLTFEntry.mqh"
#include "Engine/adDPCEngine.mqh"         // orchestratore — incluso per ultimo

// ── LAYER 3: Broker + sessioni (dipende da: adHelpers) ─────────────
#include "Core/adBrokerValidation.mqh"
#include "Core/adSessionManager.mqh"

// ── LAYER 4: Orders & Risk (dipende da: adEnums, adGlobalVariables) ─
#include "Orders/adATRCalculator.mqh"
#include "Orders/adRiskManager.mqh"
#include "Orders/adOrderManager.mqh"
#include "Orders/adCycleManager.mqh"

// ── LAYER 5: Filtri aggiuntivi ─────────────────────────────────────
#include "Filters/adHTFFilter.mqh"
#include "Virtual/adVirtualTrader.mqh"

// ── LAYER 6: Persistence ───────────────────────────────────────────
#include "Persistence/adStatePersistence.mqh"
#include "Persistence/adRecoveryManager.mqh"

// ── LAYER 7: UI (dipende da tutto — inclusa per ultima) ─────────────
#include "UI/adDashboard.mqh"
#include "UI/adControlButtons.mqh"
#include "UI/adChannelOverlay.mqh"
#include "UI/adSignalMarkers.mqh"
```

---

## 5. ENGINE INTERFACE — IL CONTRATTO IMMUTABILE

```cpp
// Config/adEngineInterface.mqh
// ══════════════════════════════════════════════════════════════
// Per swappare engine (DPC → ATR Bands → LuxAlgo):
//   1. Crea Engine/adATRBandsEngine.mqh (+ sottomoduli)
//   2. Implementa le 3 funzioni del contratto
//   3. Cambia 6 righe #include in AcquaDulza.mq5
//   ZERO modifiche a: UI, Orders, Persistence, Core
// ══════════════════════════════════════════════════════════════

struct EngineSignal
{
   // Segnale
   int      direction;        // +1=BUY · -1=SELL · 0=nessuno
   int      quality;          // 3=TBS (forte) · 1=TWS (debole) · 0=nessuno
   bool     isNewSignal;      // true solo sulla barra dove scatta (anti-duplicato)

   // Prezzi
   double   entryPrice;       // Punto di ingresso suggerito
   double   tpPrice;          // Take profit (midline DPC)
   double   slPrice;          // Stop loss suggerito (banda opposta)
   double   bandLevel;        // Banda toccata (lower=BUY, upper=SELL)

   // Canale completo (per dashboard e overlay)
   double   upperBand;
   double   midline;
   double   lowerBand;
   double   channelWidthPip;

   // Regime
   bool     isFlat;           // true = regime ranging — segnali attivi
   int      ltfConfirm;       // +1/-1/0 — conferma LTF (Buffer 20)
   datetime barTime;          // Timestamp bar[1]
};

// ── Le 3 funzioni del contratto ──────────────────────────────
bool  EngineInit();
void  EngineDeinit();
bool  EngineCalculate(EngineSignal &sig);
// EngineCalculate():
//   - Legge bar[1] (anti-repaint assoluto)
//   - Popola TUTTI i campi di sig
//   - Ritorna true se sig.direction != 0 (segnale valido)
//   - Ritorna false se nessun segnale (sig.direction = 0, bande aggiornate)
```

---

## 6. DETTAGLIO MODULI ENGINE DPC

### 6.1 — `adDPCPresets.mqh` (~100r)
**Responsabilità**: Inizializza i parametri effettivi per il TF corrente.
**Funzione unica**: `bool DPCPresetsInit()`

```
switch(Period())
  PERIOD_M5:  dcLen=20, maLen=25, minWidth=7.0, flatLook=3, flatTol=0.40, nSame=3, nOpp=2
  PERIOD_M15: dcLen=20, maLen=30, minWidth=8.0, flatLook=3, flatTol=0.50, nSame=3, nOpp=2
  PERIOD_M30: dcLen=20, maLen=30, minWidth=9.0, flatLook=3, flatTol=0.50, nSame=4, nOpp=2
  PERIOD_H1:  dcLen=20, maLen=35, minWidth=12.0, flatLook=4, flatTol=0.38, nSame=4, nOpp=3
  PERIOD_H4:  dcLen=20, maLen=40, minWidth=18.0, flatLook=5, flatTol=0.35, nSame=5, nOpp=3
  default (MANUAL): usa i valori da input
```
Se `InpEngineAutoTFPreset=true` → usa preset. Se false → usa tutti gli input direttamente.
Scrive su: `g_dpc_dcLen`, `g_dpc_maLen`, `g_dpc_minWidth`, `g_dpc_flatLook`, `g_dpc_flatTol`, `g_dpc_nSame`, `g_dpc_nOpp`

### 6.2 — `adDPCBands.mqh` (~150r)
**Responsabilità**: Calcola bande Donchian e EMA ATR. Math puro, nessuna logica segnale.

```
void DPCBandsCalculate(int bar, int total,
    const double &high[], const double &low[], const double &close[],
    const double &atrValues[], double &emaATR[],
    double &dcHi, double &dcLo, double &dcMid)
```
- Loop su `g_dpc_dcLen` barre per max(high) e min(low)
- `dcMid = (dcHi + dcLo) / 2`
- EMA ATR manuale (seed con SMA su prime 200 barre)
- Nessuna variabile globale — tutto passato per parametro

### 6.3 — `adDPCFilters.mqh` (~200r)
**Responsabilità**: 3 filtri indipendenti.

```cpp
// Filtro 1: Flatness
bool CheckFlatness(double dcHi, double dcLo, double dcMid,
    const double &close[], int bar, int total, double &atr)
// Usa LinearRegressionSlope su g_dpc_flatLook barre
// Soglia: |slope| < g_dpc_flatTol * atr
// Ritorna: true = piatto (segnali ammessi)

// Filtro 2: MA Filter (BUG FIX CRITICO v7.18→v3)
// ORIGINALE: if(false && InpSignalFilter)  ← dead code!
// CORRETTO:  if(i > 0 && InpMAFilterMode != MAFILTER_DISABLED)
bool CheckMAFilter(double close_bar1, double ma_bar1, int direction)
// direction=+1: BUY ammesso solo se close > MA (o DISABLED)
// direction=-1: SELL ammesso solo se close < MA (o DISABLED)

// Filtro 3: Channel Width
bool CheckChannelWidth(double dcHi, double dcLo)
// Ritorna: (dcHi - dcLo) / _Point / 10 >= g_dpc_minWidth

// Helpers math
double LinearRegressionSlope(const double &src[], int bar, int len, int total)
double ManualWMA(const double &src[], int bar, int period, int total)
```

### 6.4 — `adDPCCooldown.mqh` (~120r)
**Responsabilità**: SmartCooldown — impedisce segnali ridondanti nello stesso trend.

```cpp
// Stato interno (variabili globali g_dpc_*)
// g_dpc_lastDir, g_dpc_midlineTouched, g_dpc_midlineTouchBar
// g_dpc_lastMarkerBar

bool CheckSmartCooldown(int newDirection, double mid, double close_bar1, int currentBar)
// Logica:
// 1. Stesso verso dell'ultimo segnale?
//    → attendi g_dpc_nSame barre dall'ultimo segnale
// 2. Verso opposto?
//    → attendi g_dpc_nOpp barre E midline_touched=true
// 3. Prima volta (g_dpc_lastDir==0)?
//    → sempre ammesso
// Ritorna: true = cooldown OK (segnale ammesso)

void CooldownUpdateMidlineTouch(double mid, double close_bar1, int bar)
// Chiamato ogni barra: aggiorna g_dpc_midlineTouched

void CooldownOnSignal(int direction, int bar)
// Chiamato quando segnale confermato: reset contatori
```

### 6.5 — `adDPCLTFEntry.mqh` (~130r)
**Responsabilità**: LTF Entry Signal — conferma anticipata della rejection su timeframe inferiore.

```cpp
// Mapping auto TF: M5→M1, M15→M5, M30→M5, H1→M15, H4→M30
ENUM_TIMEFRAMES GetLTFTimeframe()

// Apertura finestra quando Touch Trigger emette segnale (bar[1])
void LTFOpenWindow(int direction, double bandLevel, datetime barTime)

// Check ogni barra: conferma su prima bar LTF chiusa (shift=1)
int LTFCheckConfirmation()
// Ritorna: +1=BUY confermato, -1=SELL confermato, 0=nessuno

// Reset finestra se scaduta (> 1 barra del TF principale)
void LTFCheckExpiry()
```

### 6.6 — `adDPCEngine.mqh` (~200r)
**Responsabilità**: Orchestratore. Chiama i 5 moduli nell'ordine corretto, popola `EngineSignal`.

```cpp
bool EngineInit()
// 1. DPCPresetsInit()
// 2. Crea handle iATR(14), iMA (secondo tipo), iMA per HMA se necessario
// 3. Valida handles (INVALID_HANDLE → errore)
// 4. g_engineReady = true

void EngineDeinit()
// Rilascia tutti gli handle iATR, iMA

bool EngineCalculate(EngineSignal &sig)
// A. Copy ATR buffer, Copy MA buffer → gestisce fallback su prev_calculated
// B. Legge bar[1]: high[], low[], close[], time[]
// C. DPCBandsCalculate() → dcHi, dcLo, dcMid
// D. Controlla larghezza: CheckChannelWidth() → se NO, sig.direction=0, popola bande, return false
// E. CheckFlatness() → se non piatto, sig.isFlat=false
// F. DetectTouchTrigger():
//    - BAR_CLOSE: close[1] <= dcLo[1] → BUY candidate, close[1] >= dcHi[1] → SELL candidate
//    - Applica MinLevelAge (band age check)
//    - Applica TrendContext (midline direction)
// G. Se segnale trovato:
//    - CheckSmartCooldown() → se NO, return false
//    - CheckMAFilter() → se NO, return false
//    - ClassifySignal() → TBS (corpo sfonda) o TWS (solo wick)
//    - LTFOpenWindow() (se InpUseLTFEntry)
// H. Se InpUseLTFEntry: LTFCheckConfirmation() → aggiorna sig.ltfConfirm
// I. Popola sig completo (tutti i campi)
// J. CooldownOnSignal() se segnale valido
// K. return (sig.direction != 0)
```

---

## 7. VISUAL THEME — PALETTE OCEAN MQL5

```cpp
// Config/adVisualTheme.mqh
// ── Sfondi ────────────────────────────────────────────────────────
#define AD_BG_DEEP         C'3,8,15'        // Ocean abyss — sfondo chart
#define AD_BG_PANEL        C'9,21,37'       // Panel dark
#define AD_BG_SECTION_A    C'13,30,53'      // Sezioni alternate A (titolo, DPC, cicli)
#define AD_BG_SECTION_B    C'18,35,60'      // Sezioni alternate B (status, signals, P&L)

// ── Bordi ─────────────────────────────────────────────────────────
#define AD_BORDER          C'30,61,92'      // Bordo pannello
#define AD_BORDER_GLOW     C'42,85,128'     // Bordo attivo / hover

// ── Accent — Bioluminescenza ───────────────────────────────────────
#define AD_BIOLUM          C'0,212,255'     // Cyan — accent principale
#define AD_BIOLUM_DIM      C'0,136,170'     // Cyan smorzato

// ── Segnali ───────────────────────────────────────────────────────
#define AD_BUY             C'0,232,176'     // Acquamarina — BUY/profit
#define AD_BUY_DIM         C'0,122,92'      // BUY smorzato
#define AD_SELL            C'255,77,109'    // Corallo — SELL/loss
#define AD_SELL_DIM        C'136,34,68'     // SELL smorzato
#define AD_AMBER           C'255,179,71'    // Ambra marina — warning/TWS
#define AD_AMBER_DIM       C'136,85,0'

// ── Testo ─────────────────────────────────────────────────────────
#define AD_TEXT_HI         C'221,238,255'   // Testo principale
#define AD_TEXT_MID        C'122,154,184'   // Testo secondario
#define AD_TEXT_LO         C'42,74,101'     // Testo disabilitato

// ── Stato ─────────────────────────────────────────────────────────
#define AD_STATE_OK        AD_BUY
#define AD_STATE_WARN      AD_AMBER
#define AD_STATE_ERR       AD_SELL
#define AD_STATE_INFO      AD_BIOLUM
#define AD_STATE_INACTIVE  AD_TEXT_MID

// ── Candele chart ─────────────────────────────────────────────────
#define AD_CANDLE_BULL     C'0,196,122'
#define AD_CANDLE_BEAR     C'220,50,80'

// ── Overlay canale ────────────────────────────────────────────────
#define AD_CHAN_UPPER_CLR   AD_SELL_DIM
#define AD_CHAN_LOWER_CLR   AD_BUY_DIM
#define AD_CHAN_MID_CLR     AD_BIOLUM_DIM

// ── Z-Order ───────────────────────────────────────────────────────
#define AD_ZORDER_RECT     15000
#define AD_ZORDER_LABEL    16000
#define AD_ZORDER_BTN      16001

// ── Font ──────────────────────────────────────────────────────────
#define AD_FONT_MONO       "Consolas"
#define AD_FONT_TITLE      "Arial Black"
#define AD_FONT_SECTION    "Arial Bold"
#define AD_FONT_SIZE       9
#define AD_FONT_SIZE_TITLE 16
#define AD_FONT_SIZE_SEC   10

// ── ApplyChartTheme() ─────────────────────────────────────────────
void ApplyChartTheme()
{
    ChartSetInteger(0, CHART_COLOR_BACKGROUND,   AD_BG_DEEP);
    ChartSetInteger(0, CHART_COLOR_FOREGROUND,   AD_TEXT_HI);
    ChartSetInteger(0, CHART_COLOR_GRID,         C'18,36,55');
    ChartSetInteger(0, CHART_COLOR_CANDLE_BULL,  AD_CANDLE_BULL);
    ChartSetInteger(0, CHART_COLOR_CANDLE_BEAR,  AD_CANDLE_BEAR);
    ChartSetInteger(0, CHART_COLOR_CHART_UP,     AD_CANDLE_BULL);
    ChartSetInteger(0, CHART_COLOR_CHART_DOWN,   AD_CANDLE_BEAR);
    ChartSetInteger(0, CHART_COLOR_ASK,          AD_BUY);
    ChartSetInteger(0, CHART_COLOR_BID,          AD_SELL);
    ChartSetInteger(0, CHART_SHOW_GRID,          false);
    ChartSetInteger(0, CHART_SHOW_VOLUMES,       CHART_VOLUME_HIDE);
}
```

---

## 8. DASHBOARD — SPECIFICHE COMPLETE

La dashboard replica il pattern Carneval (`DashRectangle` + `DashLabel`) con prefisso `AD_` al posto di `CARN_`.

### Costanti dimensionamento

```cpp
#define AD_DASH_X          10
#define AD_DASH_Y          25
#define AD_DASH_W          640
#define AD_LINE_H          18
#define AD_PAD             14
#define AD_GAP             4       // spazio tra pannelli (bg chart visibile)

// Altezze pannelli
#define AD_H_TITLE         62      // EA name + symbol + tf
#define AD_H_STATUS        70      // System state + market info
#define AD_H_ENGINE        88      // DPC bands + regime + width
#define AD_H_FILTERS       26      // Filter bar compatta
#define AD_H_SIGNALS       80      // Last 2 signals
#define AD_H_CYCLES        (28 + 5 * 16 + 4)   // Cicli attivi tabella
#define AD_H_PL            88      // P&L sessione
#define AD_H_MARKET        46      // ATR + equity + float
#define AD_H_CONTROLS      90      // 4 pulsanti + stato testo
```

### Sezioni pannello sinistro (dall'alto)

**TITLE** — `AD_BG_SECTION_A` — `AD_BIOLUM` titolo grande
```
🌊 ACQUADULZA                              v1.0.0
DPC Engine · XAUUSD · M15
```

**SYSTEM STATUS** — `AD_BG_SECTION_B`
```
SYSTEM STATUS                              ● ACTIVE
Mode:  TRIGGER | Symbol: XAUUSD | Spread: 1.8 pip | Lot: 0.02
Session: LONDON | Server: 14:37 | Magic: 88401
```

**DPC ENGINE** — `AD_BG_SECTION_A`
```
DPC ENGINE                                  ACTIVE
Upper: 2661.40    Mid: 2651.80    Lower: 2642.20
Width: 19.2 pip   ──────────────  Trend: BULLISH
Active filters: 5/6 | EMA_ATR: 13.8 pip
```

**FILTER BAR** — `AD_BG_SECTION_A` (linea compatta)
```
[Flat ✓] [Width ✓] [MA EMA] [Age ✓] [TWS hid] [London ✓]
```

**SIGNALS & CHANNEL** — `AD_BG_SECTION_B`
```
SIGNALS & CHANNEL                  BUY: 4 | SELL: 3 | Tot: 7
Last BUY:  2642.20 → TP 2651.80   14:35  TBS  LTF✓
Last SELL: 2661.40 → TP 2651.80   14:22  TWS  filtered
```

**ACTIVE CYCLES** — `AD_BG_SECTION_A`
```
ACTIVE CYCLES                              2 / 3
#01  BUY  TRIG-LIVE  2642.20          P/L: +$68.40
#02  BUY  TRIG-LIVE  2642.80          P/L: +$22.10
```

**P&L SESSION** — `AD_BG_SECTION_B`
```
P&L SESSION
Trades:  +$247.30  (W:5  L:2)
Winrate: 71%  TBS: 83%  |  Max DD: -$38  (1.9%)
Float:   +$90.50 open
```

**MARKET** — `AD_BG_SECTION_A`
```
MARKET
ATR: 14.2 pip | Bal: $20 000 | Eq: $20 247      Float: +$90.50
Session: LONDON | Server: 14:37:22
```

**CONTROLS** — `AD_BG_SECTION_B`
```
CONTROLS
[▶ START]     [⏸ PAUSE]     [↺ RECOVERY]     [■ STOP]
Auto-save: 47s ago | VirtualMode: OFF
```

### Pannello laterale — ENGINE MONITOR (a destra del pannello principale)
```
ENGINE MONITOR
DPC Engine     ACTIVE
ATR(14)        14.2 pip
EMA ATR(200)   13.8 pip
Spread         1.8 pip ✓
TF Preset      M15 auto
DC Period      20
MA EMA(30)     2648.2
SmartCD        ON S3/O2
LTF Entry      M5 ✓
──────────────────────
Bal    20 000
Eq     20 247   ← verde
DD     0.0%
──────────────────────
Sig    B:4 S:3 Tot:7
```

---

## 9. INPUT PARAMETERS COMPLETI

```
════════════════════════════════════════
  🌊 ACQUADULZA EA  v1.0.0
════════════════════════════════════════

  ─── ⚙  SYSTEM ─────────────────────────────────────────
  EnableSystem          bool      true
  MagicNumber           int       88401
  Slippage              int       3
  VirtualMode           bool      false

  ─── 🔷 ENGINE · DONCHIAN CHANNEL ──────────────────────
  EngineAutoTFPreset    bool      true
  InpLenDC              int       20
  InpTriggerMode        enum      BAR_CLOSE   // ▸ BAR_CLOSE | INTRABAR
  InpMAType             enum      EMA         // ▸ SMA | EMA | WMA | HMA
  InpMAFilterMode       enum      DISABLED    // ▸ DISABLED | ABOVE | BELOW | BOTH
  InpMALen              int       30
  InpMinWidthPips       double    8.0
  InpFlatLookback       int       3
  InpFlatnessTolerance  double    0.55
  InpShowTWSSignals     bool      true

  ─── 🔁 SMART COOLDOWN ──────────────────────────────────
  InpNSameBars          int       3
  InpNOppositeBars      int       2
  InpMinLevelAge        int       3

  ─── 📡 LTF ENTRY SIGNAL ────────────────────────────────
  InpUseLTFEntry        bool      false
  InpLTFOnlyTBS         bool      true

  ─── 💰 RISK MANAGEMENT ─────────────────────────────────
  RiskMode              enum      RISK_PCT    // ▸ FIXED_LOT | RISK_PCT | FIXED_CASH
  LotSize               double    0.01
  RiskPercent           double    1.0
  MaxConcurrentTrades   int       3
  MaxSpreadPips         double    3.0
  DailyLossLimit        double    2.0

  ─── 📈 TRADE PARAMETERS ────────────────────────────────
  EntryMode             enum      MARKET      // ▸ MARKET | LIMIT | STOP
  LimitOffsetPips       double    2.0
  SLMode                enum      BAND        // ▸ BAND_OPPOSITE | ATR_MULT | FIXED_PIPS
  SLValue               double    1.5
  TPMode                enum      MIDLINE     // ▸ MIDLINE | ATR_MULT | FIXED_PIPS
  TPValue               double    2.0
  UseHedge              bool      false

  ─── 🌍 SESSION FILTER ──────────────────────────────────
  EnableSessionFilter   bool      true
  SessionLondon         bool      true
  SessionNewYork        bool      true
  SessionAsian          bool      false
  BlockedTimeStart      string    "00:00"
  BlockedTimeEnd        string    "00:00"

  ─── 📊 MTF DIRECTION FILTER ────────────────────────────
  UseHTFFilter          bool      false
  HTFTimeframe          enum      H1          // ▸ H1 | H4 | D1
  HTFPeriod             int       20

  ─── 🎨 VISUAL ──────────────────────────────────────────
  ShowChannelOverlay    bool      true
  ShowSignalArrows      bool      true
  ShowTPTargetLines     bool      true
  ColTBS_Buy            color     C'0,232,176'
  ColTBS_Sell           color     C'255,77,109'
  ColTWS_Buy            color     C'0,122,92'
  ColTWS_Sell           color     C'136,34,68'
  DashboardCorner       enum      TOP_LEFT

  ─── 🔧 ADVANCED ────────────────────────────────────────
  ClearStateOnRemove    bool      true
  EnableAutoSave        bool      true
  EnableDebugMode       bool      false
```

---

## 10. FLUSSO COMPLETO OnTick()

```
OnTick()
│
├─ [500ms throttle]
│   ├─ UpdateDashboard()
│   └─ (se overlay) UpdateChannelLiveEdge()
│
├─ [gate] systemState != STATE_ACTIVE → return
├─ [gate] !g_engineReady              → return
├─ [gate] !IsNewBar()                 → return   ← anti-repaint assoluto
│
├─ UpdateATR()
├─ (se SessionFilter) IsWithinSession() → HandleSessionEnd() se fuori
│
├─ EngineCalculate(sig)               ← popola EngineSignal da bar[1]
│
├─ (se InpShowChannelOverlay) UpdateChannelOverlay(sig)
│
└─ se sig.direction != 0 AND sig.isNewSignal:
    ├─ CheckSpreadFilter()            ← GetSpreadPips() <= MaxSpreadPips?
    ├─ CheckDailyLossLimit()          ← giornata ancora entro limite?
    ├─ CheckMaxConcurrentTrades()     ← cicli attivi < MaxConcurrentTrades?
    ├─ CheckHTFFilter(sig.direction)  ← direzione compatibile con HTF? (se attivo)
    ├─ CheckQualityFilter(sig)        ← TBS-only? LTF confirm required?
    │
    ├─ se VirtualMode:
    │   └─ VirtualTraderOpenTrade(sig)
    └─ se !VirtualMode:
        ├─ CreateCycle(sig)
        ├─ RiskCalcLot(sig) → lot
        ├─ OrderPlace(sig, lot)
        └─ DrawSignalMarker(sig)

→ UpdateActiveCycles()    ← poll TP/SL, aggiorna P&L display
→ PollOrderFills()        ← backup detection (copertura OnTradeTransaction)
→ CheckCircuitBreaker()   ← daily loss % o max hedge → STATE_PAUSED
```

---

## 11. REGOLE NON NEGOZIABILI

| # | Regola | Conseguenza se violata |
|---|--------|----------------------|
| 1 | `AcquaDulza.mq5` non contiene logica — solo chiamate | Impossibilità di manutenzione |
| 2 | Segnali solo su `bar[1]` — mai `bar[0]` nel calcolo segnale | Repainting |
| 3 | Un solo handle ATR — gestito da `adATRCalculator.mqh` | Memory leak / conflitti |
| 4 | `EngineSignal` è l'unico canale Engine→Framework | Accoppiamento engine-specifico |
| 5 | Dashboard legge solo `DashboardData` struct — mai variabili engine dirette | Dashboard non funziona con altro engine |
| 6 | Ogni `.mqh` ha `*Init()` e `*Deinit()` — gestisce i propri handle | Memory leak su rimozione EA |
| 7 | Auto-save ogni 60s obbligatorio | Perdita stato su crash MT5 |
| 8 | Recovery obbligatorio a ogni `OnInit()` | Posizioni orfane dopo riavvio |
| 9 | VirtualMode esegue tutta la logica — salta solo `OrderSend()` | Paper trading non rappresentativo |
| 10 | Nessun magic number hardcoded — tutto via input o `#define AD_C_*` | Conflitti multi-EA |

---

## 12. STATE MACHINE

```
OnInit() ──► INITIALIZING
                │
           [validazioni OK]
                │
              IDLE ◄──────────────── [■ STOP button]
                │
           [▶ START button]
                │
             ACTIVE ◄──────────────── [↺ RECOVERY]
                │
       [⏸ PAUSE / circuit break / daily limit]
                │
             PAUSED
                │
          [errore grave]
                │
             ERROR
```

---

## 13. FASI DI SVILUPPO PER CLAUDE CODE

Claude Code riceverà questo documento + `Carneval.mq5` + tutti i `.mqh` di Carneval + `DonchianPredictiveChannel0404.mq5`.

### FASE 1 — Config Layer (~2h)
File da creare: `adVisualTheme.mqh`, `adEnums.mqh`, `adEngineInterface.mqh`, `adInputParameters.mqh`
- Estrarre enum da DPC0404 righe 316-420
- Portare stile sezioni da `carnInputParameters.mqh`
- Definire `CycleRecord` struct in `adEnums.mqh`
- Implementare palette Ocean in `adVisualTheme.mqh`

### FASE 2 — Core Layer (~1h)
File da creare: `adGlobalVariables.mqh`, `adHelpers.mqh`, `adBrokerValidation.mqh`, `adSessionManager.mqh`
- `AdLog()` macro: `AdLog(level, category, message)`
- `IsNewBar()` con static datetime
- Portare `ParseTimeToMinutes()` e `IsInBlockedTime()` da DPC0404

### FASE 3 — DPC Engine (il lavoro più lungo, ~5h)
File da creare: `adDPCPresets.mqh`, `adDPCBands.mqh`, `adDPCFilters.mqh`, `adDPCCooldown.mqh`, `adDPCLTFEntry.mqh`, `adDPCEngine.mqh`
- **Priorità assoluta**: il MA filter dead code fix (`if(false &&` → `if(i>0 &&`)
- Estrarre math puro in `adDPCBands.mqh` (no side effects, no globals — tutto per parametro)
- Estrarre SmartCooldown come macchina a stati autonoma
- Implementare contratto `EngineCalculate()` che popola `EngineSignal` su bar[1]
- **Verificare**: segnali solo su bar[1], nessun calcolo su bar[0]

### FASE 4 — Orders Layer (~2h)
File da creare: `adATRCalculator.mqh`, `adRiskManager.mqh`, `adOrderManager.mqh`, `adCycleManager.mqh`
- `RiskCalcLot()`: 3 modalità (FIXED/RISK_PCT/FIXED_CASH)
- `OrderPlace()`: 3 modalità entry (MARKET/LIMIT/STOP)
- Circuit breaker in `adRiskManager.mqh`

### FASE 5 — Persistence (~1h)
File da creare: `adStatePersistence.mqh`, `adRecoveryManager.mqh`
- GlobalVariables con prefisso `AD_STATE_{Symbol}_{Magic}_`
- Recovery: scan `PositionsTotal()` per magic number

### FASE 6 — Filtri aggiuntivi (~1h)
File da creare: `adHTFFilter.mqh`, `adVirtualTrader.mqh`

### FASE 7 — UI (~3h)
File da creare: `adDashboard.mqh`, `adControlButtons.mqh`, `adChannelOverlay.mqh`, `adSignalMarkers.mqh`
- Replica pattern `DashRectangle()` + `DashLabel()` da Carneval — cambio prefisso `CARN_` → `AD_`
- Sostituire colori Arlecchino con palette Ocean
- `DashboardData` struct populata da framework prima di chiamare `UpdateDashboard()`
- 4 pulsanti: START/PAUSE/RECOVERY/STOP — replica `carnControlButtons.mqh`

### FASE 8 — Stub `AcquaDulza.mq5` + Wire-up (~1h)
- OnInit con ordine include esatto (Sezione 4 di questo documento)
- OnTick con flusso esatto (Sezione 10)
- OnDeinit, OnTimer, OnTradeTransaction, OnChartEvent

### FASE 9 — Backtest visivo e verifica (~1h)
- Compilazione senza errori
- Backtest M15 XAUUSD: verificare frecce TBS/TWS, TP lines, dashboard
- Verificare: nessun segnale su bar[0], recovery funziona dopo riavvio MT5

---

## 14. NOTA SULLE FRECCE SEGNALE E GRAFICA CHART

L'indicatore originale DPC0404 usava:
1. `OBJ_ARROW` (buffer DRAW_ARROW) per frecce principali
2. `OBJ_ARROW` sovrapposto per tooltip
3. `DRAW_COLOR_CANDLES` per candele trigger gialle

In AcquaDulza EA:
1. **Frecce segnale**: `OBJ_ARROW` con codici ASCII — ▲ (code 241) per BUY, ▼ (code 242) per SELL
   - TBS: `AD_BUY` (acquamarina) / `AD_SELL` (corallo) — dimensione 3
   - TWS: `AD_BUY_DIM` / `AD_SELL_DIM` — dimensione 2 (se `InpShowTWSSignals=true`)
2. **TP Line**: `OBJ_HLINE` tratteggiata (`STYLE_DASH`) con `AD_BIOLUM_DIM`
3. **Entry dot**: `OBJ_ARROW` code 159 (●) a prezzo di ingresso
4. **Trigger candle highlight**: `OBJ_RECTANGLE` sottilissimo (1px) in giallo `AD_AMBER` sulla candle di trigger
5. **Nome oggetti**: `AD_SIG_{direction}_{barTime}`, `AD_TP_{n}`, `AD_ENT_{n}`
6. **Cleanup**: `DestroyAllMarkers()` in `OnDeinit()` + `DeleteOldMarkers()` per storia > 500 barre

---

## APPENDICE A — Dipendenze tra moduli

```
adVisualTheme.mqh   ← nessuna dipendenza
adEnums.mqh         ← nessuna
adEngineInterface.mqh ← nessuna
adInputParameters.mqh ← adEnums.mqh
adGlobalVariables.mqh ← adEnums.mqh, adEngineInterface.mqh
adHelpers.mqh        ← adGlobalVariables.mqh
adDPCPresets.mqh     ← adEnums.mqh, adGlobalVariables.mqh
adDPCBands.mqh       ← adGlobalVariables.mqh
adDPCFilters.mqh     ← adDPCBands.mqh
adDPCCooldown.mqh    ← adGlobalVariables.mqh
adDPCLTFEntry.mqh    ← adGlobalVariables.mqh, adDPCBands.mqh
adDPCEngine.mqh      ← TUTTI i moduli Engine sopra + adEngineInterface.mqh
adBrokerValidation.mqh ← adHelpers.mqh
adSessionManager.mqh ← adHelpers.mqh
adATRCalculator.mqh  ← adGlobalVariables.mqh
adRiskManager.mqh    ← adATRCalculator.mqh, adHelpers.mqh
adOrderManager.mqh   ← adRiskManager.mqh, adGlobalVariables.mqh
adCycleManager.mqh   ← adOrderManager.mqh, adEngineInterface.mqh
adHTFFilter.mqh      ← adGlobalVariables.mqh
adVirtualTrader.mqh  ← adCycleManager.mqh
adStatePersistence.mqh ← adGlobalVariables.mqh, adCycleManager.mqh
adRecoveryManager.mqh ← adStatePersistence.mqh, adOrderManager.mqh
adDashboard.mqh      ← adVisualTheme.mqh, adGlobalVariables.mqh, adEngineInterface.mqh
adControlButtons.mqh ← adDashboard.mqh, adGlobalVariables.mqh
adChannelOverlay.mqh ← adVisualTheme.mqh, adEngineInterface.mqh
adSignalMarkers.mqh  ← adVisualTheme.mqh, adEngineInterface.mqh
```

## APPENDICE B — Dimensioni stimate file Engine DPC

| File | Righe stimate | Sorgente in DPC0404 |
|------|--------------|-------------------|
| `adDPCPresets.mqh` | ~100r | OnInit righe 1253–1380 |
| `adDPCBands.mqh` | ~150r | OnCalculate sezione core band loop |
| `adDPCFilters.mqh` | ~200r | OnCalculate sezioni 1-3 + righe 1805-1891 |
| `adDPCCooldown.mqh` | ~120r | OnCalculate sezione 4 (cooldown) |
| `adDPCLTFEntry.mqh` | ~130r | OnCalculate sezione 5c (righe 4256-4425) |
| `adDPCEngine.mqh` | ~200r | Orchestratore + EngineInit/Deinit/Calculate |
| **Totale Engine** | **~900r** | (era 3200+ righe in un solo file) |

**Da 3200 righe in 1 file → 900 righe in 6 file** — manutenzione reale.
