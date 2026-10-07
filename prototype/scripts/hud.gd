extends Node2D

const UI = preload("res://scripts/ui_style.gd")
const INK := UI.INK
const MUTED := UI.MUTED
const CYAN := UI.ACCENT
const Mutations = preload("res://scripts/mutations.gd")
const Plan = preload("res://scripts/run_plan.gd")
const MutationCard = preload("res://scripts/mutation_card.gd")
const SETTINGS := Rect2(350, 130, 580, 640)
var game: Node2D
var font: Font = UI.font(UI.REGULAR)
var pause_button: Button
var restart_button: Button
var debug_button: Button
var mode_button: Button
var motion_button: Button
var center_button: Button
var sound_button: Button
var sound_close: Button
var mute_button: Button
var music_slider: HSlider
var effects_slider: HSlider
var cards: Array[Button] = []
var comfort_motion_button: Button
var contrast_button: Button
var text_button: Button
var quality_button: Button

## Native buttons with an optional keyboard hint and a drawn pause glyph.
class HudButton extends Button:
	var hint := ""
	var glyph := ""
	func _draw() -> void:
		var ink: Color = get_theme_color("font_disabled_color" if disabled else "font_color")
		if glyph == "pause":
			var middle := size / 2.0
			for x in [-5.5, 1.5]:
				draw_rect(Rect2(middle + Vector2(x, -7.0), Vector2(4.0, 14.0)), ink)
		if hint.is_empty():
			return
		var hint_font: Font = UI.font(UI.MEDIUM)
		var hint_width := hint_font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		var label_width: float = get_theme_font("font").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, get_theme_font_size("font_size")).x
		# Centered captions keep the hint only where both fit without touching.
		if alignment == HORIZONTAL_ALIGNMENT_CENTER and (size.x + label_width) * 0.5 + 14.0 > size.x - 16.0 - hint_width:
			return
		draw_string(hint_font, Vector2(size.x - 16.0 - hint_width, size.y * 0.5 + 4.5), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(ink, 0.55))

func _ready() -> void:
	game = get_parent()
	pause_button = button("Pause  ·  Space", Vector2(1080, 620), Vector2(164, 40), game.pause)
	restart_button = button("Restart  ·  R", Vector2(1080, 670), Vector2(164, 40), game.restart)
	mode_button = button("Input: drag  ·  C", Vector2(36, 674), Vector2(170, 38), game.toggle_mode)
	motion_button = button("Motion: full  ·  M", Vector2(36, 721), Vector2(170, 38), game.toggle_motion)
	debug_button = button("Inspect dish  ·  D", Vector2(1080, 721), Vector2(164, 38), game.toggle_debug)
	center_button = button("Resume", Vector2(536, 510), Vector2(208, 48), game.overlay_action)
	UI.style_button(center_button, "primary", 15)
	center_button.visible = false
	sound_button = button("Settings  ·  V", Vector2(36, 767), Vector2(170, 38), game.toggle_sound_settings)
	sound_close = button("Done", Vector2(540, 698), Vector2(200, 44), game.toggle_sound_settings)
	UI.style_button(sound_close, "primary", 15)
	mute_button = button("On", Vector2(690, 0), Vector2(200, 38), game.soundscape.toggle_mute)
	quality_button = button("Full", Vector2(690, 0), Vector2(200, 38), game.toggle_quality)
	comfort_motion_button = button("Full", Vector2(690, 0), Vector2(200, 38), game.toggle_motion)
	contrast_button = button("Soft", Vector2(690, 0), Vector2(200, 38), game.toggle_contrast)
	text_button = button("Standard", Vector2(690, 0), Vector2(200, 38), game.toggle_text)
	music_slider = volume_slider(Vector2(560, 0), game.soundscape.music_volume, game.soundscape.set_music_volume)
	effects_slider = volume_slider(Vector2(560, 0), game.soundscape.effects_volume, game.soundscape.set_effects_volume)
	for i in 3:
		var card := MutationCard.new()
		card.position = Vector2(245 + i * 270, 325)
		card.size = Vector2(250, 346)
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		card.focus_mode = Control.FOCUS_ALL
		card.theme = UI.theme()
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			var style := UI.box(Color(1, 1, 1, 0.03) if state != "hover" else Color(1, 1, 1, 0.06), 14, UI.LINE if state in ["normal", "disabled"] else UI.LINE_STRONG)
			if state == "focus":
				style.draw_center = false
				style.border_color = Color(CYAN, 0.7)
			card.add_theme_stylebox_override(state, style)
		card.pressed.connect(game.choose_evolution.bind(i))
		add_child(card)
		cards.append(card)
	refresh()

