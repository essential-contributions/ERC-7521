import { expect } from 'chai';
import { BLSSmartContractAccount, deployTestEnvironment, Environment } from '../../scripts/scenarios/environment';
import { TransferEthScenario } from '../../scripts/scenarios/transferEthScenario';
import { UserIntent } from '../../scripts/library/intent';
import { ConstantCurve } from '../../scripts/library/curveCoder';
import { UserIntentStruct } from '../../typechain/src/core/EntryPoint';
import { PublicKey } from '../../scripts/library/bls/bls';

describe('BLS Signature Aggregation Test', () => {
  const MAX_INTENTS = 4;
  const USE_TRANSIENT_DATA = true;
  let env: Environment;
  let scenario: TransferEthScenario;

  before(async () => {
    env = await deployTestEnvironment({ numAccounts: MAX_INTENTS, useTransientData: USE_TRANSIENT_DATA });
    scenario = new TransferEthScenario(env);
    scenario.init();
  });

  it('Should verify single signature', async () => {
    const account = env.blsAccounts[0];
    const intent = await generateIntent(account);
    const message = intent.hash(env.chainId, env.entrypointAddress);
    const signature = account.signer.sign(message);
    intent.setSignature(signature);

    const result = env.blsVerifier.verify(signature, account.signer.pubkey, message);
    expect(result).to.equal(true, 'Failed to verify signature via library');

    await expect(env.blsSignatureAggregator.validateSignature(intent.asUserIntentStruct())).to.not.be.reverted;
  });

  it('Should successfully aggregate signatures', async () => {
    const signatures: string[] = [];
    const intentStructs: UserIntentStruct[] = [];
    for (let i = 0; i < MAX_INTENTS; i++) {
      const account = env.blsAccounts[i];
      const intent = await generateIntent(account);
      const message = intent.hash(env.chainId, env.entrypointAddress);
      const signature = account.signer.sign(message);
      intent.setSignature(signature);

      signatures.push(signature);
      intentStructs.push(intent.asUserIntentStruct());
    }

    const aggregate = env.blsVerifier.aggregate(signatures);
    const aggregate2 = await env.blsSignatureAggregator.aggregateSignatures(intentStructs);
    expect(aggregate).to.equal(aggregate2, 'Contract and library did not return the same aggregation result');
  });

  it('Should verify aggregated signatures', async () => {
    const pubKeys: PublicKey[] = [];
    const messages: string[] = [];
    const signatures: string[] = [];
    const intentStructs: UserIntentStruct[] = [];
    for (let i = 0; i < MAX_INTENTS; i++) {
      const account = env.blsAccounts[i];
      pubKeys.push(account.signer.pubkey);
      const intent = await generateIntent(account);
      intentStructs.push(intent.asUserIntentStruct());

      const message = intent.hash(env.chainId, env.entrypointAddress);
      messages.push(message);

      const signature = account.signer.sign(message);
      signatures.push(signature);
    }
    const aggregateSignature = env.blsVerifier.aggregate(signatures);

    const result = env.blsVerifier.verifyMultiple(aggregateSignature, pubKeys, messages);
    expect(result).to.equal(true, 'Failed to verify signature via library');

    await expect(env.blsSignatureAggregator.validateSignatures(intentStructs, aggregateSignature)).to.not.be.reverted;
  });

  it('Should fail invalid aggregated signature', async () => {
    const signatures: string[] = [];
    const intentStructs: UserIntentStruct[] = [];
    for (let i = 0; i < MAX_INTENTS; i++) {
      const account = env.blsAccounts[i];
      const intent = await generateIntent(account);
      intentStructs.push(intent.asUserIntentStruct());

      const badMessage = intent.hash(0n, '0x0000000000000000000000000000000000000000');
      const signature = account.signer.sign(badMessage);
      signatures.push(signature);
    }
    const aggregateSignature = env.blsVerifier.aggregate(signatures);

    await expect(env.blsSignatureAggregator.validateSignatures(intentStructs, aggregateSignature)).to.be.revertedWith(
      'BLS: invalid aggregated signature',
    );
  });

  // Helper function
  async function generateIntent(account: BLSSmartContractAccount): Promise<UserIntent> {
    const intent = new UserIntent(account.contractAddress);
    intent.addSegment(env.standards.sequentialNonce(await env.utils.getNonce(account.contractAddress)));
    intent.addSegment(env.standards.ethRecord(false));
    intent.addSegment(env.standards.ethRequire(new ConstantCurve(123n, true, false)));

    return intent;
  }
});
