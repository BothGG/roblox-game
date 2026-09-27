--[[
	IncubatorService: incubators at the back of every base, where eggs hatch.

	- You start with 1 incubator; the "Incubator" upgrade adds more (max 6).
	- New eggs (from breeding, nests, stealing) go into a free incubator,
	  or wait in egg storage until one frees up.
	- Hatch timers use os.time(), so eggs keep hatching while you're offline
	  (they pop out the next time you join).
	- "Faster Hatching" upgrade: eggs placed after buying it hatch faster.
	- Bigger eggs get a bigger model, a longer hatch and a bigger reveal.

	API:
	  IncubatorService:AddEgg(player, { Species, Mutation?, Size, Bonus?, Source? }) -> uid?
	  IncubatorService:Refresh(player)          (after upgrades)
	  IncubatorService:GetEggModel(player, uid) -> Model?
	  IncubatorService:TakeEgg(player, uid) -> EggData?   (removes it; used by stealing)
	  IncubatorService.OnEggPad(fn(prompt, plot, slot))   (step 4 hooks steal prompts)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Creatures = require(Shared.Config.Creatures)
local Mutations = require(Shared.Config.Mutations)
local Rarities = require(Shared.Config.Rarities)
local Upgrades = require(Shared.Config.Upgrades)
local Breeding = require(Shared.Game.Breeding)
local CreatureMath = require(Shared.Game.CreatureMath)
local Rules = require(Shared.Game.Rules)
local Format = require(Shared.Lib.Format)
local Log = require(Shared.Lib.Log)
local Net = require(Shared.Net)

local Server = ServerScriptService:WaitForChild("Server")
local EggBuilder = require(Server.Modules.EggBuilder)
local GameEvents = require(Server.Modules.GameEvents)
local StudGround = require(Server.Modules.Map.StudGround)

local log = Log.new("IncubatorService")

local SLOT_X = { -50, -30, -10, 10, 30, 50 }
local SLOT_Z = 70
local MAX_SLOTS = 1 + Upgrades.Incubators.Max

local GOLD = Color3.fromRGB(255, 210, 60)
local RED = Color3.fromRGB(255, 90, 90)

type Pad = {
	Base: Part,
	Label: TextLabel,
	Bar: Frame,
	Prompt: ProximityPrompt,
	Egg: Model?,
	EggUid: string?,
}

local IncubatorService = {
	Priority = 30, -- after CreatureService (25) and UpgradeService (22)
	Pads = {} :: { [number]: { Pad } }, -- [plot index][slot]
}

local Data, Base, Creature, Fx
local padHooks: { (ProximityPrompt, any, number) -> () } = {}

function IncubatorService:Init(registry)
	Data = registry.DataService
	Base = registry.BaseService
	Creature = registry.CreatureService
	Fx = registry.FxService
end

-- Lets another service add its own prompt logic to every incubator pad.
function IncubatorService.OnEggPad(fn: (ProximityPrompt, any, number) -> ())
	table.insert(padHooks, fn)
	for plotIndex, pads in IncubatorService.Pads do
		for slot, pad in pads do
			fn(pad.Prompt, Base.Plots[plotIndex], slot)
		end
	end
end

--------------------------------------------------------------------------
-- Building
--------------------------------------------------------------------------

local function part(
	parent: Instance,
	name: string,
	shape: Enum.PartType,
	size: Vector3,
	cf: CFrame,
	color: Color3
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

function IncubatorService:_build(plot)
	local folder = Instance.new("Model")
	folder.Name = "Incubators"
	local pads = {}
	for slot = 1, MAX_SLOTS do
		local cf = plot.CFrame * CFrame.new(SLOT_X[slot], 1.1, SLOT_Z)
		local model = Instance.new("Model")
		model.Name = "Incubator" .. slot
		local base = part(
			model,
			"Base",
			Enum.PartType.Cylinder,
			Vector3.new(1.4, 12, 12),
			cf * CFrame.new(0, 0.7, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromRGB(70, 75, 95)
		)
		local ring = part(
			model,
			"Ring",
			Enum.PartType.Cylinder,
			Vector3.new(0.3, 12.6, 12.6),
			cf * CFrame.new(0, 1.3, 0) * CFrame.Angles(0, 0, math.rad(90)),
			GOLD
		)
		ring.Material = Enum.Material.Neon
		ring.CanCollide = false

		local gui = Instance.new("BillboardGui")
		gui.Name = "Timer"
		gui.Size = UDim2.fromOffset(170, 52)
		gui.StudsOffsetWorldSpace = Vector3.new(0, 12, 0)
		gui.MaxDistance = 140
		gui.AlwaysOnTop = false
		gui.Parent = base
		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, 0, 0, 30)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = Color3.new(1, 1, 1)
		label.Text = ""
		label.Parent = gui
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Parent = label
		local barBack = Instance.new("Frame")
		barBack.Position = UDim2.fromOffset(10, 34)
		barBack.Size = UDim2.new(1, -20, 0, 12)
		barBack.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
		barBack.Parent = gui
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = barBack
		local bar = Instance.new("Frame")
		bar.Size = UDim2.fromScale(0, 1)
		bar.BackgroundColor3 = GOLD
		bar.BorderSizePixel = 0
		bar.Parent = barBack
		corner:Clone().Parent = bar

		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "IncubatorPrompt"
		prompt.ActionText = "Place egg"
		prompt.ObjectText = "Incubator"
		prompt.HoldDuration = 0.3
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt:SetAttribute("Off", true)
		prompt:SetAttribute("OnlyUserId", -1)
		prompt.Parent = base
		prompt.Triggered:Connect(function(player)
			if Base:GetPlot(player) == plot then
				self:_ownerUse(player, slot)
			end
		end)

		if GameConfig.Map.Style ~= "Terrain" then
			StudGround.Style(model)
		end
		model.Parent = folder
		pads[slot] = { Base = base, Label = label, Bar = bar, Prompt = prompt }
		for _, hook in padHooks do
			hook(prompt, plot, slot)
		end
	end
	folder.Parent = plot.Model
	self.Pads[plot.Index] = pads
end

function IncubatorService:Start()
	for _, plot in Base.Plots do
		self:_build(plot)
	end
	Data:AddSnapshotHook(function(player, snapshot)
		local data = Data:Get(player)
		if data then
			snapshot.Incubators = Breeding.IncubatorCount(Rules.UpgradeLevel(data, "Incubators"))
		end
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				local ok, err = pcall(self._tick, self, player)
				if not ok then
					log:Warn("tick failed for", player.Name, err)
				end
			end
		end
	end)
	log:Info("incubators built:", #Base.Plots * MAX_SLOTS)
end

function IncubatorService:OnPlayerReady(player: Player)
	self:_fill(player)
	self:Refresh(player)
end

function IncubatorService:OnPlayerRemoving(player: Player)
	local pads = self:_pads(player)
	if not pads then
		return
	end
	for _, pad in pads do
		self:_clearModel(pad)
		pad.Label.Text = ""
		pad.Bar.Size = UDim2.fromScale(0, 1)
		pad.Prompt:SetAttribute("Off", true)
		pad.Prompt:SetAttribute("OnlyUserId", -1)
		pad.Base:SetAttribute("HasEgg", false)
		pad.Base:SetAttribute("OwnerUserId", nil)
	end
end

--------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------

function IncubatorService:_pads(player: Player): { Pad }?
	local plot = Base:GetPlot(player)
	return plot and self.Pads[plot.Index]
end

function IncubatorService:Count(player: Player): number
	local data = Data:Get(player)
	return if data then math.min(MAX_SLOTS, Breeding.IncubatorCount(Rules.UpgradeLevel(data, "Incubators"))) else 1
end

local function eggInSlot(data, slot: number): (string?, any)
	for uid, egg in data.Eggs do
		if egg.Slot == slot then
			return uid, egg
		end
	end
	return nil, nil
end

local function storedEggs(data): { string }
	local list = {}
	for uid, egg in data.Eggs do
		if egg.Slot == nil then
			table.insert(list, uid)
		end
	end
	-- Biggest / rarest first so the best egg starts hatching first.
	table.sort(list, function(a, b)
		local ea, eb = data.Eggs[a], data.Eggs[b]
		if ea.Size ~= eb.Size then
			return ea.Size > eb.Size
		end
		return (tonumber(a) or 0) < (tonumber(b) or 0)
	end)
	return list
end

function IncubatorService:_clearModel(pad: Pad)
	if pad.Egg then
		pad.Egg:Destroy()
		pad.Egg = nil
		pad.EggUid = nil
	end
end

function IncubatorService:GetEggModel(player: Player, uid: string): Model?
	local pads = self:_pads(player)
	if pads then
		for _, pad in pads do
			if pad.EggUid == uid then
				return pad.Egg
			end
		end
	end
	return nil
end

-- Puts an egg into a slot and starts its timer.
function IncubatorService:_place(player: Player, uid: string, slot: number)
	local data = Data:Get(player)
	if not data then
		return
	end
	local egg = data.Eggs[uid]
	local now = os.time()
	egg.Slot = slot
	egg.StartedAt = now
	egg.HatchAt = now + Breeding.HatchTime(egg.Species, egg.Size, Rules.UpgradeLevel(data, "IncubatorSpeed"))
end

-- Moves stored eggs into every free incubator.
function IncubatorService:_fill(player: Player): boolean
	local data = Data:Get(player)
	if not data then
		return false
	end
	local changed = false
	local stored = storedEggs(data)
	for slot = 1, self:Count(player) do
		if #stored == 0 then
			break
		end
		if not eggInSlot(data, slot) then
			self:_place(player, table.remove(stored, 1) :: string, slot)
			changed = true
		end
	end
	-- Eggs in slots you no longer have (shouldn't happen) go back to storage.
	for _, egg in data.Eggs do
		if egg.Slot and egg.Slot > self:Count(player) then
			egg.Slot, egg.StartedAt, egg.HatchAt = nil, nil, nil
			changed = true
		end
	end
	return changed
end

--------------------------------------------------------------------------
-- Visuals
--------------------------------------------------------------------------

function IncubatorService:Refresh(player: Player)
	local data = Data:Get(player)
	local pads = self:_pads(player)
	if not data or not pads then
		return
	end
	local count = self:Count(player)
	local stored = #storedEggs(data)
	for slot, pad in pads do
		local uid, egg = eggInSlot(data, slot)
		pad.Prompt:SetAttribute("OnlyUserId", player.UserId)
		pad.Base:SetAttribute("OwnerUserId", player.UserId)
		pad.Base:SetAttribute("HasEgg", uid ~= nil and slot <= count)
		pad.Base:SetAttribute("EggUid", if slot <= count then uid else nil)
		if slot > count then
			self:_clearModel(pad)
			pad.Label.Text = "🔒 Buy at upgrade board"
			pad.Label.TextColor3 = Color3.fromRGB(170, 170, 190)
			pad.Bar.Parent.Visible = false
			pad.Prompt:SetAttribute("Off", true)
			pad.Base.Transparency = 0.5
		elseif not uid then
			self:_clearModel(pad)
			pad.Base.Transparency = 0
			pad.Label.Text = if stored > 0 then "🥚 Place an egg" else "Empty incubator"
			pad.Label.TextColor3 = Color3.new(1, 1, 1)
			pad.Bar.Parent.Visible = false
			pad.Prompt.ActionText = "Place egg"
			pad.Prompt:SetAttribute("Off", stored <= 0)
		else
			pad.Base.Transparency = 0
			pad.Bar.Parent.Visible = true
			pad.Prompt:SetAttribute("Off", true)
			if pad.EggUid ~= uid then
				self:_clearModel(pad)
				local model = EggBuilder.Build(egg)
				model:PivotTo(pad.Base.CFrame * CFrame.Angles(0, 0, math.rad(-90)) * CFrame.new(0, 0.7, 0))
				model:SetAttribute("OwnerUserId", player.UserId)
				model:SetAttribute("EggUid", uid)
				model:SetAttribute("Slot", slot)
				model.Parent = pad.Base.Parent
				pad.Egg, pad.EggUid = model, uid
			end
			self:_updateTimer(pad, egg, os.time())
		end
	end
end

function IncubatorService:_updateTimer(pad: Pad, egg, now: number)
	local def = Creatures[egg.Species]
	local left = math.max(0, (egg.HatchAt or now) - now)
	local tierText = if Breeding.TierIndex(egg.Size) > 1 then CreatureMath.SizeLabel(egg.Size) .. " " else ""
	if left <= 0 then
		pad.Label.Text = "🐣 " .. tierText .. def.Name .. " hatching!"
	else
		pad.Label.Text = string.format("🥚 %s%s  %s", tierText, def.Name, Format.Time(left))
	end
	pad.Label.TextColor3 = if egg.Mutation then Mutations[egg.Mutation].Color else Rarities[def.Rarity].Color
	pad.Bar.Size = UDim2.fromScale(Breeding.HatchProgress(egg, now), 1)
end

--------------------------------------------------------------------------
-- Tick & hatching
--------------------------------------------------------------------------

function IncubatorService:_tick(player: Player)
	local data = Data:Get(player)
	local pads = self:_pads(player)
	if not data or not pads then
		return
	end
	local now = os.time()
	for slot = 1, self:Count(player) do
		local uid, egg = eggInSlot(data, slot)
		if uid and egg.HatchAt and now >= egg.HatchAt then
			if Rules.HasFreeSlot(data) then
				self:_hatch(player, uid)
			elseif Net.Throttle(player, "IncubatorFull", 30) then
				Net.Notify(player, "🥚 An egg is ready but your pens are full! Sell a titan or buy a pen.", RED)
			end
		end
		local pad = pads[slot]
		if uid and pad and pad.EggUid == uid then
			self:_updateTimer(pad, egg, now)
		end
	end
end

function IncubatorService:_hatch(player: Player, uid: string)
	local data = Data:Get(player)
	if not data then
		return
	end
	local egg = data.Eggs[uid]
	local pads = self:_pads(player)
	local position = nil
	if pads and egg.Slot and pads[egg.Slot] then
		position = pads[egg.Slot].Base.Position
	end
	local newUid = Creature:Add(player, egg.Species, egg.Mutation, egg.Size)
	if not newUid then
		return
	end
	local creature = data.Creatures[newUid]
	creature.Bonus = egg.Bonus or 0
	data.Eggs[uid] = nil
	data.Stats.Hatched += 1
	Creature:RefreshAllTags(player)

	local def = Creatures[egg.Species]
	local rarity = Rarities[def.Rarity]
	local color = if egg.Mutation then Mutations[egg.Mutation].Color else rarity.Color
	if position then
		Fx:PlayAll("Spawn", { Position = position, Color = color, Rare = Breeding.TierIndex(egg.Size) >= 4 })
		Fx:PlayAll("Poof", { Position = position })
	end
	GameEvents.Fire(player, "Hatched", { Titan = egg.Species, Mutation = egg.Mutation, Size = egg.Size })
	Net.Fire(player, "Hatched", {
		CreatureId = egg.Species,
		Mutation = egg.Mutation,
		Source = "Egg",
		Size = egg.Size,
	})
	local name =
		CreatureMath.DisplayName({ Id = egg.Species, Level = 1, Xp = 0, Mutation = egg.Mutation, Size = egg.Size })
	if Breeding.ShouldAnnounce(egg.Size) then
		Net.Announce("🐣 HUGE HATCH!", player.DisplayName .. " hatched a " .. name .. "!", color)
	elseif rarity.Order >= Rarities.Legendary.Order or egg.Mutation then
		Net.NotifyAll(string.format("🐣 %s hatched a %s!", player.DisplayName, name), color)
	end
	log:Info(player.Name, "hatched", name)

	self:_fill(player)
	self:Refresh(player)
	Data:Changed(player)
end

--------------------------------------------------------------------------
-- Actions
--------------------------------------------------------------------------

function IncubatorService:_ownerUse(player: Player, slot: number)
	local data = Data:Get(player)
	if not data or slot > self:Count(player) or eggInSlot(data, slot) then
		return
	end
	local stored = storedEggs(data)
	if #stored == 0 then
		Net.Notify(player, "🥚 No eggs waiting. Breed titans or find nests!", RED)
		return
	end
	self:_place(player, stored[1], slot)
	self:Refresh(player)
	Data:Changed(player)
end

-- Adds a new egg. It goes into a free incubator, or egg storage if none.
function IncubatorService:AddEgg(
	player: Player,
	info: {
		Species: string,
		Mutation: string?,
		Size: number?,
		Bonus: number?,
		Source: string?,
	}
): string?
	local data = Data:Get(player)
	if not data or not Creatures[info.Species] then
		return nil
	end
	local count = 0
	for _ in data.Eggs do
		count += 1
	end
	if count >= GameConfig.Data.Limits.Eggs then
		Net.Notify(player, "🥚 Your egg storage is full!", RED)
		return nil
	end
	local uid = tostring(data.NextUid)
	data.NextUid += 1
	data.Eggs[uid] = {
		Uid = uid,
		Species = info.Species,
		Mutation = if info.Mutation and Mutations[info.Mutation] then info.Mutation else nil,
		Size = Breeding.TierSize(Breeding.TierIndex(info.Size or 1)),
		Bonus = info.Bonus or 0,
		Source = info.Source or "Breed",
	}
	local egg = data.Eggs[uid]
	self:_fill(player)
	self:Refresh(player)
	if Breeding.ShouldAnnounce(egg.Size) then
		local def = Creatures[egg.Species]
		Net.Announce(
			"🥚 GIANT EGG!",
			player.DisplayName .. " has a " .. CreatureMath.SizeLabel(egg.Size) .. " " .. def.Name .. " egg!",
			Rarities[def.Rarity].Color
		)
	end
	Data:Changed(player)
	return uid
end

-- Removes an egg (for stealing / carrying). Returns its data.
function IncubatorService:TakeEgg(player: Player, uid: string)
	local data = Data:Get(player)
	local egg = data and data.Eggs[uid]
	if not data or not egg then
		return nil
	end
	data.Eggs[uid] = nil
	self:_fill(player)
	self:Refresh(player)
	Data:Changed(player)
	return egg
end

return IncubatorService
