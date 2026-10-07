extends "res://tests/harvest_visual.gd"
const Anatomy = preload("res://scripts/evolution_anatomy.gd")
const Save = preload("res://scripts/journey_save.gd")

func exercise() -> void:
	game = Main.new()
	game.audio_enabled = false
	game.save_records = false
	game.preferences_enabled = false
	game.pause_on_focus_loss = false
	game.journey_path = "/tmp/microverse-evolution-visual-unused.cfg"
	game.journey_profile.path = "/tmp/microverse-evolution-visual-profile.cfg"
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	root.size = Vector2i(1280,900)
	root.content_scale_size = Vector2i(1280,900)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	RenderingServer.render_loop_enabled = false
	game.run.fixed_seed = 73
	game.run.restart()
	game.run.state = Run.EVOLVE
	game.run.biomass = 30
	game.run.offered_mutations = ["elastic","fission","symbiosis"]
	await refresh()
	await capture("evolution-build-choices")
	expect(game.hud.cards[0].specimen.material.get_shader_parameter("evolution_form").y==1.0, "An upgrade card previews the anatomy it will add")
	key(KEY_1)
	await refresh()
	var reveal = game.evolution_reveal
	expect(reveal.visible and game.run.state==Run.BRIEF and game.run.stage_index==1, "A real purchase opens the safe evolution close-up")
	expect(game.run.mutations==["elastic"] and game.run.biomass==24, "The purchase is committed exactly once")
	expect(not game.hud.center_button.visible and not game.hud.cards[0].visible, "Underlying mission controls are hidden during growth")
	await capture("evolution-growth-before")
	var initial: Vector4 = reveal.mother.material.get_shader_parameter("evolution_form")
	var anchors: PackedVector2Array = game.run.board.anchors.duplicate()
	var rng_state: int = game.run.rng.state
	var elapsed: float = game.run.elapsed
	game.run.step(2.0)
	game._process(1.6)
	await capture("evolution-growth-middle")
	var middle: Vector4 = reveal.mother.material.get_shader_parameter("evolution_form")
	game._process(1.7)
	await capture("evolution-growth-after")
	var final_form: Vector4 = reveal.mother.material.get_shader_parameter("evolution_form")
	expect(initial.y==0.0 and middle.y>0.4 and middle.y<0.6 and final_form.y==1.0, "Membranes grow progressively into their permanent form")
	expect(game.run.elapsed==elapsed and game.run.board.anchors==anchors and game.run.rng.state==rng_state, "Watching evolution cannot advance the encounter or consume gameplay randomness")
	expect(reveal.cells[0].material.get_shader_parameter("evolution_form")==final_form, "Mother and colony share their build anatomy")
	key(KEY_ENTER)
	await refresh()
	expect(not reveal.visible and game.run.state==Run.BRIEF and game.hud.center_button.visible, "Enter dismisses the reveal without starting the mission")
	key(KEY_ENTER)
	await refresh()
	expect(game.run.state==Run.ACTIVE, "A separate Enter starts the next encounter")
	var cells: Array = game.microscope.cells
	expect(cells[0].material.get_shader_parameter("evolution_form")==final_form, "Actual playable cells retain the evolved shape")
	game.run.state = Run.ACTIVE
	game.run.mutations = ["elastic","enzyme","feast","filter"]
	await refresh()
	await capture("evolution-mature-feast-colony")
	expect(Anatomy.recipe(game.run.mutations).form.y>1.5,"Related traits develop a visibly broader mature feeding silhouette")
	game.run.state = Run.BRIEF
	reveal.present("feast")
	game._process(3.3)
	await capture("evolution-feast")
	var owned_recipe := Anatomy.recipe(game.run.mutations)
	expect(reveal.mother.material.get_shader_parameter("evolution_organs")==owned_recipe.organs, "Earlier organs remain when another trait develops")
	var snapshot := Save.capture(game.run)
	var restored := Run.new(true,73,true,true)
	expect(Save.restore(restored,snapshot), "An evolved journey still restores through the existing save format")
	expect(Anatomy.recipe(restored.mutations)==owned_recipe, "Anatomy reconstructs exactly from saved traits")
	restored.dispose()
	for build in [["fission","grazer","lure","nursery"],["symbiosis","enzyme","residual","frenzy"]]:
		reveal.dismiss()
		game.run.state = Run.ACTIVE
		game.run.mutations = build
		await refresh()
		await capture("evolution-mature-nimble-colony" if build[0]=="fission" else "evolution-mature-hunter-colony")
		game.run.state = Run.BRIEF
		reveal.present(build.back())
		game._process(3.3)
		await capture("evolution-nimble" if build[0]=="fission" else "evolution-hunter")
	game.large_text = true
	game.reduced_motion = true
	game.run.mutations = Anatomy.IDS.duplicate()
	reveal.present("nursery")
	await capture("evolution-all-traits-large-text")
	expect(game.microscope.growth_progress()==1.0, "Reduced motion shows completed anatomy immediately")
	expect(reveal.mother.material.get_shader_parameter("motion")==0.0, "Reduced motion also stops the specimen deformation")
	key(KEY_ESCAPE)
	await refresh()
	expect(not reveal.visible and game.run.state==Run.BRIEF, "Escape safely skips the close-up")
	game.reduced_motion = false
	reveal.present("nursery")
	mouse(Vector2(640,741),true)
	mouse(Vector2(640,741),false)
	await refresh()
	expect(not reveal.visible, "The Continue button skips growth immediately")
	game.reset_presentation()
	await refresh()
	expect(game.microscope.growing_trait.is_empty() and not reveal.visible, "Resetting presentation clears only the transient reveal")
	expect(game.microscope.mother.material.get_shader_parameter("evolution_organs")==Anatomy.recipe(game.run.mutations).organs, "Resetting presentation preserves owned anatomy")
	# Shared tissue changes must retain the existing core injury and fused capture.
	game.run.state = Run.ACTIVE
	game.run.enemies.clear()
	var center: Vector2 = game.run.board.center
	game.run.enemies.append(Drifter.new(800,center+Vector2(44,0),0.0))
	game.run.resolve_contacts()
	game.run.mother_damage.step(2.3)
	await refresh()
	var damage: PackedFloat32Array = game.microscope.mother.material.get_shader_parameter("core_damage")
	expect(game.run.integrity==4 and damage.count(1.0)==1, "A fully evolved Mother still loses exactly one visible health core per hit")
	expect(game.microscope.mother.material.get_shader_parameter("core_sites")==PackedVector2Array(game.run.MotherDamage.CORE_UVS), "Evolution retains the registered health core positions")
	expect(game.microscope.mother.get_node("GrowthBud0").visible, "The Mother retains living buds from Fission")
	expect(game.microscope.mother.get_node("GrowthBud2").visible,"Nursery creates a distinct living pearl bud")
	var hybrid := Anatomy.recipe(["elastic","fission","symbiosis","enzyme"])
	expect(hybrid.form.y>1.0 and hybrid.form.x>0.0 and hybrid.form.z>0.0,"Mixed specializations retain visible secondary anatomy")
	game.run.state = Run.BRIEF
	reveal.present("nursery")
	game._process(3.3)
	await capture("evolution-wounded-mother")
	expect(reveal.mother.material.get_shader_parameter("core_damage")==damage, "The close-up preserves wounds instead of showing a healthy substitute")
	reveal.dismiss()
	game.run.state = Run.ACTIVE
	var b = game.run.board
	var meal_center: Vector2 = (b.anchors[0]+b.anchors[8]+b.anchors[9])/3.0
	game.run.enemies.append(game.run.Harvest.Organism.new(801,"food",meal_center,Vector2.ZERO,0.0))
	game.run.selection.start(b.anchors[0])
	for id in [8,9,0]:
		game.run.selection.visit(id)
	game.commit_selection()
	expect(game.run.clots.size()==1, "Evolved cells still start a fused capture")
	game.run.step_recovery(1.0)
	await refresh()
	expect(not game.microscope.buds[8].visible and game.microscope.cells[8].modulate.a<0.05, "Buds and evolved tissue disappear into the shared digestion mass")
	game.run.step_recovery(8.0)
	await refresh()
	expect(game.microscope.buds[8].visible and game.microscope.cells[8].modulate.a==1.0, "Cells return with their permanent anatomy after digestion")
	var clock_before: float = game.microscope.mother.material.get_shader_parameter("clock")
	game.run.state = Run.PAUSED
	game._process(2.0)
	expect(game.microscope.mother.material.get_shader_parameter("clock")==clock_before, "Pausing freezes evolved tissue and its buds")
	game.queue_free()
	await process_frame
	print("EVOLUTION VISUALS: %d checks; %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
