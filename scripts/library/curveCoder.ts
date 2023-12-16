import { ethers } from 'ethers';

// The curve abstract class
export abstract class Curve {
  //returns the encoded curve bytes
  abstract encode(): string;

  //returns the curve value at the given parameters
  abstract evaluate(timestamp: number, previousValue?: bigint): bigint;

  //returns the curve minimum
  abstract min(previousValue?: bigint): bigint;

  //returns the curve maximum
  abstract max(previousValue?: bigint): bigint;

  //returns if the curve is to be evaluated relative to a previous recorded value
  abstract isRelative(): boolean;
}

// Constant value curve
// [bytes1]  flags - curve type, relative, evaluate backwards (flip), negative [c--r fn--]
// [uint32]  startAmount - starting amount
// [uint8]   amountMult - amount multiplier (final_amount = amount * (amountMult * 10))
export class ConstantCurve extends Curve {
  private relative: boolean;
  private negative: boolean;
  private amount: number;
  private mult: number;

  constructor(amount: bigint, relative: boolean = false) {
    super();
    const encodedAmount = encodeAsUint32(amount);

    this.relative = relative;
    this.negative = encodedAmount.negative;
    this.amount = encodedAmount.value;
    this.mult = encodedAmount.mult;
  }

  //returns the encoded curve bytes
  encode(): string {
    const flags = (this.relative ? 0x10 : 0) + (this.negative ? 0x04 : 0);
    return combineHex(ethers.toBeHex(flags, 1), ethers.toBeHex(this.amount, 4), ethers.toBeHex(this.mult, 1));
  }

  //returns the curve value at the given parameters
  evaluate(timestamp: number, previousValue?: bigint): bigint {
    const amount = (BigInt(this.amount) << BigInt(this.mult)) * (this.negative ? -1n : 1n);
    if (previousValue && this.relative) return previousValue + amount;
    return amount;
  }

  //returns the curve minimum
  min(previousValue?: bigint): bigint {
    return this.evaluate(0, previousValue);
  }

  //returns the curve maximum
  max(previousValue?: bigint): bigint {
    return this.evaluate(0, previousValue);
  }

  //returns if the curve is to be evaluated relative to a previous recorded value
  isRelative(): boolean {
    return this.relative;
  }
}

// Linear value curve
// [bytes1]  flags - curve type, relative, negatives [c--r -nnn]
// [uint32]  startAmount - starting amount
// [uint8]   amountMult - amount multiplier (final_amount = amount * (amountMult * 10))
// --only for linear or exponential--
// [uint32]  startTime -  start time of the curve (in seconds)
// [uint16]  deltaTime - amount of time from start until curve caps (in seconds)
// [uint24]  deltaAmount - amount of change after each second
// [bytes1]  misc - delta amount mult [mmmm ----]
export class LinearCurve extends Curve {
  private relative: boolean;
  private negativeStartAmount: boolean;
  private negativeDeltaAmount: boolean;
  private negativeDeltaAmountMult: boolean;
  private startTime: number;
  private deltaTime: number;
  private startAmount: number;
  private startAmountMult: number;
  private deltaAmount: number;
  private deltaAmountMult: number;

  constructor(startTime: number, duration: number, startAmount: bigint, endAmount: bigint, relative: boolean = false) {
    super();
    if (startTime < 0) throw new Error(`startTime cannot be negative (startTime: ${startTime})`);
    if (duration < 0) throw new Error(`duration cannot be negative (duration: ${startTime})`);
    if (startTime > 0xffffffff) throw new Error(`startTime too large (startTime: ${startTime} [seconds])`);
    if (duration > 0xffff) throw new Error(`duration too large (duration: ${duration} [seconds])`);
    const encodedStartAmount = encodeAsUint32(startAmount);
    const encodedDeltaAmount = encodeAsUint24((endAmount - startAmount) / BigInt(duration));
    if (startAmount == 0n) {
      encodedStartAmount.mult = encodedDeltaAmount.mult;
      encodedDeltaAmount.mult = 0;
    } else {
      encodedDeltaAmount.mult = encodedStartAmount.mult - encodedDeltaAmount.mult;
      if (encodedDeltaAmount.mult < -15) throw new Error('delta too small in comparison to start');
      if (encodedDeltaAmount.mult > 15) throw new Error('delta too large in comparison to start');
    }

    this.startTime = startTime;
    this.deltaTime = duration;
    this.startAmount = encodedStartAmount.value;
    this.startAmountMult = encodedStartAmount.mult;
    this.deltaAmount = encodedDeltaAmount.value;
    this.deltaAmountMult = Math.abs(encodedDeltaAmount.mult);
    this.negativeStartAmount = encodedStartAmount.negative;
    this.negativeDeltaAmount = encodedDeltaAmount.negative;
    this.negativeDeltaAmountMult = encodedDeltaAmount.mult < 0;
    this.relative = relative;
  }

