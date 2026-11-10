--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local RemoteEvents = require(Shared:WaitForChild("RemoteEvents"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui

local gui = Instance.new("ScreenGui")
gui.Name = "PocketHabitatHUD"
gui.ResetOnSpawn = false
gui.Parent = playerGui

-- Main Frame
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 420, 0, 520)
mainFrame.Position = UDim2.new(0.5, -210, 0.5, -260)
mainFrame.BackgroundColor3 = Color3.fromRGB(245, 235, 220)
mainFrame.BorderSizePixel = 0
mainFrame.Parent = gui

local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, 12)
uiCorner.Parent = mainFrame

-- Title
local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, 0, 0, 45)
titleLabel.BackgroundColor3 = Color3.fromRGB(90, 140, 95)
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.TextSize = 20
titleLabel.Font = Enum.Font.FredokaOne
titleLabel.Text = "🌱 Pocket Habitat"
titleLabel.Parent = mainFrame

local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 12)
titleCorner.Parent = titleLabel

-- Bells Label
local bellsLabel = Instance.new("TextLabel")
bellsLabel.Size = UDim2.new(0, 180, 0, 35)
bellsLabel.Position = UDim2.new(0, 15, 0, 55)
bellsLabel.BackgroundColor3 = Color3.fromRGB(255, 245, 200)
bellsLabel.TextColor3 = Color3.fromRGB(120, 90, 20)
bellsLabel.TextSize = 16
bellsLabel.Font = Enum.Font.GothamBold
bellsLabel.Text = "Bells: 50 🔔"
bellsLabel.Parent = mainFrame

local bellsCorner = Instance.new("UICorner")
bellsCorner.CornerRadius = UDim.new(0, 8)
bellsCorner.Parent = bellsLabel

-- Quest Label
local questLabel = Instance.new("TextLabel")
questLabel.Size = UDim2.new(0, 210, 0, 35)
questLabel.Position = UDim2.new(0, 200, 0, 55)
questLabel.BackgroundColor3 = Color3.fromRGB(220, 240, 255)
questLabel.TextColor3 = Color3.fromRGB(20, 80, 140)
questLabel.TextSize = 14
questLabel.Font = Enum.Font.GothamMedium
questLabel.Text = "Quest: Gather Wood"
questLabel.Parent = mainFrame

local questCorner = Instance.new("UICorner")
questCorner.CornerRadius = UDim.new(0, 8)
questCorner.Parent = questLabel

-- Inventory Scroll
local inventoryLabel = Instance.new("TextLabel")
inventoryLabel.Size = UDim2.new(1, -30, 0, 80)
inventoryLabel.Position = UDim2.new(0, 15, 0, 100)
inventoryLabel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
inventoryLabel.TextColor3 = Color3.fromRGB(50, 50, 50)
inventoryLabel.TextSize = 14
inventoryLabel.Font = Enum.Font.Gotham
inventoryLabel.TextXAlignment = Enum.TextXAlignment.Left
inventoryLabel.TextYAlignment = Enum.TextYAlignment.Top
inventoryLabel.TextWrapped = true
inventoryLabel.Text = "Inventory: Loading..."
inventoryLabel.Parent = mainFrame

local invCorner = Instance.new("UICorner")
invCorner.CornerRadius = UDim.new(0, 8)
invCorner.Parent = inventoryLabel

-- Actions Container (Buttons)
local actionsFrame = Instance.new("ScrollingFrame")
actionsFrame.Size = UDim2.new(1, -30, 0, 280)
actionsFrame.Position = UDim2.new(0, 15, 0, 195)
actionsFrame.BackgroundTransparency = 1
actionsFrame.CanvasSize = UDim2.new(0, 0, 0, 400)
actionsFrame.ScrollBarThickness = 6
actionsFrame.Parent = mainFrame

local uiLayout = Instance.new("UIListLayout")
uiLayout.Padding = UDim.new(0, 8)
uiLayout.SortOrder = Enum.SortOrder.LayoutOrder
uiLayout.Parent = actionsFrame

local function createActionButton(text: string, callback: () -> ())
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -10, 0, 38)
    btn.BackgroundColor3 = Color3.fromRGB(110, 170, 115)
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.TextSize = 15
    btn.Font = Enum.Font.GothamBold
    btn.Text = text
    btn.Parent = actionsFrame

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = btn

    btn.MouseButton1Click:Connect(callback)
