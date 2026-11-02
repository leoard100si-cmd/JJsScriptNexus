
--========================================================
-- NEXUS HUB | JJS EDITION
-- Version: 4.0 | GOD LOCK ABSOLUTE
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
    Smoothness = 8.0,          -- resposta angular (maior = mais rápido)
    TargetRange = 120,         -- alcance para adquirir/manter alvo (studs)
    TargetBias = 0.62,         -- peso visual do alvo no enquadramento
    CameraFOV = 70,             -- campo de visão durante o GOD ON
    MaxTurnSpeed = 210,        -- limite de rotação em graus por segundo
    ManualOrbitHold = 0.85,    -- pausa o assist após movimento manual da câmera
    ManualTurnThreshold = 2.0, -- graus de movimento para detectar órbita manual
    OutOfRangeGrace = 1.25,    -- tolerância antes de perder alvo fora do alcance
    AimRadius = 0.62,          -- raio normalizado para seleção pela mira
    BodyTracking = true,       -- mantém a orientação visual do corpo voltada ao alvo
    BodyResponsiveness = 24,   -- resposta da rotação do corpo
    Prediction = 0.10,         -- antecipação visual limitada do movimento do alvo
    AdaptiveFOV = true,        -- FOV se adapta à distância
    AutoReacquire = false,     -- opcional: procura outro alvo se o atual ficar inválido
    Profile = "DOMINION",
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
local LastTarget = nil
local Locked = false
local Highlight = nil
local AuraObjects = {}
local OriginalLighting = {}
local LockedCharacter = nil
local LOCK_BIND_NAME = "NEXUS_HUB_GodOnCamera"
local LastBaseCFrame = nil
local ManualOrbitUntil = 0
local OutOfRangeSince = nil
local OriginalCameraFOV = nil
local CurrentAdaptiveFOV = nil
local LastTargetVelocity = Vector3.zero
local AwarenessText = "AGUARDANDO ALVO"
local BodyAligner = nil
local BodyAttachment = nil
local BodyHumanoid = nil
local BodyCharacter = nil
local OriginalAutoRotate = nil

--========================================================
-- CLEANUP OLD HUB
--========================================================

-- Remove vínculos de câmera conhecidos de versões anteriores.
pcall(function()
    RunService:UnbindFromRenderStep("NEXUS_HUB_SoftLockCamera")
end)
pcall(function()
    RunService:UnbindFromRenderStep(LOCK_BIND_NAME)
end)

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
    Text = "JJS EDITION | GOD LOCK 4.0",
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
TargetInfo.Size = UDim2.new(1,-3,0,44)

--========================================================
-- TARGET DISCOVERY + GOD ON CAMERA
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
                local distance = (root.Position - myRoot.Position).Magnitude
                if distance <= CONFIG.TargetRange then
                    table.insert(list, {
                        Player = player,
                        Distance = distance
                    })
                end
            end
        end
    end

    table.sort(list, function(a, b)
        return a.Distance < b.Distance
    end)

    return list
end

local function GetAimTarget()
    local camera = workspace.CurrentCamera
    local myRoot = GetRoot(LP)
    if not camera or not myRoot then
        return nil
    end

    local viewport = camera.ViewportSize
    local center = Vector2.new(viewport.X * 0.5, viewport.Y * 0.5)
    local maxRadius = math.min(viewport.X, viewport.Y) * CONFIG.AimRadius
    local bestPlayer, bestScore = nil, math.huge

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LP and Alive(player) then
            local root = GetRoot(player)
            if root then
                local distance = (root.Position - myRoot.Position).Magnitude
                if distance <= CONFIG.TargetRange then
                    local screenPoint, onScreen = camera:WorldToViewportPoint(
                        root.Position + Vector3.new(0, 1.5, 0)
                    )
                    if onScreen and screenPoint.Z > 0 then
                        local screenDistance = (
                            Vector2.new(screenPoint.X, screenPoint.Y) - center
                        ).Magnitude
                        if screenDistance <= maxRadius then
                            -- A posição na mira pesa mais que a distância física.
                            local score = screenDistance + distance * 0.12
                            if score < bestScore then
                                bestScore = score
                                bestPlayer = player
                            end
                        end
                    end
                end
            end
        end
    end

    return bestPlayer
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
        OutlineColor = LIGHT_GOLD,
        OutlineTransparency = 0.05,
        DepthMode = Enum.HighlightDepthMode.Occluded
    }, workspace)
