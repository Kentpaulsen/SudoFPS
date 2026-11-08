# SudoFPS design decisions

Agreed decisions so far. Prototype v0.1 is playable (offline sandbox). Asset templates v0.2 in `assets/`.
Repo: https://github.com/Kentpaulsen/SudoFPS. GitHub Pages enabled (Source: GitHub Actions).

## Platform and tech
- Engine: Godot 4, GDScript (C# cannot export to web).
- Targets: browser build and portable Windows executable from the same project. Phone ruled out.
- Delivery: automatic build publishing the web version (GitHub Pages) and the Windows download.
- Hit registration: lag compensation ("rewind": the server checks a shot against where targets were when it was fired). Zombies are rewound with a simple capsule hitbox only; players get detailed hitboxes (head/body).

## Multiplayer
- 1v1 and 2v2 at launch, server-authoritative. WebSocket transport in the browser.
- Team size is a setting, not hard-coded. 3v3 or 4v4 later is a balance job, not a rebuild.
- Scaling: comfortable up to ~16–20 players total. Beyond that the server must send each player only nearby entities.
- Balance that scales with player count: island size (procedural, follows player count), crates, objective items, storm timing, zombie count, CTF respawns and flag distance.
- Estimated bandwidth at 6 players + 60 chasing zombies: ~0.1–0.2 Mbit/s per player, under 1 Mbit/s total server upload.
- Architecture from v0.1: game always runs as server + client in one program, so multiplayer is connecting the network, not a rewrite.
- Online hosting: dedicated server on Kent's homelab. Browser clients need a domain with a certificate (secure WebSocket).
- LAN play: one desktop player hosts, others join by IP. LAN play uses the desktop version.

## Modes
| Mode | Storm (Hex Horizon) | Zombies | Objective item |
|---|---|---|---|
| Last Standing (pure 1v1 / 2v2) | Yes | No | Airstrike |
| Capture the Flag | No | Optional | Fake flag |
| Zombie Royale (endless escalation, score points) | No | Yes (see open question) | Zombie beacon |
- Storm and zombies never appear in the same mode.
- Zombie-related rules (harvest noise, broadcast attraction, zombification) only apply in modes with zombies.

## Zombies (DayZ-style)
- Idle around the island, alone or in groups. Not shown on the map.
- Noise or line of sight makes them chase you, screaming; screams pull in more zombies.
- Harvesting is loud and can trigger them. An open broadcast draws them to your position.
- Zombie Royale: zombies respawn out of sight and density rises over time, so the scream chain turns into endless waves.
- Performance target: a couple of hundred idle on the island, 40–60 chasing at once. To be confirmed with the stress-test scene.

## Building
- Rust-style snapping on a 3 m cell. Pieces snap to each other; the first piece follows the terrain, with an automatic foundation on slopes.
- Place from a build menu (selection wheel) with a ghost preview. Requires the materials in inventory. Short framing phase before full strength.
- Sandbag wheel: wall, wall with window, wall with doorway, L-shaped corner. Each costs a different number of sandbags (proposed: 10 / 9 / 8 / 18).
- Plank wheel: floors and roofs/ceilings (pieces to be listed).
- Damage: bullets barely scratch sandbags, do some damage to planks. The airstrike flattens anything.
- Crowbar dismantles any piece. 3 uses per crowbar. It is a tool, not a weapon (cannot hit players).
- CTF: building around your own flag is allowed. Proposed: no placement within a few metres of the flag.

## Materials and crafting
- Trees: wood, crafted into planks.
- Bushes/plants: fibre for sandbag sacks. Rocks: sand/filler. Sacks + filler = sandbags.
- Rocks also give a small amount of metal. Metal crafts the crowbar and the metal camera stick.
- Crafting menu needed (first recipes: sandbag, plank, crowbar, camera stick).

## Storm: "Hex Horizon"
- Shrinking hexagonal zone. Each new zone placed randomly inside the previous one.
- Damages and kills players. Kills vegetation (trees, bushes, flowers), so wood, fibre and natural cover disappear outside the zone.
- Unaffected: structures, rocks (stone and metal stay harvestable), loot.
- Walls do not shield players from storm damage.
- Edge warning: bug-zapper crackle when a player is close to the edge.

## Loot
- World loot (ordinary to mid-value) is spread around the island and not marked on the map.
- Dropped crates (high-value, arriving during the match) are marked on the map for all players.
- Opening a dropped crate: casino-style lock mini-game, skill-based, a few seconds. Proposed: interrupted by taking damage.
- All loot survives the storm.
- Decoy broadcast item: super rare, dropped crates only.

## Objective items
- Each map holds 3–4 items. Combined, they build something decisive. Resets every match; no progression across matches.
- Last Standing: airstrike (antenna + walkie-talkie + launch codes).
- Zombie Royale: zombie beacon, sends a horde at a target.
- Capture the Flag: fake flag, to confuse the defending team.
- Battlescanner kept as an alternative.
- Open: does the beacon target a sector the player picks on the map (proposed), with a warning to players in that sector?

## Map and location reporting
- Minimap in the corner plus a full map. Rust-style grid: fixed tile size, tile name in the tile corner, number of tiles follows island size.
- Fine position by numpad subdivision: A6-6.
- Team ping: marks your tile for your team-mate only. Comms chirp plus tile text on their HUD.
- Open broadcast: transmits your tile to all players, as a taunt. Has a cooldown. Draws zombies in zombie modes.

## Combat
- Melee knockback: big against zombies, minor against players.

## Zombification (modes with zombies)
- Two bars: Health and Zombification (raised by zombie hits). Antidote (loot) lowers zombification.
- 50%: stagger walk visible to others, screen wobble and a desaturating vignette for the infected player. No map reveal.
- 50% option to test once playable: reduced healing.
- 100%: you join the zombie faction. No guns, melee only. Zombies ignore you. Turned players are allied with each other. You keep your health bar and can still be killed.
- Open: zombie faction win condition, and what ends a Zombie Royale match.

## Vehicles
- v0.3: slope-following physics, so crests and ramps give air time; landing squash and thump. Eight dirt ramps per island.
- v0.3: engine sound with simulated gear changes (Tike deep four-stroke, Bike buzzy two-stroke), gravel rumble, tyre skid, horn (G, draws zombies), crash and landing sounds.
- Tike: one-seat modified kiddie car (roll cage, knobby tyres, rear engine). Arcade four-wheel handling.
- Bike: one-seat scrambler. Same arcade handling, cannot fall over, the model leans into corners.
- Canoe/surfboard for satellite islands.
- Camera: first person by default. Third person only with a camera stick (GoPro-style) mounted on the vehicle.
  - Crafted from wood (breaks on a hard crash or landing) or metal (has durability, survives several hits). Metal competes with crowbars for the same scarce resource.
  - The camera sits at the stick tip and collides with the world, so it cannot see through walls.
  - Proposed: the stick is visible to others and can be shot off. It belongs to the vehicle, so whoever takes the vehicle gets the stick.
  - Breakage triggers on impact force (crash speed, hard landings), since the vehicles are arcade and rarely roll.

## Weapons
- Pistol and UZI one-handed, shotgun and rifle two-handed, knife, bat.

## Art direction
- Deferred.

## Release plan (proposed)
- v0.1 offline sandbox: island, movement, six weapons, harvesting, sandbag build wheel with four pieces, DayZ zombies + stress-test spawner with FPS counter, Rust-style map, storm on/off.
- v0.2: LAN multiplayer.
- v0.3: planks and floors, crowbar, crafting menu, crates with lock mini-game, objective items.

## Prototype v0.1 notes (implementation choices to review in play-testing)
- Island 384 m, map tiles 64 m (6 x 6). Starting kit: 20 sandbags so building can be tried at once.
- Zombies: 110 at start, growing by ~8 per minute up to 260; hordes every 45-80 s from a named sector.
- Zombie hit: 9 damage, +11% zombification. Health regenerates after 6 s without damage.
- Storm: six phases, damage 1-8.5 HP/s depending on phase.
- Vehicles are drivable offline from v0.2 (play-test request, ahead of the multiplayer plan). They will need network work in the multiplayer release.
- Third person while driving is on the V key for testing; the camera stick that should gate it is not built yet.
- Bat removes 2 tree hit points per hit, knife 1 (trees have 5).

## Queued for the next implementation round (Kent, 2026-11-08)
- A moving vehicle knocks back zombies and players like a bat, but 10x as hard. This applies whether the vehicle is manned or not.
- Jumping off a moving vehicle: the player rolls and takes a bit of damage. The vehicle carries on until it loses its speed.
- Crashing into zombies or structures slows the vehicle faster than rolling to a stop.
- Standing still on the Bike: zombies can pull you off.
- Zombie count limited by performance: the game measures frame rate and stops spawning (and removes far-away idle zombies) when it drops below 30 fps; it lets the population grow again when there is headroom.
- Quality settings (grass density, shadows, view distance) so low-end machines such as Chromebooks can hold 30 fps.

## Town and structure spawner (v0.4)
- Data-driven spawner: each structure type rolls a count per island (supermarket 1, church 1, car dealership 1, houses 5-9) and a placement ring around the town centre. Entrances face the town centre. Add a type by adding a row to the table plus its Blender template.
- Parking lots (asphalt, painted bays, a few wrecked cars) in front of the supermarket, church and dealership. Houses get a narrow driveway instead.
- Roads: a minimum spanning tree links every entrance, routed round water, steep ground and other buildings; the ground is smoothed under the road. Asphalt with a dashed centre line. Roads and parking show on the map.
- Abandoned car dealership: 7 m wide drive-out opening, broken showroom glass, caved-in roof section, office, workshop door. The Tike and Bike spawn inside, facing out.
- Floors are flush with the flattened ground (v0.4 fix), so players and vehicles go straight in.
- Pine forests: 10-14 clusters of 10-22 pines per island, harvestable for wood.
- Zombies lurk inside the supermarket, church, dealership and some houses. Houses get random wall and roof colours.

## Developer mode (v0.3)
- P opens the developer panel: zombies chase me on/off, god mode, free building, stats, zombie spawn/remove buttons.

## Menus and settings (v0.5)
- Esc opens the in-game menu: Resume, Settings, Controls, Toggle fullscreen, Main menu, Quit (desktop only). In the browser, Esc releases the mouse and the menu opens by itself.
- Zombie Royale pauses while the menu is open. Last Standing keeps running (as a multiplayer match will).
- Settings (saved between sessions): quality preset Low/Medium/High, render scale, shadows, grass density, view distance, fullscreen, VSync, frame rate limit, master volume, field of view, mouse sensitivity, invert Y, day length, and rebindable keys.
- Settings also reachable from the start screen, with a fullscreen button.

## Day and night, roads (v0.5)
- Day/night cycle, 14 minutes per day by default (setting 4-40). Sunrise and sunset colours, moonlight at night.
- Street lamps along the main roads and on parking lots switch on at dusk.
- Norwegian road markings: yellow dashed centre line (3 m dash, 6 m gap), white solid edge lines, zebra crossings with blue crossing signs outside the supermarket, church and dealership.
- Buildings: the ground inside every footprint is set just below the floor after all flattening, so no building is ever partly buried.

## v0.6
- Doors: the church tower has a wooden double door, every house a front door. E opens and closes them. Closed doors block zombies too, so a house is a place to hide (zombies spawned inside stay inside until someone opens up).
- Bjørn the car dealer stands in the dealership. Talk to him (E) and pick the Tike or the motorbike; it appears at the showroom door. One of each: asking again brings yours back if nobody is driving it. Without a dealership the vehicles are parked near the spawn as before.
- More roads: up to three extra links make loops in town, and up to three dead-end roads lead out to the coast.
- Norwegian signs: 50 km/h at both ends of town roads, forkjørsvei, vikeplikt and blindvei on roads out of town, P at parking lots, 30 km/h by the church, gangfelt at crossings.
- Zombies: jointed bodies (legs, hunched torso, reaching arms, lolling head), walk cycle that follows their speed, limping walkers and about 20% runners, flinch when hit, arm swipe when attacking, glowing eyes, blood and torn clothes, five outfits, varied height. Animation only runs within 70 m.
- Fix: the church tower door was walled up (stacked openings bug in the Blender wall builder).

## Recorded sounds (v0.4.1)
- The game loads `assets/audio/<slot>_<nn>.wav/.ogg` automatically and picks a random take per play; generated sounds stay as fallback. Spec: `docs/audio.md`.
- First recordings in: player_hurt (1), zombie_scream (9 takes cut from two files), reload (2 parts). Originals kept in `assets/audio/raw/`.

## Character
- Suit outfit added to the character template (Top_04_Suit with shirt and tie, Bottom_04_SuitTrousers, Shoes_03_Dress). First-person arms wear the suit sleeves; a seated suited driver shows in third person while driving.
- No real people's likenesses for characters.

## Pending
- Kent's review of this document.
- Zombie Royale "without zombies": what is it?
- Zombie faction win condition / Zombie Royale end condition.
- Beacon targeting.
