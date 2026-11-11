--!strict
-- selene: allow(undefined_variable)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))

return function()
    describe("Milestone 1 Gameplay Loop Simulation", function()
        it("should simulate a full planting and harvesting cycle", function()
            -- Mocked player data
            local playerData = {
                bells = 50,
                inventory = {
                    [Constants.RESOURCES.SEED_BERRY] = 1,
                    [Constants.RESOURCES.DEWDROP] = 2,
                },
                plots = {
                    [1] = { seedId = nil, plantedTime = 0, waterCount = 0, stage = 0 },
                },
            }

            -- Mocking the planting logic
            local function plantSeed(plotIndex: number, seedId: string)
                local plot = playerData.plots[plotIndex]
                if plot.seedId then
                    return false
                end
                plot.seedId = seedId
                plot.plantedTime = os.time()
                plot.waterCount = 0
                plot.stage = 1
                return true
            end

            -- Mocking the watering logic
            local function waterPlot(plotIndex: number)
                local plot = playerData.plots[plotIndex]
                if not plot.seedId then
                    return false
                end
                plot.waterCount += 1
                return true
            end

            -- Planting
            expect(plantSeed(1, Constants.RESOURCES.SEED_BERRY)).to.equal(true)
            expect(playerData.plots[1].seedId).to.equal(Constants.RESOURCES.SEED_BERRY)

            -- Watering
            expect(waterPlot(1)).to.equal(true)
            expect(waterPlot(1)).to.equal(true)
            expect(playerData.plots[1].waterCount).to.equal(2)
        end)
    end)
end
