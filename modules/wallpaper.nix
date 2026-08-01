{pkgs, ...}: let
  menu = (import ./menu-util.nix {inherit pkgs;}).menu;
  wallpaperMenu = pkgs.writeShellApplication {
    name = "wallpaper-menu";
    runtimeInputs = with pkgs; [
      coreutils
      feh
      libnotify
      menu
    ];
    text = ''
      state_file="$HOME/.wallpaper"
      wallpaper_dir="$HOME/UbuntuConfig/Wallpapers"

      rows=""
      while IFS= read -r file; do
        rows+="$(basename "$file")"$'\t'"$file"$'\n'
      done < <(find "$wallpaper_dir" -maxdepth 1 -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' -o -iname '*.bmp' \) | sort)

      choice="$(printf '%s' "$rows" | menu --dmenu --with-nth=1 --prompt='Wallpaper ❯ ' --lines=14 --width=55)" || exit 0
      IFS=$'\t' read -r _ file <<< "$choice"
      [ -n "$file" ] || exit 0

      feh --bg-fill --no-fehbg "$file" || exit 1
      printf '%s\n' "$file" > "$state_file"
      notify-send --app-name="Wallpaper" --expire-time=2000 "Wallpaper set" "$(basename "$file")"
    '';
  };
in {
  home.packages = [wallpaperMenu];
}
