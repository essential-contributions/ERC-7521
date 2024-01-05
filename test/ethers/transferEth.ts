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
  };

  before(async () => {
    env = await deployTestEnvironment({ numAccounts: MAX_INTENTS });
    scenario = new TransferEthScenario(env);
    scenario.init();
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
    const account = env.abstractAccounts[0];
    const to = env.utils.randomAddresses(1)[0];
    const previousSolverBalanceErc20 = await env.test.erc20.balanceOf(env.deployerAddress);
    const previousFromBalanceErc20 = await env.test.erc20.balanceOf(account.contractAddress);
    const previousToBalance = await env.provider.getBalance(to);
    const previousFromBalance = await env.provider.getBalance(account.contractAddress);

    //transfer
    const transferResults = await scenario.run([to], scenarioOptions);
    await expect(transferResults.tx).to.not.be.reverted;

    expect(await env.test.erc20.balanceOf(env.deployerAddress)).to.equal(
      previousSolverBalanceErc20 + transferResults.fee,
      'Solvers token balance is incorrect',
    );
    expect(await env.test.erc20.balanceOf(account.contractAddress)).to.equal(
      previousFromBalanceErc20 - transferResults.fee,
      'Senders token balance is incorrect',
    );
    expect(await env.provider.getBalance(account.contractAddress)).to.equal(
      previousFromBalance - transferResults.amount,
      'Senders balance is incorrect',
    );
    expect(await env.provider.getBalance(to)).to.equal(
      previousToBalance + transferResults.amount,
      'Recipients balance is incorrect',
    );
  });

  it('Should run multi intent', async () => {
    const to: string[] = env.utils.randomAddresses(MAX_INTENTS);
    const previousToBalances: bigint[] = [];
    const previousFromBalances: bigint[] = [];
    const previousFromBalancesErc20: bigint[] = [];
    const previousSolverBalanceErc20 = await env.test.erc20.balanceOf(env.deployerAddress);
    for (let i = 0; i < MAX_INTENTS; i++) {
      const account = env.abstractAccounts[i];
      previousToBalances.push(await env.provider.getBalance(to[i]));
      previousFromBalances.push(await env.provider.getBalance(account.contractAddress));
      previousFromBalancesErc20.push(await env.test.erc20.balanceOf(account.contractAddress));
    }

    //transfer
    const transferResults = await scenario.run(to, scenarioOptions);
    await expect(transferResults.tx).to.not.be.reverted;

    expect(await env.test.erc20.balanceOf(env.deployerAddress)).to.equal(
      previousSolverBalanceErc20 + transferResults.fee * BigInt(MAX_INTENTS),
      'Solvers token balance is incorrect',
    );
    for (let i = 0; i < MAX_INTENTS; i++) {
      const account = env.abstractAccounts[i];
      expect(await env.test.erc20.balanceOf(account.contractAddress)).to.equal(
        previousFromBalancesErc20[i] - transferResults.fee,
        'Senders token balance is incorrect',
      );
      expect(await env.provider.getBalance(account.contractAddress)).to.equal(
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
