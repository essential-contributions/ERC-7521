import { ethers } from 'ethers';

// The curve abstract class
export abstract class Curve {
  //returns the encoded curve bytes
  abstract encode(): string;

  //returns the curve value at the given parameters
  abstract evaluate(timestamp: number, previousValue?: bigint): bigint;

  //returns if the curve is to be evaluated relative to a previous recorded value
  abstract isRelative(): boolean;
}

// Constant value curve
export class ConstantCurve extends Curve {
  private amount: bigint;
  private relative: boolean;

  constructor(amount: bigint, relative: boolean = false) {
    super();
    this.amount = amount;
    this.relative = relative;
  }

  //returns the encoded curve bytes
  encode(): string {
    const amount = encodeAsUint96(this.amount);
    const flags = (amount.negative ? 0x80 : 0) + (this.relative ? 0x40 : 0);
    return combineHex(ethers.toBeHex(amount.value, 12), ethers.toBeHex(amount.mult, 1), ethers.toBeHex(flags, 1));
  }

  //returns the curve value at the given parameters
  evaluate(timestamp: number, previousValue?: bigint): bigint {
    if (previousValue && this.relative) return previousValue + this.amount;
    return this.amount;
  }

  //returns if the curve is to be evaluated relative to a previous recorded value
  isRelative(): boolean {
    return this.relative;
  }
}

// Linear value curve
export class LinearCurve extends Curve {
  private startTime: number;
  private duration: number;
  private startAmount: bigint;
  private deltaAmount: bigint;
  private relative: boolean;

  constructor(startTime: number, duration: number, startAmount: bigint, endAmount: bigint, relative: boolean = false) {
    super();
    if (startTime < 0) throw new Error(`startTime cannot be negative (startTime: ${startTime})`);
    if (duration < 0) throw new Error(`duration cannot be negative (duration: ${startTime})`);
    if (startTime > 0xffffffffff) throw new Error(`startTime too large (startTime: ${startTime} [seconds])`);
    if (duration > 0xffffffff) throw new Error(`duration too large (duration: ${duration} [seconds])`);
    this.startTime = startTime;
    this.duration = duration;
    this.startAmount = startAmount;
    this.deltaAmount = (endAmount - startAmount) / BigInt(duration);
    this.relative = relative;
  }

  //returns the encoded curve bytes
  encode(): string {
    const start = encodeAsUint96(this.startAmount);
    const delta = encodeAsUint64(this.deltaAmount);
    const flags = (start.negative ? 0x80 : 0) + (delta.negative ? 0x40 : 0) + (this.relative ? 0x20 : 0);
    return combineHex(
      ethers.toBeHex(this.startTime, 5),
      ethers.toBeHex(this.duration, 4),
      ethers.toBeHex(start.value, 12),
      ethers.toBeHex(start.mult, 1),
      ethers.toBeHex(delta.value, 8),
      ethers.toBeHex(delta.mult, 1),
      ethers.toBeHex(flags, 1)
    );
  }

  //returns the curve value at the given parameters
  evaluate(timestamp: number, previousValue?: bigint): bigint {
    if (timestamp < this.startTime) timestamp = this.startTime;
    if (timestamp > this.startTime + this.duration) timestamp = this.startTime + this.duration;
    const value = this.startAmount + this.deltaAmount * BigInt(timestamp - this.startTime);

    if (previousValue && this.relative) return previousValue + value;
    return value;
  }

  //returns if the curve is to be evaluated relative to a previous recorded value
  isRelative(): boolean {
    return this.relative;
  }
}

// Exponential value curve
export class ExponentialCurve extends Curve {
  private startTime: number;
  private duration: number;
  private startAmount: bigint;
  private deltaAmount: bigint;
  private exponent: number;
  private backwards: boolean;
  private relative: boolean;

  constructor(
    startTime: number,
    duration: number,
    startAmount: bigint,
    endAmount: bigint,
    exponent: number,
    invert: boolean,
    relative: boolean = false
  ) {
    super();
    if (startTime < 0) throw new Error(`startTime cannot be negative (startTime: ${startTime})`);
    if (duration < 0) throw new Error(`duration cannot be negative (duration: ${startTime})`);
    if (startTime > 0xffffffffff) throw new Error(`startTime too large (startTime: ${startTime} [seconds])`);
    if (duration > 0xffffffff) throw new Error(`duration too large (duration: ${duration} [seconds])`);
    if (exponent > 16) throw new Error(`exponent too large (exponent: ${duration} [max 16])`);
    if (invert) {
      const tmp = endAmount;
      endAmount = startAmount;
      startAmount = tmp;
    }
    this.startTime = startTime;
    this.duration = duration;
    this.startAmount = startAmount;
    this.deltaAmount = (endAmount - startAmount) / BigInt(Math.pow(duration, exponent));
    this.exponent = exponent;
    this.backwards = invert;
    this.relative = relative;
  }

  //returns the encoded curve bytes
  encode(): string {
    const start = encodeAsUint96(this.startAmount);
    const delta = encodeAsUint64(this.deltaAmount);
    const flags =
      (this.backwards ? 0x80 : 0) +
      (start.negative ? 0x40 : 0) +
      (delta.negative ? 0x20 : 0) +
      (this.relative ? 0x10 : 0);
    return combineHex(
      ethers.toBeHex(this.startTime, 5),
      ethers.toBeHex(this.duration, 4),
      ethers.toBeHex(start.value, 12),
      ethers.toBeHex(start.mult, 1),
      ethers.toBeHex(delta.value, 8),
      ethers.toBeHex(delta.mult, 1),
      ethers.toBeHex(flags + this.exponent, 1)
    );
  }

  //returns the curve value at the given parameters
  evaluate(timestamp: number, previousValue?: bigint): bigint {
    if (timestamp < this.startTime) timestamp = this.startTime;
    if (timestamp > this.startTime + this.duration) timestamp = this.startTime + this.duration;
    const evaluateAt = this.backwards ? timestamp - this.startTime : this.duration - (timestamp - this.startTime);
    const value = this.startAmount + this.deltaAmount * BigInt(Math.pow(evaluateAt, this.exponent));

    if (previousValue && this.relative) return previousValue + value;
    return value;
  }

  //returns if the curve is to be evaluated relative to a previous recorded value
  isRelative(): boolean {
    return this.relative;
  }
}

// Defined amount encoding pieces
type EncodedAmount = {
  value: bigint;
  mult: number;
  negative: boolean;
};

// Helper function to encode an int256 into a smaller data size
function encodeAsUint96(amount: bigint): EncodedAmount {
  const negative = amount < 0;
  if (negative) amount = -amount;
  let mult = 0;
  while (amount > ethers.toBigInt('0xffffffffffffffffffffffff')) {
    amount = amount >> 1n;
    mult++;
  }
  return {
    value: amount,
    mult,
    negative,
  };
}

// Helper function to encode an int256 into a smaller data size
function encodeAsUint64(amount: bigint): EncodedAmount {
  const negative = amount < 0;
  if (negative) amount = -amount;
  let mult = 0;
  while (amount > ethers.toBigInt('0xffffffffffffffff')) {
    amount = amount >> 1n;
    mult++;
  }
  return {
    value: amount,
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
