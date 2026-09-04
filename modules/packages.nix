{pkgs, ...}: {
  home.packages = with pkgs; [
    i3status-rust
    nerd-fonts.fira-code
    # wl-clipboard
    nwg-displays
    # wl-mirror
    fzf
    tree
    bat
    git
    fuzzel
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
    yazi
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
    bluetui
    kanshi # automatic output management
    autotiling
    picom
  ];
}
