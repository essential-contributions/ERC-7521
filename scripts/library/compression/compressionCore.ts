import { ethers } from 'ethers';
import { breakdownCalldata, initCalldataUtils } from './calldataUtils';

// Encoding Prefixes
// 000 - 1 byte dynamic dictionary [1-32] (items to put in storage)
// 001 - 1 byte closed stateful dictionary [1-32] (items specific to particular target)
// 010 - 2 byte closed stateful dictionary [1-8192] (function selectors, lengths of zeros greater than 64, multiples of 32, etc)
// 011 - 4 byte stateful dictionary [1-536870912] (addresses, hashes, etc)
// 100 - zeros [1-32]
// 101 - zero padded bytes (to 32) [1-32 zeros]
// 110 - regular bytes [1-32 bytes]
// 111 - decimal number

const PF_TYPE_MASK = 0xe0;
const PF_1BYTE_DICT = 0x00;
const PF_1BYTE_STATE = 0x20;
const PF_2BYTE_STATE = 0x40;
const PF_4BYTE_STATE = 0x60;
const PF_ZEROS = 0x80;
const PF_ZERO_PADDED = 0xa0;
const PF_NUM_BYTES = 0xc0;
const PF_NUMBER = 0xe0;

// Perform stateful encoding
export class CompressionCore {
  protected oneByteDictionary: Map<string, number> = new Map<string, number>();
  protected twoByteDictionary: Map<string, number> = new Map<string, number>();
  protected fourByteDictionary: Map<string, number> = new Map<string, number>();

  // Encodes the given array of bytes quickly, but may not be the most compressed
  public encodeFast(bytes: string, l3DictionaryEnabled: boolean = true): string {
    let hexPrefix = false;
    if (bytes.indexOf('0x') == 0) {
      hexPrefix = true;
      bytes = bytes.substring(2);
    }

    //encode via chunks
    const encoded: string[] = [];
    const chunks = breakdownCalldata(bytes);
    for (let i = 0; i < chunks.length; i++) {
      if (chunks[i].data.length <= 64) encoded.push(...this.doEncode(chunks[i].data, l3DictionaryEnabled));
      else encoded.push(...this.optimalEncode(chunks[i].data, l3DictionaryEnabled));
    }

    //finish encoding with dynamic dictionary
    let encodedString = this.compileWithDynamicDictionary(encoded);
    return (hexPrefix ? '0x' : '') + encodedString;
  }

  // Encodes the given array of bytes
  public encode(bytes: string, l3DictionaryEnabled: boolean = true): string {
    let hexPrefix = false;
    if (bytes.indexOf('0x') == 0) {
      hexPrefix = true;
      bytes = bytes.substring(2);
    }

    //get plain encoding
    const encoded = this.optimalEncode(bytes, l3DictionaryEnabled);

    //finish encoding with dynamic dictionary
    let encodedString = this.compileWithDynamicDictionary(encoded);
    return (hexPrefix ? '0x' : '') + encodedString;
  }

  // Decodes the given array of bytes
  public decode(bytes: string): string {
    let index = 0;
    let hexPrefix = false;
    if (bytes.indexOf('0x') == 0) {
      hexPrefix = true;
      bytes = bytes.substring(2);
    }

    //fill dynamic dictionary
    const dictLength = parseInt(bytes.substring(index, index + 2), 16);
    if (dictLength > 32) throw new Error('Invalid dictionary size');
    index += 2;
    const dictionary: string[] = [];
    for (let i = 0; i < dictLength; i++) {
      const decode = this.doDecode(bytes.substring(index, index + 66));
      dictionary.push(decode.decoded);
      index += decode.bytesRead * 2;
    }

    let decoded = hexPrefix ? '0x' : '';
    while (index < bytes.length) {
      const decode = this.doDecode(bytes.substring(index, index + 66), dictionary);
      decoded += decode.decoded;
      index += decode.bytesRead * 2;
    }
    return decoded;
  }

  // Get the length of the L1 dictionary
  public getL1DictionaryLength(): number {
    return this.oneByteDictionary.size;
  }

