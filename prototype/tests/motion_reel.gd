extends SceneTree
## Twenty seconds of the production renderer: birth, feeding, and core injury.
## Camera close-ups belong only to this review reel, never normal gameplay.
const Main = preload("res://scripts/main.gd")
const Drifter = preload("res://scripts/drifter.gd")
var game: Node2D
var frame := 0
var captured := false
var wounded := false

func _initialize() -> void:
	call_deferred("setup")

func setup() -> void:
	root.gui_disable_input = true
	root.size = Vector2i(1152,810)
	root.content_scale_size = Vector2i(1280,900)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	game = Main.new()
	game.audio_enabled = false
	game.save_records = false
	game.preferences_enabled = false
	game.pause_on_focus_loss = false
	game.journey_path = "/tmp/microverse-motion-reel-unused.cfg"
	game.journey_profile.path = "/tmp/microverse-motion-reel-profile.cfg"
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.set_process_unhandled_input(false)
	game.run.fixed_seed = 73
	game.run.restart()
	game.run.stage_index = 1
	game.run.start_stage()
	game.run.begin_encounter()
	for id in ["elastic","enzyme","lure"]:
		game.run.add_mutation(id)
	game.run.enemies.clear()
	var b = game.run.board
	var center: Vector2 = (b.anchors[0]+b.anchors[8]+b.anchors[9]+b.anchors[1])/4.0
	for i in 3:
		var body = game.run.Harvest.Organism.new(900+i,"food",center+Vector2((i-1)*17,0),Vector2.ZERO,float(i))
		body.form = "fern_desmid" if i==1 else "spiral_alga"
		game.run.enemies.append(body)
	for i in 5:
		var at: Vector2 = b.center+Vector2.from_angle(0.3+i*1.15)*285.0
		var body = game.run.Harvest.Organism.new(910+i,"spore" if i%2==0 else "cyst",at,Vector2.ZERO,float(i))
		body.form = "snow_spore" if i%2==0 else "crown_cyst"
		game.run.enemies.append(body)
	game.last_discovery = game.run.discovery_serial
	game.hud.visible = false
	game._process(0.0)
	RenderingServer.render_loop_enabled = false

func _process(_delta: float) -> bool:
	if game == null:
		return false
	frame += 1
	var t := frame/60.0
	match frame:
		144: game.run.selection.start(game.run.board.anchors[0])
		168: game.run.selection.visit(8)
		192: game.run.selection.visit(9)
		216: game.run.selection.visit(1)
		240:
			game.run.selection.visit(0)
			game.commit_selection()
			captured = game.run.clots.size()==1 and game.run.clots[0].food==3
		600:
			game.run.enemies.append(Drifter.new(950,game.run.board.center+Vector2(-64,-35),9.8))
	game.run.step(1.0/60.0)
	game._process(1.0/60.0)
	wounded = wounded or game.run.integrity<5
	var meal_zoom := smoothstep(2.7,3.8,t)*(1.0-smoothstep(8.1,9.5,t))
	var injury_zoom := smoothstep(10.8,12.0,t)*(1.0-smoothstep(15.5,17.7,t))
	var zoom := 1.0+meal_zoom*0.85+injury_zoom*1.15
	var focus := Vector2(640,450).lerp(Vector2(662,366),meal_zoom)
	root.canvas_transform = Transform2D(0.0,Vector2.ONE*zoom,0.0,Vector2(640,450)-focus*zoom)
	call_deferred("draw_frame")
	return false

func draw_frame() -> void:
	RenderingServer.force_draw(false)
	if frame in [90,280,330,780,900] and DisplayServer.get_name()!="headless":
		root.get_texture().get_image().save_png("res://artifacts/motion-overhaul-%04d.png" % frame)
	if frame>=1200:
		print("MOTION REEL: ","capture, return, and core injury completed" if captured and wounded else "FAIL: incomplete review sequence")
		game.queue_free()
		quit(0 if captured and wounded else 1)
