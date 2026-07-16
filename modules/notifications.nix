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
      sound_file="${pkgs.sound-theme-freedesktop}/share/sounds/freedesktop/stereo/message.oga"

      exec 9>"$lock_file"
      flock --nonblock 9 || exit 0

      stream_ids=()
      stream_volumes=()

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

  system-control = pkgs.writeShellApplication {
    name = "system-control";
    runtimeInputs = with pkgs; [
      brightnessctl
      coreutils
      gawk
      libnotify
      pulseaudio
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

      case "''${1:-}" in
        brightness-up)
          brightnessctl set +5%
          value="$(brightnessctl -m | awk -F, '{gsub(/%/, "", $4); print $4}')"
          notify_level brightness display-brightness-symbolic "Brightness" "$value"
          ;;
        brightness-down)
          brightnessctl set 5%-
          value="$(brightnessctl -m | awk -F, '{gsub(/%/, "", $4); print $4}')"
          notify_level brightness display-brightness-symbolic "Brightness" "$value"
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
          state_file="''${XDG_RUNTIME_DIR:-/tmp}/caps-lock-state"
          if [[ -e "$state_file" ]]; then
            rm -f "$state_file"
            state="Off"
            icon="changes-prevent-symbolic"
          else
            touch "$state_file"
            state="On"
            icon="changes-allow-symbolic"
          fi
          notify-send --app-name="System" --expire-time=1500 \
            --hint="string:x-canonical-private-synchronous:caps-lock" \
            --icon="$icon" "Caps Lock" "$state"
          ;;
        *)
          echo "Usage: system-control {brightness-up|brightness-down|volume-up|volume-down|volume-mute|caps-lock}" >&2
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
    pulseaudio
    swaynotificationcenter
  ];
}
