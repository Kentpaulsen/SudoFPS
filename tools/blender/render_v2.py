import bpy, os, sys, math
from mathutils import Vector

OUT = os.path.abspath(sys.argv[-2]); V1 = os.path.abspath(sys.argv[-1])
B = os.path.join(OUT, "blender"); R = os.path.join(OUT, "previews")
os.makedirs(R, exist_ok=True)

def setup(res=(900, 640)):
    s = bpy.context.scene
    s.render.engine = 'BLENDER_WORKBENCH'
    sh = s.display.shading
    sh.light = 'STUDIO'; sh.color_type = 'MATERIAL'
    sh.show_object_outline = True; sh.show_cavity = True; sh.cavity_type = 'BOTH'
    sh.show_shadows = True; sh.shadow_intensity = 0.35
    sh.show_specular_highlight = True
    s.display.light_direction = (0.45, -0.35, 0.82)
    s.render.resolution_x, s.render.resolution_y = res
    if s.world is None:
        s.world = bpy.data.worlds.new("W")
    s.world.color = (0.80, 0.82, 0.85)
    try:
        s.view_settings.view_transform = 'Standard'
    except Exception:
        pass

def ground(size=30):
    bpy.ops.mesh.primitive_plane_add(size=size)
    g = bpy.context.active_object
    m = bpy.data.materials.new("Ground"); m.diffuse_color = (0.62, 0.58, 0.50, 1)
    g.data.materials.append(m)

def frame(direction, pad=1.15, res=(900, 640)):
    pts = []
    dg = bpy.context.evaluated_depsgraph_get()
    for ob in bpy.context.scene.objects:
        if ob.type == 'MESH' and not ob.hide_render and ob.name != "Plane" and "-convcolonly" not in ob.name:
            eo = ob.evaluated_get(dg)
            me = eo.to_mesh()
            pts += [eo.matrix_world @ v.co for v in me.vertices]
            eo.to_mesh_clear()
    lo = Vector([min(p[i] for p in pts) for i in range(3)]); hi = Vector([max(p[i] for p in pts) for i in range(3)])
    c = (lo + hi) / 2; size = (hi - lo).length
    cd = bpy.data.cameras.new("C"); cd.type = 'ORTHO'
    cd.ortho_scale = size * pad; cd.clip_end = size * 20
    cam = bpy.data.objects.new("C", cd); bpy.context.scene.collection.objects.link(cam)
    d = Vector(direction).normalized()
    cam.location = c + d * size * 4
    cam.rotation_euler = (-d).to_track_quat('-Z', 'Y').to_euler()
    bpy.context.scene.camera = cam

def hide_colliders():
    for ob in bpy.context.scene.objects:
        if "-convcolonly" in ob.name:
            ob.hide_render = True; ob.hide_set(True)

def add_person(loc, rotz=0):
    with bpy.data.libraries.load(os.path.join(V1, "person.blend")) as (src, dst):
        dst.objects = list(src.objects)
    keep = {"Character", "Body", "Head_01_Square", "Hair_01_Short", "Top_02_Jacket", "Bottom_01_Trousers",
            "Shoes_01_Boots", "Hat_01_Cap"}
    for ob in dst.objects:
        if ob.name in keep:
            bpy.context.scene.collection.objects.link(ob)
    arm = bpy.data.objects["Character"]
    arm.location = loc; arm.rotation_euler = (0, 0, math.radians(rotz)); arm.hide_render = True

def render(name):
    bpy.context.scene.render.filepath = os.path.join(R, name + ".png")
    bpy.ops.render.render(write_still=True)

def scene(f, person=None):
    bpy.ops.wm.open_mainfile(filepath=os.path.join(B, f + ".blend"))
    setup(); hide_colliders(); ground()
    if person:
        add_person(*person)

for f, pers in (("vehicle_tike", ((1.4, 0.3, 0), 0)), ("vehicle_bike", ((1.1, 0.2, 0), 0))):
    scene(f); frame((1.5, -1.6, 0.85)); render(f + "_a")
    scene(f); frame((-1.6, 1.2, 0.7)); render(f + "_b")
    scene(f); frame((1, 0, 0.02), 1.05); render(f + "_side")
    scene(f, pers); frame((1.2, -1.8, 0.5)); render(f + "_scale")

for f in ("build_wall", "build_wallwindow", "build_walldoor", "build_walll"):
    scene(f, ((0.0, -1.0, 0), 0) if f == "build_walldoor" else ((-1.0, -1.0, 0), 0) if f != "build_walll" else ((1.5, -1.0, 0), 0))
    frame((0.9, -1.6, 0.7) if f != "build_walll" else (-1.2, -1.6, 0.9), 1.05, (700, 640))
    bpy.context.scene.render.resolution_x = 700
    render(f)