  //returns the encoded curve bytes
  encode(): string {
    const flags =
      0x80 +
      (this.relative ? 0x10 : 0) +
      (this.negativeStartAmount ? 0x04 : 0) +
      (this.negativeDeltaAmount ? 0x02 : 0) +
      (this.negativeDeltaAmountMult ? 0x01 : 0);
    const misc = this.deltaAmountMult << 4;
    return combineHex(
      ethers.toBeHex(flags, 1),
      ethers.toBeHex(this.startAmount, 4),
      ethers.toBeHex(this.startAmountMult, 1),
      ethers.toBeHex(this.startTime, 4),
      ethers.toBeHex(this.deltaTime, 2),
      ethers.toBeHex(this.deltaAmount, 3),
      ethers.toBeHex(misc, 1),
    );
  }

  //returns the curve value at the given parameters
  evaluate(timestamp: number, previousValue?: bigint): bigint {
    const deltaMult = this.startAmountMult + this.deltaAmountMult * (this.negativeDeltaAmountMult ? -1 : 1);
    const startAmount =
      (BigInt(this.startAmount) << BigInt(this.startAmountMult)) * (this.negativeStartAmount ? -1n : 1n);
    const deltaAmount = (BigInt(this.deltaAmount) << BigInt(deltaMult)) * (this.negativeDeltaAmount ? -1n : 1n);

    //determine where to evaluate the curve
    let evaluateAt = 0;
    if (timestamp > this.startTime) {
      if (timestamp < this.startTime + this.deltaTime) evaluateAt = timestamp - this.startTime;
      else evaluateAt = this.deltaTime;
    }

    //evaluate
    const amount = startAmount + BigInt(evaluateAt) * deltaAmount;
    if (previousValue && this.relative) return previousValue + amount;
    return amount;
  }

  //returns the curve minimum
  min(previousValue?: bigint): bigint {
    return this.evaluate(this.startTime, previousValue);
  }

  //returns the curve maximum
  max(previousValue?: bigint): bigint {
    return this.evaluate(this.startTime + this.deltaTime, previousValue);
  }

  //returns if the curve is to be evaluated relative to a previous recorded value
  isRelative(): boolean {
    return this.relative;
  }
}

// Exponential value curve
// [bytes1]  flags - curve type, relative, evaluate backwards (flip), negatives [c--r fnnn]
// [uint32]  startAmount - starting amount
// [uint8]   amountMult - amount multiplier (final_amount = amount * (amountMult * 10))
// --only for linear or exponential--
// [uint32]  startTime -  start time of the curve (in seconds)
// [uint16]  deltaTime - amount of time from start until curve caps (in seconds)
// [uint24]  deltaAmount - amount of change after each second
// [bytes1]  misc - delta amount mult, exponent [mmmm eeee]
export class ExponentialCurve extends Curve {
  private relative: boolean;
  private evaluateBackwards: boolean;
  private negativeStartAmount: boolean;
  private negativeDeltaAmount: boolean;
  private negativeDeltaAmountMult: boolean;
  private startTime: number;
  private deltaTime: number;
  private startAmount: number;
  private startAmountMult: number;
  private deltaAmount: number;
  private deltaAmountMult: number;
  private exponent: number;

  constructor(
    startTime: number,
    duration: number,
    startAmount: bigint,
    endAmount: bigint,
    exponent: number,
    invert: boolean,
    relative: boolean = false,
  ) {
    super();
    if (startTime < 0) throw new Error(`startTime cannot be negative (startTime: ${startTime})`);
    if (duration < 0) throw new Error(`duration cannot be negative (duration: ${startTime})`);
    if (startTime > 0xffffffff) throw new Error(`startTime too large (startTime: ${startTime} [seconds])`);
    if (duration > 0xffff) throw new Error(`duration too large (duration: ${duration} [seconds])`);
    if (exponent > 15) throw new Error(`exponent too large (exponent: ${duration} [max 15])`);
    if (invert) {
      const tmp = endAmount;
      endAmount = startAmount;
      startAmount = tmp;
    }
    const encodedStartAmount = encodeAsUint32(startAmount);
    const encodedDeltaAmount = encodeAsUint24((endAmount - startAmount) / BigInt(Math.pow(duration, exponent)));
    if (startAmount == 0n) {
      encodedStartAmount.mult = encodedDeltaAmount.mult;
      encodedDeltaAmount.mult = 0;
    } else {
      encodedDeltaAmount.mult = encodedStartAmount.mult - encodedDeltaAmount.mult;
      if (encodedDeltaAmount.mult < -15) throw new Error('delta too small in comparison to start');
      if (encodedDeltaAmount.mult > 15) throw new Error('delta too large in comparison to start');
    }

    this.startTime = startTime;
    this.deltaTime = duration;
    this.startAmount = encodedStartAmount.value;
    this.startAmountMult = encodedStartAmount.mult;
    this.deltaAmount = encodedDeltaAmount.value;
    this.deltaAmountMult = Math.abs(encodedDeltaAmount.mult);
    this.exponent = exponent;
    this.evaluateBackwards = invert;
    this.negativeStartAmount = encodedStartAmount.negative;
    this.negativeDeltaAmount = encodedDeltaAmount.negative;
    this.negativeDeltaAmountMult = encodedDeltaAmount.mult < 0;
    this.relative = relative;
  }

