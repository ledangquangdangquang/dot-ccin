{pkgs, ...}: {
  # WiFi/IP manager web UI (nmcli) on http://127.0.0.1:8765/, opened from the Firefox new tab (`w`).
  systemd.user.services.wifimanager = {
    Unit = {
      Description = "WiFi/IP manager web UI over nmcli";
      After = ["network.target"];
    };
    Service = {
      Type = "simple";
      # nmcli, iw, ip, dig, ping come from Ubuntu
      Environment = "PATH=/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin";
      ExecStart = "${pkgs.python3}/bin/python3 ${./app.py}";
      Restart = "on-failure";
    };
    Install.WantedBy = ["default.target"];
  };
}
