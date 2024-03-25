import { expect } from 'chai';
import { deployTestEnvironment, Environment } from '../../scripts/scenarios/environment';
import { TransferEthScenario } from '../../scripts/scenarios/transferEthScenario';
import { ScenarioOptions } from '../../scripts/scenarios/scenario';

describe('Transient Data Test', () => {
  const MAX_INTENTS = 4;
  const USE_TRANSIENT_DATA = true;
  let env: Environment;
  let scenario: TransferEthScenario;

  before(async () => {
    env = await deployTestEnvironment({ numAccounts: MAX_INTENTS, useTransientData: USE_TRANSIENT_DATA });
    scenario = new TransferEthScenario(env);
    await scenario.init();
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
    const scenarioOptions: ScenarioOptions = {
      useEmbeddedStandards: true,
      useCompression: false,
      useCompressionRegistry: false,
      useAccountAsEOAProxy: false,
      useBLSSignatureAggregation: false,
    };
    await runSingleTest(scenarioOptions);
  });

  // Basic test structure
  async function runSingleTest(scenarioOptions: ScenarioOptions) {
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
  }
});
