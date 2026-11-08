extends CanvasLayer
## Reflowed, scrollable native controls for small windows and larger text.
## The simulation stays in its original coordinate system; Main maps input.
const UI = preload("res://scripts/ui_style.gd")
const Comparison = preload("res://scripts/evolution_comparison.gd")
const Guidance = preload("res://scripts/journey_guidance.gd")
var game: Node2D
var screen: Control
var body: VBoxContainer
var signature := ""
var status: Label
var goal: Label
var instruction: Label
var feedback: Label
var controls: Array[Control] = []
## The main dialog panel shrinks to its content, up to the full window height.
var fitted: PanelContainer
var fitted_column: VBoxContainer
const FULL := Rect2(84, 38, 1112, 824)

func _ready() -> void:
	game = get_parent()
	layer = 30
	screen = Control.new()
	screen.size = Vector2(1280, 900)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(screen)

func label(text: String, size_px: int = 25, color: Color = UI.INK, parent: Node = null) -> Label:
	var node := Label.new()
	node.text = text
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.add_theme_font_override("font", UI.font(UI.MEDIUM))
	node.add_theme_font_size_override("font_size", size_px)
	node.add_theme_color_override("font_color", color)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent != null else body).add_child(node)
	return node

func button(text: String, action: Callable, primary: bool = false, parent: Node = null) -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size = Vector2(0, 62)
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.focus_mode = Control.FOCUS_ALL
	UI.style_button(node, "primary" if primary else "secondary", 25)
	node.pressed.connect(func(): action.call(); signature = "")
	(parent if parent != null else body).add_child(node)
	controls.append(node)
	return node

func row(parent: Node = null) -> HBoxContainer:
	var node := HBoxContainer.new()
	node.add_theme_constant_override("separation", 16)
	(parent if parent != null else body).add_child(node)
	return node

func panel(rect: Rect2, scrollable: bool = true) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.add_theme_stylebox_override("panel", UI.box(UI.SURFACE, 18, UI.LINE, Vector2(28, 22)))
	screen.add_child(panel)
	var content: Node = panel
	if scrollable:
		var scroll := ScrollContainer.new()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.follow_focus = true
		panel.add_child(scroll)
		# Room for the scroll bar, so sliders and buttons never run beneath it.
		var gutter := MarginContainer.new()
		gutter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		gutter.add_theme_constant_override("margin_right", 18)
		scroll.add_child(gutter)
		content = gutter
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 18)
	content.add_child(column)
	return column

func screen_key() -> String:
	var run = game.run
	if not game.pending_new_colony.is_empty(): return "confirm"
	if game.settings_open: return "settings"
	if game.comparisons_open: return "comparisons"
	if game.help_open: return "help"
	if game.journal_open: return "journal:%d:%d" % [game.hud.journal_page, game.journey_profile.discovered.size()+run.seen_species.size()]
	if game.hud.renaming(): return "rename"
	if run.state == run.HOME: return "pond:%d:%d:%d" % [game.home_pond.page, game.home_pond.selected, game.home_pond.welcome_tokens.size()] if game.home_pond_open else "home"
	if game.round_result_showing(): return "settling:" + run.state
	if run.state == run.BRIEF: return "brief:%d:%d:%s" % [run.stage_index,run.growth_slot(),str(run.Habitats.pending(run))]
	return run.state + ":" + str(run.offered_mutations)

func sync() -> void:
	# Normal windows draw every dialog in the HUD; this layout serves small windows and larger text.
	var enabled: bool = game.comfort_layout()
	var reveal: bool = game.evolution_reveal != null and game.evolution_reveal.visible
	screen.visible = enabled and not reveal
	game.hud.visible = true
	if not enabled or reveal: return
	var key := screen_key()
	if key != signature:
		signature = key
		rebuild(key)
	if status != null:
		update_active()
	fit()

