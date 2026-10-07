# MICROVERSE: first prototype implementation brief

## Purpose

Implement the smallest playable test of an enclosure-based microscopic arcade puzzle. This brief is intentionally narrower than the complete game design. Do not start by implementing the full mutation roster, bosses, or rendering system.

**Status:** Implementation instructions. No implementation or tests are claimed to have run.

## Proposed environment

Use Godot with GDScript and a native desktop target. Use the installed stable engine version and verify API availability against its matching documentation. Do not silently upgrade an existing project, replace its renderer, or overwrite unrelated files.

For a new project, create an isolated project directory. The first build must run directly in the editor without network access or purchased assets.

## Game premise

A mother cell sits at the center of a circular petri dish. Twenty-four friendly cells form an irregular network around it. Drifter enemies approach the mother from the perimeter. The player connects neighboring friendly cells into a closed polygon to capture enemies. Every used cell then enters recovery, so spending cells has a spatial cost.

There is no individual player avatar, color matching, auto-fire, fluid simulation, camera scrolling, or inventory.

## Required screen

Use a 1280 × 900 logical canvas, scaled uniformly with letterboxing. A circular dish about 800 logical pixels in diameter occupies the center. Include mother integrity, score, a brief instruction, pause, and restart.

Represent friendly cells as clearly visible circles with interiors. Ready and recovering states must differ by both brightness and a visible progress ring. Give enemies a distinct oval silhouette and a visible nucleus. Keep the mother distinguishable by size and internal structure.

## Authored board

Define 24 cell anchors and explicit neighbor edges in a data resource. Use a planar, connected arrangement with small triangles and several larger alternative routes. No edge may cross another except at a shared endpoint. Avoid edges visually passing through the mother.

Do not generate a fresh random graph on each run. Author a readable board and include a debug overlay for cell IDs and legal edges. The same layout must be used by input, preview, and capture.

Cells may have a subtle cosmetic wobble; their logical anchors and hit regions stay stable.

## Input contract

- Press the primary mouse button on a ready cell to start.
- Drag into a ready neighboring cell's hit region to append it.
- Require 3–8 distinct cells for a valid loop.
- Returning to the first cell closes the loop.
- Release while closed to commit; releasing an open path cancels.
- Returning to the immediately preceding cell backtracks one step.
- Right-click or Escape cancels selection.
- Reject non-neighbor jumps, crossings, repeated nodes other than closure/backtracking, and degenerate polygons.
- Cancellation consumes nothing.
- Starting in empty space does nothing.

While selecting, highlight legal next cells, the closing node, and the targets inside a prospective closed loop. When the endpoint cannot legally connect to the start, do not present a false closed-loop preview.

Use forgiving hit areas and state feedback. Do not make the player trace the exact lines.

## Capture and recovery

Capture tests a target's nucleus position against the polygon, including a small consistent boundary tolerance. Reuse the exact predicate for preview and resolution.

On commit, atomically validate the selected cells, snapshot target positions for this simulation step, identify targets, spend used cells, and apply one damage to each captured enemy. Then play visual feedback. Do not delay logical capture until the animation finishes.

All Drifters have one health. Kills award 100 points each. A valid empty loop earns no score but still exhausts its vertices. Other friendly cells inside the polygon are unaffected.

Used vertices recover after six seconds. This is a configurable tuning value. Show visible progress and restore availability immediately when the timer expires.

## Drifter and mother behavior

The mother has five integrity segments. Spawn Drifters from authored perimeter sectors. Their movement aims toward the mother with a small cosmetic undulation. Avoid large direction randomness that would make capture preview untrustworthy.

An enemy reaching the mother boundary deals one damage and is removed. At zero integrity, stop combat and show game over, score, and immediate restart. Resolve simultaneous contacts consistently and add a regression test for that behavior.

Use a finite encounter budget, initially 20 Drifters with no more than six simultaneously active. These values are tuning defaults. After all scheduled enemies are resolved and at least one integrity remains, show a success state and immediate restart.

The first encounter should be short enough for rapid repeated testing. Do not add three-wave run structure to this initial test.

## Presentation scope

Use simple locally generated shapes, a restrained dark background, clear cyan/pearl friendly cells, and warm hostile cells. Include a membrane contraction effect, a brief nutrient-absorption trail, and a recovery animation.

State and silhouette must remain readable without color. No external image generation dependency is needed to run this prototype. Full refraction, layered microscopy shaders, complex organelles, bosses, and mutation visuals belong to later gates.

## Suggested responsibilities

- `board`: cell positions and legal edges.
- `cell`: ready/recovering state and feedback.
- `input_controller`: interaction state machine.
- `loop_geometry`: validation and containment functions.
- `loop_resolver`: atomic gameplay result.
- `drifter`: movement, health, mother contact.
- `encounter`: finite spawn budget and completion.
- `run_controller`: active, paused, success, loss, restart.
- `hud`: integrity, score, instructions, controls.

Keep implementation straightforward. Do not introduce a general entity-component framework or a universal ability language. Exact filenames may follow an existing project's conventions.

## Required tests

Test pure geometry functions separately from rendering:

1. Valid triangle and valid larger loop.
2. Too few vertices, too many vertices, and zero-area polygon.
3. Non-neighbor connection and invalid closing edge.
4. Self-intersection and overlapping segments.
5. Target inside, outside, on an edge, and on a vertex.
6. Reversed winding order produces the same capture result.
7. Open release and explicit cancellation do not spend cells.
8. A recovering cell cannot be selected or committed.
9. Backtracking removes only the most recent node.
10. Previewed targets match targets resolved in the same simulation state.
11. Empty valid loop exhausts its cells and awards nothing.
12. One enemy cannot award kill score twice.
13. Recovery timing is independent of frame rate.
14. Restart clears enemies, selected paths, timers, spawn budget, score, and integrity.
15. Pausing freezes simulation and recovery, and does not accidentally commit input.
16. Simultaneous mother contacts resolve consistently.
17. Resizing does not change logical hit testing or stretch the dish.

Provide a debug mode showing graph edges, target nuclei, selection geometry, recovery timers, and the count of currently available legal triangles. That last value helps identify excessive downtime; it is not a complete count of all possible polygons.

## Acceptance criteria

A person can launch the project, understand the goal, complete a capture, observe recovery, lose or win, and restart without editor intervention. The preview must agree with the committed result. Both short and larger loops should be possible on the authored board.

Report the engine version and the actual checks run. Distinguish automated tests, manual checks, and untested assumptions. Do not claim playtesting or performance measurements that were not performed.

The target is stable 60 fps at 1920 × 1080 on a named test machine. That is an acceptance goal, not a pre-existing measurement.

## Stop condition

Stop after this one-enemy enclosure test is complete and verified. Provide the project, launch instructions, controls, test results, and known limitations. Do not expand scope to compensate for an unconvincing core mechanic.

The next gate is to polish one organism and the capture effect, followed by adding Shellback, Twinspore, mutations, and the boss as specified in the complete design document.
