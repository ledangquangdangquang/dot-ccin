{pkgs, ...}: let
  fzf-preview = pkgs.writeShellApplication {
    name = "fzf-preview.sh";
    runtimeInputs = with pkgs; [bat eza];
    text = ''
      if [ -d "$1" ]; then
        eza --tree --level=2 --icons --color=always "$1"
      else
        bat --style=numbers --color=always --line-range=:500 "$1"
      fi
    '';
  };

  fuzzyvim = pkgs.writeShellApplication {
    name = "fuzzyvim";
    runtimeInputs = with pkgs; [
      fzf
      fzf-preview
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
        fzf --style full \
          --layout=reverse \
          --height=80% \
          --preview 'fzf-preview.sh {}' \
          --preview-window='right:60%,border-left' \
          --bind 'enter:become(nvim -- {})'
    '';
  };
in {
  home.packages = [fuzzyvim];
}
