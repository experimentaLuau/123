loadstring(game:HttpGet("https://raw.githubusercontent.com/Pixeluted/adoniscries/main/Source.lua",false))()
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = "Lackadaisy",
    Icon = "cat",
    LoadingTitle = "Lackadaisy",
    LoadingSubtitle = "by 14z88",
    ShowText = "Lackadaisy",
    Theme = "Default"
})

Rayfield:Notify({
    Title = "Welcome :D",
    Content = "Good luck!",
    Duration = 2,
    Image = "cigarette"
})

local MainTab = Window:CreateTab("Main", "crosshair")
local VisualTab = Window:CreateTab("Visual", "scan-eye")
local TeleportTab = Window:CreateTab("Teleport", "satellite-dish")

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

local SilentAimEnabled = false
local SilentAimAutoFireEnabled = false
local NoRecoilEnabled = false
local UsePrediction = false
local PredictionAmount = 0
local MaxDistance = 1000
local SilentAimTargetListEnabled = false
local SilentAimTargetedPlayers = {}
local SilentAimTargetListGUI = nil
local SilentAimTargetListOpen = false

local AimLockEnabled = false
local AimLockAutoFireEnabled = false
local AimLockPart = "Head"
local AimLockTargetListEnabled = false
local AimLockTargetedPlayers = {}
local AimLockTargetListGUI = nil
local AimLockTargetListOpen = false
local AimLockTarget = nil
local AimLockUsePrediction = false
local AimLockPredictionAmount = 0

local TeleportToPlayerEnabled = false
local SelectedPlayerForTeleport = nil
local TPToAimlockedEnabled = false
local UseMaxTeleportDistance = false
local MAX_TELEPORT_DISTANCE = 90

local ProtectedTeams = {
    ["Житель"] = true,
    ["Оружейный Диллер"] = true
}

local OriginalRecoil = {}

local bodyPartMapping = {
    ["Head"] = {parts = {"Head"}, offset = Vector3.new(0, 0.3, 0)},
    ["Torso"] = {parts = {"Torso"}, offset = Vector3.new(0, 0.2, 0)},
    ["Left Arm"] = {parts = {"Left Arm"}, offset = Vector3.new(0, 0.15, 0)},
    ["Right Arm"] = {parts = {"Right Arm"}, offset = Vector3.new(0, 0.15, 0)},
    ["Left Leg"] = {parts = {"Left Leg"}, offset = Vector3.new(0, 0.1, 0)},
    ["Right Leg"] = {parts = {"Right Leg"}, offset = Vector3.new(0, 0.1, 0)}
}

local SAFEZONE_DELAY = 1
local playerSafeZoneStatus = {}
local cachedSafeZones = nil

local function CreateSilentAimCore()
    local function IsPointInPart(point, part)
        if not part:IsA("BasePart") then return false end
        local rel = part.CFrame:PointToObjectSpace(point)
        local size = part.Size / 2
        return math.abs(rel.X) <= size.X and math.abs(rel.Y) <= size.Y and math.abs(rel.Z) <= size.Z
    end

    local function CollectSafeZones()
        if cachedSafeZones then
            return cachedSafeZones
        end
        
        local zones = {}
        local function addZones(folder)
            if not folder then return end
            for _, z in ipairs(folder:GetChildren()) do
                if z:IsA("BasePart") then
                    table.insert(zones, z)
                end
            end
        end
        addZones(workspace:FindFirstChild("SafeZones"))
        local durka = workspace:FindFirstChild("дурка")
        if durka then addZones(durka:FindFirstChild("SafeZones")) end
        
        cachedSafeZones = zones
        return zones
    end

    local function IsInSafeZonePhysically(character)
        if not character then return false end
        
        local partsToCheck = {
            "HumanoidRootPart",
            "Head",
            "Torso",
            "Left Arm",
            "Right Arm",
            "Left Leg",
            "Right Leg"
        }
        
        local allZones = CollectSafeZones()
        
        for _, partName in ipairs(partsToCheck) do
            local part = character:FindFirstChild(partName)
            if part and part:IsA("BasePart") then
                local pos = part.Position
                for _, zone in ipairs(allZones) do
                    if IsPointInPart(pos, zone) then
                        return true
                    end
                end
            end
        end
        
        return false
    end

    local function InitializePlayerSZStatus(player)
        if not playerSafeZoneStatus[player.UserId] then
            playerSafeZoneStatus[player.UserId] = {
                isProtected = false,
                physicallyInside = false,
                enterTime = nil,
                exitTime = nil,
                justSpawned = true
            }
        end
    end

    local function IsInSafeZone(character)
        if not character then return false end
        
        local player = Players:GetPlayerFromCharacter(character)
        if not player then return false end
        
        InitializePlayerSZStatus(player)
        local status = playerSafeZoneStatus[player.UserId]
        
        local physicallyInside = IsInSafeZonePhysically(character)
        local currentTime = tick()
        
        if status.justSpawned and physicallyInside then
            status.justSpawned = false
            status.isProtected = false
            status.physicallyInside = physicallyInside
            status.enterTime = currentTime
            return false
        end
        
        status.justSpawned = false
        
        if physicallyInside ~= status.physicallyInside then
            if physicallyInside then
                status.enterTime = currentTime
                status.exitTime = nil
            else
                status.exitTime = currentTime
                status.enterTime = nil
            end
            status.physicallyInside = physicallyInside
        end
        
        if physicallyInside then
            if status.enterTime and (currentTime - status.enterTime) >= SAFEZONE_DELAY then
                status.isProtected = true
            end
        else
            if status.exitTime and (currentTime - status.exitTime) >= SAFEZONE_DELAY then
                status.isProtected = false
            end
        end
        
        return status.isProtected
    end

    local function IsPlayerTargeted(player, targetListEnabled, targetedPlayers)
        if not targetListEnabled then
            return true
        end
        return targetedPlayers[player.Name] == true
    end

    local function IsPartOfCharacter(part)
        if not part then return false end
        local parent = part.Parent
        if not parent then return false end
        
        if parent:FindFirstChild("Humanoid") then
            return true, parent
        end
        
        if part.Parent:IsA("Accessory") or part.Parent:IsA("Hat") then
            local character = part.Parent.Parent
            if character and character:FindFirstChild("Humanoid") then
                return true, character
            end
        end
        
        return false, nil
    end

    local function IsWall(part)
        if not part or not part:IsA("BasePart") then return false end
        
        if not part.CanCollide then return false end
        
        local isChar, _ = IsPartOfCharacter(part)
        if isChar then return false end
        
        local transparency = part.Transparency
        if transparency >= 0.95 then return false end
        
        local size = part.Size
        local minDimension = math.min(size.X, size.Y, size.Z)
        if minDimension < 0.1 then return false end
        
        return true
    end

    local function AdvancedRaycast(from, to, ignoreList)
        ignoreList = ignoreList or {}
        table.insert(ignoreList, Camera)
        
        local params = RaycastParams.new()
        params.FilterDescendantsInstances = ignoreList
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.IgnoreWater = true
        
        local direction = (to - from)
        local distance = direction.Magnitude
        local rayResult = workspace:Raycast(from, direction, params)
        
        if not rayResult then
            return true, nil
        end
        
        local hitPart = rayResult.Instance
        local hitPosition = rayResult.Position
        local hitDistance = (hitPosition - from).Magnitude
        
        local isChar, character = IsPartOfCharacter(hitPart)
        
        if isChar then
            if character and character:FindFirstChild("Humanoid") then
                return true, character
            end
        end
        
        if hitPart.Parent:IsA("Accessory") or hitPart.Parent:IsA("Hat") then
            table.insert(ignoreList, hitPart.Parent)
            return AdvancedRaycast(from, to, ignoreList)
        end
        
        if hitPart.Transparency >= 0.95 and not hitPart.CanCollide then
            table.insert(ignoreList, hitPart)
            return AdvancedRaycast(from, to, ignoreList)
        end
        
        if IsWall(hitPart) then
            local remainingDistance = distance - hitDistance
            if remainingDistance > 0.5 then
                return false, nil
            end
        end
        
        if hitPart.CanCollide then
            return false, nil
        end
        
        table.insert(ignoreList, hitPart)
        return AdvancedRaycast(from, to, ignoreList)
    end

    local function GetClosestEnemyHead(forAutoFire, targetListEnabled, targetedPlayers, usePrediction, predictionAmount, maxDistance)
        local closestScreenDistance = math.huge
        local closestHeadPos = nil
        local myCharacter = LocalPlayer.Character
        
        if not myCharacter or not myCharacter:FindFirstChild("HumanoidRootPart") then
            return nil
        end
        
        if forAutoFire then
            if IsInSafeZone(myCharacter) then
                return nil
            end
            if myCharacter:FindFirstChildOfClass("ForceField") then
                return nil
            end
        end
        
        local myHRP = myCharacter.HumanoidRootPart
        local mousePos = UserInputService:GetMouseLocation()

        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                local character = player.Character
                local head = character:FindFirstChild("Head")
                local humanoid = character:FindFirstChild("Humanoid")
                local enemyHRP = character:FindFirstChild("HumanoidRootPart")
                
                if head and humanoid and humanoid.Health > 0 and enemyHRP then
                    if IsPlayerTargeted(player, targetListEnabled, targetedPlayers) and not IsInSafeZone(character) and not character:FindFirstChildOfClass("ForceField") then
                        local headPos3D = head.Position
                        local distance3D = (headPos3D - myHRP.Position).Magnitude
                        
                        if distance3D <= maxDistance then
                            local headPos2D = Camera:WorldToViewportPoint(headPos3D)
                            local screenDistance = (Vector2.new(headPos2D.X, headPos2D.Y) - mousePos).Magnitude
                            
                            if screenDistance < closestScreenDistance then
                                local canHit, hitChar = AdvancedRaycast(myHRP.Position, headPos3D, {myCharacter})
                                
                                if canHit and hitChar == character then
                                    closestScreenDistance = screenDistance
                                    closestHeadPos = headPos3D
                                    
                                    if usePrediction and predictionAmount > 0 then
                                        local velocity = enemyHRP.AssemblyLinearVelocity
                                        closestHeadPos = closestHeadPos + (velocity * predictionAmount)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end

        return closestHeadPos
    end

    return {
        GetClosestEnemyHead = GetClosestEnemyHead,
        IsInSafeZone = IsInSafeZone,
        AdvancedRaycast = AdvancedRaycast,
        IsPlayerTargeted = IsPlayerTargeted,
        CollectSafeZones = CollectSafeZones,
        IsPointInPart = IsPointInPart
    }
