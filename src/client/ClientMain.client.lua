--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local RemoteEvents = require(Shared:WaitForChild("RemoteEvents"))

local player = Players.LocalPlayer

local currentQuestId: string? = nil
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui

local gui = Instance.new("ScreenGui")
gui.Name = "PocketHabitatHUD"
gui.ResetOnSpawn = false
gui.Parent = playerGui

-- Sound IDs (using Roblox default sounds for now)
local SOUNDS = {
    gather = "rbxassetid://12222073",
    plant = "rbxassetid://12222073",
    water = "rbxassetid://138097902",
    harvest = "rbxassetid://12222073",
    upgrade = "rbxassetid://12222073",
    quest = "rbxassetid://12222073",
    discover = "rbxassetid://12222073",
    notify = "rbxassetid://12222073",
}

-- Create sound instances
local sounds: { [string]: Sound } = {}
for name, id in pairs(SOUNDS) do
    local sound = Instance.new("Sound")
    sound.SoundId = id
    sound.Volume = 0.5
    sound.Parent = SoundService
    sounds[name] = sound
end

local function playSound(name: string)
    local sound = sounds[name]
    if sound then
        sound:Play()
    end
end

-- Create particle effect at position
local function createParticles(
    position: Vector3,
    color: Color3,
    size: number,
    lifetime: number,
    rate: number
)
    local part = Instance.new("Part")
    part.Name = "EffectPart"
    part.Size = Vector3.new(1, 1, 1)
    part.Position = position
    part.Anchored = true
    part.CanCollide = false
    part.Transparency = 1
    part.Parent = Workspace

    local emitter = Instance.new("ParticleEmitter")
    emitter.Color = ColorSequence.new(color)
    emitter.Size = NumberSequence.new(size)
    emitter.Transparency = NumberSequence.new(0, 1)
    emitter.Lifetime = NumberRange.new(lifetime)
    emitter.Rate = rate
    emitter.Speed = NumberRange.new(2, 5)
    emitter.SpreadAngle = Vector2.new(180, 180)
    emitter.Parent = part

    task.delay(lifetime + 1, function()
        part:Destroy()
    end)
end

-- Floating text effect
local function createFloatingText(position: Vector3, text: string, color: Color3)
    local part = Instance.new("Part")
    part.Name = "FloatingText"
    part.Size = Vector3.new(1, 1, 1)
    part.Position = position
    part.Anchored = true
    part.CanCollide = false
    part.Transparency = 1
    part.Parent = Workspace

    local billboard = Instance.new("BillboardGui")
    billboard.Size = UDim2.new(0, 100, 0, 50)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.Parent = part

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = color
    label.TextSize = 18
    label.TextStrokeTransparency = 0
    label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    label.Font = Enum.Font.GothamBold
    label.Parent = billboard

    -- Animate upward and fade
    local tween = TweenService:Create(
        part,
        TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {
            Position = position + Vector3.new(0, 5, 0),
        }
    )
    tween:Play()

    local fadeTween = TweenService:Create(
        label,
        TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {
            TextTransparency = 1,
        }
    )
    fadeTween:Play()

    task.delay(1.5, function()
        part:Destroy()
    end)
end

-- Main Frame
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 300, 0, 400)
mainFrame.Position = UDim2.new(0.5, -150, 0.5, -200)
mainFrame.Visible = false -- Start hidden
mainFrame.BackgroundColor3 = Color3.fromRGB(245, 235, 220)
mainFrame.BorderSizePixel = 0
mainFrame.Parent = gui

local uiStroke = Instance.new("UIStroke")
uiStroke.Color = Color3.fromRGB(180, 160, 140)
uiStroke.Thickness = 2
uiStroke.Parent = mainFrame

local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, 12)
uiCorner.Parent = mainFrame

-- Toggle Button
local toggleButton = Instance.new("TextButton")
toggleButton.Size = UDim2.new(0, 50, 0, 50)
toggleButton.Position = UDim2.new(0, 20, 0, 20)
toggleButton.BackgroundColor3 = Color3.fromRGB(90, 140, 95)
toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleButton.Text = "☰"
toggleButton.TextSize = 24
toggleButton.Parent = gui

local uiCornerToggle = Instance.new("UICorner")
uiCornerToggle.CornerRadius = UDim.new(0, 8)
uiCornerToggle.Parent = toggleButton

local uiStrokeToggle = Instance.new("UIStroke")
uiStrokeToggle.Color = Color3.fromRGB(60, 100, 65)
uiStrokeToggle.Thickness = 2
uiStrokeToggle.Parent = toggleButton

