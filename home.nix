{
  inputs,
  hostMain,
  user,
  ...
}: {
  imports = [
    inputs.catppuccin.homeModules.catppuccin
    ./modules
  ];

  catppuccin.enable = true;
  catppuccin.autoEnable = true;

  home.username = user;
  home.homeDirectory = "/home/${user}";
  home.stateVersion = hostMain.stateVersion;
  targets.genericLinux.enable = true;

  home.sessionVariables.TERMINAL = "alacritty";
}
