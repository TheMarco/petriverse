#!/usr/bin/env python3
"""Render isolated native gameplay shots, retaining the source edit and evidence."""
import json
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "trailer"
FRAMES = Path("/tmp/microverse-trailer-frames")
SHOTS = [("hook",8),("reveal",6),("loop",12),("nudge",8),("danger",7),
         ("defend",7),("evolve",8),("world_a",4),("world_b",4),("world_c",4),
         ("rare_a",3),("rare_b",3),("boss_a",3),("boss_b",3),("boss_c",3),("end",7)]

def main():
    wanted = sys.argv[1:]
    failures = []
    for shot, duration in SHOTS:
        if wanted and shot not in wanted:
            continue
        log = OUT / f"{shot}-capture.log"
        print(f"Capturing {shot}: {duration}s", flush=True)
        with log.open("w") as handle:
            run = subprocess.run(["/opt/homebrew/bin/godot", "--path", str(ROOT/"prototype"),
                "--script", "res://tests/trailer_capture.gd", "--log-file", f"/tmp/microverse-trailer-{shot}-engine.log",
                "--", shot], stdout=handle, stderr=subprocess.STDOUT, timeout=480)
        report_path = FRAMES / shot / "report.json"
        if run.returncode or not report_path.exists():
            failures.append(shot)
            print(f"CAPTURE FAILED: {shot}; see {log}", flush=True)
            continue
        report = json.loads(report_path.read_text())
        shutil.copy(report_path,OUT/"footage"/f"{shot}.json")
        for frame in [45,int(duration*15),int(duration*30)-30]:
            shutil.copy(FRAMES/shot/f"frame-{frame:04d}.jpg",OUT/"stills"/f"{shot}-{frame:04d}.jpg")
        subprocess.run(["/opt/homebrew/bin/ffmpeg","-hide_banner","-loglevel","error","-y",
            "-framerate","30","-i",str(FRAMES/shot/"frame-%04d.jpg"),
            "-frames:v",str(duration*30),"-vf","scale=in_range=full:out_range=tv,format=yuv420p",
            "-c:v","libx264","-preset","fast","-crf","16","-threads","6",
            "-color_primaries","bt709","-color_trc","bt709","-colorspace","bt709",
            "-movflags","+faststart",str(OUT/"footage"/f"{shot}.mp4")],check=True)
        # Only this runner's temporary frame sequences are removed after encoding.
        for frame in (FRAMES/shot).glob("frame-*.jpg"):
            frame.unlink()
        print(f"Ready: {shot}; {report['frames']} frames; {len(report['failures'])} capture failures",flush=True)
    timeline=[]
    start=0
    for shot,duration in SHOTS:
        timeline.append({"shot":shot,"start":start,"duration":duration,"file":f"footage/{shot}.mp4"})
        start+=duration
    (OUT/"timeline.json").write_text(json.dumps(timeline,indent=2)+"\n")
    print(f"Render pass complete. Failed shots: {failures}",flush=True)
    return bool(failures)

if __name__ == "__main__":
    raise SystemExit(main())
