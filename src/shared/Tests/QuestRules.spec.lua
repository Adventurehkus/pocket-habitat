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
			creatures = {},
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
		local success, reason = QuestRules.tryClaim(data, "q1_gather")
		expect(success).to.equal(false)
		expect(reason).to.equal("Quest objectives not met")
	end)

	it("allows claiming completed quest", function()
		local data = makePlayerData()
		local questId = "q1_gather"
		local questDef = Constants.QUESTS[questId]

		data.questProgress[questDef.targetType .. ":" .. questDef.targetItemId] = questDef.targetCount

		local success, reason = QuestRules.tryClaim(data, questId)
		expect(success).to.equal(true)
		expect(reason).to.equal(nil)
		expect(data.questsCompleted[questId]).to.equal(true)
	end)

	it("allows claiming discover quest", function()
		local data = makePlayerData()
		data.currentQuest = "q6_creature"
		data.creaturesDiscovered["bunny"] = true

		local success = QuestRules.tryClaim(data, "q6_creature")
		expect(success).to.equal(true)
	end)

	it("allows claiming friendship quest (q11_friendship)", function()
		local data = makePlayerData()
		data.currentQuest = "q11_friendship"
		data.creaturesDiscovered["bunny"] = true
		-- Set bunny to friendship level 2
		data.creatures.bunny = {
			friendshipLevel = 2,
			friendshipXP = 200,
			totalInteractions = 5,
			lastInteractionTime = os.time() * 1000,
			care = { fedCount = 0, totalFeedings = 0 },
		}

		local success, reason = QuestRules.tryClaim(data, "q11_friendship")
		expect(success).to.equal(true)
		expect(reason).to.equal(nil)
		expect(data.questsCompleted.q11_friendship).to.equal(true)
		expect(data.currentQuest).to.equal("q12_deep_bond")
		expect(data.bells).to.equal(175) -- 100 + 75 reward
		expect(data.inventory.crop_flower).to.equal(1)
	end)

	it("prevents claiming friendship quest without required friendship level", function()
		local data = makePlayerData()
		data.currentQuest = "q11_friendship"
		data.creaturesDiscovered["bunny"] = true
		-- Bunny at level 1, need level 2
		data.creatures.bunny = {
			friendshipLevel = 1,
			friendshipXP = 50,
			totalInteractions = 3,
			lastInteractionTime = os.time() * 1000,
			care = { fedCount = 0, totalFeedings = 0 },
		}

		local success, reason = QuestRules.tryClaim(data, "q11_friendship")
		expect(success).to.equal(false)
		expect(reason).to.equal("Quest objectives not met")
	end)

	it("allows claiming deep bond quest (q12_deep_bond)", function()
		local data = makePlayerData()
		data.currentQuest = "q12_deep_bond"
		data.creaturesDiscovered["bunny"] = true
		-- Set bunny to friendship level 5 (max)
		data.creatures.bunny = {
			friendshipLevel = 5,
			friendshipXP = 500,
			totalInteractions = 20,
			lastInteractionTime = os.time() * 1000,
			care = { fedCount = 0, totalFeedings = 0 },
		}

		local success, reason = QuestRules.tryClaim(data, "q12_deep_bond")
		expect(success).to.equal(true)
		expect(reason).to.equal(nil)
		expect(data.questsCompleted.q12_deep_bond).to.equal(true)
		expect(data.currentQuest).to.equal("q13_creature_caretaker")
		expect(data.bells).to.equal(350) -- 100 + 250 reward
		expect(data.inventory.seed_moonflower).to.equal(1)
	end)

	it("allows claiming creature caretaker quest (q13_creature_caretaker)", function()
		local data = makePlayerData()
		data.currentQuest = "q13_creature_caretaker"
		data.creaturesDiscovered["bunny"] = true
		data.creaturesDiscovered["sprite"] = true
		data.creaturesDiscovered["leafling"] = true
		-- Three creatures at friendship level 3
		data.creatures.bunny = {
			friendshipLevel = 3,
			friendshipXP = 300,
			totalInteractions = 10,
			lastInteractionTime = os.time() * 1000,
			care = { fedCount = 0, totalFeedings = 0 },
		}
		data.creatures.sprite = {
			friendshipLevel = 3,
			friendshipXP = 300,
			totalInteractions = 10,
			lastInteractionTime = os.time() * 1000,
			care = { fedCount = 0, totalFeedings = 0 },
		}
		data.creatures.leafling = {
			friendshipLevel = 3,
			friendshipXP = 300,
			totalInteractions = 10,
			lastInteractionTime = os.time() * 1000,
			care = { fedCount = 0, totalFeedings = 0 },
		}

		local success, reason = QuestRules.tryClaim(data, "q13_creature_caretaker")
		expect(success).to.equal(true)
		expect(reason).to.equal(nil)
		expect(data.questsCompleted.q13_creature_caretaker).to.equal(true)
		expect(data.currentQuest).to.equal(nil) -- Final quest
		expect(data.bells).to.equal(400) -- 100 + 300 reward
		expect(data.inventory.seed_glowcap).to.equal(1)
	end)

	it("prevents claiming creature caretaker quest with insufficient creatures at level", function()
		local data = makePlayerData()
		data.currentQuest = "q13_creature_caretaker"
		data.creaturesDiscovered["bunny"] = true
		data.creaturesDiscovered["sprite"] = true
		-- Only two creatures at level 3, need three
		data.creatures.bunny = {
			friendshipLevel = 3,
			friendshipXP = 300,
			totalInteractions = 10,
			lastInteractionTime = os.time() * 1000,
			care = { fedCount = 0, totalFeedings = 0 },
		}
		data.creatures.sprite = {
			friendshipLevel = 2,
			friendshipXP = 200,
			totalInteractions = 5,
			lastInteractionTime = os.time() * 1000,
			care = { fedCount = 0, totalFeedings = 0 },
		}

		local success, reason = QuestRules.tryClaim(data, "q13_creature_caretaker")
		expect(success).to.equal(false)
		expect(reason).to.equal("Quest objectives not met")
	end)

	it("rejects quest claim with invalid creatures data", function()
		local data = makePlayerData()
		data.currentQuest = "q11_friendship"
		data.creaturesDiscovered["bunny"] = true
		data.creatures = "not a table"

		local success, reason = QuestRules.tryClaim(data, "q11_friendship")
		expect(success).to.equal(false)
		expect(reason).to.equal("Invalid player data")
	end)

	it("validates all quest definitions have required fields including new types", function()
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

	it("validates friendship quest definitions", function()
		local q11 = Constants.QUESTS.q11_friendship
		expect(q11.targetType).to.equal("friendship")
		expect(q11.targetCount).to.equal(2)
		expect(q11.rewardItems[Constants.RESOURCES.CROP_FLOWER]).to.equal(1)

		local q12 = Constants.QUESTS.q12_deep_bond
		expect(q12.targetType).to.equal("friendship")
		expect(q12.targetCount).to.equal(5)
		expect(q12.rewardItems[Constants.RESOURCES.SEED_MOONFLOWER]).to.equal(1)

		local q13 = Constants.QUESTS.q13_creature_caretaker
		expect(q13.targetType).to.equal("friendship_multi")
		expect(q13.targetCount).to.equal(3)
		expect(q13.rewardItems[Constants.RESOURCES.SEED_GLOWCAP]).to.equal(1)
	end)
end)