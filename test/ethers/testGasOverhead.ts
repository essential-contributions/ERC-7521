import { expect } from 'chai';
import { ethers } from 'hardhat';
import { deployTestEnvironment, Environment } from './utils/environment';
import { buildSolutionForNextBlock, UserIntent } from './utils/intent';
import { ConstantCurve } from './utils/curveCoder';

describe('Gass Overhead Test', () => {
  let env: Environment;
  before(async () => {
    env = await deployTestEnvironment();
  });

  it('Should run successfully', async () => {
    // standard mint (68bytes, 51136gas)
    const tx = env.test.erc20.mint(env.deployerAddress, ethers.parseEther('1000'));
    await expect(tx).to.not.be.reverted;

    console.log('data: ' + (await tx).data);
    console.log('gasUsed: ' + (await (await tx).wait())?.gasUsed);

    // intent mint (1028bytes, 146356gas)
    const account = env.abstractAccounts[0];
    const executeMintTx = account.contract.interface.encodeFunctionData('execute', [
      env.test.erc20Address,
      0,
      env.test.erc20.interface.encodeFunctionData('mint', [account.contractAddress, ethers.parseEther('1000')]),
    ]);

    const intent = new UserIntent(account.contractAddress);
    intent.addSegment(env.standards.sequentialNonce(1));
    intent.addSegment(env.standards.call(executeMintTx));
    await intent.sign(env.chainId, env.entrypointAddress, account.signer);

    const solution = await buildSolutionForNextBlock(env.provider, [intent], []);
    const tx2 = env.entrypoint.handleIntents(solution);
    await expect(tx2).to.not.be.reverted;

    console.log('solution data: ' + (await tx2).data);
    console.log('solution gasUsed: ' + (await (await tx2).wait())?.gasUsed);
  });
});
