--[[ ═══════════════════════════════════════════════════════════
     ORBIT ANTI-CHEAT v11.0 — УСИЛЕННАЯ ЗАЩИТА
     ═══════════════════════════════════════════════════════════
     НЕ зависит от ОРБИТЫ
     
     🆕 НОВОЕ в v11.0:
     - Улучшенный Auto-Dodge (реагирует на игроков рядом)
     - Агрессивный Anti-Fling (пороги в 5 раз ниже)
     - Звуки Санса и смеха при спасении и отбитии атак
     - Новый детект троллинга (detectTroll)
     - Исправлен бесконечный Smart Floor
     
     Запуск:
     loadstring(game:HttpGet("https://raw.githubusercontent.com/y7hdyvdmr/my-orbit-script/refs/heads/main/orbit_anticheat.lua"))()
     ═══════════════════════════════════════════════════════════ ]]

local GENV = rawget(_G, "getgenv") and getgenv() or _G
if GENV._ORBIT_AC_LOADED then
    warn("[Orbit AC] Уже запущен! Выгружаю старый...")
    pcall(function() GENV._ORBIT_AC_UNLOAD() end)
end
GENV._ORBIT_AC_LOADED = true

local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local Workspace    = game:GetService("Workspace")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local LocalPlayer  = Players.LocalPlayer
local PlayerGui    = LocalPlayer:WaitForChild("PlayerGui")

-- ==================== БЕЗОПАСНЫЙ PARENT ====================
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
    Enabled           = false,
    SoundEnabled      = true,

    -- Защита
    AntiFling         = true,
    AntiVoid          = true,
    AntiTeleport      = true,
    AntiKnockback     = true,
    AntiFreeze        = true,
    AntiAnchor        = true,
    AntiInstantKill   = true,
    AntiDropKick      = true,
    AntiExplosion     = true,
    DisableFallDamage = true,

    -- Утилиты
    AutoHeal          = false,
    AutoHealValue     = 100,
    LockPosition      = false,

    -- Auto-Dodge / Troll
    DodgeEnabled      = false,
    DetectTroll       = true,   -- 🆕 Детект троллинга

    -- Reverse Fling
    ReverseFlingEnabled = false,

    -- Детект
    DetectSpeedHack   = true,
    DetectGodMode     = true,

    -- Smart Floor
    SmartFloorY       = 5,

    -- Настройки UI
    UIButtonPos       = UDim2.new(0, 20, 0, 200),
}

local SESSION = {
    protectionsTriggered = 0,
    dodgesMade = 0,
    cheatersTagged = 0,
    startTime = tick(),
}

local TAGGED = {}
local CHEATERS_LOG = {}

-- ==================== ЗВУКИ ====================
local sfxFolder = Instance.new("Folder")
sfxFolder.Name = "OrbitAC_Sfx_" .. tostring(math.random(100000, 999999))
sfxFolder.Parent = SoundService

local SOUND_IDS = {
    click       = "rbxasset://sounds/button.wav",
    switch      = "rbxasset://sounds/switch.wav",
    ping        = "rbxasset://sounds/electronicpingshort.wav",
    snap        = "rbxasset://sounds/snap.mp3",
    dodge       = "rbxassetid://140721035016341",
    afterDodge  = "rbxassetid://6325779988",
    sans        = "rbxassetid://135692693675195",
    laugh       = "rbxassetid://113650760423588",
    botCollect  = "rbxassetid://12221967",
}

local sfxTemplates = {}
for name, id in pairs(SOUND_IDS) do
    local s = Instance.new("Sound")
    s.Name = name
    s.SoundId = id
    s.Volume = 0.5
    s.Parent = sfxFolder
    sfxTemplates[name] = s
end

task.spawn(function()
    pcall(function()
        game:GetService("ContentProvider"):PreloadAsync(sfxFolder:GetChildren())
    end)
end)

local lastPlay = {}
local function playSound(name, volume, pitch)
    if not SETTINGS.SoundEnabled then return end
    local tpl = sfxTemplates[name]
    if not tpl then return end
    local now = os.clock()
    if lastPlay[name] and now - lastPlay[name] < 0.04 then return end
    lastPlay[name] = now
    pcall(function()
        local s = tpl:Clone()
        s.Volume = (volume or 1) * tpl.Volume
        s.PlaybackSpeed = pitch or 1
        s.Parent = sfxFolder
        s:Play()
        game:GetService("Debris"):AddItem(s, 6)
    end)
end

local function playClick() playSound("click", 0.5) end
local function playSwitch() playSound("switch", 0.5) end
local function playPing() playSound("ping", 0.5) end

-- 🆕 Полная последовательность: Санс + смех + уворот
local function playSansDodge()
    if not SETTINGS.SoundEnabled then return end
    playSound("dodge", 1, 1)
    task.delay(0.3, function() playSound("afterDodge", 1, 1) end)
    task.delay(0.6, function()
        pcall(function()
            local char = LocalPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if not hum then return end
            hum:PlayEmote("Laugh")
            task.delay(2, function()
                pcall(function()
                    local animator = hum:FindFirstChildOfClass("Animator")
                    if not animator then return end
                    for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                        local nm = track.Animation and track.Animation.Name or ""
                        if nm:lower():find("laugh") or nm:lower():find("emote") then
                            track:Stop(0)
                        end
                    end
                end)
            end)
        end)
        playSound("sans", 1, 1)
        task.delay(0.15, function() playSound("laugh", 0.8, 1) end)
    end)
end

-- 🆕 Звук при спасении (Smart Floor) — теперь тоже с Сансом
local function playSmartFloorSound()
    if not SETTINGS.SoundEnabled then return end
    playSansDodge()
end

-- 🆕 Звук при пометке читера
local function playCheaterTagSound()
    if not SETTINGS.SoundEnabled then return end
    playSound("ping", 0.4, 0.8)
end

-- ==================== СОСТОЯНИЕ ====================
local STATE = {
    lastSafePos = nil, lastSafeCFrame = nil, lastCheckTime = 0, lastHealTime = 0,
    lastHealth = 100, lastKnockTime = 0, lastFreezeTime = 0, spawnGrace = 0,
    lastHealthCheck = 0, lastScan = 0, lastPositions = {}, godmodeWarned = {},
    voidTimer = 0, lastFloorCheck = 0, lastHRP = nil, dropkickWarned = {},
    cframeJumpCounter = 0, blockedFlingCount = 0, groundTimer = 0, charConn = nil,
    lastSmartFloor = 0,
}

local CFG = {
    MAX_WALKSPEED = 60, MAX_JUMPPOWER = 100,
    -- 🆕 Агрессивные пороги Anti-Fling
    FLING_VEL_THRESHOLD = 200, FLING_SPIN_THRESHOLD = 100,
    FLING_INSTANT_THRESHOLD = 100000,
    TELEPORT_DETECT_DIST = 30,
    VOID_TIMER_THRESHOLD = 0.5,
    VOID_FAST_FALL_VY = -50,
    FLOOR_RAY_LENGTH = 500, FLOOR_RAY_SIDE = 100,
    GROUND_MIN_TIME = 1.0,
    SMART_FLOOR_COOLDOWN = 3,
}

