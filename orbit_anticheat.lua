--[[ ═══════════════════════════════════════════════════════════════
     ОРБИТА АНТИ-ЧИТ v11.2 — ПОЛНАЯ ВЕРСИЯ НА РУССКОМ
     ═══════════════════════════════════════════════════════════════
     НЕ зависит от ОРБИТЫ
     
     🆕 Что нового:
     - Визуальная сфера (видна только тебе)
     - ДЕТЕКТ ВТОРЖЕНИЯ — игрок зашёл в сферу → уведомление + звук
     - Anti-SuperRing (удаляет AlignPosition/Torque)
     - Очередь звуков (без наложения)
     - Улучшенный Умный Пол
     
     ⚠️ ВАЖНО:
     Физический барьер для ДРУГИХ игроков из клиента невозможен.
     Сфера работает как радиус детекта — мы отслеживаем вход игроков.
     
     Запуск:
     loadstring(game:HttpGet("https://raw.githubusercontent.com/y7hdyvdmr/my-orbit-script/refs/heads/main/orbit_anticheat.lua"))()
     ═══════════════════════════════════════════════════════════════ ]]

-- ==================== ЗАЩИТА ОТ ПОВТОРНОГО ЗАПУСКА ====================
local GENV = rawget(_G, "getgenv") and getgenv() or _G
if GENV._ORBIT_AC_LOADED then
    warn("[Orbit AC] Уже запущен! Выгружаю старый...")
    pcall(function() GENV._ORBIT_AC_UNLOAD() end)
end
GENV._ORBIT_AC_LOADED = true

-- ==================== СЕРВИСЫ ====================
local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local Workspace    = game:GetService("Workspace")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local LocalPlayer  = Players.LocalPlayer
local PlayerGui    = LocalPlayer:WaitForChild("PlayerGui")

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
local НАСТРОЙКИ = {
    Включено           = false,
    Звуки              = true,

    -- Защита
    АнтиФлинг          = true,
    АнтиПустота        = true,
    АнтиТелепорт       = true,
    АнтиОтбрасывание   = true,
    АнтиЗаморозка      = true,
    АнтиЯкорь          = true,
    АнтиМгновСмерть    = true,
    АнтиДропКик        = true,
    АнтиВзрыв          = true,
    АнтиСуперКольцо    = true,
    УбратьУронПадения  = true,

    -- Утилиты
    АвтоЛечение       = false,
    СилаЛечения        = 100,
    БлокировкаПозиции  = false,

    -- Визуал
    ВизуальнаяСфера    = false,
    РазмерСферы        = 8,
    ДетектВторжения    = true,   -- 🆕 Следим за входом в сферу

    -- Уклонение
    Уклонение          = false,
    ДетектТроллинга    = true,

    -- Ответный флинг
    ОтветныйФлинг      = false,

    -- Детект
    ДетектСкорости     = true,
    ДетектGodMode      = true,

    -- Умный пол
    УмныйПол           = 5,

    -- UI
    ПозицияКнопки      = UDim2.new(0, 20, 0, 200),
}

-- ==================== СТАТИСТИКА СЕССИИ ====================
local СЕССИЯ = {
    защитСработало = 0,
    уворотов = 0,
    читеровПомечено = 0,
    вторжений = 0,        -- 🆕 сколько раз кто-то входил в сферу
    начало = tick(),
}

local ПОМЕЧЕННЫЕ = {}
local ЛОГ_ЧИТЕРОВ = {}

-- ==================== ЗВУКИ ====================
local папкаЗвуков = Instance.new("Folder")
папкаЗвуков.Name = "OrbitAC_Sfx_" .. tostring(math.random(100000, 999999))
папкаЗвуков.Parent = SoundService

local ID_ЗВУКОВ = {
    клик        = "rbxasset://sounds/button.wav",
    переключатель = "rbxasset://sounds/switch.wav",
    сигнал      = "rbxasset://sounds/electronicpingshort.wav",
    щелчок      = "rbxasset://sounds/snap.mp3",
    уворот      = "rbxassetid://140721035016341",
    послеУворота = "rbxassetid://6325779988",
    санс        = "rbxassetid://135692693675195",
    смех        = "rbxassetid://113650760423588",
    бот         = "rbxassetid://12221967",
    вторжение   = "rbxassetid://12221967",  -- 🆕 звук при входе в сферу
}

local шаблоныЗвуков = {}
for имя, id in pairs(ID_ЗВУКОВ) do
    local s = Instance.new("Sound")
    s.Name = имя
    s.SoundId = id
    s.Volume = 0.5
    s.Parent = папкаЗвуков
    шаблоныЗвуков[имя] = s
end

task.spawn(function()
    pcall(function()
        game:GetService("ContentProvider"):PreloadAsync(папкаЗвуков:GetChildren())
    end)
end)

-- ==================== ОЧЕРЕДЬ ЗВУКОВ ====================
-- Звуки не накладываются — каждый ждёт окончания предыдущего
local ОЧЕРЕДЬ = {
    Играет = false,
    Список = {},
}

local function проигратьЗвук(имя, громкость, питч)
    if not НАСТРОЙКИ.Звуки then return end
    local шаблон = шаблоныЗвуков[имя]
    if not шаблон then return end

    table.insert(ОЧЕРЕДЬ.Список, {
        имя = имя,
        громкость = громкость or 1,
        питч = питч or 1,
    })

    if not ОЧЕРЕДЬ.Играет then
        task.spawn(function()
            ОЧЕРЕДЬ.Играет = true
            while #ОЧЕРЕДЬ.Список > 0 do
                local эл = table.remove(ОЧЕРЕДЬ.Список, 1)
                local t = шаблоныЗвуков[эл.имя]
                if t then
                    pcall(function()
                        local s = t:Clone()
                        s.Volume = (эл.громкость or 1) * t.Volume
                        s.PlaybackSpeed = эл.питч or 1
                        s.Parent = папкаЗвуков
                        s:Play()
                        game:GetService("Debris"):AddItem(s, 8)
                        local длит = math.min(s.TimeLength > 0 and s.TimeLength or 0.5, 3)
                        task.wait(длит)
                    end)
                end
            end
            ОЧЕРЕДЬ.Играет = false
        end)
    end
end

local function звякКлик() проигратьЗвук("клик", 0.5) end
local function звякПереключатель() проигратьЗвук("переключатель", 0.5) end
local function звякСигнал() проигратьЗвук("сигнал", 0.5) end

-- Полная последовательность уворота: уворот → после → Санс → смех
local function звякУворотСанса()
    if not НАСТРОЙКИ.Звуки then return end
    проигратьЗвук("уворот", 1, 1)
    проигратьЗвук("послеУворота", 1, 1)
    проигратьЗвук("санс", 1, 1)
    проигратьЗвук("смех", 0.8, 1)

    pcall(function()
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum:PlayEmote("Laugh")
            task.delay(2, function()
                pcall(function()
                    local animator = hum:FindFirstChildOfClass("Animator")
                    if animator then
                        for _, трек in ipairs(animator:GetPlayingAnimationTracks()) do
                            local им = трек.Animation and трек.Animation.Name or ""
                            if им:lower():find("laugh") or им:lower():find("emote") then
                                трек:Stop(0)
                            end
                        end
                    end
                end)
            end)
        end
    end)
end

local function звякУмныйПол()
    if not НАСТРОЙКИ.Звуки then return end
    звякУворотСанса()
end

local function звякВторжение()
    if not НАСТРОЙКИ.Звуки then return end
    проигратьЗвук("вторжение", 0.7, 1.5)
end

local function звякПометкаЧитера()
    if not НАСТРОЙКИ.Звуки then return end
    проигратьЗвук("сигнал", 0.4, 0.8)
end

-- ==================== ВИЗУАЛЬНАЯ СФЕРА ====================
local модельСферы = nil
local частьСферы = nil

local function создатьСферу()
    if модельСферы then модельСферы:Destroy() end
    модельСферы = Instance.new("Model")
    модельСферы.Name = "OrbitAC_Сфера"
    модельСферы.Parent = Workspace

    частьСферы = Instance.new("Part")
    частьСферы.Name = "Сфера"
    частьСферы.Shape = Enum.PartType.Ball
    частьСферы.Size = Vector3.new(НАСТРОЙКИ.РазмерСферы, НАСТРОЙКИ.РазмерСферы, НАСТРОЙКИ.РазмерСферы)
    частьСферы.Material = Enum.Material.ForceField
    частьСферы.Color = Color3.fromRGB(0, 150, 255)
    частьСферы.Transparency = 0.5
    частьСферы.Anchored = true
    частьСферы.CanCollide = false
    частьСферы.CastShadow = false
    частьСферы.CanQuery = false
    частьСферы.CanTouch = false
    частьСферы.Parent = модельСферы
end

local function обновитьСферу()
    if not НАСТРОЙКИ.ВизуальнаяСфера then
        if модельСферы then модельСферы:Destroy(); модельСферы = nil; частьСферы = nil end
        return
    end
    if not частьСферы or not частьСферы.Parent then
        создатьСферу()
    end
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hrp and частьСферы then
        частьСферы.CFrame = hrp.CFrame
    end
end

-- ==================== ДЕТЕКТ ВТОРЖЕНИЯ ====================
-- 🆕 Следим за игроками, которые входят в радиус сферы
local СЛЕЖКА_ВТОРЖЕНИЙ = {
    ПоследняяПроверка = 0,
    Кулдаун = {},
    БылиВнутри = {},
}

