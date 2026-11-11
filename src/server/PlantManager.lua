--!strict

-- selene: allow(unused_variable)
local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))
local RemoteEvents = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RemoteEvents"))
local DataStoreManager = require(script.Parent:WaitForChild("DataStoreManager"))
local EconomyManager = require(script.Parent:WaitForChild("EconomyManager"))
local CreatureManager = require(script.Parent:WaitForChild("CreatureManager"))

-- New unified plot interaction handler
RemoteEvents.InteractWithPlot.OnServerInvoke = function(
    player: Player,
    plotIndex: any,
    action: string
): (boolean, string)
    if typeof(plotIndex) ~= "number" or typeof(action) ~= "string" then
        return false, "Invalid arguments"
    end

    local data = DataStoreManager.getSession(player)
    if not data then
        return false, "No session"
    end

    local plot = data.plots[plotIndex]
    if not plot or not plot.seedId then
        return false, "Nothing to interact with"
    end

    local plantDef =
        Constants.PLANTS[plot.seedId == Constants.RESOURCES.SEED_BERRY and "berry" or "flower"]
    if not plantDef then
        return false, "Invalid plant"
    end

    if action == "water" then
        if plot.waterCount >= plantDef.waterNeeded then
            return false, "Already fully watered"
        end

        if
            not data.inventory[Constants.RESOURCES.DEWDROP]
            or data.inventory[Constants.RESOURCES.DEWDROP] <= 0
        then
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

        CreatureManager.checkDiscoveries(player)

        -- Fire visual effect
        local pos = PLOT_POSITIONS[plotIndex] or Vector3.new(0, 0, 0)
        RemoteEvents.WaterEffect:FireClient(player, pos, plot.waterCount, plantDef.waterNeeded)

        RemoteEvents.SyncData:FireClient(player, data)
        RemoteEvents.Notification:FireClient(player, "Watered plant!")
        return true, "Success"
    elseif action == "harvest" then
        local elapsed = os.time() - plot.plantedTime
        if elapsed < plantDef.growthTime or plot.waterCount < plantDef.waterNeeded then
            return false, "Plant is still growing"
        end

        local rewardQty = math.random(plantDef.harvestReward.min, plantDef.harvestReward.max)
        if not EconomyManager.addItem(player, plantDef.harvestReward.itemId, rewardQty) then
            return false, "Inventory full"
        end

        EconomyManager.addBells(player, plantDef.bellReward)

        -- Fire visual effect before resetting plot
        local pos = PLOT_POSITIONS[plotIndex] or Vector3.new(0, 0, 0)
        RemoteEvents.HarvestEffect:FireClient(
            player,
            pos,
            plantDef.harvestReward.itemId,
            rewardQty,
            plantDef.bellReward
        )

        -- Reset plot
        plot.seedId = nil
        plot.plantedTime = 0
        plot.waterCount = 0
        plot.stage = 0

        CreatureManager.checkDiscoveries(player)
        RemoteEvents.SyncData:FireClient(player, data)
        RemoteEvents.Notification:FireClient(
            player,
            "Harvested "
                .. tostring(rewardQty)
                .. " crops and earned "
                .. tostring(plantDef.bellReward)
                .. " Bells!"
        )
        return true, "Success"
    else
        return false, "Invalid action. Use 'water' or 'harvest'."
    end
end

local PlantManager = {}

-- Plot positions (must match WorldBuilder)
local PLOT_POSITIONS = {
    [1] = Vector3.new(4, 0.5, 4),
    [2] = Vector3.new(-4, 0.5, 4),
    [3] = Vector3.new(4, 0.5, -4),
    [4] = Vector3.new(-4, 0.5, -4),
}

