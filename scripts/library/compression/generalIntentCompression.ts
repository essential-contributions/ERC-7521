import { StatefulAbiEncoding } from './statefulAbiEncoding';
import { IntentSolutionStruct, UserIntentStruct } from '../../../typechain/src/core/EntryPoint';
import {
  DataRegistry,
  EntryPoint__factory,
  GeneralIntentCompression as GeneralIntentCompressionContract,
} from '../../../typechain';
import { Result, Signer, ContractTransactionResponse } from 'ethers';

// Handle intents encoding
// xx (num solutions) [
//     xx..xx (encoded solution)
// ] (solutions)
//   --if first bit in "num solutions" is 1--
// xx..xx (encoded aggregator)
// xx..xx (intents to aggregate)
// xx (signature length) xx..xx (signature)

// Solution template encoding
// xxxxxxxx (timestamp) xx (num intents) [
//     xx..xx (encoded sender)
//     xx (num segments) [
//         xx..xx (encoded standard) xx-xxxx (data length) xx..xx (data)
//     ] ( segments)
//     xx (signature length) xx..xx (signature)
// ] (intents)
// xx (execution order length) xx.. (order [each step is 5bits skipping the last bit if sequence goes beyond 256bits])

// Common pieces for encoding
const HANDLE_AGGREGATED_FLAG = 0x80;

// Perform intent compression via templating
export class GeneralIntentCompression {
  private generalIntentCompressionContract: GeneralIntentCompressionContract;
  private statefulEncoding: StatefulAbiEncoding;

  // Constructor
  constructor(generalIntentCompressionContract: GeneralIntentCompressionContract, dataRegistry: DataRegistry) {
    this.generalIntentCompressionContract = generalIntentCompressionContract;
    this.statefulEncoding = new StatefulAbiEncoding(dataRegistry);
  }

  // Uses compressed data to call handleIntents on the entrypoint contract
  public async handleIntents(
    solution: IntentSolutionStruct,
    stateful: boolean = true,
    signer?: Signer,
  ): Promise<ContractTransactionResponse> {
    return await this.execute(this.compressHandleIntents(solution), stateful, signer);
  }

  // Uses compressed data to call handleIntentsMulti on the entrypoint contract
  public async handleIntentsMulti(
    solutions: IntentSolutionStruct[],
    stateful: boolean = true,
    signer?: Signer,
  ): Promise<ContractTransactionResponse> {
    return await this.execute(this.compressHandleIntentsMulti(solutions), stateful, signer);
  }

  // Uses compressed data to call handleIntentsAggregated on the entrypoint contract
  public async handleIntentsAggregated(
    solutions: IntentSolutionStruct[],
    aggregator: string,
    intentsToAggregate: string,
    signature: string,
    stateful: boolean = true,
    signer?: Signer,
  ): Promise<ContractTransactionResponse> {
    return await this.execute(
      this.compressHandleIntentsAggregated(solutions, aggregator, intentsToAggregate, signature),
      stateful,
      signer,
    );
  }

  // Manually sync up with the on-chain data registry
  public async sync() {
    await this.statefulEncoding.sync();
  }

  // Sets if encoding should utilize the stateful registry
  public setStateful(stateful: boolean) {
    this.statefulEncoding.setStateful(stateful);
  }

  /////////////////
  // Compression //
  /////////////////

  // Convert the given solution into compressed data for calling handleIntents
  public compressHandleIntents(solution: IntentSolutionStruct): string {
    let compressed = '0x00';
    return compressed + this.compressSolution(solution);
  }

  // Convert the given solution into compressed data for calling handleIntentsMulti
  public compressHandleIntentsMulti(solutions: IntentSolutionStruct[]): string {
    if (solutions.length == 0) throw new Error('No solutions');
    if (solutions.length >= 32) throw new Error('Too many solutions');
    let compressed = '0x' + toHex(solutions.length, 1);
    for (let i = 0; i < solutions.length; i++) {
      compressed += this.compressSolution(solutions[i]);
    }
    return compressed;
  }

