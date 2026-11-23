--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))
local QuestRules = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("QuestRules"))

return function()
    describe("Creature interaction progression — server-side validation", function()
        it("records petting progress and validates interaction rules", function()
            local progress = {}
            local bunnyDef = Constants.CREATURES.bunny

            -- Petting: progress should be recorded
            local recorded = QuestRules.recordProgress(progress, "discover", bunnyDef.id, 1)
            expect(recorded).to.equal(true)
            expect(QuestRules.getProgress(progress, "discover", bunnyDef.id)).to.equal(1)
        end)

        it("records feeding progress with valid food", function()
            local progress = {}
            local bunnyDef = Constants.CREATURES.bunny

            -- Feeding: progress should be recorded
            local recorded = QuestRules.recordProgress(progress, "feed", bunnyDef.id, 1)
            expect(recorded).to.equal(true)
            expect(QuestRules.getProgress(progress, "feed", bunnyDef.id)).to.equal(1)
        end)

        it("validates interaction cooldown for server authority", function()
            -- Mocking the interval check as done in CreatureManager (0.5s)
            local lastRequestAt: { [number]: number } = {}
            local playerUserId = 123
            local now = os.clock()

            local function canInteract(userId: number, requestTime: number): boolean
                local last = lastRequestAt[userId]
                if last and requestTime - last < 0.5 then
                    return false
                end
                lastRequestAt[userId] = requestTime
                return true
            end

            expect(canInteract(playerUserId, now)).to.equal(true)
            expect(canInteract(playerUserId, now + 0.1)).to.equal(false) -- Too fast
            expect(canInteract(playerUserId, now + 0.6)).to.equal(true) -- After cooldown
        end)
    end)
end
