{pkgs, ...}: let
  menu = (import ./menu-util.nix {inherit pkgs;}).menu;
  bluetoothMenu = pkgs.writeShellApplication {
    name = "bluetooth-menu";
    runtimeInputs = with pkgs; [
      bluez
      coreutils
      gawk
      gnugrep
      libnotify
      menu
    ];
    text = ''
      notify() {
        notify-send --app-name="Bluetooth" --expire-time=3000 "$@"
      }

      if bluetoothctl show 2>/dev/null | grep -q 'Powered: yes'; then
        power_label="󰂲  Turn Bluetooth off"
        power_action="power-off"
      else
        power_label="󰂲  Turn Bluetooth on"
        power_action="power-on"
      fi

      build_rows() {
        printf '%s\t%s\n' "$power_label" "$power_action"
        [ "$power_action" = "power-on" ] && return

        printf '󰑓  Scan for devices\tscan\n'
        while read -r _ mac name; do
          [ -n "''${mac:-}" ] || continue
          if bluetoothctl info "$mac" 2>/dev/null | grep -q 'Connected: yes'; then
            printf '󰂱  %s  Connected\tdevice\t%s\n' "$name" "$mac"
          else
            printf '󰂯  %s\tdevice\t%s\n' "$name" "$mac"
          fi
        done < <(bluetoothctl devices 2>/dev/null)
      }

      choice="$(build_rows | menu --dmenu --with-nth=1 --prompt='Bluetooth ❯ ' --lines=12 --width=55)" || exit 0
      IFS=$'\t' read -r _ action mac <<< "$choice"

      case "$action" in
        power-on)
          bluetoothctl power on >/dev/null && notify "Bluetooth enabled"
          ;;
        power-off)
          bluetoothctl power off >/dev/null && notify "Bluetooth disabled"
          ;;
        scan)
          notify "Scanning for Bluetooth devices…"
          bluetoothctl --timeout 8 scan on >/dev/null 2>&1 || true
          exec bluetooth-menu
          ;;
        device)
          name="$(bluetoothctl info "$mac" 2>/dev/null | awk -F': ' '/^[[:space:]]*Name:/ { print $2; exit }')"
          if bluetoothctl info "$mac" 2>/dev/null | grep -q 'Connected: yes'; then
            if bluetoothctl disconnect "$mac" >/dev/null; then
              notify "Disconnected" "$name"
            else
              notify -u critical "Could not disconnect" "$name"
            fi
          elif bluetoothctl connect "$mac" >/dev/null 2>&1; then
            notify "Connected" "$name"
          else
            notify "Pairing…" "$name"
            if bluetoothctl --timeout 30 --agent NoInputNoOutput pair "$mac" >/dev/null 2>&1 &&
              bluetoothctl trust "$mac" >/dev/null 2>&1 &&
              bluetoothctl connect "$mac" >/dev/null 2>&1; then
              notify "Paired and connected" "$name"
            else
              notify -u critical "Pairing failed" "Try pairing $name from a terminal if it requires a PIN."
            fi
          fi
          ;;
      esac
    '';
  };
in {
  home.packages = [bluetoothMenu];
}
