--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local EconomyRules = require(Shared:WaitForChild("EconomyRules"))
local HabitatRules = require(Shared:WaitForChild("HabitatRules"))
local QuestRules = require(Shared:WaitForChild("QuestRules"))
local RemoteEvents = require(Shared:WaitForChild("RemoteEvents"))
local DataStoreManager = require(script.Parent:WaitForChild("DataStoreManager"))
local HabitatManager = require(script.Parent:WaitForChild("HabitatManager"))
local WorldBuilder = require(script.Parent:WaitForChild("WorldBuilder"))

local EconomyManager = {}

function EconomyManager.addBells(player: Player, amount: number): boolean
    local data = DataStoreManager.getSession(player)
    if not data or amount <= 0 then
        return false
    end
    data.bells += amount
    RemoteEvents.SyncData:FireClient(player, data)
    return true
end

function EconomyManager.spendBells(player: Player, amount: number): boolean
    local data = DataStoreManager.getSession(player)
    if not data or amount <= 0 then
        return false
    end
    if data.bells < amount then
        return false
    end
    data.bells -= amount
    RemoteEvents.SyncData:FireClient(player, data)
    return true
end

function EconomyManager.addItem(
    player: Player,
    itemId: string,
    amount: number,
    shouldSync: boolean?
): boolean
    local data = DataStoreManager.getSession(player)
    if not data or amount <= 0 then
        return false
    end

    local canAdd, validationError =
        EconomyRules.canAddItem(data.inventory, data.upgrades, itemId, amount)
    if not canAdd then
        if validationError == "Inventory full" then
            RemoteEvents.Notification:FireClient(player, "Inventory full!")
        end
        return false
    end

    local currentQty = data.inventory[itemId] or 0
    data.inventory[itemId] = currentQty + amount
    if shouldSync ~= false then
        RemoteEvents.SyncData:FireClient(player, data)
    end
    return true
end

function EconomyManager.removeItem(player: Player, itemId: string, amount: number): boolean
    local data = DataStoreManager.getSession(player)
    if not data or amount <= 0 then
        return false
    end

    local currentQty = data.inventory[itemId] or 0
    if currentQty < amount then
        return false
    end

    data.inventory[itemId] = currentQty - amount
    if data.inventory[itemId] <= 0 then
        data.inventory[itemId] = nil
    end

    RemoteEvents.SyncData:FireClient(player, data)
    return true
end

function EconomyManager.purchaseUpgrade(player: Player, upgradeId: any): (boolean, string)
    if typeof(upgradeId) ~= "string" then
        return false, "Invalid argument"
    end

    local data = DataStoreManager.getSession(player)
    if not data then
        return false, "No session"
    end

    local def = Constants.UPGRADES[upgradeId]
    if not def then
        return false, "Invalid upgrade"
    end
    if upgradeId ~= "plot_expansion" and upgradeId ~= "storage_expansion" then
        return false, "Upgrade is not available yet"
    end

    local currentLevel = data.upgrades[upgradeId] or 1
    if currentLevel >= def.maxLevel then
        return false, "Max level reached"
    end

    local cost = math.floor(def.baseCost * (def.costMultiplier ^ (currentLevel - 1)))
    if data.bells < cost then
        return false, "Not enough Bells"
    end

    local nextLevel = currentLevel + 1
    local updatedQuestProgress = table.clone(data.questProgress)
    if not QuestRules.setProgress(updatedQuestProgress, "upgrade", upgradeId, nextLevel) then
        return false, "Unable to record upgrade progress"
    end

    local newPlotIndex: number? = nil
    local newPlotData: any? = nil
    if upgradeId == "plot_expansion" then
        local currentPlotCount = HabitatRules.getPlotCount(data.upgrades)
        if not currentPlotCount or #data.plots ~= currentPlotCount then
            return false, "Habitat plot data is unavailable"
        end

        local habitat = HabitatManager.getHabitat(player)
        if not habitat then
            return false, "Player habitat not found"
        end
        newPlotIndex = currentPlotCount + 1
        newPlotData = data.lockedPlots[newPlotIndex]
            or { seedId = nil, plantedTime = 0, waterCount = 0, stage = 0 }
        newPlotData = table.clone(newPlotData)
        if not WorldBuilder.addGardenPlot(habitat, newPlotIndex, newPlotData) then
            return false, "Unable to expand habitat"
        end
    end

    data.bells -= cost
    data.upgrades[upgradeId] = nextLevel
    data.questProgress = updatedQuestProgress

    if newPlotIndex then
        data.plots[newPlotIndex] = newPlotData
        data.lockedPlots[newPlotIndex] = nil
    end

    -- Fire visual effect
    RemoteEvents.UpgradeEffect:FireClient(player, upgradeId, nextLevel)

    RemoteEvents.SyncData:FireClient(player, data)
    RemoteEvents.Notification:FireClient(
        player,
        "Upgraded " .. def.name .. " to Level " .. tostring(nextLevel) .. "!"
    )
    return true, "Success"
end

function EconomyManager.init()
    RemoteEvents.PurchaseUpgrade.OnServerInvoke = EconomyManager.purchaseUpgrade
end

return EconomyManager
