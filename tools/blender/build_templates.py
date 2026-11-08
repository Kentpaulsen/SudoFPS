"""SudoFPS Blender template generator. Run: python3 build_templates.py <outdir>"""
import bpy, bmesh, math, os, sys
from mathutils import Vector, Matrix, Euler

OUT = os.path.abspath(sys.argv[-1])
BLEND_DIR = os.path.join(OUT, "blender")
GLB_DIR = os.path.join(OUT, "glb")
os.makedirs(BLEND_DIR, exist_ok=True)
os.makedirs(GLB_DIR, exist_ok=True)

# ---------------------------------------------------------------- helpers
def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    s = bpy.context.scene
    s.unit_settings.system = 'METRIC'
    s.unit_settings.scale_length = 1.0
    s.unit_settings.length_unit = 'METERS'

def mat(name, rgb, rough=0.8, metal=0.0):
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    try:
        m.use_nodes = True
    except Exception:
        pass
    nt = m.node_tree
    bsdf = nt.nodes.get("Principled BSDF") if nt else None
    if bsdf is None and nt is not None:
        bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
        out = nt.nodes.get("Material Output") or nt.nodes.new("ShaderNodeOutputMaterial")
        nt.links.new(bsdf.outputs[0], out.inputs[0])
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (*rgb, 1)
        bsdf.inputs["Roughness"].default_value = rough
        bsdf.inputs["Metallic"].default_value = metal
    m.diffuse_color = (*rgb, 1)
    m.roughness = rough
    m.metallic = metal
    return m

def coll(name, parent=None):
    c = bpy.data.collections.new(name)
    (parent or bpy.context.scene.collection).children.link(c)
    return c

FACES = [((0,0,0),(0,0,1),(0,1,1),(0,1,0)), ((1,0,0),(1,1,0),(1,1,1),(1,0,1)),
         ((0,0,0),(1,0,0),(1,0,1),(0,0,1)), ((0,1,0),(0,1,1),(1,1,1),(1,1,0)),
         ((0,0,0),(0,1,0),(1,1,0),(1,0,0)), ((0,0,1),(1,0,1),(1,1,1),(0,1,1))]

def P(size, loc, mat=0, rot=(0,0,0), bone=None, f=None):
    """One box part. f = ((sx,sy,sz),(ox,oy,oz)) female shape-key scale/offset."""
    return dict(size=size, loc=loc, mat=mat, rot=rot, bone=bone, f=f)

def build(name, parts, collection, mats, origin=(0,0,0), parent=None, armature=None):
    origin = Vector(origin)
    bm = bmesh.new()
    groups, fem, has_f = {}, [], False
    for p in parts:
        sx, sy, sz = p['size']
        R = Euler([math.radians(a) for a in p['rot']]).to_matrix()
        c = Vector(p['loc']) - origin
        fs, fo = p['f'] if p['f'] else ((1,1,1),(0,0,0))
        has_f = has_f or bool(p['f'])
        start = len(bm.verts)
        vs = []
        for i in (0, 1):
            for j in (0, 1):
                for k in (0, 1):
                    l = Vector(((i-.5)*sx, (j-.5)*sy, (k-.5)*sz))
                    vs.append(bm.verts.new(c + R @ l))
                    lf = Vector((l.x*fs[0], l.y*fs[1], l.z*fs[2]))
                    fem.append(c + Vector(fo) + R @ lf)
        for fc in FACES:
            face = bm.faces.new([vs[a*4+b*2+cc] for a, b, cc in fc])
            face.material_index = p['mat']
        if p['bone']:
            groups.setdefault(p['bone'], []).extend(range(start, start+8))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for m in mats:
        me.materials.append(m)
    ob = bpy.data.objects.new(name, me)
    collection.objects.link(ob)
    ob.location = origin
    if parent:
        ob.parent = parent
        ob.location = origin - parent.matrix_world.translation
    if has_f:
        ob.shape_key_add(name="Basis")
        sk = ob.shape_key_add(name="female")
        for i, co in enumerate(fem):
            sk.data[i].co = co
    if armature:
        for bone, idx in groups.items():
            ob.vertex_groups.new(name=bone).add(idx, 1.0, 'REPLACE')
        mod = ob.modifiers.new("Armature", 'ARMATURE')
        mod.object = armature
        ob.parent = armature
    return ob

def empty(name, loc, collection, parent=None, size=0.05, kind='ARROWS', rot=(0,0,0)):
    e = bpy.data.objects.new(name, None)
    e.empty_display_type = kind
    e.empty_display_size = size
    collection.objects.link(e)
    e.location = loc
    e.rotation_euler = [math.radians(a) for a in rot]
    if parent:
        e.parent = parent
    return e

