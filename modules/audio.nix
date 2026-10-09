{
  pkgs,
  menu,
  ...
}: let
  audioMenu = pkgs.writeShellApplication {
    name = "audio-menu";
    runtimeInputs = with pkgs; [
      gawk
      libnotify
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

      IFS=$'\t' read -r label sink <<< "$choice"
      [[ -z "$sink" ]] && exit 0

      pactl set-default-sink "$sink"
      # Move already-playing streams to the new sink
      pactl list short sink-inputs | awk '{print $1}' | while read -r id; do
        pactl move-sink-input "$id" "$sink" || true
      done
      notify-send -a audio-menu -i audio-speakers-symbolic "Audio output" "''${label#*  }"
    '';
  };
in {
  home.packages = [audioMenu];
}
