#!/usr/bin/env python3
"""Import registered ElevenLabs/Magnific creations; no credentials ship in game."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path
import subprocess
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "artifacts/creature-film-audio"
DEST = ROOT / "prototype/assets/audio/introductions"

def import_one(item):
    name, source = item
    if not name.replace('_', '').isalnum():
        raise ValueError('Invalid species identifier')
    original = SOURCE / (name + '.mp3')
    target = DEST / (name + '.ogg')
    if not original.exists():
        with urllib.request.urlopen(source['url'], timeout=120) as response:
            data = response.read()
        if len(data) < 1024:
            raise ValueError('Empty generated recording: ' + name)
        original.write_bytes(data)
    if not target.exists():
        temporary = target.with_suffix('.partial.ogg')
        subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', str(original),
                        '-af', 'loudnorm=I=-18:TP=-2.5:LRA=6', '-ar', '44100', '-ac', '2',
                        '-c:a', 'vorbis', '-strict', 'experimental', '-q:a', '5', str(temporary)], check=True)
        temporary.replace(target)
    duration = float(subprocess.check_output(['ffprobe', '-v', 'error', '-show_entries',
        'format=duration', '-of', 'default=nw=1:nk=1', str(target)], text=True))
    if not 4.0 <= duration <= 35.0:
        raise ValueError(f'{name}: unexpected narration duration {duration}')
    return name, {'creation': source['identifier'], 'narration': source['narration'],
                  'duration': duration, 'sha256': hashlib.sha256(target.read_bytes()).hexdigest(),
                  'original_sha256': hashlib.sha256(original.read_bytes()).hexdigest()}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--sources', required=True, type=Path)
    args = parser.parse_args()
    sources = json.loads(args.sources.read_text())
    SOURCE.mkdir(parents=True, exist_ok=True)
    DEST.mkdir(parents=True, exist_ok=True)
    results = {}
    with ThreadPoolExecutor(max_workers=3) as pool:
        for name, data in pool.map(import_one, sources.items()):
            results[name] = data
    (SOURCE / 'provenance.json').write_text(json.dumps({
        'provider': 'ElevenLabs via Magnific', 'model': 'eleven_v3',
        'voice': 'Willa Ashford', 'catalog_voice_id': 918,
        'mastering': '44.1kHz stereo Vorbis, -18 LUFS, -2.5 dBTP target',
        'assets': results}, indent=2) + '\n')
    print(f'{len(results)} narrated creature introductions imported and validated.')

if __name__ == '__main__':
    main()
