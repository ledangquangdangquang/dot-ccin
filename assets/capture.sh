#!/usr/bin/env bash
# Retake README screenshots on an empty workspace (9), 1920x1080 eDP-1.
# Only touches windows it creates: terminals get class "shot", Firefox window tracked by id.
# Usage: bash assets/capture.sh   (overwrites the PNGs next to this script)
set -euo pipefail

out=$(cd "$(dirname "$0")" && pwd)
repo=$(dirname "$out")
ws=9
prev=$(i3-msg -t get_workspaces | jq -r '.[] | select(.focused).name')
pause() { sleep "${1:-1.5}"; }
shot() { maim -u "$out/$1"; echo "saved $1"; }
kill_shots() { i3-msg -q '[class="^shot$"] kill' || true; sleep 0.5; }
# own class escapes the alacritty -> workspace 1 rule; smaller font so btop fits the tiles
term() { i3-msg -q "exec alacritty --class shot -o font.size=10 --working-directory $repo $*"; pause; }
firefox_ids() { i3-msg -t get_tree | jq -r '.. | objects | select(.window_properties?.class? // "" | test("firefox";"i")) | .id' | sort; }

i3-msg -q "workspace $ws"
if [ -n "$(i3-msg -t get_tree | jq ".. | objects | select(.type==\"workspace\" and .name==\"$ws\") | .. | objects | select(.window?)")" ]; then
  echo "workspace $ws is not empty, aborting" >&2; exit 1
fi

# 1. clean: wallpaper + i3bar only (wait out picom's workspace-switch fade)
pause 1
shot desktop-clean.png

# 2. busy: auto-split-7030 puts the 1st window at 70%, the next two stacked on the right
term "-e btop"
term "-e nvim -c \"set nowrap\" flake.nix"
term "--hold -e fastfetch --logo-position top"; pause
shot desktop-busy.png
kill_shots

# 3. fuzzyvim + yazi
term "-e fuzzyvim"
term "-e yazi"
shot fuzzyvim-yazi.png
kill_shots

# 4. rofi launcher (Mod+space)
i3-msg -q "exec menu-launcher"; pause
shot rofi-launcher.png
pkill -x rofi || true

# 5. power menu (Mod+x) -- screenshot only, rofi is killed, nothing is executed
i3-msg -q "exec power-menu"; pause
shot rofi-power.png
pkill -x rofi || true

# 6. Firefox new tab with outer gaps (Mod+g); the new window lands on B (for_window), pull only it back
before=$(firefox_ids)
i3-msg -q "exec firefox --new-window http://127.0.0.1:8918/"; pause 4
new=$(comm -13 <(echo "$before") <(firefox_ids))
if [ "$(echo "$new" | grep -c .)" != 1 ]; then
  echo "could not identify the new Firefox window, skipping" >&2
else
  i3-msg -q "[con_id=$new] move container to workspace $ws"
  i3-msg -q "workspace $ws"
  i3-msg -q "gaps outer current toggle 60"; pause 0.5
  shot firefox-newtab.png
  i3-msg -q "gaps outer current toggle 60"
  i3-msg -q "[con_id=$new] kill"
fi

i3-msg -q "workspace $prev"
