extends Node2D
## Each virion uses its own photographic tissue and articulated tail shader.
const TEXTURE = preload("res://assets/organisms/silver-phage.png")
const SKIN = preload("res://shaders/phage.gdshader")
var run: RefCounted
var clock := 0.0
var motion := 1.0
var sprites: Dictionary = {}
var wanted: Dictionary = {}

static func specimen(canvas: CanvasItem, at: Vector2, angle: float, size: float, _time: float, _contraction: float = 0.0, alpha: float = 1.0) -> void:
	canvas.draw_set_transform(at,angle,Vector2.ONE*size)
	canvas.draw_texture_rect(TEXTURE,Rect2(-8,-12,16,24),false,Color(1,1,1,alpha))
	canvas.draw_set_transform(Vector2.ZERO)

static func drift_offset(index: int, age: float) -> Vector2:
	return Vector2.from_angle(index*TAU/3.0+0.2)*15.0+Vector2(sin(age*0.6+index*1.7),cos(age*0.43+index))*2.5

func virion(key: String, at: Vector2, angle: float, height: float, contraction: float, opacity: float) -> void:
	wanted[key] = true
	if not sprites.has(key):
		var item := Sprite2D.new()
		item.texture = TEXTURE
		item.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		item.material = ShaderMaterial.new()
		item.material.shader = SKIN
		item.material.set_shader_parameter("phase",float(sprites.size())*1.71)
		add_child(item)
		sprites[key] = item
	var sprite: Sprite2D = sprites[key]
	sprite.position = at
	sprite.rotation = angle
	sprite.scale = Vector2.ONE*height/TEXTURE.get_height()
	sprite.modulate.a = opacity
	sprite.material.set_shader_parameter("clock",clock)
	sprite.material.set_shader_parameter("motion",motion)
	sprite.material.set_shader_parameter("contraction",contraction)

func sync(value: RefCounted, time: float, movement: float) -> void:
	run = value
	clock = time
	motion = movement
	visible = run.journey and run.state not in ["home","brief"]
	wanted.clear()
	for group in run.phages.clusters:
		var body = run.phages.host(run,group.host_id)
		var arrival := smoothstep(0.1,2.5,group.age)
		for i in 3:
			var at: Vector2 = group.nucleus+drift_offset(i,clock*motion)
			var angle: float = i*2.4+sin(clock*0.25*motion+group.id+i)*0.3
			var contraction := 0.0
			if body!=null:
				var ports := [Vector2(-21,-7.5),Vector2(0,8.5),Vector2(21,-7.5)]
				var facing: float = body.heading.angle()
				var target_angle := facing+(PI if i==1 else 0.0)
				# The baseplate meets the cell wall; the capsid stays outside it.
				var destination: Vector2 = body.nucleus+ports[i].rotated(facing)-Vector2(0,5.2).rotated(target_angle)
				var dock := smoothstep(i*0.12,1.25+i*0.12,body.infection_age)
				at = (group.attached_from+drift_offset(i,0)).lerp(destination,dock)
				angle = lerp_angle(angle,target_angle,dock)
				contraction = smoothstep(0.7+i*0.12,1.8+i*0.12,body.infection_age)
			else:
				angle += group.nudge_roll()*motion*0.4
			virion("%d:%d" % [group.id,i],at,angle,25.0*lerpf(0.65,1.0,arrival),contraction,arrival*group.opacity())
	for burst in run.phages.bursts:
		var fade := 1.0-smoothstep(0.8,3.2,burst.age)
		var spread: float = (1.0-exp(-burst.age*1.8))*40.0*motion
		for i in 6:
			var angle: float = i*2.399+burst.serial
			var origin := Vector2(sin(i*1.71)*25.0,cos(i*2.39)*6.0).rotated(burst.angle)
			var at: Vector2 = burst.at+origin+Vector2.from_angle(angle)*spread
			virion("burst:%d:%d" % [burst.serial,i],at,angle+burst.age*0.15*motion,9.0,0.0,fade*0.70)
	for key in sprites.keys():
		if not wanted.has(key):
			sprites[key].queue_free()
			sprites.erase(key)
	queue_redraw()

func _draw() -> void:
	if run==null: return
	for group in run.phages.clusters:
		var body = run.phages.host(run,group.host_id)
		if body==null: continue
		# Faint capsids assemble within the host's granular cytoplasm.
		var growth := smoothstep(2.4,7.5,body.infection_age)
		var fade := 1.0-smoothstep(8.0,9.0,body.infection_age)
		for i in 17:
			var local := Vector2(sin(i*2.399)*27.0,cos(i*1.73)*5.0)
			var at: Vector2 = body.nucleus+local.rotated(body.heading.angle())
			draw_circle(at,0.65,Color(0.80,0.86,0.98,growth*fade*0.55),true,-1,true)
			draw_arc(at,1.05,0,TAU,6,Color(0.67,0.77,0.96,growth*fade*0.4),0.5,true)
	for burst in run.phages.bursts:
		var fade := 1.0-smoothstep(0.8,3.2,burst.age)
		var spread: float = (1.0-exp(-burst.age*1.8))*40.0*motion
		for i in 14:
			var angle: float = i*2.399+burst.serial
			var origin := Vector2(sin(i*1.71)*25.0,cos(i*2.39)*6.0).rotated(burst.angle)
			var at: Vector2 = burst.at+origin+Vector2.from_angle(angle)*spread
			draw_arc(at,2.0+i%3,angle,angle+1.8,8,Color(0.73,0.72,0.52,fade*0.46),0.65,true)
		if motion>0:
			draw_arc(burst.at,15.0+spread,0,TAU,64,Color(0.57,0.81,0.86,fade*0.10),0.8,true)
