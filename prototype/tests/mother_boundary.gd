extends "res://tests/harvest_visual.gd"
const Geometry = preload("res://scripts/loop_geometry.gd")
const Resolver = preload("res://scripts/loop_resolver.gd")

func exercise() -> void:
	game = Main.new()
	game.audio_enabled = false
	game.save_records = false
	game.preferences_enabled = false
	game.pause_on_focus_loss = false
	game.journey_path = "/tmp/microverse-mother-boundary-unused.cfg"
	game.journey_profile.path = "/tmp/microverse-mother-boundary-profile-unused.cfg"
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	root.content_scale_size = Vector2i(1280,900)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.size = Vector2i(1280,900)
	RenderingServer.render_loop_enabled = false
	var run = game.run
	run.stage_index = 1
	run.start_stage()
	run.begin_encounter()
	run.enemies = [Drifter.new(500,run.board.center+Vector2(65,0),0)]
	var ring := [0,1,2,3,4,5,6,7]
	for reverse in [false,true]:
		if reverse: ring.reverse()
		mouse(run.board.anchors[ring[0]],true)
		for i in range(1,ring.size()):
			drag(run.board.anchors[ring[i-1]],run.board.anchors[ring[i]])
		expect(run.selection.mother_blocked() and not run.selection.can_close(),"Enclosing Mother is blocked in either winding")
		expect(run.preview().is_empty(),"Invalid membrane never highlights a capture")
		expect(game.JourneyHud.Guidance.next_action(run).title=="Keep the mother outside the loop","Live instruction names the actual restriction")
		drag(run.board.anchors[ring[-1]],run.board.anchors[ring[0]])
		if not reverse:
			game.large_text = true
			await capture("mother-boundary-preview")
		mouse(run.board.anchors[ring[0]],false)
		expect(run.integrity==5 and run.biomass==0 and run.kills==0 and run.enemies.size()==1,"Blocked release costs no health or food and kills nothing")
		expect(run.cells.all(func(cell): return cell.is_ready()) and run.clots.is_empty() and run.capture_serial==0,"No recovery, absorption or capture event on rejection")
		expect(game.toast.begins_with("Keep the mother outside"),"Release explains why the loop was cancelled")
	expect(not Resolver.commit(ring,run).valid,"Atomic commit also blocks direct or stale invalid input")
	run.selection.start(run.board.anchors[0])
	run.selection.visit(2)
	run.selection.visit(4)
	expect(run.selection.mother_blocked(),"Proposed closing line warns before release")
	run.selection.visit(2)
	run.selection.visit(9)
	run.selection.visit(0)
	expect(run.selection.closed and not run.selection.mother_blocked(),"Backtracking reshapes the loop and clears the warning")
	run.selection.cancel()
	var outside := PackedVector2Array([run.board.center+Vector2(35,-80),run.board.center+Vector2(35,80),run.board.center+Vector2(90,0)])
	expect(not Geometry.contains(run.board.center,outside) and Geometry.touches_mother(outside,run.board.center,40),"An edge cutting the body is blocked even with her center outside")
	var safe := [0,17,9]
	run.enemies[0].nucleus = (run.board.anchors[0]+run.board.anchors[17]+run.board.anchors[9])/3.0
	game.click_mode = true
	for id in safe+[safe[0]]:
		mouse(run.board.anchors[id],true)
		mouse(run.board.anchors[id],false)
	expect(run.selection.closed and run.preview()==[500],"Free connections around an outside enemy still preview correctly")
	key(KEY_ENTER)
	expect(run.kills==1 and run.integrity==5,"Click capture still defends Mother outside the exclusion zone")
	game.queue_free()
	await process_frame
	print("MOTHER BOUNDARY: %d checks; %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
