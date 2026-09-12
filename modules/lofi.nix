{pkgs, ...}: let
  lofi = pkgs.writeShellApplication {
    name = "lofi";
    runtimeInputs = with pkgs; [mpv procps util-linux socat];
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

      case "''${1:-toggle}" in
        status)
          if ! running; then
            printf '\xef\x80\x81 Lofi'
          elif is_paused; then
            printf '\xef\x81\x8c Lofi'
          else
            printf '\xef\x81\x8b Lofi'
          fi
          ;;
        toggle)
          flock -n 9 || exit 0
          if ! running; then
            setsid -f mpv --no-video --shuffle --loop-playlist=inf \
              --input-ipc-server="$sock" --title="$marker" "$dir" \
              >/dev/null 2>&1 9>&-
          else
            ipc '{ "command": ["cycle", "pause"] }' >/dev/null
          fi
          ;;
        stop)
          flock -n 9 || exit 0
          pkill -KILL -f "$marker" 2>/dev/null || true
          rm -f "$sock"
          ;;
      esac
    '';
  };
in {
  home.packages = [lofi];
}
