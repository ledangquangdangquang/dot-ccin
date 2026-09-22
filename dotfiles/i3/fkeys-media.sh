#!/usr/bin/env bash
# Runs a media command on an F-key, unless F-keys are toggled off
# (see fkeys-toggle.sh), in which case it replays the real key instead.
set -euo pipefail

key="$1"
shift

if [ -e "$HOME/.cache/fkeys-media-off" ]; then
	xdotool key "$key"
else
	"$@"
fi