local BAD_CLASSES = {
    BodyVelocity=true, BodyForce=true, BodyAngularVelocity=true,
    BodyGyro=true, BodyPosition=true, BodyThrust=true,
    LinearVelocity=true, AngularVelocity=true, VectorForce=true,
    Torque=true, AlignPosition=true, AlignOrientation=true,
}

-- 🆕 Улучшенный Auto-Dodge
local DODGE = {
    Enabled = false,
    ScanRadius = 25,        -- Радиус поиска угроз
    SpeedThreshold = 25,    -- Порог скорости угрозы
    DodgeDist = 15,         -- Дистанция уворота
    Cooldown = 0.35,        -- Кулдаун между уворотами
    LastDodge = 0,
}

-- 🆕 Детект троллинга
local TROLL = {
    Enabled = true,
    LastScan = 0,
    WarnCooldown = {},
}

local REVERSE = {
    Enabled = false, RotateLimit = 20 * 2 * math.pi, FlingForce = 500,
    LastCheck = 0, CheckInterval = 0.3, Detected = {},
}

local ORIG_WS, ORIG_JP = 16, 50
LocalPlayer.CharacterAdded:Connect(function(c)
    local h = c:WaitForChild("Humanoid", 5)
    if h then ORIG_WS, ORIG_JP = h.WalkSpeed, h.JumpPower end
end)

-- ==================== УТИЛИТЫ ====================
local function log(text) print("[OrbitAC] " .. text) end

local function killObject(obj)
    if not obj or not obj.Parent then return end
    pcall(function() obj:Destroy() end)
end

local function resetVelocity(char)
    if not char then return end
    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") then
            pcall(function()
                p.AssemblyLinearVelocity = Vector3.zero
                p.AssemblyAngularVelocity = Vector3.zero
            end)
        end
    end
end

local function isGrounded(hrp)
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
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Exclude
    rp.FilterDescendantsInstances = {char}
    local ray = Workspace:Raycast(hrp.Position, Vector3.new(0, -4, 0), rp)
    return ray ~= nil
end

local function isAirborne(hrp)
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

local function getSafeFloorPosition()
    local char = LocalPlayer.Character
    if not char then return nil end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Exclude
    rp.FilterDescendantsInstances = {char, Workspace.CurrentCamera}
    local origin = hrp.Position + Vector3.new(0, 20, 0)
    local ray = Workspace:Raycast(origin, Vector3.new(0, -CFG.FLOOR_RAY_LENGTH, 0), rp)
    if ray then return ray.Position + Vector3.new(0, 4, 0) end
    local dirs = {
        Vector3.new(0, -CFG.FLOOR_RAY_SIDE, 30),
        Vector3.new(0, -CFG.FLOOR_RAY_SIDE, -30),
        Vector3.new(30, -CFG.FLOOR_RAY_SIDE, 0),
        Vector3.new(-30, -CFG.FLOOR_RAY_SIDE, 0),
    }
    for _, dir in ipairs(dirs) do
        local sideRay = Workspace:Raycast(origin, dir, rp)
        if sideRay then return sideRay.Position + Vector3.new(0, 4, 0) end
    end
    if STATE.lastSafeCFrame then
        local p = STATE.lastSafeCFrame.Position
        return Vector3.new(p.X, math.max(p.Y, 10), p.Z)
    end
    return Vector3.new(0, 50, 0)
end

local function disableFallDamage(char)
    if not SETTINGS.DisableFallDamage then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    pcall(function()
        hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
    end)
end

-- ==================== ФУНКЦИИ ЗАЩИТЫ ====================
local function antiDropKick(char, hrp, now)
    if not SETTINGS.AntiDropKick then return end
    local curCF = hrp.CFrame
    if STATE.lastHRP then
        local dist = (curCF.Position - STATE.lastHRP.Position).Magnitude
        if dist > CFG.TELEPORT_DETECT_DIST and not isAirborne(hrp) then
            STATE.cframeJumpCounter = STATE.cframeJumpCounter + 1
            if STATE.cframeJumpCounter >= 2 then
                if STATE.lastSafeCFrame then
                    pcall(function()
                        char:PivotTo(STATE.lastSafeCFrame)
                        resetVelocity(char)
                    end)
                    SESSION.protectionsTriggered = SESSION.protectionsTriggered + 1
                    STATE.blockedFlingCount = STATE.blockedFlingCount + 1
                    playSansDodge() -- 🆕 Звук при отбитии DropKick
                end
                STATE.cframeJumpCounter = 0
            end
        else
            STATE.cframeJumpCounter = 0
        end
    end
    STATE.lastHRP = curCF
    if hrp.Anchored and not isAirborne(hrp) then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum and hum.MoveDirection.Magnitude > 0.05 then
            pcall(function() hrp.Anchored = false end)
            SESSION.protectionsTriggered = SESSION.protectionsTriggered + 1
        end
    end
end

local function antiFling(char, hrp)
    if not SETTINGS.AntiFling then return end
    if isAirborne(hrp) then return end
    pcall(function()
        local vel = hrp.AssemblyLinearVelocity.Magnitude
        local spin = hrp.AssemblyAngularVelocity.Magnitude
        if vel > CFG.FLING_INSTANT_THRESHOLD or spin > CFG.FLING_INSTANT_THRESHOLD then
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
            if STATE.lastSafeCFrame then pcall(function() char:PivotTo(STATE.lastSafeCFrame) end) end
            SESSION.protectionsTriggered = SESSION.protectionsTriggered + 1
            playSansDodge() -- 🆕 Звук при мгновенном флинге
            return
        end
        -- 🆕 Агрессивный порог
        if vel > CFG.FLING_VEL_THRESHOLD and spin > CFG.FLING_SPIN_THRESHOLD then
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
            SESSION.protectionsTriggered = SESSION.protectionsTriggered + 1
            playSansDodge() -- 🆕 Звук при обычном флинге
        end
    end)
    -- 🆕 Детект флинга у других (уведомление)
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end
        local pChar = plr.Character
        if not pChar then continue end
        local pHrp = pChar:FindFirstChild("HumanoidRootPart")
        if not pHrp then continue end
        local pSpin = pHrp.AssemblyAngularVelocity.Magnitude
        local pVel = pHrp.AssemblyLinearVelocity.Magnitude
        if pSpin > CFG.FLING_SPIN_THRESHOLD * 2 or pVel > CFG.FLING_VEL_THRESHOLD * 2 then
            if not STATE.dropkickWarned[plr] then
                STATE.dropkickWarned[plr] = tick()
                tagCheater(plr, true)
            end
        end
    end
