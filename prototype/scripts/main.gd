extends Node2D

const Run = preload("res://scripts/run_controller.gd")
const Geometry = preload("res://scripts/loop_geometry.gd")
const LoopStrain = preload("res://scripts/loop_strain.gd")
const Hud = preload("res://scripts/hud.gd")
const Microscope = preload("res://scripts/microscope.gd")
const Soundscape = preload("res://scripts/soundscape.gd")
const Records = preload("res://scripts/records.gd")
const JourneyHud = preload("res://scripts/journey_hud.gd")
const JourneyProfile = preload("res://scripts/journey_profile.gd")
const JourneySave = preload("res://scripts/journey_save.gd")
const HomePond = preload("res://scripts/home_pond.gd")
const EvolutionReveal = preload("res://scripts/evolution_reveal.gd")
const CreatureCinema = preload("res://scripts/creature_cinema.gd")
const UI = preload("res://scripts/ui_style.gd")
const PEARL := Color("c7eee4")
const CYAN := Color("86cbc5")
const WARM := Color("edb184")
const RESULT_REVEAL_SECONDS := 2.8

var run = Run.new(true, 0, true, true)
var journey_profile = JourneyProfile.new()
var journey_path := "user://journey.cfg"
var resume_data: Dictionary = {}
var home_pond_open := false
var home_pond: Node2D
var help_open := false
var resume_after_help := false
var journal_open := false
var resume_after_journal := false
var save_message := ""
var autosave_elapsed := 0.0
var saved_journey_serial := -1
var show_home_on_start := true
var hud: Node2D
var microscope: Node2D
var evolution_reveal: Node2D
var creature_cinema: CanvasLayer
var creature_intros_enabled := true
var soundscape: Node
var audio_enabled := true
var settings_open := false
var resume_after_settings := false
var records = Records.new()
var save_records := true
var results_saved := false
var last_discovery := 0
var last_mastery_count := 0
var last_guard_notice_serial := 0
var debug_mode := false
var developer_tools := "--dev-tools" in OS.get_cmdline_user_args()
var click_mode := false
var reduced_motion := false
var high_contrast := false
var large_text := false
var preferences_enabled := true
var preferences_path := "user://preferences.cfg"
var visual_quality := 2 # 0 Light, 1 Balanced, 2 Full; gameplay detail is unchanged.
var pause_on_focus_loss := true
var last_pointer := Vector2.ZERO
var hovered := -1
var effects: Array:
	get:
		return run.clots
var visual_time := 0.0
var toast := ""
var toast_time := 0.0
var reject_time := 0.0
var result_reveal_state := ""
var result_reveal_remaining := 0.0
var big_capture_remaining := 0.0
var big_capture_center := Vector2.ZERO
var guard_flash_remaining := 0.0
var font: Font = UI.font(UI.MEDIUM)

func _ready() -> void:
	if "--campaign" in OS.get_cmdline_user_args() and run.harvest_mode:
		run.dispose()
		run = Run.new(true)
	if "--harvest" in OS.get_cmdline_user_args():
		run.dispose()
		run = Run.new(false, 0, true)
	if run.journey:
		journey_profile.load_profile()
		resume_data = JourneySave.read(journey_path)
		if show_home_on_start:
			run.state = Run.HOME
			home_pond_open = false
	DisplayServer.window_set_title("PETRIVERSE — A living journey" if run.journey else "PETRIVERSE — Risky harvest" if run.harvest_mode else "PETRIVERSE — Stillwater")
	load_preferences()
	records.load_records()
	microscope = Microscope.new()
	add_child(microscope)
	soundscape = Soundscape.new()
	soundscape.enabled = audio_enabled
	soundscape.preferences_path = preferences_path
	add_child(soundscape)
	if run.journey:
		home_pond = HomePond.new()
		add_child(home_pond)
	hud = JourneyHud.new() if run.journey else Hud.new()
	add_child(hud)
	if run.journey:
		evolution_reveal = EvolutionReveal.new()
		add_child(evolution_reveal)
	if run.journey and creature_intros_enabled:
		creature_cinema = CreatureCinema.new()
		add_child(creature_cinema)
	for error in run.board.validate_board():
		push_error(error)

