# Petriverse 0.2.3 trailer

[Final 90-second trailer](../Petriverse-trailer-0.2.3.mp4) · 1920×1080 · 30 fps · H.264 · stereo AAC

This is a new edit from **18 native Godot gameplay shots** captured against the 0.2.3 source. It opens on Mother, demonstrates a real membrane capture, poison nudge, amoeba cell rescue, and bacteriophage infection, then shows Mother changing from three to seven visible organelles, a creature's independent film, the current fifteen-encounter route choice, all three biomes, a late hunter wave, the three bosses, and the home pond. Captions and camera framing are added over the native game simulation. The film and hunter wave run through the game's actual systems, with isolated staged state; no player save is used or changed.

`timeline.json` lists the cut points. `footage/*.json` records each shot's simulation checks and sound events. `contact-sheet.jpg` previews the finished edit. The final file passed 90-second, codec, frame-rate, resolution, stereo, and audio sample-rate checks in `validation.json`.

The mix uses the three supplied Petriverse scores, pond ambience, and the gameplay effects recorded by the captures. `audio/mix.json`, `audio/provenance.json`, and `audio/mastering.json` retain placements, source information, and loudness measurements. No generation service or credits were used for this trailer.

From the project root, rebuild with `python3 tools/render_petriverse_trailer.py` followed by `python3 tools/edit_petriverse_trailer.py`. Native capture needs Godot 4.7.2 and a graphics display; editing needs FFmpeg and FFprobe. Existing 0.2.0 and Microverse trailers remain available separately.
