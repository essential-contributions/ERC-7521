import { ethers } from 'hardhat';
import { Transaction, ContractTransactionResponse } from 'ethers';
import { ScenarioOptions, ScenarioResult, Scenario, DEFAULT_SCENARIO_OPTIONS } from './scenario';
import { BLSSmartContractAccount, Environment, SmartContractAccount } from '../../scripts/scenarios/environment';
import { buildSolution, UserIntent } from '../../scripts/library/intent';
import { ConstantCurve, Curve, LinearCurve } from '../../scripts/library/curveCoder';
import { ExactInputSingleParamsStruct } from '../../typechain/src/test/TestUniswap';

// The scenario object
export class TokenSwapScenario extends Scenario {
  private env: Environment;
  public TOKEN_SWAP_SLIPPAGE = 5n;

  constructor(environment: Environment) {
    super();
    this.env = environment;
  }

  //initialize the scenario
  public async init() {
    //fund accounts
    const needToMint = ethers.parseEther('1000') - (await this.env.test.erc20.balanceOf(this.env.deployerAddress));
    if (needToMint > 0) {
      await (await this.env.test.erc20.mint(this.env.deployerAddress, needToMint)).wait();
    }
    for (const account of this.env.simpleAccounts) {
      const needToMint = ethers.parseEther('1000') - (await this.env.test.erc20.balanceOf(account.contractAddress));
      if (needToMint > 0) {
        await (await this.env.test.erc20.mint(account.contractAddress, needToMint)).wait();
      }
      const needToFund = ethers.parseEther('10') - (await this.env.provider.getBalance(account.contractAddress));
      if (needToFund > 0) {
        await (await this.env.deployer.sendTransaction({ to: account.contractAddress, value: needToFund })).wait();
      }
    }
    for (const account of this.env.blsAccounts) {
      const needToMint = ethers.parseEther('1000') - (await this.env.test.erc20.balanceOf(account.contractAddress));
      if (needToMint > 0) {
        await (await this.env.test.erc20.mint(account.contractAddress, needToMint)).wait();
      }
      const needToFund = ethers.parseEther('10') - (await this.env.provider.getBalance(account.contractAddress));
      if (needToFund > 0) {
        await (await this.env.deployer.sendTransaction({ to: account.contractAddress, value: needToFund })).wait();
      }
    }
    for (const account of this.env.eoaProxyAccounts) {
      const needToMint = ethers.parseEther('1000') - (await this.env.test.erc20.balanceOf(account.signerAddress));
      if (needToMint > 0) {
        await (await this.env.test.erc20.mint(account.signerAddress, needToMint)).wait();
      }
      const needToFund = ethers.parseEther('10') - (await this.env.provider.getBalance(account.signerAddress));
      if (needToFund > 0) {
        await (await this.env.deployer.sendTransaction({ to: account.signerAddress, value: needToFund })).wait();
      }
    }

    //approve deployer swapping erc20
    await (await this.env.test.erc20.approve(this.env.test.uniswapAddress, ethers.parseEther('1000'))).wait();
  }

  //runs the baseline EOA version for the scenario
  public async runBaseline(to?: string): Promise<ScenarioResult> {
    const amount = ethers.parseEther('1');

    const swapParams = this.getSwapParams(
      this.env.test.erc20Address,
      this.env.test.wrappedNativeTokenAddress,
      amount,
      this.env.deployerAddress,
    );
    const txPromise = this.env.test.uniswap.exactInputSingle(swapParams);
    const tx = await txPromise;
    const unwrap = await this.env.test.wrappedNativeToken.withdraw(
      await this.env.test.wrappedNativeToken.balanceOf(this.env.deployerAddress),
    );

    const serialized = Transaction.from(tx).serialized;
    const bytesUsed = serialized.length / 2 - 1;
    const gasUsed = Number(((await tx.wait())?.gasUsed || 0n) + ((await unwrap.wait())?.gasUsed || 0n));
    const txFee =
      ((await tx.wait())?.gasUsed || 0n) * ((await tx.wait())?.gasPrice || 0n) +
      ((await unwrap.wait())?.gasUsed || 0n) * ((await unwrap.wait())?.gasPrice || 0n);
    return { invalidOptions: false, gasUsed, bytesUsed, txFee, serialized, amount, fee: 0n, tx: txPromise };
  }

