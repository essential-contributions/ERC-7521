import { Provider, Signer } from 'ethers';
import { ethers } from 'hardhat';
import {
  SimpleAccountFactory,
  SimpleAccount,
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
import { GeneralIntentCompression } from '../library/compression/generalIntentCompression';

// Environment definition
export type Environment = {
  chainId: bigint;
  provider: Provider;
  deployer: Signer;
  deployerAddress: string;
  entrypoint: EntryPoint;
  entrypointAddress: string;
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
    general: GeneralIntentCompression;
    registerAddresses: (addresses: string[]) => Promise<void>;
  };
  simpleAccounts: SmartContractAccount[];
  eoaProxyAccounts: SmartContractAccount[];
  gasUsed: {
    entrypoint: bigint;
    registerStandard: bigint;
    simpleAccountFactory: bigint;
    simpleAccount: bigint;
    generalCompression: bigint;
  };
  utils: {
    getNonce: (account: string) => Promise<number>;
    randomAddresses: (num: number) => string[];
  };
  solverUtils: SolverUtils;
  simpleAccountFactory: SimpleAccountFactory;
};
export type SmartContractAccount = {
  contract: SimpleAccount;
  contractAddress: string;
  signer: Signer;
  signerAddress: string;
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

  //deploy smart contract wallet factories
  const simpleAccountFactory = await ethers.deployContract('SimpleAccountFactory', [entrypointAddress], deployer);
  const simpleAccountFactoryGasUsed = (await simpleAccountFactory.deploymentTransaction()?.wait())?.gasUsed || 0n;

  //deploy smart contract wallets
  let simpleAccountGasUsed = 0n;
  const simpleAccounts: SmartContractAccount[] = [];
  for (let i = 0; i < config.numAccounts; i++) {
    const signer = new ethers.Wallet(ethers.hexlify(ethers.randomBytes(32)));
    const signerAddress = await signer.getAddress();

    const createAccountReceipt = await (await simpleAccountFactory.createAccount(signerAddress, i)).wait();
    const contractAddress = await simpleAccountFactory.getFunction('getAddress(address,uint256)')(signerAddress, i);
    const contract = await ethers.getContractAt('SimpleAccount', contractAddress, deployer);

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

    const fundAmount = ethers.parseEther('1');
    await deployer.sendTransaction({ to: signerAddress, value: fundAmount });
    await testERC20.connect(signer).approve(contractAddress, ethers.MaxUint256);
    await testWrappedNativeToken.connect(signer).approve(contractAddress, ethers.MaxUint256);

    eoaProxyAccounts.push({ contract, contractAddress, signer, signerAddress });
  }

  //fund exchange
  const funder = signers[signers.length - 1];
  await testERC20.mint(testUniswapAddress, ethers.parseEther('1000'));
  await testWrappedNativeToken.connect(funder).deposit({ value: ethers.parseEther('1000') });
  await testWrappedNativeToken.connect(funder).transfer(testUniswapAddress, ethers.parseEther('1000'));

  //deploy stateful encoding and intent compression helpers
  const dataRegistry = await ethers.deployContract('DataRegistry', [], deployer);
  const dataRegistryAddress = await dataRegistry.getAddress();
  const generalCompression = await ethers.deployContract(
    'GeneralIntentCompression',
    [entrypointAddress, dataRegistryAddress],
    deployer,
  );
  const generalCompressionGasUsed = (await generalCompression.deploymentTransaction()?.wait())?.gasUsed || 0n;
  const generalIntentCompression = new GeneralIntentCompression(generalCompression, dataRegistry);

  //fill the data registry with high frequency items
  (await dataRegistry.addOneByteItem(ethers.hexlify(ethers.randomBytes(32)))).wait();
  (await dataRegistry.addOneByteItem('0x' + testERC20Address.substring(2).padStart(64, '0'))).wait();
  (await dataRegistry.addOneByteItem('0x' + testWrappedNativeTokenAddress.substring(2).padStart(64, '0'))).wait();
  (await dataRegistry.addOneByteItem(callStdId)).wait();
  (await dataRegistry.addOneByteItem(erc20RecordStdId)).wait();
  (await dataRegistry.addOneByteItem(erc20ReleaseStdId)).wait();
  (await dataRegistry.addOneByteItem(erc20RequireStdId)).wait();
  (await dataRegistry.addOneByteItem(ethRecordStdId)).wait();
  (await dataRegistry.addOneByteItem(ethReleaseStdId)).wait();
  (await dataRegistry.addOneByteItem(ethRequireStdId)).wait();
  (await dataRegistry.addOneByteItem(sequentialNonceStdId)).wait();
  (await dataRegistry.addOneByteItem(userOperationStdId)).wait();
  (await dataRegistry.addOneByteItem(simpleCall.standardId)).wait();
  (await dataRegistry.addOneByteItem(userOperation.standardId)).wait();
  (await dataRegistry.addOneByteItem(sequentialNonce.standardId)).wait();
  (await dataRegistry.addOneByteItem(ethRecord.standardId)).wait();
  (await dataRegistry.addOneByteItem(ethRelease.standardId)).wait();
  (await dataRegistry.addOneByteItem(ethRequire.standardId)).wait();
  (await dataRegistry.addOneByteItem(erc20Record.standardId)).wait();
  (await dataRegistry.addOneByteItem(erc20Release.standardId)).wait();
  (await dataRegistry.addOneByteItem(erc20Require.standardId)).wait();

  //fill the data registry with medium frequency items
  (await dataRegistry.addTwoByteItem(ethers.hexlify(ethers.randomBytes(32)))).wait();
  (await dataRegistry.addTwoByteItem('0x' + testUniswapAddress.substring(2).padStart(64, '0'))).wait();
  (await dataRegistry.addTwoByteItem('0x' + solverUtilsAddress.substring(2).padStart(64, '0'))).wait();
  (await dataRegistry.addFunctionSelector('0xb61d27f6')).wait();
  (await dataRegistry.addFunctionSelector('0xa9059cbb')).wait();
  (await dataRegistry.addFunctionSelector('0x18c6051a')).wait();

  //fill the data registry with low frequency items
  (await dataRegistry.addFourByteItem(ethers.hexlify(ethers.randomBytes(32)))).wait();
  for (const acct of simpleAccounts) {
    (await dataRegistry.addFourByteItem('0x' + acct.contractAddress.substring(2).padStart(64, '0'))).wait();
  }

  //sync registry
  await generalIntentCompression.sync();

  return {
    chainId: network.chainId,
    provider,
    deployer,
    deployerAddress: await deployer.getAddress(),
    entrypoint,
    entrypointAddress,
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
      general: generalIntentCompression,
      registerAddresses: async (addresses: string[]) => {
        for (const addr of addresses) {
          (await dataRegistry.addFourByteItem('0x' + addr.substring(2).padStart(64, '0'))).wait();
        }
      },
    },
    simpleAccounts: simpleAccounts,
    eoaProxyAccounts: eoaProxyAccounts,
    gasUsed: {
      entrypoint: entrypointGasUsed,
      registerStandard: registerStandardGasUsed,
      simpleAccountFactory: simpleAccountFactoryGasUsed,
      simpleAccount: simpleAccountGasUsed,
      generalCompression: generalCompressionGasUsed,
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
    simpleAccountFactory,
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
