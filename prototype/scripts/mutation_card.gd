extends Button

const CELL = preload("res://assets/organisms/cell.png")
const TISSUE = preload("res://shaders/living_tissue.gdshader")
const Anatomy = preload("res://scripts/evolution_anatomy.gd")
const UI = preload("res://scripts/ui_style.gd")
const Mutations = preload("res://scripts/mutations.gd")
const Comparison = preload("res://scripts/evolution_comparison.gd")
var data: Dictionary = {}
## Exact before/after example for journey offers; empty for legacy configure.
var comparison: Dictionary = {}
## Full comparison text for a wider panel when the 236px card at large
## text (text_multiplier 1.25) can only fit the compact numeric lines.
var detail_summary := ""
var number := 1
var text_multiplier := 1.0
var specimen: Sprite2D
var bud: Sprite2D
var guided_choice := false
## Compare details: the card turns over to show its full description.
var detailed := false
var reduced_motion := false
var cost := -1
var balance := 0
var demo_time := 0.0
## Eased hover and focus presence, drawn as an accent glow.
var hover := 0.0
var glow_box: StyleBoxFlat
const FOOD = preload("res://assets/organisms/desmid.png")

func _process(delta: float) -> void:
	if visible:
		if not reduced_motion:
			demo_time += delta
		var target := 1.0 if (is_hovered() or has_focus()) and not disabled else 0.0
		hover = move_toward(hover, target, delta * (7.0 if target > hover else 4.0))
		queue_redraw()

## Every detail is printed on one face of the card; no tooltip repeats it.
func _get_tooltip(_at: Vector2) -> String:
	return ""

func _ready() -> void:
	specimen = Sprite2D.new()
	specimen.texture = CELL
	specimen.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	specimen.position = Vector2(125,62)
	specimen.scale = Vector2.ONE*76.0/CELL.get_width()
	specimen.material = ShaderMaterial.new()
	specimen.material.shader = TISSUE
	add_child(specimen)
	bud = Sprite2D.new()
	bud.texture = CELL
	bud.position = Vector2(153,77)
	bud.scale = Vector2.ONE*25.0/CELL.get_width()
	bud.visible = false
	add_child(bud)

func configure_journey(run: RefCounted, id: String, index: int) -> void:
	configure(Mutations.journey_definition(id), index, run.mutations)
	# configure clears the comparison for legacy callers; restore journey data.
	comparison = Comparison.compare(run, id)
	detail_summary = comparison.detail_summary

func configure(definition: Dictionary, index: int, owned: Array = []) -> void:
	data = definition
	number = index + 1
	comparison = {}
	detail_summary = ""
	# Every detail is printed on the card itself, so no tooltip repeats it.
	tooltip_text = ""
	var preview_traits := owned.duplicate()
	if not preview_traits.has(data.id):
		preview_traits.append(data.id)
	if specimen != null:
		specimen.position.x = size.x / 2.0
		Anatomy.apply(specimen,Anatomy.recipe(preview_traits))
		specimen.visible = not guided_choice and not detailed
		bud.visible = not guided_choice and not detailed and preview_traits.has("fission")
	queue_redraw()

func line(value: String, at: Vector2, size_px: int, color: Color, weight: int = 0) -> void:
	var actual := roundi(size_px * text_multiplier)
	draw_string(UI.text_font(actual, weight), at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, actual, color)

func centered(value: String, y: float, size_px: int, color: Color, weight: int = 0) -> void:
	var actual := roundi(size_px * text_multiplier)
	var width := UI.text_font(actual, weight).get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, actual).x
	line(value, Vector2((size.x - width) * 0.5, y), size_px, color, weight)

