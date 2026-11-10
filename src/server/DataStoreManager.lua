--!strict

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local Constants = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Constants"))

local DataStoreManager = {}

local DATA_STORE_KEY = "PocketHabitat_v1_PlayerData"
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
	}
end

function DataStoreManager.loadPlayerData(player: Player): any
	local userId = player.UserId
	if activeSessions[userId] then
		return activeSessions[userId]
	end

	local dataKey = "User_" .. tostring(userId)
	local success, result = pcall(function()
		return playerDataStore:GetAsync(dataKey)
	end)

	local data
	if success and result then
		data = result
		-- Ensure all default keys exist
		local default = DataStoreManager.getDefaultData(userId)
		for k, v in pairs(default) do
			if data[k] == nil then
				data[k] = v
			end
		end
	else
		if not success then
			warn("Failed to load DataStore for user " .. tostring(userId) .. ": " .. tostring(result))
		end
		data = DataStoreManager.getDefaultData(userId)
	end

	activeSessions[userId] = data
	return data
end

function DataStoreManager.savePlayerData(player: Player)
	local userId = player.UserId
	local data = activeSessions[userId]
	if not data then return end

	local dataKey = "User_" .. tostring(userId)
	local success, err = pcall(function()
		playerDataStore:SetAsync(dataKey, data)
	end)

	if not success then
		warn("Failed to save DataStore for user " .. tostring(userId) .. ": " .. tostring(err))
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
