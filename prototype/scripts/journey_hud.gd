extends "res://scripts/hud.gd"
const Journey = preload("res://scripts/journey_plan.gd")
const MotherAppearance = preload("res://scripts/mother_appearance.gd")
const LoopStrain = preload("res://scripts/loop_strain.gd")
const Guidance = preload("res://scripts/journey_guidance.gd")
const TitleScreen = preload("res://scripts/title_screen.gd")
var title_screen := TitleScreen.new()
const Rhythm = preload("res://scripts/encounter_rhythm.gd")
const JOURNAL_PAGE_SIZE := 4
## Side columns sit in the clear margins either side of the 392px lens.
const LEFT := 40.0
const RIGHT := 1068.0
const COLUMN := 172.0
const TRAIT_TOP := 330.0
const TRAIT_STEP := 26.0
const TRAIT_LIMIT := 8
const CHOICE := Rect2(250, 160, 780, 570)
const EVOLVE := Rect2(242, 128, 796, 660)
const REST := Rect2(330, 196, 620, 520)
const MENU := Rect2(430, 196, 420, 466)
const HELP := Rect2(230, 80, 820, 772)
const JOURNAL := Rect2(222, 96, 836, 716)
const COLONIES := Rect2(241, 170, 798, 540)
const RENAME := Rect2(370, 296, 540, 290)
var advanced_open := false
var new_button: Button
var advanced_button: Button
var pond_button: Button
var pond_previous: Button
var pond_next: Button
var habitat_buttons: Array[Button] = []
var growth_buttons: Array[Button] = []
var colony_buttons: Array[Button] = []
var continue_button: Button
var journal_button: Button
var journal_close: Button
var repair_button: Button
var travel_button: Button
var help_button: Button
var help_close: Button
var journal_page := 0
var journal_films: Array[Button] = []
var film_watch_button: Button
var film_later_button: Button
var journal_previous: Button
var journal_next: Button
var trait_tooltips: Array[Control] = []
const DishLabels = preload("res://scripts/dish_labels.gd")
var dish_labels := DishLabels.new()
var marker_boxes: Array[Rect2] = []
var specimen_boxes: Dictionary = {}
var rename_button: Button
var name_input: LineEdit
var name_save: Button
var name_cancel: Button
var name_blocker: Control
var rename_token := ""
var name_error := ""
var label_styles := {}
var pip_styles := {}

func _ready() -> void:
	super._ready()
	journal_button = button("Field journal", Vector2.ZERO, Vector2(172, 40), game.toggle_journal, "J")
	film_watch_button = button("Watch film", Vector2(RIGHT, 660), Vector2(COLUMN, 38), watch_new_film)
	film_later_button = button("Later · Journal", Vector2(RIGHT, 704), Vector2(COLUMN, 34), save_new_films_for_later)
	new_button = button("New journey", Vector2.ZERO, Vector2(320, 50), game.new_journey.bind("wanderer"))
	advanced_button = button("Advanced starting colonies", Vector2.ZERO, Vector2(320, 40), toggle_advanced)
	continue_button = button("Continue your journey", Vector2.ZERO, Vector2(320, 50), game.resume_journey)
	pond_button = button("Visit your home pond", Vector2.ZERO, Vector2(320, 40), game.toggle_home_pond)
	pond_previous = button("Previous residents", Vector2(430, 812), Vector2(200, 40), game.home_pond.turn_page.bind(-1))
	pond_next = button("More residents", Vector2(650, 812), Vector2(200, 40), game.home_pond.turn_page.bind(1))
	for i in 2:
		habitat_buttons.append(button("Take the food-rich route" if i == 0 else "Take the sheltered route", Vector2(CHOICE.position.x + 32 + i * 366, CHOICE.position.y + 416), Vector2(320, 46), game.choose_habitat.bind("bloom" if i == 0 else "refuge")))
	growth_buttons.append(button("Grow a guard organelle",Vector2(CHOICE.position.x+32,CHOICE.position.y+416),Vector2(320,50),game.choose_growth_role.bind("guard")))
	growth_buttons.append(button("Grow a feeder organelle",Vector2(CHOICE.position.x+398,CHOICE.position.y+416),Vector2(320,50),game.choose_growth_role.bind("feeder")))
	journal_close = button("Close", Vector2(JOURNAL.end.x - 24 - snug("Close", "J"), JOURNAL.position.y + 22), Vector2(snug("Close", "J"), 38), game.toggle_journal, "J")
	UI.style_button(journal_close, "quiet", 14)
	repair_button = button("Repair", Vector2.ZERO, Vector2(320, 44), game.repair_and_travel)
	travel_button = button("Keep food and travel", Vector2.ZERO, Vector2(320, 44), game.travel_without_evolution)
	for i in 3:
		var colony: Dictionary = Journey.COLONIES[i]
		var control := button(colony.name, Vector2(COLONIES.position.x + 43 + i * 248, COLONIES.position.y + 250), Vector2(220, 48), game.new_journey.bind(colony.id))
		control.tooltip_text = colony.detail + "\n" + colony.unlock
		colony_buttons.append(control)
	for slot in JOURNAL_PAGE_SIZE:
		var control := button("Watch film",Vector2(JOURNAL.position.x+40+(slot%2)*388+18,JOURNAL.position.y+124+(slot/2)*248+80),Vector2(110,32),watch_creature_film.bind(slot))
		UI.style_button(control,"quiet",12)
		journal_films.append(control)
	journal_previous = button("Previous", Vector2(JOURNAL.position.x + 40, JOURNAL.end.y - 72), Vector2(140, 44), turn_journal.bind(-1))
	journal_next = button("Next", Vector2(JOURNAL.end.x - 180, JOURNAL.end.y - 72), Vector2(140, 44), turn_journal.bind(1))
	help_button = button("?", Vector2(RIGHT + COLUMN - 80, 30), Vector2(36, 36), game.toggle_help)
	help_close = button("Close", Vector2(HELP.get_center().x - 90, HELP.end.y - 70), Vector2(180, 44), game.toggle_help, "Esc")
	UI.style_button(help_close, "primary", 15)
	pause_button.set("glyph", "pause")
	pause_button.tooltip_text = "Pause  (Space)"
	for i in TRAIT_LIMIT:
		var tip := Control.new()
		tip.position = Vector2(LEFT - 4, TRAIT_TOP + i * TRAIT_STEP - 18)
		tip.size = Vector2(COLUMN + 8, TRAIT_STEP)
		tip.mouse_filter = Control.MOUSE_FILTER_PASS
		tip.theme = UI.theme()
		add_child(tip)
		trait_tooltips.append(tip)
	rename_button = button("Give it a name", Vector2.ZERO, Vector2(172, 38), begin_rename)
	name_blocker = Control.new()
	name_blocker.size = Vector2(1280, 900)
	name_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(name_blocker)
	name_input = LineEdit.new()
	name_input.position = Vector2(RENAME.position.x + 40, RENAME.position.y + 116)
	name_input.size = Vector2(RENAME.size.x - 80, 48)
	name_input.max_length = 24
	name_input.placeholder_text = "A name for this little life"
	name_input.add_theme_font_size_override("font_size", 18)
	UI.style_line_edit(name_input)
	name_input.text_submitted.connect(func(_text): save_name())
	name_input.gui_input.connect(name_key)
	add_child(name_input)
	name_cancel = button("Cancel", Vector2(RENAME.position.x + 40, RENAME.end.y - 78), Vector2(220, 44), cancel_rename, "Esc")
	name_save = button("Save name", Vector2(RENAME.end.x - 260, RENAME.end.y - 78), Vector2(220, 44), save_name, "Enter")
	UI.style_button(name_save, "primary", 15)
	refresh()

func managed_controls() -> Array:
	return [pause_button, restart_button, debug_button, mode_button, motion_button, center_button, sound_button, journal_button, film_watch_button, film_later_button, help_button, help_close, new_button, continue_button, pond_button, advanced_button, pond_previous, pond_next, journal_close, journal_previous, journal_next, repair_button, travel_button, rename_button, name_blocker, name_input, name_save, name_cancel] + journal_films + habitat_buttons + growth_buttons + colony_buttons + cards + trait_tooltips

## Each screen lists only the controls it needs; everything else is hidden.
func refresh() -> void:
	if help_button == null:
		return
	var run = game.run
	var state: String = run.state
	var home: bool = state == "home"
	var habitat: bool = home and game.home_pond_open
	var blocked: bool = game.settings_open or game.journal_open or game.help_open or renaming() or (game.evolution_reveal != null and game.evolution_reveal.visible)
	var overlay: bool = not home and not blocked and state in ["brief", "paused", "loss", "success"] and overlay_visible() and not game.round_result_showing()
	var shown: Array = []
	if renaming():
		shown.append_array([name_blocker, name_input, name_save, name_cancel])
	elif game.journal_open:
		shown.append(journal_close)
		for slot in JOURNAL_PAGE_SIZE:
			var i := journal_page*JOURNAL_PAGE_SIZE+slot
			if i<Journey.SPECIES.size() and game.creature_cinema!=null:
				var id: String = Journey.SPECIES[i].id
				if game.journey_profile.discovered.has(id) or run.seen_species.has(id): shown.append(journal_films[slot])
		if journal_page > 0:
			shown.append(journal_previous)
		if (journal_page + 1) * JOURNAL_PAGE_SIZE < Journey.SPECIES.size():
			shown.append(journal_next)
	elif game.help_open:
		shown.append(help_close)
	elif blocked:
		pass
	elif home:
		shown.append_array(refresh_home(habitat))
	else:
		shown.append_array(refresh_encounter(overlay))
	for control in managed_controls():
		control.visible = shown.has(control)
	refresh_settings()
	title_screen.configure(self)
	queue_redraw()

