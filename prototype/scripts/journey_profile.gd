extends RefCounted
var path := "user://journey-profile.cfg"
var discovered: Array = []
var introduced_species: Array = []
var offered_species: Array = []
var residents: Array = []
var cleared_encounters: Array = []
var last_colony_traits: Array = []
var pond_memories: Array = []
var dirty := false
var deepest_dish := 0
var victories := 0
var best_score := 0
## The best score before the latest victory, for "new personal best". Not saved.
var previous_best := -1
var completed_seeds: Array = []
var last_error := OK
var recovered_from_backup := false

func _config_valid(candidate: String) -> bool:
	var config := ConfigFile.new()
	if config.load(candidate) != OK or not config.has_section("profile"):
		return false
	for key in ["introduced_species","offered_species","residents","cleared_encounters","last_colony_traits","pond_memories","discovered","completed_seeds"]:
		if not config.get_value("profile", key, []) is Array:
			return false
	for key in ["deepest_dish","victories","best_score"]:
		if not config.get_value("profile", key, 0) is int:
			return false
	for resident in config.get_value("profile", "residents", []):
		if not resident is Dictionary or not resident.get("token") is String or not resident.get("form") is String:
			return false
	return true

func _remove_file(candidate: String) -> void:
	if FileAccess.file_exists(candidate):
		DirAccess.remove_absolute(candidate)

func _replace_file(temporary: String, target: String) -> Error:
	return DirAccess.rename_absolute(temporary, target)

func _refresh_backup() -> Error:
	# Never replace a valid backup with missing or invalid current data.
	if not _config_valid(path):
		return OK
	var backup := path + ".bak"
	var backup_temporary := backup + ".tmp"
	_remove_file(backup_temporary)
	var error := DirAccess.copy_absolute(path, backup_temporary)
	return error if error != OK else _replace_file(backup_temporary, backup)

func _apply(config: ConfigFile) -> void:
	residents = Array(config.get_value("profile", "residents", []))
	cleared_encounters = Array(config.get_value("profile", "cleared_encounters", []))
	last_colony_traits = Array(config.get_value("profile", "last_colony_traits", []))
	pond_memories = Array(config.get_value("profile", "pond_memories", []))
	discovered = Array(config.get_value("profile", "discovered", []))
	introduced_species = Array(config.get_value("profile", "introduced_species", [])).filter(func(id): return id is String)
	offered_species = Array(config.get_value("profile", "offered_species", [])).filter(func(id): return id is String)
	deepest_dish = clampi(int(config.get_value("profile", "deepest_dish", 0)), 0, 3)
	victories = int(config.get_value("profile", "victories", 0))
	best_score = int(config.get_value("profile", "best_score", 0))
	completed_seeds = Array(config.get_value("profile", "completed_seeds", []))

func load_profile() -> void:
	recovered_from_backup = false
	var config := ConfigFile.new()
	if _config_valid(path) and config.load(path) == OK:
		_apply(config)
		return
	var backup := ConfigFile.new()
	if _config_valid(path + ".bak") and backup.load(path + ".bak") == OK:
		_apply(backup)
		recovered_from_backup = true

func unlocked(id: String) -> bool:
	return id == "wanderer" or (id == "weaver" and deepest_dish >= 1) or (id == "symbiont" and deepest_dish >= 2)

func observe(run: RefCounted) -> bool:
	var changed := dirty
	var tokens := {}
	for resident in residents:
		tokens[resident.token] = true
	for specimen in run.rescued_specimens:
		if not tokens.has(specimen.token):
			var resident: Dictionary = specimen.duplicate(true)
			resident.arrived_after = cleared_encounters.size()
			resident.welcomed = false
			residents.append(resident)
			tokens[specimen.token] = true
			changed = true
	# Growth follows new accomplishments, not a wall-clock wait or retry grind.
	if run.state in ["evolve","success"]:
		var encounter := "%d:%s" % [run.run_seed,run.encounter_key()]
		if not cleared_encounters.has(encounter):
			cleared_encounters.append(encounter)
			last_colony_traits = run.mutations.duplicate()
			changed = true
	for species in run.seen_species:
		if not discovered.has(species):
			discovered.append(species)
			changed = true
	if run.completed_dishes > deepest_dish:
		deepest_dish = run.completed_dishes
		changed = true
	if run.state == "success" and not completed_seeds.has(run.run_seed):
		completed_seeds.append(run.run_seed)
		victories += 1
		previous_best = best_score
		best_score = maxi(best_score, run.score)
		changed = true
	for award in run.mastery_awards:
		var token := "%d:%s:%s" % [run.run_seed,award.get("encounter",str(award.stage)),award.id]
		if not pond_memories.any(func(memory): return memory.token==token):
			pond_memories.append({"token":token,"id":award.id,"stage":award.stage})
			changed = true
	if changed:
		save_profile()
	return changed

