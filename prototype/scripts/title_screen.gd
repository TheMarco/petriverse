extends RefCounted
## Presentation only; all actions still use the existing journey/save controls.
const LOGO = preload("res://assets/branding/petriverse-title-v2.png")
const UI = preload("res://scripts/ui_style.gd")
const STACK_TOP := 536.0
## The first title of a session arrives in stages: water, logo, words, choices.
const INTRO := 2.4
var introduced := false

static func stage(age: float, from: float, length: float) -> float:
	var t := clampf((age - from) / length, 0.0, 1.0)
	return 1.0 - pow(1.0 - t, 3.0)

func intro_age(hud: Node2D) -> float:
	# Reduced motion shows the finished title at once.
	return INTRO if introduced or hud.game.reduced_motion else hud.overlay_age

func configure(hud: Node2D) -> void:
	var game = hud.game
	# These buttons also serve other screens; they take input everywhere but
	# during the title's own introduction below.
	for control in [hud.continue_button, hud.new_button, hud.pond_button, hud.advanced_button, hud.help_button, hud.journal_button, hud.experiments_button, hud.sound_button]:
		control.mouse_filter = Control.MOUSE_FILTER_STOP
		control.focus_mode = Control.FOCUS_ALL
	if game.run.state != "home" or game.home_pond_open or hud.advanced_open:
		return
	var age := intro_age(hud)
	if age >= INTRO:
		introduced = true
	var returning: bool = not game.resume_data.is_empty()
	var y := STACK_TOP
	var order: Array = []
	if returning:
		var finished: bool = game.resume_data.snapshot.run.state == "success"
		hud.place(hud.continue_button, Vector2(480, y), Vector2(320, 52), "primary", "View your completed journey" if finished else "Continue your journey", "", 16)
		hud.place(hud.new_button, Vector2(480, y + 64), Vector2(320, 40), "quiet", "Start a new journey", "", 15)
		order.append_array([hud.continue_button, hud.new_button])
		y += 108.0
	else:
		hud.place(hud.new_button, Vector2(480, y), Vector2(320, 52), "primary", "Begin your journey", "", 16)
		order.append(hud.new_button)
		y += 104.0
	var residents: int = game.journey_profile.residents.size()
	hud.place(hud.pond_button, Vector2(480, y), Vector2(320, 40), "quiet", "Visit your home pond" if residents == 0 else "Home pond  ·  %d resident%s" % [residents, "" if residents == 1 else "s"], "", 15)
	hud.place(hud.advanced_button, Vector2(480, y + 44), Vector2(320, 40), "quiet", "Advanced starting colonies", "", 15)
	order.append_array([hud.pond_button, hud.advanced_button])
	var footer := [hud.help_button, hud.journal_button, hud.experiments_button, hud.sound_button]
	var captions := ["How to play", "Field journal", "Experiments", "Settings"]
	var hints := ["H", "J", "", "V"]
	var widths: Array[float] = []
	var total := 0.0
	for i in footer.size():
		widths.append(hud.snug(captions[i], hints[i], 14))
		total += widths[i] + (24.0 if i > 0 else 0.0)
	var x := 640.0 - total * 0.5
	for i in footer.size():
		hud.place(footer[i], Vector2(x, 830), Vector2(widths[i], 40), "quiet", captions[i], hints[i], 14)
		x += widths[i] + 24.0
	# Choices settle one after another once the name has arrived.
	var fade: float = hud.entrance() if introduced else 1.0
	for i in order.size():
		order[i].modulate.a = stage(age, 1.15 + i * 0.09, 0.5) * fade
	for control in footer:
		control.modulate.a = stage(age, 1.65, 0.6) * fade
	# A choice cannot be clicked or focused before it can be seen.
	for control in order + footer:
		var shown_enough: bool = control.modulate.a >= 0.6
		control.mouse_filter = Control.MOUSE_FILTER_STOP if shown_enough else Control.MOUSE_FILTER_IGNORE
		control.focus_mode = Control.FOCUS_ALL if shown_enough else Control.FOCUS_NONE

func draw(hud: Node2D) -> void:
	var game = hud.game
	var time: float = game.visual_time if not game.reduced_motion else 0.0
	var age := intro_age(hud)
	var still: bool = game.reduced_motion
	# The live microscope supplies the actual water, specimens and currents.
	hud.canvas.draw_rect(Rect2(0, 0, 1280, 900), Color(0.008, 0.024, 0.032, 0.43 * stage(age, 0.0, 1.2)))
	var breathing := sin(time * 0.45) * 1.5
	var logo := stage(age, 0.2, 1.3)
	var rise := 0.0 if still else (1.0 - logo) * 14.0
	var grow := 1.0 if still else lerpf(0.965, 1.0, logo)
	var size := Vector2(594, 396) * grow
	var rect := Rect2(Vector2(640.0 - size.x * 0.5, 58.0 + breathing + rise + (396.0 - size.y) * 0.5), size)
	hud.canvas.draw_texture_rect(LOGO, rect, false, Color(1, 1, 1, logo))
	hud.centered("A small life. A whole world.", 500, 19, Color(Color("b9d2d0"), stage(age, 0.8, 0.7)))
	if game.resume_data.is_empty():
		hud.centered("Begins with a short, playable lesson.", STACK_TOP + 76, 13, Color(UI.FAINT, stage(age, 1.4, 0.6)))
	var profile = game.journey_profile
	if profile.victories > 0 and game.recovery_notice().is_empty():
		var record := "Best journey score %d   ·   %d journey%s completed" % [profile.best_score, profile.victories, "" if profile.victories == 1 else "s"]
		hud.centered(record, 806, 12, Color(UI.FAINT, stage(age, 1.8, 0.6)), UI.MEDIUM)
	if not game.recovery_notice().is_empty():
		hud.wrapped_centered(game.recovery_notice(), 870, 1000, 13, UI.ACCENT)
