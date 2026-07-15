{
  config,
  inputs,
  pkgs,
  hostMain,
  user,
  ...
}: let
  dotfiles = "${config.home.homeDirectory}/UbuntuConfig/dotfiles";
  create_symlink = path: config.lib.file.mkOutOfStoreSymlink path;

  # Tạo danh sách các ứng dụng cần tạo symlink từ thư mục dotfiles
  configApps = ["fuzzel" "sway" "swaync" "i3status-rust" "fcitx5" "foot" "weathr" "vicinae" "fastfetch" "btop" "bat" "DankMaterialShell" "nvim" "niri" "kitty" "starship" "yazi"];

  fuzzyvim = pkgs.writeShellApplication {
    name = "fuzzyvim";
    runtimeInputs = with pkgs; [
      bat
      fzf
      neovim
      ripgrep
    ];
    text = ''
      set -o pipefail

      rg --files --hidden --follow \
        -g '!.git' \
        -g '!node_modules' \
        -g '!target' \
        2>/dev/null |
        fzf --layout=reverse \
          --height=80% \
          --preview 'bat --style=numbers --color=always --line-range=:500 {}' \
          --preview-window='right:60%,border-left' \
          --bind 'enter:become(nvim -- {})'
    '';
  };

  screenshot = pkgs.writeShellApplication {
    name = "screenshot";
    runtimeInputs = with pkgs; [
      coreutils
      grim
      libnotify
      satty
      slurp
      wl-clipboard
    ];
    text = ''
      mode="''${1:-region}"
      screenshot_dir="''${HOME}/Pictures/Screenshots"
      screenshot_file="''${screenshot_dir}/Screenshot-$(date +'%Y-%m-%d_%H-%M-%S').png"

      mkdir -p "$screenshot_dir"

      select_region() {
        slurp -d -b '#1e1e2ecc' -c '#cba6f7ff' -s '#31324488' -w 2
      }

      edit_screenshot() {
        satty \
          --filename - \
          --fullscreen \
          --output-filename "$screenshot_file" \
          --copy-command wl-copy
      }

      case "$mode" in
        region)
          geometry="$(select_region)" || exit 0
          grim -g "$geometry" -t ppm - | edit_screenshot
          ;;
        full)
          grim -t ppm - | edit_screenshot
          ;;
        copy)
          geometry="$(select_region)" || exit 0
          grim -g "$geometry" -t png - | wl-copy --type image/png
          notify-send \
            --app-name="Screenshot" \
            --expire-time=2500 \
            "Screenshot copied" \
            "The selected region is in the clipboard"
          ;;
        *)
          echo "Usage: screenshot {region|full|copy}" >&2
          exit 2
          ;;
      esac
    '';
  };

  wifiMenu = pkgs.writeShellApplication {
    name = "wifi-menu";
    runtimeInputs = with pkgs; [
      coreutils
      fuzzel
      gawk
      libnotify
      networkmanager
    ];
    text = ''
      notify() {
        notify-send --app-name="Wi-Fi" --expire-time=3000 "$@"
      }

      wifi_state="$(nmcli -t -f WIFI general 2>/dev/null || true)"
      if [ "$wifi_state" = "enabled" ]; then
        toggle_label="󰖪  Turn Wi-Fi off"
        toggle_action="wifi-off"
      else
        toggle_label="󰖩  Turn Wi-Fi on"
        toggle_action="wifi-on"
      fi

      rows="$toggle_label"$'\t'"$toggle_action"$'\n'

      if [ "$wifi_state" = "enabled" ]; then
        rows+="󰑓  Rescan"$'\t'"rescan"$'\n'
        rows+="󰖪  Disconnect"$'\t'"disconnect"$'\n'

        networks="$(
          nmcli -t --escape no -f IN-USE,SIGNAL,SECURITY,SSID device wifi list --rescan yes 2>/dev/null |
            awk -F: '
              {
                active=$1; signal=$2; security=$3
                ssid=$0
                sub(/^[^:]*:[^:]*:[^:]*:/, "", ssid)
                if (ssid == "" || seen[ssid]++) next
                icon=(active == "*" ? "󰖩" : "󰤨")
                lock=(security == "--" || security == "" ? "" : " 󰌾")
                printf "%s  %s  %s%%%s\twifi\t%s\n", icon, ssid, signal, lock, ssid
              }
            '
        )"
        if [ -n "$networks" ]; then
          rows+="$networks"$'\n'
        fi
      fi

      choice="$(printf '%s' "$rows" | fuzzel --dmenu --with-nth=1 --prompt='Wi-Fi ❯ ' --lines=12 --width=55)" || exit 0
      IFS=$'\t' read -r _ action value <<< "$choice"

      case "$action" in
        wifi-on)
          nmcli radio wifi on && notify "Wi-Fi enabled"
          ;;
        wifi-off)
          nmcli radio wifi off && notify "Wi-Fi disabled"
          ;;
        rescan)
          nmcli device wifi rescan
          exec wifi-menu
          ;;
        disconnect)
          device="$(nmcli -t -f DEVICE,TYPE,STATE device | awk -F: '$2 == "wifi" && $3 == "connected" { print $1; exit }')"
          if [ -n "$device" ]; then
            nmcli device disconnect "$device" && notify "Wi-Fi disconnected"
          else
            notify "No active Wi-Fi connection"
          fi
          ;;
        wifi)
          if nmcli device wifi connect "$value" >/dev/null 2>&1; then
            notify "Connected" "$value"
            exit 0
          fi

          password="$(fuzzel --dmenu --prompt-only="Password for $value ❯ " --password --width=55)" || exit 0
          [ -n "$password" ] || exit 0
          if nmcli device wifi connect "$value" password "$password"; then
            notify "Connected" "$value"
          else
            notify -u critical "Connection failed" "$value"
          fi
          ;;
      esac
    '';
  };

  bluetoothMenu = pkgs.writeShellApplication {
    name = "bluetooth-menu";
    runtimeInputs = with pkgs; [
      bluez
      coreutils
      fuzzel
      gawk
      gnugrep
      libnotify
    ];
    text = ''
      notify() {
        notify-send --app-name="Bluetooth" --expire-time=3000 "$@"
      }

      if bluetoothctl show 2>/dev/null | grep -q 'Powered: yes'; then
        power_label="󰂲  Turn Bluetooth off"
        power_action="power-off"
      else
        power_label="󰂲  Turn Bluetooth on"
        power_action="power-on"
      fi

      build_rows() {
        printf '%s\t%s\n' "$power_label" "$power_action"
        [ "$power_action" = "power-on" ] && return

        printf '󰑓  Scan for devices\tscan\n'
        while read -r _ mac name; do
          [ -n "''${mac:-}" ] || continue
          if bluetoothctl info "$mac" 2>/dev/null | grep -q 'Connected: yes'; then
            printf '󰂱  %s  Connected\tdevice\t%s\n' "$name" "$mac"
          else
            printf '󰂯  %s\tdevice\t%s\n' "$name" "$mac"
          fi
        done < <(bluetoothctl devices 2>/dev/null)
      }

      choice="$(build_rows | fuzzel --dmenu --with-nth=1 --prompt='Bluetooth ❯ ' --lines=12 --width=55)" || exit 0
      IFS=$'\t' read -r _ action mac <<< "$choice"

      case "$action" in
        power-on)
          bluetoothctl power on >/dev/null && notify "Bluetooth enabled"
          ;;
        power-off)
          bluetoothctl power off >/dev/null && notify "Bluetooth disabled"
          ;;
        scan)
          notify "Scanning for Bluetooth devices…"
          bluetoothctl --timeout 8 scan on >/dev/null 2>&1 || true
          exec bluetooth-menu
          ;;
        device)
          name="$(bluetoothctl info "$mac" 2>/dev/null | awk -F': ' '/^[[:space:]]*Name:/ { print $2; exit }')"
          if bluetoothctl info "$mac" 2>/dev/null | grep -q 'Connected: yes'; then
            if bluetoothctl disconnect "$mac" >/dev/null; then
              notify "Disconnected" "$name"
            else
              notify -u critical "Could not disconnect" "$name"
            fi
          elif bluetoothctl connect "$mac" >/dev/null 2>&1; then
            notify "Connected" "$name"
          else
            notify "Pairing…" "$name"
            if bluetoothctl --timeout 30 --agent NoInputNoOutput pair "$mac" >/dev/null 2>&1 &&
              bluetoothctl trust "$mac" >/dev/null 2>&1 &&
              bluetoothctl connect "$mac" >/dev/null 2>&1; then
              notify "Paired and connected" "$name"
            else
              notify -u critical "Pairing failed" "Try pairing $name from a terminal if it requires a PIN."
            fi
          fi
          ;;
      esac
    '';
  };
