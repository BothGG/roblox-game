# 🦖 Kaiju Keepers

A Roblox game where you collect baby kaiju, feed them until they're **giant**,
steal food from other players, and fight to own the **Kaiju King**.

> The name is set in one place (`src/shared/Config/GameConfig.lua`) so it's easy to change.

## ▶️ How to play it in Roblox Studio

### Option A: easiest (no tools needed)

1. On GitHub, open **`build/KaijuKeepers.rbxlx`** and click **Download raw file**.
2. Double-click the file. It opens in **Roblox Studio**.
3. Press **Play** (F5). You'll spawn at your base with a starter kaiju.

To test with several players (for stealing), use **Test → Clients and Servers → 2 Players → Start**.

### Option B: live sync while you edit code (recommended later)

The code lives in `src/`. **Rojo** syncs it into Studio so edits show up instantly.

1. Install the **Rojo** plugin in Studio (Creator Store → search "Rojo").
2. Install Rojo on your computer (the easy way is [Aftman](https://github.com/LPGhatguy/aftman), then run `aftman install` here),
   or install the **Rojo** extension in VS Code.
3. In this folder run `rojo serve` (or click "Start" in the VS Code extension).
4. In Studio open a new **Baseplate**, click the Rojo plugin → **Connect**.
5. Press **Play**.

To rebuild the place file yourself: `rojo build -o build/KaijuKeepers.rbxlx`.

### Before publishing

- **Game Settings → Security → Enable Studio Access to API Services** (so saving works in Studio).
- **Game Settings → Places → Max Players = 8** (one plot per player; change `Plots.Count` in GameConfig to allow more).

## 🎮 What's in the game (v0.1)

| Feature | How it works |
|---|---|
| **Kaiju** | 10 species, 6 rarities (Common → Secret). Each has a special trait. |
| **Feeding & growth** | Press **E** on your kaiju to feed it. It levels up and physically **grows** (up to ~13x at Lv.100). |
| **Food** | 6 foods. Grab free food in the middle, buy it, or **steal it**. |
| **Mutations** | Special foods can mutate a kaiju: Lava, Crystal, Shadow, Golden (and a super rare Rainbow from eggs). Mutations multiply income and add glowing auras. |
| **Stealing** | Hold **E** on another player's food crate, then run home. Owners can **Take Back**, and guard kaiju (Kong, Hydra) knock thieves away. |
| **Lock** | Lock your storage for 30s (then it recharges). |
| **Eggs** | 3 eggs with different odds and an animated hatch reveal. |
| **Kaiju King** | The biggest kaiju on the server gets a crown, a gold outline and +50% income for its owner. |
| **Rebirth** | Reset for a permanent bonus: more income, more pen slots, more storage. |
| **Events** | Meteor Feast (food falls from the sky) and Blood Moon (2x growth, faster stealing). |
| **Saving** | DataStore with autosave, retries and safe shutdown. |

**Controls:** E = feed / steal / take back · hold F = sell a kaiju · left menu = Eggs / Food / Rebirth / Lock · bottom bar = pick which food to feed.

## 📁 Project layout

```
src/
  shared/             code used by both server and client
    Config/           ⭐ all game content & balance (edit these!)
    Fx/               ✨ effects system (Primitives, Presets, Auras)
    CreatureMath.lua  growth & income formulas
    Net.lua           list of remote events
  server/
    Main.server.lua   starts all services
    Services/         one file per game system
    Modules/          CreatureBuilder (kaiju models)
  client/
    Main.client.lua   starts controllers & UI
    Controllers/      effects, prompt visibility
    UI/               HUD, shop, toasts, hatch reveal
docs/
  ARCHITECTURE.md     how the code fits together + how to add things
  GAME_DESIGN.md      the game plan and update roadmap
```

Start with **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)**. It has step-by-step recipes for adding a kaiju, food, effect, event or a whole new system.
