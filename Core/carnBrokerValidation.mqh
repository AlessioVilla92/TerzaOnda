//+------------------------------------------------------------------+
//|                                     carnBrokerValidation.mqh     |
//|                     Carneval EA - Broker Validation             |
//|                                                                  |
//|  Validates EA parameters against broker specifications           |
//+------------------------------------------------------------------+
#property copyright "Carneval (C) 2026"
#property link      "https://carnivalle.com"

//+------------------------------------------------------------------+
//| Load Broker Specifications                                       |
//| Populates global variables with broker symbol info               |
//+------------------------------------------------------------------+
bool LoadBrokerSpecifications() {
    Log_Header("LOADING BROKER SPECIFICATIONS");

    // Symbol basic info
    symbolPoint = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    symbolDigits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

    if(symbolPoint <= 0) {
        Log_SystemError("Broker", 0, StringFormat("Invalid symbol point: %f", symbolPoint));
        return false;
    }

    // Stop levels
    symbolStopsLevel = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
    symbolFreezeLevel = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);

    // Lot specifications
    symbolMinLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    symbolMaxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    symbolLotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

    // Current spread
    symbolSpreadPoints = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);

    // Validation
    if(symbolMinLot <= 0) {
        Log_SystemError("Broker", 0, StringFormat("Invalid min lot: %f", symbolMinLot));
        return false;
    }

    if(symbolLotStep <= 0) {
        Log_SystemError("Broker", 0, StringFormat("Invalid lot step: %f", symbolLotStep));
        return false;
    }

    // Log specifications
    Log_KeyValue("Symbol", _Symbol);
    Log_KeyValueNum("Point", symbolPoint, symbolDigits);
    Log_KeyValueNum("Digits", symbolDigits, 0);
    Log_KeyValueNum("Stops Level", symbolStopsLevel, 0);
    Log_KeyValueNum("Freeze Level", symbolFreezeLevel, 0);
    Log_KeyValueNum("Min Lot", symbolMinLot, 2);
    Log_KeyValueNum("Max Lot", symbolMaxLot, 2);
    Log_KeyValueNum("Lot Step", symbolLotStep, 2);
    Log_KeyValue("Spread", StringFormat("%d pts (%.1f pips)", symbolSpreadPoints, PointsToPips(symbolSpreadPoints * symbolPoint)));
    Log_Separator();

    return true;
}

//+------------------------------------------------------------------+
//| Validate Input Parameters                                        |
//| Checks Carneval user inputs are within acceptable ranges       |
//+------------------------------------------------------------------+
bool ValidateInputParameters() {
    Log_Header("VALIDATING INPUT PARAMETERS");

    int errors = 0;
    int warnings = 0;

    // CHECK 1: Lot Size (unico per tutte le strategie)
    if(LotSize <= 0) {
        Log_SystemError("Validation", 0, StringFormat("LotSize must be > 0 (current: %.2f)", LotSize));
        errors++;
    }
    if(LotSize < symbolMinLot) {
        Log_SystemError("Validation", 0, StringFormat("LotSize %.2f below broker min %.2f", LotSize, symbolMinLot));
        errors++;
    }
    if(LotSize > symbolMaxLot) {
        Log_SystemError("Validation", 0, StringFormat("LotSize %.2f exceeds broker max %.2f", LotSize, symbolMaxLot));
        errors++;
    }

    // CHECK 3: DPC Period
    if(DPC_Period < 5) {
        Log_SystemError("Validation", 0, StringFormat("DPC_Period must be >= 5 (current: %d)", DPC_Period));
        errors++;
    }

    // CHECK 4: Max Concurrent Cycles
    if(Max_ConcurrentCycles < 1) {
        Log_SystemError("Validation", 0, StringFormat("Max_ConcurrentCycles must be >= 1 (current: %d)", Max_ConcurrentCycles));
        errors++;
    }

    // CHECK 5: Hedge Distance Pips
    if(Hedge_Distance_Pips <= 0) {
        Log_SystemError("Validation", 0, StringFormat("Hedge_Distance_Pips must be > 0 (current: %.1f)", Hedge_Distance_Pips));
        errors++;
    }

    // CHECK 6: Hedging Mode Required
    {
        ENUM_ACCOUNT_MARGIN_MODE marginMode =
            (ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE);

        if(marginMode != ACCOUNT_MARGIN_MODE_RETAIL_HEDGING) {
            Log_SystemError("Validation", 0, StringFormat("Requires HEDGING mode (current: %s)", EnumToString(marginMode)));
            errors++;
        } else {
            Log_Debug("Validation", "Account in HEDGING mode - OK");
        }
    }

    // CHECK 7: Magic Number
    if(MagicNumber <= 0) {
        Log_SystemError("Validation", 0, StringFormat("MagicNumber must be positive (current: %d)", MagicNumber));
        errors++;
    }

    // CHECK 8: Trigger Mode parameters
    if(TradingMode == MODE_TRIGGER_INDICATOR)
    {
        if(Trigger_Offset_Pips < 0) {
            Log_SystemError("Validation", 0, StringFormat("Trigger_Offset_Pips cannot be negative (current: %.1f)", Trigger_Offset_Pips));
            errors++;
        }
        if(Trigger_Expiry_Bars < 0) {
            Log_SystemError("Validation", 0, StringFormat("Trigger_Expiry_Bars cannot be negative (current: %d)", Trigger_Expiry_Bars));
            errors++;
        }
    }

    // SUMMARY
    Log_SubHeader("VALIDATION SUMMARY");
    Log_KeyValueNum("Errors", errors, 0);
    Log_KeyValueNum("Warnings", warnings, 0);

    if(errors > 0) {
        Log_KeyValue("Result", StringFormat("FAILED - %d error(s)", errors));
        if(EnableAlerts) {
            Alert("CARNEVAL: Input validation FAILED - check Expert Log");
        }
        Log_Separator();
        return false;
    }

    if(warnings > 0) {
        Log_KeyValue("Result", StringFormat("PASSED with %d warning(s)", warnings));
    } else {
        Log_KeyValue("Result", "PASSED - All parameters valid");
    }

    Log_Separator();
    return true;
}

