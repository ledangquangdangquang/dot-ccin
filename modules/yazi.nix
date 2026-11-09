{pkgs, ...}: let
  theme =
    builtins.removeAttrs
    (builtins.fromTOML (builtins.readFile ../dotfiles/yazi/theme.toml))
    ["syntect_theme"];
in {
  home.packages = [
    (pkgs.yazi.override {
      settings = {
        yazi.mgr.sort_by = "extension";
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
          {
            on = "C";
            # %s expands to absolute paths; strip them so the zip doesn't nest home/user/...
            run = ''shell 'set -- %s; zip -r .zip "''${@##*/}"' --interactive --cursor=18'';
            desc = "Zip selected files";
          }
          {
            on = "<Esc>";
            run = "plugin popup-esc";
            desc = "Cancel, or quit the popup when nothing is left to cancel";
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
        popup-esc = ../dotfiles/yazi/popup-esc.yazi;
      };
      initLua = ../dotfiles/yazi/init.lua;
      extraPackages = [pkgs.udisks2];
    })
  ];
}