end

local function StopCameraAssist()
    pcall(function()
        RunService:UnbindFromRenderStep(LOCK_BIND_NAME)
    end)
    LastBaseCFrame = nil
end

-- Orienta o corpo no eixo horizontal sem alterar a posição do personagem.
-- AlignOrientation aplica apenas torque de rotação; não move o HumanoidRootPart.
local function StopBodyAssist()
    if BodyAligner then
        BodyAligner:Destroy()
        BodyAligner = nil
    end

    if BodyAttachment then
        BodyAttachment:Destroy()
        BodyAttachment = nil
    end

    if BodyHumanoid and BodyHumanoid.Parent and OriginalAutoRotate ~= nil then
        BodyHumanoid.AutoRotate = OriginalAutoRotate
    end

    BodyHumanoid = nil
    BodyCharacter = nil
    OriginalAutoRotate = nil
end

local function StartBodyAssist(character, humanoid, root)
    if not CONFIG.BodyTracking or not character or not humanoid or not root then
        return
    end

    if BodyCharacter == character and BodyAligner and BodyAligner.Parent == root then
        return
    end

    StopBodyAssist()

    BodyHumanoid = humanoid
    BodyCharacter = character
    OriginalAutoRotate = humanoid.AutoRotate
    humanoid.AutoRotate = false

    BodyAttachment = Instance.new("Attachment")
    BodyAttachment.Name = "NEXUS_GodLock_BodyAttachment"
    BodyAttachment.Parent = root

    BodyAligner = Instance.new("AlignOrientation")
    BodyAligner.Name = "NEXUS_GodLock_BodyAligner"
    BodyAligner.Mode = Enum.OrientationAlignmentMode.OneAttachment
    BodyAligner.Attachment0 = BodyAttachment
    BodyAligner.Responsiveness = CONFIG.BodyResponsiveness
    BodyAligner.MaxTorque = 1000000
    BodyAligner.MaxAngularVelocity = math.rad(360)
    BodyAligner.RigidityEnabled = false
    BodyAligner.ReactionTorqueEnabled = false
    BodyAligner.Parent = root
end

local function Unlock(message)
    Locked = false
    if Target then LastTarget = Target end
    Target = nil
    LockedCharacter = nil
    ManualOrbitUntil = 0
    OutOfRangeSince = nil

    StopCameraAssist()
    StopBodyAssist()
    RemoveHighlight()

    local camera = workspace.CurrentCamera
    if camera and OriginalCameraFOV then
        camera.FieldOfView = OriginalCameraFOV
    end
    OriginalCameraFOV = nil
    CurrentAdaptiveFOV = nil

    Status.Text = "STATUS | " .. (message or "GOD ON desativado")
    TargetInfo.Text = "ALVO | Nenhum"
end