func _exit_tree() -> void:
	if run.journey and save_records and run.state != Run.HOME:
		save_journey()
	run.dispose()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and pause_on_focus_loss and is_instance_valid(hud) and run.state == Run.ACTIVE:
		pause()

func _physics_process(delta: float) -> void:
	run.step(delta)

func _process(delta: float) -> void:
	if creature_cinema!=null:
		# Manual capture/test scenes drive their own clock; films are automatic in live play.
		if is_processing() and is_physics_processing(): creature_cinema.poll(delta)
		if creature_cinema.active:
			soundscape.sync(run,delta)
			return
	advance_result_reveal(delta)
	big_capture_remaining = maxf(0.0, big_capture_remaining - delta)
	guard_flash_remaining = maxf(0.0, guard_flash_remaining - delta)
	if run.state!=Run.ACTIVE:
		run.nudge.cancel()
	if run.state in [Run.ACTIVE, Run.HOME, Run.BRIEF] or (run.state in [Run.SUCCESS, Run.LOSS, Run.EVOLVE] and (not effects.is_empty() or run.mother_damage.active() or not run.amoebas.releases.is_empty() or not run.phages.bursts.is_empty())):
		visual_time += delta
		toast_time = maxf(0.0, toast_time - delta)
		reject_time = maxf(0.0, reject_time - delta)
	hovered = run.board.hit_test(get_global_mouse_position())
	if run.discovery_serial != last_discovery:
		last_discovery = run.discovery_serial
		toast = "Shellback · crack its armor, then capture again." if run.last_discovery == "shellback" else "Twinspore · fit both glowing nuclei inside one loop."
		if run.journey:
			for species in Run.JourneyPlan.SPECIES:
				if species.id == run.last_discovery:
					# The journal keeps the full entry; the toast names it and its first fact.
					toast = "Discovered: " + species.name + " · " + first_sentence(species.detail)
		toast_time = 9.0
	if run.journey and run.mastery_awards.size()!=last_mastery_count:
		last_mastery_count = run.mastery_awards.size()
		if last_mastery_count>0:
			var award: Dictionary = run.mastery_awards[-1]
			toast = award.title+" · "+award.detail+(" · +1 upgrade food" if award.food>0 else " · +150 points")
			toast += " · Home: "+run.Mastery.KEEPSAKES[award.id]
			toast_time = 5.0
	if run.journey and run.guardian_block_serial != last_guard_notice_serial:
		var blocks: int = run.guardian_block_serial - last_guard_notice_serial
		last_guard_notice_serial = run.guardian_block_serial
		guard_flash_remaining = 1.0
		toast = "Guard organelle intercepted a hunter" if blocks == 1 else "Guard organelles intercepted %d hunters" % blocks
		toast_time = 3.0
	if run.journey and save_records and run.state != Run.HOME:
		autosave_elapsed += delta
		if saved_journey_serial != run.journey_serial or autosave_elapsed >= 8.0:
			journey_profile.observe(run)
			save_journey()
	soundscape.sync(run, delta)
	if run.full_run and not run.journey and run.state in [Run.SUCCESS, Run.LOSS] and not results_saved:
		results_saved = true
		if save_records:
			records.record(run)
	microscope.sync()
	if home_pond != null:
		home_pond.sync(delta)
	if evolution_reveal != null:
		evolution_reveal.sync()
	hud.refresh()
	queue_redraw()

func round_result_showing() -> bool:
	return run.journey and run.state in [Run.EVOLVE, Run.LOSS, Run.SUCCESS] and (result_reveal_remaining > 0.0 or not run.clots.is_empty() or run.mother_damage.active())

