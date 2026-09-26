# Map Guide

The game generates a placeholder map from code (terrain + part props). When you're ready for
real art, build the map in Studio. **Gameplay only cares about tagged markers**, so a
hand-built map works as long as it has them.

## How it decides

On server start, `MapService` checks for any part tagged `ZooPlot`.
- **Found** → uses your map as-is.
- **None** → runs `MapGenerator` to build the placeholder.

So: build your map inside `Workspace/Map`, add the markers below, and publish.
(Tip: press Play, copy the generated `Workspace/Map` folder, stop, and paste it into edit mode as
a starting point. That copies the parts and markers. Terrain doesn't copy this way; save it with
the Terrain Editor's Region tools, or sculpt your own.)

## Markers (CollectionService tags)

Use the **Tag Editor** in Studio (Model tab → Tag Editor), or the Properties panel → Tags.
Markers should be invisible parts: `Transparency = 1`, `CanCollide = false`, `Anchored = true`.

| Tag | What | Attributes |
|---|---|---|
| `ZooPlot` | One per zoo (need `GameConfig.Zoo.PlotCount`). The zoo is built centered on it. **Front (-Z / LookVector) faces the plaza.** | `PlotIndex` (number, 1..N) |
| `BiomeZone` | Covers a biome's area. Used for unlocks, ambience and "which biome am I in". | `Biome` (id from Biomes.lua), optional `Radius` (round zone; otherwise the part's box is used) |
| `FoodSpawn` | Where food grows (put it ~1.5 studs above the ground). 15–25 per biome feels good. | `Biome` |
| `WildSpawn` | Where wild kaiju appear and wander around (40 stud radius). 4–8 per biome. | `Biome` |
| `BiomeGate` | A solid wall across a biome's entrance. Locked players are blocked; the Unlock prompt + sign are added automatically. **Front (-Z) faces into the biome.** | `Biome` |
| `HubSpawn` | Where players appear before being sent to their zoo. Usually a SpawnLocation. | - |
| `MeteorZone` | Where Meteor Feast food lands. | optional `Radius` (default 60) |

## Rules of thumb

- Keep biome zones from overlapping (the first match wins).
- Players standing in a locked biome's zone get teleported outside its gate, so make sure every
  locked biome **has a gate** and its zone doesn't cover the path leading up to it.
- Keep food/wild spawns reachable (not on cliff tops).
- The zoo needs about `Zoo.PlotSize` (90×90 studs) of flat ground per plot.
- Big maps: turn on **Workspace.StreamingEnabled**. The code already handles streaming
  (biome zones are copied to `ReplicatedStorage.MapInfo`).