local function проверитьВторжение()
    if not НАСТРОЙКИ.Включено or not НАСТРОЙКИ.ДетектВторжения then return end
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local сейчас = tick()
    local радиус = НАСТРОЙКИ.РазмерСферы / 2

    for _, игрок in ipairs(Players:GetPlayers()) do
        if игрок == LocalPlayer then continue end
        local чужой = игрок.Character
        if not чужой then continue end
        local чужойHrp = чужой:FindFirstChild("HumanoidRootPart")
        if not чужойHrp then continue end

        local дист = (чужойHrp.Position - hrp.Position).Magnitude
        local внутри = дист <= радиус

        -- Если игрок только что вошёл
        if внутри and not СЛЕЖКА_ВТОРЖЕНИЙ.БылиВнутри[игрок] then
            СЛЕЖКА_ВТОРЖЕНИЙ.БылиВнутри[игрок] = true
            СЕССИЯ.вторжений = СЕССИЯ.вторжений + 1

            if not СЛЕЖКА_ВТОРЖЕНИЙ.Кулдаун[игрок] or сейчас - СЛЕЖКА_ВТОРЖЕНИЙ.Кулдаун[игрок] > 5 then
                СЛЕЖКА_ВТОРЖЕНИЙ.Кулдаун[игрок] = сейчас
                звякВторжение()
                уведомить("⚠️ Вторжение: " .. игрок.Name, Color3.fromRGB(255, 150, 150), 2)
                print("[OrbitAC] 🚨 Вторжение: " .. игрок.Name .. " (дист: " .. math.floor(дист) .. ")")

                -- Если Авто-Уклонение включено — отходим
                if НАСТРОЙКИ.Уклонение and СЛЕЖКА_ВТОРЖЕНИЙ.Кулдаун[игрок] then
                    -- отходим от игрока в противоположную сторону
                    local отход = (hrp.Position - чужойHrp.Position).Unit
                    local цель = hrp.Position + отход * 12
                    pcall(function()
                        char:PivotTo(CFrame.new(цель))
                        hrp.AssemblyLinearVelocity = Vector3.zero
                        hrp.AssemblyAngularVelocity = Vector3.zero
                    end)
                end
            end
        elseif not внутри and СЛЕЖКА_ВТОРЖЕНИЙ.БылиВнутри[игрок] then
            СЛЕЖКА_ВТОРЖЕНИЙ.БылиВнутри[игрок] = nil
        end
    end
end

-- ==================== СОСТОЯНИЕ ====================
local СОСТОЯНИЕ = {
    последняяБезопаснаяПозиция = nil,
    последнийБезопасныйCFrame = nil,
    времяПроверки = 0,
    времяЛечения = 0,
    последнееЗдоровье = 100,
    времяОтбрасывания = 0,
    времяЗаморозки = 0,
    льготныйСпавн = 0,
    последняяПроверкаЗдоровья = 0,
    последняяСкан = 0,
    последниеПозиции = {},
    предупреждениеGodMode = {},
    таймерПустоты = 0,
    последняяПроверкаПола = 0,
    последнийHRP = nil,
    предупреждениеДропКик = {},
    счётчикСкачков = 0,
    заблокированныхФлингов = 0,
    времяЗемли = 0,
    подключениеПерсонажа = nil,
    последнийУмныйПол = 0,
}

local КОНФИГ = {
    МАКС_СКОРОСТЬ = 60, МАКС_ПРЫЖОК = 100,
    ПОРОГ_ФЛИНГ_СКОРОСТЬ = 200, ПОРОГ_ФЛИНГ_ВРАЩЕНИЕ = 100,
    МГНОВЕННЫЙ_ФЛИНГ = 100000,
    ДИСТАНЦИЯ_ТЕЛЕПОРТА = 30,
    ТАЙМЕР_ПУСТОТЫ = 0.5,
    БЫСТРОЕ_ПАДЕНИЕ_VY = -50,
    ЛУЧ_ПОЛА_ДЛИНА = 500, ЛУЧ_ПОЛА_ВСТОРОНЫ = 100,
    МИН_ВРЕМЯ_НА_ЗЕМЛЕ = 1.0,
    КУЛДАУН_УМНОГО_ПОЛА = 3,
}

local ПЛОХИЕ_КЛАССЫ = {
    BodyVelocity=true, BodyForce=true, BodyAngularVelocity=true,
    BodyGyro=true, BodyPosition=true, BodyThrust=true,
    LinearVelocity=true, AngularVelocity=true, VectorForce=true,
    Torque=true, AlignPosition=true, AlignOrientation=true,
}

-- ==================== УТИЛИТЫ ====================
local function лог(текст) print("[OrbitAC] " .. текст) end

local function удалитьОбъект(объект)
    if not объект or not объект.Parent then return end
    pcall(function() объект:Destroy() end)
end

local function обнулитьСкорость(char)
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

local function наЗемле(hrp)
    if not hrp then return false end
    local char = hrp.Parent
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return false end
    local vy = math.abs(hrp.AssemblyLinearVelocity.Y)
    if vy > 0.5 then return false end
    local состояние = hum:GetState()
    if состояние ~= Enum.HumanoidStateType.Running
       and состояние ~= Enum.HumanoidStateType.RunningNoPhysics
       and состояние ~= Enum.HumanoidStateType.Seated
       and состояние ~= Enum.HumanoidStateType.PlatformStanding
       and состояние ~= Enum.HumanoidStateType.Climbing then return false end
    local пар = RaycastParams.new()
    пар.FilterType = Enum.RaycastFilterType.Exclude
    пар.FilterDescendantsInstances = {char}
    local луч = Workspace:Raycast(hrp.Position, Vector3.new(0, -4, 0), пар)
    return луч ~= nil
end

local function вВоздухе(hrp)
    if not hrp then return false end
    local char = hrp.Parent
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return false end
    local состояние = hum:GetState()
    return состояние == Enum.HumanoidStateType.Jumping
        or состояние == Enum.HumanoidStateType.Freefall
        or состояние == Enum.HumanoidStateType.Flying
end

local function получитьБезопасныйПол()
    local char = LocalPlayer.Character
    if not char then return nil end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    local пар = RaycastParams.new()
    пар.FilterType = Enum.RaycastFilterType.Exclude
    пар.FilterDescendantsInstances = {char, Workspace.CurrentCamera}
    local origin = hrp.Position + Vector3.new(0, 20, 0)
    local луч = Workspace:Raycast(origin, Vector3.new(0, -КОНФИГ.ЛУЧ_ПОЛА_ДЛИНА, 0), пар)
    if луч then return луч.Position + Vector3.new(0, 4, 0) end
    local направления = {
        Vector3.new(0, -КОНФИГ.ЛУЧ_ПОЛА_ВСТОРОНЫ, 30),
        Vector3.new(0, -КОНФИГ.ЛУЧ_ПОЛА_ВСТОРОНЫ, -30),
        Vector3.new(30, -КОНФИГ.ЛУЧ_ПОЛА_ВСТОРОНЫ, 0),
        Vector3.new(-30, -КОНФИГ.ЛУЧ_ПОЛА_ВСТОРОНЫ, 0),
    }
    for _, напр in ipairs(направления) do
        local лучБок = Workspace:Raycast(origin, напр, пар)
        if лучБок then return лучБок.Position + Vector3.new(0, 4, 0) end
    end
    if СОСТОЯНИЕ.последнийБезопасныйCFrame then
        local p = СОСТОЯНИЕ.последнийБезопасныйCFrame.Position
        return Vector3.new(p.X, math.max(p.Y, 10), p.Z)
    end
    return Vector3.new(0, 50, 0)
end

local function отключитьУронПадения(char)
    if not НАСТРОЙКИ.УбратьУронПадения then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    pcall(function()
        hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
    end)
end

-- ==================== ФУНКЦИИ ЗАЩИТЫ ====================
local function антиДропКик(char, hrp, сейчас)
    if not НАСТРОЙКИ.АнтиДропКик then return end
    local текущий = hrp.CFrame
    if СОСТОЯНИЕ.последнийHRP then
        local дист = (текущий.Position - СОСТОЯНИЕ.последнийHRP.Position).Magnitude
        if дист > КОНФИГ.ДИСТАНЦИЯ_ТЕЛЕПОРТА and not вВоздухе(hrp) then
            СОСТОЯНИЕ.счётчикСкачков = СОСТОЯНИЕ.счётчикСкачков + 1
            if СОСТОЯНИЕ.счётчикСкачков >= 2 then
                if СОСТОЯНИЕ.последнийБезопасныйCFrame then
                    pcall(function()
                        char:PivotTo(СОСТОЯНИЕ.последнийБезопасныйCFrame)
                        обнулитьСкорость(char)
                    end)
                    СЕССИЯ.защитСработало = СЕССИЯ.защитСработало + 1
                    СОСТОЯНИЕ.заблокированныхФлингов = СОСТОЯНИЕ.заблокированныхФлингов + 1
                    звякУворотСанса()
                end
                СОСТОЯНИЕ.счётчикСкачков = 0
            end
        else
            СОСТОЯНИЕ.счётчикСкачков = 0
        end
    end
    СОСТОЯНИЕ.последнийHRP = текущий
    if hrp.Anchored and not вВоздухе(hrp) then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum and hum.MoveDirection.Magnitude > 0.05 then
            pcall(function() hrp.Anchored = false end)
            СЕССИЯ.защитСработало = СЕССИЯ.защитСработало + 1
        end
    end
end

