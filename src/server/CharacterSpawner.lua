--!strict

local CharacterSpawner = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreManager = require(script.Parent.DataStoreManager)
local HabitatManager = require(script.Parent.HabitatManager)
local RemoteEvents = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RemoteEvents"))

local RESPAWN_COOLDOWN = 5
local lastRespawnTimes = {}

local function getSpawnPosition(player: Player, spawnData)
    local habitat = HabitatManager.getHabitat(player)
    local habitatPosition = Vector3.new(0, 5, 0)

    if habitat then
        local stored = habitat:GetAttribute("SpawnPosition")
        if typeof(stored) == "Vector3" then
            habitatPosition = stored
        end
    end

    if type(spawnData) == "table" and typeof(spawnData.position) == "Vector3" then
        return spawnData.position
    end

    return habitatPosition
end

function CharacterSpawner.spawnOrRestoreCharacter(player: Player, spawnData)
    local character = player.Character
    if not character or not character.Parent then
        local success, loadedCharacter = pcall(function()
            return player:LoadCharacter()
        end)
        if not success or not loadedCharacter then
            warn("Failed to load character for " .. tostring(player.UserId))
            return nil
        end
        character = loadedCharacter
    end

    local rootPart = character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart
    local position = getSpawnPosition(player, spawnData)
    local orientation = Vector3.zero
    if type(spawnData) == "table" and typeof(spawnData.orientation) == "Vector3" then
        orientation = spawnData.orientation
    end

    if rootPart then
        local cframe = CFrame.new(position)
        if orientation ~= Vector3.zero then
            cframe = CFrame.new(position)
                * CFrame.fromEulerAnglesXYZ(
                    math.rad(orientation.X),
                    math.rad(orientation.Y),
                    math.rad(orientation.Z)
                )
        end
        rootPart.CFrame = cframe
    end

    DataStoreManager.updateCharacterSpawnData(player, position, orientation) -- Update session data immediately after spawn/restore
    return character
end

function CharacterSpawner.cleanupPlayer(player: Player)
    if player.Character and player.Character.Parent then
        player.Character:Destroy()
    end

    if lastRespawnTimes[player] then
        lastRespawnTimes[player] = nil
    end
end

local function onRespawnRequest(player: Player)
    if not player or not player.Parent then
        return
    end

    local now = os.clock()
    if lastRespawnTimes[player] and (now - lastRespawnTimes[player]) < RESPAWN_COOLDOWN then
        return
    end

    local sessionData = DataStoreManager.getSession(player)
    local spawnPosition = Vector3.new(0, 5, 0)
    if type(sessionData) == "table" and type(sessionData.characterSpawnData) == "table" then
        local savedPosition = sessionData.characterSpawnData.position
        if typeof(savedPosition) == "Vector3" then
            spawnPosition = savedPosition
        end
    end

    local habitat = HabitatManager.getHabitat(player)
    if habitat and typeof(habitat:GetAttribute("SpawnPosition")) == "Vector3" then
        spawnPosition = habitat:GetAttribute("SpawnPosition")
    end

    local character = CharacterSpawner.spawnOrRestoreCharacter(player, {
        position = spawnPosition,
        orientation = Vector3.zero,
    })

    if character then
        lastRespawnTimes[player] = now
        DataStoreManager.updateCharacterSpawnData(player, spawnPosition, Vector3.zero)
    end
end

-- Add server-side validation and cooldown check before processing respawn request
local function validateRespawnRequest(player)
    if not player or not player.Parent then
        return false, "Player not found or removed"
    end

    local now = os.clock()
    if lastRespawnTimes[player] and (now - lastRespawnTimes[player]) < RESPAWN_COOLDOWN then
        return false, "Respawn cooldown active"
    end

    -- Verify player has a valid session
    local sessionData = DataStoreManager.getSession(player)
    if not sessionData then
        return false, "No active session found"
    end

    -- Check if player is currently in a habitat
    local habitat = HabitatManager.getHabitat(player)
    if not habitat then
        return false, "No habitat assigned"
    end

    return true
end

RemoteEvents.RespawnCharacter.OnServerEvent:Connect(function(player)
    local shouldRespawn, reason = validateRespawnRequest(player)
    if not shouldRespawn then
        warn("Respawn request rejected: " .. tostring(reason))
        return
    end

    onRespawnRequest(player)
end)

return CharacterSpawner
