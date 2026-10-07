extends Node2D
## Ambient life only: no input, collision, gameplay nodes, or autonomous clocks.
const SPECIMENS = preload("res://assets/organisms/pond-brightfield-life.png")
const SPECIMEN = preload("res://shaders/pond_specimen.gdshader")
const SUSPENSION = preload("res://shaders/pond_suspension.gdshader")
const Water = preload("res://scripts/water_interaction.gd")
const CENTER := Vector2(640, 450)
var specimens: Array[Sprite2D] = []
var suspension: MultiMeshInstance2D
var clock := 0.0
var movement := 1.0
var quality := 2
var biome := 0
var appearance_key := ""
var water_base := Vector3(0.055,0.115,0.150)
var light_direction := Vector2(-0.65,-1.0)
var currents := PackedVector4Array()
var strokes := PackedVector4Array()
var stroke_strengths := PackedFloat32Array()
var fluid: RefCounted

func set_fluid(field: RefCounted, texture: ImageTexture) -> void:
	fluid = field
	suspension.material.set_shader_parameter("fluid_map",texture)
	suspension.material.set_shader_parameter("fluid_enabled",true)

func set_flow(next_currents: PackedVector4Array, next_strokes: PackedVector4Array, strengths: PackedFloat32Array) -> void:
	currents = next_currents
	strokes = next_strokes
	stroke_strengths = strengths
	suspension.material.set_shader_parameter("currents",currents)
	suspension.material.set_shader_parameter("strokes",strokes)
	suspension.material.set_shader_parameter("stroke_strengths",stroke_strengths)

func _ready() -> void:
	populate(73127,90713,46,264,Vector3.ONE)

func configure_appearance(look: Dictionary) -> void:
	if appearance_key == look.key:
		return
	appearance_key = look.key
	biome = int(look.get("biome",0))
	water_base = look.water_base
	light_direction = look.light_direction
	for sprite in specimens:
		remove_child(sprite)
		sprite.queue_free()
	specimens.clear()
	if is_instance_valid(suspension):
		remove_child(suspension)
		suspension.queue_free()
	populate(look.life_seed,look.dust_seed,look.life_count,look.dust_count,look.water_grade)

func populate(life_seed: int, dust_seed: int, life_count: int, dust_count: int, grade: Vector3) -> void:
	# Sparse real-looking specimens have uneven sizes and focal depths. They
	# stay smaller than playable tissue and leave calm water around the mother.
	var rng := RandomNumberGenerator.new()
	rng.seed = life_seed
	for i in life_count:
		var angle := rng.randf() * TAU
		var radius := sqrt(rng.randf_range(0.06, 0.83)) * 380.0
		var kinds: Array = [[1,3,1,2,0],[0,2,0,1,2],[2,3,2,1,3]][biome]
		var kind: int = kinds[i%kinds.size()]
		var extent := rng.randf_range(24.0, 44.0) if kind == 0 else rng.randf_range(19.0, 38.0)
		add_specimen(CENTER + Vector2.from_angle(angle) * radius, extent, rng.randf() * TAU, kind, rng.randf_range(0.78,0.94), rng.randf_range(0.001,0.0025))
		var sprite := specimens[-1]
		var interval := rng.randf_range(6.5,10.0) if kind==1 else rng.randf_range(12.0,18.0)
		var reach := rng.randf_range(48.0,70.0) if kind==1 else rng.randf_range(42.0,62.0)
		sprite.set_meta("swim",Vector4(interval,rng.randf_range(0.0,80.0),reach,rng.randf_range(0.12,0.78)))
		sprite.material.set_shader_parameter("water_grade",grade)
		sprite.material.set_shader_parameter("water_base",water_base)
		sprite.material.set_shader_parameter("light_direction",light_direction)
	build_suspension(dust_seed,dust_count)
	suspension.material.set_shader_parameter("water_grade",grade)
	suspension.material.set_shader_parameter("water_base",water_base)
	suspension.material.set_shader_parameter("light_direction",light_direction)
	suspension.material.set_shader_parameter("biome",float(biome))
	apply_visibility()
	sync(0.0, 1.0)

