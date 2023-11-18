import { Provider, Signer } from 'ethers';
import { ethers } from 'hardhat';
import {
  AbstractAccount,
  EntryPoint,
  SolverUtils,
  TestERC20,
  TestUniswap,
  TestWrappedNativeToken,
} from '../../../typechain';
import { CallSegment } from './standards/call';
import { UserOperationSegment } from './standards/userOperation';
import { SequentialNonceSegment } from './standards/sequentialNonce';
import { EthReleaseSegment } from './standards/ethRelease';
import { EthRequireSegment } from './standards/ethRequire';
import { Erc20ReleaseSegment } from './standards/erc20Release';
import { Erc20RequireSegment } from './standards/erc20Require';

// Environment definition
export type Environment = {
  chainId: bigint;
  provider: Provider;
  deployer: Signer;
  deployerAddress: string;
  entrypoint: EntryPoint;
  entrypointAddress: string;
  standards: {
    call: (callData: string) => CallSegment;
    userOp: (callData: string, gasLimit: bigint) => UserOperationSegment;
    sequentialNonce: (nonce: number) => SequentialNonceSegment;
    ethRelease: (timeStart: number, timeEnd: number, amountStart: bigint, amountEnd: bigint) => EthReleaseSegment;
    ethRequire: (timeStart: number, timeEnd: number, amountStart: bigint, amountEnd: bigint) => EthRequireSegment;
    erc20Release: (
      contract: string,
      timeStart: number,
      timeEnd: number,
      amountStart: bigint,
      amountEnd: bigint
    ) => Erc20ReleaseSegment;
    erc20Require: (
      contract: string,
      timeStart: number,
      timeEnd: number,
      amountStart: bigint,
      amountEnd: bigint
    ) => Erc20RequireSegment;
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
  solverUtils: SolverUtils;
  abstractAccounts: SmartContractAccount[];
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
  config: DeployConfiguration = { numAbstractAccounts: 4 }
): Promise<Environment> {
  const provider = ethers.provider;
  const network = await provider.getNetwork();
  const signers = await ethers.getSigners();
  const deployer = signers[0];

  //deploy the entrypoint contract and register intent standards
  const entrypoint = await ethers.deployContract('EntryPoint', [], deployer);
  const entrypointAddress = await entrypoint.getAddress();
  const callStdId = await entrypoint.standardId();

  const userOperation = await ethers.deployContract('UserOperation', [], deployer);
  const userOperationAddress = await userOperation.getAddress();
  await (await entrypoint.registerIntentStandard(userOperationAddress)).wait();
  const userOperationStdId = await entrypoint.getIntentStandardId(userOperationAddress);

  const sequentialNonce = await ethers.deployContract('SequentialNonce', [], deployer);
  const sequentialNonceAddress = await sequentialNonce.getAddress();
  await (await entrypoint.registerIntentStandard(sequentialNonceAddress)).wait();
  const sequentialNonceStdId = await entrypoint.getIntentStandardId(sequentialNonceAddress);

  const ethRelease = await ethers.deployContract('EthReleaseIntentStandard', [], deployer);
  const ethReleaseAddress = await ethRelease.getAddress();
  await (await entrypoint.registerIntentStandard(ethReleaseAddress)).wait();
  const ethReleaseStdId = await entrypoint.getIntentStandardId(ethReleaseAddress);

  const ethRequire = await ethers.deployContract('EthRequireIntentStandard', [], deployer);
  const ethRequireAddress = await ethRequire.getAddress();
  await (await entrypoint.registerIntentStandard(ethRequireAddress)).wait();
  const ethRequireStdId = await entrypoint.getIntentStandardId(ethRequireAddress);

  const erc20Release = await ethers.deployContract('Erc20ReleaseIntentStandard', [], deployer);
  const erc20ReleaseAddress = await erc20Release.getAddress();
  await (await entrypoint.registerIntentStandard(erc20ReleaseAddress)).wait();
  const erc20ReleaseStdId = await entrypoint.getIntentStandardId(erc20ReleaseAddress);

  const erc20Require = await ethers.deployContract('Erc20RequireIntentStandard', [], deployer);
  const erc20RequireAddress = await erc20Require.getAddress();
  await (await entrypoint.registerIntentStandard(erc20RequireAddress)).wait();
  const erc20RequireStdId = await entrypoint.getIntentStandardId(erc20RequireAddress);

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
    deployer
  );
  const solverUtilsAddress = await testUniswap.getAddress();

  //deploy smart contract wallets
  const abstractAccounts = [];
  for (let i = 0; i < config.numAbstractAccounts; i++) {
    const signer = new ethers.Wallet(ethers.hexlify(ethers.randomBytes(32)));
    const account = await ethers.deployContract(
      'AbstractAccount',
      [entrypointAddress, await signer.getAddress()],
      deployer
    );
    abstractAccounts.push({
      contract: account,
      contractAddress: await account.getAddress(),
      signer,
    });
  }

  //fund exchange
  const funder = signers[signers.length - 1];
  await testERC20.mint(testUniswapAddress, ethers.parseEther('1000'));
  await testWrappedNativeToken.connect(funder).deposit({ value: ethers.parseEther('1000') });
  await testWrappedNativeToken.connect(funder).transfer(testUniswapAddress, ethers.parseEther('1000'));

  return {
    chainId: network.chainId,
    provider,
    deployer,
    deployerAddress: await deployer.getAddress(),
    entrypoint,
    entrypointAddress,
    standards: {
      call: (callData: string) => new CallSegment(callStdId, callData),
      userOp: (callData: string, gasLimit: bigint) => new UserOperationSegment(userOperationStdId, callData, gasLimit),
      sequentialNonce: (nonce: number) => new SequentialNonceSegment(sequentialNonceStdId, nonce),
      ethRelease: (timeStart: number, timeEnd: number, amountStart: bigint, amountEnd: bigint) =>
        new EthReleaseSegment(ethReleaseStdId, timeStart, timeEnd, amountStart, amountEnd),
      ethRequire: (timeStart: number, timeEnd: number, amountStart: bigint, amountEnd: bigint) =>
        new EthRequireSegment(ethRequireStdId, timeStart, timeEnd, amountStart, amountEnd),
      erc20Release: (contract: string, timeStart: number, timeEnd: number, amountStart: bigint, amountEnd: bigint) =>
        new Erc20ReleaseSegment(erc20ReleaseStdId, contract, timeStart, timeEnd, amountStart, amountEnd),
      erc20Require: (contract: string, timeStart: number, timeEnd: number, amountStart: bigint, amountEnd: bigint) =>
        new Erc20RequireSegment(erc20RequireStdId, contract, timeStart, timeEnd, amountStart, amountEnd),
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
    solverUtils,
    abstractAccounts,
  };
}
