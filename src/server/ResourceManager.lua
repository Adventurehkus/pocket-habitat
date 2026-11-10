--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))
local RemoteEvents = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RemoteEvents"))
local EconomyManager = require(script.Parent:WaitForChild("EconomyManager"))

local ResourceManager = {}

local nodes = {
	{ id = "tree_1", type = Constants.RESOURCES.WOOD, position = Vector3.new(15, 3, 0), cooldown = 10, readyTime = 0 },
	{ id = "tree_2", type = Constants.RESOURCES.WOOD, position = Vector3.new(-15, 3, 0), cooldown = 10, readyTime = 0 },
	{ id = "rock_1", type = Constants.RESOURCES.STONE, position = Vector3.new(0, 3, 15), cooldown = 12, readyTime = 0 },
	{ id = "rock_2", type = Constants.RESOURCES.STONE, position = Vector3.new(0, 3, -15), cooldown = 12, readyTime = 0 },
	{ id = "dew_1", type = Constants.RESOURCES.DEWDROP, position = Vector3.new(10, 3, 10), cooldown = 8, readyTime = 0 },
	{ id = "bush_1", type = Constants.RESOURCES.SEED_BERRY, position = Vector3.new(-10, 3, -10), cooldown = 15, readyTime = 0 },
}

function ResourceManager.init()
	RemoteEvents.GatherResource.OnServerInvoke = function(player: Player, nodeId: string): (boolean, string)
		local character = player.Character
		if not character or not character:FindFirstChild("HumanoidRootPart") then
			return false, "Invalid character"
		end
		
		local targetNode = nil
		for _, node in ipairs(nodes) do
			if node.id == nodeId then
				targetNode = node
				break
			end
		end
		
		if not targetNode then
			return false, "Node not found"
		end
		
		local currentTime = os.time()
		if currentTime < targetNode.readyTime then
			return false, "Node on cooldown"
		end
		
		local hrp = character.HumanoidRootPart :: Part
		if (hrp.Position - targetNode.position).Magnitude > 25 then
			return false, "Too far away"
		end
		
		targetNode.readyTime = currentTime + targetNode.cooldown
		
		local rewardItem = targetNode.type
		local rewardAmount = 1
		if rewardItem == Constants.RESOURCES.DEWDROP then
			rewardAmount = 2
		end
		
		if EconomyManager.addItem(player, rewardItem, rewardAmount) then
			RemoteEvents.Notification:FireClient(player, "Gathered " .. tostring(rewardAmount) .. " " .. rewardItem .. "!")
			return true, "Success"
		end
		
		return false, "Inventory full"
	end
end

return ResourceManager