def collider(name, size, loc, collection, rot=(0,0,0)):
    """Box collider. '-convcolonly' suffix: Godot imports it as a convex collision shape only."""
    ob = build(name + "-convcolonly", [P(size, loc, 0, rot)], collection, [])
    ob.display_type = 'WIRE'
    ob.hide_render = True
    return ob

def hide(ob, state=True):
    ob.hide_set(state)
    ob.hide_render = state

def save(name, select_root=None):
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(BLEND_DIR, name + ".blend"), compress=True)
    # export everything, including hidden variants
    for ob in bpy.context.scene.objects:
        ob.hide_set(False)
    bpy.ops.export_scene.gltf(filepath=os.path.join(GLB_DIR, name + ".glb"), export_format='GLB',
                              use_visible=False, export_yup=True, export_skins=True,
                              export_morph=True, export_animations=False, export_apply=False)
    bpy.ops.wm.open_mainfile(filepath=os.path.join(BLEND_DIR, name + ".blend"))

def set_meta(text):
    t = bpy.data.texts.new("README")
    t.from_string(text)

# ---------------------------------------------------------------- PERSON
def person():
    reset()
    M = dict(
        Skin=mat("Skin", (0.80, 0.60, 0.48)), Eyes=mat("Eyes", (0.05, 0.05, 0.06), 0.3),
        Under=mat("Undersuit", (0.25, 0.25, 0.27)), Hair=mat("Hair", (0.22, 0.14, 0.08)),
        Top=mat("Top", (0.32, 0.40, 0.26)), TopA=mat("TopAccent", (0.16, 0.17, 0.15)),
        Bot=mat("Bottom", (0.24, 0.27, 0.34)), BotA=mat("BottomAccent", (0.12, 0.10, 0.08)),
        Shoe=mat("Shoes", (0.18, 0.13, 0.09)), Hat=mat("Hat", (0.35, 0.36, 0.25)),
        HatA=mat("HatAccent", (0.12, 0.12, 0.12)))
    root = bpy.context.scene.collection
    c_rig = coll("Rig")
    arm_data = bpy.data.armatures.new("Skeleton")
    arm = bpy.data.objects.new("Character", arm_data)
    c_rig.objects.link(arm)
    arm.show_in_front = True
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode='EDIT')
    B = [("Root", (0,0,0), (0,0,0.2), None),
         ("Hips", (0,0,0.95), (0,0,1.05), "Root"),
         ("Spine", (0,0,1.05), (0,0,1.25), "Hips"),
         ("Chest", (0,0,1.25), (0,0,1.45), "Spine"),
         ("Neck", (0,0,1.45), (0,0,1.55), "Chest"),
         ("Head", (0,0,1.55), (0,0,1.80), "Neck")]
    for s, side in ((1, "Left"), (-1, "Right")):
        B += [(f"{side}Shoulder", (s*0.04,0,1.42), (s*0.17,0,1.42), "Chest"),
              (f"{side}UpperArm", (s*0.17,0,1.42), (s*0.48,0,1.42), f"{side}Shoulder"),
              (f"{side}LowerArm", (s*0.48,0,1.42), (s*0.74,0,1.42), f"{side}UpperArm"),
              (f"{side}Hand", (s*0.74,0,1.42), (s*0.86,0,1.42), f"{side}LowerArm"),
              (f"{side}UpperLeg", (s*0.10,0,0.95), (s*0.10,0,0.50), "Hips"),
              (f"{side}LowerLeg", (s*0.10,0,0.50), (s*0.10,0,0.08), f"{side}UpperLeg"),
              (f"{side}Foot", (s*0.10,0,0.08), (s*0.10,-0.12,0.02), f"{side}LowerLeg"),
              (f"{side}Toes", (s*0.10,-0.12,0.02), (s*0.10,-0.17,0.02), f"{side}Foot")]
    for n, h, t, par in B:
        eb = arm_data.edit_bones.new(n)
        eb.head, eb.tail = h, t
        if par:
            eb.parent = arm_data.edit_bones[par]
    bpy.ops.object.mode_set(mode='OBJECT')

    # female shape-key factors per region
    FC = ((0.90, 0.95, 1.0), (0, 0, 0))      # chest narrower
    FS = ((0.85, 0.95, 1.0), (0, 0, 0))      # waist narrower
    FH = ((1.08, 1.02, 1.0), (0, 0, 0))      # hips wider
    FA = ((1.0, 0.88, 0.88), (0, 0, 0))      # slimmer limbs

    # ---- Body (always on)
    c_body = coll("Body")
    parts = [P((0.10,0.10,0.10), (0,0,1.50), 0, bone="Neck"),
             P((0.40,0.22,0.22), (0,0,1.36), 1, bone="Chest", f=FC),
             P((0.36,0.20,0.20), (0,0,1.15), 1, bone="Spine", f=FS),
             P((0.36,0.21,0.14), (0,0,0.99), 1, bone="Hips", f=FH)]
    for s, side in ((1, "Left"), (-1, "Right")):
        parts += [P((0.31,0.10,0.10), (s*0.325,0,1.42), 0, bone=f"{side}UpperArm", f=FA),
                  P((0.26,0.09,0.09), (s*0.61,0,1.42), 0, bone=f"{side}LowerArm", f=FA),
                  P((0.12,0.05,0.09), (s*0.80,0,1.42), 0, bone=f"{side}Hand"),
                  P((0.05,0.03,0.03), (s*0.77,-0.04,1.43), 0, bone=f"{side}Hand"),
                  P((0.15,0.16,0.45), (s*0.10,0,0.725), 1, bone=f"{side}UpperLeg", f=((0.95,1,1),(s*0.005,0,0))),
                  P((0.12,0.13,0.42), (s*0.10,0,0.29), 0, bone=f"{side}LowerLeg", f=FA),
                  P((0.12,0.24,0.08), (s*0.10,-0.05,0.04), 0, bone=f"{side}Foot")]
    build("Body", parts, c_body, [M['Skin'], M['Under']], armature=arm)

    # ---- Heads: identical crown (0.22 x 0.24, top at 1.80) so hair and hats fit every head
    c_head = coll("Heads")
    eyes = [P((0.04,0.01,0.03), (s*0.05,-0.121,1.69), 1, bone="Head") for s in (1,-1)]
    nose = [P((0.03,0.03,0.05), (0,-0.13,1.65), 0, bone="Head")]
    heads = {
        "Head_01_Square": [P((0.22,0.24,0.26), (0,0,1.67), 0, bone="Head")],
        "Head_02_Narrow": [P((0.22,0.24,0.18), (0,0,1.71), 0, bone="Head"),
                           P((0.17,0.20,0.10), (0,-0.01,1.58), 0, bone="Head")],
        "Head_03_Wide":   [P((0.22,0.24,0.20), (0,0,1.70), 0, bone="Head"),
                           P((0.26,0.22,0.10), (0,-0.005,1.59), 0, bone="Head"),
                           P((0.03,0.05,0.06), (0.125,0.01,1.67), 0, bone="Head"),
                           P((0.03,0.05,0.06), (-0.125,0.01,1.67), 0, bone="Head")],
    }
    head_obs = {n: build(n, p + eyes + nose, c_head, [M['Skin'], M['Eyes']], armature=arm)
                for n, p in heads.items()}

    # ---- Hair
    c_hair = coll("Hair")
    hair = {
        "Hair_01_Short":  [P((0.24,0.26,0.05), (0,0.005,1.785)), P((0.24,0.03,0.17), (0,0.125,1.70)),
                           P((0.02,0.18,0.08), (0.115,0.03,1.74)), P((0.02,0.18,0.08), (-0.115,0.03,1.74))],
        "Hair_02_Long":   [P((0.24,0.26,0.05), (0,0.005,1.785)), P((0.25,0.04,0.36), (0,0.13,1.60)),
                           P((0.025,0.20,0.26), (0.12,0.03,1.66)), P((0.025,0.20,0.26), (-0.12,0.03,1.66))],
        "Hair_03_Mohawk": [P((0.05,0.26,0.07), (0,0.01,1.83)), P((0.05,0.03,0.12), (0,0.125,1.74))],
    }
    hair_obs = {n: build(n, [dict(x, bone="Head") for x in p], c_hair, [M['Hair']], armature=arm)
                for n, p in hair.items()}

    # ---- Tops (Jackets)
    c_top = coll("Tops")
    m = 0.015
    tor = lambda m, a=0: [P((0.40+2*m,0.22+2*m,0.22+2*m), (0,0,1.36), a, bone="Chest", f=FC),
                          P((0.36+2*m,0.20+2*m,0.20+2*m), (0,0,1.15), a, bone="Spine", f=FS)]
    def sleeve(s, side, x0, x1, m):
        out = []
        if x1 > 0.17:
            e = min(x1, 0.48)
            out.append(P((e-x0, 0.10+2*m, 0.10+2*m), (s*(x0+e)/2, 0, 1.42), 0, bone=f"{side}UpperArm", f=FA))
        if x1 > 0.48:
            out.append(P((x1-0.48, 0.09+2*m, 0.09+2*m), (s*(0.48+x1)/2, 0, 1.42), 0, bone=f"{side}LowerArm", f=FA))
        return out
    tops = {}
    p = tor(m)
    for s, side in ((1,"Left"),(-1,"Right")):
        p += sleeve(s, side, 0.17, 0.33, m)
    tops["Top_01_TShirt"] = p
    p = tor(0.02) + [P((0.40,0.24,0.07), (0,0,1.03), 0, bone="Hips", f=FH),
                     P((0.18,0.17,0.06), (0,0.005,1.48), 1, bone="Chest"),
                     P((0.02,0.006,0.40), (0,-0.133,1.26), 1, bone="Chest", f=((1,1,1),(0,0.006,0)))]
    for s, side in ((1,"Left"),(-1,"Right")):
        p += sleeve(s, side, 0.17, 0.72, 0.02)
        p.append(P((0.03,0.13,0.13), (s*0.705,0,1.42), 1, bone=f"{side}LowerArm"))
    tops["Top_02_Jacket"] = p
    p = tor(0.035) + [P((0.08,0.04,0.09), (x,-0.14,1.13), 1, bone="Spine", f=((1,1,1),(0,0.01,0))) for x in (-0.11,0,0.11)]
    p += [P((0.07,0.04,0.12), (s*0.11,-0.15,1.37), 1, bone="Chest", f=((1,1,1),(0,0.012,0))) for s in (1,-1)]
    for s, side in ((1,"Left"),(-1,"Right")):
        p += sleeve(s, side, 0.17, 0.30, m)
    tops["Top_03_TacticalVest"] = p
    top_obs = {n: build(n, p, c_top, [M['Top'], M['TopA']], armature=arm) for n, p in tops.items()}

    # ---- Bottoms (Pants)
    c_bot = coll("Bottoms")
    def legs(m, z_bottom, extra=None):
        out = [P((0.36+2*m,0.21+2*m,0.14+2*m), (0,0,0.99), 0, bone="Hips", f=FH),
               P((0.37+2*m,0.22+2*m,0.04), (0,0,1.05), 1, bone="Hips", f=FH)]
        for s, side in ((1,"Left"),(-1,"Right")):
            zt = max(z_bottom, 0.50)
            out.append(P((0.15+2*m,0.16+2*m,0.95-zt), (s*0.10,0,(0.95+zt)/2), 0, bone=f"{side}UpperLeg",
                         f=((0.95,1,1),(s*0.005,0,0))))
            if z_bottom < 0.50:
                out.append(P((0.12+2*m,0.13+2*m,0.50-z_bottom), (s*0.10,0,(0.50+z_bottom)/2), 0,
                             bone=f"{side}LowerLeg", f=FA))
        return out
    bots = {"Bottom_01_Trousers": legs(m, 0.10),
            "Bottom_02_Shorts": legs(m, 0.60),
            "Bottom_03_Cargo": legs(0.02, 0.12) + [P((0.03,0.10,0.12), (s*0.19,0,0.70), 1,
                                                     bone=f"{side}UpperLeg", f=((1,1,1),(-s*0.004,0,0)))
                                                   for s, side in ((1,"Left"),(-1,"Right"))]}
    bot_obs = {n: build(n, p, c_bot, [M['Bot'], M['BotA']], armature=arm) for n, p in bots.items()}

    # ---- Shoes
    c_sh = coll("Shoes")
    shoes = {"Shoes_01_Boots": [], "Shoes_02_Sneakers": []}
    for s, side in ((1,"Left"),(-1,"Right")):
        shoes["Shoes_01_Boots"] += [P((0.15,0.27,0.10), (s*0.10,-0.055,0.05), 0, bone=f"{side}Foot"),
                                     P((0.15,0.16,0.14), (s*0.10,0,0.17), 0, bone=f"{side}LowerLeg"),
                                     P((0.155,0.275,0.02), (s*0.10,-0.055,0.01), 1, bone=f"{side}Foot")]
        shoes["Shoes_02_Sneakers"] += [P((0.14,0.26,0.07), (s*0.10,-0.05,0.055), 0, bone=f"{side}Foot"),
                                        P((0.145,0.27,0.025), (s*0.10,-0.05,0.0125), 1, bone=f"{side}Foot")]
    sh_mat_acc = mat("ShoesAccent", (0.85, 0.85, 0.82))
    sh_obs = {n: build(n, p, c_sh, [M['Shoe'], sh_mat_acc], armature=arm) for n, p in shoes.items()}

    # ---- Hats
    c_hat = coll("Hats")
    hats = {
        "Hat_01_Cap":    [P((0.25,0.27,0.07), (0,0,1.80)), P((0.20,0.10,0.015), (0,-0.18,1.775)),
                          P((0.03,0.03,0.015), (0,0,1.84), 1)],
        "Hat_02_Beanie": [P((0.25,0.27,0.10), (0,0,1.78)), P((0.255,0.275,0.035), (0,0,1.735), 1)],
        "Hat_03_Helmet": [P((0.28,0.30,0.12), (0,0.005,1.80)), P((0.30,0.32,0.03), (0,0.005,1.74)),
                          P((0.29,0.06,0.10), (0,0.135,1.70)), P((0.06,0.02,0.04), (0,-0.16,1.80), 1)],
        "Hat_04_Boonie": [P((0.24,0.26,0.08), (0,0,1.80)), P((0.40,0.42,0.012), (0,0,1.765)),
                          P((0.245,0.265,0.02), (0,0,1.775), 1)],
    }
    hat_obs = {n: build(n, [dict(x, bone="Head") for x in p], c_hat, [M['Hat'], M['HatA']], armature=arm)
               for n, p in hats.items()}

    # ---- Sockets (empties parented to bones; weapons attach here with no rotation offset)
    c_sock = coll("Sockets")
    def socket(name, bone, loc, rot3):
        e = bpy.data.objects.new(name, None)
        e.empty_display_type = 'ARROWS'
        e.empty_display_size = 0.08
        c_sock.objects.link(e)
        e.parent = arm
        e.parent_type = 'BONE'
        e.parent_bone = bone
        bpy.context.view_layer.update()
        mw = Matrix(rot3).to_4x4()
        mw.translation = Vector(loc)
        e.matrix_world = mw
        return e
    # right palm: weapon barrel (-Y) runs along the hand, grip sits in the palm
    socket("SOCKET_Weapon_R", "RightHand", (-0.80, 0, 1.42), [[0,1,0],[0,0,-1],[-1,0,0]])
    socket("SOCKET_Offhand_L", "LeftHand", (0.80, 0, 1.42), [[0,-1,0],[0,0,-1],[1,0,0]])
    socket("SOCKET_Hat", "Head", (0, 0, 1.80), Matrix.Identity(3))
    socket("SOCKET_Back", "Chest", (0, 0.16, 1.30),
           (Euler((math.radians(-90), math.radians(35), 0))).to_matrix())
    socket("SOCKET_Hip_R", "Hips", (-0.23, 0, 0.92), Euler((math.radians(90), 0, 0)).to_matrix())
    socket("SOCKET_Camera", "Head", (0, -0.10, 1.69), Matrix.Identity(3))

    # Default look in the .blend: one of each slot visible
    default = {"Head_01_Square", "Hair_01_Short", "Top_02_Jacket", "Bottom_01_Trousers",
               "Shoes_01_Boots", "Hat_01_Cap"}
    for group in (head_obs, hair_obs, top_obs, bot_obs, sh_obs, hat_obs):
        for n, ob in group.items():
            hide(ob, n not in default)

    set_meta("""PERSON TEMPLATE
1 BU = 1 m. Height 1.80 m. Origin at feet. Faces -Y (Blender front view looks at the face).
T-pose. Bone names follow Godot's SkeletonProfileHumanoid so retargeting maps automatically.
Every mesh is rigid-skinned: each box is weighted 100% to one bone. Keep that when you model.

SLOTS (game shows one per slot, hides the rest by name prefix):
  Body (always on) | Head_* | Hair_* (optional) | Top_* | Bottom_* | Shoes_* | Hat_* (optional)
Add a variant: duplicate an object in the slot collection, rename with the next number, keep the prefix.
Hair and hats must fit the shared head crown: 0.22 x 0.24 m, top at z=1.80.

SHAPE KEY 'female' on Body, Tops and Bottoms: narrower chest/waist, wider hips. Any new
clothing that covers torso or legs needs the same shape key, or it clips when female is set.
Height and hitbox are identical for both, on purpose.

MATERIALS are tint slots the game recolours: Skin, Eyes, Hair, Undersuit, Top, TopAccent,
Bottom, BottomAccent, Shoes, ShoesAccent, Hat, HatAccent. Keep the names.

SOCKETS (empties on bones): SOCKET_Weapon_R, SOCKET_Offhand_L, SOCKET_Hat, SOCKET_Back,
SOCKET_Hip_R, SOCKET_Camera. Weapons attach to SOCKET_Weapon_R with zero offset.
""")
    save("person")