func refresh_home(habitat: bool) -> Array:
	var shown: Array = []
	if habitat:
		var x := RIGHT
		var y := 612.0
		var record: Dictionary = game.home_pond.selected_record()
		if not record.is_empty():
			place(rename_button, Vector2(x, 548), Vector2(COLUMN, 38), "secondary", "Give it a name" if record.get("nickname", "").is_empty() else "Change its name", "", 13)
			shown.append(rename_button)
		if not game.resume_data.is_empty():
			place(continue_button, Vector2(x, y), Vector2(COLUMN, 44), "primary", "View journey" if game.resume_data.snapshot.run.state == "success" else "Continue journey", "", 14)
			shown.append(continue_button)
			y += 54.0
		place(new_button, Vector2(x, y), Vector2(COLUMN, 40), "secondary" if not game.resume_data.is_empty() else "primary", "New journey", "", 14)
		place(journal_button, Vector2(x, y + 50), Vector2(COLUMN, 40), "secondary", "Field journal", "J", 14)
		place(sound_button, Vector2(x, y + 100), Vector2(COLUMN, 40), "secondary", "Settings", "V", 14)
		place(pond_button, Vector2(x + (COLUMN - snug("Back to menu", "Esc", 13)) * 0.5, y + 150), Vector2(snug("Back to menu", "Esc", 13), 36), "quiet", "Back to menu", "Esc", 13)
		shown.append_array([new_button, journal_button, sound_button, pond_button])
		if game.home_pond.page > 0:
			shown.append(pond_previous)
		if (game.home_pond.page + 1) * game.home_pond.PAGE_SIZE < game.journey_profile.residents.size():
			shown.append(pond_next)
		for control in [pond_previous, pond_next]:
			UI.style_button(control, "secondary", 14)
	elif advanced_open:
		for i in colony_buttons.size():
			colony_buttons[i].disabled = not game.journey_profile.unlocked(Journey.COLONIES[i].id)
			place(colony_buttons[i], Vector2(COLONIES.position.x + 43 + i * 248, COLONIES.position.y + 250), Vector2(220, 48), "secondary", Journey.COLONIES[i].name if not colony_buttons[i].disabled else "Not yet discovered", "", 15)
		place(advanced_button, Vector2(COLONIES.get_center().x - snug("Back") * 0.5, COLONIES.end.y - 68), Vector2(snug("Back"), 40), "quiet", "Back", "", 14)
		shown.append_array(colony_buttons + [advanced_button])
	else:
		shown.append_array([new_button, pond_button, advanced_button, help_button, journal_button, sound_button])
		if not game.resume_data.is_empty():
			shown.append(continue_button)
	return shown

func refresh_encounter(overlay: bool) -> Array:
	var run = game.run
	var state: String = run.state
	var shown: Array = []
	var middle := 640.0
	if state == "active":
		place(help_button, Vector2(RIGHT + COLUMN - 80, 30), Vector2(36, 36), "icon", "?", "", 16)
		place(pause_button, Vector2(RIGHT + COLUMN - 36, 30), Vector2(36, 36), "icon", " ", "", 15)
		help_button.tooltip_text = "How to play  (H)"
		pause_button.disabled = false
		shown.append_array([help_button, pause_button])
		if game.creature_cinema != null and not game.creature_cinema.pending_ids.is_empty():
			place(film_watch_button, Vector2(RIGHT, 660), Vector2(COLUMN, 38), "primary", "Watch film", "", 13)
			place(film_later_button, Vector2(RIGHT, 704), Vector2(COLUMN, 34), "quiet", "Later · Journal", "", 12)
			shown.append_array([film_watch_button, film_later_button])
		for i in trait_tooltips.size():
			if i < run.mutations.size():
				var definition: Dictionary = Mutations.journey_definition(run.mutations[i])
				trait_tooltips[i].tooltip_text = definition.name + "\n" + definition.detail + "\n" + definition.tradeoff
				shown.append(trait_tooltips[i])
	elif state == "brief":
		place(help_button, Vector2(RIGHT + COLUMN - 36, 30), Vector2(36, 36), "icon", "?", "", 16)
		help_button.tooltip_text = "How to play  (H)"
		shown.append(help_button)
		if run.growth_slot() >= 0:
			for i in growth_buttons.size():
				place(growth_buttons[i],Vector2(CHOICE.position.x+32+i*366,CHOICE.position.y+416),Vector2(320,50),"primary" if i==0 else "secondary","Guard · stop one hunter" if i==0 else "Feeder · reward wide meals","",14)
				shown.append(growth_buttons[i])
		elif run.Habitats.pending(run):
			for i in habitat_buttons.size():
				place(habitat_buttons[i], Vector2(CHOICE.position.x + 32 + i * 366, CHOICE.position.y + 416), Vector2(320, 46), "secondary", "", "", 15)
			shown.append_array(habitat_buttons)
		elif overlay:
			var brief := brief_rect()
			place(center_button, Vector2(middle - 140, brief.end.y - 76), Vector2(280, 48), "primary", "Begin encounter", "Enter")
			place(restart_button, Vector2(brief.position.x + 24, brief.end.y - 70), Vector2(snug("Return home", "", 13), 36), "quiet", "Return home", "", 13)
			shown.append_array([center_button, restart_button])
	elif run.evolution_ready() and not game.round_result_showing():
		var first_choice: bool = run.mutations.is_empty() and run.offered_mutations.size() == 2
		var top := EVOLVE.position.y + 160.0
		for i in cards.size():
			if i < run.offered_mutations.size():
				cards[i].guided_choice = first_choice
				cards[i].reduced_motion = game.reduced_motion
				cards[i].cost = run.evolution_cost()
				cards[i].balance = run.biomass
				cards[i].position = Vector2(277 + i * 378, top) if first_choice else Vector2(270 + i * 252, top)
				cards[i].size = Vector2(350, 346) if first_choice else Vector2(236, 346)
				cards[i].disabled = run.biomass < run.evolution_cost()
				cards[i].text_multiplier = 1.05 if game.large_text else 1.0
				cards[i].configure(Mutations.journey_definition(run.offered_mutations[i]), i, run.mutations)
				shown.append(cards[i])
		var row := EVOLVE.end.y - 128.0 if not run.offered_mutations.is_empty() else REST.end.y - 108.0
		var span := (EVOLVE if not run.offered_mutations.is_empty() else REST)
		var width := 320.0 if span == EVOLVE else 270.0
		repair_button.disabled = run.integrity >= run.max_integrity or run.biomass < run.repair_cost() or run.repair_waiting() or run.repair_needs_deeper_wound()
		place(repair_button, Vector2(middle - width - 8, row), Vector2(width, 44), "secondary", "Mother is healthy, no repair needed" if run.integrity >= run.max_integrity else "Repair needs two wounded cores" if run.repair_needs_deeper_wound() else "Repair tissue still resting" if run.repair_waiting() else "Repair +%d health for %d food" % [mini(2, run.max_integrity - run.integrity), run.repair_cost()], "", 14)
		repair_button.tooltip_text = "Late-route repair becomes available when at least two cores are wounded." if run.repair_needs_deeper_wound() else "Repair becomes available after the next encounter." if run.repair_waiting() else "Restore up to 2 of the mother's %d health cores, then travel. You have %d food; repair costs %d." % [run.max_integrity, run.biomass, run.repair_cost()]
		place(travel_button, Vector2(middle + 8, row), Vector2(width, 44), "secondary", "Keep all %d food and travel" % run.biomass, "", 14)
		travel_button.tooltip_text = "Skip this upgrade. Your saved food carries into the next encounter."
		place(restart_button, Vector2(span.position.x + 24, span.end.y - (62.0 if span == EVOLVE else 54.0)), Vector2(snug("Save and return home", "", 13), 36), "quiet", "Save and return home", "", 13)
		shown.append_array([repair_button, travel_button, restart_button])
	elif state == "paused" and overlay:
		var y := MENU.position.y + 176.0
		place(center_button, Vector2(MENU.position.x + 40, y), Vector2(MENU.size.x - 80, 48), "primary", "Resume", "Space")
		place(help_button, Vector2(MENU.position.x + 40, y + 60), Vector2(MENU.size.x - 80, 44), "menu", "How to play", "H")
		place(journal_button, Vector2(MENU.position.x + 40, y + 106), Vector2(MENU.size.x - 80, 44), "menu", "Field journal", "J")
		place(sound_button, Vector2(MENU.position.x + 40, y + 152), Vector2(MENU.size.x - 80, 44), "menu", "Settings", "V")
		place(restart_button, Vector2(MENU.position.x + 40, y + 218), Vector2(MENU.size.x - 80, 44), "menu", "Save and return home", "")
		shown.append_array([center_button, help_button, journal_button, sound_button, restart_button])
		if game.developer_tools:
			place(debug_button, Vector2(RIGHT, 721), Vector2(COLUMN, 38), "quiet", "Hide inspect" if game.debug_mode else "Inspect dish", "D", 13)
			shown.append(debug_button)
	elif state == "loss" and overlay:
		place(center_button, Vector2(middle - 140, loss_rect().end.y - 80), Vector2(280, 48), "primary", "Retry encounter", "Enter")
		shown.append(center_button)
	elif state == "success" and overlay:
		place(center_button, Vector2(middle - 300, 762), Vector2(290, 48), "primary", "Visit your home pond", "Enter")
		place(journal_button, Vector2(middle + 10, 762), Vector2(290, 48), "secondary", "Field journal", "J")
		shown.append_array([center_button, journal_button])
	return shown

func trait_y(index: int) -> float:
	return TRAIT_TOP + index * TRAIT_STEP

func pip_box(lit: bool, low: bool) -> StyleBoxFlat:
	var key := "%s:%s" % [lit, low]
	if not pip_styles.has(key):
		pip_styles[key] = UI.box((UI.DANGER if low else CYAN) if lit else Color(1, 1, 1, 0.1), 3, Color.TRANSPARENT, Vector2.ZERO)
	return pip_styles[key]

