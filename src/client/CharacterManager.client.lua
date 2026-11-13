--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local RemoteEvents = require(Shared:WaitForChild("RemoteEvents"))

local CharacterManager = {}
local player = Players.LocalPlayer

function CharacterManager.requestRestore()
    RemoteEvents.RespawnCharacter:FireServer()
end

local function watchCharacter(character: Model)
    local humanoid = character:WaitForChild("Humanoid")
    if humanoid:IsA("Humanoid") then
        humanoid.Died:Connect(CharacterManager.requestRestore)
    end
end

player.CharacterAdded:Connect(watchCharacter)
if player.Character then
    task.defer(watchCharacter, player.Character)
end

return CharacterManager
