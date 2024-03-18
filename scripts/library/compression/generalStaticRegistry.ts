import hre from 'hardhat';
import { Addressable, Signer, ContractFactory, isBytesLike } from 'ethers';
import { promises as fs } from 'fs';
import path from 'path';
import { GeneralStaticRegistry } from '../../../typechain';

const CONTRACT_NAME = 'GeneralStaticRegistry';
const MAX_DICTIONARY_SIZE = 1024;
const MAX_DATA_BYTE_SIZE = 20_000;

const PLACEHOLDER_DATA_INDEX_32 = 'eee0';
const PLACEHOLDER_DATA_INDEX_20 = 'eee1';
const PLACEHOLDER_DATA_INDEX_16 = 'eee2';
const PLACEHOLDER_DATA_INDEX_8 = 'eee3';
const PLACEHOLDER_DATA_INDEX_4 = 'eee4';
const PLACEHOLDER_DATA_OFFSET_32 = 'eee5';
const PLACEHOLDER_DATA_OFFSET_20 = 'eee6';
const PLACEHOLDER_DATA_OFFSET_16 = 'eee7';
const PLACEHOLDER_DATA_OFFSET_8 = 'eee8';
const PLACEHOLDER_DATA_OFFSET_4 = 'eee9';

export async function deployGeneralStaticRegistry(
  dictionary: string[],
  signer?: Signer | undefined,
): Promise<GeneralStaticRegistry> {
  if (signer === undefined) signer = (await hre.ethers.getSigners())[0];
  const factory = await hre.ethers.getContractFactory(CONTRACT_NAME, signer);
  const fullCode = await generateGeneralStaticRegistryDeployCode(dictionary);
  const modifiedFactory = new ContractFactory(factory.interface, fullCode, signer);
  const contract = await modifiedFactory.deploy();

  return await getGeneralStaticRegistryAt(await contract.getAddress(), signer);
}

export async function getGeneralStaticRegistryAt(
  address: string | Addressable,
  signer?: Signer | undefined,
): Promise<GeneralStaticRegistry> {
  return await hre.ethers.getContractAt(CONTRACT_NAME, address, signer);
}

export function splitDictionary(dictionary: string[]): string[][] {
  const dict32: string[] = [];
  const dict20: string[] = [];
  const dict16: string[] = [];
  const dict8: string[] = [];
  const dict4: string[] = [];
  for (let d of dictionary) {
    if (byteLen(d) == 32) dict32.push(d);
    else if (byteLen(d) == 20) dict20.push(d);
    else if (byteLen(d) == 16) dict16.push(d);
    else if (byteLen(d) == 8) dict8.push(d);
    else if (byteLen(d) == 4) dict4.push(d);
    else throw new Error(`Invalid dictionary item length: ${d} (items must be either 32, 20, 16, 8 or 4 bytes long)`);
  }

  const dictionaries: string[][] = [];

  //create an order array of the different items byte sizes
  const range: number[] = [];
  dictionary.sort((a, b) => b.length - a.length);
  for (let d of dictionary) range.push((d.length - 2) / 2);

  //scan through the range with a window of desired item count until one is found under the byte limit
  const byteSize = (from: number, to: number) => {
    let size = 0;
    for (let i = from; i < to; i++) size += range[i];
    return size;
  };
  const grabPage = (): number[] => {
    for (let windowsize = MAX_DICTIONARY_SIZE; windowsize > 0; windowsize--) {
      for (let windowstart = 0; windowstart < range.length - windowsize + 1; windowstart++) {
        if (byteSize(windowstart, windowstart + windowsize) <= MAX_DATA_BYTE_SIZE) {
          return range.splice(windowstart, windowsize);
        }
      }
    }
    return [];
  };

  //fill up a list of sub dictionaries from the window scanning
  while (range.length > 0) {
    const page = grabPage();
    const dict: string[] = [];
    for (let s of page) {
      if (s == 32) dict.push(dict32.pop() || '');
      if (s == 20) dict.push(dict20.pop() || '');
      if (s == 16) dict.push(dict16.pop() || '');
      if (s == 8) dict.push(dict8.pop() || '');
      if (s == 4) dict.push(dict4.pop() || '');
    }
    dictionaries.push(dict);
  }

  return dictionaries;
}

