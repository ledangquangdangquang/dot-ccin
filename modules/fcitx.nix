{
  pkgs,
  inputs,
  ...
}: let
  ngosen = inputs.fcitx5-ngosen.packages.${pkgs.stdenv.hostPlatform.system}.fcitx5-ngosen;
  # XIM sync mode deadlocks when a client destroys its IC mid key-forward
  # (Alacritty vi mode toggle) -> all keys swallowed until restart. fcitx/fcitx5#1641
  fcitx5 = pkgs.fcitx5.overrideAttrs (old: {
    postPatch =
      (old.postPatch or "")
      + ''
        substituteInPlace src/frontend/xim/xim.cpp \
          --replace-fail 'xcb_im_set_use_sync_mode(im_.get(), true)' 'xcb_im_set_use_sync_mode(im_.get(), false)'
      '';
  });
in {
  home.sessionVariables = {
    XMODIFIERS = "@im=fcitx";
    GTK_IM_MODULE = "fcitx";
    QT_IM_MODULE = "fcitx";
  };

  home.packages = [
    (pkgs.qt6Packages.fcitx5-with-addons.override {
      inherit fcitx5;
      addons = [ngosen];
    })
    ngosen
  ];
}