end

local SilentAimCore = CreateSilentAimCore()

Players.PlayerAdded:Connect(function(player)
    playerSafeZoneStatus[player.UserId] = {
        isProtected = false,
        physicallyInside = false,
        enterTime = nil,
        exitTime = nil,
        justSpawned = true
    }
end)

Players.PlayerRemoving:Connect(function(player)
    playerSafeZoneStatus[player.UserId] = nil
end)

for _, player in pairs(Players:GetPlayers()) do
    playerSafeZoneStatus[player.UserId] = {
        isProtected = false,
        physicallyInside = false,
        enterTime = nil,
        exitTime = nil,
        justSpawned = true
    }
end

local function CreatePlayerFrame(player, scrollFrame, targetedPlayers)
    local PlayerFrame = Instance.new("Frame")
    PlayerFrame.Name = player.Name
    PlayerFrame.Size = UDim2.new(1, -10, 0, 75)
    PlayerFrame.BackgroundColor3 = targetedPlayers[player.Name] and Color3.fromRGB(60, 140, 60) or Color3.fromRGB(35, 35, 35)
    PlayerFrame.BorderSizePixel = 0
    PlayerFrame.Parent = scrollFrame
    
    local PlayerFrameCorner = Instance.new("UICorner")
    PlayerFrameCorner.CornerRadius = UDim.new(0, 10)
    PlayerFrameCorner.Parent = PlayerFrame
    
    local AvatarImage = Instance.new("ImageLabel")
    AvatarImage.Name = "Avatar"
    AvatarImage.Size = UDim2.new(0, 65, 0, 65)
    AvatarImage.Position = UDim2.new(0, 5, 0, 5)
    AvatarImage.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    AvatarImage.BorderSizePixel = 0
    AvatarImage.Image = ""
    AvatarImage.Parent = PlayerFrame
    
    task.spawn(function()
        local success, imageId = pcall(function()
            return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
        end)
        if success and imageId then
            AvatarImage.Image = imageId
        end
    end)
    
    local AvatarCorner = Instance.new("UICorner")
    AvatarCorner.CornerRadius = UDim.new(0, 10)
    AvatarCorner.Parent = AvatarImage
    
    local teamColor = player.Team and player.Team.TeamColor.Color or Color3.fromRGB(240, 240, 240)
    
    local DisplayName = Instance.new("TextLabel")
    DisplayName.Name = "DisplayName"
    DisplayName.Size = UDim2.new(1, -80, 0, 28)
    DisplayName.Position = UDim2.new(0, 75, 0, 8)
    DisplayName.BackgroundTransparency = 1
    DisplayName.Text = player.DisplayName
    DisplayName.TextColor3 = teamColor
    DisplayName.TextSize = 17
    DisplayName.Font = Enum.Font.GothamBold
    DisplayName.TextXAlignment = Enum.TextXAlignment.Left
    DisplayName.TextTruncate = Enum.TextTruncate.AtEnd
    DisplayName.Parent = PlayerFrame
    
    local UserName = Instance.new("TextLabel")
    UserName.Name = "UserName"
    UserName.Size = UDim2.new(1, -80, 0, 20)
    UserName.Position = UDim2.new(0, 75, 0, 36)
    UserName.BackgroundTransparency = 1
    UserName.Text = "@" .. player.Name
    UserName.TextColor3 = Color3.fromRGB(160, 160, 160)
    UserName.TextSize = 13
    UserName.Font = Enum.Font.Gotham
    UserName.TextXAlignment = Enum.TextXAlignment.Left
    UserName.TextTruncate = Enum.TextTruncate.AtEnd
    UserName.Parent = PlayerFrame
    
    local SelectButton = Instance.new("TextButton")
    SelectButton.Name = "SelectButton"
    SelectButton.Size = UDim2.new(1, 0, 1, 0)
    SelectButton.BackgroundTransparency = 1
    SelectButton.Text = ""
    SelectButton.Parent = PlayerFrame
    
    SelectButton.MouseButton1Click:Connect(function()
        if targetedPlayers[player.Name] then
            targetedPlayers[player.Name] = nil
            PlayerFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
        else
            targetedPlayers[player.Name] = true
            PlayerFrame.BackgroundColor3 = Color3.fromRGB(60, 140, 60)
        end
    end)
    
    SelectButton.MouseEnter:Connect(function()
        if not targetedPlayers[player.Name] then
            PlayerFrame.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
        end
    end)
    
    SelectButton.MouseLeave:Connect(function()
        if not targetedPlayers[player.Name] then
            PlayerFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
        end
    end)
    
    return PlayerFrame
end

local function UpdatePlayerList(scrollFrame, targetedPlayers)
    if not scrollFrame then return end
    
    local existingPlayers = {}
    for _, frame in pairs(scrollFrame:GetChildren()) do
        if frame:IsA("Frame") and frame.Name ~= "UIListLayout" then
            existingPlayers[frame.Name] = frame
        end
    end
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            if not existingPlayers[player.Name] then
                CreatePlayerFrame(player, scrollFrame, targetedPlayers)
            else
                local frame = existingPlayers[player.Name]
                frame.BackgroundColor3 = targetedPlayers[player.Name] and Color3.fromRGB(60, 140, 60) or Color3.fromRGB(35, 35, 35)
                
                local teamColor = player.Team and player.Team.TeamColor.Color or Color3.fromRGB(240, 240, 240)
                local displayName = frame:FindFirstChild("DisplayName")
                if displayName then
                    displayName.TextColor3 = teamColor
                end
            end
            existingPlayers[player.Name] = nil
        end
    end
    
    for playerName, frame in pairs(existingPlayers) do
        frame:Destroy()
    end
    
    local layout = scrollFrame:FindFirstChildOfClass("UIListLayout")
    if layout then
        scrollFrame.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 10)
    end
end

