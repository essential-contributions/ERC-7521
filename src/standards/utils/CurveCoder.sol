// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

/*
 * Encoding masks
 *   [bytes1]  flags - curve type, relative, evaluate backwards (flip), negatives [c--r fnnn]
 *   [uint32]  startAmount - starting amount
 *   [uint8]   amountMult - amount multiplier (final_amount = amount * (amountMult * 10))
 * --only for linear or exponential--
 *   [uint32]  startTime -  start time of the curve (in seconds)
 *   [uint16]  deltaTime - amount of time from start until curve caps (in seconds)
 *   [uint24]  deltaAmount - amount of change after each second
 *   [bytes1]  misc - delta amount mult, exponent [mmmm eeee]
 */
bytes16 constant MASK_FLAGS_CURVE_TYPE = 0x80000000000000000000000000000000;
bytes16 constant MASK_FLAGS_RELATIVE = 0x10000000000000000000000000000000;
bytes16 constant MASK_FLAGS_FLIP = 0x08000000000000000000000000000000;
bytes16 constant MASK_FLAGS_NEG_START_AMT = 0x04000000000000000000000000000000;
bytes16 constant MASK_FLAGS_NEG_DELTA = 0x02000000000000000000000000000000;
bytes16 constant MASK_FLAGS_NEG_DELTA_MULT = 0x01000000000000000000000000000000;
bytes16 constant MASK_START_AMOUNT = 0x00ffffffff0000000000000000000000;
bytes16 constant MASK_START_AMT_MULT = 0x0000000000ff00000000000000000000;
bytes16 constant MASK_START_TIME = 0x000000000000ffffffff000000000000;
bytes16 constant MASK_DELTA_TIME = 0x00000000000000000000ffff00000000;
bytes16 constant MASK_DELTA_AMOUNT = 0x000000000000000000000000ffffff00;
bytes16 constant MASK_DELTA_AMT_MULT = 0x000000000000000000000000000000f0;
bytes16 constant MASK_EXPONENT = 0x0000000000000000000000000000000f;
uint8 constant SHIFT_START_AMOUNT = 11 * 8;
uint8 constant SHIFT_START_AMT_MULT = 10 * 8;
uint8 constant SHIFT_START_TIME = 6 * 8;
uint8 constant SHIFT_DELTA_TIME = 4 * 8;
uint8 constant SHIFT_DELTA_AMOUNT = 1 * 8;
uint8 constant SHIFT_DELTA_AMT_MULT = 4;
uint8 constant SHIFT_EXPONENT = 0;

/**
 * Encodes the parameters into a constant curve
 * @param amount the amount to encode
 * @param isRelative indicate the curve is to be evaluated relatively
 * @return encoding the parameter encoding
 */
function encodeConstantCurve(int256 amount, bool isRelative) pure returns (bytes6) {
    //convert params
    uint256 adjustedAmount;
    bool amountNegative;
    if (amount < 0) {
        amountNegative = true;
        adjustedAmount = uint256(0 - amount);
    } else {
        amountNegative = false;
        adjustedAmount = uint256(amount);
    }
    uint8 amountMult = 0;
    while (adjustedAmount > 0x00000000000000000000000000000000000000000000000000000000ffffffff) {
        adjustedAmount = adjustedAmount >> 1;
        amountMult++;
    }

    //encode
    bytes16 encoding = (bytes16(uint128(adjustedAmount)) << SHIFT_START_AMOUNT)
        | (bytes16(uint128(amountMult)) << SHIFT_START_AMT_MULT);
    if (amountNegative) encoding = encoding | MASK_FLAGS_NEG_START_AMT;
    if (isRelative) encoding = encoding | MASK_FLAGS_RELATIVE;
    return bytes6(encoding);
}

/**
 * Encodes the given fileds into the complex curve parameter encoding
 * @param startTime start time of the curve (in seconds)
 * @param deltaTime amount of time from start until curve caps (in seconds)
 * @param startAmount starting amount
 * @param deltaAmount amount of change after each second
 * @param exponent the exponent order of the curve
 * @param backwards evaluate curve from right to left
 * @param isRelative indicate the curve is to be evaluated relatively
 * @return the fully encoded intent standard segment data
 */
