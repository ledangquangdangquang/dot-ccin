#!/usr/bin/env bash

rofi \
	-dmenu \
	-i \
	-p "Shortcuts (Esc to close) > " \
	-lines 25 \
	-width 64 \
	-theme "$HOME/.config/rofi/catppuccin-mocha.rasi" \
	<"$HOME/.config/i3/keyshortcuts.txt" \
	>/dev/null
