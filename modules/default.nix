{pkgs, ...}: {
  _module.args.menu = (import ./menu-util.nix {inherit pkgs;}).menu;

  imports = [
    # --- File ---
    ./gtk.nix
    ./git.nix
    ./zsh.nix
    ./bash.nix
    ./tmux.nix
    ./nix-cleanup.nix
    ./dotfiles.nix
    ./default-apps.nix
    ./vlc.nix
    ./packages.nix
    ./fcitx.nix
    ./fuzzyvim.nix
    ./screenshot.nix
    ./pomodoro
    ./lofi
    ./calendar
    ./wallpaper.nix
    ./notifications.nix
    ./power.nix
    ./lock.nix
    ./display.nix
    ./audio.nix
    ./clipboard
    ./menu.nix
    ./yazi.nix
    ./grayscale.nix
    # --- Folder ---
    ./firefox
  ];
}