end

local function antiFreeze(char)
    if not SETTINGS.AntiFreeze then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        pcall(function()
            if hum.WalkSpeed < 1 then hum.WalkSpeed = ORIG_WS end
            if hum.JumpPower < 1 then hum.JumpPower = ORIG_JP end
            local animator = hum:FindFirstChildOfClass("Animator")
            if animator then
                for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                    local name = track.Animation and track.Animation.Name or ""
                    if name:lower():find("laugh") then track:Stop(0) end
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
        if BAD_CLASSES[child.ClassName] then killObject(child) end
    end
end

local function antiAnchor(char)
    if not SETTINGS.AntiAnchor then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if hrp and hrp.Anchored then
        pcall(function() hrp.Anchored = false end)
        SESSION.protectionsTriggered = SESSION.protectionsTriggered + 1
    end
end

local function antiInstantKill(char)
    if not SETTINGS.AntiInstantKill then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local now = tick()
    if isGrounded(hrp)
        and STATE.lastHealth > 50
        and hum.Health < 10
        and (now - (STATE.lastHealthCheck or 0)) < 0.15 then
        if STATE.lastSafeCFrame then
            pcall(function() char:PivotTo(STATE.lastSafeCFrame) end)
            resetVelocity(char)
            SESSION.protectionsTriggered = SESSION.protectionsTriggered + 1
        end
    end
    STATE.lastHealth = hum.Health
    STATE.lastHealthCheck = now
end

-- 🆕 Улучшенный Anti-Void с кулдауном
local function antiVoid(char, hrp, dt)
    if not SETTINGS.AntiVoid then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return end

    if isGrounded(hrp) then
        STATE.voidTimer = 0
        return
    end

    local vy = hrp.AssemblyLinearVelocity.Y
    local y = hrp.Position.Y
    local falling = false

    if y < -100 then
        falling = true
    elseif vy < CFG.VOID_FAST_FALL_VY then
        local rp = RaycastParams.new()
        rp.FilterType = Enum.RaycastFilterType.Exclude
        rp.FilterDescendantsInstances = {char}
        local ray = Workspace:Raycast(hrp.Position, Vector3.new(0, -CFG.FLOOR_RAY_LENGTH, 0), rp)
        if not ray then
            falling = true
        end
    end

    if not falling then
        STATE.voidTimer = 0
        return
    end

    local now = tick()
    if now - (STATE.lastSmartFloor or 0) < CFG.SMART_FLOOR_COOLDOWN then
        STATE.voidTimer = 0
        return
    end

    STATE.voidTimer = STATE.voidTimer + (dt or 0.1)
    if STATE.voidTimer > CFG.VOID_TIMER_THRESHOLD then
        local safePos = getSafeFloorPosition()
        if safePos and safePos.Y > y + 3 then
            STATE.lastSmartFloor = now
            pcall(function()
                char:PivotTo(CFrame.new(safePos))
                resetVelocity(char)
            end)
            warn("[OrbitAC] Smart Floor спас с Y=" .. math.floor(y))
            playSmartFloorSound() -- 🆕 Санс + смех
            notify("🛡 Smart Floor спас!", Color3.fromRGB(120, 255, 180), 2)
            SESSION.protectionsTriggered = SESSION.protectionsTriggered + 1
        end
        STATE.voidTimer = 0
    end
end

local function antiTeleport(char, hrp)
    if not SETTINGS.AntiTeleport then return end
    if not STATE.lastSafePos then return end
    if not isGrounded(hrp) then return end
    if STATE.groundTimer < CFG.GROUND_MIN_TIME then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum and hum.MoveDirection.Magnitude > 0.05 then return end
    local dx = hrp.Position.X - STATE.lastSafePos.X
    local dz = hrp.Position.Z - STATE.lastSafePos.Z
    local horizDist = math.sqrt(dx * dx + dz * dz)
    if horizDist > 250 then
        pcall(function() char:PivotTo(STATE.lastSafeCFrame + Vector3.new(0, 2, 0)) end)
        resetVelocity(char)
        SESSION.protectionsTriggered = SESSION.protectionsTriggered + 1
    end
end

local function autoHeal(char)
    if not SETTINGS.AutoHeal then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum and hum.Health < hum.MaxHealth and hum.Health > 0 then
        pcall(function() hum.Health = math.min(hum.MaxHealth, hum.Health + SETTINGS.AutoHealValue) end)
    end
end

local function lockPosition(char, hrp)
    if not SETTINGS.LockPosition then return end
    if not isGrounded(hrp) then return end
    if STATE.groundTimer < CFG.GROUND_MIN_TIME then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum and hum.MoveDirection.Magnitude > 0.05 then return end
    if STATE.lastSafeCFrame then pcall(function() char:PivotTo(STATE.lastSafeCFrame) end) end
end

-- ==================== AUTO-DODGE ====================
local dodgeConn = nil
local dodgeParams = OverlapParams.new()
dodgeParams.FilterType = Enum.RaycastFilterType.Exclude
local lastDodgeScan = 0

local function setupAutoDodge()
    if dodgeConn then dodgeConn:Disconnect(); dodgeConn = nil end
    dodgeConn = RunService.Heartbeat:Connect(function(dt)
        if not SETTINGS.Enabled or not DODGE.Enabled then return end
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        if isAirborne(hrp) then return end

        local now = tick()
        if now - DODGE.LastDodge < DODGE.Cooldown then return end
        if now - lastDodgeScan < 0.05 then return end
        lastDodgeScan = now
        dodgeParams.FilterDescendantsInstances = {char}

        local threats = {}
        local myPos = hrp.Position

        -- 🆕 Поиск угроз (объекты и игроки)
        local parts = Workspace:GetPartBoundsInRadius(myPos, DODGE.ScanRadius, dodgeParams)
        for _, obj in ipairs(parts) do
            if obj:IsA("BasePart") and obj.Parent ~= char then
                -- Объект
                if not obj.Anchored then
                    local vel = obj.AssemblyLinearVelocity
                    if vel.Magnitude > DODGE.SpeedThreshold then
                        local toMe = (myPos - obj.Position)
                        if toMe.Magnitude > 0.1 and vel.Unit:Dot(toMe.Unit) > 0.4 then
                            table.insert(threats, { obj = obj, dist = toMe.Magnitude })
                        end
                    end
                end
                -- 🆕 Другой игрок
                local parentChar = obj.Parent
                if parentChar and parentChar:IsA("Model") and parentChar ~= char then
                    local pHum = parentChar:FindFirstChildOfClass("Humanoid")
                    if pHum and pHum.Health > 0 then
                        local pRoot = parentChar:FindFirstChild("HumanoidRootPart")
                        if pRoot then
                            local vel = pRoot.AssemblyLinearVelocity
                            local spin = pRoot.AssemblyAngularVelocity
                            -- Если игрок быстро движется или крутится рядом
                            if vel.Magnitude > DODGE.SpeedThreshold * 2 or spin.Magnitude > DODGE.SpeedThreshold then
                                table.insert(threats, { obj = pRoot, dist = toMe.Magnitude })
                            end
                        end
                    end
                end
            end
        end

        if #threats == 0 then return end
        table.sort(threats, function(a, b) return a.dist < b.dist end)
        local threat = threats[1]
        local threatDir = (threat.obj.Position - myPos).Unit
        local rightDir = threatDir:Cross(Vector3.new(0, 1, 0)).Unit

        local rp = RaycastParams.new()
        rp.FilterType = Enum.RaycastFilterType.Exclude
        rp.FilterDescendantsInstances = {char, Workspace.CurrentCamera}
        local rayRight = Workspace:Raycast(myPos, rightDir * DODGE.DodgeDist, rp)
        local dodgeDir = rayRight and -rightDir or rightDir
        local targetPos = myPos + dodgeDir * DODGE.DodgeDist
        local rayDown = Workspace:Raycast(targetPos + Vector3.new(0, 5, 0), Vector3.new(0, -10, 0), rp)
        if rayDown then targetPos = rayDown.Position + Vector3.new(0, 3, 0) end

        pcall(function()
            char:PivotTo(CFrame.new(targetPos))
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end)
        DODGE.LastDodge = now
        SESSION.dodgesMade = SESSION.dodgesMade + 1
        playSansDodge() -- 🆕 Санс + смех + уворот
        notify("🥷 Уклонение!", Color3.fromRGB(150, 220, 255), 1.5)
    end)
end

-- ==================== ДЕТЕКТ ТРОЛЛИНГА ====================
local function detectTroll(dt, char, hrp)
    if not SETTINGS.Enabled or not TROLL.Enabled then return end
    local now = tick()
    if now - TROLL.LastScan < 0.2 then return end
    TROLL.LastScan = now

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end
        local pChar = plr.Character
        if not pChar then continue end
        local pHrp = pChar:FindFirstChild("HumanoidRootPart")
        if not pHrp then continue end

        local dist = (pHrp.Position - hrp.Position).Magnitude
        if dist < 8 then
            local pVel = pHrp.AssemblyLinearVelocity.Magnitude
            local pSpin = pHrp.AssemblyAngularVelocity.Magnitude

            if pVel > 40 or pSpin > 20 then
                if not TROLL.WarnCooldown[plr] or now - TROLL.WarnCooldown[plr] > 3 then
                    TROLL.WarnCooldown[plr] = now
                    playSansDodge() -- 🆕 Санс + смех
                    notify("⚠️ Троллинг: " .. plr.Name, Color3.fromRGB(255, 150, 150), 2)
                end
            end
        end
    end
end

-- ==================== REVERSE FLING ====================
local function reverseFlingPlayer(player)
    if not player or player == LocalPlayer then return end
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    pcall(function()
        hrp.AssemblyAngularVelocity = Vector3.new(
            math.random(-1, 1) * 1000, math.random(-1, 1) * 1000, math.random(-1, 1) * 1000)
        hrp.AssemblyLinearVelocity = Vector3.new(0, REVERSE.FlingForce, 0)
    end)
    log("🚨 REVERSE FLING: " .. player.Name)
end

local function scanForFlingers()
    if not REVERSE.Enabled then return end
    local now = tick()
    if now - REVERSE.LastCheck < REVERSE.CheckInterval then return end
    REVERSE.LastCheck = now
    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        local char = player.Character
        if not char then continue end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then continue end
        local aav = hrp.AssemblyAngularVelocity
        if math.abs(aav.X) > REVERSE.RotateLimit
            or math.abs(aav.Y) > REVERSE.RotateLimit
            or math.abs(aav.Z) > REVERSE.RotateLimit then
            if not REVERSE.Detected[player] then
                REVERSE.Detected[player] = now
                reverseFlingPlayer(player)
            end
        end
    end
    for p, t in pairs(REVERSE.Detected) do
        if now - t > 5 then REVERSE.Detected[p] = nil end
    end
end

function tagCheater(player, enable)
    if not player or player == LocalPlayer then return false end
    if enable then
        TAGGED[player] = true
        CHEATERS_LOG[player.UserId] = { name = player.Name, time = os.time() }
        SESSION.cheatersTagged = SESSION.cheatersTagged + 1
        warn("[OrbitAC] Помечен: " .. player.Name)
        playCheaterTagSound()
        notify("🚩 Помечен: " .. player.Name, Color3.fromRGB(255, 120, 120))
    else
        TAGGED[player] = nil
        CHEATERS_LOG[player.UserId] = nil
    end
    return true
end

function toggleTagCheater(player)
    return tagCheater(player, not TAGGED[player])
end

function isTagged(player) return TAGGED[player] == true end

-- ==================== ОСНОВНОЙ ЦИКЛ ====================
local function processProtection(dt, char, hrp)
    local now = tick()
    local airborne = isAirborne(hrp)

    if isGrounded(hrp) then
        STATE.groundTimer = STATE.groundTimer + dt
    else
        STATE.groundTimer = 0
    end

    antiDropKick(char, hrp, now)
    antiFling(char, hrp)
    antiAnchor(char)

    if now - STATE.lastKnockTime >= 0.1 then
        STATE.lastKnockTime = now
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

    local inGrace = (now - STATE.spawnGrace) < 5.0
    if not inGrace and not airborne then
        antiTeleport(char, hrp)
        lockPosition(char, hrp)
    end

    antiInstantKill(char)

    -- 🆕 Детект троллинга
    pcall(detectTroll, dt, char, hrp)

    if now - STATE.lastScan > 0.5 then
        STATE.lastScan = now
        if SETTINGS.DetectSpeedHack then
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer then
                    local char2 = player.Character
                    if char2 then
                        local hrp2 = char2:FindFirstChild("HumanoidRootPart")
                        if hrp2 then
                            local last = STATE.lastPositions[player]
                            if last then
                                local dt2 = now - last.time
                                if dt2 > 0.1 and dt2 < 1 then
                                    local speed = (hrp2.Position - last.pos).Magnitude / dt2
                                    if speed > 150 then
                                        tagCheater(player, true)
                                    end
                                end
                            end
                            STATE.lastPositions[player] = { pos = hrp2.Position, time = now }
                        end
                    end
                end
            end
        end
        pcall(scanForFlingers)
    end

    if now - STATE.lastCheckTime > 0.2 then
        STATE.lastCheckTime = now
        local hum = char:FindFirstChildOfClass("Humanoid")
        local vy = math.abs(hrp.AssemblyLinearVelocity.Y)
        if hum and hum.Health > 0
            and not airborne
            and vy < 1.0
            and isGrounded(hrp) then
            STATE.lastSafePos = hrp.Position
            local lv = hrp.CFrame.LookVector
            local yaw = math.atan2(-lv.X, -lv.Z)
            STATE.lastSafeCFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, yaw, 0)
        end
    end
