{pkgs}: let
  menu = pkgs.writeShellApplication {
    name = "menu";
    runtimeInputs = with pkgs; [
      coreutils
      fuzzel
      gawk
      gnugrep
      rofi
    ];
    text = ''
      prompt=""
      lines=10
      width=50
      password=0
      prompt_only=""
      with_nth=""
      while [ $# -gt 0 ]; do
        case "$1" in
          --dmenu) ;;
          --with-nth=*) with_nth="''${1#--with-nth=}" ;;
          --prompt=*) prompt="''${1#--prompt=}" ;;
          --lines=*) lines="''${1#--lines=}" ;;
          --width=*) width="''${1#--width=}" ;;
          --password) password=1 ;;
          --prompt-only=*) prompt_only="''${1#--prompt-only=}" ;;
        esac
        shift
      done

      if [[ -n "''${WAYLAND_DISPLAY:-}" ]]; then
        args=(--dmenu)
        [[ -n "$with_nth" ]] && args+=(--with-nth="$with_nth")
        args+=(--prompt="$prompt" --lines="$lines" --width="$width")
        [[ "$password" = 1 ]] && args+=(--password)
        [[ -n "$prompt_only" ]] && args+=(--prompt-only="$prompt_only")
        exec fuzzel "''${args[@]}"
      fi

      tmpdir="''$(mktemp -d)"
      trap 'rm -rf "$tmpdir"' EXIT
      cat > "$tmpdir/rows"
      if [[ -n "$with_nth" ]]; then
        awk -F '\t' -v n="$with_nth" '{ print $n }' "$tmpdir/rows" > "$tmpdir/display"
      else
        awk -F '\t' '{ print $1 }' "$tmpdir/rows" > "$tmpdir/display"
      fi

      rargs=(-dmenu -i)
      rprompt="''${prompt_only:-$prompt}"
      [[ -n "$rprompt" ]] && rargs+=(-p "$rprompt")
      rargs+=(-lines "$lines" -width "$width")
      [[ "$password" = 1 ]] && rargs+=(-password)

      selected="$(rofi "''${rargs[@]}" < "$tmpdir/display")"
      rc=$?
      [[ $rc -ne 0 ]] && exit $rc

      if [[ ! -s "$tmpdir/rows" ]]; then
        printf '%s\n' "$selected"
        exit 0
      fi
      grep -F -m1 -e "$selected"$'\t' "$tmpdir/rows" || grep -F -m1 -e "$selected" "$tmpdir/rows"
    '';
  };

  menu-launcher = pkgs.writeShellApplication {
    name = "menu-launcher";
    runtimeInputs = with pkgs; [fuzzel rofi];
    text = ''
      if [[ -n "''${WAYLAND_DISPLAY:-}" ]]; then
        exec fuzzel
      else
        exec rofi -show drun
      fi
    '';
  };
in {
  inherit menu menu-launcher;
}
