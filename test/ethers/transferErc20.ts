import { expect } from 'chai';
import { deployTestEnvironment, Environment } from '../../scripts/scenarios/environment';
import { TransferErc20Scenario } from '../../scripts/scenarios/transferErc20Scenario';
import { ScenarioOptions } from '../../scripts/scenarios/scenario';

describe('Transfer ERC-20 Test', () => {
  const MAX_INTENTS = 4;
  let env: Environment;
  let scenario: TransferErc20Scenario;
  const scenarioOptions: ScenarioOptions = {
    useEmbeddedStandards: true,
    useCompression: false,
    useStatefulCompression: false,
    useAccountAsEOAProxy: false,
    useBLSSignatureAggregation: false,
  };

  before(async () => {
    env = await deployTestEnvironment({ numAccounts: MAX_INTENTS });
    scenario = new TransferErc20Scenario(env);
    scenario.init();
  });

  it('Should run normal', async () => {
    const to = env.utils.randomAddresses(1)[0];
    const previousToBalance = await env.test.erc20.balanceOf(to);
    const previousFromBalance = await env.test.erc20.balanceOf(env.deployerAddress);

    //transfer
    const transferResults = await scenario.runBaseline(to);
    await expect(transferResults.tx).to.not.be.reverted;

    expect(await env.test.erc20.balanceOf(env.deployerAddress)).to.equal(
      previousFromBalance - transferResults.amount,
      'Senders balance is incorrect',
    );
    expect(await env.test.erc20.balanceOf(to)).to.equal(
      previousToBalance + transferResults.amount,
      'Recipients balance is incorrect',
    );
  });

  it('Should run single intent', async () => {
    const solverAddress = env.deployerAddress;
    let accountAddress: string = env.simpleAccounts[0].contractAddress;
    if (scenarioOptions.useAccountAsEOAProxy) accountAddress = env.eoaProxyAccounts[0].signerAddress;
    else if (scenarioOptions.useBLSSignatureAggregation) accountAddress = env.blsAccounts[0].contractAddress;

    const to = env.utils.randomAddresses(1)[0];
    const previousSolverBalance = await env.test.erc20.balanceOf(solverAddress);
    const previousToBalance = await env.test.erc20.balanceOf(to);
    const previousFromBalance = await env.test.erc20.balanceOf(accountAddress);

    //transfer
    const transferResults = await scenario.run([to], scenarioOptions);
    await expect(transferResults.tx).to.not.be.reverted;

    expect(await env.test.erc20.balanceOf(solverAddress)).to.equal(
      previousSolverBalance + transferResults.fee,
      'Solvers balance is incorrect',
    );
    expect(await env.test.erc20.balanceOf(accountAddress)).to.equal(
      previousFromBalance - (transferResults.amount + transferResults.fee),
      'Senders balance is incorrect',
    );
    expect(await env.test.erc20.balanceOf(to)).to.equal(
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
    const previousSolverBalance = await env.test.erc20.balanceOf(solverAddress);
    for (let i = 0; i < MAX_INTENTS; i++) {
      let accountAddress: string = env.simpleAccounts[i].contractAddress;
      if (scenarioOptions.useAccountAsEOAProxy) accountAddress = env.eoaProxyAccounts[i].signerAddress;
      else if (scenarioOptions.useBLSSignatureAggregation) accountAddress = env.blsAccounts[i].contractAddress;

      accountAddresses.push(accountAddress);
      previousToBalances.push(await env.test.erc20.balanceOf(to[i]));
      previousFromBalances.push(await env.test.erc20.balanceOf(accountAddress));
    }

    //transfer
    const transferResults = await scenario.run(to, scenarioOptions);
    await expect(transferResults.tx).to.not.be.reverted;

    expect(await env.test.erc20.balanceOf(solverAddress)).to.equal(
      previousSolverBalance + transferResults.fee * BigInt(MAX_INTENTS),
      'Solvers balance is incorrect',
    );
    for (let i = 0; i < MAX_INTENTS; i++) {
      const accountAddress = accountAddresses[i];
      expect(await env.test.erc20.balanceOf(accountAddress)).to.equal(
        previousFromBalances[i] - (transferResults.amount + transferResults.fee),
        'Senders balance is incorrect',
      );
      expect(await env.test.erc20.balanceOf(to[i])).to.equal(
        previousToBalances[i] + transferResults.amount,
        'Recipients balance is incorrect',
      );
    }
  });
});
