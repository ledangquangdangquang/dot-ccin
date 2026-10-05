{config, ...}: {
  # Firefox "show in folder" uses D-Bus FileManager1; override Ubuntu's Nautilus one
  xdg.dataFile."dbus-1/services/org.freedesktop.FileManager1.service".text = ''
    [D-BUS Service]
    Name=org.freedesktop.FileManager1
    Exec=${config.home.profileDirectory}/bin/Thunar --gapplication-service
  '';

  # Thunar (exo) terminal helper: "Open Terminal Here", Terminal=true apps
  xdg.configFile."xfce4/helpers.rc".text = "TerminalEmulator=alacritty\n";
  xdg.dataFile."xfce4/helpers/alacritty.desktop".text = ''
    [Desktop Entry]
    Version=1.0
    Type=X-XFCE-Helper
    Name=Alacritty
    X-XFCE-Category=TerminalEmulator
    X-XFCE-Commands=alacritty
    X-XFCE-CommandsWithParameter=alacritty -e %s
  '';

  xdg.configFile."mimeapps.list".force = true;
  xdg.dataFile."applications/mimeapps.list".force = true;

  xdg.mimeApps = {
    enable = true;

    defaultApplications = {
      "x-scheme-handler/terminal" = ["alacritty.desktop"];
      "x-scheme-handler/http" = ["firefox.desktop"];
      "x-scheme-handler/https" = ["firefox.desktop"];
      "x-scheme-handler/about" = ["firefox.desktop"];
      "x-scheme-handler/unknown" = ["firefox.desktop"];

      "inode/directory" = ["thunar.desktop"];

      "application/pdf" = ["org.pwmt.zathura.desktop"];

      "text/html" = ["firefox.desktop"];
      "application/xhtml+xml" = ["firefox.desktop"];
      "application/x-extension-htm" = ["firefox.desktop"];
      "application/x-extension-html" = ["firefox.desktop"];
      "application/x-extension-shtml" = ["firefox.desktop"];
      "application/x-extension-xhtml" = ["firefox.desktop"];
      "application/x-extension-xht" = ["firefox.desktop"];

      "application/json" = ["nvim.desktop"];
      "application/xml" = ["nvim.desktop"];
      "application/rss+xml" = ["nvim.desktop"];

      "text/plain" = ["nvim.desktop"];
      "text/markdown" = ["nvim.desktop"];
      "text/x-markdown" = ["nvim.desktop"];
      "text/x-readme" = ["nvim.desktop"];
      "text/x-rst" = ["nvim.desktop"];
    };
  };
}
