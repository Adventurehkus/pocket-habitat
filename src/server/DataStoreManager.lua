--!strict

local DataStoreManager = {}
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))
local CharacterSpawnData =
    require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CharacterSpawnData"))
local HabitatRules = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("HabitatRules"))
local ResourceRules =
    require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ResourceRules"))
local QuestRules = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("QuestRules"))
local RemoteEvents = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RemoteEvents"))

local PLAYER_DATA_STORE = "PlayerDataStoreV1"
local SCHEMA_VERSION = 1
local SESSION_LEASE_DURATION = 300
local RENEW_INTERVAL = 120
local LEGACY_LEASE_DURATION = 600
local RELEASE_ATTEMPTS = 3
local RELEASE_RETRY_DELAYS = { 5, 15, 30 }
local activeSessions: {
    [Player]: {
        data: any,
        sessionToken: string,
        lastModified: number,
        leaseExpiresAt: number,
        renewalTask: thread?,
        releaseRetryTask: thread?,
        releaseRetryCount: number,
        busy: boolean,
        releasing: boolean,
    },
} =
    {}
local playerDataStore: GlobalDataStore? = nil

local function isFiniteNumber(value: any): boolean
    return type(value) == "number" and value == value and math.abs(value) < math.huge
end

local function isFiniteVector3(value: any): boolean
    return typeof(value) == "Vector3"
        and isFiniteNumber(value.X)
        and isFiniteNumber(value.Y)
        and isFiniteNumber(value.Z)
        and math.abs(value.X) <= 100000
        and math.abs(value.Y) <= 100000
        and math.abs(value.Z) <= 100000
end

local function makeDefaultPlot()
    return {
        seedId = nil,
        plantedTime = 0,
        waterCount = 0,
        stage = 0,
    }
end

local function makeDefaultSessionData(userId: number)
    local plots = {}
    for index = 1, 4 do
        plots[index] = makeDefaultPlot()
    end

    return {
        userId = userId,
        bells = 0,
        inventory = {},
        questsCompleted = {},
        currentQuest = Constants.QUEST_ORDER[1],
        questProgress = {},
        creaturesDiscovered = {},
        upgrades = {},
        resourceCooldowns = {},
        plots = plots,
        lockedPlots = {},
        characterSpawnData = {
            position = Vector3.new(0, 5, 0),
            orientation = Vector3.zero,
        },
    }
end

local function normalizePlotMap(plotMap: any): (any?, string?)
    if type(plotMap) ~= "table" then
        return nil, "Malformed plot data"
    end

    local normalized = {}
    for index, plot in pairs(plotMap) do
        if type(plot) ~= "table" then
            return nil, "Malformed plot entry"
        end
        plot = table.clone(plot)
        if plot.seedId ~= nil and type(plot.seedId) ~= "string" then
            return nil, "Malformed plot seed"
        end
        if
            (
                plot.plantedTime ~= nil
                and (not isFiniteNumber(plot.plantedTime) or plot.plantedTime < 0)
            )
            or (plot.waterCount ~= nil and (not isFiniteNumber(plot.waterCount) or plot.waterCount < 0 or plot.waterCount % 1 ~= 0))
            or (
                plot.stage ~= nil
                and (not isFiniteNumber(plot.stage) or plot.stage < 0 or plot.stage % 1 ~= 0)
            )
        then
            return nil, "Malformed plot state"
        end
        plot.plantedTime = plot.plantedTime or 0
        plot.waterCount = plot.waterCount or 0
        plot.stage = plot.stage or 0
        normalized[index] = plot
    end

    return normalized, nil
end

local function getDataStore(): (GlobalDataStore?, string?)
    if playerDataStore then
        return playerDataStore, nil
    end

    local success, result = pcall(function()
        return DataStoreService:GetDataStore(PLAYER_DATA_STORE)
    end)
    if not success then
        return nil, tostring(result)
    end

    playerDataStore = result
    return playerDataStore, nil
end

