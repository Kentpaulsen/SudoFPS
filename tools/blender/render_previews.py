import bpy, os, sys, math
from mathutils import Vector

OUT = os.path.abspath(sys.argv[-1])
B = os.path.join(OUT, "blender")
R = os.path.join(OUT, "previews")
os.makedirs(R, exist_ok=True)

def setup_render(res=520):
    s = bpy.context.scene
    try:
        s.render.engine = 'BLENDER_WORKBENCH'
        s.display.shading.light = 'STUDIO'
        s.display.shading.color_type = 'MATERIAL'
        s.display.shading.show_object_outline = True
        s.display.shading.show_cavity = False
    except Exception as e:
        print("workbench fail", e)
    s.render.resolution_x = s.render.resolution_y = res
    s.render.film_transparent = False
    if s.world is None:
        s.world = bpy.data.worlds.new("W")
    s.world.color = (0.82, 0.84, 0.86)

def frame(direction=(1.0, -1.5, 0.7), pad=1.25):
    pts = []
    for ob in bpy.context.scene.objects:
        if ob.type == 'MESH' and not ob.hide_render and ob.visible_get():
            dg = bpy.context.evaluated_depsgraph_get()
            eo = ob.evaluated_get(dg)
            for v in eo.to_mesh().vertices:
                pts.append(eo.matrix_world @ v.co)
            eo.to_mesh_clear()
    lo = Vector([min(p[i] for p in pts) for i in range(3)])
    hi = Vector([max(p[i] for p in pts) for i in range(3)])
    c = (lo + hi) / 2
    size = (hi - lo).length
    cam_d = bpy.data.cameras.new("PreviewCam")
    cam_d.type = 'ORTHO'
    cam_d.ortho_scale = size * pad
    cam = bpy.data.objects.new("PreviewCam", cam_d)
    bpy.context.scene.collection.objects.link(cam)
    d = Vector(direction).normalized()
    cam.location = c + d * size * 3
    cam.rotation_euler = (-d).to_track_quat('-Z', 'Y').to_euler()
    cam_d.clip_end = size * 10
    bpy.context.scene.camera = cam
    return cam

def render(name):
    bpy.context.scene.render.filepath = os.path.join(R, name + ".png")
    bpy.ops.render.render(write_still=True)

def open_(f):
    bpy.ops.wm.open_mainfile(filepath=os.path.join(B, f + ".blend"))
    setup_render()

for f in ["tree", "bush", "rock", "sandbags", "weapon_pistol", "weapon_uzi", "weapon_shotgun",
          "weapon_rifle", "weapon_knife", "weapon_bat"]:
    open_(f)
    frame((1.0, -1.5, 0.7) if not f.startswith("weapon") else (1.6, -0.6, 0.5))
    render(f)

# Person: several outfits
outfits = [
    ("person_a", {"Head_01_Square", "Hair_01_Short", "Top_02_Jacket", "Bottom_01_Trousers", "Shoes_01_Boots", "Hat_01_Cap"}, 0),
    ("person_b", {"Head_02_Narrow", "Hair_02_Long", "Top_01_TShirt", "Bottom_02_Shorts", "Shoes_02_Sneakers"}, 1),
    ("person_c", {"Head_03_Wide", "Top_03_TacticalVest", "Bottom_03_Cargo", "Shoes_01_Boots", "Hat_03_Helmet"}, 0),
    ("person_d", {"Head_01_Square", "Hair_03_Mohawk", "Top_02_Jacket", "Bottom_03_Cargo", "Shoes_02_Sneakers", "Hat_04_Boonie"}, 1),
]
slots = ("Head_", "Hair_", "Top_", "Bottom_", "Shoes_", "Hat_")
for name, on, fem in outfits:
    open_("person")
    for ob in bpy.context.scene.objects:
        if ob.type == 'MESH' and ob.name.startswith(slots):
            ob.hide_set(ob.name not in on)
            ob.hide_render = ob.name not in on
        if ob.type == 'MESH' and ob.data.shape_keys:
            ob.data.shape_keys.key_blocks["female"].value = fem
    if name == "person_a":
        # attach pistol to the weapon socket with zero offset, rifle on the back
        for wf, wname, sock in (("weapon_pistol", "Pistol", "SOCKET_Weapon_R"), ("weapon_rifle", "Rifle", "SOCKET_Back")):
            with bpy.data.libraries.load(os.path.join(B, wf + ".blend")) as (src, dst):
                dst.objects = [n for n in src.objects]
            for ob in dst.objects:
                bpy.context.scene.collection.objects.link(ob)
            root = bpy.data.objects[wname]
            root.parent = bpy.data.objects[sock]
            root.matrix_parent_inverse.identity()
            root.location = (0, 0, 0)
            root.rotation_euler = (0, 0, 0)
    frame((0.9, -1.6, 0.35), 1.1)
    render(name)
