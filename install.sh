#!/usr/bin/env bash
# Automates INSTALL.md steps 2-6. Run from the cloned repo: ./install.sh [--ddc]
set -euo pipefail
cd "$(dirname "$0")"

step() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }

ddc=false
[ "${1:-}" = "--ddc" ] && ddc=true

step "apt packages"
sudo apt update
sudo apt install -y git curl xz-utils i3 i3lock xss-lock xserver-xorg-input-libinput

step "Cloudflare WARP"
if ! command -v warp-cli >/dev/null; then
  curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg | sudo gpg --yes --dearmor --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg
  echo "deb [signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/cloudflare-client.list >/dev/null
  sudo apt-get update && sudo apt-get install -y cloudflare-warp
fi
sudo systemctl enable --now warp-svc
sleep 2 # warp-svc needs a moment before accepting CLI calls
warp-cli --accept-tos registration show >/dev/null 2>&1 || warp-cli --accept-tos registration new
warp-cli --accept-tos connect

step "flake user -> $USER"
sed -i "s/^\(\s*user = \)\"[^\"]*\";/\1\"$USER\";/" flake.nix
grep -q "user = \"$USER\";" flake.nix || { echo "failed to set user in flake.nix" >&2; exit 1; }

step "Nix"
if ! command -v nix >/dev/null && [ ! -e ~/.nix-profile/etc/profile.d/nix.sh ]; then
  curl -fsSL https://nixos.org/nix/install | sh -s -- --no-daemon
fi
set +u # nix.sh reads unset variables
# shellcheck source=/dev/null
. ~/.nix-profile/etc/profile.d/nix.sh
set -u
mkdir -p ~/.config/nix
grep -qs 'flakes' ~/.config/nix/nix.conf || echo "experimental-features = nix-command flakes" >>~/.config/nix/nix.conf
nix --version

step "Home Manager switch"
nix run github:nix-community/home-manager -- switch -b backup --flake ".#$USER"

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
echo "Check hostMain (audioSink, xrandrLayout) in flake.nix for this machine, then reboot and pick i3 from the GDM gear icon."
