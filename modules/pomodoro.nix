{
  pkgs,
  lib,
  ...
}: let
  menu = (import ./menu-util.nix {inherit pkgs;}).menu;
  pomodoroTask = pkgs.writeShellApplication {
    name = "pomodoro-task";
    runtimeInputs = with pkgs; [coreutils menu];
    text = ''
      task_file="$HOME/.cache/pomodoro-task"
      mkdir -p "$(dirname "$task_file")"

      case "''${1:-set}" in
        show)
          if [ -s "$task_file" ]; then
            cat "$task_file"
          else
            echo "No task"
          fi
          ;;
        clear)
          : >"$task_file"
          ;;
        set|*)
          task="$(menu --dmenu --prompt-only='Task ❯ ' --width=55)" || exit 0
          [ -n "$task" ] || exit 0
          printf '%s' "$task" >"$task_file"
          ;;
      esac
    '';
  };
in {
  home.packages = [pomodoroTask];

  # i3status-rust watches this file with inotify, which requires it to
  # already exist before the bar starts. Create it if missing, never touch
  # it if it already holds a task.
  home.activation.pomodoroTaskFile = lib.hm.dag.entryAfter ["writeBoundary"] ''
    run mkdir -p "$HOME/.cache"
    run touch -a "$HOME/.cache/pomodoro-task"
  '';
}
