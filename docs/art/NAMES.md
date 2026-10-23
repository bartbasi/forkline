# Forkline names

Art director, 2026-10-23. Phase 4. For the game designer to review, then for Bart. No code uses a display name until Bart has seen this list. Code uses the ids.

## How this list was made

- It starts from the names in docs/design/RULES.md. The jobs stay exactly as RULES.md gives them.
- A name changes only where it does not fit a clear cozy silhouette, reads wrong to a player, or belongs to another game. Each change gives its reason.
- Ids are lowercase, `a` to `z`, `0` to `9` and `_`, start with a letter, and are at most 32 characters (contract 2.1). Display names are at most 24 characters.
- The theme slice used its own working names (Watch post, Bakehouse, Flour mill, Lookout, Firework loft, Lantern cottage, Nightling, Dasher, Mites). They are all retired. The slice's "Bakehouse" clashed with the boost tower "Bakery". The dome oven shape now belongs to the Bakery, where it fits.
- Spec order: spec 0 is the first path in the RULES.md tier table and spec 1 the second. `Silhouettes.draw_tower` and `data/stats/towers.json` must use the same order.

## Towers

| Id | Name | Job (RULES.md 5.1) | Silhouette | Change |
|---|---|---|---|---|
| `sling_post` | Sling Post | Quick small hits on one target, walkers and flyers | A plank cabin up on X-braced stilts with a steep peaked roof: a tall "A" | none |
| `pumpkin_catapult` | Pumpkin Catapult | Splash on groups of walkers | A low gabled shed with a long catapult arm rising to one side, a pumpkin in its cup | none |
| `lullaby_bell` | Lullaby Bell | Slows walkers in its ring | A small chapel with an open round arch on top, a big bell hanging in it, a crescent moon on the peak | none |
| `longbow_loft` | Longbow Loft | Long range, heavy arrows that ignore armor | The tallest: a stone column with battlements and a wide bow across the top: a "T" | none |
| `firework_tower` | Firework Tower | Anti air with splash, flyers only | A low cottage with a fan of three finned rockets on the roof: a spiky crown | none |
| `bakery` | Bakery | Makes towers around it attack faster | A wide beehive dome oven with a tall chimney to one side and a glowing mouth | none (takes the slice's dome oven shape) |

## Tier 3 specializations

| Tower | Spec | Id | Name | Silhouette piece | Change |
|---|---|---|---|---|---|
| Sling Post | 0 | `quickshot` | Quickshot | Double peaked roof: two cabins, an "M" on stilts | none |
| Sling Post | 1 | `stone_sling` | Stone Sling | A round boulder in a net on a beam above the roof | none |
| Pumpkin Catapult | 0 | `prize_pumpkin` | Prize Pumpkin | A huge pumpkin in a bigger cup | Was "Great Pumpkin". That is a famous cartoon character's name. A prize pumpkin from the village fair says "the big one" just as well, and it no longer shares "Great" with the bow path. |
| Pumpkin Catapult | 1 | `jam_pot` | Jam Pot | A round jam pot with a tied cloth lid in the cup, drips below | none |
| Lullaby Bell | 0 | `hush_bell` | Hush Bell | A wide, low onion dome over a bigger bell | none |
| Lullaby Bell | 1 | `night_bell` | Night Bell | A tall pointed spire with a star on the tip | none |
| Longbow Loft | 0 | `giant_bow` | Giant Bow | One huge bow, wider than the tower | Was "Great Bow". "Greatbow" is the name of a giant bow weapon class in a famous action game series, the same thing. |
| Longbow Loft | 1 | `triple_bow` | Triple Bow | Three small bows stacked in a fan | none |
| Firework Tower | 0 | `star_bloom` | Star Bloom | Five small rockets in a wide fan | Was "Starburst", the name of a famous slot game and a candy brand. A firework "bloom" is the burst opening like a flower. |
| Firework Tower | 1 | `skyrocket` | Skyrocket | One big rocket standing upright in a launch frame | none |
| Bakery | 0 | `grand_oven` | Grand Oven | Two tall chimneys | none |
| Bakery | 1 | `spice_kitchen` | Spice Kitchen | A pepper mill turret with a round knob in place of the chimney | none |

## Creatures

| Id | Name | Job (RULES.md 6.1) | Silhouette | Change |
|---|---|---|---|---|
| `scamp` | Scamp | Basic | A round fuzzy ball with two pointed ear tufts and big eyes | none |
| `pip` | Pip | Swarm, comes in crowds | A tiny bead with two antennae with glowing tips | none |
| `skitter` | Skitter | Very fast | A lean long-eared runner caught mid-leap | none |
| `flitter` | Flitter | Flyer | A round little body with two scalloped wings held up, like a small bat. Its shadow floats below it | none ("flittermouse" is an old word for a bat, which fits the shape) |
| `shellback` | Shellback | Armor | A wide dome shell with a small head peeking out | none |
| `bubbler` | Bubbler | Bubble blocks one hit | A squat round body holding a bubble wand up over its head | none |
| `puffball` | Puffball | Splits into 3 Puffs | A big scalloped cloud ball with a tiny sprout on top and short feet | none |
| `puff` | Puff | Only comes from a Puffball | A tiny cloud with three bumps on top and no feet | none |
| `mender` | Mender | Heals others | A creature under a wide mushroom cap, holding a leafy staff | none |
| `gatecrasher` | Gatecrasher | Breaks gates | A stocky bruiser with two big curled horns, head down | none |
| `dusk_moth` | Dusk Moth | Armored flyer | A moth with wide plated wings and feathered antennae. Its shadow floats below it | none |

## Bosses

| Id | Name | Region | Silhouette | Change |
|---|---|---|---|---|
| `grumblesack` | Grumblesack | 1 | A huge lumpy sack tied at the top, with a grumpy face and stubby feet | none |
| `ironshell` | Ironshell | 2 | A huge shell with three tall plates along its back | none |
| `moon_moth` | Moon Moth | 3 | A huge moth with long trailing tail streamers and crescent marks | none |
| `old_tusk` | Old Tusk | 4 | A big shaggy beast with two long tusks curving up from its snout | none |

## Regions

| Id | Name | Setting (RULES.md 12.1) | Change |
|---|---|---|---|
| `lantern_hill` | Lantern Hill | The village meadow at dusk | none |
| `millbrook` | Millbrook | River, mills and bridges | none |
| `willow_fen` | Willow Fen | Marsh boardwalks and reeds | none |
| `moonspire_keep` | Moonspire Keep | The old castle town on the hilltop | none |

## For the game designer

- RULES.md needs three renames if this list is approved: Great Pumpkin to Prize Pumpkin, Great Bow to Giant Bow, Starburst to Star Bloom. Jobs and numbers do not change.
- The contract's examples use placeholder ids (`lantern`, `nightling`, `region_1`). The real data files should use the ids above.
- Watch item: "Puff" is both a creature and the word for how every creature vanishes ("puff into sparkles"). The shapes differ, so I kept it. If players mix them up in the playtest, "Puffling" is a spare name.
