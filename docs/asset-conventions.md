# SudoFPS asset templates v0.2

Box templates for Blender 4.2 or newer (built in 5.2). Each .blend has a README text block (Scripting workspace, Text Editor) with the notes for that asset.

## Folders

- `assets/blender/` the files you edit
- `assets/glb/` ready-to-import exports of the same files
- `assets/previews/` renders of every asset; `assets/preview_*.png` are overview sheets
- `tools/blender/` the scripts that generated everything (`build_templates.py` = v0.1 set, `build_templates_v2.py` = vehicles and build pieces), so the set can be rebuilt or extended

## Rules that apply to every asset

- 1 Blender unit = 1 m. Origin at ground level for props and characters, at the grip for weapons.
- Front is -Y. Front view (numpad 1) shows the character's face and the front of the sandbags. Right view (numpad 3) shows weapons side-on with the barrel pointing left.
- Keep object names. The game finds parts, markers and colliders by name.
- Keep material names. The game uses them as tint slots (skin colour, jacket colour and so on).
- Objects ending in `-convcolonly` are colliders. Godot turns them into collision shapes and does not draw them. Keep them simple boxes and resize them if you change the shape a lot.
- Export: File > Export > glTF 2.0, format glTF Binary (.glb), Include: untick "Visible Objects" so hidden variants are exported too.

## Person

1.80 m, T-pose, rigid-skinned: every box follows exactly one bone. Bone names follow Godot's humanoid profile, so animation retargeting maps automatically.

Character creator slots, one visible at a time per slot: `Body` (always), `Head_*`, `Hair_*` (optional), `Top_*`, `Bottom_*`, `Shoes_*`, `Hat_*` (optional). To add a variant, duplicate one in its collection, rename it with the next number and keep the prefix.

All heads share one crown size (0.22 x 0.24 m, top at 1.80 m) so every hair and hat fits every head. Keep that when you model new heads.

Shape key `female` on Body, Tops and Bottoms: narrower chest and waist, wider hips. Height and hitbox are the same for both on purpose, so neither is easier to hit. New torso or leg clothing needs the same shape key or it clips.

Sockets: `SOCKET_Weapon_R` (gun hand), `SOCKET_Offhand_L`, `SOCKET_Hat`, `SOCKET_Back` (slung long gun), `SOCKET_Hip_R` (holster), `SOCKET_Camera` (eye height for first person).

## Environment

- **Tree** ~5.6 m. Collider on the trunk only. `HARVEST_Point` marks where hits and wood drops spawn.
- **Bush** no collider. You walk through it; it blocks sight only.
- **Rock** ~1.2 m, two colliders, `HARVEST_Point` for stone.
- **Sandbags** (low cover) 2.0 m wide, 1.0 m high: crouching hides you, standing lets you fire over. Kept as a quick cover piece; the full build system uses the pieces below.

## Weapons

Origin = right palm on the grip. Barrel points -Y, up is +Z. Attach to `SOCKET_Weapon_R` with zero offset.

| File | Hands | Length | Moving parts | Markers |
|---|---|---|---|---|
| pistol | 1 | 0.20 m | Slide, Mag | MUZZLE, EJECT, AIM |
| uzi | 1 | 0.31 m | Mag | MUZZLE, EJECT, AIM |
| shotgun | 2 | 1.07 m | Pump | MUZZLE, EJECT, AIM, GRIP_L |
| rifle | 2 | 1.02 m | Mag | MUZZLE, EJECT, AIM, GRIP_L |
| knife | 1 | 0.31 m | none | HIT_BASE, HIT_TIP |
| bat | 1 or 2 | 0.86 m | none | HIT_BASE, HIT_TIP, GRIP_L |

MUZZLE: flash and bullet origin. EJECT: shell casing. AIM: rear sight; aiming down sights lines the camera up from AIM to MUZZLE. GRIP_L: left hand. HIT_BASE to HIT_TIP: the melee damage line.

Moving parts have their own pivot so they can be animated: the mag drops straight down, the slide and pump slide along Y.

## Build pieces (sandbag wheel)

Rust-style snapping on a 3 m cell. Walls are 3.0 m wide, 3.0 m high, 0.38 m thick, built from 0.5 x 0.38 x 0.25 m bags in running bond. Origin at the bottom centre of the wall line; the wall runs along X and sits on the cell edge. The game adds a foundation below on sloped ground, so don't model one.

| File | Piece | Opening | Proposed cost | Markers |
|---|---|---|---|---|
| build_wall | Wall | none | 10 sandbags | SNAP_L, SNAP_R, SNAP_TOP |
| build_wallwindow | Wall with window | 1.0 x 0.75 m, sill at 1.25 m | 9 | same |
| build_walldoor | Wall with doorway | 1.0 x 2.25 m | 8 | same |
| build_walll | L-shaped corner | none | 18 | SNAP_CORNER, SNAP_A_END, SNAP_B_END, SNAP_TOP |

Window sill height: crouching hides you, standing lets you shoot through. Wooden lintels carry the bags over openings. The L piece has its origin on the shared cell corner, leg A along +X and leg B along +Y, with corner bags interlocking course by course. SNAP_TOP is where plank floors and roofs sit (z = 3.0).

## Vehicles

Origin on the ground under the vehicle centre, front -Y. The game drives both as arcade vehicles, no real tyre physics.

| File | Size | Moving parts | Markers |
|---|---|---|---|
| vehicle_tike | ~2.2 m long, cage top 1.5 m | Wheel_FL/FR/RL/RR, SteeringWheel | SEAT, HAND_L/R, FOOT_L/R, EXIT_L, CAM_3P |
| vehicle_bike | ~2.0 m long, bars 1.2 m | Steer (fork, bars, headlight; carries Wheel_F), Wheel_R | same |

Wheels roll about their own X axis, with the pivot at the hub. Front wheels on the Tike also turn about Z for steering. On the Bike, `Steer` turns about the head tube and the whole bike leans about the origin's Y axis when cornering. Materials are tint slots, so the Tike's red tub and yellow cage can be recoloured in game.

Faces: both vehicles have eyes, brows and a grin on the front (the Bike's sits on the number board and turns with the steering). `Pupil_L` and `Pupil_R` are separate objects with their origin at the eye centre. Moving them a few centimetres makes the vehicle look around, for example at the nearest player.
