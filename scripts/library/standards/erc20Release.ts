import { ethers } from 'ethers';
import { IntentSegment } from '../intent';
import { Curve } from '../curveCoder';

// The intent object
export class Erc20ReleaseSegment extends IntentSegment {
  private standard: string;
  private contract: string;
  private curve: Curve;

  constructor(standard: string, contract: string, curve: Curve) {
    super();
    if (!ethers.isHexString(standard, 32)) throw new Error(`standard is not a valid bytes32 (standard: ${standard})`);
    if (!ethers.isAddress(contract)) throw new Error(`contract is not a valid address (contract: ${contract})`);
    this.standard = standard;
    this.contract = contract;
    this.curve = curve;
  }

  //gets the bytes abi encoding of the segment
  asBytes(): string {
    return ethers.solidityPacked(['bytes32', 'address', 'bytes'], [this.standard, this.contract, this.curve.encode()]);
  }
}