end

local protConn = nil

local function enableProtection()
    if protConn then protConn:Disconnect(); protConn = nil end
    if not SETTINGS.Enabled then return end

    STATE.lastSafePos = nil; STATE.lastSafeCFrame = nil
    STATE.lastCheckTime = 0; STATE.lastHealTime = 0
    STATE.lastHealth = 100; STATE.lastKnockTime = 0
    STATE.lastFreezeTime = 0; STATE.spawnGrace = tick()
    STATE.lastPositions = {}; STATE.godmodeWarned = {}
    STATE.voidTimer = 0; STATE.lastFloorCheck = 0
    STATE.lastHRP = nil; STATE.cframeJumpCounter = 0
    STATE.dropkickWarned = {}; STATE.blockedFlingCount = 0
    STATE.groundTimer = 0; STATE.lastSmartFloor = 0

    if LocalPlayer.Character then
        antiKnockback(LocalPlayer.Character)
        disableFallDamage(LocalPlayer.Character)
    end

    if STATE.charConn then STATE.charConn:Disconnect() end
    STATE.charConn = LocalPlayer.CharacterAdded:Connect(function(newChar)
        STATE.lastHRP = nil
        STATE.spawnGrace = tick()
        STATE.lastSafePos = nil; STATE.lastSafeCFrame = nil
        STATE.groundTimer = 0; STATE.lastSmartFloor = 0
        task.wait(0.5)
        disableFallDamage(newChar)
    end)

    setupAutoDodge()

    protConn = RunService.Heartbeat:Connect(function(dt)
        if not SETTINGS.Enabled then return end
        local char = LocalPlayer.Character
        if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        pcall(processProtection, dt, char, hrp)
    end)

    notify("🛡 Anti-Cheat v11.0 ВКЛ", Color3.fromRGB(120, 255, 180), 3)
    log("Anti-Cheat v11.0 активен.")