# ---------------------------------------------------------------- ENVIRONMENT
def env_tree():
    reset()
    bark = mat("Bark", (0.33, 0.22, 0.13)); leaves = mat("Leaves", (0.20, 0.42, 0.18))
    c = coll("Tree")
    t = build("Tree", [P((0.40,0.40,3.2), (0,0,1.6), 0),
                       P((0.55,0.55,0.25), (0,0,0.125), 0),
                       P((2.4,2.4,1.4), (0,0,3.3), 1),
                       P((1.7,1.7,1.0), (0,0,4.4), 1, rot=(0,0,20)),
                       P((1.0,1.0,0.7), (0,0,5.2), 1, rot=(0,0,40)),
                       P((1.1,1.1,0.9), (1.1,0.4,3.0), 1, rot=(0,0,15)),
                       P((1.0,1.0,0.8), (-0.9,-0.8,3.1), 1, rot=(0,0,-10))], c, [bark, leaves])
    collider("Tree_COL_Trunk", (0.50,0.50,3.0), (0,0,1.5), c)
    empty("HARVEST_Point", (0,-0.25,1.1), c, parent=t, size=0.2)
    set_meta("TREE: origin at ground. Collider covers trunk only (canopy is walk-under).\n"
             "HARVEST_Point: where the hit effect and wood drop spawn. Height ~5.6 m.")
    save("tree")