local function normalizeSpawnData(data: any, legacyOrientation: boolean): (any?, string?)
    local stored = data.characterSpawnData
    if stored == nil then
        return {
            position = Vector3.new(0, 5, 0),
            orientation = Vector3.zero,
        },
            nil
    end
    if type(stored) ~= "table" then
        return nil, "Malformed character spawn data"
    end

    local position = stored.position
    local orientation = stored.orientation
    if position == nil then
        position = Vector3.new(0, 5, 0)
    elseif not CharacterSpawnData.isValidVector3(position) then
        return nil, "Malformed character spawn position"
    end
    if orientation == nil then
        orientation = Vector3.zero
    elseif not CharacterSpawnData.isValidVector3(orientation) then
        return nil, "Malformed character spawn orientation"
    end

    position = CharacterSpawnData.decodeVector3(position, Vector3.new(0, 5, 0))
    orientation = CharacterSpawnData.decodeVector3(orientation, Vector3.zero)
    if not isFiniteVector3(position) or not isFiniteVector3(orientation) then
        return nil, "Non-finite character spawn data"
    end

    if legacyOrientation and orientation.Magnitude > 0.9 and orientation.Magnitude < 1.1 then
        orientation = Vector3.new(0, math.deg(math.atan2(-orientation.X, -orientation.Z)), 0)
    end

    return {
        position = position,
        orientation = orientation,
    }, nil
end

local function normalizeSessionData(
    rawData: any,
    userId: number,
    legacyOrientation: boolean?
): (any?, string?)
    if type(rawData) ~= "table" then
        return nil, "Malformed player data"
    end

    if rawData.userId ~= nil and rawData.userId ~= userId then
        return nil, "Player data belongs to a different user"
    end

    local data = table.clone(rawData)
    data.userId = userId

    if data.bells == nil then
        data.bells = data.currency or 0
    end
    if not isFiniteNumber(data.bells) or data.bells < 0 or data.bells % 1 ~= 0 then
        return nil, "Malformed Bells balance"
    end

    if data.inventory == nil then
        data.inventory = {}
    end
    if type(data.inventory) ~= "table" then
        return nil, "Malformed inventory"
    end
    for itemId, quantity in pairs(data.inventory) do
        if
            type(itemId) ~= "string"
            or not isFiniteNumber(quantity)
            or quantity < 0
            or quantity % 1 ~= 0
        then
            return nil, "Malformed inventory item"
        end
    end

    if data.questsCompleted == nil then
        data.questsCompleted = if type(data.quests) == "table" then data.quests else {}
    end
    if type(data.questsCompleted) ~= "table" then
        return nil, "Malformed quest completion data"
    end
    for questId, completed in pairs(data.questsCompleted) do
        if type(questId) ~= "string" or type(completed) ~= "boolean" then
            return nil, "Malformed quest completion entry"
        end
    end
    if data.currentQuest ~= nil and type(data.currentQuest) ~= "string" then
        return nil, "Malformed current quest"
    end
    if data.currentQuest ~= nil and not Constants.QUESTS[data.currentQuest] then
        return nil, "Unknown current quest"
    end
    if data.questProgress == nil then
        data.questProgress = {}
    elseif not QuestRules.isValidProgress(data.questProgress) then
        return nil, "Malformed quest progress"
    else
        data.questProgress = table.clone(data.questProgress)
    end
    local nextQuest = QuestRules.nextQuest(data.questsCompleted)
    if data.currentQuest ~= nextQuest then
        data.currentQuest = nextQuest
    end

    if data.creaturesDiscovered == nil then
        data.creaturesDiscovered = {}
    end
    if type(data.creaturesDiscovered) ~= "table" then
        return nil, "Malformed creature discovery data"
    end
    for creatureId, discovered in pairs(data.creaturesDiscovered) do
        if type(creatureId) ~= "string" or type(discovered) ~= "boolean" then
            return nil, "Malformed creature discovery entry"
        end
    end

    if data.upgrades == nil then
        data.upgrades = {}
    end
    if type(data.upgrades) ~= "table" then
        return nil, "Malformed upgrade data"
    end
    for upgradeId, level in pairs(data.upgrades) do
        local upgradeDef = Constants.UPGRADES[upgradeId]
        if
            type(upgradeId) ~= "string"
            or not upgradeDef
            or not isFiniteNumber(level)
            or level < 1
            or level % 1 ~= 0
            or level > upgradeDef.maxLevel
        then
            return nil, "Malformed upgrade level"
        end
    end

    if data.resourceCooldowns == nil then
        data.resourceCooldowns = {}
    elseif not ResourceRules.isValidCooldowns(data.resourceCooldowns) then
        return nil, "Malformed resource cooldown data"
    else
        data.resourceCooldowns = table.clone(data.resourceCooldowns)
    end

    local unlockedPlotCount = HabitatRules.getPlotCount(data.upgrades)
    if not unlockedPlotCount then
        return nil, "Malformed plot expansion level"
    end
    local savedPlots = data.plots
    if savedPlots == nil then
        savedPlots = {}
    end
    local savedLockedPlots = data.lockedPlots
    if savedLockedPlots == nil then
        savedLockedPlots = {}
    end
    local plots, lockedPlots, partitionError =
        HabitatRules.partitionPlotData(savedPlots, savedLockedPlots, unlockedPlotCount)
    if not plots or not lockedPlots then
        return nil, partitionError or "Malformed plot data"
    end
    local normalizedPlots, plotsError = normalizePlotMap(plots)
    if not normalizedPlots then
        return nil, plotsError
    end
    local normalizedLockedPlots, lockedPlotsError = normalizePlotMap(lockedPlots)
    if not normalizedLockedPlots then
        return nil, lockedPlotsError
    end
    data.plots = normalizedPlots
    data.lockedPlots = normalizedLockedPlots

    for index = 1, HabitatRules.INITIAL_PLOT_COUNT do
        if data.plots[index] == nil then
            data.plots[index] = makeDefaultPlot()
        end
    end
    for index = HabitatRules.INITIAL_PLOT_COUNT + 1, unlockedPlotCount do
        if data.plots[index] == nil then
            data.plots[index] = makeDefaultPlot()
        end
    end

    local spawnData, spawnError = normalizeSpawnData(data, legacyOrientation == true)
    if not spawnData then
        return nil, spawnError
    end
    data.characterSpawnData = spawnData

    return data, nil
