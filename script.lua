
-- Mini Auto Battle - Overhead Flight
-- สำหรับ Roblox Studio ในเกมที่คุณสร้างเอง
-- ไม่มี Auto Attack / ไม่มี Hitbox Expander
--
-- โครงสร้าง:
-- Workspace
--   Main
--     Drops
--       1
--       10
--       12
--       ...

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local mainFolder = Workspace:WaitForChild("Main")
local dropsFolder = mainFolder:WaitForChild("Drops")

local CONFIG = {
    FlyHeight = 20,        -- ความสูงเหนือ HumanoidRootPart ของมอน
    MoveSpeed = 80,        -- ความเร็วเคลื่อนที่
    StopDistance = 2,      -- ระยะที่ถือว่าถึงเป้าหมาย
    PauseDuration = 1.2,     -- เวลาพักหลังมอนตาย
    DescendSpeed = 50,     -- ความเร็วตอนลดระดับ
}

local selectedFolder = nil
local selectedNPCName = nil
local currentTarget = nil

local autoMove = false
local noclip = false
local targetPause = false

local moveConnection = nil
local noclipConnection = nil

local originalCollisions = {}

--==================================================
-- CHARACTER
--==================================================

local function getCharacter()
    return player.Character
end

local function getRoot(character)
    character = character or getCharacter()
    return character and character:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid(character)
    character = character or getCharacter()
    return character and character:FindFirstChildOfClass("Humanoid")
end

--==================================================
-- NPC HELPERS
--==================================================

local function isValidNPC(model)
    if not model or not model:IsA("Model") then
        return false
    end

    local humanoid = model:FindFirstChildOfClass("Humanoid")
    local root = model:FindFirstChild("HumanoidRootPart")

    return humanoid ~= nil
        and humanoid.Health > 0
        and root ~= nil
        and model:IsDescendantOf(dropsFolder)
end

local function getNPCNames(folder)
    local names = {}
    local seen = {}

    if not folder then
        return names
    end

    for _, object in ipairs(folder:GetDescendants()) do
        if object:IsA("Model")
            and isValidNPC(object)
            and not seen[object.Name] then

            seen[object.Name] = true
            table.insert(names, object.Name)
        end
    end

    table.sort(names)
    return names
end

local function getTargets()
    local targets = {}

    if not selectedFolder or not selectedFolder.Parent then
        return targets
    end

    for _, object in ipairs(selectedFolder:GetDescendants()) do
        if object:IsA("Model")
            and isValidNPC(object)
            and (
                selectedNPCName == nil
                or object.Name == selectedNPCName
            ) then

            table.insert(targets, object)
        end
    end

    return targets
end

local function getTarget()
    local root = getRoot()
    local targets = getTargets()

    if #targets == 0 then
        return nil
    end

    if not root then
        return targets[1]
    end

    local closest = nil
    local closestDistance = math.huge

    for _, target in ipairs(targets) do
        local targetRoot = target:FindFirstChild("HumanoidRootPart")

        if targetRoot then
            local distance = (targetRoot.Position - root.Position).Magnitude

            if distance < closestDistance then
                closestDistance = distance
                closest = target
            end
        end
    end

    return closest
end

--==================================================
-- GUI
--==================================================

local oldGui = playerGui:FindFirstChild("MiniAutoBattle")

if oldGui then
    oldGui:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "MiniAutoBattle"
gui.ResetOnSpawn = false
gui.DisplayOrder = 100
gui.Parent = playerGui

local function addCorner(object, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius or 7)
    corner.Parent = object
end

local toggleButton = Instance.new("TextButton")
toggleButton.Name = "OpenClose"
toggleButton.Size = UDim2.fromOffset(125, 36)
toggleButton.Position = UDim2.new(0, 15, 0.55, 0)
toggleButton.BackgroundColor3 = Color3.fromRGB(35, 110, 210)
toggleButton.Text = "ซ่อน Mini UI"
toggleButton.TextColor3 = Color3.new(1, 1, 1)
toggleButton.TextSize = 13
toggleButton.Font = Enum.Font.GothamBold
toggleButton.Parent = gui
addCorner(toggleButton)

