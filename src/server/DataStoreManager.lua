--!strict

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = Shared:WaitForChild("Constants")
local RemoteEvents = require(Shared:WaitForChild("RemoteEvents"))

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
        characterSpawnData = {
            position = Vector3.new(0, 5, 0),
            orientation = Vector3.new(0, 0, 0),
        },
        sessionLock = nil,
    }
end

local function scheduleRenewal(player: Player, sessionToken: string)
    local userId = player.UserId
    local sessionData = activeSessions[userId]
    if not sessionData then
        return
    end
    if sessionData.sessionLock ~= sessionToken then
        return
    end
    if sessionData.renewalTask then
        task.cancel(sessionData.renewalTask)
    end
    sessionData.renewalTask = task.delay(RENEWAL_INTERVAL, function()
        DataStoreManager.renewSession(player, sessionToken)
    end)
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
    scheduleRenewal(player, sessionToken)
    return sessionToken
end

function DataStoreManager.getSession(player: Player): any
    local userId = player.UserId
    return activeSessions[userId] or nil
end

function DataStoreManager.updateCharacterSpawnData(
    player: Player,
    position: Vector3,
    orientation: Vector3?
)
    local sessionData = DataStoreManager.getSession(player)
    if sessionData and sessionData.characterSpawnData then
        sessionData.characterSpawnData.position = position
        sessionData.characterSpawnData.orientation = orientation or Vector3.new(0, 0, 0)
        print(
            "[DataStoreManager] Updated character spawn data for user "
                .. tostring(player.UserId)
                .. " to position "
                .. tostring(position)
        )
    end
end

function DataStoreManager.savePlayerData(player: Player, sessionToken: string?): boolean
    local userId = player.UserId
    local data = activeSessions[userId]
    if not data then
        return true
    end
    if sessionToken and data.sessionLock ~= sessionToken then
        warn("Session token mismatch during save for user " .. tostring(userId))
        return false
    end
    local dataKey = "User_" .. tostring(userId)
    local success, err
    for attempt = 1, 3 do
        success, err = pcall(function()
            if sessionToken then
                playerDataStore:UpdateAsync(dataKey, function(oldValue)
                    if not oldValue then
                        error("No existing session data")
                    end
                    if oldValue.lockOwner ~= sessionToken then
                        -- This is expected during contention - don't treat as fatal error
                        error("Session ownership changed during save")
                    end
                    return {
                        data = data,
                        lockOwner = sessionToken,
                        lastModified = os.time(),
                        characterSpawnData = data.characterSpawnData,
                    }
                end)
            else
                playerDataStore:SetAsync(dataKey, {
                    data = data,
                    lockOwner = nil,
                    lastModified = os.time(),
                    characterSpawnData = data.characterSpawnData,
                })
            end
        end)
        if success then
            break
        else
            -- Check if this was a session lock contention error
            if
                type(err) == "string"
                and (err:find("Session ownership") or err:find("Session lock"))
            then
                -- This is expected during contention, don't retry this specific error type
                warn(
                    "Session lock contention during save for user "
                        .. tostring(userId)
                        .. ": "
                        .. tostring(err)
                )
                return false
            end
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
        return false
    end
    return true
end

function DataStoreManager.releaseSession(player: Player, sessionToken: string?): boolean
    local userId = player.UserId
    local data = activeSessions[userId]
    if not data then
        return true
    end
    if sessionToken and data.sessionLock ~= sessionToken then
        warn("Session token mismatch during release for user " .. tostring(userId))
        return false
    end
    local saved = DataStoreManager.savePlayerData(player, sessionToken)
    if not saved then
        -- Do not clear in-memory state when the final save fails
        warn("Failed to persist player data during session release for user " .. tostring(userId))
        return false
    end
    if data.renewalTask then
        task.cancel(data.renewalTask)
        data.renewalTask = nil
    end
    data.sessionLock = nil
    activeSessions[userId] = nil
    pcall(function()
        RemoteEvents.SyncData:FireClient(player, { sessionEnded = true })
    end)
    return true
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
                data = data,
                lockOwner = sessionToken,
                lastModified = os.time(),
                characterSpawnData = data.characterSpawnData,
            }
        end)
    end)
    if success then
        -- Refresh the session data with the fresh store state to ensure time accuracy
        -- before scheduling the next renewal
        local freshStore = result
        if freshStore.data then
            data = freshStore.data
        end
        scheduleRenewal(player, sessionToken)
    else
        warn(
            "Failed to renew session lease for user "
                .. tostring(userId)
                .. ": "
                .. tostring(result)
        )
    end
end

function DataStoreManager.handleClientSessionRequest(player: Player)
    local userId = player.UserId
    local existingSession = activeSessions[userId]
    local sessionToken = DataStoreManager.acquireSession(player)
    if not sessionToken then
        if existingSession and existingSession.sessionLock then
            pcall(function()
                RemoteEvents.SyncData:FireClient(player, { sessionContested = true })
            end)
            return
        end
        pcall(function()
            RemoteEvents.SyncData:FireClient(player, { sessionUnavailable = true })
        end)
        return
    end
    pcall(function()
        RemoteEvents.SyncData:FireClient(player, {
            sessionToken = sessionToken,
            playerData = activeSessions[userId],
        })
    end)
end

return DataStoreManager