end

local function serializeSessionData(data: any): any
    local serialized = table.clone(data)
    serialized.resourceCooldowns = table.clone(data.resourceCooldowns)
    serialized.characterSpawnData = {
        position = CharacterSpawnData.encodeVector3(data.characterSpawnData.position),
        orientation = CharacterSpawnData.encodeVector3(data.characterSpawnData.orientation),
    }
    return serialized
end

local function getRecordData(
    record: any,
    userId: number,
    sessionToken: string,
    now: number
): (any?, string?)
    if record == nil then
        return makeDefaultSessionData(userId), nil
    end
    if type(record) ~= "table" then
        return nil, "Malformed saved record"
    end

    local isEnvelope = record.data ~= nil
        or record.lockOwner ~= nil
        or record.schemaVersion ~= nil
        or record.leaseExpiresAt ~= nil
    if not isEnvelope then
        return normalizeSessionData(record, userId, true)
    end

    if
        record.schemaVersion ~= nil
        and (not isFiniteNumber(record.schemaVersion) or record.schemaVersion > SCHEMA_VERSION)
    then
        return nil, "Unsupported player data schema"
    end
    if record.schemaVersion ~= nil and record.schemaVersion < 1 then
        return nil, "Malformed player data schema"
    end
    if record.lockOwner ~= nil and type(record.lockOwner) ~= "string" then
        return nil, "Malformed session lock"
    end
    if record.data == nil then
        return nil, "Missing saved player data"
    end

    if type(record.lockOwner) == "string" and record.lockOwner ~= sessionToken then
        local expiry = record.leaseExpiresAt
        if expiry == nil and record.lastModified ~= nil then
            if not isFiniteNumber(record.lastModified) then
                return nil, "Malformed legacy session lease"
            end
            expiry = record.lastModified + LEGACY_LEASE_DURATION
        end
        if expiry ~= nil and not isFiniteNumber(expiry) then
            return nil, "Malformed session lease"
        end
        if expiry == nil or expiry > now then
            return nil, "Session is already owned by another server"
        end
    end

    return normalizeSessionData(record.data, userId, record.schemaVersion == nil)
end

local function newSessionToken(player: Player): string
    return game.JobId .. ":" .. HttpService:GenerateGUID(false) .. ":" .. tostring(player.UserId)
end