local panel = Instance.new("Frame")
panel.Name = "MainPanel"
panel.Size = UDim2.fromOffset(310, 445)
panel.Position = UDim2.new(0, 25, 0.15, 0)
panel.BackgroundColor3 = Color3.fromRGB(25, 27, 35)
panel.BorderSizePixel = 0
panel.Active = true
panel.Parent = gui
addCorner(panel, 10)

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(80, 150, 255)
stroke.Thickness = 1.5
stroke.Parent = panel

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -95, 0, 40)
title.Position = UDim2.fromOffset(10, 0)
title.BackgroundTransparency = 1
title.Text = "MINI AUTO BATTLE"
title.TextColor3 = Color3.new(1, 1, 1)
title.TextSize = 15
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = panel

local hideButton = Instance.new("TextButton")
hideButton.Size = UDim2.fromOffset(42, 28)
hideButton.Position = UDim2.new(1, -49, 0, 5)
hideButton.BackgroundColor3 = Color3.fromRGB(70, 90, 130)
hideButton.Text = "ซ่อน"
hideButton.TextColor3 = Color3.new(1, 1, 1)
hideButton.TextSize = 11
hideButton.Font = Enum.Font.GothamBold
hideButton.Parent = panel
addCorner(hideButton)

local function makeButton(text, y, height)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, -24, 0, height or 34)
    button.Position = UDim2.fromOffset(12, y)
    button.BackgroundColor3 = Color3.fromRGB(48, 53, 67)
    button.BorderSizePixel = 0
    button.Text = text
    button.TextColor3 = Color3.new(1, 1, 1)
    button.TextSize = 13
    button.Font = Enum.Font.GothamMedium
    button.Parent = panel
    addCorner(button, 6)
    return button
end

local folderButton = makeButton("Folder: เลือกโฟลเดอร์", 45)
local npcButton = makeButton("NPC: ทุกชนิด", 83)
local moveButton = makeButton("บินเหนือมอน: OFF", 121)
local noclipButton = makeButton("Noclip: OFF", 159)
local refreshButton = makeButton("รีเฟรชรายการ", 197)

local list = Instance.new("ScrollingFrame")
list.Position = UDim2.fromOffset(12, 237)
list.Size = UDim2.new(1, -24, 0, 145)
list.BackgroundColor3 = Color3.fromRGB(19, 21, 28)
list.BorderSizePixel = 0
list.ScrollBarThickness = 6
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.CanvasSize = UDim2.new()
list.Parent = panel
addCorner(list, 6)

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 4)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = list

local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0, 5)
padding.PaddingLeft = UDim.new(0, 5)
padding.PaddingRight = UDim.new(0, 5)
padding.Parent = list

local status = Instance.new("TextLabel")
status.Position = UDim2.fromOffset(12, 386)
status.Size = UDim2.new(1, -24, 0, 45)
status.BackgroundTransparency = 1
status.Text = "สถานะ: พร้อมใช้งาน"
status.TextColor3 = Color3.fromRGB(180, 220, 180)
status.TextSize = 12
status.Font = Enum.Font.Gotham
status.TextWrapped = true
status.TextXAlignment = Enum.TextXAlignment.Left
status.Parent = panel

--==================================================
-- DRAG UI
--==================================================

local dragging = false
local dragInput = nil
local dragStart = nil
local startPosition = nil

title.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then

        dragging = true
        dragInput = input
        dragStart = input.Position
        startPosition = panel.Position
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and (
        input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch
    ) then
        local delta = input.Position - dragStart

        panel.Position = UDim2.new(
            startPosition.X.Scale,
            startPosition.X.Offset + delta.X,
            startPosition.Y.Scale,
            startPosition.Y.Offset + delta.Y
        )
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input == dragInput then
        dragging = false
        dragInput = nil
    end
