import { StatefulEncoding } from './statefulEncoding';
import { IntentSolutionStruct, UserIntentStruct } from '../../typechain/src/core/EntryPoint';
import { ethers } from 'ethers';

// Solution template encoding
// xxxxxx (timestamp) xx (num intents) [
//     xx-xxxxxxxx (encoded sender)
//     xx (num segments) [
//         xx (standard) xx (data length) xxxx...xxxx (data)
//     ] ( segments)
//     xx (signature length) xxxx...xxxx (signature)
// ] (intents)
// xx... (execution order [each step is 5bits skipping the last bit if sequence goes beyond 256bits])

// Common pieces for encoding
const HANDLE_INTENTS_FN_SEL = '4bf114ff';
const START_DATA_OFFSET = '0000000000000000000000000000000000000000000000000000000000000020';
const INTENTS_OFFSET = '0000000000000000000000000000000000000000000000000000000000000060';
const INTENT_DATA_OFFSET = '0000000000000000000000000000000000000000000000000000000000000060';

// Perform intent compression via templating
export class IntentCompression {
  private statefulEncoding: StatefulEncoding;

  constructor(statefulEncoding: StatefulEncoding) {
    this.statefulEncoding = statefulEncoding;
  }

  // Compress the given raw handle intents data
  public compressHandleIntentsRaw(bytes: string): string {
    let hexPrefix = false;
    bytes = (' ' + bytes).slice(1);
    if (bytes.indexOf('0x') == 0) {
      hexPrefix = true;
      bytes = bytes.substring(2);
    }

    let solutionBytes = '';
    try {
      //function selector
      if (safeSubstring(bytes, 0, HANDLE_INTENTS_FN_SEL.length) != HANDLE_INTENTS_FN_SEL) {
        throw new Error('Incorrect handleIntents() function selector');
      }

      //starting data offset
      const solutionStartOffset = HANDLE_INTENTS_FN_SEL.length + START_DATA_OFFSET.length;
      if (safeSubstring(bytes, HANDLE_INTENTS_FN_SEL.length, solutionStartOffset) != START_DATA_OFFSET) {
        throw new Error('Incorrect data offset');
      }

      solutionBytes = safeSubstring(bytes, solutionStartOffset, bytes.length);
    } catch (e) {
      if (e instanceof Error) throw new Error('Failed to parse raw handleIntents(): ' + e.message);
      else throw new Error('Failed to parse raw handleIntents()');
    }

    const solution = parseRawSolution(solutionBytes);
    const compressed = this.compressHandleIntents(solution);
    return hexPrefix ? compressed : compressed.substring(2);
  }

  // Convert the given solution into compressed data for calling handle intents
  public compressHandleIntents(solution: IntentSolutionStruct): string {
    let encoded = '0x';

    //timestamp
    encoded += toHex(solution.timestamp, 4);

    //num intents
    encoded += toHex(solution.intents.length, 1);

    //intents
    for (let i = 0; i < solution.intents.length; i++) {
      //sender
      const sender = toHex(solution.intents[i].sender.toString().substring(2), 32);
      encoded += this.statefulEncoding.singleEncode(sender, true);

      //num segments
      encoded += toHex(solution.intents[i].intentData.length, 1);

      //segments
      for (let j = 0; j < solution.intents[i].intentData.length; j++) {
        //standard
        const standard = solution.intents[i].intentData[j].toString().substring(2, 66);
        encoded += this.statefulEncoding.singleEncode(standard, true);

        //data length
        const data = solution.intents[i].intentData[j].toString().substring(66);
        const dataEncoded = this.statefulEncoding.encode(data);
        encoded += toHex(dataEncoded.length / 2, 1);

        //data
        encoded += dataEncoded;
      }

      //signature length
      const signature = solution.intents[i].signature.toString().substring(2);
      encoded += toHex(signature.length / 2, 1);

      //signature
      encoded += signature;
    }

    //execution steps
    for (let i = solution.order.length - 1; i >= 0; ) {
      let steps = 0n;
      let j = 0;
      for (; j < 51 && i >= 0; j++) {
        steps = (steps << 5n) + BigInt(solution.order[i]);
        i--;
      }
      encoded += toHex(steps, Math.ceil((j * 5) / 8));
    }

    return encoded;
  }