local function cancelRenewal(session)
    if session.renewalTask then
        task.cancel(session.renewalTask)
        session.renewalTask = nil
    end
end

local function cancelReleaseRetry(session)
    if session.releaseRetryTask then
        task.cancel(session.releaseRetryTask)
        session.releaseRetryTask = nil
    end
end

local function scheduleRenewal(player: Player, session, delaySeconds: number?)
    cancelRenewal(session)
    if session.releasing or activeSessions[player] ~= session then
        return
    end

    session.renewalTask = task.delay(delaySeconds or RENEW_INTERVAL, function()
        session.renewalTask = nil
        if session.releasing or activeSessions[player] ~= session then
            return
        end
        if session.busy then
            scheduleRenewal(player, session, 5)
            return
        end

        if not DataStoreManager.renewSession(player, session.sessionToken) then
            if os.time() >= session.leaseExpiresAt then
                warn("Player data lease expired for user " .. tostring(player.UserId))
                if player.Parent then
                    player:Kick("Your saved session could not be secured. Please rejoin.")
                end
                return
            end
            scheduleRenewal(player, session, math.min(30, session.leaseExpiresAt - os.time()))
        end
    end)
end

local function scheduleReleaseRetry(player: Player, session)
    if
        session.releaseRetryTask
        or session.releaseRetryCount >= #RELEASE_RETRY_DELAYS
        or activeSessions[player] ~= session
    then
        return
    end

    session.releaseRetryCount += 1
    local delaySeconds = RELEASE_RETRY_DELAYS[session.releaseRetryCount]
    session.releaseRetryTask = task.delay(delaySeconds, function()
        session.releaseRetryTask = nil
        if activeSessions[player] == session then
            DataStoreManager.releaseSession(player, session.sessionToken)
        end
    end)
end

local function updateStoredSession(player: Player, session, release: boolean): (boolean, string?)
    local store, storeError = getDataStore()
    if not store then
        return false, storeError
    end

    local serializedData = serializeSessionData(session.data)
    local callbackError: string? = nil
    local success, result = pcall(function()
        return store:UpdateAsync("player_" .. tostring(player.UserId), function(oldValue)
            callbackError = nil
            if
                type(oldValue) ~= "table"
                or oldValue.lockOwner ~= session.sessionToken
                or type(oldValue.data) ~= "table"
            then
                callbackError = "Session lock lost or stale"
                return nil
            end

            local updatedAt = os.time()
            if release then
                return {
                    schemaVersion = SCHEMA_VERSION,
                    data = serializedData,
                    lastModified = updatedAt,
                }
            end

            return {
                schemaVersion = SCHEMA_VERSION,
                data = serializedData,
                lockOwner = session.sessionToken,
                leaseExpiresAt = updatedAt + SESSION_LEASE_DURATION,
                lastModified = updatedAt,
            }
        end)
    end)

    if not success then
        return false, tostring(result)
    end
    if type(result) ~= "table" or callbackError then
        return false, callbackError or "DataStore update returned no record"
    end
    if release and result.lockOwner ~= nil then
        return false, "Session lock was not released"
    end
    if not release and result.lockOwner ~= session.sessionToken then
        return false, "Session lock was not renewed"
    end

    if not isFiniteNumber(result.lastModified) then
        return false, "DataStore update returned an invalid timestamp"
    end
    session.lastModified = result.lastModified
    session.leaseExpiresAt = if release then result.lastModified else result.leaseExpiresAt
    if not release and not isFiniteNumber(session.leaseExpiresAt) then
        return false, "DataStore update returned an invalid lease"
    end
    return true, nil
end

local function captureCharacterSpawnData(player: Player, session)
    local character = player.Character
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    if not rootPart or not rootPart:IsA("BasePart") then
        return
    end

    local x, y, z = rootPart.CFrame:ToOrientation()
    session.data.characterSpawnData = {
        position = rootPart.Position,
        orientation = Vector3.new(math.deg(x), math.deg(y), math.deg(z)),
    }
end

function DataStoreManager.getDefaultData(userId: number)
    return makeDefaultSessionData(userId)
end

function DataStoreManager.init(): boolean
    local store, err = getDataStore()
    if not store then
        warn("DataStoreManager init failed: " .. tostring(err))
        return false
    end
    return true
end