end

local function disableProtection()
    if STATE.charConn then STATE.charConn:Disconnect(); STATE.charConn = nil end
    if protConn then protConn:Disconnect(); protConn = nil end
    if dodgeConn then dodgeConn:Disconnect(); dodgeConn = nil end
    STATE.lastSafePos = nil; STATE.lastSafeCFrame = nil
end

Workspace.DescendantAdded:Connect(function(inst)
    if not SETTINGS.Enabled or not SETTINGS.AntiExplosion then return end
    if inst:IsA("Explosion") then
        task.defer(function() pcall(function() inst:Destroy() end) end)
    end
end)

-- ==================== UI ====================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "_OrbitAC_" .. tostring(math.random(100000, 999999))
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 9999
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
protectGui(screenGui)
local okp = pcall(function() screenGui.Parent = getSafeParent() end)
if not okp or not screenGui.Parent then screenGui.Parent = PlayerGui end

local mainBtn = Instance.new("TextButton")
mainBtn.Size = UDim2.new(0, 56, 0, 56)
mainBtn.Position = SETTINGS.UIButtonPos
mainBtn.BackgroundColor3 = Color3.fromRGB(40, 20, 20)
mainBtn.BackgroundTransparency = 0.1
mainBtn.TextColor3 = Color3.fromRGB(255, 180, 180)
mainBtn.Font = Enum.Font.GothamBold
mainBtn.TextSize = 24
mainBtn.Text = "🛡"
mainBtn.AutoButtonColor = false
mainBtn.Parent = screenGui
Instance.new("UICorner", mainBtn).CornerRadius = UDim.new(0, 14)
local mainStroke = Instance.new("UIStroke", mainBtn)
mainStroke.Color = Color3.fromRGB(255, 100, 100)
mainStroke.Thickness = 1.5

local panel = Instance.new("ScrollingFrame")
panel.Size = UDim2.new(0, 300, 0, 600)
panel.Position = UDim2.new(0, 90, 0, 60)
panel.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
panel.BackgroundTransparency = 0.15
panel.BorderSizePixel = 0
panel.Visible = false
panel.CanvasSize = UDim2.new(0, 0, 0, 1500)
panel.ScrollBarThickness = 4
panel.ScrollBarImageColor3 = Color3.fromRGB(255, 100, 100)
panel.Parent = screenGui
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
title.Text = "🛡  ORBIT ANTI-CHEAT v11.0"
title.TextColor3 = Color3.fromRGB(255, 200, 200)
title.Font = Enum.Font.GothamBold
title.TextSize = 15
title.Parent = panel

local function makeSection(text, y, color)
    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, -20, 0, 28)
    holder.Position = UDim2.new(0, 10, 0, y)
    holder.BackgroundColor3 = color or Color3.fromRGB(80, 40, 40)
    holder.BackgroundTransparency = 0.35
    holder.BorderSizePixel = 0
    holder.Parent = panel
    Instance.new("UICorner", holder).CornerRadius = UDim.new(0, 8)
    local stripe = Instance.new("Frame")
    stripe.Size = UDim2.new(0, 4, 1, -8)
    stripe.Position = UDim2.new(0, 4, 0, 4)
    stripe.BackgroundColor3 = color or Color3.fromRGB(255, 100, 100)
    stripe.BorderSizePixel = 0
    stripe.Parent = holder
    Instance.new("UICorner", stripe).CornerRadius = UDim.new(0, 2)
    local s = Instance.new("TextLabel")
    s.Size = UDim2.new(1, -14, 1, 0)
    s.Position = UDim2.new(0, 12, 0, 0)
    s.BackgroundTransparency = 1
    s.Text = text
    s.TextColor3 = Color3.fromRGB(240, 240, 255)
    s.Font = Enum.Font.GothamBold
    s.TextSize = 13
    s.TextXAlignment = Enum.TextXAlignment.Left
    s.Parent = holder
end

local function makeButton(text, y, h, bgColor, textColor)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, -20, 0, h or 32)
    b.Position = UDim2.new(0, 10, 0, y)
    b.BackgroundColor3 = bgColor or Color3.fromRGB(45, 45, 62)
    b.TextColor3 = textColor or Color3.fromRGB(235, 235, 255)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 12
    b.Text = text
    b.AutoButtonColor = true
    b.Parent = panel
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
    local stroke = Instance.new("UIStroke", b)
    stroke.Color = bgColor or Color3.fromRGB(80, 80, 120)
    stroke.Thickness = 1
    stroke.Transparency = 0.65
    b.MouseButton1Down:Connect(playClick)
    b.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then playClick() end
    end)
    return b
end

makeSection("⚡  ОСНОВНОЕ", 42, Color3.fromRGB(80, 40, 40))
local toggleBtn = makeButton("🔴 ВЫКЛЮЧЕНО", 74, 36, Color3.fromRGB(50, 35, 40), Color3.fromRGB(255, 80, 80))

