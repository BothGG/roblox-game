# Titan Clash: Full Game Plan (v1.0)

> **One sentence:** **Find** wild titans, grab and **steal food** to tame and **feed** them, then
> **pilot your titan into the arena** and fight other players' titans, like a monster movie.

The three things that matter most: **1) find titans · 2) find food & feed · 3) compete.**

This is the master plan. Other docs go deeper: [ARCHITECTURE.md](ARCHITECTURE.md) (code),
[MAP_GUIDE.md](MAP_GUIDE.md) (map contract), [LAUNCH.md](LAUNCH.md) (publishing checklist).

---

## 1. Pillars

1. **Find titans:** wild titans roam the fields. Rare ones shine a light beam into the sky and the
   whole server races to tame them first.
2. **Steal & feed:** food is scarce; you need it to tame titans and to grow them. The fastest way
   to get it is taking it from other bases.
3. **Big = strong (and visible):** every level makes your titan physically bigger and stronger.
4. **Fight like the movies:** you *become* your titan in the arena: walk, punch, special moves.
5. **Effects sell it:** every action has a layered effect (charge-up → flash + shockwave + sparks →
   aftermath) and rare titans glow (ground ring, sparkles, sky beam). See §12.
6. **Server drama:** 6–12 players on one island, so everyone sees who steals, who wins, who's King.

## 2. Server & map

- **Max players: 12** (`GameConfig.Plots.Count = 12`; set Max Players to 12 in Game Settings.
  Lower it to 6 by changing the one number.)
- **Titan Island** (generated from code; replaceable with a hand-built map via tags):

```
                 ocean
      [base]  [base]  [base]  [base]
   [base]    🌾 food fields 🌾    [base]
  [base]   🌾  ┌──────────┐  🌾    [base]
  [base]   🌾  │  ARENA   │  🌾    [base]    12 bases around the island
   [base]   🌾 │ (stands) │ 🌾    [base]    food fields in the ring
      [base]   └──────────┘   [base]         arena in the middle
             [base]   [base]
```

| Area | What happens there |
|---|---|
| **Base** (1 per player) | Your titans stand in pens. Food storage crate (can be robbed). Lock bubble. Name sign. |
| **Food fields** | Food grows at spawn points and regrows. **Wild titans roam here.** Meteors land here during Meteor Feast. |
| **Arena** | Duels and Titan Clash. Stands around it for spectators. Leaderboards at the entrances. |

## 3. Core loop

```
 FIND a wild titan in the fields ─► hold E, feed it food ─► TAMED (joins your base)
                                                   ▲
 grab food in the fields ─┐                        │ (food is used for both)
 steal food from bases ───┼─► feed titans ─► level up (bigger + stronger)
 win food in battles ─────┘         │
                                    ▼
             pick your best titan ─► DUEL / TITAN CLASH ─► trophies, cash, food
                                    │
             earn cash (titans earn per second) ─► eggs (new titans), rebirth
```

## 4. Titans

- **Get them:** starter titan (Rex), **taming wild titans** (main way), eggs (Basic / Great / Titan
  Egg), random mutations.
- **Wild titans** (`Services/Wild/WildService.lua`): up to 8 roam the fields at once. Odds, tame
  time, food cost and success chance per rarity are in `Config/Rarities.lua`:

| Rarity | Spawn weight | Hold time | Food | Chance |
|---|---|---|---|---|
| Common | 60 | 1 s | 1 | 100 % |
| Rare | 26 | 2 s | 2 | 85 % |
| Epic | 10 | 3 s | 4 | 70 % |
| Legendary | 3 | 4.5 s | 6 | 55 % |
| Mythic | 0.8 | 6 s | 10 | 40 % |
| Secret | 0.2 | 8 s | 15 | 30 % |

  Favorite food gives +20 % chance. If it fails, the food is eaten and the titan runs away.
  Legendary+ and mutated wild titans are announced to the server with a sky beam.
  **Wild Rush** event: rare ones 3× more likely and a crowd of titans appears.
