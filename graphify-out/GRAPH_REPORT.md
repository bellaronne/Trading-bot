# Graph Report - Trading-bot  (2026-11-20)

## Corpus Check
- 28 files · ~59,238 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 4 file(s) not represented in the graph (top: (none) 3, .mq5 1)

## Summary
- 768 nodes · 1773 edges · 19 communities
- Extraction: 98% EXTRACTED · 2% INFERRED · 0% AMBIGUOUS · INFERRED: 36 edges (avg confidence: 0.87)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `f3bb0773`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- Trading-bot
- scan.py
- entry.py
- timemachine.py
- news.py
- ticket.py
- exit.py
- datetime
- size.py
- json
- ptr.py
- facts.py
- trader-scanner
- trader-budget
- trader-pelosi
- trader-broker
- trader-risk
- trader-exit
- trader-timemachine

## God Nodes (most connected - your core abstractions)
1. `cmd_orb()` - 23 edges
2. `evaluate()` - 20 edges
3. `build_plan()` - 20 edges
4. `check()` - 20 edges
5. `watch_loop()` - 17 edges
6. `main()` - 17 edges
7. `ScanError` - 17 edges
8. `time_machine()` - 17 edges
9. `cmd_watch()` - 16 edges
10. `PlanError` - 16 edges

## Surprising Connections (you probably didn't know these)
- `Step 3: read a report` --references--> `fetch()`  [INFERRED]
  .claude/skills/trader-pelosi/SKILL.md → .claude/skills/trader-alerts/alerts.py
- `What it reads and writes` --references--> `sec_user_agent()`  [INFERRED]
  .claude/skills/trader-news/SKILL.md → .claude/skills/trader-news/news.py
- `Example: the reel` --references--> `check()`  [INFERRED]
  .claude/skills/trader-alerts/SKILL.md → .claude/skills/trader-risk/check.py
- `Steps` --references--> `check()`  [INFERRED]
  .claude/skills/trader-alerts/SKILL.md → .claude/skills/trader-risk/check.py
- `trader-analyst` --references--> `sec_user_agent()`  [INFERRED]
  .claude/skills/trader-analyst/SKILL.md → .claude/skills/trader-news/news.py

## Import Cycles
- None detected.

## Communities (19 total, 0 thin omitted)

### Community 0 - "Trading-bot"
Cohesion: 0.22
Nodes (8): 1. Backtest (Strategy Tester), 2. Paper trade (demo account), Claude Code skills, Files, Install, Notes, Strategy, Trading-bot

### Community 1 - "scan.py"
Cohesion: 0.05
Nodes (52): _absorb(), build_universe(), chart_path(), classify(), clock_label(), cmd_daily(), cmd_orb(), confirm() (+44 more)

### Community 2 - "entry.py"
Cohesion: 0.06
Nodes (48): ampm(), bar_line(), chart_path(), chart_range(), cmd_check(), cmd_watch(), emit(), on_trigger() (+40 more)

### Community 3 - "timemachine.py"
Cohesion: 0.05
Nodes (43): build_pool(), cents_away(), chart_result(), chart_url(), clock12(), clock24(), cmd_chart(), cmd_run() (+35 more)

### Community 4 - "news.py"
Cohesion: 0.05
Nodes (42): Example: the reel's stock, Safety, Steps, The rules, trader-analyst, What it never does, What it reads and writes, cik_map() (+34 more)

### Community 5 - "ticket.py"
Cohesion: 0.09
Nodes (44): amount_numbers(), apply_fill(), _clock(), cmd_approve(), cmd_decline(), cmd_fill(), cmd_flatten(), cmd_log() (+36 more)

### Community 6 - "exit.py"
Cohesion: 0.08
Nodes (39): ampm(), atr_of(), build_plan(), cents(), cmd_plan(), cmd_show(), compute(), D() (+31 more)

### Community 7 - "datetime"
Cohesion: 0.06
Nodes (39): Example: the reel, Quotes, Rule types, Rules, Safety, Steps, The NYSE clock, trader-alerts (+31 more)

### Community 8 - "size.py"
Cohesion: 0.07
Nodes (35): allocate(), bracket_order(), eastern_offset(), eastern_to_utc(), _f(), fresh_price(), load_config(), load_prices() (+27 more)

### Community 9 - "json"
Cohesion: 0.09
Nodes (38): active(), AlertError, cmd_add(), cmd_check(), cmd_clock(), cmd_list(), cmd_quote(), cmd_reset() (+30 more)

### Community 10 - "ptr.py"
Cohesion: 0.07
Nodes (31): Example: the reel, Rules, Safety, Steps, The rule, trader-entry, What it never does, What it reads and writes (+23 more)

### Community 11 - "facts.py"
Cohesion: 0.08
Nodes (24): analyse(), changes(), clean_title(), _date(), exhibit_name(), facts_for(), FactsError, Fetcher (+16 more)

### Community 12 - "trader-scanner"
Cohesion: 0.17
Nodes (11): Data and limits, Example: the reel, Rules, Safety, Steps, The daily scan (before the open), The opening-range breakout scan (during the session), The universe (+3 more)

### Community 13 - "trader-budget"
Cohesion: 0.18
Nodes (10): Example: the reel, Rules, Safety, Step 1: set the rules once, Step 2: size the trade, Step 3: show the user, trader-budget, Weights mode (kept from v1) (+2 more)

### Community 14 - "trader-pelosi"
Cohesion: 0.18
Nodes (10): Example: a real alert, Safety, Step 1: what has been filed, Step 2: watch for new ones, Step 3: read a report, The rules, The Senate: the manual route, trader-pelosi (+2 more)

### Community 15 - "trader-broker"
Cohesion: 0.20
Nodes (9): Example: the reel, Safety, Setup A: Alpaca (official MCP server, Claude Desktop), Setup B: Interactive Brokers (connector in Claude's directory), Steps: the entry, Steps: while it is open, and out by the close, trader-broker, What it never does (+1 more)

### Community 16 - "trader-risk"
Cohesion: 0.20
Nodes (9): Entries and exits, Example: the reel, Rules, Safety, Steps, The checks, trader-risk, What it never does (+1 more)

### Community 17 - "trader-exit"
Cohesion: 0.22
Nodes (8): Example: the reel, Rules, Safety, Steps, Stops and targets, trader-exit, What it never does, What it reads and writes

### Community 18 - "trader-timemachine"
Cohesion: 0.22
Nodes (8): Example: the reel, How it works, Rules, Safety, Steps, trader-timemachine, What it never does, What it reads and writes

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `fetch()` connect `json` to `trader-pelosi`?**
  _High betweenness centrality (0.026) - this node is a cross-community bridge._
- **Should `scan.py` be split into smaller, more focused modules?**
  _Cohesion score 0.05249569707401033 - nodes in this community are weakly interconnected._
- **Should `entry.py` be split into smaller, more focused modules?**
  _Cohesion score 0.060833902939166094 - nodes in this community are weakly interconnected._
- **Should `timemachine.py` be split into smaller, more focused modules?**
  _Cohesion score 0.05359937402190924 - nodes in this community are weakly interconnected._
- **Should `news.py` be split into smaller, more focused modules?**
  _Cohesion score 0.052083333333333336 - nodes in this community are weakly interconnected._
- **Should `ticket.py` be split into smaller, more focused modules?**
  _Cohesion score 0.09095716552088842 - nodes in this community are weakly interconnected._
- **Should `exit.py` be split into smaller, more focused modules?**
  _Cohesion score 0.0807909604519774 - nodes in this community are weakly interconnected._