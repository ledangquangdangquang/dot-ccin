{pkgs, ...}: {
  home.packages = [
    # Run by i3. shortcut: settings are lost if X re-adds the device, use xorg.conf.d if resume resets them
    (pkgs.writeShellApplication {
      name = "touchpad-setup";
      runtimeInputs = with pkgs; [gnugrep xinput];
      text = ''
        xinput list --name-only | grep -i touchpad | while IFS= read -r dev; do
          xinput set-prop "$dev" "libinput Tapping Enabled" 1
          xinput set-prop "$dev" "libinput Natural Scrolling Enabled" 1
          xinput set-prop "$dev" "libinput Click Method Enabled" 0 1 # 2-finger press = right click
          xinput set-prop "$dev" "libinput Accel Speed" 0.3
        done
      '';
    })
  ];
}
