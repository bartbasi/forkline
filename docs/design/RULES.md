# Forkline rules, version 1

Approved by Bart at hard stop A, 2026-10-23. Owner: game designer.

Phase 4 additions, 2026-10-23. No number changed. Added: the Puff's card line and the word "pop" (6.6), tower plurals (5.9), and the answers to the contract's open points: pausing on a size change (4.7), leaving and coming back (4.10), early calls in runs (4.9, 14.4), where released creatures appear (6.2, 6.3), Gateless Night (14.5) and Iron Gate (7.6, 14.6).

Names follow docs/art/NAMES.md as the game designer reviewed it on 2026-10-23. Bart still has to see the final name list. The tables in 5.1, 5.3 to 5.8, 6.1, 6.3 and 12.1 give each tower, tier 3 path, creature, boss and region its id from that list, so the data files have one source. In each tower's tier table, the first tier 3 row is spec 0 and the second is spec 1.

This file holds every game rule and number for version 1. The sim engineer, level designer, roguelite engineer, balance analyst and UI engineer build from it. If something here is unclear or seems to conflict with docs/ARCHITECTURE.md, ask the DM. Do not guess.

The numbers are starting values. The balance bots tune them, and every change comes back into this file through the game designer. data/stats/ holds this file's tower, creature and core rule numbers, with the names, plurals and card lines, as data in the contract's units (milliseconds, and hundredths of a tile). This file and those files change together, in the same step. Section 17 answers the assumptions in the first draft of docs/ARCHITECTURE.md. Section 19 is written for Bart. It holds no rules, and nobody builds from it.

## Contents

1. Design pillars
2. Words, units and rounding
3. The map
4. Core loop
5. Towers
6. Creatures
7. Gates and routes
8. How combat resolves
9. Information on screen
10. Stars
11. Relaxed difficulty
12. Campaign
13. Twists
14. Roguelite mode
15. Daily challenge
16. Progression
17. Answers to the architecture assumptions
18. Brief section 3 coverage
19. For Bart at hard stop A

## 1. Design pillars

These come from brief section 2. Each rule below serves at least one of them.

| Pillar | Where the rules use it |
|---|---|
| Real choices keep players coming back, most of all the moment two towers click together | Six towers with clear counters (5.1), two tier 3 paths each, pairs to discover (5.11), star challenges (10.3) |
| Players hate ads and pay to win | Everything is earned by playing (16). Unlocks add variety, never power (14.6) |
| Hand-built levels beat generated ones | Every campaign map and wave is hand-built (12). Runs join hand-built segments and hand-built wave packs (14) |
| Clarity over count, no super tower | Every number is shown (9). Combat has no randomness (8.1). No tower is best everywhere (5.10) |
| No ambushes | Wave preview before every wave (9.1). One new thing per wave, each with an info card (9.2, 12.5) |
| Short sessions | Levels take 5 to 10 minutes (12.5). Runs take 15 to 20 minutes (14.1). Pause at any moment (4.7) |
| Path control without fiddly mazes | A few gates on hand-built forks (7) |
| Roguelite runs drive replay | Short seeded runs with card drafts (14) and a daily run (15) |
| Cozy and bright for everyone | Gentle names and one-line cards (5.9, 6.6). Defeated creatures pop into sparkles. No blood |

## 2. Words, units and rounding

| Word | Meaning |
|---|---|
| Tile | One square of the map grid. All distances are in tiles. |
| Creature | Any enemy. A walker or a flyer. |
| Walker | A creature that follows roads. |
| Flyer | A creature that flies straight to the base. It ignores roads and gates. |
| Tower | Anything the player builds on a build spot. |
| Attacking tower | Sling Post, Pumpkin Catapult, Longbow Loft, Firework Tower. Bells and Bakeries do not attack. |
| Build spot | A tile where one tower can stand. |
| Gate socket | A road tile where a gate can go. |
| Entrance | Where creatures appear. Marked A, B, C, D on the map. Level data numbers them 1 to 4. |
| Base | The road tile creatures try to reach. |
| Wave | One numbered set of creatures. It is made of groups. |
| Group | One creature type, a count, an entrance, a start time and a gap between creatures. |
| Build phase | The calm time before each wave. Nothing moves. |
| Wave phase | The time while any wave is on the map. |
| Strength | A whole percent on each wave. 100 means the base numbers in this file (6.4). |

Units:

- Distances are in tiles, measured in a straight line between centers.
- Speeds are in tiles per second.
- Times are in seconds. Every time in this file is a multiple of 0.1 s, so it is a whole number of ticks.
- The sim's tick length is set in docs/ARCHITECTURE.md (its first draft uses 50 ms). All rules here are written in seconds.

Rounding:

- Round half up to a whole number for health, heal amounts and gold scaled by strength (bounties, clear bonuses, risk card rewards), and for percent changes to gold or damage. Example: 52.5 becomes 53.
- Refunds round down.
- The early call bonus rounds up.
- Health and bounty are never below 1.
- Speeds, positions, slows and attack rates follow the contract's integer math in fine sub-units. Any rounding there is far below what a player can see.

## 3. The map

### 3.1 Grid

- A map is 7 tiles wide and 8 to 13 tiles tall. Row 0 is the top row. Rows count down the screen. Columns count left to right.
- South means one row down, north one row up, west one column left, east one column right.
- Why 7 wide: the Fold5 cover screen is 344 dp wide. Seven tiles keep each tile at about 49 dp there, so every build spot and gate socket is a 48 dp touch target (contract section 7.4).
- Heights: region 1 maps are 8 to 11 rows, so the first maps are small and easy to read. Regions 2 to 4 use 10 to 13 rows. Run maps are 13 rows (14.2).
- Every range and speed in this file assumes a 7-wide grid, and all of them are in tiles.
- The landscape layout shows the same grid. Grid directions never change with the screen.

### 3.2 Tile kinds

| Kind | Rule |
|---|---|
| Road | Walkers move on road tiles. |
| Build spot | Holds one tower. Never a road tile. |
| Gate socket | A road tile where a gate can go. Never an entrance or the base. |
| Entrance | A road tile on the map edge where creatures appear, walkers and flyers alike. A level has 1 to 4. |
| Base | One road tile. A walker that reaches its center has got through. |
| Scenery | Everything else. Nothing happens there. |

### 3.3 Roads

- Roads are one tile wide.
- Road tiles connect north, south, east and west. Never diagonally.
- Roads may fork and join again. That is the point of every map.
- With no gates placed, every entrance must reach the base.
- Creatures never block each other. Any number can share a tile.

### 3.4 Build spots

- One tower per spot.
- Spot order is cell order: row by row from the top, left to right within a row. Towers act in that order every tick (8.1).
- Limited spots are part of the puzzle. Suggested counts:

| Region | Build spots per level |
|---|---|
| 1 | 5 to 7 |
| 2 | 7 to 9 |
| 3 | 8 to 10 |
| 4 | 9 to 11 |

## 4. Core loop

### 4.1 Level flow

1. The level starts in a build phase with the starting gold and lives.
2. The player starts the next wave. A wave phase begins.
3. Creatures come down the roads and fly toward the base. Each one that reaches the base costs lives.
4. When every creature of every started wave is gone, and nothing is left to spawn:
   - If the final wave was among them and lives are above 0, the level is won.
   - Otherwise a new build phase begins.
5. If lives reach 0 or less at any moment, the level is lost at once.

### 4.2 Build phase

- No time passes. Nothing moves. There is no timer.
- The player can build, upgrade, sell, change targeting, place, move and remove gates, read the wave preview and tap anything for its numbers.
- It ends only when the player starts the next wave.

### 4.3 Wave phase

- The game runs in real time at the chosen speed.
- The player can build, upgrade, sell, change targeting, tap anything for its numbers, and call the next wave early.
- Gates cannot be touched (7.6).

### 4.4 Lives

| | Normal | Relaxed |
|---|---|---|
| Starting lives, campaign and runs | 20 | 40 |

- A creature that reaches the base costs its lives number (6.1). Most cost 1. Bosses cost 20.
- At 0 lives or fewer, the level or run is lost at once, even in the middle of a wave.

### 4.5 Gold

| Source | Amount |
|---|---|
| Starting gold | Set per level (12.3) and per run (14.1). |
| Bounty | Paid when a tower defeats a creature. Base bounty (6.1) times strength / 100, rounded half up, at least 1. A creature that reaches the base pays nothing. |
| Wave clear bonus | Paid when the last creature of a wave is gone, defeated or through. (20 + 5 times the wave number) times strength / 100, rounded half up. Wave 1 at strength 100 pays 25. Wave 10 at strength 150 pays 105. |
| Early call bonus | 4.9. |
| Selling | 4.6. |

- There is no other income in the campaign. Runs add card effects (14.5).
- There is no gold cap.

### 4.6 Building, upgrading and selling

Building:

- Tap an empty build spot, pick a tower, see its range and cost, confirm.
- The player needs the full cost in gold.
- A new tower can fire at once.

Upgrading:

- Every tower has three tiers. Tier 1 is the build. Tier 2 is one upgrade.
- At tier 3 the player picks one of two specializations. The choice is permanent for that tower. Selling the tower is the only way to choose again.
- Every upgrade shows its cost and its before and after numbers before the player confirms (9.5).

Selling:

- Selling removes the tower at once.
- Each purchase on a tower (the build and each upgrade) is remembered with the phase it was made in.
- Refund = the full price of every purchase on that tower made in the current build phase, plus 70% of every other purchase on it, rounded down.
- A purchase made during a wave phase, even while paused, never refunds in full.

Examples:

- A Sling Post built in this build phase and sold before the wave starts refunds 100.
- A Sling Post built before wave 3 and upgraded to tier 2 during wave 3 refunds 70% of 210, which is 147, whenever it is sold.
- A tower built before wave 2 and upgraded in the build phase before wave 4, then sold in that same build phase, refunds 70% of the build plus the full upgrade price.

All prices are multiples of 10, so 70% is always a whole number.

### 4.7 Pause

- The player can pause at any moment. The sim freezes at once.
- While paused the player can build, upgrade, sell, change targeting, tap anything for its numbers and read the wave preview.
- Calling the next wave works while paused. The wave starts on the same tick, so nothing moves until play resumes.
- Gates stay locked if the game is paused during a wave.
- Opening the Pause menu also pauses.
- Leaving the app during a wave pauses it (4.10).
- Any change of the window's size during a wave pauses the game: folding or unfolding the phone, split screen, or a pop-up window. Bart chose this for folding at hard stop A, and every other size change follows the same rule. The player resumes when ready. In a build phase nothing moves, so a size change there only changes the layout.

### 4.8 Speeds

- Speeds are 1x, 2x and 3x. They change only how fast sim time passes. The same inputs give the same results at every speed.
- Every level and run starts at 1x. The chosen speed then stays until the player changes it.

### 4.9 Calling the next wave early

- During a wave phase, the player can call the next wave once the newest started wave has spawned all of its groups. Puffs and boss summons do not count for this.
- There must be a next wave. The final wave can be called early too, but nothing after it.
- At most 2 waves can be on the map at once. While 2 are running, the next wave cannot be called. This keeps the biggest crowd inside the performance budget.
- The early call bonus is half the bounty of every creature from the newest wave still on the map at that moment, rounded up. Puffs and summons count as part of their wave.
- The call button shows the bonus and updates live. It shrinks as those creatures fall.
- The called wave starts at once. Each wave still pays its own clear bonus.
- Starting a wave from a build phase is not an early call and pays no bonus.
- In a run, the next wave also cannot be called while a card draft is owed (14.4).

