{config, ...}: let
  dotfiles = "${config.home.homeDirectory}/UbuntuConfig/dotfiles";
  createSymlink = path: config.lib.file.mkOutOfStoreSymlink path;
  configApps = [
    "fuzzel"
    "zathura"
    "sway"
    "swaync"
    "i3status-rust"
    "fcitx5"
    "foot"
    "weathr"
    "vicinae"
    "kanshi"
    "fastfetch"
    "btop"
    "bat"
    "DankMaterialShell"
    "nvim"
    "niri"
    "kitty"
    "starship"
    "yazi"
    "superfile"
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
      "DankMaterialShell/settings.json".text =
        builtins.replaceStrings
        ["$HOME"]
        [config.home.homeDirectory]
        (builtins.readFile ../dotfiles/DankMaterialShell/settings.json);
    };
}
