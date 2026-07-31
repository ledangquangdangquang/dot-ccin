{pkgs, ...}: let
  menu = (import ./menu-util.nix {inherit pkgs;}).menu;

  clipboardWatcher = pkgs.writeShellApplication {
    name = "clipboard-watcher";
    runtimeInputs = with pkgs; [
      cliphist
      coreutils
      wl-clipboard
      xclip
    ];
    text = ''
      if [[ -n "''${WAYLAND_DISPLAY:-}" ]]; then
        wl-paste --type text --watch cliphist store &
        text_pid=$!
        wl-paste --type image --watch cliphist store &
        image_pid=$!

        cleanup() {
          kill "$text_pid" "$image_pid" 2>/dev/null || true
        }
        trap cleanup EXIT INT TERM
        wait
      else
        last_text=""
        last_image=""
        while true; do
          cur_text="$(xclip -selection clipboard -o 2>/dev/null)"
          if [[ "$cur_text" != "$last_text" ]]; then
            last_text="$cur_text"
            [[ -n "$cur_text" ]] && printf '%s\n' "$cur_text" | cliphist store 2>/dev/null
          fi
          cur_image="$(xclip -selection clipboard -t image/png -o 2>/dev/null)"
          if [[ "$cur_image" != "$last_image" ]]; then
            last_image="$cur_image"
            [[ -n "$cur_image" ]] && printf '%s' "$cur_image" | cliphist store image/png 2>/dev/null
          fi
          sleep 0.5
        done
      fi
    '';
  };

  clipboardMenu = pkgs.writeShellApplication {
    name = "clipboard-menu";
    runtimeInputs = with pkgs; [
      cliphist
      coreutils
      menu
      wl-clipboard
      xclip
    ];
    text = ''
      choice="$(cliphist list | menu --dmenu --prompt='Clipboard ❯ ' --lines=15 --width=70)" || exit 0
      [[ -n "$choice" ]] || exit 0
      if [[ -n "''${WAYLAND_DISPLAY:-}" ]]; then
        printf '%s' "$choice" | cliphist decode | wl-copy
      else
        printf '%s' "$choice" | cliphist decode | xclip -selection clipboard
      fi
    '';
  };

  clipboardClear = pkgs.writeShellApplication {
    name = "clipboard-clear";
    runtimeInputs = with pkgs; [
      cliphist
      coreutils
      libnotify
      menu
    ];
    text = ''
      answer="$(printf 'Cancel\nClear history\n' | menu --dmenu --prompt='Clipboard ❯ ' --lines=2 --width=36)" || exit 0
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
