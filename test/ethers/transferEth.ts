import { expect } from 'chai';
import { deployTestEnvironment, Environment } from '../../scripts/scenarios/environment';
import { TransferEthScenario } from '../../scripts/scenarios/transferEthScenario';
import { ScenarioOptions } from '../../scripts/scenarios/scenario';

describe('Transfer ETH Test', () => {
  const MAX_INTENTS = 4;
  let env: Environment;
  let scenario: TransferEthScenario;
  const scenarioOptions: ScenarioOptions = {
    useEmbeddedStandards: true,
    useCompression: false,
    useStatefulCompression: false,
    useAccountAsEOAProxy: false,
    useBLSSignatureAggregation: true,
  };

  before(async () => {
    env = await deployTestEnvironment({ numAccounts: MAX_INTENTS });
    scenario = new TransferEthScenario(env);
    scenario.init();
    expect(scenarioOptions.useAccountAsEOAProxy).to.equal(false, 'Cannot test with "useAccountAsEOAProxy" option');
  });

  it('Should run normal', async () => {
    const to = env.utils.randomAddresses(1)[0];
    const previousToBalance = await env.provider.getBalance(to);
    const previousFromBalance = await env.provider.getBalance(env.deployerAddress);

    //transfer
    const transferResults = await scenario.runBaseline(to);
    await expect(transferResults.tx).to.not.be.reverted;

    expect(await env.provider.getBalance(env.deployerAddress)).to.equal(
      previousFromBalance - (transferResults.amount + transferResults.txFee),
      'Senders balance is incorrect',
    );
    expect(await env.provider.getBalance(to)).to.equal(
      previousToBalance + transferResults.amount,
      'Recipients balance is incorrect',
    );
  });

  it('Should run single intent', async () => {
    let accountAddress: string = env.simpleAccounts[0].contractAddress;
    if (scenarioOptions.useBLSSignatureAggregation) accountAddress = env.blsAccounts[0].contractAddress;
    const to = env.utils.randomAddresses(1)[0];
    const previousSolverBalanceErc20 = await env.test.erc20.balanceOf(env.deployerAddress);
    const previousFromBalanceErc20 = await env.test.erc20.balanceOf(accountAddress);
    const previousToBalance = await env.provider.getBalance(to);
    const previousFromBalance = await env.provider.getBalance(accountAddress);

    //transfer
    const transferResults = await scenario.run([to], scenarioOptions);
    await expect(transferResults.tx).to.not.be.reverted;

    expect(await env.test.erc20.balanceOf(env.deployerAddress)).to.equal(
      previousSolverBalanceErc20 + transferResults.fee,
      'Solvers token balance is incorrect',
    );
    expect(await env.test.erc20.balanceOf(accountAddress)).to.equal(
      previousFromBalanceErc20 - transferResults.fee,
      'Senders token balance is incorrect',
    );
    expect(await env.provider.getBalance(accountAddress)).to.equal(
      previousFromBalance - transferResults.amount,
      'Senders balance is incorrect',
    );
    expect(await env.provider.getBalance(to)).to.equal(
      previousToBalance + transferResults.amount,
      'Recipients balance is incorrect',
    );
  });

  it('Should run multi intent', async () => {
    const solverAddress = env.deployerAddress;
    const to: string[] = env.utils.randomAddresses(MAX_INTENTS);
    const accountAddresses: string[] = [];
    const previousToBalances: bigint[] = [];
    const previousFromBalances: bigint[] = [];
    const previousFromBalancesErc20: bigint[] = [];
    const previousSolverBalanceErc20 = await env.test.erc20.balanceOf(solverAddress);
    for (let i = 0; i < MAX_INTENTS; i++) {
      let accountAddress: string = env.simpleAccounts[i].contractAddress;
      if (scenarioOptions.useBLSSignatureAggregation) accountAddress = env.blsAccounts[i].contractAddress;
      accountAddresses.push(accountAddress);
      previousToBalances.push(await env.provider.getBalance(to[i]));
      previousFromBalances.push(await env.provider.getBalance(accountAddress));
      previousFromBalancesErc20.push(await env.test.erc20.balanceOf(accountAddress));
    }

    //transfer
    const transferResults = await scenario.run(to, scenarioOptions);
    await expect(transferResults.tx).to.not.be.reverted;

    expect(await env.test.erc20.balanceOf(solverAddress)).to.equal(
      previousSolverBalanceErc20 + transferResults.fee * BigInt(MAX_INTENTS),
      'Solvers token balance is incorrect',
    );
    for (let i = 0; i < MAX_INTENTS; i++) {
      const accountAddress = accountAddresses[i];
      expect(await env.test.erc20.balanceOf(accountAddress)).to.equal(
        previousFromBalancesErc20[i] - transferResults.fee,
        'Senders token balance is incorrect',
      );
      expect(await env.provider.getBalance(accountAddress)).to.equal(
        previousFromBalances[i] - transferResults.amount,
        'Senders balance is incorrect',
      );
      expect(await env.provider.getBalance(to[i])).to.equal(
        previousToBalances[i] + transferResults.amount,
        'Recipients balance is incorrect',
      );
    }
  });
});