func advance_result_reveal(delta: float) -> void:
	if not run.journey:
		return
	if run.state != result_reveal_state:
		result_reveal_state = run.state
		result_reveal_remaining = RESULT_REVEAL_SECONDS if run.state in [Run.EVOLVE, Run.LOSS, Run.SUCCESS] else 0.0
	else:
		result_reveal_remaining = maxf(0.0, result_reveal_remaining - delta)
	if run.state == Run.EVOLVE and not round_result_showing() and run.evolution_ready() and not (journal_open or settings_open or help_open):
		var can_evolve: bool = not run.offered_mutations.is_empty() and run.biomass >= run.evolution_cost()
		var repair_resting: bool = run.integrity < run.max_integrity and not run.repair_needs_deeper_wound() and run.repair_waiting()
		var can_repair: bool = run.integrity < run.max_integrity and run.biomass >= run.repair_cost() and not repair_resting and not run.repair_needs_deeper_wound()
		if not can_evolve and not can_repair and not repair_resting and run.choose_journey_evolution("continue"):
			result_reveal_state = run.state
			save_journey()

static func first_sentence(text: String) -> String:
	var end := text.find(". ")
	return text if end < 0 else text.substr(0, end + 1)

func restart() -> void:
	if run.journey:
		if run.state == Run.LOSS:
			run.retry_encounter()
			results_saved = false
			reset_presentation()
			save_journey()
		else:
			return_home()
		return
	settings_open = false
	resume_after_settings = false
	results_saved = false
	last_discovery = 0
	run.restart()
	if is_instance_valid(soundscape):
		soundscape.reset_run()
	visual_time = 0.0
	toast_time = 0.0
	reject_time = 0.0
	last_pointer = get_global_mouse_position()
	if is_instance_valid(microscope):
		microscope.sync()

func pause() -> void:
	if settings_open:
		toggle_sound_settings()
		return
	run.toggle_pause()

func toggle_sound_settings() -> void:
	settings_open = not settings_open
	if settings_open:
		resume_after_settings = run.state == Run.ACTIVE
		if resume_after_settings:
			run.toggle_pause()
	elif resume_after_settings and run.state == Run.PAUSED:
		run.toggle_pause()
		resume_after_settings = false

func overlay_action() -> void:
	if run.journey:
		if run.state == Run.BRIEF:
			if run.growth_slot() >= 0:
				choose_growth_role("guard")
			elif run.Habitats.pending(run):
				choose_habitat("bloom")
			else:
				run.begin_encounter()
		elif run.state == Run.PAUSED:
			pause()
		elif run.state == Run.LOSS:
			restart()
		elif run.state == Run.SUCCESS:
			return_home()
		return
	if run.state == Run.PAUSED:
		pause()
	else:
		restart()

func toggle_debug() -> void:
	if not developer_tools:
		return
	debug_mode = not debug_mode

func toggle_mode() -> void:
	click_mode = not click_mode
	run.selection.cancel()
	run.nudge.cancel()
	save_preferences()

func toggle_motion() -> void:
	reduced_motion = not reduced_motion
	save_preferences()

func toggle_contrast() -> void:
	high_contrast = not high_contrast
	save_preferences()

func toggle_text() -> void:
	large_text = not large_text
	save_preferences()

func toggle_quality() -> void:
	visual_quality = (visual_quality + 2) % 3
	save_preferences()

func load_preferences() -> void:
	if not preferences_enabled:
		return
	var config := ConfigFile.new()
	if config.load(preferences_path) == OK:
		reduced_motion = bool(config.get_value("comfort", "reduced_motion", false))
		high_contrast = bool(config.get_value("comfort", "high_contrast", false))
		large_text = bool(config.get_value("comfort", "large_text", false))
		click_mode = bool(config.get_value("comfort", "click_mode", false))
		visual_quality = clampi(int(config.get_value("comfort", "visual_quality", 2)), 0, 2)

func save_preferences() -> void:
	if not preferences_enabled:
		return
	var config := ConfigFile.new()
	config.load(preferences_path)
	config.set_value("comfort", "reduced_motion", reduced_motion)
	config.set_value("comfort", "high_contrast", high_contrast)
	config.set_value("comfort", "large_text", large_text)
	config.set_value("comfort", "click_mode", click_mode)
	config.set_value("comfort", "visual_quality", visual_quality)
	config.save(preferences_path)

func choose_evolution(index: int) -> void:
	if round_result_showing():
		return
	if index >= 0 and index < run.offered_mutations.size():
		var id: String = run.offered_mutations[index]
		if run.choose_mutation(id):
			toast_time = 0.0
			if evolution_reveal != null:
				microscope.sync()
				evolution_reveal.present(id)
				save_journey()

