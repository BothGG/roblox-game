# Architecture

How Titan Clash is organized, and **recipes** for adding things. The game plan (what and why)
is in [PLAN.md](PLAN.md).

## Folder map

```
src/
  shared/                      → ReplicatedStorage.Shared (server + client)
    Config/                    ⭐ ALL content & balance. Most changes happen here.
      GameConfig Creatures Foods Eggs Mutations Rarities Boosts
      Quests DailyRewards Codes Index Tutorial Store Sounds
    Game/                      pure game logic (no Instances) → unit tested
      Rules  CreatureMath  Battle  Progress  ConfigValidator  Tags
    Lib/                       Loader Signal Trove Log Guard Rng Format WeightedRandom
    Net/                       typed networking (Remotes.lua = every remote)
    Fx/                        effects: Primitives, Presets, Auras, Textures, RarityTag
    Types.lua                  shared type definitions
  server/                      → ServerScriptService.Server
    Main.server.lua            boot + player lifecycle
    Data/                      Schema (versions/migrations), SessionStore (session locking)
    Modules/                   CreatureBuilder FoodBuilder GameEvents Map/MapGenerator Map/Props Map/StudGround
    Services/
      Core/     DataService FxService SettingsService AdminService
      World/    MapService
      Base/     BaseService CreatureService
      Food/     FoodService StealService
      Wild/     WildService (wild titans: spawn, roam, tame)
      Battle/   BattleService
      Economy/  EggService RebirthService
      Social/   KingService SocialService LeaderboardService
      Events/   EventService
      Progress/ RewardService QuestService DailyRewardService OfflineService
                IndexService CodeService TutorialService
      Store/    StoreService
  client/                      → StarterPlayerScripts.Client
    Main.client.lua            boots controllers
    State/ClientState.lua      latest server snapshot (Signal)
    Controllers/               State UI Fx Prompt Battle BaseAnim Food Wild Tutorial Music
    UI/                        Theme Hud Window Popups Toasts BattleHud HatchReveal
      Pages/                   Eggs Food Titans Battle Quests Daily Index Store Rebirth Settings Admin
tests/                         unit tests (run without Studio)
scripts/check.sh               format + build + type check + tests
```

## Core ideas

1. **Server decides, client shows.** Clients only *ask* (remotes). The server checks types, cash,
   distance, cooldowns and battle rules before anything changes.
2. **Content is data.** Titans, foods, eggs, quests, rewards, store items and balance live in
   `shared/Config`. `ConfigValidator` checks they fit together on every server start and in tests.
3. **Rules are pure and tested.** Formulas and decisions live in `shared/Game` with no Instances.
   The server uses them to decide and the UI uses them to show the same numbers.
4. **One service per system**, found automatically by the Loader.
5. **Systems talk through events.** Gameplay fires `GameEvents` (`Fed`, `Stole`, `BattleWon`...);
   quests, tutorial and stats listen. Feeding code doesn't know quests exist.
6. **One reward path.** Every reward (quest, daily, code, Index, battle, purchase) goes through
   `RewardService:Grant` with the same reward table format.
7. **Effects are named presets**, played on clients.
8. **The map is a contract** of tags, so the generated island can be swapped for a hand-built one.

## Services and controllers

The **Loader** finds every ModuleScript ending in `Service` (server) or `Controller` (client) and
calls `Init(registry)` on all, then `Start()`, ordered by `Priority`.

```lua
local MyService = { Priority = 45 }
function MyService:Init(registry) self.Data = registry.DataService end   -- no yielding
function MyService:Start() end                                           -- loops, Net.On
function MyService:OnPlayerReady(player) end      -- server: data loaded + base assigned
function MyService:OnPlayerRemoving(player) end   -- server: before the final save
return MyService
```

| Priority | Service | Job |
|---|---|---|
| 1 | DataService | load/save (session locked), snapshots to the client |
| 2 | FxService | send effect presets to clients |
| 5 | MapService | generate/load the island, index tagged markers |
| 10 | BaseService | build bases, assign one per player, duel challenge prompt |
| 20 | FoodService | food fields, shop, storage, lock, meteors |
| 25 | CreatureService | titans: feed, grow, mutate, sell, equip fighter, income |
| 30 | KingService | biggest titan → crown + bonus |
| 35 | StealService | steal / take back / guards |
| 38 | BattleService | duels, Titan Clash, practice bots, piloting, hits, rewards |
| 40 | WildService | wild titans: spawn (rarity odds), roam, hold-to-tame with food, announcements |
| 40–60 | Egg, Rebirth, Event | eggs (with luck), rebirth, event rotation |
| 45 | RewardService | the one place rewards are given |
| 70–79 | Quest, DailyReward, Offline, Index, Code, Store, Social, Leaderboard, Settings, Tutorial | progress & social systems |
| 80 | AdminService | test commands (creator / Studio / `GameConfig.Admins`) |

## Battles (how piloting works)

1. `BattleService` teleports the fighter into the arena and builds a copy of their active titan.
2. The titan's parts are **unanchored, massless and non-colliding**, welded to the character's
   HumanoidRootPart, and the character is hidden, so the player *walks around as the titan*.
3. Walk speed comes from `Battle.Stats(creature).Speed`. The client camera zooms out to fit.
4. The client sends only `BattleAction("Attack" | "Special")`. The server checks cooldowns,
   then runs `Battle.Hits` (cone / radius tests on flat positions) and `Battle.Damage`.