- **Pens:** 3 at start, +1 per rebirth, +2 with the Extra Pens pass, max 8.
- **Active titan:** the one you fight with. Choose it from the Titans menu or the "Choose" prompt.
- **Stats** (pure formulas in `shared/Game/Battle.lua`, tested):

| Stat | Formula |
|---|---|
| Max HP | `species.HP × (1 + (level−1) × 0.12) × mutation.StatMult` |
| Attack | `species.Attack × (1 + (level−1) × 0.10) × mutation.StatMult` |
| Speed | `16 × species.Speed × (1 + min(scale, 8) × 0.04)`, capped at 34 |
| Size | `1 + (level−1) × 0.12` (Lv.100 ≈ 13× bigger) |

- **Species abilities** (by body style):

| Style | Special (Q / button) | Effect |
|---|---|---|
| Biped (Rex, Kong, Frostbite, Voidmaw) | **Ground Slam** | Hits everyone around you, ×1.6 damage |
| Quad (Shellback, Rhinobug, Pincher, Tuskar, Hydra) | **Charge** | Dash forward, ×1.8 damage to whoever you hit |
| Blob (Gloop, Kraken) | **Bounce** | Jump and slam down, ×1.7 damage around you |
| Winged (Drake, Phoenix) | **Fire Breath** | Long cone in front, ×1.4 damage |

- Every titan also has a basic **Attack** (click / tap / F): short cone in front, ×1 damage.

## 5. Food & stealing

- 9 foods; each has Growth XP, rarity, look, and some have mutation chances.
- Titans have **favorite foods** (×2 XP).
- **Stealing:** hold E on another base's crate → carry the food above your head, walk slower →
  reach your own crate to keep it. The owner can **Take Back**; guard titans knock thieves away.
- **Lock:** protects your crate for 30 s (90 s cooldown). New players get 60 s of protection.

## 6. Battles

