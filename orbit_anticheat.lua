--[[ ═══════════════════════════════════════════════════════════════
     ОРБИТА АНТИ-ЧИТ v12.0 — ПОЛНАЯ ВЕРСИЯ НА РУССКОМ
     ═══════════════════════════════════════════════════════════════
     ✅ Все переменные латиницей (Lua-совместимо)
     ✅ Интерфейс, уведомления, комментарии — на русском
     ✅ НЕ зависит от ОРБИТЫ
     
     🆕 Что нового в v12.0:
     - Anti-Homelander (детект огромных BodyVelocity/LinearVelocity)
     - Anti-Grab (снятие чужих Weld/Motor6D)
     - Anti-Ragdoll (выход из Physics/Ragdoll)
     - Anti-Killaura (резкие удары по мне без ответа)
     - Исправлен баг с текстом уведомлений
     - Все кириллические идентификаторы → латиница
     
     Запуск:
     loadstring(game:HttpGet("https://raw.githubusercontent.com/y7hdyvdmr/orbit_anticheat.lua/refs/heads/main/orbit_anticheat.lua?t=" .. os.time()))()
     ═══════════════════════════════════════════════════════════════ ]]

-- ==================== ЗАЩИТА ОТ ПОВТОРНОГО ЗАПУСКА ====================
local GENV = rawget(_G, "getgenv") and getgenv() or _G
if GENV._ORBIT_AC_LOADED then
    warn("[Orbit AC] Уже запущен! Выгружаю старый...")
    pcall(function() GENV._ORBIT_AC_UNLOAD() end)
end
GENV._ORBIT_AC_LOADED = true

-- ==================== СЕРВИСЫ ====================
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local Workspace        = game:GetService("Workspace")
local SoundService     = game:GetService("SoundService")
local TweenService     = game:GetService("TweenService")
local HttpService      = game:GetService("HttpService")
local ContentProvider  = game:GetService("ContentProvider")
local Debris           = game:GetService("Debris")
local UIS              = game:GetService("UserInputService")
local LocalPlayer      = Players.LocalPlayer
local PlayerGui        = LocalPlayer:WaitForChild("PlayerGui")

-- ==================== БЕЗОПАСНОЕ РОДИТЕЛЬСКОЕ ОКНО ====================
local function getSafeParent()
    local gethuiFn = rawget(GENV, "gethui")
    if type(gethuiFn) == "function" then
        local ok, hui = pcall(gethuiFn)
        if ok and hui then return hui end
    end
    local ok, cg = pcall(function() return game:GetService("CoreGui") end)
    if ok and cg then return cg end
    return PlayerGui
end

local function protectGui(gui)
    if not gui then return end
    local synTbl = rawget(GENV, "syn")
    if type(synTbl) == "table" and type(synTbl.protect_gui) == "function" then
        pcall(synTbl.protect_gui, gui); return
    end
    local protectFn = rawget(GENV, "protect_gui")
    if type(protectFn) == "function" then
        pcall(protectFn, gui); return
    end
end

-- ==================== НАСТРОЙКИ ====================
local SETTINGS = {
    Enabled            = false,
    Sounds             = true,

    -- Защита
    AntiFling          = true,
    AntiVoid           = true,
    AntiTeleport       = true,
    AntiKnockback      = true,
    AntiFreeze         = true,
    AntiAnchor         = true,
    AntiInstantKill    = true,
    AntiDropKick       = true,
    AntiExplosion      = true,
    AntiSuperRing      = true,
    AntiHomelander     = true,   -- 🆕
    AntiGrab           = true,   -- 🆕
    AntiRagdoll        = true,   -- 🆕
    AntiKillaura       = true,   -- 🆕
    NoFallDamage       = true,

    -- Утилиты
    AutoHeal           = false,
    HealPower          = 100,
    LockPosition       = false,

    -- Визуал
    VisualSphere       = false,
    SphereSize         = 8,
    IntrusionDetect    = true,

    -- Уклонение
    Dodge              = false,
    TrollDetect        = true,

    -- Ответный флинг
    ReverseFling       = false,

    -- Детект
    DetectSpeed        = true,
    DetectGodMode      = true,

    -- Умный пол
    SmartFloorDelay    = 5,

    -- UI
    ButtonPosition     = UDim2.new(0, 20, 0, 200),
}

-- ==================== СТАТИСТИКА СЕССИИ ====================
local SESSION = {
    defenses           = 0,
    dodges             = 0,
    cheatersMarked     = 0,
    intrusions         = 0,
    startTime          = tick(),
}

local MARKED = {}
local CHEATER_LOG = {}

-- ==================== ЗВУКИ ====================
local soundFolder = Instance.new("Folder")
soundFolder.Name = "OrbitAC_Sfx_" .. tostring(math.random(100000, 999999))
soundFolder.Parent = SoundService

local SOUND_IDS = {
    click        = "rbxasset://sounds/button.wav",
    switch       = "rbxasset://sounds/switch.wav",
    signal       = "rbxasset://sounds/electronicpingshort.wav",
    snap         = "rbxasset://sounds/snap.mp3",
    dodge        = "rbxassetid://140721035016341",
    afterDodge   = "rbxassetid://6325779988",
    sans         = "rbxassetid://135692693675195",
    laugh        = "rbxassetid://113650760423588",
    bot          = "rbxassetid://12221967",
    intrusion    = "rbxassetid://12221967",
}

local soundTemplates = {}
for name, id in pairs(SOUND_IDS) do
    local s = Instance.new("Sound")
    s.Name    = name
    s.SoundId = id
    s.Volume  = 0.5
    s.Parent  = soundFolder
    soundTemplates[name] = s
end

task.spawn(function()
    pcall(function()
        ContentProvider:PreloadAsync(soundFolder:GetChildren())
    end)
end)

-- ==================== ОЧЕРЕДЬ ЗВУКОВ (без наложения) ====================
local SOUND_QUEUE = {
    Playing = false,
    List    = {},
}

local function playSound(name, volume, pitch)
    if not SETTINGS.Sounds then return end
    local template = soundTemplates[name]
    if not template then return end

    table.insert(SOUND_QUEUE.List, {
        name   = name,
        volume = volume or 1,
        pitch  = pitch or 1,
    })

    if not SOUND_QUEUE.Playing then
        task.spawn(function()
            SOUND_QUEUE.Playing = true
            while #SOUND_QUEUE.List > 0 do
                local item = table.remove(SOUND_QUEUE.List, 1)
                local t = soundTemplates[item.name]
                if t then
                    pcall(function()
                        local s = t:Clone()
                        s.Volume        = (item.volume or 1) * t.Volume
                        s.PlaybackSpeed = item.pitch or 1
                        s.Parent        = soundFolder
                        s:Play()
                        Debris:AddItem(s, 8)
                        local dur = math.min(s.TimeLength > 0 and s.TimeLength or 0.5, 3)
                        task.wait(dur)
                    end)
                end
            end
            SOUND_QUEUE.Playing = false
        end)
    end
end

local function sfxClick()       playSound("click", 0.5) end
local function sfxSwitch()      playSound("switch", 0.5) end
local function sfxSignal()      playSound("signal", 0.5) end

-- Полная последовательность уворота: уворот → после → Санс → смех
local function sfxDodgeSans()
    if not SETTINGS.Sounds then return end
    playSound("dodge", 1, 1)
    playSound("afterDodge", 1, 1)
    playSound("sans", 1, 1)
    playSound("laugh", 0.8, 1)

    pcall(function()
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum:PlayEmote("Laugh")
            task.delay(2, function()
                pcall(function()
                    local animator = hum:FindFirstChildOfClass("Animator")
                    if animator then
                        for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                            local nm = track.Animation and track.Animation.Name or ""
                            if nm:lower():find("laugh") or nm:lower():find("emote") then
                                track:Stop(0)
                            end
                        end
                    end
                end)
            end)
        end
    end)
end

local function sfxSmartFloor()
    if not SETTINGS.Sounds then return end
    sfxDodgeSans()
end

local function sfxIntrusion()
    if not SETTINGS.Sounds then return end
    playSound("intrusion", 0.7, 1.5)
end

local function sfxMarkCheater()
    if not SETTINGS.Sounds then return end
    playSound("signal", 0.4, 0.8)
end

-- ==================== ВИЗУАЛЬНАЯ СФЕРА ====================
local sphereModel = nil
local spherePart  = nil

