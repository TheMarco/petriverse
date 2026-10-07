extends RefCounted

var path := "user://colony.cfg"
var best_score := 0
var best_capture := 0
var victories := 0
var runs := 0
var new_record := false

func load_records() -> void:
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return
	best_score = int(config.get_value("records", "best_score", 0))
	best_capture = int(config.get_value("records", "best_capture", 0))
	victories = int(config.get_value("records", "victories", 0))
	runs = int(config.get_value("records", "runs", 0))

func record(run: RefCounted) -> void:
	new_record = run.score > best_score
	best_score = maxi(best_score, run.score)
	best_capture = maxi(best_capture, run.best_capture)
	runs += 1
	if run.state == "success":
		victories += 1
	var config := ConfigFile.new()
	config.set_value("records", "best_score", best_score)
	config.set_value("records", "best_capture", best_capture)
	config.set_value("records", "victories", victories)
	config.set_value("records", "runs", runs)
	config.save(path)
