#!/bin/bash
# Forkline. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
#
# The job list of one balance pass (docs/ARCHITECTURE.md 13, RULES 12.6): every check for the
# levels given, the Twists included. Run it from the repo root:
#     bash tools/balance/run_pass.sh 2026-10-26 4                    # every level in campaign.json
#     bash tools/balance/run_pass.sh 2026-10-26 4 r2_l1 r2_l2        # only these levels
# Arguments: the date folder name under docs/balance/raw/, how many jobs run at once (default 4;
# the machine is shared, so keep it at 4 or fewer), then the levels (default: all of campaign.json).
# Environment: EVALS (builds per search, default 3000; RULES 12.6 asks for at least 2500 in the
# no super tower searches), DRY=1 (only write jobs.txt).
#
# Per level L, with key K = 10 * region + level number (11 to 46) and A the attacking tower's
# number (1 Sling Post, 2 Catapult, 3 Longbow, 4 Firework), every seed is a base plus 100 * K + A:
#   search any tower         base 720000   all three stars, tower use, level length
#   search one attacker      base 730000 and 760000, two seeds   no super tower: that attacker plus the
#                            level's Bells and Bakeries (only=solo:...), for each attacking tower offered
#   spread                   base 710000   random play, 250 per style
#   plain                    no seed       the plain mixed recipe of RULES 12.6 (compare_old=1 on region 1)
#   det                      base 750000, and again in a new process   same inputs, same result
# And for the level's Twist (twist=1):
#   plain, search any (1500 builds, base 770000), det (base 780000).
# Then, one at a time, the timing runs (benchmark.gd). Only processes this script starts are used.
# Nothing is ended by name. A job whose output file exists is skipped.

DATE="${1:-2026-10-26}"
JOBS="${2:-4}"
shift $(( $# < 2 ? $# : 2 ))
LEVELS="$*"
if [ -z "$LEVELS" ]; then
  LEVELS=$(grep -o '"r[0-9]*_l[0-9]*"' data/levels/campaign.json | tr -d '"')
fi
EVALS="${EVALS:-3000}"
OUT="docs/balance/raw/$DATE"
mkdir -p "$OUT"
LIST="$OUT/jobs.txt"
: > "$LIST"
for LEVEL in $LEVELS; do
  REGION=$(echo "$LEVEL" | sed 's/^r\([0-9]*\)_l.*/\1/')
  NUM=$(echo "$LEVEL" | sed 's/.*_l//')
  K=$((REGION * 10 + NUM))
  S=$((K * 100))
  OPT=""
  if [ "$REGION" = "1" ]; then OPT="compare_old=1"; fi
  # The towers the level offers, in the order of the tower numbers.
  TOWERS=$(grep -o '"towers": *\[[^]]*\]' "data/levels/$LEVEL.json" | head -1)
  A=0
  for TOWER in sling_post pumpkin_catapult longbow_loft firework_tower; do
    A=$((A + 1))
    if echo "$TOWERS" | grep -q "\"$TOWER\""; then
      echo "mode=search level=$LEVEL seed=$((730000 + S + A)) evals=$EVALS only=solo:$TOWER out=$OUT/${LEVEL}_solo_${TOWER}_a.json" >> "$LIST"
      echo "mode=search level=$LEVEL seed=$((760000 + S + A)) evals=$EVALS only=solo:$TOWER out=$OUT/${LEVEL}_solo_${TOWER}_b.json" >> "$LIST"
    fi
  done
  echo "mode=search level=$LEVEL seed=$((720000 + S)) evals=$EVALS only=any out=$OUT/${LEVEL}_search_any.json" >> "$LIST"
  echo "mode=spread level=$LEVEL seed=$((710000 + S)) n=250 out=$OUT/${LEVEL}_spread.json" >> "$LIST"
  echo "mode=plain level=$LEVEL $OPT out=$OUT/${LEVEL}_plain.json" >> "$LIST"
  echo "mode=det level=$LEVEL seed=$((750000 + S)) out=$OUT/${LEVEL}_det.json" >> "$LIST"
  if grep -q '"twist"' "data/levels/$LEVEL.json"; then
    echo "mode=plain level=$LEVEL twist=1 out=$OUT/${LEVEL}_plain_twist.json" >> "$LIST"
    echo "mode=search level=$LEVEL twist=1 seed=$((770000 + S)) evals=1500 only=any out=$OUT/${LEVEL}_search_twist.json" >> "$LIST"
    echo "mode=det level=$LEVEL twist=1 seed=$((780000 + S)) out=$OUT/${LEVEL}_det_twist.json" >> "$LIST"
  fi
done
if [ -n "$DRY" ]; then
  echo "wrote $(wc -l < "$LIST") jobs to $LIST"
  exit 0
fi
run_one() {
  OUTFILE=$(echo "$1" | sed 's/.*out=//')
  if [ -f "$OUTFILE" ]; then return; fi
  timeout 5400 godot --headless --path . --script res://tools/balance/run.gd -- $1 > /dev/null 2>> "$2/errors.txt"
}
export -f run_one
cat "$LIST" | xargs -P "$JOBS" -I{} bash -c 'run_one "{}" '"$OUT"
# The same determinism jobs again, in new processes: the chain hashes must match the first set.
for LEVEL in $LEVELS; do
  REGION=$(echo "$LEVEL" | sed 's/^r\([0-9]*\)_l.*/\1/')
  NUM=$(echo "$LEVEL" | sed 's/.*_l//')
  S=$(((REGION * 10 + NUM) * 100))
  if [ ! -f "$OUT/${LEVEL}_det_again.json" ]; then
    timeout 3000 godot --headless --path . --script res://tools/balance/run.gd -- mode=det level=$LEVEL seed=$((750000 + S)) \
      out="$OUT/${LEVEL}_det_again.json" > /dev/null 2>> "$OUT/errors.txt"
  fi
done
# The timing runs go last and one at a time, so the other jobs do not slow them down.
for LEVEL in $LEVELS; do
  if [ ! -f "$OUT/${LEVEL}_bench.json" ]; then
    timeout 3000 godot --headless --path . --script res://tools/balance/benchmark.gd -- level=$LEVEL \
      build="$OUT/${LEVEL}_search_any.json,$OUT/${LEVEL}_spread.json" out="$OUT/${LEVEL}_bench.json" > /dev/null 2>> "$OUT/errors.txt"
  fi
done
echo "done: $(ls "$OUT" | wc -l) files in $OUT"