### 4.10 Leaving and coming back

- Leaving the app saves the game at that exact moment, even mid-wave (Bart, hard stop A). Coming back resumes it paused, on the Pause menu.
- One game can be saved per mode: one campaign level or Twist, one roguelite run and one daily run. One never ends another. The Continue card resumes the most recent one. The saved level's card, the Roguelite button and the Daily button each resume their own.
- Starting a different campaign level or Twist while one is saved first asks the player. If they confirm, the saved game ends as if it were abandoned from Pause, so nothing is recorded. If they cancel, nothing changes.

## 5. Towers

### 5.1 The six towers

| Tower | Id | Its one job | Hits | The right answer for | Weak against |
|---|---|---|---|---|---|
| Sling Post | `sling_post` | Quick small hits on one target | Walkers and flyers | Bubblers, Skitters, early waves, a backup against flyers | Armor (Shellback, Dusk Moth, Ironshell), big crowds |
| Pumpkin Catapult | `pumpkin_catapult` | Splash on groups | Walkers | Pips, Puffs, packed or drowsy groups | Flyers, Bubblers, fast spread-out walkers, single big targets |
| Lullaby Bell | `lullaby_bell` | Slows walkers in its ring | Walkers (Night Bell: flyers too) | Skitters, Gatecrashers, bosses, making splash hit more | Flyers, builds with no splash. It never defeats anything alone |
| Longbow Loft | `longbow_loft` | Long range, heavy arrows that ignore armor | Walkers | Shellbacks, Gatecrashers, Menders, armored bosses, covering two roads from one spot | Bubblers, Pips and Puffs (wasted arrows), flyers |
| Firework Tower | `firework_tower` | Anti air with splash | Flyers | Flitter flocks, Dusk Moths, the Moon Moth | Every walker. It cannot hit them |
| Bakery | `bakery` | Makes the towers around it attack faster | Nothing | Tight clusters of spots, late waves, bosses | Spread-out spots, early waves when gold is short, Bells (it cannot boost them) |

### 5.2 Rules for all towers

- A creature is in range when the distance from the tower's center to the creature's center is no more than the range.
- An attack hits on the tick it fires. Attacks never miss. Projectiles are only drawn. The render may hold a hit's flash or puff until the drawn projectile arrives, but the sim never waits.
- Every attacking tower has a reload timer. Each tick the timer goes down by the tick length times the tower's rate multiplier (1, or more with a Bakery boost). When the timer is 0 or less and a target is in range, the tower fires and adds its reload time to the timer, keeping any leftover. When the timer is 0 or less and no target is in range, the timer is set to 0 and waits there, so a tower never saves up shots. This keeps every rate exact at any tick length.
- The rate shown on screen is the rate multiplier divided by the reload time, to one decimal.
- Damage is always a whole number.

### 5.3 Sling Post

Quick pebbles at one target. Hits walkers and flyers.

| Tier | Name | Id | Price | Total spent | Damage | Reload (s) | Rate per s | Range | Damage per s |
|---|---|---|---|---|---|---|---|---|---|
| 1 | Sling Post | `sling_post` | 100 | 100 | 6 | 0.5 | 2.0 | 2.5 | 12 |
| 2 | Sling Post | `sling_post` | 110 | 210 | 8 | 0.4 | 2.5 | 3.0 | 20 |
| 3 | Quickshot | `quickshot` | 200 | 410 | 8 | 0.2 | 5.0 | 3.0 | 40 |
| 3 | Stone Sling | `stone_sling` | 200 | 410 | 20 | 0.5 | 2.0 | 3.0 | 40 |

- Quickshot: many small hits. Best against bubbles and crowds of weak creatures. Armor blunts it badly.
- Stone Sling: fewer, bigger hits that get through armor. Hits armored flyers too.

### 5.4 Pumpkin Catapult

Lobs pumpkins that splash every walker near the target. Cannot hit flyers.

| Tier | Name | Id | Price | Total spent | Damage | Reload (s) | Rate per s | Range | Splash radius | Extra |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | Pumpkin Catapult | `pumpkin_catapult` | 120 | 120 | 14 | 2.0 | 0.5 | 3.0 | 0.75 | none |
| 2 | Pumpkin Catapult | `pumpkin_catapult` | 130 | 250 | 24 | 2.0 | 0.5 | 3.0 | 0.75 | none |
| 3 | Prize Pumpkin | `prize_pumpkin` | 230 | 480 | 50 | 2.5 | 0.4 | 3.5 | 1.25 | none |
| 3 | Jam Pot | `jam_pot` | 230 | 480 | 24 | 1.5 | 0.7 | 3.0 | 1.0 | Every walker it damages is slowed 40% for 3.0 s |

- Prize Pumpkin: raw splash. Better against fast or spread-out groups and armored groups.
- Jam Pot: control. Its slow makes every other tower in the area better. It fires often enough that every other shot gets past a Bubbler's bubble.

### 5.5 Lullaby Bell

Makes walkers in its ring drowsy and slow. Deals no damage. Has no reload and no targeting.

| Tier | Name | Id | Price | Total spent | Slow | Range | Affects |
|---|---|---|---|---|---|---|---|
| 1 | Lullaby Bell | `lullaby_bell` | 90 | 90 | 35% | 2.0 | Walkers |
| 2 | Lullaby Bell | `lullaby_bell` | 90 | 180 | 45% | 2.5 | Walkers |
| 3 | Hush Bell | `hush_bell` | 170 | 350 | 60% | 2.5 | Walkers |
| 3 | Night Bell | `night_bell` | 170 | 350 | 45% | 3.0 | Walkers and flyers |

- The slow lingers 1.0 s after a creature leaves the ring (8.5).
- A slowed Gatecrasher also breaks gates slower by the same percent (7.7).
- Hush Bell: the strongest slow in the game.
- Night Bell: a wider ring, and the only way to slow flyers.

### 5.6 Longbow Loft

Long range. Heavy arrows ignore armor. Slow to reload. Cannot hit flyers.

| Tier | Name | Id | Price | Total spent | Damage | Reload (s) | Rate per s | Range | Targets per shot | Damage per s |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | Longbow Loft | `longbow_loft` | 150 | 150 | 40 | 2.5 | 0.4 | 4.0 | 1 | 16 |
| 2 | Longbow Loft | `longbow_loft` | 160 | 310 | 70 | 2.5 | 0.4 | 4.5 | 1 | 28 |
| 3 | Giant Bow | `giant_bow` | 280 | 590 | 180 | 3.0 | 0.3 | 5.0 | 1 | 60 |
| 3 | Triple Bow | `triple_bow` | 280 | 590 | 70 | 2.5 | 0.4 | 4.5 | 3 | 28 per target |

- Every tier ignores armor.
- Giant Bow: one giant arrow. The boss killer.
- Triple Bow: three arrows at three different targets. Best against armored groups.

### 5.7 Firework Tower

Bursts that hit every flyer near the target. Cannot hit walkers.

| Tier | Name | Id | Price | Total spent | Damage | Reload (s) | Rate per s | Range | Splash radius | Extra |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | Firework Tower | `firework_tower` | 110 | 110 | 12 | 1.0 | 1.0 | 3.0 | 0.75 | none |
| 2 | Firework Tower | `firework_tower` | 120 | 230 | 20 | 1.0 | 1.0 | 3.5 | 0.75 | none |
| 3 | Star Bloom | `star_bloom` | 210 | 440 | 30 | 1.0 | 1.0 | 3.5 | 1.25 | none |
| 3 | Skyrocket | `skyrocket` | 210 | 440 | 90 | 1.5 | 0.7 | 4.0 | none | One target. Ignores armor |

- Splash from a Firework Tower hits flyers only.
- Star Bloom: huge bursts for big flocks.
- Skyrocket: one heavy rocket for armored flyers and the Moon Moth.

### 5.8 Bakery

Bakes treats that make the towers around it attack faster. Does not attack. Has no targeting.

| Tier | Name | Id | Price | Total spent | Boost to towers it reaches | Reach |
|---|---|---|---|---|---|---|
| 1 | Bakery | `bakery` | 130 | 130 | Attack rate +15% | 1.5 |
| 2 | Bakery | `bakery` | 140 | 270 | Attack rate +25% | 1.5 |
| 3 | Grand Oven | `grand_oven` | 240 | 510 | Attack rate +40% | 1.5 |
| 3 | Spice Kitchen | `spice_kitchen` | 240 | 510 | Attack rate +25% and +2 damage per hit | 1.5 |

- Reach 1.5 covers the eight tiles around the Bakery, diagonals included. It boosts the attacking towers on those tiles.
- It never boosts Bells, other Bakeries or itself.
- Grand Oven: the most speed. Best next to big hitters such as Giant Bows and Prize Pumpkins.
- Spice Kitchen: the +2 damage counts before armor, so it lets quick small hitters such as Quickshots chew through armor.
- Boost rules are in 8.6.

### 5.9 One-line tower cards

These lines appear on the info card the first time a tower is available, and on the build menu.

| Tower or path | Line |
|---|---|
| Sling Post | Quick pebbles at one target. Hits flyers too. Armor blunts it. |
| Pumpkin Catapult | Pumpkins splash every walker near the target. Can't hit flyers. |
| Lullaby Bell | Walkers in its ring get drowsy and slow. Deals no damage. |
| Longbow Loft | Long range. Heavy arrows ignore armor. Can't hit flyers. |
| Firework Tower | Bursts hit every flyer near the target. Can't hit walkers. |
| Bakery | Towers around it attack faster. Doesn't attack. |
| Quickshot | Fires twice as fast. |
| Stone Sling | Big stones that get through armor. |
| Prize Pumpkin | Huge pumpkins, wider splash. |
| Jam Pot | Sticky jam slows every walker it splashes. |
| Hush Bell | Deeper sleep: the strongest slow. |
| Night Bell | A wider ring that reaches flyers too. |
| Giant Bow | One giant arrow. Bosses beware. |
| Triple Bow | Three arrows at three targets. |
| Star Bloom | Huge bursts for big flocks. |
| Skyrocket | One heavy rocket that ignores armor. |
| Grand Oven | Even faster towers around it. |
| Spice Kitchen | Faster towers that also hit 2 harder. |

Plurals, for the star 3 line "Build no ..." (10.3): Sling Posts, Pumpkin Catapults, Lullaby Bells, Longbow Lofts, Firework Towers, Bakeries.

### 5.10 Why no tower is best everywhere

Method. These tables come from a rough model, not from the bots. They show useful damage per second for every 100 gold spent, against a steady stream of one creature type, with wasted damage on kills counted and no support towers. Creature spacing: Pips 0.3 s apart, Flitters 0.4 s, Skitters 0.8 s, Scamps 1.0 s, Bubblers and Menders 1.2 s, Shellbacks 1.5 s, Dusk Moths 2.0 s, Gatecrashers 3.0 s, Puffs in their threes. Boss columns use one huge target. The best value in each column is in bold. The balance bots on real maps have the final word.

Tier 1 at strength 100:

| Tower | Scamp | Pip | Skitter | Flitter | Shellback | Bubbler | Puff | Mender | Gatecrasher | Dusk Moth | Ironshell | Moon Moth | Old Tusk |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Sling Post | **11.4** | 12.0 | **12.0** | 12.0 | 4.0 | **8.3** | 12.0 | **10.0** | 8.0 | 2.0 | 2.0 | 6.0 | 4.0 |
| Pumpkin Catapult | 5.6 | **25.0** | 4.2 | 0 | 4.2 | 0 | **15.0** | 4.9 | 4.8 | 0 | 3.3 | 0 | 4.2 |
| Longbow Loft | 10.7 | 3.2 | 8.0 | 0 | **8.0** | 0 | 3.2 | 9.3 | **10.7** | 0 | **10.7** | 0 | **10.7** |
| Firework Tower | 0 | 0 | 0 | **27.3** | 0 | 0 | 0 | 0 | 0 | **6.1** | 0 | **8.2** | 0 |

Tier 3 at strength 220:

| Tower | Scamp | Pip | Skitter | Flitter | Shellback | Bubbler | Puff | Mender | Gatecrasher | Dusk Moth | Ironshell | Moon Moth | Old Tusk |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Quickshot | 9.8 | 7.9 | 8.9 | 8.9 | 4.8 | **8.6** | **7.9** | 8.5 | 7.3 | 3.7 | 2.4 | 6.1 | 4.9 |
| Stone Sling | 8.6 | 6.3 | 8.0 | 8.0 | 7.4 | 6.7 | 6.3 | 8.3 | 8.6 | 7.2 | 6.8 | 8.3 | 7.8 |
| Prize Pumpkin | **11.0** | **15.2** | 2.8 | 0 | 9.9 | 0 | 6.5 | 9.6 | 3.7 | 0 | 3.7 | 0 | 3.8 |
| Jam Pot | 9.2 | 9.0 | 3.1 | 0 | 2.8 | 1.5 | 5.4 | 9.2 | 3.1 | 0 | 2.5 | 0 | 2.8 |
| Giant Bow | 5.0 | 1.5 | 3.7 | 0 | 5.6 | 0 | 1.5 | 8.7 | 9.9 | 0 | **10.2** | 0 | **10.2** |
| Triple Bow | 8.9 | 5.3 | **13.4** | 0 | **13.4** | 0 | 5.3 | **10.4** | **11.9** | 0 | 4.7 | 0 | 4.7 |
| Star Bloom | 0 | 0 | 0 | **25.0** | 0 | 0 | 0 | 0 | 0 | 5.5 | 0 | 6.1 | 0 |
| Skyrocket | 0 | 0 | 0 | 10.0 | 0 | 0 | 0 | 0 | 0 | **13.3** | 0 | **13.6** | 0 |

What the tables show:

- Every attacking tower is best against something, and none is best against everything.
- The Sling Post is the strongest all-rounder at tier 1, and it is the only tower that hurts Bubblers well. It falls to about a third of its value against armor. It is the tower to watch in the bot reports.
- The Stone Sling tops no column, but it is second best against the Dusk Moth and every armored boss, and it is the only tower that is good against both armored walkers and armored flyers. The Jam Pot's value is its slow, which the tables cannot show (see below).
- Each tier 3 pair splits cleanly: Quickshot against bubbles and crowds, Stone Sling against armor; Prize Pumpkin for damage, Jam Pot for control; Giant Bow against bosses, Triple Bow against armored groups; Star Bloom against flocks, Skyrocket against armored flyers.

The support towers, from the same rough model, using a straight road past five spots in a row:

- Bell with splash. Ten Shellbacks at strength 200. Five tier 2 Catapults let 7 through. Four tier 2 Catapults and a tier 2 Bell let 4 through. With a Hush Bell, 3. Drowsy walkers bunch up, so splash hits more of them.
- Bell without splash. With five tier 2 Sling Posts, 7 Shellbacks got through, and swapping one Sling Post for a Bell did not help. Against 24 Scamps at strength 200, five tier 2 Sling Posts let none through. Four and a Hush Bell let 7 through. A Bell is a poor pick in a build of single-target towers.
- Bakery. Sixteen Shellbacks at strength 200 past a cluster of four Quickshots. A fifth Quickshot let 9 through. A Grand Oven in the middle let 7 through. A Spice Kitchen let none through.
- Jam Pot against Prize Pumpkin, each at the point where one build starts to leak: against 30 Scamps the Jam Pot build let 0 through and the Prize Pumpkin build 9. Against 12 Shellbacks, 1 against 4. Against 16 fast Skitters, 9 against 3. Against 40 Pips, 4 against 3.

### 5.11 Pairs players can discover

These pairings are designed in. They are the moments the brief calls out.

| Pair | Why it works |
|---|---|
| Lullaby Bell and Pumpkin Catapult | Drowsy walkers bunch up, so each pumpkin hits more of them. |
| Sling Post and Longbow Loft against Bubblers | Quick pebbles pop the bubble. The heavy arrow lands before it comes back. |
| Spice Kitchen and Quickshots | The +2 damage counts before armor, so quick hits get through shells. |
| Grand Oven and Giant Bows | The biggest hits, more often. Bosses melt. |
| Gates and the Longbow Loft | A gate bends the road back past one long-range spot several times. |
| Lullaby Bell and the Gatecrasher | A drowsy Gatecrasher breaks gates slower, which buys time to defeat it. |
| Jam Pot and anything | Its slow lingers 3.0 s, so towers further down the road get more time. |
| Night Bell and Firework Tower | The only way to keep flyers under fire longer. |

## 6. Creatures

### 6.1 Creature numbers

Numbers at strength 100. Health, heal amounts and bounty scale with strength (6.4). Armor, speed and lives never do.

| Creature | Id | Health | Armor | Speed | Moves | Lives lost | Bounty | Special |
|---|---|---|---|---|---|---|---|---|
| Scamp | `scamp` | 40 | 0 | 1.0 | Walks | 1 | 5 | None. The basic creature. |
| Pip | `pip` | 12 | 0 | 1.2 | Walks | 1 | 2 | None. Comes in crowds. |
| Skitter | `skitter` | 30 | 0 | 2.0 | Walks | 1 | 5 | None. Very fast. |
| Flitter | `flitter` | 30 | 0 | 1.2 | Flies | 1 | 5 | Flies (6.5). |
| Shellback | `shellback` | 90 | 4 | 0.7 | Walks | 2 | 12 | Armor. |
| Bubbler | `bubbler` | 50 | 0 | 0.9 | Walks | 1 | 7 | Bubble (6.2). |
| Puffball | `puffball` | 60 | 0 | 0.8 | Walks | 2 | 5 | Splits into 3 Puffs (6.2). |
| Puff | `puff` | 12 | 0 | 1.3 | Walks | 1 | 2 | Only comes from a Puffball. |
| Mender | `mender` | 70 | 1 | 0.7 | Walks | 1 | 10 | Heals others (6.2). |
| Gatecrasher | `gatecrasher` | 160 | 2 | 0.8 | Walks | 3 | 25 | Breaks gates (7.7). |
| Dusk Moth | `dusk_moth` | 120 | 5 | 0.8 | Flies | 2 | 15 | Armored flyer. |

That is ten creature types, plus the Puff that only a Puffball makes, plus one boss per region (6.3).

### 6.2 Special rules

Bubble (Bubbler):

- A Bubbler starts with its bubble up.
- A hit on a creature with its bubble up pops the bubble and does nothing else. No damage, no slow.
- The bubble comes back 2.0 s after it popped. If it comes back on the same tick as a hit, it blocks that hit (8.1).
- Splash pops each bubble it reaches, one per creature.
- A Bell's slow and a Mender's heal are not hits. The bubble does not stop them.
- So a single slow tower that reloads in 2.0 s or more never hurts a Bubbler alone. Quick hitters lose at most one hit in four.

Splits (Puffball):

- When a Puffball is defeated, it releases 3 Puffs at the spot where it fell: one at once, one 0.3 s later and one 0.6 s later.
- Puffs belong to the Puffball's wave and use its strength. They follow the shortest open route from that spot.
- A Puffball that reaches the base costs 2 lives and releases nothing.

Releases (Puffs and boss batches):

- A release is a Puffball's 3 Puffs, or one batch of creatures from a boss: Grumblesack's 2 Scamps, the Moon Moth's 3 Flitters or Old Tusk's 4 Dusk Moths (6.3).
- Every creature in a release appears at the spot where the release began: where the Puffball fell, or where the boss stood when that batch began. The later ones appear at that same spot, even though the boss has moved on.
- A release that has begun always finishes, even if the boss is defeated or gets through in the meantime.
- A released walker first finishes the step its releaser was on, then takes the shortest open route from there (7.3). A released flyer flies straight from that spot to the base.
- Released creatures belong to their releaser's wave and use its strength (6.4).

Heals (Mender):

- Every 2.0 s, starting 2.0 s after it appears, every other creature within 1.5 tiles of the Mender gains 8 health, scaled by strength, up to its max health.
- It does not heal itself. It heals walkers and flyers, bosses included.
- Menders walk slowly, so they tend to trail behind their group. Towers set to Last find them (8.2).

Breaks gates (Gatecrasher): see 7.7.

### 6.3 Bosses

A boss always comes in the final wave of its level or run. A boss that reaches the base costs 20 lives, which loses any Normal game. Bosses can be slowed. The Moon Moth can be slowed only by a Night Bell.

| Boss | Id | Region | Health | Armor | Speed | Moves | Lives lost | Bounty | Special |
|---|---|---|---|---|---|---|---|---|---|
| Grumblesack | `grumblesack` | 1 | 2000 | 0 | 0.4 | Walks | 20 | 100 | Every 6.0 s it drops 2 Scamps. |
| Ironshell | `ironshell` | 2 | 2500 | 6 | 0.4, rising | Walks | 20 | 150 | Gets faster as it is hurt. |
| Moon Moth | `moon_moth` | 3 | 1600 | 3 | 0.3 | Flies | 20 | 200 | Every 6.0 s, 3 Flitters fly out. |
| Old Tusk | `old_tusk` | 4 | 3000 | 4 | 0.35 | Walks | 20 | 250 | Breaks gates in 2.0 s. At half health, 4 Dusk Moths fly out. |

Exact boss rules:

- Grumblesack: 6.0 s after it appears, and every 6.0 s after that, 2 Scamps appear at its spot, the second 0.3 s after the first. They walk on from there.
- Ironshell: the first time its health falls to 75% of its max or below, its speed goes up by 0.1. The same happens at 50% and at 25%. Its speed goes 0.4, 0.5, 0.6, 0.7.
- Moon Moth: 6.0 s after it appears, and every 6.0 s after that, 3 Flitters appear at its spot, 0.3 s apart. They fly straight to the base from there.
- Old Tusk: follows the Gatecrasher rules (7.7) but breaks a gate in 2.0 s. The first time its health falls to 50% or below, 4 Dusk Moths appear at its spot, 0.3 s apart, starting on the next tick. This happens even if the same hit defeats it.
- Every creature a boss releases belongs to the boss's wave and uses its strength.
- Where released creatures appear, and what happens when a boss falls in the middle of a batch, is in Releases (6.2).

### 6.4 Strength

