extends Node2D
## A peaceful view of real rescued specimens. Simulation and journey snapshots
## never advance here; only this habitat's independent presentation clock does.
const Forms = preload("res://scripts/creature_forms.gd")
const Anatomy = preload("res://scripts/evolution_anatomy.gd")
const PAGE_SIZE := 36
var game: Node2D
var specimens: Array = []
var wild_algae: Array[Sprite2D] = []
var keepsakes: Array = []
var mother: Sprite2D
var selected := -1
var page := 0
var identity := ""
var clock := 0.0

func _ready() -> void:
	game = get_parent()
	z_index = -2
	mother = game.microscope.organism(game.microscope.MOTHER,145.0,2.1)
	mother.reparent(self)
	mother.position = Vector2(640,450)
	visible = false

func rebuild() -> void:
	for specimen in specimens:
		specimen.sprite.queue_free()
	specimens.clear()
	for sprite in wild_algae:
		sprite.queue_free()
	wild_algae.clear()
	for keepsake in keepsakes:
		keepsake.sprite.queue_free()
	keepsakes.clear()
	selected = -1
	var residents: Array = game.journey_profile.residents
	page = clampi(page,0,maxi(0,ceili(residents.size()/float(PAGE_SIZE))-1))
	var count := 12 if showing_epilogue() else PAGE_SIZE
	var start := maxi(0,residents.size()-count) if showing_epilogue() else page*PAGE_SIZE
	for i in range(start,mini(start+count,residents.size())):
		var record: Dictionary = residents[i]
		var variation := RandomNumberGenerator.new()
		variation.seed = hash(record.token)
		var texture: Texture2D = game.microscope.enemy_texture("spore",record.form)
		var extent := variation.randf_range(48,67) if not record.rare else 94.0
		var sprite: Sprite2D = game.microscope.organism(texture,extent,variation.randf_range(0,TAU))
		sprite.reparent(self)
		var uv: Vector2 = Forms.definition(record.form).get("uv",Vector2(0.514,0.526))
		game.microscope.register_nucleus(sprite,uv)
		var index := i-start
		var angle := index*2.399+variation.randf_range(-0.25,0.25)
		var radius := 150.0+float(index%4)*45.0
		specimens.append({"sprite":sprite,"record":record,"home":Vector2.from_angle(angle)*radius,"phase":variation.randf_range(0,TAU),"extent":extent,"habit":posmod(hash(record.token),3)})
	var forms := {}
	for resident in residents:
		forms[resident.form] = true
	if forms.size()>=3:
		for i in 9:
			var sprite: Sprite2D = game.microscope.organism(game.microscope.enemy_texture("food","fern_desmid"),12.0+i%3*3.0,float(i)*1.71)
			sprite.reparent(self)
			sprite.z_index = -1
			wild_algae.append(sprite)
	var visible_records: Array = specimens.map(func(s): return s.record)
	for specimen in specimens:
		specimen.companion = game.journey_profile.companion_for(specimen.record,visible_records)
	var forms_by_feat := {"guardian":"snow_spore","gatherer":"fern_desmid","clear_water":"glass_harp"}
	for j in forms_by_feat.size():
		var feat: String = forms_by_feat.keys()[j]
		if not game.journey_profile.keepsake_unlocked(feat):
			continue
		for i in 6:
			var extent: float = (32.0 if feat=="clear_water" else 18.0)+float(i%3)*4.0
			var sprite: Sprite2D = game.microscope.organism(Forms.texture(forms_by_feat[feat]),extent,i*1.71+j)
			sprite.reparent(self)
			sprite.z_index = -1
			var cluster := Vector2.from_angle(-2.75+j*2.1)*275.0
			keepsakes.append({"sprite":sprite,"feat":feat,"home":cluster+Vector2.from_angle(i*2.399)*(16.0+i*5.0),"phase":i*1.71+j})
	identity = collection_key()

func collection_key() -> String:
	return "%d:%d:%d:%s:%d" % [game.journey_profile.residents.size(),page,game.journey_profile.cleared_encounters.size(),str(showing_epilogue()),game.journey_profile.pond_memories.size()]

func showing_epilogue() -> bool:
	return game.run.journey and game.run.state=="success" and game.run.clots.is_empty() and not game.run.mother_damage.active()