## A compact map of the whole journey, used where you plan rather than play.
func route_map(origin: Vector2, width: float) -> void:
	var run = game.run
	var total: int = run.encounter_total()
	if total < 2:
		return
	var spacing := width / float(total - 1)
	var centers := [0.0, 0.0, 0.0]
	var counts := [0, 0, 0]
	var points: Array[Vector2] = []
	for i in total:
		var destination: String = run.habitat_history.get("route:%d" % i if not run.route_plan.is_empty() else str(i), "")
		points.append(origin + Vector2(i * spacing, 5.0 if destination == "refuge" else -5.0 if destination == "bloom" else 0.0))
	for i in total - 1:
		draw_line(points[i], points[i + 1], Color(1, 1, 1, 0.1), 1.0, true)
	for i in total:
		var stage: int = int(run.route_plan[i].stage) if not run.route_plan.is_empty() else i
		var dish: Dictionary = Journey.DISHES[stage / 4]
		var reached: bool = i <= run.encounter_index()
		var color: Color = dish.color if reached else Color(1, 1, 1, 0.2)
		draw_circle(points[i], 4.5 if stage % 4 == 3 else 2.5, color, true, -1, true)
		if i == run.encounter_index():
			draw_arc(points[i], 8.5, 0, TAU, 40, color, 1.2, true)
		centers[stage / 4] += points[i].x
		counts[stage / 4] += 1
	for i in 3:
		if counts[i] > 0:
			centered(Journey.DISHES[i].name, origin.y + 26.0, 11, Color(Journey.DISHES[i].color, 0.8), UI.MEDIUM, centers[i] / counts[i])

func _draw() -> void:
	if game == null or help_button == null:
		return
	if game.evolution_reveal != null and game.evolution_reveal.visible:
		return
	var run = game.run
	var topmost: bool = game.settings_open or game.journal_open or game.help_open
	if run.state == "home":
		draw_home()
	else:
		draw_status()
		if run.state == "active" and not topmost:
			draw_targets()
			draw_nudge()
			draw_big_capture()
			if run.selection.mother_blocked():
				# HUD draws above the living tissue, keeping the warning visible.
				draw_circle(run.board.center, 58.0, Color("d9b58b"), false, 1.5, true)
		if not topmost:
			if run.state == "brief":
				scrim()
				if run.growth_slot() >= 0:
					draw_growth_choice()
				elif run.Habitats.pending(run):
					draw_habitats()
				else:
					draw_brief()
			elif game.round_result_showing():
				draw_round_result_cue()
			elif run.evolution_ready() and run.offered_mutations.is_empty():
				scrim()
				draw_rest()
			elif run.evolution_ready():
				scrim()
				draw_evolution()
			elif run.state in ["paused", "loss", "success"] and overlay_visible():
				draw_result()
	if game.settings_open:
		draw_sound_settings()
	elif game.journal_open:
		draw_journal()
	elif game.help_open:
		draw_help()
	if renaming():
		draw_rename()

func draw_status() -> void:
	var run = game.run
	if run.state == "success":
		draw_ending_status()
		return
	var harvest = run.harvest
	var spec: Dictionary = harvest.spec
	var dish: Dictionary = Journey.dish(run.stage_index)
	# Left column: where you are, the mother, and what the colony carries.
	label_at(dish.name, Vector2(LEFT, 52), 15, dish.color, UI.SEMIBOLD)
	label_at("Encounter %d of %d" % [run.encounter_index() + 1, run.encounter_total()], Vector2(LEFT, 74), 12, MUTED)
	if run.Habitats.available(run) and run.habitat_confirmed:
		label_at(run.Habitats.name_for(run.stage_index, run.habitat_choice), Vector2(LEFT, 93), 12, Color(dish.color, 0.75))
	var low: bool = run.integrity <= 2
	label_at("Mother", Vector2(LEFT, 152), 13, MUTED)
	right_at("%d of %d" % [run.integrity,run.max_integrity], Vector2(LEFT + COLUMN, 152), 13, UI.DANGER if low else INK, UI.MEDIUM)
	var pip_step: float = minf(35.5,COLUMN / float(run.max_integrity))
	for i in run.max_integrity:
		draw_style_box(pip_box(i < run.integrity, low), Rect2(LEFT + i * pip_step, 164, pip_step - 5.0, 6))
	var organelle_status: Array[String] = []
	if run.growth_roles.values().has("guard"):
		var ready_guards: int = maxi(0,run.growth_active("guard")-run.guardian_spent)
		var guard_status := "Guard %d ready" % ready_guards if ready_guards>0 else "Guard wounded" if run.growth_active("guard")==0 else "Guard recovering" if run.guardian_recovery==0 else "Guard spent"
		organelle_status.append(guard_status)
	if run.growth_roles.values().has("feeder"):
		var active_feeders: int = run.growth_active("feeder")
		organelle_status.append("Feeder %d active" % active_feeders if active_feeders>0 else "Feeder wounded")
	if not organelle_status.is_empty():
		wrapped(" · ".join(organelle_status),Vector2(LEFT,190),COLUMN,11,CYAN)
	label_at("Food saved", Vector2(LEFT, 214), 13, MUTED)
	label_at(str(run.biomass), Vector2(LEFT - 1, 254), 32, UI.FOOD, UI.SEMIBOLD)
	if run.biomass >= 30:
		label_at("Stores full", Vector2(LEFT + measure(str(run.biomass), 32, UI.SEMIBOLD) + 10, 254), 12, MUTED)
	label_at("Score  %d" % run.score, Vector2(LEFT, 281), 13, CYAN, UI.MEDIUM)
	label_at(UI.sentence(Mutations.build_name(run.mutations)), Vector2(LEFT, 304), 13, CYAN, UI.SEMIBOLD)
	if run.mutations.is_empty():
		wrapped("Choose your first upgrade." if run.evolution_ready() else "Your first upgrade comes after this encounter.", Vector2(LEFT, trait_y(0)), COLUMN, 13, MUTED)
	for i in mini(TRAIT_LIMIT, run.mutations.size()):
		label_at(Mutations.journey_definition(run.mutations[i]).name, Vector2(LEFT, trait_y(i)), 13, INK)
	if run.mutations.size() > TRAIT_LIMIT:
		label_at("+%d more" % (run.mutations.size() - TRAIT_LIMIT), Vector2(LEFT, trait_y(TRAIT_LIMIT)), 12, MUTED)
	if game.debug_mode:
		label_at("Ready triangles %d" % run.board.available_triangles(run.is_ready), Vector2(LEFT, 846), 11, CYAN)
	if game.save_message.begins_with("Could not"):
		wrapped(game.save_message, Vector2(LEFT, 868), COLUMN, 12, UI.DANGER)
	if run.evolution_ready():
		return
	# Right column: the goal, then the single most useful next action.
	var y := wrapped(spec.name, Vector2(RIGHT, 112), COLUMN, 19, INK, UI.SEMIBOLD) + 38.0
	if spec.mode == "boss":
		var hits_left := maxi(0, 3 - harvest.boss_hits)
		label_at("%d hit%s left" % [hits_left, "" if hits_left == 1 else "s"], Vector2(RIGHT, y), 24, INK, UI.SEMIBOLD)
		var attacks: int = harvest.nourishment / 3
		y += 26.0
		label_at("%d attack%s charged" % [attacks, "" if attacks == 1 else "s"], Vector2(RIGHT, y), 13, UI.FOOD, UI.MEDIUM)
		y += 21.0
		label_at("%d of 6 charge, 3 per hit" % harvest.nourishment, Vector2(RIGHT, y), 12, MUTED)
	else:
		label_at("%d / %d food" % [harvest.nourishment, spec.food], Vector2(RIGHT, y), 24, UI.FOOD, UI.SEMIBOLD)
		var objective := Guidance.objective_text(run)
		if not objective.is_empty():
			y += 25.0
			label_at(objective, Vector2(RIGHT, y), 13, CYAN, UI.MEDIUM)
	var remaining := maxi(0, ceili(run.harvest.deadline() - run.stage_elapsed))
	y += 22.0
	label_at("Practice, no time limit" if run.Lesson.active(run) else "%d:%02d left" % [remaining / 60, remaining % 60], Vector2(RIGHT, y), 13, UI.DANGER if remaining < 20 else MUTED)
	if run.state in ["active", "paused"]:
		var guide: Dictionary = Guidance.next_action(run, game.click_mode)
		var title_bottom := wrapped(guide.title, Vector2(RIGHT, y + 56.0), COLUMN, 17, UI.DANGER if guide.urgent else INK, UI.SEMIBOLD)
		wrapped(guide.detail, Vector2(RIGHT, title_bottom + 27.0), COLUMN, 13, Color(UI.DANGER, 0.85) if guide.urgent else MUTED)
		if not run.Lesson.active(run) and nudge_relevant():
			draw_nudge_meter()
	if run.state == "active" and game.creature_cinema != null and not game.creature_cinema.pending_ids.is_empty():
		var count: int = game.creature_cinema.pending_ids.size()
		draw_style_box(UI.toast_box(), Rect2(RIGHT - 10, 598, COLUMN + 20, 154))
		label_at("NEW DISCOVERY", Vector2(RIGHT, 620), 11, CYAN, UI.SEMIBOLD)
		wrapped("%d new film%s" % [count, "s" if count != 1 else ""], Vector2(RIGHT, 639), COLUMN, 13, INK, UI.MEDIUM)
	draw_feedback()

## Loop preview or the latest toast, below the lens. Shared with practice HUDs.
func draw_feedback() -> void:
	var run = game.run
	if run.state != "active":
		return
	if run.selection.can_close():
		var preview: Dictionary = run.harvest_preview()
		var outcomes: Array[String] = []
		if preview.food > 0:
			outcomes.append("+%d food" % preview.food)
		if preview.boss_layers > 0:
			outcomes.append("1 boss hit, −3 charge")
		elif preview.get("wardens", 0) > 0:
			outcomes.append("%d shields broken" % preview.wardens)
		elif preview.rescued > 0:
			outcomes.append("%d rescued" % preview.rescued)
		elif preview.purified > 0:
			outcomes.append("%d poison cleared" % preview.purified)
		elif preview.threats > 0:
			outcomes.append("%d threat%s captured" % [preview.threats, "s" if preview.threats != 1 else ""])
		if outcomes.is_empty():
			outcomes.append("No food collected")
		outcomes.append("−%d health" % preview.poison if preview.poison > 0 else "No health lost")
		var strain: float = LoopStrain.penalty(run.selection.path, run.board.anchors)
		var return_time: float = Mutations.recovery(run.mutations, run.selection.path.size(), run.board.tuning.recovery_seconds) + strain
		var benefit := Mutations.food_bonus_text(preview)
		var timing := "Cells return in %.1fs · long links +%.1fs" % [return_time, strain] if strain >= 0.1 else "Cells return in %.1fs" % return_time
		# Feedback belongs below the lens: lower cells remain visible and
		# selectable throughout a gesture, even with a two-line preview.
		toast_panel("  ·  ".join(outcomes), "Includes " + benefit + "  ·  " + timing if not benefit.is_empty() else timing, UI.DANGER if preview.poison > 0 else CYAN)
	elif game.toast_time > 0.0:
		toast_panel(game.toast, "", CYAN)