local function LockPlayer(player)
    if not player or not Alive(player) then
        Status.Text = "STATUS | Alvo inválido"
        return
    end

    local character = player.Character
    local myRoot = GetRoot(LP)
    local myHumanoid = GetHumanoid(LP)
    local camera = workspace.CurrentCamera

    if not character or not myRoot or not myHumanoid or myHumanoid.Health <= 0 or not camera then
        Status.Text = "STATUS | Personagem/câmera indisponível"
        return
    end

    if not Locked then
        OriginalCameraFOV = camera.FieldOfView
    end

    StopCameraAssist()
    Target = player
    LockedCharacter = character
    Locked = true
    ManualOrbitUntil = 0
    OutOfRangeSince = nil
    SetHighlight(player)
    camera.FieldOfView = CONFIG.CameraFOV
    StartBodyAssist(LP.Character, myHumanoid, myRoot)

    -- A câmera padrão continua calculando posição, zoom e controles.
    -- O GOD ON altera apenas a orientação, após a atualização padrão.
    RunService:BindToRenderStep(
        LOCK_BIND_NAME,
        Enum.RenderPriority.Camera.Value + 1,
        function(dt)
            if not Locked then
                return
            end

            local currentTarget = Target
            local localCharacter = LP.Character
            local myHumanoid = localCharacter and localCharacter:FindFirstChildOfClass("Humanoid")
            local myRootNow = GetRoot(LP)
            local myCharacterIsValid = localCharacter ~= nil
                and myHumanoid ~= nil
                and myHumanoid.Health > 0
            local targetRoot = GetRoot(currentTarget)
            local targetHumanoid = GetHumanoid(currentTarget)
            local currentCamera = workspace.CurrentCamera

            local targetInvalid = not currentTarget
                or currentTarget.Parent ~= Players
                or currentTarget.Character ~= LockedCharacter
                or not targetRoot
                or not targetHumanoid
                or targetHumanoid.Health <= 0

            if targetInvalid and CONFIG.AutoReacquire and myCharacterIsValid and myRootNow then
                local alternatives = GetTargets()
                if #alternatives > 0 then
                    LockPlayer(alternatives[1].Player)
                    return
                end
            end

            if targetInvalid or not myCharacterIsValid or not myRootNow or not currentCamera then
                Unlock("Alvo/personagem inválido")
                return
            end

            local distance = (targetRoot.Position - myRootNow.Position).Magnitude
            if distance > CONFIG.TargetRange then
                OutOfRangeSince = OutOfRangeSince or os.clock()
                if os.clock() - OutOfRangeSince >= CONFIG.OutOfRangeGrace then
                    Unlock("Alvo fora do alcance")
                    return
                end
            else
                OutOfRangeSince = nil
            end

            -- GOD LOCK: corpo voltado ao alvo, sem alterar a posição do jogador.
            if CONFIG.BodyTracking then
                StartBodyAssist(localCharacter, myHumanoid, myRootNow)
                if BodyAligner and BodyAligner.Parent == myRootNow then
                    local bodyDirection = targetRoot.Position - myRootNow.Position
                    bodyDirection = Vector3.new(bodyDirection.X, 0, bodyDirection.Z)
                    if bodyDirection.Magnitude > 0.05 then
                        BodyAligner.CFrame = CFrame.lookAt(
                            Vector3.zero,
                            bodyDirection.Unit,
                            Vector3.yAxis
                        )
                        BodyAligner.Responsiveness = CONFIG.BodyResponsiveness
                    end
                end
            else
                StopBodyAssist()
            end

            local baseCFrame = currentCamera.CFrame
            local now = os.clock()

            -- Detecta rotação produzida pelo controlador padrão (mouse/toque).
            -- Durante a órbita manual, não disputa o controle com o jogador.
            if LastBaseCFrame then
                local turn = LastBaseCFrame.LookVector:Angle(baseCFrame.LookVector)
                if turn >= math.rad(CONFIG.ManualTurnThreshold) then
                    ManualOrbitUntil = now + CONFIG.ManualOrbitHold
                end
            end
            LastBaseCFrame = baseCFrame

            -- Predição apenas visual: usa velocidade observada, limitada para evitar saltos.
            local velocity = targetRoot.AssemblyLinearVelocity
            local predictionTime = math.clamp(CONFIG.Prediction, 0, 0.25)
            local lead = velocity * predictionTime
            if lead.Magnitude > 8 then
                lead = lead.Unit * 8
            end
            local localFocus = myRootNow.Position + Vector3.new(0, 1.45, 0)
            local targetFocus = targetRoot.Position + lead + Vector3.new(0, 1.45, 0)
            local focus = localFocus:Lerp(targetFocus, CONFIG.TargetBias)

            -- FOV adaptativo: aproximação em curta distância, mais espaço em longa distância.
            if CONFIG.AdaptiveFOV and OriginalCameraFOV then
                local desiredFOV = math.clamp(62 + (distance / math.max(CONFIG.TargetRange, 1)) * 20, 62, 84)
                CurrentAdaptiveFOV = CurrentAdaptiveFOV
                    and CurrentAdaptiveFOV + (desiredFOV - CurrentAdaptiveFOV) * math.clamp(dt * 3, 0, 1)
                    or desiredFOV
                currentCamera.FieldOfView = CurrentAdaptiveFOV
            else
                currentCamera.FieldOfView = CONFIG.CameraFOV
            end

            if now >= ManualOrbitUntil then
                local toFocus = focus - baseCFrame.Position
                if toFocus.Magnitude > 0.05 then
                    local desired = CFrame.lookAt(baseCFrame.Position, focus, Vector3.yAxis)
                    local angle = baseCFrame.LookVector:Angle(desired.LookVector)
                    local alpha = 1 - math.exp(-CONFIG.Smoothness * math.max(dt, 0))
                    local maxStep = math.rad(CONFIG.MaxTurnSpeed) * math.max(dt, 0)
                    if angle > 0.0001 then alpha = math.min(alpha, maxStep / angle) end
                    alpha = math.clamp(alpha, 0, 1)
                    currentCamera.CFrame = baseCFrame:Lerp(desired, alpha)
                end
            end

            local screenPoint, onScreen = currentCamera:WorldToViewportPoint(targetRoot.Position)
            local speed = velocity.Magnitude
            local movement = speed > 2 and "EM MOVIMENTO" or "ESTÁVEL"
            local visibility = onScreen and screenPoint.Z > 0 and "NO ENQUADRAMENTO" or "FORA DA TELA"
            local orbitState = now < ManualOrbitUntil and " | ÓRBITA MANUAL" or ""
            AwarenessText = string.format("%s | %.1f studs/s | %s", visibility, speed, movement)
            TargetInfo.Text = string.format("ALVO | %s | %.1f studs\n%s%s", currentTarget.DisplayName, distance, AwarenessText, orbitState)
        end
    )

    Status.Text = "STATUS | GOD ON ATIVO"
    TargetInfo.Text = "ALVO | " .. player.DisplayName
