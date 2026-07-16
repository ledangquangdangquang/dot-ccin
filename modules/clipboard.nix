{pkgs, ...}: let
  clipboardWatcher = pkgs.writeShellApplication {
    name = "clipboard-watcher";
    runtimeInputs = with pkgs; [
      cliphist
      wl-clipboard
    ];
    text = ''
      wl-paste --type text --watch cliphist store &
      text_pid=$!
      wl-paste --type image --watch cliphist store &
      image_pid=$!

      cleanup() {
        kill "$text_pid" "$image_pid" 2>/dev/null || true
      }
      trap cleanup EXIT INT TERM
      wait
    '';
  };

  clipboardMenu = pkgs.writeShellApplication {
    name = "clipboard-menu";
    runtimeInputs = with pkgs; [
      cliphist
      fuzzel
      wl-clipboard
    ];
    text = ''
      choice="$(cliphist list | fuzzel --dmenu --prompt='Clipboard ❯ ' --lines=15 --width=70)" || exit 0
      [[ -n "$choice" ]] || exit 0
      printf '%s' "$choice" | cliphist decode | wl-copy
    '';
  };

  clipboardClear = pkgs.writeShellApplication {
    name = "clipboard-clear";
    runtimeInputs = with pkgs; [
      cliphist
      fuzzel
      libnotify
    ];
    text = ''
      answer="$(printf 'Cancel\nClear history\n' | fuzzel --dmenu --prompt='Clipboard ❯ ' --lines=2 --width=36)" || exit 0
      if [[ "$answer" == "Clear history" ]]; then
        cliphist wipe
        notify-send --app-name="Clipboard" --expire-time=1500 "Clipboard history cleared"
      fi
    '';
  };
in {
  home.packages = [
    clipboardWatcher
    clipboardMenu
    clipboardClear
  ];
}
