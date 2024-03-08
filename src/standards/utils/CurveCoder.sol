// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

/*
 * Encoding masks
 *   [bytes1]  flags - evaluate backwards (flip), relative, as proxy, exponent [frp- eeee] [exponent: 0 = const, 1 = linear, >1 = exponential]
 *   [uint32]  startAmount - starting amount
 *   [uint8]   startAmountMult - amount multiplier (final_amount = amount * (10 ** amountMult)) [first bit = negative]
 * --only for linear or exponential--
 *   [uint24]  deltaAmount - amount of change after each second
 *   [uint8]   deltaAmountMult - amount multiplier (final_amount = amount * (10 ** amountMult)) [first bit = negative]
 *   [uint32]  startTime -  start time of the curve (in seconds)
 *   [uint16]  deltaTime - amount of time from start until curve caps (in seconds)
 */

bytes16 constant MASK_FLAGS_FLIP = 0x80000000000000000000000000000000;
bytes16 constant MASK_FLAGS_RELATIVE = 0x40000000000000000000000000000000;
bytes16 constant MASK_FLAGS_PROXY = 0x20000000000000000000000000000000;
bytes16 constant MASK_EXPONENT = 0x0f000000000000000000000000000000;
bytes16 constant MASK_START_AMOUNT = 0x00ffffffff0000000000000000000000;
bytes16 constant MASK_START_AMT_MULT = 0x00000000007f00000000000000000000;
bytes16 constant MASK_START_AMT_NEG = 0x00000000008000000000000000000000;
bytes16 constant MASK_DELTA_AMOUNT = 0x000000000000ffffff00000000000000;
bytes16 constant MASK_DELTA_AMT_MULT = 0x0000000000000000007f000000000000;
bytes16 constant MASK_DELTA_AMT_NEG = 0x00000000000000000080000000000000;
bytes16 constant MASK_START_TIME = 0x00000000000000000000ffffffff0000;
bytes16 constant MASK_DELTA_TIME = 0x0000000000000000000000000000ffff;
uint8 constant SHIFT_EXPONENT = 15 * 8;
uint8 constant SHIFT_START_AMOUNT = 11 * 8;
uint8 constant SHIFT_START_AMT_MULT = 10 * 8;
uint8 constant SHIFT_DELTA_AMOUNT = 7 * 8;
uint8 constant SHIFT_DELTA_AMT_MULT = 6 * 8;
uint8 constant SHIFT_START_TIME = 2 * 8;
uint8 constant SHIFT_DELTA_TIME = 0;

/**
 * Encodes the parameters into a constant curve
 * @param amount the amount to encode
 * @param isRelative indicate the curve is to be evaluated relatively
 * @param isProxy indicate the curve is for an account other than the original sender
 * @return encoding the parameter encoding
 */
function encodeConstantCurve(int256 amount, bool isRelative, bool isProxy) pure returns (bytes6) {
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
        uint256 div = adjustedAmount / 10;
        require((div * 10) == adjustedAmount, "too many digits on constant curve amount");
        adjustedAmount = div;
        amountMult++;
    }

    //encode
    bytes16 encoding = (bytes16(uint128(adjustedAmount)) << SHIFT_START_AMOUNT)
        | (bytes16(uint128(amountMult)) << SHIFT_START_AMT_MULT);
    if (amountNegative) encoding |= MASK_START_AMT_NEG;
    if (isRelative) encoding |= MASK_FLAGS_RELATIVE;
    if (isProxy) encoding |= MASK_FLAGS_PROXY;
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
 * @param isProxy indicate the curve is for an account other than the original sender
 * @return the fully encoded intent standard segment data
 */
function encodeComplexCurve(
    uint32 startTime,
    uint16 deltaTime,
    int256 startAmount,
    int256 deltaAmount,
    uint8 exponent,
    bool backwards,
    bool isRelative,
    bool isProxy
) pure returns (bytes16) {
    //start encode
    bytes16 encoding = (bytes16(uint128(exponent & 0x0f)) << SHIFT_EXPONENT);
    if (backwards) encoding |= MASK_FLAGS_FLIP;
    if (isRelative) encoding |= MASK_FLAGS_RELATIVE;
    if (isProxy) encoding |= MASK_FLAGS_PROXY;

    //encode start amount
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
        uint8 startAmountMult = 0;
        while (adjustedStartAmount > 0x00000000000000000000000000000000000000000000000000000000ffffffff) {
            uint256 div = adjustedStartAmount / 10;
            require((div * 10) == adjustedStartAmount, "too many digits on complex curve start amount");
            adjustedStartAmount = div;
            startAmountMult++;
        }
        encoding |= (bytes16(uint128(adjustedStartAmount)) << SHIFT_START_AMOUNT)
            | (bytes16(uint128(startAmountMult)) << SHIFT_START_AMT_MULT);
        if (startAmountNegative) encoding |= MASK_START_AMT_NEG;
    }

    if (exponent >= 1) {
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
            uint8 deltaAmountMult = 0;
            while (adjustedDeltaAmount > 0x0000000000000000000000000000000000000000000000000000000000ffffff) {
                uint256 div = adjustedDeltaAmount / 10;
                require((div * 10) == adjustedDeltaAmount, "too many digits on complex curve delta amount");
                adjustedDeltaAmount = div;
                deltaAmountMult++;
            }
            encoding |= (bytes16(uint128(adjustedDeltaAmount)) << SHIFT_DELTA_AMOUNT)
                | (bytes16(uint128(deltaAmountMult)) << SHIFT_DELTA_AMT_MULT);
            if (deltaAmountNegative) encoding |= MASK_DELTA_AMT_NEG;
        }

        //encode time data
        encoding |=
            (bytes16(uint128(startTime)) << SHIFT_START_TIME) | (bytes16(uint128(deltaTime)) << SHIFT_DELTA_TIME);
    }

    return encoding;
}

