--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))
local QuestRules = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("QuestRules"))
local RemoteEvents = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RemoteEvents"))
local DataStoreManager = require(script.Parent:WaitForChild("DataStoreManager"))
local EconomyManager = require(script.Parent:WaitForChild("EconomyManager"))
local HabitatManager = require(script.Parent:WaitForChild("HabitatManager"))

local CreatureManager = {}

-- Per-player creature registry: [UserId] -> { [creatureId] -> Model }
local playerCreatures: { [number]: { [string]: Model } } = {}

local function getHabitatBounds(habitat: Folder): (Vector3, Vector3)
    local baseOffset = habitat:GetAttribute("BaseOffset") or Vector3.new(0, 0, 0)
    local min = baseOffset + Vector3.new(-45, 1, -45)
    local max = baseOffset + Vector3.new(45, 50, 45)
    return min, max
end

local function idleBehavior(
    model: Model,
    humanoid: Humanoid,
    body: BasePart,
    creatureId: string,
    habitat: Folder
)
    local lastMoveTime = 0
    local moveInterval = creatureId == "bunny" and 3 or 5
    local minBound, maxBound = getHabitatBounds(habitat)

    while model.Parent and humanoid.Health > 0 do
        task.wait(1)

        local now = tick()
        if now - lastMoveTime >= moveInterval then
            lastMoveTime = now

            -- Random wander within habitat bounds
            local currentPos = body.Position
            local targetPos = currentPos
                + Vector3.new(math.random(-10, 10), 0, math.random(-10, 10))

            -- Keep within habitat bounds
            targetPos = Vector3.new(
                math.clamp(targetPos.X, minBound.X, maxBound.X),
                math.clamp(targetPos.Y, minBound.Y, maxBound.Y),
                math.clamp(targetPos.Z, minBound.Z, maxBound.Z)
            )

            humanoid:MoveTo(targetPos)
        end
    end
end

local function createCreatureModel(
    creatureId: string,
    position: Vector3,
    habitat: Folder,
    ownerUserId: number
): Model
    local def = Constants.CREATURES[creatureId]
    local model = Instance.new("Model")
    model.Name = creatureId .. "_" .. tostring(ownerUserId)
    model:SetAttribute("CreatureId", creatureId)
    model:SetAttribute("OwnerUserId", ownerUserId)

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
    elseif creatureId == "leafling" then
        -- Leafling: small leafy creature
        body.Size = Vector3.new(1, 1.8, 1)
        body.Position = position + Vector3.new(0, 0.9, 0)
        body.BrickColor = BrickColor.new("Lime green")
        body.Material = Enum.Material.SmoothPlastic
        body.Shape = Enum.PartType.Block

        -- Leaf on head
        local leaf = Instance.new("Part")
        leaf.Name = "Leaf"
        leaf.Size = Vector3.new(1.2, 0.2, 1.2)
        leaf.Position = position + Vector3.new(0, 1.9, 0)
        leaf.Anchored = false
        leaf.CanCollide = false
        leaf.Massless = true
        leaf.BrickColor = BrickColor.new("Forest green")
        leaf.Material = Enum.Material.SmoothPlastic
        leaf.Parent = model
        local leafWeld = Instance.new("WeldConstraint")
        leafWeld.Part0 = body
        leafWeld.Part1 = leaf
        leafWeld.Parent = leaf

        humanoid.WalkSpeed = 5
        humanoid.JumpPower = 12
    elseif creatureId == "tortoise" then
        -- Pebble Tortoise: slow, rocky shell
        body.Size = Vector3.new(2.5, 1.2, 2.5)
        body.Position = position + Vector3.new(0, 0.6, 0)
        body.BrickColor = BrickColor.new("Medium stone grey")
        body.Material = Enum.Material.Slate
        body.Shape = Enum.PartType.Ball

        -- Shell pattern
        local shell = Instance.new("Part")
        shell.Name = "Shell"
        shell.Size = Vector3.new(2.2, 1, 2.2)
        shell.Position = position + Vector3.new(0, 1.1, 0)
        shell.Anchored = false
        shell.CanCollide = false
        shell.Massless = true
        shell.BrickColor = BrickColor.new("Dark stone grey")
        shell.Material = Enum.Material.Slate
        shell.Shape = Enum.PartType.Ball
        shell.Parent = model
        local shellWeld = Instance.new("WeldConstraint")
        shellWeld.Part0 = body
        shellWeld.Part1 = shell
        shellWeld.Parent = shell

        humanoid.WalkSpeed = 3
        humanoid.JumpPower = 8
    elseif creatureId == "finch" then
        -- Cloud Finch: small bird
        body.Size = Vector3.new(1, 0.8, 1)
        body.Position = position + Vector3.new(0, 2, 0)
        body.BrickColor = BrickColor.new("Bright yellow")
        body.Material = Enum.Material.SmoothPlastic
        body.Shape = Enum.PartType.Ball

        -- Wings
        for i = -1, 1, 2 do
            local wing = Instance.new("Part")
            wing.Name = "Wing" .. (i == -1 and "L" or "R")
            wing.Size = Vector3.new(0.8, 0.2, 0.5)
            wing.Position = position + Vector3.new(i * 0.6, 2.1, 0)
            wing.Anchored = false
            wing.CanCollide = false
            wing.Massless = true
            wing.BrickColor = BrickColor.new("Cool yellow")
            wing.Material = Enum.Material.SmoothPlastic
            wing.Parent = model
            local wingWeld = Instance.new("WeldConstraint")
            wingWeld.Part0 = body
            wingWeld.Part1 = wing
            wingWeld.Parent = wing
        end

        humanoid.WalkSpeed = 4
        humanoid.JumpPower = 30
    end

    -- Weld body to root
    local weld = Instance.new("WeldConstraint")
    weld.Part0 = root
    weld.Part1 = body
    weld.Parent = root

    -- Parent to habitat's Creatures folder (create if needed)
    local creaturesFolder = habitat:FindFirstChild("Creatures")
    if not creaturesFolder then
        creaturesFolder = Instance.new("Folder")
        creaturesFolder.Name = "Creatures"
        creaturesFolder.Parent = habitat
    end
    model.Parent = creaturesFolder

    -- Start idle behavior scoped to habitat
    task.spawn(function()
        idleBehavior(model, humanoid, body, creatureId, habitat)
    end)

    return model