func nudge_relevant() -> bool:
	var run = game.run
	if run.phages.free_cluster() != null or run.nudge.target_id >= 0:
		return true
	for body in run.enemies:
		if body.kind == "cyst":
			return true
	return false

func draw_nudge_meter() -> void:
	var run = game.run
	var recharge: float = run.nudge.cooldown
	var y := 790.0
	label_at("Nudge", Vector2(RIGHT, y), 13, MUTED)
	right_at("Ready" if recharge <= 0.0 else "%ds" % ceili(recharge), Vector2(RIGHT + COLUMN, y), 13, CYAN if recharge <= 0.0 else MUTED, UI.MEDIUM)
	draw_style_box(pip_box(false, false), Rect2(RIGHT, y + 10, COLUMN, 3))
	var fill: float = COLUMN * (1.0 - recharge / run.nudge.COOLDOWN)
	if fill > 2.0:
		draw_rect(Rect2(RIGHT, y + 10, fill, 3), Color(CYAN, 0.75 if recharge <= 0.0 else 0.4))
	wrapped("Guide silver phages to copper rods" if run.phages.free_cluster() != null else "Click a cyst, then clear water" if game.click_mode else "Drag a purple cyst aside", Vector2(RIGHT, y + 34), COLUMN, 12, UI.FAINT)

## Feedback below the lens, sized to its text and growing upward if needed.
func toast_panel(main: String, detail: String, color: Color) -> void:
	var size_px := 15 if not detail.is_empty() else 14
	var actual := scaled(size_px, true)
	var lines := lines_for(main, 700.0, actual, UI.MEDIUM)
	var width := 0.0
	for line in lines:
		width = maxf(width, UI.text_font(actual, UI.MEDIUM).get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, actual).x)
	if not detail.is_empty():
		width = maxf(width, measure(detail, 12))
	width = minf(760.0, width + 44.0)
	var height := 22.0 + lines.size() * line_step(actual) + (18.0 if not detail.is_empty() else 0.0)
	var box := Rect2(640.0 - width * 0.5, 894.0 - height, width, height)
	draw_style_box(UI.toast_box(), box)
	var y := wrapped_centered(main, box.position.y + 10.0 + actual, 700.0, size_px, color, UI.MEDIUM)
	if not detail.is_empty():
		centered(detail, y + 20.0, 12, MUTED)

func visual_box(item: CanvasItem, rect: Rect2) -> Rect2:
	return (global_transform.affine_inverse()*item.get_global_transform()*rect).grow(6.0)

func prepare_labels() -> void:
	var occupied: Array[Rect2] = []
	var scope = game.microscope
	specimen_boxes.clear()
	for sprite in scope.cells+scope.buds+[scope.mother]+scope.phage_visual.sprites.values():
		if sprite.is_visible_in_tree() and sprite.modulate.a>0.05:
			occupied.append(visual_box(sprite,sprite.get_rect()))
	for body in game.run.enemies:
		var bounds := Rect2(body.nucleus-Vector2.ONE*18.0,Vector2.ONE*36.0)
		var visual: Node2D = scope.enemies.get(body.id)
		if visual!=null:
			for lobe in visual.get_meta("lobes",[]):
				var rect: Rect2 = Rect2(Vector2.ZERO,lobe.size) if lobe is Control else lobe.get_rect()
				bounds = bounds.merge(visual_box(lobe,rect))
		# Union covers the connecting tissue of twins and the amoeba's reach.
		specimen_boxes[body.get_instance_id()] = bounds
		occupied.append(bounds)
	for pulse in scope.pulses:
		var surface: ColorRect = pulse.get_meta("surface")
		if surface.is_visible_in_tree():
			occupied.append(visual_box(surface,Rect2(Vector2.ZERO,surface.size)))
	for group in game.run.phages.clusters:
		if group.host_id<0:
			var bounds := Rect2(group.nucleus-Vector2.ONE*33.0,Vector2.ONE*66.0)
			specimen_boxes[group.get_instance_id()] = bounds
			occupied.append(bounds)
	dish_labels.begin(occupied,game.run.selection.active or game.run.nudge.target(game.run)!=null)
	marker_boxes = dish_labels.boxes

func water_label(key: String, anchor: Rect2, title: String, color: Color) -> void:
	var actual := scaled(11)
	var size := Vector2(measure(title, 11, UI.MEDIUM) + 16.0, actual + 12.0)
	var box: Rect2 = dish_labels.place(key,anchor,size)
	if not box.has_area(): return
	var center := anchor.get_center()
	var from := Vector2(clampf(center.x,box.position.x,box.end.x),clampf(center.y,box.position.y,box.end.y))
	var to := Vector2(clampf(from.x,anchor.position.x,anchor.end.x),clampf(from.y,anchor.position.y,anchor.end.y))
	if dish_labels.clear_leader(from,to):
		draw_line(from,to,Color(color,0.35),1.0,true)
	draw_style_box(label_style(color),box)
	label_at(title, box.position + Vector2(8, actual + 2), 11, color, UI.MEDIUM)

func label_style(color: Color) -> StyleBoxFlat:
	var key := color.to_html()
	if not label_styles.has(key):
		label_styles[key] = UI.box(Color(0.016, 0.043, 0.052, 0.84), 6, Color(color, 0.28), Vector2.ZERO)
	return label_styles[key]

func marker(body: RefCounted, title: String, color: Color) -> void:
	var bounds: Rect2 = specimen_boxes.get(body.get_instance_id(),Rect2(body.nucleus-Vector2.ONE*25.0,Vector2.ONE*50.0))
	water_label("body:%d" % body.get_instance_id(),bounds,title,color)
	# Capture centers remain visible when labels yield to a gesture or crowding.
	for point in body.nuclei():
		for quadrant in 4:
			var angle := quadrant * PI/2.0 + 0.15
			draw_arc(point,13.0,angle,angle+0.7,9,Color(color,0.7),1.0,true)

func draw_nudge() -> void:
	var run = game.run
	var nudge = run.nudge
	var body = nudge.target(run)
	if body!=null:
		var from: Vector2 = body.nucleus
		var move: Vector2 = nudge.displacement(run)
		var to := from+move
		draw_arc(from,26.0,0,TAU,48,Color(CYAN,0.75),1.2,true)
		if move.length()>=nudge.MIN_DRAG:
			var direction := move.normalized()
			draw_line(from+direction*18.0,to,CYAN,1.6,true)
			draw_polyline(PackedVector2Array([to-direction.rotated(-0.5)*9.0,to,to-direction.rotated(0.5)*9.0]),CYAN,1.6,true)
			draw_arc(to,19.0,0,TAU,40,Color(CYAN,0.35),1.0,true)
		return
	var hovered = nudge.pick(run,game.get_global_mouse_position())
	if hovered!=null:
		draw_arc(hovered.nucleus,26.0,0,TAU,48,Color(CYAN,0.75 if nudge.cooldown<=0.0 else 0.3),1.2,true)
	var teach = nudge.teaching_target(run)
	if teach!=null and not Guidance.next_action(run,game.click_mode).urgent:
		marker(teach,"CLICK CYST TO NUDGE" if game.click_mode else "DRAG CYST TO NUDGE",CYAN)

func draw_targets() -> void:
	var run = game.run
	prepare_labels()
	if run.Lesson.active(run):
		draw_lesson()
		return
	draw_approaching_life()
	for group in run.phages.clusters:
		if group.host_id<0 and group.age>2.5 and (not run.phages.learned or group.nucleus.distance_to(game.get_global_mouse_position())<40):
			marker(group,"PHAGES · DRAG TO ROD",CYAN)
	for hunter in run.enemies:
		if hunter.kind=="bacterium":
			marker(hunter,"INFECTED · %ds" % ceili(hunter.infection_remaining()) if hunter.infection_age>=0.0 else "FOOD THIEF",Color("bacbe5") if hunter.infection_age>=0.0 else Color("dbbf95"))
		if hunter.kind=="amoeba":
			if hunter.captive_node>=0:
				marker(hunter,"SAVE CELL · %ds" % ceili(hunter.rescue_remaining()),Color("efb29f") if hunter.rescue_remaining()<5.0 else Color("e5cea2"))
			elif hunter.phase=="reaching":
				marker(hunter,"REACHING",Color("e5cea2"))
		if hunter.hunt_target>=0:
			var prey = run.harvest.ecology.prey_for(run,hunter)
			if prey != null and prey.kind!="spore" and hunter.hunt_time>0.0:
				marker(hunter,"FEEDING · %ds" % ceili(6.0-hunter.hunt_time),Color("dbbf95"))
	if run.harvest.spec.mode == "sectors":
		for i in 8:
			var start := i*TAU/8.0 - TAU/16.0 + 0.025
			var finish := start + TAU/8.0 - 0.05
			var edge := Vector2.from_angle(start-0.025)
			draw_line(run.board.center+edge*80.0, run.board.center+edge*387.0, Color(0.35,0.58,0.62,0.12), 1.0, true)
			var visited: bool = run.harvest.visited.has(i)
			draw_arc(run.board.center, 387, start, finish, 28, CYAN if visited else Color("3f5c63"), 3.0 if visited else 1.5, true)
	var boss = run.boss()
	if boss != null:
		marker(boss, boss.status_text(), CYAN if boss.can_take_pulse() else Color("c4be9d"))
	var guide: Dictionary = Guidance.next_action(run, game.click_mode)
	draw_ecology(guide.target)
	for body in run.enemies:
		if body.id == guide.target and body != boss:
			if body.cradle or body.kind in ["amoeba","bacterium"]:
				continue # Its choice/predation marker already supplies the relevant deadline.
			var caption: String = {"food":"LOOP AROUND FOOD", "cyst":"POISON ONLY", "spore":"RESCUE", "drifter":"HUNTER", "shellback":"ARMORED HUNTER", "twinspore":"BOTH CENTERS", "grazer":"GRAZER", "parasite":"PARASITE", "divider":"DIVIDER", "warden":"BREAK SHIELD"}.get(body.kind,"TARGET")
			if body.kind=="spore":
				var eating: float = run.harvest.ecology.eating_progress(run,body.id)
				caption = "RESCUE IN %ds" % ceili(6.0*(1.0-eating)) if eating>0.0 else "ESCAPES IN %ds" % ceili(body.lifetime()-body.age)
			elif body.kind=="divider" and not body.daughter:
				caption = "SPLITS IN %ds" % ceili(body.split_remaining())
			elif body.kind=="grazer" and body.stored_food>0:
				caption = "GRAZER · %d FOOD" % body.stored_food
			if guide.urgent and Guidance.contact_seconds(run, body) < 20.0:
				caption = "MOTHER IN ~%ds" % ceili(Guidance.contact_seconds(run, body))
				var end: Vector2 = run.board.center + (body.nucleus-run.board.center).normalized()*62.0
				draw_dashed_line(body.nucleus,end,Color(0.94,0.66,0.77,0.32),1.0,5.0,true,true)
			marker(body, caption, Color("efa8c5") if guide.urgent else CYAN)
			break

