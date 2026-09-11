{pkgs, ...}: let
  screenshot = pkgs.writeShellApplication {
    name = "screenshot";
    runtimeInputs = with pkgs; [
      coreutils
      libnotify
      maim
      satty
      xclip
    ];
    text = ''
      mode="''${1:-region}"
      screenshot_dir="''${HOME}/Pictures/Screenshots"
      screenshot_file="''${screenshot_dir}/Screenshot-$(date +'%Y-%m-%d_%H-%M-%S').png"

      mkdir -p "$screenshot_dir"

      case "$mode" in
        region)
          maim -s | satty --filename - --fullscreen --output-filename "$screenshot_file" --copy-command "xclip -selection clipboard -t image/png"
          ;;
        full)
          maim | satty --filename - --fullscreen --output-filename "$screenshot_file" --copy-command "xclip -selection clipboard -t image/png"
          ;;
        copy)
          maim -s | xclip -selection clipboard -t image/png
          notify-send \
            --app-name="Screenshot" \
            --expire-time=2500 \
            "Screenshot copied" \
            "The selected region is in the clipboard"
          ;;
        *)
          echo "Usage: screenshot {region|full|copy}" >&2
          exit 2
          ;;
      esac
    '';
  };
in {
  home.packages = with pkgs; [
    maim
    satty
    screenshot
    xclip
  ];
}