//+------------------------------------------------------------------+
//| Validate Broker Minimums (LOG-ONLY - Never blocks)               |
//+------------------------------------------------------------------+
bool ValidateBrokerMinimums() {
    Log_SubHeader("BROKER DISTANCE CHECK");

    double brokerStopsPips = PointsToPips(symbolStopsLevel * symbolPoint);
    double brokerFreezePips = PointsToPips(symbolFreezeLevel * symbolPoint);
    double brokerMinimum = MathMax(brokerStopsPips, brokerFreezePips);

    if(brokerMinimum < 0.1) {
        brokerMinimum = 5.0;
        Log_Debug("Broker", "No min distance from broker - using 5.0 pips default");
    }

    Log_KeyValueNum("Stops Level", brokerStopsPips, 1);
    Log_KeyValueNum("Freeze Level", brokerFreezePips, 1);
    Log_KeyValueNum("Effective Min", brokerMinimum, 1);

    // Check hedge distance against broker minimum
    if(Hedge_Distance_Pips > 0 && Hedge_Distance_Pips < brokerMinimum) {
        Log_SystemWarning("Broker", StringFormat("Hedge_Distance_Pips %.1f < broker min %.1f - orders may reject", Hedge_Distance_Pips, brokerMinimum));
    } else if(Hedge_Distance_Pips > 0) {
        Log_Debug("Broker", StringFormat("Hedge_Distance_Pips %.1f >= broker min - OK", Hedge_Distance_Pips));
    }

    Log_Separator();

    // Always return true - this is informative only
    return true;
}

//+------------------------------------------------------------------+
//| Normalize Lot Size to Broker Requirements                        |
//+------------------------------------------------------------------+
double NormalizeLotSize(double lot) {
    double originalLot = lot;

    // Apply minimum
    if(lot < symbolMinLot) {
        lot = symbolMinLot;
    }

    // Apply broker maximum
    if(lot > symbolMaxLot) {
        lot = symbolMaxLot;
    }

    // Round to lot step
    if(symbolLotStep > 0) {
        lot = MathFloor(lot / symbolLotStep) * symbolLotStep;
    }

    // Ensure lot is not zero after rounding (when symbolMinLot < symbolLotStep)
    if(lot < symbolMinLot) {
        lot = symbolMinLot;
    }

    lot = NormalizeDouble(lot, 2);

    if(MathAbs(lot - originalLot) > 0.001)
        CarnLogW(LOG_CAT_BROKER, StringFormat("Lot normalized: %.2f -> %.2f (min=%.2f max=%.2f step=%.2f)",
                 originalLot, lot, symbolMinLot, symbolMaxLot, symbolLotStep));

    return lot;
}

//+------------------------------------------------------------------+
//| Validate Take Profit Distance                                    |
//| Ensures TP is at least broker minimum distance from price        |
//+------------------------------------------------------------------+
double ValidateTakeProfit(double price, double tp, bool isBuy) {
    if(tp == 0) return 0;

    double originalTP = tp;
    double minDistance = symbolStopsLevel * symbolPoint;
    if(minDistance < symbolPoint * 10) {
        minDistance = symbolPoint * 30;  // Default 3 pips minimum
    }

    // Add safety margin
    minDistance *= 1.1;  // 10% margin

    if(isBuy) {
        // For BUY, TP must be above price
        double minTP = price + minDistance;
        if(tp < minTP) {
            tp = minTP;
        }
    } else {
        // For SELL, TP must be below price
        double maxTP = price - minDistance;
        if(tp > maxTP) {
            tp = maxTP;
        }
    }

    tp = NormalizeDouble(tp, symbolDigits);

    if(MathAbs(tp - originalTP) > symbolPoint)
        CarnLogW(LOG_CAT_BROKER, StringFormat("TP adjusted for broker distance: %s -> %s (%s, minDist=%.1fp)",
                 DoubleToString(originalTP, symbolDigits), DoubleToString(tp, symbolDigits),
                 isBuy ? "BUY" : "SELL", PointsToPips(minDistance)));

    return tp;
}