func draw_approaching_life() -> void:
	var run = game.run
	var event: Dictionary = run.harvest.HabitatEvents.sample(run)
	if not event.is_empty() and event.kind=="hatching" and event.age>=0.0 and event.age<22.0:
		for at in run.harvest.event_state.sites:
			var color := Color("ba9cab") if event.age<14.0 else Color("efa8c5")
			draw_arc(at,24,0.3,5.8,32,Color(color,0.5),1.0,true)
			water_label("cyst-site:%s" % at,Rect2(at-Vector2.ONE*24.0,Vector2.ONE*48.0),"CYSTS IN %ds" % ceili(22.0-event.age),color)
	var visitor_in: float = run.harvest.visitor_at-run.stage_elapsed
	if not run.harvest.visitor_spawned and visitor_in>0.0 and visitor_in<=8.0:
		var at: Vector2 = run.harvest.Discoveries.site(run)
		draw_arc(at,34,0.3,4.9,32,Color(0.76,0.82,0.96,0.35),1.0,true)
		water_label("visitor-site",Rect2(at-Vector2.ONE*34.0,Vector2.ONE*68.0),"VISITOR · %ds" % ceili(visitor_in),Color("c7caea"))
	for site in Rhythm.warning_sites(run):
		var p: Vector2 = site.position
		var amount := 1.0-float(site.remaining)/8.0
		var color := Color("a1ddd5") if site.kind=="grazer" else Color("dbbf95")
		var radius := lerpf(42.0,28.0,amount)
		# Irregular broken arcs read as a disturbance below the focal plane.
		for i in 3:
			var angle: float = TAU*i/3.0 + (0.0 if game.reduced_motion else game.visual_time*0.09)
			draw_arc(p,radius,angle,angle+1.1,20,Color(color,0.18+amount*0.2),1.0,true)
		water_label("arrival:%s" % p,Rect2(p-Vector2.ONE*radius,Vector2.ONE*radius*2.0),"%s · %ds" % [{"bacterium":"BACTERIUM", "amoeba":"AMOEBA", "hunter":"HUNTER", "grazer":"FOOD THIEF", "parasite":"PARASITE", "divider":"DIVIDER"}.get(site.kind,"ARRIVAL"), ceili(site.remaining)],color)

func draw_growth_choice() -> void:
	var run = game.run
	dialog(CHOICE)
	centered("The Mother has grown a new organelle",CHOICE.position.y+100,30)
	centered("Choose what this living tissue will do.",CHOICE.position.y+135,15,MUTED)
	for i in 2:
		var x := CHOICE.position.x+32+i*366.0
		var card := Rect2(x,CHOICE.position.y+192,320,208)
		draw_style_box(UI.card_box(),card)
		label_at("GUARD" if i==0 else "FEEDER",Vector2(x+22,card.position.y+42),13,CYAN,UI.SEMIBOLD)
		label_at("A safer center" if i==0 else "More from a wide meal",Vector2(x+22,card.position.y+79),19,INK,UI.SEMIBOLD)
		wrapped("Blocks one hunter, then rests through two encounters." if i==0 and run.encounter_total()==30 else "Blocks one hunter that reaches Mother each encounter." if i==0 else "Clean loops with four or more food gain one extra food.",Vector2(x+22,card.position.y+111),276,15,MUTED)
		wrapped("If this organelle is wounded, its ability sleeps until repaired.",Vector2(x+22,card.position.y+177),276,13,MUTED)
	centered("%d health organelles now · both choices can be repaired" % run.max_integrity,CHOICE.end.y-42,13,MUTED)

func draw_habitats() -> void:
	var run = game.run
	dialog(CHOICE)
	route_map(Vector2(CHOICE.position.x + 70, CHOICE.position.y + 44), CHOICE.size.x - 140)
	centered("Choose where to travel", CHOICE.position.y + 124, 30)
	var route_context := "Original 30-encounter save · routes lead through %s." % Journey.dish(run.stage_index).name if run.encounter_total()==30 else "Both routes lead onward through %s." % Journey.dish(run.stage_index).name
	centered(route_context, CHOICE.position.y + 152, 14, MUTED)
	for i in 2:
		var x := CHOICE.position.x + 16 + i * 366.0 + 16
		var card := Rect2(x - 16, CHOICE.position.y + 176, 352, 306)
		var tint := Color("b8dc9f") if i == 0 else Color("a2ccde")
		draw_style_box(UI.card_box(), card)
		label_at(run.Habitats.name_for(run.stage_index, "bloom" if i == 0 else "refuge"), Vector2(x + 8, card.position.y + 44), 20, tint, UI.SEMIBOLD)
		var texture: Texture2D = game.microscope.enemy_texture("food" if i == 0 else "spore", "" if i == 0 else run.harvest.Discoveries.form_for(run))
		draw_texture_rect(texture, Rect2(card.end.x - 92, card.position.y + 18, 68, 68), false)
		var lines: Array = ["Abundant algae: 5 food per bloom.", "More hunters compete for your food.", "Rare visitors in some encounters."] if i == 0 else ["Smaller blooms: 4 food per bloom.", "Half as many hunter arrivals.", "A %s will visit." % run.harvest.Discoveries.name_for(run)]
		var y := card.position.y + 120.0
		for j in lines.size():
			draw_circle(Vector2(x + 11, y - 5), 2.5, tint if j != 1 else Color(tint, 0.6), true, -1, true)
			y = wrapped(lines[j], Vector2(x + 26, y), 290, 15, INK) + 36.0
	if run.harvest.final_surge_enabled:
		centered("Final hunter wave after the goal · a swift clear draws more.", CHOICE.end.y - 62, 13, CYAN)
	elif run.harvest.hunter_quota()>0:
		centered("This feeding visit needs two hunter captures%s." % (" · quicker hunters ahead" if run.mutations.size()>=4 else ""), CHOICE.end.y - 62, 13, CYAN)
	elif run.encounter_total()==30 and run.stage_index>=8 and run.mutations.size()>=5:
		centered("Stored food draws faster hunters in the Blue Deep.", CHOICE.end.y - 62, 13, CYAN)
	elif run.stage_index>=4 and run.mutations.size()>=4:
		centered("This evolved colony attracts quicker hunters. Watch the arrival marks.", CHOICE.end.y - 62, 13, CYAN)
	centered("Next: %s. Your health and upgrades travel with you." % run.harvest.spec.name, CHOICE.end.y - 36, 13, MUTED)

## Wrapped text that can also be measured without painting, so dialogs fit.
func block(paint: bool, value: String, at: Vector2, width: float, size_px: int, color: Color, weight: int = 0) -> float:
	if paint:
		return wrapped(value, at, width, size_px, color, weight)
	var actual := scaled(size_px, true)
	return at.y + (lines_for(value, width, actual, weight).size() - 1) * line_step(actual)

func brief_rect() -> Rect2:
	var height := brief_content(false, 0.0) + 112.0
	return Rect2(250, roundf(450.0 - height * 0.5), 780, height)

func draw_brief() -> void:
	var rect := brief_rect()
	dialog(rect)
	brief_content(true, rect.position.y)