func _unhandled_input(event: InputEvent) -> void:
	if creature_cinema!=null and creature_cinema.active: return
	if hud!=null and run.journey and hud.renaming():
		if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
			hud.cancel_rename()
		return
	if run.state==Run.HOME and home_pond_open and not settings_open and not journal_open and not help_open:
		if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
			home_pond.pick(event.position)
			return
		if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
			toggle_home_pond()
			return
	if evolution_reveal != null and evolution_reveal.visible:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ENTER,KEY_KP_ENTER,KEY_ESCAPE]:
			evolution_reveal.dismiss()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if run.journey and help_open:
			if event.keycode in [KEY_ESCAPE, KEY_H]:
				toggle_help()
			return
		if run.journey and event.keycode == KEY_H and not settings_open and not journal_open:
			toggle_help()
			return
		if run.journey and journal_open:
			if event.keycode in [KEY_ESCAPE, KEY_J]:
				toggle_journal()
			return
		if run.journey and event.keycode == KEY_J:
			toggle_journal()
			return
		if settings_open:
			if event.keycode in [KEY_ESCAPE, KEY_V, KEY_SPACE]:
				toggle_sound_settings()
			return
		match event.keycode:
			KEY_SPACE: pause()
			KEY_R: restart()
			KEY_D, KEY_F3: toggle_debug()
			KEY_C: toggle_mode()
			KEY_M: toggle_motion()
			KEY_V: toggle_sound_settings()
			KEY_1: choose_evolution(0)
			KEY_2: choose_evolution(1)
			KEY_3: choose_evolution(2)
			KEY_ESCAPE:
				run.selection.cancel()
				run.nudge.cancel()
			KEY_ENTER:
				if run.nudge.target_id>=0 and run.state==Run.ACTIVE:
					commit_nudge(last_pointer)
				elif run.journey and run.state in [Run.BRIEF, Run.PAUSED, Run.LOSS, Run.SUCCESS]:
					overlay_action()
				elif click_mode and run.state == Run.ACTIVE:
					commit_selection()
		return
	if run.state != Run.ACTIVE or journal_open or help_open:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			run.selection.cancel()
			run.nudge.cancel()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if run.nudge.target_id>=0:
				if (event.pressed and click_mode) or (not event.pressed and (not click_mode or event.position.distance_to(run.nudge.pointer_origin)>=Run.CystNudge.MIN_DRAG)):
					commit_nudge(event.position)
				return
			if event.pressed:
				last_pointer = event.position
				if run.nudge.pick(run,event.position)!=null:
					if not run.nudge.begin(run,event.position):
						toast = "Nudge recharging · %.1fs" % run.nudge.cooldown
						toast_time = 1.5
					return
				if click_mode and run.selection.active:
					run.selection.visit(run.board.hit_test(event.position))
				else:
					run.selection.start(event.position)
			elif not click_mode:
				microscope.disturb_water(last_pointer,event.position)
				run.selection.drag(last_pointer, event.position)
				commit_selection()
	elif event is InputEventMouseMotion:
		if run.nudge.target_id>=0:
			run.nudge.point(event.position)
			last_pointer = event.position
			return
		if not click_mode and run.selection.active:
			microscope.disturb_water(last_pointer,event.position)
			run.selection.drag(last_pointer, event.position)
			if run.selection.rejected_id >= 0:
				reject_time = 0.4
		last_pointer = event.position

func commit_nudge(at: Vector2) -> void:
	var result: Dictionary = run.nudge.release(run,at)
	if result.is_empty():
		return
	run.fluid.stroke(result.from,result.to,0.45)
	if not reduced_motion:
		microscope.water.stroke(result.from,result.to,visual_time)
	soundscape.play_effect("close",0.24,0.86)
	toast = "Phages nudged · bring them close to a copper bacterium" if result.get("kind","")=="phage" else "Cyst nudged · draw a clean loop around the food"
	toast_time = 2.5

