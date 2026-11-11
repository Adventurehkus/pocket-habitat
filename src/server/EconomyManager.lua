--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))
local RemoteEvents = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RemoteEvents"))
local DataStoreManager = require(script.Parent:WaitForChild("DataStoreManager"))

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

function EconomyManager.addItem(player: Player, itemId: string, amount: number): boolean
    local data = DataStoreManager.getSession(player)
    if not data or amount <= 0 then
        return false
    end

    local currentQty = data.inventory[itemId] or 0
    local maxCapacity = 50 + (data.upgrades.storage_expansion or 1) * 25
    local totalItems = 0
    for _, qty in pairs(data.inventory) do
        totalItems += qty
    end

    if totalItems + amount > maxCapacity then
        RemoteEvents.Notification:FireClient(player, "Inventory full!")
        return false
    end

    data.inventory[itemId] = currentQty + amount
    RemoteEvents.SyncData:FireClient(player, data)
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

    local currentLevel = data.upgrades[upgradeId] or 1
    if currentLevel >= def.maxLevel then
        return false, "Max level reached"
    end

    local cost = math.floor(def.baseCost * (def.costMultiplier ^ (currentLevel - 1)))
    if data.bells < cost then
        return false, "Not enough Bells"
    end

    if not EconomyManager.spendBells(player, cost) then
        return false, "Transaction failed"
    end

    data.upgrades[upgradeId] = currentLevel + 1

    -- If plot expansion, add a new plot
    if upgradeId == "plot_expansion" then
        local newPlotIndex = #data.plots + 1
        data.plots[newPlotIndex] = { seedId = nil, plantedTime = 0, waterCount = 0, stage = 0 }
    end

    -- Fire visual effect
    RemoteEvents.UpgradeEffect:FireClient(player, upgradeId, currentLevel + 1)

    RemoteEvents.SyncData:FireClient(player, data)
    RemoteEvents.Notification:FireClient(
        player,
        "Upgraded " .. def.name .. " to Level " .. tostring(currentLevel + 1) .. "!"
    )
    return true, "Success"
end

return EconomyManager