end

function CreatureManager.checkDiscoveries(player: Player)
    local data = DataStoreManager.getSession(player)
    if not data then
        return
    end

    local habitat = HabitatManager.getHabitat(player)
    if not habitat then
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
                if not QuestRules.recordProgress(data.questProgress, "discover", creatureId, 1) then
                    warn(
                        "Failed to record creature quest progress for user "
                            .. tostring(player.UserId)
                    )
                end
                EconomyManager.addBells(player, def.bellReward)

                -- Spawn creature in the player's habitat
                local baseOffset = habitat:GetAttribute("BaseOffset") or Vector3.new(0, 0, 0)
                local spawnPos = baseOffset
                    + Vector3.new(math.random(-10, 10), 3, math.random(-10, 10))
                local model = createCreatureModel(creatureId, spawnPos, habitat, player.UserId)

                -- Track this creature for the player
                if not playerCreatures[player.UserId] then
                    playerCreatures[player.UserId] = {}
                end
                playerCreatures[player.UserId][creatureId] = model

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

function CreatureManager.restoreCreatures(player: Player, habitat: Folder, data: any)
    if not data or not data.creaturesDiscovered then
        return
    end

    if not playerCreatures[player.UserId] then
        playerCreatures[player.UserId] = {}
    end

    local baseOffset = habitat:GetAttribute("BaseOffset") or Vector3.new(0, 0, 0)

    for creatureId, discovered in pairs(data.creaturesDiscovered) do
        if discovered and Constants.CREATURES[creatureId] then
            -- Spawn a creature for each discovered type
            local spawnPos = baseOffset + Vector3.new(math.random(-10, 10), 3, math.random(-10, 10))
            local model = createCreatureModel(creatureId, spawnPos, habitat, player.UserId)
            playerCreatures[player.UserId][creatureId] = model
        end
    end
end

function CreatureManager.cleanupPlayer(player: Player)
    local creatures = playerCreatures[player.UserId]
    if creatures then
        for _, model in pairs(creatures) do
            if model and model.Parent then
                model:Destroy()
            end
        end
        playerCreatures[player.UserId] = nil
    end
end

return CreatureManager
