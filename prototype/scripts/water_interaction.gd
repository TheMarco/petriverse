extends RefCounted
## Presentation-only wakes. All ages follow the same pausable visual clock.
const LIMIT := 6
const LIFETIME := 3.2
var wakes: Array = []

func stroke(from: Vector2, to: Vector2, time: float) -> void:
	if from.distance_to(to) < 5.0:
		return
	wakes.append({"from":from,"to":to,"time":time})
	while wakes.size() > LIMIT:
		wakes.pop_front()

func sample(time: float, reduced: bool) -> Dictionary:
	if reduced:
		wakes.clear()
	wakes = wakes.filter(func(w): return time-w.time < LIFETIME and time >= w.time)
	var strokes := PackedVector4Array()
	var strengths := PackedFloat32Array()
	for wake in wakes:
		var age: float = (time-wake.time)/LIFETIME
		strokes.append(Vector4(wake.from.x,wake.from.y,wake.to.x,wake.to.y))
		strengths.append(pow(1.0-age,1.5)*1.45)
	strokes.resize(LIMIT)
	strengths.resize(LIMIT)
	return {"strokes":strokes,"strengths":strengths}

static func displacement(at: Vector2, currents: PackedVector4Array, strokes: PackedVector4Array, strengths: PackedFloat32Array) -> Vector2:
	# Keep this small bounded field equivalent to water_interaction.gdshaderinc.
	var offset := Vector2.ZERO
	for current in currents:
		var delta := at-Vector2(current.x,current.y)
		var distance := delta.length()
		var radial := delta/maxf(distance,1.0)
		var envelope := exp(-distance*distance/14400.0)*minf(distance/24.0,1.0)
		offset += (radial*current.z+radial.orthogonal()*current.w)*envelope
	for i in strokes.size():
		if strengths[i] <= 0.0:
			continue
		var a := Vector2(strokes[i].x,strokes[i].y)
		var b := Vector2(strokes[i].z,strokes[i].w)
		var segment := b-a
		var fraction := clampf((at-a).dot(segment)/maxf(segment.length_squared(),1.0),0.0,1.0)
		var delta := at-a-segment*fraction
		var envelope := exp(-delta.length_squared()/900.0)*strengths[i]
		offset += (delta/maxf(delta.length(),4.0)*7.0+segment.normalized()*2.0)*envelope
	return offset.limit_length(28.0)
