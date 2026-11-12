--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RemoteEvents = require(Shared:WaitForChild("RemoteEvents"))

local player = Players.LocalPlayer
local habitatsFolder = Workspace:WaitForChild("Habitats")
local activeHabitat: Folder? = nil
local promptConnections: { [ProximityPrompt]: RBXScriptConnection } = {}
local habitatConnections: { RBXScriptConnection } = {}

local function onResourceGathered(prompt: ProximityPrompt)
    local nodeId = prompt:GetAttribute("NodeId")
    if typeof(nodeId) == "string" then
        local success, result = RemoteEvents.GatherResource:InvokeServer(nodeId)
        print("[ProximityHandler] Gather result:", success, result, "from", nodeId)
    end
end

local function onPlotAction(prompt: ProximityPrompt)
    local plotIndex = prompt:GetAttribute("PlotIndex")
    local plotAction = prompt:GetAttribute("PlotAction") or "harvest"

    if typeof(plotIndex) ~= "number" then
        return
    end

    if plotAction == "water" then
        local success, result = RemoteEvents.WaterPlot:InvokeServer(plotIndex)
        print("[ProximityHandler] Water result:", success, result, "from plot", plotIndex)
    elseif plotAction == "harvest" then
        local success, result = RemoteEvents.HarvestPlot:InvokeServer(plotIndex)
        print("[ProximityHandler] Harvest result:", success, result, "from plot", plotIndex)
    elseif plotAction == "harvest_or_plant" then
        local success, result =
            RemoteEvents.InteractWithPlot:InvokeServer(plotIndex, "harvest_or_plant")
        print("[ProximityHandler] Harvest/Plant result:", success, result, "from plot", plotIndex)
    end
end

local function connectPrompt(descendant: Instance)
    if not descendant:IsA("ProximityPrompt") or promptConnections[descendant] then
        return
    end

    promptConnections[descendant] = descendant.Triggered:Connect(function()
        if not activeHabitat or not descendant:IsDescendantOf(activeHabitat) then
            return
        end

        if typeof(descendant:GetAttribute("NodeId")) == "string" then
            onResourceGathered(descendant)
        elseif typeof(descendant:GetAttribute("PlotIndex")) == "number" then
            onPlotAction(descendant)
        end
    end)
end

local function disconnectHabitat()
    for _, connection in pairs(promptConnections) do
        connection:Disconnect()
    end
    table.clear(promptConnections)

    for _, connection in ipairs(habitatConnections) do
        connection:Disconnect()
    end
    table.clear(habitatConnections)
    activeHabitat = nil
end

local function connectToHabitat(habitat: Folder)
    if activeHabitat == habitat then
        return
    end

    disconnectHabitat()
    activeHabitat = habitat
    table.insert(habitatConnections, habitat.DescendantAdded:Connect(connectPrompt))

    for _, descendant in ipairs(habitat:GetDescendants()) do
        connectPrompt(descendant)
    end
end

local ownHabitatName = "Habitat_" .. tostring(player.UserId)

habitatsFolder.ChildAdded:Connect(function(child)
    if child:IsA("Folder") and child.Name == ownHabitatName then
        connectToHabitat(child)
    end
end)

habitatsFolder.ChildRemoved:Connect(function(child)
    if child == activeHabitat then
        disconnectHabitat()
    end
end)

local existingHabitat = habitatsFolder:FindFirstChild(ownHabitatName)
if existingHabitat and existingHabitat:IsA("Folder") then
    connectToHabitat(existingHabitat)
end

print("[ProximityHandler] Local player's habitat prompt discovery initialized.")