func volume_slider(at: Vector2, value: float, action: Callable) -> HSlider:
	var slider := HSlider.new()
	slider.position = at
	slider.size = Vector2(250, 26)
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = value
	slider.focus_mode = Control.FOCUS_NONE
	slider.value_changed.connect(action)
	slider.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	UI.style_slider(slider)
	add_child(slider)
	return slider

func button(caption: String, at: Vector2, dimensions: Vector2, action: Callable, hint: String = "") -> Button:
	var result := HudButton.new()
	result.text = caption
	result.hint = hint
	result.position = at
	result.size = dimensions
	result.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	result.focus_mode = Control.FOCUS_NONE
	result.theme = UI.theme()
	UI.style_button(result, "secondary", 15)
	result.pressed.connect(action)
	add_child(result)
	return result

## One call places a control for the current screen: geometry, look and copy.
func place(control: Button, at: Vector2, dimensions: Vector2, variant: String, caption: String = "", hint: String = "", size_px: int = 15) -> void:
	# Copy and style first: a Button clamps its size to the old caption's width.
	if not caption.is_empty():
		control.text = caption
	UI.style_button(control, variant, size_px)
	if control is HudButton:
		control.set("hint", hint)
		control.queue_redraw()
	control.size = dimensions
	control.position = at

## Width that keeps a centered caption and its key hint close together.
func snug(caption: String, hint: String = "", size_px: int = 14) -> float:
	var text_width := UI.font(UI.MEDIUM).get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	if hint.is_empty():
		return ceilf(text_width + 40.0)
	var hint_width := UI.font(UI.MEDIUM).get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	return ceilf(text_width + 2.0 * (hint_width + 30.0))

func refresh() -> void:
	pause_button.text = "Resume  ·  Space" if game.run.state == "paused" else "Pause  ·  Space"
	pause_button.disabled = game.run.state in ["success", "loss", "evolve"]
	mode_button.text = "Input: clicks  ·  C" if game.click_mode else "Input: drag  ·  C"
	motion_button.text = "Motion: low  ·  M" if game.reduced_motion else "Motion: full  ·  M"
	debug_button.text = "Hide inspect  ·  D" if game.debug_mode else "Inspect dish  ·  D"
	center_button.visible = overlay_visible() and not game.settings_open and game.run.state != "evolve"
	center_button.text = "Resume encounter" if game.run.state == "paused" else "Grow again  ·  R"
	refresh_settings()
	if not game.settings_open:
		place(mode_button, Vector2(36, 674), Vector2(170, 38), "secondary", "Input: clicks  ·  C" if game.click_mode else "Input: drag  ·  C")
	for i in cards.size():
		cards[i].visible = game.run.evolution_ready() and not game.settings_open
		if cards[i].visible:
			cards[i].text_multiplier = 1.08 if game.large_text else 1.0
			cards[i].configure(Mutations.definition(game.run.offered_mutations[i]), i, game.run.mutations)
	queue_redraw()

const SETTING_ROWS := ["Music", "Living sounds", "All sound", "Input", "Motion", "Markers", "Text size", "Visual detail"]
const SETTING_KEYS := ["", "", "", "C", "M", "", "", ""]

func setting_row(index: int) -> float:
	return SETTINGS.position.y + 132.0 + index * 54.0

