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
    runtimeInputs = with pkgs; [picom procps util-linux gnugrep libnotify];
    text = ''
      args=(--config "$HOME/.config/picom/picom.conf")
      if pgrep -ax picom | grep -q window-shader-fg; then
        msg="Grayscale off"
      else
        args+=(--window-shader-fg ${shader})
        msg="Grayscale on"
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
