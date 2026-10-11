extends SceneTree
## Deterministic core injury checks; native runs also save the real materials.
class DamageScene:
	extends "res://scripts/main.gd"
	func _init() -> void:
		pause_on_focus_loss = false
const Drifter = preload("res://scripts/drifter.gd")
const Run = preload("res://scripts/run_controller.gd")
var game: Node2D
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("exercise")

func expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", description)

func advance(seconds: float) -> void:
	for _i in roundi(seconds * 60.0):
		game.run.step(1.0 / 60.0)
		game._process(1.0 / 60.0)

func hit(id: int, angle: float) -> void:
	var origin: Vector2 = game.run.board.center + Vector2.from_angle(angle) * (game.run.board.mother_radius + 9.0)
	game.run.enemies.append(Drifter.new(id, origin, 0.0))
	game.run.resolve_contacts()
	game._process(0.0)

func reset() -> void:
	game.restart()
	game.run.encounter.next_spawn = 1000.0
	game._process(0.0)

func capture(name: String, closeup: bool = false) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if closeup:
		root.canvas_transform = Transform2D(0.0, Vector2.ONE * 4.0, 0.0, Vector2(root.size) * 0.5 - game.run.board.center * 4.0)
	await process_frame
	RenderingServer.force_draw(false)
	expect(root.get_texture().get_image().save_png("res://artifacts/" + name + ".png") == OK, "Saved " + name)
	await process_frame
	root.canvas_transform = Transform2D.IDENTITY

