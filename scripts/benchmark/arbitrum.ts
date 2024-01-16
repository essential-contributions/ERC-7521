import { TxFeeCalculator, TxResult } from './feeCalculator';
import { ethers } from 'ethers';
var brotli = require('brotli');

// Arbitrum transaction fee calculator
export class ArbitrumCalculator extends TxFeeCalculator {
  private gasPriceGwei: number;
  private dataPriceGwei: number;
  private ethPrice: number;

  constructor(gasPriceGwei: number, dataPriceGwei: number, ethPrice: number) {
    super();
    this.gasPriceGwei = gasPriceGwei;
    this.dataPriceGwei = dataPriceGwei;
    this.ethPrice = ethPrice;
  }

  calcTxFee(tx: TxResult): number {
    let dataLength = 0;
    if (tx.serialized) {
      const data = ethers.toBeArray(tx.serialized);
      const compressed = brotli.compress(data, {
        mode: 0, // 0 = generic, 1 = text, 2 = font (WOFF2)
        quality: 0, // 0 - 11
        lgwin: 22, // window size
      });
      dataLength = compressed ? compressed.length : data.length;
    }

    const gasForData = BigInt(dataLength * 16);
    const gasPrice = BigInt(this.gasPriceGwei * 1_000_000_000);
    const dataPrice = BigInt(this.dataPriceGwei * 1_000_000_000);
    const l1Fee = (gasForData * dataPrice * BigInt(this.ethPrice)) / 10_000_000_000_000n;
    const l2Fee = (BigInt(tx.gasUsed) * gasPrice * BigInt(this.ethPrice)) / 10_000_000_000_000n;
    return Number(l1Fee + l2Fee) / 100_000;
  }
}
