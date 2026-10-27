{user, ...}: {
  programs.bash = {
    enable = true;
    bashrcExtra = ''
      export PATH="$HOME/bin:$PATH"

    '';
    shellAliases = {
      c = "clear";
      rebuild = "nix flake check && nix run --inputs-from . home-manager -- switch --flake .#${user}";
    };
  };
}
