--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RemoteEvents = require(Shared:WaitForChild("RemoteEvents"))
local _Constants = require(Shared:WaitForChild("Constants"))

local _player = Players.LocalPlayer

-- Functions to handle proximity prompt triggers
local function OnResourceGathered(_player: Player, prompt: ProximityPrompt)
    local nodeId = prompt:GetAttribute("NodeId")
    if nodeId then
        local success, res = RemoteEvents.GatherResource:InvokeServer(nodeId)
        print("[ProximityHandler] Gather result:", success, res, "from", nodeId)
    end
end

local function OnPlotAction(_player: Player, prompt: ProximityPrompt)
    local plotIndex = prompt:GetAttribute("PlotIndex")
    local plotAction = prompt:GetAttribute("PlotAction") or "harvest"

    if plotIndex then
        if plotAction == "water" then
            local success, res = RemoteEvents.WaterPlot:InvokeServer(plotIndex)
            print("[ProximityHandler] Water result:", success, res, "from plot", plotIndex)
        elseif plotAction == "harvest" then
            local success, res = RemoteEvents.HarvestPlot:InvokeServer(plotIndex)
            print("[ProximityHandler] Harvest result:", success, res, "from plot", plotIndex)
        elseif plotAction == "harvest_or_plant" then
            local success, res =
                RemoteEvents.InteractWithPlot:InvokeServer(plotIndex, "harvest_or_plant")
            print("[ProximityHandler] Harvest/Plant result:", success, res, "from plot", plotIndex)
        end
    end
end

-- Connect to all proximity prompts in the world
local function ConnectToFolder(folder: Instance?)
    if not folder then
        return
    end

    for _, descendant in ipairs(folder:GetDescendants()) do
        if descendant:IsA("ProximityPrompt") then
            -- Check prompt type based on attributes
            local nodeId = descendant:GetAttribute("NodeId")
            local plotIndex = descendant:GetAttribute("PlotIndex")

            if nodeId then
                descendant.Triggered:Connect(function(player)
                    OnResourceGathered(player, descendant)
                end)
            end

            if plotIndex then
                descendant.Triggered:Connect(function(player)
                    OnPlotAction(player, descendant)
                end)
            end
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
            local nodeId = descendant:GetAttribute("NodeId")
            local plotIndex = descendant:GetAttribute("PlotIndex")

            if nodeId then
                descendant.Triggered:Connect(function(player)
                    OnResourceGathered(player, descendant)
                end)
            end

            if plotIndex then
                descendant.Triggered:Connect(function(player)
                    OnPlotAction(player, descendant)
                end)
            end
        end
    end)
end

print("[ProximityHandler] Client proximity prompts connected successfully.")
