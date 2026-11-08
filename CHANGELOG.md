# Change log

## Prototype v0.4.1 (2026-11-08)
- Your own recordings are in: the damage scream when you get hurt, 9 zombie screams (cut from your two files, picked at random), and 3 reload sounds (all five files used).
- The game now loads any recording put in assets/audio with the right slot name, and falls back to the generated sounds for the rest.

## Prototype v0.4.0 (2026-11-08)
- Structure spawner: every island rolls its own town (supermarket, church, car dealership, 5-9 houses), entrances facing the town centre.
- Abandoned car dealership: the Tike and Bike now start inside it, with a 7 m opening to drive out through. Broken glass, a hanging sign, part of the roof caved in.
- Parking lots with painted bays and wrecked cars outside the supermarket, church and dealership.
- Roads connect every building, with driveways to each house. They follow the hills, avoid water and show on the map.
- Pine forests in clusters around the island.
- Fix: building floors are now level with the ground, so you can walk and drive straight in.

## Prototype v0.3.0 (2026-11-08)
- Town: a supermarket (shelves, checkouts, storage room), a church (bell tower, pews, altar) and seven houses (two rooms, furniture) on every island. All enterable, with open windows. Zombies wait inside some of them.
- Vehicle physics: velocity follows the slope, so hills and the eight dirt ramps launch you. Air time is announced, landings squash the suspension.
- Vehicle sound: gear changes, separate Tike and Bike engines, gravel rumble, tyre skid, horn on G (draws zombies), start-up, crash and landing sounds.
- Developer mode on P: zombies chase me on/off, god mode, free building, stats, spawn or remove zombies.
- Suit outfit: navy suit, white shirt and tie added to the character template. Your arms wear suit sleeves with white cuffs, and a seated driver in a suit shows in third person.

## Prototype v0.2.0 (2026-11-08)
Play-test requests: grassier ground, breaking trees with the bat, more realistic guns, driving.
- Ground: thick grass tufts everywhere grassy, plus dirt patches and rock patches with loose stones. The map shows them too. Grass dies when Hex Horizon passes over it.
- Trees: the bat chops trees twice as fast as the knife (3 hits). Felled trees tip over and leave a stump, with wood chips and a crack.
- Guns: new, more detailed models (polymer pistol, UZI with folded stock, pump shotgun, AR-style rifle with a red dot sight, combat knife, taped bat). Aiming with the rifle looks through the red dot.
- Gun feel: the gun kicks up when fired, casings fly out (red shells from the shotgun), muzzle smoke, the shotgun pump racks, guns lower while sprinting, forearms on screen, gunshots with an echo tail.
- Driving: E next to the Tike or Bike to get in. W/S drive, A/D steer, Space brakes. The Tike reaches 54 km/h, the Bike 68 km/h and leans into corners. Wheels spin and steer, the steering wheel turns, the eyes look ahead. Running over zombies hurts them. The engine is loud, so it draws zombies.
- V switches to third person while driving. This is a test key until the craftable camera stick exists.

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
