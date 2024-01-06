import { ethers } from 'ethers';
import { IntentSegment } from '../intent';
import { Curve } from '../curveCoder';

// The intent object
export class Erc20ReleaseSegment extends IntentSegment {
  private standard: string;
  private token: string;
  private curve: Curve;

  constructor(standard: string, token: string, curve: Curve) {
    super();
    if (!ethers.isHexString(standard, 32)) throw new Error(`standard is not a valid bytes32 (standard: ${standard})`);
    if (!ethers.isAddress(token)) throw new Error(`token is not a valid address (token: ${token})`);
    this.standard = standard;
    this.token = token;
    this.curve = curve;
  }

  //gets the bytes abi encoding of the segment
  asBytes(): string {
    return ethers.solidityPacked(['bytes32', 'uint256', 'bytes'], [this.standard, this.token, this.curve.encode()]);
  }
}
