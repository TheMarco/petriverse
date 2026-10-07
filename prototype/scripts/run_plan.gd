extends RefCounted
## Deliberate formations, rotated together between runs. Times are simulation time.
const TITLES := ["First currents", "Armored waters", "A living weave", "The Conjoined"]
const LESSONS := ["Let them gather. One loop can feed several cells.", "Crack a shell, then keep another route ready.", "Linked nuclei must share one membrane.", "Enclose both hearts when the body contracts."]

static func encounter(index: int, rotation: float) -> Array:
	var waves: Array
	match index:
		0:
			waves = [
				[2.0, -80, ["drifter", "drifter"]],
				[12.0, 70, ["drifter", "drifter"]],
				[23.0, 205, ["drifter", "drifter"]],
				[37.0, -25, ["drifter", "drifter"]],
			]
		1:
			waves = [
				[2.0, -65, ["shellback", "drifter"]],
				[10.0, 110, ["shellback", "drifter"]],
				[19.0, 225, ["twinspore", "drifter"]],
				[28.0, -5, ["shellback", "drifter"]],
				[38.0, 150, ["twinspore", "shellback"]],
			]
		_:
			waves = [
				[1.0, -90, ["twinspore", "drifter"]],
				[8.0, 70, ["shellback", "drifter"]],
				[16.0, 215, ["shellback", "twinspore"]],
				[24.0, -10, ["twinspore", "drifter"]],
				[31.0, 140, ["shellback", "drifter"]],
				[43.0, 270, ["shellback", "twinspore"]],
			]
	var result: Array = []
	for wave in waves:
		for i in wave[2].size():
			result.append({"at": wave[0] + i * 0.6, "angle": float(wave[1]) + rotation + i * 9.0,
				"kind": wave[2][i], "speed": 6.6 + index * 0.55 + i * 0.25,
				"radius": 373.0 - i * 9.0})
	return result
