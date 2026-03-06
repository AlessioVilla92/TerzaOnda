//+------------------------------------------------------------------+
//|                                                 carnEnums.mqh    |
//|              El Carnevaal de Schignan - Enumerations              |
//|                                                                  |
//|  All system enumerations for Carneval EA v3.40                   |
//+------------------------------------------------------------------+
#property copyright "Sugamara Ribelle (C) 2026"

//+------------------------------------------------------------------+
//| 🎭 CYCLE STATE — Stato di ogni ciclo Soup/Trigger/Hedge           |
//+------------------------------------------------------------------+
enum ENUM_CYCLE_STATE {
    CYCLE_IDLE,              // 💤 Slot disponibile
    CYCLE_SOUP_ACTIVE,       // 🍲 Soup aperta + Breakout pendente
    CYCLE_TRIGGER_PENDING,   // ⏳ Trigger STOP pendente (non ancora fillato)
    CYCLE_TRIGGER_ACTIVE,    // 🎯 Trigger STOP fillato — posizione attiva
    CYCLE_HEDGING,           // 🛡️ Entrambe aperte (Soup + Breakout)
    CYCLE_CLOSED             // ✅ Ciclo completato
};

//+------------------------------------------------------------------+
//| ⚙️ SYSTEM STATE — Stato globale del sistema                       |
//+------------------------------------------------------------------+
enum ENUM_SYSTEM_STATE {
    STATE_INIT = 0,          // 🔧 Inizializzazione
    STATE_IDLE = 1,          // 💤 Inattivo (premi START)
    STATE_ACTIVE = 2,        // ▶️ Operativo
    STATE_PAUSED = 3,        // ⏸️ In pausa
    STATE_INITIALIZING = 4,  // 🔄 Inizializzazione in corso
    STATE_CLOSING = 5,       // ❌ Chiusura posizioni
    STATE_EMERGENCY = 90,    // 🚨 Emergency stop
    STATE_ERROR = 99         // ❗ Errore critico
};

//+------------------------------------------------------------------+
//| 🎭 TRADING MODE — Modalita' operativa EA                          |
//+------------------------------------------------------------------+
enum ENUM_TRADING_MODE {
    MODE_CLASSIC_TURTLE,     // 🍲 Classic Turtle Soup (market + breakout hedge)
    MODE_TRIGGER_INDICATOR   // 🎯 Trigger Indicator (pending STOP at signal price)
};

//+------------------------------------------------------------------+
//| 🎯 BREAKOUT TP MODE — Come calcolare TP ordine breakout           |
//+------------------------------------------------------------------+
enum ENUM_BKO_TP_MODE {
    BKO_TP_PIPS,             // 📏 TP fisso in pips
    BKO_TP_ATR,              // 📊 TP = N x ATR
    BKO_TP_OPPOSITE_BAND     // 🔄 TP alla banda opposta del canale
};

//+------------------------------------------------------------------+
//| 🎯 TRIGGER TP MODE — Come calcolare il TP in Trigger Mode        |
//+------------------------------------------------------------------+
enum ENUM_TRIGGER_TP_MODE {
    TRIGGER_TP_MIDLINE        = 0,  // 🎯 TP alla Midline Donchian (default, equilibrato)
    TRIGGER_TP_OPPOSITE_BAND  = 1,  // 🔄 TP alla banda opposta (target massimo, +rischio)
    TRIGGER_TP_OPPOSITE_TRIGGER = 2 // ⚡ TP al trigger opposto buffer 7/8 (massimo rendimento)
};

//+------------------------------------------------------------------+
//| 🛡️ HEDGE RESOLUTION MODE — Come risolvere l'hedging               |
//+------------------------------------------------------------------+
enum ENUM_HEDGE_RESOLUTION {
    HEDGE_BREAKOUT_TP_ONLY,   // 🎯 Regola 1: Breakout chiude in TP, Soup resta
    HEDGE_NET_PROFIT           // 💰 Regola 3: Chiudi entrambi a net profit >= soglia
};

//+------------------------------------------------------------------+
//| 🔮 DPC MA FILTER MODE — Modalita' filtro MA nell'indicatore        |
//+------------------------------------------------------------------+
enum ENUM_MA_FILTER_MODE {
    MA_FILTER_CLASSIC  = 0,  // 📈 Classico (BUY se close > MA — trend following)
    MA_FILTER_INVERTED = 1   // 🔄 Invertito (BUY se close < MA — mean reversion Soup)
};

//+------------------------------------------------------------------+
//| 🔮 DPC MA TYPE — Mirror dell'enum nell'indicatore                 |
//+------------------------------------------------------------------+
enum ENUM_DPC_MA_TYPE {
    DPC_MA_SMA = 0,          // 📊 SMA - Simple Moving Average
    DPC_MA_EMA = 1,          // 📈 EMA - Exponential Moving Average
    DPC_MA_WMA = 2,          // 📉 WMA - Weighted Moving Average
    DPC_MA_HMA = 3           // 🌊 HMA - Hull Moving Average
};