func add_specimen(at: Vector2, extent: float, phase: float, kind: int, opacity: float, blur: float) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = SPECIMENS
	sprite.hframes = 2
	sprite.vframes = 2
	sprite.frame = kind
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.scale = Vector2.ONE * extent / (SPECIMENS.get_width() * 0.5)
	sprite.z_index = -1
	sprite.set_meta("extent", extent)
	sprite.set_meta("rest_position", at)
	sprite.set_meta("phase", phase)
	sprite.set_meta("kind", kind)
	sprite.set_meta("blur", blur)
	sprite.set_meta("base_scale",sprite.scale)
	sprite.material = ShaderMaterial.new()
	sprite.material.shader = SPECIMEN
	sprite.material.set_shader_parameter("phase", phase)
	sprite.material.set_shader_parameter("kind", float(kind))
	sprite.material.set_shader_parameter("frame_origin", Vector2(kind % 2, kind / 2) * 0.5)
	sprite.material.set_shader_parameter("blur", blur)
	sprite.material.set_shader_parameter("opacity", opacity)
	add_child(sprite)
	specimens.append(sprite)

func build_suspension(seed_value: int = 90713, count: int = 264) -> void:
	# One instanced draw for hundreds of flecks, swimmers, husks, and filaments.
	# Their transforms are uploaded once; the shader advects them thereafter.
	var mesh := QuadMesh.new()
	mesh.size = Vector2.ONE
	var cloud := MultiMesh.new()
	cloud.transform_format = MultiMesh.TRANSFORM_2D
	cloud.use_colors = true
	cloud.use_custom_data = true
	cloud.mesh = mesh
	cloud.instance_count = count
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in cloud.instance_count:
		var angle := rng.randf() * TAU
		var radius := sqrt(rng.randf()) * 378.0
		var at := CENTER + Vector2.from_angle(angle) * radius
		var depth := rng.randf()
		var category := i*264/count
		var kind := 0
		var size := Vector2.ONE * rng.randf_range(2.0, 4.5)
		var tint := Color(0.065, 0.09, 0.12, rng.randf_range(0.20, 0.40))
		if category >= 250:
			kind = 4 # Fine drifting algal fibres.
			size = Vector2(rng.randf_range(14.0, 34.0), 8.0)
			tint = Color(0.12, 0.17, 0.20, 0.24)
		elif category >= 224:
			kind = 3 # Irregular husks and flakes, well below the focal plane.
			size = Vector2(rng.randf_range(6.0, 11.0), rng.randf_range(4.0, 8.0))
			tint = Color(0.08, 0.105, 0.105, rng.randf_range(0.16, 0.28))
		elif category >= 196:
			kind = 2 # Small translucent protozoa.
			size = Vector2(rng.randf_range(7.0, 12.0), rng.randf_range(4.0, 7.0))
			tint = Color(0.18, 0.23, 0.25, rng.randf_range(0.20, 0.34))
		elif category >= 160:
			kind = 1 # Fine bacilli.
			size = Vector2(rng.randf_range(4.5, 8.0), 3.0)
		var rotation := rng.randf() * TAU
		# Interleave kinds so every detail level retains varied microscopic debris.
		var slot := (i * 97) % cloud.instance_count
		cloud.set_instance_transform_2d(slot, Transform2D(rotation, size, 0.0, at))
		cloud.set_instance_color(slot, tint)
		cloud.set_instance_custom_data(slot, Color(rng.randf(), depth, float(kind), rng.randf()))
	suspension = MultiMeshInstance2D.new()
	suspension.multimesh = cloud
	suspension.material = ShaderMaterial.new()
	suspension.material.shader = SUSPENSION
	suspension.z_index = 0
	add_child(suspension)

func set_quality(value: int) -> void:
	if quality == value:
		return
	quality = value
	apply_visibility()

