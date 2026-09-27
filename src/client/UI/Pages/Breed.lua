--[[
	Breed page: pick two titans of the same species to make an egg, watch the
	breeding timer, and see your eggs (in incubators or waiting for one).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Creatures = require(Shared.Config.Creatures)
local Mutations = require(Shared.Config.Mutations)
local Rarities = require(Shared.Config.Rarities)
local Breeding = require(Shared.Game.Breeding)
local CreatureMath = require(Shared.Game.CreatureMath)
local Format = require(Shared.Lib.Format)
local Theme = require(script.Parent.Parent.Theme)

local Page = { Name = "Breed", Title = "💞 Breeding" }

local PINK = Color3.fromRGB(255, 120, 175)

local container: ScrollingFrame
local context
local lastSignature = ""
local lastState
local picked: { string } = {}
local clockOffset = 0
local live: { () -> () } = {} -- timer labels updated every frame

local function now(): number
	return os.time() + clockOffset
end

local function colorOf(creature): Color3
	local def = Creatures[creature.Id]
	return if creature.Mutation then Mutations[creature.Mutation].Color else Rarities[def.Rarity].Color
end

local function section(order: number, text: string)
	local r = Theme.Row(container, order, 30)
	r.BackgroundTransparency = 1
	Theme.Label({
		Size = UDim2.fromScale(1, 1),
		Text = text,
		TextColor3 = Theme.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = r,
	})
end

local function rebuild(state)
	for _, child in container:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	table.clear(live)
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end

	-- Current breeding -------------------------------------------------------
	local pen = state.Breeding or {}
	if pen.ReadyAt and state.Creatures[pen.A] and state.Creatures[pen.B] then
		local a = state.Creatures[pen.A]
		local r = Theme.Row(container, nextOrder(), 96)
		Theme.Stroke(PINK, 3).Parent = r
		Theme.Label({
			Position = UDim2.fromOffset(14, 6),
			Size = UDim2.new(1, -150, 0, 30),
			Text = "💞 " .. CreatureMath.DisplayName(a) .. " + " .. CreatureMath.DisplayName(state.Creatures[pen.B]),
			TextColor3 = PINK,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = r,
		})
		local timer = Theme.Label({
			Position = UDim2.fromOffset(14, 38),
			Size = UDim2.new(1, -150, 0, 22),
			Text = "",
			TextColor3 = Theme.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = r,
		})
		local _, fill = Theme.ProgressBar(r, {
			Position = UDim2.fromOffset(14, 66),
			Size = UDim2.new(1, -150, 0, 16),
		})
		fill.BackgroundColor3 = PINK
		table.insert(live, function()
			local left = math.max(0, pen.ReadyAt - now())
			timer.Text = if left > 0 then "🥚 Egg in " .. Format.Time(left) else "🥚 Egg coming!"
			local total = math.max(1, pen.ReadyAt - (pen.StartedAt or pen.ReadyAt))
			fill.Size = UDim2.fromScale(math.clamp(1 - left / total, 0, 1), 1)
		end)
		local cancel = Theme.Button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.fromOffset(120, 50),
			Text = "Cancel",
			BackgroundColor3 = Theme.Red,
			Parent = r,
		})
		cancel.Activated:Connect(function()
			context.Net.Send("BreedCancel")
		end)
	else
		-- Picker ------------------------------------------------------------
		local first = picked[1] and state.Creatures[picked[1]]
		local second = picked[2] and state.Creatures[picked[2]]
		local r = Theme.Row(container, nextOrder(), 70)
		Theme.Stroke(PINK, 2).Parent = r
		local text
		if first and second then
			text = string.format(
				"%s + %s  •  %s",
				CreatureMath.DisplayName(first),
				CreatureMath.DisplayName(second),
				Format.Time(Breeding.Time(first.Id))
			)
			text ..= "  •  size " .. CreatureMath.SizeLabel(math.min(first.Size or 1, second.Size or 1)) .. "+"
		elseif first then
			text = "Now pick another " .. Creatures[first.Id].Name
		else
			text = "Pick two titans of the same kind"
		end
		Theme.Label({
			Position = UDim2.fromOffset(14, 0),
			Size = UDim2.new(1, -170, 1, 0),
			Text = text,
			TextColor3 = Theme.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = r,
		})
		local go = Theme.Button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.fromOffset(140, 50),
			Text = "💞 Breed!",
			BackgroundColor3 = if first and second then PINK else Color3.fromRGB(90, 90, 100),
			Parent = r,
		})
		go.Activated:Connect(function()
			if first and second then
				context.Net.Send("Breed", picked[1], picked[2])
				table.clear(picked)
			end
		end)
	end

	-- Eggs -------------------------------------------------------------------
	local eggUids = {}
	for uid in state.Eggs or {} do
		table.insert(eggUids, uid)
	end
	table.sort(eggUids, function(x, y)
		local ex, ey = state.Eggs[x], state.Eggs[y]
		if (ex.Slot ~= nil) ~= (ey.Slot ~= nil) then
			return ex.Slot ~= nil
		end
		return (tonumber(x) or 0) < (tonumber(y) or 0)
	end)
	section(nextOrder(), string.format("🥚 Eggs (%d)  •  %d incubators", #eggUids, state.Incubators or 1))
	for _, uid in eggUids do
		local egg = state.Eggs[uid]
		local def = Creatures[egg.Species]
		local r = Theme.Row(container, nextOrder(), 44)
		local label = Theme.Label({
			Position = UDim2.fromOffset(14, 0),
			Size = UDim2.new(1, -28, 1, 0),
			Text = "",
			TextColor3 = if egg.Mutation then Mutations[egg.Mutation].Color else Rarities[def.Rarity].Color,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = r,
		})
		local name =
			CreatureMath.DisplayName({ Id = egg.Species, Level = 1, Xp = 0, Mutation = egg.Mutation, Size = egg.Size })
		local bonus = if (egg.Bonus or 0) > 0 then string.format("  +%d%%", math.floor(egg.Bonus * 100)) else ""
		table.insert(live, function()
			local status
			if egg.HatchAt then
				local left = egg.HatchAt - now()
				status = if left > 0 then "hatching in " .. Format.Time(left) else "hatching!"
			else
				status = "waiting for a free incubator"
			end
			label.Text = "🥚 " .. name .. bonus .. "  •  " .. status
		end)
	end
	if #eggUids == 0 then
		local r = Theme.Row(container, nextOrder(), 36)
		r.BackgroundTransparency = 1
		Theme.Label({
			Size = UDim2.fromScale(1, 1),
			Text = "No eggs yet. Breed titans, raid nests or steal one!",
			TextColor3 = Theme.Muted,
			Parent = r,
		})
	end

	-- Titans to pick ----------------------------------------------------------
	if pen.ReadyAt then
		return
	end
	section(nextOrder(), "🐾 Your titans")
	local counts: { [string]: number } = {}
	for _, creature in state.Creatures do
		counts[creature.Id] = (counts[creature.Id] or 0) + 1
	end
	local uids = {}
	for uid in state.Creatures do
		table.insert(uids, uid)
	end
	table.sort(uids, function(x, y)
		local cx, cy = state.Creatures[x], state.Creatures[y]
		if cx.Id ~= cy.Id then
			return cx.Id < cy.Id
		end
		return (cx.Size or 1) > (cy.Size or 1)
	end)
	local firstPick = picked[1] and state.Creatures[picked[1]]
	for _, uid in uids do
		local creature = state.Creatures[uid]
		local isPicked = table.find(picked, uid) ~= nil
		local wrongKind = firstPick ~= nil and firstPick.Id ~= creature.Id and not isPicked
		local alone = counts[creature.Id] < 2
		local r = Theme.Row(container, nextOrder(), 48)
		if isPicked then
			Theme.Stroke(PINK, 3).Parent = r
		end
		Theme.Label({
			Position = UDim2.fromOffset(14, 0),
			Size = UDim2.new(1, -150, 1, 0),
			Text = CreatureMath.DisplayName(creature) .. "  Lv." .. creature.Level,
			TextColor3 = if wrongKind or alone then Theme.Muted else colorOf(creature),
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = r,
		})
		local button = Theme.Button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.fromOffset(130, 38),
			Text = if isPicked then "✓ Picked" else "Pick",
			BackgroundColor3 = if isPicked
				then PINK
				elseif wrongKind or alone then Color3.fromRGB(80, 80, 90)
				else Theme.Green,
			Parent = r,
		})
		local readyAt = creature.BreedReadyAt or 0
		table.insert(live, function()
			local left = readyAt - now()
			if left > 0 and not isPicked then
				button.Text = "😴 " .. Format.Time(left)
			elseif alone and not isPicked then
				button.Text = "Needs a pair"
			end
		end)
		button.Activated:Connect(function()
			if isPicked then
				table.remove(picked, table.find(picked, uid) :: number)
			elseif readyAt > now() or alone then
				return
			elseif wrongKind then
				table.clear(picked)
				table.insert(picked, uid)
			elseif #picked < 2 then
				table.insert(picked, uid)
			end
			lastSignature = ""
			rebuild(lastState)
		end)
	end
