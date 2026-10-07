"""Generate original MICROVERSE audio with ElevenLabs, then master local assets.

Set ELEVENLABS_API_KEY in the process environment. The key is never saved.
Existing originals are reused; requests and non-secret provenance are retained.
Use --only connect to validate a representative effect before generating the set.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import urllib.error
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "artifacts/audio-source"
OUT = ROOT / "prototype/assets/audio"


def effect(name, description, seconds, loop=False):
    prompt = description + " No voices, harsh transients or distortion. Quiet microscopic pond-game sound design."
    if len(prompt) > 450:
        raise ValueError(f"{name}: sound-effect prompt exceeds the provider's 450-character limit")
    return {"name": name, "endpoint": "sound-generation", "request": {
        "text": prompt,
        "duration_seconds": seconds, "loop": loop, "prompt_influence": .65,
        "model_id": "eleven_text_to_sound_v2"}, "loop": loop}


ASSETS = [
    effect("connect", "One single tiny rounded water droplet with a warm delicate glass resonance, a soft musical A4 note. Immediate gentle pluck at time zero, short clean decay into silence. Intimate, tactile, tranquil, almost ASMR. Not a cartoon pop or a computer beep. No background ambience or music.", .65),
    effect("close", "One delicate organic membrane closing: a rounded liquid tuck softly blooming into a luminous consonant A major suspended glass chord. Immediate tactile onset, smooth airy resonance, quiet satisfying resolution, soft short tail. No beat or background music.", 1.5),
    effect("absorb", "A tiny translucent cell draws liquid inward, slowly dissolves and absorbs another cell: very soft swirling viscous water, fine wet granular fizz and a few microscopic bubbles, ending in a warm pearlescent exhale. Beautiful, delicate and nourishing, not disgusting. Quiet close-up texture, no big splash, suction horror or bass impact. No music.", 2.5),
    effect("injury", "One fragile living membrane gently tears under water, a muted rounded low droplet followed by a short descending glass sigh and fine bubbles escaping. Tender, melancholy, immediately noticeable but never alarming. Quiet isolated game feedback, no crunch or explosion. No music.", 1.8),
    effect("fracture", "A tiny opalescent microscopic shell flexes and fractures, a very soft fine crystalline tick inside thick water, followed by a delicate shimmering sandy exhale. Immediate rounded onset, gentle and satisfying, no shattering glass crash. No music.", 1.0),
    effect("evolve", "One serene ascending blossom of soft glass harmonics in A major pentatonic, like an underwater flower opening, with a tiny breath of liquid bubbles. A tender three-note musical reward, warm luminous airy tail, unhurried, soothing and intimate. No beat, fanfare or background track.", 4.0),
    effect("warning", "One very quiet low rounded resonant water bell, soft A3 fundamental and airy glass overtones, slowly blooming then fading. Calm attention cue for a fragile organism, not an alarm. No ticking, no sharp ping, no music bed.", 1.6),
    effect("victory", "A gentle luminous resolution of three slowly blooming soft glass chords in A major, warm airy harmonics, an intimate underwater garden opening into light. Peaceful accomplishment, soothing and emotional, no celebratory fanfare, percussion or rhythmic beat.", 6.0),
    effect("loss", "A tender falling pair of softly bowed glass notes over a fading low warm water resonance, a fragile life returning to the pond. Bittersweet, accepting and peaceful, not ominous or dramatic. Quiet tail into silence, no percussion.", 4.0),
    effect("pond", "Seamless almost-silent underwater micro-ambience. A soft warm current with scattered extremely tiny distant liquid bubbles and a faint silky aqueous rustle. Sparse, spacious, calm, close and delicate, no large ocean waves, birds, wind, splashes, heartbeat, melody or music. Consistent level, no beginning or ending.", 24.0, True),
    {"name": "stillwater", "endpoint": "music", "request": {
        "prompt": "Original instrumental ambient meditation score for a beautiful microscopic pond ecosystem. Deeply soothing, spacious, intimate and quietly wondrous. A major pentatonic tonal center with gentle suspended harmonies, warm soft analog pads breathing very slowly, sparse felt-like glass mallet notes with beautifully rounded attacks, delicate distant bowed glass harmonics, subtle liquid granular texture. Lots of silence between melodic gestures. A floating sense of 48 BPM without any drums or explicit rhythm. Slow graceful harmonic evolution, restrained dynamic range, no tension build, no dramatic climax. Never saccharine, never a stock spa melody. Wide natural space, soft upper frequencies, clear warm low midrange, no heavy sub bass. A continuous living soundscape from first second to last, end in the same A suspended harmonic bed for a smooth long crossfade to the opening. No fade to silence, no finale. No percussion, ostinato, arpeggiator, vocals, voices, choir, singing or speech.",
        "music_length_ms": 120000, "force_instrumental": True, "model_id": "music_v2"}, "loop": True},
    {"name": "deepwater", "endpoint": "music", "request": {
        "prompt": "Original instrumental ambient meditation music for discovering a majestic two-hearted microscopic organism in a dark blue pond. Peaceful concentration and compassionate wonder, never battle music. A major pentatonic, warm slowly breathing low pads, airy bowed glass, very sparse soft rounded glass mallet notes, a few deep velvety water resonances, wide dreamy natural reverberation. The sensation of 48 BPM, no drums or explicit beat. Slightly deeper and more enveloping than a tranquil garden, still very soothing, gentle and safe. Gradual harmonic movement with suspended chords, no dramatic swells or tension risers, no harsh sounds, no ominous dissonance. Restrained even volume. Continuous atmosphere from beginning to end, finish in the same A suspended harmonic bed to crossfade seamlessly to the opening. No fade to silence or final cadence. No percussion, ostinato, arpeggiators, vocals, voices, singing, choir or speech.",
        "music_length_ms": 90000, "force_instrumental": True, "model_id": "music_v2"}, "loop": True},
    {"name": "glassgarden", "endpoint": "music", "request": {
        "prompt": "Original instrumental ambient score for a microscopic garden of etched glass diatoms. Meditative, intimate, curious, spacious. A major pentatonic with sustained A and E overtones, sparse tiny felted celesta gestures, resonant glass bowls, soft brushed crystal harmonics and warm velvety pads. More translucent and crystalline than a pond score but never shrill or tinkling. No drum beat, no rhythmic ostinato, no ticking, no arpeggiator, no dramatic rise or finale. Extremely gentle dynamic range with long breathing spaces. Sensation of 48 BPM without explicit pulse. Rounded attacks and softened treble. A continuous living atmosphere from first to last second, ending on the same suspended A harmony to allow a five-second crossfade. No fade to silence. Absolutely no voices, singing, choir, speech, percussion or heavy bass.",
        "music_length_ms": 120000, "force_instrumental": True, "model_id": "music_v2"}, "loop": True},
    effect("current-layer", "Seamless soft watery texture for a living microscopic current. A warm airy liquid rustle with tiny silk-like bubbles, breathing slowly in irregular waves. Very sparse and delicate, calm anticipation without alarm or ticking. No distinct melody, beat, impact or large splash. Even level, no beginning or ending.", 24.0, True),
    effect("tension-layer", "Seamless extremely gentle low bowed-glass resonance on A2 and E3, floating in thick quiet water. Slow breathing and fine silky aqueous grain. Peaceful alert concentration, tender and protective, never frightening. No beat, ticking, riser, crescendo or sub-bass. Stable suspended harmony, no melody or ending.", 24.0, True),
    effect("mastery", "One small beautiful musical blossom: three rounded liquid-glass notes A5 E6 B6 spread gently over two seconds, overlapping warm shimmering overtones and a soft pearly water exhale. Restrained, intimate, satisfying discovery. Smooth quiet decay, no fanfare, percussion or background track.", 3.8),
    effect("nimble-layer", "Seamless sparse rounded liquid-glass micro-plucks on A5 E6 B5, with long quiet spaces and delicate floating tails. Intimate, light, curious, meditative. Irregular natural timing, no repeated rhythmic pattern, beat, ticking or sharp treble. Stable suspended harmony, no beginning or ending.", 24.0, True),
    effect("feast-layer", "Seamless warm bowed-glass resonance on A3 E4, broad velvety overtones breathing in very slow gentle swells. Spacious, nourishing, meditative, rich but transparent. No melodic sequence, beat, pulsing bass, ticking or dramatic rise. Soft upper frequencies, no beginning or ending.", 24.0, True),
    effect("hunter-layer", "Seamless soft protective harmonics on A4 E5 B4, slowly overlapping bell-glass tones and a fine airy watery halo. Tender, watchful, reassuring, meditative. No alarm, tension rise, melody, beat, ticking, bass impact, choir or voices. Restrained treble, continuous quiet texture, no beginning or ending.", 24.0, True),
]


def generate(asset, key):
    name = asset["name"]
    original = SOURCE / (name + ".mp3")
    metadata = SOURCE / (name + ".json")
    if not original.exists():
        request = urllib.request.Request(
            "https://api.elevenlabs.io/v1/" + asset["endpoint"] + "?output_format=mp3_44100_128",
            data=json.dumps(asset["request"]).encode(),
            headers={"xi-api-key": key, "Content-Type": "application/json"}, method="POST")
        try:
            with urllib.request.urlopen(request, timeout=360) as response:
                data = response.read()
                if not response.headers.get("Content-Type", "").startswith(("audio/", "application/octet-stream")):
                    raise ValueError("Provider returned non-audio content")
                if len(data) < 1000:
                    raise ValueError("Provider returned an empty audio asset")
                temporary = original.with_suffix(".partial")
                temporary.write_bytes(data)
                temporary.replace(original)
                metadata.write_text(json.dumps({"provider": "ElevenLabs", **asset,
                    "request_id": response.headers.get("request-id"),
                    "credit_cost": response.headers.get("character-cost"),
                    "sha256": hashlib.sha256(data).hexdigest()}, indent=2) + "\n")
        except urllib.error.HTTPError as error:
            detail = error.read().decode(errors="replace").replace(key, "[redacted]")
            raise RuntimeError(f"{name}: HTTP {error.code}: {detail[:450]}") from None
    master(asset, original)
    return {"asset": name, "status": "ready", "bytes": original.stat().st_size}


def master(asset, original):
    destination = OUT / (asset["name"] + ".ogg")
    if destination.exists() and destination.stat().st_size > 1024:
        return
    # Music loops are crossfaded at runtime. Keep a consistent quiet source mix.
    if asset["endpoint"] == "music":
        filters = "highpass=f=45,lowpass=f=9500,loudnorm=I=-23:TP=-3:LRA=7"
    elif asset["loop"]:
        filters = "highpass=f=80,lowpass=f=6000,loudnorm=I=-29:TP=-5:LRA=5"
    else:
        # Remove generator lead-in so connecting a node responds immediately.
        filters = "silenceremove=start_periods=1:start_duration=0.008:start_threshold=-48dB,highpass=f=65,lowpass=f=8500,loudnorm=I=-23:TP=-4:LRA=6,afade=t=in:d=0.006"
    encoders = subprocess.run(["ffmpeg", "-hide_banner", "-encoders"], capture_output=True,
                              text=True, check=True).stdout
    codec = ["-c:a", "libvorbis"] if "libvorbis" in encoders else ["-c:a", "vorbis", "-strict", "experimental"]
    temporary = destination.with_suffix(".partial.ogg")
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(original), "-af", filters,
                    "-ar", "44100", "-ac", "2", *codec, "-q:a", "5", str(temporary)], check=True)
    temporary.replace(destination)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--only", nargs="*")
    args = parser.parse_args()
    key = os.environ.get("ELEVENLABS_API_KEY")
    if not key:
        raise SystemExit("Set ELEVENLABS_API_KEY in the process environment.")
    SOURCE.mkdir(parents=True, exist_ok=True)
    OUT.mkdir(parents=True, exist_ok=True)
    for asset in ASSETS:
        if args.only and asset["name"] not in args.only:
            continue
        try:
            print(json.dumps(generate(asset, key)), flush=True)
        except Exception as error:
            # Never print request headers, environment variables or traceback locals.
            raise SystemExit(str(error).replace(key, "[redacted]")) from None
    available = []
    for asset in ASSETS:
        if (OUT / (asset["name"] + ".ogg")).exists():
            # Retain the exact request that produced reused originals.
            metadata = SOURCE / (asset["name"] + ".json")
            available.append(json.loads(metadata.read_text()) if metadata.exists() else asset)
    (OUT / "provenance.json").write_text(json.dumps({"provider": "ElevenLabs",
        "documentation": ["https://elevenlabs.io/docs/api-reference/music/compose",
                          "https://elevenlabs.io/docs/api-reference/text-to-sound-effects/convert"],
        "mastering": "44.1kHz Vorbis, gentle bandwidth shaping, -23 LUFS music/effects, -29 LUFS pond. Short effects have lead-in silence removed. Runtime mixer adds headroom and crossfades music.",
        "assets": available}, indent=2) + "\n")


if __name__ == "__main__":
    main()
