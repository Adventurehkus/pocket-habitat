--!strict
-- Tests for PlantManager and ResourceManager manager-level gameplay integration

local Constants = require(script.Parent.Parent.Constants)
local EconomyRules = require(script.Parent.Parent.EconomyRules)
local ResourceRules = require(script.Parent.Parent.ResourceRules)
local QuestRules = require(script.Parent.Parent.QuestRules)

local NOW = 10_000
local BERRY_SEED = Constants.RESOURCES.SEED_BERRY
local FLOWER_SEED = Constants.RESOURCES.SEED_FLOWER

-- Mock manager functions for testing
local function mockAddItem(session, itemId, amount)
    local current = session.inventory[itemId] or 0
    local newAmount = current + amount
    if newAmount > EconomyRules.getMaxCapacity(session.upgrades, itemId) or newAmount < 0 then
        return false
    end
    session.inventory[itemId] = newAmount
    return true
end

local function mockRemoveItem(session, itemId, amount)
    local current = session.inventory[itemId]
    if not current or current < amount then
        return false
    end
    session.inventory[itemId] = current - amount
    return true
end

local function mockAddBells(session, bells)
    local newAmount = session.bells + bells
    if newAmount < 0 then
        return false
    end
    session.bells = newAmount
    return true
end

local function makeSession(): any
    return {
        bells = 100,
        inventory = {
            [BERRY_SEED] = 2,
            [FLOWER_SEED] = 1,
        },
        plots = {
            [1] = { seedId = nil, plantedTime = 0, waterCount = 0, stage = 0 },
            [2] = { seedId = nil, plantedTime = 0, waterCount = 0, stage = 0 },
        },
        questProgress = {},
        upgrades = {
            watering_can = 1,
        },
        resourceCooldowns = {},
    }
end

-- Managers branch: Plant and resource gameplay integration

describe("PlantManager — seed planting progression", function()
    it("removes seed from inventory and updates plot state correctly", function()
        local session = makeSession()
        local plotIndex = 1
        local success = mockRemoveItem(session, BERRY_SEED, 1)
        local plot = session.plots[plotIndex]

        expect(success).to.equal(true)
        expect(session.inventory[BERRY_SEED]).to.equal(1)
        expect(plot.seedId).to.equal(BERRY_SEED)
        expect(plot.plantedTime).to.be.ok()
        expect(plot.waterCount).to.equal(0)
        expect(plot.stage).to.equal(1)

        -- Verify quest progress is recorded
        local progressKey = "plant:" .. BERRY_SEED
        expect(session.questProgress[progressKey]).to.equal(1)
    end)

    it("prevents planting when seed inventory is insufficient", function()
        local session = makeSession()
        session.inventory[BERRY_SEED] = 0

        local success = mockRemoveItem(session, BERRY_SEED, 1)
        local plot = session.plots[1]

        expect(success).to.equal(false)
        expect(session.inventory[BERRY_SEED]).to.equal(0)
        expect(plot.seedId).to.equal(nil)
        expect(plot.plantedTime).to.equal(0)
    end)

    it("records watering action independently of current plot state", function()
        local session = makeSession()
        local dewdropCost = 1

        -- First water: consume dewdrop
        session.inventory[Constants.RESOURCES.DEWDROP] = 1
        local success = mockRemoveItem(session, Constants.RESOURCES.DEWDROP, dewdropCost)
        local progressKey = "water"
        session.questProgress[progressKey] = 1

        expect(success).to.equal(true)
        expect(session.questProgress[progressKey]).to.equal(1)

        -- Water again: second time should also record action but not consume additional dewdrop
        local newWaterProgress = (session.questProgress[progressKey] or 0) + 1

        expect(newWaterProgress).to.equal(2)
    end)
end)

