import { isAddress } from 'ethers';
import { Contract, Provider, Signer, BaseContract, ContractTransactionResponse } from 'ethers';
import { CompressionCore } from './compressionCore';

// Perform stateful encoding
export class CalldataCompression extends CompressionCore {
  private initialized = false;
  private targetContract: BaseContract;
  private compressionContractAddress: string;
  private provider: Provider;
  private l3RegistryAddress: string = '0x0000000000000000000000000000000000000000';
  private l3DictionaryLength: number = 0;

  // Constructor
  constructor(targetContract: BaseContract, compressionContractAddress: string, provider: Provider) {
    super();
    if (!isAddress(compressionContractAddress)) {
      throw new Error(`Invalid address: ${compressionContractAddress}`);
    }
    this.targetContract = targetContract;
    this.compressionContractAddress = compressionContractAddress;
    this.provider = provider;
  }

  // Syncs the dictionaries for compression
  public async sync() {
    if (!this.initialized) {
      this.initialized = true;

      //parse the bytecode for additional values
      const compressionContract = new Contract(this.compressionContractAddress, compressionABI, this.provider);
      const version = (await compressionContract.version_0511d9()).toString();
      const bytecode = await this.provider.getCode(await compressionContract.getAddress());
      const { target, l1Dictionary, l2Registries, l3Registry } = parseBytecode(version, bytecode);

      //verify the target contract is correct
      const targetContract = await this.targetContract.getAddress();
      if (target.toLowerCase() != targetContract.toLowerCase()) {
        throw new Error(`Compression contracts target does not match what was given`);
      }

      //parse the static one byte dictionary
      let l1DictionaryIndex = 0;
      for (let item of l1Dictionary) {
        this.oneByteDictionary.set(item.substring(2), l1DictionaryIndex++);
      }

      //parse the static two byte dictionary
      let l2DictionaryIndex = 0;
      for (let i = 0; i < 8; i++) {
        if (l2Registries[i] != '0x0000000000000000000000000000000000000000') {
          const registryContract = new Contract(l2Registries[i], registryABI, this.provider);
          const l2DictionaryPage = await registryContract.retrieveBatch(0, 1024);
          for (let item of l2DictionaryPage) {
            this.twoByteDictionary.set(item.substring(2), l2DictionaryIndex++);
          }
        }
      }

      //remember the four byte dictionary source
      this.l3RegistryAddress = l3Registry;
    }

    //sync the static four byte dictionary
    if (this.l3RegistryAddress != '0x0000000000000000000000000000000000000000') {
      const registryContract = new Contract(this.l3RegistryAddress, registryABI, this.provider);
      const l3DictionaryLength = Number(await registryContract.length());
      if (this.l3DictionaryLength != l3DictionaryLength) {
        let l3DictionaryIndex = this.l3DictionaryLength;
        for (let i = l3DictionaryIndex; i < l3DictionaryLength; i += 1024) {
          const items = await registryContract.retrieveBatch(i, Math.min(i + 1024, l3DictionaryLength));
          for (let item of items) {
            this.fourByteDictionary.set(item.substring(2), l3DictionaryIndex++);
          }
        }
        this.l3DictionaryLength = l3DictionaryLength;
      }
    }
  }

  //make a call to the target contract using compressed calldata
  public async compressedCall(
    fragment: string,
    values: any[],
    signer?: Signer,
    fastEncryption: boolean = true,
    l3DictionaryEnabled: boolean = true,
  ): Promise<ContractTransactionResponse> {
    await this.sync();
    const calldata = this.targetContract.interface.encodeFunctionData(fragment, values);
    const compressed = fastEncryption
      ? this.encodeFast(calldata, l3DictionaryEnabled)
      : this.encode(calldata, l3DictionaryEnabled);

    //compress and call
    const compressionContract = new Contract(this.compressionContractAddress, compressionABI, signer);
    if (compressionContract.fallback) {
      return compressionContract.fallback({ data: compressed, gasLimit: 10_000_000 });
    }

    //fail if no fallback
    return new Promise<ContractTransactionResponse>((resolve, reject) => {
      reject();
    });
  }
}

