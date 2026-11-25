--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))

local CreatureRules = {}

type CreatureCare = {
    fedCount: number,
    totalFeedings: number,
}

type CreatureFriendshipData = {
    friendshipLevel: number,
    friendshipXP: number,
    totalInteractions: number,
    lastInteractionTime: number,
}

type CreatureData = {
    id: string,
    name: string,
    description: string?,
    favoriteFood: string,
    bellReward: number,
    care: CreatureCare?,
    friendship: CreatureFriendshipData?,
}

type CreatureActionResult = {
    success: boolean,
    creature: CreatureData,
    action: string,
    careProgress: number,
    friendshipProgress: number?,
    friendshipLevelUp: boolean?,
    friendshipRewards: { bells: number, items: { [string]: number } }?,
}

local function isFiniteNumber(value: any): boolean
    return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function isInteger(value: any): boolean
    return type(value) == "number"
        and value == value
        and value > -math.huge
        and value < math.huge
        and value % 1 == 0
        and value > 0
end

local function isNonNegativeInteger(value: any): boolean
    return type(value) == "number"
        and value == value
        and value > -math.huge
        and value < math.huge
        and value % 1 == 0
        and value >= 0
end

local function isNonEmptyString(value: any): boolean
    return type(value) == "string" and #value > 0 and #value <= 256
end

local function getCreature(creatureId: any): (CreatureData?, string?)
    if not isNonEmptyString(creatureId) then
        return nil, "Invalid creature ID"
    end

    local creatureDef = Constants.CREATURES[creatureId]
    if not creatureDef then
        return nil, "Creature not found"
    end

    -- Validate creature definition structure
    if
        not isFiniteNumber(creatureDef.bellReward)
        or creatureDef.bellReward < 0
        or creatureDef.bellReward > 1_000_000
    then
        return nil, "Creature has invalid bell reward"
    end

    if not isNonEmptyString(creatureDef.favoriteFood) then
        return nil, "Creature has invalid favorite food"
    end

    return creatureDef, nil
end

local function initializeCreatureData(playerData: any, creatureId: string): CreatureData
    local creature = playerData.creatures[creatureId]
    if
        not creature
        or type(creature) ~= "table"
        or not isNonNegativeInteger(creature.friendshipLevel or 0)
        or not isNonNegativeInteger(creature.friendshipXP or 0)
        or not isNonNegativeInteger(creature.totalInteractions or 0)
        or not isFiniteNumber(creature.lastInteractionTime or 0)
    then
        creature = {
            id = creatureId,
            friendshipLevel = 0,
            friendshipXP = 0,
            totalInteractions = 0,
            lastInteractionTime = 0,
            care = { fedCount = 0, totalFeedings = 0 },
        }
        playerData.creatures[creatureId] = creature
    end
    return creature
end

local function calculateFriendshipRewards(
    newLevel: number
): { bells: number, items: { [string]: number } }?
    local rewards = Constants.CREATURE_FRIENDSHIP.REWARDS
    if rewards and rewards[newLevel] then
        return rewards[newLevel]
    end
    return nil
end

local function addFriendshipXP(
    playerData: any,
    creatureId: string,
    xpAmount: number,
    now: number
): (number?, boolean?, { bells: number, items: { [string]: number } }?)
    local creature = initializeCreatureData(playerData, creatureId)

    local maxLevel = Constants.CREATURE_FRIENDSHIP.MAX_LEVEL
    local xpPerLevel = Constants.CREATURE_FRIENDSHIP.XP_PER_LEVEL

    creature.friendshipXP += xpAmount
    creature.totalInteractions += 1
    creature.lastInteractionTime = now

    local oldLevel = creature.friendshipLevel
    local newLevel = math.min(
        maxLevel,
        math.floor(creature.friendshipXP / xpPerLevel)
            + (creature.friendshipXP % xpPerLevel == 0 and 0 or 1)
    )
    newLevel = math.max(1, newLevel)

    if newLevel > maxLevel then
        newLevel = maxLevel
    end

    creature.friendshipLevel = newLevel

    local leveledUp = newLevel > oldLevel
    local rewards = nil
    if leveledUp then
        rewards = calculateFriendshipRewards(newLevel)
    end

    return newLevel, leveledUp, rewards
end

