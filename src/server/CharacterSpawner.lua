--!strict

local CharacterSpawner = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreManager = require(script.Parent.DataStoreManager)
local HabitatManager = require(script.Parent.HabitatManager)
local RemoteEvents = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RemoteEvents"))

local RESPAWN_COOLDOWN = 5
local REQUEST_INTERVAL = 0.5
local RESPAWN_HEIGHT_LIMIT = 200
local lastRespawnTimes: { [Player]: number } = {}
local lastRequestTimes: { [Player]: number } = {}
local respawnsInProgress: { [Player]: boolean } = {}

local function isInsideHabitat(habitat: Folder, position: Vector3): boolean
    local offset = habitat:GetAttribute("BaseOffset")
    if typeof(offset) ~= "Vector3" then
        return false
    end

    return math.abs(position.X - offset.X) <= 45
        and math.abs(position.Z - offset.Z) <= 45
        and position.Y >= 1
        and position.Y <= RESPAWN_HEIGHT_LIMIT
end

local function getSpawnPosition(player: Player, spawnData): Vector3
    local habitat = HabitatManager.getHabitat(player)
    if not habitat then
        return Vector3.new(0, 5, 0)
    end

    local habitatPosition = habitat:GetAttribute("SpawnPosition")
    if typeof(habitatPosition) ~= "Vector3" then
        habitatPosition = Vector3.new(0, 5, 0)
    end

    if
        type(spawnData) == "table"
        and typeof(spawnData.position) == "Vector3"
        and isInsideHabitat(habitat, spawnData.position)
    then
        return spawnData.position
    end

    return habitatPosition
end

local function monitorCharacter(player: Player, character: Model)
    task.spawn(function()
        while player.Parent and player.Character == character do
            local rootPart = character:FindFirstChild("HumanoidRootPart")
            if rootPart and rootPart:IsA("BasePart") then
                local x, y, z = rootPart.CFrame:ToOrientation()
                DataStoreManager.updateCharacterSpawnData(
                    player,
                    rootPart.Position,
                    Vector3.new(math.deg(x), math.deg(y), math.deg(z))
                )
            end
            task.wait(5)
        end
    end)
end

local function spawnOrRestoreCharacter(player: Player, spawnData): Model?
    if not DataStoreManager.getSession(player) or not HabitatManager.getHabitat(player) then
        return nil
    end

    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not character or not character.Parent or not humanoid or humanoid.Health <= 0 then
        local success, loadError = pcall(function()
            player:LoadCharacterAsync()
        end)
        if not success then
            warn(
                "Failed to load character for "
                    .. tostring(player.UserId)
                    .. ": "
                    .. tostring(loadError)
            )
            return nil
        end
        character = player.Character
    end

    if not character then
        warn("Character load completed without a character for " .. tostring(player.UserId))
        return nil
    end

    local rootPart = character:WaitForChild("HumanoidRootPart", 10)
    if not rootPart or not rootPart:IsA("BasePart") then
        warn("Character root part was not available for " .. tostring(player.UserId))
        return nil
    end

    local habitat = HabitatManager.getHabitat(player)
    if not habitat then
        return nil
    end

    local position = getSpawnPosition(player, spawnData)
    local orientation = Vector3.zero
    if
        type(spawnData) == "table"
        and typeof(spawnData.position) == "Vector3"
        and typeof(spawnData.orientation) == "Vector3"
        and isInsideHabitat(habitat, spawnData.position)
    then
        orientation = Vector3.new(
            math.clamp(spawnData.orientation.X, -360, 360),
            math.clamp(spawnData.orientation.Y, -360, 360),
            math.clamp(spawnData.orientation.Z, -360, 360)
        )
    end

    rootPart.CFrame = CFrame.new(position)
        * CFrame.Angles(math.rad(orientation.X), math.rad(orientation.Y), math.rad(orientation.Z))
    local x, y, z = rootPart.CFrame:ToOrientation()
    DataStoreManager.updateCharacterSpawnData(
        player,
        rootPart.Position,
        Vector3.new(math.deg(x), math.deg(y), math.deg(z))
    )
    monitorCharacter(player, character)
    return character
end

function CharacterSpawner.spawnOrRestoreCharacter(player: Player, spawnData): Model?
    if respawnsInProgress[player] then
        return nil
    end
    respawnsInProgress[player] = true

    local succeeded, characterOrError = pcall(spawnOrRestoreCharacter, player, spawnData)
    respawnsInProgress[player] = nil
    if not succeeded then
        warn(
            "Character spawn failed for "
                .. tostring(player.UserId)
                .. ": "
                .. tostring(characterOrError)
        )
        return nil
    end

    return characterOrError
end

function CharacterSpawner.cleanupPlayer(player: Player)
    if player.Character and player.Character.Parent then
        player.Character:Destroy()
    end

    lastRespawnTimes[player] = nil
    lastRequestTimes[player] = nil
    respawnsInProgress[player] = nil
end

local function validateRespawnRequest(player: Player): boolean
    if not player.Parent or not DataStoreManager.getSession(player) then
        return false
    end
    if not HabitatManager.getHabitat(player) then
        return false
    end

    local character = player.Character
    if not character then
        return true
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    return humanoid ~= nil and humanoid.Health <= 0
end

local function onRespawnRequest(player: Player)
    local now = os.clock()
    if respawnsInProgress[player] then
        return
    end
    if lastRequestTimes[player] and now - lastRequestTimes[player] < REQUEST_INTERVAL then
        return
    end
    lastRequestTimes[player] = now

    if lastRespawnTimes[player] and now - lastRespawnTimes[player] < RESPAWN_COOLDOWN then
        return
    end
    if not validateRespawnRequest(player) then
        return
    end

    local sessionData = DataStoreManager.getSession(player)
    if not sessionData then
        return
    end

    local character =
        CharacterSpawner.spawnOrRestoreCharacter(player, sessionData.characterSpawnData)
    if character then
        lastRespawnTimes[player] = os.clock()
    end
end

RemoteEvents.RespawnCharacter.OnServerEvent:Connect(onRespawnRequest)

return CharacterSpawner
