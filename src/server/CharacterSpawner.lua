--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local DataStoreManager = require(script.Parent:WaitForChild("DataStoreManager"))
local HabitatManager = require(script.Parent:WaitForChild("HabitatManager"))
local RemoteEvents = require(Shared:WaitForChild("RemoteEvents"))

local CharacterSpawner = {}

local lastRespawnTimes: { [number]: number } = {}
local RESPAWN_COOLDOWN = 3 -- seconds

Players.PlayerRemoving:Connect(function(player: Player)
    lastRespawnTimes[player.UserId] = nil
end)

-- Character model template
local function createCharacterModel()
    local character = Instance.new("Model")
    local humanoidRootPart = Instance.new("Part")
    humanoidRootPart.Name = "HumanoidRootPart"
    humanoidRootPart.Size = Vector3.new(2, 2, 1)
    humanoidRootPart.Shape = Enum.PartType.Block
    humanoidRootPart.BrickColor = BrickColor.new("Medium stone grey")
    humanoidRootPart.Anchored = false
    humanoidRootPart.Parent = character

    local humanoid = Instance.new("Humanoid")
    humanoid.Parent = character

    local head = Instance.new("Part")
    head.Name = "Head"
    head.Size = Vector3.new(1.5, 1.5, 1.5)
    head.Shape = Enum.PartType.Ball
    head.BrickColor = BrickColor.new("Brown")
    head.Anchored = false
    head.Parent = character

    local torso = Instance.new("Part")
    torso.Name = "Torso"
    torso.Size = Vector3.new(2, 2, 1)
    torso.Shape = Enum.PartType.Block
    torso.BrickColor = BrickColor.new("Brown")
    torso.Anchored = false
    torso.Parent = character

    local rightArm = Instance.new("Part")
    rightArm.Name = "RightArm"
    rightArm.Size = Vector3.new(0.8, 2, 0.8)
    rightArm.Shape = Enum.PartType.Block
    rightArm.BrickColor = BrickColor.new("Brown")
    rightArm.Anchored = false
    rightArm.Parent = character

    local leftArm = Instance.new("Part")
    leftArm.Name = "LeftArm"
    leftArm.Size = Vector3.new(0.8, 2, 0.8)
    leftArm.Shape = Enum.PartType.Block
    leftArm.BrickColor = BrickColor.new("Brown")
    leftArm.Anchored = false
    leftArm.Parent = character

    local rightLeg = Instance.new("Part")
    rightLeg.Name = "RightLeg"
    rightLeg.Size = Vector3.new(0.8, 2, 0.8)
    rightLeg.Shape = Enum.PartType.Block
    rightLeg.BrickColor = BrickColor.new("Brown")
    rightLeg.Anchored = false
    rightLeg.Parent = character

    local leftLeg = Instance.new("Part")
    leftLeg.Name = "LeftLeg"
    leftLeg.Size = Vector3.new(0.8, 2, 0.8)
    leftLeg.Shape = Enum.PartType.Block
    leftLeg.BrickColor = BrickColor.new("Brown")
    leftLeg.Anchored = false
    leftLeg.Parent = character

    local animate = Instance.new("LocalScript")
    animate.Name = "Animate"
    animate.Parent = character

    return character
end

-- Spawn character at specific position with orientation
function CharacterSpawner.spawnCharacter(player: Player, position: Vector3, orientation: Vector3?)
    -- Remove existing character if any
    if player.Character then
        player.Character:Destroy()
    end

    -- Create new character model
    local character = createCharacterModel()

    -- Set character position and orientation
    local cframe = CFrame.new(position)
    if orientation then
        cframe = cframe * CFrame.fromEulerAnglesXYZ(orientation.X, orientation.Y, orientation.Z)
    end

    character:PivotTo(cframe)

    -- Assign to player
    player.Character = character

    -- Set up humanoid state
    local humanoid = character:WaitForChild("Humanoid")
    -- Animation loading corrected
    local animation = Instance.new("Animation")
    animation.AnimationId = "rbxassetid://YOUR_ANIMATION_ID"
    humanoid.Animator:LoadAnimation(animation):Play()

    print(
        "[CharacterSpawner] Spawned character for player: "
            .. player.Name
            .. " at position: "
            .. tostring(position)
    )

    -- Update character spawn data for persistence
    DataStoreManager.updateCharacterSpawnData(player, position, orientation)

    return character
