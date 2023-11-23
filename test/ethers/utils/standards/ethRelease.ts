import { ethers } from 'ethers';
import { IntentSegment } from '../intent';

// The intent object
export class EthReleaseSegment extends IntentSegment {
  private standard: string;
  private timeStart: number;
  private timeEnd: number;
  private amountStart: bigint;
  private amountEnd: bigint;

  constructor(standard: string, timeStart: number, timeEnd: number, amountStart: bigint, amountEnd: bigint) {
    super();
    if (!ethers.isHexString(standard, 32)) throw new Error(`standard is not a valid bytes32 (standard: ${standard})`);
    this.standard = standard;
    this.timeStart = timeStart;
    this.timeEnd = timeEnd;
    this.amountStart = amountStart;
    this.amountEnd = amountEnd;
  }

  //gets the bytes abi encoding of the segment
  asBytes(): string {
    const abi = new ethers.AbiCoder();
    const flags = '0x000000000004'; //[curve type] 000001 [evaluation type] 00
    const deltaAmount = this.amountEnd - this.amountStart;
    const deltaTime = BigInt(this.timeEnd) - BigInt(this.timeStart);
    const m = deltaTime > 0 ? deltaAmount / deltaTime : 1;
    const params = [m, this.amountStart, this.timeEnd];
    return abi.encode(['bytes32', 'tuple(uint48, uint48, int256[])'], [this.standard, [this.timeStart, flags, params]]);
  }
}
