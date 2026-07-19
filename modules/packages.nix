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
    fastfetch
    swaybg
    neovim
    alejandra
    ripgrep
    shfmt
    stylua
    tree-sitter
    nil
    nixpkgs-fmt
    nodejs
    btop
    gcc
    yazi
    starship
    zathura
    ffmpeg
    # kitty
    foot
    kew
    brightnessctl # laptop/internal display brightness
    ddcutil # brightness
    eza # alternative ls
  ];
}
