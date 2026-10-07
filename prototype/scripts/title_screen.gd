extends RefCounted
## Presentation only; all actions still use the existing journey/save controls.
const LOGO = preload("res://assets/branding/petriverse-title-v2.png")
const UI = preload("res://scripts/ui_style.gd")
const STACK_TOP := 536.0

func configure(hud: Node2D) -> void:
	var game = hud.game
	if game.run.state != "home" or game.home_pond_open or hud.advanced_open:
		return
	var returning: bool = not game.resume_data.is_empty()
	var y := STACK_TOP
	if returning:
		var finished: bool = game.resume_data.snapshot.run.state == "success"
		hud.place(hud.continue_button, Vector2(480, y), Vector2(320, 52), "primary", "View your completed journey" if finished else "Continue your journey", "", 16)
		hud.place(hud.new_button, Vector2(480, y + 64), Vector2(320, 40), "quiet", "Start a new journey", "", 15)
		y += 108.0
	else:
		hud.place(hud.new_button, Vector2(480, y), Vector2(320, 52), "primary", "Begin your journey", "", 16)
		y += 104.0
	var residents: int = game.journey_profile.residents.size()
	hud.place(hud.pond_button, Vector2(480, y), Vector2(320, 40), "quiet", "Visit your home pond" if residents == 0 else "Home pond  ·  %d resident%s" % [residents, "" if residents == 1 else "s"], "", 15)
	hud.place(hud.advanced_button, Vector2(480, y + 44), Vector2(320, 40), "quiet", "Advanced starting colonies", "", 15)
	var footer := [hud.help_button, hud.journal_button, hud.sound_button]
	var captions := ["How to play", "Field journal", "Settings"]
	var hints := ["H", "J", "V"]
	var widths: Array[float] = []
	var total := 0.0
	for i in footer.size():
		widths.append(hud.snug(captions[i], hints[i], 14))
		total += widths[i] + (24.0 if i > 0 else 0.0)
	var x := 640.0 - total * 0.5
	for i in footer.size():
		hud.place(footer[i], Vector2(x, 830), Vector2(widths[i], 40), "quiet", captions[i], hints[i], 14)
		x += widths[i] + 24.0

func draw(hud: Node2D) -> void:
	var game = hud.game
	var time: float = game.visual_time if not game.reduced_motion else 0.0
	# The live microscope supplies the actual water, specimens and currents.
	hud.draw_rect(Rect2(0, 0, 1280, 900), Color(0.008, 0.024, 0.032, 0.43))
	var breathing := sin(time * 0.45) * 1.5
	hud.draw_texture_rect(LOGO, Rect2(343, 58 + breathing, 594, 396), false)
	hud.centered("A small life. A whole world.", 500, 19, Color("b9d2d0"))
	if game.resume_data.is_empty():
		hud.centered("Begins with a short, playable lesson.", STACK_TOP + 76, 13, UI.FAINT)
