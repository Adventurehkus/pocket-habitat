--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Constants = require(Shared:WaitForChild("Constants"))
local PlantRules = require(Shared:WaitForChild("PlantRules"))
local QuestRules = require(Shared:WaitForChild("QuestRules"))
local RemoteEvents = require(Shared:WaitForChild("RemoteEvents"))

local DataStoreManager = require(script.Parent:WaitForChild("DataStoreManager"))
local EconomyManager = require(script.Parent:WaitForChild("EconomyManager"))
local CreatureManager = require(script.Parent:WaitForChild("CreatureManager"))

local PlantManager = {}

-- These positions mirror WorldBuilder's initial garden plot positions.
-- Keep this declaration above the handler so every reference resolves to
-- this local table rather than an undeclared global.
local PLOT_POSITIONS: { [number]: Vector3 } = {
    [1] = Vector3.new(4, 0.2, 4),
    [2] = Vector3.new(-4, 0.2, 4),
    [3] = Vector3.new(4, 0.2, -4),
    [4] = Vector3.new(-4, 0.2, -4),
}

local function getPlotPosition(plotIndex: number): Vector3
    return PLOT_POSITIONS[plotIndex] or Vector3.new(0, 0.2, 0)
end

local function syncAndNotify(player: Player, data: any, message: string)
    RemoteEvents.SyncData:FireClient(player, data)
    RemoteEvents.Notification:FireClient(player, message)
end

local function plantSeed(player: Player, data: any, plan: any): (boolean, string)
    local seedId = plan.seedId
    if type(seedId) ~= "string" or not plan.plantDef then
        return false, "Invalid seed type"
    end

    if not EconomyManager.removeItem(player, seedId, 1) then
        return false, "Failed to remove seed"
    end

    local plot = plan.plot
    plot.seedId = seedId
    plot.plantedTime = os.time()
    plot.waterCount = 0
    plot.stage = 1

    if not QuestRules.recordProgress(data.questProgress, "plant", seedId, 1) then
        warn("Failed to record planting quest progress for user " .. tostring(player.UserId))
    end
    CreatureManager.checkDiscoveries(player)

    -- Use actual plot Instance position for effects
    local plotPosition = plan.plotInstance and plan.plotInstance.Position
        or getPlotPosition(plan.plotIndex)
    RemoteEvents.PlantEffect:FireClient(player, plotPosition, seedId)

    local message = if plan.automatic then "Planted seed automatically!" else "Planted seed!"
    syncAndNotify(player, data, message)

    if plan.automatic then
        return true, "Planted automatically"
    end
    return true, "Success"
end

local function waterPlant(player: Player, data: any, plan: any): (boolean, string)
    local plantDef = plan.plantDef
    if not plantDef then
        return false, "Invalid plant"
    end

    if not EconomyManager.removeItem(player, Constants.RESOURCES.DEWDROP, 1) then
        return false, "Failed to use dewdrop"
    end

    local plot = plan.plot
    plot.waterCount += 1

    local elapsed = os.time() - plot.plantedTime
    if elapsed >= plantDef.growthTime and plot.waterCount >= plantDef.waterNeeded then
        plot.stage = 2
    end

    if not QuestRules.recordProgress(data.questProgress, "water", nil, 1) then
        warn("Failed to record watering quest progress for user " .. tostring(player.UserId))
    end
    CreatureManager.checkDiscoveries(player)

    -- Use actual plot Instance position for effects
    local plotPosition = plan.plotInstance and plan.plotInstance.Position
        or getPlotPosition(plan.plotIndex)
    RemoteEvents.WaterEffect:FireClient(player, plotPosition, plot.waterCount, plantDef.waterNeeded)

    syncAndNotify(player, data, "Watered plant!")
    return true, "Success"
end

