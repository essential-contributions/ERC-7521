// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

/**
 * Encodes the given fileds into the constant curve parameter encoding
 * @param amount constant amount
 * @param amountMult amount multiplier (final_amount = amount << amountMult)
 * @param amountNegative indicates that amount is negative
 * @param isRelative indicate the curve is to be evaluated relatively
 * @return encoding the parameter encoding
 */
function encodeConstantCurve(uint96 amount, uint8 amountMult, bool amountNegative, bool isRelative)
    pure
    returns (bytes32 encoding)
{
    encoding = (bytes32(uint256(amount)) << 160) | (bytes32(uint256(amountMult)) << 152);
    if (amountNegative) encoding = encoding | 0x0000000000000000000000000080000000000000000000000000000000000000;
    if (isRelative) encoding = encoding | 0x0000000000000000000000000040000000000000000000000000000000000000;
}

/**
 * Decodes the given constant curve parameter encoding and evaluates it
 * @param data the encoded parameters
 * @dev data
 *   [uint96]  amount - amount required
 *   [uint8]   amountMult - amount multiplier (final_amount = amount << amountMult)
 *   [bytes1]  flags - negative, relative or absolute [nrxx xxxx]
 * @return value the evaluated value
 */
function evaluateConstantCurve(bytes32 data) pure returns (int256) {
    unchecked {
        uint256 value = uint256((data & 0xffffffffffffffffffffffff0000000000000000000000000000000000000000) >> 160);

        //multiplier
        uint256 amountMult = uint256(data & 0x000000000000000000000000ff00000000000000000000000000000000000000);
        if (amountMult > 0) value = value << (amountMult >> 152);

        //evaluate
        if (uint256(data & 0x0000000000000000000000000080000000000000000000000000000000000000) > 0) {
            return 0 - int256(value);
        }
        return int256(value);
    }
}

/**
 * Gets if the constant curve is flagged as relative from the given parameter encoding
 * @param data the encoded parameters
 * @return isRelative true if curve is meant to be evaluated relatively
 */
function isConstantCurveRelative(bytes32 data) pure returns (bool isRelative) {
    return uint256(data & 0x0000000000000000000000000040000000000000000000000000000000000000) > 0;
}

/**
 * Encodes the given fileds into the linear curve parameter encoding (1 of 2 parts)
 * @param encoding current encoding from previous steps
 * @param startTime start time of the curve (in seconds)
 * @param deltaTime amount of time from start until curve caps (in seconds)
 * @param startAmount starting amount
 * @param startMult starting amount multiplier (final_amount = amount << amountMult)
 * @param startNegative indicates that start amount is negative
 * @return encoding the parameter encoding
 */
function encodeLinearCurve1(
    bytes32 encoding,
    uint40 startTime,
    uint32 deltaTime,
    uint96 startAmount,
    uint8 startMult,
    bool startNegative
) pure returns (bytes32) {
    encoding = encoding | (bytes32(uint256(startTime)) << 216) | (bytes32(uint256(deltaTime)) << 184)
        | (bytes32(uint256(startAmount)) << 88) | (bytes32(uint256(startMult)) << 80);
    if (startNegative) encoding = encoding | 0x0000000000000000000000000000000000000000000000000000000000000080;
    return encoding;
}

/**
 * Encodes the given fileds into the linear curve parameter encoding (1 of 2 parts)
 * @param encoding current encoding from previous steps
 * @param deltaAmount amount of change after each second
 * @param deltaMult delta amount multiplier (final_amount = amount << amountMult)
 * @param deltaNegative indicates that start amount is negative
 * @param isRelative indicate the curve is to be evaluated relatively
 * @return encoding the parameter encoding
 */
function encodeLinearCurve2(bytes32 encoding, uint64 deltaAmount, uint8 deltaMult, bool deltaNegative, bool isRelative)
    pure
    returns (bytes32)
{
    encoding = encoding | (bytes32(uint256(deltaAmount)) << 16) | (bytes32(uint256(deltaMult)) << 8);
    if (deltaNegative) encoding = encoding | 0x0000000000000000000000000000000000000000000000000000000000000040;
    if (isRelative) encoding = encoding | 0x0000000000000000000000000000000000000000000000000000000000000020;
    return encoding;
}

/**
 * Decodes the given linear curve parameter encoding and evaluates it
 * @param data the encoded parameters
 * @dev data
 *   [uint40]  startTime - start time of the curve (in seconds)
 *   [uint32]  deltaTime - amount of time from start until curve caps (in seconds)
 *   [uint96]  startAmount - starting amount
 *   [uint8]   startAmountMult - starting amount multiplier (final_amount = amount << amountMult)
 *   [uint64]  deltaAmount - amount of change after each second
 *   [uint8]   deltaAmountMult - delta amount multiplier (final_amount = amount << amountMult)
 *   [bytes1]  flags - negatives, relative or absolute [nnrx xxxx]
 * @param solutionTimestamp the time of evaluation specified by the solution
 * @return value the evaluated value
 */
