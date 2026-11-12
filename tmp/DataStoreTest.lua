-- DataStoreManager simulation test
local DataStoreManager = require(script.Parent.Parent:WaitForChild("DataStoreManager"))

-- Simulate multiple servers contending for same user
local function testContention()
    print("=== Testing session contention ===")
    local userId = 12345
    local sessionToken1 = "server1_" .. os.time()
    local sessionToken2 = "server2_" .. os.time()

    -- Simulate acquireSession for both servers
    local token1 = DataStoreManager.acquireSession({UserId = userId}, sessionToken1)
    print("Server 1 acquired session:", token1)

    -- Simulate second server trying to acquire same session
    local token2 = DataStoreManager.acquireSession({UserId = userId}, sessionToken2)
    print("Server 2 acquired session:", token2)

    if not token2 then
        print("✅ Server 2 correctly failed to acquire")
    else
        print("❌ Server 2 should have failed")
    end

    -- Clean up
    if token1 then
        DataStoreManager.releaseSession({UserId = userId}, token1)
    end
end

testContention()

-- Simulate save with contention errors
testContention()