local function антиФлинг(char, hrp)
    if not НАСТРОЙКИ.АнтиФлинг then return end
    if вВоздухе(hrp) then return end
    pcall(function()
        local скор = hrp.AssemblyLinearVelocity.Magnitude
        local вращ = hrp.AssemblyAngularVelocity.Magnitude
        if скор > КОНФИГ.МГНОВЕННЫЙ_ФЛИНГ or вращ > КОНФИГ.МГНОВЕННЫЙ_ФЛИНГ then
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
            if СОСТОЯНИЕ.последнийБезопасныйCFrame then pcall(function() char:PivotTo(СОСТОЯНИЕ.последнийБезопасныйCFrame) end) end
            СЕССИЯ.защитСработало = СЕССИЯ.защитСработало + 1
            звякУворотСанса()
            return
        end
        if скор > КОНФИГ.ПОРОГ_ФЛИНГ_СКОРОСТЬ and вращ > КОНФИГ.ПОРОГ_ФЛИНГ_ВРАЩЕНИЕ then
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
            СЕССИЯ.защитСработало = СЕССИЯ.защитСработало + 1
            звякУворотСанса()
        end
    end)
    -- Детект у других игроков
    for _, игрок in ipairs(Players:GetPlayers()) do
        if игрок == LocalPlayer then continue end
        local чужой = игрок.Character
        if not чужой then continue end
        local чужойHrp = чужой:FindFirstChild("HumanoidRootPart")
        if not чужойHrp then continue end
        local чужоеВращ = чужойHrp.AssemblyAngularVelocity.Magnitude
        local чужаяСкор = чужойHrp.AssemblyLinearVelocity.Magnitude
        if чужоеВращ > КОНФИГ.ПОРОГ_ФЛИНГ_ВРАЩЕНИЕ * 2 or чужаяСкор > КОНФИГ.ПОРОГ_ФЛИНГ_СКОРОСТЬ * 2 then
            if not СОСТОЯНИЕ.предупреждениеДропКик[игрок] then
                СОСТОЯНИЕ.предупреждениеДропКик[игрок] = tick()
                пометитьЧитера(игрок, true)
            end
        end
    end
end

