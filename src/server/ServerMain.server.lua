--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataStoreManager = require(script.Parent:WaitForChild("DataStoreManager"))
local ResourceManager = require(script.Parent:WaitForChild("ResourceManager"))
local PlantManager = require(script.Parent:WaitForChild("PlantManager"))
local QuestManager = require(script.Parent:WaitForChild("QuestManager"))
local EconomyManager = require(script.Parent:WaitForChild("EconomyManager"))
local RemoteEvents = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RemoteEvents"))

print("[ServerMain] Starting Pocket Habitat Server...")

ResourceManager.init()
PlantManager.init()
QuestManager.init()

RemoteEvents.PurchaseUpgrade.OnServerInvoke = function(player: Player, upgradeId: string)
	return EconomyManager.purchaseUpgrade(player, upgradeId)
end

Players.PlayerAdded:Connect(function(player)
	print("[ServerMain] Player added: " .. player.Name)
	local data = DataStoreManager.loadPlayerData(player)
	task.wait(1)
	RemoteEvents.SyncData:FireClient(player, data)
end)

Players.PlayerRemoving:Connect(function(player)
	print("[ServerMain] Player removing: " .. player.Name)
	DataStoreManager.removeSession(player)
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		DataStoreManager.removeSession(player)
	end
end)

print("[ServerMain] Pocket Habitat Server initialized successfully.")