function evaluateLinearCurve(bytes32 data, uint256 solutionTimestamp) pure returns (int256 value) {
    unchecked {
        //time parameters
        uint48 startTime =
            uint48(uint256((data & 0xffffffffff000000000000000000000000000000000000000000000000000000) >> 216));
        uint48 deltaTime =
            uint48(uint256((data & 0x0000000000ffffffff0000000000000000000000000000000000000000000000) >> 184));
        uint48 endTime = startTime + deltaTime;
        uint256 evaluateAt = 0;
        if (solutionTimestamp > startTime) {
            if (solutionTimestamp < endTime) evaluateAt = solutionTimestamp - startTime;
            else evaluateAt = deltaTime;
        }

        //starting amount
        uint256 startAmount = uint256((data & 0x000000000000000000ffffffffffffffffffffffff0000000000000000000000) >> 88);
        uint256 startMult = uint256(data & 0x000000000000000000000000000000000000000000ff00000000000000000000);
        if (startMult > 0) startAmount = startAmount << (startMult >> 80);

        //delta amount
        uint256 deltaAmount = uint256((data & 0x00000000000000000000000000000000000000000000ffffffffffffffff0000) >> 16);
        uint256 deltaMult = uint256(data & 0x000000000000000000000000000000000000000000000000000000000000ff00);
        if (deltaMult > 0) deltaAmount = deltaAmount << (deltaMult >> 8);

        //evaluate curve
        if (uint256(data & 0x0000000000000000000000000000000000000000000000000000000000000080) > 0) {
            if (uint256(data & 0x0000000000000000000000000000000000000000000000000000000000000040) > 0) {
                return (0 - int256(startAmount)) - int256(evaluateAt * deltaAmount);
            } else {
                return (0 - int256(startAmount)) + int256(evaluateAt * deltaAmount);
            }
        } else {
            if (uint256(data & 0x0000000000000000000000000000000000000000000000000000000000000040) > 0) {
                return int256(startAmount) - int256(evaluateAt * deltaAmount);
            } else {
                return int256(startAmount) + int256(evaluateAt * deltaAmount);
            }
        }
    }
}

/**
 * Gets if the linear curve is flagged as relative from the given parameter encoding
 * @param data the encoded parameters
 * @return isRelative true if curve is meant to be evaluated relatively
 */
function isLinearCurveRelative(bytes32 data) pure returns (bool isRelative) {
    return uint256(data & 0x0000000000000000000000000000000000000000000000000000000000000020) > 0;
}

/**
 * Encodes the given fileds into the exponential curve parameter encoding (1 of 3 parts)
 * @param encoding current encoding from previous steps
 * @param startTime start time of the curve (in seconds)
 * @param deltaTime amount of time from start until curve caps (in seconds)
 * @param exponent the exponent order of the curve
 * @param flipYAxis evaluate curve from right to left
 * @param isRelative indicate the curve is to be evaluated relatively
 * @return encoding the parameter encoding
 */
function encodeExponentialCurve1(
    bytes32 encoding,
    uint40 startTime,
    uint32 deltaTime,
    uint8 exponent,
    bool flipYAxis,
    bool isRelative
) pure returns (bytes32) {
    encoding = encoding | (bytes32(uint256(startTime)) << 216) | (bytes32(uint256(deltaTime)) << 184);
    if (flipYAxis) encoding = encoding | 0x0000000000000000000000000000000000000000000000000000000000000080;
    if (isRelative) encoding = encoding | 0x0000000000000000000000000000000000000000000000000000000000000010;
    if (exponent > uint8(0x0f)) exponent = uint8(0x0f);
    encoding = encoding | bytes32(uint256(exponent));
    return encoding;
}

/**
 * Encodes the given fileds into the exponential curve parameter encoding (1 of 3 parts)
 * @param encoding current encoding from previous steps
 * @param startAmount starting amount
 * @param startMult starting amount multiplier (final_amount = amount << amountMult)
 * @param startNegative indicates that start amount is negative
 * @return encoding the parameter encoding
 */
function encodeExponentialCurve2(bytes32 encoding, uint96 startAmount, uint8 startMult, bool startNegative)
    pure
    returns (bytes32)
{
    encoding = encoding | (bytes32(uint256(startAmount)) << 88) | (bytes32(uint256(startMult)) << 80);
    if (startNegative) encoding = encoding | 0x0000000000000000000000000000000000000000000000000000000000000040;
    return encoding;
}

/**
 * Encodes the given fileds into the exponential curve parameter encoding (1 of 3 parts)
 * @param encoding current encoding from previous steps
 * @param deltaAmount amount of change after each second
 * @param deltaMult delta amount multiplier (final_amount = amount << amountMult)
 * @param deltaNegative indicates that start amount is negative
 * @return encoding the parameter encoding
 */
function encodeExponentialCurve3(bytes32 encoding, uint64 deltaAmount, uint8 deltaMult, bool deltaNegative)
    pure
    returns (bytes32)
{
    encoding = encoding | (bytes32(uint256(deltaAmount)) << 16) | (bytes32(uint256(deltaMult)) << 8);
    if (deltaNegative) encoding = encoding | 0x0000000000000000000000000000000000000000000000000000000000000020;
    return encoding;
}