func commit_selection() -> void:
	var advice: Dictionary = JourneyHud.Guidance.next_action(run, click_mode) if run.journey and run.selection.closed else {}
	var blocked_reason: String = run.selection.MOTHER_WARNING if run.selection.mother_blocked() else run.selection.rejection_reason
	var was_active: bool = run.selection.active
	var result: Dictionary = run.release()
	if not result.valid and was_active:
		toast = blocked_reason if not blocked_reason.is_empty() else "Loop unfinished · return to START before releasing."
		toast_time = 3.0
	if result.valid:
		if run.harvest != null:
			toast = ("+%d food" if run.journey else "+%d nourishment") % result.food
			if run.journey and result.boss_layers > 0:
				toast = "Boss hit · %d hit%s left · −3 charge" % [3-run.harvest.boss_hits, "" if run.harvest.boss_hits == 2 else "s"]
			elif run.journey and result.get("wardens",0)>0:
				toast = run.harvest.ecology.notice
			elif run.journey and result.armor_hits > 0:
				toast = "Shell fractured · capture again"
			elif run.journey and result.get("cells_rescued",0)>0:
				toast = "Blue cell rescued · returning to your colony"
			elif run.journey and result.get("rescued", 0) > 0:
				toast += " · %d spores rescued" % result.rescued
			elif run.journey and result.get("purified", 0) > 0:
				toast = "%d cysts safely neutralized" % result.purified
			elif result.poison > 0:
				toast += " · %d health lost" % result.poison
			elif result.threats > 0:
				toast += " · mother defended"
			elif result.food == 0:
				toast = "Empty loop · cells returning" if advice.is_empty() or advice.title == "Nothing useful inside" else advice.title + " · no capture"
		elif result.boss_layers > 0:
			toast = "Protection dissolved"
		elif result.armor_hits > 0 and result.points == 0:
			toast = "Shell fractured · capture again"
		elif result.points > 0:
			toast = "+%d · %s" % [result.points, "Feast!" if result.kills >= 3 else ("Double capture" if result.kills == 2 else "Absorbed")]
		else:
			toast = "Empty loop · cells returning"
		if run.journey and result.boss_layers == 0 and result.food > 0 and advice.get("title", "") == "The boss is protected":
			toast += " · boss still protected"
		if run.journey:
			var benefit: String = run.Mutations.food_bonus_text(result)
			if not benefit.is_empty():
				toast += " · includes " + benefit
			if not result.get("capture_grade","").is_empty():
				toast = "%s · +%d score · %s" % [result.capture_grade,result.capture_bonus,toast]
				big_capture_remaining = 2.0
				big_capture_center = Vector2.ZERO
				if not result.positions.is_empty():
					for point in result.positions:
						big_capture_center += point / float(result.positions.size())
				else:
					for point in result.polygon:
						big_capture_center += point / float(result.polygon.size())
		toast_time = 3.0 if run.journey and not result.get("capture_grade","").is_empty() else 2.0
		if run.journey and result.get("rescued",0)>0:
			toast += " · settled in your home pond"
			toast_time = 4.0
			if save_records:
				journey_profile.observe(run)
				save_journey()

func _draw() -> void:
	if run.state==Run.HOME: return
	draw_dish()
	if (run.state==Run.HOME and home_pond_open) or (home_pond!=null and home_pond.showing_epilogue()):
		return
	for membrane in run.residuals:
		var outline: PackedVector2Array = membrane.polygon.duplicate()
		outline.append(outline[0])
		var fade: float = minf(1.0, membrane.remaining * 2.0)
		draw_polyline(outline, Color(0.55, 0.84, 0.8, 0.07 * fade), 5.0, true)
		draw_polyline(outline, Color(0.67, 0.89, 0.85, 0.33 * fade), 1.0, true)
	var legal: Array = run.selection.legal_next()
	draw_graph(legal)
	draw_selection()
	draw_mother()
	var targets: Array = run.preview()
	for enemy in run.enemies:
		draw_drifter(enemy, targets.has(enemy.id))
	for i in run.cells.size():
		draw_cell(i, legal)

