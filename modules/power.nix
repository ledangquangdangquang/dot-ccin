{
  pkgs,
  menu,
  ...
}: let
  powerMenu = pkgs.writeShellApplication {
    name = "power-menu";
    runtimeInputs = with pkgs; [
      menu
      systemd
      xorg.xset
    ];
    text = ''
      choice="$({
        printf '󰌾  Lock\tlock\n'
        printf '󰒲  Suspend\tsuspend\n'
        printf '󰍃  Logout\tlogout\n'
        printf '󰜉  Reboot\treboot\n'
        printf '󰐥  Shutdown\tshutdown\n'
      } | menu --dmenu --with-nth=1 --prompt='Power ❯ ' --lines=5 --width=36)" || exit 0

      IFS=$'\t' read -r _ action <<< "$choice"

      confirm() {
        local label="$1"
        local answer
        answer="$(printf 'Cancel\n%s\n' "$label" | menu --dmenu --prompt='Confirm ❯ ' --lines=2 --width=36)" || return 1
        [[ "$answer" == "$label" ]]
      }

      case "$action" in
        lock)
          xset s activate
          ;;
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
