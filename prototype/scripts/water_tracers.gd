extends Node2D
## Fine suspended grains follow the same water as the tissue and sediment.
## Local inertia and rare glints reveal eddies without covering the playfield.
const CAPACITY := 960
var motes: Array = []
var last_time := -1.0
var recipe := ""
var visible_count := CAPACITY
var cloud: MultiMeshInstance2D

func create_cloud() -> void:
	cloud = MultiMeshInstance2D.new()
	cloud.multimesh = MultiMesh.new()
	cloud.multimesh.transform_format = MultiMesh.TRANSFORM_2D
	cloud.multimesh.use_colors = true
	cloud.multimesh.use_custom_data = true
	var quad := QuadMesh.new()
	quad.size = Vector2(7.0,7.0)
	cloud.multimesh.mesh = quad
	cloud.multimesh.instance_count = CAPACITY
	cloud.material = ShaderMaterial.new()
	cloud.material.shader = preload("res://shaders/water_tracers.gdshader")
	add_child(cloud)

func sync(time: float, motion: float, fluid: RefCounted, look: Dictionary, quality: int) -> void:
	if cloud==null: create_cloud()
	if recipe!=look.key or time<last_time:
		recipe = look.key
		motes.clear()
		var rng := RandomNumberGenerator.new()
		rng.seed = int(look.dust_seed)^0x47ad11
		for i in CAPACITY:
			# Area-uniform seeding avoids a bright ring around Mother.
			var at: Vector2 = fluid.center+Vector2.from_angle(rng.randf()*TAU)*sqrt(rng.randf_range(76.0*76.0,366.0*366.0))
			motes.append({"at":at,"velocity":fluid.sample(at)*2.8,"size":rng.randf_range(0.32,0.70),"depth":rng.randf_range(0.45,1.0),"phase":rng.randf()*TAU,"rate":rng.randf_range(0.45,1.1),"response":rng.randf_range(0.08,0.32),"glints":i%4==0})
		for i in motes.size():
			var mote: Dictionary = motes[i]
			cloud.multimesh.set_instance_custom_data(i,Color(mote.size,mote.depth,mote.phase/TAU,mote.rate))
		last_time = time
	var delta := clampf(time-last_time,0.0,0.1)
	last_time = time
	visible_count = [240,560,CAPACITY][clampi(quality,0,2)]
	visible = motion>0.0
	for mote in motes:
		if delta<=0.0 or motion<=0.0: continue
		var flow: Vector2 = fluid.sample(mote.at)*(2.4+mote.depth*0.8)
		mote.velocity = mote.velocity.lerp(flow,1.0-exp(-delta/mote.response))
		mote.at += mote.velocity*delta
		var offset: Vector2 = mote.at-fluid.center
		var distance := offset.length()
		if distance>368.0 or distance<68.0:
			var normal := offset.normalized()
			mote.at = fluid.center+normal*clampf(distance,68.0,368.0)
			mote.velocity -= normal*mote.velocity.dot(normal)
	cloud.multimesh.visible_instance_count = visible_count
	cloud.material.set_shader_parameter("clock",time)
	for i in visible_count:
		var mote: Dictionary = motes[i]
		cloud.multimesh.set_instance_transform_2d(i,Transform2D(mote.velocity.angle(),mote.at))
		cloud.multimesh.set_instance_color(i,Color(minf(mote.velocity.length()/60.0,1.0),1.0 if mote.glints else 0.0,0.0,1.0))
