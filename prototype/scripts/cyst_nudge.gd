extends RefCounted
## One deliberate water push. Gestures are transient; cooldown and ripples save.
const Arrival = preload("res://scripts/organism_arrival.gd")
const RANGE := 60.0
const COOLDOWN := 6.0
const MIN_DRAG := 8.0
const HIT_RADIUS := 23.0
var cooldown := 0.0
var learned := false
var ripple_origin := Vector2.ZERO
var ripple_vector := Vector2.ZERO
var target_id := -1
var pointer_origin := Vector2.ZERO
var aim := Vector2.ZERO

func cancel() -> void:
	target_id = -1
	aim = Vector2.ZERO

func reset_encounter() -> void:
	cancel()
	cooldown = 0.0
	ripple_vector = Vector2.ZERO

func step(delta: float, run: RefCounted) -> void:
	cooldown = maxf(0.0,cooldown-delta)
	if target_id>=0 and target(run)==null:
		cancel()

func eligible(body: RefCounted) -> bool:
	return (body.kind=="cyst" or (body.kind=="phage" and body.host_id<0)) and body.has_method("start_nudge") and Arrival.progress(body)>0.8 and body.opacity()>0.3

func target(run: RefCounted) -> RefCounted:
	for body in run.enemies+run.phages.clusters:
		if body.id==target_id and eligible(body):
			return body
	return null

func pick(run: RefCounted, at: Vector2) -> RefCounted:
	if not run.journey or run.state!="active" or run.selection.active or cell_has_priority(run,at):
		return null # Drawing a ready blue cell keeps its familiar priority.
	var best: RefCounted
	var distance := INF
	for body in run.enemies+run.phages.clusters:
		if eligible(body) and body.nucleus.distance_to(at)<minf(distance,32.0 if body.kind=="phage" else HIT_RADIUS):
			best = body
			distance = body.nucleus.distance_to(at)
	return best

func cell_has_priority(run: RefCounted, at: Vector2) -> bool:
	var cell: int = run.board.hit_test(at)
	return cell>=0 and run.is_ready(cell)

func begin(run: RefCounted, at: Vector2) -> bool:
	var body := pick(run,at)
	if body==null or cooldown>0.0:
		return false
	run.selection.cancel()
	target_id = body.id
	pointer_origin = at
	aim = Vector2.ZERO
	return true

func point(at: Vector2) -> void:
	aim = (at-pointer_origin).limit_length(RANGE)

func displacement(run: RefCounted) -> Vector2:
	var body := target(run)
	if body==null:
		return Vector2.ZERO
	# Keep the whole future drift envelope inside the lens, including its husk.
	var radius: float = run.board.dish_radius-24.0-body.drift.length()*2.0
	var start: Vector2 = body.nucleus
	var finish: Vector2 = run.board.center+(start+aim-run.board.center).limit_length(radius)
	var move := (finish-start).limit_length(RANGE)
	return move if move.dot(aim)>0.0 else Vector2.ZERO

func release(run: RefCounted, at: Vector2) -> Dictionary:
	point(at)
	var body := target(run)
	var move := displacement(run)
	if run.state!="active" or body==null or cooldown>0.0 or aim.length()<MIN_DRAG or move.length()<MIN_DRAG:
		cancel()
		return {}
	ripple_origin = body.nucleus
	ripple_vector = move
	body.start_nudge(move)
	cooldown = COOLDOWN
	learned = true
	cancel()
	return {"from":ripple_origin,"to":ripple_origin+move,"kind":body.kind}

func teaching_target(run: RefCounted) -> RefCounted:
	if learned or cooldown>0.0 or run.selection.active or run.boss()!=null or run.Lesson.active(run):
		return null
	for cyst in run.enemies:
		if cyst.kind!="cyst" or not eligible(cyst) or cell_has_priority(run,cyst.nucleus):
			continue
		for food in run.enemies:
			if food.kind=="food" and cyst.nucleus.distance_to(food.nucleus)<65.0:
				return cyst
	return null