end

-- Create Interaction Buttons
createActionButton("🪵 Gather Wood (Tree 1)", function()
    local success, res = RemoteEvents.GatherResource:InvokeServer("tree_1")
    print("Gather result:", success, res)
end)

createActionButton("🪨 Gather Stone (Rock 1)", function()
    local success, res = RemoteEvents.GatherResource:InvokeServer("rock_1")
    print("Gather result:", success, res)
end)

createActionButton("💧 Gather Dewdrops (Dew 1)", function()
    local success, res = RemoteEvents.GatherResource:InvokeServer("dew_1")
    print("Gather result:", success, res)
end)

createActionButton("🌾 Gather Berry Seed (Bush 1)", function()
    local success, res = RemoteEvents.GatherResource:InvokeServer("bush_1")
    print("Gather result:", success, res)
end)

createActionButton("🌱 Plant Berry Seed in Plot 1", function()
    local success, res = RemoteEvents.PlantSeed:InvokeServer(1, Constants.RESOURCES.SEED_BERRY)
    print("Plant result:", success, res)
end)

createActionButton("💧 Water Plot 1", function()
    local success, res = RemoteEvents.WaterPlot:InvokeServer(1)
    print("Water result:", success, res)
end)

createActionButton("🧺 Harvest Plot 1", function()
    local success, res = RemoteEvents.HarvestPlot:InvokeServer(1)
    print("Harvest result:", success, res)
end)

createActionButton("⬆️ Buy Plot Expansion", function()
    local success, res = RemoteEvents.PurchaseUpgrade:InvokeServer("plot_expansion")
    print("Upgrade result:", success, res)
end)

createActionButton("⭐ Claim Current Quest", function()
    -- Find current quest ID from data if possible, or try common current quest
    local success, res = RemoteEvents.ClaimQuest:InvokeServer("q1_wood")
    if not success then
        RemoteEvents.ClaimQuest:InvokeServer("q2_stone")
        RemoteEvents.ClaimQuest:InvokeServer("q3_plant")
        RemoteEvents.ClaimQuest:InvokeServer("q4_water")
        RemoteEvents.ClaimQuest:InvokeServer("q5_harvest")
        RemoteEvents.ClaimQuest:InvokeServer("q6_creature")
    end
    print("Claim Quest result:", success, res)
end)

-- Notification Banner
local notifLabel = Instance.new("TextLabel")
notifLabel.Size = UDim2.new(0, 350, 0, 40)
notifLabel.Position = UDim2.new(0.5, -175, 0, 20)
notifLabel.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
notifLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
notifLabel.TextSize = 14
notifLabel.Font = Enum.Font.GothamBold
notifLabel.Text = "Welcome to Pocket Habitat!"
notifLabel.Visible = false
notifLabel.Parent = gui

local notifCorner = Instance.new("UICorner")
notifCorner.CornerRadius = UDim.new(0, 8)
notifCorner.Parent = notifLabel

RemoteEvents.Notification.OnClientEvent:Connect(function(msg: string)
    notifLabel.Text = msg
    notifLabel.Visible = true
    task.delay(3, function()
        if notifLabel.Text == msg then
            notifLabel.Visible = false
        end
    end)
end)

RemoteEvents.SyncData.OnClientEvent:Connect(function(data: any)
    if not data then
        return
    end
    bellsLabel.Text = "Bells: " .. tostring(data.bells) .. " 🔔"

    if data.currentQuest and Constants.QUESTS[data.currentQuest] then
        questLabel.Text = "Quest: " .. Constants.QUESTS[data.currentQuest].title
    else
        questLabel.Text = "Quest: All Complete! 🎉"
    end

    local invText = "Inventory:\n"
    for itemId, qty in pairs(data.inventory) do
        invText ..= "• " .. itemId .. ": " .. tostring(qty) .. "\n"
    end
    inventoryLabel.Text = invText
end)

RemoteEvents.CreatureDiscovered.OnClientEvent:Connect(function(creatureId: string)
    local creature = Constants.CREATURES[creatureId]
    if creature then
        print("🌟 Discovered creature:", creature.name)
    end
end)

print("[ClientMain] Pocket Habitat HUD initialized.")