//generate the code for deployment
export async function generateGeneralStaticRegistryDeployCode(dictionary: string[]): Promise<string> {
  if (dictionary.length > MAX_DICTIONARY_SIZE)
    throw new Error(`Dictionary size larger than max: ${MAX_DICTIONARY_SIZE}`);

  //sort the dictionary into different categories
  const dict32: string[] = [];
  const dict20: string[] = [];
  const dict16: string[] = [];
  const dict8: string[] = [];
  const dict4: string[] = [];
  for (let d of dictionary) {
    if (!isBytesLike(d)) throw new Error(`Invalid dictionary item: ${d} (invalid bytes)`);
    if (byteLen(d) == 32) dict32.push(d);
    else if (byteLen(d) == 20) dict20.push(d);
    else if (byteLen(d) == 16) dict16.push(d);
    else if (byteLen(d) == 8) dict8.push(d);
    else if (byteLen(d) == 4) dict4.push(d);
    else throw new Error(`Invalid dictionary item length: ${d} (items must be either 32, 20, 16, 8 or 4 bytes long)`);
  }

  //fetch compiled byte code
  let { initCode, deployedBytecode } = await readArtifact();

  //compile extra contract data
  let extraData = '';
  const dataOffset32 = byteLen(deployedBytecode);
  for (let d of dict32) extraData += d.substring(2);
  const dataIndex32 = dict32.length;
  const dataOffset20 = dataOffset32 + byteLen(extraData) - dataIndex32 * 20;
  for (let d of dict20) extraData += d.substring(2);
  const dataIndex20 = dataIndex32 + dict20.length;
  const dataOffset16 = dataOffset32 + byteLen(extraData) - dataIndex20 * 16;
  for (let d of dict16) extraData += d.substring(2);
  const dataIndex16 = dataIndex20 + dict16.length;
  const dataOffset8 = dataOffset32 + byteLen(extraData) - dataIndex16 * 8;
  for (let d of dict8) extraData += d.substring(2);
  const dataIndex8 = dataIndex16 + dict8.length;
  const dataOffset4 = dataOffset32 + byteLen(extraData) - dataIndex8 * 4;
  for (let d of dict4) extraData += d.substring(2);
  const dataIndex4 = dataIndex8 + dict4.length;

  //fill in placeholders
  if (deployedBytecode.indexOf(PLACEHOLDER_DATA_INDEX_32) <= 0)
    throw new Error(`Failed to find data index 32 placeholder`);
  if (deployedBytecode.indexOf(PLACEHOLDER_DATA_INDEX_20) <= 0)
    throw new Error(`Failed to find data index 20 placeholder`);
  if (deployedBytecode.indexOf(PLACEHOLDER_DATA_INDEX_16) <= 0)
    throw new Error(`Failed to find data index 16 placeholder`);
  if (deployedBytecode.indexOf(PLACEHOLDER_DATA_INDEX_8) <= 0)
    throw new Error(`Failed to find data index 8 placeholder`);
  if (deployedBytecode.indexOf(PLACEHOLDER_DATA_INDEX_4) <= 0)
    throw new Error(`Failed to find data index 4 placeholder`);
  if (deployedBytecode.indexOf(PLACEHOLDER_DATA_OFFSET_32) <= 0)
    throw new Error(`Failed to find data offset 32 placeholder`);
  if (deployedBytecode.indexOf(PLACEHOLDER_DATA_OFFSET_20) <= 0)
    throw new Error(`Failed to find data offset 20 placeholder`);
  if (deployedBytecode.indexOf(PLACEHOLDER_DATA_OFFSET_16) <= 0)
    throw new Error(`Failed to find data offset 16 placeholder`);
  if (deployedBytecode.indexOf(PLACEHOLDER_DATA_OFFSET_8) <= 0)
    throw new Error(`Failed to find data offset 8 placeholder`);
  if (deployedBytecode.indexOf(PLACEHOLDER_DATA_OFFSET_4) <= 0)
    throw new Error(`Failed to find data offset 4 placeholder`);
  deployedBytecode = deployedBytecode.split(PLACEHOLDER_DATA_INDEX_32).join(format2(dataIndex32));
  deployedBytecode = deployedBytecode.split(PLACEHOLDER_DATA_INDEX_20).join(format2(dataIndex20));
  deployedBytecode = deployedBytecode.split(PLACEHOLDER_DATA_INDEX_16).join(format2(dataIndex16));
  deployedBytecode = deployedBytecode.split(PLACEHOLDER_DATA_INDEX_8).join(format2(dataIndex8));
  deployedBytecode = deployedBytecode.split(PLACEHOLDER_DATA_INDEX_4).join(format2(dataIndex4));
  deployedBytecode = deployedBytecode.split(PLACEHOLDER_DATA_OFFSET_32).join(format2(dataOffset32));
  deployedBytecode = deployedBytecode.split(PLACEHOLDER_DATA_OFFSET_20).join(format2(dataOffset20));
  deployedBytecode = deployedBytecode.split(PLACEHOLDER_DATA_OFFSET_16).join(format2(dataOffset16));
  deployedBytecode = deployedBytecode.split(PLACEHOLDER_DATA_OFFSET_8).join(format2(dataOffset8));
  deployedBytecode = deployedBytecode.split(PLACEHOLDER_DATA_OFFSET_4).join(format2(dataOffset4));

  //replace the code length in the init code
  const codeLengthPush = `61${byteLen(deployedBytecode).toString(16).padStart(4, '0')}`;
  const codeLengthPushIndex = initCode.indexOf(codeLengthPush);
  if (codeLengthPushIndex <= 0) throw new Error(`Failed to find code length PUSH2 op`);
  deployedBytecode = deployedBytecode + extraData;
  initCode = initCode.replace(codeLengthPush, `61${byteLen(deployedBytecode).toString(16).padStart(4, '0')}`);

  return initCode + deployedBytecode.substring(2);
}