end)

local function setPanelVisible(visible)
    panel.Visible = visible
    toggleButton.Text = visible and "ซ่อน Mini UI" or "เปิด Mini UI"
end

toggleButton.Activated:Connect(function()
    setPanelVisible(not panel.Visible)
end)

hideButton.Activated:Connect(function()
    setPanelVisible(false)
end)

--==================================================
-- SCROLLING LIST
--==================================================

local function clearList()
    for _, item in ipairs(list:GetChildren()) do
        if item:IsA("TextButton") then
            item:Destroy()
        end
    end
end

local function addListItem(text, callback, order)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, -5, 0, 30)
    button.BackgroundColor3 = Color3.fromRGB(52, 58, 73)
    button.BorderSizePixel = 0
    button.Text = text
    button.TextColor3 = Color3.new(1, 1, 1)
    button.TextSize = 12
    button.Font = Enum.Font.Gotham
    button.LayoutOrder = order or 1
    button.Parent = list
    addCorner(button, 5)

    button.Activated:Connect(callback)
    return button
end

local function refreshFolders()
    clearList()

    local folders = {}

    for _, object in ipairs(dropsFolder:GetChildren()) do
        if object:IsA("Folder") then
            table.insert(folders, object)
        end
    end

    table.sort(folders, function(a, b)
        local numberA = tonumber(a.Name)
        local numberB = tonumber(b.Name)

        if numberA and numberB then
            return numberA < numberB
        end

        return a.Name < b.Name
    end)

    for index, folder in ipairs(folders) do
        addListItem(folder.Name, function()
            selectedFolder = folder
            selectedNPCName = nil
            currentTarget = nil

            folderButton.Text = "Folder: " .. folder.Name
            npcButton.Text = "NPC: ทุกชนิด"
            status.Text = "เลือกโฟลเดอร์ " .. folder.Name

            refreshFolders()
        end, index)
    end

    if #folders == 0 then
        addListItem("ไม่พบโฟลเดอร์", function() end, 1)
    end

    list.CanvasPosition = Vector2.zero
end

local function refreshNPCs()
    clearList()

    if not selectedFolder or not selectedFolder.Parent then
        addListItem("กรุณาเลือกโฟลเดอร์ก่อน", function() end, 1)
        return
    end

    addListItem("ทุกชนิดในโฟลเดอร์", function()
        selectedNPCName = nil
        currentTarget = nil
        npcButton.Text = "NPC: ทุกชนิด"
        status.Text = "เลือกมอนสเตอร์ทุกชนิด"
        refreshNPCs()
    end, 1)

    local names = getNPCNames(selectedFolder)

    for index, name in ipairs(names) do
        addListItem(name, function()
            selectedNPCName = name
            currentTarget = nil
            npcButton.Text = "NPC: " .. name
            status.Text = "เลือก NPC: " .. name
            refreshNPCs()
        end, index + 1)
    end
end

folderButton.Activated:Connect(refreshFolders)
npcButton.Activated:Connect(refreshNPCs)

refreshButton.Activated:Connect(function()
    if selectedFolder and selectedFolder.Parent then
        refreshNPCs()
    else
        refreshFolders()
    end
end)

--==================================================
-- OVERHEAD FLIGHT + DESCEND + WAIT 2 SECONDS
--==================================================

local function stopMove()
    autoMove = false
    targetPause = false

    if moveConnection then
        moveConnection:Disconnect()
        moveConnection = nil
    end

    local root = getRoot()

    if root then
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end

    moveButton.Text = "บินเหนือมอน: OFF"
end

