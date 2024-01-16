import * as mcl from 'mcl-wasm';
import { Fr, G1, G2 } from 'mcl-wasm';
import { ethers } from 'ethers';

/// Note:
/// Based on the Hubble BLS typesript library from the Hubble Project.
/// Find the original source here: https://github.com/thehubbleproject/hubble-bls/blob/master/src/mcl.ts

export const FIELD_ORDER = BigInt('0x30644e72e131a029b85045b68181585d97816a916871ca8d3c208c16d87cfd47');

export { Fr, G1, G2 };
export type Domain = Uint8Array;

export async function init() {
  await mcl.init(mcl.BN_SNARK1);
  mcl.setMapToMode(mcl.BN254);
}

export function validateHex(hex: string) {
  if (!ethers.isHexString(hex)) throw new Error(`BadHex: Expect hex but got ${hex}`);
}

export function validateDomain(domain: Domain) {
  if (domain.length != 32) throw new Error(`BadDomain: Expect 32 bytes but got ${domain.length}`);
}

export function hashToPoint(msg: string, domain: Domain): G1 {
  if (!ethers.isHexString(msg)) throw new Error(`BadMessage: Expect hex string but got ${msg}`);

  const _msg = toBeArray(msg);
  const [e0, e1] = hashToField(domain, _msg, 2);
  const p0 = mapToPoint(e0);
  const p1 = mapToPoint(e1);
  const p = mcl.add(p0, p1);
  p.normalize();
  return p;
}

export function hashToField(domain: Uint8Array, msg: Uint8Array, count: number): bigint[] {
  const u = 48;
  const _msg = expandMsg(domain, msg, count * u);
  const els = [];
  for (let i = 0; i < count; i++) {
    const el = BigInt(ethers.hexlify(_msg.slice(i * u, (i + 1) * u))) % FIELD_ORDER;
    els.push(el);
  }
  return els;
}

export function expandMsg(domain: Uint8Array, msg: Uint8Array, outLen: number): Uint8Array {
  validateDomain(domain);

  const out: Uint8Array = new Uint8Array(outLen);

  const len0 = 64 + msg.length + 2 + 1 + domain.length + 1;
  const in0: Uint8Array = new Uint8Array(len0);
  // zero pad
  let off = 64;
  // msg
  in0.set(msg, off);
  off += msg.length;
  // l_i_b_str
  in0.set([(outLen >> 8) & 0xff, outLen & 0xff], off);
  off += 2;
  // I2OSP(0, 1)
  in0.set([0], off);
  off += 1;
  // DST_prime
  in0.set(domain, off);
  off += domain.length;
  in0.set([domain.length], off);

  const b0 = ethers.sha256(in0);

  const len1 = 32 + 1 + domain.length + 1;
  const in1: Uint8Array = new Uint8Array(len1);
  // b0
  in1.set(toBeArray(b0, 32), 0);
  off = 32;
  // I2OSP(1, 1)
  in1.set([1], off);
  off += 1;
  // DST_prime
  in1.set(domain, off);
  off += domain.length;
  in1.set([domain.length], off);

  const b1 = ethers.sha256(in1);

  // b_i = H(strxor(b_0, b_(i - 1)) || I2OSP(i, 1) || DST_prime);
  const ell = Math.floor((outLen + 32 - 1) / 32);
  let bi = b1;

  for (let i = 1; i < ell; i++) {
    const ini: Uint8Array = new Uint8Array(32 + 1 + domain.length + 1);
    const nb0 = toBeArray(b0, 32);
    const nbi = toBeArray(bi, 32);
    const tmp = new Uint8Array(32);
    for (let i = 0; i < 32; i++) {
      tmp[i] = nb0[i] ^ nbi[i];
    }

    ini.set(tmp, 0);
    let off = 32;
    ini.set([1 + i], off);
    off += 1;
    ini.set(domain, off);
    off += domain.length;
    ini.set([domain.length], off);

    out.set(toBeArray(bi, 32), 32 * (i - 1));
    bi = ethers.sha256(ini);
  }

  out.set(toBeArray(bi, 32), 32 * (ell - 1));
  return out;
}

export function mapToPoint(e0: bigint): G1 {
  let e1 = new mcl.Fp();
  e1.setStr((e0 % FIELD_ORDER).toString());
  return e1.mapToG1();
}

export function toBigEndian(p: mcl.Fp | mcl.Fp2): Uint8Array {
  // serialize() gets a little-endian output of Uint8Array
  // reverse() turns it into big-endian, which Solidity likes
  return p.serialize().reverse();
}