func exercise() -> void:
	root.gui_disable_input = true
	root.size = Vector2i(1280, 900)
	root.content_scale_size = Vector2i(1280, 900)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	RenderingServer.render_loop_enabled = false
	game = DamageScene.new()
	game.save_records = false
	game.preferences_enabled = false
	game.audio_enabled = false
	game.run.journey = false # This fixture exercises the isolated enclosure rules.
	game.run.harvest_mode = false
	game.run.full_run = false
	game.run.restart()
	root.add_child(game)
	if game.microscope.injury_motes == null:
		printerr("FAIL: Injury renderer failed to load")
		quit(1)
		return
	game.set_process(false)
	game.set_physics_process(false)
	game.set_process_unhandled_input(false)
	game.run.encounter.next_spawn = 1000.0
	await capture("mother-healthy-detail", true)
	hit(1, -0.58)
	var damage = game.run.mother_damage
	expect(game.run.integrity == 4 and game.run.enemies.is_empty() and game.run.encounter.resolved == 1, "Contact applies damage and resolves the enemy immediately")
	expect(damage.bites.size() == 1 and damage.lost.count(true) == 1, "One hit claims exactly one peripheral core")
	expect(damage.bites[0].core == 1, "The invader claims the closest intact core")
	expect(game.microscope.invaders.size() == 1, "The removed enemy persists as an invasion visual")
	advance(0.25)
	expect(game.microscope.mother.material.get_shader_parameter("injury_opening")[1]>0.0 and damage.core_progress(1)==0.0,"The membrane opens before the health core starts dissolving")
	await capture("mother-entry-detail", true)
	advance(0.50)
	expect(damage.core_progress(1) > 0.0 and damage.core_progress(1) < 1.0, "The golden core contracts during the bite")
	var invader: Node2D = game.microscope.invaders[1]
	expect(invader.get_meta("lobes")[0].material.get_shader_parameter("invading_depth")>0.8,"The hunter visibly passes beneath the host tissue")
	var pose := invader.transform
	var mother_pose: Transform2D = game.microscope.mother.transform
	var age: float = damage.bites[0].age
	var values: PackedFloat32Array = game.microscope.mother.material.get_shader_parameter("core_damage")
	game.pause()
	advance(1.0)
	expect(game.hud.center_button.visible, "Pause controls remain immediately available during a bite")
	expect(damage.bites[0].age == age and invader.transform == pose, "Pause freezes the invading enemy and bite age")
	expect(game.microscope.mother.transform == mother_pose and game.microscope.mother.material.get_shader_parameter("core_damage") == values, "Pause freezes the wound and tissue recoil")
	game.pause()
	game._process(0.0)
	await capture("mother-bite")
	await capture("mother-bite-detail", true)
	advance(0.65)
	await capture("mother-core-dissolving-detail", true)
	advance(0.90)
	expect(game.microscope.invaders.is_empty() and not damage.active(), "The invading tissue clears after digestion")
	expect(damage.core_progress(1) == 1.0 and damage.core_progress(0) == 0.0, "The wound remains while other cores stay intact")
	await capture("mother-wound-detail", true)
	hit(2, -0.58)
	expect(damage.bites[0].core != 1 and damage.lost.count(true) == 2 and game.run.integrity == 3, "A repeated hit from the same side eats a different surviving core")
	advance(2.3)
	expect(damage.progress_values().count(1.0) == 2, "Both spent cores remain visible after their animations")
	reset()
	expect(game.run.mother_damage.lost.count(true) == 0 and game.microscope.invaders.is_empty(), "Restart restores all five cores and clears invaders")
	expect(game.microscope.mother.material.get_shader_parameter("core_damage") == PackedFloat32Array([0, 0, 0, 0, 0, 0, 0]), "Restart clears all wound shader masks")
	# Reduced motion keeps the visual information without locomotion or sparks.
	game.reduced_motion = true
	hit(3, PI)
	invader = game.microscope.invaders[1]
	pose = invader.transform
	mother_pose = game.microscope.mother.transform
	advance(0.8)
	expect(invader.transform == pose and game.microscope.mother.transform == mother_pose, "Reduced motion disables burrowing, swimming, and recoil")
	expect(not game.microscope.injury_motes.visible, "Reduced motion hides moving gold fragments")
	expect(game.run.mother_damage.core_progress(4) > 0.0, "Reduced motion still communicates organelle depletion")
	advance(1.5)
	expect(game.microscope.invaders.is_empty() and game.run.mother_damage.core_progress(4) == 1.0, "Reduced motion finishes with the same persistent wound")
	game.reduced_motion = false
	# Restart while a bite is in flight must clear its material and particles.
	reset()
	hit(4, 1.7)
	advance(0.6)
	reset()
	expect(not game.run.mother_damage.active() and game.microscope.invaders.is_empty(), "Restart during a bite removes its visual immediately")
	expect(game.microscope.mother.material.get_shader_parameter("injury_pulse") == PackedFloat32Array([0, 0, 0, 0, 0, 0, 0]), "Restart clears injury lighting")
	expect(game.microscope.mother.material.get_shader_parameter("injury_opening") == PackedFloat32Array([0,0,0,0,0,0,0]) and game.microscope.mother.material.get_shader_parameter("injury_seal") == PackedFloat32Array([0,0,0,0,0,0,0]),"Restart clears membrane opening and closure")
	hit(5, -2.0)
	expect(game.microscope.invaders.size() == 1 and game.run.mother_damage.bites[0].core == 0, "The first hit after restart has fresh anatomy and visuals")
	reset()
	# Sorted contact IDs make simultaneous allocation independent of array order.
	for id in [5, 1, 4, 3, 2, 6]:
		game.run.enemies.append(Drifter.new(id, game.run.board.center + Vector2.from_angle(id * 1.1) * 48.0, 0.0))
	game.run.resolve_contacts()
	game._process(0.0)
	damage = game.run.mother_damage
	expect(game.run.integrity == 0 and game.run.state == "loss" and game.run.encounter.resolved == 6, "All simultaneous contacts resolve, even beyond remaining health")
	expect(damage.bites.size() == 5 and damage.lost.count(true) == 5 and game.microscope.invaders.size() == 5, "No sixth core or duplicate wound is invented")
	var cores := {}
	var ids: Array = []
	for bite in damage.bites:
		cores[bite.core] = true
		ids.append(bite.enemy_id)
	expect(cores.size() == 5 and ids == [1, 2, 3, 4, 5], "Simultaneous hits consume five distinct cores in stable ID order")
	var other = Run.new(false)
	for id in [6, 2, 3, 4, 1, 5]:
		other.enemies.append(Drifter.new(id, other.board.center + Vector2.from_angle(id * 1.1) * 48.0, 0.0))
	other.resolve_contacts()
	expect(other.mother_damage.bites == damage.bites, "Contact ordering does not change which cores are eaten")
	other.dispose()
	var frozen_board: PackedVector2Array = game.run.board.anchors.duplicate()
	var elapsed: float = game.run.elapsed
	advance(0.8)
	expect(damage.core_progress(0) > 0.0 and game.run.elapsed == elapsed and game.run.board.anchors == frozen_board, "The fatal bite continues before results while combat and node drift stop")
	expect(not game.hud.overlay_visible() and not game.hud.center_button.visible and game.hud.restart_button.visible, "The fatal bite remains visible before results, with Restart still available")
	await capture("mother-fatal-bite-detail", true)
	advance(1.5)
	expect(not damage.active() and game.microscope.invaders.is_empty(), "Fatal invasion visuals finish before the results overlay")
	expect(damage.progress_values() == PackedFloat32Array([1, 1, 1, 1, 1, 0, 0]), "All five active cores are visibly spent at zero integrity")
	expect(game.microscope.mother.material.get_shader_parameter("fatal_damage") == 1.0, "Loss dims the central nucleus after the last cores are consumed")
	expect(game.hud.overlay_visible() and game.hud.center_button.visible, "Results and replay appear as soon as the fatal bite finishes")
	# Inspect the actual depleted tissue beneath the result panel in this fixture.
	game.hud.visible = false
	await capture("mother-fatal-detail", true)
	game.hud.visible = true
	reset()
	expect(game.run.integrity == 5 and game.microscope.mother.material.get_shader_parameter("fatal_damage") == 0.0, "Restart after loss restores the central nucleus and full integrity")
	# A surviving final contact also finishes visibly before its success panel.
	game.run.encounter.spawned = game.run.encounter.budget
	game.run.encounter.resolved = game.run.encounter.budget - 1
	hit(20, 0.0)
	advance(0.1)
	expect(game.run.state == "success" and not game.hud.overlay_visible(), "A final surviving hit remains visible before success results")
	advance(2.2)
	expect(game.hud.overlay_visible() and game.run.integrity == 4 and game.run.mother_damage.lost.count(true) == 1, "Success appears with the correct persistent damage")
	print("MOTHER DAMAGE: %d checks; %d failures" % [checks, failures])
	game.queue_free()
	quit(0 if failures == 0 else 1)
