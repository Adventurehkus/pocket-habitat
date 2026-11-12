--!strict

local Workspace = game:GetService("Workspace")
local WorldBuilder = require(script.Parent:WaitForChild("WorldBuilder"))

local HabitatManager = {}

local habitatsFolder = Instance.new("Folder")
habitatsFolder.Name = "Habitats"
habitatsFolder.Parent = Workspace

local playerHabitats: { [number]: Folder } = {}
local habitatSlots: { [number]: number } = {}
local availableSlots: { number } = {}
local nextSlot = 0

local gridWidth = 5
local slotSize = 100
local spacing = 25

local function releaseSlot(userId: number)
    local slot = habitatSlots[userId]
    if slot then
        habitatSlots[userId] = nil
        table.insert(availableSlots, slot)
    end
end

function HabitatManager.init()
    print("[HabitatManager] Initialized")
end

function HabitatManager.allocateHabitat(player: Player): Folder
    local userId = player.UserId

    local existingHabitat = playerHabitats[userId]
    if existingHabitat and existingHabitat.Parent == habitatsFolder then
        return existingHabitat
    elseif existingHabitat then
        existingHabitat:Destroy()
        playerHabitats[userId] = nil
        releaseSlot(userId)
    end

    local slot = table.remove(availableSlots)
    if not slot then
        slot = nextSlot
        nextSlot += 1
    end

    local gridX = slot % gridWidth
    local gridZ = math.floor(slot / gridWidth)
    local offsetX = gridX * (slotSize + spacing)
    local offsetZ = gridZ * (slotSize + spacing)

    local habitat = Instance.new("Folder")
    habitat.Name = "Habitat_" .. tostring(userId)
    habitat:SetAttribute("BaseOffset", Vector3.new(offsetX, 0, offsetZ))
    habitat:SetAttribute("OwnerUserId", userId)
    habitat.Parent = habitatsFolder

    WorldBuilder.buildHabitat(habitat, player)

    playerHabitats[userId] = habitat
    habitatSlots[userId] = slot
    return habitat
end

function HabitatManager.getHabitat(player: Player): Folder?
    local habitat = playerHabitats[player.UserId]
    if habitat and habitat.Parent == habitatsFolder then
        return habitat
    end
    return nil
end

function HabitatManager.removeHabitat(player: Player)
    local habitat = playerHabitats[player.UserId]
    if habitat then
        habitat:Destroy()
        playerHabitats[player.UserId] = nil
    end
    releaseSlot(player.UserId)
end

return HabitatManager