  // Get item from the L1 dictionary at the given index
  public getL1DictionaryItem(index: number): string {
    for (let item of this.oneByteDictionary.entries()) {
      if (item[1] == index) return item[0];
    }
    return '';
  }

  // Gets the length of the L2 dictionary
  public getL2DictionaryLength(): number {
    return this.twoByteDictionary.size;
  }

  // Get item from the L2 dictionary at the given index
  public getL2DictionaryItem(index: number): string {
    for (let item of this.twoByteDictionary.entries()) {
      if (item[1] == index) return item[0];
    }
    return '';
  }

  // Gets the length of the L3 dictionary
  public getL3DictionaryLength(): number {
    return this.fourByteDictionary.size;
  }

  // Get item from the L3 dictionary at the given index
  public getL3DictionaryItem(index: number): string {
    for (let item of this.fourByteDictionary.entries()) {
      if (item[1] == index) return item[0];
    }
    return '';
  }

  //////////////////////////////
  // Private Helper Functions //
  //////////////////////////////

  //encode single element (max 32bytes)
  private doEncode(bytes: string, l3DictionaryEnabled: boolean = true): string[] {
    if (!bytes) return [];
    bytes = (' ' + bytes).slice(1).toLowerCase();

    //encode by one byte lookup
    let encodedViaLookup1: string[] | undefined;
    const oneByteMatch = this.oneByteDictionary.get(bytes);
    if (oneByteMatch !== undefined) {
      encodedViaLookup1 = [toHex(PF_1BYTE_STATE + (oneByteMatch & ~PF_TYPE_MASK), 1)];
    }

    //encode by two byte lookup
    let encodedViaLookup2: string[] | undefined;
    const twoByteMatch = this.twoByteDictionary.get(bytes);
    if (twoByteMatch !== undefined) {
      encodedViaLookup1 = [toHex((PF_2BYTE_STATE << 8) + (twoByteMatch & ~(PF_TYPE_MASK << 8)), 2)];
    }

    //encode by four byte lookup
    let encodedViaLookup4: string[] | undefined;
    if (l3DictionaryEnabled) {
      const fourByteMatch = this.fourByteDictionary.get(bytes);
      if (fourByteMatch !== undefined) {
        encodedViaLookup4 = [toHex((PF_4BYTE_STATE << 24) + (fourByteMatch & ~(PF_TYPE_MASK << 24)), 4)];
      }
    }

    //encode by compressing zeros
    let encodedViaZeros: string[] | undefined;
    const leadZeros = leadingZeros(bytes);
    const zeroSplit = splitZeros(bytes, 3);
    if (zeroSplit.length > 1) {
      encodedViaZeros = [];
      for (const part of zeroSplit) {
        if (part.numZeros > 0) encodedViaZeros.push(toHex(PF_ZEROS + ((part.numZeros - 1) & ~PF_TYPE_MASK), 1));
        else encodedViaZeros.push(...this.doEncode(part.bytes, l3DictionaryEnabled));
      }
    } else if (leadZeros == bytes.length / 2) {
      encodedViaZeros = [toHex(PF_ZEROS + ((bytes.length / 2 - 1) & ~PF_TYPE_MASK), 1)];
    }

    //encode entirely by specifying leading zeros
    let encodedViaZeroPadding: string[] | undefined;
    if (leadZeros > 0 && bytes.length == 64) {
      encodedViaZeroPadding = [
        toHex(PF_ZERO_PADDED + ((leadZeros - 1) & ~PF_TYPE_MASK), 1) + bytes.substring(leadZeros * 2),
      ];
    }

    //encode by number format
    let encodedViaNumber: string[] | undefined;
    const num = toCompressedNumber(bytes);
    if (num !== undefined) {
      const enc = toHex(num.decimal, getPrecisionByteSize(num.precision));
      encodedViaNumber = [
        toHex(PF_NUMBER + (((num.size << 3) | num.precision) & ~PF_TYPE_MASK), 1) + enc + toHex(num.mult, 1),
      ];
    }

    //encode by declaring raw bytes
    let encodedViaRawBytes: string[] = [toHex(PF_NUM_BYTES + ((bytes.length / 2 - 1) & ~PF_TYPE_MASK), 1) + bytes];

    //return the smallest encoding
    let encoding = encodedViaRawBytes;
    if (encodedViaZeros && encoding.join('').length > encodedViaZeros.join('').length) encoding = encodedViaZeros;
    if (encodedViaZeroPadding && encoding.join('').length > encodedViaZeroPadding.join('').length)
      encoding = encodedViaZeroPadding;
    if (encodedViaNumber && encoding.join('').length > encodedViaNumber.join('').length) encoding = encodedViaNumber;
    if (encodedViaLookup1 && encoding.join('').length > encodedViaLookup1.join('').length) encoding = encodedViaLookup1;
    if (encodedViaLookup2 && encoding.join('').length > encodedViaLookup2.join('').length) encoding = encodedViaLookup2;
    if (encodedViaLookup4 && encoding.join('').length > encodedViaLookup4.join('').length) encoding = encodedViaLookup4;
    return encoding;
  }