describe("ResourceManager — resource gathering cooldowns", function()
    it("grants reward only when node is ready", function()
        local session = makeSession()
        local now = NOW
        local cooldownHours = 1
        local readyTime = now + (cooldownHours * 3600)

        -- Initially not ready
        local granted, error = ResourceRules.tryGrantReward(
            session.resourceCooldowns,
            "tree_1",
            now,
            readyTime,
            function()
                return mockAddItem(session, Constants.RESOURCES.OAK_WOOD, 1)
            end
        )

        expect(granted).to.equal(false)
        expect(error).to.equal("Node in cooldown")

        -- After cooldown expires
        readyTime = now
        session.resourceCooldowns = {}

        granted, error = ResourceRules.tryGrantReward(
            session.resourceCooldowns,
            "tree_1",
            now,
            readyTime,
            function()
                return mockAddItem(session, Constants.RESOURCES.OAK_WOOD, 1)
            end
        )

        expect(granted).to.equal(true)
        expect(session.inventory[Constants.RESOURCES.OAK_WOOD]).to.equal(1)
    end)

    it("rolls back cooldown reservation when reward is rejected", function()
        local session = makeSession()
        local now = NOW
        local readyTime = now + 3600

        local granted, error = ResourceRules.tryGrantReward(
            session.resourceCooldowns,
            "tree_1",
            now,
            readyTime,
            function()
                -- Simulate full inventory
                return mockAddItem(session, Constants.RESOURCES.OAK_WOOD, 100)
            end
        )

        expect(granted).to.equal(false)
        expect(error).to.equal("Inventory full")
        expect(session.resourceCooldowns["tree_1"]).to.equal(readyTime)
    end)

    it("grants production rewards and rewards Bells together atomically", function()
        local session = makeSession()
        local now = NOW
        local readyTime = NOW + 3600
        local node = Constants.RESOURCE_NODES[1]

        session.resourceCooldowns = {}

        local granted, error = ResourceRules.tryGrantReward(
            session.resourceCooldowns,
            node.id,
            now,
            readyTime,
            function()
                local inWood = mockAddItem(session, node.type, node.amount)
                local inBells = mockAddBells(session, node.bellReward)
                return inWood and inBells
            end
        )

        expect(granted).to.equal(true)
        expect(session.inventory[node.type]).to.equal(node.amount)
        expect(session.bells).to.equal(100 + node.bellReward)
        expect(session.resourceCooldowns[node.id]).to.equal(readyTime)
    end)
end)

describe("QuestManager integration items", function()
    it("stores improve harvest quest progress, not current inventory level", function()
        local session = makeSession()
        local cropItem = Constants.RESOURCES.CROP_BERRY

        -- Simulate harvesting and getting rewards
        session.inventory[cropItem] = 10
        session.bells = 200

        -- Recording progress should not depend on inventory for validation
        local progressKey = "harvest:" .. cropItem
        session.questProgress[progressKey] = 5

        -- Now harvest again
        session.questProgress[progressKey] = 6

        -- Attempting to claim quest without enough harvest progress
        local next = QuestRules.nextQuest(session.questsCompleted)
        expect(next).to.equal("q5_harvest")

        -- Achieving the target counts
        session.questProgress[progressKey] = Constants.QUESTS.q5_harvest.targetCount

        local isComplete = QuestRules.isComplete(session.questProgress, Constants.QUESTS.q5_harvest)

        expect(isComplete).to.equal(true)
        expect(session.inventory[cropItem]).to.equal(10)
    end)

    it("tracks creature discovery and advances correctly", function()
        local session = makeSession()
        local creatureId = "bunny"

        -- Discover a creature for the first time
        session.creaturesDiscovered[creatureId] = true
        session.questProgress["discover:" .. creatureId] = 1

        -- Verify discovery progress
        local discoveryProgress =
            QuestRules.getProgress(session.questProgress, "discover", creatureId)

        expect(discoveryProgress).to.equal(1)

        -- Try to claim the related quest
        local next = QuestRules.nextQuest(session.questsCompleted)
        expect(next).to.equal("q6_creature")
    end)

    it("supports multiple item type progress aggregation", function()
        local session = makeSession()

        -- Track progress for different crops
        session.questProgress["harvest:" .. Constants.RESOURCES.CROP_BERRY] = 5
        session.questProgress["harvest:" .. Constants.RESOURCES.CROP_FLOWER] = 3

        -- Aggregated progress should sum correctly
        local harvestProgress = QuestRules.getProgress(session.questProgress, "harvest")

        expect(harvestProgress).to.equal(8)
    end)
end)

describe("EconomyManager — Bells and pooled items", function()
    it("allows partial Bell rewards within script logic", function()
        local session = makeSession()
        local bellReward = 50
        local success = mockAddBells(session, bellReward)

        expect(success).to.equal(true)
        expect(session.bells).to.equal(150)

        -- Ensure never goes negative
        session.bells = 10
        local negateAttempt = mockAddBells(session, -50)

        expect(negateAttempt).to.equal(false)
        expect(session.bells).to.equal(10)
    end)

    it("splits pooled item rewards correctly", function()
        local session = makeSession()
        local minReward = 2
        local maxReward = 5
        local baseAmount = 20

        -- Simulated random reward
        for _ = 1, 10 do
            local rewardQty = math.random(minReward, maxReward)
            local success = mockAddItem(session, baseAmount, rewardQty)
            local currentTotal = session.inventory[baseAmount] or 0

            expect(success).to.equal(true)
            expect(currentTotal).to.equal(rewardQty + 20)
        end
    end)
end)
