{
  pkgs,
  menu,
  ...
}: let
  findWallpapers = "find \"$HOME/dot-ccin/Wallpapers\" -maxdepth 1 -type f \\( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' -o -iname '*.bmp' \\)";

  # Random wallpaper every 5 minutes; toggled from wallpaper-menu
  wallpaperSlideshow = pkgs.writeShellApplication {
    name = "wallpaper-slideshow";
    runtimeInputs = with pkgs; [coreutils findutils feh];
    text = ''
      while true; do
        file="$(${findWallpapers} | shuf -n1)"
        feh --bg-fill --no-fehbg "$file" && printf '%s\n' "$file" > "$HOME/.wallpaper"
        sleep 300
      done
    '';
  };

  wallpaperMenu = pkgs.writeShellApplication {
    name = "wallpaper-menu";
    runtimeInputs = with pkgs; [
      coreutils
      feh
      libnotify
      menu
      procps
      wallpaperSlideshow
    ];
    text = ''
      state_file="$HOME/.wallpaper"
      slideshow_flag="$HOME/.wallpaper-slideshow" # i3 restarts the slideshow on login when present

      if pgrep -f wallpaper-slideshow >/dev/null; then
        rows="󰑓 Slideshow 5 min: on"$'\t'"slideshow"$'\n'
      else
        rows="󰑓 Slideshow 5 min: off"$'\t'"slideshow"$'\n'
      fi
      while IFS= read -r file; do
        rows+="$(basename "$file")"$'\t'"$file"$'\n'
      done < <(${findWallpapers} | sort)

      choice="$(printf '%s' "$rows" | menu --dmenu --with-nth=1 --prompt='Wallpaper ❯ ' --lines=14 --width=55)" || exit 0
      IFS=$'\t' read -r _ file <<< "$choice"
      [ -n "$file" ] || exit 0

      if [ "$file" = slideshow ]; then
        if pkill -f wallpaper-slideshow; then
          rm -f "$slideshow_flag"
          notify-send --app-name="Wallpaper" --expire-time=2000 "Slideshow off"
        else
          touch "$slideshow_flag"
          wallpaper-slideshow &
          disown
          notify-send --app-name="Wallpaper" --expire-time=2000 "Slideshow on" "New wallpaper every 5 minutes"
        fi
        exit 0
      fi

      # Picking a fixed wallpaper ends the slideshow
      pkill -f wallpaper-slideshow || true
      rm -f "$slideshow_flag"

      feh --bg-fill --no-fehbg "$file" || exit 1
      printf '%s\n' "$file" > "$state_file"
      notify-send --app-name="Wallpaper" --expire-time=2000 "Wallpaper set" "$(basename "$file")"
    '';
  };
in {
  home.packages = [wallpaperMenu wallpaperSlideshow];
}