func fit() -> void:
	if fitted == null or not is_instance_valid(fitted):
		return
	# Wrapped labels report their height once laid out at the panel's width.
	var height := minf(FULL.size.y, fitted_column.get_combined_minimum_size().y + 44.0 + 18.0)
	fitted.size = Vector2(FULL.size.x, height)
	fitted.position = Vector2(FULL.position.x, roundf(450.0 - height * 0.5))

func rebuild(key: String) -> void:
	for child in screen.get_children():
		screen.remove_child(child)
		child.queue_free()
	controls.clear()
	fitted = null
	status = null
	goal = null
	instruction = null
	feedback = null
	if key.begins_with("active") or key.begins_with("settling"):
		build_active()
		return
	if key.begins_with("pond"):
		build_pond()
		return
	body = panel(FULL)
	fitted = body.get_parent().get_parent().get_parent()
	fitted_column = body
	if game.save_message.begins_with("Could not"):
		label(game.save_message,24,UI.DANGER)
	match key.split(":")[0]:
		"settings": build_settings()
		"help": build_help()
		"journal": build_journal()
		"home": build_home()
		"brief": build_brief()
		"evolve", "comparisons": build_evolution()
		"paused":
			label("A moment of stillness", 38)
			button("Resume · Space", game.pause, true)
			button("How to play · H", game.toggle_help)
			button("Field journal · J", game.toggle_journal)
			button("Settings · V", game.toggle_sound_settings)
			button("Save and return home", game.return_home)
		"loss":
			label(game.run.harvest.loss_title, 38)
			label(game.run.harvest.loss_reason)
			label("Earlier evolution and discoveries are kept. Retry begins with at least three health.", 24, UI.ACCENT)
			button("Retry this encounter · Enter", game.restart, true)
			button("Return home", game.return_home)
		"success":
			label("A whole world, alive", 38)
			label("%d lives rescued · %d evolutions · %d score" % [game.run.total_rescued,game.run.mutations.size(),game.run.score])
			label("Meet the lives you brought home in your pond.")
			button("Visit your home pond", game.return_home, true)
		"confirm":
			label("Start a new journey?", 38)
			label(game.hud.confirm_summary(), 25, UI.ACCENT)
			label("A new journey ends this one. Your home pond residents, discoveries and unlocked colonies stay with you.", 24, UI.MUTED)
			button("Keep my journey · Escape", game.cancel_new_journey, true)
			button("Start a new journey", game.confirm_new_journey)
			controls[0].grab_focus.call_deferred()
		"rename":
			label("Give this life a name", 38)
			var edit := LineEdit.new()
			edit.text = game.hud.name_input.text
			edit.max_length = 24
			edit.custom_minimum_size.y = 66
			edit.add_theme_font_size_override("font_size", 28)
			UI.style_line_edit(edit)
			body.add_child(edit)
			button("Save name", func(): game.hud.name_input.text = edit.text; game.hud.save_name(), true)
			button("Cancel · Escape", game.hud.cancel_rename)
			edit.grab_focus()
	link_focus()

func link_focus() -> void:
	for i in controls.size():
		controls[i].focus_next = controls[i].get_path_to(controls[(i+1)%controls.size()])
		controls[i].focus_previous = controls[i].get_path_to(controls[posmod(i-1,controls.size())])

func build_active() -> void:
	body = panel(Rect2(24, 14, 1232, 150), false)
	var top := row()
	status = label("", 24, UI.INK, top)
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var help := button("Help", game.toggle_help, false, top)
	help.custom_minimum_size.x = 120
	help.size_flags_horizontal = Control.SIZE_FILL
	var pause := button("Pause", game.pause, false, top)
	pause.custom_minimum_size.x = 140
	pause.size_flags_horizontal = Control.SIZE_FILL
	goal = label("", 24, UI.FOOD)
	body = panel(Rect2(24, 712, 1232, 174))
	instruction = label("", 27)
	feedback = label("", 24, UI.ACCENT)
	link_focus()