  //runs the scenario
  public async run(count?: string[] | number, options?: ScenarioOptions): Promise<ScenarioResult> {
    options = options || DEFAULT_SCENARIO_OPTIONS;
    count = count || 1;
    const batchSize: number = typeof count == 'number' ? count : count.length || 1;
    const proxy = options.useAccountAsEOAProxy;
    const bls = options.useBLSSignatureAggregation;

    if (this.env.simpleAccounts.length < batchSize) throw new Error('not enough abstract accounts to run batch');
    const timestamp = (await this.env.provider.getBlock('latest'))?.timestamp || 0;
    const amount = ethers.parseEther('1');
    if (batchSize <= 1) return this.runSingle(timestamp, amount, options);

    //create intents
    const intents: UserIntent[] = [];
    const signatures: string[] = [];
    const tos: string[] = [];
    const amounts: bigint[] = [];
    for (let i = 0; i < batchSize; i++) {
      let account: SmartContractAccount | BLSSmartContractAccount = this.env.simpleAccounts[i];
      if (proxy) account = this.env.eoaProxyAccounts[i];
      else if (bls) account = this.env.blsAccounts[i];

      const intent = new UserIntent(account.contractAddress);
      if (options.useEmbeddedStandards) {
        //using the embedded intent standard versions
        intent.addSegment(this.env.standards.sequentialNonce(await this.env.utils.getNonce(account.contractAddress)));
        intent.addSegment(this.env.standards.ethRecord(proxy));
        intent.addSegment(
          this.env.standards.erc20Release(
            this.env.test.erc20Address,
            this.generateLinearRelease(timestamp, amount, proxy),
          ),
        );
        intent.addSegment(this.env.standards.ethRequire(new ConstantCurve(amount, true, proxy)));
      } else {
        //using the registered intent standard versions
        intent.addSegment(
          this.env.registeredStandards.sequentialNonce(await this.env.utils.getNonce(account.contractAddress)),
        );
        intent.addSegment(this.env.registeredStandards.ethRecord(proxy));
        intent.addSegment(
          this.env.registeredStandards.erc20Release(
            this.env.test.erc20Address,
            this.generateLinearRelease(timestamp, amount, proxy),
          ),
        );
        intent.addSegment(this.env.registeredStandards.ethRequire(new ConstantCurve(amount, true, proxy)));
      }

      //sign
      if (bls) {
        const hash = intent.hash(this.env.chainId, this.env.entrypointAddress);
        const blsSignature = (account as BLSSmartContractAccount).signer.sign(hash);
        signatures.push(blsSignature);
      } else {
        await intent.sign(this.env.chainId, this.env.entrypointAddress, (account as SmartContractAccount).signer);
      }

      intents.push(intent);
      tos.push(proxy ? (account as SmartContractAccount).signerAddress : account.contractAddress);
      amounts.push(amount);
    }

    //aggregate signatures
    const aggregatedSignature = signatures.length > 0 ? this.env.blsVerifier.aggregate(signatures) : '';
    let bitfield = 0n;
    for (let i = 0; i < signatures.length; i++) bitfield = (bitfield << 1n) + 1n;
    const toAggregate = `0x${bitfield.toString(16).padStart(64, '0')}`;

    //solver intents
    const solverIntent1 = new UserIntent(this.env.test.solverUtilsAddress);
    const solverIntent2 = new UserIntent(this.env.test.solverUtilsAddress);
    solverIntent2.addSegment(
      this.env.standards.call(this.generateSolverSwapMultiTx(this.env.deployerAddress, tos, amounts)),
    );
    intents.push(solverIntent1);
    intents.push(solverIntent2);

    //solution
    const order = [];
    for (let i = 0; i < batchSize; i++) {
      order.push(i);
      order.push(i);
      order.push(i);
      order.push(batchSize);
    }
    order.push(batchSize + 1);
    for (let i = 0; i < batchSize; i++) {
      order.push(i);
    }
    const solution = buildSolution(timestamp, intents, order);

    //handle intents
    let txPromise: Promise<ContractTransactionResponse>;
    if (options.useCompression) {
      if (aggregatedSignature) {
        txPromise = this.env.compression.general.handleIntentsAggregated(
          [solution],
          this.env.blsSignatureAggregatorAddress,
          toAggregate,
          aggregatedSignature,
          options.useStatefulCompression,
        );
      } else {
        txPromise = this.env.compression.general.handleIntents(solution, options.useStatefulCompression);
      }
    } else {
      if (aggregatedSignature) {
        txPromise = this.env.entrypoint.handleIntentsAggregated(
          [solution],
          this.env.blsSignatureAggregatorAddress,
          toAggregate,
          aggregatedSignature,
        );
      } else {
        txPromise = this.env.entrypoint.handleIntents(solution);
      }
    }
    const tx = await txPromise;

    const serialized = Transaction.from(tx).serialized;
    const bytesUsed = serialized.length / 2 - 1;
    const gasUsed = Number((await tx.wait())?.gasUsed || 0n);
    const txFee = ((await tx.wait())?.gasUsed || 0n) * ((await tx.wait())?.gasPrice || 0n);
    return { invalidOptions: false, gasUsed, bytesUsed, txFee, serialized, amount, fee: 0n, tx: txPromise };
  }

  //////////////////////
  // Helper Functions //
  //////////////////////