function parseBytecode(
  version: string,
  bytecode: string,
): {
  target: string;
  l1Dictionary: string[];
  l2Registries: string[];
  l3Registry: string;
} {
  if (version == '0') {
    const dataSize = 1256;
    const targetOffset = 0;
    const l1DictionaryOffset = 20;
    const l1DictLengthsOffset = 1044;
    const l2RegistriesOffset = 1076;
    const l3RegistryOffset = 1236;

    const data = bytecode.substring(bytecode.length - dataSize * 2);
    const target = '0x' + data.substring(targetOffset * 2, (targetOffset + 20) * 2);
    const l1Dictionary: string[] = [];
    for (let i = 0; i < 32; i++) {
      const length = parseInt(data.substring((l1DictLengthsOffset + i) * 2, (l1DictLengthsOffset + i + 1) * 2), 16);
      l1Dictionary.push(
        '0x' + data.substring((l1DictionaryOffset + i * 32) * 2, (l1DictionaryOffset + i * 32 + length) * 2),
      );
    }
    const l2Registries: string[] = [];
    for (let i = 0; i < 8; i++) {
      l2Registries.push(
        '0x' + data.substring((l2RegistriesOffset + i * 20) * 2, (l2RegistriesOffset + (i + 1) * 20) * 2),
      );
    }
    const l3Registry = '0x' + data.substring(l3RegistryOffset * 2, (l3RegistryOffset + 20) * 2);
    return { target, l1Dictionary, l2Registries, l3Registry };
  }

  throw new Error(`Unknown contract version (version ${version})`);
}

const compressionABI = [
  {
    'stateMutability': 'nonpayable',
    'type': 'fallback',
  },
  {
    'inputs': [
      {
        'internalType': 'bytes',
        'name': 'data',
        'type': 'bytes',
      },
    ],
    'name': 'decompress_0076ce',
    'outputs': [
      {
        'internalType': 'bytes',
        'name': '',
        'type': 'bytes',
      },
    ],
    'stateMutability': 'view',
    'type': 'function',
  },
  {
    'inputs': [],
    'name': 'version_0511d9',
    'outputs': [
      {
        'internalType': 'uint8',
        'name': '',
        'type': 'uint8',
      },
    ],
    'stateMutability': 'pure',
    'type': 'function',
  },
];

const registryABI = [
  {
    'anonymous': false,
    'inputs': [
      {
        'indexed': true,
        'internalType': 'uint256',
        'name': 'index',
        'type': 'uint256',
      },
      {
        'indexed': false,
        'internalType': 'bytes',
        'name': 'data',
        'type': 'bytes',
      },
    ],
    'name': 'DataRegistered',
    'type': 'event',
  },
  {
    'inputs': [],
    'name': 'length',
    'outputs': [
      {
        'internalType': 'uint256',
        'name': '',
        'type': 'uint256',
      },
    ],
    'stateMutability': 'pure',
    'type': 'function',
  },
  {
    'inputs': [
      {
        'internalType': 'uint256',
        'name': 'index',
        'type': 'uint256',
      },
    ],
    'name': 'retrieve',
    'outputs': [
      {
        'internalType': 'bytes',
        'name': '',
        'type': 'bytes',
      },
    ],
    'stateMutability': 'pure',
    'type': 'function',
  },
  {
    'inputs': [
      {
        'internalType': 'uint256',
        'name': 'from',
        'type': 'uint256',
      },
      {
        'internalType': 'uint256',
        'name': 'to',
        'type': 'uint256',
      },
    ],
    'name': 'retrieveBatch',
    'outputs': [
      {
        'internalType': 'bytes[]',
        'name': '',
        'type': 'bytes[]',
      },
    ],
    'stateMutability': 'pure',
    'type': 'function',
  },
];
