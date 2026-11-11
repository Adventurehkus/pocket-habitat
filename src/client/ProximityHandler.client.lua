--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RemoteEvents = require(Shared:WaitForChild("RemoteEvents"))

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

local function ConnectToPlayerHabitat(player: Player)
    local habitat = Workspace:WaitForChild("Habitats")
    habitat = habitat:FindFirstChild("Habitat_" .. tostring(player.UserId))
    if habitat then
        -- Wait for habitat to be fully initialized
        if habitat:FindFirstChild("GardenPlots") then
            ConnectToFolder(habitat)
        else
            -- Wait for garden plots to be created
            habitat.ChildAdded:Connect(function(child)
                if child.Name == "GardenPlots" then
                    ConnectToFolder(habitat)
                end
            end)
        end
    end
end

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
                descendant.Triggered:Connect(function(triggeringPlayer)
                    OnResourceGathered(triggeringPlayer, descendant)
                end)
            end

            if plotIndex then
                descendant.Triggered:Connect(function(triggeringPlayer)
                    OnPlotAction(triggeringPlayer, descendant)
                end)
            end
        end
    end
end

local habitatsFolder = Workspace:WaitForChild("Habitats")
if habitatsFolder then
    habitatsFolder.ChildAdded:Connect(function(child)
        if child:IsA("Folder") then
            -- New habitat folder added
            ConnectToFolder(child)
        end
    end)
end

-- Initialize connection when player joins
Players.PlayerAdded:Connect(function(player)
    if player == _player then
        print("[ProximityHandler] Connected to player, setting up habitat prompts")
        ConnectToPlayerHabitat(_player)
    end
end)

print("[ProximityHandler] Client proximity prompts connected successfully.")
