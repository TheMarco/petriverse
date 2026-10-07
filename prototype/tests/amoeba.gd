extends "res://tests/journey_rules.gd"

func quiet(run: RefCounted) -> void:
	fixture_stage(run,5)
	run.enemies.clear()
	run.harvest.next_bloom = 9999.0
	run.harvest.ecology.next_wave = 9999.0
	run.harvest.ecology.pending.clear()
	run.harvest.spec.food = 999

func ready_amoeba(run: RefCounted) -> RefCounted:
	var body = run.harvest.ecology.add(run,"amoeba",0,run.harvest.ecology.pocket(run,0))
	body.age = 4.0
	run.amoebas.step(run,0.01)
	body.nucleus = body.destination
	body.age = 6.0
	run.amoebas.step(run,0.01)
	return body

func engulf(run: RefCounted, body: RefCounted) -> void:
	body.reach_age = 2.79
	run.amoebas.step(run,0.02)

func exercise() -> void:
	var crawler = Run.Amoebas.Body.new(41,Vector2.ZERO)
	crawler.destination = Vector2(1000,0)
	crawler.phase = "approaching"
	var period := TAU/0.85
	crawler.step(period,Vector2.ZERO)
	expect(absf(crawler.nucleus.x-6.0*period)<0.001,"Extension/retraction preserves the six-pixel average crawling pace")
	var fine = Run.Amoebas.Body.new(41,Vector2.ZERO)
	fine.destination = Vector2(1000,0)
	fine.phase = "approaching"
	for i in 120: fine.step(period/120.0,Vector2.ZERO)
	expect(fine.nucleus.distance_to(crawler.nucleus)<0.001,"Crawling travel is independent of frame subdivision")
	var run = Run.new(true,73,true,true)
	quiet(run)
	var body = ready_amoeba(run)
	var victim: int = body.target_node
	expect(body.phase=="reaching" and victim>=0,"Amoeba approaches a real cell and telegraphs its reach")
	expect(not body.site_nodes.has(victim) and run.Geometry.capture_valid(body.site_nodes,run.board,run.is_ready,8),"Rescue triangle excludes the victim and Mother")
	run.selection.start(run.board.anchors[victim])
	engulf(run,body)
	expect(body.captive_node<0 and run.is_ready(victim) and run.selection.path.has(victim),"Never swallows a cell in the current gesture")
	run.selection.cancel()
	run.enemies.clear()
	body = ready_amoeba(run)
	victim = body.target_node
	run.cells[victim].spend(3.0)
	engulf(run,body)
	expect(body.captive_node<0,"Never swallows a recovering cell")
	run.cells[victim].remaining = 0.0
	run.enemies.clear()
	body = ready_amoeba(run)
	victim = body.target_node
	engulf(run,body)
	expect(body.captive_node==victim and not run.is_ready(victim) and not run.cells[victim].lost,"Engulfed cell remains alive, visibly captive and unavailable")
	expect(body.rescue_remaining()==15.0,"The rescue window starts at a full fifteen seconds")
	expect(body.captive_position().distance_to(run.board.anchors[victim])<0.01,"Engulf animation starts at the cell's actual location")
	run.toggle_pause()
	run.step(5.0)
	expect(body.rescue_remaining()==15.0,"Pause freezes the digestion deadline")
	var clone = Run.new(true,92,true,true)
	expect(Save.restore(clone,Save.capture(run)),"Captive encounter restores from save")
	var other = clone.enemies.filter(func(e): return e.kind=="amoeba")[0]
	expect(other.captive_node==victim and other.rescue_remaining()==15.0 and not clone.is_ready(victim),"Save preserves both ends of captivity and remaining time")
	clone.dispose()
	run.toggle_pause()
	run.amoebas.step(run,14.9)
	expect(not run.cells[victim].lost and body.rescue_remaining()>0.09,"Cell is recoverable until the deadline")
	select(run,body.site_nodes)
	expect(run.harvest_preview().cells_rescued==1,"Capture preview promises the actual rescue")
	var result: Dictionary = run.release()
	expect(result.valid and result.cells_rescued==1 and not run.enemies.has(body),"A normal loop captures the gold nucleus and rescues the cell")
	expect(run.cells[victim].captor<0 and not run.is_ready(victim) and not run.amoebas.return_for(victim).is_empty(),"Rescued cell swims home before becoming selectable")
	clone = Run.new(true,93,true,true)
	Save.restore(clone,Save.capture(run))
	expect(clone.amoebas.releases==run.amoebas.releases,"Return animation survives save/resume")
	clone.dispose()
	for i in 80: run.step(1.0/60.0)
	expect(run.is_ready(victim) and run.amoebas.releases.is_empty(),"Rescue restores a working blue cell")
	quiet(run)
	body = ready_amoeba(run)
	victim = body.target_node
	engulf(run,body)
	for i in 540: run.step(1.0/60.0)
	var rescue_path: Array = body.site_nodes.duplicate()
	run.selection.start(run.board.anchors[rescue_path[0]])
	for node in rescue_path.slice(1)+[rescue_path[0]]:
		for i in 20: run.step(1.0/60.0)
		run.selection.visit(node)
	result = run.release()
	expect(result.valid and result.cells_rescued==1 and not run.cells[victim].lost,"A drifting rescue remains feasible after nine seconds of deliberation at three segments per second")
	quiet(run)
	body = ready_amoeba(run)
	victim = body.target_node
	engulf(run,body)
	run.amoebas.step(run,15.0)
	expect(run.cells[victim].lost and body.phase=="sated" and body.captive_node<0 and run.integrity==5,"Expired rescue costs one cell, never Mother health")
	clone = Run.new(true,94,true,true)
	Save.restore(clone,Save.capture(run))
	expect(clone.cells[victim].lost and not clone.is_ready(victim),"Digested cells remain absent after resume")
	clone.dispose()
	fixture_stage(run,6)
	expect(run.cells.all(func(c): return c.is_ready() and not c.lost),"All eaten cells regrow in the next encounter")
	quiet(run)
	for i in 4: run.cells[i].lost = true
	body = ready_amoeba(run)
	expect(body.target_node<0,"At most four cells can be missing")
	quiet(run)
	for i in 4: run.harvest.ecology.spawn_event(run,{"kind":"amoeba","area":i})
	expect(run.enemies.size()==1,"Introduction allows only one amoeba at a time")
	run.stage_index = 8
	for i in 4: run.harvest.ecology.spawn_event(run,{"kind":"amoeba","area":i})
	expect(run.enemies.size()==2,"Later encounters cap amoebas at two")
	quiet(run)
	body = ready_amoeba(run)
	engulf(run,body)
	var second = ready_amoeba(run)
	engulf(run,second)
	expect(second.captive_node<0,"Two amoebas cannot swallow cells at the same moment")
	var first_cell: int = body.captive_node
	run.finish_journey_stage()
	expect(run.cells[first_cell].captor<0 and not run.amoebas.releases.is_empty(),"Finishing the encounter releases any surviving captive")
	for i in 80: run.step(1.0/60.0)
	expect(run.amoebas.releases.is_empty(),"Release animation finishes while the evolution screen is open")
	run.dispose()
	print("AMOEBA: %d checks; %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
