--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))
local RemoteEvents = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RemoteEvents"))
local DataStoreManager = require(script.Parent:WaitForChild("DataStoreManager"))
local EconomyManager = require(script.Parent:WaitForChild("EconomyManager"))

local CreatureManager = {}

function CreatureManager.checkDiscoveries(player: Player)
	local data = DataStoreManager.getSession(player)
	if not data then return end
	
	-- Calculate flora density (planted plots or items) and water
	local floraCount = 0
	local waterTotal = 0
	for _, plot in pairs(data.plots) do
		if plot.seedId ~= nil then
			floraCount += 1
		end
		waterTotal += plot.waterCount
	end
	
	for creatureId, def in pairs(Constants.CREATURES) do
		if not data.creaturesDiscovered[creatureId] then
			if floraCount >= def.requiredFlora and waterTotal >= def.requiredWater then
				data.creaturesDiscovered[creatureId] = true
				EconomyManager.addBells(player, def.bellReward)
				RemoteEvents.SyncData:FireClient(player, data)
				RemoteEvents.CreatureDiscovered:FireClient(player, creatureId)
				RemoteEvents.Notification:FireClient(player, "Discovered new creature: " .. def.name .. "!")
			end
		end
	end
end

return CreatureManager