end

-- Restore character from saved state
function CharacterSpawner.restoreCharacter(player: Player, savedState: table)
    local sessionData = DataStoreManager.getSession(player)
    if sessionData and sessionData.characterSpawnData then
        -- Use saved character spawn data from session
        local position = sessionData.characterSpawnData.position or Vector3.new(0, 5, 0)
        local orientation = sessionData.characterSpawnData.orientation or Vector3.new(0, 0, 0)
        local character = CharacterSpawner.spawnCharacter(player, position, orientation)
        -- Also update the session's character spawn data with the current state
        if sessionData and sessionData.characterSpawnData then
            sessionData.characterSpawnData.position = position
            sessionData.characterSpawnData.orientation = orientation
        end
        return character
    elseif savedState and savedState.position then
        -- Fallback to passed saved state
        local position = Vector3.new(
            savedState.position.X or 0,
            savedState.position.Y or 5,
            savedState.position.Z or 0
        )
        local orientation = savedState.orientation or Vector3.new(0, 0, 0)
        local character = CharacterSpawner.spawnCharacter(player, position, orientation)
        -- Update character spawn data for persistence
        DataStoreManager.updateCharacterSpawnData(player, position, orientation)
        return character
    else
        -- Default spawn location
        local character = CharacterSpawner.spawnCharacter(player, Vector3.new(0, 5, 0))
        DataStoreManager.updateCharacterSpawnData(
            player,
            Vector3.new(0, 5, 0),
            Vector3.new(0, 0, 0)
        )
        return character
    end
end

-- Event handler for character respawn requests
local function onRespawnRequest(player: Player)
    print("[CharacterSpawner] Respawn request for player: " .. player.Name)

    -- Validate player ownership and state before processing respawn
    if not player or not player.UserId then
        warn("[CharacterSpawner] Invalid player request for respawn")
        return
    end

    -- Check cooldown to prevent spam respawns
    local currentTime = os.time()
    local lastRespawnTime = lastRespawnTimes[player.UserId] or 0
    local timeSinceLastRespawn = currentTime - lastRespawnTime

    if timeSinceLastRespawn < RESPAWN_COOLDOWN then
        local remainingCooldown = RESPAWN_COOLDOWN - timeSinceLastRespawn
        warn(
            "[CharacterSpawner] Respawn request rejected due to cooldown. "
                .. player.Name
                .. " must wait "
                .. tostring(remainingCooldown)
                .. " seconds"
        )
        return
    end

    -- Check if player is already respawning or has invalid state
    if
        player.Character
        and player.Character:FindFirstChild("Humanoid")
        and player.Character.Humanoid.Health > 0
    then
        warn("[CharacterSpawner] Respawn request rejected - player is alive")
        return
    end

    -- Get player's habitat for spawn positioning
    local habitat = HabitatManager.getHabitat(player)
    if habitat then
        local baseOffset = habitat:GetAttribute("BaseOffset") or Vector3.new(0, 0, 0)
        -- Spawn near habitat center
        local spawnPosition = Vector3.new(0, 5, 0) + baseOffset
        CharacterSpawner.spawnCharacter(player, spawnPosition)
        -- Update character spawn data for persistence
        DataStoreManager.updateCharacterSpawnData(player, spawnPosition)
    else
        -- Fallback to safe spawn location
        CharacterSpawner.spawnCharacter(player, Vector3.new(0, 5, 0))
        -- Update character spawn data for persistence
        DataStoreManager.updateCharacterSpawnData(player, Vector3.new(0, 5, 0))
    end

    -- Update cooldown timestamp
    lastRespawnTimes[player.UserId] = currentTime

    print("[CharacterSpawner] Respawn successful for player: " .. player.Name)
end

RemoteEvents.RespawnCharacter.OnServerEvent:Connect(onRespawnRequest)

return CharacterSpawner
