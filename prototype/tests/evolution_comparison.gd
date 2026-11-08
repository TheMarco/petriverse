extends "res://tests/journey_rules.gd"
const Comparison = preload("res://scripts/evolution_comparison.gd")
const Card = preload("res://scripts/mutation_card.gd")

func snapshot(run: RefCounted) -> Dictionary:
	return {"mutations": run.mutations.duplicate(), "enemies": run.enemies.size(),
		"integrity": run.integrity, "biomass": run.biomass, "clean": run.harvest.clean_food}

func check_case(run: RefCounted, owned: Array, offered: String, kinds: Array, path: Array) -> void:
	fixture_stage(run, 0)
	run.mutations.clear()
	for id in owned:
		run.add_mutation(id)
	run.harvest.spec.mode = "feed"
	var before_state := snapshot(run)
	var comparison: Dictionary = Comparison.compare(run, offered)
	expect(snapshot(run) == before_state, "Comparison does not mutate live run (%s)" % offered)
	meal(run, kinds, path)
	select(run, path)
	var actual_before: Dictionary = run.harvest.outcome(run.enemies.map(func(e): return e.id), run, path.size())
	var after_traits := owned.duplicate()
	after_traits.append(offered)
	run.mutations = after_traits
	run.selection.max_vertices = run.Mutations.maximum(after_traits)
	var actual_after: Dictionary = run.harvest.outcome(run.enemies.map(func(e): return e.id), run, path.size())
	expect(int(comparison.before.food) == int(actual_before.food) and int(comparison.after.food) == int(actual_after.food), "Exact food before/after vs JourneyHarvest (%s): %s vs %s" % [offered, comparison.before.food, actual_before.food])
	expect(int(comparison.before.poison) == int(actual_before.poison) and int(comparison.after.poison) == int(actual_after.poison), "Exact poison before/after (%s)" % offered)
	expect(is_equal_approx(float(comparison.before.recovery), run.Mutations.recovery(owned, path.size())) and is_equal_approx(float(comparison.after.recovery), run.Mutations.recovery(after_traits, path.size())), "Recovery matches Mutations.recovery (%s)" % offered)
	expect(int(comparison.after.capacity) == run.Mutations.maximum(after_traits), "Capacity matches Mutations.maximum (%s)" % offered)
	expect(not str(comparison.synergy).is_empty() and not str(comparison.playstyle).is_empty() and str(comparison.assumption).contains("short links"), "Synergy, playstyle and strain assumption present (%s)" % offered)

func exercise() -> void:
	var run := Run.new(true, 73, true, true)
	# Filter + catalyst owned build, catalyst-relevant sample is food+2 cysts.
	check_case(run, ["filter"], "catalyst", ["food", "cyst", "cyst"], [0, 8, 9])
	check_case(run, ["catalyst"], "filter", ["food", "cyst", "cyst"], [0, 8, 9])
	# Fission + grazer stack on the same clean small loop.
	check_case(run, ["fission"], "grazer", ["food", "food"], [0, 8, 9])
	check_case(run, ["grazer"], "fission", ["food", "food", "food"], [0, 8, 9])
	check_case(run, [], "fission", ["food", "food", "food"], [0, 8, 9])
	check_case(run, [], "elastic", ["food", "food", "food"], [0, 1, 2, 10, 9, 8])
	check_case(run, ["elastic"], "feast", ["food", "food", "food", "food"], [0, 1, 2, 10, 9, 8])
	check_case(run, [], "enzyme", ["shellback"], [0, 1, 2, 10, 9, 8])
	check_case(run, [], "symbiosis", ["drifter"], [0, 8, 9])
	# Legacy configure compatibility and the journey entry point.
	fixture_stage(run, 0)
	run.mutations.clear()
	run.add_mutation("filter")
	var card := Card.new()
	card.size = Vector2(236, 346)
	card.text_multiplier = 1.25
	card.configure(run.Mutations.journey_definition("catalyst"), 0, run.mutations)
	expect(card.data.id == "catalyst" and card.comparison.is_empty(), "Legacy configure still works without a run")
	card.configure_journey(run, "catalyst", 1)
	expect(card.number == 2 and int(card.comparison.after.food) == 5 and card.detail_summary.contains("short links"), "configure_journey exposes exact comparison and detail summary")
	expect(snapshot(run).mutations == ["filter"], "Card configuration does not mutate live run")
	card.free()
	run.dispose()
	print("EVOLUTION COMPARISON: %d checks; %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
