#!/usr/bin/env python3
"""Bounded offline editor for the 90-second Petriverse game trailer.

Reads native capture clips plus per-shot JSON reports from
``<root>/trailer/petriverse-0.2.3/footage/`` and encodes the final trailer to
``<root>/trailer/Petriverse-trailer-0.2.3.mp4`` (1920x1080 H264 yuv420p,
30fps, AAC stereo 192kbps, +faststart, exactly 90s).

Conventions follow tools/edit_trailer.py (numpy premix helpers, two-pass
ffmpeg loudnorm mastering) and tools/render_trailer.py (per-shot mp4 +
report.json evidence). No narration, no added typography or subtitles:
source clips carry native in-game titles.

Audio uses ONLY the supplied scores in prototype/assets/audio:
petriverse-stillwater.ogg (0-37), petriverse-glassgarden.ogg (32-66),
petriverse-blue-deep.ogg (60-90), pond.ogg ambience at ~0.12 gain, plus
real capture-report sound events at restrained levels. No old
harmonic/colony layers, no invented events or footage.
"""
import argparse
import json
import shutil
import subprocess
import sys
from pathlib import Path

try:
    import numpy as np
except ImportError:
    np = None

RATE = 48000
SECONDS = 90
N = RATE * SECONDS
TARGET_NAME = "Petriverse-trailer-0.2.3.mp4"

# Exact cut timeline in seconds (total 90). Never retimed: straight cuts
# (or an optional short fade that preserves every boundary and the total).
SHOTS = [
    ("hook", 5), ("reveal", 4), ("loop", 7), ("fluid", 3),
    ("amoeba", 10), ("phages", 12), ("mother_growth", 6),
    ("film", 6), ("route_choice", 4),
    ("world_a", 3), ("world_b", 3), ("world_c", 3),
    ("final_wave", 5),
    ("boss_a", 3), ("boss_b", 3), ("boss_c", 3),
    ("home", 4), ("end", 6),
]

# (track, timeline_start, timeline_end, fade_in, fade_out). Each source
# starts at its own beginning.
MUSIC_CUES = [
    ("petriverse-stillwater", 0, 35, 2.0, 5.0),
    ("petriverse-glassgarden", 30, 68, 5.0, 6.0),
    ("petriverse-blue-deep", 62, 90, 6.0, 2.0),
]
MUSIC_GAINS = {
    "petriverse-stillwater": 0.80,
    "petriverse-glassgarden": 0.90,
    "petriverse-blue-deep": 1.00,
}
POND_GAIN = 0.12

# Restrained per-effect gains. Unknown-but-existing Ogg effects fall back
# to DEFAULT_EFFECT_GAIN; missing Ogg files are a hard failure.
EFFECT_LEVELS = {
    "connect": 0.55, "close": 0.55, "absorb": 0.68, "injury": 0.78,
    "evolve": 0.72, "mastery": 0.65, "victory": 0.48, "fracture": 0.70,
    "loss": 0.55, "warning": 0.60,
}
DEFAULT_EFFECT_GAIN = 0.60


def fail(message):
    raise SystemExit(f"ERROR: {message}")


def which_tool(name):
    path = shutil.which(name)
    if not path:
        fail(f"required tool not in PATH: {name}")
    return path


def build_timeline():
    timeline = []
    start = 0.0
    for shot, duration in SHOTS:
        timeline.append({"shot": shot, "start": start, "duration": duration,
                         "file": f"footage/{shot}.mp4"})
        start += duration
    assert round(start) == SECONDS, f"timeline totals {start}s, want {SECONDS}s"
    return timeline


# --- numpy premix helpers (same concept as tools/edit_trailer.py) ---

def np_decode(ffmpeg, path, length=None):
    args = [ffmpeg, "-v", "error", "-i", str(path),
            "-ac", "2", "-ar", str(RATE), "-f", "f32le", "-"]
    raw = np.frombuffer(subprocess.check_output(args), np.float32)
    audio = raw.reshape(-1, 2).copy()
    return audio[:round(length * RATE)] if length else audio


def np_put(dest, audio, at, gain=1.0, fade_in=0.025, fade_out=0.1):
    start = round(at * RATE)
    end = min(N, start + len(audio))
    if end <= start:
        return
    audio = audio[:end - start].copy()
    head = min(len(audio), round(fade_in * RATE))
    tail = min(len(audio), round(fade_out * RATE))
    if head:
        audio[:head] *= np.linspace(0, 1, head, dtype=np.float32)[:, None]
    if tail:
        audio[-tail:] *= np.linspace(1, 0, tail, dtype=np.float32)[:, None]
    dest[start:end] += audio * gain


