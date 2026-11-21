--!strict
local QuestRules = require(script.Parent.Parent.QuestRules)
local Constants = require(script.Parent.Parent.Constants)

describe("QuestRules — tryClaim logic", function()
    local function makePlayerData()
        return {
            bells = 100,
            inventory = {},
            upgrades = { storage_expansion = 1 },
            creaturesDiscovered = {},
            questProgress = {},
            questsCompleted = {},
            currentQuest = "q1_gather",
        }
    end

    it("prevents claiming non-current quest", function()
        local data = makePlayerData()
        local success, reason = QuestRules.tryClaim(data, "q2_plant")
        expect(success).to.equal(false)
        expect(reason).to.equal("Not current quest")
    end)

    it("prevents claiming incomplete quest", function()
        local data = makePlayerData()
        -- q1_gather needs targetCount items
        local success, reason = QuestRules.tryClaim(data, "q1_gather")
        expect(success).to.equal(false)
        expect(reason).to.equal("Quest objectives not met")
    end)

    it("allows claiming completed quest", function()
        local data = makePlayerData()
        local questId = "q1_gather"
        local questDef = Constants.QUESTS[questId]

        -- Set progress
        data.questProgress[questDef.targetType .. ":" .. questDef.targetItemId] =
            questDef.targetCount

        local success, reason = QuestRules.tryClaim(data, questId)
        expect(success).to.equal(true)
        expect(reason).to.equal(nil)
        expect(data.questsCompleted[questId]).to.equal(true)
    end)
end)
