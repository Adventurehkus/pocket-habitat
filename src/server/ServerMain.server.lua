--!strict

-- Server main entry point and lifecycle management
-- Initializes all managers and event handlers for Pocket Habitat

local Players = game:GetService("Players")

-- Require all managers
local DataStoreManager = require(script.Parent:WaitForChild("DataStoreManager"))
local WorldBuilder = require(script.Parent:WaitForChild("WorldBuilder"))
local ResourceManager = require(script.Parent:WaitForChild("ResourceManager"))
local QuestManager = require(script.Parent:WaitForChild("QuestManager"))
local PlantManager = require(script.Parent:WaitForChild("PlantManager"))
local EconomyManager = require(script.Parent:WaitForChild("EconomyManager"))
local HabitatManager = require(script.Parent:WaitForChild("HabitatManager"))
local CreatureManager = require(script.Parent:WaitForChild("CreatureManager"))

-- Initialize all managers in correct order
print("[ServerMain] Initializing Pocket Habitat Server...")

-- WorldBuilder must initialize first to set up global workspace structures
WorldBuilder.init()

-- Initialize remaining managers (DataStoreManager doesn't require init)
ResourceManager.init()
QuestManager.init()
PlantManager.init()
EconomyManager.init()
HabitatManager.init()
CreatureManager.init()

print("[ServerMain] All managers initialized successfully")

-- Player lifecycle event handlers

-- When a player joins the game
Players.PlayerAdded:Connect(function(player: Player)
    print(
        "[ServerMain] Player added: " .. player.Name .. " (ID: " .. tostring(player.UserId) .. ")"
    )

    -- Allocate a habitat for the player
    local habitat = HabitatManager.allocateHabitat(player)
    if habitat then
        print("[ServerMain] Habitat allocated for player: " .. player.Name)
    else
        warn("[ServerMain] Failed to allocate habitat for player: " .. player.Name)
    end

    -- Request session token and player data from DataStoreManager
    DataStoreManager.handleClientSessionRequest(player)

    -- IMPORTANT: Character spawning/restoration now occurs AFTER DataStoreManager
    -- has successfully loaded the player's session data to prevent race conditions
    -- This ensures players are only spawned once, at the correct saved position

    -- Restore character position from saved data or habitat
    local characterSpawner = require(script.Parent:WaitForChild("CharacterSpawner"))
    local sessionData = DataStoreManager.getSession(player)
    if sessionData and sessionData.characterSpawnData then
        characterSpawner.restoreCharacter(player, sessionData.characterSpawnData)
    elseif habitat then
        local baseOffset = habitat:GetAttribute("BaseOffset") or Vector3.new(0, 0, 0)
        characterSpawner.spawnCharacter(player, Vector3.new(0, 5, 0) + baseOffset)
    else
        characterSpawner.spawnCharacter(player, Vector3.new(0, 5, 0))
    end
end)

-- When a player leaves the game
Players.PlayerRemoving:Connect(function(player: Player)
    print(
        "[ServerMain] Player removing: "
            .. player.Name
            .. " (ID: "
            .. tostring(player.UserId)
            .. ")"
    )

    -- Release the player's session to save data
    local sessionData = DataStoreManager.getSession(player)
    if sessionData and sessionData.sessionLock then
        local success = DataStoreManager.releaseSession(player, sessionData.sessionLock)
        if success then
            print("[ServerMain] Session released for player: " .. player.Name)
        else
            warn("[ServerMain] Failed to release session for player: " .. player.Name)
        end
    end

    -- Clean up player's habitat
    HabitatManager.removeHabitat(player)
    print("[ServerMain] Habitat removed for player: " .. player.Name)

    -- Clean up resource cooldowns
    ResourceManager.removePlayer(player)
    print("[ServerMain] Resource cooldowns cleared for player: " .. player.Name)
end)

-- When the server is shutting down
local function onBindToClose()
    print("[ServerMain] Server shutting down - cleaning up all active sessions...")

    -- Iterate through all connected players and release their sessions
    for _, player in ipairs(Players:GetPlayers()) do
        local sessionData = DataStoreManager.getSession(player)
        if sessionData and sessionData.sessionLock then
            local success = DataStoreManager.releaseSession(player, sessionData.sessionLock)
            if success then
                print("[ServerMain] Released session for player during shutdown: " .. player.Name)
            else
                warn(
                    "[ServerMain] Failed to release session for player during shutdown: "
                        .. player.Name
                )
            end
        end
    end

    -- Note: Habitats will be automatically cleaned up when players disconnect
    print("[ServerMain] All sessions cleaned up during shutdown")
end

-- Connect the shutdown handler
game:BindToClose(onBindToClose)

print("[ServerMain] Server initialization complete - ready for players!")
