extends RefCounted
## Plain-language instructions derived from the same live state as capture.
## Presentation only: no timings, costs, targets, or capture rules change here.
const Geometry = preload("res://scripts/loop_geometry.gd")

static func message(title: String, detail: String, target: int = -1, urgent: bool = false) -> Dictionary:
	return {"title": title, "detail": detail, "target": target, "urgent": urgent}

static func target_of_kind(run: RefCounted, kind: String) -> int:
	for body in run.enemies:
		if body.kind == kind:
			if kind == "food" and run.harvest.spec.mode == "sectors" and run.harvest.visited.size()<int(run.harvest.spec.target):
				var sector := posmod(roundi((body.nucleus-run.board.center).angle()/(TAU/8.0)),8)
				if run.harvest.visited.has(sector):
					continue
			return body.id
	return -1

static func contact_seconds(run: RefCounted, body: RefCounted) -> float:
	if body.is_boss() or body.kind not in ["drifter","shellback","twinspore","divider"] or body.speed <= 0.0:
		return INF
	if body.hunt_target>=0:
		return INF # It is pursuing other life; the feeding cue explains this risk.
	var distance := INF
	for point in body.nuclei():
		distance = minf(distance, point.distance_to(run.board.center) - run.board.mother_radius - 10.0)
	# An estimate: linked nuclei sway and slows can expire en route.
	var grace: float = body.spawning if body.kind == "divider" else 0.0
	return maxf(0.0, distance) / body.speed + body.stunned + body.slowed * 0.4 + grace + body.fed_remaining*0.65

