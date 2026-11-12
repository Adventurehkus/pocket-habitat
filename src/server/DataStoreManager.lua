--!strict
local DataStoreService = game:GetService("DataStoreService")

local Constants =
    require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Constants"))

local DataStoreManager = {}

local DATA_STORE_KEY = "PocketHabitat_v2_PlayerData"
local playerDataStore = DataStoreService:GetDataStore(DATA_STORE_KEY)

-- Session lease constants
local SESSION_LEASE_DURATION = 300 -- 5 minutes
local RENEWAL_INTERVAL = 240 -- 4 minutes

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

function DataStoreManager.acquireSession(player: Player): string?
    local userId = player.UserId
    local existingSession = activeSessions[userId]
    if existingSession then
        if existingSession.sessionLock then
            return existingSession.sessionLock
        end
        return nil
    end

    local dataKey = "User_" .. tostring(userId)
    local sessionToken = tostring(userId)
        .. "_"
        .. tostring(os.time())
        .. "_"
        .. tostring(math.random(1000000))

    local success, result = pcall(function()
        return playerDataStore:UpdateAsync(dataKey, function(oldValue)
            if oldValue then
                local lastModified = oldValue.lastModified or 0
                local timeSince = os.time() - lastModified
                if timeSince < SESSION_LEASE_DURATION then
                    error("Session already owned by another server")
                end
                return {
                    data = oldValue.data,
                    lockOwner = sessionToken,
                    lastModified = os.time(),
                }
            else
                local defaultData = DataStoreManager.getDefaultData(userId)
                return {
                    data = defaultData,
                    lockOwner = sessionToken,
                    lastModified = os.time(),
                }
            end
        end)
    end)

    if not success then
        if result and result:find("Session already owned") then
            return nil
        end
        warn(
            "Failed to acquire session lease for user "
                .. tostring(userId)
                .. ": "
                .. tostring(result)
        )
        return nil
    end

    local sessionData = result.data
    sessionData.sessionLock = sessionToken
    activeSessions[userId] = sessionData

    task.delay(RENEWAL_INTERVAL, function()
        if activeSessions[userId] and activeSessions[userId].sessionLock == sessionToken then
            DataStoreManager.renewSession(player, sessionToken)
        end
    end)

    return sessionToken
end

function DataStoreManager.getSession(player: Player): any
    local userId = player.UserId
    return activeSessions[userId] or nil
end

function DataStoreManager.savePlayerData(player: Player, sessionToken: string?)
    local userId = player.UserId
    local data = activeSessions[userId]
    if not data then
        return
    end

    if sessionToken and data.sessionLock ~= sessionToken then
        warn("Session token mismatch during save for user " .. tostring(userId))
        return
    end

    local dataKey = "User_" .. tostring(userId)
    local success, err
    for attempt = 1, 3 do
        success, err = pcall(function()
            if sessionToken then
                local record = playerDataStore:GetAsync(dataKey)
                local current = record and record.data
                local lockOwner = record and record.lockOwner
                if not current or lockOwner ~= sessionToken then
                    error("Session lock lost or stale")
                end
                playerDataStore:SetAsync(dataKey, {
                    data = current,
                    lockOwner = sessionToken,
                    lastModified = os.time(),
                })
            else
                playerDataStore:SetAsync(dataKey, data)
            end
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
        return
    end

    if sessionToken then
        data.sessionLock = nil
    end
end

function DataStoreManager.releaseSession(player: Player, sessionToken: string?)
    local userId = player.UserId
    local data = activeSessions[userId]
    if not data then
        return
    end

    if sessionToken and data.sessionLock ~= sessionToken then
        warn("Session token mismatch during release for user " .. tostring(userId))
        return
    end

    DataStoreManager.savePlayerData(player, sessionToken)

    data.sessionLock = nil
    activeSessions[userId] = nil

    RemoteEvents.SyncData:FireClient(player, { sessionEnded = true })
end

function DataStoreManager.renewSession(player: Player, sessionToken: string)
    local userId = player.UserId
    local data = activeSessions[userId]
    if not data or data.sessionLock ~= sessionToken then
        return
    end

    local dataKey = "User_" .. tostring(userId)
    local success, result = pcall(function()
        return playerDataStore:UpdateAsync(dataKey, function(oldValue)
            if not oldValue then
                error("No existing session data")
            end
            if oldValue.lockOwner ~= sessionToken then
                error("Session ownership changed")
            end
            return {
                data = oldValue.data,
                lockOwner = sessionToken,
                lastModified = os.time(),
            }
        end)
    end)

    if not success then
        warn(
            "Failed to renew session lease for user "
                .. tostring(userId)
                .. ": "
                .. tostring(result)
        )
        DataStoreManager.releaseSession(player, sessionToken)
    end
end

function DataStoreManager.handleClientSessionRequest(player: Player)
    local userId = player.UserId
    local existingSession = activeSessions[userId]

    local sessionToken = DataStoreManager.acquireSession(player)
    if not sessionToken then
        if existingSession and existingSession.sessionLock then
            RemoteEvents.SyncData:FireClient(player, { sessionContested = true })
            return
        end
        RemoteEvents.SyncData:FireClient(player, { sessionUnavailable = true })
        return
    end

    RemoteEvents.SyncData:FireClient(player, {
        sessionToken = sessionToken,
        playerData = activeSessions[userId],
    })

    task.delay(RENEWAL_INTERVAL, function()
        if activeSessions[userId] and activeSessions[userId].sessionLock == sessionToken then
            DataStoreManager.renewSession(player, sessionToken)
        end
    end)
end

return DataStoreManager
