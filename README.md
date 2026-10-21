# Trading-bot

A MetaTrader 5 Expert Advisor that trades **Fair Value Gaps (FVGs) on XAU/USD, 15-minute chart**.

## Strategy

An FVG is a three-candle imbalance:

- **Bullish FVG**: candle 1's high is below candle 3's low. The EA places a **buy limit at the top edge of the gap** (candle 3's low) and waits for price to retrace into it.
- **Bearish FVG**: candle 1's low is above candle 3's high. The EA places a **sell limit at the bottom edge of the gap** (candle 3's high).

| Rule | Default |
|---|---|
| Stop loss | Beyond candle 1's extreme + 50 point buffer (switchable to the far gap edge) |
| Take profit | 2R (twice the stop distance) |
| Risk | 1% of balance per trade, sized from the stop distance |
| Min gap size | 100 points (about $1.00 on most gold feeds) |
| Displacement | Middle candle must close in the gap's direction |
| Trend filter | Buys only when the last closed H1 candle is above the 200 EMA, sells only when below |
| Sessions | London (10:00–19:00) and New York (15:00–23:00), broker server time; unfilled orders are cancelled outside them |
| Unfilled orders | Cancelled after 16 bars (4 hours); a newer FVG replaces an older unfilled order |
| Max positions | 1 |
| Daily kill switch | Closes everything and stops for the day at a 3% equity drawdown |
| Spread filter | No new orders above 50 points of spread |

## Files

- `MQL5/Experts/FVG_Gold_EA.mq5`: the Expert Advisor

## Install

1. Open MetaTrader 5 and go to **File → Open Data Folder**.
2. Copy `FVG_Gold_EA.mq5` into `MQL5/Experts/`.
3. Open it in MetaEditor (F4) and **Compile** (F7). Fix any broker-specific warnings.
4. Check your broker's gold symbol name (`XAUUSD`, `XAUUSD.m`, `GOLD`, ...) and attach the EA to that chart.

## 1. Backtest (Strategy Tester)

1. In MT5, press **Ctrl+R** to open the Strategy Tester.
2. Expert: `FVG_Gold_EA`. Symbol: your gold symbol. Timeframe: **M15**.
3. Modelling: **Every tick based on real ticks** (most accurate for limit orders and tight stops).
4. Date range: at least 1–2 years. Deposit: what you plan to trade with.
5. Run it, then review the **Backtest** tab (profit factor, drawdown, win rate) and the **Graph** tab.
6. Optional: use **Optimization** on `InpMinGapPoints`, `InpStopBufferPoints`, `InpRewardRisk` and the session hours. Be wary of over-fitting: confirm the best settings on a date range you didn't optimise on.

## 2. Paper trade (demo account)

1. Open a **demo account** with any MT5 broker (File → Open an Account).
2. Attach the EA to an XAUUSD M15 chart, enable **Algo Trading** in the toolbar.
3. Let it run for several weeks and compare the results with the backtest before considering real money.

## Notes

- Point size differs between brokers (gold is usually 2 decimals, so 1 point = $0.01). Adjust the point-based inputs if your feed uses 3 decimals.
- Session hours use the broker's server time. The defaults assume a GMT+2 (winter) / GMT+3 (summer) server, which most MT5 brokers use. On that clock London opens at 10:00 and New York at 15:00 all year. If your broker's clock is different, shift the hours: London is 08:00–17:00 UK time and New York is 08:00–16:00 New York time. The NY window stops at 23:00 to avoid the wide spreads around the daily rollover.
- Open positions are not closed when a session ends; they run to their stop or target.
- If the stop distance needs less than the broker's minimum lot size, the trade is skipped rather than over-risked.
