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
in {
  home.packages = with pkgs; [
    libnotify
    notification-sound
    pulseaudio
    swaynotificationcenter
  ];
}
