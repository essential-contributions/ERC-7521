import { TxFeeCalculator, TxResult } from './benchmark/feeCalculator';
import { MainnetCalculator } from './benchmark/mainnet';
import { OPStackCalculator } from './benchmark/opstack';
import { Environment, deployTestEnvironment } from './scenarios/environment';
import { TokenSwapScenario } from './scenarios/tokenSwapScenario';
import { TransferErc20Scenario } from './scenarios/transferErc20Scenario';
import { TransferEthScenario } from './scenarios/transferEthScenario';

const MAX_INTENT_BATCH = 16;
const MAINNET_BLOCK_GAS_LIMIT = 15_000_000n;
const GAS_PRICE = 38;
const ETH_PRICE = 2250;
const OP_GAS_PRICE = 0.004;
const OP_DATA_PRICE = 38;
const OP_DATA_SCALER = 0.684;

// Main script entry
async function main() {
  console.log('ASSUMED PARAMETERS');
  logParameters();

  console.log('DEPLOYMENT');
  const env = await deployTestEnvironment({ numAbstractAccounts: MAX_INTENT_BATCH });
  logDeployments(env);

  console.log('SCENARIOS');
  const transferErc20 = new TransferErc20Scenario(env);
  await transferErc20.init();
  await transferErc20.run(env.utils.randomAddresses(16));
  const transferErc20Results: ScenarioCombinations = {
    embedded: {
      base: await transferErc20.runBaseline(env.utils.randomAddresses(1)[0]),
      r1: await transferErc20.run(env.utils.randomAddresses(1)),
      r2: await transferErc20.run(env.utils.randomAddresses(4)),
      r3: await transferErc20.run(env.utils.randomAddresses(8)),
      r4: await transferErc20.run(env.utils.randomAddresses(16)),
    },
    registered: {
      base: await transferErc20.runBaseline(env.utils.randomAddresses(1)[0]),
      r1: await transferErc20.run(env.utils.randomAddresses(1), true),
      r2: await transferErc20.run(env.utils.randomAddresses(4), true),
      r3: await transferErc20.run(env.utils.randomAddresses(8), true),
      r4: await transferErc20.run(env.utils.randomAddresses(16), true),
    },
  };
  const transferEth = new TransferEthScenario(env);
  await transferEth.init();
  await transferEth.run(env.utils.randomAddresses(16));
  const transferEthResults: ScenarioCombinations = {
    embedded: {
      base: await transferEth.runBaseline(env.utils.randomAddresses(1)[0]),
      r1: await transferEth.run(env.utils.randomAddresses(1)),
      r2: await transferEth.run(env.utils.randomAddresses(4)),
      r3: await transferEth.run(env.utils.randomAddresses(8)),
      r4: await transferEth.run(env.utils.randomAddresses(16)),
    },
    registered: {
      base: await transferEth.runBaseline(env.utils.randomAddresses(1)[0]),
      r1: await transferEth.run(env.utils.randomAddresses(1), true),
      r2: await transferEth.run(env.utils.randomAddresses(4), true),
      r3: await transferEth.run(env.utils.randomAddresses(8), true),
      r4: await transferEth.run(env.utils.randomAddresses(16), true),
    },
  };
  const tokenSwap = new TokenSwapScenario(env);
  await tokenSwap.init();
  await tokenSwap.run(16);
  const tokenSwapResults: ScenarioCombinations = {
    embedded: {
      base: await tokenSwap.runBaseline(),
      r1: await tokenSwap.run(1),
      r2: await tokenSwap.run(4),
      r3: await tokenSwap.run(8),
      r4: await tokenSwap.run(16),
    },
    registered: {
      base: await tokenSwap.runBaseline(),
      r1: await tokenSwap.run(1, true),
      r2: await tokenSwap.run(4, true),
      r3: await tokenSwap.run(8, true),
      r4: await tokenSwap.run(16, true),
    },
  };
  logScenarios(transferErc20Results, transferEthResults, tokenSwapResults);
}

// Log parameters
function logParameters() {
  console.log('| Param                   | Value            |');
  console.log('|-------------------------|------------------|');
  console.log('| ETH Price               | $' + ETH_PRICE.toString().padEnd(15, ' ') + ' |');
  console.log('| Mainnet Gas Price       | ' + (GAS_PRICE + 'gwei').padEnd(16, ' ') + ' |');
  console.log('| Optimism Data Price     | ' + (OP_DATA_PRICE + 'gwei').padEnd(16, ' ') + ' |');
  console.log('| Optimism Gas Price      | ' + (OP_GAS_PRICE + 'gwei').padEnd(16, ' ') + ' |');
  console.log('| Optimism Data Scaler    | ' + OP_DATA_SCALER.toString().padEnd(16, ' ') + ' |');
  console.log('');
}

// Log deployment data
function logDeployments(env: Environment) {
  console.log('| Function                | Gas used         | Cost (USD)       | % of limit       |');
  console.log('|-------------------------|------------------|------------------|------------------|');
  function line(name: string, gas: bigint) {
    const cost = Number((gas * BigInt(GAS_PRICE * 1_000_000_000) * BigInt(ETH_PRICE)) / 10_000_000_000_000_000n) / 100;
    const percent = Number((gas * 10000n) / MAINNET_BLOCK_GAS_LIMIT) / 100;
    const n = name.toString().padEnd(23, ' ');
    const g = gas.toString().padEnd(16, ' ');
    const c = price(cost.toString()).padEnd(15, ' ');
    const p = `${percent}%`.toString().padEnd(16, ' ');
    console.log(`| ${n} | ${g} | $${c} | ${p} |`);
  }
  line('Deploy EntryPoint', env.gasUsed.entrypoint);
  line('Deploy Abstract Acct', env.gasUsed.abstractAccount);
  line('Register Standard', env.gasUsed.registerStandard);
  console.log('');
}

