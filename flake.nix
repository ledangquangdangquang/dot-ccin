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
      stateVersion = "25.11";
      # Machine-specific; written to ~/.config/i3/host.conf by modules/display.nix
      audioSink = "alsa_output.pci-0000_00_1f.3-platform-skl_hda_dsp_generic.HiFi__hw_sofhdadsp__sink";
      xrandrLayout = "--output eDP-1 --off --output HDMI-1-0 --auto";
    };
    pkgs = import nixpkgs {
      inherit system;
      config.allowUnfree = true;
    };

    mkHome = targetUser:
      home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        extraSpecialArgs = {
          inherit inputs hostMain;
          user = targetUser;
        };
        modules = [
          ./home.nix
        ];
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

    homeConfigurations."${user}" = mkHome user;
  };
}