def np_wav(ffmpeg, path, audio):
    path.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run([ffmpeg, "-v", "error", "-y", "-f", "f32le",
                    "-ar", str(RATE), "-ac", "2", "-i", "-",
                    "-c:a", "pcm_s24le", str(path)],
                   input=audio.astype(np.float32).tobytes(), check=True)


def check_reports(timeline, footage_dir):
    """Load and validate every per-shot report. Returns {shot: report}."""
    reports = {}
    for shot in timeline:
        name = shot["shot"]
        clip = footage_dir / f"{name}.mp4"
        report_path = footage_dir / f"{name}.json"
        if not clip.exists():
            fail(f"missing footage clip (will not invent footage): {clip}")
        if not report_path.exists():
            fail(f"missing capture report: {report_path}")
        report = json.loads(report_path.read_text())
        if report.get("failures"):
            fail(f"capture failures recorded for shot '{name}': "
                 f"{report['failures']}; see {report_path}")
        for event in report.get("events", []):
            t = event.get("time")
            if t is None or not 0 <= t <= shot["duration"]:
                fail(f"event time {t} outside shot '{name}' "
                     f"(0-{shot['duration']}s): {event}")
            if "sound" not in event:
                fail(f"event without 'sound' in shot '{name}': {event}")
        reports[name] = report
    return reports


def mix_numpy(ffmpeg, game_audio, timeline, reports):
    bed = np.zeros((N, 2), np.float32)
    effects = np.zeros_like(bed)
    for name, start, end, fade_in, fade_out in MUSIC_CUES:
        src = game_audio / f"{name}.ogg"
        if not src.exists():
            fail(f"missing supplied score: {src}")
        np_put(bed, np_decode(ffmpeg, src, end - start), start,
               MUSIC_GAINS[name], fade_in, fade_out)
    pond_src = game_audio / "pond.ogg"
    if not pond_src.exists():
        fail(f"missing ambience: {pond_src}")
    pond = np_decode(ffmpeg, pond_src)
    span = len(pond) / RATE
    at = 0.0
    while at < SECONDS:
        np_put(bed, pond, at, POND_GAIN, 1.0, 1.0)
        at += span
    event_log = []
    for shot in timeline:
        for event in reports[shot["shot"]].get("events", []):
            sound = event["sound"]
            src = game_audio / f"{sound}.ogg"
            if not src.exists():
                fail(f"event sound has no Ogg effect: {src} "
                     f"(shot '{shot['shot']}', will not invent audio)")
            at = shot["start"] + event["time"]
            gain = EFFECT_LEVELS.get(sound, DEFAULT_EFFECT_GAIN)
            np_put(effects, np_decode(ffmpeg, src), at, gain)
            event_log.append({"at": round(at, 3), "sound": sound,
                              "gain": gain, "shot": shot["shot"]})
    return bed, effects, event_log


def mix_ffmpeg_filters(ffmpeg, game_audio, timeline, reports, premix_path):
    """Fallback mix without numpy: one amix filter graph into premix.wav."""
    inputs = []
    filters = []
    labels = []
    idx = 0

    def add_input(path, extra=()):
        nonlocal idx
        inputs.extend([*extra, "-i", str(path)])
        label = f"[{idx}:a]"
        idx += 1
        return label

    for name, start, end, fade_in, fade_out in MUSIC_CUES:
        src = game_audio / f"{name}.ogg"
        if not src.exists():
            fail(f"missing supplied score: {src}")
        gain = MUSIC_GAINS[name]
        filters.append(
            f"{add_input(src)}atrim=0:{end - start},asetpts=PTS-STARTPTS,"
            f"afade=t=in:st=0:d={fade_in},afade=t=out:st={end - start - fade_out}:d={fade_out},"
            f"volume={gain},adelay={round(start * 1000)}|{round(start * 1000)}[m{len(labels)}]")
        labels.append(f"[m{len(labels)}]")
    pond_src = game_audio / "pond.ogg"
    if not pond_src.exists():
        fail(f"missing ambience: {pond_src}")
    loops = 8
    filters.append(
        f"{add_input(pond_src, ('-stream_loop', str(loops)))}"
        f"atrim=0:{SECONDS},asetpts=PTS-STARTPTS,volume={POND_GAIN}[pond]")
    labels.append("[pond]")
    event_log = []
    for shot in timeline:
        for event in reports[shot["shot"]].get("events", []):
            sound = event["sound"]
            src = game_audio / f"{sound}.ogg"
            if not src.exists():
                fail(f"event sound has no Ogg effect: {src}")
            at = shot["start"] + event["time"]
            gain = EFFECT_LEVELS.get(sound, DEFAULT_EFFECT_GAIN)
            ms = round(at * 1000)
            filters.append(f"{add_input(src)}volume={gain},adelay={ms}|{ms}[e{len(labels)}]")
            labels.append(f"[e{len(labels)}]")
            event_log.append({"at": round(at, 3), "sound": sound,
                              "gain": gain, "shot": shot["shot"]})
    filters.append(f"{''.join(labels)}amix=inputs={len(labels)}:normalize=0,"
                   f"aformat=sample_fmts=fltp:channel_layouts=stereo,aresample={RATE}[mix]")
    premix_path.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run([ffmpeg, "-hide_banner", "-loglevel", "error", "-y",
                    *inputs, "-filter_complex", ";".join(filters),
                    "-map", "[mix]", "-t", str(SECONDS),
                    "-c:a", "pcm_s24le", str(premix_path)], check=True)
    return event_log


