# ⚔️ Titan Clash

Raise giant titans by grabbing and **stealing food**, then **pilot your titan into the arena**
and fight other players' titans, like a monster movie. 6–12 players per server.

> Name, balance and content all live in `src/shared/Config/`. The full game plan is in
> **[docs/PLAN.md](docs/PLAN.md)**.

## ▶️ Play it in Roblox Studio

**Easiest:** download [`build/TitanClash.rbxlx`](build/TitanClash.rbxlx), double-click it,
press **Play (F5)**. The island is generated when the server starts (a few seconds).

- **Test battles alone:** open ⚔️ Battle → **Practice vs Bot**.
- **Test with friends / stealing / duels:** Test tab → Clients and Servers → **2 Players** → Start.
- **Admin panel:** in Studio everyone is an admin. Open 🛠️ Admin for cash, titans, levels, events.
- Before publishing, follow **[docs/LAUNCH.md](docs/LAUNCH.md)**.

**Live sync while coding:** install [Aftman](https://github.com/LPGhatguy/aftman) → `aftman install`
→ `rojo serve` → Rojo plugin in Studio → **Connect**.

## 🎮 The game

| System | What it is |
|---|---|
| **Titans** | 13 species, 6 rarities, battle stats (HP / Attack / Speed) and a special move per body type |
| **Food & stealing** | Food grows in the fields around the arena. Steal from other bases, carry it home. Owners take it back; guard titans knock thieves away |
| **Growth** | Feeding levels titans up: bigger, stronger, more income. Favorite foods = 2× XP |
| **Mutations** | Lava, Crystal, Shadow, Golden, Rainbow: more income, better stats, glowing auras |
| **Battles** | **Pilot your titan** in the arena. Duels (1v1, winner takes 15 % of the loser's food), **Titan Clash** free-for-all event, **Practice vs Bot** |
| **Progress** | Eggs, rebirth, trophies, Titan King 👑, Champion 🏅, global leaderboards |
| **Retention** | Tutorial with arrows, daily rewards (7-day streak), daily quests, offline earnings, Index book with milestones, codes, boosts, friend boost |
| **Store** | Game passes (2× Cash, VIP, Big Storage, Extra Pens) + products (cash, potions, Star Food). Set IDs in `Config/Store.lua` |
| **Events** | Titan Clash, Meteor Feast, Blood Moon |

**Controls:** E = feed / steal / take back · G = challenge (at a base entrance) · hold F = sell ·
in battle: **Click / F = Attack, Q = Special** (or the on-screen buttons on mobile).

## 🧱 For developers

- **[docs/PLAN.md](docs/PLAN.md)**: the full game plan (systems, numbers, save data)
- **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)**: how the code is organized + recipes for adding things
- **[docs/MAP_GUIDE.md](docs/MAP_GUIDE.md)**: replacing the generated island with a hand-built map
- **[docs/LAUNCH.md](docs/LAUNCH.md)**: publishing checklist

`scripts/check.sh` runs formatting, build, type check and **49 unit tests**. CI runs it on every push.
