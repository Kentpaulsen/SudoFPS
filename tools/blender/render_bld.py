import sys, os
src = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "render_v2.py")).read()
exec(src[:src.index("for f, pers in")])
for f, d in (("bld_house", (1.2, -1.6, 0.9)), ("bld_supermarket", (1.0, -1.7, 0.8)), ("bld_church", (1.4, -1.6, 0.7))):
    scene(f); frame(d, 1.05, (800, 600)); render(f)
# suit outfit
bpy.ops.wm.open_mainfile(filepath=os.path.join(B, "person.blend")); setup((600, 600))
on = {"Body", "Head_02_Narrow", "Hair_01_Short", "Top_04_Suit", "Bottom_04_SuitTrousers", "Shoes_03_Dress"}
for ob in bpy.context.scene.objects:
    if ob.type == 'MESH':
        vis = ob.name in on or not ob.name.startswith(("Head_", "Hair_", "Top_", "Bottom_", "Shoes_", "Hat_"))
        ob.hide_set(not vis); ob.hide_render = not vis
        if ob.name == "Top_04_Suit":
            for ms in ob.material_slots:
                if ms.material and ms.material.name == "Top":
                    ms.material.diffuse_color = (0.03, 0.05, 0.10, 1)
        if ob.name == "Bottom_04_SuitTrousers":
            ob.material_slots[0].material.diffuse_color = (0.03, 0.05, 0.10, 1)
frame((0.9, -1.6, 0.35), 1.1, (600, 600)); render("suit")