def env_bush():
    reset()
    leaves = mat("Leaves", (0.24, 0.45, 0.20)); dark = mat("LeavesDark", (0.16, 0.32, 0.14))
    c = coll("Bush")
    build("Bush", [P((1.1,0.9,0.7), (0,0,0.35), 0, rot=(0,0,10)),
                   P((0.7,0.7,0.55), (0.45,0.2,0.40), 1, rot=(0,0,35)),
                   P((0.6,0.6,0.5), (-0.4,-0.15,0.45), 1, rot=(0,0,-20)),
                   P((0.5,0.5,0.35), (0.05,0.1,0.82), 0, rot=(0,0,25))], c, [leaves, dark])
    set_meta("BUSH: origin at ground. No collider: players walk through it. Blocks vision only.")
    save("bush")

def env_rock():
    reset()
    rock = mat("Rock", (0.45, 0.44, 0.42), 0.95); rock2 = mat("RockDark", (0.34, 0.33, 0.32), 0.95)
    c = coll("Rock")
    r = build("Rock", [P((1.4,1.1,0.9), (0,0,0.40), 0, rot=(4,-6,12)),
                       P((0.8,0.7,0.6), (0.75,0.35,0.28), 1, rot=(-8,5,40)),
                       P((0.6,0.55,0.45), (-0.6,-0.45,0.22), 1, rot=(10,0,-25)),
                       P((0.7,0.6,0.35), (0.1,-0.1,0.95), 0, rot=(5,8,30))], c, [rock, rock2])
    collider("Rock_COL", (1.5,1.2,1.05), (0,0,0.50), c, rot=(0,0,12))
    collider("Rock_COL_Side", (0.85,0.75,0.6), (0.75,0.35,0.28), c, rot=(0,0,40))
    empty("HARVEST_Point", (0,-0.6,0.6), c, parent=r, size=0.2)
    set_meta("ROCK: origin at ground, ~1.2 m tall. Two convex colliders. HARVEST_Point for stone.")
    save("rock")

