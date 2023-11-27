import { expect } from 'chai';
import { ethers } from 'hardhat';
import { deployTestEnvironment, Environment, SmartContractAccount } from './utils/environment';
import { buildSolution, UserIntent } from './utils/intent';
import { Curve, LinearCurve } from './utils/curveCoder';

const LOGGING_ENABLED = false;

describe('Transfer ERC-20 Test', () => {
  const MAX_INTENTS = 4;
  let env: Environment;

  before(async () => {
    env = await deployTestEnvironment({ numAbstractAccounts: MAX_INTENTS });

    //fund accounts
    await (await env.test.erc20.mint(env.deployerAddress, ethers.parseEther('1000'))).wait();
    for (const account of env.abstractAccounts) {
      await (await env.test.erc20.mint(account.contractAddress, ethers.parseEther('1000'))).wait();
    }
  });

  it('Should run normal', async () => {
    // intent transfer (68bytes, 51354gas)
    const to = ethers.hexlify(ethers.randomBytes(20));
    const amount = ethers.parseEther('10');
    const previousToBalance = await env.test.erc20.balanceOf(to);
    const previousFromBalance = await env.test.erc20.balanceOf(env.deployerAddress);

    const tx = env.test.erc20.transfer(to, amount);
    await expect(tx).to.not.be.reverted;

    if (LOGGING_ENABLED) {
      console.log('dataSize: ' + ((await tx).data.length / 2 - 1));
      console.log('gasUsed: ' + (await (await tx).wait())?.gasUsed);
    }

    expect(await env.test.erc20.balanceOf(env.deployerAddress)).to.equal(
      previousFromBalance - amount,
      'Senders balance is incorrect',
    );
    expect(await env.test.erc20.balanceOf(to)).to.equal(previousToBalance + amount, 'Recipients balance is incorrect');
  });

  it('Should run single intent', async () => {
    // intent transfer (1380bytes, 187763gas)
    const timestamp = (await env.provider.getBlock('latest'))?.timestamp || 0;
    const account = env.abstractAccounts[0];
    const to = ethers.hexlify(ethers.randomBytes(20));
    const amount = ethers.parseEther('10');
    const gas = ethers.parseEther('1');
    const previousSolverBalance = await env.test.erc20.balanceOf(env.deployerAddress);
    const previousToBalance = await env.test.erc20.balanceOf(to);
    const previousFromBalance = await env.test.erc20.balanceOf(account.contractAddress);

    const intent = new UserIntent(account.contractAddress);
    intent.addSegment(env.standards.sequentialNonce(1));
    intent.addSegment(env.standards.erc20Release(env.test.erc20Address, generateLinearRelease(timestamp, gas)));
    intent.addSegment(env.standards.userOp(generateExecuteTransferTx(account, to, amount), 100_000n));
    await intent.sign(env.chainId, env.entrypointAddress, account.signer);

    const solverIntent = new UserIntent(env.deployerAddress);
    const tx = env.entrypoint.handleIntents(buildSolution(timestamp, [intent, solverIntent], []));
    await expect(tx).to.not.be.reverted;

    if (LOGGING_ENABLED) {
      console.log('solution dataSize: ' + ((await tx).data.length / 2 - 1));
      console.log('solution gasUsed: ' + (await (await tx).wait())?.gasUsed);
    }

    expect(await env.test.erc20.balanceOf(account.contractAddress)).to.equal(
      previousFromBalance - (amount + gas),
      'Senders balance is incorrect',
    );
    expect(await env.test.erc20.balanceOf(env.deployerAddress)).to.equal(
      previousSolverBalance + gas,
      'Solvers balance is incorrect',
    );
    expect(await env.test.erc20.balanceOf(to)).to.equal(previousToBalance + amount, 'Recipients balance is incorrect');
  });

  it('Should run multi intent', async () => {
    // intent transfer (1028bytes, 146356gas)
    const timestamp = (await env.provider.getBlock('latest'))?.timestamp || 0;
    const amount = ethers.parseEther('10');
    const gas = ethers.parseEther('1');
    const previousSolverBalance = await env.test.erc20.balanceOf(env.deployerAddress);
    const toAddresses: string[] = [];
    const previousToBalances: bigint[] = [];
    const previousFromBalances: bigint[] = [];
    for (let i = 0; i < MAX_INTENTS; i++) {
      const account = env.abstractAccounts[i];
      const to = ethers.hexlify(ethers.randomBytes(20));
      toAddresses.push(to);
      previousToBalances.push(await env.test.erc20.balanceOf(to));
      previousFromBalances.push(await env.test.erc20.balanceOf(account.contractAddress));
    }

    const intents = [];
    for (let i = 0; i < MAX_INTENTS; i++) {
      const account = env.abstractAccounts[i];
      const to = toAddresses[i];
      const intent = new UserIntent(account.contractAddress);
      intent.addSegment(env.standards.sequentialNonce(i == 0 ? 2 : 1));
      intent.addSegment(env.standards.erc20Release(env.test.erc20Address, generateLinearRelease(timestamp, gas)));
      intent.addSegment(env.standards.userOp(generateExecuteTransferTx(account, to, amount), 100_000n));
      await intent.sign(env.chainId, env.entrypointAddress, account.signer);
      intents.push(intent);
    }
    const solverIntent = new UserIntent(env.deployerAddress);
    intents.push(solverIntent);

    const order = [];
    for (let i = 0; i < MAX_INTENTS; i++) {
      order.push(i);
      order.push(i);
      order.push(MAX_INTENTS);
      order.push(i);
    }

    const tx = env.entrypoint.handleIntents(buildSolution(timestamp, intents, order));
    await expect(tx).to.not.be.reverted;

    if (LOGGING_ENABLED) {
      console.log('solution dataSize: ' + ((await tx).data.length / 2 - 1) / MAX_INTENTS + ' (per intent)');
      console.log(
        'solution gasUsed: ' + ((await (await tx).wait())?.gasUsed || 0n) / BigInt(MAX_INTENTS) + ' (per intent)',
      );
    }

    expect(await env.test.erc20.balanceOf(env.deployerAddress)).to.equal(
      previousSolverBalance + gas * BigInt(MAX_INTENTS),
      'Solvers balance is incorrect',
    );
    for (let i = 0; i < MAX_INTENTS; i++) {
      const account = env.abstractAccounts[i];
      expect(await env.test.erc20.balanceOf(account.contractAddress)).to.equal(
        previousFromBalances[i] - (amount + gas),
        'Senders balance is incorrect',
      );
      expect(await env.test.erc20.balanceOf(toAddresses[i])).to.equal(
        previousToBalances[i] + amount,
        'Recipients balance is incorrect',
      );
    }
  });

  // helper function to generate transfer tx calldata
  function generateExecuteTransferTx(account: SmartContractAccount, to: string, amount: bigint): string {
    return account.contract.interface.encodeFunctionData('execute', [
      env.test.erc20Address,
      0,
      env.test.erc20.interface.encodeFunctionData('transfer', [to, amount]),
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
});
