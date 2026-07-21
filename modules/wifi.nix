{pkgs, ...}: let
  networkMenu = pkgs.writeShellApplication {
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
        notify-send --app-name="Network" --expire-time=3000 "$@"
      }

      # ── Wi-Fi section ──
      wifi_state="$(nmcli -t -f WIFI general 2>/dev/null || true)"
      if [ "$wifi_state" = "enabled" ]; then
        wifi_toggle_label="󰖪  Turn Wi-Fi off"
        wifi_toggle_action="wifi-off"
      else
        wifi_toggle_label="󰖩  Turn Wi-Fi on"
        wifi_toggle_action="wifi-on"
      fi

      # ── Ethernet section ──
      eth_device="$(nmcli -t -f DEVICE,TYPE device | awk -F: '$2 == "ethernet" { print $1; exit }')"
      eth_connection="$(nmcli -t -f NAME,TYPE connection show 2>/dev/null | awk -F: '$2 == "802-3-ethernet" { print $1; exit }')"

      if [ -n "$eth_device" ]; then
        eth_state="$(nmcli -t -f DEVICE,STATE device | awk -F: -v dev="$eth_device" '$1 == dev { print $2; exit }')"
        if [ "$eth_state" = "connected" ]; then
          eth_label="󰈀  Ethernet · Connected ($eth_device)"
          eth_action="eth-disconnect"
        else
          eth_label="󰈂  Ethernet · Disconnected ($eth_device)"
          eth_action="eth-connect"
        fi
      elif [ -n "$eth_connection" ]; then
        eth_label="󰈂  Ethernet ($eth_connection)"
        eth_action="eth-connect"
      else
        eth_label="󰈂  Ethernet · Not detected"
        eth_action=""
      fi

      # ── Build menu ──
      rows=""

      # Wi-Fi toggle
      rows+="$wifi_toggle_label"$'\t'"$wifi_toggle_action"$'\n'

      # Ethernet
      if [ -n "$eth_action" ]; then
        rows+="$eth_label"$'\t'"$eth_action"$'\n'
      else
        rows+="$eth_label"$'\t'"noop"$'\n'
      fi

      rows+=$'\t'"sep"$'\n'

      # Wi-Fi networks
      if [ "$wifi_state" = "enabled" ]; then
        rows+="󰑓  Rescan"$'\t'"rescan"$'\n'
        rows+="󰖪  Disconnect Wi-Fi"$'\t'"wifi-disconnect"$'\n'

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

      choice="$(printf '%s' "$rows" | fuzzel --dmenu --with-nth=1 --prompt='Network ❯ ' --lines=14 --width=55)" || exit 0
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
        wifi-disconnect)
          device="$(nmcli -t -f DEVICE,TYPE,STATE device | awk -F: '$2 == "wifi" && $3 == "connected" { print $1; exit }')"
          if [ -n "$device" ]; then
            nmcli device disconnect "$device" && notify "Wi-Fi disconnected"
          else
            notify "No active Wi-Fi connection"
          fi
          ;;
        eth-connect)
          err=""
          if [ -n "$eth_device" ]; then
            err="$(nmcli device connect "$eth_device" 2>&1)" && notify "Ethernet connected" "$eth_device" && exit 0
            err="$(nmcli connection up "$eth_connection" 2>&1)" && notify "Ethernet connected" "$eth_connection" && exit 0
          elif [ -n "$eth_connection" ]; then
            err="$(nmcli connection up "$eth_connection" 2>&1)" && notify "Ethernet connected" "$eth_connection" && exit 0
          fi
          notify -u critical "Ethernet connection failed" "${err:-No Ethernet device or connection found}"
          ;;
        eth-disconnect)
          if [ -n "$eth_device" ]; then
            nmcli device disconnect "$eth_device" && notify "Ethernet disconnected" "$eth_device"
          elif [ -n "$eth_connection" ]; then
            nmcli connection down "$eth_connection" && notify "Ethernet disconnected" "$eth_connection"
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
  home.packages = [networkMenu];
}