def env_sandbags():
    reset()
    bag = mat("Sandbag", (0.62, 0.55, 0.38), 0.95); bag2 = mat("SandbagDark", (0.52, 0.46, 0.32), 0.95)
    c = coll("Sandbags")
    parts = []
    L, H = 0.5, 0.25
    for row in range(4):
        depth_rows = [0.0] if row >= 2 else [-0.17, 0.17]
        offset = 0.0 if row % 2 == 0 else L/2
        for yy in depth_rows:
            x = -1.0 + offset
            if offset:
                parts.append(P((L/2-0.01, 0.33, H-0.01), (-1.0+L/4, yy, H/2+row*H), row % 2))
            while x + L <= 1.0 + 1e-6:
                parts.append(P((L-0.01, 0.33, H-0.01), (x+L/2, yy, H/2+row*H), (row + int((x+1)/L)) % 2))
                x += L
            if offset:
                parts.append(P((L/2-0.01, 0.33, H-0.01), (1.0-L/4, yy, H/2+row*H), row % 2))
    s = build("Sandbags", parts, c, [bag, bag2])
    collider("Sandbags_COL", (2.0,0.67,0.5), (0,0,0.25), c)
    collider("Sandbags_COL_Top", (2.0,0.34,0.5), (0,0,0.75), c)
    empty("SNAP_L", (-1.0,0,0), c, parent=s, size=0.15)
    empty("SNAP_R", (1.0,0,0), c, parent=s, size=0.15)
    set_meta("SANDBAGS: one build piece. 2.0 m wide (build grid), 1.0 m high: crouch hides you,\n"
             "standing lets you shoot over. Origin at ground centre, front faces -Y.\n"
             "SNAP_L / SNAP_R: where neighbouring pieces join.")
    save("sandbags")

