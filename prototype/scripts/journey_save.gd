extends RefCounted
## Versioned local snapshots. Simulation state is explicit; no objects or scripts
## are deserialized from disk. Transient selection is deliberately cancelled.
const VERSION := 2
const Route = preload("res://scripts/journey_route.gd")
const NUDGE_FIELDS := ["cooldown","learned","ripple_origin","ripple_vector"]
const ORGANISM_FIELDS := ["origin","drift","phase","nudge_vector","nudge_elapsed"]
const ECOLOGY_FIELDS := ["pace","next_wave","rhythm_origin","wave","pending","eaten_food","escaped_spores","notice","notice_time","gates_spawned"]
const BOSS_FIELDS := ["variant", "hit_cycle", "attack_count", "gate_ids", "open_remaining", "reset_remaining", "round_index", "pattern_time", "juvenile"]
const HABITAT_FIELDS := ["habitat_choice", "habitat_confirmed", "habitat_applied", "habitat_history"]
const AMOEBA_FIELDS := ["phase","target_node","captive_node","site_nodes","destination","reach_point","ingest_axis","reach_age","digestion_age","rest_age","arm_extension","victim_home","search_after"]
const LIVING_FIELDS := ["destination","target_id","target_node","site_nodes","latched","action_clock","stored_food","daughter","sector","spawning"]
const RUN_FIELDS := ["rescued_specimens", "mastery_awards", "lesson_step", "lesson_nodes", "stage_index", "state", "score", "integrity", "kills", "elapsed", "stage_elapsed", "biomass", "total_food", "total_rescued", "completed_dishes", "colony_id", "retries", "run_seed", "next_enemy_id", "boss_defeated", "mutations", "offered_mutations", "seen_species", "discovery_serial", "last_discovery", "best_capture", "loops_drawn", "capture_serial", "last_capture", "contact_time", "last_contacts", "residuals"]
const ENEMY_FIELDS := ["cradle_open_age", "story", "gate_ids", "shield_remaining", "cradle", "visitor", "bloom_releases", "hunt_target", "hunt_time", "forage_remaining", "foraging_done", "fed_remaining", "carried_food", "bloom_id", "id", "nucleus", "speed", "heading", "health", "age", "kind", "form", "stunned", "slowed", "hit_flash", "shield_flash", "pair_angle", "pair_span", "lure_vector", "lure_elapsed"]
const HARVEST_FIELDS := ["visitor_at", "visitor_spawned", "nourishment", "poison_taken", "next_bloom", "next_threat", "blooms", "rotation", "loss_reason", "loss_title", "rescued", "purified", "defended", "visited", "clean_food", "threats_spawned", "spores_spawned", "next_spore", "tide", "boss_hits", "last_time"]

static func fields(object: RefCounted, names: Array) -> Dictionary:
	var result := {}
	for key in names:
		result[key] = object.get(key)
	return result.duplicate(true)

static func apply(object: RefCounted, data: Dictionary, names: Array) -> void:
	for key in names:
		if data.has(key):
			object.set(key, data[key])

static func capture(run: RefCounted) -> Dictionary:
	var data := {"version": VERSION, "run": fields(run, RUN_FIELDS), "rng": run.rng.state,
		"harvest": fields(run.harvest, HARVEST_FIELDS), "enemies": [], "cells": [], "clots": [],
		"anchors": run.board.anchors, "motion_times": run.board.motion_times,
		"wander": {"homes":run.board.motion_homes,"velocities":run.board.velocities,"accumulator":run.board.motion_accumulator},
		"mother": fields(run.mother_damage, ["lost", "bites", "serial"]), "ecology": fields(run.harvest.ecology,ECOLOGY_FIELDS)}
	data.run.merge(fields(run,HABITAT_FIELDS))
	data["nudge"] = fields(run.nudge,NUDGE_FIELDS)
	data["water"] = run.fluid.snapshot()
	data["water_previous"] = run.water_positions.duplicate(true)
	data["phages"] = run.phages.snapshot()
	data["cell_returns"] = run.amoebas.releases.duplicate(true)
	data["route"] = {"plan":run.route_plan.duplicate(true),"position":run.route_position}
	data["expedition_roster"] = run.expedition_roster.duplicate(true)
	data.harvest["event_state"] = run.harvest.event_state.duplicate(true)
	for body in run.enemies:
		var value := fields(body, ENEMY_FIELDS)
		if body.is_boss() or body.kind=="bell_bud":
			value["boss"] = fields(body, BOSS_FIELDS)
		elif body.kind=="amoeba":
			value["amoeba"] = fields(body,AMOEBA_FIELDS)
		elif body.kind=="bacterium":
			value["bacterium"] = fields(body,LIVING_FIELDS+["infection_age"])
		elif body.kind in ["grazer","parasite","divider","warden"]:
			value["living"] = fields(body,LIVING_FIELDS)
		elif body.kind in ["food", "cyst", "spore"]:
			value["organism"] = fields(body, ORGANISM_FIELDS)
		data.enemies.append(value)
	for cell in run.cells:
		data.cells.append(fields(cell, ["remaining", "duration", "captor", "lost"]))
	for clot in run.clots:
		data.clots.append(fields(clot, ["serial", "nodes", "polygon", "positions", "prey_kinds", "prey_forms", "restored_node", "food", "poison", "duration", "mastery"]))
	return data.duplicate(true)

