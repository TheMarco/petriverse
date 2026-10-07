extends RefCounted
## A small, persistent water simulation shared by gameplay and microscope optics.
## Semi-Lagrangian advection, viscosity, pressure relaxation and solid boundaries.
## Positions/velocities are in dish pixels and seconds; no gameplay RNG is used.
const SIZE := 28
const COUNT := SIZE * SIZE
const STEP := 1.0 / 20.0
const MAX_SPEED := 18.0
const OFFSET_RANGE := 96.0
var center := Vector2(640,450)
var radius := 392.0
var origin := Vector2.ZERO
var spacing := 1.0
var phase := 0.0
var clock := 0.0
var accumulator := 0.0
var revision := 0
var velocity := PackedVector2Array()
var transport := PackedVector2Array()
var wet := PackedByteArray()
var points := PackedVector2Array()
var pressure := PackedFloat32Array()
var divergence := PackedFloat32Array()
var sources := PackedVector4Array()
var texture: ImageTexture
var texture_revision := -1

func reset(at: Vector2, extent: float, seed_value: int) -> void:
	center = at
	radius = extent
	origin = center-Vector2.ONE*radius
	spacing = radius*2.0/float(SIZE-1)
	phase = float(posmod(seed_value,10007))*0.017
	clock = 0.0
	accumulator = 0.0
	velocity.resize(COUNT)
	transport.resize(COUNT)
	wet.resize(COUNT)
	points.resize(COUNT)
	pressure.resize(COUNT)
	divergence.resize(COUNT)
	velocity.fill(Vector2.ZERO)
	transport.fill(Vector2.ZERO)
	sources.clear()
	for y in SIZE:
		for x in SIZE:
			var i := x+y*SIZE
			points[i] = origin+Vector2(x,y)*spacing
			var distance := points[i].distance_to(center)
			wet[i] = int(x>0 and y>0 and x<SIZE-1 and y<SIZE-1 and distance<radius-8.0 and distance>55.0)
			if wet[i]:
				velocity[i] = ambient(points[i])
	project()
	revision += 1

func ambient(at: Vector2) -> Vector2:
	# Curl of a changing stream function: several local eddies, no common orbit.
	var q := (at-center)/155.0
	var a := q.x*1.13+q.y*0.71+phase+clock*0.039
	var b := q.x*-0.64+q.y*1.31-phase*0.7-clock*0.031
	return Vector2(0.71,-1.13)*cos(a)*4.8+Vector2(1.31,0.64)*cos(b)*3.5

func interpolate(values: PackedVector2Array, at: Vector2) -> Vector2:
	var grid := ((at-origin)/spacing).clamp(Vector2.ZERO,Vector2.ONE*(SIZE-1.001))
	var x := int(grid.x)
	var y := int(grid.y)
	var i := x+y*SIZE
	return values[i].lerp(values[i+1],grid.x-x).lerp(values[i+SIZE].lerp(values[i+SIZE+1],grid.x-x),grid.y-y)

func sample(at: Vector2) -> Vector2:
	if velocity.is_empty() or at.distance_to(center)>=radius:
		return Vector2.ZERO
	return interpolate(velocity,at)

func displacement(at: Vector2) -> Vector2:
	return interpolate(transport,at) if not transport.is_empty() else Vector2.ZERO

func stroke(from: Vector2, to: Vector2, strength: float = 0.35) -> void:
	if velocity.is_empty() or not from.is_finite() or not to.is_finite():
		return
	var segment := to-from
	if segment.length_squared()<0.00001:
		return
	# Splat only nearby grid cells. A stroke imparts momentum once; it does not
	# tether water to the pointer, and its wake survives after input stops.
	var low := ((from.min(to)-Vector2.ONE*65.0-origin)/spacing).floor().clamp(Vector2.ONE,Vector2.ONE*(SIZE-2))
	var high := ((from.max(to)+Vector2.ONE*65.0-origin)/spacing).ceil().clamp(Vector2.ONE,Vector2.ONE*(SIZE-2))
	var impulse := segment.limit_length(70.0)*strength
	for y in range(int(low.y),int(high.y)+1):
		for x in range(int(low.x),int(high.x)+1):
			var i := x+y*SIZE
			if not wet[i]: continue
			var fraction := clampf((points[i]-from).dot(segment)/segment.length_squared(),0.0,1.0)
			var distance := points[i].distance_squared_to(from+segment*fraction)
			velocity[i] = (velocity[i]+impulse*exp(-distance/1500.0)).limit_length(MAX_SPEED)
	revision += 1