end

local function AutoTarget()
    local list = GetTargets()
    if #list == 0 then
        Status.Text = "STATUS | Nenhum alvo próximo"
        return
    end
    LockPlayer(list[1].Player)
end

local function AimTarget()
    local player = GetAimTarget()
    if player then
        LockPlayer(player)
    else
        Status.Text = "STATUS | Nenhum alvo próximo da mira"
    end
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
        index = ((index - 1 + direction) % #list) + 1
    end

    LockPlayer(list[index].Player)
end

--========================================================
-- GOD ON UI
--========================================================

Section("GOD ON | COMBAT CAMERA")
Button("◎ GOD ON | ALVO MAIS PRÓXIMO", AutoTarget)
Button("⌖ SELECIONAR ALVO NA MIRA", AimTarget)
Button("◎ PRIORIZAR ALVO MAIS PRÓXIMO", AutoTarget)
Button("◀ ALVO ANTERIOR", function()
    CycleTarget(-1)
end)
Button("PRÓXIMO ALVO ▶", function()
    CycleTarget(1)
end)
Button("↺ RECONECTAR ÚLTIMO ALVO", function()
    if LastTarget and Alive(LastTarget) then
        LockPlayer(LastTarget)
    else
        Status.Text = "STATUS | Último alvo indisponível"
    end
end)
Button("DESATIVAR GOD ON", function()
    Unlock()
end)

local BodyButton
BodyButton = Button("ORIENTAÇÃO DO CORPO | ON", function()
    CONFIG.BodyTracking = not CONFIG.BodyTracking
    BodyButton.Text = CONFIG.BodyTracking
        and "ORIENTAÇÃO DO CORPO | ON"
        or "ORIENTAÇÃO DO CORPO | OFF"

    if not CONFIG.BodyTracking then
        StopBodyAssist()
    elseif Locked then
        StartBodyAssist(LP.Character, GetHumanoid(LP), GetRoot(LP))
    end

    Status.Text = CONFIG.BodyTracking
        and "STATUS | Corpo acompanhando o alvo"
        or "STATUS | Orientação automática do corpo desligada"
end)

Section("GOD LOCK PROFILES")

local ProfileButton
local function ApplyCombatProfile(profile)
    local presets = {
        DOMINION = {Smoothness=8, MaxTurnSpeed=210, TargetBias=0.62, Prediction=0.10, BodyResponsiveness=24, CameraFOV=70},
        PREDATOR = {Smoothness=13, MaxTurnSpeed=300, TargetBias=0.72, Prediction=0.18, BodyResponsiveness=32, CameraFOV=78},
        ABSOLUTE = {Smoothness=6, MaxTurnSpeed=150, TargetBias=0.55, Prediction=0.08, BodyResponsiveness=18, CameraFOV=85}
    }
    local preset = presets[profile]
    if not preset then return end
    CONFIG.Profile = profile
    for key, value in pairs(preset) do CONFIG[key] = value end
    if Locked and workspace.CurrentCamera then
        workspace.CurrentCamera.FieldOfView = CONFIG.CameraFOV
        CurrentAdaptiveFOV = CONFIG.CameraFOV
    end
    ProfileButton.Text = "PERFIL | " .. profile
    Status.Text = "STATUS | Perfil " .. profile .. " aplicado"
end

ProfileButton = Button("PERFIL | DOMINION", function()
    local profiles = {"DOMINION", "PREDATOR", "ABSOLUTE"}
    local index = table.find(profiles, CONFIG.Profile) or 1
    ApplyCombatProfile(profiles[index % #profiles + 1])
end)

Button("PREDIÇÃO VISUAL | " .. math.floor(CONFIG.Prediction * 1000) .. " ms", function()
    local values = {0, 0.06, 0.10, 0.16, 0.22}
    local index = 1
    for i, value in ipairs(values) do if value == CONFIG.Prediction then index = i break end end
    CONFIG.Prediction = values[index % #values + 1]
    Status.Text = "STATUS | Predição visual " .. math.floor(CONFIG.Prediction * 1000) .. " ms"
end)

local AdaptiveButton
AdaptiveButton = Button("FOV ADAPTATIVO | ON", function()
    CONFIG.AdaptiveFOV = not CONFIG.AdaptiveFOV
    AdaptiveButton.Text = CONFIG.AdaptiveFOV and "FOV ADAPTATIVO | ON" or "FOV ADAPTATIVO | OFF"
    if not CONFIG.AdaptiveFOV and Locked and workspace.CurrentCamera then
        workspace.CurrentCamera.FieldOfView = CONFIG.CameraFOV
    end
    Status.Text = "STATUS | FOV adaptativo " .. (CONFIG.AdaptiveFOV and "ativo" or "desativado")
end)

local ReacquireButton
ReacquireButton = Button("AUTO-REACQUIRE | OFF", function()
    CONFIG.AutoReacquire = not CONFIG.AutoReacquire
    ReacquireButton.Text = CONFIG.AutoReacquire and "AUTO-REACQUIRE | ON" or "AUTO-REACQUIRE | OFF"
    Status.Text = CONFIG.AutoReacquire and "STATUS | Busca novo alvo se o atual cair" or "STATUS | Troca automática desativada"
end)

Button("ORIENTAÇÃO DO CORPO | VELOCIDADE", function()
    local values = {12, 18, 24, 32, 40}
    local index = 1
    for i, value in ipairs(values) do if value == CONFIG.BodyResponsiveness then index = i break end end
    CONFIG.BodyResponsiveness = values[index % #values + 1]
    if BodyAligner then BodyAligner.Responsiveness = CONFIG.BodyResponsiveness end
    Status.Text = "STATUS | Rotação corporal " .. CONFIG.BodyResponsiveness
end)

local SmoothButton
SmoothButton = Button("RESPOSTA | " .. CONFIG.Smoothness, function()
    local values = {4, 6, 8, 11, 15}
    local i = table.find(values, CONFIG.Smoothness) or 3
    i = i % #values + 1
    CONFIG.Smoothness = values[i]
    SmoothButton.Text = "RESPOSTA | " .. values[i]
    Status.Text = "STATUS | Resposta: " .. values[i]
end)

local RangeButton
RangeButton = Button("ALCANCE | " .. CONFIG.TargetRange .. " studs", function()
    local values = {30, 50, 80, 120, 160}
    local i = table.find(values, CONFIG.TargetRange) or 4
    i = i % #values + 1
    CONFIG.TargetRange = values[i]
    RangeButton.Text = "ALCANCE | " .. values[i] .. " studs"
    Status.Text = "STATUS | Alcance: " .. values[i] .. " studs"
end)

local FramingButton
FramingButton = Button("PESO DO ALVO | " .. math.floor(CONFIG.TargetBias * 100) .. "%", function()
    local values = {0.45, 0.55, 0.62, 0.72, 0.82}
    local i = table.find(values, CONFIG.TargetBias) or 3
    i = i % #values + 1
    CONFIG.TargetBias = values[i]
    FramingButton.Text = "PESO DO ALVO | " .. math.floor(values[i] * 100) .. "%"
    Status.Text = "STATUS | Peso visual: " .. math.floor(values[i] * 100) .. "%"
end)

local FOVButton
FOVButton = Button("CAMPO DE VISÃO | " .. CONFIG.CameraFOV .. "°", function()
    local values = {60, 65, 70, 75, 80, 90}
    local i = table.find(values, CONFIG.CameraFOV) or 3
    i = i % #values + 1
    CONFIG.CameraFOV = values[i]
    FOVButton.Text = "CAMPO DE VISÃO | " .. values[i] .. "°"

    if Locked and workspace.CurrentCamera then
        workspace.CurrentCamera.FieldOfView = CONFIG.CameraFOV
    end

    Status.Text = "STATUS | Campo de visão: " .. values[i] .. "°"
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
local dragInput = nil
local dragStart
local startPosition

Header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then

        dragging = true
        dragInput = input
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
    if input == dragInput
    or input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
        dragInput = nil
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

    -- O GOD ON roda em BindToRenderStep, após a câmera padrão.
    -- Este loop fica responsável somente pelo monitor de desempenho.
end)

--========================================================
-- CHARACTER RESPAWN
--========================================================

LP.CharacterAdded:Connect(function()
    if Locked then
        Unlock("Seu personagem renasceu")
    end

    task.wait(1)

    if CONFIG.Aura then
        CreateAura()
    end
end)

LP.CharacterRemoving:Connect(function()
    if Locked then
        Unlock("Personagem local removido")
    end
end)

Players.PlayerRemoving:Connect(function(player)
    if player == Target then
        Unlock("Alvo saiu do servidor")
    end
end)

--========================================================
-- INITIALIZE
--========================================================

if CONFIG.Aura then
    task.delay(1,CreateAura)
end

print("NEXUS HUB | JJS EDITION v4.0 GOD LOCK ABSOLUTE LOADED")