  // Decompress the given data to the raw handle intents data
  public decompressHandleIntentsRaw(bytes: string): string {
    let hexPrefix = false;
    bytes = (' ' + bytes).slice(1);
    if (bytes.indexOf('0x') == 0) {
      hexPrefix = true;
      bytes = bytes.substring(2);
    }
    let i = 0;

    try {
      //timestamp
      const timestamp = parseInt(safeSubstring(bytes, i, i + 8), 16);
      i += 8;

      //num intents
      const numIntents = parseInt(safeSubstring(bytes, i, i + 2), 16);
      i += 2;

      //intents
      const intentDatas: string[] = [];
      for (let j = 0; j < numIntents; j++) {
        //sender
        const senderEncodedLength = this.statefulEncoding.singleDecodeLength(safeSubstring(bytes, i, i + 2));
        const sender = this.statefulEncoding.singleDecode(safeSubstring(bytes, i, i + senderEncodedLength * 2), true);
        i += senderEncodedLength * 2;

        //num segments
        const numSegments = parseInt(safeSubstring(bytes, i, i + 2), 16);
        i += 2;

        //segments
        const segmentDatas: string[] = [];
        for (let k = 0; k < numSegments; k++) {
          //standard
          const standardEncodedLength = this.statefulEncoding.singleDecodeLength(safeSubstring(bytes, i, i + 2));
          const standard = this.statefulEncoding.singleDecode(
            safeSubstring(bytes, i, i + standardEncodedLength * 2),
            true,
          );
          i += standardEncodedLength * 2;

          //data length
          const compressedDataLength = parseInt(safeSubstring(bytes, i, i + 2), 16);
          i += 2;

          //data
          let data = this.statefulEncoding.decode(safeSubstring(bytes, i, i + 2 * compressedDataLength));
          const dataLength = data.length / 2 + 32;
          data = data.padEnd(Math.ceil(data.length / 64) * 64, '0');
          i += 2 * compressedDataLength;

          //put data together
          segmentDatas.push(toHex(dataLength, 32) + standard + data);
        }

        //signature length
        const signatureLength = parseInt(safeSubstring(bytes, i, i + 2), 16);
        i += 2;

        //signature
        const signature = safeSubstring(bytes, i, i + 2 * signatureLength);
        i += 2 * signatureLength;

        //signature offset
        let segmentsLengthTotal = 0;
        for (let k = 0; k < numSegments; k++) segmentsLengthTotal += segmentDatas[k].length / 2;
        const signatureOffsetHex = parseInt(INTENT_DATA_OFFSET, 16) + 32 * (1 + numSegments) + segmentsLengthTotal;

        //put data together
        let collectedData = toHex(sender, 32);
        collectedData += INTENT_DATA_OFFSET;
        collectedData += toHex(signatureOffsetHex, 32);
        collectedData += toHex(numSegments, 32);
        if (numSegments > 0) {
          let offset = 32 * numSegments;
          for (let k = 0; k < numSegments; k++) {
            collectedData += toHex(offset, 32);
            offset += segmentDatas[k].length / 2;
          }
          for (let k = 0; k < numSegments; k++) {
            collectedData += segmentDatas[k];
          }
        }
        collectedData += toHex(signatureLength, 32);
        collectedData += signature.padEnd(Math.ceil(signatureLength / 32) * 64, '0');

        intentDatas.push(collectedData);
      }

      //calculate order offset
      let intentsLengthTotal = 0;
      for (let k = 0; k < numIntents; k++) intentsLengthTotal += intentDatas[k].length / 2;
      const orderOffsetHex = parseInt(INTENTS_OFFSET, 16) + 32 * (1 + numIntents) + intentsLengthTotal;

      //num execution steps
      const bytesLeft = (bytes.length - i) / 2;
      const numExecutionSteps = Math.floor((bytesLeft * 8) / 5) - Math.floor(bytesLeft / 160);

      //execution steps
      let executionSteps = toHex(numExecutionSteps, 32);
      for (let k = 0; k < numExecutionSteps; ) {
        let data = ethers.toBigInt('0x' + bytes.substring(i, i + 64));
        for (let l = 0; l < 51 && k < numExecutionSteps; l++) {
          executionSteps += toHex(data & 0x1fn, 32);
          data = data >> 5n;
          k++;
        }
        i += 64;
      }

      //put data together
      let decompressed = hexPrefix ? '0x' : '';
      decompressed += HANDLE_INTENTS_FN_SEL;
      decompressed += START_DATA_OFFSET;
      decompressed += toHex(timestamp, 32);
      decompressed += INTENTS_OFFSET;
      decompressed += toHex(orderOffsetHex, 32);
      decompressed += toHex(numIntents, 32);
      if (numIntents > 0) {
        let offset = 32 * numIntents;
        for (let k = 0; k < numIntents; k++) {
          decompressed += toHex(offset.toString(16), 32);
          offset += intentDatas[k].length / 2;
        }
        for (let k = 0; k < numIntents; k++) {
          decompressed += intentDatas[k];
        }
      }
      decompressed += executionSteps;

      return decompressed;
    } catch (e) {
      if (e instanceof Error) throw new Error('Failed to decompress handleIntents(): ' + e.message);
      else throw new Error('Failed to decompress handleIntents()');
    }
  }

