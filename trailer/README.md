# Petriverse trailers

The current [Petriverse 0.2.3 game trailer](Petriverse-trailer-0.2.3.mp4) is a new 90-second edit showing Mother's evolving anatomy, creature films, the focused route, late hunter waves, and updated gameplay. [Shot list, sources, and verification](petriverse-0.2.3/README.md). The [0.2.0 Petriverse trailer](Petriverse-trailer-0.2.0.mp4) and original Microverse trailer remain available.

## Original Microverse trailer

**Final film:** `Microverse-trailer-1080p.mp4` — 90 seconds, 1920×1080,
30 fps, H.264 video, stereo 48 kHz AAC audio. English subtitles are embedded
as an optional track and supplied separately in `Microverse-trailer.en.srt`.

The footage is rendered by the actual game. Encounters are staged with isolated
test state and cinematic camera framing; the loop drawing, cyst nudge, absorption,
rescue, Mother injury, evolution, and creature animation use the native systems.
No shipping gameplay code or player saves were changed to make this film.

## Edit

- 00:00 — A microscopic world; Mother and the colony.
- 00:08 — MICROVERSE title and premise.
- 00:14 — Draw a closed loop; capture green food; cells merge and recover.
- 00:26 — Move a poison cyst aside, then make a clean capture.
- 00:34 — A hunter enters Mother and consumes an organelle.
- 00:41 — Catch a hunter and rescue a glasswing spore.
- 00:48 — Food becomes visible colony evolution.
- 00:56 — Stillwater, Glassgarden, Blue Deep.
- 01:08 — Rare creatures and ongoing discovery.
- 01:14 — The Bellwether, Glass Regent, and Conjoined.
- 01:23 — A home pond populated by actual rescued specimens; closing title.

## Audio and sources

Narration: ElevenLabs `eleven_v3`, Willa Ashford, generated through the connected
Magnific service. Eleven generation calls used 168 credits. The original
voice segments are in `audio/`; text and generation metadata are retained in
`narration.json`. No voice cloning was used.

Music and effects come from the game's existing original ElevenLabs assets in
`../prototype/assets/audio/`, whose provenance is recorded there. The edit uses
Stillwater, Glassgarden, Deepwater, current/hunter/tension layers, pond ambience,
and native interaction effects. `audio/mix.json` retains placements and
`audio/mastering.json` retains the two-pass loudness measurements. The mix targets
−16 LUFS and a −1.5 dBTP master peak. Narration and music/effects WAV stems are
included for future edits.

`timeline.json` defines the 16 shots. `footage/*.json` records the actual gameplay
results and synchronized sound events. All shot checks passed, including clean
feeding, successful rescue, and one real Mother hit. The export has 2,700 video
frames and 90 seconds of audio; the only black frames are the intentional opening
and closing fades. `stills/final-review.jpg` is a contact sheet of the final export.

## Rebuild

From the project root, with Godot and FFmpeg installed at `/opt/homebrew/bin`:

```sh
python3 tools/render_trailer.py
python3 tools/edit_trailer.py
```

The renderer also accepts individual shot names, for example
`python3 tools/render_trailer.py loop`. It uses temporary frame sequences under
`/tmp/microverse-trailer-frames/` and removes those frames after encoding each shot.
The editor requires NumPy. Original generated audio is retained, so rebuilding
does not make further API calls or use generation credits.