  //returns the encoded curve bytes
  encode(): string {
    const flags =
      0x80 +
      (this.relative ? 0x10 : 0) +
      (this.evaluateBackwards ? 0x08 : 0) +
      (this.negativeStartAmount ? 0x04 : 0) +
      (this.negativeDeltaAmount ? 0x02 : 0) +
      (this.negativeDeltaAmountMult ? 0x01 : 0);
    const misc = (this.deltaAmountMult << 4) + this.exponent;
    return combineHex(
      ethers.toBeHex(flags, 1),
      ethers.toBeHex(this.startAmount, 4),
      ethers.toBeHex(this.startAmountMult, 1),
      ethers.toBeHex(this.startTime, 4),
      ethers.toBeHex(this.deltaTime, 2),
      ethers.toBeHex(this.deltaAmount, 3),
      ethers.toBeHex(misc, 1),
    );
  }

  //returns the curve value at the given parameters
  evaluate(timestamp: number, previousValue?: bigint): bigint {
    const deltaMult = this.startAmountMult + this.deltaAmountMult * (this.negativeDeltaAmountMult ? -1 : 1);
    const startAmount =
      (BigInt(this.startAmount) << BigInt(this.startAmountMult)) * (this.negativeStartAmount ? -1n : 1n);
    const deltaAmount = (BigInt(this.deltaAmount) << BigInt(deltaMult)) * (this.negativeDeltaAmount ? -1n : 1n);

    //determine where to evaluate the curve
    let evaluateAt = 0;
    if (timestamp > this.startTime) {
      if (timestamp < this.startTime + this.deltaTime) evaluateAt = timestamp - this.startTime;
      else evaluateAt = this.deltaTime;
    }
    if (this.evaluateBackwards) evaluateAt = this.deltaTime - evaluateAt;

    //evaluate
    const amount = startAmount + BigInt(evaluateAt) ** BigInt(this.exponent) * deltaAmount;
    if (previousValue && this.relative) return previousValue + amount;
    return amount;
  }

  //returns the curve minimum
  min(previousValue?: bigint): bigint {
    return this.evaluate(this.startTime, previousValue);
  }

  //returns the curve maximum
  max(previousValue?: bigint): bigint {
    return this.evaluate(this.startTime + this.deltaTime, previousValue);
  }

  //returns if the curve is to be evaluated relative to a previous recorded value
  isRelative(): boolean {
    return this.relative;
  }
}

// Defined amount encoding pieces
type EncodedAmount = {
  value: number;
  mult: number;
  negative: boolean;
};

// Helper function to encode an int256 into a smaller data size
function encodeAsUint32(amount: bigint): EncodedAmount {
  const negative = amount < 0;
  if (negative) amount = -amount;
  let mult = 0;
  while (amount > ethers.toBigInt('0xffffffff')) {
    amount = amount >> 1n;
    mult++;
  }
  return {
    value: Number(amount),
    mult,
    negative,
  };
}

// Helper function to encode an int256 into a smaller data size
function encodeAsUint24(amount: bigint): EncodedAmount {
  const negative = amount < 0;
  if (negative) amount = -amount;
  let mult = 0;
  while (amount > ethers.toBigInt('0xffffff')) {
    amount = amount >> 1n;
    mult++;
  }
  return {
    value: Number(amount),
    mult,
    negative,
  };
}

// Helper function to combine the hex bytes strings into one
function combineHex(...hexStrings: string[]): string {
  let combined = '';
  for (const hex of hexStrings) {
    combined = combined + hex.substring(2);
  }
  return `0x${combined}`;
}
