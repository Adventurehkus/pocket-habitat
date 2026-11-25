--!strict
local CreatureRules = require(script.Parent.Parent.CreatureRules)
local Constants = require(script.Parent.Parent.Constants)

describe("CreatureRules — feeding and care mechanics", function()
    local function makePlayerData()
        return {
            bells = 100,
            inventory = {},
            creatures = {},
            creaturesDiscovered = {},
            questProgress = {},
            questsCompleted = {},
            currentQuest = "q1_gather",
        }
    end

    it("prevents feeding undiscovered creature", function()
        local data = makePlayerData()
        local success, reason =
            CreatureRules.validateInteraction(data, "bunny", "feed", os.time() * 1000)
        expect(success).to.equal(false)
        expect(reason).to.equal("Creature not discovered")
    end)

    it("prevents feeding without favorite food", function()
        local data = makePlayerData()
        data.creaturesDiscovered["bunny"] = true

        local success, reason =
            CreatureRules.validateInteraction(data, "bunny", "feed", os.time() * 1000)
        expect(success).to.equal(false)
        expect(reason).to.equal("No crop_berry available")
    end)

    it("prevents feeding too frequently (cooldown violation)", function()
        local data = makePlayerData()
        data.creaturesDiscovered["bunny"] = true
        data.inventory = {}
        for _, creature in pairs(Constants.CREATURES) do
            data.inventory[creature.favoriteFood] = math.random(3, 10)
        end

        local success, reason =
            CreatureRules.validateInteraction(data, "bunny", "feed", os.time() * 1000)
        expect(success).to.equal(true)

        success, reason = CreatureRules.validateInteraction(data, "bunny", "feed", os.time() * 1000)
        expect(success).to.equal(false)
        expect(string.find(reason, "cooldown") ~= nil).to.equal(true)
    end)

    it("delivers favorite food on successful feeding", function()
        local data = makePlayerData()
        data.creaturesDiscovered["bunny"] = true
        data.inventory["crop_berry"] = 10

        local success, _ =
            CreatureRules.validateInteraction(data, "bunny", "feed", os.time() * 1000)
        expect(success).to.equal(true)
    end)

    it("tracks creature care progress", function()
        local data = makePlayerData()
        data.creaturesDiscovered["bunny"] = true
        data.inventory["crop_berry"] = 10

        local success, action =
            CreatureRules.validateInteraction(data, "bunny", "feed", os.time() * 1000)
        expect(success).to.equal(true)
        expect(action.action).to.equal("feed")
        expect(action.careProgress).to.equal(1)

        local newTime = os.time() * 1000 + 600_001
        success, action = CreatureRules.validateInteraction(data, "bunny", "feed", newTime)
        expect(success).to.equal(true)
        expect(action.careProgress).to.equal(2)
    end)

    it("prevents invalid creature ID", function()
        local data = makePlayerData()
        data.creaturesDiscovered["invalid_creature"] = true
        data.inventory = {}

        local success, reason =
            CreatureRules.validateInteraction(data, "invalid_creature", "feed", os.time() * 1000)
        expect(success).to.equal(false)
        expect(string.find(reason, "Creature not found") ~= nil).to.equal(true)
    end)

    it("allows generic care action", function()
        local data = makePlayerData()
        data.creaturesDiscovered["bunny"] = true

        local success, action =
            CreatureRules.validateInteraction(data, "bunny", "care", os.time() * 1000)
        expect(success).to.equal(true)
        expect(action.success).to.equal(true)
        expect(action.action).to.equal("care")
    end)

    it("rejects invalid action type", function()
        local data = makePlayerData()
        data.creaturesDiscovered["bunny"] = true
        data.inventory = {}

        local success, reason =
            CreatureRules.validateInteraction(data, "bunny", "invalid_action", os.time() * 1000)
        expect(success).to.equal(false)
        expect(reason).to.equal("Invalid action. Use 'feed' or 'care'")
    end)

    it("validates creature definition structure", function()
        local _, userError = CreatureRules.getCreatureDef("invalid_creature")
        expect(userError).to.equal("Creature not found")
    end)

    it("returns creature favorite food correctly", function()
        local favoriteFood, _ = CreatureRules.getFavoriteFood("bunny")
        expect(favoriteFood).to.equal("crop_berry")

        favoriteFood, _ = CreatureRules.getFavoriteFood("sprite")
        expect(favoriteFood).to.equal("dewdrop")
    end)
end)

