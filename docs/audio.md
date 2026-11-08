# SudoFPS audio spec

How to deliver recorded sounds so they drop straight into the game. Until a file exists, the game uses its generated placeholder for that slot.

## Format

- **Short sounds (screams, hits, shots, footsteps):** WAV, 16-bit PCM, 44.1 kHz, **mono**.
- **Long or looping sounds (engines, ambience, music):** OGG Vorbis, quality 5-6, mono for things in the world, stereo only for music.
- **Mono matters:** the game places sounds in 3D (left/right, distance). Stereo files can't be positioned.
- **Levels:** peak around -1 dBFS, no clipping. Trim silence at the start so the sound fires instantly; leave a short natural tail at the end.
- **Dry:** no reverb or echo baked in. The game adds distance and echo itself.
- **Variations:** record 3-5 takes of anything that repeats (screams, hurt, groans, footsteps). The game picks one at random so it never sounds like a loop.
- **Loops:** engines and rumble should loop seamlessly (start and end match). 1-3 seconds is plenty.
- **Recording:** a phone in a quiet room with soft furnishings is fine. Keep 15-30 cm from the mic and don't overload it on screams.

## File names

`assets/audio/<slot>_<nn>.wav`, numbered from 01. Example: `zombie_scream_01.wav`, `zombie_scream_02.wav`.

## Slots

| Slot | What it is | Length | Takes |
|---|---|---|---|
| **zombie_scream** | Zombie spots you and screams (pulls in others) | 0.6-1.2 s | 4-5 |
| **zombie_groan** | Idle/chasing groan | 0.8-1.5 s | 4-5 |
| zombie_attack | Zombie hits you (snarl + swipe) | 0.3-0.6 s | 3 |
| zombie_death | Zombie dies | 0.5-1.0 s | 3 |
| **player_hurt** | Player takes damage | 0.2-0.5 s | 4-5 |
| player_death | Player dies | 0.6-1.2 s | 2 |
| player_turn | Player hits 100% zombification | 1-2 s | 1-2 |
| player_land | Grunt on hard landing / jumping off a vehicle | 0.2-0.4 s | 3 |
| pistol / uzi / rifle / shotgun | Gunshots | 0.4-1.0 s | 2-3 |
| reload | Mag out / in | 0.3-0.8 s | 2 |
| empty | Dry fire click | 0.05-0.1 s | 1 |
| swing | Knife/bat swoosh | 0.2-0.3 s | 3 |
| hit | Melee impact on a body | 0.1-0.3 s | 3 |
| chop | Hitting a tree | 0.1-0.3 s | 3 |
| rock | Hitting a rock | 0.1-0.3 s | 3 |
| tree_fall | Tree cracks and falls | 1-2 s | 2 |
| build | Sandbags thumping into place | 0.5-1.0 s | 2 |
| craft | Crafting confirm | 0.1-0.3 s | 1 |
| ping / broadcast | Radio chirp | 0.2-0.5 s | 1 each |
| crackle | Hex Horizon edge zap | 0.3-0.6 s | 3 |
| footstep_grass / footstep_dirt / footstep_wood | Footsteps by ground | 0.1-0.3 s | 4 each |
| engine_tike / engine_bike | Engine loop at steady mid revs (OGG) | 1-3 s loop | 1 |
| start_tike / start_bike | Engine start | 0.5-1.5 s | 1 |
| horn_tike / horn_bike | Horn | 0.3-0.8 s | 1 |
| rumble / skid | Gravel rumble loop, tyre skid loop (OGG) | 1-2 s loop | 1 |
| land_vehicle / crash | Vehicle landing thump, crash | 0.3-0.8 s | 2 |

Slots in **bold** are the dubbing priority: zombie_scream, zombie_groan, player_hurt.
