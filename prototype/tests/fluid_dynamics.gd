extends SceneTree
const Fluid = preload("res://scripts/fluid_field.gd")
const Run = preload("res://scripts/run_controller.gd")
const Save = preload("res://scripts/journey_save.gd")
var checks := 0
var failures := 0

func expect(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ",label)

func field(seed_value: int = 73) -> RefCounted:
	var result = Fluid.new()
	result.reset(Vector2(640,450),392.0,seed_value)
	return result

func _initialize() -> void:
	var a = field()
	var b = field()
	var c = field(74)
	expect(a.velocity==b.velocity and a.velocity!=c.velocity,"Currents are seeded independently of gameplay RNG")
	var before: Vector2 = a.sample(Vector2(810,270))
	expect(before.distance_to(a.sample(Vector2(814,270)))<1.5,"Neighboring organisms feel a coherent local current")
	a.stroke(Vector2(730,235),Vector2(880,235))
	expect(a.sample(Vector2(810,235)).x>b.sample(Vector2(810,235)).x+4.0,"Drawing transfers directional momentum to the water")
	var start := Time.get_ticks_usec()
	for _frame in 180:
		a.step(1.0/60.0)
		b.step(1.0/60.0)
	var simulation_ms := (Time.get_ticks_usec()-start)/1000.0
	var difference := 0.0
	for i in Fluid.COUNT:
		difference += a.velocity[i].distance_to(b.velocity[i])
	expect(difference>5.0,"A stroke leaves a persistent wake three seconds after input stops")
	expect(a.displacement(Vector2(810,235)).distance_to(b.displacement(Vector2(810,235)))>2.0,"Wake history transports visible suspended matter")
	var slow = field()
	var fast = field()
	for _frame in 90: slow.step(1.0/30.0)
	for _frame in 432: fast.step(1.0/144.0)
	expect(slow.velocity==fast.velocity and slow.transport==fast.transport,"Fluid stepping is deterministic at 30 and 144 Hz")
	var bounded := true
	var dry := true
	for i in Fluid.COUNT:
		bounded = bounded and a.velocity[i].is_finite() and a.velocity[i].length()<=Fluid.MAX_SPEED+0.001 and a.transport[i].length()<Fluid.OFFSET_RANGE
		if not a.wet[i]: dry = dry and a.velocity[i]==Vector2.ZERO
	expect(bounded and dry,"Water stays finite, speed limited and outside glass/Mother obstacles")
	var restored = field(125)
	restored.restore(a.snapshot())
	restored.step(0.2)
	a.step(0.2)
	expect(restored.snapshot()==a.snapshot(),"Saved momentum and material transport resume exactly")
	var run = Run.new(true,73,true,true)
	run.stage_index = 1
	run.start_stage()
	run.begin_encounter()
	run.enemies.clear()
	run.harvest.next_bloom = 9999.0
	run.harvest.ecology.next_wave = 9999.0
	run.harvest.ecology.pending.clear()
	var nodes := [0,8,9]
	var at: Vector2 = (run.board.anchors[0]+run.board.anchors[8]+run.board.anchors[9])/3.0
	var food = run.Harvest.Organism.new(300,"food",at,Vector2.ZERO,0.0)
	run.enemies.append(food)
	run.selection.start(run.board.anchors[0])
	for id in [8,9,0]: run.selection.visit(id)
	var polygon: PackedVector2Array = run.Geometry.polygon_for(nodes,run.board.anchors)
	run.fluid.stroke(at-Vector2(60,0),at+Vector2(60,0))
	for _frame in 60: run.step(1.0/60.0)
	expect(run.Geometry.polygon_for(nodes,run.board.anchors)==polygon,"Strong local flow cannot move selected cells")
	expect(food.origin.distance_to(at)>0.01 and food.origin.distance_to(at)<=1.21,"Food shares the flow at a bounded, drawable speed")
	var plain_food = run.Drifter.new(999,Vector2(810,270),0.0,"food")
	var old_position: Vector2 = plain_food.nucleus
	run.advect_body(plain_food,0.1)
	expect(plain_food.nucleus.distance_to(old_position)>0.0 and plain_food.nucleus.distance_to(old_position)<=0.121,"Legacy plain organisms can advect without a swimming-origin property")
	var result: Dictionary = run.release()
	expect(result.valid and result.food==1 and run.integrity==5,"Human-paced loop still feeds Mother in flowing water")
	run.step(0.4)
	run.step(0.1)
	expect(not run.fluid.sources.is_empty() and run.fluid.sources[0].z<0.0,"Absorption draws the surrounding water inward")
	var snapshot: Dictionary = run.fluid.snapshot()
	run.toggle_pause()
	run.step(5.0)
	expect(run.fluid.snapshot()==snapshot,"Pause freezes every fluid state including residual momentum")
	var clone = Run.new(true,95,true,true)
	expect(Save.restore(clone,Save.capture(run)) and clone.fluid.snapshot()==snapshot,"Journey save and resume preserves the exact water state")
	var legacy: Dictionary = Save.capture(run)
	legacy.erase("water")
	Save.restore(clone,legacy)
	var legacy_flow: Dictionary = clone.fluid.snapshot()
	Save.restore(clone,legacy)
	expect(clone.fluid.snapshot()==legacy_flow and clone.board.anchors==run.board.anchors,"Legacy saves get reproducible calm water without moving existing cells")
	run.toggle_pause()
	for _frame in 180: run.step(1.0/60.0)
	expect(run.cells.all(func(cell): return cell.is_ready()),"Water does not delay recovery")
	var maximum := 0.0
	for v in run.board.velocities: maximum = maxf(maximum,v.length())
	expect(maximum<=run.board.MAX_SPEED+0.001,"Fluid steering respects the existing cell speed cap")
	run.restart()
	expect(run.fluid.clock==0.0 and run.fluid.transport.count(Vector2.ZERO)==Fluid.COUNT,"New journeys clear residual wake history")
	# A real swimming body must stir fine particles, even without cursor input.
	var swimmers = Run.new(true,73,true,true)
	swimmers.stage_index = 1
	swimmers.start_stage()
	swimmers.begin_encounter()
	swimmers.enemies.clear()
	var swimmer = swimmers.Drifter.new(9999,Vector2(860,290),6.0)
	swimmer.age = 4.0
	swimmers.enemies.append(swimmer)
	swimmers.step_water(1.0/60.0)
	swimmer.nucleus += Vector2(0.1,0.0)
	swimmers.step_water(1.0/60.0)
	expect(swimmers.fluid.sources.size()==2 and swimmers.fluid.sources[0].w*swimmers.fluid.sources[1].w<0.0,"Swimming creates a pair of counter-rotating wakes")
	swimmers.step_water(1.0/60.0)
	expect(swimmers.fluid.sources.is_empty(),"Stationary creatures do not manufacture propulsion wakes")
	var tracers = preload("res://scripts/water_tracers.gd").new()
	var look := {"key":"test","dust_seed":73}
	tracers.sync(0.0,1.0,swimmers.fluid,look,2)
	var initial: Array = tracers.motes.duplicate(true)
	for frame in 120: tracers.sync(float(frame+1)/60.0,1.0,swimmers.fluid,look,2)
	var travel := 0.0
	for i in tracers.motes.size(): travel += tracers.motes[i].at.distance_to(initial[i].at)
	expect(tracers.motes.size()==960 and travel/tracers.motes.size()>4.0,"A dense field of tiny particles visibly travels with the actual fluid")
	expect(tracers.motes.all(func(m): return m.size<=0.70),"Every sparkling grain remains smaller than 1.4 dish pixels across")
	var frozen: Array = tracers.motes.duplicate(true)
	tracers.sync(2.0,1.0,swimmers.fluid,look,2)
	expect(tracers.motes==frozen,"Unchanged visual time freezes tracer motion")
	tracers.sync(9.0,0.0,swimmers.fluid,look,0)
	tracers.sync(9.0,1.0,swimmers.fluid,look,0)
	expect(tracers.motes==frozen and tracers.visible_count==240,"Reduced motion accumulates no catch-up and low quality reduces density")
	tracers.free()
	swimmers.dispose()
	clone.dispose()
	run.dispose()
	print("FLUID PERFORMANCE: two fields, 3 simulated seconds: %.1fms (%.2fms per 20Hz update)" % [simulation_ms,simulation_ms/120.0])
	print("FLUID DYNAMICS: %d checks; %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
