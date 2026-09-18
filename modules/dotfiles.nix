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
    "fastfetch"
    "btop"
    "bat"
    "kitty"
    "alacritty"
    "starship"
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
      # Non-recursive: a single whole-directory symlink so new files under
      # dotfiles/nvim/ appear immediately, without the build-time snapshot
      # that `recursive = true` bakes in (it won't pick up added files
      # without a nix-store rebuild-cache workaround).
      "nvim".source = createSymlink "${dotfiles}/nvim";
    };
}