local function CreateTargetListGUI(title, targetedPlayers)
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "TargetListGUI"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.IgnoreGuiInset = true
    
    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.new(0, 420, 0, 520)
    MainFrame.Position = UDim2.new(0.5, -210, 0.5, -260)
    MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    MainFrame.BorderSizePixel = 0
    MainFrame.Active = true
    MainFrame.Parent = ScreenGui
    
    local UICorner = Instance.new("UICorner")
    UICorner.CornerRadius = UDim.new(0, 12)
    UICorner.Parent = MainFrame
    
    local TopBar = Instance.new("Frame")
    TopBar.Name = "TopBar"
    TopBar.Size = UDim2.new(1, 0, 0, 45)
    TopBar.BackgroundColor3 = Color3.fromRGB(34, 34, 34)
    TopBar.BorderSizePixel = 0
    TopBar.Parent = MainFrame
    
    local TopBarCorner = Instance.new("UICorner")
    TopBarCorner.CornerRadius = UDim.new(0, 12)
    TopBarCorner.Parent = TopBar
    
    local TopBarCover = Instance.new("Frame")
    TopBarCover.Size = UDim2.new(1, 0, 0, 12)
    TopBarCover.Position = UDim2.new(0, 0, 1, -12)
    TopBarCover.BackgroundColor3 = Color3.fromRGB(34, 34, 34)
    TopBarCover.BorderSizePixel = 0
    TopBarCover.Parent = TopBar
    
    local Title = Instance.new("TextLabel")
    Title.Name = "Title"
    Title.Size = UDim2.new(1, -60, 1, 0)
    Title.Position = UDim2.new(0, 18, 0, 0)
    Title.BackgroundTransparency = 1
    Title.Text = title
    Title.TextColor3 = Color3.fromRGB(240, 240, 240)
    Title.TextSize = 18
    Title.Font = Enum.Font.GothamBold
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.Parent = TopBar
    
    local CloseButton = Instance.new("TextButton")
    CloseButton.Name = "CloseButton"
    CloseButton.Size = UDim2.new(0, 32, 0, 32)
    CloseButton.Position = UDim2.new(1, -38, 0, 6)
    CloseButton.BackgroundTransparency = 1
    CloseButton.BorderSizePixel = 0
    CloseButton.Text = "X"
    CloseButton.TextColor3 = Color3.fromRGB(200, 200, 200)
    CloseButton.TextSize = 16
    CloseButton.Font = Enum.Font.GothamBold
    CloseButton.Parent = TopBar
    
    CloseButton.MouseEnter:Connect(function()
        CloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    end)
    
    CloseButton.MouseLeave:Connect(function()
        CloseButton.TextColor3 = Color3.fromRGB(200, 200, 200)
    end)
    
    local ScrollFrame = Instance.new("ScrollingFrame")
    ScrollFrame.Name = "PlayerList"
    ScrollFrame.Size = UDim2.new(1, -24, 1, -65)
    ScrollFrame.Position = UDim2.new(0, 12, 0, 53)
    ScrollFrame.BackgroundTransparency = 1
    ScrollFrame.BorderSizePixel = 0
    ScrollFrame.ScrollBarThickness = 6
    ScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(60, 60, 60)
    ScrollFrame.Active = true
    ScrollFrame.Parent = MainFrame
    
    local UIListLayout = Instance.new("UIListLayout")
    UIListLayout.SortOrder = Enum.SortOrder.Name
    UIListLayout.Padding = UDim.new(0, 6)
    UIListLayout.Parent = ScrollFrame
    
    ScreenGui.Parent = game.CoreGui
    
    return ScreenGui, MainFrame, ScrollFrame, CloseButton
end

local function OpenTargetList(isOpen, setOpen, guiRef, setGuiRef, targetedPlayers, title, notifyTitle)
    if isOpen then
        if guiRef then
            guiRef:Destroy()
            setGuiRef(nil)
        end
        setOpen(false)
        
        Rayfield:Notify({
            Title = notifyTitle,
            Content = "Closed",
            Duration = 1,
            Image = "list-x"
        })
    else
        local gui, mainFrame, scrollFrame, closeButton = CreateTargetListGUI(title, targetedPlayers)
        setGuiRef(gui)
        setOpen(true)
        
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                CreatePlayerFrame(player, scrollFrame, targetedPlayers)
            end
        end
        
        local layout = scrollFrame:FindFirstChildOfClass("UIListLayout")
        if layout then
            scrollFrame.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 10)
        end
        
        Rayfield:Notify({
            Title = notifyTitle,
            Content = "Opened",
            Duration = 1,
            Image = "list-checks"
        })
        
        closeButton.MouseButton1Click:Connect(function()
            gui:Destroy()
            setGuiRef(nil)
            setOpen(false)
            
            Rayfield:Notify({
                Title = notifyTitle,
                Content = "Closed",
                Duration = 1,
                Image = "list-x"
            })
        end)
        
        local dragToggle = false
        local dragStart = nil
        local startPos = nil
        
        local function updateInput(input)
            if not dragToggle then return end
            local delta = input.Position - dragStart
            mainFrame.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
        
        mainFrame.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragToggle = true
                dragStart = input.Position
                startPos = mainFrame.Position
                
                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then
                        dragToggle = false
                    end
                end)
            end
        end)
        
        mainFrame.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
                updateInput(input)
            end
        end)
        
        UserInputService.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement then
                updateInput(input)
            end
        end)
        
        local updateConnection = RunService.Heartbeat:Connect(function()
            if isOpen and guiRef and scrollFrame then
                UpdatePlayerList(scrollFrame, targetedPlayers)
            end
        end)
        
        local playerAddedConnection = Players.PlayerAdded:Connect(function(player)
            if isOpen and guiRef and scrollFrame then
                if player ~= LocalPlayer then
                    CreatePlayerFrame(player, scrollFrame, targetedPlayers)
                    local layout = scrollFrame:FindFirstChildOfClass("UIListLayout")
                    if layout then
                        scrollFrame.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 10)
                    end
                end
            end
        end)
        
        local playerRemovingConnection = Players.PlayerRemoving:Connect(function(player)
            if targetedPlayers[player.Name] then
                targetedPlayers[player.Name] = nil
            end
            if isOpen and guiRef and scrollFrame then
                local frame = scrollFrame:FindFirstChild(player.Name)
                if frame then
                    frame:Destroy()
                    local layout = scrollFrame:FindFirstChildOfClass("UIListLayout")
                    if layout then
                        scrollFrame.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 10)
                    end
                end
            end
        end)
        
        gui.Destroying:Connect(function()
            updateConnection:Disconnect()
            playerAddedConnection:Disconnect()
            playerRemovingConnection:Disconnect()
        end)
    end
end

local function GetBodyPart(character, partName)
    local mapping = bodyPartMapping[partName]
    if mapping then
        for _, part in ipairs(mapping.parts) do
            local foundPart = character:FindFirstChild(part)
            if foundPart then
                return foundPart, mapping.offset
            end
        end
    end
    return character:FindFirstChild(partName), Vector3.new(0, 0, 0)
end

local function GetClosestEnemyPart(targetPart, targetListEnabled, targetedPlayers)
    local closestScreenDistance = math.huge
    local closestPartPos = nil
    local closestPlayer = nil
    local closestCharacter = nil
    local myCharacter = LocalPlayer.Character
    
    if not myCharacter or not myCharacter:FindFirstChild("HumanoidRootPart") then
        return nil, nil
    end
    
    if SilentAimCore.IsInSafeZone(myCharacter) then
        return nil, nil
    end
    
    if myCharacter:FindFirstChildOfClass("ForceField") then
        return nil, nil
    end
    
    local myHRP = myCharacter.HumanoidRootPart
    local mousePos = UserInputService:GetMouseLocation()

    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local character = player.Character
            local humanoid = character:FindFirstChild("Humanoid")
            
            if humanoid and humanoid.Health > 0 then
                if SilentAimCore.IsPlayerTargeted(player, targetListEnabled, targetedPlayers) and not SilentAimCore.IsInSafeZone(character) and not character:FindFirstChildOfClass("ForceField") then
                    local part, offset = GetBodyPart(character, targetPart)
                    
                    if part then
                        local partPos3D = part.Position + offset
                        local distance3D = (partPos3D - myHRP.Position).Magnitude
                        
                        if distance3D <= MaxDistance then
                            local partPos2D = Camera:WorldToViewportPoint(partPos3D)
                            local screenDistance = (Vector2.new(partPos2D.X, partPos2D.Y) - mousePos).Magnitude
                            
                            if screenDistance < closestScreenDistance then
                                local canHit, hitChar = SilentAimCore.AdvancedRaycast(myHRP.Position, partPos3D, {myCharacter})
                                
                                if canHit and hitChar == character then
                                    closestScreenDistance = screenDistance
                                    closestPartPos = partPos3D
                                    closestPlayer = player
                                    closestCharacter = character
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    if closestPartPos and AimLockUsePrediction and AimLockPredictionAmount > 0 and closestCharacter then
        local enemyHRP = closestCharacter:FindFirstChild("HumanoidRootPart")
        if enemyHRP then
            local velocity = enemyHRP.AssemblyLinearVelocity
            closestPartPos = closestPartPos + (velocity * AimLockPredictionAmount)
        end
    end

    return closestPartPos, closestPlayer
