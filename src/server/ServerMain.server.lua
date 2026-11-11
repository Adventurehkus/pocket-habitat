--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataStoreManager = require(script.Parent:WaitForChild("DataStoreManager"))
local ResourceManager = require(script.Parent:WaitForChild("ResourceManager"))
local PlantManager = require(script.Parent:WaitForChild("PlantManager"))
local QuestManager = require(script.Parent:WaitForChild("QuestManager"))
local EconomyManager = require(script.Parent:WaitForChild("EconomyManager"))
local WorldBuilder = require(script.Parent:WaitForChild("WorldBuilder"))
local HabitatManager = require(script.Parent:WaitForChild("HabitatManager"))
local RemoteEvents = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RemoteEvents"))

print("[ServerMain] Starting Pocket Habitat Server...")

WorldBuilder.init()
ResourceManager.init()
QuestManager.init()
PlantManager.init()
HabitatManager.init()

RemoteEvents.PurchaseUpgrade.OnServerInvoke = function(player: Player, upgradeId: any)
    return EconomyManager.purchaseUpgrade(player, upgradeId)
end

RemoteEvents.ClaimQuest.OnServerInvoke = function(player: Player, questId: any): (boolean, string)
    return QuestManager.claimQuest(player, questId)
end

Players.PlayerAdded:Connect(function(player)
    print("[ServerMain] Player added: " .. player.Name)
    local data = DataStoreManager.loadPlayerData(player)
    if data then
        task.wait(1)
        RemoteEvents.SyncData:FireClient(player, data)

        -- Allocate player's habitat
        HabitatManager.allocateHabitat(player)
    end
end)

Players.PlayerRemoving:Connect(function(player)
    print("[ServerMain] Player removing: " .. player.Name)
    DataStoreManager.removeSession(player)
    -- Clean up habitat folder when player leaves
    HabitatManager.removeHabitat(player)
end)

game:BindToClose(function()
    for _, player in ipairs(Players:GetPlayers()) do
        DataStoreManager.removeSession(player)
    end
end)

print("[ServerMain] Pocket Habitat Server initialized successfully.")
