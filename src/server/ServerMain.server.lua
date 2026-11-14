--!strict

local Players = game:GetService("Players")
Players.CharacterAutoLoads = false

local HabitatManager = require(script.Parent.HabitatManager)
local DataStoreManager = require(script.Parent.DataStoreManager)
local CharacterSpawner = require(script.Parent.CharacterSpawner)
local WorldBuilder = require(script.Parent.WorldBuilder)
local ResourceManager = require(script.Parent.ResourceManager)
local PlantManager = require(script.Parent.PlantManager)
local QuestManager = require(script.Parent.QuestManager)
local CreatureManager = require(script.Parent.CreatureManager)

WorldBuilder.init()
HabitatManager.init()
DataStoreManager.init()
ResourceManager.init()
PlantManager.init()
QuestManager.init()
CreatureManager.checkDiscoveries = CreatureManager.checkDiscoveries -- Ensure function is accessible

local initializingPlayers: { [Player]: boolean } = {}
local cleaningPlayers: { [Player]: boolean } = {}

local function stopPlayerSession(player: Player, reason: string)
    warn("Unable to start a safe player session for " .. tostring(player.UserId) .. ": " .. reason)
    DataStoreManager.releaseSession(player)
    CharacterSpawner.cleanupPlayer(player)
    ResourceManager.removePlayer(player)
    HabitatManager.removeHabitat(player)
    if player.Parent then
        player:Kick("Your habitat could not be loaded safely. Please rejoin.")
    end
end

local function onPlayerAdded(player: Player)
    if initializingPlayers[player] then
        return
    end
    initializingPlayers[player] = true

    local sessionData, loadError = DataStoreManager.loadPlayerData(player)
    if not sessionData then
        initializingPlayers[player] = nil
        stopPlayerSession(player, tostring(loadError or "Data load failed"))
        return
    end
    if not player.Parent then
        initializingPlayers[player] = nil
        DataStoreManager.releaseSession(player)
        return
    end

    HabitatManager.allocateHabitat(player, sessionData)
    local habitat = HabitatManager.getHabitat(player)
    if habitat then
        CreatureManager.restoreCreatures(player, habitat, sessionData)
    end
    local spawned, character =
        pcall(CharacterSpawner.spawnOrRestoreCharacter, player, sessionData.characterSpawnData)
    if not spawned or not character then
        initializingPlayers[player] = nil
        stopPlayerSession(player, if spawned then "Character spawn failed" else tostring(character))
        return
    end

    if player.Parent then
        DataStoreManager.handleClientSessionRequest(player)
    end
    initializingPlayers[player] = nil
end

local function cleanupPlayer(player: Player)
    if cleaningPlayers[player] then
        while cleaningPlayers[player] do
            task.wait(0.1)
        end
        return
    end
    cleaningPlayers[player] = true

    local sessionReleased = DataStoreManager.releaseSession(player)
    if not sessionReleased then
        warn("Session release failed during cleanup for " .. tostring(player.UserId))
    end

    CreatureManager.cleanupPlayer(player)
    CharacterSpawner.cleanupPlayer(player)
    ResourceManager.removePlayer(player)
    HabitatManager.removeHabitat(player)
    initializingPlayers[player] = nil
    cleaningPlayers[player] = nil
end

Players.PlayerAdded:Connect(function(player: Player)
    task.spawn(onPlayerAdded, player)
end)

Players.PlayerRemoving:Connect(cleanupPlayer)

for _, player in ipairs(Players:GetPlayers()) do
    task.spawn(onPlayerAdded, player)
end

game:BindToClose(function()
    local deadline = os.clock() + 25
    local pending = 0
    for _, player in ipairs(Players:GetPlayers()) do
        pending += 1
        task.spawn(function()
            cleanupPlayer(player)
            DataStoreManager.releaseSession(player, nil, deadline)
            pending -= 1
        end)
    end

    while pending > 0 do
        local remaining = deadline - os.clock()
        if remaining <= 0 then
            break
        end
        task.wait(math.min(0.1, remaining))
    end
    if pending > 0 then
        warn("Timed out while releasing player sessions during server shutdown")
    end
end)
