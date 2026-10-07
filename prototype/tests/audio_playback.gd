extends SceneTree
## Native mixer verification. Run with Movie Maker to capture deterministic output.
class AudioScene:
	extends "res://scripts/main.gd"
	func _init() -> void:
		pause_on_focus_loss = false
const Enemy = preload("res://scripts/drifter.gd")
var game: Node2D
var capture: AudioEffectCapture
var raw: FileAccess
var frame := 0
var checks := 0
var failures: Array[String] = []
var peak := 0.0
var energy := 0.0
var samples := 0
var mute_energy := 0.0
var mute_samples := 0
var paused_voice: AudioStreamPlayer
var paused_position := 0.0
var initial_music := 0
var loop_overlap_seen := false
var boss_overlap_seen := false
var windows: Array = []
var window_energy := 0.0
var window_samples := 0

func _initialize() -> void:
	root.unfocusable = true
	call_deferred("setup")

func expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		printerr("FAIL: ", description)

func setup() -> void:
	root.gui_disable_input = true
	root.size = Vector2i(1280, 900)
	root.content_scale_size = root.size
	RenderingServer.render_loop_enabled = false
	capture = AudioEffectCapture.new()
	capture.buffer_length = 1.0
	AudioServer.add_bus_effect(0, capture)
	raw = FileAccess.open("/tmp/microverse-native-audio.f32", FileAccess.WRITE)
	game = AudioScene.new()
	game.preferences_enabled = false
	game.preferences_path = "/tmp/petriverse-audio-playback-test.cfg"
	game.save_records = false
	game.run.journey = false # This fixture exercises the isolated enclosure rules.
	game.run.harvest_mode = false
	game.run.full_run = false
	game.run.restart()
	root.add_child(game)
	DisplayServer.window_set_title("PETRIVERSE — audio verification")
	root.mode = Window.MODE_MINIMIZED
	game.set_process(false)
	game.set_physics_process(false)
	game.set_process_unhandled_input(false)
	game.run.encounter.next_spawn = 1000.0
	var sound = game.soundscape
	sound.muted = false
	sound.music_volume = 0.65
	sound.effects_volume = 0.70
	var expected: int = sound.EFFECTS.size()+sound.TRACKS.size()+sound.LAYERS.size()+1
	expect(sound.streams.size() == expected, "All bundled scores and effects load in the native engine")
	if sound.streams.size() != expected:
		finish()
		return
	var board = game.run.board
	game.run.enemies = [Enemy.new(1, (board.anchors[0] + board.anchors[8] + board.anchors[9]) / 3.0, 0.0)]
	game.run.encounter.spawned = 1
	game.run.mutations = ["fission"]

func read_output() -> void:
	var available := capture.get_frames_available()
	if available == 0:
		return
	var buffer := capture.get_buffer(available)
	raw.store_buffer(buffer.to_byte_array())
	for sample in buffer:
		var squared := sample.length_squared()
		peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
		energy += squared
		samples += 2
		window_energy += squared
		window_samples += 2
		if frame >= 1340 and frame < 1380:
			mute_energy += squared
			mute_samples += 2
	if frame % 6 == 0 and window_samples > 0:
		windows.append({"seconds": frame / 60.0, "rms_db": linear_to_db(maxf(0.00000001, sqrt(window_energy / window_samples)))})
		window_energy = 0.0
		window_samples = 0

