--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local Server = ServerScriptService:WaitForChild("Server")
local DataStoreManager = require(Server:WaitForChild("DataStoreManager"))

return function()
    local spawnData = DataStoreManager.getDefaultData(1).characterSpawnData
    local passed = spawnData.position == Vector3.new(0, 5, 0)
        and spawnData.orientation == Vector3.new(0, 0, 0)

    return {
        passed = passed,
        message = passed and "Character spawn defaults passed" or "Character spawn defaults failed",
    }
end
