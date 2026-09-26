# Map Guide

The game generates **Titan Island** from code (terrain + part props). For real art, build
the map in Studio. **Gameplay only cares about tagged markers**, so a hand-built map works as
long as it has them.

## How it decides

On server start `MapService` looks for any part tagged `Plot`.
- **Found** → uses your map.
- **None** → runs `MapGenerator` (placeholder island).

Tip: press Play, copy `Workspace/Map`, stop, paste it in edit mode as a starting point
(parts and markers copy; terrain doesn't, so use the Terrain Editor's region tools for that).

## Markers (CollectionService tags)

Use the **Tag Editor** (View → Tag Editor) or Properties → Tags. Marker parts should be
invisible: `Transparency = 1`, `CanCollide = false`, `Anchored = true`.

| Tag | What | Attributes |
|---|---|---|
| `Plot` | One per base (need `GameConfig.Plots.Count`). The base is built centered on it. **Front (-Z) faces the arena.** Needs ~74×74 studs of flat ground. | `PlotIndex` (1..N) |
| `Arena` | Center of the fighting area. | `Radius` (fighting circle, studs) |
| `ArenaSpawn` | Where fighters start (at least 2; 12 for full Titan Clashes), facing the center. | — |
| `Stands` | Where spectators are moved during a match. | — |
| `FoodSpawn` | Where food grows (~1.5 studs above ground). 40–80 total. | — |
| `MeteorZone` | Where Meteor Feast food lands: a ring around the part. | `Radius`, `InnerRadius` |
| `Leaderboard` | A flat board (front face readable). | `Board` = `Trophies` / `Biggest` / `Rebirths` |
| `HubSpawn` | Where players first appear (a SpawnLocation). | — |

## Rules of thumb

- Keep the arena flat and walled (fighters leaving `Radius` get pulled back in).
- Keep food spawns reachable and outside the arena.
- Bases need clear paths to the fields: stealing is the core loop.
- Turn on **Workspace.StreamingEnabled** for big maps; the code handles it.
