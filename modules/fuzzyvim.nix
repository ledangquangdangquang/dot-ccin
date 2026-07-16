{pkgs, ...}: let
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
  home.packages = [fuzzyvim];
}
