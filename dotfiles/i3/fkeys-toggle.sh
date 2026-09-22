#!/usr/bin/env bash
# Toggles whether F1-F3/F6-F9 trigger media actions or pass through as
# plain F-keys (see fkeys-media.sh).
set -euo pipefail

state="$HOME/.cache/fkeys-media-off"

if [ -e "$state" ]; then
	rm -f "$state"
	notify-send --app-name="System" --expire-time=1500 \
		--hint="string:x-canonical-private-synchronous:fkeys-media" \
		--icon=changes-allow-symbolic "F-keys" "Media functions On"
else
	touch "$state"
	notify-send --app-name="System" --expire-time=1500 \
		--hint="string:x-canonical-private-synchronous:fkeys-media" \
		--icon=changes-prevent-symbolic "F-keys" "Media functions Off · F1-F3, F6-F9 pass through"
fi
