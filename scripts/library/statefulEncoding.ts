import { ethers } from 'ethers';
// TODO: eventually add a contract to shadow

// Encoding Prefixes
// 00x - 1 byte stateful common bytes [0-63] (extremely common addresses, function selectors, etc)
// 010 - 2 byte stateful common bytes [0-16,383] (function selectors, lengths of Zeros, etc)
// 011 - 4 byte stateful common bytes [0-536,870,911] (addresses, hashes, etc)
// 100 - zeros [1-32]
// 101 - zero padded bytes (to 32) [1-32 num bytes]
// 110 - regular bytes [1-32 num bytes]
// 111 - 6-10 byte compressed 256bit number
const PF_TYPE1_MASK = 0xc0;
const PF_TYPE2_MASK = 0xe0;
const PF_1BYTE_STATE = 0x00;
const PF_2BYTE_STATE = 0x40;
const PF_4BYTE_STATE = 0x60;
const PF_ZEROS = 0x80;
const PF_ZERO_PADDED = 0xa0;
const PF_NUM_BYTES = 0xc0;
const PF_NUMBER = 0xe0;

// Perform stateful encoding
export class StatefulEncoding {
  private oneByteList: string[] = [];
  private twoByteList: string[] = [];
  private fourByteList: string[] = [];

  //TODO: sync lists with a contract
  public init() {}

  //Adds an array of bytes to the single byte encoding registry
  public addOneByteItem(bytes: string): number {
    const index = this.oneByteList.indexOf(bytes);
    if (index > -1) return index;
    this.oneByteList.push(bytes);
    return this.oneByteList.length - 1;
  }

  //Adds an array of bytes to the two byte encoding registry
  public addTwoByteItem(bytes: string): number {
    const index = this.twoByteList.indexOf(bytes);
    if (index > -1) return index;
    this.twoByteList.push(bytes);
    return this.twoByteList.length - 1;
  }

  //Adds an array of bytes to the four byte encoding registry
  public addFourByteItem(bytes: string): number {
    const index = this.fourByteList.indexOf(bytes);
    if (index > -1) return index;
    this.fourByteList.push(bytes);
    return this.fourByteList.length - 1;
  }

  //Encodes the given array of bytes
  public encode(bytes: string): string {
    let hexPrefix = false;
    if (bytes.indexOf('0x') == 0) {
      hexPrefix = true;
      bytes = bytes.substring(2);
    }
    const root = this;
    const encodingResults = new Map<string, string>();
    function encodeSingle(bytes: string): string {
      if (!encodingResults.has(bytes)) {
        encodingResults.set(bytes, root.doEncode(bytes));
      }
      return encodingResults.get(bytes) ?? '';
    }

    const encodingAtIndex = new Map<number, string>();
    function encodeRecursive(index: number): string {
      if (index >= bytes.length) return '';
      if (!encodingAtIndex.has(index)) {
        let smallestEncoding = ''.padEnd(bytes.length, '0');
        for (let i = 64; i > 0; i -= 2) {
          const encoding = encodeSingle(bytes.substring(index, index + i)) + encodeRecursive(index + i);
          if (encoding.length < smallestEncoding.length) smallestEncoding = encoding;
        }
        encodingAtIndex.set(index, smallestEncoding);
      }
      return encodingAtIndex.get(index) ?? '';
    }

    //prefill encoding results
    for (let i = 0; i < bytes.length; i += 2) {
      for (let j = 64; j > 0; j -= 2) encodeSingle(bytes.substring(i, i + j));
    }
    for (let i = bytes.length - 2; i > 0; i -= 2) encodeRecursive(i);

    return (hexPrefix ? '0x' : '') + encodeRecursive(0);
  }

  //Dencodes the given array of bytes
  public decode(bytes: string): string {
    let hexPrefix = false;
    if (bytes.indexOf('0x') == 0) {
      hexPrefix = true;
      bytes = bytes.substring(2);
    }

    let decoded = hexPrefix ? '0x' : '';
    for (let i = 0; i < bytes.length; ) {
      const decode = this.doDecode(bytes.substring(i, i + 66));
      decoded += decode.decoded;
      i += decode.bytesRead * 2;
    }
    return decoded;
  }

  //encode single element (max 32bytes)
  public singleEncode(bytes: string, trimLeadingZeros: boolean = false): string {
    const fullEncode = this.doEncode(bytes);
    if (trimLeadingZeros) {
      const trimmedEncode = this.doEncode(bytes.substring(leadingZeros(bytes) * 2));
      return trimmedEncode.length < fullEncode.length ? trimmedEncode : fullEncode;
    }
    return fullEncode;
  }

  //decode a single element total length (to a max 32 bytes)
  public singleDecodeLength(bytes: string): number {
    return this.doDecode(bytes).bytesRead;
  }

