#!/usr/bin/env python3
# 2nd window: 70/30. 3rd window: stacked 50/50 under the 2nd (right column stays 30%).
import i3ipc

i3 = i3ipc.Connection()


def on_new_window(i3, e):
    con = i3.get_tree().find_by_id(e.container.id)
    parent = con.parent if con else None
    if not parent or parent.layout not in ("splith", "splitv"):
        return
    n = len(parent.nodes)
    if n == 2:
        dim = "width" if parent.layout == "splith" else "height"
        i3.command(f'[con_id="{con.id}"] resize set {dim} 30 ppt')
    elif n == 3 and parent.layout == "splith" and con.id != parent.nodes[0].id:
        second = next(c for c in parent.nodes[1:] if c.id != con.id)
        i3.command(f'[con_id="{second.id}"] split v')
        i3.command(f'[con_id="{con.id}"] move left')
        col = i3.get_tree().find_by_id(con.id).parent
        i3.command(f'[con_id="{col.id}"] resize set width 30 ppt')
        i3.command(f'[con_id="{con.id}"] resize set height 50 ppt')


i3.on("window::new", on_new_window)
i3.main()
