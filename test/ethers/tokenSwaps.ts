import { expect } from 'chai';
import { ethers } from 'hardhat';
import { deployTestEnvironment, Environment } from './utils/environment';
import { buildSolution, UserIntent } from './utils/intent';
import { ConstantCurve, Curve, LinearCurve } from './utils/curveCoder';
import { ExactInputSingleParamsStruct } from '../../typechain/src/test/TestUniswap';

const LOGGING_ENABLED = false;

describe('Token Swaps Test', () => {
  const MAX_INTENTS = 4;
  const TOKEN_SWAP_SLIPPAGE = 5n;
  let env: Environment;

  before(async () => {
    env = await deployTestEnvironment({ numAbstractAccounts: MAX_INTENTS + 1 });

    //fund accounts
    await (await env.test.erc20.mint(env.deployerAddress, ethers.parseEther('1000'))).wait();
    for (const account of env.abstractAccounts) {
      await (await env.test.erc20.mint(account.contractAddress, ethers.parseEther('1000'))).wait();
      await (
        await env.deployer.sendTransaction({ to: account.contractAddress, value: ethers.parseEther('10') })
      ).wait();
    }

    //approve deployer swapping erc20
    await (await env.test.erc20.approve(env.test.uniswapAddress, ethers.parseEther('1000'))).wait();
  });

  it('Should run normal', async () => {
    // intent transfer (260bytes, 117437gas)
    const amount = ethers.parseEther('1');
    const previousFromBalance = await env.test.erc20.balanceOf(env.deployerAddress);
    const previousToBalance = await env.provider.getBalance(env.deployerAddress);

    const swapParams = getSwapParams(
      env.test.erc20Address,
      env.test.wrappedNativeTokenAddress,
      amount,
      env.deployerAddress
    );
    const tx = env.test.uniswap.exactInputSingle(swapParams);
    await expect(tx).to.not.be.reverted;
    const unwrap = env.test.wrappedNativeToken.withdraw(
      await env.test.wrappedNativeToken.balanceOf(env.deployerAddress)
    );
    await expect(unwrap).to.not.be.reverted;

    if (LOGGING_ENABLED) {
      console.log('dataSize: ' + ((await tx).data.length / 2 - 1));
      console.log(
        'gasUsed: ' +
          (((await (await tx).wait())?.gasUsed || 0n) + ((await (await unwrap).wait())?.gasUsed || 0n)) +
          ' (including unwrap)'
      );
    }

    const gasUsed =
      ((await (await tx).wait())?.gasUsed || 0n) * ((await (await tx).wait())?.gasPrice || 0n) +
      ((await (await unwrap).wait())?.gasUsed || 0n) * ((await (await unwrap).wait())?.gasPrice || 0n);
    expect(await env.test.erc20.balanceOf(env.deployerAddress)).to.equal(
      previousFromBalance - amount,
      'From balance is incorrect'
    );
    expect(await env.provider.getBalance(env.deployerAddress)).to.equal(
      previousToBalance + amount + TOKEN_SWAP_SLIPPAGE - gasUsed,
      'To balance is incorrect'
    );
  });

  it('Should run single intent', async () => {
    // intent transfer (1732bytes, 269814gas)
    const timestamp = (await env.provider.getBlock('latest'))?.timestamp || 0;
    const account = env.abstractAccounts[0];
    const amount = ethers.parseEther('1');
    const previousFromBalance = await env.test.erc20.balanceOf(account.contractAddress);
    const previousToBalance = await env.provider.getBalance(account.contractAddress);
    const previousSolverBalance = await env.provider.getBalance(env.deployerAddress);

    const intent = new UserIntent(account.contractAddress);
    intent.addSegment(env.standards.sequentialNonce(1));
    intent.addSegment(env.standards.ethRecord());
    intent.addSegment(env.standards.erc20Release(env.test.erc20Address, generateLinearRelease(timestamp, amount)));
    intent.addSegment(env.standards.ethRequire(new ConstantCurve(amount, true)));
    await intent.sign(env.chainId, env.entrypointAddress, account.signer);

    const solverIntent = new UserIntent(env.test.solverUtilsAddress);
    solverIntent.addSegment(
      env.standards.call(generateSolverSwapTx(env, env.deployerAddress, account.contractAddress, amount))
    );
    const order = [0, 0, 0, 1, 0];

    const tx = env.entrypoint.handleIntents(buildSolution(timestamp, [intent, solverIntent], order));
    await expect(tx).to.not.be.reverted;

    if (LOGGING_ENABLED) {
      console.log('solution dataSize: ' + ((await tx).data.length / 2 - 1));
      console.log('solution gasUsed: ' + (await (await tx).wait())?.gasUsed);
    }

    const gasUsed = ((await (await tx).wait())?.gasUsed || 0n) * ((await (await tx).wait())?.gasPrice || 0n);
    expect(await env.test.erc20.balanceOf(account.contractAddress)).to.equal(
      previousFromBalance - amount,
      'Senders token balance is incorrect'
    );
    expect(await env.provider.getBalance(env.deployerAddress)).to.equal(
      previousSolverBalance + TOKEN_SWAP_SLIPPAGE - gasUsed,
      'Solvers balance is incorrect'
    );
    expect(await env.provider.getBalance(account.contractAddress)).to.equal(
      previousToBalance + amount,
      'Senders balance is incorrect'
    );
  });

  it('Should run multi intent', async () => {
    // intent transfer (1297bytes, 201973gas)
    const timestamp = (await env.provider.getBlock('latest'))?.timestamp || 0;
    const account = env.abstractAccounts[0];
    const amount = ethers.parseEther('1');
    const previousFromBalances: bigint[] = [];
    const previousToBalances: bigint[] = [];
    const previousSolverBalance = await env.provider.getBalance(env.deployerAddress);
    for (let i = 0; i < MAX_INTENTS; i++) {
      const account = env.abstractAccounts[i + 1];
      previousFromBalances.push(await env.test.erc20.balanceOf(account.contractAddress));
      previousToBalances.push(await env.provider.getBalance(account.contractAddress));
    }

    const intents: UserIntent[] = [];
    const tos: string[] = [];
    const amounts: bigint[] = [];
    for (let i = 0; i < MAX_INTENTS; i++) {
      const account = env.abstractAccounts[i + 1];
      const intent = new UserIntent(account.contractAddress);
      intent.addSegment(env.standards.sequentialNonce(1));
      intent.addSegment(env.standards.ethRecord());
      intent.addSegment(env.standards.erc20Release(env.test.erc20Address, generateLinearRelease(timestamp, amount)));
      intent.addSegment(env.standards.ethRequire(new ConstantCurve(amount, true)));
      await intent.sign(env.chainId, env.entrypointAddress, account.signer);
      intents.push(intent);
      tos.push(account.contractAddress);
      amounts.push(amount);
    }

    const solverIntent1 = new UserIntent(env.test.solverUtilsAddress);
    const solverIntent2 = new UserIntent(env.test.solverUtilsAddress);
    solverIntent2.addSegment(env.standards.call(generateSolverSwapMultiTx(env, env.deployerAddress, tos, amounts)));
    intents.push(solverIntent1);
    intents.push(solverIntent2);

    const order = [];
    for (let i = 0; i < MAX_INTENTS; i++) {
      order.push(i);
      order.push(i);
      order.push(i);
      order.push(MAX_INTENTS);
    }
    order.push(MAX_INTENTS + 1);
    for (let i = 0; i < MAX_INTENTS; i++) {
      order.push(i);
    }

    const tx = env.entrypoint.handleIntents(buildSolution(timestamp, intents, order));
    await expect(tx).to.not.be.reverted;

    if (LOGGING_ENABLED) {
      console.log('solution dataSize: ' + ((await tx).data.length / 2 - 1) / MAX_INTENTS + ' (per intent)');
      console.log(
        'solution gasUsed: ' + ((await (await tx).wait())?.gasUsed || 0n) / BigInt(MAX_INTENTS) + ' (per intent)'
      );
    }

    const gasUsed = ((await (await tx).wait())?.gasUsed || 0n) * ((await (await tx).wait())?.gasPrice || 0n);
    expect(await env.provider.getBalance(env.deployerAddress)).to.equal(
      previousSolverBalance + TOKEN_SWAP_SLIPPAGE - gasUsed,
      'Solvers balance is incorrect'
    );
    for (let i = 0; i < MAX_INTENTS; i++) {
      const account = env.abstractAccounts[i + 1];
      expect(await env.test.erc20.balanceOf(account.contractAddress)).to.equal(
        previousFromBalances[i] - amount,
        'Senders token balance is incorrect'
      );
      expect(await env.provider.getBalance(account.contractAddress)).to.equal(
        previousToBalances[i] + amount,
        'Senders balance is incorrect'
      );
    }
  });

  // helper function to generate transfer tx calldata
  function generateSolverSwapTx(env: Environment, solver: string, to: string, amount: bigint): string {
    return env.test.solverUtils.interface.encodeFunctionData('swapERC20ForETHAndForward', [
      env.test.uniswapAddress,
      env.test.erc20Address,
      env.test.wrappedNativeTokenAddress,
      amount,
      solver,
      amount,
      to,
    ]);
  }

  // helper function to generate transfer tx calldata
  function generateSolverSwapMultiTx(env: Environment, solver: string, tos: string[], amounts: bigint[]): string {
    let minSwap = 0n;
    for (const amount of amounts) minSwap += amount;
    return env.test.solverUtils.interface.encodeFunctionData('swapERC20ForETHAndForwardMulti', [
      env.test.uniswapAddress,
      env.test.erc20Address,
      env.test.wrappedNativeTokenAddress,
      minSwap,
      solver,
      amounts,
      tos,
    ]);
  }

  // helper function to generate a linear release curve
  function generateLinearRelease(timestamp: number, amount: bigint): Curve {
    const evaluateAt = 1000;
    const startTime = timestamp - evaluateAt;
    const duration = 3000;
    const startAmount = 0n;
    const endAmount = amount * BigInt(duration / evaluateAt);
    return new LinearCurve(startTime, duration, startAmount, endAmount);
  }

  // helper function to get token swap params
  function getSwapParams(
    tokenIn: string,
    tokenOut: string,
    amount: bigint,
    recipient: string
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
});
