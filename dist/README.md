# Petriverse 0.2.0

- **Mac, Apple Silicon + Intel:** [Petriverse-0.2.0-macos-universal.zip](Petriverse-0.2.0-macos-universal.zip). Developer ID signed, Apple notarized, with the ticket stapled. Requires macOS 13+ on Apple Silicon or macOS 11+ on Intel.
- **Windows x86-64:** [Petriverse-0.2.0-windows-x86_64.zip](Petriverse-0.2.0-windows-x86_64.zip). Extract everything and run `Petriverse.exe`; keep `Petriverse.pck` beside it. Not Authenticode signed.
- **Linux x86-64:** [Petriverse-0.2.0-linux-x86_64.tar.gz](Petriverse-0.2.0-linux-x86_64.tar.gz). Extract and run `./Petriverse.x86_64`; keep `Petriverse.pck` beside it. Executable permissions are preserved.

All packages include the art, three supplied music tracks, sound effects and license notices. They work offline without Godot or API keys. Existing Microverse saves remain in their original application-data location and carry over under the Petriverse name.

## Included in this release

The living Petriverse title screen, independent cell drift, reactive water and sparkling particles, continuous-membrane amoebas with timed cell rescue, bacteriophages that infect bacteria and release stolen food, colony evolution, rare creatures, three biomes and their guardians, thirty-encounter journeys, and the home pond. The current interface typography and collision-aware creature labels are included.

## Verification

All three platforms contain the same game pack. That pack passed 54 native smoke checks on macOS, covering menu startup, release identity, logo, fonts, creatures, all three supplied scores, board data, a real food capture, recovery, fluid rendering and pause. The final extracted Mac archive passed signature, stapled-ticket and Gatekeeper verification. Archive contents, game-pack hashes and Linux executable permissions were checked. Windows and Linux have not been run on their target operating systems.

See [release verification](0.2.0/reports/release-verification.json), [native pack report](0.2.0/reports/pack-native.json), and [checksums](SHA256SUMS.txt). Previous 0.1.0 and 0.1.1 archives are retained.

## Trailer

[Watch the new 90-second trailer](../trailer/Petriverse-trailer-0.2.0.mp4). It uses native gameplay footage and the three supplied scores, with captions explaining the major mechanics.

## Rebuilding

Use Godot 4.7.2 with `--headless --path prototype --export-release` and preset `macOS`, `Windows`, or `Linux`. Mac signing uses the configured Developer ID identity. Submit the signed archive with the existing `AC_PASSWORD` Keychain profile, staple the accepted ticket, then package and verify the extracted final app. Keep source files unchanged between platform exports; compare game-pack hashes before signing the final Mac package. Credentials are never stored in this project.