  // Convert the given solution into compressed data for calling handleIntentsAggregated
  public compressHandleIntentsAggregated(
    solutions: IntentSolutionStruct[],
    aggregator: string,
    intentsToAggregate: string,
    signature: string,
  ): string {
    if (solutions.length == 0) throw new Error('No solutions');
    if (solutions.length >= 32) throw new Error('Too many solutions');
    let compressed = '0x' + toHex(solutions.length + HANDLE_AGGREGATED_FLAG, 1);

    //solutions
    let numIntents = 0;
    for (let i = 0; i < solutions.length; i++) {
      compressed += this.compressSolution(solutions[i]);
      numIntents += solutions[i].intents.length;
    }

    //aggregator address
    const aggregatorAddress = toHex(aggregator.substring(2), 32);
    compressed += this.statefulEncoding.singleEncode(aggregatorAddress, true);

    //intents to aggregate bit field
    const intentsToAggregateBytes = Math.ceil(numIntents / 8);
    compressed += toHex(BigInt(intentsToAggregate), intentsToAggregateBytes);

    //signature
    const signatureLength = (signature.length - 2) / 2;
    if (signatureLength >= 256) throw new Error('Signature too long');
    compressed += toHex(signatureLength, 1) + signature.substring(2);

    return compressed;
  }

  ///////////////////
  // Decompression //
  ///////////////////

  // Convert the handleIntents compressed data into the corresponding params
  public decompressHandleIntents(bytes: string): IntentSolutionStruct {
    const numSolutions = parseInt(bytes.substring(0, 4), 16);
    bytes = bytes.substring(4);
    if (isNaN(numSolutions) || numSolutions > 0) throw new Error('Incorrect handleIntents() prefix');
    return this.decompressSolution(bytes).decompressed;
  }

  // Convert the handleIntentsMulti compressed data into the corresponding params
  public decompressHandleIntentsMulti(bytes: string): IntentSolutionStruct[] {
    const numSolutions = parseInt(bytes.substring(0, 4), 16);
    bytes = bytes.substring(4);
    if (isNaN(numSolutions) || numSolutions == 0 || numSolutions >= HANDLE_AGGREGATED_FLAG) {
      throw new Error('Incorrect handleIntentsMulti() prefix');
    }
    const solutions: IntentSolutionStruct[] = [];
    for (let i = 0; i < numSolutions; i++) {
      const res = this.decompressSolution(bytes);
      bytes = bytes.substring(res.bytesRead * 2);
      solutions.push(res.decompressed);
    }
    return solutions;
  }

  // Convert the handleIntentsAggregated compressed data into the corresponding params
  public decompressHandleIntentsAggregated(bytes: string): {
    solutions: IntentSolutionStruct[];
    aggregator: string;
    intentsToAggregate: string;
    signature: string;
  } {
    const numSolutions = parseInt(bytes.substring(0, 4), 16);
    bytes = bytes.substring(4);
    if (isNaN(numSolutions) || numSolutions <= HANDLE_AGGREGATED_FLAG) {
      throw new Error('Incorrect handleIntentsAggregated() prefix');
    }
    let numIntents = 0;
    const solutions: IntentSolutionStruct[] = [];
    for (let i = 0; i < numSolutions - HANDLE_AGGREGATED_FLAG; i++) {
      const res = this.decompressSolution(bytes);
      bytes = bytes.substring(res.bytesRead * 2);
      solutions.push(res.decompressed);
      numIntents += res.decompressed.intents.length;
    }
    try {
      const aggregatorLength = this.statefulEncoding.singleDecodeLength(safeSubstring(bytes, 0, 2)) * 2;
      const aggregator =
        '0x' + this.statefulEncoding.singleDecode(safeSubstring(bytes, 0, aggregatorLength), true).substring(24);
      bytes = bytes.substring(aggregatorLength);

      const intentsToAggregateLength = Math.ceil(numIntents / 8) * 2;
      const intentsToAggregate = '0x' + toHex(BigInt('0x' + safeSubstring(bytes, 0, intentsToAggregateLength)), 32);
      bytes = bytes.substring(intentsToAggregateLength);

      const signatureLength = parseInt('0x' + safeSubstring(bytes, 0, 2), 16) * 2;
      const signature = '0x' + safeSubstring(bytes, 2, signatureLength + 2);
      bytes = bytes.substring(signatureLength + 2);

      return {
        solutions,
        aggregator,
        intentsToAggregate,
        signature,
      };
    } catch (e) {
      if (e instanceof Error) throw new Error('Failed to decompress handleIntentsAggregated(): ' + e.message);
      else throw new Error('Failed to decompress handleIntentsAggregated()');
    }
  }

  //////////////////////////////////////////
  // Parsing functions useful for testing //
  //////////////////////////////////////////

  // Parses raw transaction data into handleIntents params
  public parseHandleIntents(data: string): IntentSolutionStruct {
    const entryPointInterface = EntryPoint__factory.createInterface();
    const parsed = entryPointInterface.parseTransaction({ data });
    if (parsed === null) throw new Error('Failed to parse handleIntents()');
    if (parsed.name != 'handleIntents') throw new Error('Tx data is not a handleIntents() call');

    return parseSolution(parsed.args[0]);
  }