func update_active() -> void:
	var run = game.run
	status.text = "%s · %d/%d    Mother %d/%d    Food saved %d" % [run.JourneyPlan.dish(run.stage_index).name, run.encounter_index()+1,run.encounter_total(),run.integrity,run.max_integrity,run.biomass]
	if game.save_message.begins_with("Could not"): status.text += " · Save failed"
	var progress := "%d boss hits left · %d/6 charge" % [3-run.harvest.boss_hits,run.harvest.nourishment] if run.harvest.spec.mode=="boss" else "%d/%d food" % [run.harvest.nourishment,run.harvest.spec.food]
	var objective: String = Guidance.objective_text(run)
	if run.harvest.spec.mode!="boss" and not objective.is_empty(): progress += " · "+objective
	goal.text = run.harvest.spec.name+" · "+progress
	var remaining := maxi(0,ceili(run.harvest.deadline()-run.stage_elapsed))
	goal.text += " · Practice" if run.Lesson.active(run) else " · %d:%02d left" % [remaining/60,remaining%60]
	if run.state != run.ACTIVE:
		instruction.text = "The colony is settling" if run.state==run.EVOLVE else "The encounter has ended"
		feedback.text = "Your next choice appears after digestion."
		return
	var guide: Dictionary = Guidance.next_action(run, game.click_mode)
	instruction.text = guide.title
	if run.selection.can_close():
		var meal: Dictionary = run.harvest_preview()
		feedback.text = game.CaptureFeedback.summary(meal)+" · "+game.CaptureFeedback.health_text(meal,run.integrity)
		var recovery: float = run.Mutations.recovery(run.mutations,run.selection.path.size(),run.board.tuning.recovery_seconds) + game.hud.LoopStrain.penalty(run.selection.path,run.board.anchors)
		feedback.text += " · Cells ready in %.1fs" % recovery
		if game.capture_feedback.warning_remaining>0.0 and meal.poison>0: instruction.text = "Poison entered the loop · cancel or reshape"
		feedback.add_theme_color_override("font_color", UI.DANGER if meal.poison>0 else UI.ACCENT)
	else:
		feedback.text = game.toast if game.toast_time>0 and not guide.urgent else guide.detail
		if game.hud.nudge_relevant(): feedback.text += " · Nudge ready" if run.nudge.cooldown<=0 else " · Nudge in %.1fs" % run.nudge.cooldown
		feedback.add_theme_color_override("font_color", UI.ACCENT)

func build_settings() -> void:
	label("Sound and comfort", 38)
	label("Small windows and larger text use this reflowed layout.", 24, UI.MUTED)
	for entry in [["Music",game.soundscape.music_volume,game.soundscape.set_music_volume],["Living sounds",game.soundscape.effects_volume,game.soundscape.set_effects_volume]]:
		var line := row()
		var caption := label("%s · %d%%" % [entry[0],entry[1]*100],24,UI.INK,line)
		caption.custom_minimum_size.x = 340
		var slider := HSlider.new()
		slider.min_value = 0; slider.max_value = 1; slider.step = 0.05; slider.value = entry[1]
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.custom_minimum_size.y = 54
		slider.focus_mode = Control.FOCUS_ALL
		UI.style_slider(slider)
		slider.value_changed.connect(entry[2])
		slider.value_changed.connect(func(value): caption.text = "%s · %d%%" % [entry[0],value*100])
		line.add_child(slider); controls.append(slider)
	button("All sound: " + ("Muted" if game.soundscape.muted else "On"), game.soundscape.toggle_mute)
	button("Input: " + ("Click cells, then Enter" if game.click_mode else "Hold and drag"), game.toggle_mode)
	button("Motion: " + ("Reduced" if game.reduced_motion else "Full"), game.toggle_motion)
	button("Markers: " + ("High contrast" if game.high_contrast else "Standard"), game.toggle_contrast)
	button("Text: " + ("Larger" if game.large_text else "Standard"), game.toggle_text)
	button("Closure assistance: " + ("On" if game.assisted_closure else "Off"), game.toggle_assistance)
	label("Assistance closes a valid loop when you release just outside its starting cell.", 23, UI.MUTED)
	button("Slow down while holding a closed loop: " + ("On" if game.deliberate_capture else "Off"), game.toggle_deliberation)
	label("The entire dish runs at 35% speed while you read a closed-loop preview.",23,UI.MUTED)
	button("Visual detail: " + ["Light","Balanced","Full"][game.visual_quality], game.toggle_quality)
	button("Full screen: " + ("On" if game.fullscreen else "Off") + " · F11", game.toggle_fullscreen)
	button("Done · Escape", game.toggle_sound_settings, true)