end

local oldIndex
oldIndex = hookmetamethod(game, "__index", function(self, key)
    if SilentAimEnabled and self:IsA("Mouse") and key == "Hit" then
        local closestHead = SilentAimCore.GetClosestEnemyHead(false, SilentAimTargetListEnabled, SilentAimTargetedPlayers, UsePrediction, PredictionAmount, MaxDistance)
        if closestHead then
            return CFrame.new(closestHead)
        end
    end
    return oldIndex(self, key)
end)

local AUTO_CLICKS_PER_STEP = 3
local function fastClick(n)
    n = n or AUTO_CLICKS_PER_STEP
    for i = 1, n do
        mouse1click()
    end
end

RunService.RenderStepped:Connect(function()
    if not (SilentAimEnabled and SilentAimAutoFireEnabled) then return end
    
    local myCharacter = LocalPlayer.Character
    if not myCharacter then return end
    if SilentAimCore.IsInSafeZone(myCharacter) then return end
    if myCharacter:FindFirstChildOfClass("ForceField") then return end
    
    local tool = myCharacter:FindFirstChildOfClass("Tool")
    if not tool or not tool:FindFirstChild("ConfigGun") then return end
    
    local targetHead = SilentAimCore.GetClosestEnemyHead(true, SilentAimTargetListEnabled, SilentAimTargetedPlayers, UsePrediction, PredictionAmount, MaxDistance)
    if targetHead then
        fastClick()
    end
end)

RunService.RenderStepped:Connect(function()
    if not (AimLockEnabled and AimLockAutoFireEnabled) then return end
    
    local myCharacter = LocalPlayer.Character
    if not myCharacter then return end
    if SilentAimCore.IsInSafeZone(myCharacter) then return end
    if myCharacter:FindFirstChildOfClass("ForceField") then return end
    
    if AimLockTarget and AimLockTarget.Character then
        local character = AimLockTarget.Character
        local humanoid = character:FindFirstChild("Humanoid")
        
        if not humanoid or humanoid.Health <= 0 then
            return
        end
        
        if SilentAimCore.IsInSafeZone(character) then return end
        if character:FindFirstChildOfClass("ForceField") then return end
        
        local part, offset = GetBodyPart(character, AimLockPart)
        if part then
            local myHead = myCharacter:FindFirstChild("Head")
            if not myHead then return end
            
            local targetPos = part.Position + offset
            local canHit, hitChar = SilentAimCore.AdvancedRaycast(myHead.Position, targetPos, {myCharacter})
            if canHit and hitChar == character then
                fastClick()
            end
        end
    end
end)

RunService.RenderStepped:Connect(function()
    if AimLockEnabled and AimLockTarget then
        local character = AimLockTarget.Character
        if not character then
            AimLockTarget = nil
            UserInputService.MouseBehavior = Enum.MouseBehavior.Default
            return
        end
        
        local humanoid = character:FindFirstChild("Humanoid")
        if not humanoid or humanoid.Health <= 0 then
            AimLockTarget = nil
            UserInputService.MouseBehavior = Enum.MouseBehavior.Default
            return
        end
        
        local part, offset = GetBodyPart(character, AimLockPart)
        
        if part then
            local targetPosition = part.Position + offset
            
            if AimLockUsePrediction and AimLockPredictionAmount > 0 then
                local enemyHRP = character:FindFirstChild("HumanoidRootPart")
                if enemyHRP then
                    local velocity = enemyHRP.AssemblyLinearVelocity
                    targetPosition = targetPosition + (velocity * AimLockPredictionAmount)
                end
            end
            
            Camera.CFrame = CFrame.new(Camera.CFrame.Position, targetPosition)
        else
            AimLockTarget = nil
            UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        end
    end
end)

task.spawn(function()
    while task.wait() do
        local character = LocalPlayer.Character
        if character then
            local tool = character:FindFirstChildOfClass("Tool")
            if tool then
                local configGun = tool:FindFirstChild("ConfigGun")
                if configGun then
                    local success, module = pcall(require, configGun)
                    if success and module then
                        local toolName = tool.Name
                        
                        if not OriginalRecoil[toolName] then
                            OriginalRecoil[toolName] = {
                                RecoilX = module.RecoilX,
                                RecoilY = module.RecoilY
                            }
                        end
                        
                        if NoRecoilEnabled then
                            module.RecoilX = 0
                            module.RecoilY = 0
                        else
                            if OriginalRecoil[toolName] then
                                module.RecoilX = OriginalRecoil[toolName].RecoilX
                                module.RecoilY = OriginalRecoil[toolName].RecoilY
                            end
                        end
                    end
                end
            end
        end
    end
end)

local function GetAllPlayers()
    local playerNames = {}
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            table.insert(playerNames, player.Name)
        end
    end
    return playerNames
end

local PlayerDropdown = nil

MainTab:CreateSection("Silent Aim")

local SilentAimToggle = MainTab:CreateToggle({
    Name = "Silent Aim",
    CurrentValue = false,
    Flag = "SilentAimToggle",
    Callback = function(Value)
        SilentAimEnabled = Value
        Rayfield:Notify({
            Title = "Silent Aim",
            Content = Value and "Enabled" or "Disabled",
            Duration = 1,
            Image = Value and "crosshair" or "x"
        })
    end,
})

local MaxDistanceSlider = MainTab:CreateSlider({
    Name = "Max Distance",
    Range = {50, 1000},
    Increment = 10,
    Suffix = " studs",
    CurrentValue = 1000,
    Flag = "MaxDistanceSlider",
    Callback = function(Value)
        MaxDistance = Value
    end,
})

local AutoFireToggle = MainTab:CreateToggle({
    Name = "Auto Fire",
    CurrentValue = false,
    Flag = "SilentAimAutoFireToggle",
    Callback = function(Value)
        SilentAimAutoFireEnabled = Value
        Rayfield:Notify({
            Title = "Auto Fire",
            Content = Value and "Enabled" or "Disabled",
            Duration = 1,
            Image = Value and "zap" or "zap-off"
        })
    end,
})

local NoRecoilToggle = MainTab:CreateToggle({
    Name = "No Recoil",
    CurrentValue = false,
    Flag = "NoRecoilToggle",
    Callback = function(Value)
        NoRecoilEnabled = Value
        Rayfield:Notify({
            Title = "No Recoil",
            Content = Value and "Enabled" or "Disabled",
            Duration = 1,
            Image = Value and "shield" or "shield-off"
        })
    end,
})

local PredictionToggle = MainTab:CreateToggle({
    Name = "Use Prediction",
    CurrentValue = false,
    Flag = "PredictionToggle",
    Callback = function(Value)
        UsePrediction = Value
        Rayfield:Notify({
            Title = "Prediction",
            Content = Value and "Enabled" or "Disabled",
            Duration = 1,
            Image = Value and "target" or "x"
        })
    end,
})

local PredictionSlider = MainTab:CreateSlider({
    Name = "Prediction",
    Range = {0, 1},
    Increment = 0.01,
    Suffix = "",
    CurrentValue = 0,
    Flag = "PredictionSlider",
    Callback = function(Value)
        PredictionAmount = Value
    end,
})

local SilentAimTargetListToggle = MainTab:CreateToggle({
    Name = "Use Target List",
    CurrentValue = false,
    Flag = "SilentAimTargetListToggle",
    Callback = function(Value)
        SilentAimTargetListEnabled = Value
        Rayfield:Notify({
            Title = "Target List",
            Content = Value and "Enabled - Only targeting selected players" or "Disabled - Targeting all players",
            Duration = 1,
            Image = Value and "users" or "users-round"
        })
    end,
})

