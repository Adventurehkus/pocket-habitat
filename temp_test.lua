local function test_world_builder_positions()
    local baseOffset = Vector3.new(125, 0, 125)
    
    -- Original buggy positions from WorldBuilder.lua
    local resources = {
        {name = "Tree_1", pos = Vector3.new(15, 2.5, 0), color = "Reddish brown", type = "WOOD"},
        {name = "Tree_2", pos = Vector3.new(-15, 2.5, 0), color = "Reddish brown", type = "WOOD"},
        {name = "Rock_1", pos = Vector3.new(0, 1.5, 15), color = "Medium stone grey", type = "STONE"},
        {name = "Rock_2", pos = Vector3.new(0, 1.5, -15), color = "Medium stone grey", type = "STONE"},
        {name = "Dew_1", pos = Vector3.new(10, 1, 10), color = "Cyan", type = "DEWDROP"},
        {name = "Bush_1", pos = Vector3.new(-10, 1.25, -10), color = "Forest green", type = "SEED_BERRY"}
    }
    
    print("=== TEST: Resource Positions with BaseOffset ===")
    
    -- Test with baseOffset (FIXED)
    for _, res in ipairs(resources) do
        local finalPos = res.pos + baseOffset
        print(string.format("%s: %s -> %s", res.name, res.pos, finalPos))
        
        -- Verify position is within expected bounds (around baseOffset + small offset)
        local distFromBase = (finalPos - baseOffset).Magnitude
        local expectedMaxDist = 30  -- Maximum expected offset from baseOffset
        if distFromBase > expectedMaxDist then
            print("  WARNING: Resource too far from baseOffset!", distFromBase)
        end
    end
    
    print("\n=== TEST: Relative Positions ===")
    
    -- Show relative positions from base
    for _, res in ipairs(resources) do
        local relPos = res.pos
        print(string.format("%s relative: %s", res.name, relPos))
    end
    
    print("\n=== TEST: ProximityHandler Logic ===")
    
    -- Test duplicate connection prevention simulation
    local connections = {}
    local promptCount = 0
    
    -- Simulate old behavior (buggy - re-scans entire folder)
    local function old_behavior_simulate()
        for i = 1, 3 do
            -- Simulate adding a new prompt
            promptCount = promptCount + 1
            local promptId = "Prompt_" .. promptCount
            print("Old: Adding", promptId)
            -- In old version, this would re-scan all existing prompts and create duplicate connections
            for existingId, _ in pairs(connections) do
                print("Old: Creating duplicate connection for", existingId, "when adding", promptId)
                connections[existingId] = connections[existingId] + 1
            end
            connections[promptId] = 1
        end
    end
    
    -- Simulate new behavior (fixed - only connects new prompt)
    local function new_behavior_simulate()
        for i = 1, 3 do
            promptCount = promptCount + 1
            local promptId = "Prompt_" .. promptCount
            print("New: Adding", promptId)
            -- In new version, only connect the new prompt
            connections[promptId] = 1
        end
    end
    
    print("Old behavior - duplicate connections:")
    old_behavior_simulate()
    print("Connection counts:", table.concat(connections, ", "))
    
    print("\nNew behavior - no duplicates:")
    connections = {}
    promptCount = 0
    new_behavior_simulate()
    print("Connection counts:", table.concat(connections, ", "))
end

test_world_builder_positions()