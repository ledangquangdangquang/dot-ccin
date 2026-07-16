{user, ...}: {
  programs.bash = {
    enable = true;
    bashrcExtra = ''
      export PATH="$HOME/bin:$PATH"

    '';
    shellAliases = {
      c = "clear";
      rebuild = "nix flake check && nix run github:nix-community/home-manager -- switch --flake .#${user}";
    };
  };
}
