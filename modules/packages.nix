{pkgs, ...}: {
  home.packages = with pkgs; [
    i3status-rust
    nerd-fonts.fira-code
    fum
    fzf
    tree
    bat
    git
    rofi
    xclip
    udiskie
    maim
    fastfetch
    feh
    neovim
    alejandra
    ripgrep
    shfmt
    stylua
    tree-sitter
    nil
    pyright
    clang-tools
    matlab-language-server
    vscode-langservers-extracted
    vtsls
    btop
    # Esc quits, after first cancelling a follow/search
    (htop.overrideAttrs (old: {
      postPatch =
        (old.postPatch or "")
        + "substituteInPlace MainPanel.c --replace-fail '(ch == 27)' '(ch == 27 && host->activeTable->following != -1)'";
    }))
    # Wi-Fi TUI (NetworkManager), replaces nm-applet. Esc quits, after first clearing a filter
    (wifitui.overrideAttrs (old: {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace internal/tui/list.go \
            --replace-fail 'case "q":' 'case "q", "esc":' \
            --replace-fail 'm.list.FilterState() != list.Filtering' 'msg.String() == "q" || m.list.FilterState() == list.Unfiltered'
        '';
    }))
    gcc
    alacritty
    starship
    zathura
    ffmpeg
    kitty
    kew
    brightnessctl # laptop/internal display brightness
    ddcutil # brightness
    eza # alternative ls
    # right-click extract/compress; plugin only reads .tap from its own libexec, so add xarchiver's
    (thunar.override {
      thunarPlugins = [
        (thunar-archive-plugin.overrideAttrs (old: {
          postInstall = (old.postInstall or "") + "cp ${xarchiver}/libexec/thunar-archive-plugin/xarchiver.tap $out/libexec/thunar-archive-plugin/";
        }))
      ];
    })
    xarchiver # archive backend for thunar-archive-plugin
    bluetui
    picom
    pavucontrol # volume mixer (bar sound block left-click)
    xdotool # replay real F-key press when media F-keys are toggled off
    xbanish # hide mouse cursor while typing
    (python3.withPackages (ps: [ps.i3ipc]))
  ];
}
