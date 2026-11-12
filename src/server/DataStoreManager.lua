--!strict

local DataStoreManager = {}
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemoteEvents = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RemoteEvents"))

local PLAYER_DATA_STORE = "PlayerDataStoreV1"
local activeSessions = {}

local function makeDefaultSessionData(userId: number)
    return {
        userId = userId,
        currency = 0,
        inventory = {},
        quests = {},
        plants = {},
        upgrades = {},
        characterSpawnData = {
            position = Vector3.new(0, 5, 0),
            orientation = Vector3.zero,
        },
    }
end

function DataStoreManager.getDefaultData(userId: number)
    return makeDefaultSessionData(userId)
end

function DataStoreManager.init()
    local success, err = pcall(function()
        return DataStoreService:GetDataStore(PLAYER_DATA_STORE)
    end)
    if not success then
        warn("DataStoreManager init failed: " .. tostring(err))
    end
end

function DataStoreManager.loadPlayerData(player, callback)
    local userId = player and player.UserId or 0
    local dataKey = "player_" .. tostring(userId)
    local playerDataStore = DataStoreService:GetDataStore(PLAYER_DATA_STORE)

    local success, savedData = pcall(function()
        return playerDataStore:GetAsync(dataKey)
    end)

    local sessionData = savedData
    if not success or type(sessionData) ~= "table" then
        if success and sessionData == nil then
            sessionData = makeDefaultSessionData(userId)
        else
            sessionData = makeDefaultSessionData(userId)
            warn(
                "Failed to load persisted data for player "
                    .. tostring(userId)
                    .. ": "
                    .. tostring(savedData)
            )
        end
    end

    activeSessions[player] = {
        data = sessionData,
        sessionToken = tostring(os.clock()) .. "_" .. tostring(userId),
        lastModified = os.time(),
    }

    if callback then
        callback(sessionData)
    end

    return sessionData
end

function DataStoreManager.getSession(player)
    local session = activeSessions[player]
    if session then
        return session.data
    end

    if player and player.UserId then
        return makeDefaultSessionData(player.UserId)
    end

    return makeDefaultSessionData(0)
end

function DataStoreManager.acquireSession(player, token)
    local sessionToken = token or tostring(os.clock()) .. "_" .. tostring(player.UserId)
    local dataKey = "player_" .. tostring(player.UserId)
    local playerDataStore = DataStoreService:GetDataStore(PLAYER_DATA_STORE)

    local success, result = pcall(function()
        local current = playerDataStore:GetAsync(dataKey)
        if
            type(current) == "table"
            and type(current.lockOwner) == "string"
            and current.lockOwner ~= sessionToken
        then
            return nil
        end

        local freshData = current and type(current.data) == "table" and current.data
            or makeDefaultSessionData(player.UserId)
        local leaseValue = {
            data = freshData,
            lockOwner = sessionToken,
            lastModified = os.time(),
        }

        playerDataStore:SetAsync(dataKey, leaseValue)
        return leaseValue
    end)

    if not success or not result then
        warn(
            "Session acquisition failed for player "
                .. tostring(player.UserId)
                .. ": "
                .. tostring(result)
        )
        return nil
    end

    activeSessions[player] = {
        data = result.data,
        sessionToken = sessionToken,
        lastModified = os.time(),
    }

    return sessionToken
end

function DataStoreManager.renewSession(player, sessionToken)
    local session = activeSessions[player]
    if not session then
        return false
    end

    if sessionToken and session.sessionToken ~= sessionToken then
        return false
    end

    session.lastModified = os.time()
    return true
end

function DataStoreManager.updateCharacterSpawnData(player, position, orientation)
    local session = activeSessions[player]
    if not session then
        return false
    end

    session.data.characterSpawnData = {
        position = typeof(position) == "Vector3" and position or Vector3.new(0, 5, 0),
        orientation = typeof(orientation) == "Vector3" and orientation or Vector3.zero,
    }

    return true
end

function DataStoreManager.savePlayerData(player, sessionToken)
    local session = activeSessions[player]
    if not session then
        return false
    end

    local suppliedToken = sessionToken or session.sessionToken
    if session.sessionToken ~= suppliedToken then
        return false
    end

    if player.Character and player.Character.PrimaryPart then
        local position = player.Character.PrimaryPart.Position
        local lookVector = player.Character.PrimaryPart.CFrame.LookVector
        session.data.characterSpawnData = {
            position = position,
            orientation = Vector3.new(lookVector.X, lookVector.Y, lookVector.Z),
        }
    end

    local dataKey = "player_" .. tostring(player.UserId)
    local playerDataStore = DataStoreService:GetDataStore(PLAYER_DATA_STORE)

    local success, storedValue = pcall(function()
        return playerDataStore:UpdateAsync(dataKey, function(oldValue)
            if
                type(oldValue) == "table"
                and type(oldValue.lockOwner) == "string"
                and oldValue.lockOwner ~= suppliedToken
            then
                error("Session lock lost or stale")
            end

            return {
                data = session.data,
                lockOwner = suppliedToken,
                lastModified = os.time(),
            }
        end)
    end)

    if not success then
        warn(
            "Failed to persist player data for "
                .. tostring(player.UserId)
                .. ": "
                .. tostring(storedValue)
        )
        return false
    end

    session.lastModified = os.time()
    return true
end

function DataStoreManager.releaseSession(player, sessionToken)
    local session = activeSessions[player]
    if not session then
        return true
    end

    if sessionToken and session.sessionToken ~= sessionToken then
        warn("Session token mismatch while releasing player session: " .. tostring(player.UserId))
        return false
    end

    local saved = DataStoreManager.savePlayerData(player, session.sessionToken)
    if not saved then
        warn(
            "Failed to persist player data during release for user "
                .. tostring(player.UserId)
                .. "; in-memory data retained."
        )
        return false
    end

    activeSessions[player] = nil
    return true
end

function DataStoreManager.handleClientSessionRequest(player)
    local session = activeSessions[player]
    if not session then
        session = {
            data = makeDefaultSessionData(player.UserId),
            sessionToken = tostring(os.clock()) .. "_" .. tostring(player.UserId),
            lastModified = os.time(),
        }
        activeSessions[player] = session
    end

    if RemoteEvents and RemoteEvents.SyncData then
        RemoteEvents.SyncData:FireClient(player, {
            sessionToken = session.sessionToken,
            data = session.data,
        })
    end

    return session.data
end

return DataStoreManager