local function validateFeeding(
    playerData: any,
    creatureId: string,
    now: number?
): (CreatureActionResult?, string?)
    -- Validate player data structure
    if
        type(playerData) ~= "table"
        or type(playerData.creatures) ~= "table"
        or type(playerData.creaturesDiscovered) ~= "table"
        or type(playerData.inventory) ~= "table"
        or type(playerData.bells) ~= "number"
    then
        return nil, "Invalid player data"
    end

    -- Validate creature definition
    local creatureDef, creatureError = getCreature(creatureId)
    if not creatureDef then
        return nil, creatureError or "Invalid creature"
    end

    -- Validate creature ownership/validity
    local discovered = playerData.creaturesDiscovered[creatureId]
    if not isFiniteNumber(discovered) or discovered <= 0 then
        return nil, "Creature not discovered"
    end

    -- Check if creature exists in creatures table
    local creature = playerData.creatures[creatureId]
    if
        not creature
        or type(creature) ~= "table"
        or not creature.care
        or type(creature.care) ~= "table"
        or not isFiniteNumber(creature.care.fedCount or 0)
        or not isFiniteNumber(creature.care.totalFeedings or 0)
    then
        -- Initialize care tracking
        creature = {
            id = creatureId,
            care = { fedCount = 0, totalFeedings = 0 },
        }
        playerData.creatures[creatureId] = creature
    end

    -- Validate now timestamp
    local validationTime = isFiniteNumber(now) and now >= 0
    if not validationTime then
        now = os.time() * 1000
    end

    -- Check if player has favorite food in inventory
    local favoriteFood = creatureDef.favoriteFood
    local foodAmount = playerData.inventory[favoriteFood] or 0

    if not isInteger(foodAmount) or foodAmount <= 0 then
        return nil, "No " .. favoriteFood .. " available"
    end

    -- Validate current feeding interval (minimum 10 minutes between feedings)
    local lastFed = creature.care.lastFed or 0
    local cooldown = Constants.CREATURE_COOLDOWN_MINUTES * 60 * 1000 or 10 * 60 * 1000

    if creature.care.fedCount > 0 and validationTime and now < lastFed + cooldown then
        local remainingCooldown = math.ceil((lastFed + cooldown - now) / 60_000)
        return nil, "Creature feeding on cooldown. " .. remainingCooldown .. " minutes remaining"
    end

    -- Deduct favorite food from inventory
    local newFoodAmount = foodAmount - 1
    playerData.inventory[favoriteFood] = newFoodAmount

    -- Reset food to 0 if negative
    if newFoodAmount < 0 then
        newFoodAmount = 0
    end

    -- Increment care stats
    creature.care.totalFeedings += 1
    creature.care.fedCount += 1
    creature.care.lastFed = now

    -- Add friendship XP for feeding
    local isFavorite = favoriteFood == creatureDef.favoriteFood
    local feedXP = Constants.CREATURE_FRIENDSHIP.FEED_XP
    if isFavorite then
        feedXP += Constants.CREATURE_FRIENDSHIP.FAVORITE_FOOD_BONUS_XP
    end

    local newLevel, leveledUp, rewards = addFriendshipXP(playerData, creatureId, feedXP, now)

    return {
        success = true,
        creature = creatureDef,
        action = "feed",
        careProgress = creature.care.fedCount,
        friendshipProgress = newLevel,
        friendshipLevelUp = leveledUp,
        friendshipRewards = rewards,
    },
        nil
end

local function careForCreature(
    playerData: any,
    creatureId: string,
    action: string,
    now: number?
): (CreatureActionResult?, string?)
    if not isFiniteNumber(now) or now < 0 then
        return nil, "Invalid timestamp"
    end

    local creatureDef, creatureError = getCreature(creatureId)
    if not creatureDef then
        return nil, creatureError or "Invalid creature"
    end

    local creature = playerData.creatures[creatureId]
    if
        not creature
        or type(creature) ~= "table"
        or not creature.care
        or type(creature.care) ~= "table"
        or not isFiniteNumber(creature.care.fedCount or 0)
        or not isFiniteNumber(creature.care.totalFeedings or 0)
    then
        return nil, "Creature not properly initialized"
    end

    local outcome: CreatureActionResult = {
        success = false,
        creature = creatureDef,
        action = action,
    }

    if action == "feed" then
        local result, reason = validateFeeding(playerData, creatureId, now)
        if result then
            outcome.success = true
            outcome.careProgress = result.careProgress
            outcome.friendshipProgress = result.friendshipProgress
            outcome.friendshipLevelUp = result.friendshipLevelUp
            outcome.friendshipRewards = result.friendshipRewards
        else
            outcome.success = false
            return outcome, reason
        end
    elseif action == "care" then
        -- Generic care action for UI interaction (petting)
        -- Add friendship XP for petting
        local petXP = Constants.CREATURE_FRIENDSHIP.PET_XP
        local newLevel, leveledUp, rewards = addFriendshipXP(playerData, creatureId, petXP, now)

        outcome.success = true
        outcome.careProgress = creature.care.fedCount
        outcome.friendshipProgress = newLevel
        outcome.friendshipLevelUp = leveledUp
        outcome.friendshipRewards = rewards
    else
        outcome.success = false
        return outcome, "Invalid action. Use 'feed' or 'care'"
    end

    return outcome, nil
