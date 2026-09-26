--[[
	StoreService: Robux game passes and developer products (Config/Store.lua).

	- Passes: ownership is checked on join and saved in data.Passes; perks
	  are applied through shared/Game/Rules.lua (Rules.Perks).
	- Products: ProcessReceipt grants the reward once. Receipt ids are
	  stored in the player's save so a purchase is never granted twice.
	Client prompts purchases directly with MarketplaceService.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Store = require(Shared.Config.Store)
local Log = require(Shared.Lib.Log)
local Net = require(Shared.Net)

local log = Log.new("StoreService")

local StoreService = {
	Priority = 75,
}

local Data, Reward, Base, Food, Creature

function StoreService:Init(registry)
	Data = registry.DataService
	Reward = registry.RewardService
	Base = registry.BaseService
	Food = registry.FoodService
	Creature = registry.CreatureService
end

local function passByGameId(id: number)
	for key, pass in Store.Passes do
		if pass.Id ~= 0 and pass.Id == id then
			return key, pass
		end
	end
	return nil, nil
end

local function productByGameId(id: number)
	for key, product in Store.Products do
		if product.Id ~= 0 and product.Id == id then
			return key, product
		end
	end
	return nil, nil
end

function StoreService:Start()
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		local key, pass = passByGameId(passId)
		local data = Data:Get(player)
		if key and pass and data then
			data.Passes[key] = true
			self:_applyPerks(player)
			Reward:Grant(player, {}, pass.Icon .. " " .. pass.Name .. " unlocked! Thank you!", "Pass")
		end
	end)

	MarketplaceService.ProcessReceipt = function(receipt)
		return self:_processReceipt(receipt)
	end
end

function StoreService:OnPlayerReady(player: Player)
	local data = Data:Get(player)
	if not data then
		return
	end
	for key, pass in Store.Passes do
		if RunService:IsStudio() and Store.StudioOwnsAllPasses then
			data.Passes[key] = true
		elseif pass.Id ~= 0 and not data.Passes[key] then
			local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.Id)
			if ok and owns then
				data.Passes[key] = true
			end
		end
	end
	self:_applyPerks(player)
end

-- Pens, storage and income tags depend on passes: refresh them.
function StoreService:_applyPerks(player: Player)
	local data = Data:Get(player)
	if not data then
		return
	end
	player:SetAttribute("VIP", data.Passes.VIP == true)
	Base:RefreshPens(player)
	Food:RefreshStorage(player)
	Creature:RefreshAllTags(player)
	Data:Changed(player)
end

function StoreService:_processReceipt(receipt): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local data = player and Data:Get(player)
	if not player or not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local receiptId = tostring(receipt.PurchaseId)
	if table.find(data.Purchases, receiptId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local key, product = productByGameId(receipt.ProductId)
	if not key or not product then
		log:Warn("unknown product id", receipt.ProductId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	Reward:Grant(player, product.Reward, product.Icon .. " " .. product.Name .. "! Thank you!", "Product")
	table.insert(data.Purchases, receiptId)
	while #data.Purchases > GameConfig.Data.MaxReceipts do
		table.remove(data.Purchases, 1)
	end
	Data:Save(player)
	Net.Notify(player, "💖 Purchase complete!", Color3.fromRGB(255, 150, 200))
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

return StoreService
