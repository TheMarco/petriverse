# Challenge adjustment — later feeding visits

October 10, 2026. A player reached encounter 17 of a saved thirty-encounter journey with little perceived challenge. That saved colony had full Mother health, six mutations, and a generated Glassgarden feeding visit ahead. The default new journey has fifteen encounters, but existing journeys retain their saved length and route.

## Change

- Generated feeding visits in Glassgarden and Blue Deep now require two actual hunter captures alongside their food goal. Food alone no longer ends them. The goal is shown before and during play, and capture progress persists through save and resume.
- Hunters move faster against colonies with four or more mutations from Glassgarden onward. With five or more, warned hunter arrivals follow the bloom sooner. The eight-second warning remains; the sheltered route retains its single-hunter wave.
- The first biome and less evolved colonies keep their teaching pace. The game labels the thirty-encounter format as an original journey in its route and briefing screens.

## Matched saved-encounter probe

The same saved encounter was restored into a separate, read-only simulation for each candidate. It used actual swept-pointer captures at two segments per second, 2.5 seconds of deliberation, six-pixel aim error, local observed routes, and no retries. The player's save was not changed.

| Rules | Outcome | Active time | Mother contacts | Guard blocks | Health change |
| --- | --- | ---: | ---: | ---: | ---: |
| Before adjustment | Cleared after food goal | 51.18 sec | 0 | 0 | 0 |
| Current adjustment | Cleared after food and two hunters | 107.37 sec | 3 | 1 | −2 |

The current run finished with three of five Mother health. An earlier candidate with faster hunters caused this simulated player to lose at 127.42 seconds, so hunter speed was reduced before the current run. This is one deterministic feasibility comparison, not a human win-rate estimate. The added objective creates a decision beyond collecting abundant food; the health cost gives the result stakes. Human play still needs to establish whether this feels fair and interesting over the remaining route.

## Full focused-route check

Two distinct scripted policies then traversed all fifteen encounters of the default route without retries at the same pointer speed and deliberation. Both completed. The Guard/Fission policy finished in **23.59 minutes** of active simulation with 23 hunter contacts, 11 blocks, and four of seven health. The careful Feeder/Elastic policy finished in **24.67 minutes** with 16 contacts, no blocks, and two of five health. The earlier careful Feeder sample had ended at encounter nine. These are behavior probes for this seed and these policies; they do not establish a player success rate. [Guard run](journey-living-ecosystem-feasibility-local-2.0-fission-long-seed101-challenge-v2.json) · [Feeder run](journey-living-ecosystem-feasibility-local-2.0-elastic-long-seed101-growth-feeder-careful-challenge-v2.json).
