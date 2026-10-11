# MICROVERSE — A living journey

The default game is a connected journey through **Stillwater, Glassgarden, and the Blue Deep**: fifteen encounters, three bosses, twelve available mutations, and three starting colonies. Only the final Conjoined victory ends the journey. Existing saves retain their original twelve- or thirty-encounter route.

Your colony carries its health, mutations, stored nourishment, and discoveries forward. The mother begins with three health organelles and grows to seven. Capture green desmids for food; violet spiked cysts poison mixed meals. Hunters threaten the mother, while pearl spores are young colonies to rescue. Every encounter begins with its own paused briefing.

## First-encounter creature films

All **44 discoverable creatures and forms** have a close-up introduction, rendered live with the same textures, animation, fluid and capture behavior as the game and promo reel. First sightings offer a nonblocking **Watch film** choice. When several appear together, the player can watch one and find the others in the Field Journal, or choose **Later** and keep playing. Opening a film pauses the real encounter and demonstrates the creature in an independent dish. Timers, health, food, cells and water in the player's dish remain unchanged.

Each film includes a bundled **ElevenLabs / Willa Ashford** voiceover, matching subtitles, and a short action cue. **Space** pauses playback; **Replay** starts it again; **Escape / Skip film** closes it. The soundtrack lowers during narration. Audio preferences, reduced motion, larger text and focus-loss pausing apply. No network or API key is needed at runtime.

Viewed introductions and offered films persist across journeys. Open the **Field Journal (J)** and select **Watch film** under any discovered creature to see it later or again. Older profiles migrate automatically. The current **0.2.3** Mac, Windows and Linux release packages are in `../dist/`, named `Petriverse-0.2.3-macos-universal.zip`, `Petriverse-0.2.3-windows-x86_64.zip` and `Petriverse-0.2.3-linux-x86_64.zip` (also available as `.tar.gz`). Their internal versions match; previous releases and development previews are retained.

Focused verification: 44 behavior scenarios (179 unique checks, with six grazing variants rechecked after correcting their capture margin), 25 native cinema integration checks, the existing 19-check discovery/journal fixture, and native visual runs for amoeba, phage, grazer and Warden. Tests: `tests/creature_films.gd` (headless), `tests/creature_cinema_integration.gd` (native audio driver), and `tests/creature_cinema_visual.gd`. Exact spoken text and generation provenance live in `../artifacts/creature-film-audio/provenance.json`; `../tools/import_creature_narration.py` imports and validates registered audio downloads.

## Bacteriophages and copper bacteria

**Small allies**, encounter 4 of a new fifteen-encounter journey, introduces silver bacteriophage clusters and copper rod-shaped bacterial food thieves. This guaranteed teaching encounter places a cluster near its host and holds the first hunter arrival. From Glassgarden onward, bacteria/phages join the seeded family pool. The older twelve-encounter journey can first encounter them in the Nursery's second wave. Saved route recipes are preserved.

Drag a silver cluster toward a copper rod using **Nudge**. The push shares the six-second cooldown with cyst nudging. Three independently animated phages settle onto the bacterial wall, flex their fibres and contract their tails. Infection lasts **nine seconds**; the host slows, stops feeding after three seconds, swells, develops internal capsids and ruptures. Rupture removes one threat, stirs the shared water, and releases exactly the stolen food as collectable green organisms. Capturing the host directly instead returns its stolen food immediately. A cluster treats one host; escaping progeny are a short visual aftermath, not a chain reaction. Phages never infect Mother, blue colony cells, amoebas, or the non-bacterial enemy families, and loops cannot consume them.

Guidance, countdown labels, the briefing and journal explain the choice in play. Attachment, infection, free clusters, in-flight nudges and rupture aftermath survive save/resume; pause freezes them. Reduced motion quiets the fibres and dispersal while retaining the readable infection state. Save snapshots also retain previous body positions so wake impulses resume without a small drift discontinuity.

The new artwork uses the built-in image-generation tool: [copper bacterium](assets/organisms/copper-bacterium.png), [silver phage](assets/organisms/silver-phage.png). Exact prompts and provenance: [bacterium](assets/organisms/copper-bacterium-prompts.json), [phage](assets/organisms/silver-phage-prompts.json). Both textures use mipmaps for small-scale clarity. The amoeba now has a brighter refractive double membrane while retaining one continuous body through engulfing.

Focused checks: phage rules **22**, native phage presentation **11**, shared Nudge **37**, journey ecology **34**, procedural routes **706**, and native amoeba membrane pixels **15**, all passing. Native visual script: `godot --path . --script res://tests/phage_visuals.gd --fixed-fps 60`; optional `-- --closeup` produces a magnified view. [15.5-second in-engine infection preview](artifacts/phage-infection-closeup.mp4).

Separate Mac practice apps live in `../dist/playtests/`: **Amoeba Practice.app** and **Phage Practice.app**. Enter begins; R restarts. Both disable journey/profile/preference writes and use separate application data names. The source scenes can also be run with `godot --path . res://playtests/amoeba.tscn` or `godot --path . res://playtests/phages.tscn`.

## Launch

Tested with **Godot 4.7.2 stable**, native macOS, Compatibility renderer. Textures and shaders are bundled. Playing needs no plugins, downloads, or network access.

- On macOS, double-click `Launch.command`.
- Import `project.godot` into Godot and press **F5**.
- From this directory: `godot --path .`
- Legacy combat campaign: `godot --path . -- --campaign`
- Isolated harvest fixture: `godot --path . -- --harvest`

The logical canvas is 1280 × 900. The resizable window starts at 1152 × 810, letterboxes other aspect ratios, and supports a minimum 768 × 540. Relaunch after source changes; returning home saves progression; relaunching loads the current scripts and offers Continue.

## Controls

**New journey** starts the ordinary colony with a safe, playable opening: follow three numbered cells around food, watch their recovery, then surround two food clusters with six cells. Practice food does not expire and the encounter timer waits. Only the six teaching cells hold position; the rest of the dish keeps drifting. Lesson progress survives save/resume. **Advanced starting colonies** is optional and retains the earned unlocks.

The first upgrade offers **Faster small captures** and **More food from large captures**, with animated examples, the scientific trait name underneath, costs, remaining food, and tradeoffs. Upgrades last for the current journey. Repair explicitly restores Mother health; keeping food skips the purchase and travels onward. Defense-specific upgrades enter the offer pool after the defense encounter. Existing saves at the first upgrade receive the simpler pair without resetting progress.

| Action | Control |
| --- | --- |
| Start and extend | Hold left mouse on a ready cell, then drag through any ready blue cells |
| Close and capture | Return to the first cell after 3–8 distinct cells, then release |
| Nudge poison aside | Drag a purple cyst toward clear water and release; in click mode, click the cyst, then its destination |
| Backtrack | Return to the immediately previous cell |
| Cancel | Release an open path, right-click, or Escape |
| Pause / resume | Space or the pause button at the top right; losing application focus also pauses |
| Retry a failed encounter | R or Retry this encounter; earlier progress is retained |
| Save & return home | Pause menu, or R outside the loss screen |
| How to play | H, the ? button, or the pause menu; pauses the dish and shows the loop gesture, organism key, current objectives, and keyboard shortcuts |
| Field journal | J or the pause menu; pauses active gameplay |
| Begin an encounter | Enter or Begin encounter |
| Click input | C, or Input in Settings; click vertices and the start, then Enter commits |
| Choose evolution | Click a card or press 1, 2, or 3 |
| Settings | V or the pause menu; music/effect volume, mute, input mode, motion, markers, text size, and visual detail |
| Reduced motion | M, or Motion in Settings |
| Inspect dish | D or F3; displays internal node IDs and diagnostic values |

During an encounter the screen shows only what you act on: where you are, mother health, saved food, your traits, the goal, the next action, and the Nudge meter while poison or phages are in the dish. The journey route map appears in briefings and the pause menu. Every dialog shares one type scale (Inter, SIL OFL, bundled in `assets/fonts/`) and one button style; shortcut keys are printed on the buttons they trigger.

**Nudge** is a basic journey ability: no upgrade, food, health, or drawing cells are required. Drag a purple cyst to aim a push of up to **60 logical pixels**; the arrow previews the bounded destination. Release to let it coast and tumble through the water for 1.25 seconds. It then keeps drifting around its new location. The shared cooldown is **six seconds**, shown in the Nudge meter at the lower right. Right-click or Escape cancels for free, and tiny accidental drags spend nothing. Ready blue cells retain drawing priority; digesting cells cannot block a visible cyst. The first mixed pocket identifies a cyst to try, and H explains the control. Click mode also supports click-cyst, click-destination or Enter. The rim prevents ejecting poison from the dish.

The native Nudge fixture passed **42 checks**, including a contaminated meal made safe and captured at two segments/second, actual pointer input, cooldown, click controls, cancellation, overlaps, permanent displacement with continuing drift, pause, reduced motion, in-flight save/resume, and older saves. The affected existing fixtures also passed: journey/save rules **83**, input integration **35**, onboarding **46**, and native guidance/help **44**. [Aim preview](artifacts/nudge-aim-large.png) · [Water response](artifacts/nudge-ripple.png) · [Clean meal](artifacts/nudge-clean-meal.png). Reproduce with `godot --path . --script res://tests/cyst_nudge.gd`; its rule checks also run headlessly in `./test.sh`.