func draw_dish() -> void:
	# The pond ecosystem is entirely below gameplay. Only the dish ticks live here.
	var center: Vector2 = run.board.center
	for i in 8:
		var angle := TAU * i / 8.0
		draw_line(center + Vector2.from_angle(angle) * 399.0, center + Vector2.from_angle(angle) * 404.0, Color(0.38, 0.54, 0.6, 0.27), 1.0, true)

func bond(a: Vector2, b: Vector2, color: Color, width: float = 1.0, dashed: bool = false) -> void:
	# Terminate at tissue surfaces so connection strokes never cross organelles.
	var direction := (b - a).normalized()
	var start := a + direction * 27.0
	var end := b - direction * 27.0
	if dashed:
		draw_dashed_line(start, end, color, width, 4.0, true, true)
	else:
		draw_line(start, end, color, width, true)

func draw_graph(legal: Array) -> void:
	# Any ready cell can extend a simple polygon. Highlight destinations, rather
	# than drawing a complete web that would obscure the organisms beneath it.
	if run.selection.active and not run.selection.closed and legal.has(hovered):
		var origin: Vector2 = run.board.anchors[run.selection.path[-1]]
		var destination: Vector2 = run.board.anchors[hovered]
		var tint: float = LoopStrain.edge_tint(origin,destination) if run.journey else 0.0
		bond(origin, destination, Color(0.65, 0.86, 0.86, 0.65).lerp(Color(WARM,0.85),tint), 1.1+tint, true)

func draw_selection() -> void:
	if not run.selection.active:
		return
	var polygon := Geometry.polygon_for(run.selection.path, run.board.anchors)
	var edge_color := Color("eaa2bf") if run.harvest != null and run.harvest_preview().poison > 0 else PEARL
	var mother_blocked: bool = run.selection.mother_blocked()
	if mother_blocked:
		edge_color = WARM
	for i in range(polygon.size() - 1):
		var tint: float = LoopStrain.edge_tint(polygon[i],polygon[i+1]) if run.journey else 0.0
		var stroke: Color = edge_color.lerp(WARM,minf(1.0,tint*1.6)) if not mother_blocked else WARM
		bond(polygon[i], polygon[i + 1], Color(stroke, 0.13), 5.0)
		bond(polygon[i], polygon[i + 1], stroke, 1.4 + tint * 1.2)
		if tint>0.15:
			draw_circle((polygon[i]+polygon[i+1])*0.5,2.2+tint*2.0,Color(WARM,0.75),false,1.2,true)
	if run.selection.can_close():
		var close_tint: float = LoopStrain.edge_tint(polygon[-1],polygon[0]) if run.journey else 0.0
		var close_color: Color = edge_color.lerp(WARM,minf(1.0,close_tint*1.6))
		bond(polygon[-1], polygon[0], close_color if run.selection.closed else close_color.darkened(0.12), 1.4 + close_tint * 1.2, not run.selection.closed)
	elif mother_blocked and Geometry.simple_polygon(polygon):
		bond(polygon[-1], polygon[0], Color(WARM, 0.65), 1.4, true)

func draw_cell(id: int, legal_cells: Array) -> void:
	var cell = run.cells[id]
	if cell.lost or cell.captor>=0: return
	var p: Vector2 = run.board.anchors[id]
	var selected: bool = run.selection.path.has(id)
	var legal: bool = legal_cells.has(id)
	var ready: bool = run.is_ready(id)
	if not ready:
		# Recovery is the gather/digest/return motion, not a countdown ring.
		# A still dormancy mark remains available in reduced-motion mode.
		if reduced_motion:
			draw_line(p + Vector2(-4, 17), p + Vector2(4, 17), Color(0.75, 0.83, 0.84, 0.8), 2.0, true)
		if debug_mode:
			var body: Vector2 = microscope.cells[id].position
			draw_string(font, body + Vector2(25, -29), "%02d %.1fs" % [id, cell.remaining], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, PEARL)
		return
	if high_contrast or legal or (hovered == id and ready):
		draw_arc(p, 32.0, 0.2, 1.1, 18, PEARL, 1.2, true)
		draw_arc(p, 32.0, PI + 0.2, PI + 1.1, 18, PEARL, 1.2, true)
	if selected and id == run.selection.path[0]:
		draw_circle(p, 34.0, PEARL, false, 1.6 if run.selection.can_close() else 1.0, true)
		draw_string(font, p + Vector2(-17, -41), "START", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, PEARL)
	if reject_time > 0.0 and id == run.selection.rejected_id:
		draw_line(p + Vector2(-8, -8), p + Vector2(8, 8), WARM, 2.0, true)
		draw_line(p + Vector2(8, -8), p + Vector2(-8, 8), WARM, 2.0, true)
	if debug_mode:
		var caption := "%02d" % id if ready else "%02d %.1fs" % [id, cell.remaining]
		draw_string(font, p + Vector2(25, -29), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, PEARL)