local function антиЗаморозка(char)
    if not НАСТРОЙКИ.АнтиЗаморозка then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        pcall(function()
            if hum.WalkSpeed < 1 then hum.WalkSpeed = 16 end
            if hum.JumpPower < 1 then hum.JumpPower = 50 end
            local animator = hum:FindFirstChildOfClass("Animator")
            if animator then
                for _, трек in ipairs(animator:GetPlayingAnimationTracks()) do
                    local им = трек.Animation and трек.Animation.Name or ""
                    if им:lower():find("laugh") then трек:Stop(0) end
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

local function антиОтбрасывание(char)
    if not НАСТРОЙКИ.АнтиОтбрасывание then return end
    for _, ребёнок in ipairs(char:GetDescendants()) do
        if ПЛОХИЕ_КЛАССЫ[ребёнок.ClassName] then удалитьОбъект(ребёнок) end
    end
end

local function антиЯкорь(char)
    if not НАСТРОЙКИ.АнтиЯкорь then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if hrp and hrp.Anchored then
        pcall(function() hrp.Anchored = false end)
        СЕССИЯ.защитСработало = СЕССИЯ.защитСработало + 1
    end
end

local function антиМгновСмерть(char)
    if not НАСТРОЙКИ.АнтиМгновСмерть then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local сейчас = tick()
    if наЗемле(hrp)
        and СОСТОЯНИЕ.последнееЗдоровье > 50
        and hum.Health < 10
        and (сейчас - (СОСТОЯНИЕ.последняяПроверкаЗдоровья or 0)) < 0.15 then
        if СОСТОЯНИЕ.последнийБезопасныйCFrame then
            pcall(function() char:PivotTo(СОСТОЯНИЕ.последнийБезопасныйCFrame) end)
            обнулитьСкорость(char)
            СЕССИЯ.защитСработало = СЕССИЯ.защитСработало + 1
        end
    end
    СОСТОЯНИЕ.последнееЗдоровье = hum.Health
    СОСТОЯНИЕ.последняяПроверкаЗдоровья = сейчас
end

local function антиПустота(char, hrp, dt)
    if not НАСТРОЙКИ.АнтиПустота then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return end

    if наЗемле(hrp) then
        СОСТОЯНИЕ.таймерПустоты = 0
        return
    end

    local vy = hrp.AssemblyLinearVelocity.Y
    local y = hrp.Position.Y
    local падаем = false

    if y < -100 then
        падаем = true
    elseif vy < КОНФИГ.БЫСТРОЕ_ПАДЕНИЕ_VY then
        local пар = RaycastParams.new()
        пар.FilterType = Enum.RaycastFilterType.Exclude
        пар.FilterDescendantsInstances = {char}
        local луч = Workspace:Raycast(hrp.Position, Vector3.new(0, -КОНФИГ.ЛУЧ_ПОЛА_ДЛИНА, 0), пар)
        if not луч then
            падаем = true
        end
    end

    if not падаем then
        СОСТОЯНИЕ.таймерПустоты = 0
        return
    end

    local сейчас = tick()
    if сейчас - (СОСТОЯНИЕ.последнийУмныйПол or 0) < КОНФИГ.КУЛДАУН_УМНОГО_ПОЛА then
        СОСТОЯНИЕ.таймерПустоты = 0
        return
    end

    СОСТОЯНИЕ.таймерПустоты = СОСТОЯНИЕ.таймерПустоты + (dt or 0.1)
    if СОСТОЯНИЕ.таймерПустоты > КОНФИГ.ТАЙМЕР_ПУСТОТЫ then
        local безопасно = получитьБезопасныйПол()
        if безопасно and безопасно.Y > y + 3 then
            СОСТОЯНИЕ.последнийУмныйПол = сейчас
            pcall(function()
                char:PivotTo(CFrame.new(безопасно))
                обнулитьСкорость(char)
            end)
            warn("[OrbitAC] Умный Пол спас с Y=" .. math.floor(y))
            звякУмныйПол()
            уведомить("🛡 Умный Пол спас!", Color3.fromRGB(120, 255, 180), 2)
            СЕССИЯ.защитСработало = СЕССИЯ.защитСработало + 1
        end
        СОСТОЯНИЕ.таймерПустоты = 0
    end
end

local function антиТелепорт(char, hrp)
    if not НАСТРОЙКИ.АнтиТелепорт then return end
    if not СОСТОЯНИЕ.последняяБезопаснаяПозиция then return end
    if not наЗемле(hrp) then return end
    if СОСТОЯНИЕ.времяЗемли < КОНФИГ.МИН_ВРЕМЯ_НА_ЗЕМЛЕ then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum and hum.MoveDirection.Magnitude > 0.05 then return end
    local dx = hrp.Position.X - СОСТОЯНИЕ.последняяБезопаснаяПозиция.X
    local dz = hrp.Position.Z - СОСТОЯНИЕ.последняяБезопаснаяПозиция.Z
    local горизонт = math.sqrt(dx * dx + dz * dz)
    if горизонт > 250 then
        pcall(function() char:PivotTo(СОСТОЯНИЕ.последнийБезопасныйCFrame + Vector3.new(0, 2, 0)) end)
        обнулитьСкорость(char)
        СЕССИЯ.защитСработало = СЕССИЯ.защитСработало + 1
    end
end

local function автоЛечение(char)
    if not НАСТРОЙКИ.АвтоЛечение then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum and hum.Health < hum.MaxHealth and hum.Health > 0 then
        pcall(function() hum.Health = math.min(hum.MaxHealth, hum.Health + НАСТРОЙКИ.СилаЛечения) end)
    end
end

local function блокировкаПозиции(char, hrp)
    if not НАСТРОЙКИ.БлокировкаПозиции then return end
    if not наЗемле(hrp) then return end
    if СОСТОЯНИЕ.времяЗемли < КОНФИГ.МИН_ВРЕМЯ_НА_ЗЕМЛЕ then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum and hum.MoveDirection.Magnitude > 0.05 then return end
    if СОСТОЯНИЕ.последнийБезопасныйCFrame then pcall(function() char:PivotTo(СОСТОЯНИЕ.последнийБезопасныйCFrame) end) end
end

-- ==================== АНТИ-СУПЕРКОЛЬЦО ====================
-- Удаляет AlignPosition и Torque у чужих объектов (Super Ring V4)
local function антиСуперКольцо()
    if not НАСТРОЙКИ.АнтиСуперКольцо then return end
    task.spawn(function()
        while НАСТРОЙКИ.Включено do
            task.wait(0.2)
            for _, объект in ipairs(Workspace:GetDescendants()) do
                if объект:IsA("BasePart") and not объект.Anchored then
                    local родитель = объект.Parent
                    if родитель and родитель:IsA("Model") then
                        local hum = родитель:FindFirstChildOfClass("Humanoid")
                        if not hum then
                            for _, реб in ipairs(объект:GetChildren()) do
                                if реб:IsA("AlignPosition") or реб:IsA("Torque") then
                                    pcall(function() реб:Destroy() end)
                                end
                            end
                        end
                    else
                        for _, реб in ipairs(объект:GetChildren()) do
                            if реб:IsA("AlignPosition") or реб:IsA("Torque") then
                                pcall(function() реб:Destroy() end)
                            end
                        end
                    end
                end
            end
        end
    end)
end

-- ==================== УКЛОНЕНИЕ ====================
local подключениеУклонения = nil
local параметрыУклонения = OverlapParams.new()
параметрыУклонения.FilterType = Enum.RaycastFilterType.Exclude
local последнийСканУклонения = 0

local УКЛОНЕНИЕ = {
    Включено = false,
    Радиус = 25,
    ПорогСкорости = 25,
    Дистанция = 15,
    Кулдаун = 0.35,
    Последнее = 0,
}

local function настроитьУклонение()
    if подключениеУклонения then подключениеУклонения:Disconnect(); подключениеУклонения = nil end
    подключениеУклонения = RunService.Heartbeat:Connect(function(dt)
        if not НАСТРОЙКИ.Включено or not УКЛОНЕНИЕ.Включено then return end
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        if вВоздухе(hrp) then return end

        local сейчас = tick()
        if сейчас - УКЛОНЕНИЕ.Последнее < УКЛОНЕНИЕ.Кулдаун then return end
        if сейчас - последнийСканУклонения < 0.05 then return end
        последнийСканУклонения = сейчас
        параметрыУклонения.FilterDescendantsInstances = {char}

        local угрозы = {}
        local мояПоз = hrp.Position

        local части = Workspace:GetPartBoundsInRadius(мояПоз, УКЛОНЕНИЕ.Радиус, параметрыУклонения)
        for _, объект in ipairs(части) do
            if объект:IsA("BasePart") and объект.Parent ~= char then
                if not объект.Anchored then
                    local скор = объект.AssemblyLinearVelocity
                    if скор.Magnitude > УКЛОНЕНИЕ.ПорогСкорости then
                        local коМне = (мояПоз - объект.Position)
                        if коМне.Magnitude > 0.1 and скор.Unit:Dot(коМне.Unit) > 0.4 then
                            table.insert(угрозы, { объект = объект, дист = коМне.Magnitude })
                        end
                    end
                end
                -- Другой игрок
                local родитель = объект.Parent
                if родитель and родитель:IsA("Model") and родитель ~= char then
                    local чужойХум = родитель:FindFirstChildOfClass("Humanoid")
                    if чужойХум and чужойХум.Health > 0 then
                        local чужойRoot = родитель:FindFirstChild("HumanoidRootPart")
                        if чужойRoot then
                            local скор = чужойRoot.AssemblyLinearVelocity
                            local вращ = чужойRoot.AssemblyAngularVelocity
                            if скор.Magnitude > УКЛОНЕНИЕ.ПорогСкорости * 2 or вращ.Magnitude > УКЛОНЕНИЕ.ПорогСкорости then
                                table.insert(угрозы, { объект = чужойRoot, дист = (чужойRoot.Position - мояПоз).Magnitude })
                            end
                        end
                    end
                end
            end
        end

        if #угрозы == 0 then return end
        table.sort(угрозы, function(a, b) return a.дист < b.дист end)
        local угроза = угрозы[1]
        local напр = (угроза.объект.Position - мояПоз).Unit
        local вправо = напр:Cross(Vector3.new(0, 1, 0)).Unit

        local пар = RaycastParams.new()
        пар.FilterType = Enum.RaycastFilterType.Exclude
        пар.FilterDescendantsInstances = {char, Workspace.CurrentCamera}
        local лучВправо = Workspace:Raycast(мояПоз, вправо * УКЛОНЕНИЕ.Дистанция, пар)
        local напрУклон = лучВправо and -вправо or вправо
        local цель = мояПоз + напрУклон * УКЛОНЕНИЕ.Дистанция
        local лучВниз = Workspace:Raycast(цель + Vector3.new(0, 5, 0), Vector3.new(0, -10, 0), пар)
        if лучВниз then цель = лучВниз.Position + Vector3.new(0, 3, 0) end

        pcall(function()
            char:PivotTo(CFrame.new(цель))
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end)
        УКЛОНЕНИЕ.Последнее = сейчас
        СЕССИЯ.уворотов = СЕССИЯ.уворотов + 1
        звякУворотСанса()
        уведомить("🥷 Уклонение!", Color3.fromRGB(150, 220, 255), 1.5)
    end)
end

-- ==================== ДЕТЕКТ ТРОЛЛИНГА ====================
local ТРОЛЛИНГ = {
    Включено = true,
    ПоследнийСкан = 0,
    Кулдаун = {},
}

local function детектТроллинга()
    if not НАСТРОЙКИ.Включено or not ТРОЛЛИНГ.Включено then return end
    local сейчас = tick()
    if сейчас - ТРОЛЛИНГ.ПоследнийСкан < 0.2 then return end
    ТРОЛЛИНГ.ПоследнийСкан = сейчас

    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    for _, игрок in ipairs(Players:GetPlayers()) do
        if игрок == LocalPlayer then continue end
        local чужой = игрок.Character
        if not чужой then continue end
        local чужойHrp = чужой:FindFirstChild("HumanoidRootPart")
        if not чужойHrp then continue end

        local дист = (чужойHrp.Position - hrp.Position).Magnitude
        if дист < 8 then
            local скор = чужойHrp.AssemblyLinearVelocity.Magnitude
            local вращ = чужойHrp.AssemblyAngularVelocity.Magnitude
            if скор > 40 or вращ > 20 then
                if not ТРОЛЛИНГ.Кулдаун[игрок] or сейчас - ТРОЛЛИНГ.Кулдаун[игрок] > 3 then
                    ТРОЛЛИНГ.Кулдаун[игрок] = сейчас
                    звякУворотСанса()
                    уведомить("⚠️ Троллинг: " .. игрок.Name, Color3.fromRGB(255, 150, 150), 2)
                end
            end
        end
    end
end

-- ==================== ОТВЕТНЫЙ ФЛИНГ ====================
local ОТВЕТНЫЙ = {
    Включено = false, ЛимитВращения = 20 * 2 * math.pi, СилаФлинга = 500,
    ПоследняяПроверка = 0, Интервал = 0.3, Обнаружено = {},
}

local function ответныйФлинг(игрок)
    if not игрок or игрок == LocalPlayer then return end
    local char = игрок.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    pcall(function()
        hrp.AssemblyAngularVelocity = Vector3.new(
            math.random(-1, 1) * 1000, math.random(-1, 1) * 1000, math.random(-1, 1) * 1000)
        hrp.AssemblyLinearVelocity = Vector3.new(0, ОТВЕТНЫЙ.СилаФлинга, 0)
    end)
    лог("🚨 ОТВЕТНЫЙ ФЛИНГ: " .. игрок.Name)
end

local function сканФлинтеров()
    if not ОТВЕТНЫЙ.Включено then return end
    local сейчас = tick()
    if сейчас - ОТВЕТНЫЙ.ПоследняяПроверка < ОТВЕТНЫЙ.Интервал then return end
    ОТВЕТНЫЙ.ПоследняяПроверка = сейчас
    for _, игрок in ipairs(Players:GetPlayers()) do
        if игрок == LocalPlayer then continue end
        local char = игрок.Character
        if not char then continue end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then continue end
        local вращ = hrp.AssemblyAngularVelocity
        if math.abs(вращ.X) > ОТВЕТНЫЙ.ЛимитВращения
            or math.abs(вращ.Y) > ОТВЕТНЫЙ.ЛимитВращения
            or math.abs(вращ.Z) > ОТВЕТНЫЙ.ЛимитВращения then
            if not ОТВЕТНЫЙ.Обнаружено[игрок] then
                ОТВЕТНЫЙ.Обнаружено[игрок] = сейчас
                ответныйФлинг(игрок)
            end
        end
    end
    for p, t in pairs(ОТВЕТНЫЙ.Обнаружено) do
        if сейчас - t > 5 then ОТВЕТНЫЙ.Обнаружено[p] = nil end
    end
end

-- ==================== ПОМЕТКА ЧИТЕРА ====================
function пометитьЧитера(игрок, вкл)
    if not игрок or игрок == LocalPlayer then return false end
    if вкл then
        ПОМЕЧЕННЫЕ[игрок] = true
        ЛОГ_ЧИТЕРОВ[игрок.UserId] = { имя = игрок.Name, время = os.time() }
        СЕССИЯ.читеровПомечено = СЕССИЯ.читеровПомечено + 1
        warn("[OrbitAC] Помечен: " .. игрок.Name)
        звякПометкаЧитера()
        уведомить("🚩 Помечен: " .. игрок.Name, Color3.fromRGB(255, 120, 120))
    else
        ПОМЕЧЕННЫЕ[игрок] = nil
        ЛОГ_ЧИТЕРОВ[игрок.UserId] = nil
    end
    return true
end

function переключитьПометку(игрок)
    return пометитьЧитера(игрок, not ПОМЕЧЕННЫЕ[игрок])
end

function помеченЛи(игрок) return ПОМЕЧЕННЫЕ[игрок] == true end

-- ==================== ОСНОВНОЙ ЦИКЛ ЗАЩИТЫ ====================
local function обработкаЗащиты(dt, char, hrp)
    local сейчас = tick()
    local вВоздухеФлаг = вВоздухе(hrp)

    if наЗемле(hrp) then
        СОСТОЯНИЕ.времяЗемли = СОСТОЯНИЕ.времяЗемли + dt
    else
        СОСТОЯНИЕ.времяЗемли = 0
    end

    антиДропКик(char, hrp, сейчас)
    антиФлинг(char, hrp)
    антиЯкорь(char)

    if сейчас - СОСТОЯНИЕ.времяОтбрасывания >= 0.1 then
        СОСТОЯНИЕ.времяОтбрасывания = сейчас
        антиОтбрасывание(char)
    end
    if сейчас - СОСТОЯНИЕ.времяЗаморозки >= 0.25 then
        СОСТОЯНИЕ.времяЗаморозки = сейчас
        антиЗаморозка(char)
    end
    if НАСТРОЙКИ.АвтоЛечение and сейчас - СОСТОЯНИЕ.времяЛечения >= 0.3 then
        СОСТОЯНИЕ.времяЛечения = сейчас
        автоЛечение(char)
    end

    антиПустота(char, hrp, dt)

    local вЛьготе = (сейчас - СОСТОЯНИЕ.льготныйСпавн) < 5.0
    if not вЛьготе and not вВоздухеФлаг then
        антиТелепорт(char, hrp)
        блокировкаПозиции(char, hrp)
    end

    антиМгновСмерть(char)

    pcall(детектТроллинга)
    pcall(проверитьВторжение)

    if сейчас - СОСТОЯНИЕ.последняяСкан > 0.5 then
        СОСТОЯНИЕ.последняяСкан = сейчас
        if НАСТРОЙКИ.ДетектСкорости then
            for _, игрок in ipairs(Players:GetPlayers()) do
                if игрок ~= LocalPlayer then
                    local чужой = игрок.Character
                    if чужой then
                        local чужойHrp = чужой:FindFirstChild("HumanoidRootPart")
                        if чужойHrp then
                            local последняя = СОСТОЯНИЕ.последниеПозиции[игрок]
                            if последняя then
                                local dt2 = сейчас - последняя.время
                                if dt2 > 0.1 and dt2 < 1 then
                                    local скор = (чужойHrp.Position - последняя.поз).Magnitude / dt2
                                    if скор > 150 then
                                        пометитьЧитера(игрок, true)
                                    end
                                end
                            end
                            СОСТОЯНИЕ.последниеПозиции[игрок] = { поз = чужойHrp.Position, время = сейчас }
                        end
                    end
                end
            end
        end
        pcall(сканФлинтеров)
    end

    if сейчас - СОСТОЯНИЕ.времяПроверки > 0.2 then
        СОСТОЯНИЕ.времяПроверки = сейчас
        local hum = char:FindFirstChildOfClass("Humanoid")
        local vy = math.abs(hrp.AssemblyLinearVelocity.Y)
        if hum and hum.Health > 0
            and not вВоздухеФлаг
            and vy < 1.0
            and наЗемле(hrp) then
            СОСТОЯНИЕ.последняяБезопаснаяПозиция = hrp.Position
            local lv = hrp.CFrame.LookVector
            local yaw = math.atan2(-lv.X, -lv.Z)
            СОСТОЯНИЕ.последнийБезопасныйCFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, yaw, 0)
        end
    end
