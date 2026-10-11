extends Node2D
## A skippable, safe close-up between purchase and the next mission briefing.
const Anatomy = preload("res://scripts/evolution_anatomy.gd")
const MotherAppearance = preload("res://scripts/mother_appearance.gd")
const Mutations = preload("res://scripts/mutations.gd")
const UI = preload("res://scripts/ui_style.gd")
var game: Node2D
var trait_id := ""
var stage := -1
var mother: Sprite2D
var cells: Array[Sprite2D] = []
var buds: Array[Sprite2D] = []
var continue_button: Button

func _ready() -> void:
	game = get_parent()
	z_index = 30
	visible = false
	# Reuse the real organism renderer, including damage sites and anatomy.
	mother = game.microscope.organism(game.microscope.MOTHER,196.0,0.3)
	mother.reparent(self)
	mother.position = Vector2(500,434)
	mother.z_index = 1
	for i in 3:
		var cell: Sprite2D = game.microscope.organism(game.microscope.CELL,80.0,float(i)*1.7)
		cell.reparent(self)
		cell.position = [Vector2(772,382),Vector2(848,452),Vector2(756,518)][i]
		cell.rotation = float(i)*2.399
		cell.z_index = 1
		cells.append(cell)
		var bud: Sprite2D = game.microscope.organism(game.microscope.CELL,28.0,float(i)*1.7+1.0,false)
		bud.reparent(self)
		bud.z_index = 1
		buds.append(bud)
	continue_button = game.hud.button("Continue",Vector2(500,728),Vector2(280,48),dismiss,"Enter")
	UI.style_button(continue_button,"primary",15)
	continue_button.reparent(self)
	continue_button.z_index = 2

func present(id: String) -> void:
	trait_id = id
	stage = game.run.stage_index
	game.microscope.start_growth(id)
	visible = true
	sync()
	game.hud.refresh()

func dismiss() -> void:
	visible = false
	game.microscope.finish_growth()
	game.hud.refresh()

func sync() -> void:
	if not visible:
		return
	if game.run.state!="brief" or game.run.stage_index!=stage:
		dismiss()
		return
	var recipe := Anatomy.recipe(game.run.mutations,trait_id,game.microscope.growth_progress())
	MotherAppearance.apply(mother,game.run.stage_index,game.run.mutations)
	var movement := 0.0 if game.reduced_motion else 1.0
	for i in cells.size():
		cells[i].material.set_shader_parameter("phenotype",game.microscope.appearance.cells[i])
	for sprite in [mother]+cells:
		Anatomy.apply(sprite,recipe)
		sprite.material.set_shader_parameter("colony_grade",game.microscope.appearance.colony_grade)
		game.microscope.animate_organism(sprite,game.visual_time,movement,1.0)
	mother.material.set_shader_parameter("core_damage",game.run.mother_damage.progress_values())
	for i in cells.size():
		buds[i].visible = recipe.traits.x>0.0
		buds[i].position = cells[i].position+Vector2.from_angle(float(i)*2.399+0.4)*41.0
		buds[i].scale = Vector2.ONE*35.0/game.microscope.CELL.get_width()*recipe.traits.x
		buds[i].modulate.a = recipe.traits.x
		buds[i].material.set_shader_parameter("colony_grade",game.microscope.appearance.colony_grade)
		game.microscope.animate_organism(buds[i],game.visual_time,movement,0.75)
	queue_redraw()

func line(value: String, at: Vector2, size_px: int, color: Color, weight: int = 0) -> void:
	draw_string(UI.text_font(size_px,weight),at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size_px,color)

func centered(value: String, y: float, size_px: int, color: Color, weight: int = 0) -> void:
	var width := UI.text_font(size_px,weight).get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,size_px).x
	line(value,Vector2((1280-width)*0.5,y),size_px,color,weight)

func _draw() -> void:
	if trait_id.is_empty():
		return
	var definition := Mutations.journey_definition(trait_id)
	draw_rect(Rect2(0,0,1280,900),Color(0.005,0.015,0.018,0.88))
	draw_style_box(UI.dialog_box(),Rect2(235,110,810,694))
	centered(definition.name,178,32,UI.INK)
	centered(("Your colony is evolving.  " if game.microscope.growth_progress()<1.0 else "Now part of your colony.  ")+Anatomy.CHANGES[trait_id],208,14,UI.MUTED)
	line("The mother",Vector2(464,660),13,UI.ACCENT,UI.MEDIUM)
	line("Her cells",Vector2(774,660),13,UI.ACCENT,UI.MEDIUM)
	var size_px := 17 if game.large_text else 15
	var lines: PackedStringArray = definition.detail.split("\n")
	for i in lines.size():
		centered(lines[i],686+i*22,size_px,UI.INK)