local function createSphere()
    if sphereModel then sphereModel:Destroy() end
    sphereModel = Instance.new("Model")
    sphereModel.Name = "OrbitAC_Сфера"
    sphereModel.Parent = Workspace

    spherePart = Instance.new("Part")
    spherePart.Name         = "Сфера"
    spherePart.Shape        = Enum.PartType.Ball
    spherePart.Size         = Vector3.new(SETTINGS.SphereSize, SETTINGS.SphereSize, SETTINGS.SphereSize)
    spherePart.Material     = Enum.Material.ForceField
    spherePart.Color        = Color3.fromRGB(0, 150, 255)
    spherePart.Transparency = 0.5
    spherePart.Anchored     = true
    spherePart.CanCollide   = false
    spherePart.CastShadow   = false
    spherePart.CanQuery     = false
    spherePart.CanTouch     = false
    spherePart.Parent       = sphereModel
end

local function updateSphere()
    if not SETTINGS.VisualSphere then
        if sphereModel then sphereModel:Destroy(); sphereModel = nil; spherePart = nil end
        return
    end
    if not spherePart or not spherePart.Parent then
        createSphere()
    end
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hrp and spherePart then
        spherePart.CFrame = hrp.CFrame
    end
end

-- ==================== ДЕТЕКТ ВТОРЖЕНИЯ ====================
local INTRUSION_TRACK = {
    LastCheck = 0,
    Cooldown  = {},
    WasInside = {},
}

local function checkIntrusion()
    if not SETTINGS.Enabled or not SETTINGS.IntrusionDetect then return end
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local now = tick()
    local radius = SETTINGS.SphereSize / 2

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end
        local other = plr.Character
        if not other then continue end
        local otherHrp = other:FindFirstChild("HumanoidRootPart")
        if not otherHrp then continue end

        local dist = (otherHrp.Position - hrp.Position).Magnitude
        local inside = dist <= radius

        if inside and not INTRUSION_TRACK.WasInside[plr] then
            INTRUSION_TRACK.WasInside[plr] = true
            SESSION.intrusions = SESSION.intrusions + 1

            if not INTRUSION_TRACK.Cooldown[plr] or now - INTRUSION_TRACK.Cooldown[plr] > 5 then
                INTRUSION_TRACK.Cooldown[plr] = now
                sfxIntrusion()
                notify("⚠️ Вторжение: " .. plr.Name, Color3.fromRGB(255, 150, 150), 2)
                print("[OrbitAC] 🚨 Вторжение: " .. plr.Name .. " (дист: " .. math.floor(dist) .. ")")

                if SETTINGS.Dodge and INTRUSION_TRACK.Cooldown[plr] then
                    local away = (hrp.Position - otherHrp.Position).Unit
                    local target = hrp.Position + away * 12
                    pcall(function()
                        char:PivotTo(CFrame.new(target))
                        hrp.AssemblyLinearVelocity  = Vector3.zero
                        hrp.AssemblyAngularVelocity = Vector3.zero
                    end)
                end
            end
        elseif not inside and INTRUSION_TRACK.WasInside[plr] then
            INTRUSION_TRACK.WasInside[plr] = nil
        end
    end
end

-- ==================== СОСТОЯНИЕ ====================
local STATE = {
    lastSafePosition     = nil,
    lastSafeCFrame       = nil,
    lastCheckTime        = 0,
    lastHealTime         = 0,
    lastHealth           = 100,
    lastKnockbackTime    = 0,
    lastFreezeTime       = 0,
    spawnGrace           = 0,
    lastHealthCheck      = 0,
    lastScan             = 0,
    lastPositions        = {},
    godModeWarning       = {},
    voidTimer            = 0,
    lastFloorCheck       = 0,
    lastHrp              = nil,
    dropKickWarning      = {},
    jumpCounter          = 0,
    blockedFlings        = 0,
    groundTime           = 0,
    charConnection       = nil,
    lastSmartFloor       = 0,
}

local CONFIG = {
    MAX_SPEED              = 60,
    MAX_JUMP               = 100,
    FLING_SPEED_THRESHOLD  = 200,
    FLING_ROT_THRESHOLD    = 100,
    INSTANT_FLING          = 100000,
    TELEPORT_DISTANCE      = 30,
    VOID_TIMER             = 0.5,
    FAST_FALL_VY           = -50,
    FLOOR_RAY_LENGTH       = 500,
    FLOOR_RAY_SIDE         = 100,
    MIN_GROUND_TIME        = 1.0,
    SMART_FLOOR_COOLDOWN   = 3,
}

local BAD_CLASSES = {
    BodyVelocity        = true,
    BodyForce           = true,
    BodyAngularVelocity = true,
    BodyGyro            = true,
    BodyPosition        = true,
    BodyThrust          = true,
    LinearVelocity      = true,
    AngularVelocity     = true,
    VectorForce         = true,
    Torque              = true,
    AlignPosition       = true,
    AlignOrientation    = true,
}

-- ==================== УТИЛИТЫ ====================
local function log(text) print("[OrbitAC] " .. text) end

local function destroyObj(obj)
    if not obj or not obj.Parent then return end
    pcall(function() obj:Destroy() end)
end

local function zeroVelocity(char)
    if not char then return end
    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") then
            pcall(function()
                p.AssemblyLinearVelocity  = Vector3.zero
                p.AssemblyAngularVelocity = Vector3.zero
            end)
        end
    end
end

local function isOnGround(hrp)
    if not hrp then return false end
    local char = hrp.Parent
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return false end
    local vy = math.abs(hrp.AssemblyLinearVelocity.Y)
    if vy > 0.5 then return false end
    local state = hum:GetState()
    if state ~= Enum.HumanoidStateType.Running
       and state ~= Enum.HumanoidStateType.RunningNoPhysics
       and state ~= Enum.HumanoidStateType.Seated
       and state ~= Enum.HumanoidStateType.PlatformStanding
       and state ~= Enum.HumanoidStateType.Climbing then return false end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {char}
    local ray = Workspace:Raycast(hrp.Position, Vector3.new(0, -4, 0), params)
    return ray ~= nil
end

local function isInAir(hrp)
    if not hrp then return false end
    local char = hrp.Parent
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return false end
    local state = hum:GetState()
    return state == Enum.HumanoidStateType.Jumping
        or state == Enum.HumanoidStateType.Freefall
        or state == Enum.HumanoidStateType.Flying
end

local function getSafeFloor()
    local char = LocalPlayer.Character
    if not char then return nil end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {char, Workspace.CurrentCamera}
    local origin = hrp.Position + Vector3.new(0, 20, 0)
    local ray = Workspace:Raycast(origin, Vector3.new(0, -CONFIG.FLOOR_RAY_LENGTH, 0), params)
    if ray then return ray.Position + Vector3.new(0, 4, 0) end
    local directions = {
        Vector3.new(0,  -CONFIG.FLOOR_RAY_SIDE,  30),
        Vector3.new(0,  -CONFIG.FLOOR_RAY_SIDE, -30),
        Vector3.new(30, -CONFIG.FLOOR_RAY_SIDE,   0),
        Vector3.new(-30,-CONFIG.FLOOR_RAY_SIDE,   0),
    }
    for _, dir in ipairs(directions) do
        local r = Workspace:Raycast(origin, dir, params)
        if r then return r.Position + Vector3.new(0, 4, 0) end
    end
    if STATE.lastSafeCFrame then
        local p = STATE.lastSafeCFrame.Position
        return Vector3.new(p.X, math.max(p.Y, 10), p.Z)
    end
    return Vector3.new(0, 50, 0)
end

local function disableFallDamage(char)
    if not SETTINGS.NoFallDamage then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    pcall(function()
        hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
    end)
end

-- ==================== ПОМЕТКА ЧИТЕРА (глобально, вызывается из функций) ====================
function markCheater(plr, enable)
    if not plr or plr == LocalPlayer then return false end
    if enable then
        MARKED[plr] = true
        CHEATER_LOG[plr.UserId] = { name = plr.Name, time = os.time() }
        SESSION.cheatersMarked = SESSION.cheatersMarked + 1
        warn("[OrbitAC] Помечен: " .. plr.Name)
        sfxMarkCheater()
        notify("🚩 Помечен: " .. plr.Name, Color3.fromRGB(255, 120, 120))
    else
        MARKED[plr] = nil
        CHEATER_LOG[plr.UserId] = nil
    end
    return true
end

-- Forward declaration (для вызова из функций защиты)
local notify