static func next_action(run: RefCounted, clicks: bool = false) -> Dictionary:
	if run.selection.mother_blocked():
		return message("Keep the mother outside the loop", "Loops cannot surround her or cross her body. Backtrack to reshape it, or cancel for free.")
	if run.nudge.target_id>=0:
		if run.nudge.aim.length()>=run.nudge.MIN_DRAG and run.nudge.displacement(run).length()<run.nudge.MIN_DRAG:
			return message("Keep it inside the dish","The rim blocks this push. Aim toward clear water inside the lens, or right-click to cancel.")
		var nudged = run.nudge.target(run)
		if nudged!=null and nudged.kind=="phage":
			return message("Guide phages to a bacterium","Aim at a copper rod, then click or press Enter. They attach when close enough." if clicks else "Drag toward a copper rod and release. Phages attach when close enough; Nudge recharges in 6s.")
		return message("Make room for food","Choose clear water, then click or press Enter to nudge. Right-click cancels." if clicks else "Drag away from the food, then release. The arrow shows the push. Right-click cancels.")
	if not run.selection.rejection_reason.is_empty():
		var id: int = run.selection.rejected_id
		if id>=0 and run.cells[id].lost:
			return message("Cell was digested", "It regrows in the next encounter. Use the remaining blue cells.")
		if id>=0 and run.cells[id].captor>=0:
			return message("An amoeba swallowed this cell", "Loop around its gold nucleus using other blue cells before the 15s timer runs out.",run.cells[id].captor,true)
		if id >= 0 and not run.cells[id].is_ready():
			return message("Cell is digesting", "Ready in %.1fs. Use a different blue cell while it returns." % run.cells[id].remaining)
		if id >= 0 and run.harvest.ecology.blocked(run, id):
			return message("A parasite blocks this cell", "Capture the attached parasite using other blue cells to free it.")
		if not run.selection.rejection_reason.begins_with("This cell is busy"):
			return message("Connection blocked", run.selection.rejection_reason)
	if run.Lesson.active(run) and not run.selection.closed:
		return run.Lesson.instruction(run, clicks)
	var harvest = run.harvest
	var spec: Dictionary = harvest.spec
	var boss = run.boss()
	if run.selection.active:
		if not run.selection.can_close():
			return message("Connect the blue cells", "Choose any ready blue cells. Use at least 3, then return to START. Avoid crossing your loop.")
		var outcome: Dictionary = run.harvest_preview()
		if outcome.poison >= run.integrity:
			return message("This loop will kill you", "Too many purple cysts. Right-click to cancel. Nudge a cyst away, then draw a clean loop.", -1, true)
		if not run.selection.closed:
			return message("Return to START", "Move back to the first blue cell to close your loop. Then " + ("press Enter." if clicks else "release the mouse."))
		if outcome.boss_layers > 0:
			return message("%s to attack" % ("Enter" if clicks else "Release"), "The boss is inside. This uses 3 charge and removes one of its remaining layers.", boss.id)
		if outcome.get("wardens",0)>0:
			return message("%s to break shields" % ("Enter" if clicks else "Release"), "Break both together, or the second within 18 seconds. " + ("Then attack the Regent while OPEN." if boss!=null else "Then rescue the exposed pearl."))
		if outcome.purified > 0:
			return message("%s to clear poison" % ("Enter" if clicks else "Release"), "%d purple cysts will be safely removed. No health will be lost." % outcome.purified)
		if outcome.rescued > 0:
			return message("%s to rescue" % ("Enter" if clicks else "Release"), "%d pearl spores are inside your loop." % outcome.rescued)
		if outcome.get("cells_rescued",0)>0:
			return message("%s to save your cell" % ("Enter" if clicks else "Release"), "This captures the amoeba and releases the blue cell back to your colony.")
		if outcome.threats > 0:
			return message("%s to defend" % ("Enter" if clicks else "Release"), "This loop removes %d threats to your colony." % outcome.threats)
		for body in run.enemies:
			if body.kind == "shellback" and run.preview().has(body.id):
				return message("%s to crack its shell" % ("Enter" if clicks else "Release"), "Capture this armored hunter once more after your blue cells return.",body.id)
		if boss != null:
			var polygon := Geometry.polygon_for(run.selection.path,run.board.anchors)
			var inside := 0
			for point in boss.nuclei():
				if Geometry.contains(point,polygon): inside += 1
			if inside > 0 and harvest.nourishment < 3 and outcome.food == 0:
				return message("Need %d more food charge" % (3-harvest.nourishment), "The boss is inside, but this loop cannot hurt it yet. Cancel and collect green food first.",boss.id)
			if inside > 0 and harvest.nourishment >= 3 and not boss.can_take_pulse():
				return message("The boss is protected", protection_instruction(boss), boss.id)
			if inside == 1 and boss.nuclei().size() == 2:
				return message("Include BOTH gold centers", "The Conjoined has two hearts. Both must be inside the same closed loop.",boss.id)
			if outcome.food == 0 and harvest.nourishment >= 3:
				return message("The boss is outside", "Move your loop around the labeled boss's gold center. Right-click cancels this loop.",boss.id)
		for body in run.enemies:
			if body.kind=="bell_bud" and not body.can_take_pulse() and Geometry.contains(body.nucleus,Geometry.polygon_for(run.selection.path,run.board.anchors)) and outcome.food==0:
				return message("The bell bud is inhaling","Wait until it says OPEN, then enclose its gold center. Right-click cancels for free.",body.id)
			if body.cradle and not body.gate_ids.is_empty() and Geometry.contains(body.nucleus,Geometry.polygon_for(run.selection.path,run.board.anchors)):
				return message("The pearl is shielded","Capture its two small shield organisms first. The last shield exposes the pearl.",body.id)
		if outcome.food > 0:
			return message("%s to collect food" % ("Enter" if clicks else "Release"), "%d food will be collected.%s" % [outcome.food," You will also lose %d health." % outcome.poison if outcome.poison > 0 else " No health will be lost."],-1,outcome.poison>0)
		if run.preview_warning() == "Fit both glowing nuclei":
			return message("Include BOTH gold centers", "This linked hunter has two hearts. Both must fit inside the same closed loop.")
		return message("Nothing useful inside", "Right-click to cancel for free. Enclose an organism's center, then close your loop.")
	var danger = null
	var soonest := 20.0
	for body in run.enemies:
		var seconds := contact_seconds(run, body)
		if seconds < soonest:
			soonest = seconds
			danger = body
	var captive = null
	for body in run.enemies:
		if body.kind=="amoeba" and body.captive_node>=0 and (captive==null or body.rescue_remaining()<captive.rescue_remaining()): captive = body
	if captive!=null and (danger==null or captive.rescue_remaining()<soonest):
		return message("Save your blue cell · %ds" % ceili(captive.rescue_remaining()), "Loop around the amoeba's gold nucleus using other cells. If time runs out, the cell is lost until next encounter.",captive.id,true)
	if danger != null:
		return message("Protect the mother first", "About %ds until it eats a health core. Enclose %s, then close and %s." % [ceili(soonest), "BOTH gold centers" if danger.kind == "twinspore" else "its gold center", "press Enter" if clicks else "release"], danger.id, true)
	for hunter in run.enemies:
		if hunter.hunt_target>=0:
			var prey = run.harvest.ecology.prey_for(run,hunter)
			if prey != null and prey.kind=="spore":
				return message("A hunter wants the spore", "Rescue the pearl-white spore. Catch both together for an optional reward.",prey.id,true)
		if hunter.carried_food>0:
			return message("Recover the hunter's meal", "It swallowed %d food and is moving slowly while digesting. Capture it to recover the food." % hunter.carried_food,hunter.id)
	if boss != null:
		if harvest.nourishment < 3:
			return message("Collect %d more food" % (3-harvest.nourishment), "Loop around green organisms. Each boss attack uses 3 food charge.",target_of_kind(run,"food"))
		if not boss.can_take_pulse():
			if boss.reset_remaining>0.0:
				return message("Boss is reforming", "Recover and recharge. Its next pattern begins in %ds." % ceili(boss.reset_remaining),boss.id)
			if boss.variant==0:
				return message("Wait for the exhale","It draws food and poison inward. In %ds its gold center opens for 16 seconds. Prepare a clean loop." % ceili(boss.seconds_until_open()),boss.id)
			if boss.shield_remaining>0.0:
				return message("Break the last shield","Capture it within %ds or both shields regrow. Then the boss opens for 14 seconds." % ceili(boss.shield_remaining),boss.gate_ids[0],true)
			return message("Break 2 shields", "Capture both together, or the second within 18 seconds of the first. The boss opens for 14 seconds.",target_of_kind(run,"warden"))
		if boss.variant==2:
			return message("Enclose BOTH hearts","Capture both together. They spread farther after each hit. Wait for them to meet, or draw wider. Young pairs hatch nearby.",boss.id)
		return message("Attack the boss now", "%ds before it closes. Enclose %s, close at START, then %s." % [ceili(boss.open_remaining),"BOTH gold centers" if boss.nuclei().size()==2 else "its gold center","press Enter" if clicks else "release"],boss.id,true)
	for body in run.enemies:
		if body.cradle and not body.gate_ids.is_empty():
			return message("Open the glass cradle","Capture its two linked shields together, or finish the second within 18 seconds. Then rescue the pearl.",body.gate_ids[0])
		if body.cradle and body.hatch_remaining()>=0.0:
			return message("Rescue now, or let it hatch","Loop around its pearl now for one rescue. Protect it for %ds to hatch two young. Hunters can eat it." % ceili(body.hatch_remaining()),body.id)
	for body in run.enemies:
		if body.kind == "parasite" and body.latched:
			return message("Free the blocked cell", "Capture the coral parasite at the other end of its pink tether. Use the cells around its body.",body.id)
	if spec.mode=="rescue" and harvest.rescued<int(spec.target):
		for body in run.enemies:
			if body.kind=="spore" and not body.visitor and body.lifetime()-body.age<18.0:
				return message("Rescue the fading spore", "It escapes in %ds. Enclose the pearl-white center before collecting more food." % ceili(body.lifetime()-body.age),body.id,true)
	for body in run.enemies:
		if body.kind == "divider" and not body.daughter and body.split_remaining()<7.0:
			return message("Divider is about to split", "Two hunters in %ds. Capture the ribbed blue body now, or catch both young hunters together." % ceili(body.split_remaining()),body.id,true)
	var helpers = run.phages.free_cluster()
	if helpers!=null and not run.phages.learned:
		var host = run.phages.nearest_host(run,helpers.nucleus,180.0)
		if host!=null:
			return message("Put the tiny phages to work","Drag the silver cluster toward the copper rod. It ruptures after 9s. You can also loop around the bacterium yourself.",host.id)
	for body in run.enemies:
		if body.kind=="bacterium" and body.infection_age>=0.0:
			return message("Phages are treating the thief · %ds" % ceili(body.infection_remaining()),"Keep collecting food. When the bacterium ruptures, loop around the food it releases.",body.id)
	for body in run.enemies:
		if body.kind in ["grazer","bacterium"] and body.stored_food > 0 and harvest.nourishment < int(spec.food):
			return message("Recover the stolen food", "This grazer carries %d food. Enclose its gold center to get that food back before it swims away." % body.stored_food,body.id)
	var food_left := maxi(0,int(spec.food)-harvest.nourishment)
	if food_left > 0:
		var event: Dictionary = harvest.HabitatEvents.sample(run)
		if not event.is_empty() and event.age>=0.0 and event.age<22.0:
			var food: Array = run.enemies.filter(func(body): return harvest.event_state.food.has(body.id))
			if not food.is_empty():
				var detail := "Cysts hatch in %ds. Loop around green food now; leave the purple cysts outside." % ceili(22.0-event.age) if event.kind=="hatching" else "Loop around this passing green bloom. A food thief follows it."
				return message("Harvest before the garden wakes" if event.kind=="hatching" else "Catch the drifting bloom",detail,food[0].id)
		return message("Collect %d more food" % food_left, "Loop around green organisms. Leave purple spikes outside to avoid losing health.",target_of_kind(run,"food"))
	if harvest.hunter_quota()>harvest.hunters_captured:
		var next_hunter := -1
		for body in run.enemies:
			if body.kind in ["drifter","shellback","twinspore","divider"]:
				next_hunter = body.id
				break
		return message("Capture %d more hunters" % (harvest.hunter_quota()-harvest.hunters_captured), "Catch the approaching hunters before this feeding visit can end." if next_hunter>=0 else "Watch the arrival marks. The next hunter is coming with the bloom.",next_hunter)
	if harvest.final_surge_started:
		var final_target: int = harvest.final_surge_ids[0] if not harvest.final_surge_ids.is_empty() else -1
		var armored: bool = run.enemies.any(func(body): return body.id==final_target and body.kind=="shellback")
		var linked: bool = run.enemies.any(func(body): return body.id==final_target and body.kind=="twinspore")
		return message("Repel the final hunter%s" % ("s" if harvest.final_surge_needed-harvest.final_surge_captured>1 else ""), "Crack its armor, then capture it again." if armored else "Fit both linked nuclei inside one loop." if linked else "Capture the approaching hunter before it reaches Mother." if final_target>=0 else "Watch the marked water. The final hunter is approaching.",final_target,true)
	match spec.mode:
		"rescue":
			return message("Rescue %d more spores" % maxi(0,int(spec.target)-harvest.rescued), "Enclose the pearl-white organisms. Their bright centers mark what to rescue.",target_of_kind(run,"spore"))
		"purify":
			return message("Clear %d more cysts" % maxi(0,int(spec.target)-harvest.purified), "Enclose purple spikes ALONE. Leave every green organism outside. This costs no health.",target_of_kind(run,"cyst"))
		"sectors":
			return message("Feed in %d new areas" % maxi(0,int(spec.target)-harvest.visited.size()), "Collect green food in a dim sector. Each newly lit arc marks another area completed.",target_of_kind(run,"food"))
		"defend":
			var target := -1
			for body in run.enemies:
				if body.kind in ["drifter","shellback","twinspore","divider","grazer","bacterium","parasite","bell_bud"]:
					target = body.id
					break
			return message("Capture %d more threats" % maxi(0,int(spec.target)-harvest.defended), "Capture hunters, food thieves, or parasites. Each protects the colony." if target >= 0 else "The next threat arrives with the bloom. Prepare a clear route.",target)
	return message("Meal complete", "Your cells are returning. Evolution comes next.")

