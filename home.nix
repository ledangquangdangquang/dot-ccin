{
  config,
  inputs,
  pkgs,
  hostMain,
  user,
  ...
}: let
  dotfiles = "${config.home.homeDirectory}/UbuntuConfig/dotfiles";
  create_symlink = path: config.lib.file.mkOutOfStoreSymlink path;

  # Tạo danh sách các ứng dụng cần tạo symlink từ thư mục dotfiles
  configApps = ["sway" "i3status-rust" "fcitx5" "foot" "weathr" "vicinae" "fastfetch" "btop" "bat" "DankMaterialShell" "nvim" "niri" "kitty" "starship" "yazi"];

  fuzzyvim = pkgs.writeShellApplication {
    name = "fuzzyvim";
    runtimeInputs = with pkgs; [
      bat
      fzf
      neovim
      ripgrep
    ];
    text = ''
      set -o pipefail

      rg --files --hidden --follow \
        -g '!.git' \
        -g '!node_modules' \
        -g '!target' \
        2>/dev/null |
        fzf --layout=reverse \
          --height=80% \
          --preview 'bat --style=numbers --color=always --line-range=:500 {}' \
          --preview-window='right:60%,border-left' \
          --bind 'enter:become(nvim -- {})'
    '';
  };
in {
  imports = [
    inputs.catppuccin.homeModules.catppuccin
    ./modules
  ];

  catppuccin.autoEnable = true;

  home.username = "${user}";
  home.homeDirectory = "/home/${user}";
  home.stateVersion = hostMain.stateVersion;
  targets.genericLinux.enable = true;

  # Tối ưu hóa toàn bộ phần định nghĩa xdg.configFile cũ bằng một vòng lặp map
  xdg.configFile = builtins.listToAttrs (map (app: {
      name = app;
      value = {
        source = create_symlink "${dotfiles}/${app}/";
        recursive = true;
      };
    })
    configApps);

  home.packages = with pkgs; [
    i3status-rust
    nerd-fonts.fira-code
    wl-clipboard
    pulseaudio
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
    #kitty
    foot
    kew
    ddcutil # brightness
    eza # alternative ls
    fuzzyvim
  (qt6Packages.fcitx5-with-addons.override {
    addons = [
      qt6Packages.fcitx5-unikey
    ];
  })
    #discord
    #opencode
  ];
}