-- ==================== ФУНКЦИИ ЗАЩИТЫ ====================
local function antiDropKick(char, hrp, now)
    if not SETTINGS.AntiDropKick then return end
    local current = hrp.CFrame
    if STATE.lastHrp then
        local dist = (current.Position - STATE.lastHrp.Position).Magnitude
        if dist > CONFIG.TELEPORT_DISTANCE and not isInAir(hrp) then
            STATE.jumpCounter = STATE.jumpCounter + 1
            if STATE.jumpCounter >= 2 then
                if STATE.lastSafeCFrame then
                    pcall(function()
                        char:PivotTo(STATE.lastSafeCFrame)
                        zeroVelocity(char)
                    end)
                    SESSION.defenses = SESSION.defenses + 1
                    STATE.blockedFlings = STATE.blockedFlings + 1
                    sfxDodgeSans()
                end
                STATE.jumpCounter = 0
            end
        else
            STATE.jumpCounter = 0
        end
    end
    STATE.lastHrp = current
    if hrp.Anchored and not isInAir(hrp) then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum and hum.MoveDirection.Magnitude > 0.05 then
            pcall(function() hrp.Anchored = false end)
            SESSION.defenses = SESSION.defenses + 1
        end
    end
end

local function antiFling(char, hrp)
    if not SETTINGS.AntiFling then return end
    if isInAir(hrp) then return end
    pcall(function()
        local spd = hrp.AssemblyLinearVelocity.Magnitude
        local rot = hrp.AssemblyAngularVelocity.Magnitude
        if spd > CONFIG.INSTANT_FLING or rot > CONFIG.INSTANT_FLING then
            hrp.AssemblyLinearVelocity  = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
            if STATE.lastSafeCFrame then pcall(function() char:PivotTo(STATE.lastSafeCFrame) end) end
            SESSION.defenses = SESSION.defenses + 1
            sfxDodgeSans()
            return
        end
        if spd > CONFIG.FLING_SPEED_THRESHOLD and rot > CONFIG.FLING_ROT_THRESHOLD then
            hrp.AssemblyLinearVelocity  = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
            SESSION.defenses = SESSION.defenses + 1
            sfxDodgeSans()
        end
    end)
    -- Детект у других игроков
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end
        local other = plr.Character
        if not other then continue end
        local otherHrp = other:FindFirstChild("HumanoidRootPart")
        if not otherHrp then continue end
        local otherRot = otherHrp.AssemblyAngularVelocity.Magnitude
        local otherSpd = otherHrp.AssemblyLinearVelocity.Magnitude
        if otherRot > CONFIG.FLING_ROT_THRESHOLD * 2 or otherSpd > CONFIG.FLING_SPEED_THRESHOLD * 2 then
            if not STATE.dropKickWarning[plr] then
                STATE.dropKickWarning[plr] = tick()
                markCheater(plr, true)
            end
        end
    end
end

local function antiFreeze(char)
    if not SETTINGS.AntiFreeze then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        pcall(function()
            if hum.WalkSpeed < 1 then hum.WalkSpeed = 16 end
            if hum.JumpPower < 1 then hum.JumpPower = 50 end
            local animator = hum:FindFirstChildOfClass("Animator")
            if animator then
                for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                    local nm = track.Animation and track.Animation.Name or ""
                    if nm:lower():find("laugh") then track:Stop(0) end
                end
            end
        end)
    end
    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") and p.Anchored and p.Name ~= "HumanoidRootPart" then
            pcall(function() p.Anchored = false end)
        end
    end
end

local function antiKnockback(char)
    if not SETTINGS.AntiKnockback then return end
    for _, child in ipairs(char:GetDescendants()) do
        if BAD_CLASSES[child.ClassName] then destroyObj(child) end
    end
end

local function antiAnchor(char)
    if not SETTINGS.AntiAnchor then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if hrp and hrp.Anchored then
        pcall(function() hrp.Anchored = false end)
        SESSION.defenses = SESSION.defenses + 1
    end
end

local function antiInstantKill(char)
    if not SETTINGS.AntiInstantKill then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local now = tick()
    if isOnGround(hrp)
        and STATE.lastHealth > 50
        and hum.Health < 10
        and (now - (STATE.lastHealthCheck or 0)) < 0.15 then
        if STATE.lastSafeCFrame then
            pcall(function() char:PivotTo(STATE.lastSafeCFrame) end)
            zeroVelocity(char)
            SESSION.defenses = SESSION.defenses + 1
        end
    end
    STATE.lastHealth = hum.Health
    STATE.lastHealthCheck = now
end

local function antiVoid(char, hrp, dt)
    if not SETTINGS.AntiVoid then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return end

    if isOnGround(hrp) then
        STATE.voidTimer = 0
        return
    end

    local vy = hrp.AssemblyLinearVelocity.Y
    local y = hrp.Position.Y
    local falling = false

    if y < -100 then
        falling = true
    elseif vy < CONFIG.FAST_FALL_VY then
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = {char}
        local ray = Workspace:Raycast(hrp.Position, Vector3.new(0, -CONFIG.FLOOR_RAY_LENGTH, 0), params)
        if not ray then falling = true end
    end

    if not falling then
        STATE.voidTimer = 0
        return
    end

    local now = tick()
    if now - (STATE.lastSmartFloor or 0) < CONFIG.SMART_FLOOR_COOLDOWN then
        STATE.voidTimer = 0
        return
    end

    STATE.voidTimer = STATE.voidTimer + (dt or 0.1)
    if STATE.voidTimer > CONFIG.VOID_TIMER then
        local safe = getSafeFloor()
        if safe and safe.Y > y + 3 then
            STATE.lastSmartFloor = now
            pcall(function()
                char:PivotTo(CFrame.new(safe))
                zeroVelocity(char)
            end)
            warn("[OrbitAC] Умный Пол спас с Y=" .. math.floor(y))
            sfxSmartFloor()
            notify("🛡 Умный Пол спас!", Color3.fromRGB(120, 255, 180), 2)
            SESSION.defenses = SESSION.defenses + 1
        end
        STATE.voidTimer = 0
    end
end

local function antiTeleport(char, hrp)
    if not SETTINGS.AntiTeleport then return end
    if not STATE.lastSafePosition then return end
    if not isOnGround(hrp) then return end
    if STATE.groundTime < CONFIG.MIN_GROUND_TIME then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum and hum.MoveDirection.Magnitude > 0.05 then return end
    local dx = hrp.Position.X - STATE.lastSafePosition.X
    local dz = hrp.Position.Z - STATE.lastSafePosition.Z
    local horiz = math.sqrt(dx * dx + dz * dz)
    if horiz > 250 then
        pcall(function() char:PivotTo(STATE.lastSafeCFrame + Vector3.new(0, 2, 0)) end)
        zeroVelocity(char)
        SESSION.defenses = SESSION.defenses + 1
    end
end

local function autoHeal(char)
    if not SETTINGS.AutoHeal then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum and hum.Health < hum.MaxHealth and hum.Health > 0 then
        pcall(function() hum.Health = math.min(hum.MaxHealth, hum.Health + SETTINGS.HealPower) end)
    end
end

local function lockPosition(char, hrp)
    if not SETTINGS.LockPosition then return end
    if not isOnGround(hrp) then return end
    if STATE.groundTime < CONFIG.MIN_GROUND_TIME then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum and hum.MoveDirection.Magnitude > 0.05 then return end
    if STATE.lastSafeCFrame then pcall(function() char:PivotTo(STATE.lastSafeCFrame) end) end
end

-- ==================== АНТИ-СУПЕРКОЛЬЦО ====================
local function antiSuperRing()
    if not SETTINGS.AntiSuperRing then return end
    task.spawn(function()
        while SETTINGS.Enabled do
            task.wait(0.2)
            for _, obj in ipairs(Workspace:GetDescendants()) do
                if obj:IsA("BasePart") and not obj.Anchored then
                    local parent = obj.Parent
                    if parent and parent:IsA("Model") then
                        local hum = parent:FindFirstChildOfClass("Humanoid")
                        if not hum then
                            for _, ch in ipairs(obj:GetChildren()) do
                                if ch:IsA("AlignPosition") or ch:IsA("Torque") then
                                    pcall(function() ch:Destroy() end)
                                end
                            end
                        end
                    else
                        for _, ch in ipairs(obj:GetChildren()) do
                            if ch:IsA("AlignPosition") or ch:IsA("Torque") then
                                pcall(function() ch:Destroy() end)
                            end
                        end
                    end
                end
            end
        end
    end)
end

-- ==================== АНТИ-HOMELANDER 🆕 ====================
local function antiHomelander(char, hrp)
    if not SETTINGS.AntiHomelander then return end
    -- 1) Огромные BodyVelocity/LinearVelocity на себе
    for _, v in ipairs(hrp:GetChildren()) do
        if v:IsA("BodyVelocity") or v:IsA("LinearVelocity") then
            local vel = v.Velocity or v.LineVelocity
            if vel and vel.Magnitude > 200 then
                destroyObj(v)
                SESSION.defenses = SESSION.defenses + 1
            end
        end
    end
    -- 2) Резкие чужие части рядом со мной с огромной скоростью
    local parts = Workspace:GetPartBoundsInRadius(hrp.Position, 6, OverlapParams.new())
    for _, obj in ipairs(parts) do
        if obj:IsA("BasePart") and obj ~= hrp then
            local owner = Players:GetPlayerFromCharacter(obj.Parent)
            if owner and owner ~= LocalPlayer then
                if obj.AssemblyLinearVelocity.Magnitude > 250 then
                    pcall(function()
                        obj.AssemblyLinearVelocity  = Vector3.zero
                        obj.AssemblyAngularVelocity = Vector3.zero
                    end)
                    markCheater(owner, true)
                end
            end
        end
    end
