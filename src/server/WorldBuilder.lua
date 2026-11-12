--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))

local WorldBuilder = {}

local function addProximityPrompt(
    parent: BasePart,
    actionText: string,
    objectText: string,
    holdDuration: number,
    keyCode: Enum.KeyCode
)
    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText = actionText
    prompt.ObjectText = objectText
    prompt.HoldDuration = holdDuration
    prompt.KeyboardKeyCode = keyCode
    prompt.GamepadKeyCode = keyCode
    prompt.MaxActivationDistance = 12
    prompt.RequiresLineOfSight = false
    prompt.Parent = parent
    return prompt
end

local function createResourceNode(
    folder: Folder,
    name: string,
    position: Vector3,
    color: BrickColor,
    resourceType: string
)
    local part = Instance.new("Part")
    part.Name = name
    part.Size = Vector3.new(3, 5, 3)
    part.Position = position
    part.Anchored = true
    part.BrickColor = color
    part.Material = Enum.Material.Wood
    part.Shape = Enum.PartType.Cylinder
    part.Parent = folder

    -- Add a trunk-like appearance
    if resourceType == Constants.RESOURCES.WOOD then
        part.Material = Enum.Material.Wood
        part.Color = Color3.fromRGB(120, 80, 40)
        -- Add leaves on top
        local leaves = Instance.new("Part")
        leaves.Name = "Leaves"
        leaves.Size = Vector3.new(6, 4, 6)
        leaves.Position = position
            + Vector3.new(0, 4.5, 0)
            + (folder:GetAttribute("BaseOffset") or Vector3.new(0, 0, 0))
        leaves.Anchored = true
        leaves.BrickColor = BrickColor.new("Forest green")
        leaves.Material = Enum.Material.LeafyGrass
        leaves.Shape = Enum.PartType.Ball
        leaves.Parent = folder
    elseif resourceType == Constants.RESOURCES.STONE then
        part.Material = Enum.Material.Slate
        part.Color = Color3.fromRGB(130, 130, 130)
        part.Shape = Enum.PartType.Block
    elseif resourceType == Constants.RESOURCES.DEWDROP then
        part.Material = Enum.Material.Neon
        part.Color = Color3.fromRGB(100, 200, 255)
        part.Shape = Enum.PartType.Ball
        part.Size = Vector3.new(2, 2, 2)
        -- Add a sparkle effect
        local sparkle = Instance.new("ParticleEmitter")
        sparkle.Color = ColorSequence.new(Color3.fromRGB(200, 255, 255))
        sparkle.Size = NumberSequence.new(0.5)
        sparkle.Transparency = NumberSequence.new(0.5)
        sparkle.Lifetime = NumberRange.new(0.5, 1)
        sparkle.Rate = 10
        sparkle.Speed = NumberRange.new(1, 2)
        sparkle.SpreadAngle = Vector2.new(180, 180)
        sparkle.Parent = part
    elseif resourceType == Constants.RESOURCES.SEED_BERRY then
        part.Material = Enum.Material.Grass
        part.Color = Color3.fromRGB(60, 140, 60)
        part.Shape = Enum.PartType.Ball
        part.Size = Vector3.new(2.5, 2.5, 2.5)
        -- Add berries
        local berries = Instance.new("Part")
        berries.Name = "Berries"
        berries.Size = Vector3.new(1.5, 1.5, 1.5)
        berries.Position = position
            + Vector3.new(0, 2, 0)
            + (folder:GetAttribute("BaseOffset") or Vector3.new(0, 0, 0))
        berries.Anchored = true
        berries.BrickColor = BrickColor.new("Bright red")
        berries.Material = Enum.Material.Neon
        berries.Shape = Enum.PartType.Ball
        berries.Parent = folder
    end

    -- Add proximity prompt
    local prompt = addProximityPrompt(part, "Gather", name:gsub("_", " "), 1.5, Enum.KeyCode.E)
    prompt:SetAttribute("NodeId", name:lower())

    return part
end

local function createGardenPlot(folder: Folder, index: number, position: Vector3)
    local plotPart = Instance.new("Part")
    plotPart.Name = "Plot_" .. tostring(index)
    plotPart.Size = Vector3.new(5, 0.4, 5)
    plotPart.Position = position
    plotPart.Anchored = true
    plotPart.BrickColor = BrickColor.new("Dirt brown")
    plotPart.Material = Enum.Material.Slate
    plotPart.Parent = folder

    -- Add a border
    local border = Instance.new("Part")
    border.Name = "Border"
    border.Size = Vector3.new(5.4, 0.2, 5.4)
    border.Position = position
        + Vector3.new(0, 0.3, 0)
        + (folder:GetAttribute("BaseOffset") or Vector3.new(0, 0, 0))
    border.Anchored = true
    border.BrickColor = BrickColor.new("Dark stone grey")
    border.Material = Enum.Material.Concrete
    border.Transparency = 0.5
    border.Parent = folder

    -- Add proximity prompt for planting/interacting
    -- Players can use this to harvest, or plant seeds directly (alternative flower seeds in future)
    local prompt =
        addProximityPrompt(plotPart, "Harvest/Plant", "Garden Plot " .. index, 1, Enum.KeyCode.E)
    prompt:SetAttribute("PlotIndex", index)
    prompt:SetAttribute("PlotAction", "harvest_or_plant")

    return plotPart