## Every comfort option lives in one dialog; gameplay screens stay uncluttered.
func refresh_settings() -> void:
	var open: bool = game.settings_open
	for control in [sound_close, mute_button, music_slider, effects_slider, comfort_motion_button, contrast_button, text_button, quality_button]:
		control.visible = open
	if not open:
		return
	mode_button.visible = true
	var right := SETTINGS.end.x - 40.0
	for slider in [music_slider, effects_slider]:
		slider.position = Vector2(right - 312.0, setting_row(0 if slider == music_slider else 1) - 13.0)
	var toggles := [mute_button, mode_button, comfort_motion_button, contrast_button, text_button, quality_button]
	var values := ["Muted" if game.soundscape.muted else "On", "Clicks" if game.click_mode else "Drag", "Reduced" if game.reduced_motion else "Full", "High contrast" if game.high_contrast else "Soft", "Larger" if game.large_text else "Standard", ["Light", "Balanced", "Full"][game.visual_quality]]
	for i in toggles.size():
		place(toggles[i], Vector2(right - 200.0, setting_row(i + 2) - 19.0), Vector2(200, 38), "secondary", values[i], "", 14)
	place(sound_close, Vector2(SETTINGS.get_center().x - 100.0, SETTINGS.end.y - 76.0), Vector2(200, 44), "primary", "Done", "Esc", 15)

func overlay_visible() -> bool:
	# Results must not cover the very bite that ended the encounter. Simulation
	# is already stopped; the persistent side Restart control remains available.
	if game.run.state == "evolve":
		return game.run.evolution_ready()
	if (game.run.full_run or game.run.harvest != null) and game.run.state == "success" and not game.run.clots.is_empty():
		return false
	return game.run.state != "active" and not (game.run.state in ["loss", "success"] and game.run.mother_damage.active())

func scaled(size_px: int, always: bool = false) -> int:
	return roundi(size_px * 1.12) if game.large_text and (always or size_px <= 17) else size_px

func measure(value: String, size_px: int, weight: int = 0) -> float:
	var actual := scaled(size_px)
	return UI.text_font(actual, weight).get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, actual).x

func label_at(value: String, at: Vector2, size_px: int = 16, color: Color = INK, weight: int = 0) -> void:
	var actual := scaled(size_px)
	draw_string(UI.text_font(actual, weight), at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, actual, color)

func right_at(value: String, at: Vector2, size_px: int = 16, color: Color = INK, weight: int = 0) -> void:
	label_at(value, Vector2(at.x - measure(value, size_px, weight), at.y), size_px, color, weight)

func centered(value: String, y: float, size_px: int, color: Color = INK, weight: int = 0, middle: float = 640.0) -> void:
	label_at(value, Vector2(middle - measure(value, size_px, weight) * 0.5, y), size_px, color, weight)

func lines_for(value: String, width: float, actual: int, weight: int) -> PackedStringArray:
	var face := UI.text_font(actual, weight)
	var result := PackedStringArray()
	var text := ""
	for word in value.split(" "):
		var next: String = word if text.is_empty() else text + " " + word
		if not text.is_empty() and face.get_string_size(next, HORIZONTAL_ALIGNMENT_LEFT, -1, actual).x > width:
			result.append(text)
			text = word
		else:
			text = next
		# Names may contain no spaces. Keep even a long single word inside its
		# column instead of drawing into the dish or beyond the window.
		while face.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, actual).x > width:
			var cut := text.length()-1
			while cut>1 and face.get_string_size(text.substr(0,cut),HORIZONTAL_ALIGNMENT_LEFT,-1,actual).x>width:
				cut -= 1
			result.append(text.substr(0,cut))
			text = text.substr(cut)
	result.append(text)
	return result

func line_step(actual: int) -> float:
	return roundf(actual * 1.45)

## Draws wrapped text and returns the baseline of its last line.
func wrapped(value: String, at: Vector2, width: float, size_px: int = 14, color: Color = CYAN, weight: int = 0) -> float:
	var actual := scaled(size_px, true)
	var lines := lines_for(value, width, actual, weight)
	var y := at.y
	for i in lines.size():
		draw_string(UI.text_font(actual, weight), Vector2(at.x, y), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, actual, color)
		if i < lines.size() - 1:
			y += line_step(actual)
	return y

