# Titan Clash: ARK-Style Survival Roadmap

> Plan by @Jign (Sep 27, 2026). **Vision:** a 6-player survival island where you tame, ride
> and breed titans, and every egg can be stolen. The creature depth of ARK plus the
> steal-and-run tension of Steal an Egg, in our cute Roblox style.

**Pillars:** tame and ride · eggs are the prize · survive and build · grow huge (size up to x100,000).
**Core loop:** ride out → tame or steal → run home with eggs → reinvest into the next trip.
**Out of scope:** ARK-level realistic graphics (stylized models + strong effects instead).

Each phase ships a playable game. Status: ✅ done · 🟡 partly · ⬜ not started.

> **Note on the starting point.** The plan was written for a version with 50 titans, 8
> mutations, an egg conveyor and schema v4. The code in this repo had 13 titans, 5 mutations,
> eggs from a menu and schema v3, so Phase 0 moves it to **schema v4** (the plan's "v5") and
> the missing titans/mutations are added through the per-titan tasks below.

---

## Phase 0: Foundation ✅

### Server and bases
- ✅ `Plots.Count = 6` (set **Max Players = 6** in Game Settings; see LAUNCH.md)
- ✅ 6 plots re-spaced on a bigger island (`IslandRadius` 330 → 450, `RingRadius` 310)
- ✅ Base size 74 → **160** studs per side
- ✅ Pens 8 → **24** (6 × 4 grid), unlocked by rebirths, passes and **base upgrades**
- ✅ Upgrade board at every base (`UpgradeService`): Pens, Storage, Incubators (Phase 2)
- 🟡 Base lock: our lock is the storage **bubble** (works at any base size); lock *walls* come with Phase 4 building
- ✅ Signs, crate, challenge point and board placed for the new size

### Save data (schema v4)
- ✅ Titans: `Size`, `Tamed`, `Saddle`, `Hunger`
- ✅ `Inventory` (Resources, Items), `Structures`, `Upgrades`
- ✅ Migration test v3 → v4 keeps titans, food and cash
- ✅ Save caps (`GameConfig.Data.Limits`, `Schema.Trim` before every save) + a test that a
  maxed-out save stays far below 4 MB

### Huge numbers
- ✅ Size multiplier x1 … x100,000 (`Config/Sizes.lua`, `CreatureMath.ClampSize`)
- ✅ Income = base × level × **size** × mutation (× trait)
- ✅ Model scale grows with log(size) and caps at **25×** (`CreatureMath.VisualScale`)
- ✅ Number format K, M, B, T … up to Vg (10^63), then scientific
- ✅ Size tiers: Tiny x1, Normal x3, Big x10, Huge x100, Giant x1K, Colossal x10K, Titanic x50K, Mythical x100K
- ✅ Unit tests for size math, caps, labels, formatting, upgrades

### Logging and admin
- ✅ Every service logs with its own tag (`Log.new("UpgradeService")` → `[UpgradeService]`)
- ✅ Admin commands: `give <Titan> [Mutation] [Size]`, `size <n>`, `res <Resource> <n>`, `upgrade <Id>`
  (eggs as items arrive in Phase 2)

---

## Phase 1: Living island ✅ (21 done · 3 partly · 2 later)

### Wild titans (`WildService`, `shared/Game/WildBrain.lua`)
- ✅ Up to **20** wild titans per server
- 🟡 Spawn tables per biome: rarity-weighted pool for now; per-biome tables come with the 8 biomes (map phase)
- ✅ States: idle, graze, wander, flee, chase, attack, return, asleep
- ✅ Passive titans flee when hit; aggressive ones chase players in range and attack
- ✅ Packs of 3–5 for pack titans (Gloop, Shellback, Pincher); the pack reacts together
- ✅ Name tag with size tier, temper, HP bar, torpor bar, taming bar
- ✅ Spawn near players, despawn when nobody is near for 40 s

### Knock-out taming (`ToolService`, `TameService`, `shared/Game/Taming.lua`)
- ✅ Torpor meter: **Wooden Club** and **Tranq Blowgun** add torpor; it drains over time
- ✅ Full torpor → asleep for 60 s
- ✅ Feed it (hold E): favorite food counts double; food needed grows with rarity and size
- ✅ Hitting it while asleep lowers effectiveness (and the tamed level)
- ✅ Every player has their own taming bar: first to fill it gets the titan (tame stealing)
- ✅ Tamed titan follows you (if a slot is free) or goes to your base
- ✅ Effects: knocked-out stars, 💤 Zzz, hearts while feeding, taming bar, success burst

### Riding (`RideService`, `RideController`, `RideHud`, `shared/Game/Riding.lua`)
- 🟡 Mount/dismount any owned titan (R at the pen or follower, or the Titans menu). Saddles are
  required only after crafting exists (`Riding.RequireSaddle = false` until Phase 3)
- ✅ Riding camera zooms out for the titan's size
- 🟡 Runners sprint (Shift), flyers fly (V, Space up, Ctrl down), blobs bounce; swimmers diving ⬜ (needs deep-water biomes)
- ✅ Stamina for sprinting and flying
- ✅ Attack (click) and style special (Q) hit wild titans
- ✅ Phone controls: big buttons on the ride panel
- ⬜ Carry an egg on the saddle (eggs as items arrive in Phase 2)
- ✅ Wild titans hit your mount; at 0 HP you're knocked off (30 s rest)

### Followers (`FollowerService`)
- ✅ Up to 3 titans follow you and defend you (they attack whatever attacks you or what you hit)
- ✅ Commands: Follow, Stay, Attack, Guard base (go home); per-titan Follow / Send home in the Titans menu
- ✅ Teleport to you when stuck far away

### Logging and tests
- ✅ `WildService`, `ToolService`, `TameService`, `RideService`, `FollowerService` log with their tags
- ✅ Unit tests for the wild brain, torpor, taming math, stamina and ride stats (`tests/specs/Phase1.spec.lua`)

## Phase 2: Eggs and breeding ⬜
Breeding pen (2 of a species) · timer by rarity (2 min … 2 h) · stat inheritance + small bonus ·
5 % mutation chance (more with mutated parents) · egg size from parents with rare tier jumps ·
cooldowns. Wild nests per biome with a guardian, refill timers, rarer biomes = bigger eggs.
Egg size tiers x1 … x100K (slower hatch/carry, bigger glow, sky beam for Titanic+, server
announcement for Colossal+). Incubators (upgradeable; board slot already exists). Hatch
cinematic scales with tier; hatched titan keeps the size. Egg stealing: grab from incubators,
knock carriers to drop, dropped eggs last 10 s, carrier trail + map marker, owner alarm +
Take Back (reuse). Fusion: 3 of a titan → next size tier.

## Phase 3: Survival and crafting ⬜
Player health + slow hunger · food refills · respawn at base (carried eggs/resources drop) ·
no thirst/temperature at launch. Titan hunger while riding/fighting; hungry = slower, less
income; feeding trough. Resource nodes (wood, stone, berries/fiber, metal, crystal), tools and
gatherer titans, shared respawning nodes. 30-slot backpack, base chest (raidable), drag & drop /
tap UI. Crafting (tools, weapons incl. tranq arrows, saddles per style, food, traps) at stations
(workbench, campfire, smithy), recipes by player level. Player XP from taming, gathering,
crafting, hatching, stealing.

## Phase 4: Build and raid ⬜
Grid build mode inside your plot (foundation, wall, doorway, door, gate, ramp, roof, fence) in
wood/stone/metal · preview + rotate · 50 % refund demolish · piece limit (`Limits.Structures`) and
save/rebuild from `Structures`. Defenses: owner/friend doors, turrets with ammo, guard titans on
posts, spike walls, base lock stays. Raiding: structure health, big titans hit walls harder,
raid window + offline protection, steal eggs/chest resources/unsaddled titans, raid alarm,
free slow repair. Fairness: 30 min new-player protection, 1 raid per base per 20 min, 20 %
loot cap, raid log.

---

## Titans (one task each: model, ride setup, wild biome, ability, tame food, Index card)
Today's 13: Gloop, Rex, Shellback, Pincher, Rhinobug, Kong, Frostbite, Kraken, Drake, Tuskar,
Phoenix, Hydra, Voidmaw. To add (37): Mudpup, Pebblit, Snapjaw, Bubbloo, Chompy, Sproutle,
Fuzzmo, Beaklet · Thornback, Zappik, Tidefin, Stompo, Glimmoth, Coralisk, Puffcap, Nightflap ·
Magmaw, Cryoclaw, Thunderhoof, Dunewyrm, Mechasaur, Toxitail, Skyray · Stormwing, Glacierra,
Infernox, Leviathorn, Colossaur, Thornwyrm, Goldmane · Eclipsar, Behemoth, Chronodon, Nebulon,
Cerberex · Omegazor, Aetherion. (Biome, role and ability per titan: see the original plan.)

## Biomes and map ⬜
8 biomes from safe to dangerous (Beach & Reef · Jungle · Plains & Savanna (Lv 5) · Mountains &
Snow (Lv 10) · Desert & Ruins (Lv 15) · Volcano (Lv 25) · Ancient Valley (Lv 30) · Sky Isles &
Cosmic Rift (flyer + Lv 40)). Island radius → ~900, one zone module per biome, border signs,
terrain/props/resources/nests/wild zones per biome, sky isles for flyers, cosmic rift portal,
ambient sound, **StreamingEnabled** tested on phones, minimap.

## UI, effects, audio ⬜
Survival HUD (health, hunger, stamina while riding), riding HUD, taming UI, inventory/crafting,
build toolbar, titan screen (size tier, needs, commands), breeding screen, map; phone-size tests.
Effects: upload VFX textures into `Fx/Textures.lua`, knock-out stars, sleep bubbles, tame burst,
mount dust, size-tier auras (Giant+), breeding hearts, structure hit/crack/collapse, turret
tracers, biome weather. Audio: roar + steps per style (pitched by size), biome music + chase
track, UI sounds.

## Retention and monetization ⬜
Offline hatching/breeding · quests for taming/riding/gathering/breeding/raiding · weekly
Omegazor boss · events (Egg Rush, Blood Moon, Meteor Shower, Titanic Egg Hunt) · Index rewards
per biome · tribes · season pass (cosmetics). Robux: VIP, 2× income, incubators, follower slot,
auto-gather titan; cash packs, instant hatch, taming food, 1 h raid shield; cosmetics. **Never
sell raid power.**

## Testing (every phase)
`scripts/check.sh` (format, build, type check, unit tests) · unit tests for new pure logic ·
Studio 1-player full loop · 6-player test (Test tab) · phone test · no red errors in 15 min ·
save/leave/rejoin · commit + push.