-- Toggle Button for Quest Log
local questLogButton = Instance.new("TextButton")
questLogButton.Size = UDim2.new(0, 50, 0, 50)
questLogButton.Position = UDim2.new(0, 80, 0, 20)
questLogButton.BackgroundColor3 = Color3.fromRGB(80, 120, 180)
questLogButton.TextColor3 = Color3.fromRGB(255, 255, 255)
questLogButton.Text = "⭐"
questLogButton.TextSize = 24
questLogButton.Parent = gui

local uiCornerQuest = Instance.new("UICorner")
uiCornerQuest.CornerRadius = UDim.new(0, 8)
uiCornerQuest.Parent = questLogButton

local uiStrokeQuest = Instance.new("UIStroke")
uiStrokeQuest.Color = Color3.fromRGB(50, 80, 120)
uiStrokeQuest.Thickness = 2
uiStrokeQuest.Parent = questLogButton

-- Quest Log Frame
local questLogFrame = Instance.new("Frame")
questLogFrame.Name = "QuestLogFrame"
questLogFrame.Size = UDim2.new(0, 300, 0, 400)
questLogFrame.Position = UDim2.new(0.5, -150, 0.5, -200)
questLogFrame.Visible = false
questLogFrame.BackgroundColor3 = Color3.fromRGB(240, 245, 255)
questLogFrame.BorderSizePixel = 0
questLogFrame.Parent = gui

local questLogStroke = Instance.new("UIStroke")
questLogStroke.Color = Color3.fromRGB(140, 160, 180)
questLogStroke.Thickness = 2
questLogStroke.Parent = questLogFrame

local questLogCorner = Instance.new("UICorner")
questLogCorner.CornerRadius = UDim.new(0, 12)
questLogCorner.Parent = questLogFrame

local questLogTitle = Instance.new("TextLabel")
questLogTitle.Size = UDim2.new(1, 0, 0, 45)
questLogTitle.BackgroundColor3 = Color3.fromRGB(80, 120, 180)
questLogTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
questLogTitle.TextSize = 20
questLogTitle.Font = Enum.Font.FredokaOne
questLogTitle.Text = "⭐ Quest Log"
questLogTitle.Parent = questLogFrame

local questCloseButton = Instance.new("TextButton")
questCloseButton.Size = UDim2.new(0, 30, 0, 30)
questCloseButton.Position = UDim2.new(1, -35, 0, 7)
questCloseButton.BackgroundColor3 = Color3.fromRGB(200, 80, 80)
questCloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
questCloseButton.Text = "X"
questCloseButton.TextSize = 18
questCloseButton.Font = Enum.Font.GothamBold
questCloseButton.Parent = questLogTitle

local questCloseCorner = Instance.new("UICorner")
questCloseCorner.CornerRadius = UDim.new(0, 8)
questCloseCorner.Parent = questCloseButton

questCloseButton.MouseButton1Click:Connect(function()
    questLogFrame.Visible = false
end)

local questScroll = Instance.new("ScrollingFrame")
questScroll.Size = UDim2.new(1, -20, 1, -60)
questScroll.Position = UDim2.new(0, 10, 0, 50)
questScroll.BackgroundTransparency = 1
questScroll.CanvasSize = UDim2.new(0, 0, 0, 1000)
questScroll.ScrollBarThickness = 6
questScroll.Parent = questLogFrame

local questLayout = Instance.new("UIListLayout")
questLayout.Padding = UDim.new(0, 8)
questLayout.Parent = questScroll

for _, questId in ipairs(Constants.QUEST_ORDER) do
    local quest = Constants.QUESTS[questId]
    local qLabel = Instance.new("TextLabel")
    qLabel.Size = UDim2.new(1, -10, 0, 60)
    qLabel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    qLabel.TextColor3 = Color3.fromRGB(50, 50, 50)
    qLabel.TextSize = 14
    qLabel.Font = Enum.Font.Gotham
    qLabel.TextXAlignment = Enum.TextXAlignment.Left
    qLabel.TextWrapped = true
    qLabel.Text = quest.title .. "\n" .. quest.description
    qLabel.Parent = questScroll

    local qCorner = Instance.new("UICorner")
    qCorner.CornerRadius = UDim.new(0, 8)
    qCorner.Parent = qLabel
end

questLogButton.MouseButton1Click:Connect(function()
    questLogFrame.Visible = not questLogFrame.Visible
end)