function encodeComplexCurve(
    uint32 startTime,
    uint24 deltaTime,
    int256 startAmount,
    int256 deltaAmount,
    uint8 exponent,
    bool backwards,
    bool isRelative
) pure returns (bytes16) {
    //start encode
    bytes16 encoding = MASK_FLAGS_CURVE_TYPE | (bytes16(uint128(startTime)) << SHIFT_START_TIME)
        | (bytes16(uint128(deltaTime)) << SHIFT_DELTA_TIME) | (bytes16(uint128(exponent & 0x0f)) << SHIFT_EXPONENT);
    if (isRelative) encoding = encoding | MASK_FLAGS_RELATIVE;
    if (backwards) encoding = encoding | MASK_FLAGS_FLIP;

    //encode start amount
    uint8 startMult = 0;
    {
        uint256 adjustedStartAmount;
        bool startAmountNegative;
        if (startAmount < 0) {
            startAmountNegative = true;
            adjustedStartAmount = uint256(0 - startAmount);
        } else {
            startAmountNegative = false;
            adjustedStartAmount = uint256(startAmount);
        }
        while (adjustedStartAmount > 0x00000000000000000000000000000000000000000000000000000000ffffffff) {
            adjustedStartAmount = adjustedStartAmount >> 1;
            startMult++;
        }
        encoding |= (bytes16(uint128(adjustedStartAmount)) << SHIFT_START_AMOUNT)
            | (bytes16(uint128(startMult)) << SHIFT_START_AMT_MULT);
        if (startAmountNegative) encoding = encoding | MASK_FLAGS_NEG_START_AMT;
    }

    //encode delta amount
    {
        uint256 adjustedDeltaAmount;
        bool deltaAmountNegative;
        if (deltaAmount < 0) {
            deltaAmountNegative = true;
            adjustedDeltaAmount = uint256(0 - deltaAmount);
        } else {
            deltaAmountNegative = false;
            adjustedDeltaAmount = uint256(deltaAmount);
        }
        int256 deltaMult = 0;
        while (adjustedDeltaAmount > 0x0000000000000000000000000000000000000000000000000000000000ffffff) {
            adjustedDeltaAmount = adjustedDeltaAmount >> 1;
            deltaMult++;
        }
        if (startAmount == 0) {
            startMult = uint8(uint256(deltaMult));
            deltaMult = 0;
        } else {
            deltaMult = int256(uint256(startMult)) - deltaMult;
            require(deltaMult > -16, "delta too small in comparison to start");
            require(deltaMult < 16, "delta too large in comparison to start");
        }
        uint8 adjustedDeltaMult;
        bool deltaMultNegative;
        if (deltaMult < 0) {
            deltaMultNegative = true;
            adjustedDeltaMult = uint8(uint256(0 - deltaMult));
        } else {
            deltaMultNegative = false;
            adjustedDeltaMult = uint8(uint256(deltaMult));
        }
        encoding |= (bytes16(uint128(adjustedDeltaAmount)) << SHIFT_DELTA_AMOUNT)
            | (bytes16(uint128(adjustedDeltaMult & 0x0f)) << SHIFT_DELTA_AMT_MULT);
        if (deltaMultNegative) encoding = encoding | MASK_FLAGS_NEG_DELTA_MULT;
        if (deltaAmountNegative) encoding = encoding | MASK_FLAGS_NEG_DELTA;
    }

    return encoding;
}

/**
 * Decodes the given curve parameter encoding and evaluates it
 * @param curve the encoded parameters
 * @dev curve
 *   [bytes1]  flags - curve type, relative, evaluate backwards (flip), negatives [c--r fnnn]
 *   [uint32]  startAmount - starting amount
 *   [uint8]   amountMult - amount multiplier (final_amount = amount * (amountMult * 10))
 * --only for linear or exponential--
 *   [uint32]  startTime -  start time of the curve (in seconds)
 *   [uint16]  deltaTime - amount of time from start until curve caps (in seconds)
 *   [uint24]  deltaAmount - amount of change after each second
 *   [bytes1]  misc - delta amount mult, exponent [eeee mmmm]
 * @param solutionTimestamp the time of evaluation specified by the solution
 * @return value the evaluated value
 */