func step(delta: float) -> void:
	if delta<=0.0 or velocity.is_empty(): return
	accumulator += delta
	while accumulator>=STEP-0.000000001:
		accumulator = maxf(0.0,accumulator-STEP)
		advance()

func advance() -> void:
	clock += STEP
	var next := velocity.duplicate()
	for i in COUNT:
		if not wet[i]: continue
		var at := points[i]
		var carried := interpolate(velocity,at-velocity[i]*STEP)
		var viscous := (velocity[i-1]+velocity[i+1]+velocity[i-SIZE]+velocity[i+SIZE])*0.25
		var v := carried.lerp(viscous,0.035).lerp(ambient(at),STEP*0.28)
		for source in sources:
			var offset := at-Vector2(source.x,source.y)
			var envelope := exp(-offset.length_squared()/6200.0)*smoothstep(12.0,40.0,offset.length())
			var radial := offset.normalized()
			v += (radial*source.z+radial.orthogonal()*source.w)*envelope*STEP
		next[i] = v
	velocity = next
	project()
	var carried_offsets := transport.duplicate()
	for i in COUNT:
		if not wet[i]: continue
		# Transport a material coordinate through the same field. Slow relaxation
		# bounds optical stretching while preserving several seconds of wake.
		carried_offsets[i] = ((interpolate(transport,points[i]-velocity[i]*STEP)+velocity[i]*STEP)*exp(-STEP*0.045)).limit_length(OFFSET_RANGE-1.0)
	transport = carried_offsets
	revision += 1

func project() -> void:
	pressure.fill(0.0)
	for i in COUNT:
		if wet[i]:
			divergence[i] = -0.5*spacing*(velocity[i+1].x-velocity[i-1].x+velocity[i+SIZE].y-velocity[i-SIZE].y)
	for _pass in 9:
		for i in COUNT:
			if not wet[i]: continue
			var sum := 0.0
			var count := 0
			for neighbor in [i-1,i+1,i-SIZE,i+SIZE]:
				if wet[neighbor]:
					sum += pressure[neighbor]
					count += 1
			pressure[i] = (divergence[i]+sum)/maxi(1,count)
	for i in COUNT:
		if not wet[i]: continue
		var left := pressure[i-1] if wet[i-1] else pressure[i]
		var right := pressure[i+1] if wet[i+1] else pressure[i]
		var up := pressure[i-SIZE] if wet[i-SIZE] else pressure[i]
		var down := pressure[i+SIZE] if wet[i+SIZE] else pressure[i]
		var v := velocity[i]-Vector2(right-left,down-up)*(0.5/spacing)
		var radial := points[i]-center
		var distance := radial.length()
		# Slip along the glass wall and around Mother, with no flow through either.
		var normal := radial.normalized()
		var edge := smoothstep(radius-65.0,radius-12.0,distance)
		var mother := 1.0-smoothstep(55.0,90.0,distance)
		v -= normal*v.dot(normal)*maxf(edge,mother)
		velocity[i] = v.limit_length(MAX_SPEED)

func flow_texture() -> ImageTexture:
	if texture_revision==revision and texture!=null: return texture
	var image := Image.create(SIZE,SIZE,false,Image.FORMAT_RGBAH)
	for i in COUNT:
		var offset := transport[i]/(OFFSET_RANGE*2.0)+Vector2.ONE*0.5
		var v := velocity[i]/(MAX_SPEED*2.0)+Vector2.ONE*0.5
		image.set_pixel(i%SIZE,i/SIZE,Color(offset.x,offset.y,v.x,v.y))
	if texture==null:
		texture = ImageTexture.create_from_image(image)
	else:
		texture.update(image)
	texture_revision = revision
	return texture

func snapshot() -> Dictionary:
	return {"clock":clock,"accumulator":accumulator,"phase":phase,"velocity":velocity.duplicate(),"transport":transport.duplicate()}

func restore(data: Dictionary) -> void:
	# Older journeys simply start with calm currents, preserving their positions.
	if not data.get("velocity") is PackedVector2Array or not data.get("transport") is PackedVector2Array: return
	if data.velocity.size()!=COUNT or data.transport.size()!=COUNT: return
	for i in COUNT:
		if not data.velocity[i].is_finite() or not data.transport[i].is_finite(): return
	clock = maxf(0.0,float(data.get("clock",0.0)))
	accumulator = clampf(float(data.get("accumulator",0.0)),0.0,STEP)
	phase = float(data.get("phase",phase))
	for i in COUNT:
		velocity[i] = data.velocity[i].limit_length(MAX_SPEED) if wet[i] else Vector2.ZERO
		transport[i] = data.transport[i].limit_length(OFFSET_RANGE-1.0) if wet[i] else Vector2.ZERO
	revision += 1
