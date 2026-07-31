#!/usr/bin/env bash

fuzzel \
	--dmenu \
	--prompt="Shortcuts (Esc to close) > " \
	--lines=25 \
	--width=64 \
	<"$HOME/.config/i3/keyshortcuts.txt" \
	>/dev/null
