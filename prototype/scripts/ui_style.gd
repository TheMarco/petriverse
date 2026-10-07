extends RefCounted
## One visual language for every interface surface: type, color and controls.
## Presentation only. Nothing here reads or changes game rules.
const FONT_FILE = preload("res://assets/fonts/Inter-Variable.ttf")

const INK := Color("e6f0ec")
const MUTED := Color("8fa8a9")
const FAINT := Color("62797c")
const ACCENT := Color("a1ddd5")
const FOOD := Color("c0e6a3")
const DANGER := Color("efa8c5")
const WARM := Color("e9bf8f")
const ON_ACCENT := Color("06171c")
const SURFACE := Color(0.027, 0.063, 0.077, 0.96)
const RAISED := Color(0.047, 0.098, 0.114, 1.0)
const LINE := Color(0.63, 0.87, 0.84, 0.12)
const LINE_STRONG := Color(0.63, 0.87, 0.84, 0.3)
const SCRIM := Color(0.004, 0.012, 0.016, 0.6)

const REGULAR := 420
const MEDIUM := 520
const SEMIBOLD := 620

static var fonts := {}
static var boxes := {}
static var shared_theme: Theme

## Inter's optical size axis tightens large headings; body text keeps opsz 14.
static func font(weight: int = REGULAR, display: bool = false) -> Font:
	var key := weight * 2 + (1 if display else 0)
	if not fonts.has(key):
		var server := TextServerManager.get_primary_interface()
		var variation := FontVariation.new()
		variation.base_font = FONT_FILE
		variation.variation_opentype = {server.name_to_tag("wght"): weight, server.name_to_tag("opsz"): 32 if display else 14}
		fonts[key] = variation
	return fonts[key]

static func text_font(size_px: int, weight: int = 0) -> Font:
	if weight <= 0:
		weight = SEMIBOLD if size_px >= 18 else REGULAR
	return font(weight, size_px >= 24)

static func box(color: Color, radius: int, border: Color = Color.TRANSPARENT, margin := Vector2(16, 8)) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.corner_detail = 6
	style.anti_aliasing = true
	if border.a > 0.0:
		style.border_color = border
		style.set_border_width_all(1)
	style.content_margin_left = margin.x
	style.content_margin_right = margin.x
	style.content_margin_top = margin.y
	style.content_margin_bottom = margin.y
	return style

static func dialog_box() -> StyleBoxFlat:
	if not boxes.has("dialog"):
		var style := box(SURFACE, 18, LINE)
		style.shadow_color = Color(0, 0, 0, 0.32)
		style.shadow_size = 28
		style.shadow_offset = Vector2(0, 8)
		boxes.dialog = style
	return boxes.dialog

static func card_box(highlight: bool = false) -> StyleBoxFlat:
	var key := "card_hi" if highlight else "card"
	if not boxes.has(key):
		boxes[key] = box(Color(1, 1, 1, 0.035 if highlight else 0.025), 12, LINE_STRONG if highlight else LINE)
	return boxes[key]

static func toast_box() -> StyleBoxFlat:
	if not boxes.has("toast"):
		var style := box(Color(0.027, 0.063, 0.077, 0.92), 12, LINE)
		style.shadow_color = Color(0, 0, 0, 0.25)
		style.shadow_size = 12
		boxes.toast = style
	return boxes.toast

