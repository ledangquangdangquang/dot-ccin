# Install

Tested on Ubuntu 26.04 with GDM.

Quick path: after step 1, run `./install.sh` (add `--ddc` for step 6). It runs steps 2–6 and is safe to rerun.

## 1. Clone the repo

```bash
sudo apt install -y git curl xz-utils
git clone https://github.com/ledangquangdangquang/dot-ccin.git ~/dot-ccin
cd ~/dot-ccin
```

Set `user = "<your-username>"` in `flake.nix` (and adjust `hostMain` for your machine).

## 2. Install Nix

```bash
curl -fsSL https://nixos.org/nix/install | sh -s -- --no-daemon
. ~/.nix-profile/etc/profile.d/nix.sh
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
nix --version
```

## 3. Install i3 and system packages (apt)

These must come from apt (they need system PAM, Xorg drivers, or system services):

```bash
sudo apt install -y i3 i3lock xss-lock \
  xserver-xorg-input-libinput
```

## 4. Apply Home Manager

```bash
cd ~/dot-ccin
nix run github:nix-community/home-manager -- switch -b backup --flake ".#$USER"
```

Later runs: `rebuild` (zsh alias), or the same `nix run ... switch` without `-b backup`. Home Manager is not installed globally; it always runs through `nix run`.

Set Zsh as the default shell:

```bash
command -v zsh | sudo tee -a /etc/shells
chsh -s "$(command -v zsh)"
```

Log out and back in to apply (`echo $SHELL` should show the Nix zsh path).

## 5. Register the i3 session in GDM

The `i3` package installs `/usr/share/xsessions/i3.desktop`. Check it exists:

```bash
ls /usr/share/xsessions/
```

If missing, create it:

```bash
sudo tee /usr/share/xsessions/i3.desktop >/dev/null <<'DESKTOP'
[Desktop Entry]
Name=i3
Comment=improved dynamic tiling window manager
Exec=i3
TryExec=i3
Type=Application
DesktopNames=i3
DESKTOP
```

GDM only lists X11 sessions when Wayland is off. In `/etc/gdm3/custom.conf`, under `[daemon]`:

```ini
WaylandEnable=false
```

Then `sudo systemctl restart gdm3` (or reboot), pick **i3** from the gear icon on the login screen.

## 6. External monitor brightness (optional)

F6/F7 and the brightness keys set external-monitor brightness via `ddcutil` (DDC/CI), which needs access to `/dev/i2c-*`:

```bash
echo 'KERNEL=="i2c-[0-9]*", TAG+="uaccess"' | sudo tee /etc/udev/rules.d/60-ddcutil-i2c.rules
echo i2c-dev | sudo tee /etc/modules-load.d/i2c-dev.conf
sudo udevadm control --reload
sudo udevadm trigger --action=add --subsystem-match=i2c-dev --settle
```

Check with `ddcutil detect`: the monitor should list a `VCP version`. If it still says `Permission denied`, reboot. DDC/CI must be enabled in the monitor's OSD menu. Laptop panels use `brightnessctl` and need none of this.

## 7. Check for errors

| Symptom | Check / fix |
| --- | --- |
| i3 starts but mouse/keyboard dead | `grep "No input driver" ~/.local/share/xorg/Xorg.0.log` → `sudo apt install xserver-xorg-input-libinput` |
| i3 missing from GDM | `ls /usr/share/xsessions/`, `WaylandEnable=false` in `/etc/gdm3/custom.conf` |
| Black screen / session exits | `~/.local/share/xorg/Xorg.0.log`, `journalctl --user -b`, `i3 -C -c ~/.config/i3/config` (validate config) |
| Wrong monitor layout / no audio | `hostMain.xrandrLayout` / `audioSink` in `flake.nix`, then `rebuild` |
| Lock screen doesn't unlock | `/usr/bin/i3lock` must exist → `sudo apt install i3lock` |
| `nix: command not found` | `. ~/.nix-profile/etc/profile.d/nix.sh` or open a new terminal |
| `switch` fails: "would be clobbered" | rerun with `-b backup` |
| Commands missing after switch | log out and back in (reloads `~/.nix-profile` PATH) |

> `apt autoremove` after removing i3 can also remove `xserver-xorg-input-libinput`, `i3lock`, and `xss-lock`. Reinstall them with step 3.