  // Convert the handle intents compressed data into the corresponding solution
  public decompressHandleIntents(bytes: string): IntentSolutionStruct {
    bytes = (' ' + bytes).slice(1);
    if (bytes.indexOf('0x') == 0) {
      bytes = bytes.substring(2);
    }
    const decompressed = this.decompressHandleIntentsRaw(bytes);

    const solutionStartOffset = HANDLE_INTENTS_FN_SEL.length + START_DATA_OFFSET.length;
    let solutionBytes = safeSubstring(decompressed, solutionStartOffset, decompressed.length);

    return parseRawSolution(solutionBytes);
  }
}

// Helper functions
function safeSubstring(str: string, from: number, to: number): string {
  if (from >= str.length || to > str.length) throw new Error('String accessed out of bounds');
  if (from < 0 || to < 0) throw new Error('String accessed out of bounds');
  return str.substring(from, to);
}
function parseRawSolution(bytes: string): IntentSolutionStruct {
  let i = 0;
  try {
    //timestamp
    const timestamp = parseInt(safeSubstring(bytes, i, i + 64), 16);
    i += 64;

    //intents offset
    if (safeSubstring(bytes, i, i + INTENTS_OFFSET.length) != INTENTS_OFFSET) {
      throw new Error('Incorrect intents offset');
    }
    i += INTENTS_OFFSET.length;

    //order offset
    const orderOffset = parseInt(safeSubstring(bytes, i, i + 64), 16);
    i += 64;

    //num intents
    const numIntents = parseInt(safeSubstring(bytes, i, i + 64), 16);
    i += 64;

    //intent offsets
    const intentOffsets: number[] = [];
    for (let j = 0; j < numIntents; j++) {
      intentOffsets.push(parseInt(safeSubstring(bytes, i, i + 64), 16));
      i += 64;
    }

    //intents
    const intents: UserIntentStruct[] = [];
    for (let j = 0; j < numIntents; j++) {
      const totalOffset = parseInt(INTENTS_OFFSET, 16) + 32 + intentOffsets[j];
      intents.push(parseRawIntent(safeSubstring(bytes, totalOffset * 2, bytes.length)));
    }
    i = orderOffset * 2;

    //execution steps
    const numExecutionSteps = parseInt(bytes.substring(i, i + 64), 16);
    i += 64;

    //execution steps
    const executionSteps: number[] = [];
    for (let j = 0; j < numExecutionSteps; j++) {
      executionSteps.push(parseInt(bytes.substring(i, i + 64), 16));
      i += 64;
    }

    return { timestamp, intents, order: executionSteps };
  } catch (e) {
    if (e instanceof Error) throw new Error('Failed to parse raw solution: ' + e.message);
    else throw new Error('Failed to parse raw solution');
  }
}
function parseRawIntent(bytes: string): UserIntentStruct {
  let i = 0;
  try {
    //intent sender
    const sender = '0x' + safeSubstring(bytes, i + 24, i + 64);
    i += 64;

    //skip starting data offset
    if (safeSubstring(bytes, i, i + INTENT_DATA_OFFSET.length) != INTENT_DATA_OFFSET) {
      throw new Error('Incorrect intent data offset');
    }
    i += INTENT_DATA_OFFSET.length;

    //skip signature offset
    i += 64;

    //num segments
    const numSegments = parseInt(safeSubstring(bytes, i, i + 64), 16);
    i += 64;

    //skip segment offsets
    i += 64 * numSegments;

    //segments
    const intentData: string[] = [];
    for (let k = 0; k < numSegments; k++) {
      const dataLength = parseInt(safeSubstring(bytes, i, i + 64), 16);
      i += 64;

      const data = '0x' + safeSubstring(bytes, i, i + dataLength * 2);
      i += Math.ceil(dataLength / 32) * 64;

      intentData.push(data);
    }

    //signature
    const signatureLength = parseInt(safeSubstring(bytes, i, i + 64), 16);
    i += 64;
    const signature = '0x' + safeSubstring(bytes, i, i + signatureLength * 2);

    return { sender, intentData, signature };
  } catch (e) {
    if (e instanceof Error) throw new Error('Failed to parse raw intent: ' + e.message);
    else throw new Error('Failed to parse raw intent');
  }
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
