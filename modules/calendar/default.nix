{
  pkgs,
  lib,
  ...
}: let
  # Rust TUI: month calendar with Vietnamese lunar dates (bar clock left-click)
  lunarCalendar = pkgs.rustPlatform.buildRustPackage {
    pname = "lunar-calendar";
    version = "0.1.0";
    src = lib.fileset.toSource {
      root = ./.;
      fileset = lib.fileset.unions [./Cargo.toml ./Cargo.lock ./src];
    };
    cargoLock.lockFile = ./Cargo.lock;
  };
in {
  home.packages = [lunarCalendar];
}
