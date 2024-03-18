import hre from 'hardhat';
import { Addressable, Signer, ContractFactory, isAddress, isBytesLike } from 'ethers';
import { promises as fs } from 'fs';
import path from 'path';
import { GeneralCalldataCompression } from '../../../typechain';

const CONTRACT_NAME = 'GeneralCalldataCompression';
const MAX_DICTIONARY_SIZE = 32;

const PLACEHOLDER_TARGET_OFFSET = 'eee0';
const PLACEHOLDER_L1_DICTIONARY_OFFSET = 'eee1';
const PLACEHOLDER_L1_DICT_LENGTHS_OFFSET = 'eee2';
const PLACEHOLDER_L2_REGISTRIES_OFFSET = 'eee3';
const PLACEHOLDER_L3_REGISTRY_OFFSET = 'eee4';

export async function deployGeneralCalldataCompression(
  target: string,
  l1Dictionary: string[],
  l2Registries: string[],
  l3Registry: string,
  signer?: Signer,
): Promise<GeneralCalldataCompression> {
  if (signer === undefined) signer = (await hre.ethers.getSigners())[0];
  const factory = await hre.ethers.getContractFactory(CONTRACT_NAME, signer);
  const fullCode = await generateGeneralCalldataCompressionDeployCode(target, l1Dictionary, l2Registries, l3Registry);
  const modifiedFactory = new ContractFactory(factory.interface, fullCode, signer);
  const contract = await modifiedFactory.deploy();

  return await getGeneralCalldataCompressionAt(await contract.getAddress(), signer);
}

export async function getGeneralCalldataCompressionAt(
  address: string | Addressable,
  signer?: Signer | undefined,
): Promise<GeneralCalldataCompression> {
  return await hre.ethers.getContractAt(CONTRACT_NAME, address, signer);
}

//generate the code for deployment
export async function generateGeneralCalldataCompressionDeployCode(
  target: string,
  l1Dictionary: string[],
  l2Registries: string[],
  l3Registry: string,
): Promise<string> {
  if (l1Dictionary.length > MAX_DICTIONARY_SIZE)
    throw new Error(`Dictionary size large than max: ${MAX_DICTIONARY_SIZE}`);

  //ensure appropriate target provided
  if (!target || !isAddress(target)) throw new Error(`Invalid target: ${target}`);

  //ensure appropriate dictionary item sizes
  for (let d of l1Dictionary) {
    if (!isBytesLike(d)) throw new Error(`Invalid L1 dictionary item: ${d} (invalid bytes)`);
    if (byteLen(d) > 32) throw new Error(`Invalid L1 dictionary item length: ${d} (items must be 32 bytes or less)`);
  }

  //ensure appropriate L2 registry addreses
  if (l2Registries.length > 8) throw new Error(`Number of L2 registries cannot exceed 8`);
  for (let a = 0; a < l2Registries.length; a++) {
    if (l2Registries[a] && !(l2Registries[a] == '0x' || isAddress(l2Registries[a]))) {
      throw new Error(`Invalid L2 registries: ${l2Registries[a]}`);
    }
  }

  //ensure appropriate l3Registry is provided
  if (l3Registry && !(l3Registry == '0x' || isAddress(l3Registry))) {
    throw new Error(`Invalid L3 registry: ${l3Registry}`);
  }

  //fetch compiled byte code
  let { initCode, deployedBytecode } = await readArtifact();

  //compile dictionary lengths
  let l1DictLengths = '';
  for (let d of l1Dictionary) {
    l1DictLengths += byteLen(d).toString(16).padStart(2, '0');
  }

  //compile extra contract data
  const targetOffset = byteLen(deployedBytecode);
  let extraData = target.substring(2);
  const l1DictionaryOffset = targetOffset + byteLen(extraData);
  for (let d = 0; d < 32; d++) {
    if (d < l1Dictionary.length && l1Dictionary[d]) extraData += l1Dictionary[d].substring(2).padEnd(64, '0');
    else extraData += ''.padEnd(64, '0');
  }
  const l1DictLengthsOffset = targetOffset + byteLen(extraData);
  extraData += l1DictLengths.padEnd(64, '0');
  const l2RegistriesOffset = targetOffset + byteLen(extraData);
  for (let r = 0; r < 8; r++) {
    if (r < l2Registries.length && l2Registries[r]) extraData += l2Registries[r].substring(2).padStart(40, '0');
    else extraData += ''.padEnd(40, '0');
  }
  const l3RegistryOffset = targetOffset + byteLen(extraData);
  if (l3Registry) extraData += l3Registry.substring(2).padEnd(40, '0');
  else extraData += ''.padEnd(40, '0');

  //fill in placeholders
  if (deployedBytecode.indexOf(PLACEHOLDER_TARGET_OFFSET) <= 0)
    throw new Error(`Failed to find target offset placeholder`);
  if (deployedBytecode.indexOf(PLACEHOLDER_L1_DICTIONARY_OFFSET) <= 0)
    throw new Error(`Failed to find L1 dictionary offset placeholder`);
  if (deployedBytecode.indexOf(PLACEHOLDER_L1_DICT_LENGTHS_OFFSET) <= 0)
    throw new Error(`Failed to find L1 dictionary lengths placeholder`);
  if (deployedBytecode.indexOf(PLACEHOLDER_L2_REGISTRIES_OFFSET) <= 0)
    throw new Error(`Failed to find L2 registries offset placeholder`);
  if (deployedBytecode.indexOf(PLACEHOLDER_L3_REGISTRY_OFFSET) <= 0)
    throw new Error(`Failed to find L4 registry offset placeholder`);
  deployedBytecode = deployedBytecode.split(PLACEHOLDER_TARGET_OFFSET).join(format2(targetOffset));
  deployedBytecode = deployedBytecode.split(PLACEHOLDER_L1_DICTIONARY_OFFSET).join(format2(l1DictionaryOffset));
  deployedBytecode = deployedBytecode.split(PLACEHOLDER_L1_DICT_LENGTHS_OFFSET).join(format2(l1DictLengthsOffset));
  deployedBytecode = deployedBytecode.split(PLACEHOLDER_L2_REGISTRIES_OFFSET).join(format2(l2RegistriesOffset));
  deployedBytecode = deployedBytecode.split(PLACEHOLDER_L3_REGISTRY_OFFSET).join(format2(l3RegistryOffset));

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
