--[[
	Client entry point. The Loader finds every "*Controller" module in
	Controllers/ and runs Init(registry) then Start(), ordered by Priority.
	UI lives in UI/ and is started by UIController.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Loader = require(ReplicatedStorage:WaitForChild("Shared").Lib.Loader)

Loader.Boot(script.Parent:WaitForChild("Controllers"), "Controller")
