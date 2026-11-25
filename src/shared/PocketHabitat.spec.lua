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

        it("supports the seed-to-harvest rules for every defined plant", function()
            for plantId, plantDef in pairs(Constants.PLANTS) do
                local plot = { seedId = nil, plantedTime = 0, waterCount = 0, stage = 0 }
                local data = {
                    inventory = {
                        [plantDef.seedId] = 1,
                        [DEWDROP] = plantDef.waterNeeded,
                    },
                    plots = { [1] = plot },
                    upgrades = {},
                }

                local planting = validateInteraction(data, 1, "plant", plantDef.seedId, NOW)
                expect(planting.action).to.equal("plant")
                expect(planting.plantDef.id).to.equal(plantId)
                plot.seedId = planting.seedId
                plot.plantedTime = NOW - plantDef.growthTime
                data.inventory[plantDef.seedId] -= 1

                while plot.waterCount < plantDef.waterNeeded do
                    local watering = validateInteraction(data, 1, "water", nil, NOW)
                    expect(watering.action).to.equal("water")
                    expect(watering.dewdropCost).to.equal(1)
                    data.inventory[DEWDROP] -= watering.dewdropCost
                    plot.waterCount += 1
                end

                local growing = validateInteraction(data, 1, "harvest", nil, NOW - 1)
                expect(growing).to.equal(nil)

                local harvest = validateInteraction(data, 1, "harvest", nil, NOW)
                expect(harvest.action).to.equal("harvest")
                expect(harvest.plantDef.id).to.equal(plantId)
                expect(harvest.plantDef.harvestReward.itemId).to.equal(
                    Constants.RESOURCES["CROP_" .. string.upper(plantId)]
                )
            end
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
    describe("Creature movement profiles", function()
        it("defines a unique valid movement profile for each creature", function()
            local seenModes = {}
            local creatureCount = 0

            for _, creatureDef in pairs(Constants.CREATURES) do
                local behavior = creatureDef.behavior
                creatureCount += 1

                expect(type(behavior)).to.equal("table")
                expect(type(behavior.mode)).to.equal("string")
                expect(seenModes[behavior.mode]).to.equal(nil)
                seenModes[behavior.mode] = true

                expect(behavior.moveInterval > 0 and behavior.moveInterval % 1 == 0).to.equal(true)
                expect(behavior.wanderRadius > 0 and behavior.wanderRadius % 1 == 0).to.equal(true)
                expect(
                    behavior.jumpInterval == nil
                        or (behavior.jumpInterval > 0 and behavior.jumpInterval % 1 == 0)
                ).to.equal(true)
                expect(behavior.hoverHeight == nil or behavior.hoverHeight > 0).to.equal(true)
            end

            local modeCount = 0
            for _ in pairs(seenModes) do
                modeCount += 1
            end
            expect(modeCount).to.equal(creatureCount)
        end)
    end)

    describe("ResourceRules — cooldown transaction edge cases", function()
        it("validates readyAt timestamp must be strictly greater than now", function()
            local cooldowns = { tree_1 = NOW - 10 }
            local granted = ResourceRules.tryGrantReward(
                cooldowns,
                "tree_1",
                NOW,
                NOW, -- readyAt == now should fail
                function()
                    return true
                end
            )
            expect(granted).to.equal(false)
        end)

        it("rejects negative cooldown timestamps", function()
            local cooldowns = {}
            local granted = ResourceRules.tryGrantReward(cooldowns, "tree_1", NOW, -1, function()
                return true
            end)
            expect(granted).to.equal(false)
        end)

        it("rejects non-integer cooldown timestamps", function()
            local cooldowns = {}
            local granted = ResourceRules.tryGrantReward(
                cooldowns,
                "tree_1",
                NOW,
                NOW + 1.5,
                function()
                    return true
                end
            )
            expect(granted).to.equal(false)
        end)

        it("rejects infinite cooldown timestamps", function()
            local cooldowns = {}
            local granted = ResourceRules.tryGrantReward(
                cooldowns,
                "tree_1",
                NOW,
                math.huge,
                function()
                    return true
                end
            )
            expect(granted).to.equal(false)
        end)

        it("rejects non-function reward callbacks", function()
            local cooldowns = {}
            local granted = ResourceRules.tryGrantReward(
                cooldowns,
                "tree_1",
                NOW,
                NOW + 60,
                "not a function" :: any
            )
            expect(granted).to.equal(false)
        end)

        it("rejects nil reward callbacks", function()
            local cooldowns = {}
            local granted = ResourceRules.tryGrantReward(cooldowns, "tree_1", NOW, NOW + 60, nil)
            expect(granted).to.equal(false)
        end)

        it("handles multiple different node cooldowns independently", function()
            local cooldowns = { tree_1 = NOW + 10, rock_1 = NOW - 5 }
            expect(ResourceRules.isReady(cooldowns, "tree_1", NOW)).to.equal(false)
            expect(ResourceRules.isReady(cooldowns, "rock_1", NOW)).to.equal(true)
        end)

        it("validates cooldown map with empty string key is invalid", function()
            expect(ResourceRules.isValidCooldowns({ [""] = NOW })).to.equal(false)
        end)
    end)

    describe("EconomyRules — capacity edge cases", function()
        it("calculates base capacity correctly at level 1", function()
            local inventory = {}
            local upgrades = { storage_expansion = 1 }
            local maxCapacity = 50 + 1 * 25
            local allowed = EconomyRules.canAddItem(inventory, upgrades, "test", maxCapacity)
            expect(allowed).to.equal(true)

            local denied = EconomyRules.canAddItem(inventory, upgrades, "test", maxCapacity + 1)
            expect(denied).to.equal(false)
        end)

        it("calculates capacity correctly at max storage level 3", function()
            local inventory = {}
            local upgrades = { storage_expansion = 3 }
            local maxCapacity = 50 + 3 * 25
            local allowed = EconomyRules.canAddItem(inventory, upgrades, "test", maxCapacity)
            expect(allowed).to.equal(true)

            local denied = EconomyRules.canAddItem(inventory, upgrades, "test", maxCapacity + 1)
            expect(denied).to.equal(false)
        end)

        it("accounts for existing items when checking capacity", function()
            local inventory = { wood = 60 }
            local upgrades = { storage_expansion = 1 } -- 75 capacity
            local allowed = EconomyRules.canAddItem(inventory, upgrades, "stone", 10) -- 60 + 10 = 70 <= 75
            expect(allowed).to.equal(true)

            local denied = EconomyRules.canAddItem(inventory, upgrades, "stone", 20) -- 60 + 20 = 80 > 75
            expect(denied).to.equal(false)
        end)

        it("rejects non-integer quantities in inventory", function()
            local inventory = { wood = 1.5 }
            local upgrades = { storage_expansion = 1 }
            local allowed = EconomyRules.canAddItem(inventory, upgrades, "stone", 1)
            expect(allowed).to.equal(false)
        end)

        it("rejects negative quantities in inventory", function()
            local inventory = { wood = -5 }
            local upgrades = { storage_expansion = 1 }
            local allowed = EconomyRules.canAddItem(inventory, upgrades, "stone", 1)
            expect(allowed).to.equal(false)
        end)

        it("rejects non-integer storage upgrade levels", function()
            local inventory = {}
            local upgrades = { storage_expansion = 1.5 }
            local allowed = EconomyRules.canAddItem(inventory, upgrades, "stone", 1)
            expect(allowed).to.equal(false)
        end)

        it("rejects storage upgrade level 0", function()
            local inventory = {}
            local upgrades = { storage_expansion = 0 }
            local allowed = EconomyRules.canAddItem(inventory, upgrades, "stone", 1)
            expect(allowed).to.equal(false)
        end)

        it("rejects negative storage upgrade levels", function()
            local inventory = {}
            local upgrades = { storage_expansion = -1 }
            local allowed = EconomyRules.canAddItem(inventory, upgrades, "stone", 1)
            expect(allowed).to.equal(false)
        end)

        it("handles very large item amounts without overflow", function()
            local inventory = {}
            local upgrades = { storage_expansion = 3 }
            local allowed = EconomyRules.canAddItem(inventory, upgrades, "test", 1000000)
            expect(allowed).to.equal(false)
        end)
    end)

    describe("QuestRules — progress aggregation and validation", function()
        it("correctly aggregates harvest progress across different crop types", function()
            local progress = {}
            QuestRules.recordProgress(progress, "harvest", "crop_berry", 2)
            QuestRules.recordProgress(progress, "harvest", "crop_flower", 3)
            QuestRules.recordProgress(progress, "harvest", "crop_sunpetal", 1)

            expect(QuestRules.getProgress(progress, "harvest")).to.equal(6)
            expect(QuestRules.getProgress(progress, "harvest", "crop_berry")).to.equal(2)
            expect(QuestRules.getProgress(progress, "harvest", "crop_flower")).to.equal(3)
        end)

        it("handles discover progress with specific and aggregate counts", function()
            local progress = {}
            QuestRules.recordProgress(progress, "discover", "bunny", 1)
            QuestRules.recordProgress(progress, "discover", "sprite", 1)
            QuestRules.recordProgress(progress, "discover", "leafling", 1)
            QuestRules.recordProgress(progress, "discover", "tortoise", 1)
            QuestRules.recordProgress(progress, "discover", "finch", 1)

            expect(QuestRules.getProgress(progress, "discover")).to.equal(5)
            expect(QuestRules.getProgress(progress, "discover", "bunny")).to.equal(1)
        end)

        it("rejects progress with non-integer amounts", function()
            local progress = {}
            expect(QuestRules.recordProgress(progress, "gather", "wood", 1.5)).to.equal(false)
            expect(QuestRules.recordProgress(progress, "gather", "wood", -1)).to.equal(false)
        end)

        it("rejects progress with zero amount for positive-only targets", function()
            local progress = {}
            expect(QuestRules.recordProgress(progress, "gather", "wood", 0)).to.equal(false)
        end)

        it("validates upgrade progress against max level for all upgrades", function()
            local progress = {}
            for upgradeId, upgradeDef in pairs(Constants.UPGRADES) do
                expect(QuestRules.setProgress(progress, "upgrade", upgradeId, upgradeDef.maxLevel)).to.equal(
                    true
                )
                expect(
                    QuestRules.setProgress(progress, "upgrade", upgradeId, upgradeDef.maxLevel + 1)
                ).to.equal(false)
            end
        end)

        it("rejects unknown upgrade IDs", function()
            local progress = {}
            expect(QuestRules.setProgress(progress, "upgrade", "nonexistent", 1)).to.equal(false)
            expect(QuestRules.setProgress(progress, "upgrade", "", 1)).to.equal(false)
        end)

        it("isComplete returns false for progress on non-existent target", function()
            local progress = { ["gather:wood"] = 5 }
            expect(QuestRules.isComplete(progress, {
                targetType = "gather",
                targetItemId = "nonexistent",
                targetCount = 1,
            })).to.equal(false)
        end)
    end)

    describe("QuestRules — quest completion and ordering", function()
        it("validates all quest definitions have required fields", function()
            for _, questId in ipairs(Constants.QUEST_ORDER) do
                local quest = Constants.QUESTS[questId]
                expect(quest).to.be.ok()
                expect(type(quest.id)).to.equal("string")
                expect(type(quest.title)).to.equal("string")
                expect(type(quest.description)).to.equal("string")
                expect(type(quest.targetType)).to.equal("string")
                expect(QuestRules.validTargets[quest.targetType]).to.equal(true)
                expect(type(quest.targetCount)).to.equal("number")
                expect(quest.targetCount > 0).to.equal(true)
                expect(type(quest.rewardBells)).to.equal("number")
                expect(quest.rewardBells >= 0).to.equal(true)
            end
        end)

        it("q6_creature grants sunpetal seed as item reward", function()
            local quest = Constants.QUESTS.q6_creature
            expect(quest.rewardItems).to.be.ok()
            expect(quest.rewardItems[Constants.RESOURCES.SEED_SUNPETAL]).to.equal(1)
        end)

        it("quest order progresses through all ten quests sequentially", function()
            local completed = {}
            local previousQuest = nil
            for _, questId in ipairs(Constants.QUEST_ORDER) do
                local currentQuest = QuestRules.nextQuest(completed)
                expect(currentQuest).to.equal(questId)
                if previousQuest then
                    completed[previousQuest] = true
                end
                previousQuest = questId
            end
            expect(QuestRules.nextQuest(completed)).to.equal(nil)
        end)
    end)

    describe("HabitatRules — plot expansion edge cases", function()
        it("returns nil for malformed upgrades table", function()
            expect(HabitatRules.getPlotCount(nil)).to.equal(nil)
            expect(HabitatRules.getPlotCount("not a table")).to.equal(nil)
            expect(HabitatRules.getPlotCount(123)).to.equal(nil)
        end)

        it("handles missing plot_expansion key as level 1", function()
            expect(HabitatRules.getPlotCount({})).to.equal(4)
            expect(HabitatRules.getPlotCount({ other_upgrade = 1 })).to.equal(4)
        end)

        it("validates plot index bounds correctly based on upgrades", function()
            -- Initial level 1: 4 plots
            expect(HabitatRules.isPlotIndexUnlocked({ plot_expansion = 1 }, 1)).to.equal(true)
            expect(HabitatRules.isPlotIndexUnlocked({ plot_expansion = 1 }, 4)).to.equal(true)
            expect(HabitatRules.isPlotIndexUnlocked({ plot_expansion = 1 }, 5)).to.equal(false)

            -- Level 2: 5 plots
            expect(HabitatRules.isPlotIndexUnlocked({ plot_expansion = 2 }, 5)).to.equal(true)
            expect(HabitatRules.isPlotIndexUnlocked({ plot_expansion = 2 }, 6)).to.equal(false)

            -- Level 3: 6 plots
            expect(HabitatRules.isPlotIndexUnlocked({ plot_expansion = 3 }, 6)).to.equal(true)
            expect(HabitatRules.isPlotIndexUnlocked({ plot_expansion = 3 }, 7)).to.equal(false)
        end)

        it("handles fractional plot indices", function()
            expect(HabitatRules.isPlotIndexUnlocked({}, 1.5)).to.equal(false)
            expect(HabitatRules.isPlotIndexUnlocked({}, 2.0)).to.equal(true)
        end)

        it("partitionPlotData rejects indices beyond max supported", function()
            local active, _, err = HabitatRules.partitionPlotData({ [8] = {} }, {}, 4)
            expect(active).to.equal(nil)
            expect(err).to.equal("Malformed plot entry")
        end)

        it("partitionPlotData rejects duplicate indices across active and archived", function()
            local active, _, err = HabitatRules.partitionPlotData({ [5] = {} }, { [5] = {} }, 5)
            expect(active).to.equal(nil)
            expect(err).to.equal("Duplicate plot entry")
        end)

        it("partitionPlotData preserves plot data exactly", function()
            local testPlot = {
                seedId = "seed_berry",
                plantedTime = 1000,
                waterCount = 2,
                stage = 1,
            }
            local active, _ = HabitatRules.partitionPlotData({ [5] = testPlot }, {}, 5)
            expect(active[5].seedId).to.equal(testPlot.seedId)
            expect(active[5].plantedTime).to.equal(testPlot.plantedTime)
            expect(active[5].waterCount).to.equal(testPlot.waterCount)
            expect(active[5].stage).to.equal(testPlot.stage)
        end)
    end)

    describe("PlantRules — seed validation edge cases", function()
        it("getPlantDef returns nil for non-seed items", function()
            expect(PlantRules.getPlantDef("wood")).to.equal(nil)
            expect(PlantRules.getPlantDef("stone")).to.equal(nil)
            expect(PlantRules.getPlantDef("dewdrop")).to.equal(nil)
            expect(PlantRules.getPlantDef("invalid_seed")).to.equal(nil)
        end)

        it("getPlantDef returns correct plant for all seed types", function()
            for plantId, plantDef in pairs(Constants.PLANTS) do
                local retrieved = PlantRules.getPlantDef(plantDef.seedId)
                expect(retrieved).to.equal(plantDef)
                expect(retrieved.id).to.equal(plantId)
            end
        end)

        it("resolveSeed rejects invalid seed types in automatic mode", function()
            local data = {
                inventory = { wood = 10 },
                plots = { [1] = { seedId = nil, plantedTime = 0, waterCount = 0, stage = 0 } },
                upgrades = {},
            }
            local plan, reason =
                PlantRules.validateInteraction(data, 1, "harvest_or_plant", nil, NOW)
            expect(plan).to.equal(nil)
            expect(reason).to.equal("No seeds available for planting")
        end)

        it("validates waterCount bounds for each plant type", function()
            for _, plantDef in pairs(Constants.PLANTS) do
                local data = {
                    inventory = { [plantDef.seedId] = 1, dewdrop = plantDef.waterNeeded },
                    plots = {
                        [1] = {
                            seedId = plantDef.seedId,
                            plantedTime = NOW - plantDef.growthTime,
                            waterCount = 0,
                            stage = 1,
                        },
                    },
                    upgrades = {},
                }

                -- Water exactly to completion
                for _ = 1, plantDef.waterNeeded do
                    local plan = PlantRules.validateInteraction(data, 1, "water", nil, NOW)
                    expect(plan).to.be.ok()
                    expect(plan.dewdropCost).to.equal(1)
                    data.plots[1].waterCount += 1
                    data.inventory.dewdrop -= 1
                end

                -- Next water should fail
                local plan = PlantRules.validateInteraction(data, 1, "water", nil, NOW)
                expect(plan).to.equal(nil)
            end
        end)

        it("validates harvest reward configuration for each plant", function()
            for plantId, plantDef in pairs(Constants.PLANTS) do
                expect(type(plantDef.harvestReward)).to.equal("table")
                expect(type(plantDef.harvestReward.itemId)).to.equal("string")
                expect(plantDef.harvestReward.itemId).to.equal(
                    Constants.RESOURCES["CROP_" .. string.upper(plantId)]
                )
                expect(type(plantDef.harvestReward.min)).to.equal("number")
                expect(type(plantDef.harvestReward.max)).to.equal("number")
                expect(plantDef.harvestReward.min >= 1).to.equal(true)
                expect(plantDef.harvestReward.max >= plantDef.harvestReward.min).to.equal(true)
                expect(type(plantDef.bellReward)).to.equal("number")
                expect(plantDef.bellReward >= 1).to.equal(true)
            end
        end)
    end)

    describe("CharacterSpawnData — serialization edge cases", function()
        it("decodes Vector3 from array-style table", function()
            local decoded = CharacterSpawnData.decodeVector3({ 1, 2, 3 }, Vector3.zero)
            expect(decoded).to.equal(Vector3.new(1, 2, 3))
        end)

        it("decodes Vector3 from object-style table", function()
            local decoded = CharacterSpawnData.decodeVector3({ x = 1, y = 2, z = 3 }, Vector3.zero)
            expect(decoded).to.equal(Vector3.new(1, 2, 3))
        end)

        it("decodes mixed array/object style table", function()
            local decoded =
                CharacterSpawnData.decodeVector3({ [1] = 1, y = 2, z = 3 }, Vector3.zero)
            expect(decoded).to.equal(Vector3.new(1, 2, 3))
        end)

        it("returns fallback for invalid coordinate types", function()
            local fallback = Vector3.new(0, 5, 0)
            expect(CharacterSpawnData.decodeVector3({ x = "a", y = 2, z = 3 }, fallback)).to.equal(
                fallback
            )
            expect(CharacterSpawnData.decodeVector3({ x = true, y = 2, z = 3 }, fallback)).to.equal(
                fallback
            )
            expect(CharacterSpawnData.decodeVector3({}, fallback)).to.equal(fallback)
        end)

        it("returns fallback for coordinates exceeding 100000", function()
            local fallback = Vector3.new(0, 5, 0)
            expect(CharacterSpawnData.decodeVector3({ x = 100001, y = 0, z = 0 }, fallback)).to.equal(
                fallback
            )
            expect(CharacterSpawnData.decodeVector3({ x = -100001, y = 0, z = 0 }, fallback)).to.equal(
                fallback
            )
        end)

        it("returns fallback for NaN and infinite coordinates", function()
            local fallback = Vector3.new(0, 5, 0)
            expect(CharacterSpawnData.decodeVector3({ x = 0 / 0, y = 0, z = 0 }, fallback)).to.equal(
                fallback
            )
            expect(CharacterSpawnData.decodeVector3({ x = math.huge, y = 0, z = 0 }, fallback)).to.equal(
                fallback
            )
        end)

        it("encodes Vector3 to object with x, y, z keys", function()
            local encoded = CharacterSpawnData.encodeVector3(Vector3.new(1.5, -2.5, 3.7))
            expect(type(encoded)).to.equal("table")
            expect(encoded.x).to.equal(1.5)
            expect(encoded.y).to.equal(-2.5)
            expect(encoded.z).to.equal(3.7)
        end)

        it("round-trip preserves precision for typical values", function()
            local original = Vector3.new(12.5, 6, -8)
            local encoded = CharacterSpawnData.encodeVector3(original)
            local decoded = CharacterSpawnData.decodeVector3(encoded, Vector3.zero)
            expect(decoded).to.equal(original)
        end)
    end)

    describe("Constants — resource node and plant consistency", function()
        it("every resource node has valid structure", function()
            for _, node in ipairs(Constants.RESOURCE_NODES) do
                expect(type(node.id)).to.equal("string")
                expect(node.id).to.equal(string.lower(node.name))
                expect(type(node.type)).to.equal("string")
                expect(node.amount > 0 and node.amount % 1 == 0).to.equal(true)
                expect(node.cooldownMinutes > 0).to.equal(true)
                expect(typeof(node.position)).to.equal("Vector3")
            end
        end)

        it("every plant has a corresponding seed resource node", function()
            local seedNodeTypes = {}
            for _, node in ipairs(Constants.RESOURCE_NODES) do
                if string.sub(node.type, 1, 5) == "seed_" then
                    seedNodeTypes[node.type] = true
                end
            end

            for _, plantDef in pairs(Constants.PLANTS) do
                expect(seedNodeTypes[plantDef.seedId]).to.equal(true)
            end
        end)

        it("every seed resource node has a corresponding plant", function()
            for _, node in ipairs(Constants.RESOURCE_NODES) do
                if string.sub(node.type, 1, 5) == "seed_" then
                    local found = false
                    for _, plantDef in pairs(Constants.PLANTS) do
                        if plantDef.seedId == node.type then
                            found = true
                            break
                        end
                    end
                    expect(found).to.equal(true)
                end
            end
        end)

        it("all creature definitions have valid behavior profiles", function()
            for _, creatureDef in pairs(Constants.CREATURES) do
                expect(type(creatureDef.id)).to.equal("string")
                expect(type(creatureDef.name)).to.equal("string")
                expect(type(creatureDef.requiredFlora)).to.equal("number")
                expect(creatureDef.requiredFlora >= 0).to.equal(true)
                expect(type(creatureDef.requiredWater)).to.equal("number")
                expect(creatureDef.requiredWater >= 0).to.equal(true)
                expect(type(creatureDef.bellReward)).to.equal("number")
                expect(creatureDef.bellReward >= 0).to.equal(true)
                expect(type(creatureDef.behavior)).to.equal("table")
                expect(type(creatureDef.behavior.mode)).to.equal("string")
                expect(creatureDef.behavior.moveInterval > 0).to.equal(true)
                expect(creatureDef.behavior.wanderRadius > 0).to.equal(true)
            end
        end)

        it("all upgrades have valid cost progression", function()
            for _, upgradeDef in pairs(Constants.UPGRADES) do
                expect(type(upgradeDef.id)).to.equal("string")
                expect(type(upgradeDef.baseCost)).to.equal("number")
                expect(upgradeDef.baseCost > 0).to.equal(true)
                expect(type(upgradeDef.costMultiplier)).to.equal("number")
                expect(upgradeDef.costMultiplier > 0).to.equal(true)
                expect(type(upgradeDef.maxLevel)).to.equal("number")
                expect(upgradeDef.maxLevel >= 1).to.equal(true)
            end
        end)
    end)

    describe("Quest-to-Reward Progression — Integrated Vertical Slice", function()
        local _Constants = require(script.Parent.Parent.Constants)
        local _ResourceRules = require(script.Parent.Parent.ResourceRules)
        local _QuestRules = require(script.Parent.Parent.QuestRules)

        local NOW_TEST = 10_000
        local WOOD = _Constants.RESOURCES.WOOD
        local SEED_BERRY = _Constants.RESOURCES.SEED_BERRY
        local CROP_BERRY = _Constants.RESOURCES.CROP_BERRY
        local CROP_SUNPETAL = _Constants.RESOURCES.CROP_SUNPETAL

        local function makePlayerSession()
            return {
                bells = 50,
                inventory = {
                    [WOOD] = 3,
                    [SEED_BERRY] = 1,
                    [CROP_BERRY] = 0,
                    [CROP_SUNPETAL] = 0,
                },
                plots = {
                    [1] = { seedId = nil, plantedTime = 0, waterCount = 0, stage = 0 },
                },
                questProgress = {},
                creaturesDiscovered = {},
                questsCompleted = {},
                resourceCooldowns = {},
                upgrades = {},
            }
        end

        local function makeQuestData(currentQuest: string): any
            local completed = {}
            for _, questId in ipairs(_Constants.QUEST_ORDER) do
                if questId == currentQuest then
                    break
                end
                completed[questId] = true
            end
            return {
                bells = 50,
                inventory = {
                    [WOOD] = 3,
                    [SEED_BERRY] = 1,
                    [CROP_BERRY] = 0,
                    [CROP_SUNPETAL] = 0,
                },
                plots = {
                    [1] = { seedId = nil, plantedTime = 0, waterCount = 0, stage = 0 },
                },
                questProgress = {},
                creaturesDiscovered = {},
                questsCompleted = completed,
                currentQuest = currentQuest,
                resourceCooldowns = {},
                upgrades = {},
            }
        end

        it("q1_wood — sequences through gathering, funding, and claim", function()
            local data = makePlayerSession()
            local now = NOW_TEST
            local treeCooldown = now + (10 * 60)

            _ResourceRules.tryGrantReward(
                data.resourceCooldowns,
                "tree_1",
                now,
                treeCooldown,
                function()
                    data.inventory[WOOD] = (data.inventory[WOOD] or 0) + 1
                    return true
                end
            )

            expect(data.inventory[WOOD]).to.equal(4)
            _QuestRules.recordProgress(data.questProgress, "gather", WOOD, 1)

            local success, reason = _QuestRules.tryClaim(data, "q1_wood")
            expect(success).to.equal(true)
            expect(reason).to.equal(nil)
            expect(data.questsCompleted.q1_wood).to.equal(true)
            expect(data.currentQuest).to.equal("q2_stone")
            expect(data.bells).to.equal(70)
        end)

        it("q6_creature — validates discovery mechanics and item rewards", function()
            local data = makeQuestData("q6_creature")

            local success = _QuestRules.tryClaim(data, "q6_creature")
            expect(success).to.equal(false)

            data.creaturesDiscovered.bunny = true
            data.questProgress["discover:bunny"] = 1

            success = _QuestRules.tryClaim(data, "q6_creature")
            expect(success).to.equal(true)
            expect(data.questsCompleted.q6_creature).to.equal(true)
            expect(data.currentQuest).to.equal("q7_sunpetal")
        end)

        it("prevents duplicate claims and maintains consistency", function()
            local data = makeQuestData("q1_wood")
            data.questProgress["gather:wood"] = 3

            local success1, _ = _QuestRules.tryClaim(data, "q1_wood")
            expect(success1).to.equal(true)
            expect(data.questsCompleted.q1_wood).to.be.ok()
            expect(data.currentQuest).to.equal("q2_stone")

            data.currentQuest = "q1_wood"
            local success2, reason2 = _QuestRules.tryClaim(data, "q1_wood")
            expect(success2).to.equal(false)
            expect(reason2).to.equal("Already completed")
            expect(data.bells).to.equal(70)
        end)
    end)

    describe("Creature Friendship Progression — Integrated Vertical Slice", function()
        local _Constants = require(script.Parent.Parent.Constants)
        local _QuestRules = require(script.Parent.Parent.QuestRules)
        local _CreatureRules = require(script.Parent.Parent.CreatureRules)

        local NOW_TEST = 10_000
        local CROP_BERRY = _Constants.RESOURCES.CROP_BERRY
        local CROP_FLOWER = _Constants.RESOURCES.CROP_FLOWER
        local SEED_MOONFLOWER = _Constants.RESOURCES.SEED_MOONFLOWER
        local SEED_GLOWCAP = _Constants.RESOURCES.SEED_GLOWCAP

        local function makeFriendshipData()
            return {
                bells = 100,
                inventory = {
                    [CROP_BERRY] = 50,
                },
                creatures = {},
                creaturesDiscovered = {
                    bunny = true,
                    sprite = true,
                    leafling = true,
                },
                questProgress = {},
                questsCompleted = {},
                currentQuest = "q11_friendship",
                resourceCooldowns = {},
                upgrades = { storage_expansion = 1 },
            }
        end

        local function setCreatureFriendship(data: any, creatureId: string, level: number)
            local xpPerLevel = _Constants.CREATURE_FRIENDSHIP.XP_PER_LEVEL
            data.creatures[creatureId] = {
                friendshipLevel = level,
                friendshipXP = level * xpPerLevel,
                totalInteractions = level * 5,
                lastInteractionTime = NOW_TEST,
                care = { fedCount = 0, totalFeedings = 0 },
            }
        end

        it("q11_friendship — befriend a creature to level 2", function()
            local data = makeFriendshipData()
            data.currentQuest = "q11_friendship"
            setCreatureFriendship(data, "bunny", 2)

            local success = _QuestRules.tryClaim(data, "q11_friendship")
            expect(success).to.equal(true)
            expect(data.questsCompleted.q11_friendship).to.equal(true)
            expect(data.currentQuest).to.equal("q12_deep_bond")
            expect(data.bells).to.equal(175) -- 100 + 75
            expect(data.inventory[CROP_FLOWER]).to.equal(1)
        end)

        it("q11_friendship — fails when no creature at level 2", function()
            local data = makeFriendshipData()
            data.currentQuest = "q11_friendship"
            setCreatureFriendship(data, "bunny", 1)

            local success = _QuestRules.tryClaim(data, "q11_friendship")
            expect(success).to.equal(false)
        end)

        it("q12_deep_bond — reach max friendship level 5 with a creature", function()
            local data = makeFriendshipData()
            data.currentQuest = "q12_deep_bond"
            setCreatureFriendship(data, "bunny", 5)

            local success = _QuestRules.tryClaim(data, "q12_deep_bond")
            expect(success).to.equal(true)
            expect(data.questsCompleted.q12_deep_bond).to.equal(true)
            expect(data.currentQuest).to.equal("q13_creature_caretaker")
            expect(data.bells).to.equal(350) -- 100 + 250
            expect(data.inventory[SEED_MOONFLOWER]).to.equal(1)
        end)

        it("q12_deep_bond — fails when creature below max level", function()
            local data = makeFriendshipData()
            data.currentQuest = "q12_deep_bond"
            setCreatureFriendship(data, "bunny", 4)

            local success = _QuestRules.tryClaim(data, "q12_deep_bond")
            expect(success).to.equal(false)
        end)

        it("q13_creature_caretaker — three creatures at friendship level 3", function()
            local data = makeFriendshipData()
            data.currentQuest = "q13_creature_caretaker"
            setCreatureFriendship(data, "bunny", 3)
            setCreatureFriendship(data, "sprite", 3)
            setCreatureFriendship(data, "leafling", 3)

            local success = _QuestRules.tryClaim(data, "q13_creature_caretaker")
            expect(success).to.equal(true)
            expect(data.questsCompleted.q13_creature_caretaker).to.equal(true)
            expect(data.currentQuest).to.equal(nil) -- Final quest
            expect(data.bells).to.equal(400) -- 100 + 300
            expect(data.inventory[SEED_GLOWCAP]).to.equal(1)
        end)

        it("q13_creature_caretaker — fails with only two creatures at level 3", function()
            local data = makeFriendshipData()
            data.currentQuest = "q13_creature_caretaker"
            setCreatureFriendship(data, "bunny", 3)
            setCreatureFriendship(data, "sprite", 3)
            setCreatureFriendship(data, "leafling", 2)

            local success = _QuestRules.tryClaim(data, "q13_creature_caretaker")
            expect(success).to.equal(false)
        end)

        it("CreatureRules friendship XP and rewards match Constants", function()
            local data = makeFriendshipData()
            data.creaturesDiscovered.bunny = true
            data.inventory[CROP_BERRY] = 50

            -- Test pet interaction XP
            local petResult = _CreatureRules.validateInteraction(data, "bunny", "care", NOW_TEST)
            expect(petResult.success).to.equal(true)
            expect(data.creatures.bunny.friendshipXP).to.equal(
                _Constants.CREATURE_FRIENDSHIP.PET_XP
            )

            -- Test feed interaction XP (with favorite food bonus)
            local feedResult =
                _CreatureRules.validateInteraction(data, "bunny", "feed", NOW_TEST + 600_001)
            expect(feedResult.success).to.equal(true)
            local expectedFeedXP = _Constants.CREATURE_FRIENDSHIP.FEED_XP
                + _Constants.CREATURE_FRIENDSHIP.FAVORITE_FOOD_BONUS_XP
            expect(data.creatures.bunny.friendshipXP).to.equal(
                _Constants.CREATURE_FRIENDSHIP.PET_XP + expectedFeedXP
            )

            -- Test friendship level up rewards
            data.creatures.bunny.friendshipLevel = 1
            data.creatures.bunny.friendshipXP = _Constants.CREATURE_FRIENDSHIP.XP_PER_LEVEL
            data.creatures.bunny.totalInteractions = 10

            local levelUpResult =
                _CreatureRules.validateInteraction(data, "bunny", "care", NOW_TEST + 1_200_001)
            expect(levelUpResult.success).to.equal(true)
            expect(levelUpResult.friendshipLevelUp).to.equal(true)
            expect(levelUpResult.friendshipRewards).to.be.ok()
            expect(levelUpResult.friendshipRewards.bells).to.equal(
                _Constants.CREATURE_FRIENDSHIP.REWARDS[2].bells
            )
        end)
    end)
end
