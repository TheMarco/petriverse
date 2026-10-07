extends RefCounted
## Optional, once-per-encounter rewards. Never alter required food progress.
const FEATS := {
	"guardian":{"title":"A life protected","detail":"Rescued a spore with a nearby hunter."},
	"gatherer":{"title":"Two blooms, one loop","detail":"Gathered at least four food from two different blooms."},
	"clear_water":{"title":"A clean encounter","detail":"Finished without taking poison damage."},
}
const KEEPSAKES := {"guardian":"Pearl nursery","gatherer":"Fern meadow","clear_water":"Glass garden"}

static func award(run: RefCounted, id: String) -> bool:
	if run.stage_index==0 or run.integrity<=0 or run.mastery_awards.any(func(a): return a.id==id and a.get("encounter",str(a.stage))==run.encounter_key()):
		return false
	var before: int = run.biomass
	run.bank_food(1)
	run.score += 150
	run.mastery_awards.append({"id":id,"stage":run.stage_index,"encounter":run.encounter_key(),"title":FEATS[id].title,"detail":FEATS[id].detail,"food":run.biomass-before})
	return true

static func capture(run: RefCounted, absorbed: Array, poison: int) -> Array:
	var earned: Array = []
	if poison>0 or run.stage_index==0:
		return earned
	var bodies: Array = run.enemies.filter(func(e): return absorbed.has(e.id))
	var spores: Array = bodies.filter(func(e): return e.kind=="spore")
	var hunters: Array = bodies.filter(func(e): return e.kind in ["drifter","shellback","twinspore","divider"])
	var guardian := false
	for spore in spores:
		for hunter in hunters:
			guardian = guardian or spore.nucleus.distance_to(hunter.nucleus)<=110.0
	if guardian and award(run,"guardian"):
		earned.append("guardian")
	var food: Array = bodies.filter(func(e): return e.kind=="food")
	var blooms: Array = []
	for body in food:
		if body.bloom_id>=0 and not blooms.has(body.bloom_id):
			blooms.append(body.bloom_id)
	if food.size()>=4 and blooms.size()>=2 and award(run,"gatherer"):
		earned.append("gatherer")
	return earned

static func complete(run: RefCounted) -> void:
	if run.harvest.poison_taken==0:
		award(run,"clear_water")

static func suggestion(run: RefCounted) -> String:
	var preferred := "guardian" if run.harvest.spec.mode=="rescue" else "gatherer"
	if run.mastery_awards.any(func(a): return a.id==preferred and a.get("encounter",str(a.stage))==run.encounter_key()):
		return "Optional feat earned · "+FEATS[preferred].title
	return "Optional · rescue a spore with a nearby hunter." if preferred=="guardian" else "Optional · gather 4 food from two blooms in one loop."