end

function WorldBuilder.buildHabitat(folder: Folder, owner: Player)
    -- Baseplate
    local baseplate = Instance.new("Part")
    baseplate.Name = "Baseplate"
    baseplate.Size = Vector3.new(100, 1, 100)
    baseplate.Position = Vector3.new(0, -0.5, 0)
        + (folder:GetAttribute("BaseOffset") or Vector3.new(0, 0, 0))
    baseplate.Anchored = true
    baseplate.BrickColor = BrickColor.new("Dark green")
    baseplate.Material = Enum.Material.Grass
    baseplate.Parent = folder

    -- Resource Nodes with ProximityPrompts
    -- ... (keep existing creation logic but adapt positions)
    -- Actually, for now, let's just use the same logic but adjust positions slightly if needed
    -- To keep it simple, I'll keep the positions for now, but they will be part of the individual habitat folder

    -- Resource Nodes with ProximityPrompts
    createResourceNode(
        folder,
        "Tree_1",
        Vector3.new(15, 2.5, 0) + (folder:GetAttribute("BaseOffset") or Vector3.new(0, 0, 0)),
        BrickColor.new("Reddish brown"),
        Constants.RESOURCES.WOOD
    )
    createResourceNode(
        folder,
        "Tree_2",
        Vector3.new(-15, 2.5, 0) + (folder:GetAttribute("BaseOffset") or Vector3.new(0, 0, 0)),
        BrickColor.new("Reddish brown"),
        Constants.RESOURCES.WOOD
    )
    createResourceNode(
        folder,
        "Rock_1",
        Vector3.new(0, 1.5, 15) + (folder:GetAttribute("BaseOffset") or Vector3.new(0, 0, 0)),
        BrickColor.new("Medium stone grey"),
        Constants.RESOURCES.STONE
    )
    createResourceNode(
        folder,
        "Rock_2",
        Vector3.new(0, 1.5, -15) + (folder:GetAttribute("BaseOffset") or Vector3.new(0, 0, 0)),
        BrickColor.new("Medium stone grey"),
        Constants.RESOURCES.STONE
    )
    createResourceNode(
        folder,
        "Dew_1",
        Vector3.new(10, 1, 10) + (folder:GetAttribute("BaseOffset") or Vector3.new(0, 0, 0)),
        BrickColor.new("Cyan"),
        Constants.RESOURCES.DEWDROP
    )
    createResourceNode(
        folder,
        "Bush_1",
        Vector3.new(-10, 1.25, -10) + (folder:GetAttribute("BaseOffset") or Vector3.new(0, 0, 0)),
        BrickColor.new("Forest green"),
        Constants.RESOURCES.SEED_BERRY
    )

    -- Garden Plots with ProximityPrompts
    local plotsFolder = Instance.new("Folder")
    plotsFolder.Name = "GardenPlots"
    plotsFolder.Parent = folder

    local plotPositions = {
        Vector3.new(4, 0.2, 4) + (folder:GetAttribute("BaseOffset") or Vector3.new(0, 0, 0)),
        Vector3.new(-4, 0.2, 4) + (folder:GetAttribute("BaseOffset") or Vector3.new(0, 0, 0)),
        Vector3.new(4, 0.2, -4) + (folder:GetAttribute("BaseOffset") or Vector3.new(0, 0, 0)),
        Vector3.new(-4, 0.2, -4) + (folder:GetAttribute("BaseOffset") or Vector3.new(0, 0, 0)),
    }

    for i, pos in ipairs(plotPositions) do
        createGardenPlot(plotsFolder, i, pos)
    end

    -- Add some decorative elements
    -- Path from center to plots
    local pathFolder = Instance.new("Folder")
    pathFolder.Name = "Paths"
    pathFolder.Parent = folder

    for _, pos in ipairs(plotPositions) do
        local pathPart = Instance.new("Part")
        pathPart.Name = "PathSegment"
        pathPart.Size = Vector3.new(
            1,
            0.2,
            (pos - (folder:GetAttribute("BaseOffset") or Vector3.new(0, 0, 0))).Magnitude
        )
        pathPart.Position = (pos + Vector3.new(0, 0.15, 0)) / 2
        pathPart.Anchored = true
        pathPart.BrickColor = BrickColor.new("Sand red")
        pathPart.Material = Enum.Material.Cobblestone
        pathPart.CFrame = CFrame.lookAt(pathPart.Position, Vector3.new(0, 0.15, 0))
        pathPart.Parent = pathFolder
    end

    -- Add a small pond/water feature
    local pond = Instance.new("Part")
    pond.Name = "Pond"
    pond.Size = Vector3.new(12, 0.5, 12)
    pond.Position = Vector3.new(0, 0.25, 0)
        + (folder:GetAttribute("BaseOffset") or Vector3.new(0, 0, 0))
    pond.Anchored = true
    pond.BrickColor = BrickColor.new("Bright blue")
    pond.Material = Enum.Material.Water
    pond.Transparency = 0.3
    pond.Shape = Enum.PartType.Cylinder
    pond.Parent = folder

    print("[WorldBuilder] Habitat built for: " .. owner.Name)
end

function WorldBuilder.init()
    print("[WorldBuilder] Initialized")
end

return WorldBuilder