func draw_mother() -> void:
	var p: Vector2 = run.board.center
	if run.selection.mother_blocked():
		var radius: float = run.board.mother_radius + Geometry.BOUNDARY_TOLERANCE
		draw_circle(p, radius, Color(WARM, 0.08), true)
		draw_circle(p, radius, Color(WARM, 0.8), false, 1.8, true)
	# The rim tracks the number of organelles the Mother has grown so far.
	for i in run.max_integrity:
		var start: float = -PI / 2.0 + i * TAU / run.max_integrity + 0.30
		draw_arc(p, 60, start, start + TAU / run.max_integrity - 0.60, 20, Color(0.72, 0.85, 0.82, 0.6) if i < run.integrity else Color(0.23, 0.33, 0.40, 0.6), 1.2, true)
	if guard_flash_remaining > 0.0:
		var glow: float = guard_flash_remaining
		draw_arc(p, 68.0 + (1.0-glow)*14.0, 0.0, TAU, 64, Color(CYAN, glow*0.75), 2.0+glow*2.0, true)

	for nucleus in run.critical_nuclei():
		var angle := (nucleus - p).angle()
		var outward := Vector2.from_angle(angle)
		var tangent := outward.orthogonal()
		var tip := p + outward * 67.0
		draw_arc(p, 72.0, angle - 0.18, angle + 0.18, 16, WARM, 1.8, true)
		draw_polyline(PackedVector2Array([tip + outward * 7.0 + tangent * 4.0, tip, tip + outward * 7.0 - tangent * 4.0]), WARM, 1.4, true)

func draw_drifter(enemy: RefCounted, targeted: bool) -> void:
	var nuclei: PackedVector2Array = enemy.nuclei()
	for nucleus in nuclei:
		draw_nucleus(enemy, nucleus, targeted)
	if enemy.is_boss():
		var p: Vector2 = enemy.nucleus
		for i in 3:
			draw_circle(p + Vector2((i - 1) * 9.0, -39), 2.0, PEARL if i < enemy.health else Color("36454f"), true, -1, true)

func draw_nucleus(enemy: RefCounted, p: Vector2, targeted: bool) -> void:
	# A tiny specular point registers the logical nucleus exactly, independent
	# of texture anatomy and cosmetic membrane deformation.
	draw_circle(p, 1.4, Color(1.0, 0.83, 0.52, 0.78), true, -1, true)
	if enemy.kind == "cyst":
		# Persistent crossed nucleus: toxicity is readable without color vision.
		var color := Color("f3a8c5")
		draw_line(p + Vector2(-3, -3), p + Vector2(3, 3), color, 1.3, true)
		draw_line(p + Vector2(3, -3), p + Vector2(-3, 3), color, 1.3, true)
	if high_contrast:
		draw_circle(p, 8.0, Color("ffe1ab"), false, 1.6, true)
	if targeted:
		var marker := WARM if enemy.kind == "shellback" and enemy.health > Run.Mutations.damage(run.mutations, run.selection.path.size()) else PEARL
		if enemy.kind == "cyst":
			marker = Color("f3a8c5")
		draw_circle(p, 11, marker, false, 1.2, true)
		for offset in [Vector2(-15, 0), Vector2(15, 0), Vector2(0, -15), Vector2(0, 15)]:
			draw_line(p + offset, p + offset * 1.2, PEARL, 1.0, true)
	if debug_mode:
		draw_line(p - Vector2(4, 0), p + Vector2(4, 0), Color.WHITE, 1.0)
		draw_line(p - Vector2(0, 4), p + Vector2(0, 4), Color.WHITE, 1.0)
		draw_string(font, p + Vector2(17, -24), "N%d" % enemy.id, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, WARM)

