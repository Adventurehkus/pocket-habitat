--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))
local RemoteEvents = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RemoteEvents"))
local EconomyManager = require(script.Parent:WaitForChild("EconomyManager"))
local CreatureManager = require(script.Parent:WaitForChild("CreatureManager"))

local ResourceManager = {}

-- Per-player cooldown tracking (keyed by UserId)
local playerCooldowns: { [number]: { [string]: number } } = {}

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

-- Helper to get player's habitat folder
local function getHabitatFolder(player)
    local habitatRoot = workspace:WaitForChild("Habitats")
    if not habitatRoot then
        return nil
    end
    return habitatRoot:FindFirstChild("Habitat_" .. tostring(player.UserId))
end

-- Per-player cooldown tracking (keyed by UserId)
local function getPlayerCooldown(player, nodeId)
    local userId = player.UserId
    if not playerCooldowns[userId] then
        playerCooldowns[userId] = {}
    end
    return playerCooldowns[userId][nodeId] or 0
end

local function setPlayerCooldown(player, nodeId, readyTime)
    local userId = player.UserId
    if not playerCooldowns[userId] then
        playerCooldowns[userId] = {}
    end
    playerCooldowns[userId][nodeId] = readyTime
end

function ResourceManager.init()
    RemoteEvents.GatherResource.OnServerInvoke = function(
        player: Player,
        nodeId: any
    ): (boolean, string)
        if typeof(nodeId) ~= "string" then
            return false, "Invalid argument"
        end

        local character = player.Character
        if not character or not character:FindFirstChild("HumanoidRootPart") then
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

        -- Get habitat offset for position calculation
        local habitatFolder = getHabitatFolder(player)
        local habitatOffset = Vector3.new(0, 0, 0)
        if habitatFolder then
            habitatOffset = habitatFolder:GetAttribute("BaseOffset") or Vector3.new(0, 0, 0)
        end

        -- Calculate actual position
        local nodePosition = staticNode.basePosition + habitatOffset

        -- Check cooldown per player
        local readyTime = getPlayerCooldown(player, nodeId)
        if os.time() < readyTime then
            return false, "Node on cooldown"
        end

        -- Check distance
        if (character.HumanoidRootPart.Position - nodePosition).Magnitude > 30 then
            return false, "Too far away"
        end

        -- Update cooldown (convert minutes to seconds)
        local cooldownSeconds = (staticNode.cooldown or 10) * 60
        setPlayerCooldown(player, nodeId, os.time() + cooldownSeconds)

        local rewardItem = staticNode.type
        local rewardAmount = rewardItem == Constants.RESOURCES.DEWDROP and 2 or 1

        if EconomyManager.addItem(player, rewardItem, rewardAmount) then
            CreatureManager.checkDiscoveries(player)

            RemoteEvents.GatherEffect:FireClient(player, nodePosition, rewardItem, rewardAmount)
            RemoteEvents.Notification:FireClient(
                player,
                "Gathered " .. rewardAmount .. " " .. rewardItem .. "!"
            )
            return true, "Success"
        end

        return false, "Inventory full"
    end
end

return ResourceManager
