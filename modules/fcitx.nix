{pkgs, ...}: {
  home.sessionVariables = {
    XMODIFIERS = "@im=fcitx";
    GTK_IM_MODULE = "fcitx";
    QT_IM_MODULE = "fcitx";
  };

  home.packages = [
    (pkgs.qt6Packages.fcitx5-with-addons.override {
      addons = [pkgs.qt6Packages.fcitx5-unikey];
    })
  ];
}