Selected cells hold still. A dashed closing bond previews a valid polygon; a solid membrane is closed. Enclosed nuclei receive a marker. Both nuclei of a linked creature must fit inside. The preview and release share one boundary-inclusive predicate. Empty loops still spend cells. Recovering cells and their temporary bonds disappear into the fused organism, then become selectable when they finish returning. Reduced motion keeps them at their anchors with dim interiors and a dormancy bar.

Connect any ready blue cells, regardless of distance or the original neighbor layout. In a journey, links longer than 130 pixels warm toward amber and add up to 2.4 seconds of cell recovery after capture; the preview shows the exact added time. A capture must be a closed, non-crossing polygon of 3–8 distinct cells (up to 10 with Elastic Membranes), with **the mother outside**. A loop enclosing her or cutting her body turns warm amber, highlights her outline, and explains how to backtrack or cancel. Preview and atomic capture use the same disk-overlap check. Rejection costs no health, food, recovery, or absorption effect. Recovering and parasite-blocked cells stay unavailable. Available next cells highlight while drawing, and the hovered destination shows a preview line. No background connection web implies artificial routes. An unfinished release explains how to close the loop.

Focused opening check: `godot --path . --script res://tests/onboarding.gd` exercises real input, both practice captures, recovery, save migration, costs, upgrade progression, and connection feedback. It writes native screenshots to `artifacts/onboarding-*.png` and also runs headlessly in `test.sh`.

The next-action guidance in the right column follows the live encounter and your current loop: gather missing food, rescue spores, clear poison, intercept a hunter, break a linked shield, or release a valid attack. Boss annotations point to the actual capture center and show the opening countdown. **Hits left** is boss health; **attacks charged** is the number of three-charge attacks you can afford. **Food saved** is spent between encounters, not during combat. Hover an acquired upgrade to read its effect and tradeoff. A closed loop's preview shows its food gain and health cost before release.

The capture preview sits below the lens, leaving every lower cell visible; the journey tracker occupies the unused top margin. It names the strongest food-producing evolution, includes any other upgrade bonuses, and shows the actual recovery duration for that loop. The same bonus ledger calculates the food award and the post-capture message, so “includes” never adds an apparent second award. Native review passed **44 clarity checks** and **33 journey checks**, including the first real capture, evolution, bosses, retry, victory, and larger text. [Native preview](artifacts/journey-evolution-payoff-preview.png) · [Absorption feedback](artifacts/journey-evolution-payoff-capture.png) · [Larger-text preview](artifacts/journey-evolution-payoff-preview-large.png).

Urgent guidance states the consequence: an approaching hunter eats a health core, a spore escapes, a divider becomes two hunters, or a boss closes. A highlighted hunter gets a faint path to the mother and an estimated contact countdown (linked nuclei sway, so the estimate is marked `~`). These cues do not increase movement speeds or shorten the existing windows. Stolen food becomes an explicit recovery target.

The Conjoined finale escalates spatially with each lost layer: its hearts spread farther apart, but the last layer retains an eight-second close-pair plateau. Young paired hunters hatch near the fight, spend three seconds visibly emerging, then approach Mother directly. The first pair has roughly an 18–35 second response window. Pattern and save/resume checks passed (36 assertions). With the new mother exclusion rule, three sampled five-trait builds (Nimble, Feast, Hunter) completed the finale at two segments/second with 2.5 seconds of deliberation and imperfect pointer aim, in **92.20–109.33 seconds**. All six focused pacing checks passed. These are feasibility proxies, not human difficulty ratings. [Detailed results](artifacts/finale-pacing.json).

### Living ecosystem expansion

The opening uses a gentle 48-second cycle: twelve seconds of quiet feeding, eight seconds of advance warning, fourteen seconds of activity, then recovery. After round four, cycles shorten gradually to 36 seconds, with at least six seconds of recovery and the full eight-second warning throughout. Incoming hunters and specialist organisms disturb their actual arrival sites. Quiet feeding currents replenish food and, during rescue encounters, missing rescue opportunities. Existing saves finish their current encounter at its original pace; the next encounter adopts the new curve.

Drifters and Twinspores can pursue nearby food or spores before approaching Mother. Their six-second meals remain interruptible: capture the prey, the hunter, or both. A fed hunter slows for eight seconds, and capturing it recovers swallowed food. Algae gently congregate within their bloom; delicate life scatters around hunters and capture disturbances. Pursuit, stolen food, and partially eaten prey survive save/resume. Shellbacks and dividers retain their direct pressure on Mother.

Optional feats reward a clean rescue alongside a nearby hunter, four food from two different blooms in one polygon, and finishing an encounter without poison damage. Each feat grants 150 points and one food for upgrades, subject to the normal storage capacity, once per encounter. It never advances the required food objective. Exceptional captures have a subtle pearlescent membrane and a generated musical flourish; the opening lesson has no optional rewards to learn.

Stillwater, Glassgarden, and Blue Deep now use three distinct photographic microscopy plates, biome-specific ambient populations, and different water movements. Assets and exact new prompts are in `assets/biomes/`; they were generated with the built-in imagegen tool. Drawing pushes aside fine debris, absorption curls background organisms inward, and separation releases the water. A nearby hunter produces a directional protective contraction and warm pulse in Mother without moving her damage sites. Pause and reduced-motion settings apply to these effects.

The second-generation plates give Stillwater fine organic sediment and algae, Glassgarden etched silica diatoms in slate-blue water, and Blue Deep translucent plankton membranes in indigo water. Square framing retains the specimens near the dish edge. Settled photographic material is now almost stationary, with softened local contrast and lifted shadows. Individual suspended organisms follow seeded, smoothly connected wandering paths: ciliates face their direction of travel and flex, amoebae extend uneven lobes, and silica bodies tumble gently. Their focal depth changes softness, translucency, and apparent size together. Full detail now carries 40–46 small background organisms (still at most 44 pixels including transparent margins). Their independent routes have shorter travel intervals, and fine suspended particles drift faster. Balanced and Light retain their 18/10 specimen and 160/80 particle budgets. [Exact generation prompts and sources](assets/biomes/v2-provenance.json) · [Native appearance previews](artifacts/visual-overhaul-v2/manifest.json).

Transparent ambient tissue refracts the actual rendered water behind it. Brighter water midtones and compressed foreground highlights reduce the separation between the sediment and living tissue; suspended specimens are visible through this shared water tint. Sediment, suspended life, playable tissue, and fused captures share broad transmitted lighting. Pause freezes the presentation clock; reduced motion fixes the whole composition. The strengthened isolated-background fixture passed 8 checks: median specimen displacement is 14.6 pixels over four seconds, and moving pixels exceed both an absolute visibility threshold and the settled plate's lighting drift. The affected native motion and appearance fixtures passed 23 and 91 checks; the visual-state fixture passed 67. The legacy campaign fixture now passes 29 headless checks, including victory and replay: its scripted boss captures choose enclosing polygons from the current moving cells instead of reusing obsolete fixed-node routes. [Matched native comparison: eight seconds before, then eight seconds after, at normal speed](artifacts/pond-motion-contrast-comparison.mp4). `tests/pond_cohesion_reel.gd` captures 240 native PNG frames in `artifacts/pond-cohesion-frames/`, without reading or writing the player's journey. Encode them at 30 fps; explicit rendering keeps capture reliable when the window is covered.

The current Petriverse score uses the three user-supplied tracks: track1 for Stillwater and the title screen, track2 for Glassgarden, and track3 for Blue Deep. The full tracks have matched playback loudness and five-second loop/world crossfades. The original ElevenLabs water ambience, activity texture and interaction cues remain; fixed-key tension and colony music layers are silent so they cannot clash with the supplied compositions. All audio is bundled for offline play. Source hashes and mastering details are in `assets/audio/provided-scores-provenance.json`; the older generated assets retain their own provenance.

Focused checks: `tests/encounter_rhythm.gd`, `tests/food_web.gd`, `tests/journey_mastery.gd`, and `tests/audio.gd -- --require-assets`. Native integration: `tests/ecosystem_expansion.gd`, `tests/motion_pixels.gd`, and `tests/mission_appearance.gd`. Mature evolution combinations now strengthen the colony silhouette and retain secondary anatomy; native coverage is in `tests/evolution_visuals.gd`. Distinct boss patterns are now implemented and taught by earlier organisms; see below.

### Habitat events

Three encounters contain forecast ecological moments. The nursery’s drifting bloom supplies six real food bodies and a following grazer. The turning tide’s sleeping garden offers 22 seconds of clean feeding before cysts emerge at three marked sites. In the deep current, a large harmless specimen passes below gameplay and gently separates food from poison. Eight-second advance notices and live instructions explain these opportunities. Event state persists through saving; reduced motion removes the giant’s sweep. Existing saves without event state do not gain surprise arrivals.

Rules and native scenes passed 15 and 12 checks (`tests/habitat_events.gd`, `tests/habitat_events_visual.gd`). The larger-text garden preview was inspected and its instruction spacing corrected. Rare helper checks passed 12 rules and 11 native checks; the expanded arrival fixture passed 135 checks.

