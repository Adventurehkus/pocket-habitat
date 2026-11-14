--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))
local HabitatRules = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("HabitatRules"))

local WorldBuilder = {}

local plotPositions = {
    Vector3.new(4, 0.2, 4),
    Vector3.new(-4, 0.2, 4),
    Vector3.new(4, 0.2, -4),
    Vector3.new(-4, 0.2, -4),
    Vector3.new(-12, 0.2, -4),
    Vector3.new(12, 0.2, -4),
    Vector3.new(-12, 0.2, 4),
}

local SEED_NODE_COLORS = {
    [Constants.RESOURCES.SEED_FLOWER] = Constants.PLANTS.flower.color,
    [Constants.RESOURCES.SEED_SUNPETAL] = Constants.PLANTS.sunpetal.color,
    [Constants.RESOURCES.SEED_MOONFLOWER] = Constants.PLANTS.moonflower.color,
    [Constants.RESOURCES.SEED_GLOWCAP] = Constants.PLANTS.glowcap.color,
}

local function getPlotPosition(index: number): Vector3?
    return plotPositions[index]
end

local function createPathSegment(folder: Folder, position: Vector3, baseOffset: Vector3)
    local pathPart = Instance.new("Part")
    pathPart.Name = "PathSegment"
    pathPart.Size = Vector3.new(1, 0.2, position.Magnitude)
    pathPart.Position = (position + Vector3.new(0, 0.15, 0)) / 2 + baseOffset
    pathPart.Anchored = true
    pathPart.BrickColor = BrickColor.new("Sand red")
    pathPart.Material = Enum.Material.Cobblestone
    pathPart.CFrame = CFrame.lookAt(pathPart.Position, Vector3.new(0, 0.15, 0) + baseOffset)
    pathPart.Parent = folder
end

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
    part:SetAttribute("NodeId", name:lower())
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
        leaves.Position = position + Vector3.new(0, 4.5, 0)
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
        berries.Position = position + Vector3.new(0, 2, 0)
        berries.Anchored = true
        berries.BrickColor = BrickColor.new("Bright red")
        berries.Material = Enum.Material.Neon
        berries.Shape = Enum.PartType.Ball
        berries.Parent = folder
    elseif SEED_NODE_COLORS[resourceType] then
        part.Material = Enum.Material.Neon
        part.Color = SEED_NODE_COLORS[resourceType]
        part.Shape = Enum.PartType.Ball
        part.Size = Vector3.new(2.5, 2.5, 2.5)
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
    border.Position = position + Vector3.new(0, 0.3, 0)
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

local function restorePlotState(folder: Folder, plotData: any, plotIndex: number)
    local plotName = "Plot_" .. tostring(plotIndex)
    local plotsFolder = folder:FindFirstChild("GardenPlots") or folder
    local plotPart = plotsFolder:FindFirstChild(plotName)
    if not plotPart then
        return
    end

    for _, child in ipairs(plotPart:GetChildren()) do
        if child.Name == "Plant" or child.Name == "WaterDrops" then
            child:Destroy()
        end
    end

    if
        type(plotData) ~= "table"
        or type(plotData.seedId) ~= "string"
        or plotData.plantedTime == nil
    then
        return
    end

    local plantDef = Constants.PLANTS[plotData.seedId:gsub("seed_", "")]
    if plantDef and plotData.plantedTime > 0 then
        local elapsed = os.time() - plotData.plantedTime
        local isMature = elapsed >= plantDef.growthTime
            and (plotData.waterCount or 0) >= plantDef.waterNeeded
        local stage = isMature and 2 or 1

        local plant = Instance.new("Part")
        plant.Name = "Plant"
        plant.Size = Vector3.new(2, stage * 1.5, 2)
        plant.Position = plotPart.Position + Vector3.new(0, (stage * 1.5) / 2 + 0.2, 0)
        plant.Anchored = true
        plant.BrickColor = BrickColor.new(plantDef.color)
        plant.Material = Enum.Material.SmoothPlastic
        plant.Parent = plotPart

        if (plotData.waterCount or 0) > 0 then
            local waterIndicator = Instance.new("Part")
            waterIndicator.Name = "WaterDrops"
            waterIndicator.Size = Vector3.new(1, 0.5, 1)
            waterIndicator.Position = plant.Position + Vector3.new(0, plant.Size.Y / 2 + 0.5, 0)
            waterIndicator.Anchored = true
            waterIndicator.BrickColor = BrickColor.new("Cyan")
            waterIndicator.Material = Enum.Material.Neon
            waterIndicator.Shape = Enum.PartType.Cylinder
            waterIndicator.Transparency = 0.5
            waterIndicator.Parent = plotPart
        end
    end
