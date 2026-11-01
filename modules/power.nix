{
  pkgs,
  menu,
  ...
}: let
  powerMenu = pkgs.writeShellApplication {
    name = "power-menu";
    runtimeInputs = with pkgs; [
      menu
      systemd
      xset
    ];
    text = ''
      choice="$({
        printf '󰌾  Lock\tlock\n'
        printf '󰒲  Suspend\tsuspend\n'
        printf '󰍃  Logout\tlogout\n'
        printf '󰜉  Reboot\treboot\n'
        printf '󰐥  Shutdown\tshutdown\n'
      } | menu --dmenu --with-nth=1 --prompt='Power ❯ ' --lines=5 --width=36)" || exit 0

      IFS=$'\t' read -r _ action <<< "$choice"

      confirm() {
        local label="$1"
        local answer
        answer="$(printf 'Cancel\n%s\n' "$label" | menu --dmenu --prompt='Confirm ❯ ' --lines=2 --width=36)" || return 1
        [[ "$answer" == "$label" ]]
      }

      case "$action" in
        lock)
          xset s activate
          ;;
        suspend)
          systemctl suspend
          ;;
        logout)
          confirm "Logout" && { SOUND_NAME=service-logout notification-sound || true; i3-msg exit; }
          ;;
        reboot)
          confirm "Reboot" && systemctl reboot
          ;;
        shutdown)
          confirm "Shutdown" && systemctl poweroff
          ;;
      esac
    '';
  };
  # Battery block click: no-sleep toggle (screensaver/lock off) + power profile (Ubuntu's power-profiles-daemon)
  batteryMenu = pkgs.writeShellApplication {
    name = "battery-menu";
    runtimeInputs = with pkgs; [
      gawk
      libnotify
      menu
      xset
    ];
    text = ''
      ppctl=/usr/bin/powerprofilesctl
      timeout="$(xset q | awk '/timeout:/ { print $2 }')"
      profile="$($ppctl get 2>/dev/null || echo balanced)"
      mark() { [[ "$1" == "$2" ]] && printf ' ✓' || true; }
      [[ "$timeout" == 0 ]] && nosleep=on || nosleep=off

      choice="$({
        printf '󰅶  No sleep%s\tnosleep\n' "$(mark "$nosleep" on)"
        printf '󰌪  Power saver%s\tpower-saver\n' "$(mark "$profile" power-saver)"
        printf '󰾅  Balanced%s\tbalanced\n' "$(mark "$profile" balanced)"
        printf '󰓅  Performance%s\tperformance\n' "$(mark "$profile" performance)"
      } | menu --dmenu --with-nth=1 --prompt='Battery ❯ ' --lines=4 --width=36)" || exit 0

      IFS=$'\t' read -r _ action <<< "$choice"

      case "$action" in
        nosleep)
          if [[ "$nosleep" == on ]]; then
            xset s 3600 3600
            notify-send -a Battery -t 1500 -h string:x-dunst-stack-tag:battery-mode "No sleep off" "Lock after 1 hour"
          else
            xset s off
            notify-send -a Battery -t 1500 -h string:x-dunst-stack-tag:battery-mode "No sleep on" "Screen won't lock"
          fi
          ;;
        power-saver | balanced | performance)
          $ppctl set "$action" && notify-send -a Battery -t 1500 -h string:x-dunst-stack-tag:battery-mode "Power profile" "$action"
          ;;
      esac
    '';
  };
in {
  home.packages = [powerMenu batteryMenu];
}
