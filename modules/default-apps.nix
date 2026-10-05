{
  config,
  pkgs,
  ...
}: {
  # Firefox "show in folder" uses D-Bus FileManager1; override Ubuntu's Nautilus one
  xdg.dataFile."dbus-1/services/org.freedesktop.FileManager1.service".text = ''
    [D-BUS Service]
    Name=org.freedesktop.FileManager1
    Exec=${config.home.profileDirectory}/bin/Thunar --gapplication-service
  '';

  # GLib (Terminal=true apps like nvim.desktop) tries xdg-terminal-exec first, else Ubuntu's broken gnome-terminal
  home.packages = [pkgs.xdg-terminal-exec];
  xdg.configFile."xdg-terminals.list" = {
    text = "Alacritty.desktop\n";
    force = true;
  };

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

  # Thunar prefs; xfconfd owns thunar.xml (rewrites it), so set via xfconf-query instead of linking
  xfconf.settings.thunar = {
    default-view = "ThunarDetailsView";
    last-view = "ThunarDetailsView";
    misc-single-click = false;
    misc-expandable-folders = true;
    misc-symbolic-icons-in-sidepane = false;
    misc-image-preview-mode = "THUNAR_IMAGE_PREVIEW_MODE_STANDALONE";
    shortcuts-icon-size = "THUNAR_ICON_SIZE_32";
    tree-icon-size = "THUNAR_ICON_SIZE_24";
    last-details-view-zoom-level = "THUNAR_ZOOM_LEVEL_38_PERCENT";
    last-icon-view-zoom-level = "THUNAR_ZOOM_LEVEL_100_PERCENT";
    last-sort-column = "THUNAR_COLUMN_SIZE";
    last-sort-order = "GTK_SORT_DESCENDING";
    last-menubar-visible = true;
    last-statusbar-visible = true;
    last-side-pane = "THUNAR_SIDEPANE_TYPE_SHORTCUTS";
    last-image-preview-visible = true;
    last-location-bar = "ThunarLocationButtons";
  };

  xdg.configFile."mimeapps.list".force = true;
  xdg.dataFile."applications/mimeapps.list".force = true;

  xdg.mimeApps = {
    enable = true;

    defaultApplications = {
      "x-scheme-handler/terminal" = ["Alacritty.desktop"];
      "x-scheme-handler/http" = ["firefox.desktop"];
      "x-scheme-handler/https" = ["firefox.desktop"];
      "x-scheme-handler/about" = ["firefox.desktop"];
      "x-scheme-handler/unknown" = ["firefox.desktop"];

      "inode/directory" = ["thunar.desktop"];

      "application/pdf" = ["org.pwmt.zathura.desktop"];

      # thunar-archive-plugin picks the .tap of the mime default (was zathura-cb)
      "application/zip" = ["xarchiver.desktop"];
      "application/x-7z-compressed" = ["xarchiver.desktop"];
      "application/x-rar" = ["xarchiver.desktop"];
      "application/vnd.rar" = ["xarchiver.desktop"];
      "application/x-tar" = ["xarchiver.desktop"];
      "application/x-compressed-tar" = ["xarchiver.desktop"];
      "application/x-xz-compressed-tar" = ["xarchiver.desktop"];
      "application/x-zstd-compressed-tar" = ["xarchiver.desktop"];
      "application/gzip" = ["xarchiver.desktop"];

      # office files subclass application/zip; pin them or they inherit xarchiver
      "application/msword" = ["libreoffice-writer.desktop"];
      "application/vnd.openxmlformats-officedocument.wordprocessingml.document" = ["libreoffice-writer.desktop"];
      "application/vnd.oasis.opendocument.text" = ["libreoffice-writer.desktop"];
      "application/rtf" = ["libreoffice-writer.desktop"];
      "application/vnd.ms-excel" = ["libreoffice-calc.desktop"];
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" = ["libreoffice-calc.desktop"];
      "application/vnd.oasis.opendocument.spreadsheet" = ["libreoffice-calc.desktop"];
      "text/csv" = ["libreoffice-calc.desktop"];
      "application/vnd.ms-powerpoint" = ["libreoffice-impress.desktop"];
      "application/vnd.openxmlformats-officedocument.presentationml.presentation" = ["libreoffice-impress.desktop"];
      "application/vnd.oasis.opendocument.presentation" = ["libreoffice-impress.desktop"];

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