- Every wave has a strength, a whole percent. 100 means the numbers in 6.1 and 6.3.
- Strength scales health, heal amounts, bounties, the wave clear bonus and risk card rewards. Each is the base number times strength / 100, rounded half up, at least 1.
- Strength never changes armor, speed, tower damage or lives lost.
- Campaign: each level has a strength (12.3). By default every wave in the level uses it. The level designer may give single waves their own strength.
- Runs: wave w has strength 100 + 10 times (w minus 1) (14.1).
- Puffs and boss summons use the strength of their wave.

Example: a Shellback at strength 150 has 135 health, armor 4, speed 0.7, and pays 18 gold.

### 6.5 Flyers, gates and anti air

- A flyer appears at its entrance and flies in a straight line to the center of the base at its speed. A flyer released by a boss starts from the spot where its release began (6.2).
- Flyers ignore roads, gates and gate sockets. They never open or break a gate.
- Only the Sling Post (every tier) and the Firework Tower (every tier) can hit flyers. The Pumpkin Catapult and Longbow Loft cannot. Bells slow flyers only as a Night Bell.
- A flyer that reaches the base costs lives like a walker.
- Flyers appear from level 1-5 on, so gates are never a complete answer.
- When the next wave has flyers, the map shows their straight line during the build phase (7.5).

### 6.6 One-line creature cards

| Creature | Line |
|---|---|
| Scamp | A small night creature. Each one that gets through costs a life. |
| Pip | Tiny and easy to pop, but comes in crowds. Splash clears them. |
| Skitter | Very fast. Give it a long road, or make it drowsy. |
| Flitter | Flies straight over roads and gates. Not every tower can hit it. |
| Shellback | Its shell blocks 4 damage from every hit. Big hits get through. |
| Bubbler | Its bubble blocks one whole hit and returns in 2 seconds. Quick hits pop it. |
| Puffball | Bursts into 3 Puffs when popped. Splash catches them. |
| Puff | Three come out of every popped Puffball. Splash catches them. |
| Mender | Heals the creatures near it every 2 seconds. Stop it first. |
| Gatecrasher | Heads for your gates and breaks one open in 4 seconds. |
| Dusk Moth | An armored flyer. Small hits barely scratch it. |
| Grumblesack | Huge and slow. Drops 2 Scamps every 6 seconds. |
| Ironshell | Armor 6. It gets faster each time it loses a quarter of its health. |
| Moon Moth | A flying boss with armor 3. Every 6 seconds, 3 Flitters fly out. |
| Old Tusk | Armor 4. Breaks gates in 2 seconds. At half health, 4 Dusk Moths fly out. |

- Player-facing text says "pop" for a defeated creature, never "puff", because the Puff is a creature. That covers card lines, hints, messages, and Twist and card text.

## 7. Gates and routes

### 7.1 Sockets and gates

- Gate sockets are road tiles marked in the level.
- A level gives a set number of gates: 0 to 3 in the campaign (12.3), 1 to 3 in runs (14.1).
- A placed gate closes its socket to walkers.
- Levels have more sockets than gates, so where to put them is a choice. Suggested socket counts are in 12.3.

### 7.2 Placing, moving and removing

- In a build phase the player can place a gate on an empty socket, move a placed gate to another empty socket, or remove a gate back to the gate tray.
- A move is one step. The gate leaves its old socket and closes the new one at the same moment. The refusal check (7.4) looks at the result.
- Removing a gate is always allowed.

### 7.3 The shortest open route

Walkers always take the shortest open route to the base. Exactly:

1. A road tile is open unless a closed gate stands on it.
2. The distance of an open road tile is the fewest steps from it to the base along open road tiles. A step goes to the next tile north, south, east or west. The base has distance 0.
3. A walker standing on a tile center picks its next tile from the open neighbor tiles whose distance is exactly one less than its own tile's distance.
4. Tie break: if more than one tile qualifies, it takes the first in this fixed order: south, west, east, north. These are grid directions (3.1), the same in any screen layout.
5. A walker decides only at tile centers. Between centers it keeps going to the tile it picked.
6. A walker's first step is from its entrance tile center.

Players never need the tie break. The route line (7.5) always shows the result.

### 7.4 Refusal

- A placement or move is refused if, after it, any entrance would have no open route to the base.
- When refused, the gate does not stay. The socket shows a crossed-out gate icon for 1.5 s, a one-line message says "That would close every road.", and a short refusal sound plays. Nothing else changes.

### 7.5 The route line

- During every build phase, the map shows a solid route line from each entrance to the base. It follows exactly the route a walker appearing there would take (7.3).
- While the player drags a gate over a socket, the lines show the result as if the gate were dropped there. Over a socket that would be refused, the crossed-out gate icon shows instead.
- If the next wave has a Gatecrasher or Old Tusk, its route shows as a dashed line, with a crack icon on each closed gate it would break.
- If the next wave has flyers, a dotted straight line runs from each entrance they use to the base.
- The lines are hidden during wave phases. The creatures show the way.

### 7.6 Locked during waves, and broken gates

- From the moment a wave starts until the next build phase begins, gates cannot be placed, moved or removed, even while paused. Tapping a gate then says "Gates are locked until the wave is over."
- A gate broken by a Gatecrasher or Old Tusk is open to every walker until the next build phase begins. Then it mends by itself, closed, on the same socket.
- In runs, the Iron Gate card locks placed gates for good each time a wave starts (14.6), and Gateless Night opens every gate from the start of its wave until the next build phase (14.5).

### 7.7 The Gatecrasher

The same rules apply to Old Tusk, with 2.0 s instead of 4.0 s.

- A Gatecrasher follows its own route: the shortest route as if no gates were placed, with the same tie break (7.3).
- When the next tile on that route has a closed gate, it stops at the center of the tile before the gate and starts breaking it. Breaking takes 4.0 s.
- A slow slows the breaking by the same percent. At a 45% slow, each second of play counts as 0.55 s of breaking.
- When the time is up, the gate is broken (7.6). The Gatecrasher walks on. If its route meets another closed gate, it breaks that one too.
- If it is defeated while breaking, the gate stays closed and the breaking is lost.
- Each Gatecrasher keeps its own timer. Two at one gate do not add up. The gate breaks when the first timer runs out.

### 7.8 Walkers changing route during a wave

- Gates never close during a wave. They can only break open.
- When a gate breaks, distances are worked out again at once.
- Every walker except Gatecrashers and Old Tusk uses the new distances from its next tile center. A walker may turn back if the new shortest route lies behind it.
- Gatecrashers and Old Tusk keep their own route, which never depends on gates.

## 8. How combat resolves

### 8.1 Tick order

The sim runs on a fixed timestep (docs/ARCHITECTURE.md). Each tick runs these steps in this order:

1. Spawns. Creatures due this tick appear, in the order of their groups in the wave data, then Puffs and boss summons that are due. Every creature gets the next spawn number when it appears.
2. Timers. Bubbles that are due come back. Slow timers run down and expire. Menders that are due heal. Breaking timers of Gatecrashers and Old Tusk run down, and a gate whose timer runs out breaks now; distances are worked out again.
3. Bells. Every creature of the right kind in a Bell's ring gets that Bell's slow (8.5).
4. Movement. Creatures move. A creature that reaches the base is removed and costs its lives. If lives are 0 or less, the game is lost at once.
5. Towers. Attacking towers act in spot order, row by row from the top (3.4). Each runs down its reload timer, picks targets, fires, and its hits land at once (8.3, 8.4). A creature at 0 health or less is defeated at once and cannot be targeted again.
6. Defeats and boss events. Bounties are paid. Puffballs queue their Puffs. Boss health events happen: Ironshell's speed rises from the next tick, Old Tusk's moths appear on the next tick.
7. Wave checks. A wave runs from the moment it starts until it is cleared. A running wave with nothing left on the map and nothing left to spawn is cleared and pays its clear bonus. If the final wave is cleared and lives are above 0, the game is won. Otherwise, if no wave is running, the build phase begins.

Combat never uses randomness. The campaign uses no randomness at all. Runs use seeded randomness only to build the run and draw cards (14).

### 8.2 Targeting

- Every attacking tower has a targeting mode. The default is First. The player can change it at any time, even mid-wave. It stays through upgrades.
- First: the creature nearest the base. For a walker this is its remaining route: the distance of the tile it is walking to, plus the part of the current step it has left. A Gatecrasher's or Old Tusk's remaining route is measured on its own route. For a flyer it is the straight-line distance to the base center.
- Last: the creature farthest from the base, measured the same way.
- Strong: the creature with the highest max health. Ties go by First.
- Any other tie: the creature with the lowest spawn number.
- A tower picks again every time it fires.
- Only creatures in range, and of a kind the tower can hit, count.
- Triple Bow: picks up to 3 different creatures, in its mode's order.

### 8.3 Damage, armor and bubbles

For each creature a hit reaches:

1. If its bubble is up, the bubble pops. Nothing else happens.
2. Hit damage = the tower's damage plus the best Bakery damage bonus on that tower (8.6) plus any run card bonus (14.5).
3. If the tower ignores armor (Longbow Loft at every tier, Skyrocket), damage taken = hit damage. Otherwise damage taken = hit damage minus armor, but at least 1.
4. The creature's health goes down by the damage taken. At 0 or less it is defeated.
5. If the tower is a Jam Pot, the creature gets the Jam slow (8.5).

### 8.4 Splash

- A splash attack picks its target as usual.
- Its hit reaches every creature of the kind it can hit whose center is within the splash radius of the target's center, the target included. Catapult splash reaches walkers only. Firework splash reaches flyers only.
- Each creature takes the full hit separately, with its own armor and bubble.

### 8.5 Slows

- A slow is a percent. A slowed creature moves at its speed times (1 minus the slow). Gate breaking also runs at (1 minus the slow).
- A creature holds one slow at a time: a percent and a time left.
- A new slow replaces the held one if its percent is higher. If the percent is equal, the time left becomes the longer of the two. If it is lower, nothing changes.
- When the time left runs out, the creature is no longer slowed.
- Bells: every tick, every creature of the right kind in the ring gets the Bell's slow with 1.0 s left. So the slow lingers 1.0 s after it leaves the ring.
- Jam Pot: 40% with 3.0 s left, on each walker it damages.
- Slows never add up. Only the strongest applies.

### 8.6 Bakery boosts

- A Bakery boosts every attacking tower whose tile center is within its reach of its own: 1.5 tiles, or 2.5 with the Warm Ovens card (14.5).
- A rate boost makes the tower's reload timer run faster by that percent (5.2). A +25% boost means 1.25 times as many shots.
- A tower takes only the best rate boost and the best damage bonus from all the Bakeries that reach it. Boosts of the same kind never add up. A tower next to a Grand Oven and a Spice Kitchen takes +40% rate from the first and +2 damage from the second.
- Boosts change at once when a Bakery is built, upgraded or sold.

### 8.7 What stacks

| Effect | Adds up? | Rule |
|---|---|---|
| Armor | No | Subtracted from each hit, at least 1 damage gets through. Longbow Loft and Skyrocket ignore it. |
| Slows | No | One slot per creature. The strongest wins (8.5). |
| Bakery rate boosts | No | The best one counts. |
| Bakery damage bonuses | No | The best one counts. |
| A rate boost and a damage bonus from two Bakeries | Yes | One of each kind can apply together. |
| Run card bonuses | Yes | They change the tower's own numbers. Bakery bonuses come on top. |
| Splash | Yes | Every creature in the radius takes the full hit. |
| Several towers on one creature | Yes | Every hit is separate. |
| Bubbles | One per creature | Blocks one hit, back 2.0 s after it pops. |
| Healing | Yes | Each Mender heals on its own. |

