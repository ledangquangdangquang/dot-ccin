{pkgs, ...}: let
  screenshot = pkgs.writeShellApplication {
    name = "screenshot";
    runtimeInputs = with pkgs; [
      coreutils
      grim
      libnotify
      satty
      slurp
      wl-clipboard
    ];
    text = ''
      mode="''${1:-region}"
      screenshot_dir="''${HOME}/Pictures/Screenshots"
      screenshot_file="''${screenshot_dir}/Screenshot-$(date +'%Y-%m-%d_%H-%M-%S').png"

      mkdir -p "$screenshot_dir"

      select_region() {
        slurp -d -b '#1e1e2ecc' -c '#cba6f7ff' -s '#31324488' -w 2
      }

      edit_screenshot() {
        satty \
          --filename - \
          --fullscreen \
          --output-filename "$screenshot_file" \
          --copy-command wl-copy
      }

      case "$mode" in
        region)
          geometry="$(select_region)" || exit 0
          grim -g "$geometry" -t ppm - | edit_screenshot
          ;;
        full)
          grim -t ppm - | edit_screenshot
          ;;
        copy)
          geometry="$(select_region)" || exit 0
          grim -g "$geometry" -t png - | wl-copy --type image/png
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
    grim
    satty
    slurp
    screenshot
  ];
}
