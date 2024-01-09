import { expect } from 'chai';
import { deployTestEnvironment, Environment } from '../../scripts/scenarios/environment';
import { TokenSwapScenario } from '../../scripts/scenarios/tokenSwapScenario';
import { ScenarioOptions } from '../../scripts/scenarios/scenario';

describe('Token Swaps Test', () => {
  const MAX_INTENTS = 4;
  let env: Environment;
  let scenario: TokenSwapScenario;
  const scenarioOptions: ScenarioOptions = {
    useEmbeddedStandards: true,
    useCompression: false,
    useStatefulCompression: false,
    useAccountAsEOAProxy: false,
    useBLSSignatureAggregation: true,
  };

  before(async () => {
    env = await deployTestEnvironment({ numAccounts: MAX_INTENTS });
    scenario = new TokenSwapScenario(env);
    scenario.init();
  });

  it('Should run normal', async () => {
    const previousFromBalance = await env.test.erc20.balanceOf(env.deployerAddress);
    const previousToBalance = await env.provider.getBalance(env.deployerAddress);

    //swap
    const swapResults = await scenario.runBaseline();
    await expect(swapResults.tx).to.not.be.reverted;

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
    const solverAddress = env.deployerAddress;
    let accountAddress: string = env.simpleAccounts[0].contractAddress;
    if (scenarioOptions.useAccountAsEOAProxy) accountAddress = env.eoaProxyAccounts[0].signerAddress;
    else if (scenarioOptions.useBLSSignatureAggregation) accountAddress = env.blsAccounts[0].contractAddress;

    const previousFromBalance = await env.test.erc20.balanceOf(accountAddress);
    const previousToBalance = await env.provider.getBalance(accountAddress);
    const previousSolverBalance = await env.provider.getBalance(solverAddress);

    //swap
    const swapResults = await scenario.run(1, scenarioOptions);
    await expect(swapResults.tx).to.not.be.reverted;

    expect(await env.provider.getBalance(solverAddress)).to.equal(
      previousSolverBalance + scenario.TOKEN_SWAP_SLIPPAGE - swapResults.txFee,
      'Solvers balance is incorrect',
    );
    expect(await env.test.erc20.balanceOf(accountAddress)).to.equal(
      previousFromBalance - swapResults.amount,
      'Senders token balance is incorrect',
    );
    expect(await env.provider.getBalance(accountAddress)).to.equal(
      previousToBalance + swapResults.amount,
      'Senders balance is incorrect',
    );
  });

  it('Should run multi intent', async () => {
    const solverAddress = env.deployerAddress;
    const accountAddresses: string[] = [];
    const previousFromBalances: bigint[] = [];
    const previousToBalances: bigint[] = [];
    const previousSolverBalance = await env.provider.getBalance(solverAddress);
    for (let i = 0; i < MAX_INTENTS; i++) {
      let accountAddress: string = env.simpleAccounts[i].contractAddress;
      if (scenarioOptions.useAccountAsEOAProxy) accountAddress = env.eoaProxyAccounts[i].signerAddress;
      else if (scenarioOptions.useBLSSignatureAggregation) accountAddress = env.blsAccounts[i].contractAddress;

      accountAddresses.push(accountAddress);
      previousFromBalances.push(await env.test.erc20.balanceOf(accountAddress));
      previousToBalances.push(await env.provider.getBalance(accountAddress));
    }

    //swap
    const swapResults = await scenario.run(MAX_INTENTS, scenarioOptions);
    await expect(swapResults.tx).to.not.be.reverted;

    expect(await env.provider.getBalance(solverAddress)).to.equal(
      previousSolverBalance + scenario.TOKEN_SWAP_SLIPPAGE - swapResults.txFee,
      'Solvers balance is incorrect',
    );
    for (let i = 0; i < MAX_INTENTS; i++) {
      const accountAddress = accountAddresses[i];
      expect(await env.test.erc20.balanceOf(accountAddress)).to.equal(
        previousFromBalances[i] - swapResults.amount,
        'Senders token balance is incorrect',
      );
      expect(await env.provider.getBalance(accountAddress)).to.equal(
        previousToBalances[i] + swapResults.amount,
        'Senders balance is incorrect',
      );
    }
  });
});
