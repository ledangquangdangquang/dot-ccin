{
  description = "A very basic flake adapted for Ubuntu (Non-NixOS)";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    catppuccin = {
      url = "github:catppuccin/nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs @ {
    nixpkgs,
    home-manager,
    ...
  }: let
    system = "x86_64-linux";
    user = "quang";

    hostMain = {
      hostname = "ubuntu-nix"; # Tên định danh cấu hình (không ảnh hưởng hostname thật của Ubuntu)
      stateVersion = "25.11"; # Hoặc 24.11 tùy thuộc vào config cũ của anh
    };
    pkgs = import nixpkgs {
      inherit system;
      config.allowUnfree = true;
    };
  in {
    formatter.${system} = pkgs.writeShellApplication {
      name = "nix-fmt";
      runtimeInputs = [pkgs.alejandra];
      text = ''
        if [ "$#" -eq 0 ]; then
          exec alejandra .
        else
          exec alejandra "$@"
        fi
      '';
    };

    # Thay thế nixosConfigurations bằng homeConfigurations độc lập
    homeConfigurations."${user}" = home-manager.lib.homeManagerConfiguration {
      inherit pkgs;

      # Truyền các tham số đặc biệt vào file home.nix y hệt cấu hình cũ của anh
      extraSpecialArgs = {
        inherit inputs hostMain user;
      };

      modules = [
        ./home.nix
      ];
    };
  };
}