## A small key cap in the corner names the number key that picks this card.
func draw_key() -> void:
	var cap := Rect2(size.x - 34, 12, 22, 22)
	draw_style_box(UI.box(Color(1, 1, 1, 0.06), 6, UI.LINE, Vector2.ZERO), cap)
	var face := UI.font(UI.SEMIBOLD)
	var width := face.get_string_size(str(number), HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	draw_string(face, Vector2(cap.get_center().x - width * 0.5, cap.position.y + 15.5), str(number), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UI.MUTED)

func draw_comparison() -> void:
	centered(data.name, 148, 20, UI.INK, UI.SEMIBOLD)
	centered(UI.sentence(comparison.playstyle), 170, 11, UI.ACCENT, UI.MEDIUM)
	var before: Dictionary = comparison.before
	var after: Dictionary = comparison.after
	var sample: Dictionary = Comparison.sample_for(data.id)
	centered("Example: %d cells · %d organisms" % [sample.loop,sample.bodies.size()],194,11,UI.MUTED)
	centered("Food %d → %d" % [before.food,after.food],216,13,UI.INK,UI.MEDIUM)
	centered("Recovery %.1fs → %.1fs" % [before.recovery,after.recovery],238,12,UI.INK)
	centered("Loop limit %d → %d cells" % [before.capacity,after.capacity],260,12,UI.INK)
	centered("Poison %d → %d" % [before.poison,after.poison] if after.poison>0 or before.poison>0 else "Short links · see Compare details",282,11,UI.MUTED)
	draw_line(Vector2(24,304),Vector2(size.x-24,304),UI.LINE,1.0)
	centered("Need %d more food" % (cost-balance) if disabled else "Evolve for %d food" % cost,330,13,UI.FAINT if disabled else UI.ACCENT,UI.MEDIUM)

## Left-aligned wrapped text; returns the baseline of the last line drawn.
## Text that would pass the footer ends with an ellipsis instead.
func paragraph(value: String, top: float, size_px: int, color: Color, weight: int = 0, limit: float = 292.0) -> float:
	var actual := roundi(size_px * text_multiplier)
	var face := UI.text_font(actual, weight)
	var width := size.x - 40.0
	var step := roundf(actual * 1.42)
	var y := top
	var text := ""
	for word in value.split(" "):
		var next: String = word if text.is_empty() else text + " " + word
		if text.is_empty() or face.get_string_size(next, HORIZONTAL_ALIGNMENT_LEFT, -1, actual).x <= width:
			text = next
			continue
		if y + step > limit:
			draw_string(face, Vector2(20, y), text + " …", HORIZONTAL_ALIGNMENT_LEFT, -1, actual, color)
			return y
		draw_string(face, Vector2(20, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, actual, color)
		y += step
		text = word
	draw_string(face, Vector2(20, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, actual, color)
	return y

## The back of the card: what the trait does, its cost, and how it combines.
func draw_details() -> void:
	var y := paragraph(data.name, 56, 17, UI.INK, UI.SEMIBOLD)
	var style: String = comparison.get("playstyle", "")
	if not style.is_empty():
		y += 20.0
		line(UI.sentence(style), Vector2(20, y), 11, UI.ACCENT, UI.MEDIUM)
	y = paragraph(data.detail.replace("\n", " "), y + 26.0, 12, UI.INK)
	line("TRADEOFF", Vector2(20, y + 26.0), 10, UI.FAINT, UI.SEMIBOLD)
	y = paragraph(data.tradeoff, y + 43.0, 12, UI.MUTED)
	var effect: String = comparison.get("effect", "")
	if not effect.is_empty() and y + 40.0 < 292.0:
		y = paragraph(effect, y + 24.0, 12, UI.ACCENT)
	var synergy: String = comparison.get("synergy", "")
	if not synergy.is_empty() and y + 40.0 < 292.0:
		paragraph(synergy, y + 24.0, 12, UI.MUTED)
	draw_line(Vector2(24, 304), Vector2(size.x - 24, 304), UI.LINE, 1.0)
	if disabled:
		centered("Need %d more food" % (cost - balance), 330, 13, UI.FAINT, UI.MEDIUM)
	else:
		centered("Evolve for %d food" % cost if cost >= 0 else "Evolve", 330, 13, UI.ACCENT, UI.SEMIBOLD)

func draw_hover() -> void:
	if hover <= 0.01:
		return
	if glow_box == null:
		glow_box = UI.box(Color.TRANSPARENT, 14, UI.ACCENT, Vector2.ZERO)
		glow_box.set_border_width_all(1)
		glow_box.shadow_size = 18
	var eased := hover * hover * (3.0 - 2.0 * hover)
	glow_box.bg_color = Color(UI.ACCENT, 0.035 * eased)
	glow_box.border_color = Color(UI.ACCENT, 0.5 * eased)
	glow_box.shadow_color = Color(UI.ACCENT, 0.10 * eased)
	draw_style_box(glow_box, Rect2(Vector2.ZERO, size))

func _draw() -> void:
	if data.is_empty():
		return
	draw_hover()
	draw_key()
	if detailed:
		draw_details()
		return
	if guided_choice:
		draw_guided(UI.INK, UI.MUTED, UI.ACCENT)
		return
	if not comparison.is_empty():
		draw_comparison()
		return
	centered(data.name, 148, 20, UI.INK, UI.SEMIBOLD)
	centered(data.summary, 174, 13, UI.ACCENT, UI.MEDIUM)
	var lines: PackedStringArray = data.detail.split("\n")
	for i in lines.size():
		centered(lines[i], 210 + i * 21, 12, UI.INK)
	# Explicit line break for the longest tradeoff keeps every card readable.
	var tradeoff: String = data.tradeoff
	if tradeoff.length() > 40:
		var split_at := tradeoff.rfind(" ", 34)
		centered(tradeoff.substr(0, split_at), 266, 12, UI.MUTED)
		centered(tradeoff.substr(split_at + 1), 283, 12, UI.MUTED)
	else:
		centered(tradeoff, 274, 12, UI.MUTED)
	draw_line(Vector2(24, 304), Vector2(size.x - 24, 304), UI.LINE, 1.0)
	if disabled:
		centered("Need %d more food" % (cost - balance), 330, 13, UI.FAINT, UI.MEDIUM)
	else:
		centered("Evolve for %d food" % cost if cost >= 0 else "Evolve", 330, 13, UI.ACCENT, UI.SEMIBOLD)

func draw_guided(ink: Color, muted: Color, cyan: Color) -> void:
	var small: bool = data.id == "fission"
	draw_demo(small, cyan)
	centered("Faster small captures" if small else "More food from large captures", 142, 21, ink, UI.SEMIBOLD)
	centered(data.name, 164, 12, muted)
	centered("3-4 blue cells per loop" if small else "6 or more blue cells per loop", 196, 14, cyan, UI.MEDIUM)
	centered("3 food becomes 4" if small else "3 food becomes 6", 224, 19, ink, UI.SEMIBOLD)
	centered("Cells return in 2s instead of 3s" if small else "Connect up to 10 cells instead of 8", 249, 13, ink)
	centered("Bonus only on food without poison." if small else "Tradeoff: every loop returns 0.6s slower.", 276, 12, muted)
	centered("No bonus on larger loops." if small else "Smaller loops get no extra food.", 294, 12, muted)
	draw_line(Vector2(24, 306), Vector2(size.x - 24, 306), UI.LINE, 1.0)
	var caption := "Choose for %d food  ·  %d left" % [cost, maxi(0, balance-cost)]
	if disabled:
		caption = "Need %d more food" % (cost-balance)
	centered(caption, 331, 13, UI.FAINT if disabled else cyan, UI.SEMIBOLD)

func draw_demo(small: bool, cyan: Color) -> void:
	var count := 3 if small else 6
	var recovery := 2.0 if small else 3.6
	var t := 1.6 if reduced_motion else fmod(demo_time, 7.5)
	var phase := clampf((t-1.6)/recovery, 0.0, 1.0)
	var merge := smoothstep(0.0, 0.27, phase) * (1.0-smoothstep(0.56, 1.0, phase))
	var center := Vector2(size.x/2.0, 56)
	var points := PackedVector2Array()
	for i in count:
		var angle := -PI/2.0 + TAU*i/count
		points.append(center+Vector2(cos(angle)*82, sin(angle)*28))
	if t <= 1.6 or reduced_motion:
		for i in count:
			var progress := clampf(t/1.6*count-i, 0.0, 1.0)
			draw_line(points[i], points[i].lerp(points[(i+1)%count], progress), Color(cyan, 0.55), 1.0, true)
	var food_alpha := 1.0-smoothstep(0.0, 0.4, phase)
	for i in 3:
		draw_texture_rect(FOOD, Rect2(center+Vector2((i-1)*19-10, -10), Vector2(20,20)), false, Color(1,1,1,food_alpha))
	for p in points:
		var position := p.lerp(center, merge)
		draw_texture_rect(CELL, Rect2(position-Vector2(14,14), Vector2(28,28)), false, Color(1,1,1,1.0-merge))
	if merge > 0.0:
		draw_texture_rect(CELL, Rect2(center-Vector2(27,27), Vector2(54,54)), false, Color(1,1,1,merge))
	var caption := "Example: follow a small loop" if small else "Example: surround more space"
	if phase > 0.0:
		caption = "+%d food  ·  %s" % [4 if small else 6, "ready again" if phase >= 1.0 else "cells recovering"]
	centered(caption, 112, 11, Color(cyan, 0.85), UI.MEDIUM)