end

-- ==================== АНТИ-GRAB 🆕 ====================
local function antiGrab(char, hrp)
    if not SETTINGS.AntiGrab then return end
    for _, v in ipairs(hrp:GetChildren()) do
        if v:IsA("WeldConstraint") or v:IsA("Weld")
        or v:IsA("ManualWeld") or v:IsA("Motor6D") then
            local p0, p1 = v.Part0, v.Part1
            if p0 and p1 then
                local other = (p0 == hrp) and p1 or p0
                if other and other.Parent then
                    local owner = Players:GetPlayerFromCharacter(other.Parent)
                    if owner and owner ~= LocalPlayer then
                        destroyObj(v)
                        SESSION.defenses = SESSION.defenses + 1
                        markCheater(owner, true)
                    end
                end
            end
        end
    end
end

-- ==================== АНТИ-RAGDOLL 🆕 ====================
local function antiRagdoll(char)
    if not SETTINGS.AntiRagdoll then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    local st = hum:GetState()
    if st == Enum.HumanoidStateType.Physics or st == Enum.HumanoidStateType.Ragdoll then
        pcall(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end)
        SESSION.defenses = SESSION.defenses + 1
    end
    for _, v in ipairs(char:GetDescendants()) do
        if v:IsA("BallSocketConstraint") or v:IsA("NoCollisionConstraint") then
            destroyObj(v)
        end
    end
end

-- ==================== АНТИ-KILLAURA 🆕 ====================
local function antiKillaura(char, hrp)
    if not SETTINGS.AntiKillaura then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    if hum.Health < (STATE.lastHealth or 100) - 15 then
        local closest, closestDist = nil, math.huge
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Character then
                local oHrp = plr.Character:FindFirstChild("HumanoidRootPart")
                if oHrp then
                    local d = (oHrp.Position - hrp.Position).Magnitude
                    if d < closestDist then closest, closestDist = plr, d end
                end
            end
        end
        if closest and closestDist < 15 then
            markCheater(closest, true)
            local away = (hrp.Position - closest.Character.HumanoidRootPart.Position).Unit
            pcall(function() char:PivotTo(CFrame.new(hrp.Position + away * 5)) end)
            SESSION.defenses = SESSION.defenses + 1
        end
    end
    STATE.lastHealth = hum.Health
end

-- ==================== УКЛОНЕНИЕ ====================
local dodgeConnection = nil
local dodgeParams = OverlapParams.new()
dodgeParams.FilterType = Enum.RaycastFilterType.Exclude
local lastDodgeScan = 0

local DODGE = {
    Enabled        = false,
    Radius         = 25,
    SpeedThreshold = 25,
    Distance       = 15,
    Cooldown       = 0.35,
    LastTime       = 0,
}

local function setupDodge()
    if dodgeConnection then dodgeConnection:Disconnect(); dodgeConnection = nil end
    dodgeConnection = RunService.Heartbeat:Connect(function(dt)
        if not SETTINGS.Enabled or not DODGE.Enabled then return end
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        if isInAir(hrp) then return end

        local now = tick()
        if now - DODGE.LastTime < DODGE.Cooldown then return end
        if now - lastDodgeScan < 0.05 then return end
        lastDodgeScan = now
        dodgeParams.FilterDescendantsInstances = {char}

        local threats = {}
        local myPos = hrp.Position

        local parts = Workspace:GetPartBoundsInRadius(myPos, DODGE.Radius, dodgeParams)
        for _, obj in ipairs(parts) do
            if obj:IsA("BasePart") and obj.Parent ~= char then
                if not obj.Anchored then
                    local spd = obj.AssemblyLinearVelocity
                    if spd.Magnitude > DODGE.SpeedThreshold then
                        local toMe = (myPos - obj.Position)
                        if toMe.Magnitude > 0.1 and spd.Unit:Dot(toMe.Unit) > 0.4 then
                            table.insert(threats, { obj = obj, dist = toMe.Magnitude })
                        end
                    end
                end
                local parent = obj.Parent
                if parent and parent:IsA("Model") and parent ~= char then
                    local otherHum = parent:FindFirstChildOfClass("Humanoid")
                    if otherHum and otherHum.Health > 0 then
                        local otherRoot = parent:FindFirstChild("HumanoidRootPart")
                        if otherRoot then
                            local spd = otherRoot.AssemblyLinearVelocity
                            local rot = otherRoot.AssemblyAngularVelocity
                            if spd.Magnitude > DODGE.SpeedThreshold * 2 or rot.Magnitude > DODGE.SpeedThreshold then
                                table.insert(threats, { obj = otherRoot, dist = (otherRoot.Position - myPos).Magnitude })
                            end
                        end
                    end
                end
            end
        end

        if #threats == 0 then return end
        table.sort(threats, function(a, b) return a.dist < b.dist end)
        local threat = threats[1]
        local dir = (threat.obj.Position - myPos).Unit
        local right = dir:Cross(Vector3.new(0, 1, 0)).Unit

        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = {char, Workspace.CurrentCamera}
        local rayRight = Workspace:Raycast(myPos, right * DODGE.Distance, params)
        local dodgeDir = rayRight and -right or right
        local target = myPos + dodgeDir * DODGE.Distance
        local rayDown = Workspace:Raycast(target + Vector3.new(0, 5, 0), Vector3.new(0, -10, 0), params)
        if rayDown then target = rayDown.Position + Vector3.new(0, 3, 0) end

        pcall(function()
            char:PivotTo(CFrame.new(target))
            hrp.AssemblyLinearVelocity  = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end)
        DODGE.LastTime = now
        SESSION.dodges = SESSION.dodges + 1
        sfxDodgeSans()
        notify("🥷 Уклонение!", Color3.fromRGB(150, 220, 255), 1.5)
    end)
end

-- ==================== ДЕТЕКТ ТРОЛЛИНГА ====================
local TROLLING = {
    Enabled   = true,
    LastScan  = 0,
    Cooldown  = {},
}

local function detectTrolling()
    if not SETTINGS.Enabled or not TROLLING.Enabled then return end
    local now = tick()
    if now - TROLLING.LastScan < 0.2 then return end
    TROLLING.LastScan = now

    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end
        local other = plr.Character
        if not other then continue end
        local otherHrp = other:FindFirstChild("HumanoidRootPart")
        if not otherHrp then continue end

        local dist = (otherHrp.Position - hrp.Position).Magnitude
        if dist < 8 then
            local spd = otherHrp.AssemblyLinearVelocity.Magnitude
            local rot = otherHrp.AssemblyAngularVelocity.Magnitude
            if spd > 40 or rot > 20 then
                if not TROLLING.Cooldown[plr] or now - TROLLING.Cooldown[plr] > 3 then
                    TROLLING.Cooldown[plr] = now
                    sfxDodgeSans()
                    notify("⚠️ Троллинг: " .. plr.Name, Color3.fromRGB(255, 150, 150), 2)
                end
            end
        end
    end
end

-- ==================== ОТВЕТНЫЙ ФЛИНГ ====================
local REVERSE = {
    Enabled        = false,
    RotLimit       = 20 * 2 * math.pi,
    FlingPower     = 500,
    LastCheck      = 0,
    Interval       = 0.3,
    Detected       = {},
}

local function reverseFling(plr)
    if not plr or plr == LocalPlayer then return end
    local char = plr.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    pcall(function()
        hrp.AssemblyAngularVelocity = Vector3.new(
            math.random(-1, 1) * 1000, math.random(-1, 1) * 1000, math.random(-1, 1) * 1000)
        hrp.AssemblyLinearVelocity = Vector3.new(0, REVERSE.FlingPower, 0)
    end)
    log("🚨 ОТВЕТНЫЙ ФЛИНГ: " .. plr.Name)
end

local function scanFlingers()
    if not REVERSE.Enabled then return end
    local now = tick()
    if now - REVERSE.LastCheck < REVERSE.Interval then return end
    REVERSE.LastCheck = now
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end
        local char = plr.Character
        if not char then continue end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then continue end
        local rot = hrp.AssemblyAngularVelocity
        if math.abs(rot.X) > REVERSE.RotLimit
            or math.abs(rot.Y) > REVERSE.RotLimit
            or math.abs(rot.Z) > REVERSE.RotLimit then
            if not REVERSE.Detected[plr] then
                REVERSE.Detected[plr] = now
                reverseFling(plr)
            end
        end
    end
    for p, t in pairs(REVERSE.Detected) do
        if now - t > 5 then REVERSE.Detected[p] = nil end
    end
