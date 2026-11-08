#!/bin/sh
# Runs every headless suite, prints each result, then a summary.
# Exits non-zero if any gating suite fails or logs a script or shader error.
set -u
cd -- "$(dirname -- "$0")"
engine=${GODOT_BIN:-godot}
log=$(mktemp /tmp/microverse-tests.XXXXXX)
trap 'rm -f "$log"' EXIT
trap 'rm -f "$log"; exit 130' HUP INT TERM
failed=""
observed=""

# run <file> <marker> <gating: yes|no> [extra engine arguments...]
run() {
	file=$1
	marker=$2
	gating=$3
	shift 3
	if "$engine" --headless --path . --script "res://tests/$file.gd" --log-file "/tmp/microverse-$file-engine.log" "$@" >"$log" 2>&1; then
		status=0
	else
		status=1
	fi
	cat "$log"
	# Some engine script-load errors return zero. Require the completion marker too.
	grep -q "$marker: .* checks; 0 failures" "$log" || status=1
	if grep -Eq 'SCRIPT ERROR:|SHADER ERROR:|Shader compilation failed' "$log"; then status=1; fi
	if [ "$status" -ne 0 ]; then
		if [ "$gating" = yes ]; then failed="$failed $file"; else observed="$observed $file"; fi
	fi
}

run test_suite RESULT yes
run amoeba AMOEBA yes
run fluid_dynamics 'FLUID DYNAMICS' yes
run node_drift 'NODE DRIFT' yes
run clot_recovery 'CLOT RECOVERY' yes
run integration INTEGRATION yes
# --no-report keeps artifacts/human-pacing.json unchanged on every run.
run human_pacing PACING yes -- --no-report
run visual_motion 'VISUAL MOTION' yes --fixed-fps 60
run mother_damage 'MOTHER DAMAGE' yes

for spec in 'capture_confidence:CAPTURE CONFIDENCE' 'save_recovery:SAVE RECOVERY' 'evolution_comparison:EVOLUTION COMPARISON' 'producer_improvements:PRODUCER IMPROVEMENTS' 'producer_lab:PRODUCER LAB' 'title_screen:TITLE SCREEN' 'dish_labels:DISH LABELS' 'phages:PHAGES' 'evolution_rules:EVOLUTION RULES' 'evolution_visuals:EVOLUTION VISUALS' 'full_run:CAMPAIGN' 'campaign_visual:CAMPAIGN VISUAL' 'audio:AUDIO' 'cyst_nudge:CYST NUDGE' 'journey_rules:JOURNEY RULES' 'journey_mutations:JOURNEY MUTATIONS' 'onboarding:ONBOARDING' 'free_polygons:FREE POLYGONS' 'mother_boundary:MOTHER BOUNDARY' 'procedural_journey:PROCEDURAL JOURNEY' 'journey_ecology:JOURNEY ECOLOGY' 'encounter_rhythm:ENCOUNTER RHYTHM' 'journey_mastery:JOURNEY MASTERY' 'food_web:FOOD WEB' 'home_pond:HOME POND RULES' 'pond_memories:POND MEMORIES' 'cradle_story:CRADLE STORY' 'discovery_journal:DISCOVERY JOURNAL' 'rare_visitors:RARE VISITORS' 'habitat_events:HABITAT EVENTS' 'journey_habitats:JOURNEY HABITATS' 'boss_patterns:BOSS PATTERNS' 'journey_clarity:JOURNEY CLARITY' 'creature_arrivals:CREATURE ARRIVALS' 'expedition_creatures:EXPEDITION CREATURES' 'mission_appearance:MISSION APPEARANCE' 'harvest_rules:HARVEST RULES' 'harvest_pacing:HARVEST PACING' 'game_feel:GAME FEEL' 'interface_dialogs:INTERFACE DIALOGS'; do
	file=${spec%%:*}
	marker=${spec#*:}
	if [ "$file" = audio ]; then
		run "$file" "$marker" yes -- --require-assets
	else
		run "$file" "$marker" yes
	fi
done

echo
if [ -n "$observed" ]; then echo "OBSERVED (not gating):$observed"; fi
if [ -n "$failed" ]; then
	echo "FAILED:$failed"
	exit 1
fi
echo "ALL GATING SUITES PASSED"