def loudnorm_two_pass(ffmpeg, premix_path, master_path):
    """Master to ~-16 LUFS / <=-1.5 dBTP; return {analysis, master} stats.

    Full ffmpeg logs are captured, not printed; only the trailing JSON
    measurement blocks are parsed.
    """
    # AAC encoding can add inter-sample peaks; reserve 0.7 dB of headroom.
    base = "loudnorm=I=-16:TP=-2.2:LRA=10:print_format=json"
    analysis = subprocess.run(
        [ffmpeg, "-hide_banner", "-i", str(premix_path),
         "-af", base, "-f", "null", "-"],
        capture_output=True, text=True, check=True)
    stats = json.JSONDecoder().raw_decode(
        analysis.stderr[analysis.stderr.rfind("{"):])[0]
    mastering = ("loudnorm=I=-16:TP=-2.2:LRA=10:linear=true:"
                 f"measured_I={stats['input_i']}:measured_TP={stats['input_tp']}:"
                 f"measured_LRA={stats['input_lra']}:measured_thresh={stats['input_thresh']}:"
                 f"offset={stats['target_offset']}:print_format=json")
    rendered = subprocess.run(
        [ffmpeg, "-hide_banner", "-y", "-i", str(premix_path),
         "-af", mastering, "-ar", str(RATE), "-c:a", "pcm_s24le",
         str(master_path)], capture_output=True, text=True, check=True)
    master = json.JSONDecoder().raw_decode(
        rendered.stderr[rendered.stderr.rfind("{"):])[0]
    return {"analysis": stats, "master": master}


def video_filter(timeline, transition):
    parts = []
    for i, shot in enumerate(timeline):
        dur = shot["duration"]
        chain = (f"[{i}:v]trim=start=0:end={dur},setpts=PTS-STARTPTS,"
                 f"scale=1920:1080:flags=lanczos,setsar=1,fps=30,format=yuv420p")
        if transition == "fade":
            dt = 0.12
            if i > 0:
                chain += f",fade=t=in:st=0:d={dt}"
            if i < len(timeline) - 1:
                chain += f",fade=t=out:st={dur - dt}:d={dt}"
        chain += f"[v{i}]"
        parts.append(chain)
    parts.append(f"{''.join(f'[v{i}]' for i in range(len(timeline)))}"
                 f"concat=n={len(timeline)}:v=1:a=0[v]")
    return ";".join(parts)


def validate(ffprobe, out_path):
    probe = subprocess.run(
        [ffprobe, "-v", "error", "-print_format", "json",
         "-show_format", "-show_streams", str(out_path)],
        capture_output=True, text=True, check=True)
    data = json.loads(probe.stdout)
    streams = {s.get("codec_type"): s for s in data.get("streams", [])}
    video, audio = streams.get("video"), streams.get("audio")
    errors = []
    if not video or video.get("codec_name") != "h264":
        errors.append("video codec is not h264")
    if not video or (video.get("width"), video.get("height")) != (1920, 1080):
        errors.append("video is not 1920x1080")
    fps = video.get("avg_frame_rate", "") if video else ""
    try:
        num, den = (float(x) for x in fps.split("/"))
        fps_val = num / den if den else 0
    except ValueError:
        fps_val = 0
    if abs(fps_val - 30) > 0.1:
        errors.append(f"video fps is {fps}, want 30")
    if video and video.get("pix_fmt") != "yuv420p":
        errors.append(f"pix_fmt is {video.get('pix_fmt')}, want yuv420p")
    if not audio or audio.get("codec_name") != "aac":
        errors.append("audio codec is not aac")
    if audio and int(audio.get("channels", 0)) != 2:
        errors.append("audio is not stereo")
    if audio and audio.get("sample_rate") != "48000":
        errors.append(f"audio sample rate is {audio.get('sample_rate')}, want 48000")
    try:
        duration = float(data.get("format", {}).get("duration", 0))
    except ValueError:
        duration = 0
    if abs(duration - SECONDS) > 0.15:
        errors.append(f"duration is {duration:.3f}s, want exactly {SECONDS}s")
    return data, errors


