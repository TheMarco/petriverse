extends CanvasLayer
## First-sighting films share the live art and behaviors, never the player's Run.
const FilmStage = preload("res://scripts/creature_film_stage.gd")
const UI = preload("res://scripts/ui_style.gd")
static var catalogue: Dictionary = {}
var game: Node2D
var screen: Control
var viewport: SubViewport
var film: Node2D
var voice: AudioStreamPlayer
var title: Label
var subtitle: Label
var caption: Label
var context: Label
var progress: ProgressBar
var pause_button: Button
var close_button: Button
var current_id := ""
var active := false
var playback_paused := false
var focus_paused := false
var previous_state := ""
var finish_at := 0.0
var is_replay := false
var previous_focus: Control
var covered_items: Array = []
var pending_ids: Array[String] = []
var notice_encounter := ""
var saved_for_journal := 0

static func entries() -> Dictionary:
	if catalogue.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/creature_films.json"))
		if parsed is Dictionary: catalogue = parsed
	return catalogue

func label_at(at: Vector2, size: Vector2, font_size: int, color: Color) -> Label:
	var control := Label.new()
	control.position = at
	control.size = size
	control.add_theme_font_override("font",UI.font(UI.MEDIUM))
	control.add_theme_font_size_override("font_size",font_size)
	control.add_theme_color_override("font_color",color)
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(control)
	return control

func button_at(text: String, at: Vector2, size: Vector2, action: Callable, primary: bool = false) -> Button:
	var control := Button.new()
	control.text = text
	control.position = at
	control.size = size
	UI.style_button(control,"primary" if primary else "secondary",15)
	control.pressed.connect(action)
	screen.add_child(control)
	return control

func _ready() -> void:
	game = get_parent()
	layer = 80
	screen = Control.new()
	screen.size = Vector2(1280,900)
	screen.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(screen)
	var background := ColorRect.new()
	background.size = screen.size
	background.color = Color("061317")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(background)
	context = label_at(Vector2(64,24),Vector2(1000,26),12,UI.ACCENT)
	title = label_at(Vector2(64,52),Vector2(1152,62),34,UI.INK)
	viewport = SubViewport.new()
	viewport.size = Vector2i(1920,1080)
	viewport.disable_3d = true
	viewport.gui_disable_input = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	screen.add_child(viewport)
	var picture := TextureRect.new()
	picture.position = Vector2(48,124)
	picture.size = Vector2(1184,562)
	picture.texture = viewport.get_texture()
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(picture)
	caption = label_at(Vector2(96,688),Vector2(1088,34),18,UI.ACCENT)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle = label_at(Vector2(96,731),Vector2(1088,91),20,UI.INK)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	progress = ProgressBar.new()
	progress.position = Vector2(48,822)
	progress.size = Vector2(1184,3)
	progress.show_percentage = false
	progress.add_theme_font_size_override("font_size",1)
	progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress.add_theme_stylebox_override("background",UI.box(Color("163039"),1,Color.TRANSPARENT,Vector2.ZERO))
	progress.add_theme_stylebox_override("fill",UI.box(UI.ACCENT,1,Color.TRANSPARENT,Vector2.ZERO))
	screen.add_child(progress)
	progress.size.y = 3.0
	pause_button = button_at("Pause · Space",Vector2(48,840),Vector2(168,42),toggle_playback)
	var replay_button := button_at("Replay",Vector2(230,840),Vector2(112,42),replay)
	close_button = button_at("Skip film · Esc",Vector2(932,840),Vector2(300,42),dismiss,true)
	var controls := [pause_button,replay_button,close_button]
	for i in controls.size():
		controls[i].focus_next = controls[i].get_path_to(controls[(i+1)%controls.size()])
		controls[i].focus_previous = controls[i].get_path_to(controls[posmod(i-1,controls.size())])
	voice = AudioStreamPlayer.new()
	add_child(voice)
	screen.hide()

func visible_species() -> Array[String]:
	var result: Array[String] = []
	for body in game.run.enemies:
		if body.health<=0 or body.age<1.4: continue
		var id: String = body.form if not body.form.is_empty() else body.kind
		if entries().has(id) and not result.has(id): result.append(id)
	if game.run.phages.clusters.any(func(c): return c.age>=1.4) and not result.has("phage"): result.append("phage")
	return result

func poll(_delta: float) -> void:
	var encounter := "%d:%s" % [game.run.run_seed,game.run.encounter_key()]
	if encounter != notice_encounter:
		notice_encounter = encounter
		pending_ids.clear()
	if active or game.run.state!=game.Run.ACTIVE: return
	if game.settings_open or game.help_open or game.journal_open: return
	if game.run.selection.active or game.run.nudge.target_id>=0: return
	if game.evolution_reveal!=null and game.evolution_reveal.visible: return
	pending_ids = pending_ids.filter(func(id): return not game.journey_profile.introduced_species.has(id))
	var changed := false
	for id in visible_species():
		if game.journey_profile.introduced_species.has(id) or game.journey_profile.offered_species.has(id):
			continue
		game.journey_profile.offered_species.append(id)
		if not game.journey_profile.discovered.has(id):
			game.journey_profile.discovered.append(id)
		pending_ids.append(id)
		changed = true
	if changed and game.save_records:
		game.journey_profile.save_profile()