/**
 * Decodes the given curve parameter encoding and evaluates it
 * @param curve the encoded parameters
 * @dev curve
 *   [bytes1]  flags - evaluate backwards (flip), relative, as proxy, exponent [frp- eeee] [exponent: 0 = const, 1 = linear, >1 = exponential]
 *   [uint32]  startAmount - starting amount
 *   [uint8]   startAmountMult - amount multiplier (final_amount = amount * (10 ** amountMult)) [first bit = negative]
 * --only for linear or exponential--
 *   [uint24]  deltaAmount - amount of change after each second
 *   [uint8]   deltaAmountMult - amount multiplier (final_amount = amount * (10 ** amountMult)) [first bit = negative]
 *   [uint32]  startTime -  start time of the curve (in seconds)
 *   [uint16]  deltaTime - amount of time from start until curve caps (in seconds)
 * @param solutionTimestamp the time of evaluation specified by the solution
 * @return value the evaluated value
 */
function evaluateCurve(bytes16 curve, uint256 solutionTimestamp) pure returns (int256) {
    unchecked {
        uint256 exponent = uint128((curve & MASK_EXPONENT) >> SHIFT_EXPONENT);

        //constant curve evaluation
        if (exponent == 0) {
            uint256 amount = uint128((curve & MASK_START_AMOUNT) >> SHIFT_START_AMOUNT);
            uint256 mult = tenToThePowerOf(uint8(uint128((curve & MASK_START_AMT_MULT) >> SHIFT_START_AMT_MULT)));
            amount = amount * mult;

            if (uint128(curve & MASK_START_AMT_NEG) > 0) return (0 - int256(amount));
            return int256(amount);
        }

        //time parameters
        uint256 startTime = uint128((curve & MASK_START_TIME) >> SHIFT_START_TIME);
        uint256 deltaTime = uint128((curve & MASK_DELTA_TIME) >> SHIFT_DELTA_TIME);
        uint256 endTime = startTime + deltaTime;
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
        uint256 startMult = tenToThePowerOf(uint8(uint128((curve & MASK_START_AMT_MULT) >> SHIFT_START_AMT_MULT)));
        startAmount = startAmount * startMult;

        //delta amount
        uint256 deltaAmount = uint128((curve & MASK_DELTA_AMOUNT) >> SHIFT_DELTA_AMOUNT);
        uint256 deltaMult = tenToThePowerOf(uint8(uint128((curve & MASK_DELTA_AMT_MULT) >> SHIFT_DELTA_AMT_MULT)));
        deltaAmount = deltaAmount * deltaMult;

        //evaluate curve
        if (exponent > 1) {
            //exponential curve evaluation
            if (uint128(curve & MASK_START_AMT_NEG) > 0) {
                if (uint128(curve & MASK_DELTA_AMT_NEG) > 0) {
                    return (0 - int256(startAmount)) - int256((evaluateAt ** exponent) * deltaAmount);
                } else {
                    return (0 - int256(startAmount)) + int256((evaluateAt ** exponent) * deltaAmount);
                }
            } else {
                if (uint128(curve & MASK_DELTA_AMT_NEG) > 0) {
                    return int256(startAmount) - int256((evaluateAt ** exponent) * deltaAmount);
                } else {
                    return int256(startAmount) + int256((evaluateAt ** exponent) * deltaAmount);
                }
            }
        } else {
            //linear curve evaluation
            if (uint128(curve & MASK_START_AMT_NEG) > 0) {
                if (uint128(curve & MASK_DELTA_AMT_NEG) > 0) {
                    return (0 - int256(startAmount)) - int256(evaluateAt * deltaAmount);
                } else {
                    return (0 - int256(startAmount)) + int256(evaluateAt * deltaAmount);
                }
            } else {
                if (uint128(curve & MASK_DELTA_AMT_NEG) > 0) {
                    return int256(startAmount) - int256(evaluateAt * deltaAmount);
                } else {
                    return int256(startAmount) + int256(evaluateAt * deltaAmount);
                }
            }
        }
    }
}

/**
 * Gets if the curve is flagged as relative from the given parameter encoding
 * @param curve the curve data
 * @return isRelative true if curve is meant to be evaluated relatively
 */
function isCurveRelative(bytes16 curve) pure returns (bool isRelative) {
    return uint128(curve & MASK_FLAGS_RELATIVE) > 0;
}

/**
 * Gets if the curve is flagged as being for an account other than the original sender
 * @param curve the curve data
 * @return isProxy true if curve is meant to be evaluated relatively
 */
function isCurveProxy(bytes16 curve) pure returns (bool isProxy) {
    return uint128(curve & MASK_FLAGS_PROXY) > 0;
}

/**
 * Gets the value of 10 raised to the given power
 * @param pow the exponent power
 * @return the result
 */
function tenToThePowerOf(uint8 pow) pure returns (uint256) {
    unchecked {
        uint256 res = 1;
        if (pow >= 64) {
            res *= (10 ** 64);
            pow -= 64;
        }
        if (pow >= 32) {
            res *= (10 ** 32);
            pow -= 32;
        }
        if (pow >= 16) {
            res *= (10 ** 16);
            pow -= 16;
        }
        if (pow >= 8) {
            res *= (10 ** 8);
            pow -= 8;
        }
        if (pow >= 4) {
            res *= (10 ** 4);
            pow -= 4;
        }
        if (pow >= 2) {
            res *= (10 ** 2);
            pow -= 2;
        }
        if (pow >= 1) {
            res *= 10;
        }
        return res;
    }
}
