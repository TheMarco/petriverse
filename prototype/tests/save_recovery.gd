extends SceneTree
const Run = preload("res://scripts/run_controller.gd")
const Save = preload("res://scripts/journey_save.gd")
const Profile = preload("res://scripts/journey_profile.gd")
const JOURNEY_PATH := "/tmp/microverse-save-recovery-journey.cfg"
const PROFILE_PATH := "/tmp/microverse-save-recovery-profile.cfg"
const LEGACY_PATH := "/tmp/microverse-save-recovery-legacy.cfg"
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("exercise")

func expect(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("FAIL: ", label)

func _clean(base: String) -> void:
	for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
		var candidate: String = base + suffix
		if FileAccess.file_exists(candidate) or DirAccess.dir_exists_absolute(candidate):
			DirAccess.remove_absolute(candidate)

func _corrupt(candidate: String) -> void:
	var file := FileAccess.open(candidate, FileAccess.WRITE)
	file.store_string("not a config [[[\n")
	file.close()

func exercise() -> void:
	_clean(JOURNEY_PATH)
	var run := Run.new(true, 73, true, true)
	run.score = 111
	run.checkpoint = {"step": 1}
	expect(Save.write(run, JOURNEY_PATH) == OK, "Journey first write succeeds")
	var first := Save.read(JOURNEY_PATH)
	expect(not first.is_empty() and int(first.snapshot.run.score) == 111 and first.get("recovered_from_backup") == false and int(first.checkpoint.get("step", -1)) == 1, "Journey valid roundtrip keeps snapshot and checkpoint")
	run.score = 222
	run.checkpoint = {"step": 2}
	expect(Save.write(run, JOURNEY_PATH) == OK, "Journey second write succeeds")
	expect(FileAccess.file_exists(JOURNEY_PATH + ".bak"), "Journey second write creates backup")
	var second := Save.read(JOURNEY_PATH)
	expect(not second.is_empty() and int(second.snapshot.run.score) == 222 and second.get("recovered_from_backup") == false, "Journey second write is primary")
	var malformed := ConfigFile.new()
	malformed.load(JOURNEY_PATH)
	malformed.set_value("journey","checkpoint","invalid")
	malformed.save(JOURNEY_PATH)
	expect(int(Save.read(JOURNEY_PATH).snapshot.run.score)==111, "Malformed checkpoint falls back before Continue can use it")
	Save.write(run,JOURNEY_PATH)
	_corrupt(JOURNEY_PATH)
	var fallback := Save.read(JOURNEY_PATH)
	expect(not fallback.is_empty() and int(fallback.snapshot.run.score) == 111 and fallback.get("recovered_from_backup") == true and int(fallback.checkpoint.get("step", -1)) == 1, "Corrupt journey primary falls back to previous state")
	run.score = 333
	run.checkpoint = {"step": 3}
	expect(Save.write(run, JOURNEY_PATH) == OK, "Journey write after fallback succeeds")
	var rewritten := Save.read(JOURNEY_PATH)
	expect(not rewritten.is_empty() and int(rewritten.snapshot.run.score) == 333 and rewritten.get("recovered_from_backup") == false, "Successful journey save clears fallback status")
	_corrupt(JOURNEY_PATH)
	var preserved := Save.read(JOURNEY_PATH)
	expect(not preserved.is_empty() and int(preserved.snapshot.run.score) == 111 and preserved.get("recovered_from_backup") == true, "Write after fallback did not overwrite backup with corrupt primary")
	run.score = 444
	expect(Save.write(run, JOURNEY_PATH) == OK, "Journey write restores primary")
	DirAccess.make_dir_absolute(JOURNEY_PATH + ".tmp")
	run.score = 999
	expect(Save.write(run, JOURNEY_PATH) != OK, "Blocked journey temp write returns an error")
	DirAccess.remove_absolute(JOURNEY_PATH + ".tmp")
	var intact := Save.read(JOURNEY_PATH)
	expect(not intact.is_empty() and int(intact.snapshot.run.score) == 444 and intact.get("recovered_from_backup") == false, "Failed journey write leaves primary recoverable")
	DirAccess.make_dir_absolute(JOURNEY_PATH + ".bak.tmp")
	expect(Save.write(run, JOURNEY_PATH) != OK, "Blocked backup refresh aborts journey replacement")
	expect(int(Save.read(JOURNEY_PATH).snapshot.run.score)==444, "Backup refresh failure preserves primary")
	DirAccess.remove_absolute(JOURNEY_PATH + ".bak.tmp")
	_corrupt(JOURNEY_PATH)
	var backup_intact := Save.read(JOURNEY_PATH)
	expect(not backup_intact.is_empty() and int(backup_intact.snapshot.run.score) == 111 and backup_intact.get("recovered_from_backup") == true, "Failed journey write leaves backup recoverable")
	_corrupt(JOURNEY_PATH + ".bak")
	expect(Save.read(JOURNEY_PATH).is_empty(), "Corrupt journey primary and backup are rejected safely")
	run.dispose()

	_clean(PROFILE_PATH)
	var profile := Profile.new()
	profile.path = PROFILE_PATH
	profile.load_profile()
	expect(profile.victories == 0 and profile.deepest_dish == 0 and profile.discovered.is_empty() and not profile.recovered_from_backup, "Missing profile loads defaults")
	profile.victories = 1
	profile.deepest_dish = 2
	profile.best_score = 50
	profile.discovered = ["alpha"]
	expect(profile.save_profile() and not profile.dirty and profile.last_error == OK, "Profile first save succeeds")
	var loaded := Profile.new()
	loaded.path = PROFILE_PATH
	loaded.load_profile()
	expect(loaded.victories == 1 and loaded.deepest_dish == 2 and loaded.best_score == 50 and loaded.discovered == ["alpha"] and not loaded.recovered_from_backup, "Profile valid roundtrip")
	profile.victories = 2
	profile.best_score = 80
	expect(profile.save_profile(), "Profile second save succeeds")
	_corrupt(PROFILE_PATH)
	var recovered := Profile.new()
	recovered.path = PROFILE_PATH
	recovered.load_profile()
	expect(recovered.victories == 1 and recovered.best_score == 50 and recovered.recovered_from_backup, "Corrupt profile primary falls back to previous state")
	recovered.victories = 3
	expect(recovered.save_profile() and not recovered.recovered_from_backup, "Profile save after fallback clears fallback status")
	_corrupt(PROFILE_PATH)
	var profile_preserved := Profile.new()
	profile_preserved.path = PROFILE_PATH
	profile_preserved.load_profile()
	expect(profile_preserved.victories == 1 and profile_preserved.recovered_from_backup, "Profile write after fallback preserved backup")
	_corrupt(PROFILE_PATH + ".bak")
	var rejected := Profile.new()
	rejected.path = PROFILE_PATH
	rejected.load_profile()
	expect(rejected.victories == 0 and not rejected.recovered_from_backup, "Corrupt profile primary and backup load defaults safely")
	_clean(PROFILE_PATH)
	var writer := Profile.new()
	writer.path = PROFILE_PATH
	writer.victories = 5
	expect(writer.save_profile(), "Profile write-failure setup first save")
	writer.victories = 6
	expect(writer.save_profile(), "Profile write-failure setup second save")
	DirAccess.make_dir_absolute(PROFILE_PATH + ".tmp")
	writer.victories = 9
	expect(not writer.save_profile() and writer.dirty and writer.last_error != OK, "Blocked profile temp write reports dirty error")
	DirAccess.remove_absolute(PROFILE_PATH + ".tmp")
	var surviving := Profile.new()
	surviving.path = PROFILE_PATH
	surviving.load_profile()
	expect(surviving.victories == 6 and not surviving.recovered_from_backup, "Failed profile write leaves primary recoverable")

	DirAccess.make_dir_absolute(PROFILE_PATH + ".bak.tmp")
	expect(not writer.save_profile(), "Blocked profile backup refresh aborts replacement")
	DirAccess.remove_absolute(PROFILE_PATH + ".bak.tmp")
	var invalid := ConfigFile.new()
	invalid.set_value("profile","residents","not an array")
	invalid.save(PROFILE_PATH)
	surviving.load_profile()
	expect(surviving.victories==5 and surviving.recovered_from_backup, "Parseable but malformed profile falls back to backup")

	_clean(LEGACY_PATH)
	var legacy_config := ConfigFile.new()
	legacy_config.set_value("profile", "residents", [{"token": "t1", "form": "glowdrift", "rare": true}])
	legacy_config.set_value("profile", "deepest_dish", 3)
	legacy_config.set_value("profile", "victories", 7)
	expect(legacy_config.save(LEGACY_PATH) == OK, "Legacy profile fixture writes")
	var legacy := Profile.new()
	legacy.path = LEGACY_PATH
	legacy.load_profile()
	expect(legacy.victories == 7 and legacy.deepest_dish == 3 and legacy.residents.size() == 1 and legacy.pond_memories.is_empty() and legacy.introduced_species.is_empty() and not legacy.recovered_from_backup, "Old profile loads with default fields")
	_clean(JOURNEY_PATH)
	_clean(PROFILE_PATH)
	_clean(LEGACY_PATH)
	print("SAVE RECOVERY: %d checks; %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