end

-- ==================== ОСНОВНОЙ ЦИКЛ ЗАЩИТЫ ====================
local function handleProtection(dt, char, hrp)
    local now = tick()
    local airFlag = isInAir(hrp)

    if isOnGround(hrp) then
        STATE.groundTime = STATE.groundTime + dt
    else
        STATE.groundTime = 0
    end

    antiDropKick(char, hrp, now)
    antiFling(char, hrp)
    antiAnchor(char)

    if now - STATE.lastKnockbackTime >= 0.1 then
        STATE.lastKnockbackTime = now
        antiKnockback(char)
    end
    if now - STATE.lastFreezeTime >= 0.25 then
        STATE.lastFreezeTime = now
        antiFreeze(char)
    end
    if SETTINGS.AutoHeal and now - STATE.lastHealTime >= 0.3 then
        STATE.lastHealTime = now
        autoHeal(char)
    end

    antiVoid(char, hrp, dt)
    antiHomelander(char, hrp)   -- 🆕
    antiGrab(char, hrp)         -- 🆕
    antiRagdoll(char)           -- 🆕
    antiKillaura(char, hrp)     -- 🆕

    local inGrace = (now - STATE.spawnGrace) < 5.0
    if not inGrace and not airFlag then
        antiTeleport(char, hrp)
        lockPosition(char, hrp)
    end

    antiInstantKill(char)

    pcall(detectTrolling)
    pcall(checkIntrusion)

    if now - STATE.lastScan > 0.5 then
        STATE.lastScan = now
        if SETTINGS.DetectSpeed then
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer then
                    local other = plr.Character
                    if other then
                        local otherHrp = other:FindFirstChild("HumanoidRootPart")
                        if otherHrp then
                            local last = STATE.lastPositions[plr]
                            if last then
                                local dt2 = now - last.time
                                if dt2 > 0.1 and dt2 < 1 then
                                    local spd = (otherHrp.Position - last.pos).Magnitude / dt2
                                    if spd > 150 then
                                        markCheater(plr, true)
                                    end
                                end
                            end
                            STATE.lastPositions[plr] = { pos = otherHrp.Position, time = now }
                        end
                    end
                end
            end
        end
        pcall(scanFlingers)
    end

    if now - STATE.lastCheckTime > 0.2 then
        STATE.lastCheckTime = now
        local hum = char:FindFirstChildOfClass("Humanoid")
        local vy = math.abs(hrp.AssemblyLinearVelocity.Y)
        if hum and hum.Health > 0
            and not airFlag
            and vy < 1.0
            and isOnGround(hrp) then
            STATE.lastSafePosition = hrp.Position
            local lv = hrp.CFrame.LookVector
            local yaw = math.atan2(-lv.X, -lv.Z)
            STATE.lastSafeCFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, yaw, 0)
        end
    end
end

local protectionConnection = nil

local function enableProtection()
    if protectionConnection then protectionConnection:Disconnect(); protectionConnection = nil end
    if not SETTINGS.Enabled then return end

    STATE.lastSafePosition  = nil
    STATE.lastSafeCFrame    = nil
    STATE.lastCheckTime     = 0
    STATE.lastHealTime      = 0
    STATE.lastHealth        = 100
    STATE.lastKnockbackTime = 0
    STATE.lastFreezeTime    = 0
    STATE.spawnGrace        = tick()
    STATE.lastPositions     = {}
    STATE.godModeWarning    = {}
    STATE.voidTimer         = 0
    STATE.lastHrp           = nil
    STATE.jumpCounter       = 0
    STATE.groundTime        = 0
    STATE.lastSmartFloor    = 0

    if LocalPlayer.Character then
        antiKnockback(LocalPlayer.Character)
        disableFallDamage(LocalPlayer.Character)
    end

    if STATE.charConnection then STATE.charConnection:Disconnect() end
    STATE.charConnection = LocalPlayer.CharacterAdded:Connect(function(newChar)
        STATE.lastHrp           = nil
        STATE.spawnGrace        = tick()
        STATE.lastSafePosition  = nil
        STATE.lastSafeCFrame    = nil
        STATE.groundTime        = 0
        STATE.lastSmartFloor    = 0
        task.wait(0.5)
        disableFallDamage(newChar)
    end)

    setupDodge()
    antiSuperRing()

    protectionConnection = RunService.Heartbeat:Connect(function(dt)
        if not SETTINGS.Enabled then return end
        local char = LocalPlayer.Character
        if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        pcall(handleProtection, dt, char, hrp)
    end)

    notify("🛡 Анти-Чит v12.0 ВКЛ", Color3.fromRGB(120, 255, 180), 3)
    log("Анти-Чит v12.0 активен.")
end

local function disableProtection()
    if STATE.charConnection then STATE.charConnection:Disconnect(); STATE.charConnection = nil end
    if protectionConnection then protectionConnection:Disconnect(); protectionConnection = nil end
    if dodgeConnection then dodgeConnection:Disconnect(); dodgeConnection = nil end
    STATE.lastSafePosition = nil
    STATE.lastSafeCFrame = nil
end

Workspace.DescendantAdded:Connect(function(obj)
    if not SETTINGS.Enabled or not SETTINGS.AntiExplosion then return end
    if obj:IsA("Explosion") then
        task.defer(function() pcall(function() obj:Destroy() end) end)
    end
end)

-- ==================== UI ====================
local screen = Instance.new("ScreenGui")
screen.Name = "_OrbitAC_" .. tostring(math.random(100000, 999999))
screen.ResetOnSpawn = false
screen.IgnoreGuiInset = true
screen.DisplayOrder = 9999
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
protectGui(screen)
local okParent = pcall(function() screen.Parent = getSafeParent() end)
if not okParent or not screen.Parent then screen.Parent = PlayerGui end

local mainButton = Instance.new("TextButton")
mainButton.Size = UDim2.new(0, 56, 0, 56)
mainButton.Position = SETTINGS.ButtonPosition
mainButton.BackgroundColor3 = Color3.fromRGB(40, 20, 20)
mainButton.BackgroundTransparency = 0.1
mainButton.TextColor3 = Color3.fromRGB(255, 180, 180)
mainButton.Font = Enum.Font.GothamBold
mainButton.TextSize = 24
mainButton.Text = "🛡"
mainButton.AutoButtonColor = false
mainButton.Parent = screen
Instance.new("UICorner", mainButton).CornerRadius = UDim.new(0, 14)
local btnStroke = Instance.new("UIStroke", mainButton)
btnStroke.Color = Color3.fromRGB(255, 100, 100)
btnStroke.Thickness = 1.5

local panel = Instance.new("ScrollingFrame")
panel.Size = UDim2.new(0, 300, 0, 600)
panel.Position = UDim2.new(0, 90, 0, 60)
panel.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
panel.BackgroundTransparency = 0.15
panel.BorderSizePixel = 0
panel.Visible = false
panel.CanvasSize = UDim2.new(0, 0, 0, 1700)
panel.ScrollBarThickness = 4
panel.ScrollBarImageColor3 = Color3.fromRGB(255, 100, 100)
panel.Parent = screen
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 12)
local panelStroke = Instance.new("UIStroke", panel)
panelStroke.Color = Color3.fromRGB(255, 100, 100)
panelStroke.Thickness = 1

local panelScale = Instance.new("UIScale")
panelScale.Parent = panel

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 30)
title.Position = UDim2.new(0, 0, 0, 6)
title.BackgroundTransparency = 1
title.Text = "🛡  ОРБИТА АНТИ-ЧИТ v12.0"
title.TextColor3 = Color3.fromRGB(255, 200, 200)
title.Font = Enum.Font.GothamBold
title.TextSize = 15
title.Parent = panel

local function createSection(text, y, color)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -20, 0, 28)
    frame.Position = UDim2.new(0, 10, 0, y)
    frame.BackgroundColor3 = color or Color3.fromRGB(80, 40, 40)
    frame.BackgroundTransparency = 0.35
    frame.BorderSizePixel = 0
    frame.Parent = panel
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(0, 4, 1, -8)
    bar.Position = UDim2.new(0, 4, 0, 4)
    bar.BackgroundColor3 = color or Color3.fromRGB(255, 100, 100)
    bar.BorderSizePixel = 0
    bar.Parent = frame
    Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 2)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -14, 1, 0)
    lbl.Position = UDim2.new(0, 12, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = Color3.fromRGB(240, 240, 255)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 13
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = frame
end

local function createButton(text, y, h, bg, txtColor)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, -20, 0, h or 32)
    b.Position = UDim2.new(0, 10, 0, y)
    b.BackgroundColor3 = bg or Color3.fromRGB(45, 45, 62)
    b.TextColor3 = txtColor or Color3.fromRGB(235, 235, 255)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 12
    b.Text = text
    b.AutoButtonColor = true
    b.Parent = panel
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
    local stroke = Instance.new("UIStroke", b)
    stroke.Color = bg or Color3.fromRGB(80, 80, 120)
    stroke.Thickness = 1
    stroke.Transparency = 0.65
    b.MouseButton1Down:Connect(sfxClick)
    b.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then sfxClick() end
    end)
    return b