//formats number
function format2(num: number): string {
  return num.toString(16).padStart(4, '0');
}

//gets the byte length
function byteLen(bytes: string): number {
  if (bytes.substring(0, 2) != '0x') return bytes.length / 2;
  return (bytes.length - 2) / 2;
}

//finds the last compilation artifact
async function readArtifact(): Promise<{ initCode: string; deployedBytecode: string }> {
  const filepath = await scanDirectory(hre.config.paths.artifacts, `${CONTRACT_NAME}.json`);
  if (filepath === null) throw new Error(`Failed to find artifact for ${CONTRACT_NAME}.sol`);

  const artifact = JSON.parse(await fs.readFile(filepath, 'utf8'));
  const bytecodeIndex = artifact.bytecode.indexOf(artifact.deployedBytecode.substring(2));
  if (bytecodeIndex <= 0) {
    throw new Error(
      `Failed to place deployedBytecode in full deploy bytecode (did you add a constructor or immutables to ${CONTRACT_NAME}.sol?)`,
    );
  }

  return { initCode: artifact.bytecode.substring(0, bytecodeIndex), deployedBytecode: artifact.deployedBytecode };
}

//scan for file and return the full file path once found
async function scanDirectory(directory: string, filename: string): Promise<string | null> {
  const files = await fs.readdir(directory);

  const directories: string[] = [];
  for (const file of files) {
    const filePath = path.join(directory, file);
    const stat = await fs.stat(filePath);
    if (stat.isDirectory()) {
      directories.push(filePath);
    } else if (file == filename) {
      return filePath;
    }

    for (const dir of directories) {
      const filePath = await scanDirectory(dir, filename);
      if (filePath !== null) return filePath;
    }
  }
  return null;
}
