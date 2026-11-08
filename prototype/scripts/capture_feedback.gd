extends RefCounted
## Presentation state observes the same live outcome that release commits.
## It never freezes organisms or changes capture eligibility.
var previous_poison := -1
var warning_remaining := 0.0
var warning_serial := 0
var outcome: Dictionary = {}

func clear() -> void:
	previous_poison = -1
	warning_remaining = 0.0
	outcome = {}

func observe(run: RefCounted, delta: float) -> void:
	if run.state == run.PAUSED:
		return
	warning_remaining = maxf(0.0, warning_remaining - delta)
	if run.harvest == null or run.state != run.ACTIVE or not run.selection.can_close():
		previous_poison = -1
		outcome = {}
		return
	outcome = run.harvest_preview()
	var poison := int(outcome.get("poison", 0))
	if previous_poison >= 0 and poison > previous_poison:
		warning_remaining = 1.8
		warning_serial += 1
	previous_poison = poison

static func summary(meal: Dictionary) -> String:
	var parts: Array[String] = []
	if meal.get("food", 0) > 0: parts.append("+%d food" % meal.food)
	if meal.get("boss_layers", 0) > 0: parts.append("Boss hit · −3 charge")
	if meal.get("wardens", 0) > 0: parts.append("%d shields broken" % meal.wardens)
	if meal.get("rescued", 0) > 0: parts.append("%d rescued" % meal.rescued)
	if meal.get("cells_rescued", 0) > 0: parts.append("Blue cell freed")
	if meal.get("purified", 0) > 0: parts.append("%d cysts neutralized" % meal.purified)
	if meal.get("threats", 0) > 0: parts.append("%d threats removed" % meal.threats)
	if meal.get("armor_hits", 0) > 0: parts.append("Armor cracked")
	if parts.is_empty(): parts.append("Nothing captured")
	return " · ".join(parts)

static func health_text(meal: Dictionary, health: int) -> String:
	var damage := int(meal.get("poison", 0))
	return "−%d health · %d remaining" % [damage, maxi(0, health - damage)] if damage > 0 else "No health lost"
