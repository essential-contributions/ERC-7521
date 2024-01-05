import { ethers } from 'hardhat';
import { Transaction } from 'ethers';
import { ScenarioOptions, ScenarioResult, Scenario, DEFAULT_SCENARIO_OPTIONS } from './scenario';
import { Environment, SmartContractAccount } from '../../scripts/scenarios/environment';
import { buildSolution, UserIntent } from '../../scripts/library/intent';
import { Curve, LinearCurve } from '../../scripts/library/curveCoder';

// The scenario object
export class TransferEthScenario extends Scenario {
  private env: Environment;

  constructor(environment: Environment) {
    super();
    this.env = environment;
  }

  //initialize the scenario
  public async init() {
    //fund accounts
    const needToMint = ethers.parseEther('1000') - (await this.env.test.erc20.balanceOf(this.env.deployerAddress));
    if (needToMint > 0) {
      await (await this.env.test.erc20.mint(this.env.deployerAddress, needToMint)).wait();
    }
    for (const account of this.env.simpleAccounts) {
      const needToMint = ethers.parseEther('1000') - (await this.env.test.erc20.balanceOf(account.contractAddress));
      if (needToMint > 0) {
        await (await this.env.test.erc20.mint(account.contractAddress, needToMint)).wait();
      }
      const needToFund = ethers.parseEther('10') - (await this.env.provider.getBalance(account.contractAddress));
      if (needToFund > 0) {
        await (await this.env.deployer.sendTransaction({ to: account.contractAddress, value: needToFund })).wait();
      }
    }
  }

  //runs the baseline EOA version for the scenario
  public async runBaseline(to?: string): Promise<ScenarioResult> {
    to = to || this.env.utils.randomAddresses(1)[0];
    const amount = ethers.parseEther('1');

    const txPromise = this.env.deployer.sendTransaction({ to, value: amount });
    const tx = await txPromise;

    const serialized = Transaction.from(tx).serialized;
    const bytesUsed = serialized.length / 2 - 1;
    const gasUsed = Number((await tx.wait())?.gasUsed || 0n);
    const txFee = ((await tx.wait())?.gasUsed || 0n) * ((await tx.wait())?.gasPrice || 0n);
    return { gasUsed, bytesUsed, txFee, serialized, amount, fee: 0n, tx: txPromise };
  }

  //runs the scenario
  public async run(count?: string[] | number, options?: ScenarioOptions): Promise<ScenarioResult> {
    options = options || DEFAULT_SCENARIO_OPTIONS;
    count = count || 1;
    let to: string[];
    let batchSize: number;
    if (typeof count == 'number') {
      to = this.env.utils.randomAddresses(count);
      batchSize = count;
    } else {
      if (count.length == 0) count.push(this.env.utils.randomAddresses(1)[0]);
      to = count;
      batchSize = count.length;
    }
    if (options.useStatefulCompression) await this.env.compression.registerAddresses(to);

    if (this.env.simpleAccounts.length < batchSize) throw new Error('not enough abstract accounts to run batch');
    const timestamp = (await this.env.provider.getBlock('latest'))?.timestamp || 0;
    const amount = ethers.parseEther('1');
    const fee = ethers.parseEther('0.1');

    const intents = [];
    for (let i = 0; i < batchSize; i++) {
      const account = this.env.simpleAccounts[i];
      const intent = new UserIntent(account.contractAddress);
      if (options.useEmbeddedStandards) {
        //using the embedded intent standard versions
        intent.addSegment(this.env.standards.sequentialNonce(await this.env.utils.getNonce(account.contractAddress)));
        intent.addSegment(
          this.env.standards.erc20Release(this.env.test.erc20Address, this.generateLinearRelease(timestamp, fee)),
        );
        intent.addSegment(this.env.standards.userOp(this.generateExecuteTransferTx(account, to[i], amount), 100_000));
      } else {
        //using the registered intent standard versions
        intent.addSegment(
          this.env.registeredStandards.sequentialNonce(await this.env.utils.getNonce(account.contractAddress)),
        );
        intent.addSegment(
          this.env.registeredStandards.erc20Release(
            this.env.test.erc20Address,
            this.generateLinearRelease(timestamp, fee),
          ),
        );
        intent.addSegment(
          this.env.registeredStandards.userOp(this.generateExecuteTransferTx(account, to[i], amount), 100_000),
        );
      }
      await intent.sign(this.env.chainId, this.env.entrypointAddress, account.signer);
      intents.push(intent);
    }
    const solverIntent = new UserIntent(this.env.deployerAddress);
    intents.push(solverIntent);

    const order = [];
    for (let i = 0; i < batchSize; i++) {
      order.push(i);
      order.push(i);
      order.push(batchSize);
      order.push(i);
    }
    const solution = buildSolution(timestamp, intents, order);
    const txPromise = options.useCompression
      ? this.env.compression.general.handleIntents(solution, options.useStatefulCompression)
      : this.env.entrypoint.handleIntents(solution);
    const tx = await txPromise;

    const serialized = Transaction.from(tx).serialized;
    const bytesUsed = serialized.length / 2 - 1;
    const gasUsed = Number((await tx.wait())?.gasUsed || 0n);
    const txFee = ((await tx.wait())?.gasUsed || 0n) * ((await tx.wait())?.gasPrice || 0n);
    return { gasUsed, bytesUsed, txFee, serialized, amount, fee, tx: txPromise };
  }

  //////////////////////
  // Helper Functions //
  //////////////////////

  // helper function to generate transfer tx calldata
  private generateExecuteTransferTx(account: SmartContractAccount, to: string, amount: bigint): string {
    return account.contract.interface.encodeFunctionData('execute', [to, amount, '0x']);
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
}
