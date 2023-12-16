import { ethers } from 'ethers';
import { IntentSegment } from '../intent';

// The intent object
export class Erc20RecordSegment extends IntentSegment {
  private standard: string;
  private contract: string;

  constructor(standard: string, contract: string) {
    super();
    if (!ethers.isHexString(standard, 32)) throw new Error(`standard is not a valid bytes32 (standard: ${standard})`);
    if (!ethers.isAddress(contract)) throw new Error(`contract is not a valid address (contract: ${contract})`);
    this.standard = standard;
    this.contract = contract;
  }

  //gets the bytes abi encoding of the segment
  asBytes(): string {
    return ethers.solidityPacked(['bytes32', 'address'], [this.standard, this.contract]);
  }
}
