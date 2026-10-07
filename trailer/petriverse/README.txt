PETRIVERSE — GAME TRAILER 0.2.0

Final: ../Petriverse-trailer-0.2.0.mp4
90 seconds / 1920 x 1080 / 30 fps / H.264 / stereo AAC

17 native Godot shots show feeding and cell fusion, cyst nudging and fluid
wakes, an amoeba swallowing and releasing a rescued cell, bacteriophage
attachment and rupture, colony evolution, all three biomes, rare life,
three guardians, the populated home pond, and the Petriverse title logo.

The game simulation runs at its normal speed. Encounters are staged with
isolated temporary saves for filming; camera framing and captions are added.
No gameplay rules are changed. Per-shot reports record actual captures,
cell rescue, infection completion, and food released from the bacterium.

Music: the three supplied Petriverse scores, crossfaded with quiet pond
ambience and gameplay effects. No narration. Final encoded audio measures
-16.02 LUFS and -2.09 dBTP. Source audio details are in audio/provenance.json.

Reproduce from the repository root:
  python3 tools/render_petriverse_trailer.py
  python3 tools/edit_petriverse_trailer.py

Native capture requires Godot 4.7.2 and a graphics display. Editing requires
Python, FFmpeg and FFprobe; numpy is used when available. The scripts retain
individual clips, report files, the timeline, source mix and title frames.
