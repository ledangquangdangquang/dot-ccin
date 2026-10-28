{pkgs, ...}: let
  # Mod+right drag anywhere in a window resizes it, tiled or floating
  # (i3 only does this natively for floating). Moves the edge nearest the
  # click; flips to the opposite edge when there is no neighbour to push.
  mouseResize =
    pkgs.writers.writePython3Bin "mouse-resize" {
      libraries = with pkgs.python3Packages; [i3ipc xlib];
    } ''
      import time

      import i3ipc
      from Xlib import X, display

      SIGN = {"right": 1, "left": -1, "down": 1, "up": -1}
      OPPOSITE = {"right": "left", "left": "right", "down": "up", "up": "down"}

      i3 = i3ipc.Connection()
      root = display.Display().screen().root


      def pointer():
          p = root.query_pointer()
          return p.root_x, p.root_y, p.mask & X.Button3Mask


      def resize(edge, delta):
          verb = "grow" if delta > 0 else "shrink"
          reply = i3.command(f"resize {verb} {edge} {abs(delta)} px")[0]
          return reply.success or "No second container" not in reply.error


      def edge_pos(rect, edge):
          return {
              "left": rect.x,
              "right": rect.x + rect.width,
              "up": rect.y,
              "down": rect.y + rect.height,
          }[edge]


      class Edge:
          # Tracks pointer + offset against the real edge position each frame,
          # so i3's px->ppt rounding never accumulates into drift.
          def __init__(self, edge, rect, p):
              self.edge = edge
              self.offset = edge_pos(rect, edge) - p

          def follow(self, rect, p):
              target = p + self.offset
              delta = SIGN[self.edge] * (target - edge_pos(rect, self.edge))
              if abs(delta) < 2:
                  return False
              if not resize(self.edge, delta):
                  self.edge = OPPOSITE[self.edge]
                  self.offset = edge_pos(rect, self.edge) - p
              return True


      rect = i3.get_tree().find_focused().rect
      x, y, _ = pointer()
      h = Edge("right" if x > rect.x + rect.width / 2 else "left", rect, x)
      v = Edge("down" if y > rect.y + rect.height / 2 else "up", rect, y)
      last = None

      while True:
          x, y, held = pointer()
          if not held:
              break
          if (x, y) != last:
              if h.follow(rect, x) | v.follow(rect, y):
                  rect = i3.get_tree().find_focused().rect
              last = (x, y)
          time.sleep(1 / 120)
    '';
in {
  home.packages = [mouseResize];
}
