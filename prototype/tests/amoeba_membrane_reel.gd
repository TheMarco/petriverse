extends SceneTree
## A close-up of the production renderer, with a blue cell at the real reach point.
const Visual = preload("res://scripts/amoeba_visual.gd")
const Body = preload("res://scripts/amoeba.gd")
class QuietScene:
	extends "res://scripts/main.gd"
	func _init() -> void: pause_on_focus_loss = false
var game: Node2D
var view: Node2D
var body: RefCounted
var prey: Sprite2D
var frame := 0
var label: Label
func _initialize() -> void: call_deferred("setup")
func setup() -> void:
	root.gui_disable_input = true
	root.size = Vector2i(1152,810)
	root.content_scale_size = Vector2i(1152,810)
	game = QuietScene.new()
	game.save_records = false
	game.preferences_enabled = false
	game.audio_enabled = false
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.hide()
	var background := ColorRect.new()
	background.color = Color(0.025,0.067,0.080)
	background.size = Vector2(1152,810)
	root.add_child(background)
	body = Body.new(7,Vector2(425,400))
	body.age = 4.0
	body.heading = Vector2.RIGHT
	body.ingest_axis = Vector2.RIGHT
	body.reach_point = body.nucleus+Vector2(105,0)
	body.victim_home = body.reach_point
	view = Visual.new()
	root.add_child(view)
	view.setup(game.microscope,body)
	view.scale = Vector2.ONE*3.5
	prey = game.microscope.organism(game.microscope.CELL,63,0.7,false)
	prey.reparent(root)
	prey.position = body.nucleus+Vector2(105,0)*3.5
	prey.scale *= 3.5
	label = Label.new()
	label.position = Vector2(64,660)
	label.add_theme_font_size_override("font_size",25)
	label.modulate = Color(0.68,0.85,0.82)
	root.add_child(label)
	if DisplayServer.get_name()!="headless": RenderingServer.render_loop_enabled = false
func _process(_delta: float) -> bool:
	if view==null: return false
	frame += 1
	var time := frame/60.0
	body.age = 4.0+time
	body.arm_extension = 1.0
	if time<1.0:
		label.text = "One living membrane"
		body.phase = "approaching"
	elif time<3.8:
		label.text = "The cell stretches and folds around its prey"
		body.phase = "reaching"
		body.reach_age = time-1.0
	else:
		label.text = "The membrane seals, then draws the prey inside"
		body.phase = "digesting"
		body.captive_node = 2
		body.digestion_age = time-3.8
		prey.hide()
	view.sync(game.microscope,body,time,1.0)
	# This fixture magnifies the entire animal; the host overlay uses world
	# coordinates, so magnify that sampling frame by the same amount.
	if view.captive.visible:
		view.captive.material.set_shader_parameter("host_center",view.to_global((Vector2.ONE*0.5-Visual.NUCLEUS_UV)*152.0))
		view.captive.material.set_shader_parameter("host_extent",Vector2.ONE*152.0*view.scale)
	game.microscope.animate_organism(prey,time,1.0,1.0)
	if DisplayServer.get_name()!="headless": call_deferred("draw_frame")
	if frame==540:
		print("AMOEBA MEMBRANE REEL: complete")
		game.queue_free()
		quit()
	return false
func draw_frame() -> void:
	RenderingServer.force_draw(false,1.0/60.0)