-- Centralized UI visibility handler with consistent animation state
local OPEN_SIZE = UDim2.new(0, 300, 0, 400)
local OPEN_POSITION = UDim2.new(0.5, -150, 0.5, -200)
local CLOSED_SIZE = UDim2.new(0, 0, 0, 0)
local CLOSED_POSITION = UDim2.new(0.5, 0, 0.5, 0)
local TWEEN_TIME = 0.3

local function setGuiVisible(visible: boolean)
    if visible then
        -- Animate in: start from closed state, then tween to open
        mainFrame.Size = CLOSED_SIZE
        mainFrame.Position = CLOSED_POSITION
        mainFrame.Visible = true

        local tweenInfo = TweenInfo.new(TWEEN_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
        local tween = TweenService:Create(mainFrame, tweenInfo, {
            Size = OPEN_SIZE,
            Position = OPEN_POSITION,
        })
        tween:Play()
    else
        -- Animate out: tween to closed state, then hide
        local tweenInfo = TweenInfo.new(TWEEN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        local tween = TweenService:Create(mainFrame, tweenInfo, {
            Size = CLOSED_SIZE,
            Position = CLOSED_POSITION,
        })
        tween:Play()
        task.delay(TWEEN_TIME, function()
            if not mainFrame.Visible then
                return
            end
            -- Only hide if still in closed state (not reopened during animation)
            if mainFrame.Size == CLOSED_SIZE and mainFrame.Position == CLOSED_POSITION then
                mainFrame.Visible = false
            end
        end)
    end
end

toggleButton.MouseButton1Click:Connect(function()
    setGuiVisible(not mainFrame.Visible)
end)

-- Title
local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, 0, 0, 45)
titleLabel.BackgroundColor3 = Color3.fromRGB(90, 140, 95)
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.TextSize = 20
titleLabel.Font = Enum.Font.FredokaOne
titleLabel.Text = "🌱 Pocket Habitat"
titleLabel.Parent = mainFrame

local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.new(0, 30, 0, 30)
closeButton.Position = UDim2.new(1, -35, 0, 7)
closeButton.BackgroundColor3 = Color3.fromRGB(200, 80, 80)
closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
closeButton.Text = "X"
closeButton.TextSize = 18
closeButton.Font = Enum.Font.GothamBold
closeButton.Parent = titleLabel

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 8)
closeCorner.Parent = closeButton

closeButton.MouseButton1Click:Connect(function()
    setGuiVisible(false)
end)

local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 12)
titleCorner.Parent = titleLabel

-- Bells Label
local bellsLabel = Instance.new("TextLabel")
bellsLabel.Size = UDim2.new(0.4, -10, 0, 35)
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

-- Garden Status Label (New)
local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -30, 0, 30)
statusLabel.Position = UDim2.new(0, 15, 0, 95)
statusLabel.BackgroundColor3 = Color3.fromRGB(230, 250, 230)
statusLabel.TextColor3 = Color3.fromRGB(60, 100, 60)
statusLabel.TextSize = 14
statusLabel.Font = Enum.Font.GothamMedium
statusLabel.Text = "Garden: 0/4 Plots Active"
statusLabel.Parent = mainFrame

local statusCorner = Instance.new("UICorner")
statusCorner.CornerRadius = UDim.new(0, 8)
statusCorner.Parent = statusLabel

-- Quest Label
local questLabel = Instance.new("TextLabel")
questLabel.Size = UDim2.new(0.6, -15, 0, 35)
questLabel.Position = UDim2.new(0.4, 0, 0, 55)
questLabel.BackgroundColor3 = Color3.fromRGB(220, 240, 255)
questLabel.TextColor3 = Color3.fromRGB(20, 80, 140)
questLabel.TextSize = 14
questLabel.Font = Enum.Font.GothamMedium
questLabel.Text = "Quest: Gather Wood"
questLabel.Parent = mainFrame

local questCorner = Instance.new("UICorner")
questCorner.CornerRadius = UDim.new(0, 8)
questCorner.Parent = questLabel

-- Creatures Discovered Label
local creaturesLabel = Instance.new("TextLabel")
creaturesLabel.Size = UDim2.new(1, -30, 0, 30)
creaturesLabel.Position = UDim2.new(0, 15, 0, 130)
creaturesLabel.BackgroundColor3 = Color3.fromRGB(250, 240, 250)
creaturesLabel.TextColor3 = Color3.fromRGB(100, 60, 100)
creaturesLabel.TextSize = 14
creaturesLabel.Font = Enum.Font.GothamMedium
creaturesLabel.Text = "Creatures: 0 Discovered"
creaturesLabel.Parent = mainFrame