function evaluateCurve(bytes16 curve, uint256 solutionTimestamp) pure returns (int256) {
    unchecked {
        //constant curve evaluation
        if (uint128(curve & MASK_FLAGS_CURVE_TYPE) == 0) {
            uint256 amount = uint128((curve & MASK_START_AMOUNT) >> SHIFT_START_AMOUNT);
            uint256 mult = uint128((curve & MASK_START_AMT_MULT) >> SHIFT_START_AMT_MULT);
            amount = amount << mult;

            if (uint128(curve & MASK_FLAGS_NEG_START_AMT) > 0) return (0 - int256(amount));
            return int256(amount);
        }

        //time parameters
        uint48 startTime = uint48(uint128((curve & MASK_START_TIME) >> SHIFT_START_TIME));
        uint48 deltaTime = uint48(uint128((curve & MASK_DELTA_TIME) >> SHIFT_DELTA_TIME));
        uint48 endTime = startTime + deltaTime;
        uint256 evaluateAt = 0;
        if (solutionTimestamp > startTime) {
            if (solutionTimestamp < endTime) evaluateAt = solutionTimestamp - startTime;
            else evaluateAt = deltaTime;
        }

        //evaluate backwards
        if (uint128(curve & MASK_FLAGS_FLIP) > 0) {
            evaluateAt = deltaTime - evaluateAt;
        }

        //starting amount
        uint256 startAmount = uint128((curve & MASK_START_AMOUNT) >> SHIFT_START_AMOUNT);
        uint256 startMult = uint128((curve & MASK_START_AMT_MULT) >> SHIFT_START_AMT_MULT);
        startAmount = startAmount << startMult;

        //delta amount
        uint256 deltaAmount = uint128((curve & MASK_DELTA_AMOUNT) >> SHIFT_DELTA_AMOUNT);
        uint256 deltaMult = uint128((curve & MASK_DELTA_AMT_MULT) >> SHIFT_DELTA_AMT_MULT);
        if (deltaMult > 0 || startMult > 0) {
            if (uint128(curve & MASK_FLAGS_NEG_DELTA_MULT) > 0) {
                deltaMult = startMult - deltaMult;
            } else {
                deltaMult = startMult + deltaMult;
            }
            deltaAmount = deltaAmount << deltaMult;
        }

        //evaluate curve
        uint256 exponent = uint128((curve & MASK_EXPONENT) >> SHIFT_EXPONENT);
        if (exponent > 1) {
            //exponential curve evaluation
            if (uint128(curve & MASK_FLAGS_NEG_START_AMT) > 0) {
                if (uint128(curve & MASK_FLAGS_NEG_DELTA) > 0) {
                    return (0 - int256(startAmount)) - int256((evaluateAt ** exponent) * deltaAmount);
                } else {
                    return (0 - int256(startAmount)) + int256((evaluateAt ** exponent) * deltaAmount);
                }
            } else {
                if (uint128(curve & MASK_FLAGS_NEG_DELTA) > 0) {
                    return int256(startAmount) - int256((evaluateAt ** exponent) * deltaAmount);
                } else {
                    return int256(startAmount) + int256((evaluateAt ** exponent) * deltaAmount);
                }
            }
        } else {
            //linear curve evaluation
            if (uint128(curve & MASK_FLAGS_NEG_START_AMT) > 0) {
                if (uint128(curve & MASK_FLAGS_NEG_DELTA) > 0) {
                    return (0 - int256(startAmount)) - int256(evaluateAt * deltaAmount);
                } else {
                    return (0 - int256(startAmount)) + int256(evaluateAt * deltaAmount);
                }
            } else {
                if (uint128(curve & MASK_FLAGS_NEG_DELTA) > 0) {
                    return int256(startAmount) - int256(evaluateAt * deltaAmount);
                } else {
                    return int256(startAmount) + int256(evaluateAt * deltaAmount);
                }
            }
        }
    }
}

/**
 * Gets if the constant curve is flagged as relative from the given parameter encoding
 * @param curve the curve data
 * @return isRelative true if curve is meant to be evaluated relatively
 */
function isCurveRelative(bytes16 curve) pure returns (bool isRelative) {
    return uint128(curve & MASK_FLAGS_RELATIVE) > 0;
}

/**
 * Gets the curve byte size given the first byte
 * @param firstByte the first byte
 * @return curve size in bytes
 */
function curveByteSize(bytes1 firstByte) pure returns (uint8) {
    if (firstByte & (MASK_FLAGS_CURVE_TYPE >> ((16 - 1) * 8)) == bytes1(0)) return 6;
    return 16;
}
