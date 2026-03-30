import JSBI from 'jsbi';
import { TickDataProvider } from '../entities/tickDataProvider';
export declare function v3Swap(fee: JSBI, sqrtRatioX96: JSBI, tickCurrent: number, liquidity: JSBI, tickSpacing: number, tickDataProvider: TickDataProvider, zeroForOne: boolean, amountSpecified: JSBI, sqrtPriceLimitX96?: JSBI): Promise<{
    amountCalculated: JSBI;
    sqrtRatioX96: JSBI;
    liquidity: JSBI;
    tickCurrent: number;
}>;