  //decode a single element (to a max 32 bytes)
  public singleDecode(bytes: string, addLeadingZeros: boolean = false): string {
    if (addLeadingZeros) return toHex(this.doDecode(bytes).decoded, 32);
    return this.doDecode(bytes).decoded;
  }

  //////////////////////////////
  // Private Helper Functions //
  //////////////////////////////

  //encode single element (max 32bytes)
  private doEncode(bytes: string): string {
    if (!bytes) return '';
    bytes = (' ' + bytes).slice(1);

    //encode by one byte lookup
    let encodedViaLookup1: string | undefined;
    const oneByteMatch = findMatch(bytes, this.oneByteList);
    if (oneByteMatch !== undefined) {
      encodedViaLookup1 = '';
      for (const part of oneByteMatch) {
        if (part.index > -1) encodedViaLookup1 += toHex(PF_1BYTE_STATE + (part.index & ~PF_TYPE1_MASK), 1);
        else encodedViaLookup1 += this.doEncode(part.bytes);
      }
    }

    //encode by two byte lookup
    let encodedViaLookup2: string | undefined;
    const twoByteMatch = findMatch(bytes, this.twoByteList);
    if (twoByteMatch !== undefined) {
      encodedViaLookup2 = '';
      for (const part of twoByteMatch) {
        if (part.index > -1)
          encodedViaLookup2 += toHex((PF_2BYTE_STATE << 8) + (part.index & ~(PF_TYPE2_MASK << 8)), 2);
        else encodedViaLookup2 += this.doEncode(part.bytes);
      }
    }

    //encode by four byte lookup
    let encodedViaLookup4: string | undefined;
    const fourByteMatch = findMatch(bytes, this.fourByteList);
    if (fourByteMatch !== undefined) {
      encodedViaLookup4 = '';
      for (const part of fourByteMatch) {
        if (part.index > -1)
          encodedViaLookup4 += toHex((PF_4BYTE_STATE << 24) + (part.index & ~(PF_TYPE2_MASK << 24)), 4);
        else encodedViaLookup4 += this.doEncode(part.bytes);
      }
    }

    //encode by compressing zeros
    let encodedViaZeros: string | undefined;
    const leadZeros = leadingZeros(bytes);
    const zeroSplit = splitZeros(bytes, 3);
    if (zeroSplit.length > 1) {
      encodedViaZeros = '';
      for (const part of zeroSplit) {
        if (part.numZeros > 0) encodedViaZeros += toHex(PF_ZEROS + ((part.numZeros - 1) & ~PF_TYPE2_MASK), 1);
        else encodedViaZeros += this.doEncode(part.bytes);
      }
    } else if (leadZeros == bytes.length / 2) {
      encodedViaZeros = toHex(PF_ZEROS + ((bytes.length / 2 - 1) & ~PF_TYPE2_MASK), 1);
    }

    //encode entirely by specifying leading zeros
    let encodedViaZeroPadding: string | undefined;
    if (leadZeros > 0 && bytes.length == 64) {
      encodedViaZeroPadding =
        toHex(PF_ZERO_PADDED + ((leadZeros - 1) & ~PF_TYPE2_MASK), 1) + bytes.substring(leadZeros * 2);
    }

    //encode by number format
    let encodedViaNumber: string | undefined;
    const num = toCompressedNumber(bytes);
    if (num !== undefined) {
      const enc = toHex(num.decimal, getPrecisionByteSize(num.precision));
      encodedViaNumber =
        toHex(PF_NUMBER + (((num.size << 3) | num.precision) & ~PF_TYPE2_MASK), 1) + enc + toHex(num.shift, 1);
    }

    //encode by declaring raw bytes
    let encodedViaRawBytes: string = toHex(PF_NUM_BYTES + ((bytes.length / 2 - 1) & ~PF_TYPE2_MASK), 1) + bytes;

    //return the smallest encoding
    let encoding = encodedViaRawBytes;
    if (encodedViaLookup1 && encoding.length > encodedViaLookup1.length) encoding = encodedViaLookup1;
    if (encodedViaLookup2 && encoding.length > encodedViaLookup2.length) encoding = encodedViaLookup2;
    if (encodedViaLookup4 && encoding.length > encodedViaLookup4.length) encoding = encodedViaLookup4;
    if (encodedViaZeros && encoding.length > encodedViaZeros.length) encoding = encodedViaZeros;
    if (encodedViaZeroPadding && encoding.length > encodedViaZeroPadding.length) encoding = encodedViaZeroPadding;
    if (encodedViaNumber && encoding.length > encodedViaNumber.length) encoding = encodedViaNumber;
    return encoding;
  }