## 9. Information on screen

### 9.1 Wave preview

- The preview of the next wave is always on screen. It is open during build phases and folded into a strip during waves.
- It lists each group in spawn order: the creature's silhouette and name, how many, and the entrance letter.
- A creature the player has never seen has a "New" tag.
- A boss row adds its one-line ability (6.6).
- Tapping a row opens that creature's card with its numbers for that wave: health, heal amount and bounty at the wave's strength.
- In runs, a waiting risk card shows as a row at the top with its effect.
- During build phases the map also shows the route lines for the next wave (7.5).

### 9.2 Info cards

- The first time a creature appears in a preview, its card opens by itself in that build phase: silhouette, name, its one line (6.6) and its numbers at that wave's strength.
- The first time a tower is available, its card opens at the start of that level (5.9).
- Each card opens by itself once per player. That is saved. Cards can be reopened from the preview, the build menu and the Info screen.

### 9.3 Tapping a tower

| Tower kind | Shows |
|---|---|
| Attacking towers | Name, tier and path. Damage per hit, with any Bakery bonus shown as "+2". Rate (attacks per second, one decimal, boosts included). Range in tiles. What it hits: walkers, flyers or both. Special: splash radius, ignores armor, 3 targets, or slow percent and time. Bakery boost received. Targeting mode, which can be changed here. Total spent. Sell value right now. |
| Lullaby Bell | Name, tier and path. Slow percent. Range. Linger 1.0 s. Affects walkers, or walkers and flyers. Total spent. Sell value. |
| Bakery | Name, tier and path. Rate boost and damage bonus. Reach. How many towers it boosts right now. Total spent. Sell value. |

### 9.4 Tapping a creature

Name. Health now and max. Armor. Speed now and base, in tiles per second to two decimals. Walks or flies. Its one line. Lives lost if it gets through. Gold when defeated. Status: slowed (percent and time left), bubble (up, or back in so many seconds), breaking a gate (time left).

### 9.5 Placing and upgrading

- When the player picks a tower for a spot, its range ring shows before confirming. A Bell's ring is its slow zone. A Bakery shows the eight tiles it reaches and marks the towers it would boost.
- An upgrade shows every number that changes as its before and after values side by side, with an arrow drawn between them, and the price, before confirming.
- At tier 3 both paths show side by side, each with its numbers. The screen says the choice is permanent for this tower.

### 9.6 Hints and highlights

- Early levels, and any level that brings something new, have one one-line hint and one highlighted thing on the map: a spot, a socket, a tower or a button (12.4).
- The hint shows at the start of the level the first time it is played, and always on the level card.
- There is no other tutorial text. The Info screen holds the full rules from this file.

### 9.7 Signals that never rely on color

- Route lines differ by line style: solid for walkers, dashed for Gatecrashers, dotted for flyers.
- A refused gate shows a crossed-out gate icon and a message.
- A broken gate has a crack shape.
- A slowed creature shows a sleepy "z" mark. A bubble is a ring outline. "New" is a word.
- The art director owns the look. Every tower and creature must read by silhouette alone.

## 10. Stars

### 10.1 Star 1

Win the level, on Normal or Relaxed.

### 10.2 Star 2

Win on Normal with 15 or more lives left. The same rule on every level. Card text: "Keep 15 lives."

### 10.3 Star 3

Win on Normal while meeting the level's challenge. Each level uses one of these types (12.4 lists them by level):

| Type | Card text, for example | Met when |
|---|---|---|
| No lives lost | Lose no lives. | Lives at the win equal starting lives. |
| Tower limit | Have at most 4 towers. | The number of towers on the map was never above N. Bells and Bakeries count. |
| Tower ban | Build no Sling Posts. | That tower was never built in the level. |
| Gate limit | Use at most 1 gate. Or: Use no gates. | At the start of every wave, at most N gates were placed. |
| Tier cap | No tower above tier 2. | No tower reached tier 3 in the level. |
| Early calls | Call 4 waves early. | At least N waves were called early (4.9). |
| Kinds limit | Use at most 3 kinds of tower. | At most N different tower types were built in the level. |
| Gates whole | Use every gate and keep them whole. | At the start of every wave all the level's gates were placed, and no gate was broken in the level. |

Rule for star 3 challenges: a challenge must always leave at least two kinds of attacking tower usable, so no level ever asks for a one-tower solution.

### 10.4 Earning and keeping stars

- Each star is earned the first time its rule is met in a win, and kept for good.
- The three stars can come from different wins.
- A Relaxed win earns star 1 only.
- The balance bots must find, for every level, one Normal win that earns all three stars at once.

### 10.5 The level card

The level card shows the level name, number of waves, number of gates, the three star lines, which stars are earned, the hint, the Normal or Relaxed choice, and the Twist once it is unlocked.

## 11. Relaxed difficulty

Relaxed gives more lives and more starting gold. Nothing else changes: same maps, waves, creatures, towers, prices, bounties and rules.

| | Normal | Relaxed |
|---|---|---|
| Lives, campaign and runs | 20 | 40 |
| Starting gold, campaign | The level's value (12.3) | 1.5 times Normal, rounded up to a multiple of 10 (listed in 12.3) |
| Starting gold, runs | 300 | 450 |

- The player picks Normal or Relaxed before each level or run. Normal is the default.
- Relaxed wins earn star 1 only (10.4). Star 1 is all that progress needs (16).
- Twists: the Twist's change applies first, then Relaxed. Five Lives gives 5 lives on Normal and 10 on Relaxed. Thin Purse halves the gold first, then Relaxed adds half again.
- The daily challenge is always Normal.

## 12. Campaign

### 12.1 Regions

| Region | Name | Id | Setting | Towers it brings | Creatures it brings | Boss |
|---|---|---|---|---|---|---|
| 1 | Lantern Hill | `lantern_hill` | The village meadow at dusk | Sling Post, Pumpkin Catapult | Scamp, Pip, Flitter | Grumblesack |
| 2 | Millbrook | `millbrook` | River, mills and bridges | Lullaby Bell, Longbow Loft | Skitter, Shellback, Bubbler | Ironshell |
| 3 | Willow Fen | `willow_fen` | Marsh boardwalks and reeds | Firework Tower | Puffball, Dusk Moth | Moon Moth |
| 4 | Moonspire Keep | `moonspire_keep` | The old castle town on the hilltop | Bakery | Mender, Gatecrasher | Old Tusk |

### 12.2 Unlock order

Each line is one new thing, in the order the player meets it.

| Level | New |
|---|---|
| 1-1 | Sling Post, Pumpkin Catapult, Scamp |
| 1-2 | Gates (1 gate) |
| 1-3 | Upgrades (taught, no new content) |
| 1-4 | Pip |
| 1-5 | Flitter, the first flyer |
| 1-6 | Tier 3 paths (taught), Grumblesack |
| 2-1 | Skitter, early calls (taught) |
| 2-2 | Lullaby Bell |
| 2-3 | Longbow Loft, Shellback |
| 2-4 | A second gate |
| 2-5 | Bubbler |
| 2-6 | Ironshell |
| 3-1 | Firework Tower |
| 3-2 | Puffball |
| 3-3 | A third gate |
| 3-4 | Dusk Moth |
| 3-5 | Nothing new |
| 3-6 | Moon Moth |
| 4-1 | Bakery |
| 4-2 | Mender, targeting modes (taught) |
| 4-3 | Gatecrasher |
| 4-4 | Nothing new |
| 4-5 | Nothing new |
| 4-6 | Old Tusk |

- A level's towers are every tower brought up to and including that level. Replays use the same list.
- Level 1-1 opens with two towers so that the brief's check, that no single tower type earns three stars alone, can pass on every level, the first one included (brief section 11).

### 12.3 Levels

"First wave" is the wave where the new creature first appears, alone. Gate sockets are suggestions for the level designer. Gold is starting gold.

Region 1, Lantern Hill:

| Level | Name | The one idea it teaches | New | First wave | Gates (sockets) | Waves | Strength | Gold, Normal | Gold, Relaxed |
|---|---|---|---|---|---|---|---|---|---|
| 1-1 | First Lanterns | Build towers on the spots by the road. | Sling Post, Pumpkin Catapult, Scamp | 1 | 0 (0) | 8 | 100 | 200 | 300 |
| 1-2 | The Fork | A gate closes a road. Creatures take the shortest open road. | Gates | none | 1 (2) | 8 | 100 | 250 | 380 |
| 1-3 | Tall Posts | Upgrade towers when spots run out. | none | none | 1 (2) | 9 | 100 | 250 | 380 |
| 1-4 | Pumpkin Patch | Splash beats crowds. | Pip | 3 | 1 (3) | 9 | 100 | 300 | 450 |
| 1-5 | Night Wings | Flyers ignore roads and gates. | Flitter | 3 | 1 (3) | 10 | 100 | 300 | 450 |
| 1-6 | Grumblesack | Tier 3 paths, then a boss. | Grumblesack | 10 | 1 (3) | 10 | 110 | 350 | 530 |

Region 2, Millbrook:

| Level | Name | The one idea it teaches | New | First wave | Gates (sockets) | Waves | Strength | Gold, Normal | Gold, Relaxed |
|---|---|---|---|---|---|---|---|---|---|
| 2-1 | Mill Race | Calling waves early pays gold. | Skitter | 2 | 1 (3) | 10 | 130 | 350 | 530 |
| 2-2 | Sleepy Mill | Drowsy crowds bunch up for splash. | Lullaby Bell | none | 1 (3) | 10 | 135 | 400 | 600 |
| 2-3 | Shell Road | Armor blocks small hits. Longbows ignore it. | Longbow Loft, Shellback | 3 | 1 (3) | 10 | 140 | 400 | 600 |
| 2-4 | Two Bridges | Two gates make one long road. | Second gate | none | 2 (4) | 11 | 145 | 450 | 680 |
| 2-5 | Bubble Brook | Quick hits pop bubbles, big hits land after. | Bubbler | 2 | 2 (4) | 11 | 150 | 450 | 680 |
| 2-6 | Ironshell | Keep the boss drowsy and pierce its shell. | Ironshell | 12 | 2 (5) | 12 | 160 | 500 | 750 |

Region 3, Willow Fen:

| Level | Name | The one idea it teaches | New | First wave | Gates (sockets) | Waves | Strength | Gold, Normal | Gold, Relaxed |
|---|---|---|---|---|---|---|---|---|---|
| 3-1 | Lantern Festival | Anti air hits whole flocks. | Firework Tower | none | 2 (4) | 11 | 170 | 500 | 750 |
| 3-2 | Puffball Pond | Catch a splitter's pieces with splash. | Puffball | 2 | 2 (4) | 11 | 175 | 550 | 830 |
| 3-3 | Reed Maze | Some sockets matter more than others. | Third gate | none | 3 (5) | 12 | 180 | 550 | 830 |
| 3-4 | Moth Lights | Armored flyers need a heavy anti air shot. | Dusk Moth | 3 | 2 (5) | 12 | 185 | 600 | 900 |
| 3-5 | Two Shores | Split the defense between two entrances. | none | none | 3 (6) | 12 | 190 | 600 | 900 |
| 3-6 | Moon Moth | A flying boss. Gates cannot help. | Moon Moth | 12 | 3 (6) | 12 | 200 | 650 | 980 |

