--!strict

local Players = game:GetService("Players")
local HabitatManager = require(script.Parent.HabitatManager)
local DataStoreManager = require(script.Parent.DataStoreManager)
local CharacterSpawner = require(script.Parent.CharacterSpawner)
local WorldBuilder = require(script.Parent.WorldBuilder)

WorldBuilder.init()
HabitatManager.init()
DataStoreManager.init()

local function onPlayerAdded(player: Player)
    DataStoreManager.loadPlayerData(player, function(sessionData)
        local spawnData = {
            position = Vector3.new(0, 5, 0),
            orientation = Vector3.zero,
        }

        if type(sessionData) == "table" and type(sessionData.characterSpawnData) == "table" then
            local savedPosition = sessionData.characterSpawnData.position
            if typeof(savedPosition) == "Vector3" then
                spawnData.position = savedPosition
            end

            local savedOrientation = sessionData.characterSpawnData.orientation
            if typeof(savedOrientation) == "Vector3" then
                spawnData.orientation = savedOrientation
            end
        end

        CharacterSpawner.spawnOrRestoreCharacter(player, spawnData)
        DataStoreManager.handleClientSessionRequest(player)
    end)
end

Players.PlayerAdded:Connect(onPlayerAdded)

for _, player in ipairs(Players:GetPlayers()) do
    task.defer(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player: Player)
    local sessionReleased = DataStoreManager.releaseSession(player)
    if not sessionReleased then
        warn("Session release failed during PlayerRemoving for " .. tostring(player.UserId))
    end

    CharacterSpawner.cleanupPlayer(player)
    HabitatManager.removeHabitat(player)
end)
