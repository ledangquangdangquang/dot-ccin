{
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