function DataStoreManager.loadPlayerData(
    player: Player,
    callback: ((any) -> ())?,
    requestedToken: string?
)
    if not player or not player:IsA("Player") then
        return nil, "Invalid player"
    end

    local existingSession = activeSessions[player]
    if existingSession then
        if existingSession.releasing then
            return nil, "Session release is in progress"
        end
        if os.time() >= existingSession.leaseExpiresAt then
            return nil, "Session lease has expired"
        end
        return existingSession.data
    end

    local store, storeError = getDataStore()
    if not store then
        warn(
            "Failed to load player data for "
                .. tostring(player.UserId)
                .. ": "
                .. tostring(storeError)
        )
        return nil, storeError
    end

    local token = requestedToken or newSessionToken(player)
    if type(token) ~= "string" or token == "" then
        return nil, "Invalid session token"
    end
    local callbackError: string? = nil
    local success, result = pcall(function()
        return store:UpdateAsync("player_" .. tostring(player.UserId), function(current)
            callbackError = nil
            local callbackNow = os.time()
            local data, dataError = getRecordData(current, player.UserId, token, callbackNow)
            if not data then
                callbackError = dataError or "Unable to validate saved player data"
                return nil
            end

            return {
                schemaVersion = SCHEMA_VERSION,
                data = serializeSessionData(data),
                lockOwner = token,
                leaseExpiresAt = callbackNow + SESSION_LEASE_DURATION,
                lastModified = callbackNow,
            }
        end)
    end)

    if not success or type(result) ~= "table" or result.lockOwner ~= token then
        local failure = if success
            then callbackError or "Session acquisition returned no owned record"
            else tostring(result)
        warn("Failed to acquire player session for " .. tostring(player.UserId) .. ": " .. failure)
        return nil, failure
    end
    if
        not isFiniteNumber(result.lastModified)
        or not isFiniteNumber(result.leaseExpiresAt)
        or result.leaseExpiresAt <= os.time()
    then
        local failure = "Session acquisition returned an expired lease"
        warn("Failed to acquire player session for " .. tostring(player.UserId) .. ": " .. failure)
        return nil, failure
    end

    local sessionData, dataError = normalizeSessionData(result.data, player.UserId)
    if not sessionData then
        warn(
            "Loaded player data is invalid for "
                .. tostring(player.UserId)
                .. ": "
                .. tostring(dataError)
        )
        return nil, dataError
    end

    local session = {
        data = sessionData,
        sessionToken = token,
        lastModified = result.lastModified,
        leaseExpiresAt = result.leaseExpiresAt,
        renewalTask = nil,
        releaseRetryTask = nil,
        releaseRetryCount = 0,
        busy = false,
        releasing = false,
    }
    activeSessions[player] = session
    scheduleRenewal(player, session)

    if callback then
        local callbackSuccess, callbackResult = pcall(callback, sessionData)
        if not callbackSuccess then
            warn("Player data callback failed: " .. tostring(callbackResult))
        end
    end

    return sessionData
end

function DataStoreManager.getSession(player: Player): any?
    local session = activeSessions[player]
    if not session or session.releasing or os.time() >= session.leaseExpiresAt then
        return nil
    end
    return session.data
end

function DataStoreManager.acquireSession(player: Player, token: string?): string?
    if token ~= nil and (type(token) ~= "string" or token == "") then
        return nil
    end
    local existingSession = activeSessions[player]
    if existingSession then
        if existingSession.releasing or os.time() >= existingSession.leaseExpiresAt then
            return nil
        end
        return existingSession.sessionToken
    end

    local sessionData, err = DataStoreManager.loadPlayerData(player, nil, token)
    if not sessionData then
        warn("Session acquisition failed for " .. tostring(player.UserId) .. ": " .. tostring(err))
        return nil
    end

    local session = activeSessions[player]
    return if session then session.sessionToken else nil
end

function DataStoreManager.updateCharacterSpawnData(
    player: Player,
    position: Vector3,
    orientation: Vector3
): boolean
    local session = activeSessions[player]
    if
        not session
        or session.releasing
        or os.time() >= session.leaseExpiresAt
        or not isFiniteVector3(position)
        or not isFiniteVector3(orientation)
    then
        return false
    end

    session.data.characterSpawnData = {
        position = position,
        orientation = orientation,
    }
    return true