  //decode a single element (to a max 32 bytes)
  private doDecode(bytes: string): { decoded: string; bytesRead: number } {
    if (!bytes) return { decoded: '', bytesRead: 0 };
    bytes = (' ' + bytes).slice(1);
    const byte = parseInt(bytes.substring(0, 2), 16);

    //1 byte state
    if ((byte & PF_TYPE1_MASK) == PF_1BYTE_STATE) {
      const index = byte & ~PF_TYPE1_MASK;
      const bytesRead = 1;
      return { decoded: this.oneByteList[index], bytesRead };
    }

    //2 byte state
    if ((byte & PF_TYPE2_MASK) == PF_2BYTE_STATE) {
      const bytesRead = 2;
      if (bytes.length > 2) {
        const bytes2 = parseInt(bytes.substring(0, 4), 16);
        const index = bytes2 & ~(PF_TYPE2_MASK << 8);
        return { decoded: this.twoByteList[index], bytesRead };
      }
      return { decoded: '', bytesRead };
    }

    //4 byte state
    if ((byte & PF_TYPE2_MASK) == PF_4BYTE_STATE) {
      const bytesRead = 4;
      if (bytes.length > 2) {
        const bytes4 = parseInt(bytes.substring(0, 8), 16);
        const index = bytes4 & ~(PF_TYPE2_MASK << 24);
        return { decoded: this.fourByteList[index], bytesRead };
      }
      return { decoded: '', bytesRead };
    }

    //zeros
    if ((byte & PF_TYPE2_MASK) == PF_ZEROS) {
      const num = (byte & ~PF_TYPE2_MASK) + 1;
      return { decoded: ''.padStart(num * 2, '0'), bytesRead: 1 };
    }

    //padded zeros
    if ((byte & PF_TYPE2_MASK) == PF_ZERO_PADDED) {
      const zeros = (byte & ~PF_TYPE2_MASK) + 1;
      const num = 32 - zeros;
      if (bytes.length > 2) {
        return { decoded: ''.padStart(zeros * 2, '0') + bytes.substring(2, 2 + num * 2), bytesRead: num + 1 };
      }
      return { decoded: '', bytesRead: num + 1 };
    }

    //bytes
    if ((byte & PF_TYPE2_MASK) == PF_NUM_BYTES) {
      const num = (byte & ~PF_TYPE2_MASK) + 1;
      if (bytes.length > 2) {
        return { decoded: bytes.substring(2, 2 + num * 2), bytesRead: num + 1 };
      }
      return { decoded: '', bytesRead: num + 1 };
    }

    //number
    if ((byte & PF_TYPE2_MASK) == PF_NUMBER) {
      const size = (byte >> 3) & 0x03;
      const precision = byte & 0x07;
      const dataLength = getPrecisionByteSize(precision);
      if (bytes.length > 2) {
        const data = bytes.substring(2, (dataLength + 1) * 2);
        const mult = parseInt(bytes.substring((dataLength + 1) * 2, (dataLength + 2) * 2), 16);
        return { decoded: fromCompressedNumber(size, data, mult), bytesRead: dataLength + 2 };
      }
      return { decoded: '', bytesRead: dataLength + 2 };
    }

    return { decoded: '', bytesRead: 0 };
  }
}

// Helper functions
function findMatch(bytes: string, list: string[]): { bytes: string; index: number }[] | undefined {
  for (let k = 0; k < list.length; k++) {
    let split = bytes.split(list[k]);
    if (split.length > 1) {
      let parts: { bytes: string; index: number }[] = [];
      for (let j = 0; j < split.length; j++) {
        if (split[j] != '') parts.push({ bytes: split[j], index: -1 });
        if (j + 1 < split.length) parts.push({ bytes: list[k], index: k });
      }
      return parts;
    }
  }
}
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
): { size: number; precision: number; decimal: string; shift: number } | undefined {
  let decimal = ethers.toBigInt('0x' + bytes).toString();
  let shift = 0;
  while (decimal[decimal.length - 1] == '0' && decimal.length > 1) {
    decimal = decimal.substring(0, decimal.length - 1);
    shift++;
  }

  let size = 0;
  if (bytes.length / 2 <= 4) size = 0;
  else if (bytes.length / 2 <= 8) size = 1;
  else if (bytes.length / 2 <= 16) size = 2;
  else if (bytes.length / 2 <= 32) size = 3;

  let precision = 0;
  if (ethers.toBigInt(decimal) < 0xffn) precision = 0;
  else if (ethers.toBigInt(decimal) <= 0xffffn) precision = 1;
  else if (ethers.toBigInt(decimal) <= 0xffffffn) precision = 2;
  else if (ethers.toBigInt(decimal) <= 0xffffffffn) precision = 3;
  else if (ethers.toBigInt(decimal) <= 0xffffffffffffn) precision = 4;
  else if (ethers.toBigInt(decimal) <= 0xffffffffffffffffn) precision = 5;
  else if (ethers.toBigInt(decimal) <= 0xffffffffffffffffffffffffn) precision = 6;
  else if (ethers.toBigInt(decimal) <= 0xffffffffffffffffffffffffffffffffn) precision = 7;

  return { size, precision, decimal, shift };
}
function fromCompressedNumber(size: number, decimal: string, mult: number): string {
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
