{pkgs, ...}: {
  home.packages = with pkgs; [
    i3status-rust
    nerd-fonts.fira-code
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
    picom
    xdotool # replay real F-key press when media F-keys are toggled off
    (python3.withPackages (ps: [ps.i3ipc]))
  ];
}
