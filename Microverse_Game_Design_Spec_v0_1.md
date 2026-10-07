# MICROVERSE
## Game design specification v0.1

**Working title:** MICROVERSE. Naming and availability have not been cleared.
**Design status:** Proposed design, not a built or playtested game.
**Core promise:** Enclose. Absorb. Evolve.
**Genre:** Single-player, real-time spatial arcade puzzler.
**Initial platform assumption:** Native desktop; mouse-first interaction. Platform choice remains a product decision, not an established user requirement.
**Prototype duration goal:** One replayable dish taking approximately 3–5 minutes per successful run.

All numerical values below are starting hypotheses for testing. They are not validated balance or performance measurements. Biological terminology supports a stylized fictional ecosystem, not a scientific simulation.

---

## 1. The game in one paragraph

You control a microscopic colony distributed across a petri dish. Its mother cell is surrounded by smaller friendly cells. Drag through nearby cells to connect them into a closed membrane. The membrane captures hostile organisms whose nuclei lie inside it and delivers a digestive pulse. Used cells become temporarily exhausted, opening gaps in your defenses. Enemies introduce different spatial problems, and mutations change how your membranes work. Clear three encounters, specialize your colony, and defeat a two-core predator that must be captured as one organism.

The battles are played through the puzzle interaction. There is no separate battle screen and no weapon auto-firing in the background.

## 2. Design pillars

### An organism you can believe in
Every gameplay object should have a recognizable membrane, interior structure, and characteristic movement. The visual signature is translucent living material viewed through glass, with controlled fluorescence and rich internal detail.

### Geometry under pressure
The player finds useful polygons in an organic network while enemies move toward the mother cell. Waiting for a better grouping, spending extra cells on a wider capture, and preserving a nearby defensive route should all be meaningful choices.

### Evolution changes decisions
Mutations change routing, recovery, grouping, and capture opportunities. Visual changes make the colony's specialization visible. Avoid a progression system dominated by small percentage increases.

### Readability before spectacle
At a glance, players must distinguish available friendly cells, recovering cells, enemies, threat direction, and the currently selected membrane. Decorative microscopic life must never look interactive.

## 3. What the player controls

The player controls the colony's connections, not a single swimming avatar. There is no WASD movement in the first version.

The mother cell stays near the center. Twenty-four friendly cells occupy an irregular arrangement around it. Their logical positions and legal neighbor connections stay fixed during an encounter. Their bodies breathe and wobble around those anchors, producing a living appearance without invalidating a player's plan.

Enemies move continuously. Faint debris and out-of-focus life drift behind the active layer. The initial game uses one screen with no camera scrolling, zoom controls, or minimap.

All friendly cells are compatible with one another. The puzzle comes from geometry, recovery, enemy behavior, and route efficiency. Color matching is not an additional requirement.

## 4. Exact core interaction

1. Press the primary mouse button on an available friendly cell.
2. Drag through its available neighboring cells. Show only currently legal next connections.
3. Visit at least three distinct cells and return to the starting cell to close the path.
4. A live preview highlights exactly which enemy nuclei would be captured.
5. Release to commit the closed membrane.
6. Resolve capture immediately against that simulation state, then play the contraction and digestion animation.
7. Cells used as vertices enter recovery. Cells merely inside the polygon remain available.

### Validity rules

- A basic loop uses 3–8 distinct cells.
- Consecutive cells, including the final cell and the start, must share a legal neighbor edge.
- All selected cells must be ready when the action is committed.
- Paths may not cross themselves or overlap an earlier edge.
- Revisiting a node is allowed only to close at the start or to backtrack to the preceding node.
- Near-zero-area polygons are invalid.
- Releasing an open or invalid path cancels it without spending cells.
- Right-click or Escape cancels selection.
- A valid empty loop may be committed, but earns no points or biomass and still exhausts its cells. Preview must make this obvious.

### Capture rules

A regular target is captured when its visible nucleus is inside the polygon. This avoids disagreements caused by tentacles, soft-body deformation, or membrane art. Count nuclei on the boundary as inside, using a small, consistent numerical tolerance. The preview and committed result must use the same predicate.

A base pulse deals one damage. It resolves once; the animated membrane is not a recurring damage field. Friendly objects are unaffected. A surviving target is briefly stunned. A captured target cannot escape after the action has been resolved merely because its digestion animation has not finished.

