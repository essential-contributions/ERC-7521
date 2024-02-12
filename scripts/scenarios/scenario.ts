import { TransactionResponse } from 'ethers';

// Scenario result definition
export type ScenarioResult = {
  invalidOptions: boolean;
  gasUsed: number;
  bytesUsed: number;
  txFee: bigint;
  serialized: string;
  amount: bigint;
  fee: bigint;
  tx: Promise<TransactionResponse> | null;
};

// Default scenario options
export const INVALID_OPTIONS_RESULT: ScenarioResult = {
  invalidOptions: true,
  gasUsed: 0,
  bytesUsed: 0,
  txFee: 0n,
  serialized: '',
  amount: 0n,
  fee: 0n,
  tx: null,
};

// Scenario options definition
export type ScenarioOptions = {
  useEmbeddedStandards: boolean;
  useCompression: boolean;
  useCompressionRegistry: boolean;
  useAccountAsEOAProxy: boolean;
  useBLSSignatureAggregation: boolean;
};

// Default scenario options
export const DEFAULT_SCENARIO_OPTIONS: ScenarioOptions = {
  useEmbeddedStandards: true,
  useCompression: false,
  useCompressionRegistry: false,
  useAccountAsEOAProxy: false,
  useBLSSignatureAggregation: false,
};

// The scenario object
export abstract class Scenario {
  //initialize the scenario
  public abstract init(): void;

  //runs the baseline EOA version for the scenario
  public abstract runBaseline(to?: string): Promise<ScenarioResult>;

  //runs the scenario
  public abstract run(count?: string[] | number, options?: ScenarioOptions): Promise<ScenarioResult>;
}
