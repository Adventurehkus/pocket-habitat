--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))

return function()
    describe("Constants", function()
        it("should have valid resources defined", function()
            expect(Constants.RESOURCES.WOOD).to.equal("wood")
            expect(Constants.RESOURCES.STONE).to.equal("stone")
            expect(Constants.RESOURCES.DEWDROP).to.equal("dewdrop")
        end)

        it("should have plant definitions", function()
            expect(Constants.PLANTS.berry).to.be.a("table")
            expect(Constants.PLANTS.berry.growthTime).to.be.a("number")
        end)

        it("should have creature definitions", function()
            expect(Constants.CREATURES.bunny).to.be.a("table")
            expect(Constants.CREATURES.bunny.bellReward).to.be.a("number")
        end)

        it("should have quest definitions", function()
            expect(Constants.QUESTS.q1_wood).to.be.a("table")
            expect(Constants.QUESTS.q1_wood.targetCount).to.equal(3)
        end)
    end)
end
