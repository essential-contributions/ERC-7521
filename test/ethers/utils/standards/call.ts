import { ethers } from 'ethers';
import { IntentSegment } from '../intent';

// The intent object
export class CallSegment extends IntentSegment {
  private standard: string;
  private callData: string;

  constructor(standard: string, callData: string) {
    super();
    if (!ethers.isHexString(standard, 32)) throw new Error(`standard is not a valid bytes32 (standard: ${standard})`);
    if (!ethers.isHexString(callData)) throw new Error(`callData is not a valid bytes value (callData: ${callData})`);
    this.standard = standard;
    this.callData = callData;
  }

  //gets the bytes abi encoding of the segment
  asBytes(): string {
    const abi = new ethers.AbiCoder();
    return abi.encode(['bytes32', 'bytes'], [this.standard, this.callData]);
  }
}
