extends "res://scripts/main.gd"
## A safe, repeatable hands-on introduction; no journey or profile writes.
class PracticeHud:
	extends "res://scripts/journey_hud.gd"
	func refresh() -> void:
		super.refresh()
		restart_button.text = "Restart practice"
	func draw_status() -> void:
		label_at("Phage practice",Vector2(LEFT,52),15,CYAN,UI.SEMIBOLD)
		var y := wrapped("Your saved journey is safe. Press R to start again.",Vector2(LEFT,84),COLUMN,13,MUTED)
		wrapped("Silver phages are helpers. Copper bacteria steal green food.",Vector2(LEFT,y+30),COLUMN,13,MUTED)
		var message := "Drag the silver cluster toward the copper rod."
		for body in game.run.enemies:
			if body.kind=="bacterium" and body.infection_age>=0.0:
				message = "Attached! The bacterium ruptures in %ds." % ceili(body.infection_remaining())
		if not game.run.enemies.any(func(e): return e.kind=="bacterium"):
			message = "Now loop around the released green food. Press R to try again."
		var bottom := wrapped(message,Vector2(RIGHT,112),COLUMN,18,INK,UI.SEMIBOLD)
		wrapped("You can also capture the bacterium directly. Phages never infect your cells.",Vector2(RIGHT,bottom+32),COLUMN,13,CYAN)
		draw_nudge_meter()
		draw_feedback()
	func brief_content(paint: bool, top: float) -> float:
		if paint:
			centered("Tiny helpers",top+76,30)
			centered("Drag the silver phages toward the copper bacterium.",top+128,18,CYAN)
			centered("Watch them attach. Nine seconds later, the host ruptures.",top+162,17,INK)
			centered("Then collect the green food it releases.",top+194,17,INK)
			centered("R restarts practice. Your saved journey stays safe.",top+236,14,MUTED)
		return 236.0

func _init() -> void:
	save_records = false
	preferences_enabled = false
	show_home_on_start = false
	journey_path = "user://phage-practice-journey.cfg"
	journey_profile.path = "user://phage-practice-profile.cfg"
	preferences_path = "user://phage-practice-preferences.cfg"

func _ready() -> void:
	super._ready()
	hud.queue_free()
	hud = PracticeHud.new()
	add_child(hud)
	practice()
	DisplayServer.window_set_title("PETRIVERSE — Phage practice")

func practice() -> void:
	run.route_plan.clear()
	run.stage_index = 2
	run.integrity = 5
	run.start_stage()
	run.enemies.clear()
	run.phages.reset()
	run.phages.learned = false
	run.harvest.next_bloom = 9999
	run.harvest.ecology.next_wave = 9999
	run.harvest.ecology.pending.clear()
	run.harvest.spec.duration = 600
	run.harvest.spec.food = 999
	var body = run.harvest.ecology.add(run,"bacterium",0,run.harvest.ecology.pocket(run,0))
	body.age = 4
	body.spawning = 0
	body.stored_food = 2
	body.speed = 2.5
	run.phages.pair(run,body)
	run.phages.clusters[0].age = 4
	reset_presentation()

func restart() -> void:
	if microscope!=null: practice()
func return_home() -> void: restart()