static func valid(data: Dictionary) -> bool:
	if data.get("version", 0) not in [1,VERSION] or not data.get("run") is Dictionary:
		return false
	var status: Dictionary = data.run
	if int(status.get("stage_index", -1)) not in range(12) or status.get("state", "") not in ["brief", "active", "paused", "evolve", "success", "loss"]:
		return false
	if not data.get("cells") is Array or data.cells.size() != 24:
		return false
	var route: Dictionary = data.get("route",{})
	if not route.get("plan",[]) is Array:
		return false
	if not route.get("plan",[]).is_empty():
		var position := int(route.get("position",-1))
		if not Route.valid(route.plan) or position not in range(route.plan.size()) or int(route.plan[position].stage)!=int(status.stage_index):
			return false
		if not preload("res://scripts/expedition_creatures.gd").valid(data.get("expedition_roster",[]),route.plan):
			return false
	return data.get("harvest") is Dictionary and data.get("enemies") is Array and data.get("anchors", []).size() == 24

static func restore(run: RefCounted, data: Dictionary) -> bool:
	if not valid(data):
		return false
	run.stage_index = int(data.run.stage_index)
	run.route_plan = data.get("route",{}).get("plan",[]).duplicate(true)
	run.route_position = int(data.get("route",{}).get("position",0))
	run.long_journey = not run.route_plan.is_empty()
	# Old saves retain their existing ecology; new discoveries start next journey.
	run.expedition_roster = data.get("expedition_roster",[]).duplicate(true) if run.long_journey else []
	run.start_journey_stage()
	run.nudge = run.CystNudge.new()
	apply(run.nudge,data.get("nudge",{}),NUDGE_FIELDS)
	run.mastery_awards.clear()
	run.rescued_specimens.clear()
	apply(run, data.run, RUN_FIELDS)
	run.habitat_history = {}
	apply(run,data.run,HABITAT_FIELDS)
	if not data.run.has("habitat_choice"):
		# Old encounters continue exactly as saved, without a surprise detour.
		run.habitat_confirmed = true
		run.habitat_applied = true
	# Existing first-upgrade saves receive the same readable pair as new runs.
	if run.stage_index == 0 and run.mutations.is_empty() and run.state == "evolve":
		run.offered_mutations = ["fission", "elastic"]
	run.rng.seed = run.run_seed
	run.rng.state = data.rng
	run.fluid.reset(run.board.center,run.board.dish_radius,run.appearance_seed() ^ (run.stage_index*48271))
	run.fluid.restore(data.get("water",{}))
	# The next water step uses the last body positions to apply its wake.
	# Losing this one-frame history makes a saved nudge drift off its course.
	run.water_positions = data.get("water_previous",{}).duplicate(true)
	run.board.anchors = data.anchors
	run.board.motion_times = data.motion_times
	if data.has("wander"):
		run.board.motion_homes = data.wander.homes
		run.board.velocities = data.wander.velocities
		run.board.motion_accumulator = data.wander.accumulator
	else:
		# Old pocket-drift/orbit saves start wandering from their saved positions,
		# including held clots. Never rotate or snap them back to the initial board.
		run.board.motion_homes = run.board.anchors.duplicate()
		run.board.velocities.fill(Vector2.ZERO)
		run.board.motion_accumulator = 0.0
	run.selection.cancel()
	run.selection.max_vertices = run.Mutations.maximum(run.mutations)
	apply(run.harvest, data.harvest, HARVEST_FIELDS)
	# Existing saves continue their established encounter without inserting an
	# ecological event that might already be due at the restored simulation time.
	run.harvest.event_state = data.harvest.get("event_state",{}).duplicate(true)
	if data.has("ecology"):
		apply(run.harvest.ecology,data.ecology,ECOLOGY_FIELDS)
	else:
		run.harvest.ecology.next_wave = run.stage_elapsed+12.0
	if not data.get("ecology",{}).has("pace"):
		# Finish an in-progress encounter at its saved pressure; the new curve
		# begins with the next encounter. Never insert a surprise second front.
		run.harvest.ecology.pace = run.harvest.ecology.Rhythm.legacy_pacing()
	if not data.get("ecology",{}).has("rhythm_origin"):
		# Keep a legacy save's scheduled arrivals and align the phase display.
		var ecology = run.harvest.ecology
		ecology.rhythm_origin = ecology.next_wave-ecology.pace.warning-ecology.wave*ecology.pace.cycle
	apply(run.mother_damage, data.mother, ["lost", "bites", "serial"])
	for i in 24:
		apply(run.cells[i], data.cells[i], ["remaining", "duration", "captor", "lost"])
	run.phages.restore(data.get("phages",{}))
	run.amoebas.releases = data.get("cell_returns",[]).duplicate(true)
	run.enemies.clear()
	for value in data.enemies:
		var body: RefCounted
		if value.has("boss"):
			body = run.JourneyHarvest.Predator.new(value.id, run.board, int(value.boss.variant))
			apply(body, value.boss, BOSS_FIELDS)
		elif value.has("amoeba"):
			body = run.Amoebas.Body.new(value.id,value.nucleus)
			apply(body,value.amoeba,AMOEBA_FIELDS)
		elif value.has("bacterium"):
			body = run.Phages.Bacterium.new(value.id,value.nucleus,int(value.bacterium.sector))
			apply(body,value.bacterium,LIVING_FIELDS+["infection_age"])
		elif value.has("living"):
			body = run.JourneyHarvest.Ecology.Body.new(value.id,value.kind,value.nucleus,int(value.living.sector))
			apply(body,value.living,LIVING_FIELDS)
		elif value.has("organism"):
			body = run.Harvest.Organism.new(value.id, value.kind, value.nucleus, Vector2.ZERO, 0.0)
			apply(body, value.organism, ORGANISM_FIELDS)
		else:
			body = run.Drifter.new(value.id, value.nucleus, value.speed, value.kind)
		apply(body, value, ENEMY_FIELDS)
		if value.has("boss") and not value.boss.has("pattern_time"):
			if body.variant!=1:
				body.gate_ids.clear()
				body.pattern_time = 24.0-body.open_remaining if body.variant==0 and body.open_remaining>0.0 else 6.0 if body.variant==2 else 0.0
			elif body.gate_ids.size()==1:
				body.shield_remaining = 18.0
		run.enemies.append(body)
	var live_links: Array = []
	for holder in run.enemies:
		live_links.append_array(holder.gate_ids)
	run.enemies = run.enemies.filter(func(e): return e.kind!="warden" or live_links.has(e.id))
	# Older saves retain health, food and boss hits. Give the player a fresh
	# shield puzzle instead of inheriting a removed clock-based vulnerability.
	if data.get("version",1)==1 and run.boss()!=null:
		run.boss().round_index = run.harvest.boss_hits
		run.harvest.ecology.spawn_gates(run)
	run.clots.clear()
	for value in data.clots:
		var copy: Dictionary = value.duplicate(true)
		copy.restored_node = -1 # Saved geometry already omits the restored cell.
		var clot = run.Clot.new(value.serial, copy, run.cells, run.board.center)
		clot.restored_node = value.restored_node
		run.clots.append(clot)
	run.journey_serial += 1
	return true

static func write(run: RefCounted, path: String = "user://journey.cfg") -> Error:
	if not run.journey or run.state == "home":
		return ERR_INVALID_DATA
	var config := ConfigFile.new()
	config.set_value("journey", "snapshot", capture(run))
	config.set_value("journey", "checkpoint", run.checkpoint)
	var temporary := path + ".tmp"
	var error := config.save(temporary)
	if error != OK:
		return error
	return DirAccess.rename_absolute(temporary, path)

static func read(path: String = "user://journey.cfg") -> Dictionary:
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return {}
	var data: Variant = config.get_value("journey", "snapshot", {})
	if not data is Dictionary or not valid(data):
		return {}
	return {"snapshot": data, "checkpoint": config.get_value("journey", "checkpoint", {})}
