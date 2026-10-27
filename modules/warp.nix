{lib, ...}: {
  # Cloudflare WARP is installed via apt; enforce 1.1.1.3 Families mode (malware + adult blocking).
  home.activation.warpFamilies = lib.hm.dag.entryAfter ["writeBoundary"] ''
    if [ -x /usr/bin/warp-cli ]; then
      run /usr/bin/warp-cli --accept-tos dns families full || true
    fi
  '';
}
