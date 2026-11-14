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
