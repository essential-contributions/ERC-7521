// Scenario result definition
export type ScenarioResult = {
  gasUsed: number;
  bytesUsed: number;
  txFee: bigint;
  serialized: string;
  amount: bigint;
  fee: bigint;
};

// Scenario options definition
export type ScenarioOptions = {
  useEmbeddedStandards: boolean;
  useCompression: boolean;
  useStatefulCompression: boolean;
};

// Default scenario options
export const DEFAULT_SCENARIO_OPTIONS: ScenarioOptions = {
  useEmbeddedStandards: true,
  useCompression: false,
  useStatefulCompression: false,
};

// The scenario object
export abstract class TestScenario {
  //initialize the scenario
  public abstract init(): void;

  //runs the baseline EOA version for the scenario
  public abstract runBaseline(to?: string): Promise<ScenarioResult>;

  //runs the scenario
  public abstract run(count?: string[] | number, options?: ScenarioOptions): Promise<ScenarioResult>;
}
