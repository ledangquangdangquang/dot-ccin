#!/usr/bin/env python3
# Keep existing window at 70%, new window at 30% on every split.
import i3ipc

i3 = i3ipc.Connection()


def on_new_window(i3, e):
    con = i3.get_tree().find_by_id(e.container.id)
    parent = con.parent if con else None
    if parent and parent.layout in ("splith", "splitv") and len(parent.nodes) == 2:
        dim = "width" if parent.layout == "splith" else "height"
        i3.command(f'[con_id="{con.id}"] resize set {dim} 30 ppt')


i3.on("window::new", on_new_window)
i3.main()
