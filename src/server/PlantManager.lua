--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))
local RemoteEvents = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RemoteEvents"))
local DataStoreManager = require(script.Parent:WaitForChild("DataStoreManager"))
local EconomyManager = require(script.Parent:WaitForChild("EconomyManager"))

local PlantManager = {}

function PlantManager.init()
	RemoteEvents.PlantSeed.OnServerInvoke = function(player: Player, plotIndex: number, seedId: string): (boolean, string)
		local data = DataStoreManager.getSession(player)
		if not data then return false, "No session" end
		
		local plot = data.plots[plotIndex]
		if not plot then return false, "Invalid plot" end
		if plot.seedId ~= nil then return false, "Plot already occupied" end
		
		if not data.inventory[seedId] or data.inventory[seedId] <= 0 then
			return false, "No seeds available"
		end
		
		if not EconomyManager.removeItem(player, seedId, 1) then
			return false, "Failed to remove seed"
		end
		
		plot.seedId = seedId
		plot.plantedTime = os.time()
		plot.waterCount = 0
		plot.stage = 1
		
		RemoteEvents.SyncData:FireClient(player, data)
		RemoteEvents.Notification:FireClient(player, "Planted seed!")
		return true, "Success"
	end
	
	RemoteEvents.WaterPlot.OnServerInvoke = function(player: Player, plotIndex: number): (boolean, string)
		local data = DataStoreManager.getSession(player)
		if not data then return false, "No session" end
		
		local plot = data.plots[plotIndex]
		if not plot or not plot.seedId then return false, "Nothing planted here" end
		
		local plantDef = Constants.PLANTS[plot.seedId == Constants.RESOURCES.SEED_BERRY and "berry" or "flower"]
		if not plantDef then return false, "Invalid plant" end
		
		if plot.waterCount >= plantDef.waterNeeded then
			return false, "Already fully watered"
		end
		
		if not data.inventory[Constants.RESOURCES.DEWDROP] or data.inventory[Constants.RESOURCES.DEWDROP] <= 0 then
			return false, "No dewdrops available"
		end
		
		if not EconomyManager.removeItem(player, Constants.RESOURCES.DEWDROP, 1) then
			return false, "Failed to use dewdrop"
		end
		
		plot.waterCount += 1
		local elapsed = os.time() - plot.plantedTime
		if elapsed >= plantDef.growthTime and plot.waterCount >= plantDef.waterNeeded then
			plot.stage = 2 -- Fully grown
		end
		
		RemoteEvents.SyncData:FireClient(player, data)
		RemoteEvents.Notification:FireClient(player, "Watered plant!")
		return true, "Success"
	end
	
	RemoteEvents.HarvestPlot.OnServerInvoke = function(player: Player, plotIndex: number): (boolean, string)
		local data = DataStoreManager.getSession(player)
		if not data then return false, "No session" end
		
		local plot = data.plots[plotIndex]
		if not plot or not plot.seedId then return false, "Nothing to harvest" end
		
		local plantKey = plot.seedId == Constants.RESOURCES.SEED_BERRY and "berry" or "flower"
		local plantDef = Constants.PLANTS[plantKey]
		if not plantDef then return false, "Invalid plant" end
		
		local elapsed = os.time() - plot.plantedTime
		if elapsed < plantDef.growthTime or plot.waterCount < plantDef.waterNeeded then
			return false, "Plant is still growing"
		end
		
		local rewardQty = math.random(plantDef.harvestReward.min, plantDef.harvestReward.max)
		if not EconomyManager.addItem(player, plantDef.harvestReward.itemId, rewardQty) then
			return false, "Inventory full"
		end
		
		EconomyManager.addBells(player, plantDef.bellReward)
		
		-- Reset plot
		plot.seedId = nil
		plot.plantedTime = 0
		plot.waterCount = 0
		plot.stage = 0
		
		RemoteEvents.SyncData:FireClient(player, data)
		RemoteEvents.Notification:FireClient(player, "Harvested " .. tostring(rewardQty) .. " crops and earned " .. tostring(plantDef.bellReward) .. " Bells!")
		return true, "Success"
	end
end

return PlantManager