### Recovery

Used cells recover in six seconds by default. Show a dimmed interior and an organic ring that refills around the membrane. Used cells remain visible; they do not disappear or permanently alter the graph.

Six seconds is an initial tuning value. Test it against drawing time and enemy travel time. Shorten it if the player routinely has nothing useful to do.

### Controls and forgiving interaction

Use generous hit areas, clear start-node feedback, and backtracking. Do not require tracing a precise line between cells. The player chooses vertices; the game renders the bonds. Pointer movement across a node should only add that node when it is a legal neighbor.

Provide an alternative click-to-build interaction with an explicit commit action for players who cannot comfortably drag. Do not build touch and controller implementations before the mouse loop is validated; controller navigation needs its own adjacency-selection design.

## 5. Why small and large loops both matter

Loop size determines coverage and cell expenditure, not automatic superiority. A three-cell loop can efficiently intercept one urgent enemy. An eight-cell loop can capture a cluster but exhaust a much larger portion of the board. Routing around one useful cell can preserve it for the next attack.

Examples of desired decisions:

- Capture an isolated attacker now, or wait for another to enter the same polygon.
- Spend two extra cells to reach a second target, or preserve those cells near the mother.
- Strip an armored enemy with one route while keeping another route available for the finishing hit.
- Catch both members of a linked pair together rather than wasting a pulse on one.
- Use an evolved short-loop build to make repeated precise captures, or a large-loop build to digest crowds.

The interaction must be engaging without upgrades. Do not use a large mutation catalog to conceal an uninteresting core.

## 6. Mother cell, enemies, and loss

The mother starts with five integrity segments. An enemy reaching its collision boundary is removed and deals one integrity damage. For the prototype, every ordinary enemy deals the same damage; threat comes from behavior rather than hidden attack statistics. Resolve multiple simultaneous contacts consistently and expose them in the debugging overlay.

The run ends at zero integrity. Preserve clear sightlines around the mother; do not hide approaching threats under HUD or foreground effects.

### Initial enemy roster

| Enemy | Behavior | Puzzle question | Readable form |
|---|---|---|---|
| Drifter | Moves slowly toward the mother; one health | Can you group several without letting the nearest reach the core? | Soft oval with one bright nucleus and a short trailing filament |
| Shellback | Two health; first pulse visibly fractures its armor | Can you preserve a second capture route while the first one recovers? | Segmented shell with an inner oval nucleus |
| Twinspore | Two linked bodies; neither is damaged unless both nuclei are in the same loop | Can you contain the pair simultaneously? | Two lobes joined by an unmistakable living tether |

Enemy illustrations and names can change; these three gameplay roles are the prototype commitment.

### Later roster, after validation

**Divider:** Splits after a clearly indicated countdown. Early capture prevents multiplication.

**Veil:** Temporarily suppresses a small set of neighbor edges, with an advance warning and a visible duration. It tests rerouting, not random input failure.

**Toxic cyst:** A stationary hazard that penalizes enclosing its marked nucleus. It tests precise contours. Introduce this only after ordinary capture is well understood.

Do not add these three to the initial implementation brief.

## 7. First boss: The Conjoined

An oversized organism with two prominent nuclei connected by an elastic body. It expands and contracts, periodically bringing its cores into a capturable configuration.

Both nuclei must be inside the same loop. Each successful joint capture removes one of three visible protection layers. Ordinary single-core enclosure produces clear shield feedback but no progress. Damage-boosting mutations do not skip protection layers.

The boss has readable attack beats that release a small number of Drifters. Its movement is authored to pass through at least two valid capture polygons on the base board. The fight must not require a specific mutation.

Twinspores introduce the rule before the boss. Boss movement should vary the spatial answer without changing the rule. Avoid using a huge health pool as the main source of difficulty.

Boss validation must include every allowed mutation combination and realistic cell-recovery states. A window may be missed because the player overspent cells, but future windows must remain achievable.

## 8. Run structure and evolution

### Prototype run

Start immediately in the dish after a brief instruction: **Connect cells. Close a loop. Protect the mother.**