local function harvestPlant(player: Player, data: any, plan: any): (boolean, string)
    local plantDef = plan.plantDef
    if not plantDef then
        return false, "Invalid plant"
    end

    local reward = plantDef.harvestReward
    local rewardQty = math.random(reward.min, reward.max)

    if not EconomyManager.addItem(player, reward.itemId, rewardQty) then
        return false, "Inventory full"
    end

    -- Both operations are synchronous and the session is checked by each
    -- economy helper. Roll back the item grant if the Bells grant fails.
    if not EconomyManager.addBells(player, plantDef.bellReward) then
        EconomyManager.removeItem(player, reward.itemId, rewardQty)
        return false, "Failed to award Bells"
    end

    local plot = plan.plot
    plot.seedId = nil
    plot.plantedTime = 0
    plot.waterCount = 0
    plot.stage = 0

    if not QuestRules.recordProgress(data.questProgress, "harvest", reward.itemId, rewardQty) then
        warn("Failed to record harvest quest progress for user " .. tostring(player.UserId))
    end
    -- Use actual plot Instance position for effects
    local plotPosition = plan.plotInstance and plan.plotInstance.Position
        or getPlotPosition(plan.plotIndex)
    RemoteEvents.HarvestEffect:FireClient(
        player,
        plotPosition,
        reward.itemId,
        rewardQty,
        plantDef.bellReward
    )

    CreatureManager.checkDiscoveries(player)
    syncAndNotify(
        player,
        data,
        "Harvested "
            .. tostring(rewardQty)
            .. " crops and earned "
            .. tostring(plantDef.bellReward)
            .. " Bells!"
    )

    return true, "Success"
end

local function handleInteraction(
    player: Player,
    plotIndex: any,
    action: any,
    seedId: any?
): (boolean, string)
    if typeof(player) ~= "Instance" or not player:IsA("Player") then
        return false, "Invalid player"
    end

    local data = DataStoreManager.getSession(player)
    if type(data) ~= "table" then
        return false, "No session"
    end

    local plan, validationError =
        PlantRules.validateInteraction(data, plotIndex, action, seedId, os.time())
    if not plan then
        return false, validationError or "Invalid interaction"
    end

    -- Server-side validation: Verify actual plot Instance ownership and distance
    local HabitatManager = require(script.Parent:WaitForChild("HabitatManager"))
    local habitat = HabitatManager.getHabitat(player)

    if not habitat then
        return false, "Player habitat not found"
    end

    -- Find the actual plot Instance in the player's habitat
    local plotInstance = nil
    local plotsFolder = habitat:FindFirstChild("GardenPlots")
    if plotsFolder then
        local plotName = "Plot_" .. tostring(plotIndex)
        plotInstance = plotsFolder:FindFirstChild(plotName)
    end

    if not plotInstance then
        return false, "Plot not found in player habitat"
    end

    -- Check interaction distance (25 studs)
    local character = player.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then
        return false, "Invalid character"
    end

    local distance = (character.HumanoidRootPart.Position - plotInstance.Position).Magnitude
    if distance > 25 then
        return false, "Too far away from plot"
    end

    -- Update plan with actual plot Instance for effects
    plan.plotInstance = plotInstance

    if plan.action == "plant" then
        return plantSeed(player, data, plan)
    elseif plan.action == "water" then
        return waterPlant(player, data, plan)
    elseif plan.action == "harvest" then
        return harvestPlant(player, data, plan)
    end

    return false, "Invalid action"
end

function PlantManager.init()
    -- One authoritative handler owns every plot interaction. Legacy remotes
    -- call it directly; RemoteFunction:InvokeServer is client-only and must
    -- never be called from another server callback.
    RemoteEvents.InteractWithPlot.OnServerInvoke = handleInteraction

    RemoteEvents.PlantSeed.OnServerInvoke = function(
        player: Player,
        plotIndex: any,
        seedId: any
    ): (boolean, string)
        return handleInteraction(player, plotIndex, "plant", seedId)
    end

    RemoteEvents.WaterPlot.OnServerInvoke = function(
        player: Player,
        plotIndex: any
    ): (boolean, string)
        return handleInteraction(player, plotIndex, "water")
    end

    RemoteEvents.HarvestPlot.OnServerInvoke = function(
        player: Player,
        plotIndex: any
    ): (boolean, string)
        return handleInteraction(player, plotIndex, "harvest")
    end
end

return PlantManager
