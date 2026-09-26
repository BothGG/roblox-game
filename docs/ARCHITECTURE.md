# Architecture

Kaiju Keepers is built to grow for months: many systems, lots of content, several people
working on it. This doc explains how it's organized and how to add things.

## Folder map

```
src/
  shared/                      → ReplicatedStorage.Shared (server + client)
    Config/                    ⭐ ALL content & balance. Most changes happen here.
      GameConfig  Biomes  Creatures  Foods  Eggs  Mutations  Rarities  Sounds
    Game/                      pure game logic (no Instances) → unit tested
      Rules  CreatureMath  ConfigValidator  Zones  Tags
    Lib/                       reusable libraries
      Loader  Signal  Trove  Log  Guard  Format  WeightedRandom
    Net/                       typed networking (Remotes.lua = every remote)
    Fx/                        effects: Primitives, Presets, Auras, Textures
    Types.lua                  shared type definitions
  server/                      → ServerScriptService.Server
    Main.server.lua            boot + player lifecycle
    Data/                      Schema (versions/migrations), SessionStore (session locking)
    Services/                  one service per system, grouped by domain
      Core/    DataService, FxService
      World/   MapService, BiomeService
      Zoo/     ZooService, CreatureService
      Food/    FoodService, StealService
      Wild/    WildService
      Economy/ EggService, RebirthService
      Social/  KingService
      Events/  EventService
    Modules/                   builders used by services
      CreatureBuilder  FoodBuilder  Map/MapGenerator  Map/Props
  client/                      → StarterPlayerScripts.Client
    Main.client.lua            boots controllers
    State/ClientState.lua      latest server snapshot + current biome (Signals)
    Controllers/               State, UI, Fx, Prompt, Biome, Wild, ZooAnim, Food
    UI/                        Theme, Hud, Shop, Toasts, HatchReveal
tests/                         unit tests (run without Studio)
scripts/check.sh               format + build + type check + tests
```

## Core ideas

1. **Server decides, client shows.** Clients only *ask* through remotes. The server checks
   everything (types, cash, distance, cooldowns, unlocks) before changing data.
2. **Content is data.** Kaiju, foods, biomes, eggs and balance live in `shared/Config`.
   `ConfigValidator` checks they fit together on every server start and in tests.
3. **Rules are pure and tested.** Formulas and decisions (XP, unlocks, food picking) live in
   `shared/Game/Rules.lua` and `CreatureMath.lua`, with no Instances, so they're unit tested
   and shared by the server (decides) and UI (displays the same numbers).
4. **One service per system**, found automatically by the Loader.
5. **Effects are named presets.** Gameplay code says `FxService:PlayAll("LevelUp", ...)`,
   and the client decides how it looks.
6. **The map is a contract.** Gameplay finds the world through **tags** (`Game/Tags.lua`),
   so the generated map can be swapped for a hand-built one (see MAP_GUIDE.md).

## Services (server) and controllers (client)

The **Loader** (`Lib/Loader.lua`) finds every ModuleScript whose name ends in `Service`
(server) or `Controller` (client), then calls `Init(registry)` on all of them, then
`Start()`, ordered by `Priority` (lower first).

```lua
local MyService = { Priority = 45 }

function MyService:Init(registry)        -- grab other services. Don't yield here.
    self.Data = registry.DataService
end

function MyService:Start() end           -- loops, remotes (Net.On), connections

function MyService:OnPlayerReady(player) end     -- server: data loaded + zoo assigned
function MyService:OnPlayerRemoving(player) end  -- server: before the final save

return MyService
```

Just create the file in `server/Services/<Domain>/` and it runs. No registration needed.

| Priority | Service | Job |
|---|---|---|
| 1 | DataService | load/save (session locked), snapshots to the client |
| 2 | FxService | send effect presets to clients |
| 5 | MapService | generate/load the map, index tagged markers, biome zones |
| 10 | ZooService | build zoos, assign one per player |
| 15 | BiomeService | unlock gates, keep players out of locked biomes |
| 20 | FoodService | food growing in biomes, shop, storage, lock, meteors |
| 25 | CreatureService | zoo kaiju: feed, grow, mutate, sell, income |
| 30 | KingService | biggest kaiju → crown + bonus |
| 35 | StealService | steal / take back / guards |
| 40 | WildService | wild kaiju roaming + catching |
| 50 | EggService | eggs + starter kaiju |
| 55 | RebirthService | rebirth |
| 60 | EventService | Meteor Feast, Blood Moon |

## Data

- `DataService:Get(player)` → the save table (`Types.PlayerData`). Change it, then call
  `DataService:Changed(player)`. Changes are batched into one snapshot per frame.
- Extra UI values that aren't saved: `DataService:AddSnapshotHook(function(player, snapshot) ... end)`.
- **Session locking** (`Data/SessionStore.lua`): only one server can own a save. A second server
  waits, then takes over an abandoned lock. If a server loses its lock it stops saving and kicks
  the player, which prevents duplication and rollback exploits.