func sync(delta: float) -> void:
	visible = (game.run.state=="home" and game.home_pond_open) or showing_epilogue()
	if not visible:
		return
	if identity!=collection_key():
		rebuild()
	var movement := 0.0 if game.reduced_motion else 1.0
	if not game.reduced_motion and not game.settings_open and not game.journal_open and not game.help_open and not game.hud.renaming():
		clock += delta
	game.microscope.animate_organism(mother,clock,movement,1.0)
	var epilogue := showing_epilogue()
	var traits: Array = game.run.mutations if epilogue else game.journey_profile.last_colony_traits
	Anatomy.apply(mother,Anatomy.recipe(traits))
	mother.material.set_shader_parameter("colony_grade",game.microscope.appearance.colony_grade if epilogue else Vector3.ONE)
	mother.material.set_shader_parameter("core_damage",game.run.mother_damage.progress_values() if epilogue else PackedFloat32Array([0,0,0,0,0]))
	mother.position = Vector2(640,430 if epilogue else 450)
	mother.scale = Vector2.ONE*(217.0 if epilogue else 145.0)/mother.texture.get_width()
	mother.rotation = sin(clock*0.13)*0.06
	for i in specimens.size():
		var specimen: Dictionary = specimens[i]
		var phase: float = specimen.phase
		var drift := Vector2(sin(clock*0.042+phase)*34+sin(clock*0.071+phase*2)*13,sin(clock*0.035+phase*1.7)*28+sin(clock*0.063+phase)*16)
		var home: Vector2 = specimen.home
		if specimen.habit==0:
			home *= 1.0-0.17*(0.5+sin(clock*0.043+phase)*0.5)
		elif specimen.habit==1:
			var kin := Vector2.ZERO
			var count := 0
			for other in specimens:
				if other.record.form==specimen.record.form and other!=specimen:
					kin += other.home
					count += 1
			if count>0:
				home = home.lerp(kin/float(count),0.20)
		else:
			drift *= 0.45
		# Friends periodically drift toward a common resting place, then explore
		# again. Use immutable home positions so update order cannot cause orbits.
		if not specimen.companion.is_empty():
			for other in specimens:
				if other.record.token==specimen.companion.token:
					var visiting: float = smoothstep(-0.25,0.85,sin(clock*0.047+phase))
					home = home.lerp(other.home,visiting*0.32)
					break
		var offset: Vector2 = home+drift
		var sprite: Sprite2D = specimen.sprite
		if epilogue:
			var angle: float = float(i)*2.399+phase*0.06
			offset = Vector2(cos(angle)*(213.0+i%2*17.0),sin(angle)*(136.0+i%2*11.0))+drift*0.2
		sprite.position = mother.position+offset.limit_length(332)
		sprite.position += game.run.fluid.displacement(sprite.position)*0.45*movement
		var previous: Vector2 = specimen.get("water_position",sprite.position)
		if movement>0.0 and sprite.position.distance_to(previous)<12.0:
			game.run.fluid.stroke(previous,sprite.position,0.85)
		specimen.water_position = sprite.position
		sprite.rotation = phase+sin(clock*0.07+phase)*0.35
		game.microscope.animate_organism(sprite,clock,movement,1.0)
		var opening := 0.5+sin(clock*TAU/18.0+phase)*0.5
		sprite.material.set_shader_parameter("visitor_open",opening if specimen.record.rare else 1.0)
		sprite.material.set_shader_parameter("visitor_glow",opening*0.6 if specimen.record.form=="glowdrift" else 0.0)
		var growth: float = lerpf(0.78,1.0,game.journey_profile.maturity(specimen.record))
		sprite.scale = Vector2.ONE*specimen.extent*growth/sprite.texture.get_width()
	for i in wild_algae.size():
		var sprite: Sprite2D = wild_algae[i]
		var angle: float = float(i)*2.399
		var drift := Vector2(sin(clock*0.023+angle),cos(clock*0.019+angle))*18.0
		sprite.position = mother.position+Vector2.from_angle(angle)*(238.0+i%3*25.0)*(0.8 if epilogue else 1.0)+drift
		sprite.position += game.run.fluid.displacement(sprite.position)*0.65*movement
		sprite.modulate.a = 0.45
		game.microscope.animate_organism(sprite,clock,movement,0.7)
	for keepsake in keepsakes:
		var sprite: Sprite2D = keepsake.sprite
		var phase: float = keepsake.phase
		sprite.position = mother.position+keepsake.home+Vector2(sin(clock*0.045+phase),cos(clock*0.033+phase))*8.0
		sprite.rotation = phase+sin(clock*0.03+phase)*0.12
		sprite.modulate.a = 0.65
		game.microscope.animate_organism(sprite,clock,movement,0.7)
	queue_redraw()

func pick(at: Vector2) -> void:
	selected = -1
	var nearest := 45.0
	for i in specimens.size():
		var distance: float = specimens[i].sprite.position.distance_to(at)
		if distance<nearest:
			selected = i
			nearest = distance
	queue_redraw()

func selected_record() -> Dictionary:
	return specimens[selected].record if selected>=0 and selected<specimens.size() else {}

func selected_companion() -> Dictionary:
	return specimens[selected].companion if selected>=0 and selected<specimens.size() else {}

func turn_page(direction: int) -> void:
	page = clampi(page+direction,0,maxi(0,ceili(game.journey_profile.residents.size()/float(PAGE_SIZE))-1))

func _draw() -> void:
	if selected<0 or selected>=specimens.size():
		return
	var specimen: Dictionary = specimens[selected]
	var p: Vector2 = specimen.sprite.position
	var radius: float = specimen.extent*0.52
	if not specimen.companion.is_empty():
		for other in specimens:
			if other.record.token==specimen.companion.token:
				draw_arc(other.sprite.position,other.extent*0.55,0.3,2.8,28,Color(0.75,0.83,0.6,0.38),1.0,true)
				break
	for i in 3:
		var angle := i*TAU/3.0+clock*0.04
		draw_arc(p,radius,angle,angle+1.1,24,Color(0.66,0.86,0.85,0.55),1.0,true)
