extends Node
## User-supplied scores and baked ElevenLabs effects; all playback stays offline.

const ROOT := "res://assets/audio/"
const EFFECTS := ["connect", "close", "absorb", "injury", "fracture", "evolve", "warning", "victory", "loss", "mastery"]
const TRACKS := ["stillwater", "glassgarden", "deepwater"]
const TRACK_FILES := {"stillwater":"petriverse-stillwater", "glassgarden":"petriverse-glassgarden", "deepwater":"petriverse-blue-deep"}
# These complete scores replace the original fixed-key adaptive music beds.
const TONAL_LAYERS_ENABLED := false
const LAYERS := ["current-layer", "tension-layer", "nimble-layer", "feast-layer", "hunter-layer"]
const BUILD_LAYERS := {"fission":"nimble-layer", "elastic":"feast-layer", "symbiosis":"hunter-layer"}
const Rhythm = preload("res://scripts/encounter_rhythm.gd")
const MotherAlert = preload("res://scripts/mother_alert.gd")
const NOTES := [0, 2, 4, 7, 9, 12, 14, 16, 19, 21]
const CROSSFADE := 5.0
const VOICE_LIMIT := 10

var music_volume := 0.65
var effects_volume := 0.70
var muted := false
var enabled := true
var preferences_path := "user://preferences.cfg"
var streams: Dictionary = {}
var music: Array[AudioStreamPlayer] = []
var voices: Array[AudioStreamPlayer] = []
var pond: AudioStreamPlayer
var layers: Dictionary = {}
var layer_gains := {"current-layer":0.0,"tension-layer":0.0,"nimble-layer":0.0,"feast-layer":0.0,"hunter-layer":0.0}
var current_track := "stillwater"
var desired_track := "stillwater"
var active_music := 0
var crossfading := false
var fade_time := 0.0
var boot_fade := 0.0
var pause_gain := 1.0
var duck := 0.0
var clock := 0.0
var pending: Array = []
var recent: Dictionary = {}
var last_capture := 0
var last_phage_burst := ""
var last_integrity := 5
var last_path: Array = []
var last_state := "active"
var last_warning := -20.0
var last_mastery := -20.0
var last_mastery_count := 0
var events_played: Dictionary = {}

func _ready() -> void:
	load_preferences()
	for name in EFFECTS + ["pond"] + TRACKS + LAYERS:
		var path: String = ROOT + TRACK_FILES.get(name,name) + ".ogg"
		if ResourceLoader.exists(path):
			streams[name] = load(path)
			if name in TRACKS:
				streams[name] = streams[name].duplicate()
				streams[name].loop = false # The two-player crossfader owns each loop.
	for i in 2:
		var player := AudioStreamPlayer.new()
		player.volume_db = -80.0
		add_child(player)
		music.append(player)
	for i in VOICE_LIMIT:
		var player := AudioStreamPlayer.new()
		add_child(player)
		voices.append(player)
	pond = AudioStreamPlayer.new()
	add_child(pond)
	if streams.has("pond"):
		pond.stream = streams.pond.duplicate()
		pond.stream.loop = true
		if enabled:
			pond.play()
	for name in LAYERS:
		var player := AudioStreamPlayer.new()
		player.volume_db = -80.0
		add_child(player)
		layers[name] = player
		if streams.has(name):
			player.stream = streams[name].duplicate()
			player.stream.loop = true
			if enabled and (name=="current-layer" or TONAL_LAYERS_ENABLED):
				player.play()
	start_music("stillwater")

func load_preferences() -> void:
	var config := ConfigFile.new()
	if config.load(preferences_path) != OK:
		return
	music_volume = clampf(float(config.get_value("audio", "music", 0.65)), 0.0, 1.0)
	effects_volume = clampf(float(config.get_value("audio", "effects", 0.70)), 0.0, 1.0)
	muted = bool(config.get_value("audio", "muted", false))

func save_preferences() -> void:
	var config := ConfigFile.new()
	config.load(preferences_path)
	config.set_value("audio", "music", music_volume)
	config.set_value("audio", "effects", effects_volume)
	config.set_value("audio", "muted", muted)
	config.save(preferences_path)

func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	save_preferences()

func set_effects_volume(value: float) -> void:
	effects_volume = clampf(value, 0.0, 1.0)
	save_preferences()

