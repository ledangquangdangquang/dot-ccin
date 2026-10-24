{pkgs, ...}: let
  notification-sound = pkgs.writeShellApplication {
    name = "notification-sound";
    runtimeInputs = with pkgs; [
      coreutils
      gawk
      gnugrep
      pulseaudio
      util-linux
    ];
    text = ''
      runtime_dir="''${XDG_RUNTIME_DIR:-/tmp}"
      lock_file="$runtime_dir/notification-sound.lock"
      # Other options to try, swap "message" below:
      #   complete, dialog-information, message-new-instant, alarm-clock-elapsed, bell
      case "''${DUNST_CATEGORY:-}" in
        device.added) sound="device-added" ;;
        device.removed) sound="device-removed" ;;
        *) sound="message" ;;
      esac
      # SOUND_NAME lets non-dunst callers (login/logout) pick a sound
      sound_file="${pkgs.sound-theme-freedesktop}/share/sounds/freedesktop/stereo/''${SOUND_NAME:-$sound}.oga"

      [[ "''${DUNST_STACK_TAG:-}" == "volume" || "''${DUNST_STACK_TAG:-}" == "brightness" ]] && exit 0

      exec 9>"$lock_file"
      flock --nonblock 9 || exit 0

      stream_ids=()
      stream_volumes=()

      pactl get-sink-mute @DEFAULT_SINK@ 2>/dev/null | grep -q yes && exit 0

      restore_volumes() {
        local index
        for index in "''${!stream_ids[@]}"; do
          pactl set-sink-input-volume \
            "''${stream_ids[$index]}" \
            "''${stream_volumes[$index]}%" \
            2>/dev/null || true
        done
      }

      trap restore_volumes EXIT INT TERM

      while IFS= read -r stream_id; do
        [[ -n "$stream_id" ]] || continue

        volume=$(
          pactl list sink-inputs |
            awk -v target="#$stream_id" '
              $1 == "Sink" && $2 == "Input" { found = ($3 == target) }
              found && /Volume:/ && match($0, /[0-9]+%/) {
                print substr($0, RSTART, RLENGTH - 1)
                exit
              }
            '
        )

        [[ "$volume" =~ ^[0-9]+$ ]] || continue

        stream_ids+=("$stream_id")
        stream_volumes+=("$volume")

        if ((volume > 25)); then
          pactl set-sink-input-volume "$stream_id" 25% || true
        fi
      done < <(pactl list short sink-inputs | awk '{print $1}')

      paplay \
        --property=media.role=event \
        --volume=65536 \
        "$sound_file"
    '';
  };

  usb-notify = pkgs.writeShellApplication {
    name = "usb-notify";
    runtimeInputs = with pkgs; [
      libnotify
      systemd
    ];
    text = ''
      # shortcut: hubs re-enumerating after suspend also notify, filter by vendor if it gets noisy
      udevadm monitor --udev --property --subsystem-match=usb/usb_device | while IFS= read -r line; do
        case "$line" in
          ACTION=*) action="''${line#*=}" ;;
          ID_VENDOR=*) vendor="''${line#*=}" ;;
          ID_VENDOR_FROM_DATABASE=*) db_vendor="''${line#*=}" ;;
          ID_MODEL=*) model="''${line#*=}" ;;
          ID_MODEL_FROM_DATABASE=*) db_model="''${line#*=}" ;;
          "")
            name="''${db_vendor:-''${vendor:-}} ''${db_model:-''${model:-USB device}}"
            name="''${name//_/ }"
            case "''${action:-}" in
              add) notify-send --app-name=USB --category=device.added --icon=drive-removable-media "USB connected" "$name" ;;
              remove) notify-send --app-name=USB --category=device.removed --icon=drive-removable-media "USB removed" "$name" ;;
            esac
            action="" vendor="" db_vendor="" model="" db_model=""
            ;;
        esac
      done
    '';
  };

  system-control = pkgs.writeShellApplication {
    name = "system-control";
    runtimeInputs = with pkgs; [
      brightnessctl
      coreutils
      ddcutil
      gammastep
      gawk
      libnotify
      pulseaudio
      xset
    ];
    text = ''
      notify_level() {
        local tag="$1"
        local icon="$2"
        local title="$3"
        local value="$4"

        notify-send \
          --app-name="System" \
          --expire-time=1500 \
          --icon="$icon" \
          --hint="string:x-canonical-private-synchronous:$tag" \
          --hint="int:value:$value" \
          "$title" "$value%"
      }

      # $1: brightnessctl value (laptop panel), rest: ddcutil value (external monitor via DDC/CI)
      set_brightness() {
        brightnessctl -q set "$1" || true
        shift
        if ddcutil --noverify setvcp 10 "$@" 2>/dev/null; then
          value="$(ddcutil -t getvcp 10 | awk '{print $4}')"
        else
          value="$(brightnessctl -m | awk -F, '{gsub(/%/, "", $4); print $4}')"
        fi
        notify_level brightness display-brightness-symbolic "Brightness" "$value"
      }

      case "''${1:-}" in
        brightness-up)
          set_brightness +5% + 5
          ;;
        brightness-down)
          set_brightness 5%- - 5
          ;;
        brightness-set)
          set_brightness "''${2:?percent}%" "''${2}"
          ;;
        volume-up)
          pactl set-sink-volume @DEFAULT_SINK@ +5%
          value="$(pactl get-sink-volume @DEFAULT_SINK@ | awk 'match($0, /[0-9]+%/) { print substr($0, RSTART, RLENGTH - 1); exit }')"
          notify_level volume audio-volume-high-symbolic "Volume" "$value"
          ;;
        volume-down)
          pactl set-sink-volume @DEFAULT_SINK@ -5%
          value="$(pactl get-sink-volume @DEFAULT_SINK@ | awk 'match($0, /[0-9]+%/) { print substr($0, RSTART, RLENGTH - 1); exit }')"
          notify_level volume audio-volume-low-symbolic "Volume" "$value"
          ;;
        volume-mute)
          pactl set-sink-mute @DEFAULT_SINK@ toggle
          if [[ "$(pactl get-sink-mute @DEFAULT_SINK@)" == *yes ]]; then
            notify-send --app-name="System" --expire-time=1500 \
              --hint="string:x-canonical-private-synchronous:volume" \
              --icon=audio-volume-muted-symbolic "Volume" "Muted"
          else
            value="$(pactl get-sink-volume @DEFAULT_SINK@ | awk 'match($0, /[0-9]+%/) { print substr($0, RSTART, RLENGTH - 1); exit }')"
            notify_level volume audio-volume-high-symbolic "Volume" "$value"
          fi
          ;;
        caps-lock)
          # read the real LED state; a toggled state file drifts when a press is missed
          if xset q | grep -q 'Caps Lock: *on'; then
            state="On"
            icon="changes-allow-symbolic"
          else
            state="Off"
            icon="changes-prevent-symbolic"
          fi
          notify-send --app-name="System" --expire-time=1500 \
            --hint="string:x-canonical-private-synchronous:caps-lock" \
            --icon="$icon" "Caps Lock" "$state"
          ;;
        night-light)
          state_file="''${XDG_RUNTIME_DIR:-/tmp}/night-light"
          if [[ -e "$state_file" ]]; then
            rm -f "$state_file"
            gammastep -x
            notify-send --app-name="System" --expire-time=1500 \
              --hint="string:x-canonical-private-synchronous:night-light" \
              --icon=weather-clear-symbolic "Night Light" "Off · 6500K"
          else
            if gammastep -O 4000 2>/dev/null; then
              touch "$state_file"
              notify-send --app-name="System" --expire-time=1500 \
                --hint="string:x-canonical-private-synchronous:night-light" \
                --icon=weather-clear-night-symbolic "Night Light" "On · 4000K"
            else
              notify-send --app-name="System" --urgency=critical --expire-time=3000 \
                --hint="string:x-canonical-private-synchronous:night-light" \
                --icon=dialog-error-symbolic "Night Light" "Could not change display temperature"
            fi
          fi
          ;;
        *)
          echo "Usage: system-control {brightness-up|brightness-down|brightness-set N|volume-up|volume-down|volume-mute|caps-lock|night-light}" >&2
          exit 2
          ;;
      esac
    '';
  };
in {
  home.packages = with pkgs; [
    libnotify
    notification-sound
    system-control
    usb-notify
    pulseaudio
  ];

  services.dunst = {
    enable = true;
    settings = {
      global = {
        origin = "bottom-center";
        offset = "10x10";
        corner_radius = 10;
        width = 400;
        timeout = 8;
        timeout_low = 4;
        timeout_critical = 0;
        follow = "mouse";
        icon_position = "left";
        frame_width = 2;
        frame_color = "#89b4fa";
        separator_color = "frame";
        font = "FiraCode Nerd Font Mono 14";
        transparency = 30;
        separator_height = 2;
        notification_limit = 10;
      };
      urgency_low = {
        background = "#1e1e2e";
        foreground = "#cdd6f4";
        timeout = 4;
        script = "${notification-sound}/bin/notification-sound";
      };
      urgency_normal = {
        background = "#1e1e2e";
        foreground = "#cdd6f4";
        timeout = 8;
        script = "${notification-sound}/bin/notification-sound";
      };
      urgency_critical = {
        background = "#1e1e2e";
        foreground = "#cdd6f4";
        timeout = 0;
        script = "${notification-sound}/bin/notification-sound";
      };
    };
  };
}