end

local подключениеЗащиты = nil

local function включитьЗащиту()
    if подключениеЗащиты then подключениеЗащиты:Disconnect(); подключениеЗащиты = nil end
    if not НАСТРОЙКИ.Включено then return end

    СОСТОЯНИЕ.последняяБезопаснаяПозиция = nil
    СОСТОЯНИЕ.последнийБезопасныйCFrame = nil
    СОСТОЯНИЕ.времяПроверки = 0
    СОСТОЯНИЕ.времяЛечения = 0
    СОСТОЯНИЕ.последнееЗдоровье = 100
    СОСТОЯНИЕ.времяОтбрасывания = 0
    СОСТОЯНИЕ.времяЗаморозки = 0
    СОСТОЯНИЕ.льготныйСпавн = tick()
    СОСТОЯНИЕ.последниеПозиции = {}
    СОСТОЯНИЕ.предупреждениеGodMode = {}
    СОСТОЯНИЕ.таймерПустоты = 0
    СОСТОЯНИЕ.последнийHRP = nil
    СОСТОЯНИЕ.счётчикСкачков = 0
    СОСТОЯНИЕ.времяЗемли = 0
    СОСТОЯНИЕ.последнийУмныйПол = 0

    if LocalPlayer.Character then
        антиОтбрасывание(LocalPlayer.Character)
        отключитьУронПадения(LocalPlayer.Character)
    end

    if СОСТОЯНИЕ.подключениеПерсонажа then СОСТОЯНИЕ.подключениеПерсонажа:Disconnect() end
    СОСТОЯНИЕ.подключениеПерсонажа = LocalPlayer.CharacterAdded:Connect(function(новый)
        СОСТОЯНИЕ.последнийHRP = nil
        СОСТОЯНИЕ.льготныйСпавн = tick()
        СОСТОЯНИЕ.последняяБезопаснаяПозиция = nil
        СОСТОЯНИЕ.последнийБезопасныйCFrame = nil
        СОСТОЯНИЕ.времяЗемли = 0
        СОСТОЯНИЕ.последнийУмныйПол = 0
        task.wait(0.5)
        отключитьУронПадения(новый)
    end)

    настроитьУклонение()
    антиСуперКольцо()

    подключениеЗащиты = RunService.Heartbeat:Connect(function(dt)
        if not НАСТРОЙКИ.Включено then return end
        local char = LocalPlayer.Character
        if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        pcall(обработкаЗащиты, dt, char, hrp)
    end)

    уведомить("🛡 Анти-Чит v11.2 ВКЛ", Color3.fromRGB(120, 255, 180), 3)
    лог("Анти-Чит v11.2 активен.")
end

local function выключитьЗащиту()
    if СОСТОЯНИЕ.подключениеПерсонажа then СОСТОЯНИЕ.подключениеПерсонажа:Disconnect(); СОСТОЯНИЕ.подключениеПерсонажа = nil end
    if подключениеЗащиты then подключениеЗащиты:Disconnect(); подключениеЗащиты = nil end
    if подключениеУклонения then подключениеУклонения:Disconnect(); подключениеУклонения = nil end
    СОСТОЯНИЕ.последняяБезопаснаяПозиция = nil
    СОСТОЯНИЕ.последнийБезопасныйCFrame = nil
end

Workspace.DescendantAdded:Connect(function(объект)
    if not НАСТРОЙКИ.Включено or not НАСТРОЙКИ.АнтиВзрыв then return end
    if объект:IsA("Explosion") then
        task.defer(function() pcall(function() объект:Destroy() end) end)
    end
end)

-- ==================== UI ====================
local экран = Instance.new("ScreenGui")
экран.Name = "_OrbitAC_" .. tostring(math.random(100000, 999999))
экран.ResetOnSpawn = false
экран.IgnoreGuiInset = true
экран.DisplayOrder = 9999
экран.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
protectGui(экран)
local ок = pcall(function() экран.Parent = getSafeParent() end)
if not ок or not экран.Parent then экран.Parent = PlayerGui end

local главнаяКнопка = Instance.new("TextButton")
главнаяКнопка.Size = UDim2.new(0, 56, 0, 56)
главнаяКнопка.Position = НАСТРОЙКИ.ПозицияКнопки
главнаяКнопка.BackgroundColor3 = Color3.fromRGB(40, 20, 20)
главнаяКнопка.BackgroundTransparency = 0.1
главнаяКнопка.TextColor3 = Color3.fromRGB(255, 180, 180)
главнаяКнопка.Font = Enum.Font.GothamBold
главнаяКнопка.TextSize = 24
главнаяКнопка.Text = "🛡"
главнаяКнопка.AutoButtonColor = false
главнаяКнопка.Parent = экран
Instance.new("UICorner", главнаяКнопка).CornerRadius = UDim.new(0, 14)
local обводкаКнопки = Instance.new("UIStroke", главнаяКнопка)
обводкаКнопки.Color = Color3.fromRGB(255, 100, 100)
обводкаКнопки.Thickness = 1.5

local панель = Instance.new("ScrollingFrame")
панель.Size = UDim2.new(0, 300, 0, 600)
панель.Position = UDim2.new(0, 90, 0, 60)
панель.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
панель.BackgroundTransparency = 0.15
панель.BorderSizePixel = 0
панель.Visible = false
панель.CanvasSize = UDim2.new(0, 0, 0, 1700)
панель.ScrollBarThickness = 4
панель.ScrollBarImageColor3 = Color3.fromRGB(255, 100, 100)
панель.Parent = экран
Instance.new("UICorner", панель).CornerRadius = UDim.new(0, 12)
local обводкаПанели = Instance.new("UIStroke", панель)
обводкаПанели.Color = Color3.fromRGB(255, 100, 100)
обводкаПанели.Thickness = 1

local масштабПанели = Instance.new("UIScale")
масштабПанели.Parent = панель

local заголовок = Instance.new("TextLabel")
заголовок.Size = UDim2.new(1, 0, 0, 30)
заголовок.Position = UDim2.new(0, 0, 0, 6)
заголовок.BackgroundTransparency = 1
заголовок.Text = "🛡  ОРБИТА АНТИ-ЧИТ v11.2"
заголовок.TextColor3 = Color3.fromRGB(255, 200, 200)
заголовок.Font = Enum.Font.GothamBold
заголовок.TextSize = 15
заголовок.Parent = панель