Clear three finite enemy encounters. Each has a defined spawn budget, not an endless stream. Between encounters, pause the simulation and present three eligible mutation choices. After the third choice, enter the boss encounter. Defeating it ends the run with score, integrity remaining, selected mutations, and an immediate replay control.

Absorbed biomass visually fills an encounter-growth meter. For this version, evolution happens at encounter completion, so there is no additional shopping currency or separate leveling grind.

Do not promise exact encounter duration until tested. Aim for a complete successful run of approximately 3–5 minutes.

### Six prototype mutations

| Mutation | Rule change | Visible evolution |
|---|---|---|
| Rapid Fission | Cells in three- or four-cell loops recover in four seconds instead of six | Paired nuclei and visible budding |
| Elastic Membranes | Maximum loop length rises from eight to ten; all used cells take one additional second to recover | Longer, more elastic connecting filaments |
| Enzyme Sacs | Loops of six or more cells deal one additional damage to ordinary enemies; their cells recover two seconds later | Amber digestive vacuoles |
| Feeding Frenzy | A loop that kills three or more ordinary enemy bodies immediately restores its starting cell; once per committed loop | A contracting feeding channel toward the starting node |
| Osmotic Lure | After capture resolves, uncontained ordinary enemies within 120 logical pixels of the boundary are displaced up to 45 pixels toward the loop centroid; no extra damage or automatic capture | Pulsing cilia and a restrained current ripple |
| Residual Membrane | Completed loops leave a 1.5-second boundary that slows ordinary enemies crossing it by 40% for one second; no damage | A thin, persistent outer membrane |

Values assume the logical layout described below and must be retuned if its scale changes. Boss cores are immune to displacement and slowing so their capture windows remain predictable.

### Mutation composition

Choices are without replacement in one run. Apply additive recovery penalties, then the short-loop recovery override as the base, and clamp recovery to a minimum of one second. Thus Rapid Fission plus Elastic Membranes produces a five-second short-loop recovery. With Enzyme Sacs, six-cell loops recover in nine seconds when Elastic Membranes is also present.

A kill-triggered effect is processed once per loop, never recursively. A paired enemy consists of two bodies for the Feeding Frenzy condition. Boss layer removal is not an ordinary enemy kill.

### Long-term evolution, later

Unlock alternate starting colonies and additional mutation pools through explicit achievements. Offer different strategies rather than permanent numerical superiority. Keep score comparisons separated when starting conditions differ.

A later full run could span three distinct dishes with different layouts and environmental rules. That is an expansion direction, not the first build.

## 9. Scoring

A starting scoring model:

- Drifter kill: 100 points.
- Shellback kill: 200 points; armor damage alone awards no kill score.
- Twinspore pair killed together: 250 points total.
- Boss defeated: 1,500 points, awarded once.
- Each additional ordinary enemy group killed in the same loop adds a 25% multi-capture bonus to that loop's base kill points, capped at 100%.
- Remaining mother integrity at victory: 200 points per segment.

Treat a Twinspore pair as one enemy group for scoring. Keep that distinction explicit in data. Do not award points for empty loops, cancelled input, or repeated hits against invulnerable targets.

A rapid-capture streak multiplier is deferred. First test whether efficiency and multi-captures already provide sufficient score-chasing depth.

## 10. Art direction

### Signature image

A broad glass dish in a dark microscope field. An opalescent mother cell pulses at its center. Smaller translucent cells sit around it, each with visible organelles. A warm, segmented predator approaches. The player completes a cyan membrane between five cells; it swells into a nearly invisible film, contracts, and draws the predator's interior into shimmering nutrient threads.

The reference image is a mood reference, not the final layout. Reduce its rainbow saturation, dense ornament, generic science-fiction controls, and minimap. Give the organisms more room and material complexity.

### Material language

Use thin double membranes, subtle iridescence, granular cytoplasm, asymmetric internal organelles, restrained optical distortion, and small ciliary movements. Friendly cells should have calmer breathing rhythms. Hostiles can move with directional contractions or coordinated flagella.

The principal palette is ink-black and desaturated teal, with pearl-cyan friendly tissue, amber/coral hostiles, and a limited violet accent for special states. Color is secondary to silhouette, motion, texture, and state markers.

### Layering