local creaturesCorner = Instance.new("UICorner")
creaturesCorner.CornerRadius = UDim.new(0, 8)
creaturesCorner.Parent = creaturesLabel

-- Inventory Scroll (Responsive height)
local inventoryFrame = Instance.new("ScrollingFrame")
inventoryFrame.Name = "InventoryFrame"
inventoryFrame.Size = UDim2.new(1, -30, 0, 100) -- Increased size slightly
inventoryFrame.Position = UDim2.new(0, 15, 0, 165)
inventoryFrame.BackgroundTransparency = 1
inventoryFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
inventoryFrame.ScrollBarThickness = 4
inventoryFrame.Parent = mainFrame

local invListLayout = Instance.new("UIListLayout")
invListLayout.Padding = UDim.new(0, 4)
invListLayout.Parent = inventoryFrame

-- Actions Container (Buttons) (Responsive height)
local actionsFrame = Instance.new("ScrollingFrame")
actionsFrame.Size = UDim2.new(1, -30, 1, -280) -- Adaptive size
actionsFrame.Position = UDim2.new(0, 15, 0, 270)
actionsFrame.BackgroundTransparency = 1
actionsFrame.CanvasSize = UDim2.new(0, 0, 0, 600)
actionsFrame.ScrollBarThickness = 6
actionsFrame.Parent = mainFrame

local uiLayout = Instance.new("UIListLayout")
uiLayout.Padding = UDim.new(0, 8)
uiLayout.SortOrder = Enum.SortOrder.LayoutOrder
uiLayout.Parent = actionsFrame

local function createActionButton(text: string, callback: () -> ()): TextButton
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

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(80, 120, 85)
    stroke.Thickness = 2
    stroke.Parent = btn

    btn.MouseButton1Click:Connect(function()
        playSound("notify")
        callback()
    end)

    return btn
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

createActionButton("💧 Buy Watering Can Upgrade", function()
    local success, res = RemoteEvents.PurchaseUpgrade:InvokeServer("watering_can")
    print("Upgrade result:", success, res)
end)

local claimQuestButton = createActionButton("⭐ Claim Current Quest", function()
    local questId = currentQuestId
    if not questId then
        return
    end

    local success, res = RemoteEvents.ClaimQuest:InvokeServer(questId)
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
    playSound("notify")
    task.delay(3, function()
        if notifLabel.Text == msg then
            notifLabel.Visible = false
        end
    end)
end)

RemoteEvents.SyncData.OnClientEvent:Connect(function(data: any)
    if type(data) ~= "table" then
        return
    end

    local playerData = data.playerData or data.data or data
    if type(playerData) == "table" and type(playerData.inventory) == "table" then
        bellsLabel.Text = "Bells: " .. tostring(playerData.bells or 0) .. " 🔔"

        -- Update Garden Status
        local activePlots = 0
        if type(playerData.plots) == "table" then
            for _, plot in pairs(playerData.plots) do
                if plot.plantId then
                    activePlots += 1
                end
            end
        end
        statusLabel.Text = "Garden: "
            .. activePlots
            .. "/"
            .. tostring(playerData.unlockedPlots or 4)
            .. " Plots Active"

        -- Update Creature Status
        local creatureCount = 0
        if type(playerData.discoveredCreatures) == "table" then
            for _ in pairs(playerData.discoveredCreatures) do
                creatureCount += 1
            end
        end
        creaturesLabel.Text = "Creatures: " .. creatureCount .. " Discovered"

        local questId = playerData.currentQuest
        local questDef = if type(questId) == "string" then Constants.QUESTS[questId] else nil
        currentQuestId = if questDef then questId else nil
        if questDef then
            questLabel.Text = "Quest: " .. questDef.title
            claimQuestButton.Text = "⭐ Claim: " .. questDef.title
        else
            questLabel.Text = "Quest: All Complete! 🎉"
            claimQuestButton.Text = "⭐ All Quests Complete!"
        end

        local invList = inventoryFrame

        -- Efficient inventory UI update: reuse existing labels instead of destroy/recreate
        local existingLabels: { [string]: TextLabel } = {}
        for _, child in pairs(invList:GetChildren()) do
            if child:IsA("TextLabel") then
                -- Extract itemId from existing label text (format: "• itemId: qty")
                local itemId = child.Text:match("^•%s*([^:]+):")
                if itemId then
                    existingLabels[itemId] = child
                end
            end
        end

        local labelIndex = 0
        for itemId, qty in pairs(playerData.inventory) do
            labelIndex += 1
            local label = existingLabels[itemId]
            if label then
                -- Reuse existing label
                label.Text = "• " .. itemId .. ": " .. tostring(qty)
                label.LayoutOrder = labelIndex
                existingLabels[itemId] = nil -- Mark as used
            else
                -- Create new label only when needed
                local itemLabel = Instance.new("TextLabel")
                itemLabel.Size = UDim2.new(1, 0, 0, 20)
                itemLabel.BackgroundTransparency = 1
                itemLabel.Text = "• " .. itemId .. ": " .. tostring(qty)
                itemLabel.TextColor3 = Color3.fromRGB(50, 50, 50)
                itemLabel.Font = Enum.Font.Gotham
                itemLabel.TextSize = 14
                itemLabel.TextXAlignment = Enum.TextXAlignment.Left
                itemLabel.LayoutOrder = labelIndex
                itemLabel.Parent = invList
            end
        end

        -- Destroy unused labels (items no longer in inventory)
        for _, unusedLabel in pairs(existingLabels) do
            unusedLabel:Destroy()
        end

        local listLayout = invList:FindFirstChildOfClass("UIListLayout")
        local contentSizeY = if listLayout then listLayout.AbsoluteContentSize.Y else 0
        invList.CanvasSize = UDim2.new(0, 0, 0, contentSizeY)
    end
end)

