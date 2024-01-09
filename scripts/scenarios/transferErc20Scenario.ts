import { ethers } from 'hardhat';
import { Transaction, ContractTransactionResponse } from 'ethers';
import { ScenarioOptions, ScenarioResult, Scenario, DEFAULT_SCENARIO_OPTIONS } from './scenario';
import { BLSSmartContractAccount, Environment, SmartContractAccount } from '../../scripts/scenarios/environment';
import { buildSolution, UserIntent } from '../../scripts/library/intent';
import { Curve, LinearCurve } from '../../scripts/library/curveCoder';

// The scenario object
export class TransferErc20Scenario extends Scenario {
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
    }
    for (const account of this.env.blsAccounts) {
      const needToMint = ethers.parseEther('1000') - (await this.env.test.erc20.balanceOf(account.contractAddress));
      if (needToMint > 0) {
        await (await this.env.test.erc20.mint(account.contractAddress, needToMint)).wait();
      }
    }
    for (const account of this.env.eoaProxyAccounts) {
      const needToMint = ethers.parseEther('1000') - (await this.env.test.erc20.balanceOf(account.signerAddress));
      if (needToMint > 0) {
        await (await this.env.test.erc20.mint(account.signerAddress, needToMint)).wait();
      }
    }
  }

  //runs the baseline EOA version for the scenario
  public async runBaseline(to?: string): Promise<ScenarioResult> {
    to = to || this.env.utils.randomAddresses(1)[0];
    const amount = ethers.parseEther('10');

    const txPromise = this.env.test.erc20.transfer(to, amount);
    const tx = await txPromise;

    const serialized = Transaction.from(tx).serialized;
    const bytesUsed = serialized.length / 2 - 1;
    const gasUsed = Number((await tx.wait())?.gasUsed || 0n);
    const txFee = ((await tx.wait())?.gasUsed || 0n) * ((await tx.wait())?.gasPrice || 0n);
    return { invalidOptions: false, gasUsed, bytesUsed, txFee, serialized, amount, fee: 0n, tx: txPromise };
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
    const proxy = options.useAccountAsEOAProxy;
    const bls = options.useBLSSignatureAggregation;

    if (this.env.simpleAccounts.length < batchSize) throw new Error('not enough abstract accounts to run batch');
    const timestamp = (await this.env.provider.getBlock('latest'))?.timestamp || 0;
    const amount = ethers.parseEther('10');
    const fee = ethers.parseEther('1');

    //create intents
    const intents = [];
    const signatures: string[] = [];
    for (let i = 0; i < batchSize; i++) {
      let account: SmartContractAccount | BLSSmartContractAccount = this.env.simpleAccounts[i];
      if (proxy) account = this.env.eoaProxyAccounts[i];
      else if (bls) account = this.env.blsAccounts[i];

      const intent = new UserIntent(account.contractAddress);
      if (options.useEmbeddedStandards) {
        //using the embedded intent standard versions
        intent.addSegment(this.env.standards.sequentialNonce(await this.env.utils.getNonce(account.contractAddress)));
        intent.addSegment(
          this.env.standards.erc20Release(
            this.env.test.erc20Address,
            this.generateLinearRelease(timestamp, fee, proxy),
          ),
        );
        intent.addSegment(
          this.env.standards.userOp(this.generateExecuteTransferTx(account, to[i], amount, proxy), 100_000),
        );
      } else {
        //using the registered intent standard versions
        intent.addSegment(
          this.env.registeredStandards.sequentialNonce(await this.env.utils.getNonce(account.contractAddress)),
        );
        intent.addSegment(
          this.env.registeredStandards.erc20Release(
            this.env.test.erc20Address,
            this.generateLinearRelease(timestamp, fee, proxy),
          ),
        );
        intent.addSegment(
          this.env.registeredStandards.userOp(this.generateExecuteTransferTx(account, to[i], amount, proxy), 100_000),
        );
      }

      //sign
      if (bls) {
        const hash = intent.hash(this.env.chainId, this.env.entrypointAddress);
        const blsSignature = (account as BLSSmartContractAccount).signer.sign(hash);
        if (batchSize == 1) intent.setSignature(blsSignature);
        else signatures.push(blsSignature);
      } else {
        await intent.sign(this.env.chainId, this.env.entrypointAddress, (account as SmartContractAccount).signer);
      }
      intents.push(intent);
    }

    //aggregate signatures
    const aggregatedSignature = signatures.length > 0 ? this.env.blsVerifier.aggregate(signatures) : '';
    let bitfield = 0n;
    for (let i = 0; i < signatures.length; i++) bitfield = (bitfield << 1n) + 1n;
    const toAggregate = `0x${bitfield.toString(16).padStart(64, '0')}`;

    //solver intent
    const solverIntent = new UserIntent(this.env.deployerAddress);
    intents.push(solverIntent);

    //solution
    const order = [];
    for (let i = 0; i < batchSize; i++) {
      order.push(i);
      order.push(i);
      order.push(batchSize);
      order.push(i);
    }
    const solution = buildSolution(timestamp, intents, order);

    //handle intents
    let txPromise: Promise<ContractTransactionResponse>;
    if (options.useCompression) {
      txPromise = this.env.compression.general.handleIntents(solution, options.useStatefulCompression);
    } else {
      if (aggregatedSignature) {
        txPromise = this.env.entrypoint.handleIntentsAggregated(
          [solution],
          this.env.blsSignatureAggregatorAddress,
          toAggregate,
          aggregatedSignature,
        );
      } else {
        txPromise = this.env.entrypoint.handleIntents(solution);
      }
    }
    const tx = await txPromise;

    const serialized = Transaction.from(tx).serialized;
    const bytesUsed = serialized.length / 2 - 1;
    const gasUsed = Number((await tx.wait())?.gasUsed || 0n);
    const txFee = ((await tx.wait())?.gasUsed || 0n) * ((await tx.wait())?.gasPrice || 0n);
    return { invalidOptions: false, gasUsed, bytesUsed, txFee, serialized, amount, fee, tx: txPromise };
  }

  //////////////////////
  // Helper Functions //
  //////////////////////

  // helper function to generate transfer tx calldata
  private generateExecuteTransferTx(
    account: SmartContractAccount | BLSSmartContractAccount,
    to: string,
    amount: bigint,
    proxy: boolean,
  ): string {
    if (proxy) {
      account = account as SmartContractAccount;
      return account.contract.interface.encodeFunctionData('execute', [
        this.env.test.erc20Address,
        0,
        this.env.test.erc20.interface.encodeFunctionData('transferFrom', [account.signerAddress, to, amount]),
      ]);
    }
    return account.contract.interface.encodeFunctionData('execute', [
      this.env.test.erc20Address,
      0,
      this.env.test.erc20.interface.encodeFunctionData('transfer', [to, amount]),
    ]);
  }

  // helper function to generate a linear release curve
  private generateLinearRelease(timestamp: number, amount: bigint, proxy: boolean): Curve {
    const evaluateAt = 1000;
    const startTime = timestamp - evaluateAt;
    const duration = 3000;
    const startAmount = 0n;
    const endAmount = amount * BigInt(duration / evaluateAt);
    return new LinearCurve(startTime, duration, startAmount, endAmount, false, proxy);
  }
}
