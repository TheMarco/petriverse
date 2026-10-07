#!/usr/bin/env python3
"""Rebuild the 90-second trailer from native footage and its audio source stems."""
import json
import subprocess
import textwrap
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "trailer"
GAME_AUDIO = ROOT / "prototype/assets/audio"
FFMPEG = "/opt/homebrew/bin/ffmpeg"
RATE = 48000
SECONDS = 90
N = RATE * SECONDS

def decode(path, filters=None):
    args=[FFMPEG,"-v","error","-i",str(path)]
    if filters:
        args += ["-af",filters]
    args += ["-ac","2","-ar",str(RATE),"-f","f32le","-"]
    return np.frombuffer(subprocess.check_output(args),np.float32).reshape(-1,2).copy()

def put(destination, audio, at, gain=1.0, fade_in=0.025, fade_out=0.1):
    start=round(at*RATE)
    end=min(N,start+len(audio))
    audio=audio[:end-start].copy()
    head=min(len(audio),round(fade_in*RATE))
    tail=min(len(audio),round(fade_out*RATE))
    if head:
        audio[:head] *= np.linspace(0,1,head,dtype=np.float32)[:,None]
    if tail:
        audio[-tail:] *= np.linspace(1,0,tail,dtype=np.float32)[:,None]
    destination[start:end] += audio * gain

