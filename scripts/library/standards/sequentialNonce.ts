import { ethers } from 'ethers';
import { IntentSegment } from '../intent';

// The intent object
export class SequentialNonceSegment extends IntentSegment {
  private standard: string;
  private nonce: string;

  constructor(standard: string, nonce: number, key?: string) {
    super();
    key = key || '0x000000000000000000000000000000000000000000000000';
    if (!ethers.isHexString(standard, 32)) throw new Error(`standard is not a valid bytes32 (standard: ${standard})`);
    if (!ethers.isHexString(key, 24)) throw new Error(`key is not a valid bytes24 (key: ${key})`);
    this.standard = standard;
    this.nonce = '0x' + nonce.toString(16).padStart(16, '0');
  }

  //gets the bytes abi encoding of the segment
  asBytes(): string {
    return ethers.solidityPacked(['bytes32', 'uint256'], [this.standard, this.nonce]);
  }
}