func _process(_delta: float) -> bool:
	if game == null or not is_instance_valid(game):
		return false
	frame += 1
	read_output()
	var sound = game.soundscape
	match frame:
		120: game.run.selection.start(game.run.board.anchors[0])
		135: game.run.selection.visit(8)
		150: game.run.selection.visit(9)
		165:
			game.run.selection.visit(0)
			game.commit_selection()
		330:
			expect(sound.events_played.get("connect", 0) == 3 and sound.events_played.get("close", 0) == 1 and sound.events_played.get("absorb", 0) == 1, "Real timed drawing produces connection, closure and digestion cues")
			expect(not sound.layers["nimble-layer"].playing and sound.layers["nimble-layer"].volume_db<=-79.0,"Nimble's old harmonic loop stays silent over the new score")
		340: sound.play_effect("absorb", 0.5)
		360: game.pause()
		365:
			for voice in sound.voices:
				if voice.stream == sound.streams.absorb and voice.stream_paused:
					paused_voice = voice
					paused_position = voice.get_playback_position()
			expect(paused_voice != null, "Pause suspends an actually playing effect")
		475:
			if paused_voice != null:
				expect(absf(paused_voice.get_playback_position() - paused_position) < 0.025, "The paused audio stream's playback position stays fixed")
		480:
			game.pause()
			game.run.mutations = ["elastic"]
		540:
			initial_music = sound.active_music
			sound.music[initial_music].seek(sound.music[initial_music].stream.get_length() - 6.0)
		930:
			expect(loop_overlap_seen and sound.active_music != initial_music and not sound.crossfading, "Track end overlaps two playing music streams and finishes the loop crossfade")
			expect(not sound.layers["feast-layer"].playing and sound.layers["feast-layer"].volume_db<=-79.0,"Feast's old harmonic loop stays silent over the new score")
			game.run.mutations = ["symbiosis"]
		960:
			game.run.full_run = true
			game.run.stage_index = 3
			game.run.enemies.clear()
			game.run.start_stage()
		1290:
			expect(boss_overlap_seen and sound.current_track == "deepwater" and not sound.crossfading, "Boss arrival crossfades to the supplied track3 score")
			expect(not sound.layers["hunter-layer"].playing and sound.layers["hunter-layer"].volume_db<=-79.0,"Hunter's old harmonic loop stays silent over the new score")
		1320: sound.muted = true
		1380:
			expect(mute_samples > 0 and sqrt(mute_energy / mute_samples) < 0.0001, "Mute reduces the actual mixed output below -80 dBFS RMS")
			sound.muted = false
		1450:
			game.run.state = "success"
			game.run.enemies.clear()
		1700: expect(sound.events_played.get("victory", 0) == 1, "The generated victory cue plays exactly once")
	game.run.step(1.0 / 60.0)
	game._process(1.0 / 60.0)
	if frame > 540 and frame < 930 and sound.crossfading:
		loop_overlap_seen = loop_overlap_seen or (sound.music[0].playing and sound.music[1].playing)
	if frame > 960 and frame < 1290 and sound.crossfading:
		boss_overlap_seen = boss_overlap_seen or (sound.music[0].playing and sound.music[1].playing)
	call_deferred("record_frame")
	return false

func record_frame() -> void:
	RenderingServer.force_draw(false, 1.0 / 60.0)
	if frame >= 1800:
		read_output()
		expect(samples > 44100 * 2 * 25 and energy > 0.01, "Native mixer emitted more than 25 seconds of non-silent stereo audio")
		expect(peak < 0.95, "Combined music, ambience and effects retain unclipped output headroom")
		expect(capture.get_discarded_frames() == 0, "The captured audio contains no dropped mixer frames")
		finish()

func finish() -> void:
	var report := {"engine": Engine.get_version_info().string, "driver": AudioServer.get_driver_name(), "sample_rate": AudioServer.get_mix_rate(), "channels": 2, "peak_dbfs": linear_to_db(maxf(0.00000001, peak)), "rms_dbfs": linear_to_db(maxf(0.00000001, sqrt(energy / maxf(samples, 1)))), "frames": samples / 2, "dropped_frames": capture.get_discarded_frames(), "checks": checks, "failures": failures, "windows": windows}
	var file := FileAccess.open("res://artifacts/audio-playback-report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ") + "\n")
	raw.close()
	print("AUDIO PLAYBACK: %d checks; %d failures; peak %.2f dBFS" % [checks, failures.size(), report.peak_dbfs])
	AudioServer.remove_bus_effect(0, AudioServer.get_bus_effect_count(0) - 1)
	game.free()
	game = null
	paused_voice = null
	capture = null
	quit(0 if failures.is_empty() else 1)