### Duel (1v1)
1. Open **Battle** menu → pick a player → **Challenge** (or use their base's sign prompt).
2. They get a popup: **Accept / Decline** (15 s).
3. Both are teleported into the arena **as their active titan**. 3-2-1 countdown.
4. Fight until one titan's HP hits 0, or 90 s (then the higher HP % wins).
5. **Rewards:** winner +10 🏆 trophies, cash (60 s of their income + $500), and **15 % of the
   loser's food** ("winner eats"). Loser −5 🏆 (never below 0). Nobody loses a titan.

### Titan Clash (free-for-all event)
- Every ~8 minutes (EventService). 20 s join window; everyone who joins fights at once.
- Last titan standing (or highest HP % at 90 s) wins: +25 🏆, big cash, a Star Food.
- Everyone who took part gets a participation reward.

### Rules
- One arena match at a time; the Battle menu shows "Arena busy".
- Leaving the arena, dying, or leaving the game = forfeit.
- Non-fighters inside the arena during a match are moved to the stands.
- All damage is decided by the server (cooldowns, range, cone checks). Clients only send
  "Attack" / "Special" presses.

## 7. Progression

| Loop | Length | Reward |
|---|---|---|
| Feed → level up | seconds | size, stats, income |
| Mutations | minutes–hours | ×2–×10 income, +15–60 % stats, auras |
| Eggs & collection (Index) | hours–weeks | new titans, Index milestone rewards |
| Trophies | ongoing | leaderboard, 🏅 Champion (most trophies on the server) |
| Rebirth | days | +50 % income, +1 pen, +storage (keeps trophies, Index) |

## 8. Retention systems

| System | How it works |
|---|---|
| **Tutorial** | 6 steps with an arrow + hint bar: feed → grab food → hatch egg → reach Lv.5 → choose your fighter → fight. Skippable. Cash per step. |
| **Daily rewards** | 7-day streak, missing a day resets. Day 7 = Luck potion + Star Food. |
| **Daily quests** | 3 quests per day from a pool (feed, steal, win battles, hatch, earn...). Same for a player all day. |
| **Offline earnings** | 25 % of income while away (50 % with VIP), up to 8 hours. Popup on join. |
| **Index** | Collect every titan and every titan × mutation (78 entries). Milestone rewards. |
| **Codes** | Type codes from socials (e.g. `RELEASE`). One use per player. |
| **Boosts** | Timed: 2× Cash, 2× Growth, 2× Luck (better eggs & mutations). |
| **Friend boost** | +10 % income per friend in the server (max +50 %). |
| **Events** | Meteor Feast, Blood Moon, Titan Clash. |

## 9. Social

- **Titan King** 👑: biggest titan on the server (crown, +50 % income).
- **Champion** 🏅: most trophies on the server (title above name).
- **Global leaderboards** (OrderedDataStore): Trophies, Biggest Titan, Rebirths, shown on boards
  at the arena.

## 10. Monetization (Robux)

IDs are **0** until you create them on the Creator Dashboard (see LAUNCH.md). Id 0 = hidden/disabled.

| Game passes | Effect |
|---|---|
| 2× Cash | income ×2 |
| VIP | +25 % growth, 50 % offline earnings, VIP tag |
| Big Storage | +50 food storage |
| Extra Pens | +2 pens |

| Developer products | Effect |
|---|---|
| Cash packs (S / M / L) | cash, scaled with rebirths |
| Luck Potion | 2× luck for 30 min |
| Growth Potion | 2× growth for 30 min |
| Star Food Pack | 3 Star Food |

Receipts are recorded in the player's save, so a purchase is never granted twice.

## 11. Save data (schema v3)

```
Version, Cash, Rebirths, NextUid
Creatures {uid -> {Id, Level, Xp, Mutation}},  Active (uid)
Food {id -> count}
Trophies, Index {key -> true}, IndexClaimed {milestone -> true}
Tutorial (step, 0 = done), Daily {Streak, LastDay}, Quests {Day, List}
Codes {code -> true}, Boosts {id -> expiresAt}, Passes {id -> true}, Purchases [receiptIds]
Settings {Music, Sfx}
Stats {StarterGiven, Hatched, Steals, Stolen, FoodEaten, FoodPicked, PlayTime,
       BattlesPlayed, BattlesWon, CashEarned}
LastOnline
```
Migration v2 → v3 removes biome unlocks and fills in the new fields.

## 12. Architecture (what gets built)

**Server services** (auto-loaded, by priority):
Data · Fx · Map · Base · Food · Creature · King · Steal · Battle · Egg · Rebirth · Event ·
Reward · Quest · DailyReward · Offline · Index · Code · Store · Social · Leaderboard ·
Settings · Tutorial · Admin

**Game events bus** (`server/Modules/GameEvents`): services report what happened
(`Fed`, `LevelUp`, `FoodPicked`, `Stole`, `Hatched`, `Mutated`, `BattleWon`, `BattlePlayed`,
`Earned`, `Rebirthed`) and quests/tutorial/stats listen. Adding a quest type = one config line.

**Pure, unit-tested rules** (`shared/Game`): Rules, CreatureMath, Battle (stats, damage, hit
tests, results), Progress (quests, daily streak, offline, index, codes, boosts, rewards).

**Client controllers:** State · UI · Fx · Prompt · Battle (piloting camera, inputs, HP bars) ·
BaseAnim · Food · Tutorial · Music.

**UI:** HUD (cash, trophies, menu, food bar, battle HUD) + one Window with pages:
Eggs · Food · Titans · Battle · Quests · Daily · Index · Store · Rebirth · Settings (+ codes) · Admin.

## 13. Test plan

- **Unit tests** (`tests/specs`, run in CI): configs valid, stats/damage math, cone hit tests,
  duel result rules, quest generation + progress, daily streak, offline cap, index milestones,
  codes, boosts, reward descriptions, schema migrations v1→v3, session locking.
- **Static checks:** StyLua formatting, luau-lsp type check, Rojo build.
- **In Studio (manual, see LAUNCH.md):** 2-player local server test of stealing, duel, clash;
  data save/rejoin; purchases with test IDs.

## 14. After launch (roadmap)

| Update | Content |
|---|---|
| 1.1 | Fusion (combine 2 titans), more titans, titan skins |
| 1.2 | Boss titan raids (PvE, whole server vs 1 giant titan) |
| 1.3 | Trading, clans / teams, ranked seasons |
| 1.4 | New island areas, map art & music upgrade |
