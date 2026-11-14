--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local EconomyRules = require(Shared:WaitForChild("EconomyRules"))

local QuestRules = {}

local validTargets = {
    gather = true,
    plant = true,
    water = true,
    harvest = true,
    discover = true,
    upgrade = true,
}

local function isInteger(value: any, allowZero: boolean): boolean
    return type(value) == "number"
        and value == value
        and value > -math.huge
        and value < math.huge
        and value % 1 == 0
        and (if allowZero then value >= 0 else value > 0)
end

local function progressKey(targetType: any, targetId: any?): string?
    if type(targetType) ~= "string" or not validTargets[targetType] then
        return nil
    end
    if targetId ~= nil then
        if
            type(targetId) ~= "string"
            or targetId == ""
            or #targetId > 64
            or not string.match(targetId, "^[%w_%-]+$")
        then
            return nil
        end
    end
    return targetType .. ":" .. (targetId or "")
end

local function isValidProgressValue(targetType: string, targetId: string?, value: number): boolean
    if targetType ~= "upgrade" then
        return true
    end

    local upgradeDef = if targetId then Constants.UPGRADES[targetId] else nil
    return upgradeDef ~= nil and value <= upgradeDef.maxLevel
end

function QuestRules.isValidProgress(progress: any): boolean
    if type(progress) ~= "table" then
        return false
    end

    for key, value in pairs(progress) do
        if type(key) ~= "string" or #key == 0 or #key > 128 or not isInteger(value, true) then
            return false
        end
        local separator = string.find(key, ":", 1, true)
        if not separator or string.find(key, ":", separator + 1, true) then
            return false
        end
        local targetType = string.sub(key, 1, separator - 1)
        local targetId = string.sub(key, separator + 1)
        local normalizedTargetId = if targetId == "" then nil else targetId
        if
            progressKey(targetType, normalizedTargetId) ~= key
            or not isValidProgressValue(targetType, normalizedTargetId, value)
        then
            return false
        end
    end

    return true
end

function QuestRules.recordProgress(
    progress: any,
    targetType: any,
    targetId: any?,
    amount: any
): boolean
    local key = progressKey(targetType, targetId)
    if not key or not QuestRules.isValidProgress(progress) or not isInteger(amount, false) then
        return false
    end

    local total = (progress[key] or 0) + amount
    if not isInteger(total, true) or not isValidProgressValue(targetType, targetId, total) then
        return false
    end

    progress[key] = total
    return true
end

function QuestRules.setProgress(
    progress: any,
    targetType: any,
    targetId: any?,
    amount: any
): boolean
    local key = progressKey(targetType, targetId)
    if
        not key
        or not QuestRules.isValidProgress(progress)
        or not isInteger(amount, true)
        or not isValidProgressValue(targetType, targetId, amount)
    then
        return false
    end

    progress[key] = amount
    return true
end

function QuestRules.getProgress(progress: any, targetType: any, targetId: any?): number?
    local key = progressKey(targetType, targetId)
    if not key or not QuestRules.isValidProgress(progress) then
        return nil
    end
    if targetId ~= nil then
        return progress[key] or 0
    end

    local total = 0
    local prefix = targetType .. ":"
    for currentKey, amount in pairs(progress) do
        if string.sub(currentKey, 1, #prefix) == prefix then
            total += amount
            if not isInteger(total, true) then
                return nil
            end
        end
    end
    return total
end

function QuestRules.isComplete(progress: any, questDef: any): boolean
    if
        type(questDef) ~= "table"
        or not isInteger(questDef.targetCount, false)
        or not progressKey(questDef.targetType, questDef.targetItemId)
    then
        return false
    end

    local current = QuestRules.getProgress(progress, questDef.targetType, questDef.targetItemId)
    return current ~= nil and current >= questDef.targetCount
end

function QuestRules.nextQuest(questsCompleted: any): string?
    if type(questsCompleted) ~= "table" then
        return nil
    end

    for _, questId in ipairs(Constants.QUEST_ORDER) do
        if questsCompleted[questId] ~= true then
            return questId
        end
    end

    return nil
end

function QuestRules.tryClaim(data: any, questId: any): (boolean, string?)
    if
        type(data) ~= "table"
        or type(data.questsCompleted) ~= "table"
        or type(data.inventory) ~= "table"
        or type(data.upgrades) ~= "table"
        or type(data.creaturesDiscovered) ~= "table"
        or not QuestRules.isValidProgress(data.questProgress)
        or not isInteger(data.bells, true)
    then
        return false, "Invalid player data"
    end
    if
        type(questId) ~= "string"
        or data.currentQuest ~= questId
        or QuestRules.nextQuest(data.questsCompleted) ~= questId
    then
        return false, "Not current quest"
    end
    if data.questsCompleted[questId] then
        return false, "Already completed"
    end

    local questDef = Constants.QUESTS[questId]
    if not questDef then
        return false, "Invalid quest"
    end

    local completed = false
    if questDef.targetType == "discover" then
        if questDef.targetItemId then
            completed = data.creaturesDiscovered[questDef.targetItemId] == true
        else
            local discoveredCount = 0
            for _, discovered in pairs(data.creaturesDiscovered) do
                if discovered == true then
                    discoveredCount += 1
                end
            end
            completed = discoveredCount >= questDef.targetCount
        end
    elseif questDef.targetType == "upgrade" then
        local upgradeId = questDef.targetItemId
        completed = type(upgradeId) == "string"
            and (data.upgrades[upgradeId] or 1) >= questDef.targetCount
    else
        completed = QuestRules.isComplete(data.questProgress, questDef)
    end

    if not completed then
        return false, "Quest objectives not met"
    end

    local rewardItems = questDef.rewardItems or {}
    if type(rewardItems) ~= "table" then
        return false, "Invalid quest rewards"
    end
    local projectedInventory = table.clone(data.inventory)
    for itemId, amount in pairs(rewardItems) do
        local canAdd, reason =
            EconomyRules.canAddItem(projectedInventory, data.upgrades, itemId, amount)
        if not canAdd then
            return false, reason or "Quest reward unavailable"
        end
        projectedInventory[itemId] = (projectedInventory[itemId] or 0) + amount
    end

    local rewardBells = questDef.rewardBells
    if not isInteger(rewardBells, false) or not isInteger(data.bells + rewardBells, true) then
        return false, "Invalid quest reward"
    end

    for itemId, amount in pairs(rewardItems) do
        data.inventory[itemId] = (data.inventory[itemId] or 0) + amount
    end
    data.bells += rewardBells
    data.questsCompleted[questId] = true
    data.currentQuest = QuestRules.nextQuest(data.questsCompleted)
    return true, nil
end

return QuestRules
