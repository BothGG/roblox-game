# Architecture

How Kaiju Keepers is put together, and **recipes** for adding things.

## The big picture

```
            ┌──────────────────── shared (ReplicatedStorage.Shared) ───────────────────┐
            │ Config/*  (content & balance)   CreatureMath   Net   Fx/*   Util/*       │
            └───────────────▲─────────────────────────────────────────▲────────────────┘
                            │ require                                 │ require
┌─────────── server (ServerScriptService.Server) ───┐   ┌──── client (StarterPlayerScripts.Client) ────┐
│ Main.server.lua → starts Services in order        │   │ Main.client.lua                               │
│  DataService      save/load + snapshot to client ─┼──►│  Hud / Shop  (DataUpdate snapshot)            │
│  FxService        "play effect X" ────────────────┼──►│  FxController → Fx.Play(preset)               │
│  WorldService     map, plots, lighting            │   │  PromptController (who sees which prompt)     │
│  CreatureService  feed, grow, sell, income        │   │  Toasts (Notify / Announce)                   │
│  FoodService      wild food, shop, storage, lock  │◄──┼─ BuyEgg, BuyFood, SelectFood, LockStorage,    │
│  StealService     steal / take back / guards      │   │  Rebirth (client → server requests)           │
│  KingService      biggest kaiju, crown            │   │  HatchReveal (Hatched)                        │
│  EggService       buy + hatch eggs                │   └───────────────────────────────────────────────┘
│  RebirthService   reset for bonuses               │
│  EventService     Meteor Feast, Blood Moon        │
└───────────────────────────────────────────────────┘
```

### Rules the code follows

1. **Server decides, client shows.** The client only *asks* (remotes like `BuyEgg`).
   The server checks everything (cash, slots, distance, cooldowns) and changes the data.
2. **Content is data.** Kaiju, foods, eggs, mutations and balance numbers live in `shared/Config`.
   Adding content almost never needs new code.
3. **One service per system.** Each service owns one job and talks to others via the
   `services` table passed into `Init`.
4. **Effects are named presets.** Gameplay code never builds particles itself. It calls
   `FxService:PlayAll("LevelUp", {...})` and the client plays the preset.

### Service lifecycle

```lua
local MyService = {}

function MyService:Init(services)   -- get other services here. Don't yield.
    self.Data = services.DataService
end

function MyService:Start()          -- start loops, connect remotes
end

function MyService:OnPlayerReady(player)     -- optional: data + plot are ready
end

function MyService:OnPlayerRemoving(player)  -- optional: clean up
end

return MyService
```

Register it by adding its name to `ORDER` in `src/server/Main.server.lua`.

### Data flow

- `DataService:Get(player)` returns the player's saved table. Change it directly, then call
  `DataService:Changed(player)`. That sends one batched **snapshot** to the client's UI.
- Need extra UI info that isn't saved? `DataService:AddSnapshotHook(function(player, snapshot) ... end)`.
- New saved field? Add it to `newData()` in `DataService.lua`. Old saves get the default automatically.

---

## ✨ The effects system (`src/shared/Fx`)

Three layers:

| Layer | File | What it is |
|---|---|---|
| **Primitives** | `Fx/Primitives.lua` | Building blocks: `Burst`, `Ring`, `Pillar`, `Light`, `FloatText`, `Sound`, `Highlight`, `Shake`, `Flash`, `Vignette`, `Confetti`, `Pop`, `Knockback` |
| **Presets** | `Fx/Presets.lua` | Named effects made of primitives: `Feed`, `LevelUp`, `Mutation`, `Spawn`, `Pickup`, `StealStart`, `StealAlert`, `Deposit`, `GuardKnock`, `TakeBack`, `Sell`, `MeteorImpact`, `MeteorWarning`, `NewKing`, `Rebirth`, `HatchReveal`, `Lock` |
| **Auras** | `Fx/Auras.lua` | Effects that *stay* on a kaiju (mutation embers, sparkles, smoke, glow) |

Plus two config files that change how everything looks and sounds:
`Fx/Textures.lua` (particle images) and `Config/Sounds.lua` (sound ids).

### Playing an effect