Region 4, Moonspire Keep:

| Level | Name | The one idea it teaches | New | First wave | Gates (sockets) | Waves | Strength | Gold, Normal | Gold, Relaxed |
|---|---|---|---|---|---|---|---|---|---|
| 4-1 | Bakers' Row | Support towers boost their neighbors. | Bakery | none | 2 (5) | 12 | 210 | 650 | 980 |
| 4-2 | Mending Lane | Stop the healers first. | Mender | 2 | 2 (5) | 12 | 220 | 700 | 1050 |
| 4-3 | Gatecrash | Guard the gate a breaker heads for. | Gatecrasher | 3 | 3 (6) | 12 | 230 | 700 | 1050 |
| 4-4 | Market Square | Three roads, everything at once. | none | none | 3 (6) | 12 | 240 | 750 | 1130 |
| 4-5 | Castle Steps | Flyers, breakers and healers together. | none | none | 3 (6) | 12 | 250 | 750 | 1130 |
| 4-6 | Old Tusk | The final boss breaks gates. | Old Tusk | 12 | 3 (6) | 12 | 260 | 800 | 1200 |

Suggested entrances: one in region 1, one or two in region 2, two in region 3, two or three in region 4. Level 3-5 has two and 4-4 has three.

### 12.4 Level cards: star 3, hint and highlight

The number in each star 3 rule is a starting target. The level designer confirms it with the bots once the map exists.

| Level | Star 3 | Hint | Highlight |
|---|---|---|---|
| 1-1 | Lose no lives. | Tap a glowing spot to build a tower by the road. | The best first build spot |
| 1-2 | Have at most 4 towers. | Drop the gate on a road. The line shows their new way. | The socket that makes the long road |
| 1-3 | Have at most 3 towers. | Tap a tower to upgrade it. Spots are few, so make them count. | The tower that covers the most road |
| 1-4 | Use no gates. | Pips come in crowds. Catapults hit the whole crowd. | The spot at the busiest bend |
| 1-5 | Lose no lives. | Flitters fly over roads and gates. Only Sling Posts hit them. | A spot under the flight line |
| 1-6 | Call 4 waves early. | At tier 3, a tower picks one of two paths for good. | The spot beside the boss's longest stretch |
| 2-1 | Call 6 waves early. | Doing well? Call the next wave early for bonus gold. | The call button |
| 2-2 | Have at most 6 towers. | Bells make walkers drowsy. Slow crowds are easy Catapult targets. | A spot whose ring covers a bend beside a Catapult spot |
| 2-3 | No tower above tier 2. | Armor blocks small hits. Longbow arrows go straight through. | A spot that sees two stretches of road |
| 2-4 | Use at most 1 gate. | Two gates now. Make their road as long as you can. | The socket that starts the longest road |
| 2-5 | Build no Longbow Lofts. | A bubble stops one hit. Quick Sling Posts pop it for the big hitters. | A spot near the start of the road |
| 2-6 | Use at most 3 kinds of tower. | Ironshell gets faster as it gets hurt. Keep it drowsy. | The spot beside its longest stretch |
| 3-1 | Lose no lives. | Fireworks hit only flyers, but the whole flock at once. | A spot under the flight line |
| 3-2 | Have at most 7 towers. | Puffballs burst into three Puffs. Pop them near a Catapult. | The spot where the road bunches |
| 3-3 | Use at most 2 gates. | Three gates. Try each socket and watch the line. | A socket that looks good but is not the best |
| 3-4 | Build no Sling Posts. | Dusk Moths wear armor. Skyrockets punch through it. | A spot under the flight line |
| 3-5 | No tower above tier 2. | none | none |
| 3-6 | Lose no lives. | The Moon Moth flies straight in. Line its path with Fireworks. | A spot under its flight line |
| 4-1 | Have at most 6 towers. | Bakeries make the towers around them faster. | The center of a cluster of spots |
| 4-2 | Build no Pumpkin Catapults. | Menders heal their friends. Set a tower to Last to hit them first. | A spot that sees the back of the groups, where Menders trail |
| 4-3 | Use every gate and keep them whole. | Gatecrashers break gates. Guard the gate on their dashed line. | The socket on the dashed line |
| 4-4 | Use at most 3 kinds of tower. | none | none |
| 4-5 | Call 6 waves early. | none | none |
| 4-6 | Lose no lives. | Old Tusk breaks gates fast. Don't count on them to hold. | The spot beside its route |

Star 2 on every level: "Keep 15 lives."

### 12.5 Building waves: a guide for the level designer

- A wave is a list of groups. Each group: creature, count, entrance, start time (seconds after the wave starts) and gap (seconds between its creatures). A wave may also set its own strength (6.4).
- A new creature's first wave holds only that creature: 3 to 5 of them. A boss comes only in the final wave. Never two new things in one wave. A new tower is ready at the start of its level.
- Typical gaps:

| Creature | Gap (s) |
|---|---|
| Scamp | 0.6 to 1.5. Packs for splash: 0.3 to 0.5 |
| Pip | 0.2 to 0.4 |
| Skitter | 0.5 to 1.0 |
| Flitter | 0.3 to 0.5, in flocks |
| Shellback | 1.2 to 2.0 |
| Bubbler | 1.0 to 1.5 |
| Puffball | 1.2 to 2.0 |
| Mender | Spawn it just after the group it should heal |
| Gatecrasher | 3.0 to 6.0 |
| Dusk Moth | 1.5 to 3.0 |

- Wave size, as a start: a wave's total health after strength is about 0.8 times the gold a player could have by then (starting gold plus every bounty and bonus paid before that wave) in region 1, rising to about 1.0 in region 4. The bots tune from there.
- Largest wave: one wave spawns at most 120 creatures in all, Puffs and summons included, and at most 2 waves run at once (4.9). That is the contract's performance ceiling. Aim for 80 or fewer per wave so the screen stays readable.
- Map height: see 3.1. Ranges are long on a 7-wide map by design: a Longbow Loft in the middle column reaches both side lanes.
- Level length: 5 to 10 minutes at 1x, measured as the sum of the wave phases with no early calls, plus 15 s for each build phase.
- To break one-tower solutions in region 1, where there is no armor yet, mix spread-out waves (better for Sling Posts) with tight packs and Pip crowds (better for Catapults), on few spots.
- Every level must pass the bots: it can be won, one Normal win can earn all three stars, no single tower type earns three stars alone, and across the campaign every tower type is part of some three-star win.

## 13. Twists

- A level's Twist unlocks when that level has 3 stars.
- A Twist is the same map and the same waves with one rule changed.
- Twists have no stars. A win on either difficulty marks the level's Twist as cleared.
- The bots must confirm every Twist can be won on Normal.

| Level | Twist | The one rule changed |
|---|---|---|
| 1-1 | Thin Purse | Start with half the gold, rounded down to a multiple of 10. |
| 1-2 | Stuck Gate | The level's gate starts placed on a socket the level sets. It cannot be moved or removed, and there is no other gate. |
| 1-3 | No Upgrades | Towers stay at tier 1. |
| 1-4 | No Catapults | The Pumpkin Catapult cannot be built. |
| 1-5 | Twice the Wings | Every group of flyers has twice as many. |
| 1-6 | Double Trouble | Every group in the final wave has twice as many. Two bosses. |
| 2-1 | Hurry | Every creature moves 20% faster. |
| 2-2 | No Bells | The Lullaby Bell cannot be built. |
| 2-3 | Thick Shells | Every creature has 2 more armor. |
| 2-4 | No Gates | The level gives 0 gates. |
| 2-5 | Bubble Night | Every creature carries a bubble. |
| 2-6 | Stuck Gates | Both of the level's gates start placed on sockets the level sets. They cannot be moved or removed, and there are no others. |
| 3-1 | No Fireworks | The Firework Tower cannot be built. |
| 3-2 | No Catapults | The Pumpkin Catapult cannot be built. |
| 3-3 | One Gate | The level gives 1 gate instead of 3. |
| 3-4 | Twice the Wings | Every group of flyers has twice as many. |
| 3-5 | Tier 2 Cap | No tower can go above tier 2. |
| 3-6 | Double Trouble | Every group in the final wave has twice as many. Two bosses. |
| 4-1 | Thin Purse | Start with half the gold, rounded down to a multiple of 10. |
| 4-2 | No Longbows | The Longbow Loft cannot be built. |
| 4-3 | Quick Crashers | Gatecrashers break gates in 2.0 s instead of 4.0 s. |
| 4-4 | No Selling | Towers cannot be sold. |
| 4-5 | Five Lives | Start with 5 lives. |
| 4-6 | Double Trouble | Every group in the final wave has twice as many. Two bosses. |

## 14. Roguelite mode

### 14.1 Run shape

| Item | Value |
|---|---|
| Waves | 18. Wave 18 is a boss wave. |
| Length | About 15 to 20 minutes at 1x. |
| Strength of wave w | 100 + 10 times (w minus 1). Wave 1 is 100, wave 18 is 270. |
| Starting gold | 300 on Normal, 450 on Relaxed. |
| Starting lives | 20 on Normal, 40 on Relaxed. |
| Starting towers | The Sling Post only. Other towers come from cards. |
| Gates | 1 at the start, up to 3 from cards. |
| Cards | One draft after each of waves 1 to 17. |
| End | The run is won when wave 18 is cleared with lives above 0. It is lost when lives reach 0. |

All core rules (4 to 9) apply in runs: phases, pause, speeds, early calls, selling, gates, the route line and the wave preview.

### 14.2 Maps from segments

- A run map is 7 columns by 13 rows, made of three hand-built segments stacked: a top segment of 4 rows, a middle segment of 5 rows and a bottom segment of 4 rows. The middle one gets the extra row because it holds the forks.
- Top segments hold 1 or 2 entrances, on the top edge or the side edges of that segment. Middle segments hold forks and gate sockets. Bottom segments hold the base. Any segment may have build spots and sockets.
- Each segment lists the columns where its road crosses its top edge and its bottom edge. Two segments join only if the bottom crossing columns of the upper one are exactly the top crossing columns of the lower one.
- The run's seed picks a top segment, then a middle segment that joins it, then a bottom segment that joins that. Each pick is even among the segments that fit.
- A joined map must have 8 to 12 build spots and 2 to 5 gate sockets, and pass the same checks as a campaign map.
- The level designer builds the segments. Tests check that every top segment can be finished into a valid map.

### 14.3 Waves in a run

- Run waves come from hand-built wave packs. A pack is 3 waves in a row.
- The 18 waves are 6 bands of 3. For each band the seed picks one pack from that band's packs. Each band has at least 4 packs.

| Band | Waves | Creatures its packs may use, on top of earlier bands |
|---|---|---|
| 1 | 1 to 3 | Scamp, Pip. Wave 1 is Scamps only. |
| 2 | 4 to 6 | Skitter, Flitter, Shellback |
| 3 | 7 to 9 | Bubbler, Puffball |
| 4 | 10 to 12 | Mender, Dusk Moth |
| 5 | 13 to 15 | Gatecrasher |
| 6 | 16 to 18 | All. Wave 18 is a boss with its escort. |

- The seed picks the run's boss from the four, and band 6 uses a pack made for that boss.
- Packs name entrance A or B. On a map with one entrance, B means A.
- A creature a run has not shown yet comes in its own group, first in its wave, and no wave brings two such creatures. Risk cards are the only exception, and their card says what they add.
- Health, heals, bounties and clear bonuses follow the wave's strength.
- The level designer builds the packs, like levels.