end

function CreatureRules.getCreatureDef(creatureId: any): (CreatureData?, string?)
    return getCreature(creatureId)
end

function CreatureRules.canFeed(playerData: any, creatureId: string): boolean
    local _, reason = validateFeeding(playerData, creatureId, os.time() * 1000)
    local success = reason == nil
    return success
end

function CreatureRules.getCareProgress(playerData: any, creatureId: string): (number?, string?)
    if
        type(playerData) ~= "table"
        or type(playerData.creatures) ~= "table"
        or type(playerData.creatures[creatureId]) ~= "table"
        or not playerData.creatures[creatureId].care
        or type(playerData.creatures[creatureId].care) ~= "table"
    then
        return nil, "Invalid player data or creature"
    end

    local creature = playerData.creatures[creatureId]
    return creature.care.fedCount, nil
end

function CreatureRules.getFriendshipProgress(
    playerData: any,
    creatureId: string
): (number?, number?, string?)
    if
        type(playerData) ~= "table"
        or type(playerData.creatures) ~= "table"
        or type(playerData.creatures[creatureId]) ~= "table"
    then
        return nil, nil, "Invalid player data or creature"
    end

    local creature = playerData.creatures[creatureId]
    if
        not isNonNegativeInteger(creature.friendshipLevel)
        or not isNonNegativeInteger(creature.friendshipXP)
    then
        return nil, nil, "Invalid friendship data"
    end

    return creature.friendshipLevel, creature.friendshipXP, nil
end

function CreatureRules.getFavoriteFood(creatureId: string): (string?, string?)
    local creatureDef, error = getCreature(creatureId)
    if not creatureDef then
        return nil, error or "Invalid creature"
    end
    return creatureDef.favoriteFood, nil
end

function CreatureRules.validateInteraction(
    playerData: any,
    creatureId: string,
    action: string,
    now: number?
): (CreatureActionResult?, string?)
    if type(action) ~= "string" then
        return nil, "Invalid action type"
    end

    return careForCreature(playerData, creatureId, action, now)
end

function CreatureRules.getCreaturesAtFriendshipLevel(
    playerData: any,
    targetLevel: number
): (number?, string?)
    if type(playerData) ~= "table" or type(playerData.creatures) ~= "table" then
        return nil, "Invalid player data"
    end

    if not isNonNegativeInteger(targetLevel) or targetLevel < 1 then
        return nil, "Invalid target level"
    end

    local count = 0
    for _, creature in pairs(playerData.creatures) do
        if
            type(creature) == "table"
            and isNonNegativeInteger(creature.friendshipLevel)
            and creature.friendshipLevel >= targetLevel
        then
            count += 1
        end
    end

    return count, nil
end

function CreatureRules.getTotalFriendshipInteractions(playerData: any): (number?, string?)
    if type(playerData) ~= "table" or type(playerData.creatures) ~= "table" then
        return nil, "Invalid player data"
    end

    local total = 0
    for _, creature in pairs(playerData.creatures) do
        if type(creature) == "table" and isNonNegativeInteger(creature.totalInteractions) then
            total += creature.totalInteractions
        end
    end

    return total, nil
end

-- If creature cooldown constant exists, validate it; otherwise set default
if Constants.CREATURE_COOLDOWN_MINUTES then
    if
        type(Constants.CREATURE_COOLDOWN_MINUTES) ~= "number"
        or Constants.CREATURE_COOLDOWN_MINUTES < 1
    then
        Constants.CREATURE_COOLDOWN_MINUTES = 10
    end
else
    Constants.CREATURE_COOLDOWN_MINUTES = 10
end

return CreatureRules