### Distinct boss patterns

The Bellwether inhales for eight seconds, drawing nearby green food and purple cysts inward at a gentle bounded speed, then opens for sixteen seconds. Its membrane contracts with the actual current and nearby background debris responds. A one-hit Bell bud in the preceding nursery encounter teaches the same breathing pattern without charge requirements. Neither has shield organisms.

The Glass Regent has two real shield organisms. Capturing one starts an eighteen-second regrowth deadline; capturing both together avoids that race. Break the pair to expose its nucleus for fourteen seconds. The preceding glass-cradle encounter teaches this exact link/regrowth behavior around a rescue pearl. Protected pearls cannot be captured or eaten by hunters until their shields are removed. Once exposed, rescue its pearl immediately for one life, or protect it for twelve seconds while it unfolds and hatches into two real young spores. Both young get forty seconds to be rescued. Hunters can eat an exposed cradle; waiting is a choice with a real risk. Rescued hatchlings retain that origin in their home-pond history. Hatching state survives pause and exact resume; older already-open cradles retain their previous behavior. The focused story passed 18 rules and 13 native checks, including real two-segments-per-second shield and rescue captures (`tests/cradle_story.gd`, `tests/cradle_story_visual.gd`).

The Conjoined's two exposed hearts drift apart and reunite in a twenty-four-second cycle. A broad membrane can catch them while apart; waiting creates a tighter opportunity. Both hearts must fit in the same polygon, as earlier Twinspores teach. A nonfatal hit releases a young paired hunter, creating a protection-versus-recharge decision. Each boss still takes three charged hits and reforms for four seconds after damage. Saves retain breathing phases, partial shield deadlines, heart geometry, and health. Previous shield-based boss saves migrate without resetting progress.

Focused rules: `tests/boss_patterns.gd`. Native scenes and actual two-segments-per-second mouse captures: `tests/boss_patterns_visual.gd`. Full journey feasibility uses stale observations, 2.5 seconds of thinking, imperfect aim, and at most eight reviewed local options, including free polygons available to the player. It is a timing simulation, not a human difficulty study.

### Rare discoveries and the home pond

The field journal now has **41 entries**, including **twelve new rare forms** with original transparent microscopy art. Stillwater can host a Chalice grazer, Sundial alga, Glasswing spore, or Trident hunter; Glassgarden a Crown rotifer, Amber nautilus, Veil parasite, or Thistle capsule; and the Blue Deep a Ribbon divider, Comet spore, Prism hunter, or Sieve alga. Their silhouettes differ, while colors and capture rules retain their familiar food, poison, rescue, thief, parasite, and hunter roles.

Every new fifteen-encounter journey selects **one of these four forms per biome**, prioritizing entries missing from the persistent journal. A fresh collector therefore needs at least **four journeys** to encounter all twelve. The selected creature emerges eight seconds into a seeded generated encounter after its family has been introduced, waiting if the relevant threat cap is full. Its discovery notice explains what to do. Selection uses an independent random stream, and saves/retries retain the roster and arrival state. Existing in-progress saves retain their current ecology; start a new journey for this discovery layer. Rescued Glasswing and Comet spores retain their exact identity as rare home-pond residents.

Assets were generated individually with the built-in image generator; source paths and complete prompts are in [expedition-prompts.json](assets/organisms/expedition-prompts.json). The isolated native discovery fixture passed **189 checks**, covering four successive discovery rosters, actual scheduled arrivals, unseen preference, disk persistence, retries, legacy saves, capture rules, and journal pagination. Run `godot --path . --script res://tests/expedition_creatures.gd`; it is also included in `test.sh`.

Each biome has its own rare visitor. Stillwater’s Moonlace opens lace petals and releases two real food organisms every 18 seconds after its first opening. Glassgarden’s Glass Harp gently draws nearby food inward and pushes cysts outward. Blue Deep’s Glowdrift slows nearby ordinary hunters while its spiral chambers shine, then rests between openings. Each stays for 72 seconds. Leave it to help the ecosystem, or rescue its central pearl with an ordinary polygon to bring that individual home. Capture ends its assistance in the dish. Position, life cycle and helper effects survive pause and save/resume; watching alone never invents a rescued resident.

Every actually captured spore records a unique journey/stage/entity identity, its exact form, and its encounter of origin. The profile merges these records idempotently; returning to a checkpoint or loading a save cannot duplicate residents. Older saves begin collecting individual residents from future rescues. New journeys preserve the home pond. Return home to watch these organisms drift and breathe independently, click a resident to recall its origin, or continue the exact paused journey. Large collections have pages of 36 residents. Reduced motion keeps the habitat still.

The three rare assets were generated with the built-in imagegen tool. Exact prompts and sources are in `assets/organisms/moonlace-provenance.json` and `assets/organisms/rare-expansion-prompts.json`. Native verification uses actual mouse captures to populate the habitat, rather than fabricated profile entries: `tests/home_pond_visual.gd`. Save, director, pause, food release, and identity coverage is in `tests/home_pond.gd`.

Residents now grow over four newly completed encounters. Re-observing, reloading, or retrying an already completed encounter cannot farm growth. Individuals have stable curious, sociable, or quiet habits; rare residents retain their petal cycle. Three different rescued forms attract a small decorative algae garden. The home Mother remembers the anatomy of the most recently completed encounter. None of these changes grant combat stats to a new journey.

Victory presents the actual evolved Mother and up to twelve recent residents in a living tableau, retaining her surviving health cores. It retires combat instructions, records the journey's rescues and routes, and names how many species remain undiscovered. Return to the home pond to see the full paginated collection. The tableau respects reduced motion and never advances simulation time.

### Personal residents and earned gardens

Click a resident, then **Give it a name**. Enter saves, Escape cancels, and an empty name restores its species name. Names stay with the individual across retries and new journeys. Each visible resident has a real companion; young residents prefer a fully grown guide. They periodically drift toward one another and return to independent exploration. The selected companion gets a soft marker. These visits respect reduced motion and stop while editing a name.

Optional feats also grow lasting, decorative gardens: a clean spore-and-hunter rescue earns a **Pearl nursery**, a clean four-food capture spanning two blooms earns a **Fern meadow**, and an encounter without poison damage earns a **Glass garden**. The home pond explains the next unearned garden. These decorations never count as rescued residents or grant combat stats. Save/retry identities prevent duplicate rewards. Focused verification: `tests/pond_memories.gd` (18 checks) and `tests/pond_memories_visual.gd` (13 native checks), including real mouse captures, naming, cancellation, disk reload, long names and reduced motion.

### Choose a habitat

The first two encounters and all bosses retain their authored route. Before other encounters, choose one of two destinations in the current biome. The food-rich route supplies five food per bloom and ordinary hunter arrivals. The sheltered route supplies four food per bloom, schedules hunters on alternate waves, and guarantees that biome’s rare visitor at 36 seconds. Specialists, objective targets, drawing speeds, and encounter deadlines stay the same. Quiet water has a cooler microscopy grade and denser sediment.

Selecting a destination opens the encounter briefing; it does not start the clock. Enter chooses the food-rich route, then a second Enter begins the encounter. Choices persist through save/resume and retries. Existing saved encounters continue with their original supply. The travelled route appears on the journey line.

Focused verification: `tests/journey_habitats.gd` covers food, arrivals, visitor, migration, idempotent restoration, and retries. `tests/habitats_visual.gd` exercises native mouse and keyboard choices, larger text, and live appearance. The complete sheltered journey was feasible in one sampled run at two segments per second, with 2.5 seconds of thinking, six-pixel aim error, and no retries; this is timing evidence, not a human win-rate claim. [Sheltered journey report](artifacts/journey-living-ecosystem-feasibility-local-2.0-refuge.json).

### Creature forms and emergence

The journal has **29 entries**, including the breathing Bell bud, Moonlace, Glass Harp and Glowdrift, and twelve new transparent specimen sprites: Fern desmid, Spiral alga, Crown cyst, Bramble cyst, Snow spore, Sail spore, Needle hunter, Ribbon hunter, Lantern grazer, Comb grazer, Lace parasite, and Hourglass divider. Journal pages use four generously spaced entries, with habitat and encounter hints for undiscovered organisms. Rare-entry hints explain how the sheltered route guarantees a visitor. The journal’s native navigation, pause and larger-text presentation passed 10 focused checks (`tests/discovery_journal.gd`). Ordinary forms enter the spawn pools progressively from encounter 2 onward. Green remains food, purple remains poison, pearl-white remains rescue, and the threat families retain their established capture rules. These are visual forms of existing roles, not twelve additional mechanics.

Appearance uses a separate deterministic random stream and does not consume gameplay randomness. Form identity survives save/resume, absorption, mother attacks, and division. Existing saves retain their original specimens; subsequent spawns can use the new forms. The original assets are retained. The built-in image generator produced the new sprites; prompts, source paths, and nucleus registration are in `assets/organisms/expansion-prompts.json`.

