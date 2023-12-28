import { Provider, Signer } from 'ethers';
import { ethers } from 'hardhat';
import {
  AbstractAccount,
  DataRegistry,
  EntryPoint,
  SolverUtils,
  TestERC20,
  TestUniswap,
  TestWrappedNativeToken,
} from '../../typechain';
import { Curve, LinearCurve } from '../library/curveCoder';
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
    ethRecord: () => EthRecordSegment;
    ethRelease: (curve: Curve) => EthReleaseSegment;
    ethRequire: (curve: Curve) => EthRequireSegment;
    erc20Record: (contract: string) => Erc20RecordSegment;
    erc20Release: (contract: string, curve: Curve) => Erc20ReleaseSegment;
    erc20Require: (contract: string, curve: Curve) => Erc20RequireSegment;
  };
  registeredStandards: {
    call: (callData: string) => SimpleCallSegment;
    userOp: (callData: string, gasLimit: number) => UserOperationSegment;
    sequentialNonce: (nonce: number) => SequentialNonceSegment;
    ethRecord: () => EthRecordSegment;
    ethRelease: (curve: Curve) => EthReleaseSegment;
    ethRequire: (curve: Curve) => EthRequireSegment;
    erc20Record: (contract: string) => Erc20RecordSegment;
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
    dataRegistry: DataRegistry;
    generalIntent: GeneralIntentCompression;
  };
  solverUtils: SolverUtils;
  abstractAccounts: SmartContractAccount[];
  gasUsed: {
    entrypoint: bigint;
    registerStandard: bigint;
    abstractAccount: bigint;
    generalCompression: bigint;
  };
  utils: {
    getNonce: (account: string) => Promise<number>;
    roundForEncoding: (amount: bigint) => bigint;
    randomAddresses: (num: number) => string[];
    registerAddresses: (addresses: string[]) => Promise<void>;
  };
};
export type SmartContractAccount = {
  contract: AbstractAccount;
  contractAddress: string;
  signer: Signer;
};

// Deploy configuration options
export type DeployConfiguration = {
  numAbstractAccounts: number;
};

// Deploy the testing environment
export async function deployTestEnvironment(
  config: DeployConfiguration = { numAbstractAccounts: 4 },
): Promise<Environment> {
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
  const registerStandardGas =
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

  //deploy smart contract wallets
  let abstractAccountGasUsed = 0n;
  const abstractAccounts: SmartContractAccount[] = [];
  for (let i = 0; i < config.numAbstractAccounts; i++) {
    const signer = new ethers.Wallet(ethers.hexlify(ethers.randomBytes(32)));
    const account = await ethers.deployContract(
      'AbstractAccount',
      [entrypointAddress, await signer.getAddress()],
      deployer,
    );
    abstractAccounts.push({
      contract: account,
      contractAddress: await account.getAddress(),
      signer,
    });
    const gasUsed = (await account.deploymentTransaction()?.wait())?.gasUsed;
    abstractAccountGasUsed += gasUsed ? gasUsed : 0n;
  }
  abstractAccountGasUsed /= BigInt(config.numAbstractAccounts);

  //fund exchange
  const funder = signers[signers.length - 1];
  await testERC20.mint(testUniswapAddress, ethers.parseEther('1000'));
  await testWrappedNativeToken.connect(funder).deposit({ value: ethers.parseEther('1000') });
  await testWrappedNativeToken.connect(funder).transfer(testUniswapAddress, ethers.parseEther('1000'));

  //deploy stateful encoding and intent compression helpers
  const dataRegistry = await ethers.deployContract('DataRegistry', [], deployer);
  const dataRegistryAddress = await dataRegistry.getAddress();
  const generalCompression = await ethers.deployContract('GeneralIntentCompression', [dataRegistryAddress], deployer);
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

  //fill the data registry with medium frequency items
  (await dataRegistry.addTwoByteItem(ethers.hexlify(ethers.randomBytes(32)))).wait();
  (await dataRegistry.addTwoByteItem('0x' + testUniswapAddress.substring(2).padStart(64, '0'))).wait();
  (await dataRegistry.addTwoByteItem('0x' + solverUtilsAddress.substring(2).padStart(64, '0'))).wait();
  (await dataRegistry.addFunctionSelector('0xb61d27f6')).wait();
  (await dataRegistry.addFunctionSelector('0xa9059cbb')).wait();

  //fill the data registry with low frequency items
  (await dataRegistry.addFourByteItem(ethers.hexlify(ethers.randomBytes(32)))).wait();
  for (const acct of abstractAccounts) {
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
      ethRecord: () => new EthRecordSegment(ethRecordStdId),
      ethRelease: (curve: Curve) => new EthReleaseSegment(ethReleaseStdId, curve),
      ethRequire: (curve: Curve) => new EthRequireSegment(ethRequireStdId, curve),
      erc20Record: (contract: string) => new Erc20RecordSegment(erc20RecordStdId, contract),
      erc20Release: (contract: string, curve: Curve) => new Erc20ReleaseSegment(erc20ReleaseStdId, contract, curve),
      erc20Require: (contract: string, curve: Curve) => new Erc20RequireSegment(erc20RequireStdId, contract, curve),
    },
    registeredStandards: {
      call: (callData: string) => new SimpleCallSegment(simpleCall.standardId, callData),
      userOp: (callData: string, gasLimit: number) =>
        new UserOperationSegment(userOperation.standardId, callData, gasLimit),
      sequentialNonce: (nonce: number) => new SequentialNonceSegment(sequentialNonce.standardId, nonce),
      ethRecord: () => new EthRecordSegment(ethRecord.standardId),
      ethRelease: (curve: Curve) => new EthReleaseSegment(ethRelease.standardId, curve),
      ethRequire: (curve: Curve) => new EthRequireSegment(ethRequire.standardId, curve),
      erc20Record: (contract: string) => new Erc20RecordSegment(erc20Record.standardId, contract),
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
      dataRegistry,
      generalIntent: generalIntentCompression,
    },
    solverUtils,
    abstractAccounts,
    gasUsed: {
      entrypoint: entrypointGasUsed,
      registerStandard: registerStandardGas,
      abstractAccount: abstractAccountGasUsed,
      generalCompression: generalCompressionGasUsed,
    },
    utils: {
      getNonce: async (account: string) => {
        return Number((await entrypoint.getNonce(account, '0x000000000000000000000000000000000000000000000000')) + 1n);
      },
      roundForEncoding: (amount: bigint) => {
        const timestamp = Math.round(new Date().getTime() / 1000);
        const evaluateAt = 1000;
        const startTime = timestamp - evaluateAt;
        const duration = 3000;
        const startAmount = 0n;
        const endAmount = amount * BigInt(duration / evaluateAt);
        const curve = new LinearCurve(startTime, duration, startAmount, endAmount);
        return curve.evaluate(timestamp);
      },
      randomAddresses: (num: number) => {
        const addresses: string[] = [];
        for (let i = 0; i < num; i++) addresses.push(ethers.hexlify(ethers.randomBytes(20)));
        return addresses;
      },
      registerAddresses: async (addresses: string[]) => {
        for (const addr of addresses) {
          (await dataRegistry.addFourByteItem('0x' + addr.substring(2).padStart(64, '0'))).wait();
        }
      },
    },
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
