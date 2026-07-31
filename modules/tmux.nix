{pkgs, ...}: let
  tmuxSessionPicker = pkgs.writeShellApplication {
    name = "tmux-session-picker";
    runtimeInputs = with pkgs; [fzf tmux];
    text = ''
      if [[ "''${1:-}" == "--preview" ]]; then
        tmux capture-pane -ep -S -200 -t "$2:"
        exit 0
      fi

      previewCommand="$(printf '%q' "$0") --preview {}"

      while true; do
        selection="$(${pkgs.tmux}/bin/tmux list-sessions -F '#{session_name}' \
          | ${pkgs.fzf}/bin/fzf \
            --expect=enter,r,x \
            --header='Enter: switch  r: rename  x: kill' \
            --preview="$previewCommand" \
            --preview-window='right,65%,border-left' \
            --prompt='Sessions> ')" || exit 0

        key="''${selection%%$'\n'*}"
        session="''${selection#*$'\n'}"

        case "$key" in
          enter)
            tmux switch-client -t "$session"
            exit 0
            ;;
          r)
            read -r -p "Rename '$session' to: " newName
            if [[ -n "$newName" ]]; then
              tmux rename-session -t "$session" "$newName" || read -r -p 'Press Enter to continue...'
            fi
            ;;
          x)
            read -r -p "Kill session '$session'? [y/N] " confirm
            if [[ "$confirm" == [yY] ]]; then
              tmux kill-session -t "$session"
            fi
            ;;
        esac
      done
    '';
  };
in {
  programs.tmux = {
    enable = true;
    baseIndex = 1;
    clock24 = true;
    escapeTime = 10;
    historyLimit = 50000;
    keyMode = "vi";
    mouse = true;
    prefix = "M-a";
    sensibleOnTop = true;
    terminal = "tmux-256color";

    plugins = with pkgs.tmuxPlugins; [
      {
        plugin = catppuccin;
        extraConfig = ''
          set -g @catppuccin_flavor 'mocha'
          set -g @catppuccin_window_status_style 'rounded'
          set -g @catppuccin_window_number_position 'right'
          set -g @catppuccin_status_modules_right 'session date_time'
          set -g @catppuccin_date_time_text '%H:%M %d/%m/%Y'
        '';
      }
      {
        plugin = resurrect;
        extraConfig = ''
          set -g @resurrect-capture-pane-contents 'on'
          set -g @resurrect-strategy-nvim 'session'
        '';
      }
      {
        plugin = continuum;
        extraConfig = ''
          set -g @continuum-restore 'on'
          set -g @continuum-save-interval '15'
        '';
      }
    ];

    extraConfig = ''
      set -g renumber-windows on
      set -g set-clipboard on

      set -g status-position top

      bind r source-file ~/.config/tmux/tmux.conf \; display-message 'tmux config reloaded'
      bind s display-popup -E -w 70% -h 70% '${tmuxSessionPicker}/bin/tmux-session-picker'
      bind | split-window -h -c '#{pane_current_path}'
      bind - split-window -v -c '#{pane_current_path}'
      bind c new-window -c '#{pane_current_path}'

      bind-key -T copy-mode-vi y send-keys -X copy-pipe-and-cancel 'if [[ -n "''${WAYLAND_DISPLAY:-}" ]]; then wl-copy; else xclip -selection clipboard; fi'

      bind -n M-h select-pane -L
      bind -n M-j select-pane -D
      bind -n M-k select-pane -U
      bind -n M-l select-pane -R

      bind -n M-H resize-pane -L 5
      bind -n M-J resize-pane -D 5
      bind -n M-K resize-pane -U 5
      bind -n M-L resize-pane -R 5
    '';
  };
}
