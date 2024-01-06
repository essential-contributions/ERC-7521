import { ethers } from 'ethers';
import { IntentSegment } from '../intent';

// The intent object
export class EthRecordSegment extends IntentSegment {
  private standard: string;
  private proxy: boolean;

  constructor(standard: string, proxy: boolean = false) {
    super();
    if (!ethers.isHexString(standard, 32)) throw new Error(`standard is not a valid bytes32 (standard: ${standard})`);
    this.standard = standard;
    this.proxy = proxy;
  }

  //gets the bytes abi encoding of the segment
  asBytes(): string {
    if (this.proxy) return ethers.solidityPacked(['bytes32', 'uint8'], [this.standard, 1]);
    return ethers.solidityPacked(['bytes32'], [this.standard]);
  }
}
