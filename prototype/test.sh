#!/bin/sh
set -eu
cd -- "$(dirname -- "$0")"
engine=${GODOT_BIN:-godot}
log=$(mktemp /tmp/microverse-tests.XXXXXX)
trap 'rm -f "$log"' EXIT HUP INT TERM
if ! "$engine" --headless --path . --script res://tests/test_suite.gd --log-file /tmp/microverse-unit-engine.log >"$log" 2>&1; then
	cat "$log"
	exit 1
fi
cat "$log"
# Some engine script-load errors return zero. Require the completion marker too.
grep -q 'RESULT: .* checks; 0 failures' "$log"
if grep -Eq 'SCRIPT ERROR:|SHADER ERROR:|Shader compilation failed' "$log"; then exit 1; fi
if ! "$engine" --headless --path . --script res://tests/amoeba.gd --log-file /tmp/microverse-amoeba-engine.log >"$log" 2>&1; then
	cat "$log"
	exit 1
fi
cat "$log"
grep -q 'AMOEBA: .* checks; 0 failures' "$log"
if grep -Eq 'SCRIPT ERROR:|SHADER ERROR:|Shader compilation failed' "$log"; then exit 1; fi
if ! "$engine" --headless --path . --script res://tests/fluid_dynamics.gd --log-file /tmp/microverse-fluid-engine.log >"$log" 2>&1; then
	cat "$log"
	exit 1
fi
cat "$log"
grep -q 'FLUID DYNAMICS: .* checks; 0 failures' "$log"
if grep -Eq 'SCRIPT ERROR:|SHADER ERROR:|Shader compilation failed' "$log"; then exit 1; fi
if ! "$engine" --headless --path . --script res://tests/node_drift.gd --log-file /tmp/microverse-drift-engine.log >"$log" 2>&1; then
	cat "$log"
	exit 1
fi
cat "$log"
grep -q 'NODE DRIFT: .* checks; 0 failures' "$log"
if grep -Eq 'SCRIPT ERROR:|SHADER ERROR:|Shader compilation failed' "$log"; then exit 1; fi
if ! "$engine" --headless --path . --script res://tests/clot_recovery.gd --log-file /tmp/microverse-clot-engine.log >"$log" 2>&1; then
	cat "$log"
	exit 1
fi
cat "$log"
grep -q 'CLOT RECOVERY: .* checks; 0 failures' "$log"
if grep -Eq 'SCRIPT ERROR:|SHADER ERROR:|Shader compilation failed' "$log"; then exit 1; fi
if ! "$engine" --headless --path . --script res://tests/integration.gd --log-file /tmp/microverse-integration-engine.log >"$log" 2>&1; then
	cat "$log"
	exit 1
fi
cat "$log"
grep -q 'INTEGRATION: .* checks; 0 failures' "$log"
if grep -Eq 'SCRIPT ERROR:|SHADER ERROR:|Shader compilation failed' "$log"; then exit 1; fi
if ! "$engine" --headless --path . --script res://tests/human_pacing.gd --log-file /tmp/microverse-pacing-engine.log >"$log" 2>&1; then
	cat "$log"
	exit 1
fi
cat "$log"
grep -q 'PACING: .* checks; 0 failures' "$log"
if grep -Eq 'SCRIPT ERROR:|SHADER ERROR:|Shader compilation failed' "$log"; then exit 1; fi
if ! "$engine" --headless --path . --script res://tests/visual_motion.gd --fixed-fps 60 --log-file /tmp/microverse-visual-engine.log >"$log" 2>&1; then
	cat "$log"
	exit 1
fi
cat "$log"
grep -q 'VISUAL MOTION: .* checks; 0 failures' "$log"
if grep -Eq 'SCRIPT ERROR:|SHADER ERROR:|Shader compilation failed' "$log"; then exit 1; fi
if ! "$engine" --headless --path . --script res://tests/mother_damage.gd --log-file /tmp/microverse-mother-engine.log >"$log" 2>&1; then
	cat "$log"
	exit 1
fi
cat "$log"
grep -q 'MOTHER DAMAGE: .* checks; 0 failures' "$log"
if grep -Eq 'SCRIPT ERROR:|SHADER ERROR:|Shader compilation failed' "$log"; then exit 1; fi

for spec in 'title_screen:TITLE SCREEN' 'dish_labels:DISH LABELS' 'phages:PHAGES' 'evolution_rules:EVOLUTION RULES' 'evolution_visuals:EVOLUTION VISUALS' 'full_run:CAMPAIGN' 'campaign_visual:CAMPAIGN VISUAL' 'audio:AUDIO' 'cyst_nudge:CYST NUDGE' 'journey_rules:JOURNEY RULES' 'journey_mutations:JOURNEY MUTATIONS' 'onboarding:ONBOARDING' 'free_polygons:FREE POLYGONS' 'mother_boundary:MOTHER BOUNDARY' 'procedural_journey:PROCEDURAL JOURNEY' 'journey_ecology:JOURNEY ECOLOGY' 'encounter_rhythm:ENCOUNTER RHYTHM' 'journey_mastery:JOURNEY MASTERY' 'food_web:FOOD WEB' 'home_pond:HOME POND RULES' 'pond_memories:POND MEMORIES' 'cradle_story:CRADLE STORY' 'discovery_journal:DISCOVERY JOURNAL' 'rare_visitors:RARE VISITORS' 'habitat_events:HABITAT EVENTS' 'journey_habitats:JOURNEY HABITATS' 'boss_patterns:BOSS PATTERNS' 'journey_clarity:JOURNEY CLARITY' 'creature_arrivals:CREATURE ARRIVALS' 'expedition_creatures:EXPEDITION CREATURES' 'mission_appearance:MISSION APPEARANCE' 'harvest_rules:HARVEST RULES' 'harvest_pacing:HARVEST PACING'; do
	file=${spec%%:*}
	marker=${spec#*:}
	if [ "$file" = audio ]; then set -- -- --require-assets; else set --; fi
	if ! "$engine" --headless --path . --script "res://tests/$file.gd" --log-file "/tmp/microverse-$file-engine.log" "$@" >"$log" 2>&1; then
		cat "$log"
		exit 1
	fi
	cat "$log"
	grep -q "$marker: .* checks; 0 failures" "$log"
	if grep -Eq 'SCRIPT ERROR:|SHADER ERROR:|Shader compilation failed' "$log"; then exit 1; fi
done