//+------------------------------------------------------------------+
//| 🎰 FOREX PAIR SELECTION — Coppie ottimizzate per Turtle Soup     |
//+------------------------------------------------------------------+
enum ENUM_FOREX_PAIR {
    PAIR_EURUSD,    // 🇪🇺🇺🇸 EUR/USD (Spread: 0.8-1.5, Range: 60-100 pips)
    PAIR_USDCAD,    // 🇺🇸🇨🇦 USD/CAD (Spread: 1.0-1.8, Range: 50-80 pips)
    PAIR_AUDNZD,    // 🇦🇺🇳🇿 AUD/NZD (Spread: 2-4, Range: 40-70 pips) - BEST RANGE
    PAIR_EURCHF,    // 🇪🇺🇨🇭 EUR/CHF (Spread: 1.5-2.5, Range: 35-60 pips)
    PAIR_AUDCAD,    // 🇦🇺🇨🇦 AUD/CAD (Spread: 2-3, Range: 50-80 pips)
    PAIR_NZDCAD,    // 🇳🇿🇨🇦 NZD/CAD (Spread: 2-3, Range: 45-75 pips)
    PAIR_EURGBP,    // 🇪🇺🇬🇧 EUR/GBP (Spread: 1-2, Range: 40-70 pips) - EXCELLENT
    PAIR_GBPUSD,    // 🇬🇧🇺🇸 GBP/USD (Spread: 1-2, Range: 80-120 pips)
    PAIR_USDCHF,    // 🇺🇸🇨🇭 USD/CHF (Spread: 1-2, Range: 50-70 pips)
    PAIR_USDJPY,    // 🇺🇸🇯🇵 USD/JPY (Spread: 0.8-1.5, Range: 70-120 pips)
    PAIR_EURJPY,    // 🇪🇺🇯🇵 EUR/JPY (Spread: 1.0-1.8, Range: 80-120 pips)
    PAIR_AUDUSD,    // 🇦🇺🇺🇸 AUD/USD (Spread: 0.8-1.5, Range: 60-90 pips)
    PAIR_NZDUSD,    // 🇳🇿🇺🇸 NZD/USD (Spread: 1.2-2.0, Range: 50-80 pips)
    PAIR_BTCUSD,    // ₿ BTC/USD (Crypto — Spread: $10-30, Range: $1500-3000/day) — Adjust LotSize!
    PAIR_ETHUSD,    // Ξ ETH/USD (Crypto — Spread: $0.5-2, Range: $50-150/day) — Adjust LotSize!
    PAIR_CUSTOM     // ⚙️ Custom (Impostazioni Manuali)
};

//+------------------------------------------------------------------+
//| 📋 ORDER STATUS — Stati degli ordini                              |
//+------------------------------------------------------------------+
enum ENUM_ORDER_STATUS {
    ORDER_NONE,              // ❌ Nessun ordine
    ORDER_PENDING,           // ⏳ Ordine pending piazzato
    ORDER_FILLED,            // ✅ Ordine eseguito
    ORDER_CLOSED,            // 🔒 Ordine chiuso (generico)
    ORDER_CLOSED_TP,         // 🎯 Chiuso in Take Profit
    ORDER_CLOSED_SL,         // 🛡️ Chiuso in Stop Loss
    ORDER_CANCELLED,         // 🗑️ Ordine cancellato
    ORDER_ERROR,             // ❗ Errore ordine
    ORDER_VIRTUAL_PENDING    // 🔮 Virtual Order in attesa
};

//+------------------------------------------------------------------+
//| 📊 ATR CONDITION — Condizione volatilita' basata su ATR          |
//+------------------------------------------------------------------+
enum ENUM_ATR_CONDITION {
    ATR_CALM,                   // 🟢 ATR < 15 pips - Mercato calmo
    ATR_NORMAL,                 // 🟡 ATR 15-30 pips - Condizioni normali
    ATR_VOLATILE,               // 🟠 ATR 30-50 pips - Mercato volatile
    ATR_EXTREME                 // 🔴 ATR > 50 pips - Volatilita' estrema
};

//+------------------------------------------------------------------+
//| 📝 LOG LEVEL — Livello di logging                                |
//+------------------------------------------------------------------+
enum ENUM_LOG_LEVEL {
    LOG_DEBUG,                  // 🔍 Debug - Tutto
    LOG_INFO,                   // ℹ️ Info - Informazioni generali
    LOG_WARNING,                // ⚠️ Warning - Avvisi
    LOG_ERROR,                  // ❗ Error - Errori
    LOG_SUCCESS                 // ✅ Success - Operazioni riuscite
};

//+------------------------------------------------------------------+
//| 🔮 VIRTUAL STATE (reserved for future)                            |
//+------------------------------------------------------------------+
enum ENUM_VIRTUAL_STATE {
    VSTATE_INACTIVE = 0,        // 💤 Inattivo
    VSTATE_TRIGGERED = 1,       // ⚡ Trigger superato
    VSTATE_PLACED = 2,          // 📌 Ordine piazzato
    VSTATE_FILLED = 3,          // ✅ Posizione aperta
    VSTATE_CLOSED = 4,          // 🔒 Chiuso
    VSTATE_ERROR = 5            // ❗ Errore
};

//+------------------------------------------------------------------+
//| TRIGGER STOP LOSS MODE — [v3.4]                                  |
//+------------------------------------------------------------------+
enum ENUM_TRIGGER_SL_MODE
{
    TRIGGER_SL_OPPOSITE_BAND  = 0,   // SL = banda opposta Donchian
    TRIGGER_SL_ATR_MULTIPLE   = 1,   // SL = N * ATR(14) dalla entry
    TRIGGER_SL_FIXED_PIPS     = 2,   // SL = N pips fissi
};

//+------------------------------------------------------------------+
//| CONSTANTS                                                        |
//+------------------------------------------------------------------+
const int ATR_RECALC_HOURS = 4;
