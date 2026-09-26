--[[
	LeaderboardService: global leaderboards (OrderedDataStore) shown on the
	boards tagged "Leaderboard" (attribute Board = Trophies | Biggest | Rebirths).
	If DataStores aren't available (e.g. an unpublished place in Studio),
	the boards show this server's players instead.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Format = require(Shared.Lib.Format)
local Log = require(Shared.Lib.Log)

local log = Log.new("LeaderboardService")

local BOARDS = {
	Trophies = {
		Title = "🏆 Most Trophies",
		Value = function(data)
			return data.Trophies
		end,
	},
	Biggest = {
		Title = "🦖 Biggest Titan",
		Value = function(data)
			local best = 0
			for _, creature in data.Creatures do
				best = math.max(best, creature.Level)
			end
			return best
		end,
	},
	Rebirths = {
		Title = "🌟 Most Rebirths",
		Value = function(data)
			return data.Rebirths
		end,
	},
}

local LeaderboardService = {
	Priority = 77,
	_stores = {} :: { [string]: OrderedDataStore },
	_names = {} :: { [number]: string },
}

local Data, Map

function LeaderboardService:Init(registry)
	Data = registry.DataService
	Map = registry.MapService
end

function LeaderboardService:Start()
	for id in BOARDS do
		local ok, store = pcall(function()
			return DataStoreService:GetOrderedDataStore("LB_" .. id .. "_" .. GameConfig.Data.StoreName)
		end)
		if ok then
			self._stores[id] = store
		end
	end
	Data.Releasing:Connect(function(player, data)
		self:_submit(player, data)
	end)
	task.spawn(function()
		task.wait(5)
		while true do
			for player in Data.Profiles do
				local data = Data:Get(player)
				if data then
					self:_submit(player, data)
				end
			end
			self:_refreshBoards()
			task.wait(GameConfig.Leaderboards.RefreshInterval)
		end
	end)
end

function LeaderboardService:_submit(player: Player, data)
	for id, board in BOARDS do
		local store = self._stores[id]
		if store then
			local value = math.floor(board.Value(data))
			pcall(store.SetAsync, store, tostring(player.UserId), value)
		end
	end
end

function LeaderboardService:_name(userId: number): string
	if self._names[userId] then
		return self._names[userId]
	end
	local player = Players:GetPlayerByUserId(userId)
	if player then
		self._names[userId] = player.DisplayName
		return player.DisplayName
	end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	self._names[userId] = if ok then name else "Player"
	return self._names[userId]
end

function LeaderboardService:_top(id: string): { { Name: string, Value: number } }
	local rows = {}
	local store = self._stores[id]
	if store then
		local ok, pages = pcall(store.GetSortedAsync, store, false, GameConfig.Leaderboards.Size)
		if ok and pages then
			for _, entry in pages:GetCurrentPage() do
				table.insert(rows, { Name = self:_name(tonumber(entry.key) or 0), Value = entry.value })
			end
			return rows
		end
	end
	-- Fallback: players on this server
	for player, profile in Data.Profiles do
		table.insert(rows, { Name = player.DisplayName, Value = BOARDS[id].Value(profile.Data) })
	end
	table.sort(rows, function(a, b)
		return a.Value > b.Value
	end)
	while #rows > GameConfig.Leaderboards.Size do
		table.remove(rows)
	end
	return rows
end

function LeaderboardService:_refreshBoards()
	for _, part in Map.Leaderboards do
		local id = part:GetAttribute("Board")
		local board = BOARDS[id]
		if board then
			local ok, err = pcall(self._render, self, part, board.Title, self:_top(id))
			if not ok then
				log:Warn("board render failed", err)
			end
		end
	end
end

function LeaderboardService:_render(part: BasePart, title: string, rows)
	local gui = part:FindFirstChild("Board") :: SurfaceGui?
	if not gui then
		local g = Instance.new("SurfaceGui")
		g.Name = "Board"
		g.Face = Enum.NormalId.Front
		g.PixelsPerStud = 30
		g.LightInfluence = 0
		g.Parent = part
		gui = g
	end
	local surface = gui :: SurfaceGui
	surface:ClearAllChildren()
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = surface
	local function line(text: string, order: number, color: Color3, height: number)
		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, -20, height, 0)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = color
		label.Text = text
		label.LayoutOrder = order
		label.Parent = surface
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Parent = label
	end
	line(title, 0, Color3.fromRGB(255, 205, 60), 0.14)
	local medals = { "🥇", "🥈", "🥉" }
	for i, row in rows do
		local color = if i <= 3 then Color3.fromRGB(255, 240, 200) else Color3.fromRGB(220, 220, 235)
		line(
			string.format("%s %s  —  %s", medals[i] or ("#" .. i), row.Name, Format.Number(row.Value)),
			i,
			color,
			0.075
		)
	end
	if #rows == 0 then
		line("No scores yet", 1, Color3.fromRGB(200, 200, 210), 0.08)
	end
end

return LeaderboardService
