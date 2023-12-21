import { TxFeeCalculator, TxResult } from './feeCalculator';

// Mainnet transaction fee calculator
export class MainnetCalculator extends TxFeeCalculator {
  private gasPriceGwei: number;
  private ethPrice: number;

  constructor(gasPriceGwei: number, ethPrice: number) {
    super();
    this.gasPriceGwei = gasPriceGwei;
    this.ethPrice = ethPrice;
  }

  calcTxFee(tx: TxResult): number {
    const gasPrice = BigInt(this.gasPriceGwei * 1_000_000_000);
    return Number((BigInt(tx.gasUsed) * gasPrice * BigInt(this.ethPrice)) / 10_000_000_000_000_000n) / 100;
  }
}
