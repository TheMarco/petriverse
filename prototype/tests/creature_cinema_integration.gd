extends SceneTree
const Main = preload("res://scripts/main.gd")
var checks := 0
var failures: Array = []
func expect(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message)
func _initialize() -> void:
	root.unfocusable = true
	call_deferred("exercise")
func exercise() -> void:
	var game = Main.new()
	game.save_records = false
	game.audio_enabled = true
	AudioServer.set_bus_mute(0,true)
	game.preferences_enabled = false
	game.pause_on_focus_loss = false
	game.journey_profile.path = "/tmp/petriverse-cinema-integration-profile.cfg"
	game.journey_path = "/tmp/petriverse-cinema-integration-journey.cfg"
	game.preferences_path = "/tmp/petriverse-cinema-integration-preferences.cfg"
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	var cinema = game.creature_cinema
	cinema.set_process(false)
	game.new_journey("wanderer")
	game.run.begin_encounter()
	game.run.enemies.clear()
	game.run.phages.reset()
	game.journey_profile.introduced_species.clear()
	game.journey_profile.offered_species.clear()
	var food = game.run.Harvest.Organism.new(700,"food",Vector2(700,200),Vector2.ZERO,0)
	food.age = 4
	game.run.enemies.append(food)
	for i in 3:
		var kind: String = ["cyst", "spore", "drifter"][i]
		var body = game.run.Drifter.new(701 + i, Vector2(710 + i * 10, 220), 0.0, kind) if kind == "drifter" else game.run.Harvest.Organism.new(701 + i, kind, Vector2(710 + i * 10, 220), Vector2.ZERO, 0)
		body.age = 4
		game.run.enemies.append(body)
	game.run.seen_species.append_array(["amoeba","phage","regent"])
	game.run.selection.start(game.run.board.anchors[0])
	cinema.poll(0.1)
	expect(not cinema.active,"Never interrupt an active drag")
	game.run.selection.cancel()
	cinema.poll(0.1)
	expect(not cinema.active and cinema.pending_ids.size()==4,"Four discoveries create one optional prompt, not four automatic films")
	expect(game.journey_profile.offered_species.size()==4 and game.journey_profile.discovered.has("cyst"),"All prompted films are retained in the Field Journal")
	cinema.watch_new_film()
	expect(cinema.active and cinema.current_id=="food","Choosing Watch opens one film")
	expect(game.run.state==game.Run.PAUSED,"Actual encounter pauses")
	expect(game.soundscape.narration_active,"Music ducks during narration")
	var before: Dictionary = game.JourneySave.capture(game.run)
	var film_run = cinema.film.run
	expect(film_run!=game.run,"Film owns a separate simulation")
	for i in 60:
		cinema.advance(1.0/30.0)
		game.run.step(1.0/30.0)
	expect(game.JourneySave.capture(game.run)==before,"Real timers, food, health, fluid and cells stay unchanged")
	expect(cinema.voice.stream!=null,"Recorded ElevenLabs narration is loaded")
	var clock: float = cinema.film.elapsed
	cinema.toggle_playback()
	cinema.advance(1.0)
	expect(cinema.film.elapsed==clock,"Pause freezes demonstration")
	expect(cinema.voice.stream_paused,"Pause freezes narration")
	cinema.replay()
	expect(cinema.film.elapsed==0.0 and not cinema.playback_paused,"Replay restarts both clocks")
	cinema.dismiss()
	expect(game.run.state==game.Run.ACTIVE and not cinema.active,"Skip resumes the same encounter")
	expect(not game.soundscape.narration_active,"Music returns after skip")
	expect(game.journey_profile.introduced_species==["food"],"Only the viewed creature is marked introduced")
	expect(cinema.pending_ids.is_empty() and game.toast.contains("Field Journal"),"Other new films go to the Journal after one is watched")
	cinema.poll(5.0)
	expect(not cinema.active and cinema.pending_ids.is_empty(),"Previously offered species do not interrupt again")
	food.form = "fern_desmid"
	cinema.poll(0.1)
	expect(not cinema.active and cinema.pending_ids==["fern_desmid"],"A new form receives a nonblocking Watch choice")
	cinema.save_new_films_for_later()
	expect(cinema.pending_ids.is_empty() and game.toast.contains("Field Journal") and game.journey_profile.discovered.has("fern_desmid"),"Declining explains where to watch later")
	game.run.toggle_pause()
	game.journal_open = true
	expect(cinema.present("amoeba",true),"Journal can replay a known creature film")
	cinema.dismiss()
	expect(game.run.state==game.Run.PAUSED and game.journal_open,"Replay returns to the journal, still paused")
	expect(not cinema.present("not-a-creature"),"Missing species is rejected safely")
	game.journal_open = false
	game.run.toggle_pause()
	game.settings_open = true
	game.journey_profile.introduced_species.clear()
	cinema.poll(5.0)
	expect(not cinema.active,"Settings are never interrupted")
	game.settings_open = false
	game.pause_on_focus_loss = true
	cinema.present("amoeba")
	cinema._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	clock = cinema.film.elapsed
	cinema.advance(2.0)
	expect(cinema.film.elapsed==clock and cinema.voice.stream_paused,"Switching away pauses both film and voice")
	cinema._notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	expect(not cinema.focus_paused and not cinema.voice.stream_paused,"Returning restores playback")
	cinema.dismiss()
	var report := {"checks":checks,"failures":failures}
	FileAccess.open("res://artifacts/creature-cinema-integration-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("CREATURE CINEMA INTEGRATION: ",JSON.stringify(report))
	game.queue_free()
	await create_timer(0.2).timeout
	quit(0 if failures.is_empty() else 1)
