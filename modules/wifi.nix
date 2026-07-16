{pkgs, ...}: let
  wifiMenu = pkgs.writeShellApplication {
    name = "wifi-menu";
    runtimeInputs = with pkgs; [
      coreutils
      fuzzel
      gawk
      libnotify
      networkmanager
    ];
    text = ''
      notify() {
        notify-send --app-name="Wi-Fi" --expire-time=3000 "$@"
      }

      wifi_state="$(nmcli -t -f WIFI general 2>/dev/null || true)"
      if [ "$wifi_state" = "enabled" ]; then
        toggle_label="󰖪  Turn Wi-Fi off"
        toggle_action="wifi-off"
      else
        toggle_label="󰖩  Turn Wi-Fi on"
        toggle_action="wifi-on"
      fi

      rows="$toggle_label"$'\t'"$toggle_action"$'\n'

      if [ "$wifi_state" = "enabled" ]; then
        rows+="󰑓  Rescan"$'\t'"rescan"$'\n'
        rows+="󰖪  Disconnect"$'\t'"disconnect"$'\n'

        networks="$(
          nmcli -t --escape no -f IN-USE,SIGNAL,SECURITY,SSID device wifi list --rescan yes 2>/dev/null |
            awk -F: '
              {
                active=$1; signal=$2; security=$3
                ssid=$0
                sub(/^[^:]*:[^:]*:[^:]*:/, "", ssid)
                if (ssid == "" || seen[ssid]++) next
                icon=(active == "*" ? "󰖩" : "󰤨")
                lock=(security == "--" || security == "" ? "" : " 󰌾")
                printf "%s  %s  %s%%%s\twifi\t%s\n", icon, ssid, signal, lock, ssid
              }
            '
        )"
        if [ -n "$networks" ]; then
          rows+="$networks"$'\n'
        fi
      fi

      choice="$(printf '%s' "$rows" | fuzzel --dmenu --with-nth=1 --prompt='Wi-Fi ❯ ' --lines=12 --width=55)" || exit 0
      IFS=$'\t' read -r _ action value <<< "$choice"

      case "$action" in
        wifi-on)
          nmcli radio wifi on && notify "Wi-Fi enabled"
          ;;
        wifi-off)
          nmcli radio wifi off && notify "Wi-Fi disabled"
          ;;
        rescan)
          nmcli device wifi rescan
          exec wifi-menu
          ;;
        disconnect)
          device="$(nmcli -t -f DEVICE,TYPE,STATE device | awk -F: '$2 == "wifi" && $3 == "connected" { print $1; exit }')"
          if [ -n "$device" ]; then
            nmcli device disconnect "$device" && notify "Wi-Fi disconnected"
          else
            notify "No active Wi-Fi connection"
          fi
          ;;
        wifi)
          if nmcli device wifi connect "$value" >/dev/null 2>&1; then
            notify "Connected" "$value"
            exit 0
          fi

          password="$(fuzzel --dmenu --prompt-only="Password for $value ❯ " --password --width=55)" || exit 0
          [ -n "$password" ] || exit 0
          if nmcli device wifi connect "$value" password "$password"; then
            notify "Connected" "$value"
          else
            notify -u critical "Connection failed" "$value"
          fi
          ;;
      esac
    '';
  };
in {
  home.packages = [wifiMenu];
}