5. Knockback and dashes are applied on the owning client (it controls its character's physics)
   through the `Hit` / `Launch` effect presets.
6. Bots (Practice and 1-player Clash) are anchored models moved by the server each tick.

## Data

- `DataService:Get(player)` → the save table (`Types.PlayerData`). Change it, then call
  `DataService:Changed(player)`. Changes are batched into one snapshot per frame.
- Extra UI values: `DataService:AddSnapshotHook(function(player, snapshot) ... end)`.
- **Session locking** (`Data/SessionStore.lua`) prevents two servers owning one save.
- **Changing the save format:** edit `Schema.Template()`, bump `CURRENT_VERSION`, add
  `Migrations[oldVersion]`, and add a test in `tests/specs/Data.spec.lua`.
- **Purchases** store receipt ids in the save, so a product is never granted twice.

## Networking

Every remote is declared in `shared/Net/Remotes.lua` with argument types and a rate limit:

```lua
Challenge = { Direction = "ToServer", Args = { "integer" }, RateLimit = 1 },
```

Server: `Net.On(name, handler)` (types + rate limit checked first), `Net.Fire`, `Net.FireAll`,
`Net.Notify`, `Net.Announce`. Client: `Net.Send`, `Net.Listen`.

## Reward format

```lua
{ Cash = 500, CashSeconds = 60, Food = { StarFood = 1 }, Boost = { Id = "Luck", Minutes = 10 }, Trophies = 5 }
```
`CashSeconds` = seconds of the player's income, so rewards stay useful as players progress.

## Effects (`shared/Fx`)

| Layer | What |
|---|---|
| `Primitives.lua` | Burst, Ring, Pillar, Light, FloatText, Sound, Highlight · **Glow, Shockwave, Sparks, ChargeUp, Slash, Beam, Chunks** · Shake, Flash, Vignette, Confetti, Pop, FovPunch, Bounce, Knockback |
| `Presets.lua` | Feed, LevelUp, Mutation, Spawn, Income, **WildSpawn, TameStart, TameSuccess, TameFail**, Pickup, Steal*, Deposit, GuardKnock, Sell, Meteor*, NewKing, Rebirth, HatchReveal, **TitanAttack, Hit, KO, Victory, Launch**, Reward, Lock, Poof |
| `Auras.lua` | effects that stay on titans: rarity tiers (ring → sparkles → light → sky beam → outline → vortex) and mutation particles |
| `RarityTag.lua` | shiny rarity badge on name tags (moving shine / rainbow) |
| `Textures.lua` | particle textures (built-in Roblox ones by default; swap for Creator Store ones) |

**The recipe every preset follows:** anticipation (ChargeUp) → impact (Glow + Shockwave + Sparks)
→ aftermath (Burst / smoke / Chunks / FloatText) → only for you: Shake / FovPunch / Flash.
`Lighting` has Bloom with a low threshold (MapService), so Neon parts and effects glow.

**Make effects look even better:** the cheapest big upgrade is swapping `Textures.lua` for nicer
textures from the Creator Store (search "sparkle", "shockwave", "slash"). Every effect uses them.

New effect: add `function Presets.MyEffect(p, P) ... end`, then
`FxService:PlayAll("MyEffect", { Position = pos, Owner = player.UserId })`.

---

## Recipes

| I want to add... | Do this |
|---|---|
| **A titan** | `Config/Creatures.lua` (Rarity, BaseIncome, Style, colors, Diet, **Stats**) + add it to an egg in `Eggs.lua`. Custom model: `ServerStorage/CreatureModels/<Id>` (PrimaryPart at the feet, facing -Z; parts can have `Paint = "Body"/"Accent"`). |
| **A food** | `Config/Foods.lua` + `Foods.Order`. `SpawnWeight > 0` grows it in the fields; `Price` sells it in the shop. |
| **A mutation** | `Config/Mutations.lua` (+ `StatMult`), then use it from a food or `HatchPool`. |
| **A quest** | One line in `Config/Quests.lua` (`Event` must be a GameEvents name). |
| **A code** | One line in `Config/Codes.lua` (UPPERCASE key). |
| **A daily reward / Index milestone** | Edit `Config/DailyRewards.lua` / `Config/Index.lua`. |
| **A store item** | `Config/Store.lua` (+ its Id from the Creator Dashboard). New pass perks go in `Rules.Perks`. |
| **A special move** | `Battle.Specials` in `shared/Game/Battle.lua` + a branch in `Presets.TitanAttack`. |
| **An event** | A function in `EVENTS` (`Services/Events/EventService.lua`), add it to `ROTATION`, and a name in `Hud.lua`. |
| **A game event** (for quests) | `GameEvents.Fire(player, "Name", payload)` + add `Name` to `ConfigValidator.Events`. |
| **A remote** | `Net/Remotes.lua` with `Args` + `RateLimit`, then `Net.On` / `Net.Send`. |
| **A menu page** | `client/UI/Pages/<Name>.lua` (`Build`, `Update`), add it to `PAGES` in `UIController` and a button in `Hud.lua`'s `MENU`. |
| **A whole system** | Service in `server/Services/<Domain>/`, saved fields in `Schema` (+ migration + test), rules in `shared/Game` (+ tests), UI page. |

## Tests & checks

- `python3 tests/run.py` runs `tests/specs/*.spec.lua` in plain Luau with a small fake Roblox
  (instances, require, Color3/Enum, an in-memory DataStore).
- `scripts/check.sh` = StyLua check + Rojo build + luau-lsp type check + tests (CI runs the same).
