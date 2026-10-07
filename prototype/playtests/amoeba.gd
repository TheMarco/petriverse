extends "res://scripts/main.gd"
## A manually playable fixture with no journey/profile writes.
class PracticeHud:
	extends "res://scripts/journey_hud.gd"
	func refresh() -> void:
		super.refresh()
		restart_button.text = "Restart practice"
	func draw_status() -> void:
		label_at("Amoeba practice",Vector2(LEFT,52),15,CYAN,UI.SEMIBOLD)
		wrapped("Your saved journey is safe. R restarts practice. Space pauses.",Vector2(LEFT,84),COLUMN,13,MUTED)
		var message := "Wait for the amoeba to swallow a blue cell."
		for body in game.run.enemies:
			if body.kind=="amoeba" and body.captive_node>=0:
				message = "Loop around its gold nucleus to save your cell. %d seconds left." % ceili(body.rescue_remaining())
		if game.run.enemies.is_empty(): message = "Captured! Press R to try again."
		if game.run.cells.any(func(cell): return cell.lost): message = "The cell was digested. Press R to try again."
		var bottom := wrapped(message,Vector2(RIGHT,112),COLUMN,18,INK,UI.SEMIBOLD)
		wrapped("Use 3 or more blue cells. Close your loop, then release. Keep Mother outside.",Vector2(RIGHT,bottom+32),COLUMN,13,CYAN)
		draw_feedback()
	func brief_content(paint: bool, top: float) -> float:
		if paint:
			centered("Amoeba rescue practice",top+76,30)
			centered("Let it swallow one of your blue cells.",top+128,18,CYAN)
			centered("Then draw a closed loop around its gold nucleus.",top+162,17,INK)
			centered("You have 15 seconds to rescue the swallowed cell.",top+194,17,INK)
			centered("R restarts this practice. Your saved journey stays safe.",top+236,14,MUTED)
		return 236.0

func _init() -> void:
	save_records = false
	preferences_enabled = false
	show_home_on_start = false
	journey_path = "user://amoeba-practice-journey.cfg"
	journey_profile.path = "user://amoeba-practice-profile.cfg"
	preferences_path = "user://amoeba-practice-preferences.cfg"

func _ready() -> void:
	super._ready()
	hud.queue_free()
	hud = PracticeHud.new()
	add_child(hud)
	practice()
	DisplayServer.window_set_title("PETRIVERSE — Amoeba practice")

func practice() -> void:
	run.route_plan.clear()
	run.stage_index = 5
	run.integrity = 5
	run.start_stage()
	run.enemies.clear()
	run.harvest.next_bloom = 9999.0
	run.harvest.ecology.next_wave = 9999.0
	run.harvest.ecology.pending.clear()
	run.harvest.spec.duration = 600.0
	run.harvest.spec.food = 999
	var body = run.harvest.ecology.add(run,"amoeba",0,run.harvest.ecology.pocket(run,0))
	body.age = 4.0
	run.amoebas.choose_target(run,body)
	body.nucleus = body.destination
	body.search_after = body.age+0.75
	reset_presentation()

func restart() -> void:
	if is_instance_valid(microscope): practice()

func return_home() -> void: restart()