local function создатьСекцию(текст, y, цвет)
    local рамка = Instance.new("Frame")
    рамка.Size = UDim2.new(1, -20, 0, 28)
    рамка.Position = UDim2.new(0, 10, 0, y)
    рамка.BackgroundColor3 = цвет or Color3.fromRGB(80, 40, 40)
    рамка.BackgroundTransparency = 0.35
    рамка.BorderSizePixel = 0
    рамка.Parent = панель
    Instance.new("UICorner", рамка).CornerRadius = UDim.new(0, 8)
    local полоска = Instance.new("Frame")
    полоска.Size = UDim2.new(0, 4, 1, -8)
    полоска.Position = UDim2.new(0, 4, 0, 4)
    полоска.BackgroundColor3 = цвет or Color3.fromRGB(255, 100, 100)
    полоска.BorderSizePixel = 0
    полоска.Parent = рамка
    Instance.new("UICorner", полоска).CornerRadius = UDim.new(0, 2)
    local т = Instance.new("TextLabel")
    т.Size = UDim2.new(1, -14, 1, 0)
    т.Position = UDim2.new(0, 12, 0, 0)
    т.BackgroundTransparency = 1
    т.Text = текст
    т.TextColor3 = Color3.fromRGB(240, 240, 255)
    т.Font = Enum.Font.GothamBold
    т.TextSize = 13
    т.TextXAlignment = Enum.TextXAlignment.Left
    т.Parent = рамка
end

local function создатьКнопку(текст, y, h, фон, цветТекста)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, -20, 0, h or 32)
    b.Position = UDim2.new(0, 10, 0, y)
    b.BackgroundColor3 = фон or Color3.fromRGB(45, 45, 62)
    b.TextColor3 = цветТекста or Color3.fromRGB(235, 235, 255)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 12
    b.Text = текст
    b.AutoButtonColor = true
    b.Parent = панель
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
    local обводка = Instance.new("UIStroke", b)
    обводка.Color = фон or Color3.fromRGB(80, 80, 120)
    обводка.Thickness = 1
    обводка.Transparency = 0.65
    b.MouseButton1Down:Connect(звякКлик)
    b.InputBegan:Connect(function(ввод)
        if ввод.UserInputType == Enum.UserInputType.Touch then звякКлик() end
    end)
    return b
end

создатьСекцию("⚡  ОСНОВНОЕ", 42, Color3.fromRGB(80, 40, 40))
local кнопкаВкл = создатьКнопку("🔴 ВЫКЛЮЧЕНО", 74, 36, Color3.fromRGB(50, 35, 40), Color3.fromRGB(255, 80, 80))

создатьСекцию("📊  СТАТИСТИКА", 118, Color3.fromRGB(60, 60, 90))
local статистика = Instance.new("TextLabel")
статистика.Size = UDim2.new(1, -20, 0, 110)
статистика.Position = UDim2.new(0, 10, 0, 150)
статистика.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
статистика.BackgroundTransparency = 0.2
статистика.BorderSizePixel = 0
статистика.TextColor3 = Color3.fromRGB(200, 220, 255)
статистика.Font = Enum.Font.GothamBold
статистика.TextSize = 11
статистика.TextXAlignment = Enum.TextXAlignment.Left
статистика.TextYAlignment = Enum.TextYAlignment.Top
статистика.Text = "Загрузка..."
статистика.Parent = панель
Instance.new("UICorner", статистика).CornerRadius = UDim.new(0, 6)

создатьСекцию("🛡️  ЗАЩИТА", 268, Color3.fromRGB(60, 100, 60))
local кнФлинг   = создатьКнопку("🛡️ Анти-Флинг: ВКЛ", 300, 30, Color3.fromRGB(35,50,35), Color3.fromRGB(160,255,160))
local кнПустота  = создатьКнопку("🛡️ Анти-Пустота: ВКЛ", 334, 30, Color3.fromRGB(35,50,35), Color3.fromRGB(160,255,160))
local кнТелепорт = создатьКнопку("🛡️ Анти-Телепорт: ВКЛ", 368, 30, Color3.fromRGB(35,50,35), Color3.fromRGB(160,255,160))
local кнОтбрас   = создатьКнопку("🛡️ Анти-Отбрасывание: ВКЛ", 402, 30, Color3.fromRGB(35,50,35), Color3.fromRGB(160,255,160))
local кнЗамороз  = создатьКнопку("🛡️ Анти-Заморозка: ВКЛ", 436, 30, Color3.fromRGB(35,50,35), Color3.fromRGB(160,255,160))
local кнДропКик  = создатьКнопку("🛡️ Анти-ДропКик: ВКЛ", 470, 30, Color3.fromRGB(35,50,35), Color3.fromRGB(160,255,160))
local кнМгнСмерть= создатьКнопку("🛡️ Анти-МгновСмерть: ВКЛ", 504, 30, Color3.fromRGB(35,50,35), Color3.fromRGB(160,255,160))
local кнВзрыв    = создатьКнопку("🛡️ Анти-Взрыв: ВКЛ", 538, 30, Color3.fromRGB(35,50,35), Color3.fromRGB(160,255,160))
local кнСуперК   = создатьКнопку("🛡️ Анти-СуперКольцо: ВКЛ", 572, 30, Color3.fromRGB(35,50,35), Color3.fromRGB(160,255,160))
local кнУронП    = создатьКнопку("🛡️ Убрать урон падения: ВКЛ", 606, 30, Color3.fromRGB(35,50,35), Color3.fromRGB(160,255,160))

создатьСекцию("💚  УТИЛИТЫ", 648, Color3.fromRGB(80, 100, 60))
local кнЛечение = создатьКнопку("💚 Авто-Лечение: ВЫКЛ", 680, 30, Color3.fromRGB(35,50,35), Color3.fromRGB(160,255,160))
local кнБлокПоз = создатьКнопку("📍 Блокировка позиции: ВЫКЛ", 714, 30, Color3.fromRGB(35,50,35), Color3.fromRGB(160,255,160))

создатьСекцию("👁️  ВИЗУАЛ", 756, Color3.fromRGB(60, 80, 120))
local кнСфера    = создатьКнопку("🔵 Сфера: ВЫКЛ", 788, 32, Color3.fromRGB(40,50,70), Color3.fromRGB(180,220,255))
local кнРазмер   = создатьКнопку("📏 Размер сферы: 8", 824, 30, Color3.fromRGB(40,50,70), Color3.fromRGB(180,220,255))
local кнВторж    = создатьКнопку("🚨 Детект вторжения: ВКЛ", 858, 30, Color3.fromRGB(50,40,60), Color3.fromRGB(255,180,200))

создатьСекцию("🥷  ДОП. ЗАЩИТА", 900, Color3.fromRGB(80, 60, 130))
local кнУклон    = создатьКнопку("🥷 Уклонение: ВЫКЛ", 932, 32, Color3.fromRGB(50,50,50), Color3.fromRGB(200,200,200))
local кнТролл    = создатьКнопку("👁️ Детект троллинга: ВКЛ", 968, 30, Color3.fromRGB(50,60,80), Color3.fromRGB(200,220,255))
local кнОтветн   = создатьКнопку("🚨 Ответный флинг: ВЫКЛ", 1000, 30, Color3.fromRGB(60,30,30), Color3.fromRGB(255,150,150))

создатьСекцию("👁️  ДЕТЕКТ ЧИТЕРОВ", 1042, Color3.fromRGB(100, 60, 60))
local кнСкорость = создатьКнопку("⚡ Детект скорости: ВКЛ", 1074, 30, Color3.fromRGB(50,40,40), Color3.fromRGB(255,180,180))
local кнGodMode  = создатьКнопку("👁️ Детект GodMode: ВКЛ", 1108, 30, Color3.fromRGB(50,40,40), Color3.fromRGB(255,180,180))
local кнСписок   = создатьКнопку("📋 Список читеров: 0", 1142, 28, Color3.fromRGB(60,35,45), Color3.fromRGB(255,180,220))

создатьСекцию("🔊  ЗВУКИ", 1182, Color3.fromRGB(70, 80, 110))
local кнЗвук     = создатьКнопку("🔊 Звуки: ВКЛ", 1214, 30, Color3.fromRGB(35,60,45), Color3.fromRGB(180,255,180))
local кнТестЗвук = создатьКнопку("🎵 Проверить звуки", 1248, 30, Color3.fromRGB(50,60,90), Color3.fromRGB(200,220,255))

создатьСекцию("💾  СИСТЕМА", 1290, Color3.fromRGB(60, 60, 80))
local кнСохранить = создатьКнопку("💾 Сохранить настройки", 1322, 30, Color3.fromRGB(35,60,45), Color3.fromRGB(160,255,180))
local кнЗагрузить  = создатьКнопку("📂 Загрузить настройки", 1356, 30, Color3.fromRGB(35,50,60), Color3.fromRGB(180,220,255))
local кнСброс     = создатьКнопку("🔄 Сбросить всё", 1390, 30, Color3.fromRGB(50,30,30), Color3.fromRGB(255,180,180))
local кнВыгрузить = создатьКнопку("❌ ВЫГРУЗИТЬ", 1424, 32, Color3.fromRGB(80,30,30), Color3.fromRGB(255,140,140))

панель.CanvasSize = UDim2.new(0, 0, 0, 1470)

-- ==================== УВЕДОМЛЕНИЯ ====================
local контейнерУвед = Instance.new("Frame")
контейнерУвед.Size = UDim2.new(0, 300, 0.4, 0)
контейнерУвед.Position = UDim2.new(1, -320, 0.15, 0)
контейнерУвед.BackgroundTransparency = 1
контейнерУвед.Parent = экран

local раскладкаУвед = Instance.new("UIListLayout")
раскладкаУвед.SortOrder = Enum.SortOrder.LayoutOrder
раскладкаУвед.Padding = UDim.new(0, 6)
раскладкаУвед.VerticalAlignment = Enum.VerticalAlignment.Top
раскладкаУвед.Parent = контейнерУвед