func watch_new_film() -> void:
	if active or pending_ids.is_empty() or game.run.state != game.Run.ACTIVE:
		return
	var id := pending_ids[0]
	saved_for_journal = pending_ids.size() - 1
	pending_ids.clear()
	present(id)

func save_new_films_for_later() -> void:
	if pending_ids.is_empty():
		return
	pending_ids.clear()
	game.toast = "New films saved in the Field Journal · J"
	game.toast_time = 3.0

func present(id: String, replaying: bool = false) -> bool:
	if active or not entries().has(id): return false
	current_id = id
	previous_focus = get_viewport().gui_get_focus_owner()
	is_replay = replaying
	close_button.text = "Return to journal · Esc" if replaying else "Skip film · Esc"
	previous_state = game.run.state
	if previous_state==game.Run.ACTIVE: game.run.toggle_pause()
	active = true
	playback_paused = false
	focus_paused = false
	game.soundscape.narration_active = true
	context.text = "FIELD NOTES  /  " + ("WATCH AGAIN" if replaying else "FIRST ENCOUNTER") + "     ·     YOUR DISH IS PAUSED"
	title.text = entries()[id].name
	subtitle.text = entries()[id].narration
	subtitle.add_theme_font_size_override("font_size",22 if game.large_text else 20)
	screen.show()
	screen.modulate.a = 0.0 if not game.reduced_motion else 1.0
	# Only the photographed dish needs to render while this opaque screen is up.
	covered_items.clear()
	for item in [game.microscope,game.hud,game.home_pond]:
		if item!=null and item.visible:
			covered_items.append(item)
			item.hide()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	reset_film()
	pause_button.grab_focus()
	return true

func reset_film() -> void:
	voice.stop()
	if film!=null:
		viewport.remove_child(film)
		film.queue_free()
	film = FilmStage.new()
	viewport.add_child(film)
	film.prepare(entries()[current_id],game.reduced_motion,game.visual_quality)
	finish_at = maxf(film.duration,float(subtitle.text.split(" ").size())/2.6+1.2)
	var path := "res://assets/audio/introductions/"+current_id+".ogg"
	if ResourceLoader.exists(path):
		voice.stream = load(path)
		finish_at = maxf(film.duration,voice.stream.get_length()+1.0)
		if game.audio_enabled and not game.soundscape.muted: voice.play()
	else:
		voice.stream = null # Captions and demonstration remain usable offline if a file is missing.
	caption.text = film.cue
	progress.value = 0.0
	playback_paused = false
	pause_button.text = "Pause · Space"
	voice.stream_paused = focus_paused

func replay() -> void:
	if active: reset_film()

func toggle_playback() -> void:
	if not active: return
	playback_paused = not playback_paused
	voice.stream_paused = playback_paused or focus_paused
	pause_button.text = "Play · Space" if playback_paused else "Pause · Space"

func advance(delta: float) -> void:
	if not active or playback_paused or focus_paused: return
	voice.volume_db = game.soundscape.gain_db(game.soundscape.effects_volume) if game.audio_enabled and not game.soundscape.muted else -80.0
	film.advance(minf(delta,0.1))
	screen.modulate.a = 1.0 if game.reduced_motion else smoothstep(0.0,0.35,film.elapsed)
	caption.text = film.cue
	progress.value = 100.0*film.elapsed/finish_at
	if film.elapsed>=finish_at: dismiss()

func _process(delta: float) -> void:
	advance(delta)

func dismiss() -> void:
	if not active: return
	voice.stop()
	voice.stream = null
	active = false
	screen.hide()
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	game.soundscape.narration_active = false
	for item in covered_items:
		if is_instance_valid(item): item.show()
	covered_items.clear()
	if not game.journey_profile.introduced_species.has(current_id):
		game.journey_profile.introduced_species.append(current_id)
		if game.save_records: game.journey_profile.save_profile()
	if film!=null:
		viewport.remove_child(film)
		film.queue_free()
		film = null
	# Replaying from a journal/pause screen returns to that same screen.
	if previous_state==game.Run.ACTIVE and game.run.state==game.Run.PAUSED and not focus_paused:
		game.run.toggle_pause()
	if saved_for_journal > 0:
		game.toast = "%d more new film%s in the Field Journal · J" % [saved_for_journal, "s" if saved_for_journal != 1 else ""]
		game.toast_time = 3.0
		saved_for_journal = 0
	else:
		game.toast_time = 0.0
	game.hud.refresh()
	if is_instance_valid(previous_focus) and previous_focus.is_visible_in_tree(): previous_focus.grab_focus()

func _input(event: InputEvent) -> void:
	if not active: return
	if event is InputEventKey:
		# Tab stays available to the film's explicit focus cycle.
		if event.keycode not in [KEY_ESCAPE,KEY_SPACE]: return
		if event.pressed and not event.echo:
			match event.keycode:
				KEY_ESCAPE: dismiss()
				KEY_SPACE: toggle_playback()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT:
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if not active or game==null or not game.pause_on_focus_loss: return
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT:
		focus_paused = true
		voice.stream_paused = true
	elif what==NOTIFICATION_APPLICATION_FOCUS_IN:
		focus_paused = false
		voice.stream_paused = playback_paused

func _exit_tree() -> void:
	if is_instance_valid(voice):
		voice.stop()
		voice.stream = null