local OpenSilentAimTargetListButton = MainTab:CreateButton({
    Name = "Open Silent Aim Target List",
    Callback = function()
        OpenTargetList(
            SilentAimTargetListOpen,
            function(val) SilentAimTargetListOpen = val end,
            SilentAimTargetListGUI,
            function(gui) SilentAimTargetListGUI = gui end,
            SilentAimTargetedPlayers,
            "Silent Aim Target List",
            "Silent Aim Target List"
        )
    end,
})

MainTab:CreateSection("Aim Lock")

local AimLockToggle = MainTab:CreateToggle({
    Name = "Aim Lock",
    CurrentValue = false,
    Flag = "AimLockToggle",
    Callback = function(Value)
        AimLockEnabled = Value
        if not Value then
            AimLockTarget = nil
            UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        end
        Rayfield:Notify({
            Title = "Aim Lock",
            Content = Value and "Enabled" or "Disabled",
            Duration = 1,
            Image = Value and "lock" or "unlock"
        })
    end,
})

local AimLockKeybindInput = MainTab:CreateKeybind({
    Name = "Aim Lock Keybind",
    CurrentKeybind = "",
    HoldToInteract = false,
    Flag = "AimLockKeybind",
    Callback = function()
        if not AimLockEnabled then return end
        
        if not AimLockTarget then
            local mouse = LocalPlayer:GetMouse()
            local mousePosition = Vector2.new(mouse.X, mouse.Y)
            
            local nearestPlayer = nil
            local minDistance = math.huge
            local camera = workspace.CurrentCamera

            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and player.Character then
                    if SilentAimCore.IsPlayerTargeted(player, AimLockTargetListEnabled, AimLockTargetedPlayers) then
                        local character = player.Character
                        local humanoid = character:FindFirstChild("Humanoid")
                        
                        if humanoid and humanoid.Health > 0 then
                            local part, offset = GetBodyPart(character, AimLockPart)

                            if part then
                                local partPosition = part.Position + offset
                                local partScreenPosition, onScreen = camera:WorldToViewportPoint(partPosition)

                                if onScreen and partScreenPosition.Z > 0 then
                                    local distance = (Vector2.new(partScreenPosition.X, partScreenPosition.Y) - mousePosition).magnitude

                                    if distance < minDistance then
                                        minDistance = distance
                                        nearestPlayer = player
                                    end
                                end
                            end
                        end
                    end
                end
            end
            
            if nearestPlayer then
                AimLockTarget = nearestPlayer
                UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
            end
        else
            AimLockTarget = nil
            UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        end
    end,
})

local AimLockPartDropdown = MainTab:CreateDropdown({
    Name = "Aim Part",
    Options = {"Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg"},
    CurrentOption = {"Head"},
    MultipleOptions = false,
    Flag = "AimLockPart",
    Callback = function(Options)
        AimLockPart = Options[1]
        Rayfield:Notify({
            Title = "Aim Lock",
            Content = "Aim part set to " .. AimLockPart,
            Duration = 1,
            Image = "target"
        })
    end,
})

local AimLockAutoFireToggle = MainTab:CreateToggle({
    Name = "Auto Fire",
    CurrentValue = false,
    Flag = "AimLockAutoFireToggle",
    Callback = function(Value)
        AimLockAutoFireEnabled = Value
        Rayfield:Notify({
            Title = "Aim Lock Auto Fire",
            Content = Value and "Enabled" or "Disabled",
            Duration = 1,
            Image = Value and "zap" or "zap-off"
        })
    end,
})

local AimLockPredictionToggle = MainTab:CreateToggle({
    Name = "Use Prediction",
    CurrentValue = false,
    Flag = "AimLockPredictionToggle",
    Callback = function(Value)
        AimLockUsePrediction = Value
        Rayfield:Notify({
            Title = "Aim Lock Prediction",
            Content = Value and "Enabled" or "Disabled",
            Duration = 1,
            Image = Value and "target" or "x"
        })
    end,
})

local AimLockPredictionSlider = MainTab:CreateSlider({
    Name = "Prediction",
    Range = {0, 1},
    Increment = 0.01,
    Suffix = "",
    CurrentValue = 0,
    Flag = "AimLockPredictionSlider",
    Callback = function(Value)
        AimLockPredictionAmount = Value
    end,
})

local AimLockTargetListToggle = MainTab:CreateToggle({
    Name = "Use Target List",
    CurrentValue = false,
    Flag = "AimLockTargetListToggle",
    Callback = function(Value)
        AimLockTargetListEnabled = Value
        Rayfield:Notify({
            Title = "Aim Lock Target List",
            Content = Value and "Enabled - Only targeting selected players" or "Disabled - Targeting all players",
            Duration = 1,
            Image = Value and "users" or "users-round"
        })
    end,
})

local OpenAimLockTargetListButton = MainTab:CreateButton({
    Name = "Open Aim Lock Target List",
    Callback = function()
        OpenTargetList(
            AimLockTargetListOpen,
            function(val) AimLockTargetListOpen = val end,
            AimLockTargetListGUI,
            function(gui) AimLockTargetListGUI = gui end,
            AimLockTargetedPlayers,
            "Aim Lock Target List",
            "Aim Lock Target List"
        )
    end,
})

local PlayerESPEnabled = false
local Holder = nil
local updateConnections = {}
local espLoopRunning = false
local playerConnections = {}

local Box = Instance.new("BoxHandleAdornment")
Box.Name = "nilBox"
Box.Size = Vector3.new(1, 2, 1)
Box.Color3 = Color3.fromRGB(100, 100, 100)
Box.Transparency = 0.7
Box.ZIndex = 0
Box.AlwaysOnTop = false
Box.Visible = false

local NameTag = Instance.new("BillboardGui")
NameTag.Name = "nilNameTag"
NameTag.Enabled = false
NameTag.Size = UDim2.new(0, 200, 0, 50)
NameTag.AlwaysOnTop = true
NameTag.StudsOffset = Vector3.new(0, 1.8, 0)
local Tag = Instance.new("TextLabel", NameTag)
Tag.Name = "Tag"
Tag.BackgroundTransparency = 1
Tag.Position = UDim2.new(0, -50, 0, 0)
Tag.Size = UDim2.new(0, 300, 0, 20)
Tag.TextSize = 15
Tag.TextColor3 = Color3.fromRGB(100, 100, 100)
Tag.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
Tag.TextStrokeTransparency = 0.4
Tag.Text = "nil"
Tag.Font = Enum.Font.SourceSansBold
Tag.TextScaled = false

local function LoadCharacter(v)
    if not PlayerESPEnabled or not Holder then return end
    
    task.spawn(function()
        repeat task.wait() until v.Character ~= nil
        if not PlayerESPEnabled then return end
        repeat task.wait() until v.Character:FindFirstChild("Humanoid")
        if not PlayerESPEnabled then return end
        repeat task.wait() until v.Character:FindFirstChild("HumanoidRootPart")
        if not PlayerESPEnabled then return end
        repeat task.wait() until v.Character:FindFirstChild("Head")
        if not PlayerESPEnabled or not Holder then return end
        
        local vHolder = Holder:FindFirstChild(v.Name)
        if not vHolder then return end
        
        vHolder:ClearAllChildren()
        
        local b = Box:Clone()
        b.Name = v.Name .. "Box"
        b.Adornee = v.Character
        b.Parent = vHolder
        
        local t = NameTag:Clone()
        t.Name = v.Name .. "NameTag"
        t.Enabled = true
        t.Parent = vHolder
        t.Adornee = v.Character.Head
        t.Tag.Text = v.Name
        
        b.Color3 = Color3.new(v.TeamColor.r, v.TeamColor.g, v.TeamColor.b)
        t.Tag.TextColor3 = Color3.new(v.TeamColor.r, v.TeamColor.g, v.TeamColor.b)
        
        if updateConnections[v.Name] then
            updateConnections[v.Name]:Disconnect()
        end
        
        local UpdateNameTag = function()
            if not PlayerESPEnabled then return end
            pcall(function()
                if v.Character and v.Character:FindFirstChild("Humanoid") and v.Character:FindFirstChild("HumanoidRootPart") then
                    v.Character.Humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
                    local h = math.floor(v.Character.Humanoid.Health)
                    
                    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                        local distance = math.floor((LocalPlayer.Character.HumanoidRootPart.Position - v.Character.HumanoidRootPart.Position).Magnitude)
                        t.Tag.Text = v.Name .. " | " .. h .. " HP | " .. distance .. " Studs"
                    else
                        t.Tag.Text = v.Name .. " | " .. h .. " HP"
                    end
                end
            end)
        end
        
        UpdateNameTag()
        updateConnections[v.Name] = RunService.RenderStepped:Connect(UpdateNameTag)
    end)
