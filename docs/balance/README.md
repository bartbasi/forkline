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

**Added for the 2026-10-25 campaign pass.**

- `mode=need`: no plays. Works out the flyer cost and the walker cost of a level (count times lives, bosses included) and
  which lone attackers RULES 12.6 says need a search. A tower that cannot hit flyers needs none when the flyers cost 6 lives
  or more; the Firework Tower needs none when the walkers do.
- `stop_dry=N` on a search: stop when N builds are tried and none has won (RULES 12.6: 2500 of the 6000). The result says
  `stopped_dry`. `run_pass_post.sh` plays a dry search in full when its partner won something.
- `mode=replay from=FILE,FILE pick=best_win|three_star_best|top|all`: plays strategies saved in search results again, on the level
  as it is now. It takes every what-if the other modes take (`level_file=`, `towers=`, `enemies=`, `stat=`, `tweak=`,
  `twist=1`, `relaxed=1`) and `max_tier=N` (no tower above tier N). `from=plain` plays the plain recipe at every gate
  placement. Each row has the saved result next to the new one, lives lost by creature type (`leaks`, and `leaks_wave` by the
  wave the creature came from), kills, and for every flying boss its health a quarter, a half and three quarters of the
  way along its line and how it ended. A cheap first screen for any what-if: no search is needed.
- `mode=plain max_tier=N`: the plain recipe with no tower above tier N.
- `Bot.play(..., watch)`: a play that records events. It only reads, so a watched play gives the same result as an unwatched one.
- `run_special.sh` parts: 1 (every level watched, random play under every Twist, tier caps on 3-4 and 3-5), 2 (the saved
  champions of 3-4 to 3-6 watched), 3 (any-tower searches with the banned tower left out, for 3-4 and 4-2: the plain any-tower
  search misses builds that avoid a tower), 4 (longer Twist searches), 5 (the 3-4 champions at tiers 3, 2 and 1).
  `run_whatif_b3.sh` plays star 3 what-ifs on the failing levels (2500 build screens), and with `CHECKS=1` the 6000 build checks
  of the rules a report recommends. A 2500 build screen can miss (3-2 "at most 5 towers" in the 2026-10-25 report).
  Do not overwrite a script while a copy of it is running: bash reads it as it goes.
- `run_pass.sh` now follows RULES 12.6 as revised by G2 (two lone searches of 6000 builds per attacker that needs one,
  stopping at 2500 when dry), takes `SEED_SHIFT`, and can run as several workers on one folder (a lock folder per job).
  `run_pass_post.sh` does what needs the first jobs: dry pairs in full, determinism again in a new process, timing.
  `run_special.sh` has the extra jobs of the 2026-10-25 report (who costs the lives, the Moon Moth, Dusk Moths, random play
  under every Twist). `summary.gd pass=1` prints every table, special ones included.

Two more tools: `benchmark.gd` times each tick, and `run.gd mode=det` plays the same things twice
(and once with a save and load in the middle of a wave) and checks the results match.

## Runs and the daily (task B2)

Reports: `runs-<date>.md`. Raw numbers: `raw/<date>-b2/`. The run bots drive `RunSession` (ARCHITECTURE 3.3) and
choose cards as well as towers. They are in `run_bot.gd`, and the runner is `runs.gd`.

A **run strategy** has three parts. A pick style: `towers` (a tower card first, then a perk, a spare gate, an economy
card, a risk card last), `economy` (economy first, but a tower card while the run has fewer than 2 kinds of tower), `risk`
(a risk card whenever one is offered) or `random` (any offered card). A build style: `wide` (new towers first, up to 4 plus
0.7 per wave started) or `tall` (upgrades first, 2 plus 1 per 4 waves). Early calls, off or on (from wave 4, when 6 or fewer
creatures are on the map). Together that is 16 named strategies (`towers_wide`, `towers_wide_early`, and so on). All of
them place gates on the socket that puts the most build spots within 2.5 tiles of the walking route, buy during waves as
gold comes in, and sell one tower only to make room for a tower type they have never built. Within a kind, the card is
chosen by the bot's own generator, seeded from the run seed and the strategy id. A tower is chosen by the lowest count over
weight (Sling Post 1.5, Catapult 1.0, Longbow 1.0, Firework 0.7, Bell 0.8 up to 2, Bakery 0.8 up to 1, each weight
changed by 0.7 to 1.3 times per bot). Spots are ranked by the road they see, as in the plain recipe (RULES 12.6).

A **random strategy** (`mode=search` and the extra tries of `mode=daily`) takes a random order of the five card kinds, a
random pace (`base` 2 to 6 towers plus `rate` 0.1 to 1.0 per wave) and a random early call habit. They are seeded from the
run seed, so the same seed always tries the same strategies in the same order.

Modes of `runs.gd`:

- `rates`: the 16 named strategies on run seeds `first` to `first + count - 1`, with `pool=base` (no unlocks: the 22 base
  cards) or `pool=all` (every card), and `relaxed=0` or `1`. Run `i` has the seed `i * 2654435761 mod 2^32`.
- `search`: `n` random strategies on each run seed. A seed is "winnable" when one of them wins.
- `daily`: day `n` is 2026-10-25 plus `n` days, with the seed YYYYMMDD, Normal, every card. The 16 named strategies play it,
  and a day none wins gets up to `extra` random strategies.
- `det`: for 50 seeds and 50 days, the map and waves built twice; the same play twice; a play saved and loaded again (through
  JSON text, the way a saved game is read) in the middle of a wave; and a play saved and loaded with a draft open, which
  must show the same offers. All must end in equal battle and run state. A second process must give the same chain hash.
- `risk`: one strategy plays seeds with a saved battle before each wave. Each saved wave is then played again with each
  risk card on it, on the same towers, and the peak creatures, lives lost and gold gained are recorded.
- `static`: the stacks (each top, middle and bottom that fit), and the creatures each pack wave spawns with each risk card.
- `cardvalue`: a random-picking strategy plays seeds; before each pick the state is saved, each of the 3 offered cards is taken in
  turn, and the run is played on to its end by the same strategy. A card's gain is its result less the average of the 3 offered.
- `deep`: `days=2026-11-11,... n=400` plays `n` random strategies on each named day (the days that were left unwon).
- `boss=ironshell` on `rates` and `daily` plays only the seeds (days) whose run has that boss (used to play Ironshell again after a
  stat change).
- `bakery_min=1`: a bot builds a Bakery that reaches only one other spot (the default is 2, as in the plain recipe).
- `tweak=strength_step:8,strength_start:100,start_gold:300,gates:1,tea_break:5` changes those `run.json` numbers, or the lives Tea
  Break gives, in memory only.

`run_runs.sh` is the job list and its seeds. `runs_summary.gd dir=PATH` prints the report's tables from the raw folder (`part=det|rates|search|length|waves|boss|maps|towers|cards|daily|risk|cardvalue|whatif|ironshell|lives`). Jobs added by hand are in `extra_jobs.txt` of the raw folder.
Length at 1x is the wave time plus 15 s for each build phase, the same rule as for levels (RULES 12.5).

## Files

- `tools/balance/bot.gd`: strategies, the generator and mutator, the plain recipe, the player.
- `tools/balance/run.gd`: spread, search, recipes and determinism runs, with `tweak=` and `stat=`
  what-ifs that edit a level or tower numbers in memory only.
- `tools/balance/benchmark.gd`: time per tick and peak creatures (`twist=1` for a Twist).
- `tools/balance/compare_raw.gd`: compares two raw folders file by file (see "Checking the bots"
  below).
- `tools/balance/summary.gd`: turns the raw JSON into the report's markdown tables. `pass=1` prints the tables of
  a `run_pass.sh` run (plain, solo, search, spread, Twist, determinism and benchmark files, and the what-if
  files of `run_whatif_b1.sh`). Without it, the old region 1 tables.
- `tools/balance/run_bot.gd`, `runs.gd`, `runs_summary.gd`, `run_runs.sh`: the run and daily bots, runner, tables and job list (above).
- `tools/balance/run_region1.sh`, `run_whatif.sh`, `run_stats.sh`: the exact job lists and seeds.
- `tools/balance/run_pass.sh`, `run_pass_post.sh`, `run_special.sh`, `run_whatif_b3.sh`: the job lists and seeds of the 2026-10-25
  campaign pass (raw folder `raw/2026-10-25-b3/`, report `campaign-2026-10-25.md`, `SEED_SHIFT=100000`).
- `tools/balance/run_pass.sh` and `run_whatif_b1.sh`: the job lists of the B1 pass (2026-10-24, raw folder
  `raw/2026-10-24-b1/`) and its star 3 what-ifs (other rules tried with `tweak=star3:...`, and a level file with
  Flitters added to 2-3).
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
it uses are in the script's header. `EVALS` sets the builds per search (default 3000; the B1 pass used 2500).
Then `summary.gd dir=... pass=1` prints the tables. Run it from a clean checkout of the commit being measured:
other agents edit the working tree, and a half-written data file stops a job with exit code 2 and no output file.

**What-ifs on star 3 rules.** `tweak=star3:KIND;N` replaces the level's star 3 rule in memory (`tier_at_most;2`,
`towers_at_most;5`, `gates_at_most;1`, `early_calls_at_least;6`, `kinds_at_most;3`, `tower_ban;ID`, `no_lives_lost`).
`run_whatif_b1.sh` plays an any-tower search and one lone-attacker search per attacking tower for each rule.

**Plain mode rows** hold `lives_at` (lives when each wave starts), so a report can say in which wave lives were lost.
When `compare_raw.gd` compares a plain file made before B1, add `lives_at` to its `ignore` list.
