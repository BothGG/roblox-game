--[[
	RarityTag: styles a TextLabel as a shiny rarity badge ("LEGENDARY").
	Epic and up get a moving shine; Mythic and up get a rainbow.
	The gradient is tagged "Shine" and animated by BaseAnimController.

	  RarityTag.Add(label, "Legendary")
]]

local CollectionService = game:GetService("CollectionService")

local Rarities = require(script.Parent.Parent.Config.Rarities)

local RarityTag = {}

RarityTag.ShineTag = "Shine"

function RarityTag.Add(label: TextLabel, rarityId: string)
	local rarity = Rarities[rarityId]
	if not rarity then
		return
	end
	label.Text = string.upper(rarity.Id)
	label.TextColor3 = Color3.new(1, 1, 1)
	local gradient = Instance.new("UIGradient")
	gradient.Name = "Shine"
	if rarity.Order >= 5 then
		gradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
			ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 220, 60)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(90, 240, 120)),
			ColorSequenceKeypoint.new(0.75, Color3.fromRGB(80, 170, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(230, 90, 255)),
		})
	elseif rarity.Order >= 3 then
		local c = rarity.Color
		gradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, c),
			ColorSequenceKeypoint.new(0.42, c),
			ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(0.58, c),
			ColorSequenceKeypoint.new(1, c),
		})
	else
		gradient.Color = ColorSequence.new(rarity.Color)
	end
	gradient.Parent = label
	if rarity.Order >= 3 then
		CollectionService:AddTag(gradient, RarityTag.ShineTag)
	end
end

return RarityTag