func save_journey() -> void:
	if not save_records or not run.journey or run.state == Run.HOME:
		return
	var error := JourneySave.write(run, journey_path)
	save_message = "Journey saved" if error == OK else "Could not save · keep this window open"
	if error == OK:
		saved_journey_serial = run.journey_serial
		autosave_elapsed = 0.0

func reset_presentation() -> void:
	home_pond_open = false
	microscope.finish_growth()
	if evolution_reveal != null:
		evolution_reveal.visible = false
	settings_open = false
	journal_open = false
	help_open = false
	resume_after_help = false
	results_saved = false
	last_discovery = run.discovery_serial
	toast_time = 0.0
	result_reveal_state = run.state
	result_reveal_remaining = 0.0
	big_capture_remaining = 0.0
	guard_flash_remaining = 0.0
	visual_time = run.elapsed
	last_mastery_count = run.mastery_awards.size()
	last_guard_notice_serial = run.guardian_block_serial
	soundscape.reset_run()
	soundscape.last_mastery_count = last_mastery_count
	soundscape.last_guard_block = run.guardian_block_serial
	soundscape.last_integrity = run.integrity
	# IDs restart with a new colony; discard old sprite and effect identities.
	for body in microscope.enemies.values():
		body.queue_free()
	microscope.enemies.clear()
	for pulse in microscope.pulses:
		pulse.queue_free()
	microscope.pulses.clear()
	for invader in microscope.invaders.values():
		invader.queue_free()
	microscope.invaders.clear()
	microscope.sync()

func new_journey(id: String) -> void:
	if not journey_profile.unlocked(id):
		return
	run.colony_id = id
	run.long_journey = true
	run.discovery_history = journey_profile.discovered.duplicate()
	run.restart()
	if id == "wanderer":
		run.Lesson.begin(run)
	hud.advanced_open = false
	reset_presentation()
	save_journey()

func resume_journey() -> void:
	if resume_data.is_empty():
		return
	if JourneySave.restore(run, resume_data.snapshot):
		run.checkpoint = resume_data.checkpoint.duplicate(true)
		if run.state == Run.ACTIVE:
			run.state = Run.PAUSED
		reset_presentation()

func toggle_home_pond() -> void:
	if run.state==Run.HOME:
		home_pond_open = not home_pond_open
		hud.advanced_open = false

func return_home() -> void:
	run.nudge.cancel()
	home_pond_open = true
	if run.state != Run.HOME:
		save_journey()
		if save_records:
			journey_profile.observe(run)
		resume_data = {"snapshot": JourneySave.capture(run), "checkpoint": run.checkpoint.duplicate(true)}
		run.selection.cancel()
		run.state = Run.HOME
	settings_open = false
	journal_open = false
	help_open = false
	resume_after_help = false

func toggle_journal() -> void:
	journal_open = not journal_open
	if journal_open:
		resume_after_journal = run.state == Run.ACTIVE
		if resume_after_journal:
			run.toggle_pause()
	elif resume_after_journal and run.state == Run.PAUSED:
		run.toggle_pause()
		resume_after_journal = false

func travel_without_evolution() -> void:
	if run.choose_journey_evolution("continue"):
		save_journey()

func choose_habitat(id: String) -> void:
	if run.Habitats.choose(run,id):
		save_journey()
		hud.refresh()

func choose_growth_role(role: String) -> void:
	if run.choose_growth_role(role):
		save_journey()
		hud.refresh()

func repair_and_travel() -> void:
	if run.choose_journey_evolution("repair"):
		save_journey()

func toggle_help() -> void:
	help_open = not help_open
	if help_open:
		resume_after_help = run.state == Run.ACTIVE
		if resume_after_help:
			run.toggle_pause()
	elif resume_after_help and run.state == Run.PAUSED:
		run.toggle_pause()
		resume_after_help = false
