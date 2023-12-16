import { ethers } from 'ethers';
import { IntentSegment } from '../intent';

// The intent object
export class EthRecordSegment extends IntentSegment {
  private standard: string;

  constructor(standard: string) {
    super();
    if (!ethers.isHexString(standard, 32)) throw new Error(`standard is not a valid bytes32 (standard: ${standard})`);
    this.standard = standard;
  }

  //gets the bytes abi encoding of the segment
  asBytes(): string {
    return ethers.solidityPacked(['bytes32'], [this.standard]);
  }
}
