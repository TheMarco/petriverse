extends SceneTree
class MovieScene:
	extends "res://scripts/main.gd"
	func _init() -> void:
		pause_on_focus_loss = false
var game: Node2D
var frame := 0
var body: RefCounted
var victim := -1
var checks := 0
var failures := 0

func expect(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ",label)

func _initialize() -> void:
	call_deferred("setup")

func setup() -> void:
	root.gui_disable_input = true
	root.size = Vector2i(1280,900)
	root.content_scale_size = Vector2i(1280,900)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	game = MovieScene.new()
	game.save_records = false
	game.preferences_enabled = false
	game.audio_enabled = false
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.set_process_unhandled_input(false)
	game.run.stage_index = 5
	game.run.start_stage()
	game.run.begin_encounter()
	game.run.enemies.clear()
	game.run.harvest.next_bloom = 9999.0
	game.run.harvest.ecology.next_wave = 9999.0
	game.run.harvest.ecology.pending.clear()
	game.run.harvest.spec.food = 999
	body = game.run.harvest.ecology.add(game.run,"amoeba",0,game.run.harvest.ecology.pocket(game.run,0))
	body.age = 4.0
	game.run.amoebas.choose_target(game.run,body)
	body.nucleus = body.destination-Vector2(28,0)
	body.search_after = 5.0
	victim = body.target_node
	if DisplayServer.get_name()!="headless": RenderingServer.render_loop_enabled = false

func _process(_delta: float) -> bool:
	if game==null: return false
	if DisplayServer.get_name()!="headless": call_deferred("draw_frame")
	frame += 1
	if frame<=240:
		body.step(1.0/60.0,game.run.board.center)
	else:
		game.run.step(1.0/60.0)
	game._process(1.0/60.0)
	if frame==240:
		body.nucleus = body.destination
		body.search_after = body.age+1.0
	match frame-240:
		180:
			var view: Node2D = game.microscope.enemies[body.id]
			expect(view.skin.material.get_shader_parameter("extension")>0.0,"Reaching pseudopods have a continuous textured membrane")
			expect(game.microscope.cells[victim].visible,"Prey stays visible at its original location until engulfed")
		360:
			var view: Node2D = game.microscope.enemies[body.id]
			expect(view.captive.visible and not game.microscope.cells[victim].visible,"Only the captive cell is shown after ingestion")
			expect(view.position==body.nucleus,"Rendered gold nucleus matches the capture target")
			expect(view.captive.material.get_shader_parameter("invading_depth")==1.0,"Host cytoplasm refracts over the swallowed cell")
			var pose: Transform2D = view.captive.transform
			var motes: Array = game.microscope.water_tracers.motes.duplicate(true)
			var shader_clock: float = view.skin.material.get_shader_parameter("clock")
			game.pause()
			game.run.step(2.0)
			game._process(2.0)
			expect(view.captive.transform==pose and view.skin.material.get_shader_parameter("clock")==shader_clock,"Pause freezes amoeba and its captive")
			expect(game.microscope.water_tracers.motes==motes,"Pause freezes every fine fluid particle")
			game.pause()
			game.toggle_motion()
			game._process(0.0)
			expect(view.skin.material.get_shader_parameter("extension")==0.0 and not game.microscope.water_tracers.visible and view.captive.visible,"Reduced motion retains the captive and removes moving water/pseudopods")
			game.toggle_motion()
		420:
			game.run.selection.start(game.run.board.anchors[body.site_nodes[0]])
		435: game.run.selection.visit(body.site_nodes[1])
		450: game.run.selection.visit(body.site_nodes[2])
		465:
			game.run.selection.visit(body.site_nodes[0])
			game.commit_selection()
		480:
			expect(game.run.cells[victim].captor<0 and game.microscope.cells[victim].visible,"Capturing the amoeba reveals the returning blue cell")
		570:
			expect(game.run.is_ready(victim),"Returned cell is usable again")
		720:
			print("AMOEBA MOTION: %d checks; %d failures" % [checks,failures])
			game.queue_free()
			quit(0 if failures==0 else 1)
	return false

func draw_frame() -> void:
	RenderingServer.force_draw(false,1.0/60.0)
