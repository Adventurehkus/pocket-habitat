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

local loadingPlayers: { [number]: boolean } = {}
local removingPlayers: { [number]: boolean } = {}

local function initializePlayer(player: Player)
    local userId = player.UserId
    if loadingPlayers[userId] or removingPlayers[userId] then
        return
    end
    loadingPlayers[userId] = true

    print("[ServerMain] Player added: " .. player.Name)
    local data = DataStoreManager.loadPlayerData(player)
    local currentPlayer = Players:GetPlayerByUserId(userId)
    if currentPlayer ~= player then
        loadingPlayers[userId] = nil
        if currentPlayer then
            task.spawn(initializePlayer, currentPlayer)
        elseif data then
            DataStoreManager.removeSession(player)
        end
        return
    end

    if not data then
        loadingPlayers[userId] = nil
        return
    end

    HabitatManager.allocateHabitat(player)
    RemoteEvents.SyncData:FireClient(player, data)
    loadingPlayers[userId] = nil
end

Players.PlayerAdded:Connect(function(player)
    task.spawn(initializePlayer, player)
end)

Players.PlayerRemoving:Connect(function(player)
    local userId = player.UserId
    removingPlayers[userId] = true
    print("[ServerMain] Player removing: " .. player.Name)
    ResourceManager.removePlayer(player)
    -- Clean up habitat folder when player leaves
    HabitatManager.removeHabitat(player)
    DataStoreManager.removeSession(player)
    removingPlayers[userId] = nil

    local currentPlayer = Players:GetPlayerByUserId(userId)
    if currentPlayer and currentPlayer ~= player then
        task.spawn(initializePlayer, currentPlayer)
    end
end)

for _, player in ipairs(Players:GetPlayers()) do
    task.spawn(initializePlayer, player)
end

game:BindToClose(function()
    for _, player in ipairs(Players:GetPlayers()) do
        DataStoreManager.removeSession(player)
    end
end)

print("[ServerMain] Pocket Habitat Server initialized successfully.")