## Button variants: primary (the one action that moves you on), secondary,
## quiet (text-only menu items), menu (full-width rows) and icon (square).
static func style_button(control: Button, variant: String = "secondary", size_px: int = 15) -> void:
	if control.get_meta("variant", "") == variant + str(size_px):
		return
	control.set_meta("variant", variant + str(size_px))
	var radius := 10
	var fill := {"normal": Color(0.058, 0.11, 0.125, 0.94), "hover": Color(0.09, 0.15, 0.166, 0.96), "pressed": Color(0.04, 0.085, 0.1, 0.94), "disabled": Color(0.04, 0.075, 0.088, 0.7)}
	var edge := {"normal": LINE, "hover": LINE_STRONG, "pressed": LINE, "disabled": Color(LINE, 0.06)}
	var ink := {"normal": INK, "hover": Color.WHITE, "pressed": MUTED, "disabled": FAINT}
	var weight := MEDIUM
	match variant:
		"primary":
			fill = {"normal": ACCENT, "hover": Color("c3ece6"), "pressed": Color("86c4bc"), "disabled": Color(ACCENT, 0.25)}
			edge = {"normal": Color.TRANSPARENT, "hover": Color.TRANSPARENT, "pressed": Color.TRANSPARENT, "disabled": Color.TRANSPARENT}
			ink = {"normal": ON_ACCENT, "hover": ON_ACCENT, "pressed": ON_ACCENT, "disabled": Color(ON_ACCENT, 0.6)}
			weight = SEMIBOLD
		"quiet", "menu":
			fill = {"normal": Color(1, 1, 1, 0.0), "hover": Color(1, 1, 1, 0.06), "pressed": Color(1, 1, 1, 0.03), "disabled": Color(1, 1, 1, 0.0)}
			edge = {"normal": Color.TRANSPARENT, "hover": Color.TRANSPARENT, "pressed": Color.TRANSPARENT, "disabled": Color.TRANSPARENT}
			ink = {"normal": INK if variant == "menu" else Color("c3d6d3"), "hover": Color.WHITE, "pressed": MUTED, "disabled": FAINT}
		"icon":
			radius = 12
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var key: String = state if state != "focus" else "hover"
		var style := box(fill[key], radius, edge[key], Vector2(18 if variant == "menu" else 14, 6))
		if state == "focus":
			style.draw_center = false
			style.border_color = Color(ACCENT, 0.7)
			style.set_border_width_all(1)
		control.add_theme_stylebox_override(state, style)
	control.add_theme_font_override("font", font(weight))
	control.add_theme_font_size_override("font_size", size_px)
	control.add_theme_color_override("font_color", ink.normal)
	control.add_theme_color_override("font_hover_color", ink.hover)
	control.add_theme_color_override("font_focus_color", ink.normal)
	control.add_theme_color_override("font_hover_pressed_color", ink.pressed)
	control.add_theme_color_override("font_pressed_color", ink.pressed)
	control.add_theme_color_override("font_disabled_color", ink.disabled)
	control.alignment = HORIZONTAL_ALIGNMENT_LEFT if variant == "menu" else HORIZONTAL_ALIGNMENT_CENTER

static func dot_texture(diameter: int, color: Color, ring: Color = Color.TRANSPARENT) -> ImageTexture:
	var image := Image.create_empty(diameter, diameter, false, Image.FORMAT_RGBA8)
	var radius := diameter / 2.0
	for y in diameter:
		for x in diameter:
			var distance := Vector2(x + 0.5 - radius, y + 0.5 - radius).length()
			var coverage := clampf(radius - distance, 0.0, 1.0)
			var tint := color if ring.a <= 0.0 or distance < radius - 2.0 else ring
			image.set_pixel(x, y, Color(tint, tint.a * coverage))
	return ImageTexture.create_from_image(image)

static func style_slider(slider: HSlider) -> void:
	var track := box(Color(1, 1, 1, 0.1), 3, Color.TRANSPARENT, Vector2(0, 2))
	var filled := box(ACCENT, 3, Color.TRANSPARENT, Vector2(0, 2))
	slider.add_theme_stylebox_override("slider", track)
	slider.add_theme_stylebox_override("grabber_area", filled)
	slider.add_theme_stylebox_override("grabber_area_highlight", filled)
	slider.add_theme_icon_override("grabber", dot_texture(18, INK))
	slider.add_theme_icon_override("grabber_highlight", dot_texture(18, Color.WHITE, ACCENT))
	slider.add_theme_icon_override("grabber_disabled", dot_texture(18, FAINT))
	slider.theme = theme()

static func style_line_edit(field: LineEdit) -> void:
	field.add_theme_stylebox_override("normal", box(Color(1, 1, 1, 0.05), 10, LINE_STRONG, Vector2(16, 10)))
	field.add_theme_stylebox_override("focus", box(Color(0, 0, 0, 0), 10, ACCENT, Vector2(16, 10)))
	field.add_theme_font_override("font", font(REGULAR))
	field.add_theme_color_override("font_color", INK)
	field.add_theme_color_override("font_placeholder_color", FAINT)
	field.add_theme_color_override("caret_color", ACCENT)
	field.add_theme_color_override("selection_color", Color(ACCENT, 0.3))
	field.theme = theme()

## Tooltips are created by the engine; a theme on the owning control styles them.
static func theme() -> Theme:
	if shared_theme == null:
		shared_theme = Theme.new()
		shared_theme.default_font = font(REGULAR)
		shared_theme.default_font_size = 14
		shared_theme.set_stylebox("panel", "TooltipPanel", box(Color(0.035, 0.08, 0.095, 0.98), 8, LINE_STRONG, Vector2(12, 8)))
		shared_theme.set_font("font", "TooltipLabel", font(REGULAR))
		shared_theme.set_font_size("font_size", "TooltipLabel", 13)
		shared_theme.set_color("font_color", "TooltipLabel", INK)
		shared_theme.set_constant("line_spacing", "TooltipLabel", 4)
	return shared_theme

static func sentence(value: String) -> String:
	var lower := value.to_lower()
	return lower.substr(0, 1).to_upper() + lower.substr(1)
