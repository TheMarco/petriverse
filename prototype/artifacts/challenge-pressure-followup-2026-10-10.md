# Later-route challenge follow-up

October 10, 2026. The player found the first balance pass only slightly better, then said the late journey was easy in every respect. A copy of the live save was restored at encounter 25 of the original thirty-encounter route for deterministic probes. The player's save and running game were not changed by the probes.

## Current rules

- In the original route's Blue Deep, stored food attracts faster hunters when the colony has five or more mutations. The first biome and focused fifteen-encounter route keep their existing pace.
- Alternating late non-boss encounters end with a warned hunter wave after their main goal. Defense brings an armored Shellback and other hunters; rescue brings a linked Twinspore. The food-rich route adds another hunter. If the main goal is completed within 140 seconds, one more hunter joins and the wave moves faster. A final hunter that reaches Mother is replaced after another warning. A wave triggered near the encounter limit gets at least 60 seconds to resolve.
- A Guard that blocks a hunter rests through the next two encounters on the original route. Late repair requires two wounded cores, restores two for six food, and cannot be used after consecutive encounters. Recovery and final-wave state survive save/resume.

The route, briefing, live guidance, Guard status, and repair button explain these rules. Existing saves retain their health, food, traits, and route.

## Same saved encounter

The probes use actual swept-pointer captures with six-pixel aim error and no future-spawn knowledge. The deliberate policy draws two segments per second and deliberates for 2.5 seconds; the practiced policy draws three and deliberates for 1.5 seconds. Both reject known poison and use the sheltered route. They are feasibility samples, not human win rates.

| Encounter 25 | Active time | Mother contacts | Guard blocks | Health lost |
| --- | ---: | ---: | ---: | ---: |
| Previous pass, deliberate | 196.28 sec | 3 | 2 | 1 |
| Current, deliberate | 243.70 sec | 6 | 2 | 4 |
| Previous pass, practiced | 107.37 sec | 0 | 0 | 0 |
| Current, practiced | 125.08 sec | 3 | 2 | 1 |

The current deliberate policy survived encounter 25 with two of six health. A candidate with two armored Shellbacks killed it in the same encounter, so the final wave uses one armored hunter with ordinary companions unless a swift clear draws a larger wave.

## Continuation through the finale

With the current rules, the practiced policy completed encounters 25–30 without a retry in 668.80 seconds of active simulation. It took nine Mother contacts, used four Guard blocks, and finished with six of seven health. The deliberate policy cleared encounters 25–28, then lost at encounter 29 after 13 contacts across its five encounters. The normal retry keeps previous progression and restores at least three health, but this no-retry probe stopped at the loss.

This is a meaningful split between the two scripted styles. It still does not establish how difficult or enjoyable the route is for a human player, and the practiced policy survived comfortably. More adjustments should be guided by actual play rather than a claim that these probes prove the balance is solved.

## Verification

- `tests/journey_ecology.gd`: 59 checks, zero failures. Covers late waves, linked hunters, all four food-rich arrivals, replacement, deadline grace, and save/resume.
- `tests/journey_rules.gd`: 118 checks, zero failures. Covers Guard and repair recovery, save/resume, and retry health.
- `tests/procedural_journey.gd`: 171 checks, zero failures.
- Main scene opened in headless Godot without script errors.