end

createSection("⚡  ОСНОВНОЕ", 42, Color3.fromRGB(80, 40, 40))
local btnToggle = createButton("🔴 ВЫКЛЮЧЕНО", 74, 36, Color3.fromRGB(50, 35, 40), Color3.fromRGB(255, 80, 80))

createSection("📊  СТАТИСТИКА", 118, Color3.fromRGB(60, 60, 90))
local statsLabel = Instance.new("TextLabel")
statsLabel.Size = UDim2.new(1, -20, 0, 110)
statsLabel.Position = UDim2.new(0, 10, 0, 150)
statsLabel.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
statsLabel.BackgroundTransparency = 0.2
statsLabel.BorderSizePixel = 0
statsLabel.TextColor3 = Color3.fromRGB(200, 220, 255)
statsLabel.Font = Enum.Font.GothamBold
statsLabel.TextSize = 11
statsLabel.TextXAlignment = Enum.TextXAlignment.Left
statsLabel.TextYAlignment = Enum.TextYAlignment.Top
statsLabel.Text = "Загрузка..."
statsLabel.Parent = panel
Instance.new("UICorner", statsLabel).CornerRadius = UDim.new(0, 6)

createSection("🛡️  ЗАЩИТА", 268, Color3.fromRGB(60, 100, 60))
local btnFling      = createButton("🛡️ Анти-Флинг: ВКЛ",          300, 30, Color3.fromRGB(35,50,35), Color3.fromRGB(160,255,160))
local btnVoid       = createButton("🛡️ Анти-Пустота: ВКЛ",        334, 30, Color3.fromRGB(35,50,35), Color3.fromRGB(160,255,160))
local btnTeleport   = createButton("🛡️ Анти-Телепорт: ВКЛ",       368, 30, Color3.fromRGB(35,50,35), Color3.fromRGB(160,255,160))
local btnKnockback  = createButton("🛡️ Анти-Отбрасывание: ВКЛ",   402, 30, Color3.fromRGB(35,50,35), Color3.fromRGB(160,255,160))
local btnFreeze     = createButton("🛡️ Анти-Заморозка: ВКЛ",      436, 30, Color3.fromRGB(35,50,35), Color3.fromRGB(160,255,160))
local btnDropKick   = createButton("🛡️ Анти-ДропКик: ВКЛ",        470, 30, Color3.fromRGB(35,50,35), Color3.fromRGB(160,255,160))
local btnInstant    = createButton("🛡️ Анти-МгновСмерть: ВКЛ",    504, 30, Color3.fromRGB(35,50,35), Color3.fromRGB(160,255,160))
local btnExplosion  = createButton("🛡️ Анти-Взрыв: ВКЛ",          538, 30, Color3.fromRGB(35,50,35), Color3.fromRGB(160,255,160))
local btnSuperRing  = createButton("🛡️ Анти-СуперКольцо: ВКЛ",    572, 30, Color3.fromRGB(35,50,35), Color3.fromRGB(160,255,160))
local btnHomelander = createButton("🛡️ Анти-Homelander: ВКЛ",     606, 30, Color3.fromRGB(35,50,35), Color3.fromRGB(160,255,160))
local btnGrab       = createButton("🛡️ Анти-Grab: ВКЛ",           640, 30, Color3.fromRGB(35,50,35), Color3.fromRGB(160,255,160))
local btnRagdoll    = createButton("🛡️ Анти-Ragdoll: ВКЛ",        674, 30, Color3.fromRGB(35,50,35), Color3.fromRGB(160,255,160))
local btnKillaura   = createButton("🛡️ Анти-Killaura: ВКЛ",       708, 30, Color3.fromRGB(35,50,35), Color3.fromRGB(160,255,160))
local btnNoFall     = createButton("🛡️ Убрать урон падения: ВКЛ", 742, 30, Color3.fromRGB(35,50,35), Color3.fromRGB(160,255,160))

createSection("💚  УТИЛИТЫ", 784, Color3.fromRGB(80, 100, 60))
local btnHeal     = createButton("💚 Авто-Лечение: ВЫКЛ",           816, 30, Color3.fromRGB(35,50,35), Color3.fromRGB(160,255,160))
local btnLock     = createButton("📍 Блокировка позиции: ВЫКЛ",     850, 30, Color3.fromRGB(35,50,35), Color3.fromRGB(160,255,160))

createSection("👁️  ВИЗУАЛ", 892, Color3.fromRGB(60, 80, 120))
local btnSphere   = createButton("🔵 Сфера: ВЫКЛ",                  924, 32, Color3.fromRGB(40,50,70), Color3.fromRGB(180,220,255))
local btnSize     = createButton("📏 Размер сферы: 8",              960, 30, Color3.fromRGB(40,50,70), Color3.fromRGB(180,220,255))
local btnIntrusion= createButton("🚨 Детект вторжения: ВКЛ",        994, 30, Color3.fromRGB(50,40,60), Color3.fromRGB(255,180,200))

createSection("🥷  ДОП. ЗАЩИТА", 1036, Color3.fromRGB(80, 60, 130))
local btnDodge    = createButton("🥷 Уклонение: ВЫКЛ",              1068, 32, Color3.fromRGB(50,50,50), Color3.fromRGB(200,200,200))
local btnTroll    = createButton("👁️ Детект троллинга: ВКЛ",       1104, 30, Color3.fromRGB(50,60,80), Color3.fromRGB(200,220,255))
local btnReverse  = createButton("🚨 Ответный флинг: ВЫКЛ",         1136, 30, Color3.fromRGB(60,30,30), Color3.fromRGB(255,150,150))

createSection("👁️  ДЕТЕКТ ЧИТЕРОВ", 1178, Color3.fromRGB(100, 60, 60))
local btnSpeed    = createButton("⚡ Детект скорости: ВКЛ",         1210, 30, Color3.fromRGB(50,40,40), Color3.fromRGB(255,180,180))
local btnGodMode  = createButton("👁️ Детект GodMode: ВКЛ",          1244, 30, Color3.fromRGB(50,40,40), Color3.fromRGB(255,180,180))
local btnList     = createButton("📋 Список читеров: 0",            1278, 28, Color3.fromRGB(60,35,45), Color3.fromRGB(255,180,220))

createSection("🔊  ЗВУКИ", 1318, Color3.fromRGB(70, 80, 110))
local btnSounds   = createButton("🔊 Звуки: ВКЛ",                   1350, 30, Color3.fromRGB(35,60,45), Color3.fromRGB(180,255,180))
local btnTestSnd  = createButton("🎵 Проверить звуки",              1384, 30, Color3.fromRGB(50,60,90), Color3.fromRGB(200,220,255))

createSection("💾  СИСТЕМА", 1426, Color3.fromRGB(60, 60, 80))
local btnSave     = createButton("💾 Сохранить настройки",          1458, 30, Color3.fromRGB(35,60,45), Color3.fromRGB(160,255,180))
local btnLoad     = createButton("📂 Загрузить настройки",          1492, 30, Color3.fromRGB(35,50,60), Color3.fromRGB(180,220,255))
local btnReset    = createButton("🔄 Сбросить всё",                 1526, 30, Color3.fromRGB(50,30,30), Color3.fromRGB(255,180,180))
local btnUnload   = createButton("❌ ВЫГРУЗИТЬ",                    1560, 32, Color3.fromRGB(80,30,30), Color3.fromRGB(255,140,140))

panel.CanvasSize = UDim2.new(0, 0, 0, 1610)

-- ==================== УВЕДОМЛЕНИЯ ====================
local notifyContainer = Instance.new("Frame")
notifyContainer.Size = UDim2.new(0, 300, 0.4, 0)
notifyContainer.Position = UDim2.new(1, -320, 0.15, 0)
notifyContainer.BackgroundTransparency = 1
notifyContainer.Parent = screen

local notifyLayout = Instance.new("UIListLayout")
notifyLayout.SortOrder = Enum.SortOrder.LayoutOrder
notifyLayout.Padding = UDim.new(0, 6)
notifyLayout.VerticalAlignment = Enum.VerticalAlignment.Top
notifyLayout.Parent = notifyContainer

