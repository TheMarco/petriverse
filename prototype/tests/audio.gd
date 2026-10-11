extends SceneTree
## Mixer behavior and actual HUD controls, independent of paid asset generation.

const Main = preload("res://scripts/main.gd")
const Soundscape = preload("res://scripts/soundscape.gd")
const Drifter = preload("res://scripts/drifter.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("exercise")

func expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		printerr("FAIL: ", description)

func exercise() -> void:
	var game := Main.new()
	game.save_records = false
	game.preferences_enabled = false
	game.run.journey = false # This fixture exercises the isolated enclosure rules.
	game.run.harvest_mode = false
	game.run.full_run = false
	game.run.restart()
	root.content_scale_size = Vector2i(1280, 900)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	game.audio_enabled = false
	game.pause_on_focus_loss = false
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	var sound: Node = game.soundscape
	sound.preferences_path = "/tmp/petriverse-audio-test.cfg"
	var board = game.run.board
	game.run.selection.start(board.anchors[0])
	sound.sync(game.run, 0.1)
	expect(sound.events_played.get("connect", 0) == 1, "Selecting a cell gives tactile feedback")
	sound.sync(game.run, 0.1)
	expect(sound.events_played.get("connect", 0) == 1, "An unchanged selection never repeats its note")
	game.run.selection.visit(8)
	sound.sync(game.run, 0.25)
	game.run.selection.visit(9)
	sound.sync(game.run, 0.25)
	expect(sound.events_played.get("connect", 0) == 3, "A human-speed path gives one note per added cell")
	game.run.enemies = [Drifter.new(1, (board.anchors[0] + board.anchors[8] + board.anchors[9]) / 3.0, 0.0)]
	game.run.encounter.spawned = 1
	game.run.selection.visit(0)
	game.commit_selection()
	sound.sync(game.run, 0.1)
	expect(sound.events_played.get("close", 0) == 1 and sound.pending.size() == 1, "Capture sounds close now and digest with the animation")
	game.pause()
	var pending_time: float = sound.pending[0].remaining
	sound.sync(game.run, 3.0)
	expect(sound.pending[0].remaining == pending_time, "Pause freezes pending digestion cues")
	game.pause()
	sound.sync(game.run, 0.6)
	expect(sound.events_played.get("absorb", 0) == 1 and sound.pending.is_empty(), "Resume plays the delayed absorption once")
	game.run.integrity = 2
	var near_pair := Drifter.new(2, board.center + Vector2(150, 0), 0.0, "twinspore")
	near_pair.pair_angle = 0.0
	game.run.enemies = [near_pair]
	expect(game.run.critical_nuclei().size() == 1, "Critical danger uses each Twinspore nucleus rather than its safe-looking midpoint")
	sound.sync(game.run, 0.1)
	expect(sound.events_played.get("injury", 0) == 1 and sound.events_played.get("warning", 0) == 1, "Injury and nearby critical danger have distinct cues")
	for i in 20:
		sound.sync(game.run, 0.1)
	expect(sound.events_played.get("warning", 0) == 1, "Critical warning is restrained rather than a repeating alarm")
	sound.schedule("absorb", 0.5)
	game.restart()
	expect(sound.pending.is_empty() and sound.last_capture == 0, "Restart cancels old digestion and outcome cues")
	game.toggle_sound_settings()
	game.hud.refresh()
	expect(game.settings_open and game.run.state == "paused" and game.hud.music_slider.visible and not game.hud.center_button.visible, "Sound settings pause play and replace the pause overlay")
	game.hud.music_slider.value = 0.37
	game.hud.effects_slider.value = 0.52
	sound.toggle_mute()
	game.preferences_path = sound.preferences_path
	game.preferences_enabled = true
	game.toggle_quality()
	var comfort := Main.new()
	comfort.preferences_path = game.preferences_path
	comfort.load_preferences()
	expect(comfort.visual_quality == 1, "Visual quality persists alongside audio preferences")
	comfort.run.dispose()
	comfort.free()
	if DisplayServer.get_name() != "headless":
		game._process(0.0)
		await process_frame
		await process_frame
		RenderingServer.force_draw(false)
		expect(root.get_texture().get_image().save_png("res://artifacts/audio-settings.png") == OK, "Native settings screenshot saved")
	var restored := Soundscape.new()
	restored.preferences_path = sound.preferences_path
	restored.load_preferences()
	expect(is_equal_approx(restored.music_volume, 0.37) and is_equal_approx(restored.effects_volume, 0.52) and restored.muted, "Independent volume and mute settings persist")
	restored.free()
	game.toggle_sound_settings()
	expect(not game.settings_open and game.run.state == "active", "Closing settings resumes a previously active dish")
	game.pause()
	game.toggle_sound_settings()
	game.toggle_sound_settings()
	expect(game.run.state == "paused", "Closing settings preserves an existing explicit pause")
	expect(sound.voices.size() == Soundscape.VOICE_LIMIT, "Effect polyphony is bounded")
	var journey = preload("res://scripts/run_controller.gd").new(true,73,true,true)
	journey.stage_index = 5
	journey.start_stage()
	journey.begin_encounter()
	journey.enemies.clear()
	sound.sync(journey,6.0)
	expect(sound.desired_track=="glassgarden","Glassgarden has its own music, including its boss")
	journey.stage_index = 7
	sound.sync(journey,6.0)
	expect(sound.desired_track=="glassgarden","A boss retains the biome's musical identity")
	journey.stage_index = 8
	sound.sync(journey,6.0)
	expect(sound.desired_track=="deepwater","The Blue Deep has its own music")
	journey.stage_elapsed = 25.0
	sound.sync(journey,12.0)
	var active_water: float = sound.layer_gains["current-layer"]
	journey.stage_elapsed = 46.0
	sound.sync(journey,12.0)
	expect(active_water>sound.layer_gains["current-layer"]+0.15,"Water activity rises during the wave and subsides during recovery")
	journey.enemies.append(Drifter.new(901,journey.board.center+Vector2(105,0),5.4))
	sound.sync(journey,8.0)
	var danger: float = sound.layer_gains["tension-layer"]
	journey.enemies.clear()
	sound.sync(journey,12.0)
	expect(danger==0.0 and sound.layer_gains["tension-layer"]==0.0,"Old fixed-key tension music stays silent over the supplied scores")
	journey.capture_serial += 1
	journey.last_capture = {"capture_grade":"Grand sweep","positions":[journey.board.center]}
	sound.sync(journey,0.1)
	expect(sound.pending.filter(func(c): return c.name=="connect").size()==3,"A grand sweep schedules its three rising capture notes")
	sound.enabled = true
	sound.muted = true
	sound.sync(journey,0.1)
	expect(sound.layers.values().all(func(p): return p.volume_db<=-79.0),"Mute silences every adaptive layer")
	sound.enabled = false
	journey.mastery_awards.append({"id":"guardian","stage":8})
	sound.sync(journey,0.1)
	expect(sound.pending.any(func(c): return c.name=="mastery"),"An earned feat schedules its soft musical flourish")
	journey.state = "paused"
	var pending_mastery: Array = sound.pending.duplicate(true)
	sound.sync(journey,2.0)
	expect(sound.pending==pending_mastery,"Pause holds a mastery flourish until play resumes")
	journey.state = "active"
	sound.sync(journey,1.0)
	expect(sound.events_played.get("mastery",0)==1,"The flourish plays once on resume")
	sound.sync(journey,10.0)
	expect(sound.events_played.get("mastery",0)==1,"An existing award does not repeat its sound")
	game.run.mastery_awards.append({"id":"gatherer","stage":2})
	game.reset_presentation()
	sound.sync(game.run,0.1)
	expect(not sound.pending.any(func(c): return c.name=="mastery"),"Restoring presentation does not replay already earned feats")
	journey.state = "active"
	for family in sound.BUILD_LAYERS:
		journey.mutations = [family]
		sound.sync(journey,18.0)
		var audible: String = sound.BUILD_LAYERS[family]
		expect(sound.layer_gains[audible]==0.0 and not sound.layers[audible].playing,"The %s colony adds no old harmony over the supplied score" % family)
		for other in sound.BUILD_LAYERS.values():
			if other!=audible:
				expect(sound.layer_gains[other]<0.001,"A former colony texture fades instead of accumulating: "+other)
	var before_layer: float = sound.layer_gains["hunter-layer"]
	journey.mutations = ["elastic"]
	sound.sync(journey,0.1)
	expect(before_layer==0.0 and sound.layer_gains["hunter-layer"]==0.0 and sound.layer_gains["feast-layer"]==0.0,"Changing colony anatomy keeps the supplied score free of old musical overlays")
	sound.music_volume = 0.0
	sound.sync(journey,0.1)
	expect(sound.layers["feast-layer"].volume_db<=-79.0,"The music slider also silences colony-specific layers")
	sound.music_volume = 0.65
	sound.muted = true
	sound.sync(journey,0.1)
	expect(sound.layers.values().all(func(p): return p.volume_db<=-79.0),"Mute includes every new musical layer")
	journey.dispose()
	if OS.get_cmdline_user_args().has("--require-assets"):
		for name in Soundscape.EFFECTS + ["pond"] + Soundscape.TRACKS + Soundscape.LAYERS:
			expect(sound.streams.has(name), "Bundled audio asset: " + name)
			if sound.streams.has(name):
				expect(sound.streams[name].get_length() > 0.1, "Decodable audio: " + name)
		var durations := {"stillwater":189.2,"glassgarden":139.2,"deepwater":182.8}
		for name in Soundscape.TRACKS:
			expect(sound.streams.has(name) and absf(sound.streams[name].get_length()-durations[name])<0.1,"The supplied full-length score is loaded: "+name)
			if sound.streams.has(name):
				expect(not sound.streams[name].loop,"Music loops use the smooth two-player overlap: "+name)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(sound.preferences_path))
	game.free()
	print("AUDIO: %d checks; %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
