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
  configApps = ["fuzzel" "sway" "swaync" "i3status-rust" "fcitx5" "foot" "weathr" "vicinae" "fastfetch" "btop" "bat" "DankMaterialShell" "nvim" "niri" "kitty" "starship" "yazi"];

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

  screenshot = pkgs.writeShellApplication {
    name = "screenshot";
    runtimeInputs = with pkgs; [
      coreutils
      grim
      libnotify
      satty
      slurp
      wl-clipboard
    ];
    text = ''
      mode="''${1:-region}"
      screenshot_dir="''${HOME}/Pictures/Screenshots"
      screenshot_file="''${screenshot_dir}/Screenshot-$(date +'%Y-%m-%d_%H-%M-%S').png"

      mkdir -p "$screenshot_dir"

      select_region() {
        slurp -d -b '#1e1e2ecc' -c '#cba6f7ff' -s '#31324488' -w 2
      }

      edit_screenshot() {
        satty \
          --filename - \
          --fullscreen \
          --output-filename "$screenshot_file" \
          --copy-command wl-copy
      }

      case "$mode" in
        region)
          geometry="$(select_region)" || exit 0
          grim -g "$geometry" -t ppm - | edit_screenshot
          ;;
        full)
          grim -t ppm - | edit_screenshot
          ;;
        copy)
          geometry="$(select_region)" || exit 0
          grim -g "$geometry" -t png - | wl-copy --type image/png
          notify-send \
            --app-name="Screenshot" \
            --expire-time=2500 \
            "Screenshot copied" \
            "The selected region is in the clipboard"
          ;;
        *)
          echo "Usage: screenshot {region|full|copy}" >&2
          exit 2
          ;;
      esac
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
  home.sessionVariables = {
    XMODIFIERS = "@im=fcitx";
    GTK_IM_MODULE = "fcitx";
    QT_IM_MODULE = "fcitx";
  };
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
    grim
    slurp
    satty
    swaynotificationcenter
    libnotify
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
    screenshot
    (qt6Packages.fcitx5-with-addons.override {
      addons = [
        qt6Packages.fcitx5-unikey
      ];
    })
    #discord
    #opencode
  ];
}
