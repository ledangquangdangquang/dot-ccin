{
  pkgs,
  menu,
  ...
}: let
  audioMenu = pkgs.writeShellApplication {
    name = "audio-menu";
    runtimeInputs = with pkgs; [
      gawk
      menu
      pulseaudio
    ];
    text = ''
      current="$(pactl get-default-sink)"
      choice="$(pactl list sinks | awk -v cur="$current" '
        /^\tName: / { name = $2 }
        /^\tDescription: / {
          sub(/^\tDescription: /, "")
          printf "%s  %s\t%s\n", (name == cur ? "󰓃" : "󰕾"), $0, name
        }
      ' | menu --dmenu --with-nth=1 --prompt='Audio ❯ ' --lines=6 --width=50)" || exit 0

      IFS=$'\t' read -r _ sink <<< "$choice"
      [[ -z "$sink" ]] && exit 0

      pactl set-default-sink "$sink"
      # Move already-playing streams to the new sink
      pactl list short sink-inputs | awk '{print $1}' | while read -r id; do
        pactl move-sink-input "$id" "$sink" || true
      done
      # audio-notify announces the change
    '';
  };

  # Notifies whenever the default sink changes (menu, Bluetooth connect/drop)
  audioNotify = pkgs.writeShellApplication {
    name = "audio-notify";
    runtimeInputs = with pkgs; [
      gawk
      coreutils
      libnotify
      pulseaudio
    ];
    text = ''
      describe() {
        pactl list sinks | awk -v want="$1" '
          /^\tName: / { name = $2 }
          /^\tDescription: / && name == want { sub(/^\tDescription: /, ""); print; exit }
        '
      }

      last="$(pactl get-default-sink || true)"
      # pactl subscribe exits when pipewire-pulse restarts; reconnect
      while true; do
        pactl subscribe | while IFS= read -r event; do
          [[ "$event" == *"on server"* ]] || continue
          sink="$(pactl get-default-sink || true)"
          [[ -z "$sink" || "$sink" == "$last" ]] && continue
          last="$sink"
          case "$sink" in
            bluez_*) icon=audio-headphones-symbolic ;;
            *) icon=audio-speakers-symbolic ;;
          esac
          notify-send -a audio -i "$icon" -h string:x-dunst-stack-tag:audio-output \
            "Audio output" "$(describe "$sink")"
        done
        sleep 2
      done
    '';
  };
in {
  home.packages = [audioMenu audioNotify];
}
