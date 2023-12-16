import { ethers } from 'ethers';
import { IntentSegment } from '../intent';
import { Curve } from '../curveCoder';

// The intent object
export class EthRequireSegment extends IntentSegment {
  private standard: string;
  private curve: Curve;

  constructor(standard: string, curve: Curve) {
    super();
    if (!ethers.isHexString(standard, 32)) throw new Error(`standard is not a valid bytes32 (standard: ${standard})`);
    this.standard = standard;
    this.curve = curve;
  }

  //gets the bytes abi encoding of the segment
  asBytes(): string {
    return ethers.solidityPacked(['bytes32', 'bytes'], [this.standard, this.curve.encode()]);
  }
}
