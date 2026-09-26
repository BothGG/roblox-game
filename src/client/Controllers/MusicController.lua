--[[
	MusicController: background music (Config/Sounds.lua Music ids).
	Plays the Battle track while you're fighting. Respects the Music setting.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Sounds = require(ReplicatedStorage:WaitForChild("Shared").Config.Sounds)
local ClientState = require(script.Parent.Parent.State.ClientState)

local player = Players.LocalPlayer

local MusicController = {
	Priority = 50,
}

local tracks: { [string]: Sound } = {}
local playing: string? = nil
local enabled = true

local function track(name: string): Sound?
	local id = Sounds.Music[name]
	if not id or id == "" then
		return nil
	end
	if not tracks[name] then
		local sound = Instance.new("Sound")
		sound.Name = "Music_" .. name
		sound.SoundId = id
		sound.Looped = true
		sound.Volume = 0
		sound.Parent = SoundService
		tracks[name] = sound
	end
	return tracks[name]
end

local function play(name: string?)
	if not enabled then
		name = nil
	end
	if name == playing then
		return
	end
	for trackName, sound in tracks do
		if trackName ~= name then
			TweenService:Create(sound, TweenInfo.new(1), { Volume = 0 }):Play()
		end
	end
	playing = name
	local sound = name and track(name)
	if sound then
		if not sound.IsPlaying then
			sound:Play()
		end
		TweenService:Create(sound, TweenInfo.new(1.5), { Volume = 0.35 }):Play()
	end
end

local function refresh()
	play(if player:GetAttribute("InBattle") then "Battle" else "Island")
end

function MusicController:Start()
	player:GetAttributeChangedSignal("InBattle"):Connect(refresh)
	ClientState.Changed:Connect(function(state)
		local on = state.Settings.Music ~= false
		if on ~= enabled then
			enabled = on
			playing = if on then nil else playing
			refresh()
		end
	end)
	refresh()
end

return MusicController