  //decode a single element (to a max 32 bytes)
  private doDecode(bytes: string, dictionary?: string[]): { decoded: string; bytesRead: number } {
    if (!bytes) return { decoded: '', bytesRead: 0 };
    bytes = (' ' + bytes).slice(1);
    const byte = parseInt(bytes.substring(0, 2), 16);

    //1 byte state
    if (dictionary !== undefined) {
      if ((byte & PF_TYPE_MASK) == PF_1BYTE_DICT) {
        const index = byte & ~PF_TYPE_MASK;
        const bytesRead = 1;
        return { decoded: dictionary[index], bytesRead };
      }
    }
    if ((byte & PF_TYPE_MASK) == PF_1BYTE_STATE) {
      const index = byte & ~PF_TYPE_MASK;
      const bytesRead = 1;
      for (let item of this.oneByteDictionary.entries()) {
        if (item[1] == index) {
          return { decoded: item[0], bytesRead };
        }
      }
    }

    //2 byte state
    if ((byte & PF_TYPE_MASK) == PF_2BYTE_STATE) {
      const bytesRead = 2;
      if (bytes.length > 2) {
        const bytes2 = parseInt(bytes.substring(0, 4), 16);
        const index = bytes2 & ~(PF_TYPE_MASK << 8);
        for (let item of this.twoByteDictionary.entries()) {
          if (item[1] == index) {
            return { decoded: item[0], bytesRead };
          }
        }
      }
      return { decoded: '', bytesRead };
    }

    //4 byte state
    if ((byte & PF_TYPE_MASK) == PF_4BYTE_STATE) {
      const bytesRead = 4;
      if (bytes.length > 2) {
        const bytes4 = parseInt(bytes.substring(0, 8), 16);
        const index = bytes4 & ~(PF_TYPE_MASK << 24);
        for (let item of this.fourByteDictionary.entries()) {
          if (item[1] == index) {
            return { decoded: item[0], bytesRead };
          }
        }
      }
      return { decoded: '', bytesRead };
    }

    //zeros
    if ((byte & PF_TYPE_MASK) == PF_ZEROS) {
      const num = (byte & ~PF_TYPE_MASK) + 1;
      return { decoded: ''.padStart(num * 2, '0'), bytesRead: 1 };
    }

    //padded zeros
    if ((byte & PF_TYPE_MASK) == PF_ZERO_PADDED) {
      const zeros = (byte & ~PF_TYPE_MASK) + 1;
      const num = 32 - zeros;
      if (bytes.length > 2) {
        return { decoded: ''.padStart(zeros * 2, '0') + bytes.substring(2, 2 + num * 2), bytesRead: num + 1 };
      }
      return { decoded: '', bytesRead: num + 1 };
    }

    //bytes
    if ((byte & PF_TYPE_MASK) == PF_NUM_BYTES) {
      const num = (byte & ~PF_TYPE_MASK) + 1;
      if (bytes.length > 2) {
        return { decoded: bytes.substring(2, 2 + num * 2), bytesRead: num + 1 };
      }
      return { decoded: '', bytesRead: num + 1 };
    }

    //number
    if ((byte & PF_TYPE_MASK) == PF_NUMBER) {
      const size = (byte >> 3) & 0x03;
      const precision = byte & 0x07;
      const dataLength = getPrecisionByteSize(precision);
      if (bytes.length > 2) {
        const data = bytes.substring(2, (dataLength + 1) * 2);
        const mult = parseInt(bytes.substring((dataLength + 1) * 2, (dataLength + 2) * 2), 16);
        return { decoded: fromCompressedNumber(size, parseInt(data, 16), mult), bytesRead: dataLength + 2 };
      }
      return { decoded: '', bytesRead: dataLength + 2 };
    }

    throw new Error('Failed to decode');
  }