static func goals(run: RefCounted) -> Array:
	var harvest = run.harvest
	var spec: Dictionary = harvest.spec
	if spec.mode == "boss":
		return ["Collect 3 food to charge each attack.", ["Wait through its inhale; attack during the 16-second exhale.","Break both shields together, or the second within 18 seconds.","Enclose BOTH hearts. They spread farther after each hit."][run.stage_index/4], "Hit 3 times. " + ("Young pairs hatch nearby. Catch them before they reach Mother." if run.stage_index==11 else "Recharge with green food between attacks.")]
	var result: Array = ["Collect %d green food." % spec.food]
	match spec.mode:
		"feed":
			if harvest.hunter_quota()>0: result.append("Capture %d approaching hunters before leaving." % harvest.hunter_quota())
		"rescue": result.append("Rescue %d pearl-white spores." % spec.target)
		"purify": result.append("Clear %d purple cysts in cyst-only loops." % spec.target)
		"defend": result.append("Capture %d threats: hunters, grazers, or parasites." % spec.target)
		"sectors": result.append("Collect food in %d different marked areas." % spec.target)
	if harvest.final_surge_enabled:
		result.append("Then repel a final hunter wave. Finishing the first goals within 140 seconds draws a larger wave.")
	result.append("Keep the mother alive. Purple cysts in a meal cost health.")
	return result

static func protection_instruction(boss: RefCounted) -> String:
	if boss.reset_remaining>0.0:
		return "It is reforming for %ds. Recharge and prepare the next loop." % ceili(boss.reset_remaining)
	if boss.variant==0:
		return "It is inhaling. Wait %ds for its gold center to open, then release a clean loop." % ceili(boss.seconds_until_open())
	return "Capture both linked shields together, or the second within 18 seconds. Removing the last shield creates the opening."

static func objective_text(run: RefCounted) -> String:
	var h = run.harvest
	if h.final_surge_started:
		return "%d / %d final hunters captured" % [h.final_surge_captured,h.final_surge_needed]
	if h.hunter_quota()>0:
		return "%d / %d hunters captured" % [h.hunters_captured,h.hunter_quota()]
	match h.spec.mode:
		"rescue": return "%d / %d spores rescued" % [h.rescued,h.spec.target]
		"purify": return "%d / %d cysts cleared" % [h.purified,h.spec.target]
		"defend": return "%d / %d threats captured" % [h.defended,h.spec.target]
		"sectors": return "%d / %d areas fed in" % [h.visited.size(),h.spec.target]
	return ""
