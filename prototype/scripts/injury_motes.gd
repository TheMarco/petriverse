extends Node2D
## Gold organelle fragments drawn above the invading tissue. Bounded by five
## active bites; all motion comes from simulation age, never wall-clock time.

func _draw() -> void:
	var microscope = get_parent()
	for bite in microscope.game.run.mother_damage.bites:
		if not microscope.invaders.has(bite.serial):
			continue
		var source: Vector2 = microscope.core_position(bite.core)
		var mouth: Vector2 = microscope.invaders[bite.serial].position
		var direction := (mouth - source).normalized()
		var side := direction.orthogonal()
		var age: float = bite.age
		var draw_in := sin(smoothstep(0.50,1.66,age)*PI)
		# A continuous translucent strand makes the core's material visibly
		# stretch into the hunter before it separates into tiny wet vesicles.
		if draw_in>0.0:
			var upper := PackedVector2Array()
			var lower := PackedVector2Array()
			for j in 17:
				var t := float(j)/16.0
				var center := source.lerp(mouth,t)+side*sin(t*PI)*sin(age*6.0)*2.4
				var width := sin(t*PI)*(1.3+draw_in*1.5)*(1.0-t*0.65)
				upper.append(center+side*width)
				lower.append(center-side*width)
			var ribbon := upper.duplicate()
			var reverse := lower.duplicate()
			reverse.reverse()
			ribbon.append_array(reverse)
			draw_colored_polygon(ribbon,Color(0.96,0.69,0.29,draw_in*0.20))
			draw_polyline(upper,Color(1.0,0.87,0.53,draw_in*0.48),0.65,true)
			draw_polyline(lower,Color(0.69,0.86,0.83,draw_in*0.30),0.55,true)
		if bite.kind!="cyst":
			var inward: Vector2 = (source-bite.origin).normalized()
			var across := inward.orthogonal()
			var entry: Vector2 = bite.origin.lerp(source,0.18)
			var opening := smoothstep(0.04,0.34,age)*(1.0-smoothstep(0.72,1.24,age))
			var seal := sin(smoothstep(1.30,2.2,age)*PI)
			for lip in [-1.0,1.0]:
				var fold := PackedVector2Array()
				for j in 19:
					var t := float(j)/18.0
					fold.append(entry+across*(t-0.5)*22.0+inward*sin(t*PI)*lip*(opening*4.3+0.5))
				draw_polyline(fold,Color(0.42,0.72,0.76,opening*0.38+seal*0.20),1.7,true)
				draw_polyline(fold,Color(0.79,0.94,0.91,opening*0.57+seal*0.32),0.55,true)
		for i in 28:
			var t := (age - 0.54 - i * 0.028) / 0.48
			if t <= 0.0 or t >= 1.0:
				continue
			var angle: float = i * 2.399 + bite.core * 1.31
			var origin := source + Vector2.from_angle(angle) * (2.0 + float(i % 4) * 1.2)
			var pos := origin.lerp(mouth, smoothstep(0.0, 1.0, t))
			pos += side * sin(t * PI) * sin(angle) * 7.0
			var alpha := sin(t * PI) * (0.65 + float(i % 3) * 0.12)
			var size := 0.65 + float(i % 4) * 0.29
			var trail := PackedVector2Array()
			for j in 4:
				var past := maxf(0.0,t-float(3-j)*0.035)
				trail.append(origin.lerp(mouth,smoothstep(0.0,1.0,past))+side*sin(past*PI)*sin(angle)*7.0)
			draw_polyline(trail,Color(0.88,0.64,0.26,alpha*0.23),size*0.65,true)
			size *= 1.0-t*0.38
			draw_circle(pos, size * 3.0, Color(1.0, 0.56, 0.16, alpha * 0.10), true, -1, true)
			draw_circle(pos, size, Color(1.0, 0.76 + float(i % 3) * 0.06, 0.39, alpha), true, -1, true)
			draw_circle(pos - Vector2(0.2, 0.3), size * 0.38, Color(1.0, 0.96, 0.78, alpha), true, -1, true)