RemoteEvents.CreatureDiscovered.OnClientEvent:Connect(function(creatureId: string)
    local creature = Constants.CREATURES[creatureId]
    if creature then
        print("🌟 Discovered creature:", creature.name)
        playSound("discover")
        createParticles(
            player.Character and player.Character:GetPivot().Position or Vector3.new(0, 5, 0),
            Color3.fromRGB(255, 255, 100),
            1,
            1,
            50
        )
        createFloatingText(
            player.Character and player.Character:GetPivot().Position or Vector3.new(0, 5, 0),
            "✨ " .. creature.name .. " Discovered! ✨",
            Color3.fromRGB(255, 255, 100)
        )
    end
end)

-- Visual Effect Handlers
-- selene: allow(unused_variable)
RemoteEvents.GatherEffect.OnClientEvent:Connect(
    function(position: Vector3, resourceType: string, amount: number)
        playSound("gather")
        local color = Color3.fromRGB(150, 100, 50)
        if resourceType == "wood" then
            color = Color3.fromRGB(139, 100, 50)
        elseif resourceType == "stone" then
            color = Color3.fromRGB(130, 130, 130)
        elseif resourceType == "dewdrop" then
            color = Color3.fromRGB(100, 200, 255)
        elseif resourceType == "seed_berry" then
            color = Color3.fromRGB(200, 50, 50)
        end
        createParticles(position, color, 0.5, 0.5, 20)
        createFloatingText(position, "+" .. tostring(amount) .. " " .. resourceType, color)
    end
)

-- selene: allow(unused_variable)
RemoteEvents.PlantEffect.OnClientEvent:Connect(function(position: Vector3, _seedId: string)
    playSound("plant")
    local color = Color3.fromRGB(60, 140, 60)
    createParticles(position, color, 0.8, 1, 30)
    createFloatingText(position, "🌱 Planted!", color)
end)

RemoteEvents.WaterEffect.OnClientEvent:Connect(
    function(position: Vector3, waterCount: number, waterNeeded: number)
        playSound("water")
        local color = Color3.fromRGB(100, 200, 255)
        createParticles(position, color, 0.4, 0.5, 15)
        createFloatingText(
            position,
            "💧 Watered (" .. waterCount .. "/" .. waterNeeded .. ")",
            color
        )
    end
)

RemoteEvents.HarvestEffect.OnClientEvent:Connect(
    function(position: Vector3, cropId: string, amount: number, bells: number)
        playSound("harvest")
        local color = Color3.fromRGB(255, 200, 50)
        createParticles(position, color, 0.8, 1, 40)
        createFloatingText(
            position,
            "🧺 +" .. amount .. " " .. cropId .. " (+" .. bells .. " 🔔)",
            color
        )
    end
)

-- selene: allow(unused_variable)
RemoteEvents.UpgradeEffect.OnClientEvent:Connect(function(_upgradeId: string, newLevel: number)
    playSound("upgrade")
    local pos = player.Character and player.Character:GetPivot().Position or Vector3.new(0, 5, 0)
    local color = Color3.fromRGB(255, 215, 0)
    createParticles(pos, color, 1, 1.5, 50)
    createFloatingText(pos, "⬆️ Upgraded to Level " .. newLevel .. "!", color)
end)

print("[ClientMain] Pocket Habitat HUD initialized.")
