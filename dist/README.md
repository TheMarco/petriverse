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