local function startMove()
    stopMove()

    autoMove = true
    targetPause = false
    moveButton.Text = "บินเหนือมอน: ON"

    local pauseUntil = 0
    local descending = false
    local descendPosition = nil

    moveConnection = RunService.Heartbeat:Connect(function(dt)
        if not autoMove then
            return
        end

        local character = getCharacter()
        local root = getRoot(character)
        local humanoid = getHumanoid(character)

        if not root or not humanoid or humanoid.Health <= 0 then
            status.Text = "สถานะ: รอตัวละคร"
            return
        end

        -- ตรวจสอบว่าเป้าหมายเดิมตายหรือหายไป
        if currentTarget and not isValidNPC(currentTarget) then
            currentTarget = nil
            targetPause = true
            pauseUntil = os.clock() + CONFIG.PauseDuration
            descending = true

            -- ลดลงเท่ากับ FlyHeight จากตำแหน่งปัจจุบัน
            descendPosition =
                root.Position - Vector3.new(0, CONFIG.FlyHeight, 0)

            status.Text = "มอนตาย: ลดระดับและพัก 2 วินาที"
        end

        -- ช่วงลดระดับและพัก
        if targetPause then
            if descending and descendPosition then
                local offset = descendPosition - root.Position
                local distance = offset.Magnitude

                if distance > 0.15 then
                    local step = math.min(
                        CONFIG.DescendSpeed * dt,
                        distance
                    )

                    root.CFrame = CFrame.new(
                        root.Position + offset.Unit * step
                    )
                else
                    root.CFrame = CFrame.new(descendPosition)
                    descending = false
                end
            end

            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero

            if os.clock() < pauseUntil then
                return
            end

            targetPause = false
            descending = false
            descendPosition = nil
            status.Text = "สถานะ: กำลังหาเป้าหมายถัดไป"
        end

        -- หาเป้าหมายตัวถัดไป
        if not currentTarget then
            currentTarget = getTarget()
        end

        if not currentTarget then
            status.Text = "สถานะ: ไม่พบ NPC"
            return
        end

        local targetRoot =
            currentTarget:FindFirstChild("HumanoidRootPart")

        if not targetRoot then
            currentTarget = nil
            return
        end

        local destination =
            targetRoot.Position + Vector3.new(0, CONFIG.FlyHeight, 0)

        local offset = destination - root.Position
        local distance = offset.Magnitude

        if distance > CONFIG.StopDistance then
            local step = math.min(CONFIG.MoveSpeed * dt, distance)
            local newPosition = root.Position + offset.Unit * step

            root.CFrame = CFrame.lookAt(
                newPosition,
                Vector3.new(
                    targetRoot.Position.X,
                    newPosition.Y,
                    targetRoot.Position.Z
                )
            )
        else
            root.CFrame = CFrame.lookAt(
                destination,
                targetRoot.Position
            )
        end

        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero

        status.Text = "ลอยเหนือ: " .. currentTarget.Name
    end)
end

moveButton.Activated:Connect(function()
    if autoMove then
        stopMove()
    else
        startMove()
    end
end)

--==================================================
-- NOCLIP
--==================================================

local function stopNoclip()
    noclip = false

    if noclipConnection then
        noclipConnection:Disconnect()
        noclipConnection = nil
    end

    for part, oldValue in pairs(originalCollisions) do
        if part and part.Parent then
            part.CanCollide = oldValue
        end
    end

    table.clear(originalCollisions)
    noclipButton.Text = "Noclip: OFF"
end

local function startNoclip()
    stopNoclip()

    noclip = true
    noclipButton.Text = "Noclip: ON"

    noclipConnection = RunService.Stepped:Connect(function()
        if not noclip then
            return
        end

        local character = getCharacter()

        if not character then
            return
        end

        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                if originalCollisions[part] == nil then
                    originalCollisions[part] = part.CanCollide
                end

                part.CanCollide = false
            end
        end
    end)
end

noclipButton.Activated:Connect(function()
    if noclip then
        stopNoclip()
    else
        startNoclip()
    end
end)

--==================================================
-- RESPAWN / CLEANUP
--==================================================

player.CharacterAdded:Connect(function()
    currentTarget = nil
    table.clear(originalCollisions)
end)

gui.Destroying:Connect(function()
    stopMove()
    stopNoclip()
end)

refreshFolders()

print("[Mini Auto Battle] Ready")