end

function WorldBuilder.addGardenPlot(habitat: Folder, index: number, plotData: any?): BasePart?
    local position = getPlotPosition(index)
    local plotsFolder = habitat:FindFirstChild("GardenPlots")
    if not position or not plotsFolder or not plotsFolder:IsA("Folder") then
        return nil
    end
    if plotsFolder:FindFirstChild("Plot_" .. tostring(index)) then
        return nil
    end

    local baseOffset = habitat:GetAttribute("BaseOffset") or Vector3.zero
    local plotPart = createGardenPlot(plotsFolder, index, position + baseOffset)
    local pathsFolder = habitat:FindFirstChild("Paths")
    if pathsFolder and pathsFolder:IsA("Folder") then
        createPathSegment(pathsFolder, position, baseOffset)
    end
    if plotData then
        restorePlotState(habitat, plotData, index)
    end
    return plotPart
end

function WorldBuilder.buildHabitat(folder: Folder, owner: Player, sessionData: any?)
    -- Get the habitat's BaseOffset once for consistent application
    local baseOffset = folder:GetAttribute("BaseOffset") or Vector3.new(0, 0, 0)

    -- Baseplate
    local baseplate = Instance.new("Part")
    baseplate.Name = "Baseplate"
    baseplate.Size = Vector3.new(100, 1, 100)
    baseplate.Position = Vector3.new(0, -0.5, 0) + baseOffset
    baseplate.Anchored = true
    baseplate.BrickColor = BrickColor.new("Dark green")
    baseplate.Material = Enum.Material.Grass
    baseplate.Parent = folder

    -- Resource node positions, identifiers, and rewards share one definition.
    for _, node in ipairs(Constants.RESOURCE_NODES) do
        createResourceNode(
            folder,
            node.name,
            node.position + baseOffset,
            BrickColor.new("Forest green"),
            node.type
        )
    end

    -- Garden Plots with ProximityPrompts
    local plotsFolder = Instance.new("Folder")
    plotsFolder.Name = "GardenPlots"
    plotsFolder.Parent = folder

    local plotCount = HabitatRules.INITIAL_PLOT_COUNT
    if sessionData then
        local savedPlotCount = HabitatRules.getPlotCount(sessionData.upgrades)
        if not savedPlotCount then
            error("Invalid saved plot expansion state")
        end
        plotCount = savedPlotCount
    end

    for i = 1, plotCount do
        local pos = getPlotPosition(i)
        if pos then
            createGardenPlot(plotsFolder, i, pos + baseOffset)
        end
    end

    -- Restore saved plot state if session data provided
    if sessionData and sessionData.plots then
        for i = 1, plotCount do
            restorePlotState(folder, sessionData.plots[i], i)
        end
    end

    -- Add some decorative elements
    -- Path from center to plots
    local pathFolder = Instance.new("Folder")
    pathFolder.Name = "Paths"
    pathFolder.Parent = folder

    for index = 1, plotCount do
        local pos = getPlotPosition(index)
        if pos then
            createPathSegment(pathFolder, pos, baseOffset)
        end
    end

    -- Add a small pond/water feature
    local pond = Instance.new("Part")
    pond.Name = "Pond"
    pond.Size = Vector3.new(12, 0.5, 12)
    pond.Position = Vector3.new(0, 0.25, 0) + baseOffset
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

    -- Create global Workspace structures if they don't exist
    local Workspace = game:GetService("Workspace")

    -- Ensure Creatures folder exists for creature runtime instances
    local creaturesFolder = Workspace:FindFirstChild("Creatures")
    if not creaturesFolder then
        creaturesFolder = Instance.new("Folder")
        creaturesFolder.Name = "Creatures"
        creaturesFolder.Parent = Workspace
    end

    -- Ensure Habitats folder exists (created by HabitatManager but ensure it exists)
    local habitatsFolder = Workspace:FindFirstChild("Habitats")
    if not habitatsFolder then
        habitatsFolder = Instance.new("Folder")
        habitatsFolder.Name = "Habitats"
        habitatsFolder.Parent = Workspace
    end

    print("[WorldBuilder] Global world structures initialized")
end

return WorldBuilder
