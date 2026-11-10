--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents = {}

local function getOrCreateFolder(parent: Instance, name: string): Folder
	local found = parent:FindFirstChild(name)
	if found and found:IsA("Folder") then
		return found
	end
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local remotesFolder = getOrCreateFolder(ReplicatedStorage, "Remotes")

local function getOrCreateRemote(className: string, name: string): Instance
	local found = remotesFolder:FindFirstChild(name)
	if found and found:IsA(className) then
		return found
	end
	if found then
		found:Destroy()
	end
	local remote = Instance.new(className)
	remote.Name = name
	remote.Parent = remotesFolder
	return remote
end

RemoteEvents.GatherResource = getOrCreateRemote("RemoteFunction", "GatherResource") :: RemoteFunction
RemoteEvents.PlantSeed = getOrCreateRemote("RemoteFunction", "PlantSeed") :: RemoteFunction
RemoteEvents.WaterPlot = getOrCreateRemote("RemoteFunction", "WaterPlot") :: RemoteFunction
RemoteEvents.HarvestPlot = getOrCreateRemote("RemoteFunction", "HarvestPlot") :: RemoteFunction
RemoteEvents.PurchaseUpgrade = getOrCreateRemote("RemoteFunction", "PurchaseUpgrade") :: RemoteFunction
RemoteEvents.ClaimQuest = getOrCreateRemote("RemoteFunction", "ClaimQuest") :: RemoteFunction

RemoteEvents.SyncData = getOrCreateRemote("RemoteEvent", "SyncData") :: RemoteEvent
RemoteEvents.Notification = getOrCreateRemote("RemoteEvent", "Notification") :: RemoteEvent
RemoteEvents.CreatureDiscovered = getOrCreateRemote("RemoteEvent", "CreatureDiscovered") :: RemoteEvent

return RemoteEvents
