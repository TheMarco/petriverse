# Petriverse 0.3.0

- **Mac, Apple Silicon + Intel:** [Petriverse-0.3.0-macos-universal.zip](Petriverse-0.3.0-macos-universal.zip). Developer ID signed, Apple notarized, and ticket stapled.
- **Windows x86-64:** [Petriverse-0.3.0-windows-x86_64.zip](Petriverse-0.3.0-windows-x86_64.zip). Extract everything and run `Petriverse.exe`; keep `Petriverse.pck` beside it. Not Authenticode signed.
- **Linux x86-64:** [Petriverse-0.3.0-linux-x86_64.zip](Petriverse-0.3.0-linux-x86_64.zip) or [tar.gz](Petriverse-0.3.0-linux-x86_64.tar.gz). Extract and run `./Petriverse.x86_64`; keep `Petriverse.pck` beside it. Executable permissions are preserved.

All three builds contain version **0.3.0** internally and the same game pack. Artwork, music, effects, creature-film narration, subtitles and license notices are bundled. No Godot installation, network connection or API key is needed to play. Existing saves remain compatible.

## New in 0.3.0

Captures snap shut with a flash and sparks, food flies into the counters, and the dish shakes when Mother is hurt; a heartbeat warns at her last organelle. A microscope lens pass, encounter title cards and fading screens give the dish a new look, with new interface and heartbeat sounds. Quick chains of clean captures build flow and fast clears earn a swift bonus; both add score only. The title shows the best journey score.

Settings has Sound, Play and Display sections, adds full screen (F11 or Alt+Enter) and explains each option on hover. Tooltips wrap. Starting a new journey over an unfinished one asks first and shows what would be lost. Compare details turns the evolution cards over. Rare visitors can no longer drift beyond the reach of any loop.

## Verification (0.3.0)

The exported game pack passed **113 native Mac smoke checks** with Godot 4.7.2 (version, startup, journey length, film voiceovers, Mother textures, art, music, capture, recovery, fluid rendering, pause; no shader errors). Mac, Windows and Linux share one pack (SHA-256 `65f5d208...dbc38e`). The Mac app is Developer ID signed with the hardened runtime; Apple notarization submission `5145dda7-e59c-4491-9022-b0ad4f24fd1f` was Accepted, the ticket is stapled, and an app extracted from the release ZIP passes `codesign --verify --deep --strict`, `stapler validate` and Gatekeeper (`spctl`: Notarized Developer ID). The Windows executable reports file and product version 0.3.0.0; the Linux executable keeps its executable permission in both archives. All four archives pass integrity tests. Windows and Linux have not been run on their target operating systems. See [release checksums](SHA256SUMS.txt).

# Petriverse 0.2.3

- **Mac, Apple Silicon + Intel:** [Petriverse-0.2.3-macos-universal.zip](Petriverse-0.2.3-macos-universal.zip). Developer ID signed, Apple notarized, and ticket stapled.
- **Windows x86-64:** [Petriverse-0.2.3-windows-x86_64.zip](Petriverse-0.2.3-windows-x86_64.zip). Extract everything and run `Petriverse.exe`; keep `Petriverse.pck` beside it. Not Authenticode signed.
- **Linux x86-64:** [Petriverse-0.2.3-linux-x86_64.zip](Petriverse-0.2.3-linux-x86_64.zip) or [tar.gz](Petriverse-0.2.3-linux-x86_64.tar.gz). Extract and run `./Petriverse.x86_64`; keep `Petriverse.pck` beside it. Executable permissions are preserved.

All three builds contain version **0.2.3** internally and the same game pack. Artwork, the three supplied music tracks, effects, creature-film narration, subtitles, and license notices are bundled. No Godot installation, network connection, or API key is needed to play. Existing Microverse saves remain compatible.

## New in 0.2.3

New journeys use a focused fifteen-encounter path through three biomes. Mother visibly grows from three to seven organelles and takes on a different body with a first major mutation. Route choices and organelle roles add longer-term decisions. First sightings offer a nonblocking **Watch film** choice; **Later** saves the film in the Field Journal, where it can be replayed. Round outcomes appear in the dish before the next decision.

Existing thirty-encounter saves keep their route. In late Blue Deep visits, a warned hunter wave follows the ordinary goal, swift clears draw more hunters, Guard organelles rest longer, and repair requires a deeper wound. Long membrane links strain the colony, while varied clean feeding can reward careful play. These changes increase scripted pressure; human difficulty and enjoyment still need playtesting.

## Verification

The identical exported game pack passed **109 native Mac smoke checks** with Godot 4.7.2. These cover startup, version, current journey length, all 44 film voiceovers, Mother stage textures, art, music, real capture, cell recovery, fluid rendering, and pause. The Mac archive and extracted app signature passed validation. Windows and Linux archives passed integrity checks; Windows version metadata and Linux executable permissions were inspected. Windows and Linux have not been run on their target operating systems. The Mac app has an accepted Apple notarization ticket stapled to it.

See [native pack report](0.2.3/reports/pack-native.json), [release checksums](SHA256SUMS.txt), and the [new game trailer](../trailer/Petriverse-trailer-0.2.3.mp4). Previous archives and the 0.2.0 trailer are retained.

## Rebuilding

Use Godot 4.7.2 with `--headless --path prototype --export-release` and preset `macOS`, `Windows`, or `Linux`. The Mac export uses the configured Developer ID identity from Keychain. Keep source files unchanged between platform exports and compare game-pack hashes. Credentials are never stored in this project.
