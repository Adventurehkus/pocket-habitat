--!strict

local DataStoreService = game:GetService("DataStoreService")

local Constants =
    require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Constants"))

local DataStoreManager = {}

local DATA_STORE_KEY = "PocketHabitat_v2_PlayerData"
local playerDataStore = DataStoreService:GetDataStore(DATA_STORE_KEY)

local activeSessions: { [number]: any } = {}

function DataStoreManager.getDefaultData(userId: number)
    return {
        userId = userId,
        bells = 50,
        inventory = {
            [Constants.RESOURCES.WOOD] = 5,
            [Constants.RESOURCES.STONE] = 3,
            [Constants.RESOURCES.DEWDROP] = 10,
            [Constants.RESOURCES.SEED_BERRY] = 2,
        },
        questsCompleted = {},
        currentQuest = "q1_wood",
        creaturesDiscovered = {},
        upgrades = {
            plot_expansion = 1,
            storage_expansion = 1,
        },
        plots = {
            [1] = { seedId = nil, plantedTime = 0, waterCount = 0, stage = 0 },
            [2] = { seedId = nil, plantedTime = 0, waterCount = 0, stage = 0 },
        },
        sessionLock = nil,
    }
end

function DataStoreManager.loadPlayerData(player: Player): any
    local userId = player.UserId
    if activeSessions[userId] then
        return activeSessions[userId]
    end

    local dataKey = "User_" .. tostring(userId)
    local success, result
    for attempt = 1, 3 do
        success, result = pcall(function()
            return playerDataStore:GetAsync(dataKey)
        end)
        if success then
            break
        else
            task.wait(2 * attempt)
        end
    end

    local data
    if success then
        if result ~= nil then
            data = result
            -- Ensure all default keys exist
            local default = DataStoreManager.getDefaultData(userId)
            for k, v in pairs(default) do
                if data[k] == nil then
                    data[k] = v
                end
            end
        else
            data = DataStoreManager.getDefaultData(userId)
        end
    else
        warn(
            "Failed to load DataStore after retries for user "
                .. tostring(userId)
                .. ": "
                .. tostring(result)
        )
        player:Kick(
            "Failed to load your save data due to a temporary DataStore service error. Please rejoin to protect your progress."
        )
        return nil
    end

    activeSessions[userId] = data
    return data
end

function DataStoreManager.savePlayerData(player: Player)
    local userId = player.UserId
    local data = activeSessions[userId]
    if not data then
        return
    end

    local dataKey = "User_" .. tostring(userId)
    local success, err
    for attempt = 1, 3 do
        success, err = pcall(function()
            playerDataStore:SetAsync(dataKey, data)
        end)
        if success then
            break
        else
            task.wait(2 * attempt)
        end
    end

    if not success then
        warn(
            "Failed to save DataStore after retries for user "
                .. tostring(userId)
                .. ": "
                .. tostring(err)
        )
    end
end

function DataStoreManager.removeSession(player: Player)
    local userId = player.UserId
    DataStoreManager.savePlayerData(player)
    activeSessions[userId] = nil
end

function DataStoreManager.getSession(player: Player)
    return activeSessions[player.UserId]
end

return DataStoreManager