# ---------------------------------------------------------------- WEAPONS
def wmats():
    return dict(metal=mat("Metal", (0.14, 0.14, 0.15), 0.45, 0.8),
                poly=mat("Polymer", (0.08, 0.08, 0.09), 0.7),
                wood=mat("Wood", (0.42, 0.26, 0.14), 0.7),
                acc=mat("Accent", (0.55, 0.50, 0.40), 0.6))

WEAPON_README = """WEAPON TEMPLATE ({kind})
Origin = where the right palm grips. Barrel / business end points -Y. Up is +Z. 1 BU = 1 m.
Attach to the character's SOCKET_Weapon_R with zero offset.
Moving parts are separate objects with their own pivot (Mag, Slide, Pump) so they can be animated.
Markers (empties): MUZZLE (flash + bullet origin), EJECT (shell casing), AIM (rear sight: camera
lines up AIM -> MUZZLE when aiming down sights), GRIP_L (left hand for two-handed weapons),
HIT_BASE / HIT_TIP (melee hit line).
Materials: Metal, Polymer, Wood, Accent."""

def weapon_pistol():
    reset(); W = wmats(); c = coll("Pistol")
    body = build("Pistol", [P((0.028,0.045,0.11), (0,0.008,-0.01), 1),
                            P((0.026,0.13,0.02), (0,-0.045,0.035), 1),
                            P((0.006,0.04,0.004), (0,-0.045,0.002), 1),
                            P((0.004,0.006,0.02), (0,-0.03,0.018), 0)], c, [W['metal'], W['poly']])
    build("Slide", [P((0.03,0.19,0.035), (0,-0.065,0.0625), 0),
                    P((0.006,0.006,0.008), (0,-0.155,0.084), 1),
                    P((0.02,0.006,0.008), (0,0.022,0.084), 1)], c, [W['metal'], W['acc']],
          origin=(0,0.03,0.0625), parent=body)
    build("Mag", [P((0.022,0.034,0.10), (0,0.008,-0.02), 0),
                  P((0.03,0.045,0.012), (0,0.008,-0.071), 1)], c, [W['metal'], W['poly']],
          origin=(0,0.008,0.03), parent=body)
    for n, l in (("MUZZLE", (0,-0.162,0.0625)), ("EJECT", (0.017,-0.03,0.072)), ("AIM", (0,0.022,0.09))):
        empty(n, l, c, parent=body, size=0.02)
    set_meta(WEAPON_README.format(kind="PISTOL, one-handed, ~20 cm"))
    save("weapon_pistol")

