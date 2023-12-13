import { BlsSignerFactory, BlsSignerInterface } from '@thehubbleproject/bls/dist/signer';
import { Provider, Signer } from 'ethers';
import { ethers } from 'hardhat';
import {
  ECDSAAccount,
  BLSAccount,
  BLSOpen,
  BLSSignatureAggregator,
  BLSSignatureAggregator__factory,
  EntryPoint,
  SolverUtils,
  TestERC20,
  TestUniswap,
  TestWrappedNativeToken,
  BLSOpen__factory,
} from '../../../typechain';
import { Curve, LinearCurve, ExponentialCurve } from './curveCoder';
import { SimpleCallSegment } from './standards/simpleCall';
import { UserOperationSegment } from './standards/userOperation';
import { SequentialNonceSegment } from './standards/sequentialNonce';
import { EthRecordSegment } from './standards/ethRecord';
import { EthReleaseSegment } from './standards/ethRelease';
import { EthRequireSegment } from './standards/ethRequire';
import { Erc20RecordSegment } from './standards/erc20Record';
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
  solverUtils: SolverUtils;
  ecdsaAccounts: ECDSASmartContractAccount[];
  blsAccounts: BLSSmartContractAccount[];
  blsAggregator: BLSSignatureAggregator;
  blsDomain: Uint8Array;
};
export type ECDSASmartContractAccount = {
  contract: ECDSAAccount;
  contractAddress: string;
  signer: Signer;
};
export type BLSSmartContractAccount = {
  contract: BLSAccount;
  contractAddress: string;
  signer: BlsSignerInterface;
};

// Deploy configuration options
export type DeployConfiguration = {
  numECDSAAccounts: number;
  numBLSAccounts: number;
};