// Log scenario data
function logScenarios(
  transferErc20Results: ScenarioCombinations,
  transferEthResults: ScenarioCombinations,
  tokenSwapResults: ScenarioCombinations,
) {
  console.log(
    '| Action                | Baseline Gas     | Intent Gas       | Batch(x4)        | Batch(x8)        | Batch(x16)       |',
  );
  console.log(
    '|-----------------------|------------------|------------------|------------------|------------------|------------------|',
  );
  function line(name: string, results: ScenarioResults, results2: ScenarioResults) {
    const n = name.padEnd(21, ' ');
    const b = results.base.gasUsed;
    const xb = b.toString().padEnd(16, ' ');
    const x1 = `${Math.round(results.r1.gasUsed / 1)}`.padEnd(16, ' ');
    const x4 = `${Math.round(results.r2.gasUsed / 4)}`.padEnd(16, ' ');
    const x8 = `${Math.round(results.r3.gasUsed / 8)}`.padEnd(16, ' ');
    const x16 = `${Math.round(results.r4.gasUsed / 16)}`.padEnd(16, ' ');
    console.log(`| ${n} | ${xb} | ${x1} | ${x4} | ${x8} | ${x16} |`);

    function subline(name: string, calculator: TxFeeCalculator, results: ScenarioResults) {
      const n = name.padEnd(19, ' ');
      const b = calculator.calcTxFee(results.base);
      const xb = `($${price(b.toString())})`.padEnd(16, ' ');
      const g1 = Math.round((calculator.calcTxFee(results.r1) * 100) / 1) / 100;
      const x1 = `($${price(g1.toString())}) ${percent(b, g1)}`.padEnd(16 + 9, ' ');
      const g4 = Math.round((calculator.calcTxFee(results.r2) * 100) / 4) / 100;
      const x4 = `($${price(g4.toString())}) ${percent(b, g4)}`.padEnd(16 + 9, ' ');
      const g8 = Math.round((calculator.calcTxFee(results.r3) * 100) / 8) / 100;
      const x8 = `($${price(g8.toString())}) ${percent(b, g8)}`.padEnd(16 + 9, ' ');
      const g16 = Math.round((calculator.calcTxFee(results.r4) * 100) / 16) / 100;
      const x16 = `($${price(g16.toString())}) ${percent(b, g16)}`.padEnd(16 + 9, ' ');
      console.log(`|   ${n} | ${xb} | ${x1} | ${x4} | ${x8} | ${x16} |`);
    }
    subline('mainnet', new MainnetCalculator(GAS_PRICE, ETH_PRICE), results);
    subline('opstack', new OPStackCalculator(OP_GAS_PRICE, OP_DATA_PRICE, OP_DATA_SCALER, ETH_PRICE), results);
    //subline('opstack(cmp)', new OPStackCalculator(OP_GAS_PRICE, OP_DATA_PRICE, OP_DATA_SCALER, ETH_PRICE), results2);

    console.log(
      '|                       |                  |                  |                  |                  |                  |',
    );
  }
  line('Token Swap', tokenSwapResults.embedded, tokenSwapResults.embedded);
  line('ERC20 Transfer', transferErc20Results.embedded, transferErc20Results.embedded);
  line('ETH Transfer', transferEthResults.embedded, transferEthResults.embedded);
  console.log(
    '|                        ..................... Using Registered Standards .....................                        |',
  );
  console.log(
    '|                       |                  |                  |                  |                  |                  |',
  );
  line('Token Swap', tokenSwapResults.registered, tokenSwapResults.registered);
  line('ERC20 Transfer', transferErc20Results.registered, transferErc20Results.registered);
  line('ETH Transfer', transferEthResults.registered, transferEthResults.registered);
}

// Scenario results
export type ScenarioCombinations = {
  embedded: ScenarioResults;
  registered: ScenarioResults;
};

// Scenario results
export type ScenarioResults = {
  base: TxResult;
  r1: TxResult;
  r2: TxResult;
  r3: TxResult;
  r4: TxResult;
};

// Pad price string
function price(p: string): string {
  const decimal = p.indexOf('.');
  if (decimal == -1) return p + '.00';
  if (decimal == 0) p = '0' + p;
  const index = p.indexOf('.');
  return p.substring(0, index) + p.substring(index).padEnd(3, '0');
}

// Format percent string
function percent(before: number, now: number): string {
  let v = 0;
  let n = false;
  let p = '';
  if (before > now) {
    n = true;
    v = (before - now) / before;
    p = `-${Math.round(v * 1000) / 10}%`;
  } else {
    n = false;
    v = (now - before) / before;
    p = `+${Math.round(v * 1000) / 10}%`;
  }
  if (p.length > 7 && p.indexOf('.') > -1) p = `${p.substring(0, p.indexOf('.'))}%`;

  if (n) return '\x1b[32m' + p + '\x1b[0m';
  if (v < 1) return '\x1b[33m' + p + '\x1b[0m';
  return '\x1b[31m' + p + '\x1b[0m';
}

// Start script
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