### 14.4 The card draft

- After each of waves 1 to 17 is cleared, the player picks 1 card from 3. The draft opens in the next build phase.
- If waves were called early, the drafts wait and come one after another, in wave order, at the next build phase. The next wave cannot start until every waiting draft is picked. A draft cannot be skipped.
- That holds for early calls too. A wave cleared while another wave is still on the map owes its draft at once, and from then on the next wave cannot be called until the build phase, where the waiting drafts are picked first. Tapping the call button meanwhile says "Pick your card after this wave."
- A draft opens only in a build phase. If wave 18 is called early and wave 17 is cleared after that, no build phase follows, so the draft for wave 17 never opens.
- Card type weights: tower 30, tower perk 25, extra gate 10, economy 20, risk 15.
- Drawing a draft: for each of the 3 slots, pick a type by weight among the types that still have an eligible card, then pick a card of that type evenly. No card appears twice in one draft.
- While the run has fewer than 3 kinds of tower, the first slot is always a tower card, if one is eligible.
- Eligible cards:
  - A tower card only for a tower not yet in the run.
  - A tower perk only for a tower in the run.
  - A card marked once is gone after it is taken.
  - An extra gate only while the run has fewer than 3 gates and fewer gates than the map has sockets.
  - At most one risk card per draft. None while another risk card is waiting. None in the draft after wave 17, so the boss wave is never changed.
- A risk card changes the next wave that starts. Its reward is paid when that wave is cleared.
- Each draft uses its own random generator, seeded from the run seed and the wave number. Earlier picks never change which random numbers later drafts get. The architect sets how the seed is mixed.

### 14.5 Base cards

Every player has these from the start. Gold rewards on risk cards are base numbers, scaled by the strength of the wave they change and rounded half up.

Tower cards (5). Each adds one tower to the run: Pumpkin Catapult, Lullaby Bell, Longbow Loft, Firework Tower, Bakery.

Tower perks (6). Each is once per run.

| Card | Tower | Effect |
|---|---|---|
| Sharp Pebbles | Sling Post | Deals 2 more damage per hit. |
| Wide Splash | Pumpkin Catapult | Splash radius is 0.25 tiles bigger. |
| Deep Lullaby | Lullaby Bell | Slows are 10 points stronger. 35% becomes 45%. |
| Steady Aim | Longbow Loft | Reload times are 20% shorter. 2.5 s becomes 2.0 s. |
| Bigger Bangs | Firework Tower | Deals 5 more damage per hit. |
| Warm Ovens | Bakery | Reaches 2.5 tiles instead of 1.5. |

Extra gate (1).

| Card | Effect | Taken |
|---|---|---|
| Spare Gate | Gain 1 gate, up to 3. | Again and again |

Economy (5).

| Card | Effect | Taken |
|---|---|---|
| Gold Purse | Gain 100 gold plus 10 for each wave cleared so far. | Again and again |
| Fat Bounties | Creatures give 20% more gold for the rest of the run, rounded half up. | Once |
| Feast Days | Wave clear bonuses are 50% bigger for the rest of the run, rounded half up. | Once |
| Fair Trade | Selling refunds 90% instead of 70% for the rest of the run. | Once |
| Tea Break | Gain 5 lives. | Again and again |

Risk (5). Each changes the next wave only.

| Card | Next wave | Reward |
|---|---|---|
| Crowded Night | Every group has 50% more creatures, rounded up. | 100 gold |
| Thick Hides | Creatures have 50% more health, rounded half up. | 120 gold |
| Hurry Night | Creatures move 25% faster. | 100 gold |
| Gateless Night | Your gates stand open. They block nothing and cannot be broken. | 120 gold |
| Flock | 8 extra Flitters come from entrance A, 0.4 s apart, starting 2.0 s after the wave's last group starts. | 80 gold |

- Gateless Night opens every gate from the moment its wave starts until the next build phase begins. Gates never close during a wave (7.8), so any other wave on the map in that time, including one called early, finds them open too. Gatecrashers and Old Tusk walk through without stopping. In the build phase before that wave, the route lines already show the roads with every gate open. When the next build phase begins, every gate stands closed again on its socket.

### 14.6 Unlockable cards

- Playing unlocks new cards into the pool. Each one is a sidegrade: it changes how something works and carries a cost, so it adds variety, never raw power. Nothing is bought.
- An unlocked card joins its type in every later draft.
- The daily challenge always uses every card, unlocked or not (15).

| Card | Type | Effect | Unlocked by |
|---|---|---|---|
| Twin Pebbles | Tower perk, Sling Post | Hits 2 targets per shot, but deals 2 less damage per hit. Once. | Reach wave 6 in a run |
| Heavy Pumpkins | Tower perk, Pumpkin Catapult | Deals 10 more damage, but reloads 0.5 s slower. Once. | Reach wave 12 in a run |
| Frost Chime | Tower perk, Lullaby Bell | Also slows flyers, but its range is 0.5 tiles shorter. Once. | Finish a daily challenge, won or lost |
| Volley | Tower perk, Longbow Loft | Hits one more target per shot, but each arrow deals 40% less damage, rounded half up. Once. | Win a run |
| Long Fuse | Tower perk, Firework Tower | Reaches 1 tile further, but reloads 0.5 s slower. Once. | Win a run on Normal |
| Spice Rack | Tower perk, Bakery | Also adds 2 damage per hit to the towers it reaches, but its speed boost is 10 points smaller. 25% becomes 15%. Once. | Earn 24 stars |
| Piggy Bank | Economy | At the start of each build phase, gain 10% of your unspent gold, rounded down, up to 50. Once. | Earn 36 stars |
| Bargain | Economy | New towers cost 20 more. Upgrades cost 20 less. Once. | Earn 48 stars |
| Iron Gate | Extra gate | Gain 2 gates, up to 3. When a wave starts, placed gates lock for good. Once. | Clear any Twist |
| Moonlit Wager | Risk | Next wave: creatures have twice the health. Reward: 250 gold. | Earn 60 stars |
| Crasher Escort | Risk | Next wave: 2 Gatecrashers join from entrance A at the wave's start, 3.0 s apart. Reward: 150 gold. | Win a run after taking 3 or more risk cards in it |
| Pip Parade | Risk | Next wave: a crowd of 24 Pips joins from entrance A, 0.3 s apart, starting 1.0 s after the wave starts. Reward: 100 gold. | Earn 72 stars |

- Daily runs count as runs for these conditions.
- Unlock progress is kept in these counters: `best_run_wave` (the highest wave reached in any run; it only goes up), `runs_won`, `runs_won_normal`, `dailies_finished` and `risky_wins` (runs won after taking 3 or more risk cards in them). Stars and Twist clears come from the level records (16).
- Iron Gate locks nothing at the moment it is taken. In that build phase every gate can still be placed, moved and removed, so a mistaken drop can be fixed. From then on, each time a wave starts, every gate on a socket locks there for the rest of the run and can never be moved or removed again. That includes gates placed before the card was taken. Gates still in the tray stay free until they are placed and a wave starts. A locked gate can still be broken by a Gatecrasher or Old Tusk, and it mends on its socket as usual (7.6).

### 14.7 Leaving, losing and results

- A run can be left at any time and resumed later at the exact moment it was left, from the Continue card or its own mode button (4.10).
- A run ends when lives reach 0, or when the player abandons it from Pause after a confirm. An abandoned run counts as a loss at its current wave.
- A run's result is: won or lost, waves cleared, and lives left.
- Runs carry nothing over except progress toward unlocks (14.6).

## 15. Daily challenge

- One run per calendar day, built exactly like a roguelite run (14), with these differences:
  - Seed: the phone's local date as the number YYYYMMDD, for example 20261023. The same date gives the same run on every phone with the same app version. No network.
  - Always Normal.
  - Uses every card, unlocked or not, so every player draws from the same pool.
  - Opens together with the roguelite mode (16).
- The player may try as often as they like. Each finished try is compared with the day's best.
- Best result: a win beats a loss. Between wins, more lives left is better. Between losses, more waves cleared is better. A tie keeps the earlier result.
- A daily run belongs to the date it started, even if it ends after midnight.
- Streak. The phone keeps a streak count and the last date it counted.
  - When a daily run ends (won, lost or abandoned), look at the date it belongs to.
  - If that date is the day after the last counted date, the streak grows by 1.
  - If it is the last counted date itself, or an earlier date, nothing changes. This covers a phone whose date moved backward.
  - Otherwise the streak starts again at 1.
  - The screen shows the streak while the last counted date is today or yesterday, and 0 after that.
- The day's best result and the streak are saved on the phone only.

## 16. Progression

| Unlock | Needs |
|---|---|
| Region 1, level 1-1 | Nothing. Open from the start. |
| The next level in a region | Clearing the level before it. |
| Region 2 | Level 1-6 cleared and 6 stars. |
| Region 3 | Level 2-6 cleared and 12 stars. |
| Region 4 | Level 3-6 cleared and 18 stars. |
| Roguelite mode and daily challenge | 12 stars. |
| A level's Twist | 3 stars on that level. |
| Towers in the campaign | Reaching the level that brings them (12.2). |
| Unlockable cards | Their conditions (14.6). |

Why a player at one or two stars per level still reaches the end:

- Every cleared level gives at least 1 star, on Normal or Relaxed.
- Levels open in order. Clearing every level of a region once gives exactly 6 stars for that region. That meets every region's star count: 6, 12 and 18.
- Relaxed is always available, and a Relaxed win is enough to move on.
- Second and third stars open only Twists and some roguelite cards. Both are variety, never needed to finish.
- A player with two stars per level reaches 12 stars after region 1 and can open the roguelite early. A one-star player opens it after region 2.

## 17. Answers to the architecture assumptions

The first draft of docs/ARCHITECTURE.md was written before this file and lists 19 assumptions in its section 11. One row per item. Where this file already decided, its rule stands.