def weapon_uzi():
    reset(); W = wmats(); c = coll("UZI")
    body = build("UZI", [P((0.045,0.26,0.07), (0,-0.04,0.0775), 0),
                         P((0.035,0.05,0.10), (0,0,-0.008), 1),
                         P((0.02,0.04,0.02), (0,-0.19,0.0775), 0),
                         P((0.05,0.015,0.06), (0,0.098,0.07), 1),
                         P((0.012,0.012,0.014), (0,-0.10,0.12), 2),
                         P((0.006,0.045,0.004), (0,-0.035,0.008), 0),
                         P((0.004,0.006,0.02), (0,-0.035,0.024), 0)], c,
                 [W['metal'], W['poly'], W['acc']])
    build("Mag", [P((0.024,0.03,0.20), (0,0,-0.07), 0)], c, [W['metal']],
          origin=(0,0,0.03), parent=body)
    for n, l in (("MUZZLE", (0,-0.212,0.0775)), ("EJECT", (0.024,-0.02,0.09)), ("AIM", (0,0.07,0.125))):
        empty(n, l, c, parent=body, size=0.02)
    set_meta(WEAPON_README.format(kind="UZI, one-handed, ~31 cm (stock folded)"))
    save("weapon_uzi")

def weapon_shotgun():
    reset(); W = wmats(); c = coll("Shotgun")
    body = build("Shotgun", [P((0.035,0.08,0.05), (0,0,0.012), 2),
                             P((0.04,0.30,0.08), (0,0.18,-0.005), 2, rot=(-6,0,0)),
                             P((0.045,0.02,0.13), (0,0.335,-0.02), 1),
                             P((0.045,0.20,0.075), (0,-0.13,0.035), 0),
                             P((0.025,0.50,0.025), (0,-0.48,0.055), 0),
                             P((0.025,0.40,0.022), (0,-0.43,0.022), 0),
                             P((0.006,0.05,0.004), (0,-0.05,-0.008), 0),
                             P((0.004,0.006,0.02), (0,-0.045,0.008), 0),
                             P((0.006,0.006,0.008), (0,-0.725,0.072), 3)], c,
                   [W['metal'], W['poly'], W['wood'], W['acc']])
    build("Pump", [P((0.05,0.16,0.05), (0,-0.40,0.022), 0)], c, [W['wood']],
          origin=(0,-0.40,0.022), parent=body)
    for n, l in (("MUZZLE", (0,-0.732,0.055)), ("EJECT", (0.024,-0.11,0.05)), ("AIM", (0,-0.05,0.08)),
                 ("GRIP_L", (0,-0.40,-0.005))):
        empty(n, l, c, parent=body, size=0.03)
    set_meta(WEAPON_README.format(kind="SHOTGUN, two-handed pump, ~1.07 m"))
    save("weapon_shotgun")

