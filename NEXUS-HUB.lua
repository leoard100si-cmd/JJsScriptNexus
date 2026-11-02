
--========================================================
-- NEXUS HUB | JJS EDITION
-- Version: 1.1 | Soft Lock-On Camera
-- Single File | Private Authorized Testing
--========================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local Stats = game:GetService("Stats")
local UserInputService = game:GetService("UserInputService")

local LP = Players.LocalPlayer
local PG = LP:WaitForChild("PlayerGui")

--========================================================
-- CONFIGURATION
--========================================================

local CONFIG = {
    Smoothness = 0.18,
    Distance = 80, -- alcance máximo para manter o alvo selecionado (studs)
    Framing = 0.78, -- 0 = personagem local; 1 = alvo
    Aura = true,
    AuraStyle = "DOMINION",
    AuraIntensity = 1,
    Profile = "Balanced"
}

local GOLD = Color3.fromRGB(226,183,91)
local LIGHT_GOLD = Color3.fromRGB(255,222,145)
local DARK = Color3.fromRGB(11,12,16)
local PANEL = Color3.fromRGB(22,23,29)
local WHITE = Color3.fromRGB(240,240,240)
local MUTED = Color3.fromRGB(150,150,160)

local Target = nil
local Locked = false
local Highlight = nil
local AuraObjects = {}
local OriginalLighting = {}
local LockedCharacter = nil
local LOCK_BIND_NAME = "NEXUS_HUB_SoftLockCamera"

--========================================================
-- CLEANUP OLD HUB
--========================================================

local old = PG:FindFirstChild("NEXUS_HUB")
if old then
    old:Destroy()
end

--========================================================
-- HELPERS
--========================================================

local function Create(class, props, parent)
    local obj = Instance.new(class)

    for key, value in pairs(props) do
        obj[key] = value
    end

    obj.Parent = parent
    return obj
end

local function Corner(obj, radius)
    Create("UICorner", {
        CornerRadius = UDim.new(0, radius or 8)
    }, obj)
end

local function Stroke(obj, color, transparency)
    Create("UIStroke", {
        Color = color or GOLD,
        Transparency = transparency or 0.3,
        Thickness = 1
    }, obj)
end

local function GetRoot(player)
    if not player or not player.Character then
        return nil
    end

    return player.Character:FindFirstChild("HumanoidRootPart")
end

local function GetHumanoid(player)
    if not player or not player.Character then
        return nil
    end

    return player.Character:FindFirstChildOfClass("Humanoid")
end

local function Alive(player)
    if not player or player == LP or player.Parent ~= Players then
        return false
    end

    local character = player.Character
    local hum = GetHumanoid(player)
    local root = GetRoot(player)

    return character ~= nil
        and hum ~= nil
        and hum.Health > 0
        and root ~= nil
        and root:IsA("BasePart")
end

--========================================================
-- GUI
--========================================================

local GUI = Create("ScreenGui", {
    Name = "NEXUS_HUB",
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling
}, PG)

local Main = Create("Frame", {
    Size = UDim2.fromOffset(315, 460),
    Position = UDim2.new(0, 18, 0.2, 0),
    BackgroundColor3 = DARK,
    BorderSizePixel = 0
}, GUI)

Corner(Main, 12)
Stroke(Main, GOLD, 0.15)

local Header = Create("Frame", {
    Size = UDim2.new(1,0,0,52),
    BackgroundColor3 = PANEL,
    BorderSizePixel = 0
}, Main)

Corner(Header, 12)

Create("TextLabel", {
    Size = UDim2.new(1,-60,0,25),
    Position = UDim2.fromOffset(14,5),
    BackgroundTransparency = 1,
    Text = "N E X U S   H U B",
    TextColor3 = LIGHT_GOLD,
    TextSize = 16,
    Font = Enum.Font.GothamBold,
    TextXAlignment = Enum.TextXAlignment.Left
}, Header)

Create("TextLabel", {
    Size = UDim2.new(1,-60,0,14),
    Position = UDim2.fromOffset(15,29),
    BackgroundTransparency = 1,
    Text = "JJS EDITION | PRIVATE TEST",
    TextColor3 = MUTED,
    TextSize = 9,
    Font = Enum.Font.Gotham
}, Header)