makeSection("📊  СТАТИСТИКА", 118, Color3.fromRGB(60, 60, 90))
local statsLabel = Instance.new("TextLabel")
statsLabel.Size = UDim2.new(1, -20, 0, 90)
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

makeSection("🛡️  ЗАЩИТА", 248, Color3.fromRGB(60, 100, 60))
local antiFlingBtn    = makeButton("🛡️ Anti-Fling: ВКЛ", 280, 30, Color3.fromRGB(35,50,35), Color3.fromRGB(160,255,160))
local antiVoidBtn     = makeButton("🛡️ Anti-Void: ВКЛ", 314, 30, Color3.fromRGB(35,50,35), Color3.fromRGB(160,255,160))
local antiTpBtn       = makeButton("🛡️ Anti-Teleport: ВКЛ", 348, 30, Color3.fromRGB(35,50,35), Color3.fromRGB(160,255,160))
local antiKbBtn       = makeButton("🛡️ Anti-Knockback: ВКЛ", 382, 30, Color3.fromRGB(35,50,35), Color3.fromRGB(160,255,160))
local antiFrzBtn      = makeButton("🛡️ Anti-Freeze: ВКЛ", 416, 30, Color3.fromRGB(35,50,35), Color3.fromRGB(160,255,160))
local antiDropBtn     = makeButton("🛡️ Anti-DropKick: ВКЛ", 450, 30, Color3.fromRGB(35,50,35), Color3.fromRGB(160,255,160))
local antiKillBtn     = makeButton("🛡️ Anti-InstantKill: ВКЛ", 484, 30, Color3.fromRGB(35,50,35), Color3.fromRGB(160,255,160))
local antiExpBtn      = makeButton("🛡️ Anti-Explosion: ВКЛ", 518, 30, Color3.fromRGB(35,50,35), Color3.fromRGB(160,255,160))
local noFallDmgBtn    = makeButton("🛡️ No Fall Damage: ВКЛ", 552, 30, Color3.fromRGB(35,50,35), Color3.fromRGB(160,255,160))

makeSection("💚  УТИЛИТЫ", 594, Color3.fromRGB(80, 100, 60))
local autoHealBtn = makeButton("💚 Auto-Heal: ВЫКЛ", 626, 30, Color3.fromRGB(35,50,35), Color3.fromRGB(160,255,160))
local lockPosBtn  = makeButton("📍 Lock Position: ВЫКЛ", 660, 30, Color3.fromRGB(35,50,35), Color3.fromRGB(160,255,160))

makeSection("🥷  ДОП. ЗАЩИТА", 702, Color3.fromRGB(80, 60, 130))
local dodgeBtn   = makeButton("🥷 Auto-Dodge: ВЫКЛ", 734, 32, Color3.fromRGB(50,50,50), Color3.fromRGB(200,200,200))
local trollBtn   = makeButton("👁️ Детект троллинга: ВКЛ", 770, 30, Color3.fromRGB(50,60,80), Color3.fromRGB(200,220,255))
local reverseBtn = makeButton("🚨 Reverse Fling: ВЫКЛ", 802, 30, Color3.fromRGB(60,30,30), Color3.fromRGB(255,150,150))

makeSection("👁️  ДЕТЕКТ ЧИТЕРОВ", 844, Color3.fromRGB(100, 60, 60))
local speedHackBtn = makeButton("⚡ Speed-Hack детект: ВКЛ", 876, 30, Color3.fromRGB(50,40,40), Color3.fromRGB(255,180,180))
local godModeBtn   = makeButton("👁️ GodMode детект: ВКЛ", 910, 30, Color3.fromRGB(50,40,40), Color3.fromRGB(255,180,180))
local listCheatersBtn = makeButton("📋 Список читеров: 0", 944, 28, Color3.fromRGB(60,35,45), Color3.fromRGB(255,180,220))

makeSection("🔊  ЗВУКИ", 984, Color3.fromRGB(70, 80, 110))
local soundBtn = makeButton("🔊 Звуки: ВКЛ", 1016, 30, Color3.fromRGB(35,60,45), Color3.fromRGB(180,255,180))
local testSfxBtn = makeButton("🎵 Проверить звуки", 1050, 30, Color3.fromRGB(50,60,90), Color3.fromRGB(200,220,255))

makeSection("💾  СИСТЕМА", 1092, Color3.fromRGB(60, 60, 80))
local saveBtn  = makeButton("💾 Сохранить настройки", 1124, 30, Color3.fromRGB(35,60,45), Color3.fromRGB(160,255,180))
local loadBtn  = makeButton("📂 Загрузить настройки", 1158, 30, Color3.fromRGB(35,50,60), Color3.fromRGB(180,220,255))
local resetBtn = makeButton("🔄 Сбросить всё", 1192, 30, Color3.fromRGB(50,30,30), Color3.fromRGB(255,180,180))
local unloadBtn = makeButton("❌ ВЫГРУЗИТЬ", 1226, 32, Color3.fromRGB(80,30,30), Color3.fromRGB(255,140,140))

panel.CanvasSize = UDim2.new(0, 0, 0, 1277)

-- ==================== УВЕДОМЛЕНИЯ ====================
local notifHolder = Instance.new("Frame")
notifHolder.Size = UDim2.new(0, 300, 0.4, 0)
notifHolder.Position = UDim2.new(1, -320, 0.15, 0)
notifHolder.BackgroundTransparency = 1
notifHolder.Parent = screenGui

local notifLayout = Instance.new("UIListLayout")
notifLayout.SortOrder = Enum.SortOrder.LayoutOrder
notifLayout.Padding = UDim.new(0, 6)
notifLayout.VerticalAlignment = Enum.VerticalAlignment.Top
notifLayout.Parent = notifHolder

local notifCounter = 0
function notify(text, color, duration)
    duration = duration or 2
    color = color or Color3.fromRGB(140, 255, 200)
    notifCounter = notifCounter + 1

    local slot = Instance.new("Frame")
    slot.Size = UDim2.new(1, 0, 0, 40)
    slot.BackgroundTransparency = 1
    slot.LayoutOrder = notifCounter
    slot.Parent = notifHolder

    local slots = {}
    for _, c in ipairs(notifHolder:GetChildren()) do
        if c:IsA("Frame") then table.insert(slots, c) end
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

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -16, 1, 0)
    label.Position = UDim2.new(0, 8, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = color
    label.Font = Enum.Font.GothamBold
    label.TextSize = 13
    label.TextWrapped = true
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

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

-- ==================== ОБРАБОТЧИКИ КНОПОК ====================
local dragging, dragMoved = false, false
local dragStart, startPos

mainBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch
       or input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragMoved = false
        dragStart = input.Position
        startPos = mainBtn.Position
    end
end)