```lua
-- server
FxService:PlayAll("LevelUp", { Position = pos, Level = 10, Owner = player.UserId })
FxService:PlayFor(player, "StealAlert", {})
FxService:PlayNear(pos, 300, "MeteorImpact", { Position = pos, Color = color })

-- client (UI code etc.)
Fx.Play("HatchReveal", { Color = color, RarityOrder = 4 })
Fx.Primitives.Pop(someButton)
```

`Owner` / `Target` are user ids. Presets use `P.IsMe(p.Owner)` to add screen effects
(shake, flash, big text) only for the player it's about.

### Recipe: make a new effect

1. Open `src/shared/Fx/Presets.lua` and add:
   ```lua
   function Presets.Evolve(p, P)
       if P.Distance(p.Position) > FAR then return end   -- skip if far away
       P.Pillar(p.Position, { Color = p.Color, Height = 100 })
       P.Ring(p.Position, { Color = p.Color, Radius = 20 })
       P.Burst(p.Position, { Color = p.Color, Count = 50, Speed = 40 })
       if P.IsMe(p.Owner) then
           P.Shake(0.4, 0.5)
           P.FloatText(p.Position, "EVOLVED!", { Color = p.Color, Size = 4 })
       end
   end
   ```
2. Play it from the server: `FxService:PlayAll("Evolve", { Position = pos, Color = c, Owner = player.UserId })`.

### Recipe: make a new primitive

Add a function to `Primitives.lua`. Put temporary world parts in the `LocalFx` folder
(use `holderPart(position)`) and clean them up with `Debris:AddItem`.

### Recipe: make effects look better

- Swap the particle images in `Fx/Textures.lua` for nicer ones from the Creator Store
  (search "particle texture", then use `rbxassetid://ID`).
- Swap the sounds in `Config/Sounds.lua`.
- Every preset updates automatically.

---

## Recipes: adding content

### New kaiju
1. `Config/Creatures.lua`: copy an entry, change the key/name/colors/income/traits.
2. `Config/Eggs.lua`: add `{ Creature = "YourId", Weight = 5 }` to an egg.

### Custom 3D model for a kaiju
1. Build the model in Studio. Set its **PrimaryPart** at the **feet**, facing **-Z** (forward).
2. Give parts an attribute `Paint` = `"Body"` or `"Accent"` so mutations recolor them (optional).
3. Put it in `ServerStorage/CreatureModels/` named exactly like the kaiju Id (e.g. `Rex`).
   It's used automatically instead of the placeholder.

### New food
`Config/Foods.lua`: add an entry **and** add its id to `Foods.Order`.

### New mutation
1. `Config/Mutations.lua`: add an entry (color, material, income multiplier, `Aura`).
2. Make a food use it (`Mutation = { Id = "YourMutation", Chance = 0.05 }`), or add it to `HatchPool`.

### New egg
`Config/Eggs.lua`: add an entry **and** add its id to `Eggs.Order`. It shows up in the shop.

### New server event
`Services/EventService.lua`: add a function to `EVENTS`. Announce it, do the thing, wait, clean up.
Also add a display name to `EVENT_NAMES` in `client/UI/Hud.lua`.

### New remote (client ↔ server message)
Add the name to `REMOTES` in `shared/Net.lua`, then use `Net.Get("Name")`.
**Always validate on the server** (types, cash, cooldown with `Net.Throttle`).

### New system (e.g. Daily Rewards, Trading, Clans)
1. Create `src/server/Services/DailyRewardService.lua` using the lifecycle above.
2. Add it to `ORDER` in `Main.server.lua`.
3. Store its data in `newData()`, expose UI info with a snapshot hook.
4. Add a UI module in `src/client/UI/` and start it in `Main.client.lua`.

---

## Checking the code

```bash
rojo build -o build/KaijuKeepers.rbxlx         # builds the place (fails on broken project files)
rojo sourcemap default.project.json -o sourcemap.json
luau-lsp analyze --definitions=globalTypes.d.luau --sourcemap=sourcemap.json src   # type check
```

GitHub Actions runs both on every push (`.github/workflows/ci.yml`) and uploads the built place file.
