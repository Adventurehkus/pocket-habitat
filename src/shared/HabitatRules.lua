--!strict

local Constants = require(script.Parent:WaitForChild("Constants"))

local HabitatRules = {}

HabitatRules.INITIAL_PLOT_COUNT = 4

function HabitatRules.getPlotCount(upgrades: any): number?
    if type(upgrades) ~= "table" then
        return nil
    end

    local upgrade = Constants.UPGRADES.plot_expansion
    local level = upgrades.plot_expansion
    if level == nil then
        level = 1
    end
    if
        type(level) ~= "number"
        or level ~= level
        or level % 1 ~= 0
        or level < 1
        or level > upgrade.maxLevel
    then
        return nil
    end

    return HabitatRules.INITIAL_PLOT_COUNT + level - 1
end

function HabitatRules.getMaxPlotCount(): number
    return HabitatRules.INITIAL_PLOT_COUNT + Constants.UPGRADES.plot_expansion.maxLevel - 1
end

function HabitatRules.partitionPlotData(
    plots: any,
    archivedPlots: any,
    unlockedPlotCount: any
): (any?, any?, string?)
    local maxPlotCount = HabitatRules.getMaxPlotCount()
    if
        type(plots) ~= "table"
        or type(archivedPlots) ~= "table"
        or type(unlockedPlotCount) ~= "number"
        or unlockedPlotCount ~= unlockedPlotCount
        or unlockedPlotCount % 1 ~= 0
        or unlockedPlotCount < HabitatRules.INITIAL_PLOT_COUNT
        or unlockedPlotCount > maxPlotCount
    then
        return nil, nil, "Malformed plot data"
    end

    local active = {}
    local archived = {}
    local function addPlot(index: any, plot: any): string?
        if
            type(index) ~= "number"
            or index ~= index
            or math.abs(index) == math.huge
            or index < 1
            or index % 1 ~= 0
            or index > maxPlotCount
            or type(plot) ~= "table"
        then
            return "Malformed plot entry"
        end

        local destination = if index <= unlockedPlotCount then active else archived
        if destination[index] ~= nil then
            return "Duplicate plot entry"
        end
        destination[index] = plot
        return nil
    end

    for index, plot in pairs(plots) do
        local err = addPlot(index, plot)
        if err then
            return nil, nil, err
        end
    end
    for index, plot in pairs(archivedPlots) do
        local err = addPlot(index, plot)
        if err then
            return nil, nil, err
        end
    end

    return active, archived, nil
end

function HabitatRules.isPlotIndexUnlocked(upgrades: any, plotIndex: any): boolean
    local plotCount = HabitatRules.getPlotCount(upgrades)
    return plotCount ~= nil
        and type(plotIndex) == "number"
        and plotIndex == plotIndex
        and plotIndex % 1 == 0
        and plotIndex >= 1
        and plotIndex <= plotCount
end

return HabitatRules
