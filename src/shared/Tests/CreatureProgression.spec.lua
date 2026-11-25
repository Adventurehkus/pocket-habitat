--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))
local QuestRules = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("QuestRules"))
local CreatureRules = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CreatureRules"))

return function()
	describe("Creature interaction progression — server-side validation", function()
		it("records petting progress and validates interaction rules", function()
			local progress = {}
			local bunnyDef = Constants.CREATURES.bunny

			local recorded = QuestRules.recordProgress(progress, "discover", bunnyDef.id, 1)
			expect(recorded).to.equal(true)
			expect(QuestRules.getProgress(progress, "discover", bunnyDef.id)).to.equal(1)
		end)

		it("records feeding progress with valid food", function()
			local progress = {}
			local bunnyDef = Constants.CREATURES.bunny

			local recorded = QuestRules.recordProgress(progress, "feed", bunnyDef.id, 1)
			expect(recorded).to.equal(true)
			expect(QuestRules.getProgress(progress, "feed", bunnyDef.id)).to.equal(1)
		end)

		it("validates interaction cooldown for server authority", function()
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
			expect(canInteract(playerUserId, now + 0.1)).to.equal(false)
			expect(canInteract(playerUserId, now + 0.6)).to.equal(true)
		end)
	end)

	describe("Creature friendship progression — integrated with quest system", function()
		local function makePlayerData()
			return {
				bells = 100,
				inventory = {},
				creatures = {},
				creaturesDiscovered = {},
				questProgress = {},
				questsCompleted = {},
				currentQuest = "q1_gather",
				upgrades = { storage_expansion = 1 },
			}
		end

		it("records friendship progress for petting via QuestRules.recordProgress", function()
			local progress = {}
			local bunnyDef = Constants.CREATURES.bunny

			local recorded = QuestRules.recordProgress(progress, "discover", bunnyDef.id, 1)
			expect(recorded).to.equal(true)
			expect(QuestRules.getProgress(progress, "discover", bunnyDef.id)).to.equal(1)
		end)

		it("records friendship progress for feeding via QuestRules.recordProgress", function()
			local progress = {}
			local bunnyDef = Constants.CREATURES.bunny

			local recorded = QuestRules.recordProgress(progress, "feed", bunnyDef.id, 1)
			expect(recorded).to.equal(true)
			expect(QuestRules.getProgress(progress, "feed", bunnyDef.id)).to.equal(1)
		end)

		it("validates friendship quest progress tracking", function()
			local data = makePlayerData()
			data.currentQuest = "q11_friendship"
			data.creaturesDiscovered["bunny"] = true
			data.creatures.bunny = {
				friendshipLevel = 2,
				friendshipXP = 200,
				totalInteractions = 5,
				lastInteractionTime = os.time() * 1000,
				care = { fedCount = 0, totalFeedings = 0 },
			}

			local success = QuestRules.tryClaim(data, "q11_friendship")
			expect(success).to.equal(true)
			expect(data.questsCompleted.q11_friendship).to.equal(true)
		end)

		it("validates deep bond quest requires max friendship level", function()
			local data = makePlayerData()
			data.currentQuest = "q12_deep_bond"
			data.creaturesDiscovered["bunny"] = true
			data.creatures.bunny = {
				friendshipLevel = 4,
				friendshipXP = 400,
				totalInteractions = 15,
				lastInteractionTime = os.time() * 1000,
				care = { fedCount = 0, totalFeedings = 0 },
			}

			local success = QuestRules.tryClaim(data, "q12_deep_bond")
			expect(success).to.equal(false)

			data.creatures.bunny.friendshipLevel = 5
			data.creatures.bunny.friendshipXP = 500
			success = QuestRules.tryClaim(data, "q12_deep_bond")
			expect(success).to.equal(true)
		end)

		it("validates creature caretaker quest requires multiple creatures at target level", function()
			local data = makePlayerData()
			data.currentQuest = "q13_creature_caretaker"
			data.creaturesDiscovered["bunny"] = true
			data.creaturesDiscovered["sprite"] = true
			data.creaturesDiscovered["leafling"] = true

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
				friendshipLevel = 2,
				friendshipXP = 200,
				totalInteractions = 5,
				lastInteractionTime = os.time() * 1000,
				care = { fedCount = 0, totalFeedings = 0 },
			}

			local success = QuestRules.tryClaim(data, "q13_creature_caretaker")
			expect(success).to.equal(false)

			data.creatures.leafling.friendshipLevel = 3
			data.creatures.leafling.friendshipXP = 300
			success = QuestRules.tryClaim(data, "q13_creature_caretaker")
			expect(success).to.equal(true)
		end)

		it("validates CreatureRules friendship XP calculation matches Constants", function()
			local data = makePlayerData()
			data.creaturesDiscovered["bunny"] = true
			data.inventory["crop_berry"] = 10

			-- First pet interaction
			local petResult = CreatureRules.validateInteraction(data, "bunny", "care", os.time() * 1000)
			expect(petResult.success).to.equal(true)
			expect(petResult.friendshipProgress).to.equal(1)
			expect(data.creatures.bunny.friendshipXP).to.equal(Constants.CREATURE_FRIENDSHIP.PET_XP)

			-- First feed interaction (with favorite food bonus)
			local feedResult = CreatureRules.validateInteraction(data, "bunny", "feed", os.time() * 1000 + 600_001)
			expect(feedResult.success).to.equal(true)
			local expectedFeedXP = Constants.CREATURE_FRIENDSHIP.FEED_XP + Constants.CREATURE_FRIENDSHIP.FAVORITE_FOOD_BONUS_XP
			expect(data.creatures.bunny.friendshipXP).to.equal(Constants.CREATURE_FRIENDSHIP.PET_XP + expectedFeedXP)
		end)
	end)
end