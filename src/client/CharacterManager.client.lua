--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local RemoteEvents = require(Shared:WaitForChild("RemoteEvents"))

local CharacterManager = {}

function CharacterManager.requestRestore()
    RemoteEvents.RespawnCharacter:FireServer()
end

return CharacterManager
