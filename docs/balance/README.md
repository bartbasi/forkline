# Balance reports

Owner: balance-analyst. Reports are dated: `region1-2026-10-23.md`, `region1-2026-10-24.md`, and so on. Raw numbers are
in `raw/<date>/`, one JSON file per job, so every number in a report can be checked.

## How the bots work

Battles have no randomness (ARCHITECTURE 3.1), so a level plus the player's choices gives one
result. The bots search over the choices. Every random draw comes from a generator seeded from a
number printed in the report, so a run can be repeated.

A **strategy** is: which tower on which spot (any of the six towers, Bells and Bakeries included),
which upgrades and in what order, which tier 3 path, a targeting mode for each attacking tower,
which sockets get gates (as many as the level or Twist gives), when to call waves early, and
whether to buy during waves. The bot buys strictly in its order and waits when the next item costs
too much. It uses only the public `Battle` API (`place_tower`, `upgrade_tower`, `set_aim`,
`place_gate`, `start_next_wave`, `step`, `result`).

Six kinds of runs (exhaust came with the 2026-10-24 report, plain with the B1 bots):

- **spread**: random strategies in three styles, each played on Normal and on Relaxed.
  - casual: a tower on every spot, no upgrades, usually no gate, never calls early.
  - typical: most spots, some upgrades, a gate or none, never calls early.
  - skilled: any number of spots, any upgrades, targeting, early calls.
  Random strategies are worse than a thinking player. Read the rates as a floor, and use them to
  compare levels, not as a prediction of how people will do.
- **search**: a seeded search for good strategies. It starts from random ones, then copies the best
  with one to three small edits. Fitness is a win first, then star 2, then star 3, then lives left.
  `only=` limits the towers it may use. `only=solo:sling_post` is one attacking tower plus every
  Bell and Bakery the level offers, which is the "no super tower" search of RULES 12.6 (run at least
  2500 builds). Finding a three-star win proves one exists. Finding none does not prove there is
  none, so the reports give how many builds were tried.
- **recipes**: a dozen plain recipes a new player might follow, such as "a Sling Post on every
  spot, then one upgrade each". Nothing in them is random. These sixteen recipes are the region 1
  recipes of the 2026-10-23 and 2026-10-24 reports and use only Sling Posts and Catapults.
- **plain**: the plain mixed recipe of RULES 12.6, exactly as written there (`Bot.plain_recipe`). It
  ranks the spots by road seen within 2.5 tiles, puts one Bakery on the spot with the most
  neighboring spots (when it has 2 or more), one Bell on the third spot (the fourth if the Bakery
  has the third), and gives the other spots the level's attacking towers in turn: Sling Post,
  Catapult, Longbow, Firework (only on levels whose waves bring flyers, or a boss that flies or
  releases flyers). It builds everything, then upgrades everything to tier 2 (Bakery last each
  time), and from region 2 on takes every attacker to tier 3 on its first path. It is played once
  for every gate placement that seals no entrance (none included), on Normal and on Relaxed. Best
  placement is the win with the most lives, else the loss that clears the most waves. The result
  also holds the wave sizes (a Puffball counts as itself plus its Puffs) and the largest wave.
  The region comes from the level id (`r2_l3` is region 2). `compare_old=1` plays the old region 1
  recipe too and lists any difference. On region 1 it finds none.
- **exhaust**: every static build of at most N towers (`max_towers=`), with every spot choice, upgrade
  depth, tier 3 path, purchase order, aim, gate choice, buying during waves or not, and early calls
  off or on. It runs in shards (`shard=K shards=N`). A miss here is a proof for that family of builds,
  not a sample. Used on 1-3, where the star 3 limits the tower count.

**Twists.** `twist=1` on any mode plays the level with its Twist (`level.twist_effects`, passed to
`Battle.create`). A banned tower is not offered to the bot, the gates in hand are what the Twist
leaves, and a Twist's fixed gates are already placed. Twists have no stars, so the search only
asks for a win, then lives. The bots read the level's own Twist, so a Twist that the sim refuses
stops the run with exit code 2.

Two more tools: `benchmark.gd` times each tick, and `run.gd mode=det` plays the same things twice
(and once with a save and load in the middle of a wave) and checks the results match.

## Files

- `tools/balance/bot.gd`: strategies, the generator and mutator, the plain recipe, the player.
- `tools/balance/run.gd`: spread, search, recipes and determinism runs, with `tweak=` and `stat=`
  what-ifs that edit a level or tower numbers in memory only.
- `tools/balance/benchmark.gd`: time per tick and peak creatures (`twist=1` for a Twist).
- `tools/balance/compare_raw.gd`: compares two raw folders file by file (see "Checking the bots"
  below).
- `tools/balance/summary.gd`: turns the raw JSON into the report's markdown tables.
- `tools/balance/run_region1.sh`, `run_whatif.sh`, `run_stats.sh`: the exact job lists and seeds.
- `tools/balance/run_rerun.sh` and `run_exhaust.sh`: the job lists and seeds of the 2026-10-24 report
  (fresh seeds, two single tower searches per tower, the exhaustive 1-3 check, longer searches).
- `run.gd` also takes `level_file=PATH`, `towers=PATH` and `enemies=PATH`, which play other
  level and stat files than the ones in `data/`, for what-ifs on waves and numbers without touching
  the data. Since 2026-10-24 the tower use counts in a search result (`three_star_builds_using`) are
  what stood at the end of each play. In the 2026-10-23 report they counted what the strategy planned.
- Run everything from the repo root. Nothing here is exported (the export filter excludes `tools/*` and `docs/*`).

## Checking the bots after a change

The region 1 numbers of the 2026-10-24 report must not move when the bots change, unless the change
is meant to move them. `run_bots_check.sh` plays a set of those jobs again with the same seeds into a
new folder (searches, spreads, recipes, determinism runs and the plain recipe). `compare_raw.gd` then
compares each file with the old one:

```
bash tools/balance/run_bots_check.sh 2026-10-24-bots 4
godot --headless --path . --script res://tools/balance/compare_raw.gd -- old=res://docs/balance/raw/2026-10-24 new=res://docs/balance/raw/2026-10-24-bots ignore=digest,chain_hash,search_hash
```

The `ignore` keys are hashes of the saved battle. The sim's save format changed in phase 7, so they
differ from the 2026-10-24 files although every play is the same. Everything else must be identical.
A strategy file keeps its old shape for a level with one gate (`"gate": [x, y]`). A second or third
gate goes in `"more_gates"`.

`mode=plain compare_old=1` on a region 1 level lists any difference between the plain recipe and the
old recipe. It must list none.

## One pass

`run_pass.sh DATE JOBS [levels]` writes the job list of a whole pass (all levels of campaign.json by
default, Twists included) and runs it, at most JOBS at once. `DRY=1` only writes `jobs.txt`. The seeds
it uses are in the script's header. `EVALS` sets the builds per search (default 3000). `summary.gd`
does not yet turn the `plain`, `solo` and Twist files into tables; B1 adds that.