end

function Page.Build(page: ScrollingFrame, ctx)
	container = page
	context = ctx
	RunService.Heartbeat:Connect(function()
		if container.Visible and container.Parent and (container.Parent :: any).Visible then
			for _, update in live do
				update()
			end
		end
	end)
end

function Page.Update(state)
	lastState = state
	if state.ServerTime then
		clockOffset = state.ServerTime - os.time()
	end
	-- Forget picks for titans you no longer have.
	for i = #picked, 1, -1 do
		if not state.Creatures[picked[i]] then
			table.remove(picked, i)
		end
	end
	local parts = { tostring(state.Incubators), tostring((state.Breeding or {}).ReadyAt), table.concat(picked, ",") }
	for uid, creature in state.Creatures do
		table.insert(
			parts,
			uid
				.. ":"
				.. creature.Id
				.. ":"
				.. creature.Level
				.. ":"
				.. tostring(creature.Size)
				.. ":"
				.. tostring(creature.BreedReadyAt)
				.. ":"
				.. tostring(creature.Mutation)
		)
	end
	for uid, egg in state.Eggs or {} do
		table.insert(parts, "e" .. uid .. ":" .. tostring(egg.HatchAt))
	end
	table.sort(parts)
	local signature = table.concat(parts, "|")
	if signature ~= lastSignature then
		lastSignature = signature
		rebuild(state)
	end
end

function Page.Opened()
	lastSignature = ""
end

return Page
