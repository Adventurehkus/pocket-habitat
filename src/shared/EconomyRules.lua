--!strict

local EconomyRules = {}

local function isFiniteInteger(value: any, minimum: number): boolean
    return type(value) == "number"
        and value == value
        and value > -math.huge
        and value < math.huge
        and value % 1 == 0
        and value >= minimum
end

function EconomyRules.canAddItem(
    inventory: any,
    upgrades: any,
    itemId: any,
    amount: any
): (boolean, string?)
    if type(inventory) ~= "table" or type(upgrades) ~= "table" then
        return false, "Invalid inventory data"
    end

    if type(itemId) ~= "string" or itemId == "" then
        return false, "Invalid item"
    end

    if not isFiniteInteger(amount, 1) then
        return false, "Invalid item amount"
    end

    local storageLevel = upgrades.storage_expansion or 1
    if not isFiniteInteger(storageLevel, 1) then
        return false, "Invalid upgrade data"
    end

    local totalItems = 0
    for _, quantity in pairs(inventory) do
        if not isFiniteInteger(quantity, 0) then
            return false, "Invalid inventory data"
        end
        totalItems += quantity
    end

    local currentQuantity = inventory[itemId] or 0
    if not isFiniteInteger(currentQuantity, 0) then
        return false, "Invalid inventory data"
    end

    local maxCapacity = 50 + storageLevel * 25
    if totalItems + amount > maxCapacity then
        return false, "Inventory full"
    end

    return true, nil
end

return EconomyRules