end

local function UnloadCharacter(v)
    if Holder then
        local vHolder = Holder:FindFirstChild(v.Name)
        if vHolder then
            vHolder:ClearAllChildren()
        end
    end
    
    if updateConnections[v.Name] then
        updateConnections[v.Name]:Disconnect()
        updateConnections[v.Name] = nil
    end
    
    if v.Character and v.Character:FindFirstChild("GetReal") then
        v.Character.GetReal:Destroy()
    end
end

local function LoadPlayer(v)
    if not PlayerESPEnabled or v == LocalPlayer or not Holder then return end
    
    local vHolder = Instance.new("Folder", Holder)
    vHolder.Name = v.Name
    
    if not playerConnections[v.Name] then
        playerConnections[v.Name] = {}
    end
    
    playerConnections[v.Name].CharacterAdded = v.CharacterAdded:Connect(function()
        if PlayerESPEnabled then
            pcall(LoadCharacter, v)
        end
    end)
    
    playerConnections[v.Name].CharacterRemoving = v.CharacterRemoving:Connect(function()
        pcall(UnloadCharacter, v)
    end)
    
    playerConnections[v.Name].Changed = v.Changed:Connect(function(prop)
        if prop == "TeamColor" and PlayerESPEnabled then
            UnloadCharacter(v)
            task.wait()
            LoadCharacter(v)
        end
    end)
    
    pcall(LoadCharacter, v)
end

local function UnloadPlayer(v)
    UnloadCharacter(v)
    
    if playerConnections[v.Name] then
        for _, connection in pairs(playerConnections[v.Name]) do
            connection:Disconnect()
        end
        playerConnections[v.Name] = nil
    end
    
    if Holder then
        local vHolder = Holder:FindFirstChild(v.Name)
        if vHolder then
            vHolder:Destroy()
        end
    end
end

local function StartPlayerESP()
    PlayerESPEnabled = true
    
    Holder = Instance.new("Folder", game.CoreGui)
    Holder.Name = "ESP"
    
    for _, v in pairs(Players:GetPlayers()) do
        task.spawn(function() pcall(LoadPlayer, v) end)
    end
    
    playerConnections.PlayerAdded = Players.PlayerAdded:Connect(function(v)
        if PlayerESPEnabled then
            pcall(LoadPlayer, v)
        end
    end)
    
    playerConnections.PlayerRemoving = Players.PlayerRemoving:Connect(function(v)
        pcall(UnloadPlayer, v)
    end)
    
    LocalPlayer.NameDisplayDistance = 0
    
    espLoopRunning = true
    task.spawn(function()
        local function esp(target, color)
            if not PlayerESPEnabled then return end
            if target.Character then
                if not target.Character:FindFirstChild("GetReal") then
                    local highlight = Instance.new("Highlight")
                    highlight.RobloxLocked = true
                    highlight.Name = "GetReal"
                    highlight.Adornee = target.Character
                    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    highlight.FillColor = color
                    highlight.Parent = target.Character
                else
                    target.Character.GetReal.FillColor = color
                end
            end
        end
        
        while espLoopRunning and task.wait() do
            if not PlayerESPEnabled then break end
            for _, v in pairs(Players:GetPlayers()) do
                if v ~= LocalPlayer and PlayerESPEnabled then
                    pcall(esp, v, v.TeamColor.Color)
                end
            end
        end
    end)
end

local function StopPlayerESP()
    PlayerESPEnabled = false
    espLoopRunning = false
    
    for name, connection in pairs(updateConnections) do
        if connection then
            connection:Disconnect()
        end
    end
    updateConnections = {}
    
    for name, connections in pairs(playerConnections) do
        if type(connections) == "table" then
            for _, connection in pairs(connections) do
                if connection then
                    connection:Disconnect()
                end
            end
        elseif typeof(connections) == "RBXScriptConnection" then
            connections:Disconnect()
        end
    end
    playerConnections = {}
    
    for _, v in pairs(Players:GetPlayers()) do
        if v.Character and v.Character:FindFirstChild("GetReal") then
            v.Character.GetReal:Destroy()
        end
    end
    
    if Holder then
        Holder:Destroy()
        Holder = nil
    end
end

local GunESPEnabled = false
local GunHolder = nil
local gunConnections = {}
local trackedGuns = {}

local GunList = {
    "У-ВСУ",
    "Рычажник",
    "Пистолет Искры",
    "ОРДОВИК",
    "Обрез",
    "Макаров",
    "М-Маркелоф",
    "Дизерт Игл",
    "Глок 10",
    "AK74M",
    "AK-25",
    "Rezingtan 15",
    "MP5",
    "Hommie-Durka",
    ".21 Револьвер",
    "ПУГАЧ",
    "P90",
    "M4A4",
    "Джавелин",
    "Драгунов"
}

local function IsGun(name)
    for _, gunName in ipairs(GunList) do
        if name == gunName then
            return true
        end
    end
    return false
end

local function IsInPlayerCharacter(tool)
    if not tool or not tool:IsA("Tool") then return true end
    
    local parent = tool.Parent
    
    if not parent then return false end
    
    if parent:IsA("Model") then
        local player = Players:GetPlayerFromCharacter(parent)
        if player then
            return true
        end
    end
    
    if parent:IsA("Backpack") then
        local player = parent.Parent
        if player and player:IsA("Player") then
            return true
        end
    end
    
    local current = parent
    while current do
        if current == workspace then
            return false
        end
        if current:IsA("Model") and Players:GetPlayerFromCharacter(current) then
            return true
        end
        current = current.Parent
    end
    
    return parent ~= workspace
end

local function CreateGunESP(tool)
    if not GunESPEnabled or not GunHolder or not tool then return end
    if not tool:IsA("Tool") then return end
    if not IsGun(tool.Name) then return end
    if trackedGuns[tool] then return end
    if IsInPlayerCharacter(tool) then return end
    
    local handle = tool:FindFirstChild("Handle") or tool:FindFirstChildWhichIsA("BasePart")
    if not handle then return end
    
    local billboardGui = Instance.new("BillboardGui")
    billboardGui.Name = "GunESP"
    billboardGui.AlwaysOnTop = true
    billboardGui.Size = UDim2.new(0, 200, 0, 50)
    billboardGui.StudsOffset = Vector3.new(0, 2, 0)
    billboardGui.Adornee = handle
    
    local textLabel = Instance.new("TextLabel", billboardGui)
    textLabel.BackgroundTransparency = 1
    textLabel.Size = UDim2.new(1, 0, 1, 0)
    textLabel.TextSize = 15
    textLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
    textLabel.TextStrokeTransparency = 0.4
    textLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    textLabel.Font = Enum.Font.SourceSansBold
    textLabel.Text = tool.Name
    
    billboardGui.Parent = GunHolder
    
    local lastUpdate = 0
    local UPDATE_INTERVAL = 0.1
    
    trackedGuns[tool] = {
        gui = billboardGui,
        connection = RunService.Heartbeat:Connect(function()
            if not GunESPEnabled or not tool or not tool.Parent then
                if trackedGuns[tool] then
                    trackedGuns[tool].connection:Disconnect()
                    trackedGuns[tool].gui:Destroy()
                    trackedGuns[tool] = nil
                end
                return
            end
            
            if IsInPlayerCharacter(tool) then
                if trackedGuns[tool] then
                    trackedGuns[tool].connection:Disconnect()
                    trackedGuns[tool].gui:Destroy()
                    trackedGuns[tool] = nil
                end
                return
            end
            
            local currentTime = tick()
            if currentTime - lastUpdate >= UPDATE_INTERVAL then
                lastUpdate = currentTime
                pcall(function()
                    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                        local toolHandle = tool:FindFirstChild("Handle") or tool:FindFirstChildWhichIsA("BasePart")
                        if toolHandle then
                            local distance = math.floor((LocalPlayer.Character.HumanoidRootPart.Position - toolHandle.Position).Magnitude)
                            textLabel.Text = tool.Name .. "\n[" .. distance .. " studs]"
                        end
                    end
                end)
            end
        end)
    }
