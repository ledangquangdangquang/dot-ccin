{user, ...}: {
  # Catppuccin Mocha fzf; a session variable (not .zshrc) so i3 popups like the note picker get it too
  home.sessionVariables.FZF_DEFAULT_OPTS = builtins.concatStringsSep " " [
    "--color=bg+:#313244,bg:-1,spinner:#F5E0DC,hl:#F38BA8"
    "--color=fg:#CDD6F4,header:#F38BA8,info:#CBA6F7,pointer:#F5E0DC"
    "--color=marker:#B4BEFE,fg+:#CDD6F4,prompt:#CBA6F7,hl+:#F38BA8"
    "--color=selected-bg:#45475A"
    "--color=border:#6C7086,label:#CDD6F4"
  ];

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    completionInit = "autoload -U compinit && compinit -C";
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    history.size = 10000;

    initContent = ''
      source ~/.config/zsh/.zshrc
    '';

    shellAliases = {
      t = "tmux new-session -A -s main";
      rebuild = "nix flake check && nix run --inputs-from . home-manager -- switch --flake .#${user}";
    };
  };
}