  //slower recursive encoding for optimal compression
  private optimalEncode(bytes: string, l3DictionaryEnabled: boolean = true): string[] {
    const root = this;
    const encodingResults = new Map<string, string[]>();
    function encodeSingle(bytes: string): string[] {
      if (!encodingResults.has(bytes)) {
        encodingResults.set(bytes, root.doEncode(bytes, l3DictionaryEnabled));
      }
      return encodingResults.get(bytes) ?? [];
    }

    const encodingAtIndex = new Map<number, string[]>();
    function encodeRecursive(index: number): string[] {
      if (index >= bytes.length) return [];
      if (!encodingAtIndex.has(index)) {
        let smallestEncoding: string[] | undefined;
        for (let i = 64; i > 0; i -= 2) {
          if (index + i <= bytes.length) {
            const encoding = [...encodeSingle(bytes.substring(index, index + i)), ...encodeRecursive(index + i)];
            if (!smallestEncoding || encoding.join('').length < smallestEncoding.join('').length) {
              smallestEncoding = encoding;
            }
          }
        }
        encodingAtIndex.set(index, smallestEncoding ?? []);
      }
      return encodingAtIndex.get(index) ?? [];
    }

    //prefill encoding results
    for (let i = 0; i < bytes.length; i += 2) {
      for (let j = 64; j > 0; j -= 2) {
        if (i + j <= bytes.length) encodeSingle(bytes.substring(i, i + j));
      }
    }
    for (let i = bytes.length - 2; i > 0; i -= 2) encodeRecursive(i);

    //recursion start
    return encodeRecursive(0);
  }

  //build dynamic dictionary and compile encoded parts with it
  private compileWithDynamicDictionary(encoded: string[]): string {
    const items = new Map<string, number>();
    for (let enc of encoded) {
      if (items.has(enc)) items.set(enc, (items.get(enc) ?? 0) + (enc.length / 2 - 1));
      else items.set(enc, -1);
    }
    const sorted = [...items.entries()].sort((a, b) => b[1] - a[1]);
    const dictionary: string[] = [];
    for (let i = 0; i < 32; i++) {
      if (i < sorted.length) {
        if (sorted[i][1] > 0) dictionary.push(sorted[i][0]);
        else break;
      }
    }

    //TODO: mark dynamic dictionary items for storage

    //finish encoding with dynamic dictionary
    let encodedString = toHex(dictionary.length, 1);
    for (let ent of dictionary) {
      encodedString += ent;
    }
    for (let enc of encoded) {
      const dictRef = dictionary.indexOf(enc);
      if (dictRef > -1) encodedString += toHex(PF_1BYTE_DICT + dictRef, 1);
      else encodedString += enc;
    }
    return encodedString;
  }
}

