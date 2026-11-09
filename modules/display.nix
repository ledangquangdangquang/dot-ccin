{
  pkgs,
  menu,
  hostMain,
  ...
}: let
  baseInputs = with pkgs; [
    coreutils
    feh
    gawk
    xrandr
  ];

  scriptInputs = baseInputs ++ [connectedOutputs];

  # Re-apply wallpaper so the background follows the new layout
  applyWallpaper = ''
    feh --bg-fill --no-fehbg "$(cat "$HOME/.wallpaper" 2>/dev/null || echo "$HOME/dot-ccin/Wallpapers/wallpaper.png")"
  '';

  # List of connected outputs via xrandr
  connectedOutputs = pkgs.writeShellApplication {
    runtimeInputs = baseInputs;
    name = "display-outputs";
    text = ''
      xrandr --query | awk '/ connected /{print $1}'
    '';
  };

  # Set primary output
  setPrimary = pkgs.writeShellApplication {
    runtimeInputs = scriptInputs;
    name = "display-set-primary";
    text = ''
      primary="$1"
      xrandr --output "$primary" --primary
      ${applyWallpaper}
    '';
  };

  # Extend: primary stays primary, every other connected output to the right
  extendScript = pkgs.writeShellApplication {
    runtimeInputs = scriptInputs;
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

  # Duplicate: mirror every output to the primary resolution and position
  duplicateScript = pkgs.writeShellApplication {
    runtimeInputs = scriptInputs;
    name = "display-duplicate";
    text = ''
      mapfile -t outputs < <(display-outputs)
      primary="''${outputs[0]}"
      mode="$(xrandr --query | awk -v out="$primary" '$0 ~ "^" out " connected" {getline; print $1; exit}')"
      xrandr --output "$primary" --mode "$mode" --pos 0x0
      for out in "''${outputs[@]:1}"; do
        xrandr --output "$out" --mode "$mode" --pos 0x0
      done
      ${applyWallpaper}
    '';
  };

  # Only: turn everything off except the chosen output
  onlyScript = pkgs.writeShellApplication {
    runtimeInputs = scriptInputs;
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
    runtimeInputs =
      (with pkgs; [
        menu
        xrandr
      ])
      ++ [
        connectedOutputs
        setPrimary
        extendScript
        duplicateScript
        onlyScript
      ];
    text = ''
      choice="$({
        printf '󰧑  Extend\textend\n'
        printf '󰧑  Duplicate\tduplicate\n'
        printf '󰧑  Only...\tonly\n'
        printf '󰧑  Set primary...\tprimary\n'
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
  # popup-toggle CLASS CMD...: close the window with that i3 class if open, else run CMD
  popupToggle = pkgs.writeShellApplication {
    runtimeInputs = [pkgs.jq];
    name = "popup-toggle";
    text = ''
      class="$1"
      shift
      # i3-msg comes from the externally installed i3
      if i3-msg -t get_tree | jq -e --arg c "$class" 'any(.. | .window_properties?.class? // empty; . == $c)' >/dev/null; then
        exec i3-msg "[class=\"^$class\$\"] kill" >/dev/null
      fi
      exec "$@"
    '';
  };

  # Floating Alacritty popup (toggles): float-term [--size COLSxLINES] CLASS CMD...
  # --size sizes the window in cells so it fits the content on any monitor; its i3
  # for_window rule must then skip "resize set".
  # winit rescales a window when i3 moves it to a monitor with another DPI, shrinking it
  # off-center after i3's "move position center". Pin the scale to the focused monitor's,
  # using winit's X11 formula (1/12 steps, min 1).
  floatTerm = pkgs.writeShellApplication {
    runtimeInputs = baseInputs ++ [pkgs.jq popupToggle];
    name = "float-term";
    text = ''
      size=()
      if [ "$1" = "--size" ]; then
        size=(-o "window.dimensions.columns=''${2%x*}" -o "window.dimensions.lines=''${2#*x}")
        shift 2
      fi
      class="$1"
      shift
      out="$(i3-msg -t get_workspaces | jq -r '.[] | select(.focused).output')"
      scale="$(xrandr --query | awk -v o="$out" '$1 == o {
        for (i = 1; i <= NF; i++) {
          if ($i ~ /^[0-9]+x[0-9]+\+/) { split($i, r, /[x+]/); w = r[1]; h = r[2] }
          if ($i ~ /^[0-9]+mm$/) { if (!wmm) wmm = $i + 0; else hmm = $i + 0 }
        }
        f = 1
        if (wmm && hmm) { f = int(sqrt(w * h / (wmm * hmm)) * 12 * 25.4 / 96 + 0.5) / 12; if (f < 1) f = 1 }
        printf "%.4f\n", f
      }')"
      WINIT_X11_SCALE_FACTOR="''${scale:-1}" exec popup-toggle "$class" alacritty --class "$class" -o font.size=10 "''${size[@]}" -e "$@"
    '';
  };
in {
  home.packages = [
    popupToggle
    floatTerm
    connectedOutputs
    setPrimary
    extendScript
    duplicateScript
    onlyScript
    displayMenu
  ];

  # Included by dotfiles/i3/config; keeps machine-specific values in flake.nix
  xdg.configFile."i3/host.conf".text = ''
    exec --no-startup-id xrandr | grep -q '^${hostMain.xrandrOutput} connected' && xrandr ${hostMain.xrandrLayout}
  '';
}