describe("CreatureRules — friendship progression system", function()
    local function makePlayerData()
        return {
            bells = 100,
            inventory = {},
            creatures = {},
            creaturesDiscovered = {},
            questProgress = {},
            questsCompleted = {},
            currentQuest = "q1_gather",
        }
    end

    local function setupDiscoveredCreature(data: any, creatureId: string, foodAmount: number?)
        data.creaturesDiscovered[creatureId] = true
        local creatureDef = Constants.CREATURES[creatureId]
        if creatureDef and foodAmount then
            data.inventory[creatureDef.favoriteFood] = foodAmount
        end
    end

    it("initializes friendship data on first interaction", function()
        local data = makePlayerData()
        setupDiscoveredCreature(data, "bunny", 10)

        local success, action =
            CreatureRules.validateInteraction(data, "bunny", "care", os.time() * 1000)
        expect(success).to.equal(true)
        expect(action.friendshipProgress).to.equal(1)
        expect(action.friendshipLevelUp).to.equal(false)
        expect(data.creatures.bunny.friendshipLevel).to.equal(1)
        expect(data.creatures.bunny.friendshipXP).to.equal(Constants.CREATURE_FRIENDSHIP.PET_XP)
        expect(data.creatures.bunny.totalInteractions).to.equal(1)
    end)

    it("grants friendship XP for petting (care action)", function()
        local data = makePlayerData()
        setupDiscoveredCreature(data, "bunny", 10)

        local petXP = Constants.CREATURE_FRIENDSHIP.PET_XP
        local xpPerLevel = Constants.CREATURE_FRIENDSHIP.XP_PER_LEVEL

        for i = 1, math.ceil(xpPerLevel / petXP) do
            local success, action = CreatureRules.validateInteraction(
                data,
                "bunny",
                "care",
                os.time() * 1000 + i * 1000
            )
            expect(success).to.equal(true)
            expect(action.friendshipProgress).to.be.ok()
        end

        expect(data.creatures.bunny.friendshipLevel).to.be.greaterThanOrEqual(1)
        expect(data.creatures.bunny.totalInteractions).to.be.greaterThanOrEqual(1)
    end)

    it("grants more friendship XP for feeding than petting", function()
        local data = makePlayerData()
        setupDiscoveredCreature(data, "bunny", 10)

        local petResult = CreatureRules.validateInteraction(data, "bunny", "care", os.time() * 1000)
        local petXP = data.creatures.bunny.friendshipXP

        data.creatures.bunny.friendshipXP = 0
        data.creatures.bunny.friendshipLevel = 0
        data.creatures.bunny.totalInteractions = 0
        data.inventory["crop_berry"] = 10

        local feedResult =
            CreatureRules.validateInteraction(data, "bunny", "feed", os.time() * 1000 + 1000)
        local feedXP = data.creatures.bunny.friendshipXP

        expect(feedXP).to.be.greaterThan(petXP)
    end)

    it("grants bonus XP for favorite food", function()
        local data = makePlayerData()
        setupDiscoveredCreature(data, "bunny", 10)

        -- Feed with non-favorite food (dewdrop) - but bunny's favorite is crop_berry
        -- Actually test with favorite food vs... well, feed only works with favorite food
        -- So this test verifies the favorite food bonus is included
        local feedResult =
            CreatureRules.validateInteraction(data, "bunny", "feed", os.time() * 1000)
        local feedXP = data.creatures.bunny.friendshipXP

        -- Expected: FEED_XP + FAVORITE_FOOD_BONUS_XP = 15 + 10 = 25
        expect(feedXP).to.equal(
            Constants.CREATURE_FRIENDSHIP.FEED_XP
                + Constants.CREATURE_FRIENDSHIP.FAVORITE_FOOD_BONUS_XP
        )
    end)

    it("levels up friendship and grants rewards", function()
        local data = makePlayerData()
        setupDiscoveredCreature(data, "bunny", 100) -- Lots of food

        local xpPerLevel = Constants.CREATURE_FRIENDSHIP.XP_PER_LEVEL
        local feedXP = Constants.CREATURE_FRIENDSHIP.FEED_XP
            + Constants.CREATURE_FRIENDSHIP.FAVORITE_FOOD_BONUS_XP
        local feedsNeeded = math.ceil(xpPerLevel / feedXP) + 1

        local leveledUp = false
        for i = 1, feedsNeeded do
            local newTime = os.time() * 1000 + i * 600_001 -- Past cooldown
            local success, action =
                CreatureRules.validateInteraction(data, "bunny", "feed", newTime)
            expect(success).to.equal(true)
            if action.friendshipLevelUp then
                leveledUp = true
                expect(action.friendshipRewards).to.be.ok()
                expect(action.friendshipRewards.bells).to.equal(
                    Constants.CREATURE_FRIENDSHIP.REWARDS[2].bells
                )
                break
            end
        end

        expect(leveledUp).to.equal(true)
        expect(data.creatures.bunny.friendshipLevel).to.equal(2)
    end)

    it("caps friendship at MAX_LEVEL", function()
        local data = makePlayerData()
        setupDiscoveredCreature(data, "bunny", 1000)

        local maxLevel = Constants.CREATURE_FRIENDSHIP.MAX_LEVEL
        -- Pre-set to one below max
        data.creatures.bunny = {
            friendshipLevel = maxLevel - 1,
            friendshipXP = (maxLevel - 1) * Constants.CREATURE_FRIENDSHIP.XP_PER_LEVEL,
            totalInteractions = 0,
            lastInteractionTime = 0,
            care = { fedCount = 0, totalFeedings = 0 },
        }

        -- Feed enough to reach max
        for i = 1, 10 do
            local newTime = os.time() * 1000 + i * 600_001
            local success, action =
                CreatureRules.validateInteraction(data, "bunny", "feed", newTime)
            if not success then
                break
            end
        end

        expect(data.creatures.bunny.friendshipLevel).to.equal(maxLevel)
        expect(data.creatures.bunny.friendshipLevel).to.never.be.greaterThan(maxLevel)
    end)

    it("tracks friendship progress correctly via getFriendshipProgress", function()
        local data = makePlayerData()
        setupDiscoveredCreature(data, "bunny", 10)

        local level, xp, err = CreatureRules.getFriendshipProgress(data, "bunny")
        expect(err).to.equal(nil)
        expect(level).to.equal(0)
        expect(xp).to.equal(0)

        CreatureRules.validateInteraction(data, "bunny", "care", os.time() * 1000)

        level, xp, err = CreatureRules.getFriendshipProgress(data, "bunny")
        expect(err).to.equal(nil)
        expect(level).to.equal(1)
        expect(xp).to.equal(Constants.CREATURE_FRIENDSHIP.PET_XP)
    end)

    it("returns error for undiscovered creature friendship query", function()
        local data = makePlayerData()
        data.creaturesDiscovered["bunny"] = false

        local level, xp, err = CreatureRules.getFriendshipProgress(data, "bunny")
        expect(err).to.equal("Invalid player data or creature")
    end)

    it("counts creatures at friendship level correctly", function()
        local data = makePlayerData()
        setupDiscoveredCreature(data, "bunny", 10)
        setupDiscoveredCreature(data, "sprite", 10)
        setupDiscoveredCreature(data, "leafling", 10)

        -- All start at level 0
        local count, err = CreatureRules.getCreaturesAtFriendshipLevel(data, 1)
        expect(err).to.equal(nil)
        expect(count).to.equal(0)

        -- Level up bunny to level 2
        data.creatures.bunny = {
            friendshipLevel = 2,
            friendshipXP = 200,
            totalInteractions = 5,
            lastInteractionTime = os.time() * 1000,
            care = { fedCount = 5, totalFeedings = 5 },
        }

        count, err = CreatureRules.getCreaturesAtFriendshipLevel(data, 1)
        expect(count).to.equal(1) -- Only bunny at level 1+

        count, err = CreatureRules.getCreaturesAtFriendshipLevel(data, 2)
        expect(count).to.equal(1) -- Only bunny at level 2+

        count, err = CreatureRules.getCreaturesAtFriendshipLevel(data, 3)
        expect(count).to.equal(0)
    end)

    it("rejects invalid target level for getCreaturesAtFriendshipLevel", function()
        local data = makePlayerData()

        local count, err = CreatureRules.getCreaturesAtFriendshipLevel(data, 0)
        expect(err).to.equal("Invalid target level")

        count, err = CreatureRules.getCreaturesAtFriendshipLevel(data, -1)
        expect(err).to.equal("Invalid target level")

        count, err = CreatureRules.getCreaturesAtFriendshipLevel(data, 1.5)
        expect(err).to.equal("Invalid target level")
    end)

    it("tracks total interactions across all creatures", function()
        local data = makePlayerData()
        setupDiscoveredCreature(data, "bunny", 10)
        setupDiscoveredCreature(data, "sprite", 10)

        local total, err = CreatureRules.getTotalFriendshipInteractions(data)
        expect(total).to.equal(0)

        CreatureRules.validateInteraction(data, "bunny", "care", os.time() * 1000)
        CreatureRules.validateInteraction(data, "bunny", "care", os.time() * 1000 + 1000)
        CreatureRules.validateInteraction(data, "sprite", "care", os.time() * 1000 + 2000)

        total, err = CreatureRules.getTotalFriendshipInteractions(data)
        expect(total).to.equal(3)
    end)

    it("initializes creature data with care and friendship tables", function()
        local data = makePlayerData()
        setupDiscoveredCreature(data, "bunny", 10)

        CreatureRules.validateInteraction(data, "bunny", "care", os.time() * 1000)

        local creature = data.creatures.bunny
        expect(creature.care).to.be.ok()
        expect(creature.care.fedCount).to.equal(0)
        expect(creature.care.totalFeedings).to.equal(0)
        expect(creature.friendshipLevel).to.equal(1)
        expect(creature.friendshipXP).to.equal(Constants.CREATURE_FRIENDSHIP.PET_XP)
        expect(creature.totalInteractions).to.equal(1)
    end)

    it("handles multiple creatures independently", function()
        local data = makePlayerData()
        setupDiscoveredCreature(data, "bunny", 10)
        setupDiscoveredCreature(data, "sprite", 10)

        -- Pet bunny 5 times
        for i = 1, 5 do
            CreatureRules.validateInteraction(data, "bunny", "care", os.time() * 1000 + i * 1000)
        end

        -- Pet sprite 2 times
        for i = 1, 2 do
            CreatureRules.validateInteraction(data, "sprite", "care", os.time() * 1000 + i * 1000)
        end

        expect(data.creatures.bunny.friendshipLevel).to.be.greaterThan(
            data.creatures.sprite.friendshipLevel
        )
        expect(data.creatures.bunny.totalInteractions).to.equal(5)
        expect(data.creatures.sprite.totalInteractions).to.equal(2)
    end)
end)