func toggle_mute() -> void:
	muted = not muted
	save_preferences()

func gain_db(value: float) -> float:
	return linear_to_db(maxf(value, 0.0001))

func start_music(track: String) -> void:
	current_track = track
	desired_track = track
	if not streams.has(track):
		return
	music[active_music].stream = streams[track]
	if enabled:
		music[active_music].play()

func transition_music(track: String) -> void:
	if not streams.has(track) or crossfading:
		return
	var incoming := music[1 - active_music]
	incoming.stream = streams[track]
	incoming.volume_db = -80.0
	if enabled:
		incoming.play()
	current_track = track
	crossfading = true
	fade_time = 0.0

func update_music(delta: float, paused: bool) -> void:
	boot_fade = minf(1.0, boot_fade + delta / 3.0)
	pause_gain = move_toward(pause_gain, 0.45 if paused else 1.0, delta * 0.7)
	duck = maxf(0.0, duck - delta)
	var global_gain := 0.0 if muted or not enabled else 1.0
	var base_gain := music_volume * pause_gain * boot_fade * global_gain * (0.78 if duck > 0.0 else 1.0)
	var active := music[active_music]
	if not crossfading and streams.has(desired_track):
		if desired_track != current_track:
			transition_music(desired_track)
		elif active.stream != null and active.get_playback_position() >= active.stream.get_length() - CROSSFADE:
			transition_music(current_track)
	if crossfading:
		fade_time = minf(CROSSFADE, fade_time + delta)
		var amount := fade_time / CROSSFADE
		# Equal-power overlap preserves the atmosphere at a loop or stage boundary.
		active.volume_db = gain_db(base_gain * cos(amount * PI * 0.5))
		music[1 - active_music].volume_db = gain_db(base_gain * sin(amount * PI * 0.5))
		if fade_time >= CROSSFADE:
			active.stop()
			active_music = 1 - active_music
			crossfading = false
	else:
		active.volume_db = gain_db(base_gain)
	pond.volume_db = gain_db(effects_volume * 0.42 * pause_gain * boot_fade * global_gain)

func update_layers(run: RefCounted, delta: float) -> void:
	var current := 0.0
	var tension := 0.0
	if run.state in ["active","paused"]:
		tension = MotherAlert.sample(run).strength*0.60
		if run.journey:
			current = Rhythm.sample(run).energy*0.48
			var boss = run.boss()
			if boss != null and boss.can_take_pulse():
				tension = maxf(tension,0.32)
	var targets := {"current-layer":current,"tension-layer":tension}
	var build: String = run.Mutations.build_anchor(run.mutations)
	var space := 1.0 if run.state in ["active","paused"] else 0.65
	for id in BUILD_LAYERS:
		targets[BUILD_LAYERS[id]] = (minf(0.38,0.23+0.025*run.mutations.size())*space) if id==build else 0.0
	for name in LAYERS:
		if name!="current-layer" and not TONAL_LAYERS_ENABLED:
			targets[name] = 0.0
		# Slow, continuous envelopes. No abrupt loop restarts or tempo changes.
		layer_gains[name] = lerpf(layer_gains[name],targets[name],1.0-exp(-maxf(delta,0.0)/3.0))
		var master := effects_volume if name=="current-layer" else music_volume
		var gain: float = master*layer_gains[name]*pause_gain*boot_fade
		layers[name].volume_db = gain_db(0.0 if muted or not enabled else gain)

func play_effect(name: String, gain: float = 1.0, pitch: float = 1.0) -> void:
	# Swept pointer events and simultaneous damage cannot flood the mix.
	if float(recent.get(name, -100.0)) > clock - 0.065:
		return
	recent[name] = clock
	events_played[name] = int(events_played.get(name, 0)) + 1
	if not streams.has(name) or muted or not enabled or effects_volume <= 0.0:
		return
	var voice: AudioStreamPlayer = null
	for candidate in voices:
		if not candidate.playing:
			voice = candidate
			break
	if voice == null:
		# Keep injury and outcome cues audible without raising total polyphony.
		if name in ["injury", "victory", "loss"]:
			voice = voices[0]
			voice.stop()
		else:
			return
	voice.stream = streams[name]
	voice.pitch_scale = clampf(pitch, 0.6, 3.4)
	voice.set_meta("gain", gain)
	voice.volume_db = gain_db(effects_volume * gain * 0.62)
	voice.play()
	if name in ["close", "injury", "evolve", "victory", "loss"]:
		duck = 1.1

