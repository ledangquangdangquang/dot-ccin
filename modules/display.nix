{pkgs, ...}: let
  menu = (import ./menu-util.nix {inherit pkgs;}).menu;

  runtimeInputs = with pkgs; [
    coreutils
    feh
    gnugawk
    xorg.xrandr
  ];

  # Re-apply wallpaper so the background follows the new layout
  applyWallpaper = ''
    feh --bg-fill --no-fehbg "$(cat "$HOME/.wallpaper" 2>/dev/null || echo "$HOME/UbuntuConfig/Wallpapers/wallpaper.png")"
  '';

  # List of connected outputs via xrandr
  connectedOutputs = pkgs.writeShellApplication {
    inherit runtimeInputs;
    name = "display-outputs";
    text = ''
      xrandr --query | awk '/ connected /{print $1}'
    '';
  };

  # Set primary output
  setPrimary = pkgs.writeShellApplication {
    inherit runtimeInputs;
    name = "display-set-primary";
    text = ''
      primary="$1"
      xrandr --output "$primary" --primary
      ${applyWallpaper}
    '';
  };

  # Extend: primary stays primary, every other connected output to the right
  extendScript = pkgs.writeShellApplication {
    inherit runtimeInputs;
    name = "display-extend";
    text = ''
      mapfile -t outputs < <(display-outputs)
      primary="''${outputs[0]}"
      for out in "''${outputs[@]}"; do
        if [[ "$out" == "$primary" ]]; then
          xrandr --output "$out" --primary --auto --pos 0x0
        else
          xrandr --output "$out" --auto --right-of "$primary"
        fi
      done
      ${applyWallpaper}
    '';
  };

  # Duplicate: mirror every output to the primary
  duplicateScript = pkgs.writeShellApplication {
    inherit runtimeInputs;
    name = "display-duplicate";
    text = ''
      mapfile -t outputs < <(display-outputs)
      primary="''${outputs[0]}"
      for out in "''${outputs[@]}"; do
        xrandr --output "$out" --same-as "$primary"
      done
      ${applyWallpaper}
    '';
  };

  # Only: turn everything off except the chosen output
  onlyScript = pkgs.writeShellApplication {
    inherit runtimeInputs;
    name = "display-only";
    text = ''
      target="$1"
      mapfile -t outputs < <(display-outputs)
      for out in "''${outputs[@]}"; do
        if [[ "$out" == "$target" ]]; then
          xrandr --output "$out" --primary --auto
        else
          xrandr --output "$out" --off
        fi
      done
      ${applyWallpaper}
    '';
  };

  # Interactive menu: Extend / Duplicate / Only / Pick primary
  displayMenu = pkgs.writeShellApplication {
    name = "display-menu";
    runtimeInputs = with pkgs; [
      menu
      xorg.xrandr
    ];
    text = ''
      choice="$({
        printf '󰧑  Extend\t extend\n'
        printf '󰧑  Duplicate\t duplicate\n'
        printf '󰧑  Only...\t only\n'
        printf '󰧑  Set primary...\t primary\n'
      } | menu --dmenu --with-nth=1 --prompt='Display ❯ ' --lines=4 --width=36)" || exit 0

      IFS=$'\t' read -r _ action <<< "$choice"

      case "$action" in
        extend)
          display-extend
          ;;
        duplicate)
          display-duplicate
          ;;
        only|primary)
          target="$(display-outputs | menu --dmenu --prompt='Output ❯ ' --lines=5 --width=24)" || exit 0
          [[ -z "$target" ]] && exit 0
          if [[ "$action" == "only" ]]; then
            display-only "$target"
          else
            display-set-primary "$target"
          fi
          ;;
      esac
    '';
  };
in {
  home.packages = [
    connectedOutputs
    setPrimary
    extendScript
    duplicateScript
    onlyScript
    displayMenu
  ];
}