func build_home() -> void:
	label("PETRIVERSE", 48, UI.ACCENT)
	label("Feed. Protect. Evolve.", 28)
	if not game.recovery_notice().is_empty(): label(game.recovery_notice(),24,UI.ACCENT)
	if not game.resume_data.is_empty(): button("Continue your journey", game.resume_journey, true)
	button("Begin a new journey", game.request_new_journey.bind("wanderer"), game.resume_data.is_empty())
	button("Visit your home pond · %d residents" % game.journey_profile.residents.size(), game.toggle_home_pond)
	if not game.journey_profile.new_residents().is_empty(): label("%d new lives are waiting to come home." % game.journey_profile.new_residents().size(),24,UI.ACCENT)
	for colony in game.run.JourneyPlan.COLONIES.slice(1):
		if game.journey_profile.unlocked(colony.id): button("Start as "+colony.name+" · "+colony.detail, game.request_new_journey.bind(colony.id))
	button("Field journal", game.toggle_journal)
	button("How to play", game.toggle_help)
	button("Experiments · three playable ideas",game.open_experiments)
	button("Settings", game.toggle_sound_settings)

func build_help() -> void:
	label("Make a loop. Capture what is inside.", 36)
	label("1. Start on a ready blue cell.\n2. Connect at least three cells.\n3. Return to the starting cell.\n4. Release to capture. In click mode, press Enter.")
	label("Keep Mother outside. Return to the previous cell to backtrack. Right-click or Escape cancels for free.",25,UI.ACCENT)
	label("Green food feeds. Violet cysts cost health. Pearl spores are rescued. Gold nuclei mark hunters and bosses.")
	label("Nudge: drag a cyst away from food, or a silver phage cluster toward a copper bacterium. One push every six seconds.")
	if game.run.state != game.Run.HOME:
		for text in Guidance.goals(game.run): label("• "+text,25,UI.FOOD)
	label("Space pauses. H opens help. J opens the journal. V opens settings. Tab moves keyboard focus.",24,UI.MUTED)
	button("Return · Escape", game.toggle_help, true)

func build_journal() -> void:
	label("Field journal",38)
	var entries: Array = game.run.JourneyPlan.SPECIES
	var first: int = game.hud.journal_page * 4
	for entry in entries.slice(first, mini(first+4, entries.size())):
		var known: bool = game.journey_profile.discovered.has(entry.id) or game.run.seen_species.has(entry.id)
		label(entry.name if known else "Undiscovered",29,UI.ACCENT)
		label(entry.detail if known else game.run.JourneyPlan.search_hint(entry),25)
		if known and game.creature_cinema != null: button("Watch "+entry.name+" film", game.creature_cinema.present.bind(entry.id,true))
	var navigation := row()
	if first>0: button("Previous",game.hud.turn_journal.bind(-1),false,navigation)
	if first+4<entries.size(): button("Next",game.hud.turn_journal.bind(1),false,navigation)
	button("Close · J",game.toggle_journal,true)

func build_brief() -> void:
	var run = game.run
	if run.growth_slot() >= 0:
		label("Mother is growing",38)
		label("Choose what her new organelle does.")
		button("Guard · intercept a hunter, then recover",game.choose_growth_role.bind("guard"),true)
		button("Feeder · extra food from clean meals of four or more",game.choose_growth_role.bind("feeder"))
	elif run.Habitats.pending(run):
		label("Choose the next habitat",38)
		label("Food-rich water has larger blooms and the usual hunter arrivals. Shelter has smaller blooms, fewer hunters and a guaranteed rare visitor.")
		button("Take the food-rich route",game.choose_habitat.bind("bloom"),true)
		button("Take the sheltered route",game.choose_habitat.bind("refuge"))
	else:
		label(run.harvest.spec.name,38)
		label("Encounter %d of %d · %s" % [run.encounter_index()+1,run.encounter_total(),run.JourneyPlan.dish(run.stage_index).name],24,UI.ACCENT)
		for text in Guidance.goals(run): label("• "+text)
		label(run.harvest.spec.lesson,24,UI.MUTED)
		button("Begin encounter · Enter",game.overlay_action,true)
	button("Save and return home",game.return_home)