func apply_visibility() -> void:
	var visible_specimens: int = [10, 18, 46][quality]
	for i in specimens.size():
		specimens[i].visible = i < visible_specimens
	suspension.multimesh.visible_instance_count = mini([80, 160, 264][quality],suspension.multimesh.instance_count)

func sync(time: float, motion: float) -> void:
	clock = time
	movement = motion
	var t := time * motion
	for sprite in specimens:
		if not sprite.visible:
			continue
		var phase: float = sprite.get_meta("phase")
		var kind: int = sprite.get_meta("kind")
		var rest: Vector2 = sprite.get_meta("rest_position")
		var swim: Vector4 = sprite.get_meta("swim")
		var at := swimming_position(sprite,t)
		# Currents are a small common influence, never a replacement for swimming.
		at += Vector2(sin(t*0.029+biome)*5.0,cos(t*0.023+biome)*4.0)
		sprite.position = rest.lerp(at,motion)
		sprite.position += Water.displacement(sprite.position,currents,strokes,stroke_strengths)*motion*0.65
		if fluid != null:
			# Share transported water with the suspension; swimming remains local.
			sprite.position += fluid.displacement(at)*motion*(0.90+swim.w*0.55)
		var turn := phase+sin(t*0.067+phase)*0.33+sin(t*0.037+phase*1.9)*0.21
		if kind==1:
			# The photographed ciliate's long axis points diagonally upward right.
			# Face its own route, including smooth turns, instead of sliding sideways.
			var velocity := swimming_position(sprite,t+0.3)-swimming_position(sprite,t-0.3)
			turn = velocity.angle()+PI*0.25
		sprite.rotation = lerp_angle(phase,turn,motion)
		sprite.material.set_shader_parameter("clock", time)
		sprite.material.set_shader_parameter("motion", motion)
		# Swimming above and below focus changes softness, translucency and size
		# together. Every specimen has a different depth and phase.
		var depth := clampf(swim.w+(sin(t*0.081+phase)*0.14+sin(t*0.043+phase*2.3)*0.09)*motion,0.0,1.0)
		sprite.scale = Vector2(sprite.get_meta("base_scale"))*(1.0+(swim.w-depth)*0.055)
		sprite.material.set_shader_parameter("depth",depth)
		sprite.material.set_shader_parameter("blur",float(sprite.get_meta("blur"))+depth*0.010)
	suspension.material.set_shader_parameter("clock", time)
	suspension.material.set_shader_parameter("motion", motion)

func swimming_position(sprite: Sprite2D, time: float) -> Vector2:
	# Random-looking C1-continuous routes sampled directly from the visual clock.
	# No integration drift, shared orbit, path-loop reset or gameplay RNG use.
	var swim: Vector4 = sprite.get_meta("swim")
	var phase: float = sprite.get_meta("phase")
	var rest: Vector2 = sprite.get_meta("rest_position")
	var at := (time+sin(time*0.31+phase)*0.65+swim.y)/swim.x
	var leg := int(floorf(at))
	var f := at-floorf(at)
	var a := swimming_waypoint(leg-1,phase,rest,swim.z)
	var b := swimming_waypoint(leg,phase,rest,swim.z)
	var c := swimming_waypoint(leg+1,phase,rest,swim.z)
	var d := swimming_waypoint(leg+2,phase,rest,swim.z)
	return 0.5*((2.0*b)+(-a+c)*f+(2.0*a-5.0*b+4.0*c-d)*f*f+(-a+3.0*b-3.0*c+d)*f*f*f)

static func swimming_waypoint(leg: int, phase: float, rest: Vector2, reach: float) -> Vector2:
	var direction := fposmod(sin(leg*127.1+phase*311.7)*43758.5453,1.0)*TAU
	var length := (0.35+fposmod(sin(leg*269.5+phase*183.3)*23421.631,1.0)*0.65)*reach
	var offset := rest+Vector2.from_angle(direction)*length-CENTER
	return CENTER+offset.limit_length(353.0)
