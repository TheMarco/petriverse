extends ColorRect
## Presentation only: the final optical pass over the dish, below the interface.
## Light detail disables it; Balanced keeps the rim optics without glow.
const SHADER = preload("res://shaders/lens_optics.gdshader")
const DIALOG_DEFOCUS := 0.55
const TITLE_DEFOCUS := 0.32
var game: Node2D
var defocus := 1.0
var clock := 0.0
var saturation := 1.0
var exposure := 1.0
## The screen copy this pass reads; hidden with the pass so Light skips it.
var backbuffer: BackBufferCopy

func _ready() -> void:
	game = get_parent()
	size = Vector2(1280, 900)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 8
	material = ShaderMaterial.new()
	material.shader = SHADER

func target_defocus() -> float:
	var run = game.run
	if game.settings_open or game.journal_open or game.help_open or game.comparisons_open:
		return DIALOG_DEFOCUS
	if run.state == "home":
		return 0.0 if game.home_pond_open else TITLE_DEFOCUS
	if game.round_result_showing():
		return 0.0
	if run.state in ["brief", "paused", "loss", "evolve"] or (run.state == "success" and game.hud.overlay_visible()):
		return DIALOG_DEFOCUS if run.state != "success" else 0.0
	return 0.0

func sync(delta: float) -> void:
	visible = game.visual_quality > 0
	if backbuffer != null:
		backbuffer.visible = visible
	if not visible:
		return
	clock += delta
	var target := target_defocus()
	# A focus pull, never a cut. Reduced motion settles almost at once.
	var rate := 18.0 if game.reduced_motion else (2.2 if target < defocus else 5.0)
	# A zero step (direct refresh in fixtures and captures) shows the settled view.
	defocus = lerpf(defocus, target, 1.0 - exp(-delta * rate)) if delta > 0.0 else target
	var run = game.run
	var title: bool = run.state == "home" and not game.home_pond_open
	var scale_factor: float = 2.15 if title else game.dish_scale()
	var center: Vector2 = run.board.center if title else run.board.center * scale_factor + game.view_offset()
	var window := Vector2(get_window().size) if is_inside_tree() else Vector2(1280, 900)
	var logical := minf(window.x / 1280.0, window.y / 900.0)
	var mat: ShaderMaterial = material
	mat.set_shader_parameter("lens_center", center)
	mat.set_shader_parameter("lens_radius", 392.0 * scale_factor)
	mat.set_shader_parameter("uv_per_logical", Vector2(logical / window.x, logical / window.y))
	mat.set_shader_parameter("lod_bias", log(maxf(logical, 1.0)) / log(2.0))
	mat.set_shader_parameter("defocus", defocus)
	mat.set_shader_parameter("clock", clock if not game.reduced_motion else 0.0)
	var full: bool = game.visual_quality >= 2
	# High contrast keeps edges crisp: no glow, grain or color fringing.
	var crisp: bool = game.high_contrast
	mat.set_shader_parameter("bloom", 1.0 if full and not crisp else 0.0)
	mat.set_shader_parameter("grain", 1.0 if full and not crisp else 0.0)
	# Outcome grading: a loss drains the dish, a win lifts it for a moment.
	var drain := 0.0
	var lift := 0.0
	if run.journey and run.state == "loss":
		drain = 1.0
	elif run.journey and run.state in ["evolve", "success"] and game.round_result_showing():
		lift = 1.0
	saturation = lerpf(saturation, 1.0 - drain * 0.72, 1.0 - exp(-delta * 1.6)) if delta > 0.0 else 1.0 - drain * 0.72
	exposure = lerpf(exposure, 1.0 - drain * 0.16 + lift * 0.07, 1.0 - exp(-delta * 2.0)) if delta > 0.0 else 1.0 - drain * 0.16
	mat.set_shader_parameter("saturation", saturation)
	mat.set_shader_parameter("exposure", exposure)
	mat.set_shader_parameter("aberration", 0.0 if crisp else 1.0)
	mat.set_shader_parameter("softness", 0.0 if crisp else 1.0)
