extends SceneTree
## Isolated native pixels prove tissue flow independently from body movement.
const Visual = preload("res://scripts/amoeba_visual.gd")
const Body = preload("res://scripts/amoeba.gd")
class QuietScene:
	extends "res://scripts/main.gd"
	func _init() -> void: pause_on_focus_loss = false
var game: Node2D
var view: Node2D
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("exercise")
func expect(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ",label)
func photo() -> Image:
	await process_frame
	await process_frame
	RenderingServer.force_draw(false)
	return root.get_texture().get_image()
func difference(a: Image,b: Image,region: Rect2i) -> float:
	var total := 0.0
	var count := 0
	for y in range(region.position.y,region.end.y,3):
		for x in range(region.position.x,region.end.x,3):
			var c := a.get_pixel(x,y)-b.get_pixel(x,y)
			total += absf(c.r)+absf(c.g)+absf(c.b)
			count += 1
	return total/maxi(count,1)

func connected_tissue(image: Image, nucleus: Vector2i) -> bool:
	# A thresholded render must be a single substantial connected component.
	# Tiny isolated antialiasing pixels are ignored, but an added grab/chamber
	# cannot pass merely because the main body itself continues to animate.
	const STRIDE := 3
	var width := image.get_width()/STRIDE
	var height := image.get_height()/STRIDE
	var mask := PackedByteArray()
	mask.resize(width*height)
	var count := 0
	var background := image.get_pixel(10,10)
	for y in height:
		for x in width:
			var c := image.get_pixel(x*STRIDE,y*STRIDE)-background
			if absf(c.r)+absf(c.g)+absf(c.b)>0.075:
				mask[y*width+x] = 1
				count += 1
	var start := int(nucleus.y/STRIDE)*width+int(nucleus.x/STRIDE)
	if mask[start]==0: return false
	var pending: Array[int] = [start]
	mask[start] = 0
	var found := 0
	while not pending.is_empty():
		var index: int = pending.pop_back()
		found += 1
		var x := index%width
		var y := index/width
		for at in [Vector2i(x-1,y),Vector2i(x+1,y),Vector2i(x,y-1),Vector2i(x,y+1)]:
			if at.x<0 or at.x>=width or at.y<0 or at.y>=height: continue
			var next: int = at.y*width+at.x
			if mask[next]==1:
				mask[next] = 0
				pending.append(next)
	return found>100 and float(found)/maxi(count,1)>0.995
func exercise() -> void:
	root.gui_disable_input = true
	root.size = Vector2i(1100,700)
	root.content_scale_size = Vector2i(1100,700)
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
	background.size = Vector2(1100,700)
	root.add_child(background)
	var body := Body.new(7,Vector2(550,330))
	body.age = 4.0
	body.heading = Vector2.RIGHT
	view = Visual.new()
	root.add_child(view)
	view.setup(game.microscope,body)
	view.scale = Vector2.ONE*4.5
	view.sync(game.microscope,body,0.0,1.0)
	var region := Rect2i(100,100,900,500)
	var before := await photo()
	before.save_png("res://artifacts/amoeba-realistic-detail.png")
	# Keep the silhouette clock fixed while advancing only internal tissue flow.
	view.sync(game.microscope,body,2.0,1.0)
	var after := await photo()
	expect(difference(before,after,region)>0.001,"Granular cytoplasm flows while the body and silhouette stay fixed")
	before = after
	view.sync(game.microscope,body,2.0,1.0)
	expect(difference(before,await photo(),region)<0.000001,"A frozen presentation clock freezes every rendered pixel")
	body.age += 3.2
	view.sync(game.microscope,body,2.0,1.0)
	after = await photo()
	expect(difference(before,after,region)>0.004,"The leading lobe grows and the trailing body changes shape")
	after.save_png("res://artifacts/amoeba-realistic-extended.png")
	view.sync(game.microscope,body,2.0,0.0)
	before = await photo()
	body.age += 7.0
	view.sync(game.microscope,body,9.0,0.0)
	expect(difference(before,await photo(),region)<0.000001,"Reduced motion fixes both outline and internal streaming")
	# Inspect long reaches at the start, wrap, seal and inward-fold boundaries.
	body.nucleus = Vector2(400,330)
	body.reach_point = body.nucleus+Vector2(110,0)
	body.victim_home = body.reach_point
	body.ingest_axis = Vector2.RIGHT
	view.scale = Vector2.ONE*3.5
	for moment in [0.02,0.5,1.6,2.79,2.81,2.95,3.3,3.9,4.8]:
		body.phase = "reaching" if moment<2.8 else "digesting"
		body.reach_age = minf(2.8,moment)
		body.digestion_age = maxf(0.0,moment-2.8)
		body.captive_node = -1 if moment<2.8 else 2
		view.sync(game.microscope,body,9.0+moment,1.0)
		view.captive.hide()
		# Exclude intracellular decorative rings from the silhouette proof.
		view.body_state = null
		view.queue_redraw()
		expect(connected_tissue(await photo(),Vector2i(body.nucleus)),"The full membrane stays connected at %.2fs" % moment)
	# Root rotation must preserve the prey's world position and logical gold target.
	body.phase = "digesting"
	body.captive_node = 2
	body.digestion_age = 2.0
	body.ingest_axis = Vector2.DOWN
	view.scale = Vector2.ONE
	view.oriented = false
	view.sync(game.microscope,body,9.0,1.0)
	expect(view.captive.global_position.distance_to(body.captive_position())<0.01,"Turning the body never moves prey away from its actual world position")
	expect(view.position==body.nucleus,"The visible nucleus stays registered to the capture target")
	print("AMOEBA PIXELS: %d checks; %d failures" % [checks,failures])
	game.queue_free()
	quit(0 if failures==0 else 1)
