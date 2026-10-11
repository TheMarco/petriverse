extends SceneTree
const Main = preload("res://scripts/main.gd")
var failures: Array = []
func expect(value: bool, message: String) -> void:
	if not value: failures.append(message)
func _initialize() -> void:
	root.unfocusable = true
	call_deferred("exercise")
func exercise() -> void:
	var args := OS.get_cmdline_user_args()
	var id := args[0] if not args.is_empty() else "amoeba"
	root.size = Vector2i(1280,900)
	root.content_scale_size = root.size
	RenderingServer.render_loop_enabled = false
	var game = Main.new()
	game.audio_enabled = args.has("voice")
	game.save_records = false
	game.preferences_enabled = false
	game.pause_on_focus_loss = false
	game.journey_profile.path = "/tmp/creature-film-visual-profile.cfg"
	game.journey_path = "/tmp/creature-film-visual-journey.cfg"
	game.preferences_path = "/tmp/creature-film-visual-preferences.cfg"
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.set_process_unhandled_input(false)
	game.new_journey("wanderer")
	game.run.begin_encounter()
	game._process(0)
	var cinema = game.creature_cinema
	cinema.set_process(false)
	expect(cinema.present(id),"Film opens")
	expect(game.run.state==game.Run.PAUSED,"Real dish pauses")
	var before: Dictionary = game.JourneySave.capture(game.run)
	cinema.finish_at = 30.0
	var stage = cinema.film
	for frame in 450:
		cinema.advance(1.0/30.0)
		game.run.step(1.0/30.0)
		await process_frame
		RenderingServer.force_draw(false)
		if frame in [60,180,300]:
			root.get_texture().get_image().save_png("res://artifacts/creature-film-"+id+"-%d.png" % frame)
		if frame==90:
			cinema.toggle_playback()
			var at: float = cinema.film.elapsed
			cinema.advance(2.0)
			expect(cinema.film.elapsed==at,"Pause freezes film")
			cinema.toggle_playback()
		if not cinema.active: break
	if cinema.active:
		expect(game.JourneySave.capture(game.run)==before,"Filming never changes the actual encounter")
		if id=="amoeba":
			expect(stage.milestones.has("swallowed"),"Amoeba visibly swallows")
			expect(stage.events.any(func(e): return e.get("cells_rescued",0)==1),"Real capture rescues the cell")
		if id=="phage": expect(stage.milestones.get("infected",false) and stage.milestones.get("ruptured",false),"Rendered infection completes")
		if id=="grazer": expect(stage.events.any(func(e): return e.get("food",0)>0),"Rendered theft and recapture complete")
		if id=="warden": expect(stage.milestones.get("opened",false),"Rendered shield links are broken")
		cinema.dismiss()
	expect(game.run.state==game.Run.ACTIVE,"Dismiss resumes active dish")
	expect(game.journey_profile.introduced_species.has(id),"Film is remembered")
	var report := {"id":id,"failures":failures}
	FileAccess.open("res://artifacts/creature-film-visual-"+id+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("CREATURE FILM: ",JSON.stringify(report))
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
