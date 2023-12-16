// Scenario result definition
export type TxResult = {
  gasUsed: number;
  bytesUsed: number;
  serialized: string;
};

// The fee calculator abstract class
export abstract class TxFeeCalculator {
  //calculates the gas fee
  abstract calcTxFee(tx: TxResult): number;
}
