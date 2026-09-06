# UbuntuConfig

> Dotfiles Ubuntu quản lý bằng Nix flakes + Home Manager. Cài đặt mọi app, config và keybinding theo một lần `switch`.

## Dùng gì

| Nhóm | Công cụ |
| --- | --- |
| Window Manager | **i3** (cài ngoài, i3status-rust) |
| Shell | **Zsh** + Starship |
| Terminal | **Kitty**, Alacritty |
| Launcher | **Rofi**, Fuzzel |
| Editor | **Neovim** + fuzzyvim (Fzf) |
| File Manager | **Yazi** (5 plugin) |
| Browser | **Firefox** (custom CSS) |
| Notification | **dunst** |
| Screenshot | Grim + Slurp + Satty |
| Power Menu | Menu + power (Fuzzel) |
| Ngoài ra | Fcitx5+Unikey, Git, GTK, Tmux, Btop, Bat, Eza, Picom, Kanshi, Wallpaper, Clipboard, VLC, nix-cleanup |

## Cấu trúc

```text
flake.nix          # inputs, hostname, user, stateVersion
home.nix           # entry point tối thiểu (import ./modules)
modules/           # logic Home Manager, mỗi app một file
  ├── default.nix  # index — đăng ký module mới ở đây
  ├── packages.nix # danh sách gói cài chung
  └── dotfiles.nix # symlink dotfiles/<app>/ → ~/.config/<app>
dotfiles/          # config thô, thư mục con = 1 app
Wallpapers/        # hình nền
```

## Cách vận hành

1. **Thêm gói** → `modules/packages.nix`
2. **Thêm config app** (file thường) → tạo `dotfiles/<app>/`, rồi thêm `"<app>"` vào danh sách `configApps` trong `modules/dotfiles.nix`
3. **Logic Home Manager** (systemd, alias, env) → file mới trong `modules/`, import từ `modules/default.nix`
4. **Áp dụng** → `home-manager switch --flake ".#$USER"`

Cấu hình dạng file (i3, kitty, nvim...) là **symlink** vào repo, chỉnh là nhận ngay. Gói bám theo `flake.lock` — tái lập được. WM chạy ngoài; repo chỉ cấu hình.

## Lệnh thường dùng

```bash
home-manager switch --flake ".#\$(whoami)"   # áp dụng config
nix flake check                              # kiểm tra trước khi switch
nix fmt                                      # format file .nix
nix store gc                                 # dọn /nix/store đầy
```

## Cài mới

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/ledangquangdangquang/UbuntuConfig/main/install.sh)
```
Cài Nix, clone repo về `~/UbuntuConfig`, gán user vào `flake.nix`, switch, đặt zsh mặc định.

## Ghi chú

- Phím tắt i3: `Mod+i` xem `dotfiles/i3/keyshortcuts.txt`
- Alias shell trong `modules/zsh.nix`
- Config i3 kiểm tra parse: `i3 -t get_version` / xem log `~/.i3/log` khi lỗi
- Không commit secret, SSH key, session trình duyệt