game:GetService("UserInputService").InputChanged:Connect(function(input)
    if not dragging then return end
    if input.UserInputType == Enum.UserInputType.Touch
       or input.UserInputType == Enum.UserInputType.MouseMovement then
        local d = input.Position - dragStart
        if d.Magnitude > 6 then dragMoved = true end
        if dragMoved then
            local abs = screenGui.AbsoluteSize
            mainBtn.Position = UDim2.fromOffset(
                math.clamp(startPos.X.Offset + d.X, 0, math.max(0, abs.X - 56)),
                math.clamp(startPos.Y.Offset + d.Y, 0, math.max(0, abs.Y - 56))
            )
        end
    end
end)

game:GetService("UserInputService").InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch
       or input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)

local panelOpen = false
local function setPanel(open)
    panelOpen = open
    playSwitch()
    if open then
        local abs = screenGui.AbsoluteSize
        panel.Size = UDim2.fromOffset(300, math.clamp(abs.Y - 40, 200, 700))
        panel.Position = UDim2.fromOffset(
            math.clamp(mainBtn.Position.X.Offset + 70, 0, math.max(0, abs.X - 310)), 20)
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

mainBtn.Activated:Connect(function()
    if dragMoved then dragMoved = false; return end
    setPanel(not panelOpen)
end)

toggleBtn.Activated:Connect(function()
    SETTINGS.Enabled = not SETTINGS.Enabled
    playSwitch()
    if SETTINGS.Enabled then
        toggleBtn.Text = "🟢 ВКЛЮЧЕНО"
        toggleBtn.TextColor3 = Color3.fromRGB(0,255,120)
        toggleBtn.BackgroundColor3 = Color3.fromRGB(40,50,40)
        enableProtection()
    else
        toggleBtn.Text = "🔴 ВЫКЛЮЧЕНО"
        toggleBtn.TextColor3 = Color3.fromRGB(255,80,80)
        toggleBtn.BackgroundColor3 = Color3.fromRGB(50,35,40)
        disableProtection()
        notify("🔴 Anti-Cheat ВЫКЛ", Color3.fromRGB(255,100,100), 2)
    end
end)

antiFlingBtn.Activated:Connect(function() SETTINGS.AntiFling = not SETTINGS.AntiFling; antiFlingBtn.Text = "🛡️ Anti-Fling: " .. (SETTINGS.AntiFling and "ВКЛ" or "ВЫКЛ") end)
antiVoidBtn.Activated:Connect(function() SETTINGS.AntiVoid = not SETTINGS.AntiVoid; antiVoidBtn.Text = "🛡️ Anti-Void: " .. (SETTINGS.AntiVoid and "ВКЛ" or "ВЫКЛ") end)
antiTpBtn.Activated:Connect(function() SETTINGS.AntiTeleport = not SETTINGS.AntiTeleport; antiTpBtn.Text = "🛡️ Anti-Teleport: " .. (SETTINGS.AntiTeleport and "ВКЛ" or "ВЫКЛ") end)
antiKbBtn.Activated:Connect(function() SETTINGS.AntiKnockback = not SETTINGS.AntiKnockback; antiKbBtn.Text = "🛡️ Anti-Knockback: " .. (SETTINGS.AntiKnockback and "ВКЛ" or "ВЫКЛ") end)
antiFrzBtn.Activated:Connect(function() SETTINGS.AntiFreeze = not SETTINGS.AntiFreeze; antiFrzBtn.Text = "🛡️ Anti-Freeze: " .. (SETTINGS.AntiFreeze and "ВКЛ" or "ВЫКЛ") end)
antiDropBtn.Activated:Connect(function() SETTINGS.AntiDropKick = not SETTINGS.AntiDropKick; antiDropBtn.Text = "🛡️ Anti-DropKick: " .. (SETTINGS.AntiDropKick and "ВКЛ" or "ВЫКЛ") end)
antiKillBtn.Activated:Connect(function() SETTINGS.AntiInstantKill = not SETTINGS.AntiInstantKill; antiKillBtn.Text = "🛡️ Anti-InstantKill: " .. (SETTINGS.AntiInstantKill and "ВКЛ" or "ВЫКЛ") end)
antiExpBtn.Activated:Connect(function() SETTINGS.AntiExplosion = not SETTINGS.AntiExplosion; antiExpBtn.Text = "🛡️ Anti-Explosion: " .. (SETTINGS.AntiExplosion and "ВКЛ" or "ВЫКЛ") end)
noFallDmgBtn.Activated:Connect(function() SETTINGS.DisableFallDamage = not SETTINGS.DisableFallDamage; noFallDmgBtn.Text = "🛡️ No Fall Damage: " .. (SETTINGS.DisableFallDamage and "ВКЛ" or "ВЫКЛ") end)

autoHealBtn.Activated:Connect(function() SETTINGS.AutoHeal = not SETTINGS.AutoHeal; autoHealBtn.Text = "💚 Auto-Heal: " .. (SETTINGS.AutoHeal and "ВКЛ" or "ВЫКЛ") end)
lockPosBtn.Activated:Connect(function() SETTINGS.LockPosition = not SETTINGS.LockPosition; lockPosBtn.Text = "📍 Lock Position: " .. (SETTINGS.LockPosition and "ВКЛ" or "ВЫКЛ") end)

dodgeBtn.Activated:Connect(function()
    DODGE.Enabled = not DODGE.Enabled
    dodgeBtn.Text = "🥷 Auto-Dodge: " .. (DODGE.Enabled and "ВКЛ" or "ВЫКЛ")
    dodgeBtn.BackgroundColor3 = DODGE.Enabled and Color3.fromRGB(60,80,50) or Color3.fromRGB(50,50,50)
end)
trollBtn.Activated:Connect(function()
    TROLL.Enabled = not TROLL.Enabled
    trollBtn.Text = "👁️ Детект троллинга: " .. (TROLL.Enabled and "ВКЛ" or "ВЫКЛ")
end)
reverseBtn.Activated:Connect(function()
    REVERSE.Enabled = not REVERSE.Enabled
    reverseBtn.Text = "🚨 Reverse Fling: " .. (REVERSE.Enabled and "ВКЛ" or "ВЫКЛ")
    reverseBtn.BackgroundColor3 = REVERSE.Enabled and Color3.fromRGB(100,30,30) or Color3.fromRGB(60,30,30)
end)

speedHackBtn.Activated:Connect(function() SETTINGS.DetectSpeedHack = not SETTINGS.DetectSpeedHack; speedHackBtn.Text = "⚡ Speed-Hack детект: " .. (SETTINGS.DetectSpeedHack and "ВКЛ" or "ВЫКЛ") end)
godModeBtn.Activated:Connect(function() SETTINGS.DetectGodMode = not SETTINGS.DetectGodMode; godModeBtn.Text = "👁️ GodMode детект: " .. (SETTINGS.DetectGodMode and "ВКЛ" or "ВЫКЛ") end)

