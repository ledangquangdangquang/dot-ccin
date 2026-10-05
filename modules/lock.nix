{pkgs, ...}: let
  font = "${pkgs.nerd-fonts.fira-code}/share/fonts/truetype/NerdFonts/FiraCode/FiraCodeNerdFontPropo-Regular.ttf";

  # Blurred wallpaper + lock icon, then Ubuntu's /usr/bin/i3lock (system PAM;
  # Nix's i3lock/i3lock-color can't verify passwords on non-NixOS).
  lockScreen = pkgs.writeShellApplication {
    name = "lock-screen";
    runtimeInputs = with pkgs; [
      coreutils
      gawk
      imagemagick
      xdpyinfo
    ];
    text = ''
      wallpaper="$(cat ~/.wallpaper 2>/dev/null || echo ~/dot-ccin/Wallpapers/wallpaper.png)"
      size="$(xdpyinfo | awk '/dimensions:/ { print $2 }')"
      cache_dir="''${XDG_CACHE_HOME:-$HOME/.cache}/lock-screen"
      image="$cache_dir/$(printf '%s' "$wallpaper $(stat -c %Y "$wallpaper" 2>/dev/null) $size" | md5sum | cut -c1-12).png"

      if [ ! -f "$image" ]; then
        mkdir -p "$cache_dir"
        rm -f "$cache_dir"/*.png
        magick "$wallpaper" -resize "$size^" -gravity center -extent "$size" \
          -scale 20% -blur 0x6 -resize 500% -extent "$size" \
          -fill '#1e1e2e' -colorize 35% \
          -fill '#1e1e2ecc' -stroke '#cba6f7' -strokewidth 4 \
          -draw "translate %[fx:w/2],%[fx:h/2] circle 0,0 0,110" \
          -stroke none -font ${font} -fill '#cba6f7' -pointsize 96 \
          -annotate +0+0 '󰌾' \
          -fill '#cdd6f4' -pointsize 26 -annotate +0+170 'Type password to unlock' \
          "$image" || image=""
      fi

      if [ -n "$image" ]; then
        exec /usr/bin/i3lock -n -i "$image" "$@"
      fi
      exec /usr/bin/i3lock -n -c 1e1e2e "$@"
    '';
  };
in {
  home.packages = [lockScreen];
}
