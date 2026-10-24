{
  pkgs,
  menu,
  ...
}: let
  lofi = pkgs.writeShellApplication {
    name = "lofi";
    runtimeInputs = with pkgs; [mpv procps util-linux socat jq menu];
    text = ''
      marker="lofi-stream"
      dir="$HOME/Music/Lofi"
      mkdir -p "$dir"

      sock="''${XDG_RUNTIME_DIR:-/tmp}/lofi-mpv.sock"
      # ponytail: non-blocking lock so a fast double-click just gets dropped
      # instead of stacking two toggles that race each other.
      lock="''${XDG_RUNTIME_DIR:-/tmp}/lofi.lock"
      exec 9>"$lock"

      running() { pgrep -f "$marker" >/dev/null; }
      # Pause/resume through mpv's own IPC socket (not SIGSTOP): SIGSTOP
      # freezes the process mid-write to the audio device, which crackles.
      ipc() { printf '%s\n' "$1" | socat -t 2 - "UNIX-CONNECT:$sock" 2>/dev/null || true; }
      is_paused() { ipc '{ "command": ["get_property", "pause"] }' | grep -q '"data":true'; }
      # Matches `signal = 8` on the bar's lofi block: redraw now instead of on the next poll.
      # Nix wraps the binary, so the process name is .i3status-rs-wrapped; match the path.
      refresh() { pkill -RTMIN+8 -f '/bin/i3status-rs( |$)' 2>/dev/null || true; }
      start() {
        pkill -KILL -f "$marker" 2>/dev/null || true
        rm -f "$sock"
        setsid -f mpv --no-video --loop-playlist=inf \
          --input-ipc-server="$sock" --title="$marker" "$@" \
          >/dev/null 2>&1 9>&-
        # Wait for mpv's socket so the refresh can read the track title.
        for _ in $(seq 20); do [ -S "$sock" ] && break; sleep 0.1; done
        sleep 0.2
        refresh
      }

      case "''${1:-toggle}" in
        status)
          if ! running; then
            printf '\xef\x80\x81 Lofi'
            exit 0
          fi
          # mpv also pushes event lines to every IPC client; only the reply has .data
          title="$(ipc '{ "command": ["get_property", "media-title"] }' | jq -r '.data // empty' 2>/dev/null || true)"
          [ "''${#title}" -gt 30 ] && title="''${title:0:29}…"
          if is_paused; then icon=$'\xef\x81\x8c'; else icon=$'\xef\x81\x8b'; fi
          # loop-file is "inf" when repeating one track, false otherwise.
          ipc '{ "command": ["get_property", "loop-file"] }' | grep -q '"data":"inf"' && icon+=$' \xef\x80\x9e'
          printf '%s %s' "$icon" "''${title:-Lofi}"
          ;;
        loop)
          running || exit 0
          ipc '{ "command": ["cycle-values", "loop-file", "inf", "no"] }' >/dev/null
          refresh
          ;;
        click)
          if running; then exec "$0" toggle; else exec "$0" pick; fi
          ;;
        pick)
          rows=$'\xef\x81\xb4 Shuffle all\t'"$dir"$'\n'
          while IFS= read -r file; do
            rows+="$(basename "$file")"$'\t'"$file"$'\n'
          done < <(find "$dir" -maxdepth 1 -type f | sort)

          choice="$(printf '%s' "$rows" | menu --dmenu --with-nth=1 --prompt='Lofi ❯ ' --lines=14 --width=55)" || exit 0
          IFS=$'\t' read -r _ file <<< "$choice"
          [ -n "$file" ] || exit 0

          flock -n 9 || exit 0
          if [ "$file" = "$dir" ]; then
            start --shuffle "$dir"
          else
            # Picked track first, then the rest of the folder, looping.
            mapfile -t rest < <(find "$dir" -maxdepth 1 -type f | sort | grep -vxF -- "$file")
            start "$file" "''${rest[@]}"
          fi
          ;;
        toggle)
          flock -n 9 || exit 0
          if ! running; then
            start --shuffle "$dir"
          else
            ipc '{ "command": ["cycle", "pause"] }' >/dev/null
            refresh
          fi
          ;;
        stop)
          flock -n 9 || exit 0
          pkill -KILL -f "$marker" 2>/dev/null || true
          rm -f "$sock"
          refresh
          ;;
      esac
    '';
  };
in {
  home.packages = [lofi];
}
