--!strict

local Workspace = game:GetService("Workspace")
local WorldBuilder = require(script.Parent:WaitForChild("WorldBuilder"))

local HabitatManager = {}

local habitatsFolder = Instance.new("Folder")
habitatsFolder.Name = "Habitats"
habitatsFolder.Parent = Workspace

local playerHabitats: { [number]: Folder } = {}

function HabitatManager.init()
    print("[HabitatManager] Initialized")
end

function HabitatManager.allocateHabitat(player: Player): Folder
    local habitat = Instance.new("Folder")
    habitat.Name = "Habitat_" .. tostring(player.UserId)
    -- Use a deterministic offset based on UserId for consistency
    habitat:SetAttribute(
        "BaseOffset",
        Vector3.new((player.UserId % 1000) * 0.1, 0, (player.UserId % 1000) * 0.1)
    )
    habitat.Parent = habitatsFolder

    WorldBuilder.buildHabitat(habitat, player)

    playerHabitats[player.UserId] = habitat
    return habitat
end

function HabitatManager.getHabitat(player: Player): Folder?
    return playerHabitats[player.UserId]
end

function HabitatManager.removeHabitat(player: Player)
    local habitat = playerHabitats[player.UserId]
    if habitat then
        habitat:Destroy()
        playerHabitats[player.UserId] = nil
    end
end

return HabitatManager
