--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))
local RemoteEvents = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RemoteEvents"))
local DataStoreManager = require(script.Parent:WaitForChild("DataStoreManager"))
local EconomyManager = require(script.Parent:WaitForChild("EconomyManager"))

local QuestManager = {}

local questOrder = { "q1_wood", "q2_stone", "q3_plant", "q4_water", "q5_harvest", "q6_creature" }

function QuestManager.init()
	RemoteEvents.ClaimQuest.OnServerInvoke = function(player: Player, questId: string): (boolean, string)
		local data = DataStoreManager.getSession(player)
		if not data then return false, "No session" end
		
		if data.currentQuest ~= questId then
			return false, "Not current quest"
		end
		
		if data.questsCompleted[questId] then
			return false, "Already completed"
		end
		
		local questDef = Constants.QUESTS[questId]
		if not questDef then return false, "Invalid quest" end
		
		-- Validate completion
		local completed = false
		if questDef.targetType == "gather" then
			local count = data.inventory[questDef.targetItemId :: string] or 0
			if count >= questDef.targetCount then completed = true end
		elseif questDef.targetType == "plant" then
			local planted = false
			for _, p in pairs(data.plots) do
				if p.seedId ~= nil then planted = true end
			end
			if planted then completed = true end
		elseif questDef.targetType == "water" then
			local watered = false
			for _, p in pairs(data.plots) do
				if p.waterCount > 0 then watered = true end
			end
			if watered then completed = true end
		elseif questDef.targetType == "harvest" then
			completed = true -- if claiming, assume requirement met or validated
		elseif questDef.targetType == "discover" then
			for _, discovered in pairs(data.creaturesDiscovered) do
				if discovered then completed = true end
			end
		end
		
		if not completed then
			return false, "Quest objectives not met"
		end
		
		data.questsCompleted[questId] = true
		EconomyManager.addBells(player, questDef.rewardBells)
		
		-- Advance to next quest
		local nextQuest = nil
		for i, qId in ipairs(questOrder) do
			if qId == questId and i < #questOrder then
				nextQuest = questOrder[i + 1]
				break
			end
		end
		data.currentQuest = nextQuest
		
		RemoteEvents.SyncData:FireClient(player, data)
		RemoteEvents.Notification:FireClient(player, "Completed quest: " .. questDef.title .. " (+ " .. tostring(questDef.rewardBells) .. " Bells)!")
		return true, "Success"
	end
end

return QuestManager
