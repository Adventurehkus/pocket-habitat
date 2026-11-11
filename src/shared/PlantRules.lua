--!strict

local Constants = require(script.Parent:WaitForChild("Constants"))

local PlantRules = {}

local SEED_TO_PLANT = {
    [Constants.RESOURCES.SEED_BERRY] = "berry",
    [Constants.RESOURCES.SEED_FLOWER] = "flower",
    [Constants.RESOURCES.SEED_SUNPETAL] = "sunpetal",
    [Constants.RESOURCES.SEED_MOONFLOWER] = "moonflower",
    [Constants.RESOURCES.SEED_GLOWCAP] = "glowcap",
}

type InteractionPlan = {
    action: string,
    plot: any,
    plotIndex: number,
    seedId: string?,
    plantDef: any?,
    automatic: boolean?,
}

local function isFiniteNumber(value: any): boolean
    return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function isIntegerAtLeast(value: any, minimum: number): boolean
    return isFiniteNumber(value) and value % 1 == 0 and value >= minimum
end

local function getPlot(data: any, plotIndex: any): (any?, string?)
    if type(data) ~= "table" or type(data.plots) ~= "table" or type(data.inventory) ~= "table" then
        return nil, "Invalid player data"
    end

    if not isIntegerAtLeast(plotIndex, 1) then
        return nil, "Invalid plot"
    end

    local plot = data.plots[plotIndex]
    if type(plot) ~= "table" then
        return nil, "Invalid plot"
    end

    return plot, nil
end

function PlantRules.getPlantDef(seedId: any): any?
    if type(seedId) ~= "string" then
        return nil
    end

    local plantKey = SEED_TO_PLANT[seedId]
    if not plantKey then
        return nil
    end

    return Constants.PLANTS[plantKey]
end

local function resolveSeed(data: any, requestedSeedId: any, allowAutomatic: boolean): (string?, string?)
    if requestedSeedId ~= nil then
        if type(requestedSeedId) ~= "string" or not PlantRules.getPlantDef(requestedSeedId) then
            return nil, "Invalid seed type"
        end

        if not isIntegerAtLeast(data.inventory[requestedSeedId], 1) then
            return nil, "No seeds available"
        end

        return requestedSeedId, nil
    end

    if not allowAutomatic then
        return nil, "Invalid seed type"
    end

    local availableSeeds = {}
    for availableSeedId, quantity in pairs(data.inventory) do
        if PlantRules.getPlantDef(availableSeedId) and isIntegerAtLeast(quantity, 1) then
            table.insert(availableSeeds, availableSeedId)
        end
    end

    table.sort(availableSeeds)

    if #availableSeeds == 0 then
        return nil, "No seeds available for planting"
    end

    return availableSeeds[1], nil
end

local function validatePlant(
    data: any,
    plot: any,
    plotIndex: number,
    requestedSeedId: any,
    allowAutomatic: boolean
): (InteractionPlan?, string?)
    if plot.seedId ~= nil then
        return nil, "Plot already occupied"
    end

    local seedId, reason = resolveSeed(data, requestedSeedId, allowAutomatic)
    if not seedId then
        return nil, reason or "Invalid seed type"
    end

    return {
        action = "plant",
        plot = plot,
        plotIndex = plotIndex,
        seedId = seedId,
        plantDef = PlantRules.getPlantDef(seedId),
        automatic = allowAutomatic,
    }, nil
end

local function validateWater(data: any, plot: any, plotIndex: number): (InteractionPlan?, string?)
    if type(plot.seedId) ~= "string" then
        return nil, "Nothing planted here"
    end

    local plantDef = PlantRules.getPlantDef(plot.seedId)
    if not plantDef then
        return nil, "Invalid plant"
    end

    if
        not isFiniteNumber(plot.plantedTime)
        or plot.plantedTime < 0
        or not isIntegerAtLeast(plot.waterCount, 0)
        or not isIntegerAtLeast(plantDef.waterNeeded, 1)
    then
        return nil, "Invalid plant state"
    end

    if plot.waterCount >= plantDef.waterNeeded then
        return nil, "Already fully watered"
    end

    if not isIntegerAtLeast(data.inventory[Constants.RESOURCES.DEWDROP], 1) then
        return nil, "No dewdrops available"
    end

    return {
        action = "water",
        plot = plot,
        plotIndex = plotIndex,
        plantDef = plantDef,
    }, nil
end

local function validateHarvest(
    plot: any,
    plotIndex: number,
    now: any
): (InteractionPlan?, string?)
    if type(plot.seedId) ~= "string" then
        return nil, "Nothing to harvest"
    end

    local plantDef = PlantRules.getPlantDef(plot.seedId)
    if not plantDef then
        return nil, "Invalid plant"
    end

    if
        not isFiniteNumber(now)
        or now < 0
        or not isFiniteNumber(plot.plantedTime)
        or plot.plantedTime < 0
        or now < plot.plantedTime
        or not isIntegerAtLeast(plot.waterCount, 0)
        or not isIntegerAtLeast(plantDef.growthTime, 1)
        or not isIntegerAtLeast(plantDef.waterNeeded, 1)
    then
        return nil, "Invalid plant state"
    end

    if now - plot.plantedTime < plantDef.growthTime or plot.waterCount < plantDef.waterNeeded then
        return nil, "Plant is still growing"
    end

    local reward = plantDef.harvestReward
    if
        type(reward) ~= "table"
        or type(reward.itemId) ~= "string"
        or reward.itemId == ""
        or not isIntegerAtLeast(reward.min, 1)
        or not isIntegerAtLeast(reward.max, reward.min)
        or not isIntegerAtLeast(plantDef.bellReward, 1)
    then
        return nil, "Invalid plant reward configuration"
    end

    return {
        action = "harvest",
        plot = plot,
        plotIndex = plotIndex,
        plantDef = plantDef,
    }, nil
end

function PlantRules.validateInteraction(
    data: any,
    plotIndex: any,
    action: any,
    seedId: any?,
    now: any?
): (InteractionPlan?, string?)
    if type(action) ~= "string" then
        return nil, "Invalid arguments"
    end

    local plot, plotError = getPlot(data, plotIndex)
    if not plot then
        return nil, plotError or "Invalid plot"
    end

    if action == "plant" then
        return validatePlant(data, plot, plotIndex, seedId, false)
    elseif action == "harvest_or_plant" then
        if plot.seedId == nil then
            return validatePlant(data, plot, plotIndex, seedId, true)
        end

        return validateHarvest(plot, plotIndex, now)
    elseif action == "water" then
        return validateWater(data, plot, plotIndex)
    elseif action == "harvest" then
        return validateHarvest(plot, plotIndex, now)
    end

    return nil, "Invalid action. Use 'plant', 'water', 'harvest', or 'harvest_or_plant'."
end

return PlantRules
