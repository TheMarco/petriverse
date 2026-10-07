#!/bin/zsh
set -eu
cd -- "$(dirname -- "$0")"
if command -v godot >/dev/null 2>&1; then
  exec godot --path "$PWD"
elif [[ -x /Applications/Godot.app/Contents/MacOS/Godot ]]; then
  exec /Applications/Godot.app/Contents/MacOS/Godot --path "$PWD"
else
  print 'Godot was not found. Import project.godot in the installed Godot editor and press F5.'
  read -r '?Press Return to close.'
fi
