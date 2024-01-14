import { ethers } from 'ethers';
import { IntentSegment } from '../intent';

// The intent object
export class Erc20RecordSegment extends IntentSegment {
  private standard: string;
  private token: string;
  private proxy: boolean;

  constructor(standard: string, token: string, proxy: boolean = false) {
    super();
    if (!ethers.isHexString(standard, 32)) throw new Error(`standard is not a valid bytes32 (standard: ${standard})`);
    if (!ethers.isAddress(token)) throw new Error(`token is not a valid address (token: ${token})`);
    this.standard = standard;
    this.token = token;
    this.proxy = proxy;
  }

  //gets the bytes abi encoding of the segment
  asBytes(): string {
    if (this.proxy) return ethers.solidityPacked(['bytes32', 'uint256', 'uint8'], [this.standard, this.token, 1]);
    return ethers.solidityPacked(['bytes32', 'uint256'], [this.standard, this.token]);
  }
}
