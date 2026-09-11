{user, ...}: {
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
      rebuild = "nix flake check && nix run github:nix-community/home-manager -- switch --flake .#${user}";
    };
  };
}
