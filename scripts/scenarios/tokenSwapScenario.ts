import { ethers } from 'hardhat';
import { Transaction } from 'ethers';
import { Environment } from '../../scripts/scenarios/environment';
import { buildSolution, UserIntent } from '../../scripts/library/intent';
import { ConstantCurve, Curve, LinearCurve } from '../../scripts/library/curveCoder';
import { ExactInputSingleParamsStruct } from '../../typechain/src/test/TestUniswap';

// Swap result definition
export type TokenSwapResult = {
  gasUsed: number;
  bytesUsed: number;
  txFee: bigint;
  serialized: string;
  amount: bigint;
};

// The scenario object
export class TokenSwapScenario {
  private env: Environment;
  public TOKEN_SWAP_SLIPPAGE = 5n;

  constructor(environment: Environment) {
    this.env = environment;
  }

  //initialize the scenario
  public async init() {
    //fund accounts
    const needToMint = ethers.parseEther('1000') - (await this.env.test.erc20.balanceOf(this.env.deployerAddress));
    if (needToMint > 0) {
      await (await this.env.test.erc20.mint(this.env.deployerAddress, needToMint)).wait();
    }
    for (const account of this.env.abstractAccounts) {
      const needToMint = ethers.parseEther('1000') - (await this.env.test.erc20.balanceOf(account.contractAddress));
      if (needToMint > 0) {
        await (await this.env.test.erc20.mint(account.contractAddress, needToMint)).wait();
      }
      const needToFund = ethers.parseEther('10') - (await this.env.provider.getBalance(account.contractAddress));
      if (needToFund > 0) {
        await (await this.env.deployer.sendTransaction({ to: account.contractAddress, value: needToFund })).wait();
      }
    }

    //approve deployer swapping erc20
    await (await this.env.test.erc20.approve(this.env.test.uniswapAddress, ethers.parseEther('1000'))).wait();
  }

  //runs the baseline EOA version for the scenario
  public async runBaseline(): Promise<TokenSwapResult> {
    const amount = ethers.parseEther('1');

    const swapParams = this.getSwapParams(
      this.env.test.erc20Address,
      this.env.test.wrappedNativeTokenAddress,
      amount,
      this.env.deployerAddress,
    );
    const tx = await this.env.test.uniswap.exactInputSingle(swapParams);
    const unwrap = await this.env.test.wrappedNativeToken.withdraw(
      await this.env.test.wrappedNativeToken.balanceOf(this.env.deployerAddress),
    );

    const serialized = Transaction.from(tx).serialized;
    const bytesUsed = serialized.length / 2 - 1;
    const gasUsed = Number(((await tx.wait())?.gasUsed || 0n) + ((await unwrap.wait())?.gasUsed || 0n));
    const txFee =
      ((await tx.wait())?.gasUsed || 0n) * ((await tx.wait())?.gasPrice || 0n) +
      ((await unwrap.wait())?.gasUsed || 0n) * ((await unwrap.wait())?.gasPrice || 0n);
    return { gasUsed, bytesUsed, txFee, serialized, amount };
  }