func build_evolution() -> void:
	var run = game.run
	label("How will your colony evolve?",36)
	if game.comparisons_open: button("Back to visual cards · Escape",game.toggle_comparisons)
	label("%d food saved · upgrades stay for this journey" % run.biomass,25,UI.FOOD)
	for i in run.offered_mutations.size():
		var data: Dictionary = run.Mutations.journey_definition(run.offered_mutations[i])
		label(data.name,29,UI.ACCENT)
		label(data.detail.replace("\n"," "))
		label("Tradeoff: "+data.tradeoff,24,UI.MUTED)
		var comparison: Dictionary = Comparison.compare(run,run.offered_mutations[i])
		for line in comparison.lines: label(line,24,UI.ACCENT if str(line).begins_with("Food") else UI.INK)
		var choice := button("Choose for %d food · %d left" % [run.evolution_cost(),maxi(0,run.biomass-run.evolution_cost())],game.choose_evolution.bind(i),true)
		choice.disabled = run.biomass < run.evolution_cost()
	if run.integrity < run.max_integrity:
		var repair := button("Repair +%d health for %d food" % [mini(2,run.max_integrity-run.integrity),run.repair_cost()],game.repair_and_travel)
		repair.disabled = run.biomass < run.repair_cost() or run.repair_waiting() or run.repair_needs_deeper_wound()
	button("Keep food and travel",game.travel_without_evolution)
	button("Save and return home",game.return_home)

func build_pond() -> void:
	body = panel(Rect2(24,14,1232,112),false)
	var top := row()
	label("Your home pond · %d lives" % game.journey_profile.residents.size(),29,UI.INK,top).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var back := button("Back",game.toggle_home_pond,false,top)
	back.size_flags_horizontal = Control.SIZE_FILL
	back.custom_minimum_size.x = 140
	body = panel(Rect2(24,644,1232,242))
	if game.save_message.begins_with("Could not"): label(game.save_message,24,UI.DANGER)
	if not game.home_pond.welcome_tokens.is_empty(): label(("Welcome home · one new life, safe in your care" if game.home_pond.welcome_tokens.size()==1 else "Welcome home · %d new lives, safe in your care" % game.home_pond.welcome_tokens.size()),27,UI.FOOD)
	var resident: Dictionary = game.home_pond.selected_record()
	if not resident.is_empty():
		label(game.journey_profile.resident_label(resident),29,UI.ACCENT)
		label(game.journey_profile.habit(resident),24)
		label(game.journey_profile.origin_text(resident),24)
		label(game.journey_profile.relationship(resident,game.home_pond.selected_companion()),24,UI.ACCENT)
		label("Fully grown in your care." if game.journey_profile.maturity(resident)>=1 else "Growing with each new encounter.",24,UI.MUTED)
		button("Give it a name",game.hud.begin_rename)
	else: label("Select a resident to meet the life you brought home.",25)
	for id in game.run.Mastery.KEEPSAKES:
		if game.journey_profile.keepsake_unlocked(id): label("Grown through your care: " + game.run.Mastery.KEEPSAKES[id],24,UI.FOOD)
	var navigation := row()
	if game.home_pond.page>0: button("Previous residents",game.home_pond.turn_page.bind(-1),false,navigation)
	if (game.home_pond.page+1)*game.home_pond.PAGE_SIZE<game.journey_profile.residents.size(): button("More residents",game.home_pond.turn_page.bind(1),false,navigation)
	link_focus()
