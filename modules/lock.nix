{pkgs, ...}: let
  lockScreen = pkgs.writeShellApplication {
    name = "lock-screen";
    runtimeInputs = with pkgs; [swaylock];
    text = ''
      exec swaylock \
        --daemonize \
        --color 1e1e2e \
        --indicator-radius 100 \
        --indicator-thickness 8 \
        --ring-color 45475a \
        --inside-color 181825 \
        --key-hl-color cba6f7 \
        --bs-hl-color f38ba8 \
        --text-color cdd6f4
    '';
  };

  sessionIdle = pkgs.writeShellApplication {
    name = "session-idle";
    runtimeInputs = [
      lockScreen
      pkgs.sway
      pkgs.swayidle
    ];
    text = ''
      exec swayidle -w \
        timeout 600 'lock-screen' \
        timeout 900 'swaymsg "output * power off"' \
          resume 'swaymsg "output * power on"' \
        before-sleep 'lock-screen' \
        lock 'lock-screen'
    '';
  };
in {
  home.packages = [
    lockScreen
    sessionIdle
  ];
}
