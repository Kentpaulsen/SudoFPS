# Change log

## Prototype v0.1.0 (2026-11-08)
First playable build. Offline sandbox in the browser and on Windows.
- Procedural island (384 m, new layout every game) with trees, bushes, rocks, beaches and sea.
- First-person movement: walk, sprint, jump, crouch.
- Six weapons from the templates: pistol, UZI, shotgun, rifle (shoot, aim, reload, recoil, muzzle flash, bullet holes), knife and bat (melee, the bat knocks zombies back).
- Harvesting: knife or bat on trees (wood), rocks (stone, sometimes metal) and bushes (fibre). Trees fall, rocks and bushes disappear.
- Crafting (Q): sandbags from 1 fibre + 2 stone.
- Building (hold B for the wheel): wall, wall with window, wall with doorway, L corner on a 3 m snap grid. Ghost preview, foundation on slopes, walls rise up as they are built.
- Zombie Royale: DayZ-style zombies idle around the island, wake on noise or sight, scream to pull in others, hordes arrive on a timer and the population grows.
- Zombification bar: zombie hits raise it. From 50% you stagger, the screen wobbles and loses colour. At 100% you have turned: melee only and zombies ignore you.
- Last Standing: Hex Horizon storm with six shrinking phases, damage outside, plants wither, crackle at the edge.
- Rust-style map grid (A-F, 1-6) with numpad sub-sectors (C4-7), minimap, full map (M), team ping (T), open broadcast (Y).
- The parked Tike and Bike watch you with their eyes.
- Stress test keys (K/L/O) with FPS counter.
- Placeholder sounds generated in code.
- Blender files re-saved in Blender 4.2 LTS so they open in 4.2 and newer.

## Assets v0.2 (2026-11-08)
- Vehicles: Tike (modified kiddie car with roll cage, knobby tyres, rear engine) and Bike (scrambler that leans in corners). Separate wheels and steering parts, seat/hand/foot/exit markers.
- Both vehicles have a cartoon face (eyes, brows, grin). Pupils are separate objects so the game can make them look around.
- Sandbag build pieces on a 3 m snapping cell: wall, wall with window, wall with doorway, L-shaped corner.
- Repo layout: `assets/` (blend, glb, previews), `tools/blender/` (generator scripts), `docs/` (design decisions, asset conventions).

## Assets v0.1 (2026-11-08)
- Character with modular slots (heads, hair, tops, bottoms, shoes, hats), female shape key, Godot humanoid bone names, weapon sockets.
- Environment: tree, bush, rock, low sandbag cover.
- Weapons: pistol, UZI, shotgun, rifle, knife, bat, with muzzle/eject/aim/grip markers.