New organisms rise through the focal plane over about 2.2–2.6 seconds (bosses 2.8): diffuse tissue sharpens, a wet membrane unfolds from the registered nucleus, and fine living detail appears. Simulation age drives the effect, so pause freezes it and resume does not restart it. Capture geometry and timers stay unchanged. Poison retains a stronger colored silhouette throughout its arrival; reduced motion removes folding and changing focus while keeping the fade.

Focused verification: `tests/creature_arrivals.gd` exercises actual spawn diversity, texture alpha/mipmaps, nucleus registration during emergence, pause/resume, absorption identity, damage identity, journal pagination, and danger instructions. Run it natively for screenshots in `artifacts/creature-*`; it also runs headlessly.

### Drifting cells and mission appearance

Each blue cell wanders independently with its own slowly changing heading and speed, rather than sharing an orbit. In the first five seconds, cells travel 8–49 logical pixels (median 30), in different radial and angular directions. Smooth steering, gentle neighbor avoidance, and broad territories let the layout deform within a stable movement scaffold. Geometry guards prevent overlapping targets, collapsed food pockets, and contact with the mother or dish rim. The internal scaffold does not restrict player connections. Speed is capped at 12 pixels/second.

Only selected and absorbing cells stop. Every unused cell continues wandering while you draw or digest a meal. Capturing cells return to their exact saved positions, then resume their own motion. Fixed 60 Hz simulation steps preserve motion across render rates. Saves retain each cell's velocity, territory, and motion time; older pocket-drift and orbit saves begin wandering from their saved positions without snapping to the original layout.

Every journey encounter has a seeded visual recipe in `scripts/mission_appearance.gd`: water tint, lens lighting, sediment orientation and contrast, ambient populations and placement, and subtle oval, fluted, or scalloped player membranes. Detailed textures remain the source of the tissue and sediment. Recipes use their own random stream, remain stable throughout an encounter and save/resume, and change with new missions or journey seeds. Green food, purple poison, and cool blue/cyan controllable cells keep their roles. Background life stays small and behind the playable tissue, with 40–46 specimens at Full detail and the original lower-detail budgets. Pause, reduced motion, and visual detail settings still apply.

The motion overhaul gives tissue travelling contractions, asymmetric breathing, separate internal currents, tapered cilia strokes, and wet membrane highlights. Cells yield slightly along their own drift direction while their selectable centers stay exact. The independent board movement remains unchanged. Evolution unfurls new sensory hairs without relocating the existing hairs, and a restrained wave of light follows growing tissue.

Capturing cells now gather and return with smooth acceleration and slight individual timing, retaining the exact recovery deadline. One continuous body digests the prey through soft cellular erosion, then separates. Nutrients and damaged organelles travel along fine fluid trails. Capture and injury events subtly refract the nearby photographic water; at most four disturbances are rendered, derived from existing event ages. Background specimens remain small, with uneven tumbling, depth changes, and slow transmitted light. Cilia and internal trails are batched to keep the added detail inexpensive.

[Watch the motion overhaul](artifacts/motion-overhaul-preview.mp4). The review reel's camera close-ups are only for inspection; normal gameplay keeps its stable camera. `tests/motion_pixels.gd` verifies **8 native pixel checks**, including visible tissue motion, fully frozen pause/reduced-motion frames, and actual capture-driven water refraction. The affected fixtures pass: visual motion **67**, clot recovery **24**, Mother damage **34**, creature arrivals **117 native**, mission appearance **84**, and evolution **36 native**. The same native eight-second comparison recorded **3.03 seconds of CPU render time**, versus **3.35 seconds before the overhaul**; this is a fixture comparison, not an in-game frame-rate guarantee.

`tests/mission_appearance.gd` checks deterministic appearance, native shader integration, gameplay independence, capture and absorption, detail levels, pause/reduced motion, and migration from older drift saves. Native runs save six mission previews and an absorption frame to `artifacts/mission-appearance-*.png`.

The drift fixture verifies independent directions and travel, minimum separation, mother clearance, and triangle validity over five simulated minutes in each of the three biomes, including long holds of separate cell groups. [12-second native motion preview](artifacts/independent-cells-preview.mp4).

With independent wandering, the bounded actual-pointer harness completed one full twelve-encounter journey at **2 segments/s**, including thinking time, imperfect aim, and one missed gesture. This is a feasibility sample, not a human win-rate estimate: [independent-wandering report](artifacts/journey-wandering-feasibility-local-2.0.json). The earlier [circulating-current report](artifacts/journey-circulating-feasibility-local-2.0.json) remains historical evidence for the superseded orbiting version.

## The connected journey

`scripts/journey_route.gd` composes **15 encounters**, five per biome. Twelve authored milestones teach mechanics and conclude each biome with its boss. Three seeded special visits vary feeding, rescue, defense, purification, and sector goals using mechanics already introduced. Each recipe also chooses a creature-family mix, hunter type, direction through the food pockets, ecological event and event timing. Independent per-encounter visual seeds vary the dish within its biome. Habitat choices remain available.

The entire route is generated from the journey seed and serialized in the save, not regenerated on resume. Retrying retains the same recipe. Each encounter has its own habitat history, home-pond growth credit, and mastery rewards. New journeys generate a new route; old saves continue their twelve- or thirty-encounter journey. Use **New journey** after relaunching for the focused format.

Evolution choices appear at authored milestones, with at most **six evolutions** per new colony. Generated encounters offer repair when Mother is wounded; on the original long route in Blue Deep, repair needs at least two wounded cores. Otherwise travel continues automatically. This retains distinct builds instead of accumulating every mutation during a long journey. There is no minimum-time gate or forced wait to extend a completed objective.

In Glassgarden and later, a generated **feeding** visit requires two real hunter captures as well as its food goal. The briefing and live HUD show both requirements. A colony carrying at least four mutations draws faster hunters from Glassgarden onward; with five or more, warned hunter arrivals overlap the bloom sooner. The first biome and lightly evolved colonies retain their previous hunter pace. These rules also apply to an older journey when its next encounter begins, without replacing its saved route. [Matched saved-encounter pressure check](artifacts/challenge-pressure-2026-10-10.md).

The original **thirty-encounter** route has more repair and Guard opportunities than the focused route. In its Blue Deep, stored food adds up to 2.4 pixels/second to hunter pursuit when the colony has five or more mutations. Alternating late non-boss visits end with a warned hunter wave after their normal goals. Defense visits use an armored Shellback and other hunters; rescue visits bring a linked Twinspore. The food-rich route draws a larger wave. Completing the first goals within 140 seconds draws an extra, faster hunter. Final hunters must be captured; an escaped one is replaced after another warning. A wave triggered near the encounter limit gets at least 60 seconds to resolve. A Guard that blocks a hunter rests for the following two encounters; other ready Guards still work. Repair restores two cores for six food, but in the Blue Deep it requires at least two wounded cores and cannot be used after consecutive encounters. The route screen, briefing, Guard status, and repair choice explain these rules. Existing saves keep their health, food, traits, route, and current encounter. [Later-route balance check](artifacts/challenge-pressure-followup-2026-10-10.md).

Every legal membrane can still close. Links longer than 130 pixels tint warm and add up to 2.4 seconds to the cells' recovery; the live preview states the exact added time. Clean captures of five or more bodies earn a **Grand sweep** score bonus, seven or more a **Living constellation** bonus, and a clean meal with at least two foods and a hunter earns a **Balanced harvest** bonus. The in-dish ripple and chord acknowledge these captures, and the final journey screen shows the score.

The current native route fixture passes **177 checks**, including twelve distinct seeds, teaching order, actual generated arrivals, the growth choice, long-link preview, graded capture feedback, on-disk save/resume, deterministic retry, separate home-pond rewards, old-save compatibility, and final progression. The native mother-boundary fixture passes **19 checks**, including both polygon windings, edges crossing her body, backtracking, click capture, preview/commit agreement, and zero-penalty rejection. Existing focused checks pass: base rules **76**, free polygons **11**, onboarding **46**, mastery **14**, and pond memories **18**. [Growth choice](artifacts/mother-growth-choice.png) · [Long-link preview](artifacts/long-link-preview.png) · [Grand sweep feedback](artifacts/grand-sweep-feedback.png).

Two earlier full thirty-encounter simulations, seeds 73 and 110, completed without retries at **2 segments/second**, 2.5 seconds of deliberation per plan and six-pixel aim error, in **44.33 and 48.46 minutes** of active simulation. Both finished with four health cores; there were 14 and 21 hunter contacts respectively. These slow-input samples verify feasibility with the mother restriction, not the target duration for every human. They do not use Nudge. Menus and pauses are excluded. [Seed 73](artifacts/journey-living-ecosystem-feasibility-local-2.0-long.json) · [Seed 110](artifacts/journey-living-ecosystem-feasibility-local-2.0-long-seed110.json).

An earlier practiced-input sample of seed 73 completed all thirty encounters without retries in **34.17 minutes**, at **3 segments/second** with 1.5 seconds of deliberation and the same six-pixel aim error. This is within the requested target, but is still a scripted sample rather than a promise of human completion time. [Practiced-input report](artifacts/journey-living-ecosystem-feasibility-local-3.0-long-think1.5.json).

