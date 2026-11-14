--!strict
-- selene: allow(undefined_variable)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local PlantRules = require(Shared:WaitForChild("PlantRules"))
local EconomyRules = require(Shared:WaitForChild("EconomyRules"))
local ResourceRules = require(Shared:WaitForChild("ResourceRules"))
local QuestRules = require(Shared:WaitForChild("QuestRules"))
local HabitatRules = require(Shared:WaitForChild("HabitatRules"))
local CharacterSpawnData = require(Shared:WaitForChild("CharacterSpawnData"))

local NOW = 10_000
local BERRY_SEED = Constants.RESOURCES.SEED_BERRY
local FLOWER_SEED = Constants.RESOURCES.SEED_FLOWER
local DEWDROP = Constants.RESOURCES.DEWDROP

local function makeData(): any
    return {
        bells = 50,
        inventory = {
            [BERRY_SEED] = 2,
            [FLOWER_SEED] = 1,
            [DEWDROP] = 5,
            [Constants.RESOURCES.WOOD] = 8,
        },
        plots = {
            [1] = { seedId = nil, plantedTime = 0, waterCount = 0, stage = 0 },
            [2] = { seedId = nil, plantedTime = 0, waterCount = 0, stage = 0 },
        },
    }
end

local function validateInteraction(
    data: any,
    plotIndex: any,
    action: any,
    seedId: any?,
    now: any?
): (any, any)
    return PlantRules.validateInteraction(data, plotIndex, action, seedId, now)
end

local function plantBerry(data: any, plotIndex: number): any
    local plot = data.plots[plotIndex]
    plot.seedId = BERRY_SEED
    plot.plantedTime = NOW - Constants.PLANTS.berry.growthTime - 1
    plot.waterCount = Constants.PLANTS.berry.waterNeeded
    plot.stage = 2
    return plot
end

