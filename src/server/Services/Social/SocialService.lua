--[[
	SocialService:
	- Friend boost: +10% income per friend in the server (max +50%)
	- Champion: the player with the most trophies on the server
	- Titles over players' heads: 👑 KING, 🏅 CHAMPION, ⭐ VIP
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)

local SocialService = {
	Priority = 76,
	_friendCache = {} :: { [string]: boolean },
}

local Data, Creature

function SocialService:Init(registry)
	Data = registry.DataService
	Creature = registry.CreatureService
	Data:AddSnapshotHook(function(player, snapshot)
		snapshot.Friends = player:GetAttribute("Friends") or 0
	end)
end

local function pairKey(a: Player, b: Player): string
	local lo, hi = math.min(a.UserId, b.UserId), math.max(a.UserId, b.UserId)
	return lo .. ":" .. hi
end

function SocialService:_areFriends(a: Player, b: Player): boolean
	local key = pairKey(a, b)
	if self._friendCache[key] == nil then
		local ok, result = pcall(a.IsFriendsWithAsync, a, b.UserId)
		self._friendCache[key] = ok and result == true
	end
	return self._friendCache[key]
end

function SocialService:_refreshFriends()
	local players = Players:GetPlayers()
	for _, player in players do
		local count = 0
		for _, other in players do
			if other ~= player and self:_areFriends(player, other) then
				count += 1
			end
		end
		if player:GetAttribute("Friends") ~= count then
			local before = player:GetAttribute("Friends") or 0
			player:SetAttribute("Friends", count)
			if count > before then
				Net.Notify(
					player,
					string.format("🤝 Friend boost! +%d%% income", math.min(count * 10, 50)),
					Color3.fromRGB(120, 220, 255)
				)
			end
			Creature:RefreshAllTags(player)
		end
	end
end

local function titleText(player: Player): (string, Color3)
	if player:GetAttribute("IsKing") then
		return "👑 TITAN KING", Color3.fromRGB(255, 205, 60)
	elseif player:GetAttribute("Champion") then
		return "🏅 CHAMPION", Color3.fromRGB(255, 150, 90)
	elseif player:GetAttribute("VIP") then
		return "⭐ VIP", Color3.fromRGB(255, 230, 120)
	end
	return "", Color3.new(1, 1, 1)
end

function SocialService:_updateTitle(player: Player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head then
		return
	end
	local gui = head:FindFirstChild("Title") :: BillboardGui?
	local text, color = titleText(player)
	if text == "" then
		if gui then
			gui:Destroy()
		end
		return
	end
	if not gui then
		local g = Instance.new("BillboardGui")
		g.Name = "Title"
		g.Size = UDim2.fromOffset(180, 30)
		g.StudsOffset = Vector3.new(0, 3.2, 0)
		g.MaxDistance = 120
		g.LightInfluence = 0
		local label = Instance.new("TextLabel")
		label.Name = "Label"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.Parent = g
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Parent = label
		g.Parent = head
		gui = g
	end
	local label = (gui :: BillboardGui):FindFirstChild("Label") :: TextLabel
	label.Text = text
	label.TextColor3 = color
end

function SocialService:_refreshChampion()
	local best, bestTrophies = nil, 0
	for player, profile in Data.Profiles do
		if player.Parent and profile.Data.Trophies > bestTrophies then
			best, bestTrophies = player, profile.Data.Trophies
		end
	end
	for _, player in Players:GetPlayers() do
		local isChampion = player == best
		if (player:GetAttribute("Champion") == true) ~= isChampion then
			player:SetAttribute("Champion", isChampion)
			if isChampion then
				Net.NotifyAll(
					"🏅 " .. player.DisplayName .. " is the new Champion (" .. bestTrophies .. " trophies)!",
					Color3.fromRGB(255, 150, 90)
				)
			end
		end
	end
end

function SocialService:Start()
	Players.PlayerRemoving:Connect(function()
		task.defer(function()
			self:_refreshFriends()
		end)
	end)
	task.spawn(function()
		while true do
			task.wait(5)
			self:_refreshChampion()
		end
	end)
end

function SocialService:OnPlayerReady(player: Player)
	task.spawn(function()
		self:_refreshFriends()
	end)
	local function watch()
		self:_updateTitle(player)
	end
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("Head", 5)
		watch()
	end)
	for _, attribute in { "IsKing", "Champion", "VIP" } do
		player:GetAttributeChangedSignal(attribute):Connect(watch)
	end
	watch()
end

return SocialService