// Helper functions
function splitZeros(bytes: string, minSize: number = 1): { bytes: string; numZeros: number }[] {
  let runs: { bytes: string; numZeros: number }[] = [];
  let i = 0;
  let run = '';
  while (i < bytes.length) {
    if (bytes.substring(i, i + 2) == '00') {
      while (bytes.substring(i, i + 2) == '00' && i < bytes.length) {
        run += '00';
        i += 2;
      }
      if (run.length >= minSize * 2) {
        runs.push({ bytes: run, numZeros: run.length / 2 });
        run = '';
      }
    } else {
      while (bytes.substring(i, i + 2) != '00' && i < bytes.length) {
        run += bytes.substring(i, i + 2);
        i += 2;
      }
      runs.push({ bytes: run, numZeros: 0 });
      run = '';
    }
  }
  if (run.length > 0) {
    if (runs.length == 0) runs.push({ bytes: run, numZeros: 0 });
    else runs[runs.length - 1].bytes += run;
  }
  return runs;
}
function leadingZeros(bytes: string): number {
  let countZeros = 0;
  let i = 0;
  while (bytes.substring(i, i + 2) == '00' && i < bytes.length) {
    i += 2;
    countZeros++;
  }
  return countZeros;
}
function toHex(item: number | bigint | string, padBytes: number): string {
  if (typeof item === 'number') {
    return item.toString(16).padStart(padBytes * 2, '0');
  }
  if (typeof item === 'bigint') {
    return item.toString(16).padStart(padBytes * 2, '0');
  }
  return item.padStart(padBytes * 2, '0');
}
function toCompressedNumber(
  bytes: string,
): { size: number; precision: number; decimal: number; mult: number } | undefined {
  let decimal = ethers.toBigInt('0x' + bytes).toString();
  let mult = 0;
  while (decimal[decimal.length - 1] == '0' && decimal.length > 1) {
    decimal = decimal.substring(0, decimal.length - 1);
    mult++;
  }

  let size: number | undefined;
  if (bytes.length / 2 == 4) size = 0;
  else if (bytes.length / 2 == 8) size = 1;
  else if (bytes.length / 2 == 16) size = 2;
  else if (bytes.length / 2 == 32) size = 3;

  let precision: number | undefined;
  if (ethers.toBigInt(decimal) < 0xffn) precision = 0;
  else if (ethers.toBigInt(decimal) <= 0xffffn) precision = 1;
  else if (ethers.toBigInt(decimal) <= 0xffffffn) precision = 2;
  else if (ethers.toBigInt(decimal) <= 0xffffffffn) precision = 3;
  else if (ethers.toBigInt(decimal) <= 0xffffffffffffn) precision = 4;
  else if (ethers.toBigInt(decimal) <= 0xffffffffffffffffn) precision = 5;
  else if (ethers.toBigInt(decimal) <= 0xffffffffffffffffffffffffn) precision = 6;
  else if (ethers.toBigInt(decimal) <= 0xffffffffffffffffffffffffffffffffn) precision = 7;

  if (precision !== undefined && size !== undefined) return { size, precision, decimal: Number(decimal), mult };
}
function fromCompressedNumber(size: number, decimal: number, mult: number): string {
  let paddedSize = 0;
  if (size == 0) paddedSize = 4;
  else if (size == 1) paddedSize = 8;
  else if (size == 2) paddedSize = 16;
  else if (size == 3) paddedSize = 32;

  const number = ethers.toBigInt(decimal) * 10n ** BigInt(mult);
  return toHex(number, paddedSize);
}
function getPrecisionByteSize(precision: number): number {
  const byteSize = [1, 2, 3, 4, 6, 8, 12, 16];
  return byteSize[precision];
}

//Compression tester with manual control over dictionaries
export class CompressionTest extends CompressionCore {
  public setL1Dictionary(items: string[]) {
    this.oneByteDictionary.clear();
    for (let i = 0; i < items.length && i < 32; i++) {
      this.oneByteDictionary.set(items[i].substring(2), i);
    }
  }
  public setL2Dictionary(items: string[]) {
    this.twoByteDictionary.clear();
    for (let i = 0; i < items.length && i < 8192; i++) {
      this.twoByteDictionary.set(items[i].substring(2), i);
    }
  }
  public setL3Dictionary(items: string[]) {
    this.fourByteDictionary.clear();
    for (let i = 0; i < items.length && i < 536870912; i++) {
      this.fourByteDictionary.set(items[i].substring(2), i);
    }
  }
}