  // Parses raw transaction data into handleIntentsMulti params
  public parseHandleIntentsMulti(data: string): IntentSolutionStruct[] {
    const entryPointInterface = EntryPoint__factory.createInterface();
    const parsed = entryPointInterface.parseTransaction({ data });
    if (parsed === null) throw new Error('Failed to parse handleIntentsAggregated()');
    if (parsed.name != 'handleIntentsAggregated') throw new Error('Tx data is not a handleIntentsAggregated() call');

    const solutions: IntentSolutionStruct[] = [];
    for (let i = 0; i < parsed.args.length; i++) {
      solutions.push(parseSolution(parsed.args[i]));
    }

    return solutions;
  }

  // Parses raw transaction data into handleIntentsAggregated params
  public parseHandleIntentsAggregated(data: string): {
    solutions: IntentSolutionStruct[];
    aggregator: string;
    intentsToAggregate: string;
    signature: string;
  } {
    const entryPointInterface = EntryPoint__factory.createInterface();
    const parsed = entryPointInterface.parseTransaction({ data });
    if (parsed === null) throw new Error('Failed to parse handleIntentsAggregated()');
    if (parsed.name != 'handleIntentsAggregated') throw new Error('Tx data is not a handleIntentsAggregated() call');

    const solutions: IntentSolutionStruct[] = [];
    for (let i = 0; i < parsed.args[0].length; i++) {
      solutions.push(parseSolution(parsed.args[0][i]));
    }

    return {
      solutions,
      aggregator: parsed.args[1].toString(),
      intentsToAggregate: parsed.args[2].toString(),
      signature: parsed.args[3].toString(),
    };
  }

  // gets the data for a handleIntents transaction
  public getHandleIntentsTxData(solution: IntentSolutionStruct): string {
    const entryPointInterface = EntryPoint__factory.createInterface();
    return entryPointInterface.encodeFunctionData('handleIntents', [solution]);
  }

  // gets the data for a handleIntentsMulti transaction
  public getHandleIntentsMultiTxData(solutions: IntentSolutionStruct[]): string {
    const entryPointInterface = EntryPoint__factory.createInterface();
    return entryPointInterface.encodeFunctionData('handleIntentsMulti', [solutions]);
  }

  // gets the data for a handleIntents transaction
  public getHandleIntentsAggregatedTxData(
    solutions: IntentSolutionStruct[],
    aggregator: string,
    intentsToAggregate: string,
    signature: string,
  ): string {
    const entryPointInterface = EntryPoint__factory.createInterface();
    return entryPointInterface.encodeFunctionData('handleIntentsAggregated', [
      solutions,
      aggregator,
      intentsToAggregate,
      signature,
    ]);
  }

  //////////////////////////////
  // Private Helper Functions //
  //////////////////////////////

  //Compress the given solution struct
  private compressSolution(solution: IntentSolutionStruct): string {
    let encoded = '';

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
        const dataLength = dataEncoded.length / 2;
        if (dataLength >= 32768) throw new Error('Segment data too large');
        else if (dataLength >= 128) encoded += toHex(32768 + dataLength, 2);
        else encoded += toHex(dataLength, 1);

        //data
        encoded += dataEncoded;
      }

      //signature length
      const signature = solution.intents[i].signature.toString().substring(2);
      if (signature.length / 2 >= 256) throw new Error('Signature too long');
      encoded += toHex(signature.length / 2, 1);

