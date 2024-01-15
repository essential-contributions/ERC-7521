import { TxFeeCalculator, TxResult } from './benchmark/feeCalculator';
import { MainnetCalculator } from './benchmark/mainnet';
import { OPStackCalculator } from './benchmark/opstack';
import { ArbitrumCalculator } from './benchmark/arbitrum';
import { Environment, deployTestEnvironment } from './scenarios/environment';
import { ScenarioOptions, ScenarioResult } from './scenarios/scenario';
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
const ARB_GAS_PRICE = 0.004;
const ARB_DATA_PRICE = 30;

// Main script entry
async function main() {
  console.log('ASSUMED PARAMETERS');
  logParameters();

  console.log('DEPLOYMENT');
  const env = await deployTestEnvironment({ numAccounts: MAX_INTENT_BATCH });
  logDeployments(env);

  console.log('SCENARIOS');
  const transferErc20 = new TransferErc20Scenario(env);
  await transferErc20.init();
  await transferErc20.run(16);
  const transferErc20Base = await transferErc20.runBaseline();
  const transferEth = new TransferEthScenario(env);
  await transferEth.init();
  await transferEth.run(16);
  const transferEthBase = await transferEth.runBaseline();
  const tokenSwap = new TokenSwapScenario(env);
  await tokenSwap.init();
  await tokenSwap.run(16);
  const tokenSwapBase = await tokenSwap.runBaseline();
  async function run(options: ScenarioOptions): Promise<ScenariosResults> {
    return {
      tokenSwap: {
        base: tokenSwapBase,
        r1: await tokenSwap.run(1, options),
        r2: await tokenSwap.run(4, options),
        r3: await tokenSwap.run(8, options),
        r4: await tokenSwap.run(16, options),
      },
      transferErc20: {
        base: transferErc20Base,
        r1: await transferErc20.run(1, options),
        r2: await transferErc20.run(4, options),
        r3: await transferErc20.run(8, options),
        r4: await transferErc20.run(16, options),
      },
      transferEth: {
        base: transferEthBase,
        r1: await transferEth.run(1, options),
        r2: await transferEth.run(4, options),
        r3: await transferEth.run(8, options),
        r4: await transferEth.run(16, options),
      },
    };
  }

  //embedded
  const embeddedStandards: ScenarioOptions = {
    useEmbeddedStandards: true,
    useCompression: false,
    useStatefulCompression: false,
    useAccountAsEOAProxy: false,
    useBLSSignatureAggregation: false,
  };
  logScenarios(await run(embeddedStandards));

  //embedded with compression
  const nonStatefulCompression: ScenarioOptions = {
    useEmbeddedStandards: true,
    useCompression: true,
    useStatefulCompression: false,
    useAccountAsEOAProxy: false,
    useBLSSignatureAggregation: false,
  };
  logScenarios(await run(nonStatefulCompression), 'Non-Stateful Compression');

  //embedded with stateful compression
  const statefulCompression: ScenarioOptions = {
    useEmbeddedStandards: true,
    useCompression: true,
    useStatefulCompression: true,
    useAccountAsEOAProxy: false,
    useBLSSignatureAggregation: false,
  };
  logScenarios(await run(statefulCompression), 'Stateful Compression');

  //embedded with bls signatures
  const blsSignatureAggregation: ScenarioOptions = {
    useEmbeddedStandards: true,
    useCompression: false,
    useStatefulCompression: false,
    useAccountAsEOAProxy: false,
    useBLSSignatureAggregation: true,
  };
  logScenarios(await run(blsSignatureAggregation), 'BLS Signature Aggregation');

  //embedded with bls signatures and compression
  const blsCompression: ScenarioOptions = {
    useEmbeddedStandards: true,
    useCompression: true,
    useStatefulCompression: false,
    useAccountAsEOAProxy: false,
    useBLSSignatureAggregation: true,
  };
  logScenarios(await run(blsCompression), 'BLS Signature Aggregation w/ Compression');

  //embedded with bls signatures and stateful compression
  const blsStatefulCompression: ScenarioOptions = {
    useEmbeddedStandards: true,
    useCompression: true,
    useStatefulCompression: true,
    useAccountAsEOAProxy: false,
    useBLSSignatureAggregation: true,
  };
  logScenarios(await run(blsStatefulCompression), 'BLS Signature Aggregation w/ Stateful Compression');

  //embedded for EOA
  const embeddedStandardsEOA: ScenarioOptions = {
    useEmbeddedStandards: true,
    useCompression: false,
    useStatefulCompression: false,
    useAccountAsEOAProxy: true,
    useBLSSignatureAggregation: false,
  };
  logScenarios(await run(embeddedStandardsEOA), 'Proxy Contracts for EOAs');

  //embedded with compression
  const nonStatefulCompressionEOA: ScenarioOptions = {
    useEmbeddedStandards: true,
    useCompression: true,
    useStatefulCompression: true,
    useAccountAsEOAProxy: true,
    useBLSSignatureAggregation: false,
  };
  logScenarios(await run(nonStatefulCompressionEOA), 'Stateful Compression Proxy for EOAs');

  //registered
  const registeredStandards: ScenarioOptions = {
    useEmbeddedStandards: false,
    useCompression: false,
    useStatefulCompression: false,
    useAccountAsEOAProxy: false,
    useBLSSignatureAggregation: false,
  };
  logScenarios(await run(registeredStandards), 'Using Registered Standards');

  //registered with stateful compression
  const registeredStatefulCompression: ScenarioOptions = {
    useEmbeddedStandards: false,
    useCompression: true,
    useStatefulCompression: true,
    useAccountAsEOAProxy: false,
    useBLSSignatureAggregation: false,
  };
  logScenarios(await run(registeredStatefulCompression), 'Using Registered Standards w/ Stateful Compression');
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
  console.log('| Arbitrum Data Price     | ' + (ARB_DATA_PRICE + 'gwei').padEnd(16, ' ') + ' |');
  console.log('| Arbitrum Gas Price      | ' + (ARB_GAS_PRICE + 'gwei').padEnd(16, ' ') + ' |');
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
  line('Deploy BLS Aggregator', env.gasUsed.blsSignatureAggregator);
  line('Deploy Simple Acct Fac', env.gasUsed.simpleAccountFactory);
  line('Deploy Simple Acct', env.gasUsed.simpleAccount);
  line('Deploy Gen Compression', env.gasUsed.generalCompression);
  line('Register Standard', env.gasUsed.registerStandard);
  console.log('');
}

