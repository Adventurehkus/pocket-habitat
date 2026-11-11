--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RemoteEvents = require(Shared:WaitForChild("RemoteEvents"))

local player = Players.LocalPlayer

-- Handle proximity prompt triggers
local function onPromptTriggered(prompt: ProximityPrompt, triggeringPlayer: Player)
    if triggeringPlayer ~= player then
        return
    end

    local nodeId = prompt:GetAttribute("NodeId")
    local plotIndex = prompt:GetAttribute("PlotIndex")

    if nodeId then
        -- Resource gathering
        local success, res = RemoteEvents.GatherResource:InvokeServer(nodeId)
        print("Gather result:", success, res, "from", nodeId)
    elseif plotIndex then
        -- Garden plot interaction
        print("Plot interaction:", plotIndex)
    end
end

-- Connect to all proximity prompts in the world
local function connectPrompts(folder: Instance?)
    if not folder then
        return
    end

    for _, descendant in ipairs(folder:GetDescendants()) do
        if descendant:IsA("ProximityPrompt") then
            descendant.Triggered:Connect(function(p)
                onPromptTriggered(p, player)
            end)
        end
    end
end

-- Wait for world to load
local workspace = game:GetService("Workspace")
local habitatWorld = workspace:WaitForChild("HabitatWorld", 10)
if habitatWorld then
    connectPrompts(habitatWorld)

    -- Also watch for new prompts added dynamically
    habitatWorld.DescendantAdded:Connect(function(descendant)
        if descendant:IsA("ProximityPrompt") then
            descendant.Triggered:Connect(function(p)
                onPromptTriggered(p, player)
            end)
        end
    end)
end

print("[ProximityHandler] Client proximity prompts connected.")
