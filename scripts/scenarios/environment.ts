import { Provider, Signer } from 'ethers';
import { ethers } from 'hardhat';
import {
  SimpleAccount,
  BLSAccount,
  BLSSignatureAggregator,
  EntryPoint,
  SolverUtils,
  TestERC20,
  TestUniswap,
  TestWrappedNativeToken,
} from '../../typechain';
import { Curve } from '../library/curveCoder';
import { SimpleCallSegment } from '../library/standards/simpleCall';
import { UserOperationSegment } from '../library/standards/userOperation';
import { SequentialNonceSegment } from '../library/standards/sequentialNonce';
import { EthRecordSegment } from '../library/standards/ethRecord';
import { EthReleaseSegment } from '../library/standards/ethRelease';
import { EthRequireSegment } from '../library/standards/ethRequire';
import { Erc20RecordSegment } from '../library/standards/erc20Record';
import { Erc20ReleaseSegment } from '../library/standards/erc20Release';
import { Erc20RequireSegment } from '../library/standards/erc20Require';
import { BlsSigner, BlsSignerFactory, BlsVerifier } from '../library/bls/bls';
import { CalldataCompression } from '../library/compression/calldataCompression';
import { deployGeneralStaticRegistry, splitDictionary } from '../library/compression/generalStaticRegistry';
import { deployGeneralCalldataCompression } from '../library/compression/generalCalldataCompression';

// Environment definition
export type Environment = {
  chainId: bigint;
  provider: Provider;
  deployer: Signer;
  deployerAddress: string;
  entrypoint: EntryPoint;
  entrypointAddress: string;
  blsSignatureAggregator: BLSSignatureAggregator;
  blsSignatureAggregatorAddress: string;
  standards: {
    call: (callData: string) => SimpleCallSegment;
    userOp: (callData: string, gasLimit: number) => UserOperationSegment;
    sequentialNonce: (nonce: number) => SequentialNonceSegment;
    ethRecord: (proxy: boolean) => EthRecordSegment;
    ethRelease: (curve: Curve) => EthReleaseSegment;
    ethRequire: (curve: Curve) => EthRequireSegment;
    erc20Record: (contract: string, proxy: boolean) => Erc20RecordSegment;
    erc20Release: (contract: string, curve: Curve) => Erc20ReleaseSegment;
    erc20Require: (contract: string, curve: Curve) => Erc20RequireSegment;
  };
  registeredStandards: {
    call: (callData: string) => SimpleCallSegment;
    userOp: (callData: string, gasLimit: number) => UserOperationSegment;
    sequentialNonce: (nonce: number) => SequentialNonceSegment;
    ethRecord: (proxy: boolean) => EthRecordSegment;
    ethRelease: (curve: Curve) => EthReleaseSegment;
    ethRequire: (curve: Curve) => EthRequireSegment;
    erc20Record: (contract: string, proxy: boolean) => Erc20RecordSegment;
    erc20Release: (contract: string, curve: Curve) => Erc20ReleaseSegment;
    erc20Require: (contract: string, curve: Curve) => Erc20RequireSegment;
  };
  test: {
    erc20: TestERC20;
    erc20Address: string;
    wrappedNativeToken: TestWrappedNativeToken;
    wrappedNativeTokenAddress: string;
    uniswap: TestUniswap;
    uniswapAddress: string;
    solverUtils: SolverUtils;
    solverUtilsAddress: string;
  };
  compression: {
    compressedEntryPoint: CalldataCompression;
    registerAddresses: (addresses: string[]) => Promise<void>;
  };
  simpleAccounts: SmartContractAccount[];
  eoaProxyAccounts: SmartContractAccount[];
  blsAccounts: BLSSmartContractAccount[];
  blsVerifier: BlsVerifier;
  gasUsed: {
    entrypoint: bigint;
    blsSignatureAggregator: bigint;
    registerStandard: bigint;
    simpleAccountFactory: bigint;
    simpleAccount: bigint;
  };
  utils: {
    getNonce: (account: string) => Promise<number>;
    randomAddresses: (num: number) => string[];
  };
  solverUtils: SolverUtils;
};
export type SmartContractAccount = {
  contract: SimpleAccount;
  contractAddress: string;
  signer: Signer;
  signerAddress: string;
};
export type BLSSmartContractAccount = {
  contract: BLSAccount;
  contractAddress: string;
  signer: BlsSigner;
  owner: Signer;
  ownerAddress: string;
};

// Deploy configuration options
export type DeployConfiguration = {
  numAccounts: number;
};