local notifyCounter = 0

notify = function(msg, color, duration)
    duration = duration or 2
    color = color or Color3.fromRGB(140, 255, 200)
    notifyCounter = notifyCounter + 1

    local slot = Instance.new("Frame")
    slot.Size = UDim2.new(1, 0, 0, 40)
    slot.BackgroundTransparency = 1
    slot.LayoutOrder = notifyCounter
    slot.Parent = notifyContainer

    local slots = {}
    for _, child in ipairs(notifyContainer:GetChildren()) do
        if child:IsA("Frame") then table.insert(slots, child) end
    end
    table.sort(slots, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
    while #slots > 6 do table.remove(slots, 1):Destroy() end

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.Position = UDim2.new(1.15, 0, 0, 0)
    frame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    frame.BackgroundTransparency = 0.15
    frame.BorderSizePixel = 0
    frame.Parent = slot
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
    local stroke = Instance.new("UIStroke", frame)
    stroke.Color = color
    stroke.Thickness = 1.5

    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(1, -16, 1, 0)
    textLabel.Position = UDim2.new(0, 8, 0, 0)
    textLabel.BackgroundTransparency = 1
    textLabel.Text = msg                 -- ← исправлено: было `текст.Text = текст`
    textLabel.TextColor3 = color
    textLabel.Font = Enum.Font.GothamBold
    textLabel.TextSize = 13
    textLabel.TextWrapped = true
    textLabel.TextXAlignment = Enum.TextXAlignment.Left
    textLabel.Parent = frame

    TweenService:Create(frame, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
        Position = UDim2.new(0, 0, 0, 0),
    }):Play()

    task.delay(duration, function()
        if not slot or not slot.Parent then return end
        local out = TweenService:Create(frame, TweenInfo.new(0.25), { Position = UDim2.new(1.15, 0, 0, 0) })
        out:Play()
        out.Completed:Connect(function() pcall(function() slot:Destroy() end) end)
    end)
end
GENV._ORBIT_AC_NOTIFY = notify

-- ==================== ОБРАБОТЧИКИ UI ====================
local dragging, moved = false, false
local startInputPos, startButtonPos

mainButton.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch
       or input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        moved = false
        startInputPos = input.Position
        startButtonPos = mainButton.Position
    end
end)

UIS.InputChanged:Connect(function(input)
    if not dragging then return end
    if input.UserInputType == Enum.UserInputType.Touch
       or input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - startInputPos
        if delta.Magnitude > 6 then moved = true end
        if moved then
            local abs = screen.AbsoluteSize
            mainButton.Position = UDim2.fromOffset(
                math.clamp(startButtonPos.X.Offset + delta.X, 0, math.max(0, abs.X - 56)),
                math.clamp(startButtonPos.Y.Offset + delta.Y, 0, math.max(0, abs.Y - 56))
            )
        end
    end
end)

UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch
       or input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)

local panelOpen = false
local function setPanel(open)
    panelOpen = open
    sfxSwitch()
    if open then
        local abs = screen.AbsoluteSize
        panel.Size = UDim2.fromOffset(300, math.clamp(abs.Y - 40, 200, 700))
        panel.Position = UDim2.fromOffset(
            math.clamp(mainButton.Position.X.Offset + 70, 0, math.max(0, abs.X - 310)), 20)
        panelScale.Scale = 0.85
        panel.Visible = true
        TweenService:Create(panelScale, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = 1 }):Play()
    else
        TweenService:Create(panelScale, TweenInfo.new(0.12), { Scale = 0.85 }):Play()
        task.delay(0.13, function()
            if not panelOpen then panel.Visible = false end
        end)
    end
end

mainButton.Activated:Connect(function()
    if moved then moved = false; return end
    setPanel(not panelOpen)
end)

btnToggle.Activated:Connect(function()
    SETTINGS.Enabled = not SETTINGS.Enabled
    sfxSwitch()
    if SETTINGS.Enabled then
        btnToggle.Text = "🟢 ВКЛЮЧЕНО"
        btnToggle.TextColor3 = Color3.fromRGB(0,255,120)
        btnToggle.BackgroundColor3 = Color3.fromRGB(40,50,40)
        enableProtection()
    else
        btnToggle.Text = "🔴 ВЫКЛЮЧЕНО"
        btnToggle.TextColor3 = Color3.fromRGB(255,80,80)
        btnToggle.BackgroundColor3 = Color3.fromRGB(50,35,40)
        disableProtection()
        if sphereModel then sphereModel:Destroy(); sphereModel = nil; spherePart = nil end
        notify("🔴 Анти-Чит ВЫКЛ", Color3.fromRGB(255,100,100), 2)
    end
end)

local function toggleBtn(button, field, prefix, colorOn, colorOff)
    SETTINGS[field] = not SETTINGS[field]
    button.Text = prefix .. ": " .. (SETTINGS[field] and "ВКЛ" or "ВЫКЛ")
    if SETTINGS[field] then
        button.TextColor3 = colorOn or Color3.fromRGB(160,255,160)
        button.BackgroundColor3 = Color3.fromRGB(35,50,35)
    else
        button.TextColor3 = colorOff or Color3.fromRGB(220,200,200)
        button.BackgroundColor3 = Color3.fromRGB(50,40,40)
    end
end

btnFling.Activated:Connect(function()      toggleBtn(btnFling, "AntiFling", "🛡️ Анти-Флинг") end)
btnVoid.Activated:Connect(function()       toggleBtn(btnVoid, "AntiVoid", "🛡️ Анти-Пустота") end)
btnTeleport.Activated:Connect(function()   toggleBtn(btnTeleport, "AntiTeleport", "🛡️ Анти-Телепорт") end)
btnKnockback.Activated:Connect(function()  toggleBtn(btnKnockback, "AntiKnockback", "🛡️ Анти-Отбрасывание") end)
btnFreeze.Activated:Connect(function()     toggleBtn(btnFreeze, "AntiFreeze", "🛡️ Анти-Заморозка") end)
btnDropKick.Activated:Connect(function()   toggleBtn(btnDropKick, "AntiDropKick", "🛡️ Анти-ДропКик") end)
btnInstant.Activated:Connect(function()    toggleBtn(btnInstant, "AntiInstantKill", "🛡️ Анти-МгновСмерть") end)
btnExplosion.Activated:Connect(function()  toggleBtn(btnExplosion, "AntiExplosion", "🛡️ Анти-Взрыв") end)
btnSuperRing.Activated:Connect(function()  toggleBtn(btnSuperRing, "AntiSuperRing", "🛡️ Анти-СуперКольцо") end)
btnHomelander.Activated:Connect(function() toggleBtn(btnHomelander, "AntiHomelander", "🛡️ Анти-Homelander") end)
btnGrab.Activated:Connect(function()       toggleBtn(btnGrab, "AntiGrab", "🛡️ Анти-Grab") end)
btnRagdoll.Activated:Connect(function()    toggleBtn(btnRagdoll, "AntiRagdoll", "🛡️ Анти-Ragdoll") end)
btnKillaura.Activated:Connect(function()   toggleBtn(btnKillaura, "AntiKillaura", "🛡️ Анти-Killaura") end)
btnNoFall.Activated:Connect(function()     toggleBtn(btnNoFall, "NoFallDamage", "🛡️ Убрать урон падения") end)
btnHeal.Activated:Connect(function()       toggleBtn(btnHeal, "AutoHeal", "💚 Авто-Лечение") end)
btnLock.Activated:Connect(function()       toggleBtn(btnLock, "LockPosition", "📍 Блокировка позиции") end)
btnIntrusion.Activated:Connect(function()  toggleBtn(btnIntrusion, "IntrusionDetect", "🚨 Детект вторжения") end)
btnSpeed.Activated:Connect(function()      toggleBtn(btnSpeed, "DetectSpeed", "⚡ Детект скорости") end)
btnGodMode.Activated:Connect(function()    toggleBtn(btnGodMode, "DetectGodMode", "👁️ Детект GodMode") end)