def weapon_rifle():
    reset(); W = wmats(); c = coll("Rifle")
    body = build("Rifle", [P((0.03,0.04,0.11), (0,0.012,-0.03), 1, rot=(-12,0,0)),
                           P((0.035,0.24,0.05), (0,-0.06,0.045), 0),
                           P((0.035,0.24,0.04), (0,-0.06,0.09), 0),
                           P((0.022,0.24,0.008), (0,-0.07,0.114), 0),
                           P((0.05,0.28,0.06), (0,-0.32,0.07), 1),
                           P((0.018,0.20,0.018), (0,-0.56,0.075), 0),
                           P((0.026,0.05,0.026), (0,-0.685,0.075), 0),
                           P((0.03,0.14,0.03), (0,0.13,0.08), 0),
                           P((0.04,0.16,0.09), (0,0.22,0.06), 1),
                           P((0.042,0.015,0.11), (0,0.305,0.055), 1),
                           P((0.02,0.02,0.03), (0,0.03,0.131), 0),
                           P((0.008,0.01,0.05), (0,-0.42,0.122), 0),
                           P((0.006,0.05,0.004), (0,-0.035,0.0), 0),
                           P((0.004,0.006,0.02), (0,-0.03,0.015), 0)], c, [W['metal'], W['poly']])
    build("Mag", [P((0.025,0.07,0.17), (0,-0.12,-0.04), 0, rot=(10,0,0))], c, [W['metal']],
          origin=(0,-0.12,0.025), parent=body)
    for n, l in (("MUZZLE", (0,-0.712,0.075)), ("EJECT", (0.02,-0.05,0.09)), ("AIM", (0,0.03,0.148)),
                 ("GRIP_L", (0,-0.32,0.035))):
        empty(n, l, c, parent=body, size=0.03)
    set_meta(WEAPON_README.format(kind="RIFLE, two-handed, ~1.02 m"))
    save("weapon_rifle")

def weapon_knife():
    reset(); W = wmats(); c = coll("Knife")
    body = build("Knife", [P((0.025,0.11,0.03), (0,0,0), 1),
                           P((0.03,0.015,0.035), (0,0.062,0), 0),
                           P((0.06,0.012,0.015), (0,-0.061,0), 0),
                           P((0.004,0.15,0.03), (0,-0.142,0.003), 2),
                           P((0.004,0.03,0.016), (0,-0.228,0.006), 2)], c,
                  [W['metal'], W['poly'], mat("Blade", (0.70, 0.71, 0.73), 0.3, 0.0)])
    empty("HIT_BASE", (0,-0.07,0), c, parent=body, size=0.02)
    empty("HIT_TIP", (0,-0.243,0.006), c, parent=body, size=0.02)
    set_meta(WEAPON_README.format(kind="KNIFE, one-handed, ~31 cm"))
    save("weapon_knife")

def weapon_bat():
    reset(); W = wmats(); c = coll("Bat")
    body = build("Bat", [P((0.05,0.02,0.05), (0,0.10,0), 0),
                         P((0.03,0.34,0.03), (0,-0.08,0), 1),
                         P((0.045,0.16,0.045), (0,-0.32,0), 0),
                         P((0.065,0.35,0.065), (0,-0.57,0), 0),
                         P((0.058,0.01,0.058), (0,-0.75,0), 0)], c,
                [mat("BatWood", (0.72, 0.55, 0.34), 0.6), W['acc']])
    empty("HIT_BASE", (0,-0.40,0), c, parent=body, size=0.03)
    empty("HIT_TIP", (0,-0.755,0), c, parent=body, size=0.03)
    empty("GRIP_L", (0,0.06,0), c, parent=body, size=0.03)
    set_meta(WEAPON_README.format(kind="BAT, ~0.86 m. GRIP_L optional for two-handed swings"))
    save("weapon_bat")

for fn in (person, env_tree, env_bush, env_rock, env_sandbags, weapon_pistol, weapon_uzi,
           weapon_shotgun, weapon_rifle, weapon_knife, weapon_bat):
    fn()
    print("built", fn.__name__)
