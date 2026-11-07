{
  pkgs,
  lib,
  menu,
  ...
}: let
  clipboardWatcher = pkgs.writeShellApplication {
    name = "clipboard-watcher";
    runtimeInputs = with pkgs; [
      cliphist
      coreutils
      gnugrep
      xclip
    ];
    text = ''
      # Binary data goes through a file: bash variables drop NUL bytes and corrupt images
      tmp="$(mktemp -d)"
      trap 'rm -rf "$tmp"' EXIT
      last=""
      # timeout: xclip -o can hang forever on an owner that stops answering, freezing the loop
      while true; do
        if timeout 1 xclip -selection clipboard -t TARGETS -o 2>/dev/null | grep -qx 'image/png'; then
          timeout 2 xclip -selection clipboard -t image/png -o >"$tmp/clip" 2>/dev/null || true
        else
          timeout 1 xclip -selection clipboard -o >"$tmp/clip" 2>/dev/null || true
        fi
        sum="$(cksum <"$tmp/clip")"
        if [[ -s "$tmp/clip" && "$sum" != "$last" ]]; then
          cliphist store <"$tmp/clip" 2>/dev/null || true
        fi
        last="$sum"
        sleep 0.5
      done
    '';
  };

  # Rust TUI: history list with text/image preview (Mod+v)
  clipboardHistory = pkgs.rustPlatform.buildRustPackage {
    pname = "clipboard-history";
    version = "0.1.0";
    src = lib.fileset.toSource {
      root = ./.;
      fileset = lib.fileset.unions [./Cargo.toml ./Cargo.lock ./src];
    };
    cargoLock.lockFile = ./Cargo.lock;
    nativeBuildInputs = [pkgs.makeWrapper];
    postInstall = ''
      wrapProgram $out/bin/clipboard-history --prefix PATH : ${lib.makeBinPath [pkgs.cliphist pkgs.xclip]}
    '';
  };

  clipboardClear = pkgs.writeShellApplication {
    name = "clipboard-clear";
    runtimeInputs = with pkgs; [
      cliphist
      coreutils
      libnotify
      menu
    ];
    text = ''
      answer="$(printf 'Cancel\nClear history\n' | menu --dmenu --prompt='Clipboard ❯ ' --lines=2 --width=36)" || exit 0
      if [[ "$answer" == "Clear history" ]]; then
        cliphist wipe
        notify-send --app-name="Clipboard" --expire-time=1500 "Clipboard history cleared"
      fi
    '';
  };
in {
  home.packages = [
    clipboardWatcher
    clipboardHistory
    clipboardClear
  ];
}
