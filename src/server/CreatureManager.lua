--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))
local RemoteEvents = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RemoteEvents"))
local DataStoreManager = require(script.Parent:WaitForChild("DataStoreManager"))
local EconomyManager = require(script.Parent:WaitForChild("EconomyManager"))

local CreatureManager = {}

local CREATURE_FOLDER = Workspace:FindFirstChild("Creatures") or Instance.new("Folder")
CREATURE_FOLDER.Name = "Creatures"
CREATURE_FOLDER.Parent = Workspace

local creatureModels: { [string]: Model } = {}

local function createCreatureModel(creatureId: string, position: Vector3): Model
    local def = Constants.CREATURES[creatureId]
    local model = Instance.new("Model")
    model.Name = creatureId
    model:SetAttribute("CreatureId", creatureId)

    local root = Instance.new("Part")
    root.Name = "HumanoidRootPart"
    root.Size = Vector3.new(2, 2, 2)
    root.Position = position
    root.Anchored = false
    root.CanCollide = false
    root.Massless = true
    root.Transparency = 1
    root.Parent = model

    -- Create visual body based on creature type
    local body = Instance.new("Part")
    body.Name = "Body"
    body.Anchored = false
    body.CanCollide = false
    body.Massless = true
    body.Parent = model

    local humanoid = Instance.new("Humanoid")
    humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
    humanoid.Health = 100
    humanoid.MaxHealth = 100
    humanoid.WalkSpeed = def.id == "bunny" and 8 or 6
    humanoid.JumpPower = def.id == "bunny" and 25 or 15
    humanoid.Parent = model

    if creatureId == "bunny" then
        -- Bunny: round body with ears
        body.Size = Vector3.new(2, 1.5, 2)
        body.Position = position
        body.BrickColor = BrickColor.new("Light gray")
        body.Material = Enum.Material.SmoothPlastic
        body.Shape = Enum.PartType.Ball

        -- Ears
        for i = -1, 1, 2 do
            local ear = Instance.new("Part")
            ear.Name = "Ear" .. (i == -1 and "L" or "R")
            ear.Size = Vector3.new(0.4, 1.2, 0.4)
            ear.Position = position + Vector3.new(i * 0.7, 1.8, 0)
            ear.Anchored = false
            ear.CanCollide = false
            ear.Massless = true
            ear.BrickColor = BrickColor.new("Light gray")
            ear.Material = Enum.Material.SmoothPlastic
            ear.Parent = model

            local weld = Instance.new("WeldConstraint")
            weld.Part0 = body
            weld.Part1 = ear
            weld.Parent = ear
        end

        -- Tail
        local tail = Instance.new("Part")
        tail.Name = "Tail"
        tail.Size = Vector3.new(0.6, 0.6, 0.6)
        tail.Position = position + Vector3.new(0, 0.5, -1.3)
        tail.Anchored = false
        tail.CanCollide = false
        tail.Massless = true
        tail.BrickColor = BrickColor.new("White")
        tail.Material = Enum.Material.SmoothPlastic
        tail.Shape = Enum.PartType.Ball
        tail.Parent = model

        local tailWeld = Instance.new("WeldConstraint")
        tailWeld.Part0 = body
        tailWeld.Part1 = tail
        tailWeld.Parent = tail
    elseif creatureId == "sprite" then
        -- Dew Sprite: glowing ethereal form
        body.Size = Vector3.new(1.5, 2.5, 1.5)
        body.Position = position + Vector3.new(0, 1.25, 0)
        body.BrickColor = BrickColor.new("Cyan")
        body.Material = Enum.Material.Neon
        body.Shape = Enum.PartType.Ball
        body.Transparency = 0.3

        -- Glowing particle effect
        local sparkle = Instance.new("ParticleEmitter")
        sparkle.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(100, 255, 255)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 255, 255)),
        })
        sparkle.Size = NumberSequence.new(0.8, 1.5)
        sparkle.Transparency = NumberSequence.new(0.2, 0.8)
        sparkle.Lifetime = NumberRange.new(0.5, 1.5)
        sparkle.Rate = 20
        sparkle.Speed = NumberRange.new(0.5, 2)
        sparkle.SpreadAngle = Vector2.new(180, 180)
        sparkle.Parent = body

        -- Light
        local light = Instance.new("PointLight")
        light.Color = Color3.fromRGB(100, 255, 255)
        light.Range = 10
        light.Brightness = 2
        light.Parent = body

        humanoid.WalkSpeed = 6
    end

    -- Weld body to root
    local weld = Instance.new("WeldConstraint")
    weld.Part0 = root
    weld.Part1 = body
    weld.Parent = root

    model.Parent = CREATURE_FOLDER
    creatureModels[creatureId] = model

    -- Start idle behavior
    task.spawn(function()
        idleBehavior(model, humanoid, body, creatureId)
    end)

    return model
end
-- selene: allow(unused_variable)

local function idleBehavior(model: Model, humanoid: Humanoid, body: BasePart, creatureId: string)
    local lastMoveTime = 0
    local moveInterval = creatureId == "bunny" and 3 or 5

    while model.Parent and humanoid.Health > 0 do
        task.wait(1)

        local now = tick()
        if now - lastMoveTime >= moveInterval then
            lastMoveTime = now

            -- Random wander
            local currentPos = body.Position
            local targetPos = currentPos
                + Vector3.new(math.random(-10, 10), 0, math.random(-10, 10))

            -- Keep within bounds
            targetPos =
                Vector3.new(math.clamp(targetPos.X, -40, 40), 2, math.clamp(targetPos.Z, -40, 40))

            humanoid:MoveTo(targetPos)
        end
    end
end

function CreatureManager.checkDiscoveries(player: Player)
    local data = DataStoreManager.getSession(player)
    if not data then
        return
    end

    -- Calculate flora density (planted plots or items) and water
    local floraCount = 0
    local waterTotal = 0
    for _, plot in pairs(data.plots) do
        if plot.seedId ~= nil then
            floraCount += 1
        end
        waterTotal += plot.waterCount
    end

    for creatureId, def in pairs(Constants.CREATURES) do
        if not data.creaturesDiscovered[creatureId] then
            if floraCount >= def.requiredFlora and waterTotal >= def.requiredWater then
                data.creaturesDiscovered[creatureId] = true
                EconomyManager.addBells(player, def.bellReward)

                -- Spawn creature near the player's habitat
                local pos = player.Character and player.Character:GetPivot().Position
                    or Vector3.new(0, 5, 0)
                createCreatureModel(creatureId, pos + Vector3.new(5, 0, 5))

                RemoteEvents.SyncData:FireClient(player, data)
                RemoteEvents.CreatureDiscovered:FireClient(player, creatureId)
                RemoteEvents.Notification:FireClient(
                    player,
                    "Discovered new creature: " .. def.name .. "!"
                )
            end
        end
    end
end

return CreatureManager