## Lays out the briefing from its top edge and returns its last baseline.
func brief_content(paint: bool, top: float) -> float:
	var run = game.run
	var spec: Dictionary = run.harvest.spec
	var dish: Dictionary = Journey.dish(run.stage_index)
	var left := 298.0
	var width := 684.0
	if paint:
		route_map(Vector2(320, top + 44), 640)
		centered(spec.name, top + 136, 32)
		centered("%s  ·  encounter %d of %d%s" % [dish.name, run.encounter_index() + 1, run.encounter_total(), " · original journey" if run.encounter_total()==30 else ""], top + 166, 14, dish.color, UI.MEDIUM)
		if run.stage_index in [2,4,8,10] and not spec.get("generated",false):
			centered("Mother grew another health organelle · %d of %d healthy" % [run.integrity,run.max_integrity], top + 190, 13, CYAN, UI.MEDIUM)
	var section := top + 210.0
	var featured: String = spec.featured
	var captioned: bool = featured in ["grazer", "parasite", "divider", "amoeba", "bacterium"]
	var art_bottom := section + 112.0
	if paint:
		var texture: Texture2D = game.microscope.enemy_texture(featured)
		draw_texture_rect(texture, Rect2(left, section + 28, 125, 49) if featured == "bacterium" else Rect2(left + 10, section, 105, 105), false)
	if captioned:
		if paint:
			label_at({"bacterium":"A bacterial food thief", "amoeba":"Swallows a cell", "grazer":"Steals food", "parasite":"Blocks a cell", "divider":"Splits into two"}[featured], Vector2(left, section + 136), 13, CYAN, UI.SEMIBOLD)
		art_bottom = block(paint, {"bacterium":"Loop it, or guide phages to it.", "amoeba":"Capture it within 15s to rescue.", "grazer":"Catch it to recover the food.", "parasite":"Catch it to free the cell.", "divider":"Catch it before it splits."}[featured], Vector2(left, section + 156), 150, 12, MUTED)
	var goals: Array = ["Surround green food with any ready blue cells.", "Practice a small loop, then a wider loop.", "Use the food you earn to improve your colony."] if run.Lesson.active(run) else Guidance.goals(run)
	if spec.get("phage_lesson", false):
		goals = ["Collect %d green food." % spec.food, "Drag the silver cluster toward the copper rod. Phages infect it when close.", "After 9 seconds it ruptures. Collect the food it releases, or capture the thief yourself."]
	if run.stage_index == 2 and not spec.get("generated", false):
		goals[1] = "Remove 3 threats. The bell bud opens between breaths."
	if run.stage_index == 6 and not spec.get("generated", false):
		goals[1] = "Rescue 3 spores. Open the glass cradle; rescue its pearl now, or protect it for 12s to hatch two young."
	var y := section + 14.0
	for goal in goals:
		if paint:
			draw_circle(Vector2(left + 214, y - 6), 3.0, CYAN, true, -1, true)
		y = block(paint, goal, Vector2(left + 232, y), 452, 16, INK) + 38.0
	y = maxf(y - 4.0, art_bottom + 40.0)
	var gesture := "Drag through 3-%d blue cells. Return to the first cell, then release to capture what is inside." % run.selection.max_vertices if not game.click_mode else "Click through 3-%d blue cells. Click the first cell again, then press Enter to capture." % run.selection.max_vertices
	y = block(paint, gesture, Vector2(left, y), width, 14, CYAN)
	if run.stage_index > 0:
		var detail: String = run.JourneyRoute.FAMILY_DETAILS[spec.featured] if spec.get("generated", false) else run.Mastery.suggestion(run)
		y = block(paint, detail, Vector2(left, y + 28), width, 13, MUTED)
		if run.encounter_total()==30 and run.stage_index>=8 and run.mutations.size()>=5:
				y = block(paint, "Stored food draws faster hunters. Follow arrival marks. Guard tissue rests for two encounters after blocking a hunter.", Vector2(left, y + 24), width, 13, CYAN)
		elif run.stage_index>=4 and run.mutations.size()>=4:
			y = block(paint, "Hunters now close in faster. Follow the marked arrivals and protect Mother before they reach her.", Vector2(left, y + 24), width, 13, CYAN)
		var feat := "guardian" if spec.mode == "rescue" else "gatherer"
		if not spec.get("generated", false) and not game.journey_profile.keepsake_unlocked(feat):
			y = block(paint, "First time: grows a %s in your home pond." % run.Mastery.KEEPSAKES[feat].to_lower(), Vector2(left, y + 26), width, 12, CYAN)
	return y - top

func draw_evolution() -> void:
	var run = game.run
	var spec: Dictionary = run.harvest.spec
	var dish: Dictionary = Journey.dish(run.stage_index)
	dialog(EVOLVE)
	var first: bool = run.mutations.is_empty()
	centered("Choose how you like to capture" if first else "Improve your colony", EVOLVE.position.y + 62, 28)
	var context := "%s complete." % spec.name
	if run.stage_index == 3:
		context = "Stillwater complete. The Weaver can now begin a journey."
	elif run.stage_index == 7:
		context = "Glassgarden complete. The Symbiont can now begin a journey."
	centered(context, EVOLVE.position.y + 94, 14, dish.color, UI.MEDIUM)
	var balance := "%d food saved  ·  upgrades cost %d  ·  " % [run.biomass, run.evolution_cost()]
	balance += "%d left afterward" % (run.biomass - run.evolution_cost()) if run.biomass >= run.evolution_cost() else "need %d more" % (run.evolution_cost() - run.biomass)
	centered(balance, EVOLVE.position.y + 120, 14, CYAN)
	if not run.route_plan.is_empty():
		centered("Evolution %d of %d. Each lasts until this journey ends." % [run.mutations.size() + 1, run.JourneyRoute.MAX_TRAITS], EVOLVE.position.y + 141, 12, MUTED)
	else:
		centered("Lasts for this journey." if first else "Upgrades combine and last for this journey.", EVOLVE.position.y + 141, 12, MUTED)
	right_at("Next: " + run.next_encounter_name(), Vector2(EVOLVE.end.x - 32, EVOLVE.end.y - 38), 13, MUTED)

func draw_rest() -> void:
	var run = game.run
	dialog(REST)
	centered("A moment to recover", REST.position.y + 66, 30)
	centered("%s complete." % run.harvest.spec.name, REST.position.y + 94, 14, CYAN, UI.MEDIUM)
	var texture: Texture2D = game.microscope.enemy_texture("spore")
	draw_texture_rect(texture, Rect2(590, REST.position.y + 118, 100, 100), false)
	centered("Next: " + run.next_encounter_name(), REST.position.y + 262, 20)
	centered("%d food saved  ·  mother has %d of %d health" % [run.biomass, run.integrity,run.max_integrity], REST.position.y + 292, 14, CYAN)
	var note := "Your six evolutions define this colony. Try a different combination next journey." if run.mutations.size() >= run.JourneyRoute.MAX_TRAITS else "Evolution choices return at the next milestone. Your food and colony travel with you."
	wrapped_centered(note + " Repair the mother if needed, or carry on.", REST.position.y + 330, REST.size.x - 120, 13, MUTED)

func draw_help() -> void:
	scrim()
	dialog(HELP)
	centered("Make a loop. Capture what's inside.", 154, 28)
	centered("The dish is paused while you read.", 182, 13, MUTED)
	var points := PackedVector2Array([Vector2(340,262), Vector2(487,327), Vector2(337,410), Vector2(340,262)])
	draw_colored_polygon(PackedVector2Array([points[0],points[1],points[2]]), Color(0.35,0.7,0.65,0.09))
	draw_polyline(points, CYAN, 2.0, true)
	for i in 3:
		draw_texture_rect(game.microscope.CELL, Rect2(points[i]-Vector2(24,24), Vector2(48,48)), false)
	label_at("Start and finish", Vector2(292,226), 12, CYAN, UI.MEDIUM)
	draw_texture_rect(game.microscope.FOOD, Rect2(358,312,46,46), false)
	draw_texture_rect(game.microscope.CYST, Rect2(476,420,37,37), false)
	label_at("Keep poison outside", Vector2(300,480), 13, UI.DANGER, UI.MEDIUM)
	var steps := ["Start on a blue cell.", "Drag through any ready blue cells.", "Return to your first cell.", "Release to capture the organisms inside."]
	if game.click_mode:
		steps = ["Click a blue cell to start.", "Click any ready blue cells.", "Click your first cell again.", "Press Enter to capture the organisms inside."]
	for i in steps.size():
		draw_circle(Vector2(571, 245 + i * 54), 12.0, Color(CYAN, 0.12), true, -1, true)
		centered(str(i + 1), 250 + i * 54, 13, CYAN, UI.SEMIBOLD, 571.0)
		wrapped(steps[i], Vector2(594, 251 + i * 54), 400, 16, INK)
	wrapped("Use 3-%d cells. Keep the mother outside; avoid crossing her or your loop. Right-click cancels for free. Used cells absorb, then return." % game.run.selection.max_vertices, Vector2(559, 477), 425, 13, MUTED)
	draw_line(Vector2(HELP.position.x + 44, 528), Vector2(HELP.end.x - 44, 528), UI.LINE)
	label_at("This encounter", Vector2(278, 566), 15, INK, UI.SEMIBOLD)
	var y := 596.0
	for goal in Guidance.goals(game.run):
		draw_circle(Vector2(282, y - 5), 2.5, CYAN, true, -1, true)
		y = wrapped(goal, Vector2(294, y), 380, 14, INK) + 28.0
	label_at("Specimens", Vector2(718, 566), 15, INK, UI.SEMIBOLD)
	var icons := [game.microscope.FOOD, game.microscope.CYST, game.microscope.SPORE, game.microscope.DRIFTER]
	var captions := ["Green: food", "Purple spikes: lose health", "Pearl buds: rescue", "Amber hunters: defend"]
	for i in 4:
		draw_texture_rect(icons[i], Rect2(714, 578 + i * 29, 26, 26), false)
		label_at(captions[i], Vector2(750, 597 + i * 29), 13, INK)
	wrapped("Nudge: click a cyst, then clear water. Free every 6 seconds." if game.click_mode else "Nudge: drag a purple cyst into clear water. Free every 6 seconds.", Vector2(718, 708), 290, 12, CYAN)
	centered("Space pause   ·   Esc cancel   ·   J journal   ·   V settings   ·   C input mode   ·   M motion", HELP.end.y - 96, 12, UI.FAINT, UI.MEDIUM)

func toggle_advanced() -> void:
	advanced_open = not advanced_open
	refresh()

