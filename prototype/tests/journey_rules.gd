extends SceneTree
const Run = preload("res://scripts/run_controller.gd")
const Save = preload("res://scripts/journey_save.gd")
const Profile = preload("res://scripts/journey_profile.gd")
const LoopStrain = preload("res://scripts/loop_strain.gd")
const Route = preload("res://scripts/journey_route.gd")
const Expedition = preload("res://scripts/expedition_creatures.gd")
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
		expect(run.max_integrity == run.MotherAppearance.capacity_for_stage(index) and run.mother_damage.capacity == run.max_integrity, "The Mother grows health organelles through all five ages (%d)" % index)
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
	expect(is_equal_approx(result.recovery, 4.2+LoopStrain.penalty([0,8,9],run.board.anchors)), "Filtering and long-link strain both contribute to recovery")
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
	run.integrity = 2
	run.mother_damage.prepare_integrity(2)
	run.harvest.clean_food = 10
	meal(run, ["food", "food"])
	select(run)
	run.release()
	expect(run.integrity == 3 and run.mother_damage.lost.count(true) == 0, "Nursery regrows a logical and visible organelle")
	fixture_stage(run, 0)
	run.state = Run.EVOLVE
	run.biomass = 8
	run.integrity = 1
	run.mother_damage.prepare_integrity(1)
	expect(run.choose_journey_evolution("repair") and run.integrity == 3 and run.biomass == 2 and run.mother_damage.lost.count(true) == 0, "Repair spends stores and restores real cores before travel")
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
	var legacy_snapshot: Dictionary = snapshot.duplicate(true)
	legacy_snapshot.run.erase("max_integrity")
	legacy_snapshot.run.integrity = 5
	legacy_snapshot.mother.lost = [false,false,false,false,false]
	var migrated := Run.new(true,11,true,true)
	expect(Save.restore(migrated,legacy_snapshot) and migrated.max_integrity==3 and migrated.integrity==3 and migrated.mother_damage.lost.count(true)==0, "An older five-core save resumes with the new visible capacity")
	migrated.dispose()
	var strained := Run.new(true,31,true,true)
	var short_path := [0,1,2]
	var wide_path := [0,8,9]
	var short_delay: float = LoopStrain.penalty(short_path,strained.board.anchors)
	var wide_delay: float = LoopStrain.penalty(wide_path,strained.board.anchors)
	expect(wide_delay > short_delay and wide_delay > 0.0,"A wide membrane carries a larger recovery cost than nearby links")
	strained.begin_encounter()
	select(strained,wide_path)
	var stretched_capture: Dictionary = strained.release()
	expect(stretched_capture.valid and is_equal_approx(stretched_capture.strain,wide_delay) and is_equal_approx(strained.cells[0].remaining,stretched_capture.recovery),"The visible long-link cost is paid by actual cells on release")
	strained.dispose()
	var thirty: Array = Route.make(32)
	for i in 15:
		thirty.insert(4,thirty[3].duplicate(true))
	var guarding := Run.new(true,32,true,true)
	guarding.route_plan = thirty.duplicate(true)
	guarding.route_position = 2
	guarding.long_journey = true
	guarding.expedition_roster = Expedition.plan(guarding.run_seed,guarding.route_plan,[])
	guarding.stage_index = 2
	guarding.start_stage()
	expect(guarding.growth_slot()==1 and guarding.choose_growth_role("guard") and guarding.growth_active("guard")==1,"The fourth organelle offers a functional guard choice")
	guarding.begin_encounter()
	guarding.enemies = [Run.Drifter.new(701,guarding.board.center+Vector2(40,0),0.0)]
	guarding.resolve_contacts()
	expect(guarding.integrity==4 and guarding.guardian_spent==1 and guarding.mother_damage.lost.count(true)==0,"The guard visibly preserves a health core on the first hunter contact")
	guarding.enemies = [Run.Drifter.new(702,guarding.board.center+Vector2(40,0),0.0)]
	guarding.resolve_contacts()
	expect(guarding.integrity==3 and guarding.mother_damage.lost.count(true)==1,"A spent guard leaves the next hunter dangerous")
	var guard_snapshot: Dictionary = Save.capture(guarding)
	var guard_resume := Run.new(true,33,true,true)
	expect(Save.restore(guard_resume,guard_snapshot) and guard_resume.growth_roles.get(1)=="guard" and guard_resume.guardian_spent==1 and guard_resume.guardian_recovery==1,"Save and resume preserve the growth choice and Guard recovery")
	guard_resume.dispose()
	guarding.heal(1)
	guarding.route_position = 19
	guarding.stage_index = 3
	guarding.start_stage()
	expect(guarding.guardian_spent==1 and guarding.guardian_recovery==0 and guarding.guardian_resting==1,"A Guard that blocked a hunter rests through the following encounter")
	var resting_snapshot: Dictionary = Save.capture(guarding)
	var resting_resume := Run.new(true,128,true,true)
	expect(Save.restore(resting_resume,resting_snapshot) and resting_resume.guardian_resting==1,"The second Guard recovery round survives save and resume")
	resting_resume.dispose()
	guarding.begin_encounter()
	guarding.enemies = [Run.Drifter.new(704,guarding.board.center+Vector2(40,0),0.0)]
	guarding.resolve_contacts()
	expect(guarding.integrity==3 and guarding.guardian_recovery==0,"The recovering Guard cannot block another hunter")
	guarding.heal(1)
	guarding.route_position = 20
	guarding.stage_index = 4
	guarding.start_stage()
	expect(guarding.guardian_spent==1 and guarding.guardian_resting==0,"A blocked Guard rests for a second encounter on the original route")
	guarding.route_position = 21
	guarding.stage_index = 4
	guarding.start_stage()
	expect(guarding.guardian_spent==0,"A Guard is ready after two complete recovery encounters")
	guarding.dispose()
	var repair_probe := Run.new(true,125,true,true)
	repair_probe.route_plan = thirty.duplicate(true)
	repair_probe.route_position = 2
	repair_probe.long_journey = true
	repair_probe.expedition_roster = Expedition.plan(repair_probe.run_seed,repair_probe.route_plan,[])
	repair_probe.stage_index = 2
	repair_probe.start_stage()
	repair_probe.state = Run.EVOLVE
	repair_probe.integrity = 1
	repair_probe.mother_damage.prepare_integrity(1)
	repair_probe.biomass = 8
	expect(repair_probe.choose_journey_evolution("repair") and repair_probe.repair_waiting(),"A repair in the thirty-encounter route must rest through the next encounter")
	var repair_snapshot: Dictionary = Save.capture(repair_probe)
	var repair_resume := Run.new(true,126,true,true)
	expect(Save.restore(repair_resume,repair_snapshot) and repair_resume.repair_waiting(),"Repair recovery survives save and resume")
	repair_resume.state = Run.EVOLVE
	repair_resume.integrity = 2
	repair_resume.mother_damage.prepare_integrity(2)
	repair_resume.biomass = 8
	expect(not repair_resume.choose_journey_evolution("repair") and repair_resume.choose_journey_evolution("continue") and not repair_resume.repair_waiting(),"A second repair needs one complete intervening encounter")
	repair_resume.dispose()
	repair_probe.dispose()
	var late_position := -1
	for i in thirty.size():
		if int(thirty[i].stage)>=8:
			late_position = i
			break
	var repair_late := Run.new(true,127,true,true)
	repair_late.route_plan = thirty.duplicate(true)
	repair_late.route_position = late_position
	repair_late.long_journey = true
	repair_late.expedition_roster = Expedition.plan(repair_late.run_seed,repair_late.route_plan,[])
	repair_late.stage_index = int(thirty[late_position].stage)
	repair_late.start_stage()
	repair_late.state = Run.EVOLVE
	repair_late.integrity = repair_late.max_integrity-1
	repair_late.mother_damage.prepare_integrity(repair_late.integrity)
	repair_late.biomass = 30
	expect(repair_late.stage_index>=8 and repair_late.repair_needs_deeper_wound() and not repair_late.choose_journey_evolution("repair"),"One wounded core no longer triggers a full late-route repair")
	repair_late.integrity -= 1
	repair_late.mother_damage.prepare_integrity(repair_late.integrity)
	expect(not repair_late.repair_needs_deeper_wound() and repair_late.choose_journey_evolution("repair"),"Two wounded cores still allow a late-route repair")
	repair_late.dispose()
	var feeding := Run.new(true,34,true,true)
	feeding.stage_index = 2
	feeding.start_stage()
	expect(feeding.choose_growth_role("feeder") and feeding.growth_active("feeder")==1,"The fourth organelle also offers a feeding choice")
	feeding.begin_encounter()
	meal(feeding,["food","food","food","food","food"])
	select(feeding,wide_path)
	var graded: Dictionary = feeding.release()
	expect(graded.valid and graded.food==6 and graded.capture_grade=="Grand sweep" and graded.capture_bonus==150 and feeding.score>=graded.points,"A clean wide meal gains feeder food, a named grade and bonus score")
	feeding.mother_damage.record(703,feeding.board.center+feeding.mother_damage.core_offset(1),feeding.board.center)
	feeding.integrity -= 1
	meal(feeding,["food","food","food","food"])
	var meal_ids: Array = feeding.enemies.map(func(body): return body.id)
	expect(feeding.harvest.outcome(meal_ids,feeding,3).food==4,"Wounding the feeder organelle suspends its benefit")
	feeding.heal(1)
	expect(feeding.harvest.outcome(meal_ids,feeding,3).food==5,"Repair restores the feeder's benefit")
	feeding.dispose()
	var young := Run.new(true,19,true,true)
	var unused_site: Vector2 = young.board.center + young.mother_damage.core_offset(1)
	young.mother_damage.record(501,unused_site,young.board.center)
	expect(young.mother_damage.active_indices().has(young.mother_damage.bites[0].core), "Damage cannot choose an organelle the young Mother has not grown")
	young.dispose()
	var elder := Run.new(true,23,true,true)
	elder.stage_index = 10
	elder.start_stage()
	var seventh_site: Vector2 = elder.board.center + elder.mother_damage.core_offset(6)
	elder.mother_damage.record(502,seventh_site,elder.board.center)
	expect(elder.max_integrity==7 and elder.integrity==7 and elder.mother_damage.bites[0].core==6, "The seventh organelle is a real late-journey health target")
	elder.dispose()
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
