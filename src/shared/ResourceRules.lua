--!strict

local ResourceRules = {}

local function isFiniteNumber(value: any): boolean
    return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

function ResourceRules.isValidCooldowns(cooldowns: any): boolean
    if type(cooldowns) ~= "table" then
        return false
    end

    for nodeId, readyAt in pairs(cooldowns) do
        if
            type(nodeId) ~= "string"
            or nodeId == ""
            or #nodeId > 64
            or not isFiniteNumber(readyAt)
            or readyAt < 0
            or readyAt % 1 ~= 0
        then
            return false
        end
    end

    return true
end

function ResourceRules.isReady(cooldowns: any, nodeId: any, now: any): boolean
    if
        not ResourceRules.isValidCooldowns(cooldowns)
        or type(nodeId) ~= "string"
        or nodeId == ""
        or not isFiniteNumber(now)
    then
        return false
    end

    return (cooldowns[nodeId] or 0) <= now
end

function ResourceRules.tryGrantReward(
    cooldowns: any,
    nodeId: any,
    now: any,
    readyAt: any,
    grantReward: any
): (boolean, string?)
    if not ResourceRules.isValidCooldowns(cooldowns) then
        return false, "Invalid cooldown state"
    end
    if type(nodeId) ~= "string" or nodeId == "" then
        return false, "Invalid node identifier"
    end
    if not ResourceRules.isReady(cooldowns, nodeId, now) then
        return false, "Node on cooldown"
    end
    if not isFiniteNumber(readyAt) or readyAt < 0 or readyAt % 1 ~= 0 or readyAt <= now then
        return false, "Invalid cooldown timestamp"
    end
    if type(grantReward) ~= "function" then
        return false, "Invalid reward callback"
    end

    local previousReadyAt = cooldowns[nodeId]
    cooldowns[nodeId] = readyAt
    if not grantReward() then
        cooldowns[nodeId] = previousReadyAt
        return false, "Reward rejected"
    end

    return true, nil
end

return ResourceRules
