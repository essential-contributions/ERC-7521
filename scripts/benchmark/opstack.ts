import { TxFeeCalculator, TxResult } from './feeCalculator';

// OP Stack transaction fee calculator
export class OPStackCalculator extends TxFeeCalculator {
  private gasPriceGwei: number;
  private dataPriceGwei: number;
  private dataScaler: number;
  private ethPrice: number;

  constructor(gasPriceGwei: number, dataPriceGwei: number, dataScaler: number, ethPrice: number) {
    super();
    this.gasPriceGwei = gasPriceGwei;
    this.dataPriceGwei = dataPriceGwei;
    this.dataScaler = dataScaler;
    this.ethPrice = ethPrice;
  }

  calcTxFee(tx: TxResult): number {
    let zeroBytes = 0;
    let nonzeroBytes = 0;
    for (let i = 2; i < tx.serialized.length; i += 2) {
      const byte = tx.serialized.substring(i, i + 2);
      if (byte == '00') zeroBytes++;
      else nonzeroBytes++;
    }

    const gasForData = BigInt(zeroBytes * 4 + nonzeroBytes * 16);
    const gasPrice = BigInt(this.gasPriceGwei * 1_000_000_000);
    const dataPrice = BigInt(this.dataPriceGwei * 1_000_000_000);
    const l1Fee = (gasForData * dataPrice * BigInt(this.ethPrice)) / 10_000_000_000_000n;
    const l2Fee = (BigInt(tx.gasUsed) * gasPrice * BigInt(this.ethPrice)) / 10_000_000_000_000n;
    return Math.round(Number(l1Fee + l2Fee) * this.dataScaler) / 100_000;
  }
}
