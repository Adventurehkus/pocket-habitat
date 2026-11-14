--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))
local QuestRules = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("QuestRules"))
local RemoteEvents = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RemoteEvents"))
local DataStoreManager = require(script.Parent:WaitForChild("DataStoreManager"))

local QuestManager = {}

function QuestManager.init()
    RemoteEvents.ClaimQuest.OnServerInvoke = function(
        player: Player,
        questId: any
    ): (boolean, string)
        if typeof(questId) ~= "string" then
            return false, "Invalid argument"
        end

        local data = DataStoreManager.getSession(player)
        if not data then
            return false, "No session"
        end

        local questDef = Constants.QUESTS[questId]
        if not questDef then
            return false, "Invalid quest"
        end

        local claimed, claimError = QuestRules.tryClaim(data, questId)
        if not claimed then
            return false, claimError or "Quest claim failed"
        end

        RemoteEvents.SyncData:FireClient(player, data)
        RemoteEvents.Notification:FireClient(
            player,
            "Completed quest: "
                .. questDef.title
                .. " (+ "
                .. tostring(questDef.rewardBells)
                .. " Bells)!"
        )
        return true, "Success"
    end
end

return QuestManager
