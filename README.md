# SudoFPS

Multiplayer first-person shooter for browser and Windows, built in Godot 4. Procedural islands, tactical sandbag and plank building, the Hex Horizon storm, and DayZ-style zombies.

- `docs/design-decisions.md`: everything agreed so far, plus open questions
- `docs/asset-conventions.md`: how the Blender templates are set up and what the game expects
- `assets/`: Blender templates (`.blend`), game-ready exports (`.glb`) and previews
- `CHANGELOG.md`: what changed in each release

Play: https://kentpaulsen.github.io/SudoFPS/ (browser version and Windows download, rebuilt on every push to main)

Status: prototype v0.1, offline sandbox.

- `game/`: the game scripts (Godot 4.4, GDScript)
- `.github/workflows/build.yml`: smoke test, web and Windows export, publish to GitHub Pages
- Run the automated test locally: `godot --headless -- --smoke`
