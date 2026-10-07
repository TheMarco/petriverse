extends Node2D
## Delicate nutrient threads tie a successful meal to the mother. The violet
## stream uses the same capture event as health loss, even on a lethal meal.
func stream_position(origin: Vector2, target: Vector2, age: float, strand: float, u: float) -> Vector2:
	var side := (target-origin).orthogonal().normalized()
	var arch := sin(u*PI)*(sin(u*3.1-age*0.73+strand)*7.0+strand*2.5)
	return origin.lerp(target,u)+side*arch

func _draw() -> void:
	var game = get_parent().game
	if game == null or game.run.harvest == null:
		return
	for clot in game.effects:
		if clot.food == 0 and clot.poison == 0:
			continue
		var t: float = clot.progress()
		var fade := smoothstep(0.22, 0.35, t) * (1.0 - smoothstep(0.78, 0.98, t))
		var target: Vector2 = game.run.board.center
		var color := Color("e9a1c3") if clot.poison > 0 else Color("d1eaa0")
		if game.reduced_motion:
			draw_arc(target, 48.0, -PI * 0.5, PI * 1.5, 48, Color(color, fade * 0.4), 1.0, true)
			continue
		for strand in 2:
			var points := PackedVector2Array()
			for i in 24:
				var u := i / 23.0
				points.append(stream_position(clot.center,target,clot.age,float(strand),u))
			draw_polyline(points,Color(color,fade*0.085),0.65,true)
		for i in mini(12, clot.food * 2 + clot.poison * 3):
			var u := clampf((t - 0.26) * 2.2 - i * 0.033, 0.0, 1.0)
			u = smoothstep(0.0,1.0,u)
			var p := stream_position(clot.center,target,clot.age,float(i%2),u)
			var alpha := sin(u * PI) * fade
			var trail := PackedVector2Array()
			for j in 4:
				trail.append(stream_position(clot.center,target,clot.age,float(i%2),maxf(0.0,u-float(3-j)*0.012)))
			draw_polyline(trail,Color(color,alpha*0.27),1.3,true)
			draw_circle(p,2.6,Color(color,alpha*0.07),true,-1,true)
			draw_circle(p,0.85+float(i%3)*0.13,Color(color,alpha*0.80),true,-1,true)
			draw_circle(p-Vector2(0.2,0.3),0.32,Color("eaf4d5")*Color(1,1,1,alpha),true,-1,true)