btnSphere.Activated:Connect(function()
    SETTINGS.VisualSphere = not SETTINGS.VisualSphere
    btnSphere.Text = "🔵 Сфера: " .. (SETTINGS.VisualSphere and "ВКЛ" or "ВЫКЛ")
    if not SETTINGS.VisualSphere then
        if sphereModel then sphereModel:Destroy(); sphereModel = nil; spherePart = nil end
    else
        createSphere()
    end
end)
btnSize.Activated:Connect(function()
    local sizes = {4, 6, 8, 12, 16, 20, 25, 30}
    local idx = 1
    for i, v in ipairs(sizes) do if v == SETTINGS.SphereSize then idx = i; break end end
    SETTINGS.SphereSize = sizes[(idx % #sizes) + 1]
    btnSize.Text = "📏 Размер сферы: " .. SETTINGS.SphereSize
    if spherePart then
        spherePart.Size = Vector3.new(SETTINGS.SphereSize, SETTINGS.SphereSize, SETTINGS.SphereSize)
    end
end)

btnDodge.Activated:Connect(function()
    DODGE.Enabled = not DODGE.Enabled
    btnDodge.Text = "🥷 Уклонение: " .. (DODGE.Enabled and "ВКЛ" or "ВЫКЛ")
    btnDodge.BackgroundColor3 = DODGE.Enabled and Color3.fromRGB(60,80,50) or Color3.fromRGB(50,50,50)
end)
btnTroll.Activated:Connect(function()
    TROLLING.Enabled = not TROLLING.Enabled
    btnTroll.Text = "👁️ Детект троллинга: " .. (TROLLING.Enabled and "ВКЛ" or "ВЫКЛ")
end)
btnReverse.Activated:Connect(function()
    REVERSE.Enabled = not REVERSE.Enabled
    btnReverse.Text = "🚨 Ответный флинг: " .. (REVERSE.Enabled and "ВКЛ" or "ВЫКЛ")
    btnReverse.BackgroundColor3 = REVERSE.Enabled and Color3.fromRGB(100,30,30) or Color3.fromRGB(60,30,30)
end)

btnList.Activated:Connect(function()
    local list = {}
    for p in pairs(MARKED) do
        if p and p.Parent then table.insert(list, p.Name) end
    end
    if #list == 0 then
        notify("📋 Читеров не найдено", Color3.fromRGB(200, 200, 255), 3)
    else
        notify("📋 Читеры: " .. table.concat(list, ", "), Color3.fromRGB(255, 180, 220), 5)
    end
end)

btnSounds.Activated:Connect(function()
    SETTINGS.Sounds = not SETTINGS.Sounds
    btnSounds.Text = "🔊 Звуки: " .. (SETTINGS.Sounds and "ВКЛ" or "ВЫКЛ")
    if SETTINGS.Sounds then sfxSwitch() end
end)

btnTestSnd.Activated:Connect(function()
    btnTestSnd.Text = "⏳ Проигрываю..."
    task.wait(0.1)
    sfxClick()
    task.wait(0.5)
    sfxDodgeSans()
    task.wait(3)
    btnTestSnd.Text = "✅ Готово"
    task.wait(2)
    btnTestSnd.Text = "🎵 Проверить звуки"
end)

-- ==================== СОХРАНЕНИЕ ====================
local SAVE_FILE = "orbit_ac_settings.json"
local HAS_FS = (writefile and readfile and isfile and type(writefile) == "function")

btnSave.Activated:Connect(function()
    if not HAS_FS then
        notify("❌ Нет файловой системы", Color3.fromRGB(255, 100, 100), 2)
        return
    end
    local ok = pcall(function()
        local data = {}
        for k, v in pairs(SETTINGS) do
            if type(v) ~= "userdata" and type(v) ~= "function" then
                data[k] = v
            end
        end
        writefile(SAVE_FILE, HttpService:JSONEncode(data))
    end)
    if ok then
        btnSave.Text = "✅ Сохранено!"
        task.wait(1.5)
        btnSave.Text = "💾 Сохранить настройки"
        notify("💾 Настройки сохранены", Color3.fromRGB(160, 255, 180), 2)
    else
        notify("❌ Ошибка сохранения", Color3.fromRGB(255, 100, 100), 2)
    end
end)

btnLoad.Activated:Connect(function()
    if not HAS_FS or not isfile(SAVE_FILE) then
        notify("❌ Нет сохранения", Color3.fromRGB(255, 100, 100), 2)
        return
    end
    pcall(function()
        local data = HttpService:JSONDecode(readfile(SAVE_FILE))
        for k, v in pairs(data) do
            if SETTINGS[k] ~= nil then SETTINGS[k] = v end
        end
        notify("📂 Настройки загружены", Color3.fromRGB(180, 220, 255), 2)
    end)
end)

btnReset.Activated:Connect(function()
    SETTINGS.AntiFling      = true
    SETTINGS.AntiVoid       = true
    SETTINGS.AntiTeleport   = true
    SETTINGS.AntiKnockback  = true
    SETTINGS.AntiFreeze     = true
    SETTINGS.AntiAnchor     = true
    SETTINGS.AntiInstantKill= true
    SETTINGS.AntiDropKick   = true
    SETTINGS.AntiExplosion  = true
    SETTINGS.AntiSuperRing  = true
    SETTINGS.AntiHomelander = true
    SETTINGS.AntiGrab       = true
    SETTINGS.AntiRagdoll    = true
    SETTINGS.AntiKillaura   = true
    SETTINGS.NoFallDamage   = true
    SETTINGS.AutoHeal       = false
    SETTINGS.LockPosition   = false
    SETTINGS.VisualSphere   = false
    SETTINGS.IntrusionDetect= true
    DODGE.Enabled           = false
    TROLLING.Enabled        = true
    REVERSE.Enabled         = false
    if sphereModel then sphereModel:Destroy(); sphereModel = nil; spherePart = nil end
    notify("🔄 Сброс выполнен", Color3.fromRGB(255, 180, 180), 2)
end)

btnUnload.Activated:Connect(function()
    pcall(function() GENV._ORBIT_AC_UNLOAD() end)
end)

-- ==================== ВЫГРУЗКА ====================
GENV._ORBIT_AC_UNLOAD = function()
    disableProtection()
    if sphereModel then pcall(function() sphereModel:Destroy() end) end
    if screen then pcall(function() screen:Destroy() end) end
    if soundFolder then pcall(function() soundFolder:Destroy() end) end
    GENV._ORBIT_AC_LOADED = nil
    GENV._ORBIT_AC_UNLOAD = nil
    GENV._ORBIT_AC_NOTIFY = nil
    print("[OrbitAC] Выгружен")
end

-- ==================== ОБНОВЛЕНИЕ СТАТИСТИКИ ====================
task.spawn(function()
    while screen and screen.Parent do
        task.wait(0.5)
        local elapsed = tick() - SESSION.startTime
        local min = math.floor(elapsed / 60)
        local sec = math.floor(elapsed % 60)
        statsLabel.Text = string.format(
            "🛡️ Защит: %d\n🥷 Уворотов: %d\n🚨 Вторжений: %d\n🚩 Читеров: %d\n⏱️ Сессия: %d:%02d",
            SESSION.defenses,
            SESSION.dodges,
            SESSION.intrusions,
            SESSION.cheatersMarked,
            min, sec
        )
        btnList.Text = "📋 Список читеров: " .. SESSION.cheatersMarked
        if SETTINGS.VisualSphere then updateSphere() end
    end
end)

-- ==================== ГОРЯЧАЯ КЛАВИША ====================
UIS.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.K then
        if GENV._ORBIT_AC_TOGGLE then GENV._ORBIT_AC_TOGGLE() end
    end
end)

GENV._ORBIT_AC_TOGGLE = function()
    SETTINGS.Enabled = not SETTINGS.Enabled
    if SETTINGS.Enabled then
        btnToggle.Text = "🟢 ВКЛЮЧЕНО"
        btnToggle.TextColor3 = Color3.fromRGB(0,255,120)
        btnToggle.BackgroundColor3 = Color3.fromRGB(40,50,40)
        enableProtection()
    else
        btnToggle.Text = "🔴 ВЫКЛЮЧЕНО"
        btnToggle.TextColor3 = Color3.fromRGB(255,80,80)
        btnToggle.BackgroundColor3 = Color3.fromRGB(50,35,40)
        disableProtection()
        if sphereModel then sphereModel:Destroy(); sphereModel = nil; spherePart = nil end
    end
end

-- ==================== АВТОЗАПУСК ====================
task.spawn(function()
    task.wait(1)
    notify("🛡 ОРБИТА АНТИ-ЧИТ v12.0", Color3.fromRGB(255, 200, 200), 3)
    task.wait(0.3)
    notify("🆕 Anti-Homelander / Grab / Ragdoll / Killaura", Color3.fromRGB(255, 220, 180), 3)
    task.wait(0.3)
    notify("🎮 K — вкл/выкл защиту", Color3.fromRGB(200, 220, 255), 3)
end)

print("[Orbit Anti-Cheat v12.0] ═══════════════════════════")
print("[Orbit Anti-Cheat v12.0] Автономный скрипт запущен ✅")
print("[Orbit Anti-Cheat v12.0] Anti-Homelander + Anti-Grab + Anti-Ragdoll + Anti-Killaura")
print("[Orbit Anti-Cheat v12.0] ═══════════════════════════")

return true