// Log scenario data
function logScenarios(results: ScenariosResults, subHeading?: string) {
  if (!subHeading) {
    console.log(
      '| Action                | Baseline Gas     | Intent Gas       | Batch(x4)        | Batch(x8)        | Batch(x16)       |',
    );
    console.log(
      '|-----------------------|------------------|------------------|------------------|------------------|------------------|',
    );
  } else {
    subHeading = '..................... ' + subHeading + '  .....................';
    const padding = (118 - subHeading.length) / 2;
    console.log('|' + ''.padStart(Math.ceil(padding), ' ') + subHeading + ''.padStart(Math.floor(padding), ' ') + '|');
    console.log(
      '|                       |                  |                  |                  |                  |                  |',
    );
  }

  function line(name: string, results: ScenarioResults) {
    const n = name.padEnd(21, ' ');
    const b = results.base.gasUsed;
    const xb = `${b} (${results.base.bytesUsed})`.padEnd(16, ' ');
    function calc(res: ScenarioResult, div: number): string {
      if (res.invalidOptions) return '       --       ';
      return `${Math.round(res.gasUsed / div)} (${Math.round(res.bytesUsed / div)})`.padEnd(16, ' ');
    }
    const x1 = calc(results.r1, 1);
    const x4 = calc(results.r2, 4);
    const x8 = calc(results.r3, 8);
    const x16 = calc(results.r4, 16);
    console.log(`| ${n} | ${xb} | ${x1} | ${x4} | ${x8} | ${x16} |`);

    function subline(name: string, calculator: TxFeeCalculator, results: ScenarioResults) {
      const n = name.padEnd(19, ' ');
      const b = calculator.calcTxFee(results.base);
      const xb = `($${price(b.toString())})`.padEnd(16, ' ');
      function calc(res: ScenarioResult, div: number): string {
        const g = Math.round((calculator.calcTxFee(res) * 10000) / div) / 10000;
        if (res.invalidOptions) return '       --       ';
        return `($${price(g.toString())}) ${percent(b, g)}`.padEnd(16 + 9, ' ');
      }
      const x1 = calc(results.r1, 1);
      const x4 = calc(results.r2, 4);
      const x8 = calc(results.r3, 8);
      const x16 = calc(results.r4, 16);
      console.log(`|   ${n} | ${xb} | ${x1} | ${x4} | ${x8} | ${x16} |`);
    }
    subline('mainnet', new MainnetCalculator(GAS_PRICE, ETH_PRICE), results);
    subline('opstack', new OPStackCalculator(OP_GAS_PRICE, OP_DATA_PRICE, OP_DATA_SCALER, ETH_PRICE), results);
    subline('arbitrum', new ArbitrumCalculator(ARB_GAS_PRICE, ARB_DATA_PRICE, ETH_PRICE), results);

    console.log(
      '|                       |                  |                  |                  |                  |                  |',
    );
  }
  line('Token Swap', results.tokenSwap);
  line('ERC20 Transfer', results.transferErc20);
  line('ETH Transfer', results.transferEth);
}

// Scenarios results
export type ScenariosResults = {
  tokenSwap: ScenarioResults;
  transferErc20: ScenarioResults;
  transferEth: ScenarioResults;
};

// Scenario results
export type ScenarioResults = {
  base: ScenarioResult;
  r1: ScenarioResult;
  r2: ScenarioResult;
  r3: ScenarioResult;
  r4: ScenarioResult;
};

// Pad price string
function price(p: string): string {
  const decimal = p.indexOf('.');
  if (decimal == -1) return p + '.00';
  if (decimal == 0) p = '0' + p;
  const index = p.indexOf('.');
  p = p.substring(0, index) + p.substring(index).padEnd(3, '0');
  if (p.length > 5) p = p.substring(0, 5);
  return p;
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
