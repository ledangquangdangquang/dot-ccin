{pkgs, ...}: {
  home.packages = with (import ./menu-util.nix {inherit pkgs;}); [
    menu
    menu-launcher
  ];
}
