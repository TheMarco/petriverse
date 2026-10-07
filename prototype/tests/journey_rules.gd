extends SceneTree
const Run = preload("res://scripts/run_controller.gd")
const Save = preload("res://scripts/journey_save.gd")
const Profile = preload("res://scripts/journey_profile.gd")
var checks := 0
var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("exercise")
func expect(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("FAIL: ", label)
func select(run: RefCounted, path: Array = [0, 8, 9]) -> void:
	run.selection.start(run.board.anchors[path[0]])
	for id in path.slice(1):
		run.selection.visit(id)
	run.selection.visit(path[0])
func meal(run: RefCounted, kinds: Array, path: Array = [0,8,9]) -> void:
	run.enemies.clear()
	var center := Vector2.ZERO
	for id in path:
		center += run.board.anchors[id]
	center /= path.size()
	for i in kinds.size():
		run.next_enemy_id += 1
		var kind: String = kinds[i]
		if kind in ["food", "cyst", "spore"]:
			run.enemies.append(run.Harvest.Organism.new(run.next_enemy_id, kind, center, Vector2.ZERO, 0.0))
		else:
			run.enemies.append(run.Drifter.new(run.next_enemy_id, center, 0.0, kind))
func settle(run: RefCounted) -> void:
	for i in 600:
		if run.clots.is_empty() and not run.mother_damage.active():
			break
		run.step(1.0 / 60.0)
func fixture_stage(run: RefCounted, index: int) -> void:
	run.stage_index = index
	run.start_stage()
	run.begin_encounter()
func exercise() -> void:
	var run := Run.new(true, 73, true, true)
	expect(run.state == Run.BRIEF and run.full_run and run.journey, "Journey begins with a readable briefing")
	var time: float = run.elapsed
	run.step(20)
	expect(run.elapsed == time, "Briefing never consumes play time")
	expect(run.begin_encounter(), "Briefing enters encounter")
	meal(run, ["food", "food", "food"])
	run.harvest.nourishment = 6
	select(run)
	run.release()
	expect(run.state == Run.EVOLVE and run.stage_index == 0, "First meal opens evolution rather than ending the game")
	expect(not run.choose_mutation(run.offered_mutations[0]), "Cannot evolve during absorption aftermath")
	settle(run)
	expect(not run.choose_mutation(run.offered_mutations[0]), "Cannot spend food that is not stored")
	run.biomass = 9
	var chosen: String = run.offered_mutations[0]
	expect(run.choose_mutation(chosen), "Stored food buys a selected mutation")
	expect(run.stage_index == 1 and run.state == Run.BRIEF and run.mutations.has(chosen) and run.biomass == 3, "Next encounter preserves the mutation and unspent food")
	for index in 12:
		fixture_stage(run, index)
		expect(run.board.validate_board().is_empty(), "Legal layout in encounter %d" % index)
		expect(run.stage_elapsed == 0 and run.harvest.nourishment == 0, "Encounter clock and food objective reset in %d" % index)
		run.harvest.nourishment = int(run.harvest.spec.food)
		if run.harvest.spec.mode == "boss":
			run.boss_defeated = true
		else:
			run.harvest.rescued = int(run.harvest.spec.target)
			run.harvest.purified = int(run.harvest.spec.target)
			run.harvest.defended = int(run.harvest.spec.target)
			run.harvest.visited = [0, 1, 2, 3]
		run.check_completion()
		expect(run.state == (Run.SUCCESS if index == 11 else Run.EVOLVE), "Only final boss completes the journey (%d)" % index)
		if index < 11:
			expect(run.choose_journey_evolution("continue") and run.stage_index == index + 1, "Forward path exists without buying an upgrade (%d)" % index)
	expect(run.completed_dishes == 3, "All dish victories retained")
	fixture_stage(run, 0)
	run.mutations.clear()
	run.add_mutation("filter")
	run.add_mutation("catalyst")
	meal(run, ["food", "cyst", "cyst"])
	select(run)
	var preview: Dictionary = run.harvest_preview()
	var result: Dictionary = run.release()
	expect(preview.poison == 1 and preview.food == 5 and result.poison == preview.poison and result.food == preview.food, "Filter + Catalyst composition agrees with preview")
	expect(is_equal_approx(result.recovery, 4.2), "Filtering has its stated recovery tradeoff")
	settle(run)
	fixture_stage(run, 4)
	run.mutations.clear()
	meal(run, ["cyst", "cyst"])
	select(run)
	result = run.release()
	expect(result.purified == 2 and result.poison == 0 and run.harvest.purified == 2, "Cyst-only membrane purifies in a purification encounter")
	settle(run)
	meal(run, ["food", "cyst"])
	select(run)
	result = run.release()
	expect(result.purified == 0 and result.poison == 1, "Mixed purification meal still has a cost")
	settle(run)
	fixture_stage(run, 1)
	meal(run, ["spore", "food"])
	select(run)
	result = run.release()
	expect(result.rescued == 1 and run.harvest.rescued == 1 and result.food == 1, "Rescue and feeding are distinct objectives")
	fixture_stage(run, 6)
	run.mutations.clear()
	run.add_mutation("enzyme")
	run.add_mutation("symbiosis")
	var wide: Array = [0,1,2,10,9,8]
	meal(run, ["shellback"], wide)
	select(run, wide)
	preview = run.harvest_preview()
	result = run.release()
	expect(result.valid and preview.food == 2 and result.food == 2 and result.threats == 1, "Released wide enzyme loop preserves armor and Symbiosis semantics")
	fixture_stage(run, 0)
	run.mutations.clear()
	run.add_mutation("grazer")
	meal(run, ["food", "food"])
	select(run)
	expect(run.release().food == 3, "Grazer rewards small clean meals")
	fixture_stage(run, 0)
	run.mutations.clear()
	run.add_mutation("feast")
	meal(run, ["food", "food", "food", "food"])
	select(run)
	expect(run.release().food == 6, "Feast rewards a larger meal")
	fixture_stage(run, 0)
	run.mutations.clear()
	run.add_mutation("nursery")
	run.integrity = 3
	run.mother_damage.prepare_integrity(3)
	run.harvest.clean_food = 10
	meal(run, ["food", "food"])
	select(run)
	run.release()
	expect(run.integrity == 4 and run.mother_damage.lost.count(true) == 1, "Nursery regrows a logical and visible organelle")
	fixture_stage(run, 0)
	run.state = Run.EVOLVE
	run.biomass = 8
	run.integrity = 2
	run.mother_damage.prepare_integrity(2)
	expect(run.choose_journey_evolution("repair") and run.integrity == 4 and run.biomass == 2 and run.mother_damage.lost.count(true) == 1, "Repair spends stores and restores real cores before travel")
	# Exact resume, including an in-flight absorption and node drift.
	run.begin_encounter()
	run.step(2.0)
	meal(run, ["food", "cyst"])
	select(run)
	run.release()
	run.step(0.6)
	var snapshot := Save.capture(run)
	var resumed := Run.new(true, 9, true, true)
	expect(Save.restore(resumed, snapshot), "Snapshot restores")
	expect(resumed.harvest.nourishment == run.harvest.nourishment and resumed.integrity == run.integrity and resumed.stage_elapsed == run.stage_elapsed, "Resume preserves food, wounds and encounter time")
	expect(resumed.clots.size() == run.clots.size() and resumed.board.anchors == run.board.anchors and resumed.cells[0].remaining == run.cells[0].remaining, "Resume preserves absorption and drifting geometry")
	for i in 300:
		run.step(1.0 / 60.0)
		resumed.step(1.0 / 60.0)
	expect(Save.capture(run).enemies == Save.capture(resumed).enemies and run.board.anchors == resumed.board.anchors, "Resumed simulation stays deterministic")
	expect(Save.write(run, "/tmp/microverse-journey-test.cfg") == OK and not Save.read("/tmp/microverse-journey-test.cfg").is_empty(), "Disk save round trip")
	var disk_data := Save.read("/tmp/microverse-journey-test.cfg")
	expect(Save.restore(resumed, disk_data.snapshot) and resumed.board.anchors == run.board.anchors and resumed.harvest.nourishment == run.harvest.nourishment, "Serialized disk data restores real simulation types and values")
	var saved_stage: int = run.stage_index
	var saved_mutations: Array = run.mutations.duplicate()
	run.state = Run.LOSS
	expect(run.retry_encounter() and run.stage_index == saved_stage and run.mutations == saved_mutations and run.integrity >= 3, "Retry preserves earlier progression and viable health")
	for index in [3, 7, 11]:
		fixture_stage(run, index)
		var boss = run.boss()
		expect(boss != null and boss.nuclei().size() == (2 if index == 11 else 1), "Boss has its own capture anatomy at stage %d" % index)
		if index == 7:
			expect(not boss.can_take_pulse(), "Regent begins protected")
			run.enemies = run.enemies.filter(func(e): return e.kind != "warden")
			run.harvest.ecology.resolve_gates(run)
			expect(boss.can_take_pulse() and boss.open_remaining==14.0, "Removing the shields creates a fourteen-second capture window")
	var profile := Profile.new()
	profile.path = "/tmp/microverse-journey-profile-test.cfg"
	expect(profile.unlocked("wanderer") and not profile.unlocked("weaver"), "Alternative colonies start locked")
	run.completed_dishes = 1
	profile.observe(run)
	expect(profile.unlocked("weaver") and not profile.unlocked("symbiont"), "Stillwater unlocks Weaver")
	run.completed_dishes = 2
	profile.observe(run)
	expect(profile.unlocked("symbiont"), "Glassgarden unlocks Symbiont")
	run.state = Run.SUCCESS
	profile.observe(run)
	profile.observe(run)
	expect(profile.victories == 1, "A resumed victory cannot count twice")
	var loaded := Profile.new()
	loaded.path = profile.path
	loaded.load_profile()
	expect(loaded.unlocked("symbiont") and loaded.discovered == profile.discovered and loaded.victories == 1, "Discoveries and unlocks persist on disk")
	run.dispose()
	resumed.dispose()
	print("JOURNEY RULES: %d checks; %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