func save_profile() -> bool:
	var config := ConfigFile.new()
	for property in ["introduced_species","offered_species","residents","cleared_encounters","last_colony_traits","pond_memories","discovered","deepest_dish","victories","best_score","completed_seeds"]:
		config.set_value("profile",property,get(property))
	var temporary := path + ".tmp"
	last_error = config.save(temporary)
	if last_error != OK:
		_remove_file(temporary)
		dirty = true
		return false
	if not _config_valid(temporary):
		_remove_file(temporary)
		last_error = ERR_INVALID_DATA
		dirty = true
		return false
	last_error = _refresh_backup()
	if last_error != OK:
		_remove_file(temporary)
		dirty = true
		return false
	last_error = _replace_file(temporary, path)
	dirty = last_error != OK
	if dirty:
		_remove_file(temporary)
	else:
		recovered_from_backup = false
	return not dirty

func rename_resident(token: String, nickname: String) -> bool:
	for resident in residents:
		if resident.token==token:
			resident.nickname = nickname.replace("\n"," ").replace("\r"," ").replace("\t"," ").strip_edges().substr(0,24)
			return save_profile()
	return false

func resident_label(resident: Dictionary) -> String:
	var nickname: String = resident.get("nickname","")
	return nickname if not nickname.is_empty() else preload("res://scripts/creature_forms.gd").definition(resident.form).get("name","Pearl spore")

func keepsake_unlocked(id: String) -> bool:
	return pond_memories.any(func(memory): return memory.id==id)

func companion_for(resident: Dictionary, visible_residents: Array) -> Dictionary:
	# Stable identity chooses an older guide for a young resident, or a familiar
	# neighbour for a grown one. Never invent residents to populate a relation.
	var best: Dictionary = {}
	var best_score := -INF
	for other in visible_residents:
		if other.token==resident.token:
			continue
		var score := float(posmod(hash(str(resident.token)+":"+str(other.token)),1000))/1000.0
		if other.form==resident.form:
			score += 2.0
		if maturity(resident)<1.0 and maturity(other)>=1.0:
			score += 4.0
		if score>best_score:
			best_score = score
			best = other
	return best

func relationship(resident: Dictionary, companion: Dictionary) -> String:
	if companion.is_empty():
		return "The first resident has this quiet pond to itself."
	var name := resident_label(companion)
	return "Shelters near %s while growing." % name if maturity(resident)<1.0 and maturity(companion)>=1.0 else "Often drifts beside %s." % name

func maturity(resident: Dictionary) -> float:
	return clampf(float(cleared_encounters.size()-int(resident.get("arrived_after",0)))/4.0,0.0,1.0)

func habit(resident: Dictionary) -> String:
	if resident.form=="glasswing_spore":
		return "Unfurls its three glass wings into the current."
	if resident.form=="comet_spore":
		return "Trails a soft silver wake through the pond."
	if resident.rare:
		if resident.form=="glowdrift":
			return "Its spiral chambers shine and rest with the water."
		return "Fans the water through its fine glass ribs." if resident.form=="glass_harp" else "Opens its lace petals to the current."
	return ["Curious: gently explores near Mother.","Sociable: drifts near its own kind.","Dreamy: follows a quiet, slow current."][posmod(hash(resident.token),3)]

func new_residents() -> Array:
	# Legacy residents are already settled; only newly recorded rescues arrive.
	return residents.filter(func(resident): return not resident.get("welcomed", true))

func welcome(tokens: Array, persist: bool = true) -> void:
	for resident in residents:
		if tokens.has(resident.token): resident.welcomed = true
	if persist: save_profile()

func origin_text(resident: Dictionary) -> String:
	if resident.get("story", "") == "hatchling": return "Hatched in Glassgarden after you opened its cradle."
	if resident.get("story", "") == "cradle": return "Rescued inside the glass cradle in Glassgarden."
	var journey = preload("res://scripts/journey_plan.gd")
	return "Rescued in %s, encounter %d." % [journey.dish(resident.get("stage", 0)).name, resident.get("encounter", int(resident.get("stage", 0))+1)]