def dry_run(root, transition):
    ffmpeg = shutil.which("ffmpeg")
    ffprobe = shutil.which("ffprobe")
    print(f"root: {root}")
    print(f"ffmpeg: {ffmpeg or 'MISSING from PATH'}")
    print(f"ffprobe: {ffprobe or 'MISSING from PATH'}")
    print(f"numpy: {'yes' if np is not None else 'no (ffmpeg-filter fallback)'}")
    print(f"transition: {transition} (total stays {SECONDS}s, no retiming)")
    timeline = build_timeline()
    print(f"timeline: {len(timeline)} shots, "
          f"{sum(s['duration'] for s in timeline)}s total")
    footage_dir = root / "trailer/petriverse-0.2.3/footage"
    game_audio = root / "prototype/assets/audio"
    missing = []
    for shot in timeline:
        for suffix in (".mp4", ".json"):
            path = footage_dir / f"{shot['shot']}{suffix}"
            mark = "ok" if path.exists() else "MISSING"
            if not path.exists():
                missing.append(str(path))
            print(f"  [{mark}] {path.relative_to(root)}")
    for name, start, end, fade_in, fade_out in MUSIC_CUES:
        src = game_audio / f"{name}.ogg"
        mark = "ok" if src.exists() else "MISSING"
        if not src.exists():
            missing.append(str(src))
        print(f"  [{mark}] {src.relative_to(root)} "
              f"(timeline {start}-{end}, fade {fade_in}/{fade_out}s)")
    pond = game_audio / "pond.ogg"
    print(f"  [{'ok' if pond.exists() else 'MISSING'}] "
          f"{pond.relative_to(root)} (ambience, gain {POND_GAIN})")
    if not pond.exists():
        missing.append(str(pond))
    print(f"output: trailer/{TARGET_NAME}")
    if not ffmpeg or not ffprobe:
        fail("ffmpeg/ffprobe must be in PATH")
    if missing:
        print(f"DRY RUN: {len(missing)} required input(s) missing; "
              f"real run would fail without inventing footage.")
    else:
        print("DRY RUN: all inputs present.")


