import { expect } from 'chai';
import { ethers } from 'hardhat';
import { deployTestEnvironment, Environment, BLSSmartContractAccount } from './utils/environment';
import { buildSolution, UserIntent } from './utils/intent';
import { Curve, LinearCurve } from './utils/curveCoder';
import { BigNumberish } from 'ethers';
import { hashToPoint } from '@thehubbleproject/bls/dist/mcl';

const LOGGING_ENABLED = false;

describe('BLS Transfer ETH Test', () => {
  const MAX_INTENTS = 4;
  let env: Environment;

  before(async () => {
    env = await deployTestEnvironment({ numECDSAAccounts: MAX_INTENTS + 1, numBLSAccounts: MAX_INTENTS + 1 });

    //fund accounts
    await (await env.test.erc20.mint(env.deployerAddress, ethers.parseEther('1000'))).wait();
    // for (const account of env.blsAccounts) {
    //   await (await env.test.erc20.mint(account.contractAddress, ethers.parseEther('1000'))).wait();
    //   await (
    //     await env.deployer.sendTransaction({ to: account.contractAddress, value: ethers.parseEther('10') })
    //   ).wait();
    // }
  });

  // it('#userIntentToMessage', async () => {
  //   const timestamp = (await env.provider.getBlock('latest'))?.timestamp || 0;
  //   const account = env.blsAccounts[0];
  //   const to = ethers.hexlify(ethers.randomBytes(20));
  //   const amount = ethers.parseEther('1');
  //   const gas = ethers.parseEther('0.1');
  //   const previousSolverBalanceErc20 = await env.test.erc20.balanceOf(env.deployerAddress);
  //   const previousFromBalanceErc20 = await env.test.erc20.balanceOf(account.contractAddress);
  //   const previousToBalance = await env.provider.getBalance(to);
  //   const previousFromBalance = await env.provider.getBalance(account.contractAddress);

  //   const intent = new UserIntent(account.contractAddress);
  //   intent.addSegment(env.standards.sequentialNonce(1));
  //   intent.addSegment(env.standards.erc20Release(env.test.erc20Address, generateLinearRelease(timestamp, gas)));
  //   intent.addSegment(env.standards.userOp(generateExecuteTransferTx(account, to, amount), 100_000));

  //   const requestHash = await env.blsAggregator.getUserIntentHash(intent.asUserIntentStruct());
  //   const solPoint: BigNumberish[] = await env.blsAggregator.userIntentToMessage(intent.asUserIntentStruct());
  //   const messagePoint = hashToPoint(requestHash, env.blsDomain);
  //   expect(`1 ${solPoint[0].toString()} ${solPoint[1].toString()}`).to.equal(messagePoint.getStr());
  // });

  it('Should run normal', async () => {
    // intent transfer (0bytes, 51354gas)
    const to = ethers.hexlify(ethers.randomBytes(20));
    const amount = ethers.parseEther('1');
    const previousToBalance = await env.provider.getBalance(to);
    const previousFromBalance = await env.provider.getBalance(env.deployerAddress);

    const tx = env.deployer.sendTransaction({ to, value: amount });
    await expect(tx).to.not.be.reverted;

    if (LOGGING_ENABLED) {
      console.log('dataSize: ' + ((await tx).data.length / 2 - 1));
      console.log('gasUsed: ' + (await (await tx).wait())?.gasUsed);
    }

    const gasUsed = ((await (await tx).wait())?.gasUsed || 0n) * ((await (await tx).wait())?.gasPrice || 0n);
    expect(await env.provider.getBalance(env.deployerAddress)).to.equal(
      previousFromBalance - (amount + gasUsed),
      'Senders balance is incorrect',
    );
    expect(await env.provider.getBalance(to)).to.equal(previousToBalance + amount, 'Recipients balance is incorrect');
  });

  // it('Should run single intent', async () => {
  //   // intent transfer (1252bytes, 194913gas)
  //   const timestamp = (await env.provider.getBlock('latest'))?.timestamp || 0;
  //   const account = env.blsAccounts[0];
  //   const to = ethers.hexlify(ethers.randomBytes(20));
  //   const amount = ethers.parseEther('1');
  //   const gas = ethers.parseEther('0.1');
  //   const previousSolverBalanceErc20 = await env.test.erc20.balanceOf(env.deployerAddress);
  //   const previousFromBalanceErc20 = await env.test.erc20.balanceOf(account.contractAddress);
  //   const previousToBalance = await env.provider.getBalance(to);
  //   const previousFromBalance = await env.provider.getBalance(account.contractAddress);

  //   const intent = new UserIntent(account.contractAddress);
  //   intent.addSegment(env.standards.sequentialNonce(1));
  //   intent.addSegment(env.standards.erc20Release(env.test.erc20Address, generateLinearRelease(timestamp, gas)));
  //   intent.addSegment(env.standards.userOp(generateExecuteTransferTx(account, to, amount), 100_000));
  //   await intent.signBLS(account.signer, env.blsAggregator, env.blsDomain);

  //   const solverIntent = new UserIntent(env.deployerAddress);
  //   const tx = env.entrypoint.handleIntents(buildSolution(timestamp, [intent, solverIntent], []));

  //   console.log('await tx: ' + (await tx));
  //   console.log('await tx value: ' + (await tx).value);
  //   console.log('await tx data: ' + (await tx).data);

  //   await expect(tx).to.not.be.reverted;

  //   if (LOGGING_ENABLED) {
  //     console.log('solution dataSize: ' + ((await tx).data.length / 2 - 1));
  //     console.log('solution gasUsed: ' + (await (await tx).wait())?.gasUsed);
  //   }

  //   expect(await env.test.erc20.balanceOf(env.deployerAddress)).to.equal(
  //     previousSolverBalanceErc20 + gas,
  //     'Solvers token balance is incorrect',
  //   );
  //   expect(await env.test.erc20.balanceOf(account.contractAddress)).to.equal(
  //     previousFromBalanceErc20 - gas,
  //     'Senders token balance is incorrect',
  //   );
  //   expect(await env.provider.getBalance(account.contractAddress)).to.equal(
  //     previousFromBalance - amount,
  //     'Senders balance is incorrect',
  //   );
  //   expect(await env.provider.getBalance(to)).to.equal(previousToBalance + amount, 'Recipients balance is incorrect');
  // });

  // it('Should run multi intent', async () => {
  //   // intent transfer (1065bytes, 167613gas)
  //   const timestamp = (await env.provider.getBlock('latest'))?.timestamp || 0;
  //   const amount = ethers.parseEther('1');
  //   const gas = ethers.parseEther('0.1');
  //   const previousSolverBalanceErc20 = await env.test.erc20.balanceOf(env.deployerAddress);
  //   const toAddresses: string[] = [];
  //   const previousToBalances: bigint[] = [];
  //   const previousFromBalances: bigint[] = [];
  //   const previousFromBalancesErc20: bigint[] = [];
  //   for (let i = 0; i < MAX_INTENTS; i++) {
  //     const account = env.blsAccounts[i + 1];
  //     const to = ethers.hexlify(ethers.randomBytes(20));
  //     toAddresses.push(to);
  //     previousToBalances.push(await env.provider.getBalance(to));
  //     previousFromBalances.push(await env.provider.getBalance(account.contractAddress));
  //     previousFromBalancesErc20.push(await env.test.erc20.balanceOf(account.contractAddress));
  //   }

  //   const intents = [];
  //   for (let i = 0; i < MAX_INTENTS; i++) {
  //     const account = env.blsAccounts[i + 1];
  //     const to = toAddresses[i];
  //     const intent = new UserIntent(account.contractAddress);
  //     intent.addSegment(env.standards.sequentialNonce(1));
  //     intent.addSegment(env.standards.erc20Release(env.test.erc20Address, generateLinearRelease(timestamp, gas)));
  //     intent.addSegment(env.standards.userOp(generateExecuteTransferTx(account, to, amount), 100_000));
  //     await intent.signBLS(account.signer, env.blsAggregator, env.blsDomain);
  //     intents.push(intent);
  //   }
  //   const solverIntent = new UserIntent(env.deployerAddress);
  //   intents.push(solverIntent);

  //   const order = [];
  //   for (let i = 0; i < MAX_INTENTS; i++) {
  //     order.push(i);
  //     order.push(i);
  //     order.push(MAX_INTENTS);
  //     order.push(i);
  //   }

  //   const tx = env.entrypoint.handleIntents(buildSolution(timestamp, intents, order));
  //   await expect(tx).to.not.be.reverted;

  //   if (LOGGING_ENABLED) {
  //     console.log('solution dataSize: ' + ((await tx).data.length / 2 - 1) / MAX_INTENTS + ' (per intent)');
  //     console.log(
  //       'solution gasUsed: ' + ((await (await tx).wait())?.gasUsed || 0n) / BigInt(MAX_INTENTS) + ' (per intent)',
  //     );
  //   }

  //   expect(await env.test.erc20.balanceOf(env.deployerAddress)).to.equal(
  //     previousSolverBalanceErc20 + gas * BigInt(MAX_INTENTS),
  //     'Solvers token balance is incorrect',
  //   );
  //   for (let i = 0; i < MAX_INTENTS; i++) {
  //     const account = env.blsAccounts[i + 1];
  //     expect(await env.test.erc20.balanceOf(account.contractAddress)).to.equal(
  //       previousFromBalancesErc20[i] - gas,
  //       'Senders token balance is incorrect',
  //     );
  //     expect(await env.provider.getBalance(account.contractAddress)).to.equal(
  //       previousFromBalances[i] - amount,
  //       'Senders balance is incorrect',
  //     );
  //     expect(await env.provider.getBalance(toAddresses[i])).to.equal(
  //       previousToBalances[i] + amount,
  //       'Recipients balance is incorrect',
  //     );
  //   }
  // });

  // helper function to generate transfer tx calldata
  function generateExecuteTransferTx(account: BLSSmartContractAccount, to: string, amount: bigint): string {
    return account.contract.interface.encodeFunctionData('execute', [to, amount, '0x']);
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