// Deploy the testing environment
export async function deployTestEnvironment(config: DeployConfiguration = { numAccounts: 4 }): Promise<Environment> {
  const provider = ethers.provider;
  const network = await provider.getNetwork();
  const signers = await ethers.getSigners();
  const deployer = signers[0];

  //deploy the entrypoint contract and register intent standards
  const entrypoint = await ethers.deployContract('EntryPoint', [], deployer);
  const entrypointAddress = await entrypoint.getAddress();
  const callStdId = '0x0000000000000000000000000000000000000000000000000000000000000000';
  const erc20RecordStdId = '0x0000000000000000000000000000000000000000000000000000000000000001';
  const erc20ReleaseStdId = '0x0000000000000000000000000000000000000000000000000000000000000002';
  const erc20RequireStdId = '0x0000000000000000000000000000000000000000000000000000000000000003';
  const ethRecordStdId = '0x0000000000000000000000000000000000000000000000000000000000000004';
  const ethReleaseStdId = '0x0000000000000000000000000000000000000000000000000000000000000005';
  const ethRequireStdId = '0x0000000000000000000000000000000000000000000000000000000000000006';
  const sequentialNonceStdId = '0x0000000000000000000000000000000000000000000000000000000000000007';
  const userOperationStdId = '0x0000000000000000000000000000000000000000000000000000000000000008';
  const entrypointGasUsed = (await entrypoint.deploymentTransaction()?.wait())?.gasUsed || 0n;

  //deploy the entrypoint contract and register intent standards
  const erc20Record = await registerIntentStandard('Erc20Record', entrypoint, deployer);
  const erc20Release = await registerIntentStandard('Erc20Release', entrypoint, deployer);
  const erc20Require = await registerIntentStandard('Erc20Require', entrypoint, deployer);
  const ethRecord = await registerIntentStandard('EthRecord', entrypoint, deployer);
  const ethRelease = await registerIntentStandard('EthRelease', entrypoint, deployer);
  const ethRequire = await registerIntentStandard('EthRequire', entrypoint, deployer);
  const sequentialNonce = await registerIntentStandard('SequentialNonce', entrypoint, deployer);
  const simpleCall = await registerIntentStandard('SimpleCall', entrypoint, deployer);
  const userOperation = await registerIntentStandard('UserOperation', entrypoint, deployer);
  const registerStandardGasUsed =
    (erc20Record.gasUsed +
      erc20Release.gasUsed +
      erc20Require.gasUsed +
      ethRecord.gasUsed +
      ethRelease.gasUsed +
      ethRequire.gasUsed +
      sequentialNonce.gasUsed +
      simpleCall.gasUsed +
      userOperation.gasUsed) /
    9n;

  //deploy misc test contracts
  const testERC20 = await ethers.deployContract('TestERC20', [], deployer);
  const testERC20Address = await testERC20.getAddress();
  const testWrappedNativeToken = await ethers.deployContract('TestWrappedNativeToken', [], deployer);
  const testWrappedNativeTokenAddress = await testWrappedNativeToken.getAddress();
  const testUniswap = await ethers.deployContract('TestUniswap', [testWrappedNativeTokenAddress], deployer);
  const testUniswapAddress = await testUniswap.getAddress();
  const solverUtils = await ethers.deployContract(
    'SolverUtils',
    [testUniswapAddress, testERC20Address, testWrappedNativeTokenAddress],
    deployer,
  );
  const solverUtilsAddress = await solverUtils.getAddress();

  //deploy signature aggregation contracts
  const blsSignatureAggregator = await ethers.deployContract('BLSSignatureAggregator', [entrypointAddress], deployer);
  const blsSignatureAggregatorAddress = await blsSignatureAggregator.getAddress();
  const blsSignatureAggregatorGasUsed = (await blsSignatureAggregator.deploymentTransaction()?.wait())?.gasUsed || 0n;

  //deploy smart contract wallet factories
  const simpleAccountFactory = await ethers.deployContract('SimpleAccountFactory', [entrypointAddress], deployer);
  const simpleAccountFactoryGasUsed = (await simpleAccountFactory.deploymentTransaction()?.wait())?.gasUsed || 0n;
  const blsAccountFactory = await ethers.deployContract(
    'BLSAccountFactory',
    [entrypointAddress, blsSignatureAggregatorAddress],
    deployer,
  );

  //deploy smart contract wallets
  const fundAmount = ethers.parseEther('1');
  let simpleAccountGasUsed = 0n;
  const simpleAccounts: SmartContractAccount[] = [];
  for (let i = 0; i < config.numAccounts; i++) {
    const signer = new ethers.Wallet(ethers.hexlify(ethers.randomBytes(32)));
    const signerAddress = await signer.getAddress();

    const createAccountReceipt = await (await simpleAccountFactory.createAccount(signerAddress, i)).wait();
    const contractAddress = await simpleAccountFactory.getFunction('getAddress(address,uint256)')(signerAddress, i);
    const contract = await ethers.getContractAt('SimpleAccount', contractAddress, deployer);

    await deployer.sendTransaction({ to: contractAddress, value: fundAmount });

    simpleAccounts.push({ contract, contractAddress, signer, signerAddress });
    simpleAccountGasUsed += createAccountReceipt?.gasUsed || 0n;
  }
  simpleAccountGasUsed /= BigInt(config.numAccounts);

  //deploy smart contract wallets intended to serve as proxies for an EOA
  const eoaProxyAccounts: SmartContractAccount[] = [];
  for (let i = 0; i < config.numAccounts; i++) {
    const signer = new ethers.Wallet(ethers.hexlify(ethers.randomBytes(32))).connect(provider);
    const signerAddress = await signer.getAddress();

    await simpleAccountFactory.createAccount(signerAddress, i);
    const contractAddress = await simpleAccountFactory.getFunction('getAddress(address,uint256)')(signerAddress, i);
    const contract = await ethers.getContractAt('SimpleAccount', contractAddress, deployer);

    await deployer.sendTransaction({ to: signerAddress, value: fundAmount });
    await testERC20.connect(signer).approve(contractAddress, ethers.MaxUint256);
    await testWrappedNativeToken.connect(signer).approve(contractAddress, ethers.MaxUint256);

    eoaProxyAccounts.push({ contract, contractAddress, signer, signerAddress });
  }

  //deploy smart contract wallets intended to serve as proxies for an EOA
  const BLS_DOMAIN = ethers.toBeArray(ethers.keccak256(Buffer.from('erc7521.bls.domain')));
  const blsSignerFactory = await BlsSignerFactory.new(BLS_DOMAIN);
  const blsVerifier = new BlsVerifier(BLS_DOMAIN);
  const blsAccounts: BLSSmartContractAccount[] = [];
  for (let i = 0; i < config.numAccounts; i++) {
    const owner = new ethers.Wallet(ethers.hexlify(ethers.randomBytes(32))).connect(provider);
    const ownerAddress = await owner.getAddress();

    const signer = blsSignerFactory.createSigner(`0x${(i + 10).toString(16).padStart(64, '0')}`);
    await blsAccountFactory.createAccount(signer.pubkey, ownerAddress, i);
    const contractAddress = await blsAccountFactory.getFunction('getAddress(uint256[4],address,uint256)')(
      signer.pubkey,
      ownerAddress,
      i,
    );
    const contract = await ethers.getContractAt('BLSAccount', contractAddress, deployer);

    await deployer.sendTransaction({ to: contractAddress, value: fundAmount });

    blsAccounts.push({ contract, contractAddress, signer, owner, ownerAddress });
  }

  //fund exchange
  const funder = signers[signers.length - 1];
  await testERC20.mint(testUniswapAddress, ethers.parseEther('1000'));
  await testWrappedNativeToken.connect(funder).deposit({ value: ethers.parseEther('1000') });
  await testWrappedNativeToken.connect(funder).transfer(testUniswapAddress, ethers.parseEther('1000'));

  //set dictionaries for compression
  const l1Dictionary: string[] = [];
  l1Dictionary.push('0x0000000000000000000000000000000000000000000000000000000000000001');
  l1Dictionary.push('0x0000000000000000000000000000000000000000000000000000000000000002');
  l1Dictionary.push('0x0000000000000000000000000000000000000000000000000000000000000003');
  l1Dictionary.push('0x0000000000000000000000000000000000000000000000000000000000000004');
  l1Dictionary.push('0x0000000000000000000000000000000000000000000000000000000000000005');
  l1Dictionary.push('0x0000000000000000000000000000000000000000000000000000000000000006');
  l1Dictionary.push('0x0000000000000000000000000000000000000000000000000000000000000007');
  l1Dictionary.push('0x0000000000000000000000000000000000000000000000000000000000000008');
  l1Dictionary.push('0x0000000000000000000000000000000000000000000000000000000000000009');
  l1Dictionary.push('0x000000000000000000000000000000000000000000000000000000000000000a');
  l1Dictionary.push('0x000000000000000000000000000000000000000000000000000000000000000b');
  l1Dictionary.push('0x000000000000000000000000000000000000000000000000000000000000000c');
  l1Dictionary.push('0x000000000000000000000000000000000000000000000000000000000000000d');
  l1Dictionary.push('0x000000000000000000000000000000000000000000000000000000000000000e');
  l1Dictionary.push('0x000000000000000000000000000000000000000000000000000000000000000f');
  l1Dictionary.push('0x0000000000000000000000000000000000000000000000000000000000000041');
  l1Dictionary.push('0x1b00000000000000000000000000000000000000000000000000000000000000');
  l1Dictionary.push('0x1c00000000000000000000000000000000000000000000000000000000000000');
  l1Dictionary.push('0x0000000000000000000000000000000000000000000000000000000000000020');
  l1Dictionary.push('0x0000000000000000000000000000000000000000000000000000000000000040');
  l1Dictionary.push(entrypointAddress);
  l1Dictionary.push(testERC20Address);
  l1Dictionary.push(testWrappedNativeTokenAddress);
  l1Dictionary.push(solverUtilsAddress);
  l1Dictionary.push(testERC20.interface.getFunction('approve').selector);
  l1Dictionary.push(testERC20.interface.getFunction('transfer').selector);
  l1Dictionary.push(testERC20.interface.getFunction('transferFrom').selector);
  l1Dictionary.push(entrypoint.interface.getFunction('handleIntents').selector);
  l1Dictionary.push(entrypoint.interface.getFunction('handleIntentsMulti').selector);
  l1Dictionary.push(entrypoint.interface.getFunction('handleIntentsAggregated').selector);

  const l2Dictionary: string[] = [];
  l2Dictionary.push(ethers.hexlify(ethers.randomBytes(32)));
  l2Dictionary.push(simpleAccounts[0].contract.interface.getFunction('execute').selector);
  l2Dictionary.push(simpleAccounts[0].contract.interface.getFunction('executeBatch').selector);
  l2Dictionary.push(simpleAccounts[0].contract.interface.getFunction('generalizedIntentDelegateCall').selector);
  l2Dictionary.push(solverUtils.interface.getFunction('swapERC20ForETHAndForward').selector);
  l2Dictionary.push(solverUtils.interface.getFunction('swapERC20ForETHAndForwardMulti').selector);
  l2Dictionary.push(solverUtils.interface.getFunction('swapETHForERC20AndForward').selector);
  l2Dictionary.push(solverUtils.interface.getFunction('transferAllETH').selector);
  l2Dictionary.push(solverUtils.interface.getFunction('transferERC20').selector);
  l2Dictionary.push(solverUtils.interface.getFunction('transferETH').selector);
  l2Dictionary.push(testUniswapAddress);
  l2Dictionary.push(blsSignatureAggregatorAddress);
  l2Dictionary.push(erc20Record.standardId);
  l2Dictionary.push(erc20Release.standardId);
  l2Dictionary.push(erc20Require.standardId);
  l2Dictionary.push(ethRecord.standardId);
  l2Dictionary.push(ethRelease.standardId);
  l2Dictionary.push(ethRequire.standardId);
  l2Dictionary.push(sequentialNonce.standardId);
  l2Dictionary.push(simpleCall.standardId);
  l2Dictionary.push(userOperation.standardId);

  const l3Dictionary: string[] = [];
  l3Dictionary.push(ethers.hexlify(ethers.randomBytes(20)));
  for (const acct of simpleAccounts) {
    l3Dictionary.push(acct.contractAddress);
  }
  for (const acct of blsAccounts) {
    l3Dictionary.push(acct.contractAddress);
  }
  for (const acct of eoaProxyAccounts) {
    l3Dictionary.push(acct.contractAddress);
    l3Dictionary.push(acct.signerAddress);
  }

  //deploy data registries
  const multiplesRegistry = await ethers.deployContract('MultiplesStaticRegistry', deployer);
  const multiplesRegistryAddress = await multiplesRegistry.getAddress();

  const staticRegistryAddresses: string[] = [];
  const l2Dictionaries = splitDictionary(l2Dictionary);
  for (const dict of l2Dictionaries) {
    const staticRegistry = await deployGeneralStaticRegistry(dict, deployer);
    staticRegistryAddresses.push(await staticRegistry.getAddress());
  }

  const publicRegistry = await ethers.deployContract('PublicStorageRegistry', deployer);
  const publicRegistryAddress = await publicRegistry.getAddress();
  for (let i = 0; i < l3Dictionary.length; i++) {
    await publicRegistry.register(l3Dictionary[i]);
  }

  //deploy calldata compression contract
  const calldataCompression = await deployGeneralCalldataCompression(
    entrypointAddress,
    l1Dictionary,
    [multiplesRegistryAddress, ...staticRegistryAddresses],
    publicRegistryAddress,
    deployer,
  );
  const calldataCompressionAddress = await calldataCompression.getAddress();

  const compressedEntryPoint = new CalldataCompression(entrypoint, calldataCompressionAddress, provider);
  await compressedEntryPoint.sync();

  return {
    chainId: network.chainId,
    provider,
    deployer,
    deployerAddress: await deployer.getAddress(),
    entrypoint,
    entrypointAddress,
    blsSignatureAggregator,
    blsSignatureAggregatorAddress,
    standards: {
      call: (callData: string) => new SimpleCallSegment(callStdId, callData),
      userOp: (callData: string, gasLimit: number) => new UserOperationSegment(userOperationStdId, callData, gasLimit),
      sequentialNonce: (nonce: number) => new SequentialNonceSegment(sequentialNonceStdId, nonce),
      ethRecord: (proxy: boolean) => new EthRecordSegment(ethRecordStdId, proxy),
      ethRelease: (curve: Curve) => new EthReleaseSegment(ethReleaseStdId, curve),
      ethRequire: (curve: Curve) => new EthRequireSegment(ethRequireStdId, curve),
      erc20Record: (contract: string, proxy: boolean) => new Erc20RecordSegment(erc20RecordStdId, contract, proxy),
      erc20Release: (contract: string, curve: Curve) => new Erc20ReleaseSegment(erc20ReleaseStdId, contract, curve),
      erc20Require: (contract: string, curve: Curve) => new Erc20RequireSegment(erc20RequireStdId, contract, curve),
    },
    registeredStandards: {
      call: (callData: string) => new SimpleCallSegment(simpleCall.standardId, callData),
      userOp: (callData: string, gasLimit: number) =>
        new UserOperationSegment(userOperation.standardId, callData, gasLimit),
      sequentialNonce: (nonce: number) => new SequentialNonceSegment(sequentialNonce.standardId, nonce),
      ethRecord: (proxy: boolean) => new EthRecordSegment(ethRecord.standardId, proxy),
      ethRelease: (curve: Curve) => new EthReleaseSegment(ethRelease.standardId, curve),
      ethRequire: (curve: Curve) => new EthRequireSegment(ethRequire.standardId, curve),
      erc20Record: (contract: string, proxy: boolean) =>
        new Erc20RecordSegment(erc20Record.standardId, contract, proxy),
      erc20Release: (contract: string, curve: Curve) =>
        new Erc20ReleaseSegment(erc20Release.standardId, contract, curve),
      erc20Require: (contract: string, curve: Curve) =>
        new Erc20RequireSegment(erc20Require.standardId, contract, curve),
    },
    test: {
      erc20: testERC20,
      erc20Address: testERC20Address,
      wrappedNativeToken: testWrappedNativeToken,
      wrappedNativeTokenAddress: testWrappedNativeTokenAddress,
      uniswap: testUniswap,
      uniswapAddress: testUniswapAddress,
      solverUtils,
      solverUtilsAddress,
    },
    compression: {
      compressedEntryPoint,
      registerAddresses: async (addresses: string[]) => {
        for (const addr of addresses) {
          (await publicRegistry.register(addr)).wait();
        }
      },
    },
    simpleAccounts: simpleAccounts,
    eoaProxyAccounts: eoaProxyAccounts,
    blsAccounts: blsAccounts,
    blsVerifier: blsVerifier,
    gasUsed: {
      entrypoint: entrypointGasUsed,
      blsSignatureAggregator: blsSignatureAggregatorGasUsed,
      registerStandard: registerStandardGasUsed,
      simpleAccountFactory: simpleAccountFactoryGasUsed,
      simpleAccount: simpleAccountGasUsed,
    },
    utils: {
      getNonce: async (account: string) => {
        return Number((await entrypoint.getNonce(account, '0x000000000000000000000000000000000000000000000000')) + 1n);
      },
      randomAddresses: (num: number) => {
        const addresses: string[] = [];
        for (let i = 0; i < num; i++) addresses.push(ethers.hexlify(ethers.randomBytes(20)));
        return addresses;
      },
    },
    solverUtils,
  };
}

async function registerIntentStandard(
  contractName: string,
  entrypoint: EntryPoint,
  deployer: Signer,
): Promise<{ standardId: string; gasUsed: bigint }> {
  const contract = await ethers.deployContract(contractName, [], deployer);
  const address = await contract.getAddress();
  const registerReceipt = await (await entrypoint.registerIntentStandard(address)).wait();
  const gasUsed = registerReceipt?.gasUsed || 0n;
  const standardId = await entrypoint.getIntentStandardId(address);

  return { standardId, gasUsed };
}
