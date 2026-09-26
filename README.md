# 🦖 Kaiju Keepers

Run your own **kaiju zoo**. Explore a big land of biomes, **catch wild kaiju**, find
food to make them grow **giant**, steal food from other zoos, and fight to own the
**Kaiju King**.

> The name lives in one place (`src/shared/Config/GameConfig.lua`), so it's easy to change.

## ▶️ Play it in Roblox Studio

**Easiest:** download [`build/KaijuKeepers.rbxlx`](build/KaijuKeepers.rbxlx), double-click it and
press **Play (F5)**. The map is generated when the server starts, so give it a few seconds.

- Test with several players (for stealing): **Test → Clients and Servers → 2 Players → Start**.
- Before publishing: **Game Settings → Security → Enable Studio Access to API Services** (saving),
  and **Max Players = 8** (one zoo per player).

**While developing (live sync):** install [Aftman](https://github.com/LPGhatguy/aftman), run
`aftman install`, then `rojo serve`, and click **Connect** in the Rojo Studio plugin.

## 🎮 Gameplay (v0.2: Big Land)

| | |
|---|---|
| **Big land** | Zoo hub in the middle + 6 biomes: 🌲 Forest, 🏖️ Beach, ❄️ Snow Peaks, 🌋 Volcano, 💎 Crystal Caves, ⭐ Star Island |
| **Explore** | Each biome grows its own food, which regrows over time. Biomes unlock with cash and rebirths |
| **Catch** | Wild kaiju roam each biome. Hold **E** to catch (rarer = longer + may run away). Rare spawns are announced server-wide |
| **Feed & grow** | Kaiju level up and physically **grow**. Each kaiju has **favorite foods** (2x XP ❤️) |
| **Mutations** | Special foods mutate kaiju (Lava, Crystal, Shadow, Golden, Rainbow): big income boost + auras |
| **Steal** | Steal food from other zoos' storage and run home. Owners take it back; guard kaiju knock thieves away |
| **Kaiju King** | The biggest kaiju on the server gets a crown and +50% income |
| **Rebirth** | Reset for permanent bonuses: income, enclosures, storage. Unlocks later areas |
| **Events** | ☄️ Meteor Feast, 🩸 Blood Moon |

**Controls:** E = feed / catch / steal / take back / unlock · hold F = sell · left menu = Eggs, Food, Areas, Rebirth, Home, Lock · bottom bar = pick food.

## 🧱 For developers

- **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)**: how the code is organized + recipes for adding content and systems
- **[docs/MAP_GUIDE.md](docs/MAP_GUIDE.md)**: how to replace the generated map with a hand-built one
- **[docs/GAME_DESIGN.md](docs/GAME_DESIGN.md)**: game plan and update roadmap

Run every check (format, build, type check, tests) with `scripts/check.sh`. CI runs the same on every push.
