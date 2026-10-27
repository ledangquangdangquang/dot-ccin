{
  pkgs,
  inputs,
  ...
}: let
  ngosen = inputs.fcitx5-ngosen.packages.${pkgs.stdenv.hostPlatform.system}.fcitx5-ngosen;
in {
  home.sessionVariables = {
    XMODIFIERS = "@im=fcitx";
    GTK_IM_MODULE = "fcitx";
    QT_IM_MODULE = "fcitx";
  };

  home.packages = [
    (pkgs.qt6Packages.fcitx5-with-addons.override {
      addons = [ngosen];
    })
    ngosen
  ];
}