local Minimize = Create("TextButton", {
    Size = UDim2.fromOffset(30,30),
    Position = UDim2.new(1,-40,0,10),
    BackgroundColor3 = DARK,
    Text = "—",
    TextColor3 = GOLD,
    TextSize = 17,
    Font = Enum.Font.GothamBold
}, Header)

Corner(Minimize,7)

local Body = Create("ScrollingFrame", {
    Position = UDim2.fromOffset(10,60),
    Size = UDim2.new(1,-20,1,-68),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 3,
    ScrollBarImageColor3 = GOLD,
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    CanvasSize = UDim2.new()
}, Main)

Create("UIListLayout", {
    Padding = UDim.new(0,7),
    SortOrder = Enum.SortOrder.LayoutOrder
}, Body)

Create("UIPadding", {
    PaddingBottom = UDim.new(0,8)
}, Body)

local function Section(text)
    Create("TextLabel", {
        Size = UDim2.new(1,-3,0,22),
        BackgroundTransparency = 1,
        Text = string.upper(text),
        TextColor3 = GOLD,
        TextSize = 10,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left
    }, Body)
end

local function Button(text, callback)
    local b = Create("TextButton", {
        Size = UDim2.new(1,-3,0,35),
        BackgroundColor3 = PANEL,
        Text = text,
        TextColor3 = WHITE,
        TextSize = 11,
        Font = Enum.Font.GothamSemibold
    }, Body)

    Corner(b,7)
    Stroke(b,GOLD,0.75)

    b.MouseButton1Click:Connect(callback)

    return b
end

local function Info(text)
    return Create("TextLabel", {
        Size = UDim2.new(1,-3,0,30),
        BackgroundColor3 = PANEL,
        Text = text,
        TextColor3 = MUTED,
        TextSize = 10,
        Font = Enum.Font.Gotham,
        TextWrapped = true
    }, Body)
end

local Status = Info("STATUS | Nexus inicializado")
local TargetInfo = Info("ALVO | Nenhum")

--========================================================
-- TARGET DISCOVERY
--========================================================

local function GetTargets()
    local list = {}
    local myRoot = GetRoot(LP)

    if not myRoot then
        return list
    end

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LP and Alive(player) then
            local root = GetRoot(player)

            if root then
                local distance = (root.Position-myRoot.Position).Magnitude
                if distance <= CONFIG.Distance then
                    table.insert(list, {
                        Player = player,
                        Distance = distance
                    })
                end
            end
        end
    end

    table.sort(list,function(a,b)
        return a.Distance < b.Distance
    end)

    return list
end

local function RemoveHighlight()
    if Highlight then
        Highlight:Destroy()
        Highlight = nil
    end
end

local function SetHighlight(player)
    RemoveHighlight()

    if not player or not player.Character then
        return
    end

    Highlight = Create("Highlight", {
        Adornee = player.Character,
        FillTransparency = 1,
        OutlineColor = GOLD,
        OutlineTransparency = 0,
        DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    }, workspace)
end

local function StopCameraAssist()
    pcall(function()
        RunService:UnbindFromRenderStep(LOCK_BIND_NAME)
    end)
end

local function Unlock()
    Locked = false
    Target = nil
    LockedCharacter = nil

    StopCameraAssist()
    RemoveHighlight()

    -- O NEXUS nunca altera CameraType ou CameraSubject.
    -- Ao desativar, a câmera padrão do Roblox continua intacta.
    Status.Text = "STATUS | Lock On desativado"
    TargetInfo.Text = "ALVO | Nenhum"
end

