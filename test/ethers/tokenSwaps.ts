import { expect } from 'chai';
import { deployTestEnvironment, Environment } from '../../scripts/scenarios/environment';
import { TokenSwapScenario } from '../../scripts/scenarios/tokenSwapScenario';

describe('Token Swaps Test', () => {
  const MAX_INTENTS = 4;
  let env: Environment;
  let scenario: TokenSwapScenario;

  before(async () => {
    env = await deployTestEnvironment({ numAbstractAccounts: MAX_INTENTS });
    scenario = new TokenSwapScenario(env);
    scenario.init();
  });

  it('Should run normal', async () => {
    const previousFromBalance = await env.test.erc20.balanceOf(env.deployerAddress);
    const previousToBalance = await env.provider.getBalance(env.deployerAddress);

    //swap
    const swapResults = await scenario.runBaseline();

    expect(await env.test.erc20.balanceOf(env.deployerAddress)).to.equal(
      previousFromBalance - swapResults.amount,
      'From balance is incorrect',
    );
    expect(await env.provider.getBalance(env.deployerAddress)).to.equal(
      previousToBalance + swapResults.amount + scenario.TOKEN_SWAP_SLIPPAGE - swapResults.txFee,
      'To balance is incorrect',
    );
  });

  it('Should run single intent', async () => {
    const account = env.abstractAccounts[0];
    const previousFromBalance = await env.test.erc20.balanceOf(account.contractAddress);
    const previousToBalance = await env.provider.getBalance(account.contractAddress);
    const previousSolverBalance = await env.provider.getBalance(env.deployerAddress);

    //swap
    const swapResults = await scenario.run(1);

    expect(await env.test.erc20.balanceOf(account.contractAddress)).to.equal(
      previousFromBalance - swapResults.amount,
      'Senders token balance is incorrect',
    );
    expect(await env.provider.getBalance(env.deployerAddress)).to.equal(
      previousSolverBalance + scenario.TOKEN_SWAP_SLIPPAGE - swapResults.txFee,
      'Solvers balance is incorrect',
    );
    expect(await env.provider.getBalance(account.contractAddress)).to.equal(
      previousToBalance + swapResults.amount,
      'Senders balance is incorrect',
    );
  });

  it('Should run multi intent', async () => {
    const previousFromBalances: bigint[] = [];
    const previousToBalances: bigint[] = [];
    const previousSolverBalance = await env.provider.getBalance(env.deployerAddress);
    for (let i = 0; i < MAX_INTENTS; i++) {
      const account = env.abstractAccounts[i];
      previousFromBalances.push(await env.test.erc20.balanceOf(account.contractAddress));
      previousToBalances.push(await env.provider.getBalance(account.contractAddress));
    }

    //swap
    const swapResults = await scenario.run(MAX_INTENTS);

    expect(await env.provider.getBalance(env.deployerAddress)).to.equal(
      previousSolverBalance + scenario.TOKEN_SWAP_SLIPPAGE - swapResults.txFee,
      'Solvers balance is incorrect',
    );
    for (let i = 0; i < MAX_INTENTS; i++) {
      const account = env.abstractAccounts[i];
      expect(await env.test.erc20.balanceOf(account.contractAddress)).to.equal(
        previousFromBalances[i] - swapResults.amount,
        'Senders token balance is incorrect',
      );
      expect(await env.provider.getBalance(account.contractAddress)).to.equal(
        previousToBalances[i] + swapResults.amount,
        'Senders balance is incorrect',
      );
    }
  });
});
