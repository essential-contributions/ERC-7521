import { ethers } from 'ethers';
import { IntentSegment } from '../intent';

// The intent object
export class UserOperationSegment extends IntentSegment {
  private standard: string;
  private gasLimit: bigint;
  private callData: string;

  constructor(standard: string, callData: string, gasLimit: bigint) {
    super();
    if (!ethers.isHexString(standard, 32)) throw new Error(`standard is not a valid bytes32 (standard: ${standard})`);
    if (!ethers.isHexString(callData)) throw new Error(`callData is not a valid bytes value (callData: ${callData})`);
    this.standard = standard;
    this.gasLimit = gasLimit;
    this.callData = callData;
  }

  //gets the bytes abi encoding of the segment
  asBytes(): string {
    return ethers.solidityPacked(['bytes32', 'uint256', 'bytes'], [this.standard, this.gasLimit, this.callData]);
  }
}