local function LockPlayer(player)
    if not player or not Alive(player) then
        return
    end

    local character = player.Character
    local myHumanoid = GetHumanoid(LP)
    local camera = workspace.CurrentCamera

    if not character or not myHumanoid or not camera then
        Status.Text = "STATUS | Personagem/câmera indisponível"
        return
    end

    Target = player
    LockedCharacter = character
    Locked = true

    SetHighlight(player)

    -- Não altera CameraType nem CameraSubject.
    -- O controlador padrão mantém a câmera no personagem local.
    -- O ajuste ocorre depois da câmera padrão, somente na orientação.
    StopCameraAssist()
    RunService:BindToRenderStep(
        LOCK_BIND_NAME,
        Enum.RenderPriority.Camera.Value + 1,
        function(dt)
            if not Locked then
                return
            end

            local currentTarget = Target
            local myRoot = GetRoot(LP)
            local targetRoot = GetRoot(currentTarget)
            local targetHumanoid = GetHumanoid(currentTarget)
            local currentCamera = workspace.CurrentCamera

            if not currentTarget
                or currentTarget.Parent ~= Players
                or currentTarget.Character ~= LockedCharacter
                or not myRoot
                or not targetRoot
                or not targetHumanoid
                or targetHumanoid.Health <= 0
                or not currentCamera
            then
                Unlock()
                return
            end

            local distance = (targetRoot.Position - myRoot.Position).Magnitude
            if distance > CONFIG.Distance then
                Unlock()
                Status.Text = "STATUS | Alvo fora do alcance"
                return
            end

            -- A posição da câmera vem da câmera padrão do Roblox.
            -- Só o ponto observado é ajustado: mistura personagem local e alvo.
            local localFocus = myRoot.Position + Vector3.new(0, 1.5, 0)
            local targetFocus = targetRoot.Position + Vector3.new(0, 1.5, 0)
            local focus = localFocus:Lerp(targetFocus, CONFIG.Framing)

            local cameraPosition = currentCamera.CFrame.Position
            local toFocus = focus - cameraPosition

            if toFocus.Magnitude > 0.05 then
                local desired = CFrame.lookAt(
                    cameraPosition,
                    focus,
                    currentCamera.CFrame.UpVector
                )

                -- Interpolação independente da taxa de quadros.
                local alpha = 1 - math.exp(
                    -CONFIG.Smoothness * 60 * math.max(dt, 0)
                )
                alpha = math.clamp(alpha, 0, 1)

                currentCamera.CFrame = currentCamera.CFrame:Lerp(
                    desired,
                    alpha
                )
            end

            TargetInfo.Text = string.format(
                "ALVO | %s | %.1f studs",
                currentTarget.DisplayName,
                distance
            )
        end
    )

    Status.Text = "STATUS | SOFT LOCK ATIVO"
    TargetInfo.Text = "ALVO | "..player.DisplayName
end

local function AutoTarget()
    local list = GetTargets()

    if #list == 0 then
        Status.Text = "STATUS | Nenhum alvo disponível"
        return
    end

    LockPlayer(list[1].Player)
end

