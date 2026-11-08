extends RefCounted
## Presentation only: a microscope reticle replaces the arrow over the live
## dish. Hardware cursors keep it lag-free; interface controls keep their own.
const SIZE := 32
const PEARL := Color(0.86, 0.97, 0.94)
const SHADOW := Color(0.0, 0.04, 0.05, 0.55)
var installed := false
var current := -1

static func coverage(distance: float, radius: float, width: float) -> float:
	return clampf(width * 0.5 + 0.5 - absf(distance - radius), 0.0, 1.0)

static func make(center_dot: float, ring: float, ticks: bool) -> Image:
	var image := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var middle := SIZE * 0.5
	for y in SIZE:
		for x in SIZE:
			var offset := Vector2(x + 0.5 - middle, y + 0.5 - middle)
			var distance := offset.length()
			var light := coverage(distance, ring, 1.6)
			light = maxf(light, clampf(center_dot + 0.5 - distance, 0.0, 1.0))
			if ticks:
				var along := maxf(absf(offset.x), absf(offset.y))
				var across := minf(absf(offset.x), absf(offset.y))
				if along > ring + 2.0 and along < ring + 6.5 and across < 0.9:
					light = maxf(light, 1.0)
			var shade := maxf(coverage(distance, ring, 4.2), clampf(center_dot + 1.8 - distance, 0.0, 1.0))
			var color := SHADOW
			color.a *= shade
			color = color.blend(Color(PEARL, light))
			image.set_pixel(x, y, color)
	return image

func install() -> void:
	installed = true
	var hotspot := Vector2(SIZE, SIZE) * 0.5
	Input.set_custom_mouse_cursor(make(1.4, 8.5, false), Input.CURSOR_CROSS, hotspot)
	Input.set_custom_mouse_cursor(make(3.2, 6.0, false), Input.CURSOR_DRAG, hotspot)
	Input.set_custom_mouse_cursor(make(1.4, 8.5, true), Input.CURSOR_MOVE, hotspot)

func update(game: Node2D) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if not installed:
		install()
	var run = game.run
	var shape := Input.CURSOR_ARROW
	var blocked: bool = game.settings_open or game.journal_open or game.help_open or (game.creature_cinema != null and game.creature_cinema.active)
	if run.state == "active" and not blocked:
		var pointer: Vector2 = game.get_global_mouse_position()
		var dish: Vector2 = game.to_dish(pointer)
		if dish.distance_to(run.board.center) < run.board.dish_radius + 8.0:
			shape = Input.CURSOR_CROSS
			if run.selection.active:
				shape = Input.CURSOR_DRAG
			elif run.nudge.target_id >= 0 or run.nudge.pick(run, dish) != null:
				shape = Input.CURSOR_MOVE
	if shape != current:
		current = shape
		Input.set_default_cursor_shape(shape)
