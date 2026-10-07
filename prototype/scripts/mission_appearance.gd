extends RefCounted
## A repeatable visual recipe. Does not read or advance the gameplay RNG.
const WATER := [
	Vector3(0.76,1.10,1.02), Vector3(0.93,1.02,1.18), Vector3(0.72,1.13,0.92),
	Vector3(0.87,1.03,1.13), Vector3(0.82,1.08,1.10), Vector3(1.02,1.01,1.02),
	Vector3(0.88,0.82,1.20), Vector3(0.65,0.98,1.07), Vector3(1.00,0.87,1.17)
]
const COLONY := [Vector3(0.79,1.10,1.12), Vector3(0.94,0.97,1.17), Vector3(0.85,1.06,1.02)]
const PLATES := ["res://assets/biomes/stillwater-v2.png", "res://assets/biomes/glassgarden-v2.png", "res://assets/biomes/blue-deep-v2.png"]
const WATER_BASE := [Vector3(0.055,0.115,0.150), Vector3(0.070,0.120,0.140), Vector3(0.030,0.040,0.085)]

static func make(seed_value: int, stage: int, journey: bool = true, habitat: String = "bloom") -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value ^ ((stage+1)*0x45d9f3b)
	var biome := clampi(stage/4,0,2)
	var grade: Vector3 = WATER[biome*3+rng.randi_range(0,2)]
	grade *= rng.randf_range(0.96,1.04)
	if habitat=="refuge" and journey:
		grade *= Vector3(0.89,1.01,1.12)
	var shape := rng.randi_range(0,2)
	var cells: Array[Vector4] = []
	for i in 24:
		var stretch := rng.randf_range(0.91,1.07) if shape==0 else rng.randf_range(0.86,0.96) if shape==1 else rng.randf_range(1.05,1.14)
		cells.append(Vector4(stretch,1.0/stretch,float(3+shape*2),rng.randf_range(0.018,0.05)))
	return {
		"key": "%d:%d:%s" % [seed_value,stage,str(journey)] + (":refuge" if habitat=="refuge" else ""),
		"biome":biome if journey else 0,
		"plate":PLATES[biome] if journey else PLATES[0],
		"water_base":WATER_BASE[biome] if journey else WATER_BASE[0],
		"water_grade": grade if journey else Vector3.ONE,
		"colony_grade": COLONY[rng.randi_range(0,2)] if journey else Vector3.ONE,
		"plate_turn": rng.randf_range(-PI,PI) if journey else 0.0,
		"plate_offset": Vector2(rng.randf_range(-0.025,0.025),rng.randf_range(-0.025,0.025)) if journey else Vector2.ZERO,
		"plate_scale": rng.randf_range(0.89,1.04) if journey else 1.0,
		"light_direction": Vector2.from_angle(rng.randf_range(-2.8,-0.35)) if journey else Vector2(-0.65,-1.0),
		"sediment": rng.randf_range(0.78,1.12)*(1.12 if habitat=="refuge" else 1.0) if journey else 1.0,
		"life_seed": int(rng.randi()) if journey else 73127,
		"dust_seed": int(rng.randi()) if journey else 90713,
		"life_count": rng.randi_range(40,46) if journey else 46,
		"dust_count": [224,240,264][rng.randi_range(0,2)] if journey else 264,
		"cells": cells if journey else [],
	}