local function CycleTarget(direction)
    local list = GetTargets()

    if #list == 0 then
        Status.Text = "STATUS | Nenhum alvo disponível"
        return
    end

    local index = 0

    for i, data in ipairs(list) do
        if data.Player == Target then
            index = i
            break
        end
    end

    if index == 0 then
        index = direction > 0 and 1 or #list
    else
        index = ((index-1+direction)%#list)+1
    end

    LockPlayer(list[index].Player)
end

--========================================================
-- LOCK ON UI
--========================================================

Section("LOCK ON SYSTEM")

Button("◎ AUTO LOCK | MAIS PRÓXIMO", AutoTarget)

Button("◀ ALVO ANTERIOR", function()
    CycleTarget(-1)
end)

Button("PRÓXIMO ALVO ▶", function()
    CycleTarget(1)
end)

Button("DESATIVAR LOCK ON", Unlock)

local SmoothButton
SmoothButton = Button("SUAVIDADE | "..CONFIG.Smoothness,function()
    local values = {0.08,0.14,0.18,0.25,0.35}
    local i = table.find(values,CONFIG.Smoothness) or 2
    i = i % #values + 1
    CONFIG.Smoothness = values[i]
    SmoothButton.Text = "SUAVIDADE | "..values[i]
    Status.Text = "STATUS | Suavidade: "..values[i]
end)

local RangeButton
RangeButton = Button("ALCANCE DO LOCK | "..CONFIG.Distance.." studs",function()
    local values = {25,40,60,80,120}
    local i = table.find(values,CONFIG.Distance) or 4
    i = i % #values + 1
    CONFIG.Distance = values[i]
    RangeButton.Text = "ALCANCE DO LOCK | "..values[i].." studs"
    Status.Text = "STATUS | Alcance: "..values[i].." studs"
end)

local FramingButton
FramingButton = Button("ENQUADRAMENTO | "..math.floor(CONFIG.Framing * 100).."%",function()
    local values = {0.55,0.65,0.78,0.90,1.0}
    local i = table.find(values,CONFIG.Framing) or 3
    i = i % #values + 1
    CONFIG.Framing = values[i]
    FramingButton.Text = "ENQUADRAMENTO | "..math.floor(values[i] * 100).."%"
    Status.Text = "STATUS | Enquadramento: "..math.floor(values[i] * 100).."%"
end)

--========================================================
-- AURA SYSTEM
--========================================================

Section("DOMINION AURA")

local function ClearAura()
    for _, obj in ipairs(AuraObjects) do
        if obj and obj.Parent then
            obj:Destroy()
        end
    end

    table.clear(AuraObjects)
end

local function CreateAura()
    ClearAura()

    local character = LP.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")

    if not root then return end

    local attachment = Create("Attachment", {
        Position = Vector3.new(0,-1.5,0)
    },root)

    table.insert(AuraObjects,attachment)

    local emitter = Create("ParticleEmitter", {
        Texture = "rbxasset://textures/particles/sparkles_main.dds",
        Color = ColorSequence.new(GOLD,LIGHT_GOLD),
        LightEmission = 0.8,
        Rate = 18 * CONFIG.AuraIntensity,
        Lifetime = NumberRange.new(0.6,1.2),
        Speed = NumberRange.new(0.5,1.3),
        SpreadAngle = Vector2.new(180,180),
        Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0,0.12),
            NumberSequenceKeypoint.new(0.5,0.22),
            NumberSequenceKeypoint.new(1,0)
        }),
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0,0.1),
            NumberSequenceKeypoint.new(1,1)
        })
    },attachment)

    table.insert(AuraObjects,emitter)

    local light = Create("PointLight", {
        Name = "NEXUS_AuraLight",
        Color = GOLD,
        Brightness = 0.6 * CONFIG.AuraIntensity,
        Range = 9
    },root)

    table.insert(AuraObjects,light)

    local ring = Create("Part", {
        Name = "NEXUS_AuraRing",
        Shape = Enum.PartType.Cylinder,
        Size = Vector3.new(0.07,5,5),
        CFrame = root.CFrame *
            CFrame.new(0,-2.5,0) *
            CFrame.Angles(0,0,math.rad(90)),
        Anchored = false,
        CanCollide = false,
        CanTouch = false,
        CanQuery = false,
        Massless = true,
        Material = Enum.Material.Neon,
        Color = GOLD,
        Transparency = 0.45
    },workspace)

    table.insert(AuraObjects,ring)

    Create("WeldConstraint", {
        Part0 = root,
        Part1 = ring
    },ring)
end

local AuraButton

AuraButton = Button("AURA | ON",function()
    CONFIG.Aura = not CONFIG.Aura

    if CONFIG.Aura then
        CreateAura()
        AuraButton.Text = "AURA | ON"
    else
        ClearAura()
        AuraButton.Text = "AURA | OFF"
    end
end)

Button("ESTILO DA AURA | "..CONFIG.AuraStyle,function()
    local styles = {"DOMINION","ARCANE","VOID"}
    local i = table.find(styles,CONFIG.AuraStyle) or 1
    i = i % #styles + 1

    CONFIG.AuraStyle = styles[i]

    if CONFIG.Aura then
        CreateAura()
    end

    Status.Text = "STATUS | Aura "..styles[i]
end)

Button("INTENSIDADE DA AURA",function()
    CONFIG.AuraIntensity =
        CONFIG.AuraIntensity >= 2 and 0.5
        or CONFIG.AuraIntensity + 0.5

    if CONFIG.Aura then
        CreateAura()
    end

    Status.Text = "STATUS | Intensidade "..CONFIG.AuraIntensity
end)

--========================================================
-- PERFORMANCE PROFILES
--========================================================

Section("PERFORMANCE")

