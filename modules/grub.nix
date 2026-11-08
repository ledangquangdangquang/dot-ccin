{pkgs, ...}: {
  home.packages = [
    # GRUB is system-level, outside Home Manager: run this once by hand to apply.
    # Undo: sudo rm /etc/default/grub.d/99-catppuccin.cfg && sudo update-grub
    (pkgs.writeShellApplication {
      name = "grub-catppuccin";
      text = ''
        sudo mkdir -p /boot/grub/themes
        sudo cp -rT --no-preserve=mode ${pkgs.catppuccin-grub} /boot/grub/themes/catppuccin-mocha
        sudo cp --no-preserve=mode ${../Wallpapers/wallpaper.png} /boot/grub/themes/catppuccin-mocha/background.png
        sudo sed -i '/^# Logo image/,/^}/d' /boot/grub/themes/catppuccin-mocha/theme.txt
        # The menu was hidden with no timeout; the theme only shows if the menu does
        sudo tee /etc/default/grub.d/99-catppuccin.cfg >/dev/null <<'EOF'
        GRUB_THEME=/boot/grub/themes/catppuccin-mocha/theme.txt
        GRUB_TIMEOUT_STYLE=menu
        GRUB_TIMEOUT=5
        EOF
        sudo update-grub
      '';
    })
  ];
}
