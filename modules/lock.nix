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
      xrandr
    ];
    text = ''
      wallpaper="$(cat ~/.wallpaper 2>/dev/null || echo ~/dot-ccin/Wallpapers/wallpaper.png)"
      size="$(xdpyinfo | awk '/dimensions:/ { print $2 }')"
      # Draw the lock panel on the external monitor if any (else the first one); the rest stays base.
      read -r mon mx my < <(xrandr --listmonitors | awk 'NR > 1 {
        split($3, g, /[\/x+]/); m = g[1] "x" g[3] " " g[5] " " g[6]
        if (!first) first = m
        if ($NF !~ /^(eDP|LVDS)/ && !ext) ext = m
      } END { print (ext ? ext : first) }') || true
      mon="''${mon:-$size}" mx="''${mx:-0}" my="''${my:-0}"
      cache_dir="''${XDG_CACHE_HOME:-$HOME/.cache}/lock-screen"
      image="$cache_dir/$(printf '%s' "$wallpaper $(stat -c %Y "$wallpaper" 2>/dev/null) $size $mon $mx $my" | md5sum | cut -c1-12).png"

      if [ ! -f "$image" ]; then
        mkdir -p "$cache_dir"
        rm -f "$cache_dir"/*.png
        magick -respect-parentheses -size "$size" xc:'#1e1e2e' +size \( "$wallpaper" \
          -resize "$mon^" -gravity center -extent "$mon" \
          -scale 20% -blur 0x6 -resize 500% -extent "$mon" \
          -fill '#1e1e2e' -colorize 35% \
          -fill '#1e1e2ecc' -stroke '#cba6f7' -strokewidth 4 \
          -draw "translate %[fx:w/2],%[fx:h/2] circle 0,0 0,110" \
          -stroke none -font ${font} -fill '#cba6f7' -pointsize 96 \
          -annotate +0+0 '󰌾' \
          -fill '#cdd6f4' -pointsize 26 -annotate +0+170 'Type password to unlock' \
          \) +gravity -geometry "+$mx+$my" -composite "$image" || image=""
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
