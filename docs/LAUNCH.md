# Launch Checklist

Everything to do between "it works in Studio" and "players can play it".

## 1. Test in Studio (30–60 min)

Open `build/TitanClash.rbxlx` (or `rojo serve`) and check each item:

- [ ] **Solo:** tutorial arrows show; feed your Rex; grab food; hatch an egg; reach Lv.5; choose your fighter; **Practice vs Bot** works (attack with click/F, special with Q, win screen, rewards).
- [ ] **Admin panel** (🛠️): `cash 1000000`, `level 30`, `give Hydra Golden`, `event TitanClash`, `event MeteorFeast`, `event BloodMoon`.
- [ ] **2 players** (Test → Clients and Servers → 2 Players): steal food from each other, take it back, lock storage, **duel** each other (challenge from the ⚔️ Battle menu and with G at a base entrance), Titan Clash with both joined.
- [ ] Daily reward popup, quests progress + claim, Index milestone claim, code `RELEASE`.
- [ ] Settings: music / sound toggles, skip tutorial.
- [ ] Phone view: Studio's Device Emulator (Test tab) → check buttons fit.

## 2. Publish & settings

- [ ] File → **Publish to Roblox** (new experience).
- [ ] Game Settings → **Security → Enable Studio Access to API Services** (saving works in Studio).
- [ ] Game Settings → **Places → Max Players = 6** (must match `GameConfig.Plots.Count`).
- [ ] Game Settings → **Avatar**: R15, scale limits default (titan piloting is tuned for normal avatars).
- [ ] Rejoin twice and check your cash, titans and trophies were **saved**.

## 3. Monetization (optional)

1. Creator Dashboard → your experience → **Monetization → Passes**: create 2× Cash, VIP, Big Storage, Extra Pens.
2. **Developer Products**: Cash Pack, Cash Bag, Cash Vault, Luck Potion, Growth Potion, Star Food Pack.
3. Copy each ID into `src/shared/Config/Store.lua` (`Id = 0` → the real number). Rebuild.
4. Test purchases in Studio (they're free test purchases).

## 4. Make it look & sound good

- [ ] Replace placeholder titans: put models in `ServerStorage/CreatureModels/<Id>` (see ARCHITECTURE.md).
- [ ] Music: add ids to `Config/Sounds.lua` → `Music.Island` / `Music.Battle`.
- [ ] Sound effects: swap ids in `Config/Sounds.lua`; particle images in `Fx/Textures.lua`.
- [ ] Map: optional hand-built island (docs/MAP_GUIDE.md).
- [ ] **Icon** (512×512) and **3+ thumbnails** (1920×1080): a giant titan fight in the arena sells the game.
- [ ] Description with the hook: *"Steal food, grow a GIANT titan, and fight in the arena!"*

## 5. Launch

- [ ] Codes for socials: edit `Config/Codes.lua` (e.g. `RELEASE`, `TITANS`, `CLASH`).
- [ ] Set the experience to **Public**.
- [ ] Post short videos: stealing drama, a Lv.60 titan stomping a Lv.5, Titan Clash chaos.
- [ ] Watch **Creator Dashboard → Analytics** (retention D1/D7, session length) and the Developer Console for errors (F9 in game).

## 6. After launch

Update every 1–2 weeks (see the roadmap in PLAN.md): new titans, events, Fusion, boss raids.
Every content change is a config edit + `scripts/check.sh`.