in {
  imports = [
    inputs.catppuccin.homeModules.catppuccin
    ./modules
  ];

  catppuccin.autoEnable = true;

  home.username = "${user}";
  home.homeDirectory = "/home/${user}";
  home.stateVersion = hostMain.stateVersion;
  home.sessionVariables = {
    XMODIFIERS = "@im=fcitx";
    GTK_IM_MODULE = "fcitx";
    QT_IM_MODULE = "fcitx";
  };
  targets.genericLinux.enable = true;

  # Tối ưu hóa toàn bộ phần định nghĩa xdg.configFile cũ bằng một vòng lặp map
  xdg.configFile =
    builtins.listToAttrs (map (app: {
        name = app;
        value = {
          source = create_symlink "${dotfiles}/${app}/";
          recursive = true;
        };
      })
      configApps)
    // {
      "sway/keyshortcuts.txt".source = create_symlink "${dotfiles}/sway/keyshortcuts.txt";
      "sway/show-keyshortcuts.sh".source = create_symlink "${dotfiles}/sway/show-keyshortcuts.sh";
    };

  home.packages = with pkgs; [
    i3status-rust
    nerd-fonts.fira-code
    wl-clipboard
    pulseaudio
    nwg-displays
    wl-mirror
    vicinae
    fzf
    tree
    bat
    git
    fuzzel
    grim
    slurp
    satty
    swaynotificationcenter
    libnotify
    fastfetch
    swaybg
    neovim
    alejandra
    ripgrep
    shfmt
    stylua
    tree-sitter
    nil
    nixpkgs-fmt
    nodejs
    btop
    gcc
    yazi
    starship
    #kitty
    foot
    kew
    ddcutil # brightness
    eza # alternative ls
    fuzzyvim
    screenshot
    wifiMenu
    bluetoothMenu
    (qt6Packages.fcitx5-with-addons.override {
      addons = [
        qt6Packages.fcitx5-unikey
      ];
    })
    #discord
    #opencode
  ];
}
