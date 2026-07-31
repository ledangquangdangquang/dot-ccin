{pkgs, ...}: let
  menu = (import ./menu-util.nix {inherit pkgs;}).menu;
  powerMenu = pkgs.writeShellApplication {
    name = "power-menu";
    runtimeInputs = with pkgs; [
      menu
      systemd
    ];
    text = ''
      choice="$({
        printf '󰒲  Suspend\tsuspend\n'
        printf '󰍃  Logout\tlogout\n'
        printf '󰜉  Reboot\treboot\n'
        printf '󰐥  Shutdown\tshutdown\n'
      } | menu --dmenu --with-nth=1 --prompt='Power ❯ ' --lines=4 --width=36)" || exit 0

      IFS=$'\t' read -r _ action <<< "$choice"

      confirm() {
        local label="$1"
        local answer
        answer="$(printf 'Cancel\n%s\n' "$label" | menu --dmenu --prompt='Confirm ❯ ' --lines=2 --width=36)" || return 1
        [[ "$answer" == "$label" ]]
      }

      case "$action" in
        suspend)
          systemctl suspend
          ;;
        logout)
          confirm "Logout" && i3-msg exit
          ;;
        reboot)
          confirm "Reboot" && systemctl reboot
          ;;
        shutdown)
          confirm "Shutdown" && systemctl poweroff
          ;;
      esac
    '';
  };
in {
  home.packages = [powerMenu];
}