local счётчикУвед = 0
function уведомить(текст, цвет, длительность)
    длительность = длительность or 2
    цвет = цвет or Color3.fromRGB(140, 255, 200)
    счётчикУвед = счётчикУвед + 1

    local слот = Instance.new("Frame")
    слот.Size = UDim2.new(1, 0, 0, 40)
    слот.BackgroundTransparency = 1
    слот.LayoutOrder = счётчикУвед
    слот.Parent = контейнерУвед

    local слоты = {}
    for _, р in ipairs(контейнерУвед:GetChildren()) do
        if р:IsA("Frame") then table.insert(слоты, р) end
    end
    table.sort(слоты, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
    while #слоты > 6 do table.remove(слоты, 1):Destroy() end

    local рамка = Instance.new("Frame")
    рамка.Size = UDim2.new(1, 0, 1, 0)
    рамка.Position = UDim2.new(1.15, 0, 0, 0)
    рамка.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    рамка.BackgroundTransparency = 0.15
    рамка.BorderSizePixel = 0
    рамка.Parent = слот
    Instance.new("UICorner", рамка).CornerRadius = UDim.new(0, 8)
    local обводка = Instance.new("UIStroke", рамка)
    обводка.Color = цвет
    обводка.Thickness = 1.5

    local текст = Instance.new("TextLabel")
    текст.Size = UDim2.new(1, -16, 1, 0)
    текст.Position = UDim2.new(0, 8, 0, 0)
    текст.BackgroundTransparency = 1
    текст.Text = текст
    текст.TextColor3 = цвет
    текст.Font = Enum.Font.GothamBold
    текст.TextSize = 13
    текст.TextWrapped = true
    текст.TextXAlignment = Enum.TextXAlignment.Left
    текст.Parent = рамка

    TweenService:Create(рамка, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
        Position = UDim2.new(0, 0, 0, 0),
    }):Play()

    task.delay(длительность, function()
        if not слот or not слот.Parent then return end
        local выход = TweenService:Create(рамка, TweenInfo.new(0.25), { Position = UDim2.new(1.15, 0, 0, 0) })
        выход:Play()
        выход.Completed:Connect(function() pcall(function() слот:Destroy() end) end)
    end)
end
GENV._ORBIT_AC_NOTIFY = уведомить

-- ==================== ОБРАБОТЧИКИ UI ====================
local тащим, двинули = false, false
local начПозиция, стартПозиция

главнаяКнопка.InputBegan:Connect(function(ввод)
    if ввод.UserInputType == Enum.UserInputType.Touch
       or ввод.UserInputType == Enum.UserInputType.MouseButton1 then
        тащим = true
        двинули = false
        начПозиция = ввод.Position
        стартПозиция = главнаяКнопка.Position
    end
end)

game:GetService("UserInputService").InputChanged:Connect(function(ввод)
    if not тащим then return end
    if ввод.UserInputType == Enum.UserInputType.Touch
       or ввод.UserInputType == Enum.UserInputType.MouseMovement then
        local д = ввод.Position - начПозиция
        if д.Magnitude > 6 then двинули = true end
        if двинули then
            local абс = экран.AbsoluteSize
            главнаяКнопка.Position = UDim2.fromOffset(
                math.clamp(стартПозиция.X.Offset + д.X, 0, math.max(0, абс.X - 56)),
                math.clamp(стартПозиция.Y.Offset + д.Y, 0, math.max(0, абс.Y - 56))
            )
        end
    end
end)

game:GetService("UserInputService").InputEnded:Connect(function(ввод)
    if ввод.UserInputType == Enum.UserInputType.Touch
       or ввод.UserInputType == Enum.UserInputType.MouseButton1 then
        тащим = false
    end
end)

local панельОткрыта = false
local function установитьПанель(откр)
    панельОткрыта = откр
    звякПереключатель()
    if откр then
        local абс = экран.AbsoluteSize
        панель.Size = UDim2.fromOffset(300, math.clamp(абс.Y - 40, 200, 700))
        панель.Position = UDim2.fromOffset(
            math.clamp(главнаяКнопка.Position.X.Offset + 70, 0, math.max(0, абс.X - 310)), 20)
        масштабПанели.Scale = 0.85
        панель.Visible = true
        TweenService:Create(масштабПанели, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = 1 }):Play()
    else
        TweenService:Create(масштабПанели, TweenInfo.new(0.12), { Scale = 0.85 }):Play()
        task.delay(0.13, function()
            if not панельОткрыта then панель.Visible = false end
        end)
    end
end

главнаяКнопка.Activated:Connect(function()
    if двинули then двинули = false; return end
    установитьПанель(not панельОткрыта)
end)

кнопкаВкл.Activated:Connect(function()
    НАСТРОЙКИ.Включено = not НАСТРОЙКИ.Включено
    звякПереключатель()
    if НАСТРОЙКИ.Включено then
        кнопкаВкл.Text = "🟢 ВКЛЮЧЕНО"
        кнопкаВкл.TextColor3 = Color3.fromRGB(0,255,120)
        кнопкаВкл.BackgroundColor3 = Color3.fromRGB(40,50,40)
        включитьЗащиту()
    else
        кнопкаВкл.Text = "🔴 ВЫКЛЮЧЕНО"
        кнопкаВкл.TextColor3 = Color3.fromRGB(255,80,80)
        кнопкаВкл.BackgroundColor3 = Color3.fromRGB(50,35,40)
        выключитьЗащиту()
        if модельСферы then модельСферы:Destroy(); модельСферы = nil; частьСферы = nil end
        уведомить("🔴 Анти-Чит ВЫКЛ", Color3.fromRGB(255,100,100), 2)
    end
end)

-- Обработчики кнопок защит
local function переключ(кнопка, поле, префикс, цветВкл, цветВыкл)
    НАСТРОЙКИ[поле] = not НАСТРОЙКИ[поле]
    кнопка.Text = префикс .. ": " .. (НАСТРОЙКИ[поле] and "ВКЛ" or "ВЫКЛ")
    if НАСТРОЙКИ[поле] then
        кнопка.TextColor3 = цветВкл or Color3.fromRGB(160,255,160)
        кнопка.BackgroundColor3 = Color3.fromRGB(35,50,35)
    else
        кнопка.TextColor3 = цветВыкл or Color3.fromRGB(220,200,200)
        кнопка.BackgroundColor3 = Color3.fromRGB(50,40,40)
    end
end

кнФлинг.Activated:Connect(function() переключ(кнФлинг, "АнтиФлинг", "🛡️ Анти-Флинг") end)
кнПустота.Activated:Connect(function() переключ(кнПустота, "АнтиПустота", "🛡️ Анти-Пустота") end)
кнТелепорт.Activated:Connect(function() переключ(кнТелепорт, "АнтиТелепорт", "🛡️ Анти-Телепорт") end)
кнОтбрас.Activated:Connect(function() переключ(кнОтбрас, "АнтиОтбрасывание", "🛡️ Анти-Отбрасывание") end)
кнЗамороз.Activated:Connect(function() переключ(кнЗамороз, "АнтиЗаморозка", "🛡️ Анти-Заморозка") end)
кнДропКик.Activated:Connect(function() переключ(кнДропКик, "АнтиДропКик", "🛡️ Анти-ДропКик") end)
кнМгнСмерть.Activated:Connect(function() переключ(кнМгнСмерть, "АнтиМгновСмерть", "🛡️ Анти-МгновСмерть") end)
кнВзрыв.Activated:Connect(function() переключ(кнВзрыв, "АнтиВзрыв", "🛡️ Анти-Взрыв") end)
кнСуперК.Activated:Connect(function() переключ(кнСуперК, "АнтиСуперКольцо", "🛡️ Анти-СуперКольцо") end)
кнУронП.Activated:Connect(function() переключ(кнУронП, "УбратьУронПадения", "🛡️ Убрать урон падения") end)
кнЛечение.Activated:Connect(function() переключ(кнЛечение, "АвтоЛечение", "💚 Авто-Лечение") end)
кнБлокПоз.Activated:Connect(function() переключ(кнБлокПоз, "БлокировкаПозиции", "📍 Блокировка позиции") end)
кнВторж.Activated:Connect(function() переключ(кнВторж, "ДетектВторжения", "🚨 Детект вторжения") end)
кнСкорость.Activated:Connect(function() переключ(кнСкорость, "ДетектСкорости", "⚡ Детект скорости") end)
кнGodMode.Activated:Connect(function() переключ(кнGodMode, "ДетектGodMode", "👁️ Детект GodMode") end)

