--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))
local ResourceRules =
    require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ResourceRules"))
local QuestRules = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("QuestRules"))
local RemoteEvents = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RemoteEvents"))
local EconomyManager = require(script.Parent:WaitForChild("EconomyManager"))
local CreatureManager = require(script.Parent:WaitForChild("CreatureManager"))
local DataStoreManager = require(script.Parent:WaitForChild("DataStoreManager"))

local ResourceManager = {}

local GATHER_REQUEST_INTERVAL = 0.25
local lastGatherRequestAt: { [number]: number } = {}

-- Static node templates with base positions (relative to habitat offset)
local staticNodes = {
    {
        id = "tree_1",
        type = Constants.RESOURCES.WOOD,
        basePosition = Vector3.new(15, 3, 0),
        cooldown = 10,
    },
    {
        id = "tree_2",
        type = Constants.RESOURCES.WOOD,
        basePosition = Vector3.new(-15, 3, 0),
        cooldown = 10,
    },
    {
        id = "rock_1",
        type = Constants.RESOURCES.STONE,
        basePosition = Vector3.new(0, 3, 15),
        cooldown = 12,
    },
    {
        id = "rock_2",
        type = Constants.RESOURCES.STONE,
        basePosition = Vector3.new(0, 3, -15),
        cooldown = 12,
    },
    {
        id = "dew_1",
        type = Constants.RESOURCES.DEWDROP,
        basePosition = Vector3.new(10, 3, 10),
        cooldown = 8,
    },
    {
        id = "bush_1",
        type = Constants.RESOURCES.SEED_BERRY,
        basePosition = Vector3.new(-10, 3, -10),
        cooldown = 15,
    },
}

function ResourceManager.init()
    RemoteEvents.GatherResource.OnServerInvoke = function(
        player: Player,
        nodeId: any
    ): (boolean, string)
        local now = os.clock()
        local lastRequestAt = lastGatherRequestAt[player.UserId]
        if lastRequestAt and now - lastRequestAt < GATHER_REQUEST_INTERVAL then
            return false, "Gather request rate limited"
        end
        lastGatherRequestAt[player.UserId] = now

        if typeof(nodeId) ~= "string" then
            return false, "Invalid argument"
        end

        local sessionData = DataStoreManager.getSession(player)
        if not sessionData then
            return false, "No active session"
        end

        local character = player.Character
        local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
        local rootPart = if character then character:FindFirstChild("HumanoidRootPart") else nil
        if
            not character
            or not humanoid
            or humanoid.Health <= 0
            or not rootPart
            or not rootPart:IsA("BasePart")
        then
            return false, "Invalid character"
        end

        -- Find static node template
        local staticNode = nil
        for _, node in ipairs(staticNodes) do
            if node.id == nodeId then
                staticNode = node
                break
            end
        end

        if not staticNode then
            return false, "Node not found"
        end

        -- Server-side validation: Verify exact resource Instance ownership and distance
        local HabitatManager = require(script.Parent:WaitForChild("HabitatManager"))
        local habitat = HabitatManager.getHabitat(player)

        if not habitat then
            return false, "Player habitat not found"
        end

        -- Find the actual resource Instance in the player's habitat
        local resourceInstance = nil
        for _, descendant in ipairs(habitat:GetDescendants()) do
            if descendant:IsA("Part") and descendant:GetAttribute("NodeId") == nodeId:lower() then
                resourceInstance = descendant
                break
            end
        end

        if not resourceInstance then
            return false, "Resource node not found in player habitat"
        end

        -- Use the actual resource Instance position, not the template position
        local nodePosition = resourceInstance.Position

        if (rootPart.Position - nodePosition).Magnitude > 30 then
            return false, "Too far away"
        end

        local cooldownSeconds = (staticNode.cooldown or 10) * 60

        local rewardItem = staticNode.type
        local rewardAmount = rewardItem == Constants.RESOURCES.DEWDROP and 2 or 1
        local currentTimestamp = os.time()
        local granted, grantError = ResourceRules.tryGrantReward(
            sessionData.resourceCooldowns,
            nodeId,
            currentTimestamp,
            currentTimestamp + cooldownSeconds,
            function()
                return EconomyManager.addItem(player, rewardItem, rewardAmount, false)
            end
        )

        if not granted then
            if grantError == "Reward rejected" then
                return false, "Inventory full"
            end
            return false, grantError or "Gather failed"
        end

        if
            not QuestRules.recordProgress(
                sessionData.questProgress,
                "gather",
                rewardItem,
                rewardAmount
            )
        then
            warn("Failed to record gather quest progress for user " .. tostring(player.UserId))
        end
        RemoteEvents.SyncData:FireClient(player, sessionData)
        CreatureManager.checkDiscoveries(player)

        RemoteEvents.GatherEffect:FireClient(player, nodePosition, rewardItem, rewardAmount)
        RemoteEvents.Notification:FireClient(
            player,
            "Gathered " .. rewardAmount .. " " .. rewardItem .. "!"
        )

        return true, "Success"
    end
end

function ResourceManager.removePlayer(player: Player)
    lastGatherRequestAt[player.UserId] = nil
end

return ResourceManager
