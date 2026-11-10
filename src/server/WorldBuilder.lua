--!strict

local Workspace = game:GetService("Workspace")

local WorldBuilder = {}

function WorldBuilder.init()
    local folder = Workspace:FindFirstChild("HabitatWorld")
    if not folder then
        folder = Instance.new("Folder")
        folder.Name = "HabitatWorld"
        folder.Parent = Workspace
    end

    -- Baseplate
    local baseplate = Instance.new("Part")
    baseplate.Name = "Baseplate"
    baseplate.Size = Vector3.new(100, 1, 100)
    baseplate.Position = Vector3.new(0, -0.5, 0)
    baseplate.Anchored = true
    baseplate.BrickColor = BrickColor.new("Dark green")
    baseplate.Material = Enum.Material.Grass
    baseplate.Parent = folder

    -- Resource Nodes visual markers
    local nodes = {
        { name = "Tree_1", pos = Vector3.new(15, 2, 0), color = BrickColor.new("Reddish brown") },
        { name = "Tree_2", pos = Vector3.new(-15, 2, 0), color = BrickColor.new("Reddish brown") },
        {
            name = "Rock_1",
            pos = Vector3.new(0, 1.5, 15),
            color = BrickColor.new("Medium stone grey"),
        },
        {
            name = "Rock_2",
            pos = Vector3.new(0, 1.5, -15),
            color = BrickColor.new("Medium stone grey"),
        },
        { name = "Dew_1", pos = Vector3.new(10, 1, 10), color = BrickColor.new("Cyan") },
        { name = "Bush_1", pos = Vector3.new(-10, 1, -10), color = BrickColor.new("Forest green") },
    }

    for _, nodeData in ipairs(nodes) do
        local part = Instance.new("Part")
        part.Name = nodeData.name
        part.Size = Vector3.new(3, 4, 3)
        part.Position = nodeData.pos
        part.Anchored = true
        part.BrickColor = nodeData.color
        part.Shape = Enum.PartType.Cylinder
        part.Parent = folder
    end

    -- Garden Plots visual markers
    local plotsFolder = Instance.new("Folder")
    plotsFolder.Name = "GardenPlots"
    plotsFolder.Parent = folder

    local plotPositions = {
        Vector3.new(4, 0.2, 4),
        Vector3.new(-4, 0.2, 4),
        Vector3.new(4, 0.2, -4),
        Vector3.new(-4, 0.2, -4),
    }

    for i, pos in ipairs(plotPositions) do
        local plotPart = Instance.new("Part")
        plotPart.Name = "Plot_" .. tostring(i)
        plotPart.Size = Vector3.new(5, 0.4, 5)
        plotPart.Position = pos
        plotPart.Anchored = true
        plotPart.BrickColor = BrickColor.new("Dirt brown")
        plotPart.Material = Enum.Material.Slate
        plotPart.Parent = plotsFolder
    end

    print("[WorldBuilder] Habitat world initialized.")
end

return WorldBuilder
