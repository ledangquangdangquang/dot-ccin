{pkgs, ...}: let
  # sticky-note: toggle the current note (Mod+n)
  # sticky-note pick: fzf choose/create a note in ~/notes, then open it (Mod+Ctrl+n)
  stickyNote = pkgs.writeShellApplication {
    name = "sticky-note";
    runtimeInputs = with pkgs; [bat coreutils fzf];
    text = ''
      dir="$HOME/notes"
      state="$dir/.current"
      mkdir -p "$dir"
      current="$(cat "$state" 2>/dev/null || true)"
      [ -f "$current" ] || current="$dir/sticky.md"
      cmd=(alacritty --class sticky-note -o font.size=12 -e nvim -S "$HOME/.config/nvim/sticky.lua")
      export WINIT_X11_SCALE_FACTOR=1

      if [ "''${1:-}" != pick ]; then
        exec popup-toggle sticky-note "''${cmd[@]}" "$current"
      fi

      cd "$dir"
      set +e
      out="$(find . -maxdepth 1 -name '*.md' -printf '%f\n' | sort \
        | fzf --print-query --style full --layout=reverse \
          --prompt 'note> ' --ghost 'Enter: open, type a new name to create' --color=ghost:#A6E3A1 \
          --preview 'bat --style=numbers --color=always --line-range=:500 {}' \
          --preview-window='right:60%,border-left')"
      rc=$?
      set -e
      [ "$rc" -eq 130 ] && exit 0
      name="$(printf '%s\n' "$out" | tail -n 1)"
      name="''${name##*/}"
      [ -n "$name" ] || exit 0
      [[ "$name" == *.md ]] || name="$name.md"
      printf '%s\n' "$dir/$name" > "$state"
      # direct launch, not popup-toggle: the old window may still exist while it is being killed
      i3-msg -q '[class="^sticky-note$"] kill' || true
      setsid -f "''${cmd[@]}" "$dir/$name" >/dev/null 2>&1
    '';
  };
in {
  home.packages = [stickyNote];
}
