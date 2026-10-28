#!/usr/bin/env bash
# Automates INSTALL.md steps 2-6. Run from the cloned repo: ./install.sh [--ddc]
set -euo pipefail
cd "$(dirname "$0")"

step() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }

ddc=false
for arg in "$@"; do
  case "$arg" in
    --ddc) ddc=true ;;
    *) echo "unknown option: $arg (usage: ./install.sh [--ddc])" >&2; exit 1 ;;
  esac
done

step "apt packages"
sudo apt update
sudo apt install -y git curl xz-utils i3 i3lock xss-lock xserver-xorg-input-libinput
# Fcitx5 frontends: gtk4/qt6 are missing on older releases (e.g. 20.04), install what exists
frontends=()
for pkg in fcitx5-frontend-gtk3 fcitx5-frontend-gtk4 fcitx5-frontend-qt5 fcitx5-frontend-qt6; do
  if apt-cache show "$pkg" >/dev/null 2>&1; then frontends+=("$pkg"); else echo "skip $pkg (not in apt)"; fi
done
[ ${#frontends[@]} -eq 0 ] || sudo apt install -y "${frontends[@]}"
# i3 config uses gaps (4.22+) and tiling_drag (4.21+)
i3ver="$(i3 --version | awk '{print $3}')"
if [ "$(printf '%s\n' 4.22 "$i3ver" | sort -V | head -1)" != 4.22 ]; then
  echo "warning: i3 $i3ver < 4.22, gaps/tiling_drag will error (use Ubuntu 24.04+)" >&2
fi

step "flake user -> $USER"
sed -i "s/^\(\s*user = \)\"[^\"]*\";/\1\"$USER\";/" flake.nix
grep -q "user = \"$USER\";" flake.nix || { echo "failed to set user in flake.nix" >&2; exit 1; }

step "Nix"
if ! command -v nix >/dev/null && [ ! -e ~/.nix-profile/etc/profile.d/nix.sh ]; then
  curl -fsSL https://nixos.org/nix/install | sh -s -- --no-daemon
fi
set +u # nix.sh reads unset variables
for nixsh in ~/.nix-profile/etc/profile.d/nix.sh /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh; do
  # shellcheck source=/dev/null
  if [ -e "$nixsh" ]; then . "$nixsh"; break; fi
done
set -u
mkdir -p ~/.config/nix
grep -qs 'flakes' ~/.config/nix/nix.conf || echo "experimental-features = nix-command flakes" >>~/.config/nix/nix.conf
nix --version

step "Home Manager switch"
nix run --inputs-from . home-manager -- switch -b backup --flake ".#$USER"

step "GPU drivers for Nix apps"
# OpenGL apps (alacritty, kitty) need /run/opengl-driver (targets.genericLinux)
sudo "$(readlink -f ~/.nix-profile/bin/non-nixos-gpu-setup)"

step "zsh default shell"
zsh="$HOME/.nix-profile/bin/zsh"
grep -qxF "$zsh" /etc/shells || echo "$zsh" | sudo tee -a /etc/shells >/dev/null
[ "$(getent passwd "$USER" | cut -d: -f7)" = "$zsh" ] || chsh -s "$zsh"

step "i3 session in GDM"
if [ ! -e /usr/share/xsessions/i3.desktop ]; then
  sudo tee /usr/share/xsessions/i3.desktop >/dev/null <<'DESKTOP'
[Desktop Entry]
Name=i3
Comment=improved dynamic tiling window manager
Exec=i3
TryExec=i3
Type=Application
DesktopNames=i3
DESKTOP
fi
gdm=/etc/gdm3/custom.conf
if [ -e "$gdm" ]; then
  if grep -qE '^\s*#?\s*WaylandEnable=' "$gdm"; then
    sudo sed -i -E 's/^\s*#?\s*WaylandEnable=.*/WaylandEnable=false/' "$gdm"
  else
    sudo sed -i '/^\[daemon\]/a WaylandEnable=false' "$gdm"
  fi
else
  echo "warning: $gdm not found, set WaylandEnable=false manually" >&2
fi

if $ddc; then
  step "ddcutil i2c access"
  echo 'KERNEL=="i2c-[0-9]*", TAG+="uaccess"' | sudo tee /etc/udev/rules.d/60-ddcutil-i2c.rules >/dev/null
  echo i2c-dev | sudo tee /etc/modules-load.d/i2c-dev.conf >/dev/null
  sudo modprobe i2c-dev
  sudo udevadm control --reload
  sudo udevadm trigger --action=add --subsystem-match=i2c-dev --settle
fi

step "Done"
echo "Check hostMain (xrandrLayout) in flake.nix for this machine, then reboot and pick i3 from the GDM gear icon."