func draw_home() -> void:
	if game.home_pond_open:
		draw_home_pond()
		return
	if not advanced_open:
		title_screen.draw(self)
		return
	scrim()
	dialog(COLONIES)
	centered("A different beginning", COLONIES.position.y + 70, 32)
	centered("Optional starting traits for players who know the pond.", COLONIES.position.y + 100, 15, MUTED)
	for i in 3:
		var x := COLONIES.position.x + 153.0 + i * 248.0
		draw_texture_rect(MotherAppearance.SYMBIOSIS_YOUNG if i == 2 else game.microscope.CELL, Rect2(x - 40, COLONIES.position.y + 140, 80, 80), false, [Color("c7eee4"), Color("b0dcd8"), Color("d6d0b7")][i])
		if i == 1:
			draw_texture_rect(game.microscope.CELL, Rect2(x + 20, COLONIES.position.y + 187, 24, 24), false)
		var colony: Dictionary = Journey.COLONIES[i]
		var unlocked: bool = game.journey_profile.unlocked(colony.id)
		wrapped_centered(colony.detail if unlocked else colony.unlock, COLONIES.position.y + 330, 200, 14, MUTED if unlocked else UI.FAINT, 0, x)
	centered("Progress saves automatically. You can leave and return.", COLONIES.end.y - 92, 12, UI.FAINT)

func draw_home_pond() -> void:
	var residents: Array = game.journey_profile.residents
	label_at("Home pond", Vector2(LEFT, 52), 15, CYAN, UI.SEMIBOLD)
	label_at(str(residents.size()), Vector2(LEFT - 2, 122), 40, INK, UI.SEMIBOLD)
	label_at("lives brought home", Vector2(LEFT, 150), 14, CYAN)
	var rare_count := residents.filter(func(r): return r.rare).size()
	label_at("%d rare visitor%s" % [rare_count, "" if rare_count == 1 else "s"], Vector2(LEFT, 174), 13, MUTED)
	var y := wrapped("Every resident is a life you rescued. They stay here between journeys.", Vector2(LEFT, 226), COLUMN, 13, MUTED)
	wrapped("Select a resident to meet it and its companion.", Vector2(LEFT, y + 30), COLUMN, 13, INK)
	var unlocked := 0
	var next_hint := "Pearl nursery, fern meadow and glass garden. Grown from your optional feats."
	for id in game.run.Mastery.KEEPSAKES:
		if game.journey_profile.keepsake_unlocked(id):
			unlocked += 1
	for id in game.run.Mastery.KEEPSAKES:
		if not game.journey_profile.keepsake_unlocked(id):
			next_hint = {"guardian":"Rescue a spore with a nearby hunter in one clean loop to grow a pearl nursery.", "gatherer":"Gather 4 food from two blooms in one clean loop to grow a fern meadow.", "clear_water":"Finish an encounter without poison damage to grow a glass garden."}[id]
			break
	label_at("Pond gardens", Vector2(LEFT, 420), 13, INK, UI.SEMIBOLD)
	right_at("%d of 3" % unlocked, Vector2(LEFT + COLUMN, 420), 13, CYAN, UI.MEDIUM)
	wrapped(next_hint, Vector2(LEFT, 446), COLUMN, 12, MUTED)
	var record: Dictionary = game.home_pond.selected_record()
	if record.is_empty():
		y = wrapped("Nothing to hurry.", Vector2(RIGHT, 112), COLUMN, 22, INK, UI.SEMIBOLD)
		y = wrapped("Your journey waits exactly where you left it.", Vector2(RIGHT, y + 30), COLUMN, 13, MUTED)
		if residents.is_empty():
			wrapped("Rescue pearl-white spores to bring the first residents home.", Vector2(RIGHT, y + 34), COLUMN, 13, CYAN)
	else:
		var definition: Dictionary = game.microscope.Forms.definition(record.form)
		label_at("Rare resident" if record.rare else "Rescued resident", Vector2(RIGHT, 80), 12, MUTED)
		var display_name: String = game.journey_profile.resident_label(record)
		var name_size := 18 if measure(display_name, 22, UI.SEMIBOLD) > 310.0 else 22
		y = wrapped(display_name, Vector2(RIGHT, 112), COLUMN, name_size, INK, UI.SEMIBOLD)
		if not record.get("nickname", "").is_empty():
			y = wrapped(definition.get("name", "Pearl spore"), Vector2(RIGHT, y + 24), COLUMN, 12, CYAN)
		var origin := "From %s, encounter %d." % [Journey.dish(record.stage).name, record.get("encounter", record.stage + 1)]
		if record.get("story", "") == "hatchling":
			origin = "Hatched in Glassgarden after you opened its cradle."
		elif record.get("story", "") == "cradle":
			origin = "Rescued inside the glass cradle in Glassgarden."
		y = wrapped(origin, Vector2(RIGHT, y + 32), COLUMN, 13, MUTED)
		y = wrapped(game.journey_profile.relationship(record, game.home_pond.selected_companion()), Vector2(RIGHT, y + 30), COLUMN, 13, CYAN)
		wrapped("Fully grown in your care." if game.journey_profile.maturity(record) >= 1.0 else "Growing with each new encounter.", Vector2(RIGHT, y + 30), COLUMN, 12, MUTED)
	if residents.size() > game.home_pond.PAGE_SIZE:
		centered("Residents %d-%d of %d" % [game.home_pond.page * game.home_pond.PAGE_SIZE + 1, mini((game.home_pond.page + 1) * game.home_pond.PAGE_SIZE, residents.size()), residents.size()], 792, 12, MUTED)
	else:
		centered("Your rescues become a living part of this pond.", 872, 13, MUTED)

func draw_lesson() -> void:
	var run = game.run
	var waiting: bool = run.lesson_step in [1, 3]
	var guide: Dictionary = run.Lesson.instruction(run, game.click_mode)
	var step := "%d of 2" % (1 if run.lesson_step < 2 else 2)
	var title_width := measure(guide.title, 16, UI.SEMIBOLD)
	var step_width := measure(step, 12, UI.MEDIUM)
	var width := title_width + step_width + 64.0
	var box := Rect2(640.0 - width * 0.5, 92, width, 46)
	draw_style_box(UI.toast_box(), box)
	label_at(guide.title, Vector2(box.position.x + 24, 121), 16, INK, UI.SEMIBOLD)
	label_at(step, Vector2(box.end.x - 24 - step_width, 121), 12, UI.FAINT, UI.MEDIUM)
	if waiting:
		return
	var path: Array = run.Lesson.route(run)
	for i in path.size():
		var p: Vector2 = run.board.anchors[path[i]]
		var next: Vector2 = run.board.anchors[path[(i+1)%path.size()]]
		var direction := (next-p).normalized()
		draw_dashed_line(p+direction*29, next-direction*29, Color(0.65, 0.86, 0.86, 0.38), 1.5, 4.0, true, true)
		draw_circle(p+Vector2(23, -25), 11, UI.RAISED, true, -1, true)
		draw_circle(p+Vector2(23, -25), 11, Color(CYAN, 0.35), false, 1.0, true)
		centered(str(i+1), p.y - 20.5, 12, CYAN, UI.SEMIBOLD, p.x + 23)
	# A moving point demonstrates the route without moving the actual cells.
	if not game.reduced_motion and not run.selection.active:
		var progress: float = fmod(game.visual_time * 0.65, path.size())
		var i := int(progress)
		var a: Vector2 = run.board.anchors[path[i]]
		var b: Vector2 = run.board.anchors[path[(i+1)%path.size()]]
		draw_circle(a.lerp(b, fmod(progress, 1.0)), 3.0, CYAN, true, -1, true)

func draw_result() -> void:
	var run = game.run
	if run.state == "success":
		draw_epilogue()
		return
	scrim()
	if run.state == "paused":
		var dish: Dictionary = Journey.dish(run.stage_index)
		dialog(MENU)
		centered("Paused", MENU.position.y + 62, 30)
		var remaining := maxi(0, ceili(run.harvest.deadline() - run.stage_elapsed))
		var context := "%s  ·  encounter %d of %d" % [dish.name, run.encounter_index() + 1, run.encounter_total()]
		if not run.Lesson.active(run):
			context += "  ·  %d:%02d left" % [remaining / 60, remaining % 60]
		centered(context, MENU.position.y + 90, 13, MUTED)
		route_map(Vector2(MENU.position.x + 48, MENU.position.y + 128), MENU.size.x - 96)
		draw_line(Vector2(MENU.position.x + 40, MENU.position.y + 386), Vector2(MENU.end.x - 40, MENU.position.y + 386), UI.LINE)
		return
	var rect := loss_rect()
	dialog(rect)
	loss_content(true, rect.position.y)

func draw_round_result_cue() -> void:
	var run = game.run
	var won: bool = run.state != "loss"
	var color: Color = CYAN if won else UI.DANGER
	if won:
		var pulse: float = 0.0 if game.reduced_motion else 1.0 - game.result_reveal_remaining / game.RESULT_REVEAL_SECONDS
		draw_arc(run.board.center, 76.0 + pulse * 34.0, 0.0, TAU, 64, Color(color, 0.55 * (1.0 - pulse * 0.7)), 2.0, true)
	var title := "Journey complete" if run.state == "success" else "Boss defeated" if run.harvest.spec.mode == "boss" else "Encounter complete"
	if not won:
		title = run.harvest.loss_title
	var detail := "Mother survived with %d health   ·   Score %d" % [run.integrity, run.score] if won else "Mother lost · retry this encounter" if run.integrity == 0 else "Goal unfinished · retry this encounter"
	var rect := Rect2(400, 695, 480, 88)
	draw_style_box(UI.toast_box(), rect)
	centered(title, rect.position.y + 36, 25, color, UI.SEMIBOLD)
	centered(detail, rect.position.y + 64, 14, INK)

func draw_big_capture() -> void:
	if game.big_capture_remaining <= 0.0:
		return
	var progress: float = 1.0 - game.big_capture_remaining / 2.0
	var opacity: float = 0.5 * (1.0 - progress)
	var radius: float = 32.0 if game.reduced_motion else 32.0 + 118.0 * progress
	draw_arc(game.big_capture_center, radius, 0.0, TAU, 48, Color(CYAN, opacity), 2.0, true)
	if not game.reduced_motion:
		draw_arc(game.big_capture_center, radius * 0.72, 0.0, TAU, 48, Color(UI.FOOD, opacity * 0.55), 1.0, true)
		draw_arc(game.big_capture_center, radius * 1.18, 0.0, TAU, 48, Color(CYAN, opacity * 0.25), 1.0, true)