Reproduce: `godot --headless --path . --script res://tests/journey_feasibility.gd -- --long --seed=73 --rate=2.0`. `--think=1.5 --rate=3.0` samples more practiced input while remaining below the four-segment/second maximum. Native `tests/procedural_journey.gd` and `tests/mother_boundary.gd` capture the screenshots; both are also included in `test.sh`.

| Dish | Encounters | Environmental rule | Finale |
| --- | --- | --- | --- |
| Stillwater | First nourishment; rescue pearl spores; defend the nursery | Quiet water and the familiar open layout | Bellwether: inhaling currents gather food and poison; strike during its 16-second exhale |
| Glassgarden | Neutralize toxins; feed from three sectors; rescue glass cradles | Narrower, rotated colony; tide reverses every 18 seconds | Glass Regent: break two shields together or finish the second within 18 seconds; strike during the 14-second opening |
| Blue Deep | Defend shared shelter; clean a current; rescue the next generation | Wider, flatter colony and a slowly turning current; linked predators | Conjoined: catch both drifting hearts in one loop; each nonfatal hit releases a paired hunter |

Authored ordinary encounters allow up to three minutes (three and a half in the deep); generated missions allow five and a half to six and a half minutes, ending as soon as their objectives are complete. Boss encounters allow four minutes, or four and a half for the finale. Each boss has three layers; a strike spends three food charge. Up to six charge can be held. Food collected in the same membrane can replenish the charge after a strike. Bosses cannot be damaged without charge.

Purification encounters have separable outer toxin pockets. A membrane containing **only cysts** neutralizes them safely; adding food or another organism makes it a normal risky meal. Rescue encounters require both nourishment and captured pearl spores. Defense encounters count captured threats: hunters, food thieves, and parasites. New threats arrive with recurring blooms, so an early miss does not permanently prevent completion.

At an evolution milestone, choose one mutation for **6 food plus 2 per mutation already owned** (maximum 24), regrow two organelles and travel for **6 food**, or keep your stores and continue. Between generated missions, or after filling all six evolution slots, choose repair or travel. Storage holds 30 food; excess food still advances objectives and earns score. Older saves with more than 30 retain that surplus but cannot add more until below capacity. Mutations are permanent for that journey. The next encounter starts with fresh ready cells and a new local timer; health and evolution remain. A failed encounter can be retried from its entry checkpoint, with at least three healthy organelles. Earlier encounters do not need to be replayed.

### A competing pond ecology

After the quiet first encounter, each wave brings a short burst of overlapping opportunities, followed by breathing room. Rounds 2–4 retain their 48-second cycles; rounds 5–8 use 46, 44, 42, and 42 seconds; rounds 9–12 use 40, 38, 36, and 36 seconds. Quiet preparation decreases from twelve to ten to eight seconds across the three biomes, while warnings always last eight seconds and recovery never falls below six seconds. Hunters begin at 5.4 pixels/second; evolved colonies draw faster ones in later biomes. Independent quiet food replenishment remains every 48 seconds.

From round 6, every other ordinary wave adds a second hunter approaching from another side, six seconds after the first hunter. Round 11 uses that pattern on every wave. Each arrival has its own full eight-second marker. Boss encounters omit this additional hunter so their own patterns remain the focus. Sheltered routes retain single hunters on alternate waves, and all scheduled hunters respect the existing population cap. Delaying intervention lets thieves carry food away, parasites occupy cells, and dividers produce two hunters; these deadlines and capture windows have not been shortened.

`tests/encounter_rhythm.gd` checks real wave frequency, staggered warning sites, population caps, pause, exact save/resume, and legacy pacing. `tests/journey_ecology.gd` covers the underlying consequences and boss windows. Difficulty comes from target priority, shared cells, and recovery rather than increased drawing or movement speed.

The progressive-pacing pass passed **45 rhythm checks** and **34 ecology checks**. The latest complete journey sample, including the stronger finale, passed all twelve encounters at **2 segments/second**, with 2.5 seconds of thinking, six-pixel aim error, and no retries. This verifies one feasible route through the harder progression, not human win rates or enjoyment. [Current progressive-pacing results](artifacts/journey-living-ecosystem-feasibility-local-2.0.json). The three focused finale samples above separately exercise Nimble, Feast, and Hunter builds.

- **Fan grazer:** follows green food, eats one desmid after four seconds beside it, and leaves with up to three. Catch it to recover what it stole. Its fan silhouette and stomach count make the opportunity visible.
- **Coral parasite:** extends a pink tether and blocks one cell after seven seconds in position. Its body always occupies another capture triangle that does not require the blocked cell. It cannot block a cell while you are using it in a gesture.
- **Divider:** constricts and divides after twenty seconds into two independently capturable hunters. Catch it early for a simple capture, or accept two approaching targets. Offspring do not split again.
- **Pearl spore:** waits in a clear neighboring pocket for 27 seconds. Its countdown and the live instruction show the rescue deadline. Food and rescue routes share a cell, so the order matters.
- **Regrowing shields:** real organisms joined to the Regent or a glass cradle by pale strands. Capture both in one polygon, or the second within 18 seconds of the first; otherwise the pair regrows. Regent opens for 14 seconds, while a freed cradle pearl stays rescuable. Each Regent hit spends three charge and starts four seconds of reformation. Waiting alone never breaks shields.

### Evolution

| Mutation | Change to play |
| --- | --- |
| Rapid Fission | Clean 3–4-cell meals give +1 food and recover in two seconds |
| Elastic Membranes | 6+ cell loops give double desmid food; up to ten cells; all returns take 0.6s longer |
| Enzyme Sacs | Six-cell-or-larger loops deal two ordinary damage; 1.2s slower return |
| Feeding Frenzy | Three absorbed bodies immediately free the starting cell |
| Osmotic Lure | Draw nearby desmids toward a used membrane to prepare the next meal |
| Residual Membrane | A four-second membrane slows crossing hunters by 40% for one second |
| Filter Veil | First cyst per meal is harmless; all returns take 1.2s longer |
| Feast Chambers | Four or more desmids give two extra food; wide loops return one second later |
| Delicate Grazer | One or two desmids give one extra food when no poison is taken |
| Symbiosis | Each captured threat gives two food; cracking armor alone gives none |
| Bitter Catalyst | Swallowed cysts give two food each; unfiltered poison still hurts |
| Living Nursery | Every twelve clean desmids regrow an organelle; tally resets per encounter |

The first evolution offers **Nimble** (extra food and fast recovery from clean small meals) and **Feast** (double desmid food from wide membranes). **Hunter** (food from captured threats) enters the pool after the defense lesson. Later offers favor two available synergies while retaining a different option; combinations remain open.

Evolution changes the Mother and her cells for the current journey. The cells retain their evolving silhouettes and trait anatomy. The Mother uses continuous painted tissue for her first feeding specialization: a division network for Nimble, flowing inner folds for Feast, or a luminous exchange network for Hunter. She begins with three golden health organelles and grows to four, five, six, then seven at story stages 3, 5, 9, and 11. Each new organelle increases her maximum health and arrives healthy; damage can target only the organelles she has grown. At stages 3 and 9, choose Guard (intercept one hunter per encounter, with a two-encounter recovery on the original thirty-encounter route) or Feeder (one extra food from clean four-food meals). A wounded organelle suspends its ability until repaired. The choice and spent guard charge survive save/resume. Anatomy is reconstructed from saved mutations, including older saves and starting-colony traits.

The Mother has five coordinated artwork stages for each specialization, with new organelles and internal tissue visible in the evolution close-up. Her membrane remains continuous; the former oversized shape warps and attached buds are removed from her renderer. Cells still show their own buds and folds. Long-link recovery and capture score now reward thoughtful geometry. Focused checks cover evolution, journey rules, and mother damage.

Upgrade cards preview the evolved tissue. After buying a trait, a skippable 3.2-second close-up shows the growth and explains its gameplay effect. The next encounter stays paused; Continue, Enter, or Escape returns to its briefing. Reduced motion shows the finished anatomy immediately. [Growth preview](artifacts/evolution-growth-preview.mp4) · [Nimble anatomy](artifacts/evolution-nimble.png) · [Feast anatomy](artifacts/evolution-feast.png) · [Hunter anatomy](artifacts/evolution-hunter.png)

The Wanderer starts without mutations. Completing Stillwater unlocks the Weaver, which starts with Rapid Fission. Completing Glassgarden unlocks the Symbiont, which starts with Symbiosis. These unlocks and the 29-entry, paginated species journal persist between journeys; no permanent stat grind is needed to win.

### Saving

`user://journey.cfg` stores versioned simulation snapshots every eight seconds and at progression transitions, plus the encounter-entry retry checkpoint. Save & return home and closing the game also save. Continue restores positions, current time, health, mutations, charge, recovery, in-flight absorption, boss layers/windows, random state, blocked cells, stolen food, pending blooms, and division progress. Version-one saves migrate without losing boss hits or stored food. The game pauses when restoring an active encounter. Uncommitted pointer gestures are cancelled.

`user://journey-profile.cfg` stores discoveries, unlocked colonies, completed journey seeds, victories, and the best journey score. A resumed victory is counted once. Existing legacy records and sound/comfort preferences remain separate. On macOS these files live in `~/Library/Application Support/Godot/app_userdata/MICROVERSE/`.