1. Dim microscope field with a restrained vignette.
2. Out-of-focus fluid detail and distant organisms.
3. Glass and nutrient substrate.
4. Sharp gameplay cells, enemies, and selection bonds.
5. Sparse foreground debris that never obscures essential information.
6. Minimal, crisp interface.

Only decorative depth layers are blurred. Avoid chromatic aberration, heavy film grain, or bloom across the gameplay layer.

### Animation as explanation

Availability, recovery, armor fracture, pairing, and boss vulnerability all need their own visible changes. The capture sequence should read as biological digestion: connection, membrane formation, contraction, absorption, recovery. Keep the meaningful gameplay result immediate even when the visual aftermath continues.

Evolution changes the mother and ordinary cells with modular additions: vacuoles, cilia, extra nuclei, membrane folds. Do not rely on simply enlarging or recoloring the same circle.

## 11. Interface and sound

Keep score and remaining integrity in one quiet corner, encounter progress in another, and chosen mutation symbols along the bottom edge. Show detailed mutation text only when selecting or inspecting it. No minimap, inventory grid, quest list, equipment bar, or combat damage-number cloud.

During selection, the membrane preview is the interface: legal neighbors brighten, captured nuclei get a clear ring, surviving armored enemies display their expected result, and the starting cell visibly invites closure. Show an invalid edge with a brief shape/state change rather than color alone.

Sound should make routing and closure pleasurable. Each valid connection adds a soft pitched note; closure resolves it with a tactile, rounded sound; digestion produces granular liquid textures. Use low ambient pressure and sparse music that builds with threat. Critical warnings must have both visual and audio forms.

Provide reduced motion, independently adjustable effects and music, readable text scaling, alternative click-to-build input, and high-contrast state markers. Do not rely on color alone or require prolonged precise dragging.

## 12. Proposed implementation direction

**Recommendation:** Godot with a 2D simulation and a layered, shader-driven presentation, targeting native desktop first. This is a project recommendation, not a claim that Godot is inherently faster than every alternative or that browser delivery is impossible.

Godot's CanvasItem shaders expose vertex, fragment, and light stages for 2D rendering. Its 2D lighting supports normal and specular maps. These are appropriate building blocks for the proposed translucent bodies and wet-looking surface highlights. Godot also supplies 2D particle systems for decorative material.

Use a shared background texture for restrained optical distortion. Godot's documentation specifically warns that overlapping screen-reading materials do not automatically read one another's previously rendered results. Do not assume separately refractive cells will compose correctly without an explicit render plan.

Keep simulation independent of presentation. Use stable cell anchors and simple enemy hit geometry. Cosmetic tentacles, cilia, internal granules, and fluid particles should not become independent physics bodies. Defer full fluid simulation, soft-body collision, and deformable hit testing.

### Logical layout

Start with a 1280 × 900 logical canvas and a dish of roughly 800 logical pixels in diameter. Scale uniformly with letterboxing rather than stretching geometry. Reserve the perimeter and outer margins for essential HUD.

Author 24 friendly anchors as a connected planar graph containing small loops and multiple overlapping larger routes. Store positions and neighbor lists in data. The geometry should feel irregular but remain visually understandable. Validate edges for crossings and occlusion by the mother cell. Do not make random board generation part of the first build.

### System responsibilities

- Board data: anchors, legal neighbor edges, authored capture areas, spawn sectors.
- Input controller: node selection, backtracking, closing, cancellation, input mode.
- Loop resolver: validation, polygon geometry, preview, atomic commit, effect resolution.
- Cell state: ready/recovering and timers.
- Enemy director: encounter budgets, explicit movement behaviors, contact resolution.
- Evolution rules: six data-defined mutations and predictable composition.
- Presentation: shaders, membranes, organelles, feedback, sound, HUD.
- Run state: start, encounter, mutation choice, boss, loss, victory, restart.

Keep this structure small. Do not start with a general-purpose entity-component framework, multiplayer architecture, or universal ability scripting language.

### Performance acceptance target

Target a stable 60 frames per second at 1920 × 1080 on a specifically named test device, with all 24 cells, the mother, and approximately 18 ordinary enemy bodies visible. This is a target, not a measured result. Record hardware, renderer, quality level, resolution, and frame-time distribution when testing.

Quality settings should first reduce decorative particles, background distortion, and optional lighting. Preserve active-target visibility and input responsiveness. Do not use a high-end development machine as the only performance check.