end

local function RemoveGunESP(tool)
    if trackedGuns[tool] then
        if trackedGuns[tool].connection then
            trackedGuns[tool].connection:Disconnect()
        end
        if trackedGuns[tool].gui then
            trackedGuns[tool].gui:Destroy()
        end
        trackedGuns[tool] = nil
    end
end

local function ScanWorkspace()
    if not GunESPEnabled then return end
    
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Tool") and IsGun(obj.Name) then
            if not IsInPlayerCharacter(obj) then
                CreateGunESP(obj)
            end
        end
    end
end

local function StartGunESP()
    GunESPEnabled = true
    
    GunHolder = Instance.new("Folder", game.CoreGui)
    GunHolder.Name = "GunESP"
    
    ScanWorkspace()
    
    gunConnections.DescendantAdded = workspace.DescendantAdded:Connect(function(obj)
        if GunESPEnabled and obj:IsA("Tool") and IsGun(obj.Name) then
            task.wait(0.2)
            if GunESPEnabled and obj.Parent and not IsInPlayerCharacter(obj) then
                CreateGunESP(obj)
            end
        end
    end)
    
    gunConnections.DescendantRemoving = workspace.DescendantRemoving:Connect(function(obj)
        if obj:IsA("Tool") and trackedGuns[obj] then
            RemoveGunESP(obj)
        end
    end)
    
    gunConnections.PlayerCharacterAdded = {}
    for _, player in pairs(Players:GetPlayers()) do
        gunConnections.PlayerCharacterAdded[player.Name] = player.CharacterAdded:Connect(function(character)
            task.wait(0.5)
            for tool, _ in pairs(trackedGuns) do
                if IsInPlayerCharacter(tool) then
                    RemoveGunESP(tool)
                end
            end
        end)
    end
    
    gunConnections.PlayerAdded = Players.PlayerAdded:Connect(function(player)
        gunConnections.PlayerCharacterAdded[player.Name] = player.CharacterAdded:Connect(function(character)
            task.wait(0.5)
            for tool, _ in pairs(trackedGuns) do
                if IsInPlayerCharacter(tool) then
                    RemoveGunESP(tool)
                end
            end
        end)
    end)
end

local function StopGunESP()
    GunESPEnabled = false
    
    for tool, data in pairs(trackedGuns) do
        if data.connection then
            data.connection:Disconnect()
        end
        if data.gui then
            data.gui:Destroy()
        end
    end
    trackedGuns = {}
    
    for name, connection in pairs(gunConnections) do
        if name == "PlayerCharacterAdded" then
            for _, conn in pairs(connection) do
                if conn then
                    conn:Disconnect()
                end
            end
        elseif connection then
            connection:Disconnect()
        end
    end
    gunConnections = {}
    
    if GunHolder then
        GunHolder:Destroy()
        GunHolder = nil
    end
end

local FullbrightEnabled = false
local OriginalLighting = {}
local lightingConnection = nil

local function SaveOriginalLighting()
    local Light = game:GetService("Lighting")
    OriginalLighting.Ambient = Light.Ambient
    OriginalLighting.ColorShift_Bottom = Light.ColorShift_Bottom
    OriginalLighting.ColorShift_Top = Light.ColorShift_Top
end

local function ApplyFullbright()
    local Light = game:GetService("Lighting")
    Light.Ambient = Color3.fromRGB(255, 255, 255)
    Light.ColorShift_Bottom = Color3.fromRGB(255, 255, 255)
    Light.ColorShift_Top = Color3.fromRGB(255, 255, 255)
end

local function RestoreOriginalLighting()
    local Light = game:GetService("Lighting")
    Light.Ambient = OriginalLighting.Ambient or Color3.fromRGB(0, 0, 0)
    Light.ColorShift_Bottom = OriginalLighting.ColorShift_Bottom or Color3.fromRGB(0, 0, 0)
    Light.ColorShift_Top = OriginalLighting.ColorShift_Top or Color3.fromRGB(0, 0, 0)
end

local function StartFullbright()
    FullbrightEnabled = true
    SaveOriginalLighting()
    ApplyFullbright()
    
    lightingConnection = game:GetService("Lighting").LightingChanged:Connect(function()
        if FullbrightEnabled then
            ApplyFullbright()
        end
    end)
end

local function StopFullbright()
    FullbrightEnabled = false
    
    if lightingConnection then
        lightingConnection:Disconnect()
        lightingConnection = nil
    end
    
    RestoreOriginalLighting()
end

local PlayerESPToggle = VisualTab:CreateToggle({
    Name = "Player ESP",
    CurrentValue = false,
    Flag = "PlayerESPToggle",
    Callback = function(Value)
        if Value then
            StartPlayerESP()
            Rayfield:Notify({
                Title = "Player ESP",
                Content = "On",
                Duration = 1,
                Image = "eye"
            })
        else
            StopPlayerESP()
            Rayfield:Notify({
                Title = "Player ESP",
                Content = "Off",
                Duration = 1,
                Image = "eye-off"
            })
        end
    end,
})

local GunESPToggle = VisualTab:CreateToggle({
    Name = "Gun ESP",
    CurrentValue = false,
    Flag = "GunESPToggle",
    Callback = function(Value)
        if Value then
            StartGunESP()
            Rayfield:Notify({
                Title = "Gun ESP",
                Content = "On",
                Duration = 1,
                Image = "sword"
            })
        else
            StopGunESP()
            Rayfield:Notify({
                Title = "Gun ESP",
                Content = "Off",
                Duration = 1,
                Image = "x"
            })
        end
    end,
})

local FullbrightToggle = VisualTab:CreateToggle({
    Name = "Fullbright",
    CurrentValue = false,
    Flag = "FullbrightToggle",
    Callback = function(Value)
        if Value then
            StartFullbright()
            Rayfield:Notify({
                Title = "Fullbright",
                Content = "On",
                Duration = 1,
                Image = "lightbulb"
            })
        else
            StopFullbright()
            Rayfield:Notify({
                Title = "Fullbright",
                Content = "Off",
                Duration = 1,
                Image = "lightbulb-off"
            })
        end
    end,
})

TeleportTab:CreateSection("TP to the sky")

local TeleportEnabled = false
local isActionActive = false
local originalPosition = nil
local HEIGHT_THRESHOLD = 750

local function performTeleport()
    if not TeleportEnabled then return end
    if isActionActive then return end
    
    isActionActive = true

    local character = LocalPlayer.Character
    if not character then 
        isActionActive = false
        return 
    end

    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChild("Humanoid")

    if humanoidRootPart and humanoid then
        if originalPosition then
            local currentHeight = humanoidRootPart.Position.Y
            local originalHeight = originalPosition.Position.Y
            
            if currentHeight >= (originalHeight + HEIGHT_THRESHOLD) then
                humanoidRootPart.CFrame = originalPosition
                originalPosition = nil
            else
                originalPosition = humanoidRootPart.CFrame
                
                local currentPosition = humanoidRootPart.Position
                local newPosition = currentPosition + Vector3.new(30, 800, 30)

                humanoidRootPart.CFrame = CFrame.new(newPosition)
                local jumpForce = Vector3.new(0, 30, 0)
                humanoidRootPart.Velocity = humanoidRootPart.Velocity + jumpForce
            end
        else
            originalPosition = humanoidRootPart.CFrame
            
            local currentPosition = humanoidRootPart.Position
            local newPosition = currentPosition + Vector3.new(30, 800, 30)

            humanoidRootPart.CFrame = CFrame.new(newPosition)
            local jumpForce = Vector3.new(0, 30, 0)
            humanoidRootPart.Velocity = humanoidRootPart.Velocity + jumpForce
        end
    end

    task.wait(0.5)
    isActionActive = false
end

RunService.Heartbeat:Connect(function()
    if not TeleportEnabled or not originalPosition then return end
    
    local character = LocalPlayer.Character
    if not character then return end
    
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    local currentHeight = hrp.Position.Y
    local originalHeight = originalPosition.Position.Y
    
    if currentHeight >= (originalHeight + HEIGHT_THRESHOLD) then
        hrp.Velocity = Vector3.new(hrp.Velocity.X, 0, hrp.Velocity.Z)
        hrp.AssemblyLinearVelocity = Vector3.new(hrp.AssemblyLinearVelocity.X, 0, hrp.AssemblyLinearVelocity.Z)
    end
end)