  // helper function to execute a single intent in the scenario
  private async runSingle(timestamp: number, amount: bigint, options: ScenarioOptions): Promise<ScenarioResult> {
    const proxy = options.useAccountAsEOAProxy;
    const bls = options.useBLSSignatureAggregation;
    let account: SmartContractAccount | BLSSmartContractAccount = this.env.simpleAccounts[0];
    if (proxy) account = this.env.eoaProxyAccounts[0];
    else if (bls) account = this.env.blsAccounts[0];
    const to = proxy ? (account as SmartContractAccount).signerAddress : account.contractAddress;

    //create intent
    const intent = new UserIntent(account.contractAddress);
    if (options.useEmbeddedStandards) {
      //using the embedded intent standard versions
      intent.addSegment(this.env.standards.sequentialNonce(await this.env.utils.getNonce(account.contractAddress)));
      intent.addSegment(this.env.standards.ethRecord(proxy));
      intent.addSegment(
        this.env.standards.erc20Release(
          this.env.test.erc20Address,
          this.generateLinearRelease(timestamp, amount, proxy),
        ),
      );
      intent.addSegment(this.env.standards.ethRequire(new ConstantCurve(amount, true, proxy)));
    } else {
      //using the registered intent standard versions
      intent.addSegment(
        this.env.registeredStandards.sequentialNonce(await this.env.utils.getNonce(account.contractAddress)),
      );
      intent.addSegment(this.env.registeredStandards.ethRecord(proxy));
      intent.addSegment(
        this.env.registeredStandards.erc20Release(
          this.env.test.erc20Address,
          this.generateLinearRelease(timestamp, amount, proxy),
        ),
      );
      intent.addSegment(this.env.registeredStandards.ethRequire(new ConstantCurve(amount, true, proxy)));
    }

    //sign
    if (bls) {
      const hash = intent.hash(this.env.chainId, this.env.entrypointAddress);
      const blsSignature = (account as BLSSmartContractAccount).signer.sign(hash);
      intent.setSignature(blsSignature);
    } else {
      await intent.sign(this.env.chainId, this.env.entrypointAddress, (account as SmartContractAccount).signer);
    }

    //solver intent
    const solverIntent = new UserIntent(this.env.test.solverUtilsAddress);
    solverIntent.addSegment(this.env.standards.call(this.generateSolverSwapTx(this.env.deployerAddress, to, amount)));

    //solution
    const solution = buildSolution(timestamp, [intent, solverIntent], [0, 0, 0, 1, 0]);

    //handle intents
    const txPromise = options.useCompression
      ? this.env.compression.general.handleIntents(solution, options.useStatefulCompression)
      : this.env.entrypoint.handleIntents(solution);
    const tx = await txPromise;

    const serialized = Transaction.from(tx).serialized;
    const bytesUsed = serialized.length / 2 - 1;
    const gasUsed = Number((await tx.wait())?.gasUsed || 0n);
    const txFee = ((await tx.wait())?.gasUsed || 0n) * ((await tx.wait())?.gasPrice || 0n);
    return { invalidOptions: false, gasUsed, bytesUsed, txFee, serialized, amount, fee: 0n, tx: txPromise };
  }

  // helper function to generate transfer tx calldata
  private generateSolverSwapTx(solver: string, to: string, amount: bigint): string {
    return this.env.test.solverUtils.interface.encodeFunctionData('swapERC20ForETHAndForward', [
      this.env.test.uniswapAddress,
      this.env.test.erc20Address,
      this.env.test.wrappedNativeTokenAddress,
      amount,
      solver,
      amount,
      to,
    ]);
  }

  // helper function to generate transfer tx calldata
  private generateSolverSwapMultiTx(solver: string, tos: string[], amounts: bigint[]): string {
    let minSwap = 0n;
    for (const amount of amounts) minSwap += amount;
    return this.env.test.solverUtils.interface.encodeFunctionData('swapERC20ForETHAndForwardMulti', [
      this.env.test.uniswapAddress,
      this.env.test.erc20Address,
      this.env.test.wrappedNativeTokenAddress,
      minSwap,
      solver,
      amounts,
      tos,
    ]);
  }

  // helper function to generate a linear release curve
  private generateLinearRelease(timestamp: number, amount: bigint, proxy: boolean): Curve {
    const evaluateAt = 1000;
    const startTime = timestamp - evaluateAt;
    const duration = 3000;
    const startAmount = 0n;
    const endAmount = amount * BigInt(duration / evaluateAt);
    return new LinearCurve(startTime, duration, startAmount, endAmount, false, proxy);
  }

  // helper function to get token swap params
  private getSwapParams(
    tokenIn: string,
    tokenOut: string,
    amount: bigint,
    recipient: string,
  ): ExactInputSingleParamsStruct {
    return {
      tokenIn,
      tokenOut,
      fee: 0,
      recipient,
      deadline: 0,
      amountIn: amount,
      amountOutMinimum: amount,
      sqrtPriceLimitX96: 0,
    };
  }
}
