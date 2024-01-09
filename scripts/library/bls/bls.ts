import {
  init as mclInit,
  Fr,
  G1,
  G2,
  Domain,
  getPubkey,
  sign,
  randFr,
  parseFr,
  setHashFr,
  aggregateRaw,
  verifyRaw,
  verifyMultipleRaw,
  hashToPoint,
  toBigEndian,
} from './mcl';
import { ethers } from 'ethers';

/// Note:
/// Based on the Hubble BLS typesript library from the Hubble Project.
/// Find the original source here: https://github.com/thehubbleproject/hubble-bls/blob/master/src/signer.ts

export type Signature = string;
export type PublicKey = [string, string, string, string];

// Interface for a BLS signer
export interface BlsSignerInterface {
  pubkey: PublicKey;
  sign(message: string): Signature;
  verify(signature: Signature, pubkey: PublicKey, message: string): boolean;
  verifyMultiple(aggSignature: Signature, pubkeys: PublicKey[], messages: string[]): boolean;
}

// Factory for generating BLS signers
export class BlsSignerFactory {
  static async new(domain: Domain) {
    await init();
    return new BlsSignerFactory(domain);
  }
  private constructor(public domain: Domain) {}

  public createSigner(secretHex?: string) {
    let secret = randFr();
    if (secretHex) {
      try {
        // Attempt to directly parse the hex
        secret = parseFr(secretHex);
      } catch {
        // If that fails, hash it
        secret = setHashFr(secretHex);
      }
    }
    return new BlsSigner(this.domain, secret);
  }
}

// Verifier for BLS signatures under a given domain
export class BlsVerifier {
  constructor(public domain: Domain) {}

  public aggregate(signatures: Signature[]): Signature {
    const signatureG1s = signatures.map((s) => parseSignature(s));
    const aggregated = aggregateRaw(signatureG1s);
    return g1ToHex(aggregated);
  }

  public verify(signature: Signature, pubkey: PublicKey, message: string) {
    const signatureG1 = parseSignature(signature);
    const pubkeyG2 = parsePublicKey(pubkey);
    const messagePoint = hashToPoint(message, this.domain);
    return verifyRaw(signatureG1, pubkeyG2, messagePoint);
  }

  public verifyMultiple(aggSignature: Signature, pubkeys: PublicKey[], messages: string[]) {
    const signatureG1 = parseSignature(aggSignature);
    const pubkeyG2s = pubkeys.map(parsePublicKey);
    const messagePoints = messages.map((m) => hashToPoint(m, this.domain));
    return verifyMultipleRaw(signatureG1, pubkeyG2s, messagePoints);
  }
}

// BLS signer with additional verification functionality
export class BlsSigner extends BlsVerifier implements BlsSignerInterface {
  private key: G2;

  constructor(
    public domain: Domain,
    private secret: Fr,
  ) {
    super(domain);
    this.key = getPubkey(secret);
  }

  get pubkey(): PublicKey {
    return g2ToHex(this.key);
  }

  public sign(message: string): Signature {
    const { signature } = sign(message, this.secret, this.domain);
    return g1ToHex(signature);
  }
}

///////////////////////
// Private functions //
///////////////////////

// Private function to make sure the mcl environment has been initialized
let isInitialized = false;
async function init() {
  if (!isInitialized) {
    await mclInit();
  }
  isInitialized = true;
}

function g1ToHex(p: G1): Signature {
  p.normalize();
  const x = ethers.hexlify(toBigEndian(p.getX()));
  const y = ethers.hexlify(toBigEndian(p.getY()));
  return x + y.substring(2);
}

function g2ToHex(p: G2): PublicKey {
  p.normalize();
  const x = toBigEndian(p.getX());
  const x0 = ethers.hexlify(x.slice(32));
  const x1 = ethers.hexlify(x.slice(0, 32));
  const y = toBigEndian(p.getY());
  const y0 = ethers.hexlify(y.slice(32));
  const y1 = ethers.hexlify(y.slice(0, 32));
  return [x0, x1, y0, y1];
}

function parseSignature(s: Signature): G1 {
  const g1 = new G1();
  const x = `0x${s.substring(2, 2 + 64)}`;
  const y = `0x${s.substring(2 + 64, 2 + 128)}`;
  g1.setStr(`1 ${x} ${y}`, 16);
  return g1;
}

function parsePublicKey(k: PublicKey): G2 {
  const g2 = new G2();
  const [x0, x1, y0, y1] = k;
  g2.setStr(`1 ${x0} ${x1} ${y0} ${y1}`);
  return g2;
}