## 13. Build order and acceptance gates

### Gate A: Prove enclosure

Build the authored board, selection, valid-loop detection, preview, Drifters, mother integrity, cell recovery, score, loss, and instant restart using simple shapes.

Pass when preview and capture agree, the controls are forgiving, useful routes are understandable, and both small and large loops have a reason to exist. Verify node-boundary cases, fast pointer movement, self-crossing rejection, cancellation, and time-based recovery.

Playtest target: at least four of five first-time testers can close a loop and describe why used cells become unavailable after one minute without spoken coaching. This is a target, not a result.

### Gate B: Prove the visual signature

Polish one friendly cell, one Drifter, the mother, the dish, and the membrane/digestion effect. Test still-image readability and motion at the intended viewing size. Do not produce the entire asset catalog before this looks convincing in motion.

Pass when cells read as living translucent material rather than glowing dots, capture feels rewarding, and decorative detail does not obscure state.

### Gate C: Prove a full run

Add Shellbacks, Twinspores, the six mutations, three encounters, The Conjoined, victory results, and replay. Validate every offered mutation and realistic combinations against all encounter requirements.

Pass when a complete run is coherent, the boss is learnable with the base kit, and players can describe at least two different strategic approaches.

### Gate D: Harden the slice

Add accessibility controls, audio settings, quality settings, resize behavior, local high score, and performance capture. Test on a second named machine. Record issues rather than claiming untested cross-platform compatibility.

Only after these gates should development expand to additional dishes, enemy families, challenge seeds, alternate starting colonies, or release-platform integrations.

## 14. Explicit exclusions

No multiplayer, open world, realistic ecosystem simulation, full fluid physics, extensive species editor, crafting, inventory, equipment, battle pass, large campaign, online leaderboard service, mobile-port commitment, console promise, or procedural generation in the initial scope.

The earlier concept image listed several modes and platforms. They are not commitments. One compelling mode earns the right to expand.

## 15. Key risks and what to test

**Loop drawing is pleasant but shallow:** Test repeated plays with only Drifters and recovery. Add strategic enemy roles only after the core has a useful efficiency tradeoff.

**Too much waiting:** Record how often no ready legal loop exists. Reduce recovery or revise graph density before adding an emergency ability.

**Large loops dominate:** Keep basic damage independent of area, maintain meaningful cell expenditure, and tune spawn grouping. Confirm small loops remain useful without a special mutation.

**The board looks like a disguised tile grid:** Use an irregular authored layout, organic cell shapes, subtle cosmetic movement, and bonds shown mainly during selection.

**The living motion undermines precision:** Keep gameplay anchors stable and compute preview and resolution from the same geometry. Restrict visual drift to a small fraction of each hit area.

**The visuals are beautiful but unreadable:** Reserve high contrast for interactive state and active threats. Evaluate grayscale screenshots, reduced-detail mode, and busy encounters.

**Boss becomes impossible after upgrades:** Keep all core geometry beatable with the base eight-cell limit, exclude forced-displacement effects on boss cores, and test all mutation combinations.

**The project expands before the mechanic works:** Treat the four gates as go/no-go decisions. More modes and species are not a substitute for an enjoyable first dish.

## 16. Definition of the first deliverable

A locally playable, restartable desktop prototype with one dish, 24 friendly cells, one mother cell, three ordinary enemy types, six mutations, three short encounters, and The Conjoined boss. It includes a readable capture preview, visible recovery, score, health, win/loss, and a narrow but polished microscopic art treatment.

This document specifies that deliverable. It does not claim that the prototype has been implemented or tested.

## Technical references

Official Godot documentation checked while preparing this specification. Consult the documentation for the actual installed engine version before implementing specific APIs.

- CanvasItem shaders: https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/canvas_item_shader.html
- 2D lights and shadows: https://docs.godotengine.org/en/stable/tutorials/2d/2d_lights_and_shadows.html
- Screen-reading shaders: https://docs.godotengine.org/en/stable/tutorials/shaders/screen-reading_shaders.html
- 2D particle systems: https://docs.godotengine.org/en/stable/tutorials/2d/particle_systems_2d.html

The particle tutorial carries an update warning; verify version-specific particle details in the class reference rather than treating that tutorial as a compatibility guarantee.