### Journey verification

- `tests/evolution_visuals.gd`: **35 headless checks** covering actual upgrade input and cost, progressive cell growth, Mother's artwork stages, save reconstruction, skip controls, reduced motion, large text, Mother damage, fused absorption, and pause.
- `tests/journey_rules.gd`: **108 checks** covering all twelve stage gates, organelle growth and roles, food/evolution/repair carry-over, toxin and rescue rules, charged bosses, save migration and resume, retries, and persistent unlocks.
- `tests/journey_mutations.gd`: **33 checks** covering the remaining mutation effects, actual ten-cell capture, residual crossing, lure displacement, mid-boss save/resume, and starting-colony traits.
- `tests/journey_visual.gd`: **33 native checks** covering mouse/keyboard flow, colony screen, evolution, distinct rendered boss anatomy, journal, resume, retry, large text, and the final result. Screenshots are saved under `artifacts/journey-*.png`.
- `tests/journey_clarity.gd`: **38 native checks** (25 without screenshots) for boss countdowns, protected/uncharged capture feedback, poison priority, contextual goals, and paused help input; includes standard and larger-text screenshots.
- `tests/journey_ecology.gd`: **34 checks** for food theft and recovery, cell blocking and alternate captures, bounded division, player-created boss openings, old-save migration, shared food/rescue routes, resource capacity, repair costs, and build offers.
- `tests/ecology_visual.gd`: **18 native checks**; renders the distinct new bacteria, tether and division cues, paginated journal, large text, creature briefing, and rescue deadline in the native window.
- `tests/journey_feasibility.gd`: actual swept-pointer drawing with six-pixel aim error, 2.5 seconds of thinking, and a release delay. `--build=fission`, `--build=elastic`, or `--build=symbiosis` selects a first upgrade and favors its supporting mutations; `--growth=guard` or `--growth=feeder` chooses the organelle role, and `--careful` rejects previews showing poison. Three seed-101 Guard builds completed the focused fifteen-encounter journey. Two Feeder paths lost at encounters eight and nine; the latter rejected poison shown in previews. [Synthetic player experience report](artifacts/player-experience-simulation-2026-10-10.md) records the outcomes and limits. These routes are distinct scripted strategies, not a controlled difficulty comparison or human win probabilities. Each examines at most eight local routes per decision and has no future-position oracle.

[Earlier Nimble samples](artifacts/journey-ecology-feasibility-local-2.0-fission.json) · [Earlier Feast samples](artifacts/journey-ecology-feasibility-local-2.0-elastic.json) · [Earlier Hunter samples](artifacts/journey-ecology-feasibility-local-2.0-symbiosis.json)

Before the first-build feeding rewards were added, the general conservative policy completed 4/5 journeys at 2 segments/s and 2/5 at 1.5. Those older reports remain available below as historical evidence, not validation of the latest feeding balance.

The last full regression run passed **642 checks across 16 fixtures**. After the first-build feeding rewards and sector-guidance fix, the four affected journey fixtures passed **175 checks**, including five new cases. The shared runner also checks geometry, input, drifting nodes, absorption, mother damage, legacy evolution/campaign behavior, audio, and the isolated harvest fixture. Headless audio fixtures allow a final mixer interval before shutdown so active Ogg streams release cleanly.

```sh
./test.sh
godot --path . --script res://tests/journey_visual.gd
godot --headless --path . --script res://tests/journey_feasibility.gd -- --seeds=5 --rate=1.5
```

[Earlier slow-drawing results](artifacts/journey-ecology-feasibility-local-1.5.json) · [Earlier two-segment results](artifacts/journey-ecology-feasibility-local-2.0.json) · [Colony screen](artifacts/journey-home.png) · [Evolution](artifacts/journey-evolution.png)

The Bellwether, Glass Regent, and Pearl Spore were generated with the built-in imagegen tool, using the existing Drifter as a material reference. Project-local transparent assets: [bellwether.png](assets/organisms/bellwether.png), [glass-regent.png](assets/organisms/glass-regent.png), [pearl-spore.png](assets/organisms/pearl-spore.png). The exact prompt set and generation method are in [journey-prompts.json](assets/organisms/journey-prompts.json).

The fan grazer, coral parasite, and divider were generated with the built-in imagegen tool. The final project-local transparent sprites are [grazer.png](assets/organisms/grazer.png), [parasite.png](assets/organisms/parasite.png), and [divider.png](assets/organisms/divider.png); [ecology-prompts.json](assets/organisms/ecology-prompts.json) preserves all three prompts. Each asset has registered capture-center coordinates, mipmaps, and species-specific tissue animation.

## Isolated harvest fixture (`--harvest`)

- **Goal:** 18 nourishment before 120 seconds, with at least one surviving organelle.
- **Green desmids:** one food each; rounded, three-lobed chloroplast anatomy.
- **Violet cysts:** one damage each if swallowed; spiky bodies, crossed centers, pink contaminated previews. They do not attack on contact.
- **Drifters:** familiar core attackers. Capturing them defends the mother, but supplies no food.
- **Blooms:** three mixed clusters start the dish; a new one arrives every nine seconds through second 99. Each has five food organisms and two cysts. Three food organisms begin in a clear neighboring triangle; two more sit in a contaminated pocket across its edge. The safe pocket drifts gently enough to inspect and draw. Blooms fade into a deeper focal plane during their last three seconds and depart at age 27 seconds. Missed food does not penalize health.
- **Defense:** Drifters arrive at seconds 20, 37, 54, 71 and 88, starting 278 pixels from the center at 8 pixels/second. They compete with harvesting for usable cells.
- **Commitment:** 3–8 selected cells are unavailable for three seconds after any valid loop, including an empty one. Giant outer loops enclose lethal amounts of poison at the opening.
- **Preview:** live nourishment gain, poison damage, and lethal/winning consequences use the same captured IDs as release. Organisms continue moving while drawing; the outline updates with them.
- **Resolution:** fatal damage overrides reaching the food goal in the same meal. A surviving final meal wins immediately; otherwise the timer stops at exactly 120 seconds. Pause freezes the timer, currents, and recovery.
- **Presentation:** original pond, fused digestion, offline ElevenLabs audio, comfort settings and core wounds remain. Food and poison flow into the mother along fine feeding threads; nourishment warms her central reservoir independently of her growing health organelles.
- **Replay:** R or the result button starts fresh, with rotated blooms and new motion phases. Harvest results do not overwrite campaign records.

This retained fixture is the earlier isolated test of feeding decisions. In human play, look for whether you spot a tempting meal, change a route as a gap opens, deliberately trade health for food, and want another attempt. If it still feels like tracing obvious loops, reconsider the core interaction before expanding the campaign again.

### Harvest verification

The first all-route optimizer was too generous to support a human-feasibility claim. A new bounded-search test includes actual swept-pointer input, imperfect aim, thinking after observing a route (so information can become stale), release delay, and occasional abandoned gestures. Each comparison uses the same 20 seeds, at most five-node local loops plus the obvious inner eight-cell defense ring.

| Synthetic profile | Tracing | Thinking per attempt | Original wins (24 / 90s) | Revised wins (18 / 120s) |
| --- | --- | --- | --- | --- |
| Learning, 4 local options, occasional input error | 1.5 segments/s | 3.5s | 0 / 20 | 6 / 20 |
| Deliberate, 6 local options | 2 segments/s | 2.5s | 0 / 20 | 11 / 20 |
| Practiced, 10 local options | 3 segments/s | 1.5s | 0 / 20 | 13 / 20 |

A separate optimistic control searches every short loop but keeps the same thinking, mouse tracing, and release delays. It wins 19/20 at 1.5 segments/s, 19/20 at 2, and 20/20 at 3 on the revised balance. These are **bot results, not human win probabilities**; the limited-search policies can overlook obvious routes, while the control has exact geometric perception. Together they establish reachable opportunities and the cost of search, not final difficulty or fun.

36 harvest-rule checks pass, including a stable safe food pocket in every sector after 3.5 seconds of observation and real tracing at 1.5 segments/s. The existing native harvest fixture passes 20 rendering/input checks. The earlier 267 shared regression assertions and 37 campaign visual assertions predate this balance-only change; they were not redundantly rerun.

[Comparison and method](artifacts/harvest-feasibility-comparison.json) · [Original runs](artifacts/harvest-feasibility-before.json) · [Revised runs](artifacts/harvest-feasibility-after.json) · [Optimistic control](artifacts/harvest-feasibility-after-generous.json). Original balance source snapshots are in `artifacts/feasibility-baseline/`.

Reproduce the current limited-search probe: `godot --headless --path . --script res://tests/harvest_feasibility.gd -- --label=current --seeds=20`. Add `--search=all` for the optimistic control. The reported assertions check the input speed cap; win/loss outcomes are reported separately, including unsuccessful samples.

[Live dish](artifacts/harvest-live-dish.png) · [Risk preview](artifacts/harvest-risk-preview.png) · [Feeding](artifacts/harvest-feeding.png).

