# Balance reports

Owner: balance-analyst. Reports are dated: `region1-2026-10-23.md`, and so on. Raw numbers are
in `raw/<date>/`, one JSON file per job, so every number in a report can be checked.

## How the bots work

Battles have no randomness (ARCHITECTURE 3.1), so a level plus the player's choices gives one
result. The bots search over the choices. Every random draw comes from a generator seeded from a
number printed in the report, so a run can be repeated.

A **strategy** is: which tower on which spot, which upgrades and in what order, which tier 3
path, a targeting mode for each tower, which socket gets the gate, when to call waves early, and
whether to buy during waves. The bot buys strictly in its order and waits when the next item costs
too much. It uses only the public `Battle` API (`place_tower`, `upgrade_tower`, `set_aim`,
`place_gate`, `start_next_wave`, `step`, `result`).

Three kinds of runs:

- **spread**: random strategies in three styles, each played on Normal and on Relaxed.
  - casual: a tower on every spot, no upgrades, usually no gate, never calls early.
  - typical: most spots, some upgrades, a gate or none, never calls early.
  - skilled: any number of spots, any upgrades, targeting, early calls.
  Random strategies are worse than a thinking player. Read the rates as a floor, and use them to
  compare levels, not as a prediction of how people will do.
- **search**: a seeded search for good strategies. It starts from random ones, then copies the best
  with one to three small edits. Fitness is a win first, then star 2, then star 3, then lives left.
  `only=` limits the towers it may use. Finding a three-star win proves one exists. Finding none
  does not prove there is none, so the reports give how many builds were tried.
- **recipes**: a dozen plain recipes a new player might follow, such as "a Sling Post on every
  spot, then one upgrade each". Nothing in them is random.

Two more tools: `benchmark.gd` times each tick, and `run.gd mode=det` plays the same things twice
(and once with a save and load in the middle of a wave) and checks the results match.

## Files

- `tools/balance/bot.gd`: strategies, the generator and mutator, the player.
- `tools/balance/run.gd`: spread, search, recipes and determinism runs, with `tweak=` and `stat=`
  what-ifs that edit a level or tower numbers in memory only.
- `tools/balance/benchmark.gd`: time per tick and peak creatures.
- `tools/balance/summary.gd`: turns the raw JSON into the report's markdown tables.
- `tools/balance/run_region1.sh`, `run_whatif.sh`, `run_stats.sh`: the exact job lists and seeds.
- Run everything from the repo root. Nothing here is exported (the export filter excludes `tools/*` and `docs/*`).