//+------------------------------------------------------------------+
//| Check if Price is Valid for Pending Order                        |
//+------------------------------------------------------------------+
bool IsValidPendingPrice(double price, ENUM_ORDER_TYPE orderType) {
    double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

    // In Strategy Tester at first tick ASK/BID can be 0
    if(currentAsk <= 0 || currentBid <= 0) {
        CarnLogD(LOG_CAT_BROKER, "ASK/BID not available yet — allowing order");
        return true;
    }

    double minDistance = symbolStopsLevel * symbolPoint;

    if(minDistance < symbolPoint * 10) {
        minDistance = symbolPoint * 30;  // 3 pips minimum
    }

    switch(orderType) {
        case ORDER_TYPE_BUY_LIMIT:
            return (price < currentAsk - minDistance);

        case ORDER_TYPE_SELL_LIMIT:
            return (price > currentBid + minDistance);

        case ORDER_TYPE_BUY_STOP:
            return (price > currentAsk + minDistance);

        case ORDER_TYPE_SELL_STOP:
            return (price < currentBid - minDistance);

        default:
            return false;
    }
}

//+------------------------------------------------------------------+
//| Get Safe Order Price - Adaptive Price Fix                        |
//| If price invalid, calculates adaptive valid price                |
//+------------------------------------------------------------------+
double GetSafeOrderPrice(double desiredPrice, ENUM_ORDER_TYPE orderType) {
    double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

    // If data not available, return original price
    if(currentAsk <= 0 || currentBid <= 0) {
        return NormalizeDouble(desiredPrice, symbolDigits);
    }

    // Calculate minimum distance from broker
    double minDistance = symbolStopsLevel * symbolPoint;
    if(minDistance < symbolPoint * 10) {
        minDistance = symbolPoint * 30;  // Minimum 3 pips
    }
    minDistance *= 1.5;  // 50% safety margin

    // Extra buffer to avoid marginal rejections
    double buffer = symbolPoint * 10;  // 1 pip extra

    double adaptivePrice = desiredPrice;
    bool priceAdjusted = false;
    string reason = "";

    switch(orderType) {
        case ORDER_TYPE_BUY_LIMIT:
            if(desiredPrice >= currentAsk - minDistance) {
                adaptivePrice = currentAsk - minDistance - buffer;
                priceAdjusted = true;
                reason = StringFormat("BUY LIMIT adjusted: %.5f -> %.5f (Ask: %.5f)",
                                      desiredPrice, adaptivePrice, currentAsk);
            }
            break;

        case ORDER_TYPE_SELL_LIMIT:
            if(desiredPrice <= currentBid + minDistance) {
                adaptivePrice = currentBid + minDistance + buffer;
                priceAdjusted = true;
                reason = StringFormat("SELL LIMIT adjusted: %.5f -> %.5f (Bid: %.5f)",
                                      desiredPrice, adaptivePrice, currentBid);
            }
            break;

        case ORDER_TYPE_BUY_STOP:
            if(desiredPrice <= currentAsk + minDistance) {
                adaptivePrice = currentAsk + minDistance + buffer;
                priceAdjusted = true;
                reason = StringFormat("BUY STOP adjusted: %.5f -> %.5f (Ask: %.5f)",
                                      desiredPrice, adaptivePrice, currentAsk);
            }
            break;

        case ORDER_TYPE_SELL_STOP:
            if(desiredPrice >= currentBid - minDistance) {
                adaptivePrice = currentBid - minDistance - buffer;
                priceAdjusted = true;
                reason = StringFormat("SELL STOP adjusted: %.5f -> %.5f (Bid: %.5f)",
                                      desiredPrice, adaptivePrice, currentBid);
            }
            break;
    }

    if(priceAdjusted) {
        double deviationPips = MathAbs(desiredPrice - adaptivePrice) / symbolPoint / 10;
        CarnLogD(LOG_CAT_BROKER, StringFormat("ADAPTIVE PRICE: %s | Deviation: %s pips",
                 reason, DoubleToString(deviationPips, 1)));
    }

    return NormalizeDouble(adaptivePrice, symbolDigits);
}
