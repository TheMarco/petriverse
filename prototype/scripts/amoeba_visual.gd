extends Node2D
## Asymmetric microscopy tissue: one deforming membrane from crawling to engulfing.
const TEXTURE = preload("res://assets/organisms/amoeba-v2.png")
const NUCLEUS_UV := Vector2(0.534,0.463)
const BODY = preload("res://shaders/amoeba_body.gdshader")
const Arrival = preload("res://scripts/organism_arrival.gd")
const Outline = preload("res://scripts/amoeba_outline.gd")
var skin: ColorRect
var captive: Sprite2D
var body_state: RefCounted
var clock := 0.0
var motion := 1.0
var captive_local := Vector2.ZERO
var meal := 0.0
var oriented := false

func setup(scope: Node2D, body: RefCounted) -> void:
	z_index = 4
	skin = ColorRect.new()
	skin.z_index = -1
	skin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skin.material = scope.material_for(BODY)
	skin.material.set_shader_parameter("tissue_texture",TEXTURE)
	skin.material.set_shader_parameter("outline_texture",Outline.texture_for(TEXTURE))
	skin.material.set_shader_parameter("phase",body.id*0.71)
	add_child(skin)
	captive = scope.organism(scope.CELL,45.0,body.id*0.7,false)
	captive.reparent(self)
	captive.z_index = 2
	set_meta("lobes",[skin])

func sync(scope: Node2D, body: RefCounted, time: float, movement: float) -> void:
	position = body.nucleus
	body_state = body
	var elapsed := clampf(time-clock,0.0,0.10)
	var direction: Vector2 = body.ingest_axis if body.phase in ["reaching","digesting","sated"] else body.heading
	if direction.length_squared()>0.01:
		rotation = lerp_angle(rotation,direction.angle(),1.0-exp(-elapsed*2.2)) if oriented else direction.angle()
		oriented = true
	clock = time
	motion = movement
	meal = body.meal_progress()
	var goal: Vector2 = (body.reach_point-body.nucleus).rotated(-rotation)
	if body.phase=="digesting": goal = (body.captive_position(movement<=0.0)-body.nucleus).rotated(-rotation)
	var extension := 0.0
	if body.phase=="reaching": extension = smoothstep(0.0,body.REACH_TIME,body.reach_age)
	if body.phase=="digesting": extension = 1.0-smoothstep(0.65,1.8,body.digestion_age)
	var extending: bool = extension>0.001
	var ingestion := smoothstep(0.0,1.1,body.digestion_age) if body.captive_node>=0 else 0.0
	var closure := smoothstep(0.0,0.35,body.digestion_age) if body.captive_node>=0 else 0.0
	var low := Vector2(-120,-95).min(goal-Vector2.ONE*43.0) if extending else Vector2(-120,-95)
	var high := Vector2(120,95).max(goal+Vector2.ONE*43.0) if extending else Vector2(120,95)
	skin.position = low
	skin.size = high-low
	var uniforms := {"extent":skin.size,"origin":-low,"target":goal,"clock":time,"crawl":body.crawl_phase(),"motion":movement,"extension":extension*movement,"ingestion":ingestion,"closure":closure,"meal":meal,"arrival":Arrival.progress(body),"water_base":scope.appearance.water_base*scope.appearance.water_grade}
	for key in uniforms: skin.material.set_shader_parameter(key,uniforms[key])
	captive.visible = body.captive_node>=0
	if captive.visible:
		captive_local = (body.captive_position(movement<=0.0)-body.nucleus).rotated(-rotation)
		captive.position = captive_local
		var size := lerpf(63.0,43.0,ingestion)*(1.0-smoothstep(0.45,1.0,meal)*0.65)
		captive.scale = Vector2.ONE*size/scope.CELL.get_width()
		captive.rotation = (body.digestion_age*0.18+sin(time*0.72)*0.08)*movement-rotation
		scope.animate_organism(captive,time,movement,1.0-meal*0.8)
		captive.material.set_shader_parameter("invading_depth",ingestion)
		captive.material.set_shader_parameter("host_texture",TEXTURE)
		captive.material.set_shader_parameter("host_center",position+((Vector2.ONE*0.5-NUCLEUS_UV)*152.0).rotated(rotation))
		captive.material.set_shader_parameter("host_extent",Vector2.ONE*152.0)
		captive.material.set_shader_parameter("host_rotation",rotation)
		captive.material.set_shader_parameter("dissolve",smoothstep(0.6,1.0,meal)*0.95)
		captive.modulate.a = 1.0-smoothstep(0.92,1.0,meal)
	queue_redraw()

func _draw() -> void:
	if body_state==null or body_state.captive_node<0: return
	var ingest := smoothstep(0.0,1.1,body_state.digestion_age)
	var radius := lerpf(28.0,24.0,ingest)*(1.0-meal*0.3)
	draw_circle(captive_local,radius,Color(0.40,0.51,0.47,0.14*ingest),true,-1,true)
	draw_arc(captive_local,radius,0.0,TAU,40,Color(0.71,0.80,0.73,0.32*ingest),0.8,true)
	draw_arc(captive_local+Vector2(-0.8,-1),radius-1.7,3.2,5.2,20,Color(0.76,0.88,0.86,0.40*ingest),1.1,true)
	for i in 14:
		var phase := i*2.399+clock*0.32*motion
		var at := captive_local+Vector2.from_angle(phase)*(radius+sin(i*1.7+clock*0.7*motion)*4.0)
		draw_circle(at,0.6+float(i%3)*0.25,Color(0.66,0.76,0.67,meal*0.6),true,-1,true)
