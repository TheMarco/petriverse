extends SceneTree
class QuietScene:
	extends "res://scripts/main.gd"
	func _init() -> void: pause_on_focus_loss = false
var game: Node2D
var body: RefCounted
var group: RefCounted
var frame := 0
var checks := 0
var failures := 0

func expect(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ",label)

func _initialize() -> void:
	root.unfocusable = true
	call_deferred("setup")

func setup() -> void:
	root.gui_disable_input = true
	root.size = Vector2i(1280,900)
	root.content_scale_size = root.size
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	game = QuietScene.new()
	game.save_records = false
	game.preferences_enabled = false
	game.audio_enabled = false
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.set_process_unhandled_input(false)
	game.run.route_plan = game.run.JourneyRoute.make(73)
	game.run.route_position = 4
	game.run.stage_index = 2
	game.run.start_stage()
	game.run.begin_encounter()
	game.run.enemies.clear()
	game.run.phages.reset()
	game.run.harvest.next_bloom = 9999
	game.run.harvest.ecology.next_wave = 9999
	game.run.harvest.ecology.pending.clear()
	game.run.harvest.spec.food = 20
	body = game.run.harvest.ecology.add(game.run,"bacterium",0,Vector2(828,495))
	body.age = 4
	body.spawning = 0
	body.speed = 0
	body.heading = Vector2(1,0.18).normalized()
	body.stored_food = 2
	group = game.run.phages.add(game.run,Vector2(820,425))
	group.age = 4
	game.run.phages.learned = false
	game.last_discovery = game.run.discovery_serial
	game.toast_time = 0
	if "--closeup" in OS.get_cmdline_user_args():
		game.hud.hide()
		game.scale = Vector2.ONE*4.0
		game.position = Vector2(610,495)-body.nucleus*4.0
	RenderingServer.render_loop_enabled = false

func _process(_delta: float) -> bool:
	if game==null: return false
	frame += 1
	game.run.step(1.0/60.0)
	game._process(1.0/60.0)
	match frame:
		90:
			expect(game.microscope.phage_visual.sprites.size()==3,"A free cluster renders three textured phages")
			call_deferred("photo","phages-free")
		120:
			expect(game.run.nudge.begin(game.run,group.nucleus),"The visible cluster can be grabbed at its center")
			game.commit_nudge(group.nucleus+(body.nucleus-group.nucleus).normalized()*60)
		300:
			expect(group.host_id==body.id,"A nudge in the rendered dish attaches phages to the bacterium")
			var virion: Sprite2D = game.microscope.phage_visual.sprites["%d:0" % group.id]
			expect(virion.material.get_shader_parameter("contraction")>0.9,"Attachment contracts each virion's tail")
			var clock: float = virion.material.get_shader_parameter("clock")
			var position: Vector2 = virion.position
			var age: float = body.infection_age
			game.pause()
			game.run.step(2)
			game._process(2)
			expect(body.infection_age==age and virion.position==position and virion.material.get_shader_parameter("clock")==clock,"Pause freezes infection, docking and microscopic animation")
			game.pause()
			game.toggle_motion()
			game._process(0)
			expect(virion.material.get_shader_parameter("motion")==0.0 and virion.visible,"Reduced motion retains recognizable phages with still fibres")
			game.toggle_motion()
			game._process(0)
			call_deferred("photo","phages-attached")
		570:
			var sprite: Sprite2D = game.microscope.enemies[body.id].get_meta("lobes")[0]
			expect(sprite.material.get_shader_parameter("infection")>0.6,"Host visibly swells and changes during infection")
			call_deferred("photo","phages-infected")
		750:
			expect(not game.run.enemies.has(body) and not game.microscope.enemies.has(body.id),"The host disappears only when the simulated infection completes")
			expect(game.microscope.phage_visual.sprites.keys().any(func(k): return k.begins_with("burst:")),"Rupture releases small drifting progeny")
			expect(game.run.enemies.filter(func(e): return e.story=="phage_salvage").size()==2,"Both released food organisms are visible and collectable")
			call_deferred("photo","phages-rupture")
		930:
			expect(game.microscope.phage_visual.sprites.is_empty(),"Transient fragments clear without leaving phantom phages")
			print("PHAGE VISUALS: %d checks; %d failures" % [checks,failures])
			game.queue_free()
			quit(0 if failures==0 else 1)
	call_deferred("draw_frame")
	return false

func draw_frame() -> void: RenderingServer.force_draw(false,1.0/60.0)
func photo(label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://artifacts/"+label+("-detail" if "--closeup" in OS.get_cmdline_user_args() else "")+".png")