listCheatersBtn.Activated:Connect(function()
    local list = {}
    for p in pairs(TAGGED) do
        if p and p.Parent then table.insert(list, p.Name) end
    end
    if #list == 0 then
        notify("📋 Читеров не найдено", Color3.fromRGB(200, 200, 255), 3)
    else
        notify("📋 Читеры: " .. table.concat(list, ", "), Color3.fromRGB(255, 180, 220), 5)
    end
end)

soundBtn.Activated:Connect(function()
    SETTINGS.SoundEnabled = not SETTINGS.SoundEnabled
    soundBtn.Text = "🔊 Звуки: " .. (SETTINGS.SoundEnabled and "ВКЛ" or "ВЫКЛ")
    if SETTINGS.SoundEnabled then playSwitch() end
end)

testSfxBtn.Activated:Connect(function()
    testSfxBtn.Text = "⏳ Проигрываю..."
    task.wait(0.1)
    playClick()
    task.wait(0.5)
    playSansDodge()
    task.wait(2.5)
    testSfxBtn.Text = "✅ Готово"
    task.wait(2)
    testSfxBtn.Text = "🎵 Проверить звуки"
end)

local SAVE_FILE = "orbit_ac_settings.json"
local HAS_FS = (writefile and readfile and isfile and type(writefile) == "function")

local function serializeSettings()
    local data = {}
    for k, v in pairs(SETTINGS) do
        if type(v) ~= "userdata" and type(v) ~= "function" then
            data[k] = v
        end
    end
    return data
end

saveBtn.Activated:Connect(function()
    if not HAS_FS then
        notify("❌ Нет файловой системы", Color3.fromRGB(255, 100, 100), 2)
        return
    end
    local ok = pcall(function()
        writefile(SAVE_FILE, game:GetService("HttpService"):JSONEncode(serializeSettings()))
    end)
    if ok then
        saveBtn.Text = "✅ Сохранено!"
        task.wait(1.5)
        saveBtn.Text = "💾 Сохранить настройки"
        notify("💾 Настройки сохранены", Color3.fromRGB(160, 255, 180), 2)
    else
        notify("❌ Ошибка сохранения", Color3.fromRGB(255, 100, 100), 2)
    end
end)

loadBtn.Activated:Connect(function()
    if not HAS_FS or not isfile(SAVE_FILE) then
        notify("❌ Нет сохранения", Color3.fromRGB(255, 100, 100), 2)
        return
    end
    pcall(function()
        local data = game:GetService("HttpService"):JSONDecode(readfile(SAVE_FILE))
        for k, v in pairs(data) do
            if SETTINGS[k] ~= nil then SETTINGS[k] = v end
        end
        notify("📂 Настройки загружены", Color3.fromRGB(180, 220, 255), 2)
    end)
end)

resetBtn.Activated:Connect(function()
    SETTINGS.AntiFling = true
    SETTINGS.AntiVoid = true
    SETTINGS.AntiTeleport = true
    SETTINGS.AntiKnockback = true
    SETTINGS.AntiFreeze = true
    SETTINGS.AntiAnchor = true
    SETTINGS.AntiInstantKill = true
    SETTINGS.AntiDropKick = true
    SETTINGS.AntiExplosion = true
    SETTINGS.DisableFallDamage = true
    SETTINGS.AutoHeal = false
    SETTINGS.LockPosition = false
    DODGE.Enabled = false
    TROLL.Enabled = true
    REVERSE.Enabled = false
    notify("🔄 Сброс выполнен", Color3.fromRGB(255, 180, 180), 2)
end)

unloadBtn.Activated:Connect(function()
    pcall(function() GENV._ORBIT_AC_UNLOAD() end)
end)

-- ==================== UNLOAD ====================
GENV._ORBIT_AC_UNLOAD = function()
    disableProtection()
    if screenGui then pcall(function() screenGui:Destroy() end) end
    if sfxFolder then pcall(function() sfxFolder:Destroy() end) end
    GENV._ORBIT_AC_LOADED = nil
    GENV._ORBIT_AC_UNLOAD = nil
    GENV._ORBIT_AC_NOTIFY = nil
    print("[OrbitAC] Выгружен")
end

-- ==================== ОБНОВЛЕНИЕ СТАТИСТИКИ ====================
task.spawn(function()
    while screenGui and screenGui.Parent do
        task.wait(0.5)
        local elapsed = tick() - SESSION.startTime
        local mins = math.floor(elapsed / 60)
        local secs = math.floor(elapsed % 60)
        statsLabel.Text = string.format(
            "🛡️ Защит: %d\n🥷 Уворотов: %d\n🚩 Читеров: %d\n⏱️ Сессия: %d:%02d",
            SESSION.protectionsTriggered,
            SESSION.dodgesMade,
            SESSION.cheatersTagged,
            mins, secs
        )
        listCheatersBtn.Text = "📋 Список читеров: " .. SESSION.cheatersTagged
    end
end)

-- ==================== ГОРЯЧАЯ КЛАВИША ====================
game:GetService("UserInputService").InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.K then
        if GENV._ORBIT_AC_TOGGLE then GENV._ORBIT_AC_TOGGLE() end
    end
end)

GENV._ORBIT_AC_TOGGLE = function()
    SETTINGS.Enabled = not SETTINGS.Enabled
    if SETTINGS.Enabled then
        toggleBtn.Text = "🟢 ВКЛЮЧЕНО"
        toggleBtn.TextColor3 = Color3.fromRGB(0,255,120)
        toggleBtn.BackgroundColor3 = Color3.fromRGB(40,50,40)
        enableProtection()
    else
        toggleBtn.Text = "🔴 ВЫКЛЮЧЕНО"
        toggleBtn.TextColor3 = Color3.fromRGB(255,80,80)
        toggleBtn.BackgroundColor3 = Color3.fromRGB(50,35,40)
        disableProtection()
    end
end

-- ==================== АВТОЗАПУСК ====================
task.spawn(function()
    task.wait(1)
    notify("🛡 ORBIT ANTI-CHEAT v11.0 загружен", Color3.fromRGB(255, 200, 200), 3)
    task.wait(0.3)
    notify("🔧 Улучшения: Auto-Dodge, Anti-Fling, Троллинг", Color3.fromRGB(160, 255, 180), 3)
    task.wait(0.3)
    notify("🎮 K — вкл/выкл защиту", Color3.fromRGB(200, 220, 255), 3)
end)

print("[Orbit Anti-Cheat v11.0] ═══════════════════════════")
print("[Orbit Anti-Cheat v11.0] Автономный скрипт запущен ✅")
print("[Orbit Anti-Cheat v11.0] Улучшенная защита от Homelander-скриптов")
print("[Orbit Anti-Cheat v11.0] ═══════════════════════════")

return true
