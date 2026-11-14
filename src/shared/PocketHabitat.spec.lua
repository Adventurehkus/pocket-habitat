--!strict
-- selene: allow(undefined_variable)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local PlantRules = require(Shared:WaitForChild("PlantRules"))
local EconomyRules = require(Shared:WaitForChild("EconomyRules"))
local ResourceRules = require(Shared:WaitForChild("ResourceRules"))

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
    end)
end
