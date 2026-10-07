extends SceneTree
## A short rendering sample, not a substitute for sustained hardware playtesting.

# Do not let desktop focus changes cancel the maximum-load preview fixture.
class SampleScene:
	extends "res://scripts/main.gd"
	var visual_update_ms := 0.0
	func _init() -> void:
		pause_on_focus_loss = false
	func _process(delta: float) -> void:
		var began := Time.get_ticks_usec()
		super._process(delta)
		visual_update_ms = (Time.get_ticks_usec()-began)/1000.0
		if "--no-life-control" in OS.get_cmdline_user_args():
			for sprite in microscope.cells+[microscope.mother]:
				sprite.get_node("Life").hide()
			for body in microscope.enemies.values():
				for sprite in body.get_meta("lobes"):
					if sprite.has_node("Life"): sprite.get_node("Life").hide()
const Drifter = preload("res://scripts/drifter.gd")
var game: Node2D
var frames := 0
var last_tick := 0
var samples: Array[float] = []
var update_total := 0.0
var process_total := 0.0
var draw_total := 0.0

func _initialize() -> void:
	call_deferred("setup")

func setup() -> void:
	root.gui_disable_input = true
	root.size = Vector2i(1152, 810) if OS.get_cmdline_user_args().has("--play-size") else Vector2i(1920, 1080)
	root.content_scale_size = Vector2i(1280, 900)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	game = SampleScene.new()
	game.save_records = false
	game.preferences_enabled = false
	game.audio_enabled = false
	game.visual_quality = 0 if OS.get_cmdline_user_args().has("--light") else 2
	game.run.journey = false # This fixture exercises the isolated enclosure rules.
	game.run.harvest_mode = false
	game.run.full_run = false
	game.run.restart()
	if "--evolved" in OS.get_cmdline_user_args():
		for item in game.run.Mutations.CATALOG+game.run.Mutations.JOURNEY_CATALOG:
			if item.id!="elastic":
				game.run.add_mutation(item.id)
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process_unhandled_input(false)
	var board = game.run.board
	for i in 12:
		var kind := "twinspore" if i < 6 else "shellback" if i < 9 else "drifter"
		var enemy: RefCounted = Drifter.new(i, board.center + Vector2.from_angle(i * TAU / 12.0) * (175.0 if i % 2 == 0 else 270.0), 7.5, kind)
		if "--fluid" in OS.get_cmdline_user_args() and i>=10:
			enemy = game.run.Amoebas.Body.new(i,enemy.nucleus)
			enemy.phase = "reaching"
			enemy.reach_point = enemy.nucleus+Vector2(72.0,25.0)
			enemy.arm_extension = 1.0
			enemy.reach_age = 2.4
		enemy.age = 4.0 # All eighteen bodies must be fully emerged and visible.
		game.run.enemies.append(enemy)
	for i in range(8, 16):
		game.run.cells[i].spend(6)
	game.run.selection.start(board.anchors[0])
	for i in range(1, 8):
		game.run.selection.visit(i)
	game.run.selection.visit(0)
	last_tick = Time.get_ticks_usec()

func _process(delta: float) -> bool:
	if game == null:
		return false
	# Keep the maximum-load fixture active even if another window gains focus.
	game.run.state = "active"
	for enemy in game.run.enemies:
		enemy.age += delta
		if "--fluid" in OS.get_cmdline_user_args():
			if enemy.kind!="amoeba":
				enemy.step(delta,game.run.board.center)
			else:
				enemy.reach_age = 1.8+sin(enemy.age*0.8)*0.8
	if "--fluid" in OS.get_cmdline_user_args():
		game.run.step_water(delta)
	if not OS.get_cmdline_user_args().has("--static-nodes"):
		game.run.board.step_motion(delta, game.run.selection.path)
	var now := Time.get_ticks_usec()
	var milliseconds := (now - last_tick) / 1000.0
	last_tick = now
	frames += 1
	if frames > 120:
		samples.append(milliseconds)
		update_total += game.visual_update_ms
		process_total += Performance.get_monitor(Performance.TIME_PROCESS)*1000.0
		draw_total += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	if frames==60:
		root.get_texture().get_image().save_png("res://artifacts/frame-sample-scene.png")
	if samples.size() == 600:
		samples.sort()
		var total := 0.0
		var slow := 0
		for value in samples:
			total += value
			if value > 20:
				slow += 1
		var report := {"engine": Engine.get_version_info().string, "display": DisplayServer.get_name(), "window_pixels": str(root.size), "static_node_control": OS.get_cmdline_user_args().has("--static-nodes"), "renderer": "gl_compatibility", "quality": ["light", "balanced", "full"][game.visual_quality], "device": RenderingServer.get_video_adapter_name(), "scenario": "Moving gameplay nodes, living tissue, animated cilia/granules, small photographic pond specimens and instanced suspension particles at the recorded quality level, and advected microscopy plate: 24 cells, 18 enemy bodies (6 Twinspore pairs, 3 Shellbacks, 3 Drifters), 8 recovering cells, closed 8-cell preview; 120 warmup frames; cap 60 fps; VSync disabled", "samples": samples.size(), "mean_ms": total / samples.size(), "median_ms": samples[300], "p95_ms": samples[570], "p99_ms": samples[594], "max_ms": samples[-1], "frames_above_20ms": slow}
		report.mutations = game.run.mutations.duplicate()
		report.background_specimens = game.microscope.pond.specimens.filter(func(body): return body.visible).size()
		report.mean_visual_update_ms = update_total/samples.size()
		report.mean_process_ms = process_total/samples.size()
		report.mean_draw_calls = draw_total/samples.size()
		report.emerged_enemy_bodies = game.run.enemies.reduce(func(count,body): return count+body.body_count() if body.age>=4.0 else count,0)
		report.no_life_control = "--no-life-control" in OS.get_cmdline_user_args()
		print("FRAME SAMPLE: ", JSON.stringify(report))
		var output := "frame-sample-static-control.json" if OS.get_cmdline_user_args().has("--static-nodes") else ("frame-sample-play-size.json" if OS.get_cmdline_user_args().has("--play-size") else "frame-sample-campaign-light.json" if game.visual_quality == 0 else "frame-sample-campaign.json")
		if "--evolved" in OS.get_cmdline_user_args():
			output = "frame-sample-evolved-%s.json" % report.quality
		if "--fluid" in OS.get_cmdline_user_args():
			output = "frame-sample-fluid-amoebas.json"
			report.scenario += "; shared fluid actively simulated, 960 fine advected particles and two reaching amoebas replacing two Drifters"
		if report.no_life_control:
			output = "frame-sample-no-life-control.json"
		var file := FileAccess.open("res://artifacts/" + output, FileAccess.WRITE)
		file.store_string(JSON.stringify(report, "  ") + "\n")
		game.queue_free()
		quit()
	return false
