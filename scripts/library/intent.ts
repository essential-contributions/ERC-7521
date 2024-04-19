import { IntentSolutionStruct, UserIntentStruct } from '../../typechain/src/core/EntryPoint';
import { ethers, AddressLike, BytesLike, Provider, Signer } from 'ethers';

// The intent object
export class UserIntent {
  private sender: AddressLike;
  private segments: IntentSegment[];
  private signature: string;

  constructor(sender?: AddressLike) {
    if (sender) this.validateSender(sender);
    this.sender = sender || '0x0000000000000000000000000000000000000000';
    this.segments = [];
    this.signature = '0x';
  }

  //set the sender of the intent (smart contract account contract address)
  public setSender(sender: AddressLike) {
    this.validateSender(sender);
    this.sender = sender;
  }

  //add a segment to the intent
  public addSegment(segment: IntentSegment) {
    this.segments.push(segment);
  }

  //gets the segment of the intent at the specified index
  public getSegment(index: number): IntentSegment {
    return this.segments[index];
  }

  //clear all intent segments
  public clearSegments() {
    this.segments = [];
  }

  //sign the intent with the ECDSA signer authorized by the intent sender
  public async sign(chainId: bigint, entrypoint: string, signer: Signer): Promise<string> {
    const hash = ethers.getBytes(this.hash(chainId, entrypoint));
    this.signature = await signer.signMessage(hash);
    return this.signature;
  }

  //manually sets the signature field if account using signature scheme other than ECDSA
  public async setSignature(signature: string) {
    this.signature = signature;
  }

  //gets the hash of the intent
  public hash(chainId: bigint, entrypoint: string): string {
    const abi = new ethers.AbiCoder();
    const segments: BytesLike[] = this.segments.map((segment) => segment.asBytes());
    const segmentsHash = ethers.keccak256(abi.encode(['bytes[]'], [segments]));
    const intentHash = ethers.keccak256(abi.encode(['address', 'bytes32'], [this.sender, segmentsHash]));
    const hash = ethers.keccak256(abi.encode(['bytes32', 'address', 'uint256'], [intentHash, entrypoint, chainId]));
    return ethers.zeroPadValue(hash, 32);
  }

  //gets the intent object with segment data encoded
  public asUserIntentStruct(): UserIntentStruct {
    const segments: BytesLike[] = this.segments.map((segment) => segment.asBytes());
    return {
      sender: this.sender,
      segments,
      signature: this.signature,
    };
  }

  //validation functions
  private validateSender(sender: AddressLike) {
    if (!ethers.isAddress(sender)) throw new Error(`sender is not a valid address (sender: ${sender})`);
  }
}

// The intent segment object
export abstract class IntentSegment {
  //gets the bytes abi encoding of the segment
  abstract asBytes(): string;
}

// Intent solution builder helper function
export function buildSolution(timestamp: number, intents: UserIntent[], order: number[]): IntentSolutionStruct {
  const intentStructs = intents.map((userIntent) => userIntent.asUserIntentStruct());
  return {
    timestamp,
    intents: intentStructs,
    order,
  };
}
