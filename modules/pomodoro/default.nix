{
  pkgs,
  lib,
  ...
}: let
  # Rust TUI: `pomodoro-task` opens the list, `show`/`done` serve the i3status-rust block
  pomodoroTask = pkgs.rustPlatform.buildRustPackage {
    pname = "pomodoro-task";
    version = "0.1.0";
    src = lib.fileset.toSource {
      root = ./.;
      fileset = lib.fileset.unions [./Cargo.toml ./Cargo.lock ./src];
    };
    cargoLock.lockFile = ./Cargo.lock;
  };
in {
  home.packages = [pomodoroTask];

  # i3status-rust watches this file with inotify, which requires it to
  # already exist before the bar starts. Create it if missing, never touch
  # its contents.
  home.activation.pomodoroTaskFile = lib.hm.dag.entryAfter ["writeBoundary"] ''
    run mkdir -p "$HOME/.cache"
    run touch -a "$HOME/.cache/pomodoro-tasks"
  '';
}