кнСфера.Activated:Connect(function()
    НАСТРОЙКИ.ВизуальнаяСфера = not НАСТРОЙКИ.ВизуальнаяСфера
    кнСфера.Text = "🔵 Сфера: " .. (НАСТРОЙКИ.ВизуальнаяСфера and "ВКЛ" or "ВЫКЛ")
    if not НАСТРОЙКИ.ВизуальнаяСфера then
        if модельСферы then модельСферы:Destroy(); модельСферы = nil; частьСферы = nil end
    else
        создатьСферу()
    end
end)
кнРазмер.Activated:Connect(function()
    local размеры = {4, 6, 8, 12, 16, 20, 25, 30}
    local ид = 1
    for i, v in ipairs(размеры) do if v == НАСТРОЙКИ.РазмерСферы then ид = i; break end end
    НАСТРОЙКИ.РазмерСферы = размеры[(ид % #размеры) + 1]
    кнРазмер.Text = "📏 Размер сферы: " .. НАСТРОЙКИ.РазмерСферы
    if частьСферы then
        частьСферы.Size = Vector3.new(НАСТРОЙКИ.РазмерСферы, НАСТРОЙКИ.РазмерСферы, НАСТРОЙКИ.РазмерСферы)
    end
end)

кнУклон.Activated:Connect(function()
    УКЛОНЕНИЕ.Включено = not УКЛОНЕНИЕ.Включено
    кнУклон.Text = "🥷 Уклонение: " .. (УКЛОНЕНИЕ.Включено and "ВКЛ" or "ВЫКЛ")
    кнУклон.BackgroundColor3 = УКЛОНЕНИЕ.Включено and Color3.fromRGB(60,80,50) or Color3.fromRGB(50,50,50)
end)
кнТролл.Activated:Connect(function()
    ТРОЛЛИНГ.Включено = not ТРОЛЛИНГ.Включено
    кнТролл.Text = "👁️ Детект троллинга: " .. (ТРОЛЛИНГ.Включено and "ВКЛ" or "ВЫКЛ")
end)
кнОтветн.Activated:Connect(function()
    ОТВЕТНЫЙ.Включено = not ОТВЕТНЫЙ.Включено
    кнОтветн.Text = "🚨 Ответный флинг: " .. (ОТВЕТНЫЙ.Включено and "ВКЛ" or "ВЫКЛ")
    кнОтветн.BackgroundColor3 = ОТВЕТНЫЙ.Включено and Color3.fromRGB(100,30,30) or Color3.fromRGB(60,30,30)
end)

кнСписок.Activated:Connect(function()
    local список = {}
    for p in pairs(ПОМЕЧЕННЫЕ) do
        if p and p.Parent then table.insert(список, p.Name) end
    end
    if #список == 0 then
        уведомить("📋 Читеров не найдено", Color3.fromRGB(200, 200, 255), 3)
    else
        уведомить("📋 Читеры: " .. table.concat(список, ", "), Color3.fromRGB(255, 180, 220), 5)
    end
end)

кнЗвук.Activated:Connect(function()
    НАСТРОЙКИ.Звуки = not НАСТРОЙКИ.Звуки
    кнЗвук.Text = "🔊 Звуки: " .. (НАСТРОЙКИ.Звуки and "ВКЛ" or "ВЫКЛ")
    if НАСТРОЙКИ.Звуки then звякПереключатель() end
end)

кнТестЗвук.Activated:Connect(function()
    кнТестЗвук.Text = "⏳ Проигрываю..."
    task.wait(0.1)
    звякКлик()
    task.wait(0.5)
    звякУворотСанса()
    task.wait(3)
    кнТестЗвук.Text = "✅ Готово"
    task.wait(2)
    кнТестЗвук.Text = "🎵 Проверить звуки"
end)

-- ==================== СОХРАНЕНИЕ ====================
local ФАЙЛ_СОХРАНЕНИЯ = "orbit_ac_settings.json"
local ЕСТЬ_ФС = (writefile and readfile and isfile and type(writefile) == "function")

кнСохранить.Activated:Connect(function()
    if not ЕСТЬ_ФС then
        уведомить("❌ Нет файловой системы", Color3.fromRGB(255, 100, 100), 2)
        return
    end
    local ок = pcall(function()
        local данные = {}
        for k, v in pairs(НАСТРОЙКИ) do
            if type(v) ~= "userdata" and type(v) ~= "function" then
                данные[k] = v
            end
        end
        writefile(ФАЙЛ_СОХРАНЕНИЯ, game:GetService("HttpService"):JSONEncode(данные))
    end)
    if ок then
        кнСохранить.Text = "✅ Сохранено!"
        task.wait(1.5)
        кнСохранить.Text = "💾 Сохранить настройки"
        уведомить("💾 Настройки сохранены", Color3.fromRGB(160, 255, 180), 2)
    else
        уведомить("❌ Ошибка сохранения", Color3.fromRGB(255, 100, 100), 2)
    end
end)

кнЗагрузить.Activated:Connect(function()
    if not ЕСТЬ_ФС or not isfile(ФАЙЛ_СОХРАНЕНИЯ) then
        уведомить("❌ Нет сохранения", Color3.fromRGB(255, 100, 100), 2)
        return
    end
    pcall(function()
        local данные = game:GetService("HttpService"):JSONDecode(readfile(ФАЙЛ_СОХРАНЕНИЯ))
        for k, v in pairs(данные) do
            if НАСТРОЙКИ[k] ~= nil then НАСТРОЙКИ[k] = v end
        end
        уведомить("📂 Настройки загружены", Color3.fromRGB(180, 220, 255), 2)
    end)
end)

кнСброс.Activated:Connect(function()
    НАСТРОЙКИ.АнтиФлинг = true
    НАСТРОЙКИ.АнтиПустота = true
    НАСТРОЙКИ.АнтиТелепорт = true
    НАСТРОЙКИ.АнтиОтбрасывание = true
    НАСТРОЙКИ.АнтиЗаморозка = true
    НАСТРОЙКИ.АнтиЯкорь = true
    НАСТРОЙКИ.АнтиМгновСмерть = true
    НАСТРОЙКИ.АнтиДропКик = true
    НАСТРОЙКИ.АнтиВзрыв = true
    НАСТРОЙКИ.АнтиСуперКольцо = true
    НАСТРОЙКИ.УбратьУронПадения = true
    НАСТРОЙКИ.АвтоЛечение = false
    НАСТРОЙКИ.БлокировкаПозиции = false
    НАСТРОЙКИ.ВизуальнаяСфера = false
    НАСТРОЙКИ.ДетектВторжения = true
    УКЛОНЕНИЕ.Включено = false
    ТРОЛЛИНГ.Включено = true
    ОТВЕТНЫЙ.Включено = false
    if модельСферы then модельСферы:Destroy(); модельСферы = nil; частьСферы = nil end
    уведомить("🔄 Сброс выполнен", Color3.fromRGB(255, 180, 180), 2)
end)

кнВыгрузить.Activated:Connect(function()
    pcall(function() GENV._ORBIT_AC_UNLOAD() end)
end)

-- ==================== ВЫГРУЗКА ====================
GENV._ORBIT_AC_UNLOAD = function()
    выключитьЗащиту()
    if модельСферы then pcall(function() модельСферы:Destroy() end) end
    if экран then pcall(function() экран:Destroy() end) end
    if папкаЗвуков then pcall(function() папкаЗвуков:Destroy() end) end
    GENV._ORBIT_AC_LOADED = nil
    GENV._ORBIT_AC_UNLOAD = nil
    GENV._ORBIT_AC_NOTIFY = nil
    print("[OrbitAC] Выгружен")
end

-- ==================== ОБНОВЛЕНИЕ СТАТИСТИКИ ====================
task.spawn(function()
    while экран and экран.Parent do
        task.wait(0.5)
        local прошло = tick() - СЕССИЯ.начало
        local мин = math.floor(прошло / 60)
        local сек = math.floor(прошло % 60)
        статистика.Text = string.format(
            "🛡️ Защит: %d\n🥷 Уворотов: %d\n🚨 Вторжений: %d\n🚩 Читеров: %d\n⏱️ Сессия: %d:%02d",
            СЕССИЯ.защитСработало,
            СЕССИЯ.уворотов,
            СЕССИЯ.вторжений,
            СЕССИЯ.читеровПомечено,
            мин, сек
        )
        кнСписок.Text = "📋 Список читеров: " .. СЕССИЯ.читеровПомечено
        if НАСТРОЙКИ.ВизуальнаяСфера then обновитьСферу() end
    end
end)

-- ==================== ГОРЯЧАЯ КЛАВИША ====================
game:GetService("UserInputService").InputBegan:Connect(function(ввод, обработано)
    if обработано then return end
    if ввод.KeyCode == Enum.KeyCode.K then
        if GENV._ORBIT_AC_TOGGLE then GENV._ORBIT_AC_TOGGLE() end
    end
end)

GENV._ORBIT_AC_TOGGLE = function()
    НАСТРОЙКИ.Включено = not НАСТРОЙКИ.Включено
    if НАСТРОЙКИ.Включено then
        кнопкаВкл.Text = "🟢 ВКЛЮЧЕНО"
        кнопкаВкл.TextColor3 = Color3.fromRGB(0,255,120)
        кнопкаВкл.BackgroundColor3 = Color3.fromRGB(40,50,40)
        включитьЗащиту()
    else
        кнопкаВкл.Text = "🔴 ВЫКЛЮЧЕНО"
        кнопкаВкл.TextColor3 = Color3.fromRGB(255,80,80)
        кнопкаВкл.BackgroundColor3 = Color3.fromRGB(50,35,40)
        выключитьЗащиту()
        if модельСферы then модельСферы:Destroy(); модельСферы = nil; частьСферы = nil end
    end
end

-- ==================== АВТОЗАПУСК ====================
task.spawn(function()
    task.wait(1)
    уведомить("🛡 ОРБИТА АНТИ-ЧИТ v11.2", Color3.fromRGB(255, 200, 200), 3)
    task.wait(0.3)
    уведомить("🚨 Детект вторжения: ВКЛ", Color3.fromRGB(255, 180, 200), 3)
    task.wait(0.3)
    уведомить("🎮 K — вкл/выкл защиту", Color3.fromRGB(200, 220, 255), 3)
end)

print("[Orbit Anti-Cheat v11.2] ═══════════════════════════")
print("[Orbit Anti-Cheat v11.2] Автономный скрипт запущен ✅")
print("[Orbit Anti-Cheat v11.2] Детект вторжения + Anti-SuperRing + Очередь звуков")
print("[Orbit Anti-Cheat v11.2] ═══════════════════════════")

return true
