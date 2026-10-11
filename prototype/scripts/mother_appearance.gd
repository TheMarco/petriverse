extends RefCounted
## One continuous Mother grows new health organelles as the journey deepens.
const YOUNG = preload("res://assets/organisms/mother-young.png")
const GROWING = preload("res://assets/organisms/mother-growing.png")
const MATURE = preload("res://assets/organisms/mother.png")
const SIX = preload("res://assets/organisms/mother-six.png")
const SEVEN = preload("res://assets/organisms/mother-seven.png")
const FISSION_YOUNG = preload("res://assets/organisms/mother-fission-young.png")
const FISSION_GROWING = preload("res://assets/organisms/mother-fission-growing.png")
const FISSION_MATURE = preload("res://assets/organisms/mother-fission.png")
const FISSION_SIX = preload("res://assets/organisms/mother-fission-six.png")
const FISSION_SEVEN = preload("res://assets/organisms/mother-fission-seven.png")
const ELASTIC_YOUNG = preload("res://assets/organisms/mother-elastic-young.png")
const ELASTIC_GROWING = preload("res://assets/organisms/mother-elastic-growing.png")
const ELASTIC_MATURE = preload("res://assets/organisms/mother-elastic.png")
const ELASTIC_SIX = preload("res://assets/organisms/mother-elastic-six.png")
const ELASTIC_SEVEN = preload("res://assets/organisms/mother-elastic-seven.png")
const SYMBIOSIS_YOUNG = preload("res://assets/organisms/mother-symbiosis-young.png")
const SYMBIOSIS_GROWING = preload("res://assets/organisms/mother-symbiosis-growing.png")
const SYMBIOSIS_MATURE = preload("res://assets/organisms/mother-symbiosis.png")
const SYMBIOSIS_SIX = preload("res://assets/organisms/mother-symbiosis-six.png")
const SYMBIOSIS_SEVEN = preload("res://assets/organisms/mother-symbiosis-seven.png")

static func capacity_for_stage(stage: int) -> int:
	return 3 + int(stage >= 2) + int(stage >= 4) + int(stage >= 8) + int(stage >= 10)

static func texture_for(stage: int, mutations: Array) -> Texture2D:
	var growth := capacity_for_stage(stage) - 3
	var branch := ""
	for id in mutations:
		if id in ["fission", "elastic", "symbiosis"]:
			branch = id
			break
	match branch:
		"fission":
			return [FISSION_YOUNG, FISSION_GROWING, FISSION_MATURE, FISSION_SIX, FISSION_SEVEN][growth]
		"elastic":
			return [ELASTIC_YOUNG, ELASTIC_GROWING, ELASTIC_MATURE, ELASTIC_SIX, ELASTIC_SEVEN][growth]
		"symbiosis":
			return [SYMBIOSIS_YOUNG, SYMBIOSIS_GROWING, SYMBIOSIS_MATURE, SYMBIOSIS_SIX, SYMBIOSIS_SEVEN][growth]
	return [YOUNG, GROWING, MATURE, SIX, SEVEN][growth]

static func apply(sprite: Sprite2D, stage: int, mutations: Array) -> void:
	var next_texture := texture_for(stage, mutations)
	if sprite.texture != next_texture:
		sprite.texture = next_texture