function PlantManager.init()
    RemoteEvents.PlantSeed.OnServerInvoke = function(
        player: Player,
        plotIndex: any,
        seedId: any
    ): (boolean, string)
        if typeof(plotIndex) ~= "number" or typeof(seedId) ~= "string" then
            return false, "Invalid arguments"
        end

        local data = DataStoreManager.getSession(player)
        if not data then
            return false, "No session"
        end

        local plot = data.plots[plotIndex]
        if not plot then
            return false, "Invalid plot"
        end
        if plot.seedId ~= nil then
            return false, "Plot already occupied"
        end

        -- Validate seedId
        if
            seedId ~= Constants.RESOURCES.SEED_BERRY
            and seedId ~= Constants.RESOURCES.SEED_FLOWER
        then
            return false, "Invalid seed type"
        end

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

        CreatureManager.checkDiscoveries(player)

        -- Fire visual effect
        local pos = PLOT_POSITIONS[plotIndex] or Vector3.new(0, 0, 0)
        RemoteEvents.PlantEffect:FireClient(player, pos, seedId)

        RemoteEvents.SyncData:FireClient(player, data)
        RemoteEvents.Notification:FireClient(player, "Planted seed!")
        return true, "Success"
    end

    RemoteEvents.WaterPlot.OnServerInvoke = function(
        player: Player,
        plotIndex: any
    ): (boolean, string)
        if typeof(plotIndex) ~= "number" then
            return false, "Invalid argument"
        end

        local data = DataStoreManager.getSession(player)
        if not data then
            return false, "No session"
        end

        local plot = data.plots[plotIndex]
        if not plot or not plot.seedId then
            return false, "Nothing planted here"
        end

        local plantDef =
            Constants.PLANTS[plot.seedId == Constants.RESOURCES.SEED_BERRY and "berry" or "flower"]
        if not plantDef then
            return false, "Invalid plant"
        end

        if plot.waterCount >= plantDef.waterNeeded then
            return false, "Already fully watered"
        end

        if
            not data.inventory[Constants.RESOURCES.DEWDROP]
            or data.inventory[Constants.RESOURCES.DEWDROP] <= 0
        then
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

        CreatureManager.checkDiscoveries(player)

        -- Fire visual effect
        local pos = PLOT_POSITIONS[plotIndex] or Vector3.new(0, 0, 0)
        RemoteEvents.WaterEffect:FireClient(player, pos, plot.waterCount, plantDef.waterNeeded)

        RemoteEvents.SyncData:FireClient(player, data)
        RemoteEvents.Notification:FireClient(player, "Watered plant!")
        return true, "Success"
    end

    RemoteEvents.HarvestPlot.OnServerInvoke = function(
        player: Player,
        plotIndex: any
    ): (boolean, string)
        if typeof(plotIndex) ~= "number" then
            return false, "Invalid argument"
        end

        local data = DataStoreManager.getSession(player)
        if not data then
            return false, "No session"
        end

        local plot = data.plots[plotIndex]
        if not plot or not plot.seedId then
            return false, "Nothing to harvest"
        end

        local plantKey = plot.seedId == Constants.RESOURCES.SEED_BERRY and "berry" or "flower"
        local plantDef = Constants.PLANTS[plantKey]
        if not plantDef then
            return false, "Invalid plant"
        end

        local elapsed = os.time() - plot.plantedTime
        if elapsed < plantDef.growthTime or plot.waterCount < plantDef.waterNeeded then
            return false, "Plant is still growing"
        end

        local rewardQty = math.random(plantDef.harvestReward.min, plantDef.harvestReward.max)
        if not EconomyManager.addItem(player, plantDef.harvestReward.itemId, rewardQty) then
            return false, "Inventory full"
        end

        EconomyManager.addBells(player, plantDef.bellReward)

        -- Fire visual effect before resetting plot
        local pos = PLOT_POSITIONS[plotIndex] or Vector3.new(0, 0, 0)
        RemoteEvents.HarvestEffect:FireClient(
            player,
            pos,
            plantDef.harvestReward.itemId,
            rewardQty,
            plantDef.bellReward
        )

        -- Reset plot
        plot.seedId = nil
        plot.plantedTime = 0
        plot.waterCount = 0
        plot.stage = 0

        CreatureManager.checkDiscoveries(player)
        RemoteEvents.SyncData:FireClient(player, data)
        RemoteEvents.Notification:FireClient(
            player,
            "Harvested "
                .. tostring(rewardQty)
                .. " crops and earned "
                .. tostring(plantDef.bellReward)
                .. " Bells!"
        )
        return true, "Success"
    end
end

return PlantManager
