# Trading-bot

A MetaTrader 5 Expert Advisor that trades **Fair Value Gaps (FVGs) on XAU/USD, 15-minute chart**.

## Strategy

An FVG is a three-candle imbalance:

- **Bullish FVG**: candle 1's high is below candle 3's low. The EA places a **buy limit at the top edge of the gap** (candle 3's low) and waits for price to retrace into it.
- **Bearish FVG**: candle 1's low is above candle 3's high. The EA places a **sell limit at the bottom edge of the gap** (candle 3's high).

| Rule | Default |
|---|---|
| Stop loss | Beyond candle 1's extreme + $0.50 buffer (switchable to the far gap edge) |
| Take profit | 2R (twice the stop distance) |
| Breakeven | At 1R profit the stop moves to entry + $0.10 (covers the spread) |
| Risk | 1% of balance per trade, sized from the stop distance |
| Min gap size | $1.00 |
| Displacement | Middle candle must close in the gap's direction |
| Trend filter | Buys only when the last closed H1 candle is above the 200 EMA, sells only when below |
| Sessions | London 08:00–17:00 UK time and New York 08:00–16:00 NY time, summer time handled automatically; unfilled orders are cancelled outside them |
| Unfilled orders | Cancelled after 16 bars (4 hours); a newer FVG replaces an older unfilled order |
| Max positions | 1 |
| Daily kill switch | Closes everything and stops for the day at a 3% equity drawdown |
| Spread filter | No new orders when the spread is above $0.50 |

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

1. Open an **Exness MT5 demo account** (or any MT5 broker's demo) and log in to it from MT5.
2. Attach the EA to an XAUUSD M15 chart, enable **Algo Trading** in the toolbar.
3. Let it run for several weeks and compare the results with the backtest before considering real money.

## Notes

- **Broker:** built and documented for [Exness](https://www.exness.com) (FSCA-regulated in South Africa, ZAR accounts), but it works with any MT5 broker. Distances are set in dollars, so it doesn't matter whether a broker quotes gold to 2 or 3 decimals, and it trades whatever gold symbol it's attached to (`XAUUSD`, `XAUUSDm`, ...).
- **Server clock:** the sessions are set in London and New York local time, and the EA converts from the broker's server clock. On a live or demo account it detects the server's offset automatically. In the Strategy Tester it can't, so it uses `InpServerGmtOffset` (default 0; Exness servers are usually GMT+0, but confirm this). Check by comparing the Market Watch clock in MT5 with UTC. For a GMT+2/+3 broker, set `InpServerClock` to "GMT+2, GMT+3 during US summer time".
- Open positions are not closed when a session ends; they run to their stop or target.
- If the stop distance needs less than the broker's minimum lot size, the trade is skipped rather than over-risked.
