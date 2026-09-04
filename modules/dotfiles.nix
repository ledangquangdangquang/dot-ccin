{config, ...}: let
  dotfiles = "${config.home.homeDirectory}/UbuntuConfig/dotfiles";
  createSymlink = path: config.lib.file.mkOutOfStoreSymlink path;
  configApps = [
    "fuzzel"
    "rofi"
    "zathura"
    "i3"
    "i3status-rust"
    "fcitx5"
    "weathr"
    "kanshi"
    "fastfetch"
    "btop"
    "bat"
    "nvim"
    "kitty"
    "alacritty"
    "starship"
    "yazi"
    "newtab"
    "picom"
    "zsh"
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
      "i3/keyshortcuts.txt".source = createSymlink "${dotfiles}/i3/keyshortcuts.txt";
      "i3/show-keyshortcuts.sh".source = createSymlink "${dotfiles}/i3/show-keyshortcuts.sh";
      "DankMaterialShell/settings.json".text =
        builtins.replaceStrings
        ["$HOME"]
        [config.home.homeDirectory]
        (builtins.readFile ../dotfiles/DankMaterialShell/settings.json);
    };
}
