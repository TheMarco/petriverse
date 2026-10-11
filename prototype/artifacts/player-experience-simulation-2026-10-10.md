# Synthetic player experience — focused journey

October 10, 2026. These are simulated play reports generated from the game's actual encounter and membrane rules. They describe measured outcomes and inferred player experience; they are not human testimonials.

These samples predate the later hunter-pressure and feeding-objective adjustment. See the [matched saved-encounter check](challenge-pressure-2026-10-10.md) for that change.

## Method

Three scripted strategies played the same seed-101 fifteen-encounter journey without retries. Each drew the real swept-pointer gesture at two membrane segments per second, paused 2.5 seconds to decide, used six-pixel aim error, and waited before release to read the consequence preview. Each considered at most eight locally observed routes and had no future-position oracle. Menus, films, and pause time are excluded from active time. The script chooses mutations, habitat and Mother growth according to each strategy. Its occasional empty captures and failed gestures are recorded.

| Strategy | Mother growth | Result | Active time | Captures | Missed gestures | Poison taken | Hunter contacts / blocked | Final health | Graded captures |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Nimble / Fission | Guard, Guard | Won 15/15 | 22.6 min | 162 | 10 | 2 | 9 / 6 | 4 of 7 | 21 |
| Hunter / Symbiosis | Guard, Guard | Won 15/15 | 22.4 min | 160 | 5 | 0 | 11 / 7 | 4 of 7 | 16 |
| Feast / Elastic | Feeder | Lost at 8/15 | 10.6 min | 72 | 2 | 7 | 4 / 0 | 0 of 5 | 10 |

The paths earned 2,850, 2,175 and 1,125 bonus score respectively from graded captures. Long-link recovery averaged 0.45, 0.41 and 0.43 seconds per capture; 66, 51 and 23 captures had at least 0.5 seconds of added recovery. Broad loops therefore remained usable, but their cost accumulated during play.

## Inferred experience from each run

**Nimble / Fission.** The fast feeding strategy still made 20 empty captures and ten missed gestures, yet cleared the route. The first damaging hunter pressure appeared in Glassgarden. Six Guard interceptions let it finish with four health. Its 17 Grand sweeps made the score flourish recur throughout the journey. This suggests the new reward is visible during ordinary skilled play, while two Guards make this strategy forgiving.

**Hunter / Symbiosis.** This path collected more food than Nimble (312 versus 284), took no poison and cleared in similar time. It still saw eleven hunter contacts; seven were intercepted. The fourteen-encounter rescue, *Seeds of tomorrow*, was the sharpest late test: five contacts, two blocks and three lost health, followed by a final-boss win at four health. This suggests the closing biome can create tension without making the boss an automatic defeat.

**Feast / Elastic.** The scripted strategy deliberately accepted single-poison meals when the preview promised at least four food, taking seven poison hits across eight encounters. It entered encounter eight on two health and lost when three hunters reached Mother together. The Feeder bonus worked, and ten graded captures show the broad-loop playstyle had rewarding moments, but extra food did not save this risky policy. The loss is a meaningful consequence of the strategy; it is also a reason to observe real players before calling the Feeder choice balanced.

**Matched Guard check.** The same Feast policy and journey seed, choosing Guard in both growth slots, won all fifteen encounters in 25.2 minutes. It made 184 captures, took thirteen poison hits, and intercepted six of eight hunter contacts; Mother finished at five of seven health. The extra protection mattered in the encounter where the Feeder path ended. The routes diverged after the growth choice, so this is a strategy comparison rather than a controlled measurement of the organelle's isolated value. [Detailed Guard run](journey-living-ecosystem-feasibility-local-2.0-elastic-long-seed101-growth-guard.json).

**Careful Feeder check.** A second Feast run rejected every preview that already showed poison. It reached encounter nine, *Glass cradles*, then lost after four hunter contacts in that encounter. Across its 13.6 minutes and 94 captures it still took three poison hits, so a clean preview does not guarantee that moving creatures remain outside the membrane until release. The Feeder path's survival remains a balance question; these two scripted losses do not establish a human win rate. [Detailed careful Feeder run](journey-living-ecosystem-feasibility-local-2.0-elastic-long-seed101-growth-feeder-careful.json).

## What to watch in human playtests

- Can players see the warm long-link cue and predict the recovery cost before release?
- Do they understand that Feeder pays off on clean four-food captures, while Guard intercepts a hunter once per encounter? Does Feeder feel worth giving up that protection?
- Do players experience a clean preview becoming poisoned before release as fair movement, or as misleading feedback?
- Does the capture chord and ripple feel earned at the observed frequency, or become background noise?
- Does the fifteen-encounter journey retain a satisfying three-biome arc around the 22-minute active-play mark once menus, films, decisions, retries and pauses are included?

These runs show feasibility and reveal policy-specific failure. They do not estimate human completion time, enjoyment, learning, or win rate. Screen and audio fixtures verify that the choice, recovery preview and capture feedback are displayed; the script does not judge how they feel to a person.

## Reproduce

From `prototype/`: `godot --headless --path . --script res://tests/journey_feasibility.gd -- --long --seed=101 --rate=2.0 --build=fission` (replace `fission` with `symbiosis` or `elastic`). The detailed machine-readable [Nimble](journey-living-ecosystem-feasibility-local-2.0-fission-long-seed101.json), [Hunter](journey-living-ecosystem-feasibility-local-2.0-symbiosis-long-seed101.json) and [Feast](journey-living-ecosystem-feasibility-local-2.0-elastic-long-seed101.json) runs include one row per encounter. The feasibility script exits nonzero when a full requested journey loses; it still writes that run's report.
