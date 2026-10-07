extends Node2D
const GRANULE_SHADER = preload("res://shaders/cytoplasm_granules.gdshader")
const CILIA_SHADER = preload("res://shaders/living_cilia.gdshader")
static var strand_mesh: ArrayMesh
## Fine living structures, instanced in the parent texture's coordinates.
## No physics: the parent sprite origin is always the logical anchor/nucleus.
var kind := 0
var phase := 0.0
var texture_extent := 1254.0
var display_extent := 63.0
var clock := 0.0
var movement := 1.0
var energy := 1.0
var feeding := 0.0
var lure := 0.0
var morphology := Vector4.ZERO
var phenotype := Vector4(1,1,0,0)
var flow_velocity := Vector2.ZERO
var granule_cloud: MultiMeshInstance2D
var cilia_cloud: MultiMeshInstance2D

func _ready() -> void:
	# One instanced draw replaces individual antialiased circles and trails.
	# A conservative source quad keeps culling bounds around the whole tissue;
	# its vertex shader follows the same tiny circulating pockets as below.
	var count := 26 if kind==1 else 13 if kind==2 else 9
	var mesh := QuadMesh.new()
	mesh.size = Vector2.ONE*texture_extent
	var cloud := MultiMesh.new()
	cloud.transform_format = MultiMesh.TRANSFORM_2D
	cloud.use_custom_data = true
	cloud.mesh = mesh
	cloud.instance_count = count
	for i in count:
		cloud.set_instance_transform_2d(i,Transform2D.IDENTITY)
		cloud.set_instance_custom_data(i,Color(float(i),0,0,0))
	granule_cloud = MultiMeshInstance2D.new()
	granule_cloud.multimesh = cloud
	granule_cloud.material = ShaderMaterial.new()
	granule_cloud.material.shader = GRANULE_SHADER
	for pair in [["kind",float(kind)],["phase",phase],["granule_count",float(count)],["texture_extent",texture_extent],["display_extent",display_extent]]:
		granule_cloud.material.set_shader_parameter(pair[0],pair[1])
	add_child(granule_cloud)
	build_cilia()

func granule_position(index: int, time: float, count: int) -> Vector2:
	var a := index*2.399+phase
	var radius := 0.11+0.18*sqrt(float(index+1)/(count+1))
	var p := Vector2.from_angle(a)*radius
	# Separate small circulating pockets, rather than particles on rigid orbits.
	p += Vector2(sin(time*0.31+a*1.3),cos(time*0.27+a*0.7))*0.032*movement
	p += Vector2(sin(time*0.53+p.y*9.0+a),cos(time*0.43-p.x*11.0+a))*0.012*movement
	if kind==2 or kind==4:
		p.y *= 0.38
	return p

func animate(time: float, motion: float, vitality: float, meal: float = 0.0) -> void:
	clock = time
	movement = motion
	energy = vitality
	feeding = meal
	if granule_cloud!=null:
		granule_cloud.self_modulate = self_modulate
		granule_cloud.material.set_shader_parameter("clock",clock)
		granule_cloud.material.set_shader_parameter("motion",movement)
		granule_cloud.material.set_shader_parameter("energy",energy)
		granule_cloud.material.set_shader_parameter("feeding",feeding)
	if cilia_cloud!=null:
		cilia_cloud.self_modulate = self_modulate
		cilia_cloud.multimesh.visible_instance_count = (42 if lure>0.0 else 34) if kind==1 else (23 if lure>0.0 else 16) if kind==0 else 34 if kind==2 else 6
		for pair in [["clock",clock],["motion",movement],["energy",energy],["lure",lure],["morphology",morphology],["phenotype",phenotype],["flow_velocity",flow_velocity]]:
			cilia_cloud.material.set_shader_parameter(pair[0],pair[1])

func build_cilia() -> void:
	if kind>=4:
		return
	if strand_mesh==null:
		var vertices := PackedVector2Array()
		var uvs := PackedVector2Array()
		var indices := PackedInt32Array()
		for sample in 8:
			var u := float(sample)/7.0
			for side in 2:
				# Conservative source bounds; the shader supplies the actual curve.
				vertices.append(Vector2((u-0.5)*1.7,float(side)*1.7-0.85))
				uvs.append(Vector2(u,float(side)))
		for segment in 7:
			var base := segment*2
			indices.append_array(PackedInt32Array([base,base+2,base+1,base+1,base+2,base+3]))
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_INDEX] = indices
		strand_mesh = ArrayMesh.new()
		strand_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var count := 42 if kind==1 else 23 if kind==0 else 34 if kind==2 else 6
	var cloud := MultiMesh.new()
	cloud.transform_format = MultiMesh.TRANSFORM_2D
	cloud.use_custom_data = true
	cloud.mesh = strand_mesh
	cloud.instance_count = count
	for i in count:
		cloud.set_instance_transform_2d(i,Transform2D.IDENTITY)
		cloud.set_instance_custom_data(i,Color(float(i),0,0,0))
	cilia_cloud = MultiMeshInstance2D.new()
	cilia_cloud.multimesh = cloud
	cilia_cloud.scale = Vector2.ONE*texture_extent
	cilia_cloud.material = ShaderMaterial.new()
	cilia_cloud.material.shader = CILIA_SHADER
	for pair in [["kind",float(kind)],["phase",phase],["display_extent",display_extent]]:
		cilia_cloud.material.set_shader_parameter(pair[0],pair[1])
	add_child(cilia_cloud)