func wrapped_centered(value: String, y: float, width: float, size_px: int = 14, color: Color = MUTED, weight: int = 0, middle: float = 640.0) -> float:
	var actual := scaled(size_px, true)
	var face := UI.text_font(actual, weight)
	var lines := lines_for(value, width, actual, weight)
	for i in lines.size():
		var line_width := face.get_string_size(lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, actual).x
		draw_string(face, Vector2(middle - line_width * 0.5, y), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, actual, color)
		if i < lines.size() - 1:
			y += line_step(actual)
	return y

func dialog(rect: Rect2) -> void:
	draw_style_box(UI.dialog_box(), rect)

func scrim() -> void:
	draw_rect(Rect2(0, 0, 1280, 900), UI.SCRIM)

func _draw() -> void:
	if game == null:
		return
	if game.run.harvest != null:
		draw_harvest()
		return
	var run = game.run
	label_at("M I C R O V E R S E", Vector2(36, 54), 22)
	label_at("ENCLOSE. ABSORB. EVOLVE.", Vector2(37, 80), 11, MUTED)
	label_at("01 / STILLWATER", Vector2(1080, 52), 14, CYAN)
	label_at(Plan.TITLES[run.stage_index] if run.full_run else "Enclosure study", Vector2(1080, 75), 13, MUTED)
	draw_line(Vector2(36, 134), Vector2(204, 134), Color("294148"), 1.0)
	label_at("MOTHER INTEGRITY", Vector2(36, 168), 12, MUTED)
	for i in 5:
		var box := Rect2(36 + i * 33, 184, 25, 8)
		draw_rect(box, CYAN if i < run.integrity else Color("26393e"))
		if i >= run.integrity:
			draw_line(box.position, box.end, MUTED, 1.0)
	label_at("%d / 5" % run.integrity, Vector2(36, 218), 14)
	if not run.critical_nuclei().is_empty():
		label_at("MOTHER UNDER THREAT", Vector2(36, 245), 12, Color("edb184"))
	label_at("ABSORPTION SCORE", Vector2(36, 277), 12, MUTED)
	label_at("%04d" % run.score, Vector2(33, 325), 43)
	label_at("BEST  %04d" % game.records.best_score, Vector2(36, 349), 13, MUTED)
	label_at("PROTECT THE MOTHER", Vector2(36, 432), 12, CYAN)
	var instructions := ["Start on a pale cell.", "Connect ready cells.", "Close at the first cell.", "Release to absorb."]
	if game.click_mode:
		instructions = ["Click a pale cell.", "Click ready cells.", "Click the first to close.", "Press Enter to absorb."]
	for i in instructions.size():
		label_at(instructions[i], Vector2(36, 462 + 26 * i), 14)
	label_at("3-%d cells per membrane" % run.selection.max_vertices, Vector2(36, 585), 13, MUTED)
	label_at("Base return · %.1fs" % run.board.tuning.recovery_seconds, Vector2(36, 608), 13, MUTED)
	label_at("Selected cells stay still.", Vector2(36, 632), 11, MUTED)
	var predator = run.boss()
	label_at("TWO HEARTS / ONE BODY" if run.stage_index == 3 else ("ENCOUNTER %d / 3" % (run.stage_index + 1) if run.full_run else "ENCOUNTER"), Vector2(1080, 167), 11, MUTED)
	label_at("%d / 3" % (predator.health if predator != null else 0) if run.stage_index == 3 else "%02d / %02d" % [run.encounter.resolved, run.encounter.budget], Vector2(1078, 207), 30)
	label_at("Protection layers" if run.stage_index == 3 else "Organisms resolved", Vector2(1080, 234), 13, MUTED)
	draw_rect(Rect2(1080, 251, 164, 3), Color("263d43"))
	var growth: float = 1.0 - predator.health / 3.0 if predator != null else float(run.encounter.resolved) / maxf(1.0, run.encounter.budget)
	draw_rect(Rect2(1080, 251, 164.0 * growth, 3), CYAN)
	label_at("%d in the dish" % run.enemies.size(), Vector2(1080, 282), 14)
	if predator != null:
		label_at("Enclose both hearts" if predator.can_take_pulse() else "Reforming · guard mother", Vector2(1080, 305), 12, MUTED)
	else:
		label_at("%d still approaching" % (run.encounter.budget - run.encounter.spawned), Vector2(1080, 305), 13, MUTED)
	if run.selection.active:
		var preview: Array = run.preview()
		label_at("MEMBRANE", Vector2(1080, 393), 12, CYAN)
		label_at("%d / %d cells" % [run.selection.path.size(), run.selection.max_vertices], Vector2(1080, 422), 22)
		if run.selection.can_close():
			var armor := 0
			for enemy in run.enemies:
				if preview.has(enemy.id) and enemy.kind == "shellback" and enemy.health > Mutations.damage(run.mutations, run.selection.path.size()):
					armor += 1
			label_at("%d within reach" % preview.size(), Vector2(1080, 457), 15)
			if armor > 0:
				label_at("%d shell%s will crack" % [armor, "s" if armor > 1 else ""], Vector2(1080, 482), 12, Color("e7bc86"))
			if preview.is_empty():
				var warning: String = run.preview_warning()
				label_at(warning if not warning.is_empty() else "Empty · still costs cells", Vector2(1080, 482), 12, Color("e7bc86"))
			label_at("Closed · release" if run.selection.closed and not game.click_mode else ("Closed · press Enter" if run.selection.closed else "Return to the first cell"), Vector2(1080, 513), 13, CYAN)
		else:
			label_at("Connect any ready cells", Vector2(1080, 457), 13, MUTED)
	elif game.toast_time > 0.0:
		wrapped(game.toast, Vector2(1080, 421), 164.0, 14, CYAN)
	if game.debug_mode:
		label_at("READY TRIANGLES  %d" % run.board.available_triangles(run.is_ready), Vector2(1080, 551), 11, CYAN)
		label_at("Last contacts: %s" % str(run.last_contacts), Vector2(1080, 574), 11, MUTED)
	centered(Plan.LESSONS[run.stage_index] if run.full_run and run.elapsed > 12.0 else "CONNECT CELLS. CLOSE A LOOP. PROTECT THE MOTHER.", 873, 13, CYAN)
	for i in run.mutations.size():
		var item := Mutations.definition(run.mutations[i])
		var x: float = 480.0 + i * 160.0
		label_at(item.name, Vector2(x - 65.0, 830), 12, CYAN)
	label_at("Right-click / Esc: cancel", Vector2(36, 818), 12, MUTED)
	label_at("Backtrack: previous cell", Vector2(36, 840), 12, MUTED)
	label_at("ONE DISH / THREE EVOLUTIONS" if run.full_run else "ONE DISH / 20 DRIFTERS", Vector2(1063, 840), 10, MUTED)
	if game.settings_open:
		draw_sound_settings()
	elif run.evolution_ready():
		scrim()
		dialog(Rect2(225, 208, 830, 498))
		centered("Evolution %s of III" % ["I", "II", "III"][run.stage_index], 252, 13, CYAN)
		centered("How will the colony grow?", 288, 30)
		centered("Choose one mutation. Take your time; the dish is still.", 314, 14, MUTED)
	elif overlay_visible():
		scrim()
		dialog(Rect2(235, 270, 810, 332))
		var title: String = {"paused": "A moment of stillness.", "success": "The colony endures.", "loss": "A fragile balance."}[run.state]
		centered(title, 369, 36)
		var subtitle: String = {"paused": "The dish is paused. Your cells can wait.", "success": "The Conjoined dissolves. Your colony has found its balance." if run.full_run else "All 20 Drifters resolved. The mother survives.", "loss": "The mother has lost its integrity. Begin a new colony."}[run.state]
		centered(subtitle, 410, 17, MUTED)
		centered("Score %04d   ·   Absorbed %d   ·   Integrity %d" % [run.score, run.kills, run.integrity], 460, 14, CYAN)
		if run.state != "paused":
			centered("%s   ·   Best capture %d   ·   %d:%02d" % ["New personal best" if game.records.new_record else "Best %04d" % game.records.best_score, run.best_capture, floori(run.elapsed / 60.0), int(run.elapsed) % 60], 490, 12, MUTED)