  //runs the scenario
  public async run(batchSize: number, useRegisteredStandards: boolean = false): Promise<TokenSwapResult> {
    if (this.env.abstractAccounts.length < batchSize) throw new Error('not enough abstract accounts to run batch');
    const timestamp = (await this.env.provider.getBlock('latest'))?.timestamp || 0;
    const amount = this.env.utils.roundForEncoding(ethers.parseEther('1'));
    if (batchSize <= 1) return this.runSingle(timestamp, amount, useRegisteredStandards);

    const intents: UserIntent[] = [];
    const tos: string[] = [];
    const amounts: bigint[] = [];
    for (let i = 0; i < batchSize; i++) {
      const account = this.env.abstractAccounts[i];
      const intent = new UserIntent(account.contractAddress);
      if (useRegisteredStandards) {
        //using the registered intent standard versions
        intent.addSegment(
          this.env.registeredStandards.sequentialNonce(await this.env.utils.getNonce(account.contractAddress)),
        );
        intent.addSegment(this.env.registeredStandards.ethRecord());
        intent.addSegment(
          this.env.registeredStandards.erc20Release(
            this.env.test.erc20Address,
            this.generateLinearRelease(timestamp, amount),
          ),
        );
        intent.addSegment(this.env.registeredStandards.ethRequire(new ConstantCurve(amount, true)));
      } else {
        //using the embedded intent standard versions
        intent.addSegment(this.env.standards.sequentialNonce(await this.env.utils.getNonce(account.contractAddress)));
        intent.addSegment(this.env.standards.ethRecord());
        intent.addSegment(
          this.env.standards.erc20Release(this.env.test.erc20Address, this.generateLinearRelease(timestamp, amount)),
        );
        intent.addSegment(this.env.standards.ethRequire(new ConstantCurve(amount, true)));
      }
      await intent.sign(this.env.chainId, this.env.entrypointAddress, account.signer);
      intents.push(intent);
      tos.push(account.contractAddress);
      amounts.push(amount);
    }

    const solverIntent1 = new UserIntent(this.env.test.solverUtilsAddress);
    const solverIntent2 = new UserIntent(this.env.test.solverUtilsAddress);
    solverIntent2.addSegment(
      this.env.standards.call(this.generateSolverSwapMultiTx(this.env.deployerAddress, tos, amounts)),
    );
    intents.push(solverIntent1);
    intents.push(solverIntent2);

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
    const tx = await this.env.entrypoint.handleIntents(buildSolution(timestamp, intents, order));

    const serialized = Transaction.from(tx).serialized;
    const bytesUsed = serialized.length / 2 - 1;
    const gasUsed = Number((await tx.wait())?.gasUsed || 0n);
    const txFee = ((await tx.wait())?.gasUsed || 0n) * ((await tx.wait())?.gasPrice || 0n);
    return { gasUsed, bytesUsed, txFee, serialized, amount };
  }

  //////////////////////
  // Helper Functions //
  //////////////////////

  // helper function to execute a single intent in the scenario
  private async runSingle(
    timestamp: number,
    amount: bigint,
    useRegisteredStandards: boolean,
  ): Promise<TokenSwapResult> {
    const account = this.env.abstractAccounts[0];

    const intent = new UserIntent(account.contractAddress);
    if (useRegisteredStandards) {
      //using the registered intent standard versions
      intent.addSegment(
        this.env.registeredStandards.sequentialNonce(await this.env.utils.getNonce(account.contractAddress)),
      );
      intent.addSegment(this.env.registeredStandards.ethRecord());
      intent.addSegment(
        this.env.registeredStandards.erc20Release(
          this.env.test.erc20Address,
          this.generateLinearRelease(timestamp, amount),
        ),
      );
      intent.addSegment(this.env.registeredStandards.ethRequire(new ConstantCurve(amount, true)));
    } else {
      //using the embedded intent standard versions
      intent.addSegment(this.env.standards.sequentialNonce(await this.env.utils.getNonce(account.contractAddress)));
      intent.addSegment(this.env.standards.ethRecord());
      intent.addSegment(
        this.env.standards.erc20Release(this.env.test.erc20Address, this.generateLinearRelease(timestamp, amount)),
      );
      intent.addSegment(this.env.standards.ethRequire(new ConstantCurve(amount, true)));
    }
    await intent.sign(this.env.chainId, this.env.entrypointAddress, account.signer);

    const solverIntent = new UserIntent(this.env.test.solverUtilsAddress);
    solverIntent.addSegment(
      this.env.standards.call(this.generateSolverSwapTx(this.env.deployerAddress, account.contractAddress, amount)),
    );
    const order = [0, 0, 0, 1, 0];
    const tx = await this.env.entrypoint.handleIntents(buildSolution(timestamp, [intent, solverIntent], order));

    const serialized = Transaction.from(tx).serialized;
    const bytesUsed = serialized.length / 2 - 1;
    const gasUsed = Number((await tx.wait())?.gasUsed || 0n);
    const txFee = ((await tx.wait())?.gasUsed || 0n) * ((await tx.wait())?.gasPrice || 0n);
    return { gasUsed, bytesUsed, txFee, serialized, amount };
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
  private generateLinearRelease(timestamp: number, amount: bigint): Curve {
    const evaluateAt = 1000;
    const startTime = timestamp - evaluateAt;
    const duration = 3000;
    const startAmount = 0n;
    const endAmount = amount * BigInt(duration / evaluateAt);
    return new LinearCurve(startTime, duration, startAmount, endAmount);
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
