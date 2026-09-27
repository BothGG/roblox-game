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
| `Arena` | Center of the fighting area, on its floor (the arena can float anywhere, e.g. high in the sky). | `Radius` (fighting circle, studs) |
| `Portal` | Touch part that teleports players (`PortalService`). | `To` = `Arena` (to the stands) / `Island` (home) |
| `ArenaSpawn` | Where fighters start (at least 2; 12 for full Titan Clashes), facing the center. | — |
| `Stands` | Where spectators are moved during a match. | — |
| `FoodSpawn` | Where food grows (~1.5 studs above ground). 40–80 total. | — |
| `WildSpawn` | Where wild titans appear; they wander ~28 studs around it. 10–20 total, spread out. Optional (falls back to `FoodSpawn`). | — |
| `MeteorZone` | Where Meteor Feast food lands: a ring around the part. | `Radius`, `InnerRadius` |
| `Leaderboard` | A flat board (front face readable). | `Board` = `Trophies` / `Biggest` / `Rebirths` |
| `HubSpawn` | Where players first appear (a SpawnLocation). | — |

## Look: classic studs or smooth terrain

`GameConfig.Map.Style = "Studs"` (default) builds the island from Plastic parts with **studs on top
and inlets on the sides**, the classic Roblox look (`Modules/Map/StudGround.lua`): bright green
grass, brown dirt patches in the food fields, tan roads and a stone plaza in the middle. Bases get
the same studded style.
`"Terrain"` uses smooth Roblox terrain instead. Colors are in `COLORS` at the top of
`MapGenerator.lua`.

**The arena is its own floating square block** (`Map.ArenaHeight`, `Map.ArenaSize`) high above
the plaza. A glowing portal in the plaza takes players up to the stands; a portal on the arena
brings them home. Fighters are teleported in and out by BattleService.

For a hand-built map in the same style: select your parts → set **Material = Plastic**,
**TopSurface = Studs**, side surfaces **Inlet**.

## Rules of thumb

- Keep the arena flat and walled (fighters leaving `Radius` get pulled back in).
- Keep food spawns reachable and outside the arena.
- Bases need clear paths to the fields: stealing is the core loop.
- Turn on **Workspace.StreamingEnabled** for big maps; the code handles it.
