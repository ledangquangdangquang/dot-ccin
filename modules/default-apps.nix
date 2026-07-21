{
  xdg.configFile."mimeapps.list".force = true;
  xdg.dataFile."applications/mimeapps.list".force = true;

  xdg.mimeApps = {
    enable = true;

    defaultApplications = {
      "x-scheme-handler/terminal" = ["foot.desktop"];

      "application/pdf" = ["org.pwmt.zathura.desktop"];

      "text/plain" = ["nvim.desktop"];
      "text/markdown" = ["nvim.desktop"];
      "text/x-markdown" = ["nvim.desktop"];
      "text/x-readme" = ["nvim.desktop"];
      "text/x-rst" = ["nvim.desktop"];
    };
  };
}