func schedule(name: String, delay: float, gain: float = 1.0) -> void:
	pending.append({"name": name, "remaining": delay, "gain": gain})

func reset_run() -> void:
	last_phage_burst = ""
	for voice in voices:
		voice.stop()
		voice.stream_paused = false
	pending.clear()
	recent.clear()
	last_capture = 0
	last_integrity = 5
	last_path.clear()
	last_state = "active"
	last_warning = -20.0
	last_mastery = -20.0
	last_mastery_count = 0
	desired_track = "stillwater"
	clock = 0.0
	# Music continues through restart; a repeated intro would break the calm.

func sync(run: RefCounted, delta: float) -> void:
	desired_track = TRACKS[clampi(run.stage_index/4,0,2)] if run.journey else "deepwater" if run.full_run and run.stage_index==3 else "stillwater"
	if run.state=="home":
		desired_track = "stillwater"
	var paused: bool = run.state == "paused"
	update_music(delta, paused)
	update_layers(run,delta)
	for voice in voices:
		voice.stream_paused = paused
		voice.volume_db = gain_db(0.0 if muted or not enabled else effects_volume * float(voice.get_meta("gain", 1.0)) * 0.62)
	if paused:
		last_path.clear()
		return
	clock += delta
	for cue in pending:
		cue.remaining -= delta
		if cue.remaining <= 0.0:
			play_effect(cue.name, cue.gain)
	pending = pending.filter(func(cue): return cue.remaining > 0.0)
	if not run.phages.bursts.is_empty():
		var burst: Dictionary = run.phages.bursts[-1]
		var key := "%d:%d:%d" % [run.appearance_seed(),run.stage_index,burst.serial]
		if key!=last_phage_burst and burst.age<0.4:
			last_phage_burst = key
			play_effect("fracture",0.24,0.78)
			schedule("absorb",0.28,0.30)
	if run.capture_serial != last_capture:
		last_capture = run.capture_serial
		play_effect("close", 0.65)
		if not run.last_capture.get("positions", []).is_empty():
			schedule("absorb", 0.55, 0.75)
		if run.last_capture.get("rescued",0)>0 and run.last_capture.get("mastery",[]).is_empty() and clock-last_mastery>=8.0:
			schedule("mastery",0.9,0.32)
			last_mastery = clock
		if run.last_capture.get("armor_hits", 0) > 0:
			schedule("fracture", 0.12, 0.65)
		last_path.clear()
	else:
		var path: Array = run.selection.path
		if path != last_path and not path.is_empty():
			var step := clampi(path.size() - 1, 0, NOTES.size() - 1)
			play_effect("connect", 0.35 if path.size() < last_path.size() else 0.55, pow(2.0, NOTES[step] / 12.0))
		last_path = path.duplicate()
	if run.integrity < last_integrity:
		play_effect("injury", 0.82)
	last_integrity = run.integrity
	if run.journey and run.mastery_awards.size()!=last_mastery_count:
		if run.mastery_awards.size()>last_mastery_count and clock-last_mastery>=8.0:
			schedule("mastery",0.9,0.60)
			last_mastery = clock
		last_mastery_count = run.mastery_awards.size()
	if run.state != last_state:
		if run.state == "success":
			schedule("victory", 0.7, 0.8)
		elif run.state == "loss":
			schedule("loss", 1.3, 0.8)
		elif run.state == "evolve":
			schedule("evolve", 0.4, 0.7)
		last_state = run.state
	if run.state == "active" and (not run.critical_nuclei().is_empty() or MotherAlert.sample(run).strength>0.65) and clock - last_warning >= 12.0:
		play_effect("warning", 0.45)
		last_warning = clock

func _exit_tree() -> void:
	# Release active Ogg playback before its source streams on scene shutdown.
	# This also makes returning from an embedded/test scene deterministic.
	for player in music + voices + layers.values():
		if is_instance_valid(player):
			player.stop()
			player.stream = null
	if is_instance_valid(pond):
		pond.stop()
		pond.stream = null
	pending.clear()
	streams.clear()