/**
 * Decodes the given exponential curve parameter encoding and evaluates it
 * @param data the encoded parameters
 * @dev data
 *   [uint40]  startTime - start time of the curve (in seconds)
 *   [uint32]  deltaTime - amount of time from start until curve caps (in seconds)
 *   [uint96]  startAmount - starting amount
 *   [uint8]   startAmountMult - starting amount multiplier (final_amount = amount * (amountMult * 10))
 *   [uint64]  deltaAmount - amount of change after each second
 *   [uint8]   deltaAmountMult - delta amount multiplier (final_amount = amount * (amountMult * 10))
 *   [bytes1]  flags/exponent - flip y, negatives, relative or absolute, exponent [fnnr eeee]
 * @param solutionTimestamp the time of evaluation specified by the solution
 * @return value the evaluated value
 */
function evaluateExponentialCurve(bytes32 data, uint256 solutionTimestamp) pure returns (int256 value) {
    unchecked {
        //time parameters
        uint48 startTime =
            uint48(uint256((data & 0xffffffffff000000000000000000000000000000000000000000000000000000) >> 216));
        uint48 deltaTime =
            uint48(uint256((data & 0x0000000000ffffffff0000000000000000000000000000000000000000000000) >> 184));
        uint48 endTime = startTime + deltaTime;
        uint256 evaluateAt = 0;
        if (solutionTimestamp > startTime) {
            if (solutionTimestamp < endTime) evaluateAt = solutionTimestamp - startTime;
            else evaluateAt = deltaTime;
        }

        //flip y-axis
        if (uint256(data & 0x0000000000000000000000000000000000000000000000000000000000000080) > 0) {
            evaluateAt = deltaTime - evaluateAt;
        }

        //starting amount
        uint256 startAmount = uint256((data & 0x000000000000000000ffffffffffffffffffffffff0000000000000000000000) >> 88);
        uint256 startMult = uint256(data & 0x000000000000000000000000000000000000000000ff00000000000000000000);
        if (startMult > 0) startAmount = startAmount << (startMult >> 80);

        //delta amount
        uint256 deltaAmount = uint256((data & 0x00000000000000000000000000000000000000000000ffffffffffffffff0000) >> 16);
        uint256 deltaMult = uint256(data & 0x000000000000000000000000000000000000000000000000000000000000ff00);
        if (deltaMult > 0) deltaAmount = deltaAmount << (deltaMult >> 8);

        //evaluate curve
        uint256 exponent = uint256(data & 0x000000000000000000000000000000000000000000000000000000000000001f);
        if (uint256(data & 0x0000000000000000000000000000000000000000000000000000000000000040) > 0) {
            if (uint256(data & 0x0000000000000000000000000000000000000000000000000000000000000020) > 0) {
                return (0 - int256(startAmount)) - int256((evaluateAt ** exponent) * deltaAmount);
            } else {
                return (0 - int256(startAmount)) + int256((evaluateAt ** exponent) * deltaAmount);
            }
        } else {
            if (uint256(data & 0x0000000000000000000000000000000000000000000000000000000000000020) > 0) {
                return int256(startAmount) - int256((evaluateAt ** exponent) * deltaAmount);
            } else {
                return int256(startAmount) + int256((evaluateAt ** exponent) * deltaAmount);
            }
        }
    }
}

/**
 * Gets if the exponential curve is flagged as relative from the given parameter encoding
 * @param data the encoded parameters
 * @return isRelative true if curve is meant to be evaluated relatively
 */
function isExponentialCurveRelative(bytes32 data) pure returns (bool isRelative) {
    return uint256(data & 0x0000000000000000000000000000000000000000000000000000000000000010) > 0;
}

/**
 * Encodes the signed int256 value into smaller pieces for encoding into 12 bytes
 * @param amount the amount to encode
 * @return value the encoded amount value
 * @return mult the amount multiplier
 * @return negative the amount negative flag
 */
function encodeAsUint96(int256 amount) pure returns (uint96 value, uint8 mult, bool negative) {
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
    while (adjustedAmount > 0x0000000000000000000000000000000000000000ffffffffffffffffffffffff) {
        adjustedAmount = adjustedAmount >> 1;
        amountMult++;
    }
    return (uint96(adjustedAmount), amountMult, amountNegative);
}

/**
 * Encodes the signed int256 value into smaller pieces for encoding into 8 bytes
 * @param amount the amount to encode
 * @return value the encoded amount value
 * @return mult the amount multiplier
 * @return negative the amount negative flag
 */
function encodeAsUint64(int256 amount) pure returns (uint64 value, uint8 mult, bool negative) {
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
    while (adjustedAmount > 0x000000000000000000000000000000000000000000000000ffffffffffffffff) {
        adjustedAmount = adjustedAmount >> 1;
        amountMult++;
    }
    return (uint64(adjustedAmount), amountMult, amountNegative);
}
