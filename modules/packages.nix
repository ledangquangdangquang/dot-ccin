{pkgs, ...}: {
  home.packages = with pkgs; [
    i3status-rust
    nerd-fonts.fira-code
    wl-clipboard
    nwg-displays
    wl-mirror
    vicinae
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
    superfile
    btop
    gcc
    # yazi
    starship
    zathura
    ffmpeg
    kitty
    kew
    brightnessctl # laptop/internal display brightness
    ddcutil # brightness
    eza # alternative ls
    kanshi # automatic output management
    autotiling
  ];
}