local function ApplyProfile(profile)
    CONFIG.Profile = profile

    if profile == "Balanced" then
        for effect,original in pairs(OriginalLighting) do
            if effect == "GlobalShadows" then
                Lighting.GlobalShadows = original
            elseif effect and effect.Parent then
                effect.Enabled = original
            end
        end

        Status.Text = "STATUS | Balanced aplicado"
        return
    end

    for _,effect in ipairs(Lighting:GetChildren()) do
        if effect:IsA("PostEffect") then
            if OriginalLighting[effect] == nil then
                OriginalLighting[effect] = effect.Enabled
            end

            effect.Enabled = false
        end
    end

    if OriginalLighting.GlobalShadows == nil then
        OriginalLighting.GlobalShadows = Lighting.GlobalShadows
    end

    if profile == "Ultra Low" then
        Lighting.GlobalShadows = false
    end

    Status.Text = "STATUS | "..profile.." aplicado"
end

Button("BALANCED",function()
    ApplyProfile("Balanced")
end)

Button("PERFORMANCE",function()
    ApplyProfile("Performance")
end)

Button("ULTRA LOW",function()
    ApplyProfile("Ultra Low")
end)

--========================================================
-- FLOATING MOBILE BUTTON
--========================================================

local Floating = Create("TextButton", {
    Size = UDim2.fromOffset(55,55),
    Position = UDim2.new(1,-75,0.58,0),
    BackgroundColor3 = DARK,
    Text = "N",
    TextColor3 = LIGHT_GOLD,
    TextSize = 24,
    Font = Enum.Font.GothamBlack
},GUI)

Corner(Floating,30)
Stroke(Floating,GOLD,0)

Floating.MouseButton1Click:Connect(function()
    if Locked then
        Unlock()
    else
        AutoTarget()
    end
end)

--========================================================
-- FPS / PING MONITOR
--========================================================

local Monitor = Create("TextLabel", {
    Size = UDim2.fromOffset(170,25),
    Position = UDim2.new(1,-180,0,10),
    BackgroundColor3 = DARK,
    Text = "FPS -- | PING --",
    TextColor3 = LIGHT_GOLD,
    TextSize = 10,
    Font = Enum.Font.GothamBold
},GUI)

Corner(Monitor,7)

local frames = 0
local elapsed = 0

--========================================================
-- MINIMIZE
--========================================================

local minimized = false

Minimize.MouseButton1Click:Connect(function()
    minimized = not minimized

    Body.Visible = not minimized

    Main.Size = minimized
        and UDim2.fromOffset(315,52)
        or UDim2.fromOffset(315,460)

    Minimize.Text = minimized and "+" or "—"
end)

--========================================================
-- DRAG WINDOW
--========================================================

local dragging = false
local dragStart
local startPosition

Header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then

        dragging = true
        dragStart = input.Position
        startPosition = Main.Position
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and (
        input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch
    ) then

        local delta = input.Position-dragStart

        Main.Position = UDim2.new(
            startPosition.X.Scale,
            startPosition.X.Offset+delta.X,
            startPosition.Y.Scale,
            startPosition.Y.Offset+delta.Y
        )
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

--========================================================
-- MAIN LOOP
--========================================================

local renderConnection

renderConnection = RunService.RenderStepped:Connect(function(dt)
    frames += 1
    elapsed += dt

    if elapsed >= 1 then
        local fps = math.floor(frames/elapsed)
        frames = 0
        elapsed = 0

        local ping = "--"

        pcall(function()
            ping = Stats.Network.ServerStatsItem[
                "Data Ping"
            ]:GetValueString()
        end)

        Monitor.Text = "FPS "..fps.." | PING "..ping
    end

    -- O Soft Lock roda em BindToRenderStep, após a câmera padrão.
    -- Este loop fica responsável somente pelo monitor de desempenho.
end)

--========================================================
-- CHARACTER RESPAWN
--========================================================

LP.CharacterAdded:Connect(function()
    if Locked then
        Unlock()
    end

    task.wait(1)

    if CONFIG.Aura then
        CreateAura()
    end
end)

LP.CharacterRemoving:Connect(function()
    if Locked then
        Unlock()
    end
end)

Players.PlayerRemoving:Connect(function(player)
    if player == Target then
        Unlock()
        Status.Text = "STATUS | Alvo saiu do servidor"
    end
end)

--========================================================
-- INITIALIZE
--========================================================

if CONFIG.Aura then
    task.delay(1,CreateAura)
end

print("NEXUS HUB | JJS EDITION v1.1 SOFT LOCK LOADED")
