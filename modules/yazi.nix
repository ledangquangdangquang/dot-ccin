{pkgs, ...}: let
  theme =
    builtins.removeAttrs
    (builtins.fromTOML (builtins.readFile ../dotfiles/yazi/theme.toml))
    ["syntect_theme"];
in {
  home.packages = [
    (pkgs.yazi.override {
      settings = {
        yazi.plugin.prepend_fetchers = [
          {
            url = "*";
            run = "git";
            group = "git";
          }
          {
            url = "*/";
            run = "git";
            group = "git";
          }
        ];
        keymap.mgr.prepend_keymap = [
          {
            on = "l";
            run = "plugin smart-enter";
            desc = "Enter the child directory, or open the file";
          }
          {
            on = "f";
            run = "plugin jump-to-char";
            desc = "Jump to char";
          }
          {
            on = "M";
            run = "plugin mount";
            desc = "Mount manager";
          }
        ];
        theme = theme;
      };
      plugins = {
        smart-enter = pkgs.yaziPlugins.smart-enter;
        full-border = pkgs.yaziPlugins.full-border;
        jump-to-char = pkgs.yaziPlugins.jump-to-char;
        git = pkgs.yaziPlugins.git;
        mount = pkgs.yaziPlugins.mount;
      };
      initLua = ../dotfiles/yazi/init.lua;
      extraPackages = [pkgs.udisks2];
    })
  ];
}
