{pkgs, ...}: let
  screenshot = pkgs.writeShellApplication {
    name = "screenshot";
    runtimeInputs = with pkgs; [
      coreutils
      libnotify
      maim
      satty
      xclip
      (tesseract.override {enableLanguages = ["eng" "vie"];})
    ];
    text = ''
      mode="''${1:-region}"
      # Delay in seconds before capturing. An app menu (e.g. a Firefox dropdown) keyboard-grabs
      # while open, so the screenshot keybind can't reach i3; use a delay to
      # trigger the capture before opening such a popup instead.
      delay="''${2:-0}"
      screenshot_dir="''${HOME}/Pictures/Screenshots"
      screenshot_file="''${screenshot_dir}/Screenshot-$(date +'%Y-%m-%d_%H-%M-%S').png"

      mkdir -p "$screenshot_dir"

      case "$mode" in
        region)
          maim -d "$delay" -s | satty --filename - --fullscreen --output-filename "$screenshot_file" --copy-command "xclip -selection clipboard -t image/png"
          ;;
        full)
          maim -d "$delay" | satty --filename - --fullscreen --output-filename "$screenshot_file" --copy-command "xclip -selection clipboard -t image/png"
          ;;
        copy)
          maim -d "$delay" -s | xclip -selection clipboard -t image/png
          notify-send \
            --app-name="Screenshot" \
            --expire-time=2500 \
            "Screenshot copied" \
            "The selected region is in the clipboard"
          ;;
        ocr)
          text="$(maim -d "$delay" -s | tesseract -l vie+eng stdin stdout 2>/dev/null)"
          if [ -z "''${text//[[:space:]]/}" ]; then
            notify-send --app-name="Screenshot" --expire-time=2500 "OCR" "No text found"
            exit 1
          fi
          printf '%s' "$text" | xclip -selection clipboard
          notify-send --app-name="Screenshot" --expire-time=4000 "OCR copied" "$(printf '%s' "$text" | head -c 200)"
          ;;
        *)
          echo "Usage: screenshot {region|full|copy|ocr} [delay_seconds]" >&2
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