def edit(root, transition):
    ffmpeg = which_tool("ffmpeg")
    ffprobe = which_tool("ffprobe")
    petra = root / "trailer/petriverse-0.2.3"
    footage_dir = petra / "footage"
    game_audio = root / "prototype/assets/audio"
    out_path = root / "trailer" / TARGET_NAME
    audio_dir = petra / "audio"
    audio_dir.mkdir(parents=True, exist_ok=True)

    timeline = build_timeline()
    (petra / "timeline.json").write_text(json.dumps(timeline, indent=2) + "\n")
    (petra / "concat.txt").write_text(
        "".join(f"file '{footage_dir / (s['shot'] + '.mp4')}'\n" for s in timeline))
    reports = check_reports(timeline, footage_dir)

    premix = audio_dir / "premix.wav"
    if np is not None:
        bed, effects, event_log = mix_numpy(ffmpeg, game_audio, timeline, reports)
        final = bed + effects
        tail = round(1.0 * RATE)
        final[-tail:] *= np.linspace(1, 0, tail, dtype=np.float32)[:, None]
        peak = float(np.max(np.abs(final)))
        if peak > 0:
            final *= min(1.0, 0.94 / peak)
        np_wav(ffmpeg, premix, final)
        np_wav(ffmpeg, audio_dir / "music-stem.wav", bed)
        np_wav(ffmpeg, audio_dir / "effects-stem.wav", effects)
        mixer = "numpy"
    else:
        event_log = mix_ffmpeg_filters(ffmpeg, game_audio, timeline, reports, premix)
        mixer = "ffmpeg-filters"

    master = audio_dir / "master.wav"
    mastering = loudnorm_two_pass(ffmpeg, premix, master)
    (audio_dir / "mastering.json").write_text(
        json.dumps(mastering, indent=2) + "\n")

    mix = {"duration": SECONDS, "sample_rate": RATE, "mixer": mixer,
           "music": [{"track": n, "file": f"prototype/assets/audio/{n}.ogg",
                      "timeline": [s, e], "fade_in": fi, "fade_out": fo,
                      "source_offset": 0, "gain": MUSIC_GAINS[n]}
                     for n, s, e, fi, fo in MUSIC_CUES],
           "ambience": {"track": "pond",
                        "file": "prototype/assets/audio/pond.ogg",
                        "gain": POND_GAIN, "loop": True},
           "events": event_log, "narration": None, "subtitles": None}
    (audio_dir / "mix.json").write_text(json.dumps(mix, indent=2) + "\n")
    provenance = {
        "scores": "User-supplied scores in prototype/assets/audio "
                  "(petriverse-stillwater/glassgarden/blue-deep); see "
                  "prototype/assets/audio/provided-scores-provenance.json. "
                  "No ElevenLabs-generated music; no old harmonic/colony layers.",
        "tracks": mix["music"], "ambience": mix["ambience"],
        "effects_source": "Existing Ogg effects in prototype/assets/audio, "
                          "placed at capture-report event times (already "
                          "per-shot aligned); no invented events.",
        "mastering": {"target": "-16 LUFS, <=-1.5 dBTP, LRA 10",
                      "measured": mastering["master"]},
    }
    (audio_dir / "provenance.json").write_text(
        json.dumps(provenance, indent=2) + "\n")

    inputs = []
    for shot in timeline:
        inputs += ["-i", str(footage_dir / f"{shot['shot']}.mp4")]
    inputs += ["-i", str(master)]
    subprocess.run(
        [ffmpeg, "-hide_banner", "-loglevel", "error", "-y", *inputs,
         "-filter_complex", video_filter(timeline, transition),
         "-map", "[v]", "-map", f"{len(timeline)}:a:0",
         "-c:v", "libx264", "-preset", "medium", "-crf", "18", "-threads", "8",
         "-pix_fmt", "yuv420p", "-r", "30",
         "-c:a", "aac", "-b:a", "192k", "-ac", "2", "-ar", "48000",
         "-t", str(SECONDS), "-movflags", "+faststart",
         "-metadata", "title=PETRIVERSE 0.2.3 — 90-second game trailer",
         str(out_path)], check=True)

    probe_data, errors = validate(ffprobe, out_path)
    (petra / "validation.json").write_text(
        json.dumps({"file": f"trailer/{TARGET_NAME}", "errors": errors,
                    "ffprobe": probe_data}, indent=2) + "\n")
    if errors:
        fail(f"validation failed for {out_path}: {'; '.join(errors)}")

    poster = petra / "poster.jpg"
    still = subprocess.run(
        [ffmpeg, "-hide_banner", "-loglevel", "error", "-y",
         "-ss", "6.5", "-i", str(out_path), "-frames:v", "1", str(poster)])
    report = {"edit": [s["shot"] for s in timeline], "transition": transition,
              "output": f"trailer/{TARGET_NAME}",
              "poster": f"trailer/petriverse-0.2.3/{poster.name}" if still.returncode == 0 else None,
              "mixer": mixer, "events_mixed": len(event_log),
              "validation_errors": errors}
    (petra / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    if still.returncode:
        print("WARNING: poster frame at 6.5s failed; trailer is complete without it.",
              file=sys.stderr)
    print(f"Finished: trailer/{TARGET_NAME}")


def main(argv=None):
    parser = argparse.ArgumentParser(
        description="Edit the 90s Petriverse trailer from native captures "
                    "(offline; ffmpeg/ffprobe from PATH).")
    parser.add_argument("--root", type=Path,
                        default=Path(__file__).resolve().parents[1],
                        help="project root (default: script's parent parent)")
    parser.add_argument("--dry-run", action="store_true",
                        help="check tools/inputs and print the plan; write nothing")
    parser.add_argument("--transition", choices=["cut", "fade"], default="cut",
                        help="straight cuts (default) or a 0.12s fade-through-dark "
                             "at boundaries; both preserve the 90s total")
    args = parser.parse_args(argv)
    if args.dry_run:
        dry_run(args.root, args.transition)
    else:
        edit(args.root, args.transition)


if __name__ == "__main__":
    main()
