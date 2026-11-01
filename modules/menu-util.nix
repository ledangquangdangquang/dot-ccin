{pkgs}: let
  menu = pkgs.writeShellApplication {
    name = "menu";
    runtimeInputs = with pkgs; [
      coreutils
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
      custom=0
      while [ $# -gt 0 ]; do
        case "$1" in
          --dmenu) ;;
          --with-nth=*) with_nth="''${1#--with-nth=}" ;;
          --prompt=*) prompt="''${1#--prompt=}" ;;
          --lines=*) lines="''${1#--lines=}" ;;
          --width=*) width="''${1#--width=}" ;;
          --password) password=1 ;;
          --custom) custom=1 ;;
          --prompt-only=*) prompt_only="''${1#--prompt-only=}" ;;
        esac
        shift
      done

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
      # Exact match on the shown column; ENVIRON avoids awk -v backslash escapes.
      # --custom: unmatched typed text is printed as-is (no tab field).
      if [[ "$custom" = 1 ]] && ! S="$selected" awk -F '\t' -v n="''${with_nth:-1}" '$n == ENVIRON["S"] { f = 1; exit } END { exit !f }' "$tmpdir/rows"; then
        printf '%s\n' "$selected"
        exit 0
      fi
      S="$selected" awk -F '\t' -v n="''${with_nth:-1}" '$n == ENVIRON["S"] { print; f = 1; exit } END { exit !f }' "$tmpdir/rows"
    '';
  };

  menu-launcher = pkgs.writeShellApplication {
    name = "menu-launcher";
    runtimeInputs = with pkgs; [rofi];
    text = ''
      exec rofi -show drun
    '';
  };
in {
  inherit menu menu-launcher;
}