// Deploy the testing environment
export async function deployTestEnvironment(
  config: DeployConfiguration = { numECDSAAccounts: 4, numBLSAccounts: 4 },
): Promise<Environment> {
  const provider = ethers.provider;
  const network = await provider.getNetwork();
  const signers = await ethers.getSigners();
  const deployer = signers[0];

  //deploy the entrypoint contract and register intent standards
  const entrypoint = await ethers.deployContract('EntryPoint', [], deployer);
  const entrypointAddress = await entrypoint.getAddress();
  const callStdId = await entrypoint.getSimpleCallStandardId();
  const userOperationStdId = await entrypoint.getUserOperationStandardId();
  const ethRecordStdId = await entrypoint.getEthRecordStandardId();
  const ethRequireStdId = await entrypoint.getEthRequireStandardId();
  const ethReleaseStdId = await entrypoint.getEthReleaseStandardId();

  const erc20Record = await ethers.deployContract('Erc20Record', [], deployer);
  const erc20RecordAddress = await erc20Record.getAddress();
  await (await entrypoint.registerIntentStandard(erc20RecordAddress)).wait();
  const erc20RecordStdId = await entrypoint.getIntentStandardId(erc20RecordAddress);

  const erc20Release = await ethers.deployContract('Erc20Release', [], deployer);
  const erc20ReleaseAddress = await erc20Release.getAddress();
  await (await entrypoint.registerIntentStandard(erc20ReleaseAddress)).wait();
  const erc20ReleaseStdId = await entrypoint.getIntentStandardId(erc20ReleaseAddress);

  const erc20ReleaseExp = await ethers.deployContract('Erc20ReleaseExponential', [], deployer);
  const erc20ReleaseExpAddress = await erc20ReleaseExp.getAddress();
  await (await entrypoint.registerIntentStandard(erc20ReleaseExpAddress)).wait();
  const erc20ReleaseExpStdId = await entrypoint.getIntentStandardId(erc20ReleaseExpAddress);

  const erc20ReleaseLin = await ethers.deployContract('Erc20ReleaseLinear', [], deployer);
  const erc20ReleaseLinAddress = await erc20ReleaseLin.getAddress();
  await (await entrypoint.registerIntentStandard(erc20ReleaseLinAddress)).wait();
  const erc20ReleaseLinStdId = await entrypoint.getIntentStandardId(erc20ReleaseLinAddress);

  const erc20Require = await ethers.deployContract('Erc20Require', [], deployer);
  const erc20RequireAddress = await erc20Require.getAddress();
  await (await entrypoint.registerIntentStandard(erc20RequireAddress)).wait();
  const erc20RequireStdId = await entrypoint.getIntentStandardId(erc20RequireAddress);

  const erc20RequireExp = await ethers.deployContract('Erc20RequireExponential', [], deployer);
  const erc20RequireExpAddress = await erc20RequireExp.getAddress();
  await (await entrypoint.registerIntentStandard(erc20RequireExpAddress)).wait();
  const erc20RequireExpStdId = await entrypoint.getIntentStandardId(erc20RequireExpAddress);

  const erc20RequireLin = await ethers.deployContract('Erc20RequireLinear', [], deployer);
  const erc20RequireLinAddress = await erc20RequireLin.getAddress();
  await (await entrypoint.registerIntentStandard(erc20RequireLinAddress)).wait();
  const erc20RequireLinStdId = await entrypoint.getIntentStandardId(erc20RequireLinAddress);

  const ethReleaseExp = await ethers.deployContract('EthReleaseExponential', [], deployer);
  const ethReleaseExpAddress = await ethReleaseExp.getAddress();
  await (await entrypoint.registerIntentStandard(ethReleaseExpAddress)).wait();
  const ethReleaseExpStdId = await entrypoint.getIntentStandardId(ethReleaseExpAddress);

  const ethReleaseLin = await ethers.deployContract('EthReleaseLinear', [], deployer);
  const ethReleaseLinAddress = await ethReleaseLin.getAddress();
  await (await entrypoint.registerIntentStandard(ethReleaseLinAddress)).wait();
  const ethReleaseLinStdId = await entrypoint.getIntentStandardId(ethReleaseLinAddress);

  const ethRequireExp = await ethers.deployContract('EthRequireExponential', [], deployer);
  const ethRequireExpAddress = await ethRequireExp.getAddress();
  await (await entrypoint.registerIntentStandard(ethRequireExpAddress)).wait();
  const ethRequireExpStdId = await entrypoint.getIntentStandardId(ethRequireExpAddress);

  const ethRequireLin = await ethers.deployContract('EthRequireLinear', [], deployer);
  const ethRequireLinAddress = await ethRequireLin.getAddress();
  await (await entrypoint.registerIntentStandard(ethRequireLinAddress)).wait();
  const ethRequireLinStdId = await entrypoint.getIntentStandardId(ethRequireLinAddress);

  const sequentialNonce = await ethers.deployContract('SequentialNonce', [], deployer);
  const sequentialNonceAddress = await sequentialNonce.getAddress();
  await (await entrypoint.registerIntentStandard(sequentialNonceAddress)).wait();
  const sequentialNonceStdId = await entrypoint.getIntentStandardId(sequentialNonceAddress);

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
  const ecdsaAccounts = [];
  for (let i = 0; i < config.numECDSAAccounts; i++) {
    const signer = new ethers.Wallet(ethers.hexlify(ethers.randomBytes(32)));
    const account = await ethers.deployContract(
      'ECDSAAccount',
      [entrypointAddress, await signer.getAddress()],
      deployer,
    );
    ecdsaAccounts.push({ contract: account, contractAddress: await account.getAddress(), signer });
  }

  // deploy BLS wallets
  const abi = new ethers.AbiCoder();
  const blsDomain = ethers.getBytes(ethers.keccak256(abi.encode(['string'], ['eip7521.bls.domain'])));
  const BLSOpenLib = await new BLSOpen__factory(deployer).deploy();

  const blsAggregator = await new BLSSignatureAggregator__factory(
    {
      'src/wallet/bls/lib/BLSOpen.sol:BLSOpen': await BLSOpenLib.getAddress(),
    },
    deployer,
  ).deploy(entrypointAddress);
  let factory = await BlsSignerFactory.new();

  const blsAccounts = [];
  for (let i = 0; i < config.numBLSAccounts; i++) {
    const signer = factory.getSigner(blsDomain, ethers.hexlify(ethers.randomBytes(32)));

    const blsAccount = await ethers.deployContract(
      'BLSAccount',
      [entrypointAddress, await blsAggregator.getAddress(), signer.pubkey],
      deployer,
    );

    blsAccounts.push({ contract: blsAccount, contractAddress: await blsAccount.getAddress(), signer });
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
      call: (callData: string) => new SimpleCallSegment(callStdId, callData),
      userOp: (callData: string, gasLimit: number) => new UserOperationSegment(userOperationStdId, callData, gasLimit),
      sequentialNonce: (nonce: number) => new SequentialNonceSegment(sequentialNonceStdId, nonce),
      ethRecord: () => new EthRecordSegment(ethRecordStdId),
      ethRelease: (curve: Curve) => {
        if (curve instanceof ExponentialCurve) return new EthReleaseSegment(ethReleaseExpStdId, curve);
        if (curve instanceof LinearCurve) return new EthReleaseSegment(ethReleaseLinStdId, curve);
        return new EthReleaseSegment(ethReleaseStdId, curve);
      },
      ethRequire: (curve: Curve) => {
        if (curve instanceof ExponentialCurve) return new EthRequireSegment(ethRequireExpStdId, curve);
        if (curve instanceof LinearCurve) return new EthRequireSegment(ethRequireLinStdId, curve);
        return new EthRequireSegment(ethRequireStdId, curve);
      },
      erc20Record: (contract: string) => new Erc20RecordSegment(erc20RecordStdId, contract),
      erc20Release: (contract: string, curve: Curve) => {
        if (curve instanceof ExponentialCurve) return new Erc20ReleaseSegment(erc20ReleaseExpStdId, contract, curve);
        if (curve instanceof LinearCurve) return new Erc20ReleaseSegment(erc20ReleaseLinStdId, contract, curve);
        return new Erc20ReleaseSegment(erc20ReleaseStdId, contract, curve);
      },
      erc20Require: (contract: string, curve: Curve) => {
        if (curve instanceof ExponentialCurve) return new Erc20RequireSegment(erc20RequireExpStdId, contract, curve);
        if (curve instanceof LinearCurve) return new Erc20RequireSegment(erc20RequireLinStdId, contract, curve);
        return new Erc20RequireSegment(erc20RequireStdId, contract, curve);
      },
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
    ecdsaAccounts,
    blsAccounts,
    blsAggregator,
    blsDomain,
  };
}