| # | Contract assumption | Answer | RULES.md |
|---|---|---|---|
| 1 | Stat block fields, creature fields, rules.json keys | Settled by the tables here. Tower blocks also need: targets per shot, a damage bonus (Bakery), the Bell's slow as a ring with a 1.0 s linger, and which kinds a Bell slows. No shot speed (row 12). Creatures also need: a bubble that returns after 2.0 s, heal (amount, 1.5 range, every 2.0 s), split (Puff, 3, 0.3 s apart), gate breaking time, and boss events. rules.json values: refund 70%, early call 50% rounded up, Relaxed lives 200% and gold 150% rounded up to a multiple of 10, region stars 6, 12 and 18 plus the boss, roguelite 12 stars, 2 waves at once, clear bonus 20 plus 5 per wave, star 2 at 15 lives. | 4.4 to 4.9, 5.3 to 5.8, 6.1 to 6.3, 10, 11, 16 |
| 2 | Effect types; one effect per Twist | Agree that each Twist changes one rule. The changes needed are in 13, 14.5 and 14.6. The game designer's report lists them as effect types for phase 4. | 13, 14.5, 14.6 |
| 3 | Targeting is First | Three modes, changeable at any time: First (the default), Last and Strong. Ties go to the lowest spawn number. | 8.2 |
| 4 | Tick order | Use 8.1. Bells slow before movement, a leak that ends the game ends the tick, and hits land at once, so there is no shot step. | 8.1 |
| 5 | Refunds: each build phase and each wave is a phase | Rule chosen instead: only purchases made in the current build phase refund in full. Anything bought during a wave refunds 70% at once. This follows brief 3.1. | 4.6 |
| 6 | Early call during a wave, at once, with a bonus, at most 2 waves running | Agree, with two details: only after the newest wave has spawned all its groups, and the bonus is half the bounty of the newest wave's creatures still on the map, rounded up. | 4.9 |
| 7 | Clear gold set per wave in the level file | Rule chosen instead: a formula, (20 + 5 times the wave number) times strength / 100, rounded half up. Levels need no per-wave gold. They need a strength instead (6.4). | 4.5, 6.4 |
| 8 | Star kinds, stars as bits, the union kept, Relaxed earns only the win | Agree. Star 2 and the eight star 3 kinds are in 10.2 and 10.3. A Twist win stores only the win bit. | 10, 13 |
| 9 | Gate breaker | Agree, plus: slows slow the breaking, a breaker defeated while breaking loses its progress, each breaker keeps its own timer, it breaks every closed gate on its route in turn, and Old Tusk takes 2.0 s. | 7.6, 7.7 |
| 10 | Flyers fly straight from entrance to base | Agree. Flyers released by a boss start at the boss. There are no flyer-only entrances. | 6.5 |
| 11 | A placement seals when any entrance loses its last route | Agree. | 7.4 |
| 12 | Homing shots with a flight time | Rule chosen instead: an attack lands on the tick the tower fires. Projectiles are only drawn. | 5.2, 8.1 |
| 13 | No chance in battle rules | Agree. Runs use their seed only to build the run and draw cards. | 8.1, 14 |
| 14 | Runs from one top, one middle and one bottom segment; waves made at the start; one draft per cleared wave | Agree. Segments are 4, 5 and 4 rows. Waves come from hand-built packs in six bands. The boss wave owes no draft. | 14.2 to 14.4 |
| 15 | Daily uses the starting pool, counts for its start day, streak counts finished days | Rule chosen instead for the pool: the daily uses every card, unlocked or not. The other two parts: agree. | 15 |
| 16 | 7 columns by 8 to 13 rows; entrances on the edge | Agree. | 3.1, 3.2 |
| 17 | One saved session at a time; starting something new asks first | Not a game rule. Bart decides (contract question 3). If one session: an ended run counts as abandoned, and an ended daily counts as finished for the streak. Bart chose one saved game per mode at hard stop A (4.10). | 4.10, 14.7, 15 |
| 18 | The difficulty choice is not remembered | Agree. Normal is preselected for every level and run. | 11 |
| 19 | A tower counts as unlocked once a level offering it was played | Agree in effect. Each level offers every tower brought up to it, listed in its file, and runs offer every tower through cards. Nothing extra is saved. | 12.2, 14.3, 14.5 |

Other differences for phase 4, outside the 19 items:

- Tie break order: this file says south, west, east, north (7.3). The draft says up, right, down, left.
- Levels and run waves need a strength (6.4).
- A hint may highlight the call button instead of a cell (12.4, level 2-1).
- Spot order: this file now uses the contract's cell order (3.4).
- Progress counters are named in 14.6.

On the contract's open question 2, map width. Yes, 7 columns by up to 13 rows is enough room for good fork and gate puzzles:

- Roads are one tile wide, so 7 columns fit up to three lanes side by side with build spots between them. The gate puzzle lives in those in-between spots: a spot between two lanes sees both, and closing a lane decides which towers the creatures pass.
- Width limits sideways detours to about 6 steps, so maps get their length from rows: switchbacks and stacked forks. With 10 to 13 rows a map can stack two or three fork sections, which gives three gates real choices and routes of about 15 to 35 steps. That is what the wave lengths and ranges in this file assume.
- 8 rows is enough only for the first teaching maps, which is why region 1 may use 8 to 11 rows and later regions 10 to 13 (3.1).
- I would not trade touch size for width. 8 or 9 columns drop below 48 dp on the cover screen.
- On old 16:9 phones 13 rows give about 39 dp (contract 7.4). If that matters, the fix should be a slimmer portrait HUD, not fewer rows. The puzzles would still work at 12 rows if it comes to that.

## 18. Brief section 3 coverage

| Brief item | Covered in |
|---|---|
| 3.1 Waves come down roads; each creature at the base costs lives; out of lives loses | 4.1, 4.4, 6.1 |
| 3.1 Build phase with no time pressure; real time in waves | 4.1, 4.2, 4.3 |
| 3.1 Pause any moment; build, upgrade, sell, inspect while paused | 4.7 |
| 3.1 Speeds 1x, 2x, 3x | 4.8 |
| 3.1 Early call bonus | 4.9 |
| 3.1 Gold from kills and clears; full refund in the same build phase, part after | 4.5, 4.6 |
| 3.2 Six towers with one job each, from the six archetypes | 5.1 to 5.8 |
| 3.2 Three tiers, a permanent pick of two at tier 3 | 4.6, 5.3 to 5.8, 9.5 |
| 3.2 No tower best everywhere; each right somewhere | 5.1, 5.10, 5.11, 10.3, 12.5 |
| 3.2 Build spots; limited spots are part of the puzzle | 3.4, 12.5 |
| 3.3 About ten creatures plus one boss per region, from the starting set | 6.1 to 6.3 |
| 3.3 Flyers ignore roads and gates | 6.5, 7.5 |
| 3.3 New creature alone first with an info card; never two new things per wave | 9.2, 12.2, 12.3, 12.5, 14.3 |
| 3.4 Hand-built forks; some road cells are gate sockets | 3.2, 3.3, 7.1 |
| 3.4 0 to 3 gates; a gate closes the road at its socket | 7.1, 12.3 |
| 3.4 Walkers take the shortest open route | 7.3, 7.8 |
| 3.4 A placement that seals every route is refused with feedback | 7.4 |
| 3.4 Route line while placing or moving | 7.5 |
| 3.4 Place, move, remove in build phases; locked in waves; mid-wave switch proposal | 7.2, 7.6, 19.2 |
| 3.5 Wave preview: what, how many, which entrance | 9.1 |
| 3.5 Tapping shows real numbers | 9.3, 9.4 |
| 3.5 Range shown on placing; before and after on upgrades | 9.5 |
| 3.5 Color never the only signal; silhouettes | 9.7. The art director owns silhouettes. |
| 3.5 Touch only, one thumb, 48 dp | 3.1 sizes the grid for 48 dp. The UI engineer owns controls. |
| 3.6 About 24 levels in 4 regions of 6; each region brings 1 or 2 towers and 2 or 3 creatures and ends with a boss | 12.1, 12.2, 12.3 |
| 3.6 Levels take 5 to 10 minutes at 1x | 12.3, 12.5 |
| 3.6 Three stars; one for winning; second and third defined and shown on the level card | 10, 12.4 |
| 3.6 First levels teach one idea with a one-line hint and a highlighted spot; Info holds the full rules | 9.6, 12.3, 12.4 |
| 3.6 Twist after three stars; the Twist list | 13 |
| 3.7 Runs of 15 to 20 waves, 15 to 25 minutes, ending in a boss | 14.1, 14.3 |
| 3.7 Maps from hand-built segments | 14.2 |
| 3.7 One of three cards after each wave, five card types | 14.4, 14.5 |
| 3.7 Losing ends the run; leave and resume at any wave | 14.7 |
| 3.7 Unlocks join the pool; variety, never power; nothing bought | 14.6 |
| 3.8 One seeded run per day from the local date, same on every phone, no network | 15 |
| 3.8 Best result for the day and a streak, on the phone only | 15 |
| 3.9 Stars unlock regions and the roguelite; towers unlock as the campaign brings them | 12.2, 16 |
| 3.9 Everything earned; no grind walls | 16 |
| 3.9a Normal and Relaxed, picked per level or run, Normal by default | 11 |
| 3.9a Relaxed numbers; nothing else changes | 11, 12.3 |
| 3.9a A Relaxed win earns one star; stars 2 and 3 need Normal | 10.4, 11 |
| 3.9a The daily is always Normal | 11, 15 |
| 3.10 Resuming after leaving | 4.10, 14.7. Bart chose the exact moment at hard stop A. |
| 3.11 Plain classes, fixed timestep, seeded randomness | 5.2, 8.1, 14.4, 15. No randomness in combat. |

## 19. For Bart at hard stop A

Nothing in this section is a rule. Engineers do not build from it.

### 19.1 Choices for Bart to approve

1. Names. Every tower, path, creature, boss, region and level name is a working name. The art director may want changes to fit the silhouettes.
2. The tower roster and jobs (5.1). The Firework Tower hits only flyers, the Sling Post hits both, the Lullaby Bell deals no damage, and the Bakery boosts attack rate.
3. Level 1-1 opens with two towers. Brief section 11 says no single tower type may earn three stars alone on any level. With one tower in the first levels that check cannot pass. The other choice is to open with the Sling Post alone and exempt the first levels from that check.
4. Star rules (10). Star 2 is always "Keep 15 lives". Star 3 is one of eight challenge types per level (12.4). Stars can be earned in different wins.
5. Relaxed numbers (11). 40 lives instead of 20, and 1.5 times the starting gold.
6. The Twist list (13).
7. The campaign plan (12): the order things arrive, gate counts, wave counts, strengths and starting gold.
8. Economy (4.5 to 4.9). Bounties, the clear bonus formula, the early call bonus of half the bounty still on the map from the newest wave, and refunds of 70% for anything not bought in the current build phase, including anything bought during a wave.
9. Gatecrasher rules (7.7). It walks the route it would take with no gates, and broken gates mend at the next build phase.
10. Route lines show during the whole build phase, not only while dragging a gate (7.5).
11. The roguelite (14). 18 waves, three segments per map, 22 base cards, and 12 unlockable cards with their conditions.
12. Roguelite and daily open together at 12 stars, and runs use every tower and creature, even ones the campaign has not brought yet. Each shows its info card the first time. The other choice is to open the daily only after level 4-3, when the player has met everything.
13. Daily rules (15). Unlimited tries, how the best result is chosen, and how the streak counts.
14. Every level and run starts at 1x speed (4.8).
15. Map size (3.1): 7 columns by 8 to 13 rows, as the contract proposes. My view on the width question is at the end of section 17.
16. Attacks land the moment a tower fires, and projectiles are only drawn (5.2). The contract's first draft assumed flying shots.
17. At most 2 waves on the map at once (4.9). This comes from the contract's performance budget and limits how far early calls can be chained.

### 19.2 Suggestions beyond brief section 3

1. Mid-wave gate switch. I propose not adding one to the campaign. The campaign's pleasure is solving the map in the calm build phase and then watching the plan work. A mid-wave switch turns that into reflex play under time pressure on a one-thumb phone screen. Players would also pause to switch, which makes it a chore rather than a skill. It would weaken the Gatecrasher, whose threat is that gates hold only until it arrives. If Bart wants to try the idea, the smallest safe version is one unlockable roguelite card, "Swing Gate": once per wave, move one gate during the wave; the new socket closes 2.0 s after the drop, and the move is refused if any walker on the map would be left with no route. It stays optional, adds variety, and costs little to build and test.
2. Remember the speed setting between levels instead of starting each level at 1x.
3. Show "damage dealt this level" when a tower is tapped, so players can see which towers carry their defense.
