#!/bin/bash
# Forkline. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
#
# The job list of one balance pass (docs/ARCHITECTURE.md 13, RULES 12.6 as revised by G2): every check for the
# levels given, the Twists included. Run it from the repo root (a clean checkout of the commit measured):
#     bash tools/balance/run_pass.sh 2026-10-26 4                    # every level in campaign.json
#     bash tools/balance/run_pass.sh 2026-10-26 4 r2_l1 r2_l2        # only these levels
# Arguments: the date folder name under docs/balance/raw/, how many jobs run at once (default 4;
# the machine is shared, so keep it at 3 or fewer), then the levels (default: all of campaign.json).
# Environment:
#   EVALS        builds per any-tower search (default 3000)
#   EVALS_SOLO   builds per lone attacker search (default 6000, RULES 12.6 as revised by G2)
#   STOP_DRY     a lone attacker search stops when this many builds are tried and none has won (default 2500)
#   SEED_SHIFT   added to every seed (default 0, which gives the seeds of the 2026-10-24 pass; the 2026-10-25 pass used 100000)
#   DRY=1        only write jobs.txt
# Several copies of this script can work on one folder: a job is taken by making a lock folder, so no job runs twice.
# If a copy is stopped, remove its lock folders (docs/balance/raw/DATE/.lock_*) before starting it again.
#
# Which lone attackers get searches is decided by `mode=need` (RULES 12.6): a tower that cannot hit flyers needs no
# search on a level whose flyers cost 6 lives or more, and a tower that cannot hit walkers likewise for walkers.
#
# Per level L, with key K = 10 * region + level number (11 to 46) and A the attacking tower's
# number (1 Sling Post, 2 Catapult, 3 Longbow, 4 Firework), every seed is SEED_SHIFT plus a base plus 100 * K + A:
#   search any tower         base 720000   all three stars, tower use, level length
#   search one attacker      base 730000 and 760000, two seeds   no super tower: that attacker plus the
#                            level's Bells and Bakeries (only=solo:...), for each attacking tower that needs it
#   spread                   base 710000   random play, 250 per style
#   plain                    no seed       the plain mixed recipe of RULES 12.6 (compare_old=1 on region 1)
#   det                      base 750000, and again in a new process   same inputs, same result
# And for the level's Twist (twist=1):
#   plain, search any (1500 builds, base 770000), det (base 780000).
# Then run_pass_post.sh (the dry pairs again, the determinism jobs again, the timing runs). Only processes this
# script starts are used. Nothing is ended by name. A job whose output file exists is skipped.

DATE="${1:-2026-10-26}"
JOBS="${2:-4}"
shift $(( $# < 2 ? $# : 2 ))
LEVELS="$*"
if [ -z "$LEVELS" ]; then
  LEVELS=$(grep -o '"r[0-9]*_l[0-9]*"' data/levels/campaign.json | tr -d '"')
fi
EVALS="${EVALS:-3000}"
EVALS_SOLO="${EVALS_SOLO:-6000}"
STOP_DRY="${STOP_DRY:-2500}"
SHIFT="${SEED_SHIFT:-0}"
OUT="docs/balance/raw/$DATE"
mkdir -p "$OUT"
LIST="$OUT/jobs.txt"
GODOT="godot --headless --path . --script res://tools/balance/run.gd --"

# Phase 0: which lone attackers each level needs (instant, no plays).
for LEVEL in $LEVELS; do
  if [ ! -f "$OUT/${LEVEL}_need.json" ] && [ -z "$DRY" ]; then
    $GODOT mode=need level=$LEVEL out="$OUT/${LEVEL}_need.json" > /dev/null 2>> "$OUT/errors.txt"
  fi
done

: > "$LIST.new"
# The slow lone attacker searches go first, then the rest.
for LEVEL in $LEVELS; do
  REGION=$(echo "$LEVEL" | sed 's/^r\([0-9]*\)_l.*/\1/')
  NUM=$(echo "$LEVEL" | sed 's/.*_l//')
  S=$((SHIFT + (REGION * 10 + NUM) * 100))
  NEEDED=$(tr -d '[:space:]' < "$OUT/${LEVEL}_need.json" 2>/dev/null | grep -o '"search_needed":\[[^]]*\]')
  A=0
  for TOWER in sling_post pumpkin_catapult longbow_loft firework_tower; do
    A=$((A + 1))
    if echo "$NEEDED" | grep -q "\"$TOWER\""; then
      echo "mode=search level=$LEVEL seed=$((730000 + S + A)) evals=$EVALS_SOLO stop_dry=$STOP_DRY only=solo:$TOWER out=$OUT/${LEVEL}_solo_${TOWER}_a.json" >> "$LIST.new"
      echo "mode=search level=$LEVEL seed=$((760000 + S + A)) evals=$EVALS_SOLO stop_dry=$STOP_DRY only=solo:$TOWER out=$OUT/${LEVEL}_solo_${TOWER}_b.json" >> "$LIST.new"
    fi
  done
done
for LEVEL in $LEVELS; do
  REGION=$(echo "$LEVEL" | sed 's/^r\([0-9]*\)_l.*/\1/')
  NUM=$(echo "$LEVEL" | sed 's/.*_l//')
  S=$((SHIFT + (REGION * 10 + NUM) * 100))
  OPT=""
  if [ "$REGION" = "1" ]; then OPT="compare_old=1"; fi
  echo "mode=search level=$LEVEL seed=$((720000 + S)) evals=$EVALS only=any out=$OUT/${LEVEL}_search_any.json" >> "$LIST.new"
  echo "mode=spread level=$LEVEL seed=$((710000 + S)) n=250 out=$OUT/${LEVEL}_spread.json" >> "$LIST.new"
  echo "mode=plain level=$LEVEL $OPT out=$OUT/${LEVEL}_plain.json" >> "$LIST.new"
  echo "mode=det level=$LEVEL seed=$((750000 + S)) out=$OUT/${LEVEL}_det.json" >> "$LIST.new"
  if grep -q '"twist"' "data/levels/$LEVEL.json"; then
    echo "mode=plain level=$LEVEL twist=1 out=$OUT/${LEVEL}_plain_twist.json" >> "$LIST.new"
    echo "mode=search level=$LEVEL twist=1 seed=$((770000 + S)) evals=1500 only=any out=$OUT/${LEVEL}_search_twist.json" >> "$LIST.new"
    echo "mode=det level=$LEVEL twist=1 seed=$((780000 + S)) out=$OUT/${LEVEL}_det_twist.json" >> "$LIST.new"
  fi
done
mv "$LIST.new" "$LIST"
if [ -n "$DRY" ]; then
  echo "wrote $(wc -l < "$LIST") jobs to $LIST"
  exit 0
fi
run_one() {
  OUTFILE=$(echo "$1" | sed 's/.*out=//')
  if [ -f "$OUTFILE" ]; then return; fi
  if ! mkdir "$2/.lock_$(basename "$OUTFILE")" 2> /dev/null; then return; fi
  timeout 7200 godot --headless --path . --script res://tools/balance/run.gd -- $1 > /dev/null 2>> "$2/errors.txt"
}
export -f run_one
cat "$LIST" | xargs -P "$JOBS" -I{} bash -c 'run_one "{}" '"$OUT"
echo "jobs done: $(ls "$OUT" | wc -l) files in $OUT. Next: bash tools/balance/run_pass_post.sh $DATE $JOBS"