func draw_sound_settings() -> void:
	scrim()
	dialog(SETTINGS)
	centered("Settings", SETTINGS.position.y + 64.0, 28)
	centered("Changes save automatically.", SETTINGS.position.y + 92.0, 13, MUTED)
	var left := SETTINGS.position.x + 40.0
	var right := SETTINGS.end.x - 40.0
	for i in SETTING_ROWS.size():
		var y := setting_row(i)
		if i in [2, 3]:
			draw_line(Vector2(left, y - 30.0), Vector2(right, y - 30.0), UI.LINE, 1.0)
		label_at(SETTING_ROWS[i], Vector2(left, y + 5.0), 15, INK)
		if not SETTING_KEYS[i].is_empty():
			label_at(SETTING_KEYS[i], Vector2(left + measure(SETTING_ROWS[i], 15) + 10.0, y + 5.0), 12, UI.FAINT, UI.MEDIUM)
	right_at("%d%%" % roundi(game.soundscape.music_volume * 100.0), Vector2(right, setting_row(0) + 5.0), 13, MUTED)
	right_at("%d%%" % roundi(game.soundscape.effects_volume * 100.0), Vector2(right, setting_row(1) + 5.0), 13, MUTED)

func draw_harvest() -> void:
	var run = game.run
	var harvest = run.harvest
	var green := Color("c0e6a3")
	var poison := Color("efa8c5")
	label_at("M I C R O V E R S E", Vector2(36, 54), 22)
	label_at("A LIVING DISH / RISKY HARVEST", Vector2(37, 80), 11, MUTED)
	label_at("STILLWATER", Vector2(1080, 52), 14, CYAN)
	label_at("Feed in %d:%02d" % [int(harvest.DURATION) / 60, int(harvest.DURATION) % 60], Vector2(1080, 75), 13, MUTED)
	draw_line(Vector2(36, 134), Vector2(204, 134), Color("294148"), 1.0)
	label_at("MOTHER INTEGRITY", Vector2(36, 168), 12, MUTED)
	for i in 5:
		var box := Rect2(36 + i * 33, 184, 25, 8)
		draw_rect(box, CYAN if i < run.integrity else Color("26393e"))
		if i >= run.integrity:
			draw_line(box.position, box.end, MUTED, 1.0)
	label_at("%d / 5 organelles" % run.integrity, Vector2(36, 218), 14)
	if not run.critical_nuclei().is_empty():
		label_at("MOTHER UNDER THREAT", Vector2(36, 245), 12, poison)
	label_at("NOURISH THE MOTHER", Vector2(36, 277), 12, green)
	label_at("%02d" % harvest.nourishment, Vector2(33, 325), 43, green)
	label_at("/ %d" % harvest.GOAL, Vector2(95, 323), 24, MUTED)
	draw_rect(Rect2(36, 349, 164, 4), Color("263d43"))
	draw_rect(Rect2(36, 349, 164.0 * harvest.nourishment / harvest.GOAL, 4), green)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var textures := [game.microscope.FOOD, game.microscope.CYST, game.microscope.DRIFTER]
	var names := ["Desmid · +1 food", "Cyst · −1 organelle", "Drifter · defend"]
	var colors := [green, poison, CYAN]
	for i in 3:
		var y := 398.0 + i * 51.0
		draw_texture_rect(textures[i], Rect2(30, y - 29, 43, 43), false)
		label_at(names[i], Vector2(78, y), 12, colors[i])
	label_at("DRAW A MEMBRANE", Vector2(36, 550), 12, CYAN)
	label_at("Start on a pale cell.", Vector2(36, 576), 13)
	label_at("Connect ready cells.", Vector2(36, 601), 13)
	label_at("Close, then Enter." if game.click_mode else "Close, then release.", Vector2(36, 626), 13)
	label_at("TIME TO FEED", Vector2(1080, 167), 12, MUTED)
	var remaining := maxi(0, ceili(harvest.DURATION - run.elapsed))
	label_at("%d:%02d" % [remaining / 60, remaining % 60], Vector2(1078, 207), 38, poison if remaining <= 15 else INK)
	label_at("%d food still needed" % (harvest.GOAL - harvest.nourishment), Vector2(1080, 238), 13, green)
	wrapped("Green lobed cells feed. Spiked cysts poison. Enclose their centers.", Vector2(1080, 283), 164, 13, MUTED)
	if run.selection.active:
		label_at("THIS MEMBRANE", Vector2(1080, 393), 12, CYAN)
		label_at("%d / 8 cells" % run.selection.path.size(), Vector2(1080, 422), 22)
		if run.selection.can_close():
			var outcome: Dictionary = run.harvest_preview()
			label_at("+%d nourishment" % outcome.food, Vector2(1080, 457), 15, green)
			label_at("−%d organelle%s" % [outcome.poison, "s" if outcome.poison != 1 else ""] if outcome.poison > 0 else "No poison enclosed", Vector2(1080, 482), 13, poison if outcome.poison > 0 else MUTED)
			var hint := "Return to the first cell"
			if run.selection.closed:
				hint = "Enter to harvest" if game.click_mode else "Release to harvest"
			if outcome.poison >= run.integrity:
				hint = "LETHAL · reshape the loop"
			elif harvest.nourishment + outcome.food >= harvest.GOAL:
				hint = "Enough food to win"
			elif outcome.threats > 0:
				hint = "%d invader%s absorbed" % [outcome.threats, "s" if outcome.threats != 1 else ""]
			wrapped(hint, Vector2(1080, 513), 164, 13, poison if outcome.poison >= run.integrity else CYAN)
		else:
			wrapped("Connect any ready cells.", Vector2(1080, 457), 164, 13, MUTED)
	elif game.toast_time > 0.0:
		wrapped(game.toast, Vector2(1080, 421), 164, 14, green)
	else:
		wrapped("A small safe meal, or a bigger risky feast?", Vector2(1080, 421), 164, 15, CYAN)
	if game.debug_mode:
		label_at("READY TRIANGLES  %d" % run.board.available_triangles(run.is_ready), Vector2(1080, 565), 11, CYAN)
	label_at("Right-click / Esc: cancel", Vector2(36, 818), 12, MUTED)
	label_at("Backtrack: previous cell", Vector2(36, 840), 12, MUTED)
	label_at("3-8 CELLS / 3s TO RETURN", Vector2(1063, 840), 10, MUTED)
	centered("LET THE CURRENT OPEN A GAP. CHOOSE WHAT YOU SWALLOW.", 873, 13, CYAN)
	if game.settings_open:
		draw_sound_settings()
	elif overlay_visible():
		scrim()
		dialog(Rect2(235, 270, 810, 332))
		var title: String = {"paused": "A moment of stillness.", "success": "The mother is nourished.", "loss": harvest.loss_title}[run.state]
		centered(title, 369, 36)
		var subtitle: String = "The dish is paused. Your cells can wait."
		if run.state == "success":
			subtitle = "A full meal, and a living colony."
		elif run.state == "loss":
			subtitle = harvest.loss_reason
		centered(subtitle, 410, 17, MUTED)
		centered("Nourishment %d / %d   ·   Organelles %d / 5" % [harvest.nourishment, harvest.GOAL, run.integrity], 460, 14, green)
		if run.state != "paused":
			centered("Largest meal %d   ·   Cysts swallowed %d   ·   %.1fs" % [run.best_capture, harvest.poison_taken, run.elapsed], 490, 12, MUTED)