func loss_rect() -> Rect2:
	var height := loss_content(false, 0.0) + 120.0
	return Rect2(390, roundf(450.0 - height * 0.5), 500, height)

func loss_content(paint: bool, top: float) -> float:
	var run = game.run
	var width := 420.0
	var y := top + 70.0
	var lines := [[run.harvest.loss_title, 28, INK, UI.SEMIBOLD, 0.0], [run.harvest.loss_reason, 15, MUTED, 0, 34.0], ["Retry encounter %d. Every earlier evolution and dish is kept." % (run.encounter_index() + 1), 14, CYAN, 0, 40.0], ["Retries begin with at least three health.", 13, MUTED, 0, 24.0]]
	for line in lines:
		y += line[4]
		if paint:
			y = wrapped_centered(line[0], y, width, line[1], line[2], line[3])
		else:
			var actual := scaled(line[1], true)
			y += (lines_for(line[0], width, actual, line[3]).size() - 1) * line_step(actual)
	return y - top

func draw_epilogue() -> void:
	var run = game.run
	centered("A whole world, alive.", 152, 36)
	centered("Stillwater, Glassgarden and the Blue Deep. The lives you brought home.", 186, 15, INK)
	var stats := "Score %d   ·   Lives rescued %d   ·   Evolutions %d" % [run.score, run.total_rescued, run.mutations.size()]
	var undiscovered := 0
	for species in Journey.SPECIES:
		if species.id not in game.journey_profile.discovered and species.id not in run.seen_species:
			undiscovered += 1
	var note := "%d species still undiscovered. Another current is waiting." % undiscovered if undiscovered > 0 else "Every known species discovered. A different colony is waiting."
	var width := maxf(measure(stats, 15, UI.MEDIUM), measure(note, 13)) + 64.0
	draw_style_box(UI.toast_box(), Rect2(640.0 - width * 0.5, 666, width, 76))
	centered(stats, 698, 15, CYAN, UI.MEDIUM)
	centered(note, 724, 13, MUTED)

func draw_ending_status() -> void:
	var run = game.run
	label_at("The colony you raised", Vector2(LEFT, 52), 13, MUTED)
	var y := wrapped(UI.sentence(Mutations.build_name(run.mutations)), Vector2(LEFT, 86), COLUMN, 22, INK, UI.SEMIBOLD) + 36.0
	for i in mini(8, run.mutations.size()):
		label_at(Mutations.journey_definition(run.mutations[i]).name, Vector2(LEFT, y + i * 26), 13, MUTED)
	label_at("%d health cores survived" % run.integrity, Vector2(LEFT, 560), 13, CYAN, UI.MEDIUM)
	label_at("%d food gathered" % run.total_food, Vector2(LEFT, 586), 13, MUTED)
	label_at("Journey score %d" % run.score, Vector2(LEFT, 612), 13, CYAN, UI.MEDIUM)
	wrapped("The pond remembers.", Vector2(RIGHT, 86), COLUMN, 22, INK, UI.SEMIBOLD)
	wrapped("Every rescued organism stays in your home pond. These are some of the lives you brought home.", Vector2(RIGHT, 150), COLUMN, 13, MUTED)
	wrapped("Next time, follow a different habitat, discover another species, or raise a new kind of colony.", Vector2(RIGHT, 290), COLUMN, 13, INK)

func draw_journal() -> void:
	scrim()
	dialog(JOURNAL)
	centered("Field journal", JOURNAL.position.y + 62, 28)
	centered("Discoveries carry over to every colony.", JOURNAL.position.y + 90, 13, MUTED)
	for slot in JOURNAL_PAGE_SIZE:
		var i := journal_page*JOURNAL_PAGE_SIZE+slot
		if i>=Journey.SPECIES.size():
			break
		var entry: Dictionary = Journey.SPECIES[i]
		var known: bool = game.journey_profile.discovered.has(entry.id) or game.run.seen_species.has(entry.id)
		var cell := Rect2(JOURNAL.position.x + 40 + (slot % 2) * 388, JOURNAL.position.y + 124 + (slot / 2) * 248, 368, 232)
		draw_style_box(UI.card_box(), cell)
		var origin := cell.position + Vector2(24, 24)
		if entry.id=="phage":
			game.microscope.PhageVisual.specimen(self,origin+Vector2(28,28),0.25,2.1,0.0,0.0,0.95 if known else 0.15)
		else:
			draw_texture_rect(game.microscope.enemy_texture(entry.id),Rect2(origin+Vector2(0,15),Vector2(57,23)) if entry.id=="bacterium" else Rect2(origin,Vector2(57,57)),false,Color(1,1,1,0.95 if known else 0.15))
		label_at(entry.name if known else "Undiscovered", origin + Vector2(76, 34), 17, INK if known else MUTED, UI.SEMIBOLD)
		wrapped(entry.detail if known else Journey.search_hint(entry), origin + Vector2(0, 92), cell.size.x - 48, 13, MUTED if known else UI.FAINT)
	centered("Page %d of %d" % [journal_page + 1, ceili(Journey.SPECIES.size() / float(JOURNAL_PAGE_SIZE))], JOURNAL.end.y - 44, 13, MUTED)

func watch_creature_film(slot: int) -> void:
	var i := journal_page*JOURNAL_PAGE_SIZE+slot
	if i<Journey.SPECIES.size() and game.creature_cinema!=null:
		game.creature_cinema.present(Journey.SPECIES[i].id,true)

func watch_new_film() -> void:
	if game.creature_cinema != null:
		game.creature_cinema.watch_new_film()

func save_new_films_for_later() -> void:
	if game.creature_cinema != null:
		game.creature_cinema.save_new_films_for_later()

func turn_journal(direction: int) -> void:
	journal_page = clampi(journal_page+direction,0,ceili(Journey.SPECIES.size()/float(JOURNAL_PAGE_SIZE))-1)
	refresh()

func draw_rename() -> void:
	scrim()
	dialog(RENAME)
	centered("Name this resident", RENAME.position.y + 60, 26)
	centered("The name stays with its story in your home pond.", RENAME.position.y + 90, 14, MUTED)
	centered("Leave it empty to use the species name." if name_error.is_empty() else name_error, RENAME.position.y + 192, 12, MUTED if name_error.is_empty() else UI.DANGER)

func draw_ecology(highlighted: int = -1) -> void:
	var run = game.run
	var boss = run.boss()
	var pink := Color("efa8c5")
	for body in run.enemies:
		var p: Vector2 = body.nucleus
		match body.kind:
			"bell_bud":
				marker(body,body.status_text(),CYAN if body.can_take_pulse() else Color("c4be9d"))
			"spore":
				if body.cradle:
					var caption: String = ("LAST SHIELD · %ds" % ceili(body.shield_remaining) if body.shield_remaining>0 else "BREAK BOTH SHIELDS") if not body.gate_ids.is_empty() else "OPEN · RESCUE THE PEARL"
					if body.hatch_remaining()>=0.0:
						caption = "RESCUE NOW / HATCH 2 IN %ds" % ceili(body.hatch_remaining())
					var eaten: float = run.harvest.ecology.eating_progress(run,body.id)
					if eaten>0.0:
						caption = "BEING EATEN · RESCUE IN %ds" % ceili(6.0*(1.0-eaten))
					marker(body,caption,pink if eaten>0.0 else CYAN)
				elif body.visitor and body.id!=highlighted:
					marker(body,"VISITOR · %ds" % ceili(body.lifetime()-body.age),Color("c7caea"))
				elif run.harvest.rescued<int(run.harvest.spec.target) and body.id!=highlighted:
					marker(body,"RESCUE · %ds" % ceili(body.lifetime()-body.age),Color("d5ded8"))
			"warden":
				for holder in run.enemies:
					if holder.gate_ids.has(body.id):
						draw_line(p,holder.nucleus,Color(0.75,0.85,0.67,0.24),1.2,true)
						draw_arc(p,24,0,TAU,36,Color("b9d399"),1.0,true)
			"parasite":
				var node: Vector2 = run.board.anchors[body.target_node]
				draw_dashed_line(p,node,Color(pink,0.75 if body.latched else 0.35),1.2,4.0,true,true)
				if body.latched:
					draw_arc(node,28,0,TAU,36,pink,1.4,true)
					water_label("blocked:%d" % body.id,Rect2(node-Vector2.ONE*35.0,Vector2.ONE*70.0),"BLOCKED",pink)
				else:
					marker(body,"LATCHING",pink)
					draw_arc(node,28,-PI/2,-PI/2+TAU*minf(1,body.action_clock/7.0),36,Color(pink,0.6),1.2,true)
			"grazer":
				if body.action_clock>0.1:
					draw_arc(p,36,-PI/2,-PI/2+TAU*minf(1,body.action_clock/4.0),30,Color("d6c79c"),1.1,true)
				if body.stored_food>0 and body.id!=highlighted:
					marker(body,"%d FOOD STOLEN" % body.stored_food,Color("d6c79c"))
			"divider":
				if not body.daughter and body.id!=highlighted:
					marker(body,"SPLITS IN %ds" % ceili(body.split_remaining()),pink if body.split_remaining()<7 else MUTED)
	var event: Dictionary = run.harvest.HabitatEvents.sample(run)
	if not run.selection.can_close() and game.toast_time<=0.0:
		centered(event.title+"  ·  "+event.detail if not event.is_empty() else run.harvest.ecology.pressure_text(run), 878, 12, UI.FAINT)

func renaming() -> bool:
	return not rename_token.is_empty()

func name_key(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
		name_input.accept_event()
		cancel_rename()

func begin_rename() -> void:
	var record: Dictionary = game.home_pond.selected_record()
	if record.is_empty():
		return
	rename_token = record.token
	name_error = ""
	name_input.text = record.get("nickname","")
	refresh()
	name_input.grab_focus()
	name_input.select_all()

func cancel_rename() -> void:
	rename_token = ""
	name_input.release_focus()
	refresh()

func save_name() -> void:
	if game.journey_profile.rename_resident(rename_token,name_input.text):
		cancel_rename()
	else:
		name_error = "Could not save yet. Please try again."
		queue_redraw()