def voice_bounds(audio):
    # Reject the isolated encoder ticks in otherwise silent file tails. Preserve
    # all spoken tails with a quarter-second margin after sustained signal.
    size=960
    mono=audio.mean(axis=1)
    blocks=mono[:len(mono)//size*size].reshape(-1,size)
    rms=np.sqrt(np.mean(blocks**2,axis=1))
    sustained=np.convolve((rms>0.008).astype(float),np.ones(4),mode="same")>=3
    active=np.flatnonzero(sustained)
    if not len(active):
        raise ValueError("Silent voiceover")
    return max(0,int(active[0]*size)-round(.09*RATE)), min(len(audio),int((active[-1]+1)*size)+round(.25*RATE))

def wav(path,audio):
    subprocess.run([FFMPEG,"-v","error","-y","-f","f32le","-ar",str(RATE),"-ac","2",
                    "-i","-","-c:a","pcm_s24le",str(path)],input=audio.astype(np.float32).tobytes(),check=True)

def timestamp(seconds):
    milliseconds=round(seconds*1000)
    return f"{milliseconds//3600000:02}:{milliseconds//60000%60:02}:{milliseconds//1000%60:02},{milliseconds%1000:03}"

def main():
    timeline=json.loads((OUT/"timeline.json").read_text())
    clips=json.loads((OUT/"narration.json").read_text())
    clips.insert(0,{"id":"01-hook","at":0.85,"text":"In a single drop of water... a whole world is fighting to survive.","creation":{"identifier":"vQ7ErxDa47","credits":16}})
    # The longer evolution sentence deliberately anticipates the scene cut.
    for clip in clips:
        if clip["id"]=="07-evolve": clip["at"]=47.15
        if clip["id"]=="08-worlds": clip["at"]=56.65
    voices=np.zeros((N,2),np.float32)
    bed=np.zeros_like(voices)
    effects=np.zeros_like(voices)
    subtitle_lines=[]
    mix_clips=[]
    for i,clip in enumerate(clips,1):
        source=OUT/"audio"/(clip["id"]+".mp3")
        raw=decode(source)
        first,last=voice_bounds(raw)
        trimmed=raw[first:last]
        # Use native loudness normalization consistently across separately
        # directed phrases before the complete mix is mastered.
        temporary=OUT/"audio"/(clip["id"]+"-trim.wav")
        wav(temporary,trimmed)
        spoken=decode(temporary,"highpass=f=75,loudnorm=I=-18:TP=-2.5:LRA=7")
        put(voices,spoken,clip["at"],1.0,.008,.045)
        end=clip["at"]+len(spoken)/RATE
        mix_clips.append({"id":clip["id"],"start":clip["at"],"end":round(end,3),"source_trim":[round(first/RATE,3),round(last/RATE,3)],"text":clip["text"]})
        subtitle_lines += [str(i),f"{timestamp(clip['at'])} --> {timestamp(end-.05)}",textwrap.fill(clip["text"],width=58),""]
        print(f"Voice {clip['id']}: {clip['at']:.2f}–{end:.2f}",flush=True)
    for previous,current in zip(mix_clips,mix_clips[1:]):
        if previous["end"]>current["start"]:
            raise ValueError(f"Overlapping narration: {previous['id']} / {current['id']}")
    # An arc of original in-game music, with overlapping transitions.
    def music(name,start,length,gain,fade_in,fade_out,source_at=0):
        audio=decode(GAME_AUDIO/(name+".ogg"))
        audio=audio[round(source_at*RATE):round((source_at+length)*RATE)]
        put(bed,audio,start,gain,fade_in,fade_out)
    music("stillwater",0,56,.8,2.0,8.0)
    music("glassgarden",48,28,.92,7.0,7.0)
    music("deepwater",68,20,1.08,6.0,5.0)
    music("stillwater",81,9,.9,3.0,2.0,32)
    music("hunter-layer",33,16,.42,3.0,3.0)
    music("tension-layer",71,13,.55,4.0,1.5)
    music("current-layer",54,16,.24,3.0,3.0)
    pond=decode(GAME_AUDIO/"pond.ogg")
    for start in [0,22,44,66,88]: put(bed,pond,start,.17,1.0,1.0)
    levels={"connect":.55,"close":.55,"absorb":.68,"injury":.78,"evolve":.72,"mastery":.65,"victory":.48}
    event_log=[]
    for shot in timeline:
        report=json.loads((OUT/"footage"/(shot["shot"]+".json")).read_text())
        if report["failures"]:
            raise ValueError(f"Gameplay verification failed: {shot['shot']}")
        for event in report["events"]:
            sound=event["sound"]
            at=shot["start"]+event["time"]
            put(effects,decode(GAME_AUDIO/(sound+".ogg")),at,levels[sound])
            event_log.append({"at":round(at,3),"sound":sound})
            if "guardian" in event.get("capture",{}).get("mastery",[]):
                put(effects,decode(GAME_AUDIO/"mastery.ogg"),at+.45,levels["mastery"])
    put(effects,decode(GAME_AUDIO/"victory.ogg"),83.1,levels["victory"],.15,1.1)
    # Smooth voice-dependent music ducking, with a gentle 250 ms attack and
    # 650 ms recovery. Quiet pauses retain the original score's motion.
    block=480
    energy=np.sqrt(np.mean(voices.reshape(-1,block,2)**2,axis=(1,2)))
    target=np.where(energy>.014,.48,1.0)
    duck=np.empty_like(target)
    value=1.0
    for i,desired in enumerate(target):
        coefficient=.075 if desired<value else .022
        value += (desired-value)*coefficient
        duck[i]=value
    envelope=np.interp(np.arange(N),np.arange(len(duck))*block,duck).astype(np.float32)
    bed *= envelope[:,None]
    final=voices+bed+effects
    final[-round(1.0*RATE):] *= np.linspace(1,0,round(RATE),dtype=np.float32)[:,None]
    # Scale, rather than clip, any rare overlapping transient before mastering.
    peak=float(np.max(np.abs(final)))
    final*=min(1.0,.94/peak)
    wav(OUT/"audio/trailer-premix.wav",final)
    wav(OUT/"audio/narration-stem.wav",voices)
    wav(OUT/"audio/music-and-effects-stem.wav",bed+effects)
    (OUT/"Microverse-trailer.en.srt").write_text("\n".join(subtitle_lines))
    (OUT/"audio/mix.json").write_text(json.dumps({"duration":SECONDS,"sample_rate":RATE,"voice":{"provider":"ElevenLabs via Magnific","model":"eleven_v3","voice":"Willa Ashford","catalog_voice_id":918,"generation_credits":sum(c['creation']['credits'] for c in clips)},"narration":mix_clips,"events":event_log,"music":["stillwater","glassgarden","deepwater","hunter-layer","tension-layer","current-layer","pond"]},indent=2)+"\n")
    # Two-pass integrated loudness mastering, with a safe true peak for AAC.
    analysis=subprocess.run([FFMPEG,"-hide_banner","-i",str(OUT/"audio/trailer-premix.wav"),
        "-af","loudnorm=I=-16:TP=-1.5:LRA=10:print_format=json","-f","null","-"],capture_output=True,text=True,check=True)
    statistics=json.JSONDecoder().raw_decode(analysis.stderr[analysis.stderr.rfind("{"):])[0]
    mastering=("loudnorm=I=-16:TP=-1.5:LRA=10:linear=true:"
        f"measured_I={statistics['input_i']}:measured_TP={statistics['input_tp']}:"
        f"measured_LRA={statistics['input_lra']}:measured_thresh={statistics['input_thresh']}:"
        f"offset={statistics['target_offset']}:print_format=json")
    rendered=subprocess.run([FFMPEG,"-hide_banner","-y","-i",str(OUT/"audio/trailer-premix.wav"),
        "-af",mastering,"-ar",str(RATE),"-c:a","pcm_s24le",str(OUT/"audio/trailer-master.wav")],capture_output=True,text=True,check=True)
    (OUT/"audio/mastering.json").write_text(json.dumps({"analysis":statistics,"master":json.JSONDecoder().raw_decode(rendered.stderr[rendered.stderr.rfind('{'):])[0]},indent=2)+"\n")
    (OUT/"concat.txt").write_text("".join(f"file '{OUT/shot['file']}'\n" for shot in timeline))
    subprocess.run([FFMPEG,"-hide_banner","-loglevel","error","-y","-f","concat","-safe","0","-i",str(OUT/"concat.txt"),
        "-i",str(OUT/"audio/trailer-master.wav"),"-i",str(OUT/"Microverse-trailer.en.srt"),
        "-map","0:v:0","-map","1:a:0","-map","2:0","-c:v","copy","-c:a","aac","-b:a","256k","-c:s","mov_text",
        "-metadata","title=MICROVERSE — A Small Life. A Whole World.","-metadata","comment=Native in-game footage with cinematic camera framing; isolated staged encounters.",
        "-metadata:s:s:0","language=eng","-disposition:s:0","0","-t","90","-movflags","+faststart",str(OUT/"Microverse-trailer-1080p.mp4")],check=True)
    print("Finished: trailer/Microverse-trailer-1080p.mp4",flush=True)

if __name__=="__main__":
    main()
