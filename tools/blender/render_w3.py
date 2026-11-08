import sys, os
src = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "render_v2.py")).read()
exec(src[:src.index("for f, pers in")])
for f in ("weapon_pistol", "weapon_uzi", "weapon_shotgun", "weapon_rifle", "weapon_knife", "weapon_bat"):
    bpy.ops.wm.open_mainfile(filepath=os.path.join(B, f + ".blend")); setup((700, 420))
    frame((1.6, -0.5, 0.45), 1.05, (700, 420)); render(f)