end

function DataStoreManager.savePlayerData(player: Player, sessionToken: string?): boolean
    local session = activeSessions[player]
    if
        not session
        or session.releasing
        or (sessionToken ~= nil and session.sessionToken ~= sessionToken)
        or session.busy
    then
        return false
    end

    session.busy = true
    captureCharacterSpawnData(player, session)
    local saved, saveError = updateStoredSession(player, session, false)
    session.busy = false
    if not saved then
        warn(
            "Failed to persist player data for "
                .. tostring(player.UserId)
                .. ": "
                .. tostring(saveError)
        )
    end
    return saved
end

function DataStoreManager.renewSession(player: Player, sessionToken: string?): boolean
    local session = activeSessions[player]
    if
        not session
        or session.releasing
        or (sessionToken ~= nil and session.sessionToken ~= sessionToken)
        or session.busy
    then
        return false
    end

    session.busy = true
    captureCharacterSpawnData(player, session)
    local renewed, renewError = updateStoredSession(player, session, false)
    session.busy = false
    if renewed then
        scheduleRenewal(player, session)
    else
        warn(
            "Failed to renew player session for "
                .. tostring(player.UserId)
                .. ": "
                .. tostring(renewError)
        )
    end
    return renewed
end

function DataStoreManager.releaseSession(
    player: Player,
    sessionToken: string?,
    shutdownDeadline: number?
): boolean
    local session = activeSessions[player]
    if not session then
        return true
    end
    if sessionToken ~= nil and session.sessionToken ~= sessionToken then
        warn("Session token mismatch while releasing player session: " .. tostring(player.UserId))
        return false
    end

    session.releasing = true
    cancelRenewal(session)
    cancelReleaseRetry(session)
    local deadline = math.min(os.clock() + 10, shutdownDeadline or math.huge)
    while session.busy and os.clock() < deadline do
        task.wait(0.1)
    end
    if session.busy then
        warn("Timed out waiting to release player session for " .. tostring(player.UserId))
        if not shutdownDeadline then
            scheduleReleaseRetry(player, session)
        end
        return false
    end

    session.busy = true
    captureCharacterSpawnData(player, session)
    local released = false
    local releaseError: string? = nil
    local didAttemptRelease = false
    local maxAttempts = RELEASE_ATTEMPTS
    if shutdownDeadline then
        maxAttempts += #RELEASE_RETRY_DELAYS
    end
    for attempt = 1, maxAttempts do
        if shutdownDeadline and os.clock() >= shutdownDeadline then
            break
        end

        didAttemptRelease = true
        released, releaseError = updateStoredSession(player, session, true)
        if released or releaseError == "Session lock lost or stale" then
            break
        end
        if attempt < maxAttempts then
            local delaySeconds = if attempt < RELEASE_ATTEMPTS
                then attempt
                else RELEASE_RETRY_DELAYS[attempt - RELEASE_ATTEMPTS + 1]
            local remaining = if shutdownDeadline then shutdownDeadline - os.clock() else math.huge
            if remaining <= delaySeconds then
                break
            end
            task.wait(delaySeconds)
        end
    end
    session.busy = false
    if not didAttemptRelease then
        releaseError = "Shutdown deadline elapsed before session release"
    end

    if released then
        cancelReleaseRetry(session)
        activeSessions[player] = nil
        return true
    end

    if releaseError == "Session lock lost or stale" then
        cancelReleaseRetry(session)
        activeSessions[player] = nil
        warn("Session ownership was lost before release for " .. tostring(player.UserId))
        return false
    end

    if not shutdownDeadline then
        scheduleReleaseRetry(player, session)
    end
    warn(
        "Failed to persist and release player session for "
            .. tostring(player.UserId)
            .. "; in-memory data retained: "
            .. tostring(releaseError)
    )
    return false
end

function DataStoreManager.handleClientSessionRequest(player: Player): any?
    local session = activeSessions[player]
    if not session or session.releasing or os.time() >= session.leaseExpiresAt then
        return nil
    end

    RemoteEvents.SyncData:FireClient(player, {
        sessionToken = session.sessionToken,
        playerData = session.data,
    })
    return session.data
end

return DataStoreManager