      //signature
      encoded += signature;
    }

    //execution steps
    if (solution.order.length > 256) throw new Error('Execution order too large');
    encoded += toHex(solution.order.length, 1);
    for (let i = 0; i < solution.order.length; ) {
      let steps = 0n;
      for (let j = 0; j < 51; j++) {
        steps = steps << 5n;
        if (i < solution.order.length) {
          steps += BigInt(solution.order[i]);
          i++;
        }
      }
      steps = steps << 1n;
      let byteLen = Math.ceil((i * 5) / 8);
      steps = steps >> ((32n - BigInt(byteLen)) * 8n);

      encoded += toHex(steps, byteLen);
    }

    return encoded;
  }

  // Decompress the given data to a full solution struct
  private decompressSolution(bytes: string): { decompressed: IntentSolutionStruct; bytesRead: number } {
    try {
      let i = 0;

      //timestamp
      const timestamp = parseInt(safeSubstring(bytes, i, i + 8), 16);
      i += 8;

      //num intents
      const numIntents = parseInt(safeSubstring(bytes, i, i + 2), 16);
      i += 2;

      //intents
      const intents: UserIntentStruct[] = [];
      for (let j = 0; j < numIntents; j++) {
        //sender
        const senderEncodedLength = this.statefulEncoding.singleDecodeLength(safeSubstring(bytes, i, i + 2));
        const sender = this.statefulEncoding.singleDecode(safeSubstring(bytes, i, i + senderEncodedLength * 2), true);
        i += senderEncodedLength * 2;

        //num segments
        const numSegments = parseInt(safeSubstring(bytes, i, i + 2), 16);
        i += 2;

        //segments
        const segments: string[] = [];
        for (let k = 0; k < numSegments; k++) {
          //standard
          const standardEncodedLength = this.statefulEncoding.singleDecodeLength(safeSubstring(bytes, i, i + 2));
          const standard = this.statefulEncoding.singleDecode(
            safeSubstring(bytes, i, i + standardEncodedLength * 2),
            true,
          );
          i += standardEncodedLength * 2;

          //data length
          let compressedDataLength = parseInt(safeSubstring(bytes, i, i + 2), 16);
          if (compressedDataLength >= 128) {
            compressedDataLength = parseInt(safeSubstring(bytes, i, i + 4), 16) - 32768;
            i += 2;
          }
          i += 2;

          //data
          let data = this.statefulEncoding.decode(safeSubstring(bytes, i, i + 2 * compressedDataLength));
          i += 2 * compressedDataLength;

          //put data together
          segments.push('0x' + standard + data);
        }

        //signature length
        const signatureLength = parseInt(safeSubstring(bytes, i, i + 2), 16);
        i += 2;

        //signature
        const signature = safeSubstring(bytes, i, i + 2 * signatureLength);
        i += 2 * signatureLength;

        intents.push({
          sender: '0x' + sender.substring(24),
          intentData: segments,
          signature: '0x' + signature,
        });
      }

      //num execution steps
      const numExecutionSteps = parseInt(safeSubstring(bytes, i, i + 2), 16);
      const numExecutionStepsBytes = Math.floor((numExecutionSteps * 5 + Math.floor(numExecutionSteps / 51) + 7) / 8);
      i += 2;

      //execution steps
      let index = i;
      const order: number[] = [];
      for (let k = 0; k < numExecutionSteps; ) {
        let data = BigInt('0x' + bytes.substring(index, index + 64).padEnd(64, '0'));
        for (let l = 0; l < 51 && k < numExecutionSteps; l++) {
          order.push(Number(data >> 251n));
          data = (data << 5n) % 2n ** 256n;
          k++;
        }
        index += 64;
      }
      i += numExecutionStepsBytes * 2;

      const solution: IntentSolutionStruct = {
        timestamp,
        intents,
        order,
      };
      return { decompressed: solution, bytesRead: i / 2 };
    } catch (e) {
      if (e instanceof Error) throw new Error('Failed to decompress solution: ' + e.message);
      else throw new Error('Failed to decompress solution');
    }
  }

  // Execute on the GeneralIntentCompression contract
  private async execute(data: string, stateful: boolean, signer?: Signer): Promise<ContractTransactionResponse> {
    await this.sync();
    this.statefulEncoding.setStateful(stateful);

    //compress and call
    const contract = signer
      ? this.generalIntentCompressionContract.connect(signer)
      : this.generalIntentCompressionContract;
    if (contract.fallback) {
      return contract.fallback({ data });
    }

    //fail if no fallback
    return new Promise<ContractTransactionResponse>((resolve, reject) => {
      reject();
    });
  }
}

///////////////////////////
// Pure Helper functions //
///////////////////////////
function safeSubstring(str: string, from: number, to?: number): string {
  if (to === undefined) to = str.length;
  if (from >= str.length || to > str.length) throw new Error('String accessed out of bounds');
  if (from < 0 || to < 0) throw new Error('String accessed out of bounds');
  return str.substring(from, to);
}
function parseSolution(arg: Result): IntentSolutionStruct {
  const intents: UserIntentStruct[] = [];
  for (let i = 0; i < arg[1].length; i++) {
    const segments: string[] = [];
    for (let j = 0; j < arg[1][i][1].length; j++) {
      segments.push(arg[1][i][1][j].toString());
    }
    intents.push({
      sender: arg[1][i][0].toString(),
      intentData: segments,
      signature: arg[1][i][2].toString(),
    });
  }
  const order: number[] = [];
  for (let i = 0; i < arg[2].length; i++) {
    order.push(Number(arg[2][i]));
  }

  return {
    timestamp: Number(arg[0]),
    intents,
    order,
  };
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