Art uses the built-in image generation tool with the existing Drifter as a material reference. Final assets: [desmid.png](assets/organisms/desmid.png), [toxic-cyst.png](assets/organisms/toxic-cyst.png). Exact prompts, mode and reference are saved in [harvest-prompts.json](assets/organisms/harvest-prompts.json). Original generated outputs are preserved; the game uses project-local copies with alpha and mipmaps.

## Previous campaign (`--campaign`)

| Encounter | Composition | Purpose |
| --- | --- | --- |
| First currents | 8 Drifters in four spaced pairs | Learn to gather prey inside one membrane |
| Armored waters | 10 groups mixing all ordinary species | Plan a second capture for armor and enclose linked nuclei |
| A living weave | 12 mixed groups | Combine mutations and preserve routes through pressure |
| The Conjoined | Two joined hearts, three protection layers, recurring Drifter broods | Catch both hearts in recurring contraction windows while guarding the mother |

Each cleared ordinary encounter offers three unchosen mutations. Time stops while choosing. The dish then continues with the same integrity and score. Formations rotate between runs; mutation offers vary. The boss needs three joint pulses and reforms between them. Its capture windows recur, including if the board was exhausted when it arrived. Enzyme damage never skips boss layers. Boss death ends the run after its final digestion; remaining ordinary invaders clear.

Enemy speed is about 6.6–8 logical pixels/second. Ordinary concurrency is capped at six groups. A Twinspore is one group with two bodies. Current pacing is designed around at most four dragged segments per second, with planning and repositioning time. The legacy isolated 20-Drifter encounter remains available only to regression fixtures through `Run.new(false)`.

### Bacteria-palooza

- **Drifter:** slender ciliated swimmer, one golden nucleus; one capture.
- **Shellback:** faceted porous glass shield with a small amber heart; first capture cracks armor and stuns it, second digests it.
- **Twinspore:** two copper-rose crescent bodies with flowing flagella and a living tether; enclose both hearts together.
- **The Conjoined:** two branching violet amoeboid lobes linked by broad living tissue; slow pseudopod breathing, expanding and contracting hearts, three protective folds.

The new textures match the original microscopic material quality. The visible nuclei are registered to their logical capture positions, including off-center artwork. Saved generation prompts and references are beside the assets in `assets/organisms/`. Current species use the `*-v2.png` textures; earlier versions are retained as source iterations.

### Mutations

| Mutation | Effect |
| --- | --- |
| Rapid Fission | 3–4-cell loops have a 2-second base recovery |
| Elastic Membranes | Up to 10 vertices; all loops add 0.6 seconds recovery |
| Enzyme Sacs | Loops with 6+ cells deal two ordinary damage and add 1.2 seconds recovery |
| Feeding Frenzy | Digest 3+ bodies and immediately restore the starting cell; Twinspores count as two bodies |
| Osmotic Lure | Draw nearby ordinary enemies gently toward the loop, up to 45 pixels; displacement never captures automatically |
| Residual Membrane | A 1.5-second membrane slows crossing ordinary enemies by 40% for one second |

Short-loop base recovery is applied before additive costs. Bosses resist lure and residual slow. Mutation visuals include budding tissue, digestive vesicles, longer cilia, elastic rims, and a feeding channel to a restored starting cell.

### Score and replay

Drifter 100, Shellback 200 on death, Twinspore pair 250, boss 1,500 on death. Each additional group in one ordinary capture adds 25%, capped at 100%. There is no rapid-input streak timer. Winning adds 200 per surviving organelle. Personal best score, largest capture, runs, and victories save locally in Godot's `user://colony.cfg`; sound/comfort preferences use `user://preferences.cfg`.

## Living presentation

Photographic pond sediment moves through two optical depths. Twenty-nine small specimens swim and turn independently among 264 instanced suspension particles. These remain quieter and smaller than playable organisms. Tissue breathes, cilia stroke, granules circulate, and digestion fuses cells into one continuous body. No recovery countdown ring is used.

Shellbacks preserve their armor damage during invasion; Twinspores preserve both bodies and the tether, and each pair causes only one damage. At two or fewer integrity, a nearby hostile nucleus adds a directional warning and the caption “MOTHER UNDER THREAT.” Audio and graphics share this nucleus-based danger predicate.

Invaders reaching the mother consume the nearest intact golden organelle over a short burrowing animation. Nutrient fragments drain into the invader, leaving a persistent empty vesicle. Fatal damage completes before the result overlay. Pause freezes cosmetic time and pending effects; reduced motion removes tissue deformation, background motion, and clot travel while preserving game-state feedback.

The invasion now stages the full 2.2-second sequence: the membrane indents and parts, the attacker squeezes beneath translucent host tissue, a golden strand and wet granules draw out the nearest health core, and the entry folds knit shut as the intruder dissolves. Host overlays share the Mother's wound state, so consumed cores cannot reappear over the hunter. Damage remains immediate. The native damage fixture passed **45 checks**, including staged entry, pause, reduced motion, simultaneous hits, cleanup, and fatal-result timing. [Updated invasion preview](artifacts/mother-invasion-preview.mp4); reproduce its 240 native frames with `tests/mother_invasion_reel.gd` and encode `/tmp/microverse-mother-invasion-frames/frame-%04d.png` at 30 fps.

[Animated species](artifacts/campaign-species-preview.mp4) · [Species](artifacts/campaign-roster.png) · [Evolution](artifacts/campaign-evolution.png) · [Boss](artifacts/campaign-conjoined-window.png) · [Comfort controls](artifacts/campaign-comfort.png) · [Pond motion](artifacts/pond-currents-preview.mp4) · [Core damage](artifacts/mother-damage-preview.mp4)

### Visual quality

Sound & comfort offers three saved detail levels. Full keeps up to 46 background specimens, up to 264 particles, and both moving optical depths. Balanced uses 18 specimens and 160 particles with one depth; Light uses 10 and 80 with one texture sample and gentler distortion. Every setting preserves full playable organism detail, gameplay geometry, capture markers, and living motion. Debris kinds are interleaved so reduced detail retains variety. [Light mode](artifacts/campaign-light-detail.png).

## Meditative audio

The three current background scores were supplied by the user on 2026-10-07:

| World | Source | Full duration | Runtime asset |
| --- | --- | --- | --- |
| Stillwater and title/home screen | track1.mp3 | 3:09.2 | `assets/audio/petriverse-stillwater.ogg` |
| Glassgarden | track2.mp3 | 2:19.2 | `assets/audio/petriverse-glassgarden.ogg` |
| Blue Deep | track3.mp3 | 3:02.8 | `assets/audio/petriverse-blue-deep.ogg` |

The original MP3s are preserved in `../artifacts/audio-source/provided-scores/`. A constant gain brings each full track to approximately −23 LUFS without compression or shortening; playback copies are 44.1 kHz stereo Ogg Vorbis. The original fixed-key tension, Nimble, Feast and Hunter music beds are disabled. Pond ambience, the non-tonal water-current layer, and interaction cues remain. `assets/audio/provided-scores-provenance.json` records source hashes, durations and processing. Older generated scores are retained as unused source material.

The game makes no audio network requests. Music uses a five-second equal-power overlap at loop boundaries and world transitions. Bosses retain their world’s music. Connections rise through pentatonic intervals, digestion cues follow the visible capture, and stronger events briefly duck the music. Pause freezes active effects and pending cues while lowering the ambient mix. Effects have bounded polyphony. Music, effects, and mute preferences persist independently. **V** opens the controls.

`../tools/generate_audio.py` reads `ELEVENLABS_API_KEY` from the environment, retains the original MP3s and exact requests in `../artifacts/audio-source/`, and masters 44.1 kHz stereo Ogg Vorbis files for the game. Completed originals and outputs are reused. No key is saved in assets, prompts, or game code. The generator validates the API's 450-character effect-prompt limit and uses the available Vorbis encoder. Request IDs, source hashes, and generation prompts are recorded in `assets/audio/provenance.json`.

Music/effects target -23 LUFS and the pond bed -29 LUFS before the runtime mix adds headroom. The following measurements describe the earlier generated assets: Short cues have leading silence removed and a 6 ms attack fade. All twelve files decode without clipping; the connection cue becomes audible within one millisecond. [Asset measurements](artifacts/audio-assets-report.json). The pond loop's boundary step is below its ordinary 99th-percentile sample-to-sample variation. Listening taste still belongs to human review; these measurements establish technical playback quality rather than subjective musical quality.

To regenerate intentionally with an environment-provided key, the script reuses existing files; preserve or move the specific original and mastered asset first if a genuinely new variation is desired. The normal game never needs credentials.

```sh
python3 ../tools/generate_audio.py --only connect
python3 ../tools/generate_audio.py
godot --headless --editor --path . --import
godot --headless --path . --script res://tests/audio.gd -- --require-assets
```

