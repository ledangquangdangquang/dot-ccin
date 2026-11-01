{
  pkgs,
  lib,
  menu,
  ...
}: let
  pomodoroTask = pkgs.writeShellApplication {
    name = "pomodoro-task";
    runtimeInputs = with pkgs; [coreutils gawk gnugrep gnused menu];
    text = ''
      # Task list (one per line) + current task shown on the bar
      list_file="$HOME/.cache/pomodoro-tasks"
      task_file="$HOME/.cache/pomodoro-task"
      mkdir -p "$(dirname "$task_file")"
      touch "$list_file" "$task_file"
      current="$(cat "$task_file")"
      if [ -n "$current" ] && ! grep -qxF -- "$current" "$list_file"; then
        printf '%s\n' "$current" >>"$list_file"
      fi

      # Rewrite in place (same inode) so the bar's inotify watch keeps working
      write_list() {
        if [ -n "$1" ]; then printf '%s\n' "$1" >"$list_file"; else : >"$list_file"; fi
      }
      set_current() {
        printf '%s' "$1" >"$task_file"
      }
      # Rows: display<TAB>line number
      task_rows() {
        CUR="$current" awk '{ printf "  %s%s\t%d\n", $0, ($0 == ENVIRON["CUR"] ? " ✓" : ""), NR }' "$list_file"
      }

      case "''${1:-pick}" in
        show)
          if [ -n "$current" ]; then
            others="$(grep -cvxF -- "$current" "$list_file" || true)"
            if [ "$others" -gt 0 ]; then printf '%s (+%d)' "$current" "$others"; else printf '%s' "$current"; fi
          else
            echo "No task"
          fi
          ;;
        done)
          [ -n "$current" ] || exit 0
          write_list "$(grep -vxF -- "$current" "$list_file" || true)"
          set_current "$(head -n1 "$list_file")"
          ;;
        pick | *)
          choice="$({
            task_rows
            printf '󰐕  Add task\tadd\n'
            if [ -s "$list_file" ]; then printf '󰆴  Remove task\tremove\n'; fi
          } | menu --dmenu --custom --prompt='Task ❯ ' --lines=10 --width=55)" || exit 0
          IFS=$'\t' read -r label action <<<"$choice"

          # Typed text matching no row → new task
          add_task() {
            [ -n "$1" ] || exit 0
            printf '%s\n' "$1" >>"$list_file"
            set_current "$1"
          }

          case "$action" in
            "")
              add_task "$label"
              ;;
            add)
              # Let the click that picked "Add task" finish, or it closes the next rofi
              sleep 0.3
              add_task "$(menu --dmenu --prompt-only='New task ❯ ' --width=55 </dev/null)"
              ;;
            remove)
              sleep 0.3
              choice="$(task_rows | menu --dmenu --prompt='Remove ❯ ' --lines=10 --width=55)" || exit 0
              IFS=$'\t' read -r _ n <<<"$choice"
              removed="$(sed -n "''${n}p" "$list_file")"
              write_list "$(awk -v n="$n" 'NR != n' "$list_file")"
              if [ "$removed" = "$current" ]; then set_current "$(head -n1 "$list_file")"; fi
              ;;
            *)
              set_current "$(sed -n "''${action}p" "$list_file")"
              ;;
          esac
          ;;
      esac
    '';
  };
in {
  home.packages = [pomodoroTask];

  # i3status-rust watches these files with inotify, which requires them to
  # already exist before the bar starts. Create them if missing, never touch
  # their contents.
  home.activation.pomodoroTaskFile = lib.hm.dag.entryAfter ["writeBoundary"] ''
    run mkdir -p "$HOME/.cache"
    run touch -a "$HOME/.cache/pomodoro-task" "$HOME/.cache/pomodoro-tasks"
  '';
}