return function()
    describe("PlantRules — server-side plot validation", function()
        it("provides a gatherable seed node for every supported plant", function()
            local seedNodes = {}
            local nodeIds = {}
            for _, node in ipairs(Constants.RESOURCE_NODES) do
                expect(nodeIds[node.id]).to.equal(nil)
                expect(string.lower(node.name)).to.equal(node.id)
                expect(node.amount % 1).to.equal(0)
                expect(node.amount > 0).to.equal(true)
                expect(node.cooldownMinutes > 0).to.equal(true)
                nodeIds[node.id] = true
                seedNodes[node.type] = true
            end

            for plantId, plantDef in pairs(Constants.PLANTS) do
                expect(PlantRules.getPlantDef(plantDef.seedId).id).to.equal(plantId)
                expect(seedNodes[plantDef.seedId]).to.equal(true)
            end
        end)

        it("rejects malformed, fractional, non-positive, and infinite plot indices", function()
            local data = makeData()
            local invalidIndices: { any } = { 0, -1, 1.5, math.huge, -math.huge, 0 / 0, "1" }

            for _, plotIndex in ipairs(invalidIndices) do
                local plan = validateInteraction(data, plotIndex, "plant", BERRY_SEED, NOW)
                expect(plan).to.equal(nil)
            end
        end)

        it("rejects plot indices that do not belong to the player's session", function()
            local plan, reason = validateInteraction(makeData(), 99, "plant", BERRY_SEED, NOW)

            expect(plan).to.equal(nil)
            expect(reason).to.equal("Invalid plot")
        end)

        it("rejects a saved plot index that is not unlocked by the player's upgrades", function()
            local data = makeData()
            data.plots[5] = { seedId = nil, plantedTime = 0, waterCount = 0, stage = 0 }

            local plan, reason = validateInteraction(data, 5, "plant", BERRY_SEED, NOW)

            expect(plan).to.equal(nil)
            expect(reason).to.equal("Invalid plot")
        end)

        it("rejects missing or malformed player session data", function()
            local plan, reason = validateInteraction(nil, 1, "plant", BERRY_SEED, NOW)

            expect(plan).to.equal(nil)
            expect(reason).to.equal("Invalid player data")
        end)

        it("rejects unknown actions and non-string action values", function()
            local data = makeData()
            local unknownPlan, unknownReason =
                validateInteraction(data, 1, "grant_rewards", nil, NOW)
            local malformedPlan = validateInteraction(data, 1, 123, nil, NOW)

            expect(unknownPlan).to.equal(nil)
            expect(unknownReason).to.equal(
                "Invalid action. Use 'plant', 'water', 'harvest', or 'harvest_or_plant'."
            )
            expect(malformedPlan).to.equal(nil)
        end)

        it(
            "accepts a supported seed only when the player owns a positive whole quantity",
            function()
                local data = makeData()
                local validPlan = validateInteraction(data, 1, "plant", BERRY_SEED, NOW)

                expect(validPlan.action).to.equal("plant")
                expect(validPlan.seedId).to.equal(BERRY_SEED)

                data.inventory[BERRY_SEED] = 0
                local emptyPlan, emptyReason =
                    validateInteraction(data, 1, "plant", BERRY_SEED, NOW)
                expect(emptyPlan).to.equal(nil)
                expect(emptyReason).to.equal("No seeds available")

                data.inventory[BERRY_SEED] = 0.5
                local fractionalPlan = validateInteraction(data, 1, "plant", BERRY_SEED, NOW)
                expect(fractionalPlan).to.equal(nil)
            end
        )

        it("rejects unsupported seed identifiers and occupied plots", function()
            local data = makeData()
            local invalidSeedPlan, invalidSeedReason =
                validateInteraction(data, 1, "plant", "admin_seed", NOW)
            expect(invalidSeedPlan).to.equal(nil)
            expect(invalidSeedReason).to.equal("Invalid seed type")

            data.plots[1].seedId = BERRY_SEED
            local occupiedPlan, occupiedReason =
                validateInteraction(data, 1, "plant", BERRY_SEED, NOW)
            expect(occupiedPlan).to.equal(nil)
            expect(occupiedReason).to.equal("Plot already occupied")
        end)

        it("chooses a deterministic owned seed for harvest_or_plant on an empty plot", function()
            local data = makeData()
            data.inventory[BERRY_SEED] = 1
            data.inventory[FLOWER_SEED] = 1

            local plan = validateInteraction(data, 1, "harvest_or_plant", nil, NOW)

            expect(plan.action).to.equal("plant")
            expect(plan.automatic).to.equal(true)
            expect(plan.seedId).to.equal(BERRY_SEED)
        end)

        it("does not automatically plant when no valid seeds are available", function()
            local data = makeData()
            data.inventory[BERRY_SEED] = nil
            data.inventory[FLOWER_SEED] = 0

            local plan, reason = validateInteraction(data, 1, "harvest_or_plant", nil, NOW)

            expect(plan).to.equal(nil)
            expect(reason).to.equal("No seeds available for planting")
        end)

        it("requires a planted valid crop and dewdrops before watering", function()
            local data = makeData()
            local emptyPlan, emptyReason = validateInteraction(data, 1, "water", nil, NOW)
            expect(emptyPlan).to.equal(nil)
            expect(emptyReason).to.equal("Nothing planted here")

            local plot = data.plots[1]
            plot.seedId = BERRY_SEED
            plot.plantedTime = NOW - 5
            plot.waterCount = 0

            data.inventory[DEWDROP] = 0
            local dryPlan, dryReason = validateInteraction(data, 1, "water", nil, NOW)
            expect(dryPlan).to.equal(nil)
            expect(dryReason).to.equal("No dewdrops available")

            data.inventory[DEWDROP] = 1
            local validPlan = validateInteraction(data, 1, "water", nil, NOW)
            expect(validPlan.action).to.equal("water")
            expect(validPlan.plantDef.id).to.equal("berry")
        end)

        it("rejects watering a fully watered or malformed plot", function()
            local data = makeData()
            local plot = data.plots[1]
            plot.seedId = BERRY_SEED
            plot.plantedTime = NOW - 5
            plot.waterCount = Constants.PLANTS.berry.waterNeeded

            local fullPlan, fullReason = validateInteraction(data, 1, "water", nil, NOW)
            expect(fullPlan).to.equal(nil)
            expect(fullReason).to.equal("Already fully watered")

            plot.waterCount = 0.5
            local malformedPlan = validateInteraction(data, 1, "water", nil, NOW)
            expect(malformedPlan).to.equal(nil)
        end)

        it("uses one dewdrop per watering before the watering-can upgrade", function()
            local data = makeData()
            local plot = data.plots[1]
            plot.seedId = BERRY_SEED
            plot.plantedTime = NOW - 5
            plot.waterCount = 0
            data.inventory[DEWDROP] = 1

            local firstWater = validateInteraction(data, 1, "water", nil, NOW)
            expect(firstWater.dewdropCost).to.equal(1)

            plot.waterCount = 1
            data.inventory[DEWDROP] = 0
            local secondWater, reason = validateInteraction(data, 1, "water", nil, NOW)
            expect(secondWater).to.equal(nil)
            expect(reason).to.equal("No dewdrops available")
        end)

        it("charges every second watering at can level two", function()
            local data = makeData()
            local plot = data.plots[1]
            plot.seedId = BERRY_SEED
            plot.plantedTime = NOW - 5
            data.upgrades = { watering_can = 2 }
            data.inventory[DEWDROP] = 1

            local firstWater = validateInteraction(data, 1, "water", nil, NOW)
            expect(firstWater.dewdropCost).to.equal(1)

            plot.waterCount = 1
            data.inventory[DEWDROP] = 0
            local secondWater = validateInteraction(data, 1, "water", nil, NOW)
            expect(secondWater.dewdropCost).to.equal(0)
        end)

        it("charges every third watering at can level three", function()
            local data = makeData()
            local plot = data.plots[1]
            plot.seedId = BERRY_SEED
            plot.plantedTime = NOW - 5
            data.upgrades = { watering_can = 3 }
            data.inventory[DEWDROP] = 1

            expect(validateInteraction(data, 1, "water", nil, NOW).dewdropCost).to.equal(1)
            plot.waterCount = 1
            data.inventory[DEWDROP] = 0
            expect(validateInteraction(data, 1, "water", nil, NOW).dewdropCost).to.equal(0)
            plot.waterCount = 2
            expect(validateInteraction(data, 1, "water", nil, NOW).dewdropCost).to.equal(0)
        end)

        it("rejects an invalid watering-can level", function()
            local data = makeData()
            local plot = data.plots[1]
            plot.seedId = BERRY_SEED
            plot.plantedTime = NOW - 5
            data.upgrades = { watering_can = Constants.UPGRADES.watering_can.maxLevel + 1 }

            local plan, reason = validateInteraction(data, 1, "water", nil, NOW)
            expect(plan).to.equal(nil)
            expect(reason).to.equal("Invalid watering can upgrade")
        end)

        it(
            "rejects malformed upgrade data instead of treating it as the base watering can",
            function()
                local data = makeData()
                data.upgrades = false

                local plan, reason = validateInteraction(data, 1, "water", nil, NOW)
                expect(plan).to.equal(nil)
                expect(reason).to.equal("Invalid player data")
            end
        )

        it(
            "requires both elapsed growth time and the complete water requirement to harvest",
            function()
                local data = makeData()
                local plot = data.plots[1]
                plot.seedId = BERRY_SEED
                plot.plantedTime = NOW - Constants.PLANTS.berry.growthTime - 1
                plot.waterCount = Constants.PLANTS.berry.waterNeeded - 1

                local underWateredPlan, underWateredReason =
                    validateInteraction(data, 1, "harvest", nil, NOW)
                expect(underWateredPlan).to.equal(nil)
                expect(underWateredReason).to.equal("Plant is still growing")

                plot.waterCount = Constants.PLANTS.berry.waterNeeded
                plot.plantedTime = NOW - 1
                local growingPlan, growingReason = validateInteraction(data, 1, "harvest", nil, NOW)
                expect(growingPlan).to.equal(nil)
                expect(growingReason).to.equal("Plant is still growing")
            end
        )

        it(
            "allows harvest only when crop timing, watering, and reward configuration are valid",
            function()
                local data = makeData()
                local plot = plantBerry(data, 1)

                local plan, reason = validateInteraction(data, 1, "harvest", nil, NOW)

                expect(reason).to.equal(nil)
                expect(plan.action).to.equal("harvest")
                expect(plan.plot).to.equal(plot)
                expect(plan.plantDef.id).to.equal("berry")
            end
        )

        it("routes harvest_or_plant to harvest for an occupied, ready plot", function()
            local data = makeData()
            plantBerry(data, 1)

            local plan = validateInteraction(data, 1, "harvest_or_plant", nil, NOW)

            expect(plan.action).to.equal("harvest")
            expect(plan.plantDef.id).to.equal("berry")
        end)

        it("does not allow harvest when plot timestamps or growth state are corrupt", function()
            local data = makeData()
            local plot = plantBerry(data, 1)
            plot.plantedTime = 0 / 0

            local plan = validateInteraction(data, 1, "harvest", nil, NOW)
            expect(plan).to.equal(nil)
        end)
    end)
    describe("ResourceRules — persisted cooldown validation", function()
        it("blocks a node until its saved cooldown expires", function()
            local cooldowns = { tree_1 = NOW + 10 }

            expect(ResourceRules.isReady(cooldowns, "tree_1", NOW)).to.equal(false)
            expect(ResourceRules.isReady(cooldowns, "tree_1", NOW + 10)).to.equal(true)
            expect(ResourceRules.isReady(cooldowns, "tree_2", NOW)).to.equal(true)
        end)

        it("rejects malformed saved cooldown identifiers and timestamps", function()
            expect(ResourceRules.isValidCooldowns({ [""] = NOW })).to.equal(false)
            expect(ResourceRules.isValidCooldowns({ tree_1 = 1.5 })).to.equal(false)
            expect(ResourceRules.isValidCooldowns({ tree_1 = math.huge })).to.equal(false)
            expect(ResourceRules.isValidCooldowns({ tree_1 = -1 })).to.equal(false)
        end)
    end)
    describe("HabitatRules — plot expansion", function()
        it("unlocks one additional plot per purchased expansion level", function()
            expect(HabitatRules.getPlotCount({})).to.equal(4)
            expect(HabitatRules.getPlotCount({ plot_expansion = 2 })).to.equal(5)
            expect(HabitatRules.getPlotCount({ plot_expansion = 4 })).to.equal(7)
        end)

        it("rejects malformed or out-of-range expansion levels and plot indices", function()
            expect(HabitatRules.getPlotCount({ plot_expansion = 5 })).to.equal(nil)
            expect(HabitatRules.getPlotCount({ plot_expansion = 1.5 })).to.equal(nil)
            expect(HabitatRules.getPlotCount({ plot_expansion = false })).to.equal(nil)
            expect(HabitatRules.isPlotIndexUnlocked({}, 4)).to.equal(true)
            expect(HabitatRules.isPlotIndexUnlocked({}, 5)).to.equal(false)
            expect(HabitatRules.isPlotIndexUnlocked({ plot_expansion = 2 }, 5)).to.equal(true)
        end)

        it("preserves excess saved plot state outside the currently unlocked plot set", function()
            local plantedPlot = {
                seedId = BERRY_SEED,
                plantedTime = NOW - 10,
                waterCount = 1,
                stage = 1,
            }
            local active, archived = HabitatRules.partitionPlotData(
                { [1] = makeData().plots[1], [6] = plantedPlot },
                {},
                4
            )

            expect(active[6]).to.equal(nil)
            expect(archived[6].seedId).to.equal(BERRY_SEED)
            expect(archived[6].plantedTime).to.equal(NOW - 10)
            expect(archived[6].waterCount).to.equal(1)
        end)

        it("restores archived plot data when that plot becomes unlocked", function()
            local archivedPlot = { seedId = BERRY_SEED, plantedTime = NOW - 10 }
            local active, archived = HabitatRules.partitionPlotData({}, { [5] = archivedPlot }, 5)

            expect(active[5].seedId).to.equal(BERRY_SEED)
            expect(archived[5]).to.equal(nil)
        end)

        it(
            "rejects duplicate and unrepresentable saved plots without discarding either copy",
            function()
                local active, duplicateError = HabitatRules.partitionPlotData(
                    { [5] = {} },
                    { [5] = {} },
                    5
                )
                local outOfRange, rangeError = HabitatRules.partitionPlotData({ [8] = {} }, {}, 4)

                expect(active).to.equal(nil)
                expect(duplicateError).to.equal("Duplicate plot entry")
                expect(outOfRange).to.equal(nil)
                expect(rangeError).to.equal("Malformed plot entry")
            end
        )
    end)
    describe("QuestRules — server-recorded action progress", function()
        it("uses validated action counters instead of the current inventory", function()
            local progress = {}
            expect(QuestRules.recordProgress(progress, "gather", "wood", 2)).to.equal(true)
            expect(QuestRules.recordProgress(progress, "gather", "wood", 1)).to.equal(true)
            expect(QuestRules.isComplete(progress, {
                targetType = "gather",
                targetItemId = "wood",
                targetCount = 3,
            })).to.equal(true)
            expect(QuestRules.isComplete({}, {
                targetType = "gather",
                targetItemId = "wood",
                targetCount = 3,
            })).to.equal(false)
        end)

        it(
            "aggregates harvest and discovery actions while supporting specific discoveries",
            function()
                local progress = {}
                expect(QuestRules.recordProgress(progress, "harvest", "crop_berry", 2)).to.equal(
                    true
                )
                expect(QuestRules.recordProgress(progress, "harvest", "crop_sunpetal", 1)).to.equal(
                    true
                )
                expect(QuestRules.recordProgress(progress, "discover", "bunny", 1)).to.equal(true)
                expect(QuestRules.recordProgress(progress, "discover", "leafling", 1)).to.equal(
                    true
                )
                expect(QuestRules.getProgress(progress, "harvest")).to.equal(3)
                expect(QuestRules.getProgress(progress, "discover")).to.equal(2)
                expect(QuestRules.getProgress(progress, "discover", "leafling")).to.equal(1)
            end
        )

        it(
            "tracks planted seeds and watering actions independently of current plot state",
            function()
                local progress = {}
                expect(QuestRules.recordProgress(progress, "plant", "seed_berry", 1)).to.equal(true)
                expect(QuestRules.recordProgress(progress, "water", nil, 2)).to.equal(true)
                expect(QuestRules.isComplete(progress, {
                    targetType = "plant",
                    targetItemId = "seed_berry",
                    targetCount = 1,
                })).to.equal(true)
                expect(QuestRules.getProgress(progress, "water")).to.equal(2)
            end
        )

        it("stores upgrade levels as levels rather than cumulative purchase counts", function()
            local progress = {}
            expect(QuestRules.setProgress(progress, "upgrade", "plot_expansion", 2)).to.equal(true)
            expect(QuestRules.setProgress(progress, "upgrade", "plot_expansion", 3)).to.equal(true)

            expect(QuestRules.getProgress(progress, "upgrade", "plot_expansion")).to.equal(3)
        end)

        it("bounds upgrade progress to the defined upgrade level", function()
            local progress = {}

            expect(QuestRules.setProgress(progress, "upgrade", "plot_expansion", 4)).to.equal(false)
            expect(QuestRules.setProgress(progress, "upgrade", "unknown_upgrade", 1)).to.equal(
                false
            )
            expect(QuestRules.isValidProgress({ ["upgrade:plot_expansion"] = 4 })).to.equal(false)
            expect(QuestRules.setProgress(progress, "upgrade", "plot_expansion", 3)).to.equal(true)
        end)

        it("rejects malformed or forged progress values", function()
            local progress = {}
            expect(QuestRules.recordProgress(progress, "harvest", "crop_berry", 0.5)).to.equal(
                false
            )
            expect(QuestRules.recordProgress(progress, "admin", "bells", 100)).to.equal(false)
            expect(QuestRules.isValidProgress({ ["gather:wood"] = -1 })).to.equal(false)
            expect(QuestRules.isValidProgress({ ["gather:wood:extra"] = 1 })).to.equal(false)
            expect(QuestRules.isValidProgress({ ["quest:unknown"] = 1 })).to.equal(false)
            expect(QuestRules.isComplete(progress, {
                targetType = "harvest",
                targetCount = math.huge,
            })).to.equal(false)
        end)
    end)
    describe("QuestRules — complete progression order", function()
        it("reaches all ten defined quests and ends after the final claim", function()
            local completed = {}
            for _, questId in ipairs(Constants.QUEST_ORDER) do
                expect(Constants.QUESTS[questId] ~= nil).to.equal(true)
                expect(QuestRules.nextQuest(completed)).to.equal(questId)
                completed[questId] = true
            end
            expect(QuestRules.nextQuest(completed)).to.equal(nil)
            expect(Constants.QUESTS.q6_creature.rewardItems[Constants.RESOURCES.SEED_SUNPETAL]).to.equal(
                1
            )
            expect(Constants.QUESTS.q9_leafling.targetItemId).to.equal("leafling")
        end)
    end)
    describe("QuestRules — objective validation and atomic claims", function()
        local function makeQuestData(currentQuest: string): any
            local completed = {}
            for _, questId in ipairs(Constants.QUEST_ORDER) do
                if questId == currentQuest then
                    break
                end
                completed[questId] = true
            end
            return {
                bells = 0,
                inventory = {},
                upgrades = {},
                questsCompleted = completed,
                currentQuest = currentQuest,
                questProgress = {},
                creaturesDiscovered = {},
            }
        end

        it("does not claim a harvest quest without a recorded harvest", function()
            local data = makeQuestData("q5_harvest")
            local claimed, reason = QuestRules.tryClaim(data, "q5_harvest")

            expect(claimed).to.equal(false)
            expect(reason).to.equal("Quest objectives not met")
            expect(data.bells).to.equal(0)
            expect(data.questsCompleted.q5_harvest).to.equal(nil)
            expect(data.currentQuest).to.equal("q5_harvest")
        end)

        it("grants the Sun Petal seed and advances exactly once", function()
            local data = makeQuestData("q6_creature")
            data.creaturesDiscovered.bunny = true
            data.questProgress["discover:bunny"] = 1

            expect(QuestRules.tryClaim(data, "q6_creature")).to.equal(true)
            expect(data.inventory[Constants.RESOURCES.SEED_SUNPETAL]).to.equal(1)
            expect(data.bells).to.equal(100)
            expect(data.questsCompleted.q6_creature).to.equal(true)
            expect(data.currentQuest).to.equal("q7_sunpetal")

            expect(QuestRules.tryClaim(data, "q6_creature")).to.equal(false)
            expect(data.inventory[Constants.RESOURCES.SEED_SUNPETAL]).to.equal(1)
            expect(data.bells).to.equal(100)
        end)

        it("leaves a quest unclaimed when its item reward exceeds capacity", function()
            local data = makeQuestData("q6_creature")
            data.creaturesDiscovered.bunny = true
            data.questProgress["discover:bunny"] = 1
            data.inventory[Constants.RESOURCES.WOOD] = 75
            data.upgrades.storage_expansion = 1

            local claimed, reason = QuestRules.tryClaim(data, "q6_creature")

            expect(claimed).to.equal(false)
            expect(reason).to.equal("Inventory full")
            expect(data.inventory[Constants.RESOURCES.SEED_SUNPETAL]).to.equal(nil)
            expect(data.bells).to.equal(0)
            expect(data.currentQuest).to.equal("q6_creature")
        end)

        it("requires the named creature and the actual required upgrade level", function()
            local leaflingData = makeQuestData("q9_leafling")
            leaflingData.creaturesDiscovered.bunny = true
            expect(QuestRules.tryClaim(leaflingData, "q9_leafling")).to.equal(false)
            leaflingData.creaturesDiscovered.leafling = true
            expect(QuestRules.tryClaim(leaflingData, "q9_leafling")).to.equal(true)

            local upgradeData = makeQuestData("q8_owned_plots")
            upgradeData.upgrades.plot_expansion = 2
            expect(QuestRules.tryClaim(upgradeData, "q8_owned_plots")).to.equal(false)
            upgradeData.upgrades.plot_expansion = 3
            expect(QuestRules.tryClaim(upgradeData, "q8_owned_plots")).to.equal(true)
        end)
    end)
    describe("EconomyRules — server inventory reward validation", function()
        it("allows item rewards that fit within the player's current capacity", function()
            local inventory = { [Constants.RESOURCES.WOOD] = 74 }
            local upgrades = { storage_expansion = 1 }
            local allowed, reason =
                EconomyRules.canAddItem(inventory, upgrades, Constants.RESOURCES.CROP_BERRY, 1)

            expect(allowed).to.equal(true)
            expect(reason).to.equal(nil)
        end)

        it("rejects rewards that would exceed inventory capacity", function()
            local inventory = { [Constants.RESOURCES.WOOD] = 75 }
            local upgrades = { storage_expansion = 1 }
            local allowed, reason =
                EconomyRules.canAddItem(inventory, upgrades, Constants.RESOURCES.CROP_BERRY, 1)

            expect(allowed).to.equal(false)
            expect(reason).to.equal("Inventory full")
        end)

        it("uses the player's storage upgrade when calculating capacity", function()
            local inventory = { [Constants.RESOURCES.WOOD] = 99 }
            local upgrades = { storage_expansion = 2 }
            local allowed =
                EconomyRules.canAddItem(inventory, upgrades, Constants.RESOURCES.CROP_BERRY, 1)
            local denied, reason =
                EconomyRules.canAddItem(inventory, upgrades, Constants.RESOURCES.CROP_BERRY, 2)

            expect(allowed).to.equal(true)
            expect(denied).to.equal(false)
            expect(reason).to.equal("Inventory full")
        end)

        it(
            "rejects malformed item identifiers, quantities, inventory, and upgrade state",
            function()
                local upgrades = { storage_expansion = 1 }
                local badItem = EconomyRules.canAddItem({}, upgrades, "", 1)
                local badAmount = EconomyRules.canAddItem({}, upgrades, "crop_berry", 0.5)
                local badInventory =
                    EconomyRules.canAddItem({ wood = -1 }, upgrades, "crop_berry", 1)
                local badUpgrade = EconomyRules.canAddItem(
                    {},
                    { storage_expansion = 0 },
                    "crop_berry",
                    1
                )

                expect(badItem).to.equal(false)
                expect(badAmount).to.equal(false)
                expect(badInventory).to.equal(false)
                expect(badUpgrade).to.equal(false)
            end
        )
        it("rolls back a production cooldown reservation when the reward is rejected", function()
            local cooldowns = { tree_1 = NOW - 1 }
            local rewardCalls = 0

            local granted, reason = ResourceRules.tryGrantReward(
                cooldowns,
                "tree_1",
                NOW,
                NOW + 60,
                function()
                    rewardCalls += 1
                    return false
                end
            )

            expect(granted).to.equal(false)
            expect(reason).to.equal("Reward rejected")
            expect(rewardCalls).to.equal(1)
            expect(cooldowns.tree_1).to.equal(NOW - 1)
        end)

        it("does not grant a reward or reserve a cooldown for a cooling-down node", function()
            local cooldowns = { tree_1 = NOW + 10 }
            local rewardCalls = 0

            local granted = ResourceRules.tryGrantReward(
                cooldowns,
                "tree_1",
                NOW,
                NOW + 60,
                function()
                    rewardCalls += 1
                    return true
                end
            )

            expect(granted).to.equal(false)
            expect(rewardCalls).to.equal(0)
            expect(cooldowns.tree_1).to.equal(NOW + 10)
        end)
    end)
    describe("CharacterSpawnData — spawn serialization", function()
        it("encodes Vector3 coordinates as a numeric table", function()
            local serialized = CharacterSpawnData.encodeVector3(Vector3.new(1, 2, 3))

            expect(type(serialized)).to.equal("table")
            expect(serialized.x).to.equal(1)
            expect(serialized.y).to.equal(2)
            expect(serialized.z).to.equal(3)
        end)
    end)
end
