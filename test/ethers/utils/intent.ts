import { expect } from 'chai';
import { BlsSignerInterface, BlsVerifier } from '@thehubbleproject/bls/dist/signer';
import { IntentSolutionStruct, UserIntentStruct } from '../../../typechain/src/core/EntryPoint';
import { ethers, AddressLike, BigNumberish, BytesLike, Provider, Signer } from 'ethers';
import { BLSSignatureAggregator } from '../../../typechain';
import { hashToPoint } from '@thehubbleproject/bls/dist/mcl';

// The intent object
export class UserIntent {
  private sender: AddressLike;
  private segments: IntentSegment[];
  private signature: string;

  constructor(sender?: AddressLike) {
    if (sender) this.validateSender(sender);
    this.sender = sender || '0x0000000000000000000000000000000000000000';
    this.segments = [];
    this.signature = '0x0000000000000000000000000000000000000000000000000000000000000000';
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

  public async signBLS(
    signer: BlsSignerInterface,
    blsAggregator: BLSSignatureAggregator,
    bls_domain: Uint8Array,
  ): Promise<string> {
    const requestHash = await blsAggregator.getUserIntentHash(this.asUserIntentStruct());
    const sigParts = signer.sign(requestHash);
    this.signature = ethers.concat(sigParts);
    expect(this.signature.length).to.equal(130); // 64-byte hex value

    const verifier = new BlsVerifier(bls_domain);
    expect(verifier.verify(sigParts, signer.pubkey, requestHash)).to.equal(true);

    const ret = await blsAggregator.validateIntentSignature(this.asUserIntentStruct());
    expect(ret).to.equal('0x');

    return this.signature;
  }

  //gets the hash of the intent
  public hash(chainId: bigint, entrypoint: string): string {
    const abi = new ethers.AbiCoder();
    const intentData: BytesLike[] = this.segments.map((segment) => segment.asBytes());
    const intentDataHash = ethers.keccak256(abi.encode(['bytes[]'], [intentData]));
    const intentHash = ethers.keccak256(abi.encode(['address', 'bytes32'], [this.sender, intentDataHash]));
    return ethers.keccak256(abi.encode(['bytes32', 'address', 'uint256'], [intentHash, entrypoint, chainId]));
  }

  //gets the intent object with segment data encoded
  public asUserIntentStruct(): UserIntentStruct {
    const intentData: BytesLike[] = this.segments.map((segment) => segment.asBytes());
    return {
      sender: this.sender,
      intentData,
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
