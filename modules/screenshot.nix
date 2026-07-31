{pkgs, ...}: let
  screenshot = pkgs.writeShellApplication {
    name = "screenshot";
    runtimeInputs = with pkgs; [
      coreutils
      grim
      libnotify
      maim
      satty
      slurp
      wl-clipboard
      xclip
    ];
    text = ''
      mode="''${1:-region}"
      screenshot_dir="''${HOME}/Pictures/Screenshots"
      screenshot_file="''${screenshot_dir}/Screenshot-$(date +'%Y-%m-%d_%H-%M-%S').png"

      mkdir -p "$screenshot_dir"

      case "$mode" in
        region)
          if [[ -n "''${WAYLAND_DISPLAY:-}" ]]; then
            geometry="$(slurp -d -b '#1e1e2ecc' -c '#cba6f7ff' -s '#31324488' -w 2)" || exit 0
            grim -g "$geometry" -t ppm - | satty --filename - --fullscreen --output-filename "$screenshot_file" --copy-command wl-copy
          else
            maim -s | satty --filename - --fullscreen --output-filename "$screenshot_file" --copy-command "xclip -selection clipboard -t image/png"
          fi
          ;;
        full)
          if [[ -n "''${WAYLAND_DISPLAY:-}" ]]; then
            grim -t ppm - | satty --filename - --fullscreen --output-filename "$screenshot_file" --copy-command wl-copy
          else
            maim | satty --filename - --fullscreen --output-filename "$screenshot_file" --copy-command "xclip -selection clipboard -t image/png"
          fi
          ;;
        copy)
          if [[ -n "''${WAYLAND_DISPLAY:-}" ]]; then
            geometry="$(slurp -d -b '#1e1e2ecc' -c '#cba6f7ff' -s '#31324488' -w 2)" || exit 0
            grim -g "$geometry" -t png - | wl-copy --type image/png
          else
            maim -s | xclip -selection clipboard -t image/png
          fi
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
    maim
    satty
    slurp
    screenshot
    xclip
  ];
}
