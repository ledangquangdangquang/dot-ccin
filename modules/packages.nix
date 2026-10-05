{pkgs, ...}: {
  home.packages = with pkgs; [
    i3status-rust
    nerd-fonts.fira-code
    fzf
    tree
    bat
    git
    rofi
    xclip
    maim
    fastfetch
    feh
    neovim
    alejandra
    ripgrep
    shfmt
    stylua
    tree-sitter
    nil
    btop
    gcc
    alacritty
    starship
    zathura
    ffmpeg
    kitty
    kew
    brightnessctl # laptop/internal display brightness
    ddcutil # brightness
    eza # alternative ls
    # right-click extract/compress; plugin only reads .tap from its own libexec, so add xarchiver's
    (thunar.override {
      thunarPlugins = [
        (thunar-archive-plugin.overrideAttrs (old: {
          postInstall = (old.postInstall or "") + "cp ${xarchiver}/libexec/thunar-archive-plugin/xarchiver.tap $out/libexec/thunar-archive-plugin/";
        }))
      ];
    })
    xarchiver # archive backend for thunar-archive-plugin
    bluetui
    picom
    xdotool # replay real F-key press when media F-keys are toggled off
    (python3.withPackages (ps: [ps.i3ipc]))
  ];
}
