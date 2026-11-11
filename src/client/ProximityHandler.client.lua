--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RemoteEvents = require(Shared:WaitForChild("RemoteEvents"))
local _Constants = require(Shared:WaitForChild("Constants"))

local _player = Players.LocalPlayer

-- Functions to handle proximity prompt triggers
local function OnResourceGathered(prompt: ProximityPrompt, _player: Player)
    local nodeId = prompt:GetAttribute("NodeId")
    if nodeId then
        local success, res = RemoteEvents.GatherResource:InvokeServer(nodeId)
        print("[ProximityHandler] Gather result:", success, res, "from", nodeId)
    end
end

local function OnPlotHarvested(prompt: ProximityPrompt, _player: Player)
    local plotIndex = prompt:GetAttribute("PlotIndex")
    if plotIndex then
        local success, res = RemoteEvents.HarvestPlot:InvokeServer(plotIndex)
        print("[ProximityHandler] Harvest result:", success, res, "from plot", plotIndex)
    end
end

local function OnPlotWatered(prompt: ProximityPrompt, _player: Player)
    local plotIndex = prompt:GetAttribute("PlotIndex")
    if plotIndex then
        local success, res = RemoteEvents.WaterPlot:InvokeServer(plotIndex)
        print("[ProximityHandler] Water result:", success, res, "from plot", plotIndex)
    end
end

-- Connect to all proximity prompts in the world
local function ConnectToFolder(folder: Instance?)
    if not folder then
        return
    end

    for _, descendant in ipairs(folder:GetDescendants()) do
        if descendant:IsA("ProximityPrompt") then
            descendant.Triggered:Connect(OnResourceGathered)
            descendant.Triggered:Connect(OnPlotHarvested)
            descendant.Triggered:Connect(OnPlotWatered)
        end
    end
end

-- Wait for world to load
local workspace = game:GetService("Workspace")
local habitatWorld = workspace:WaitForChild("HabitatWorld", 10)
if habitatWorld then
    ConnectToFolder(habitatWorld)

    -- Watch for new prompts added dynamically during gameplay
    habitatWorld.DescendantAdded:Connect(function(descendant)
        if descendant:IsA("ProximityPrompt") then
            descendant.Triggered:Connect(OnResourceGathered)
            descendant.Triggered:Connect(OnPlotHarvested)
            descendant.Triggered:Connect(OnPlotWatered)
        end
    end)
end

print("[ProximityHandler] Client proximity prompts connected successfully.")