local TeleportToggle = TeleportTab:CreateToggle({
    Name = "TP 800 studs up",
    CurrentValue = false,
    Flag = "TeleportToggle",
    Callback = function(Value)
        TeleportEnabled = Value
        
        if not Value then
            originalPosition = nil
        end
        
        Rayfield:Notify({
            Title = "Teleport 800 studs up",
            Content = Value and "Enabled" or "Disabled",
            Duration = 1,
            Image = Value and "check" or "x"
        })
    end,
})

local TeleportKeybind = TeleportTab:CreateKeybind({
    Name = "TP 800 studs up Keybind",
    CurrentKeybind = "",
    HoldToInteract = false,
    Flag = "TeleportKeybind",
    Callback = function()
        performTeleport()
    end,
})

TeleportTab:CreateSection("TP to players")

local function PositionIsFree(cframe, exclude)
    local params = OverlapParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = exclude or {}
    local size = Vector3.new(2, 4, 2)
    local touching = workspace:GetPartBoundsInBox(cframe, size, params)
    return #touching == 0
end

local function GroundBelow(pos, exclude)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = exclude or {}
    return workspace:Raycast(pos + Vector3.new(0, 3, 0), Vector3.new(0, -12, 0), params)
end

local function HasLineOfSight(fromPos, toPos, exclude)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = exclude or {}
    local res = workspace:Raycast(fromPos, (toPos - fromPos), params)
    return res == nil
end

local function BestTeleportCFrameAround(targetHRP, myChar)
    local offset = 3
    local baseCF = targetHRP.CFrame
    local exclude = { myChar, targetHRP.Parent, Camera }
    
    local behindPos = baseCF * CFrame.new(0, 0, offset)
    local behindPosWorld = behindPos.Position
    
    if PositionIsFree(CFrame.new(behindPosWorld), exclude) then
        local down = GroundBelow(behindPosWorld, exclude)
        if down and down.Instance and down.Instance.CanCollide then
            if HasLineOfSight(behindPosWorld + Vector3.new(0, 1.5, 0), targetHRP.Position, exclude) then
                return CFrame.new(down.Position + Vector3.new(0, 3, 0))
            end
        end
    end
    
    local alternativePositions = {
        baseCF * CFrame.new(0, 0, -offset),
        baseCF * CFrame.new(-offset, 0, 0),
        baseCF * CFrame.new(offset, 0, 0),
    }
    
    for _, cf in ipairs(alternativePositions) do
        local pos = cf.Position
        if PositionIsFree(CFrame.new(pos), exclude) then
            local down = GroundBelow(pos, exclude)
            if down and down.Instance and down.Instance.CanCollide then
                if HasLineOfSight(pos + Vector3.new(0, 1.5, 0), targetHRP.Position, exclude) then
                    return CFrame.new(down.Position + Vector3.new(0, 3, 0))
                end
            end
        end
    end

    return nil
end

function TeleportBehindOrBestSpot()
    if not TeleportToPlayerEnabled then return end

    local myChar = LocalPlayer.Character
    if not myChar or not myChar:FindFirstChild("HumanoidRootPart") then
        return
    end

    local targetPlayer = nil
    local targetHRP = nil

    if TPToAimlockedEnabled and AimLockTarget and AimLockTarget.Character then
        targetPlayer = AimLockTarget
        targetHRP = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
        
        if not targetHRP then
            Rayfield:Notify({
                Title = "TP to Aimlocked",
                Content = "Invalid aimlocked target",
                Duration = 1,
                Image = "alert-circle"
            })
            return
        end
    else
        if not SelectedPlayerForTeleport then return end
        
        targetPlayer = Players:FindFirstChild(SelectedPlayerForTeleport)
        if not targetPlayer or not targetPlayer.Character then
            Rayfield:Notify({
                Title = "Teleport",
                Content = "Player not found or no character",
                Duration = 1,
                Image = "alert-circle"
            })
            return
        end
        
        targetHRP = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not targetHRP then 
            Rayfield:Notify({
                Title = "Teleport",
                Content = "Target has no HumanoidRootPart",
                Duration = 1,
                Image = "alert-circle"
            })
            return 
        end
    end
    
    if UseMaxTeleportDistance then
        local distance = (targetHRP.Position - myChar.HumanoidRootPart.Position).Magnitude
        if distance > MAX_TELEPORT_DISTANCE then
            Rayfield:Notify({
                Title = "Teleport",
                Content = "Target too far (" .. math.floor(distance) .. " studs). Max: 90 studs",
                Duration = 1,
                Image = "alert-triangle"
            })
            return
        end
    end
    
    local best = BestTeleportCFrameAround(targetHRP, myChar)
    if best then
        myChar.HumanoidRootPart.CFrame = best
    else
        Rayfield:Notify({
            Title = "Teleport",
            Content = "No valid position found near " .. targetPlayer.Name,
            Duration = 1,
            Image = "alert-triangle"
        })
    end
end

local TeleportToPlayerToggle = TeleportTab:CreateToggle({
    Name = "TP To Player",
    CurrentValue = false,
    Flag = "TeleportToPlayerToggle",
    Callback = function(Value)
        TeleportToPlayerEnabled = Value
        Rayfield:Notify({
            Title = "Teleport To Player",
            Content = Value and "Enabled" or "Disabled",
            Duration = 1,
            Image = Value and "users" or "x"
        })
    end,
})

local TeleportToPlayerKeybindInput = TeleportTab:CreateKeybind({
    Name = "TP To Player Keybind",
    CurrentKeybind = "",
    HoldToInteract = false,
    Flag = "TeleportToPlayerKeybind",
    Callback = function()
        TeleportBehindOrBestSpot()
    end,
})

local TPToAimlockedToggle = TeleportTab:CreateToggle({
    Name = "TP to Aimlocked Player",
    CurrentValue = false,
    Flag = "TPToAimlockedToggle",
    Callback = function(Value)
        TPToAimlockedEnabled = Value
        Rayfield:Notify({
            Title = "TP to Aimlocked",
            Content = Value and "Enabled - Keybind will TP to aimlocked player" or "Disabled - Keybind will use dropdown selection",
            Duration = 1,
            Image = Value and "lock" or "unlock"
        })
    end,
})

local UseMaxDistanceToggle = TeleportTab:CreateToggle({
    Name = "Use maximum teleport distance (90 studs)",
    CurrentValue = false,
    Flag = "UseMaxDistanceToggle",
    Callback = function(Value)
        UseMaxTeleportDistance = Value
        Rayfield:Notify({
            Title = "Max Teleport Distance",
            Content = Value and "Limited to 90 studs" or "No distance limit",
            Duration = 1,
            Image = Value and "ruler" or "infinity"
        })
    end,
})

PlayerDropdown = TeleportTab:CreateDropdown({
    Name = "Select Player",
    Options = GetAllPlayers(),
    CurrentOption = {},
    MultipleOptions = false,
    Flag = "PlayerDropdown",
    Callback = function(Options)
        SelectedPlayerForTeleport = Options[1]
        if SelectedPlayerForTeleport then
            Rayfield:Notify({
                Title = "Teleport",
                Content = "Selected " .. SelectedPlayerForTeleport,
                Duration = 1,
                Image = "user"
            })
        end
    end,
})

Players.PlayerAdded:Connect(function()
    task.wait(0.1)
    if PlayerDropdown then
        PlayerDropdown:Refresh(GetAllPlayers())
    end
end)

Players.PlayerRemoving:Connect(function()
    task.wait(0.1)
    if PlayerDropdown then
        PlayerDropdown:Refresh(GetAllPlayers())
    end
end)

LocalPlayer.CharacterAdded:Connect(function(character)
    isActionActive = false
    originalPosition = nil
    
    local userId = LocalPlayer.UserId
    if playerSafeZoneStatus[userId] then
        playerSafeZoneStatus[userId].justSpawned = true
        playerSafeZoneStatus[userId].isProtected = false
        playerSafeZoneStatus[userId].enterTime = nil
        playerSafeZoneStatus[userId].exitTime = nil
    end
end)