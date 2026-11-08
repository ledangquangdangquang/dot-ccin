{pkgs, ...}: let
  # Stops a stylesheet that GNOME Shell can't parse from reaching the login screen
  checkCss = pkgs.writeText "gdm-check-css.js" ''
    const {St, Gio} = imports.gi;
    new St.Theme().load_stylesheet(Gio.File.new_for_path(ARGV[0]));
  '';
in {
  home.packages = [
    # GDM is system-level, outside Home Manager: run this once by hand, and again after GNOME upgrades.
    # Undo: sudo update-alternatives --remove gdm-theme.gresource /usr/share/gnome-shell/theme/catppuccin-mocha/gnome-shell-theme.gresource
    #       sudo rm /var/lib/gdm3/seat0/config/monitors.xml
    (pkgs.writeShellApplication {
      name = "gdm-catppuccin";
      runtimeInputs = [pkgs.glib];
      text = ''
        src=/usr/share/gnome-shell/theme/Yaru/gnome-shell-theme.gresource
        dest=/usr/share/gnome-shell/theme/catppuccin-mocha
        prefix=/org/gnome/shell/theme
        work=$(mktemp -d)
        trap 'rm -rf "$work"' EXIT

        # Built from the installed Yaru so the CSS always matches this GNOME version
        files=$(gresource list "$src")
        entries=""
        for path in $files; do
          rel=''${path#"$prefix"/}
          mkdir -p "$work/$(dirname "$rel")"
          gresource extract "$src" "$path" > "$work/$rel"
          entries+="<file>$rel</file>"
        done

        sed -i -E \
          -e 's/-st-accent-color/#89b4fa/g; s/-st-accent-fg-color/#1e1e2e/g' \
          -e 's/#222222/#1e1e2e/g; s/#(f2f2f2|ffffff)/#cdd6f4/g' \
          -e 's/#(36363a|373737|353535|2f2f2f)/#313244/g' \
          -e 's/#(4d4d4d|47474c|4a4a4f|48484c)/#45475a/g' \
          -e 's/rgba\((242, 242, 242|255, 255, 255|238, 238, 238)/rgba(205, 214, 244/g' \
          "$work/gdm.css"
        cat >> "$work/gdm.css" <<'EOF'

        .login-dialog {
          background: #1e1e2e url(resource:///org/gnome/shell/theme/background.png);
          background-size: cover;
          background-position: center; }
        EOF
        cp --no-preserve=mode ${../Wallpapers/wallpaper.png} "$work/background.png"
        entries+="<file>background.png</file>"

        shell_libs=/usr/lib/gnome-shell:$(echo /usr/lib/x86_64-linux-gnu/mutter-*)
        GI_TYPELIB_PATH=$shell_libs LD_LIBRARY_PATH=$shell_libs /usr/bin/gjs ${checkCss} "$work/gdm.css"

        echo "<gresources><gresource prefix=\"$prefix\">$entries</gresource></gresources>" > "$work/theme.xml"
        ${pkgs.glib.dev}/bin/glib-compile-resources --sourcedir="$work" --target="$work/out.gresource" "$work/theme.xml"

        sudo install -D -m644 "$work/out.gresource" "$dest/gnome-shell-theme.gresource"
        # Yaru is priority 15, so auto mode picks this one
        sudo update-alternatives --install /usr/share/gnome-shell/gdm-theme.gresource gdm-theme.gresource "$dest/gnome-shell-theme.gresource" 20

        # HDMI is primary in this layout; mutter ignores it when HDMI is unplugged and falls back to the laptop
        greeter_config=/var/lib/gdm3/seat0/config
        if [ -f "$HOME/.config/monitors.xml" ] && [ -d "$greeter_config" ]; then
          sudo install -m644 "$HOME/.config/monitors.xml" "$greeter_config/monitors.xml"
          sudo chown --reference="$greeter_config" "$greeter_config/monitors.xml"
        else
          echo "Skipped monitor layout: needs ~/.config/monitors.xml and $greeter_config (GDM 49+)."
        fi
        echo "Done: applies the next time the login screen starts."
      '';
    })
  ];
}
