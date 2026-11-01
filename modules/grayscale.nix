{pkgs, ...}: let
  shader = pkgs.writeText "grayscale.glsl" ''
    #version 330
    in vec2 texcoord;
    uniform sampler2D tex;
    vec4 default_post_processing(vec4 c);

    vec4 window_shader() {
      vec4 c = default_post_processing(texelFetch(tex, ivec2(texcoord), 0));
      float g = dot(c.rgb, vec3(0.299, 0.587, 0.114));
      return vec4(vec3(g), c.a);
    }
  '';
  # Toggle grayscale filter: restart picom with/without the grayscale window shader
  grayscaleToggle = pkgs.writeShellApplication {
    name = "grayscale-toggle";
    runtimeInputs = with pkgs; [picom procps util-linux gnugrep libnotify feh imagemagick coreutils];
    text = ''
      args=(--config "$HOME/.config/picom/picom.conf")
      # Wallpaper is the root background, not a window, so the shader skips it: swap in a gray copy
      wall="$(cat "$HOME/.wallpaper" 2>/dev/null || echo "$HOME/dot-ccin/Wallpapers/wallpaper.png")"
      if pgrep -ax picom | grep -q window-shader-fg; then
        msg="Grayscale off"
        feh --bg-fill --no-fehbg "$wall"
      else
        args+=(--window-shader-fg ${shader})
        msg="Grayscale on"
        gray="$HOME/.cache/grayscale-wallpaper.png"
        magick "$wall" -colorspace Gray "$gray"
        feh --bg-fill --no-fehbg "$gray"
      fi
      pkill -x picom || true
      while pgrep -x picom >/dev/null; do sleep 0.05; done
      setsid -f picom "''${args[@]}" >/dev/null 2>&1
      notify-send -a Grayscale -t 1500 -h string:x-dunst-stack-tag:grayscale "$msg"
    '';
  };
in {
  home.packages = [grayscaleToggle];
}