API references: [ElevenLabs music](https://elevenlabs.io/docs/api-reference/music/compose), [sound effects](https://elevenlabs.io/docs/api-reference/text-to-sound-effects/convert).

## Implementation map

| Files | Responsibility |
| --- | --- |
| `data/board.json`, `scripts/board.gd` | 24 anchors, 56 edges, 32 legal triangles, shared live geometry and drift |
| `scripts/run_controller.gd`, `run_plan.gd`, `encounter.gd` | Full-run progression, finite formations, resolution, pause/restart |
| `scripts/drifter.gd`, `conjoined.gd` | Species anatomy, logical nuclei, movement, armor, boss phases |
| `scripts/input_controller.gd`, `loop_geometry.gd`, `loop_resolver.gd` | Input, validation, shared preview/capture, scoring and mutation effects |
| `scripts/mutations.gd`, `mutation_card.gd`, `records.gd` | Evolution catalogue and choices, persistent records |
| `scripts/clot.gd`, `cell.gd` | One recovery clock for gameplay readiness and fused visual return |
| `scripts/main.gd`, `hud.gd` | Native input, controls, presentation, preferences, feedback |
| `scripts/microscope.gd`, `tissue_motion.gd`, `pond_life.gd`, `shaders/` | Animated microscopy, biological structures, pond depths and fusion |
| `scripts/mother_damage.gd`, `injury_motes.gd` | Consumable organelles, invasion aftermath, golden fragments |
| `scripts/soundscape.gd`, `../tools/generate_audio.py` | Offline audio runtime and authorized one-time asset generation |

## Verification — October 5, 2026

**Before the Nudge addition, 1,269 required checks were verified across 33 fixtures**, using the regression run and focused continuations. Nudge adds a focused fixture to `./test.sh`; its current validation is described with the controls above. Current coverage includes input, free polygons, independent drift, absorption, damage, evolution, the connected journey, ecology, habitats, persistent rescued life, discovery, bosses, arrivals, appearance, and bundled audio. Legacy fixture routes now use current visible cell geometry. The 30 human-pacing assertions were rechecked against the six freshly generated simulation reports after correcting their obsolete 3-pixel/s drift expectation to the established 12-pixel/s limit; simulation behavior was unchanged. The wrapper requires completion markers and rejects script errors, since some Godot parse errors return zero status.

The supplied-score update passed **83 focused audio checks and 14 native mixer checks**. The native recording verified a real end-of-track overlap, transition to track3, paused effects, silence from the old harmonic layers, mute below −80 dBFS RMS, victory exactly once, and zero dropped mixer frames. The combined peak was **−11.59 dBFS**. This captures the engine mix through Movie Maker; it does not claim subjective listening approval or physical speaker testing. [Current playback report](artifacts/audio-playback-report.json). Older audio/video previews predate the supplied tracks.

The **37 native campaign assertions** passed with the revised species art. They cover anatomical nucleus registration, real card/button clicks, unlimited evolution reading time, boss layers/reformation, final digestion before victory, replay, larger text, stronger markers, the Frenzy feeding channel, all quality modes, critical warning graphics, and species-correct core invasions. Native screenshots linked above were visually reviewed.

Full-run pacing fixtures perform real timed node visits, including closure, with a 0.55-second planning gap. The current moving-board samples completed in **195.57–202.22 seconds**, at 3 or 4 segments/second, with 29–31 captures and five integrity. Their route selector has perfect geometric knowledge: this verifies timing feasibility, **not human difficulty**. All 20 possible three-mutation combinations could defeat the boss after initial board exhaustion and a missed window.

The current mixed-species performance fixture renders **24 cells with eleven mutations**, **18 fully emerged enemy bodies**, eight recovering cells, a closed eight-cell preview, and **46 background specimens** at Full detail. At **1920 × 1080** on **Apple M3 Max**, 600 sampled frames after 120 warmup frames averaged **16.666 ms**, p95 **18.252 ms**, maximum **18.724 ms**, holding the **60 fps cap** with no frames above 20 ms. [Current measurement](artifacts/frame-sample-evolved-full.json). The render uses 286 draw calls: cytoplasm beads and cilia are instanced on the GPU, retaining circulation, coordinated hair motion, evolution shapes, growth, flow bending, and fading. The heavy scene previously required 1,123 draw calls. All organisms remain present; quality and density were not reduced.

Native evolution checks pass **42 assertions**. The updated motion fixture passes **28 assertions**, including isolated rendered cilia and cytoplasm movement, identical pixels at a frozen clock, reduced motion, and complete fading. Native comparison images were reviewed at normal play size. The performance sample runs alone with VSync disabled; sustained play and a second machine remain unverified. [Older campaign](artifacts/frame-sample-campaign.json) and [Light-detail](artifacts/frame-sample-campaign-light.json) reports predate this expanded, fully emerged scene and are not controlled comparisons with the current build.

```sh
./test.sh
godot --path . --script res://tests/campaign_visual.gd
godot --path . --script res://tests/motion_pixels.gd
godot --path . --script res://tests/frame_sample.gd --disable-vsync --max-fps 60 -- --evolved
```

## Remaining validation and scope

The default game contains the connected three-biome, fifteen-encounter route described above. Existing saves retain twelve or thirty encounters; the earlier single-dish modes remain available as fixtures. Current pacing evidence and its limits are recorded in the connected-journey section. The focused journey duration and long-term replay appeal still need human playtesting across builds; procedural combinations are constrained by the existing creature families and objective types. First-time-player observation, human listening feedback, sustained performance on other hardware, and Windows/Linux runtime behavior remain unverified. Desktop exports are available in `../dist/`; Mac export signing and notarization evidence is recorded there. Rendering is layered 2D microscopy with shader motion.


### Persistent water (0.1.1)

A 28×28 CPU fluid field advances at 20 Hz, with semi-Lagrangian advection, viscosity, pressure relaxation and slip boundaries around the dish and Mother. Local cell and hunter movement, player strokes, cyst nudges and absorption impart momentum. The same field steers free cells gently, carries food/spores/poison at up to 1.2 px/s, and moves photographic specimens, suspended debris and optical sediment. Cells retain their 12 px/s speed cap; selected and recovering cells keep their exact positions. Hunters receive at most 0.45 px/s of current assistance; bosses and attached organisms retain their authored behavior.

The water has no separate gameplay RNG. Pause freezes momentum and transported material coordinates, and journey snapshots preserve both. Reduced motion suppresses visual water deformation while retaining the same gameplay rules. The grid is a shallow 2D approximation, not a 3D liquid simulation. Run `godot --headless --path . --script res://tests/fluid_dynamics.gd` for the focused momentum, save/resume, input and feeding checks.


### Fine water particles and amoebas (development build)

960 subpixel silver/cyan grains (560 Balanced, 240 Light) travel through the shared water with slight inertial lag and occasional refractive glints. They use one instanced GPU draw. Actual creature movement leaves paired wakes; capturing pulls the water inward, then the returning cells displace it outward. Amoeba ingestion stirs the same field, and home-pond residents leave local wakes. Explicit visual time freezes particles on pause; reduced motion hides the sparkling layer. This source update is newer than the packaged 0.1.1 release.

Amber amoebas enter at **Turning tide** in Glassgarden and can appear in later procedural missions. Their gold nucleus is the capture target. The microscopy-textured body extends a broad leading lobe, streams granular cytoplasm forward and retracts its trailing edge. Its uneven outline deforms as it crawls; a continuous membrane wraps around a blue cell and draws it into a transparent digestive vacuole. The artwork silhouette is converted once to a cached signed-distance field; body, growing lips and sealed chamber are merged before applying a single tissue material and outer optical rim. The body narrows as it feeds the extension, and the cup stays intact through sealing and inward folding, with no retained outline between the old body and its reach. The pale, translucent tissue replaces the earlier radial amber star shape; the gold nucleus remains registered to the capture target. This is a biology-inspired 2D animation, not a physical cell simulation. Capture the amoeba within **15 seconds** to send the cell home; otherwise it is unavailable until the next encounter. It never steals a selected/recovering cell or damages Mother. Introductions cap at one amoeba; later encounters permit two, with staggered swallowing and a four-missing-cell safety cap. The rescue triangle excludes the swallowed cell and Mother. Captivity, digestion and return animations survive saves.

Focused checks: `tests/amoeba.gd` (28), `tests/fluid_dynamics.gd` (25), `tests/journey_ecology.gd` (34), and native `tests/amoeba_motion.gd` (10), and isolated native `tests/amoeba_pixels.gd` (15). Pixel checks isolate streaming from outline deformation, verify frozen-clock/reduced-motion frames, check captive placement after turning, and verify one connected rendered membrane at nine moments from the start of a long reach through closure and swallowing. The movement checks verify average speed and frame-rate independence. The existing visual-motion fixture also passed 67 checks. The fluid/amoeba performance variant is `tests/frame_sample.gd -- --evolved --fluid`. [Close-up of the continuous membrane](artifacts/amoeba-continuous-closeup.mp4). [Native gameplay motion preview](artifacts/amoeba-realistic-preview.mp4). [Microscopy detail](artifacts/amoeba-realistic-detail.png). [New built-in imagegen asset and prompt provenance](assets/organisms/amoeba-v2-prompts.json).

The native heavy-scene sample with active fluid, 960 instanced grains, evolved tissue and two reaching amoebas averaged **16.74 ms** (~60 fps average), with **21.69 ms p95** at 1920×1080 on Apple M3 Max. [Recorded frame sample](artifacts/frame-sample-fluid-amoebas.json). This is a short local sample, not a sustained or cross-device guarantee.