- **Changing the save format**: edit `Schema.Template()`, bump `CURRENT_VERSION`, add
  `Migrations[oldVersion]`, and add a test in `tests/specs/Data.spec.lua`.

## Networking

Every remote is declared in `shared/Net/Remotes.lua`:

```lua
BuyEgg = { Direction = "ToServer", Args = { "string" }, RateLimit = 0.4 },
```

- Server: `Net.On("BuyEgg", function(player, eggId) ... end)`. Argument types and rate limits
  are enforced **before** your handler runs (NaN/inf, wrong types and extra args are rejected).
- Still validate meaning yourself: `Guard.IsConfigKey(Eggs, eggId)`, cash, distance...
- Server → client: `Net.Fire(player, name, ...)`, `Net.FireAll`, `Net.Notify`, `Net.Announce`.
- Client: `Net.Send(name, ...)`, `Net.Listen(name, fn)`.
- Cosmetic remotes (`Fx`) are **unreliable**, so they're cheap and fine to drop under load.

## Effects (`shared/Fx`)

| Layer | What |
|---|---|
| `Primitives.lua` | building blocks: Burst, Ring, Pillar, Light, FloatText, Sound, Highlight, Shake, Flash, Vignette, Confetti, Pop, Bounce, Knockback |
| `Presets.lua` | named effects: Feed, LevelUp, Mutation, Spawn, Pickup, Steal*, Deposit, GuardKnock, Sell, MeteorImpact, NewKing, Rebirth, HatchReveal, Unlock, RareSpawn, CatchSuccess, CatchFail, Poof, Lock |
| `Auras.lua` | effects that stay on kaiju/food (embers, sparkles, smoke, glow) |
| `Textures.lua`, `Config/Sounds.lua` | swap images/sounds here to upgrade every effect |

New effect: add `function Presets.MyEffect(p, P) ... end`, then
`FxService:PlayAll("MyEffect", { Position = pos, Owner = player.UserId })`.
Use `P.IsMe(p.Owner)` for screen effects that only the involved player should see.

## Client animation pattern

Moving things smoothly for everyone without heavy networking:
- **Wild kaiju**: the server writes `MoveFrom/MoveTo/MoveStart/MoveDuration` attributes and
  snaps the model at the end; `WildController` interpolates every frame.
- **Zoo kaiju**: the server sets a `Home` attribute; `ZooAnimController` adds breathing/sway and
  a bounce when fed.
- **Food**: `FoodController` spins/bobs anything tagged `FoodPickup`.

---

## Recipes

### New kaiju
1. `Config/Creatures.lua`: add an entry (rarity, income, style, colors, `Diet`, `Traits`).
2. Make it obtainable: add it to a biome's `Wild` list (`Config/Biomes.lua`) and/or an egg.
3. `scripts/check.sh` (the validator catches typos).
4. Optional custom model: `ServerStorage/CreatureModels/<Id>` (PrimaryPart at the feet, facing -Z;
   parts can have attribute `Paint = "Body" | "Accent"` for mutation colors).

### New food
`Config/Foods.lua`: add an entry **and** add it to `Foods.Order`. Put it in a biome's `Foods` list
or give it a `Price`. Optional model: `ServerStorage/FoodModels/<Id>` with a PrimaryPart named `Hitbox`.

### New biome
1. `Config/Biomes.lua`: add an entry + add it to `Biomes.Order`.
2. Generated map: optionally add terrain in `MapGenerator` (`BIOME_TERRAIN.<Id>`) and props.
   Hand-built map: add the tagged markers (see MAP_GUIDE.md).

### New mutation / egg / rarity
Add to the config file (and its `Order` list if it has one). The validator tells you what's missing.

### New remote
Add to `Net/Remotes.lua` with `Args` and `RateLimit`, then use `Net.On` / `Net.Send`.

### New system (e.g. Daily Rewards)
1. `server/Services/Rewards/DailyRewardService.lua` using the lifecycle above.
2. Saved fields → `Data/Schema.lua` (+ migration + test).
3. Rules/formulas → `shared/Game/` (+ tests in `tests/specs/`).
4. UI → a module in `client/UI/`, started from `UIController`, reading `ClientState`.

### New server event
Add a function to `EVENTS` in `Services/Events/EventService.lua` and a display name in `Hud.lua`.

## Tests & checks

- `python3 tests/run.py` runs `tests/specs/*.spec.lua` in plain Luau with a small fake Roblox
  (instances, require, Color3/Enum, an in-memory DataStore). Great for rules, configs and data.
- `scripts/check.sh` = StyLua format check + Rojo build + luau-lsp type check + tests.
- CI (`.github/workflows/ci.yml`) runs `scripts/check.sh` on every push and uploads the place file.
