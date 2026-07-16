{config, ...}: let
  dotfiles = "${config.home.homeDirectory}/UbuntuConfig/dotfiles";
  createSymlink = path: config.lib.file.mkOutOfStoreSymlink path;
  configApps = [
    "fuzzel"
    "sway"
    "swaync"
    "i3status-rust"
    "fcitx5"
    "foot"
    "weathr"
    "vicinae"
    "fastfetch"
    "btop"
    "bat"
    "DankMaterialShell"
    "nvim"
    "niri"
    "kitty"
    "starship"
    "yazi"
  ];
in {
  xdg.configFile =
    builtins.listToAttrs (map (app: {
        name = app;
        value = {
          source = createSymlink "${dotfiles}/${app}/";
          recursive = true;
        };
      })
      configApps)
    // {
      "sway/keyshortcuts.txt".source = createSymlink "${dotfiles}/sway/keyshortcuts.txt";
      "sway/show-keyshortcuts.sh".source = createSymlink "${dotfiles}/sway/show-keyshortcuts.sh";
    };
}