export function g1(): G1 {
  const g1 = new G1();
  g1.setStr('1 0x01 0x02', 16);
  return g1;
}

export function g2(): G2 {
  const g2 = new G2();
  g2.setStr(
    '1 0x1800deef121f1e76426a00665e5c4479674322d4f75edadd46debd5cd992f6ed 0x198e9393920d483a7260bfb731fb5d25f1aa493335a9e71297e485b7aef312c2 0x12c85ea5db8c6deb4aab71808dcb408fe3d1e7690c43d37b4ce6cc0166fa7daa 0x090689d0585ff075ec9e99ad690c3395bc4b313370b38ef355acdadcd122975b',
  );
  return g2;
}

export function negativeG2(): G2 {
  const g2 = new G2();
  g2.setStr(
    '1 0x1800deef121f1e76426a00665e5c4479674322d4f75edadd46debd5cd992f6ed 0x198e9393920d483a7260bfb731fb5d25f1aa493335a9e71297e485b7aef312c2 0x1d9befcd05a5323e6da4d435f3b617cdb3af83285c2df711ef39c01571827f9d 0x275dc4a288d1afb3cbb1ac09187524c7db36395df7be3b99e673b13a075a65ec',
  );
  return g2;
}

export function getPubkey(secret: Fr): G2 {
  const pubkey = mcl.mul(g2(), secret);
  pubkey.normalize();
  return pubkey;
}

export function sign(message: string, secret: Fr, domain: Domain): { signature: G1; messagePoint: G1 } {
  const messagePoint = hashToPoint(message, domain);
  const signature = mcl.mul(messagePoint, secret);
  signature.normalize();
  return { signature, messagePoint };
}

export function verifyRaw(signature: G1, pubkey: G2, message: G1): boolean {
  const negG2 = new mcl.PrecomputedG2(negativeG2());

  const pairings = mcl.precomputedMillerLoop2mixed(message, pubkey, signature, negG2);
  // call this function to avoid memory leak
  negG2.destroy();
  return mcl.finalExp(pairings).isOne();
}

export function verifyMultipleRaw(aggG1: G1, pubkeys: G2[], messages: G1[]): boolean {
  const size = pubkeys.length;
  if (size === 0) throw new Error('EmptyArray: number of public key is zero');
  if (size != messages.length) throw new Error(`MismatchLength: public keys ${size}; messages ${messages.length}`);
  const negG2 = new mcl.PrecomputedG2(negativeG2());
  let accumulator = mcl.precomputedMillerLoop(aggG1, negG2);
  for (let i = 0; i < size; i++) {
    accumulator = mcl.mul(accumulator, mcl.millerLoop(messages[i], pubkeys[i]));
  }
  // call this function to avoid memory leak
  negG2.destroy();
  return mcl.finalExp(accumulator).isOne();
}

export function aggregateRaw(signatures: G1[]): G1 {
  let aggregated = new G1();
  for (const sig of signatures) {
    aggregated = mcl.add(aggregated, sig);
  }
  aggregated.normalize();
  return aggregated;
}

export function randFr(): Fr {
  const r = ethers.hexlify(ethers.randomBytes(12));
  let fr = new Fr();
  fr.setHashOf(r);
  return fr;
}

export function randMclG1(): G1 {
  const p = mcl.mul(g1(), randFr());
  p.normalize();
  return p;
}

export function randMclG2(): G2 {
  const p = mcl.mul(g2(), randFr());
  p.normalize();
  return p;
}

export function parseFr(hex: string) {
  validateHex(hex);
  const fr = new Fr();
  fr.setStr(hex);
  return fr;
}

export function setHashFr(hex: string) {
  validateHex(hex);
  const fr = new Fr();
  fr.setHashOf(hex);
  return fr;
}

export function dumpFr(fr: Fr): string {
  return `0x${fr.serializeToHexStr()}`;
}

export function loadFr(hex: string): Fr {
  const fr = new Fr();
  fr.deserializeHexStr(hex.slice(2));
  return fr;
}

//Helper function to convert hex string to 32 byte long Uint8Array
function toBeArray(hex: string, len: number = 0): Uint8Array {
  if (hex.indexOf('0x') == 0) hex = hex.substring(2);
  if (hex.length % 2) hex = '0' + hex;
  if (len === 0) len = hex.length / 2;

  const result = new Uint8Array(len);
  const offset = len - hex.length / 2;
  for (let i = hex.length - 2; i >= 0; i -= 2) {
    const index = offset + i / 2;
    if (index < len && index >= 0) result[index] = parseInt(hex.substring(i, i + 2), 16);
  }
  return result;
}
