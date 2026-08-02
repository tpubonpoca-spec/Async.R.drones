--[[
    Серверный модуль управления FPV-дронами zAsync
    Стиль: ОС "ЗАРЯ" v3.12 (Минобороны РФ / Ростех)

    - Полная интеграция с LVS для управления, физики, звуков и камеры.
    - Оператор оставляет физическую тушку на земле (Proxy Entity), уязвимую для любого урона.
    - Урон по тушке на земле передаётся игроку. При гибели на земле дрон отключается/взрывается.
    - Стартовые звуки vkluchenie.mp3 -> 0.3s -> esc_startup.mp3 + блокировка 5.4с.
--]]

if not SERVER then return end

util.AddNetworkString("Async_SpawnDrone")
util.AddNetworkString("Async_DroneStatus")
util.AddNetworkString("Async_DisconnectDrone")

local ASYNC_DRONE_CLASSES = {
    ["lvs_kvn1"] = true,
    ["lvs_kvn2"] = true,
    ["lvs_kvn3"] = true,
}

local ActiveDrones = {}
local OperatorProxies = {}
local SpawnCooldowns = {}

-- Создание прокси-тушки оператора на земле
local function CreateOperatorProxy(ply)
    if not IsValid(ply) then return nil end

    local proxy = ents.Create("prop_scripted")
    if not IsValid(proxy) then
        proxy = ents.Create("prop_dynamic")
    end

    proxy:SetModel(ply:GetModel())
    proxy:SetPos(ply:GetPos())
    proxy:SetAngles(Angle(0, ply:EyeAngles().y, 0))
    proxy:SetSkin(ply:GetSkin() or 0)
    proxy:Spawn()
    proxy:Activate()

    -- Скопировать бодигруппы
    for _, bg in ipairs(ply:GetBodyGroups() or {}) do
        proxy:SetBodygroup(bg.id, ply:GetBodygroup(bg.id))
    end

    -- Анимация держания геймпада/пультика
    local seq = proxy:LookupSequence("pose_standing")
    if seq and seq > 0 then
        proxy:ResetSequence(seq)
    end

    proxy:SetHealth(ply:Health())
    proxy:SetMaxHealth(ply:GetMaxHealth())

    proxy._IsOperatorProxy = true
    proxy._OperatorPlayer = ply

    -- Передача урона с тушки на оператора
    proxy:AddCallback("OnTakeDamage", function(ent, dmginfo)
        local owner = ent._OperatorPlayer
        if IsValid(owner) and owner:Alive() then
            owner:TakeDamageInfo(dmginfo)
            if not owner:Alive() then
                ent:Remove()
            end
        end
    end)

    return proxy
end

-- Возврат игрока на землю при завершении управления
local function ReturnOperatorToGround(ply)
    if not IsValid(ply) then return end

    local sid = ply:SteamID()
    local proxy = OperatorProxies[sid]

    if IsValid(proxy) then
        local groundPos = proxy:GetPos()
        local groundAng = proxy:GetAngles()

        if ply:InVehicle() then
            ply:ExitVehicle()
        end

        ply:SetPos(groundPos)
        ply:SetEyeAngles(groundAng)
        proxy:Remove()
        OperatorProxies[sid] = nil
    end

    ply:SetNWEntity("KVN_ActiveDrone", NULL)
end

-- Очистка при смерти оператора
hook.Add("PlayerDeath", "Async_OperatorDeathCleanup", function(ply)
    local sid = ply:SteamID()
    if ActiveDrones[sid] and IsValid(ActiveDrones[sid]) then
        ActiveDrones[sid]:Remove()
    end
    ActiveDrones[sid] = nil

    if OperatorProxies[sid] and IsValid(OperatorProxies[sid]) then
        OperatorProxies[sid]:Remove()
    end
    OperatorProxies[sid] = nil

    ply:SetNWEntity("KVN_ActiveDrone", NULL)
end)

hook.Add("PlayerDisconnected", "Async_CleanupOnDisconnect", function(ply)
    local sid = ply:SteamID()
    if ActiveDrones[sid] and IsValid(ActiveDrones[sid]) then
        ActiveDrones[sid]:Remove()
    end
    ActiveDrones[sid] = nil

    if OperatorProxies[sid] and IsValid(OperatorProxies[sid]) then
        OperatorProxies[sid]:Remove()
    end
    OperatorProxies[sid] = nil

    SpawnCooldowns[sid] = nil
end)

hook.Add("EntityRemoved", "Async_CleanupDrone", function(ent)
    if not IsValid(ent) then return end
    local cls = ent:GetClass()
    if not ASYNC_DRONE_CLASSES[cls] then return end

    for sid, drone in pairs(ActiveDrones) do
        if drone == ent then
            ActiveDrones[sid] = nil

            local owner = ent._AsyncOperator
            if IsValid(owner) then
                ReturnOperatorToGround(owner)

                net.Start("Async_DroneStatus")
                    net.WriteUInt(0, 2)
                net.Send(owner)
            end
            break
        end
    end
end)

-- Отключение по клавише R / F6
net.Receive("Async_DisconnectDrone", function(len, ply)
    if not IsValid(ply) then return end

    local sid = ply:SteamID()
    if ActiveDrones[sid] and IsValid(ActiveDrones[sid]) then
        ActiveDrones[sid]:Remove()
        ActiveDrones[sid] = nil
    else
        ReturnOperatorToGround(ply)
    end

    ply:EmitSound("buttons/button10.wav", 75, 100)
    ply:ChatPrint("[ОС ЗАРЯ] Отключение от канала связи БПЛА.")
end)

-- Запрос на спавн и запуск дрона
net.Receive("Async_SpawnDrone", function(len, ply)
    if not IsValid(ply) or not ply:Alive() then return end

    local droneClass = net.ReadString()
    local sid = ply:SteamID()

    if not ASYNC_DRONE_CLASSES[droneClass] then
        ply:ChatPrint("[ОС ЗАРЯ] Ошибка: неизвестный класс дрона.")
        return
    end

    local now = CurTime()
    if SpawnCooldowns[sid] and now < SpawnCooldowns[sid] then
        ply:ChatPrint("[ОС ЗАРЯ] Ошибка: повторная инициализация недоступна (перезарядка).")
        return
    end

    -- Если уже был дрон — вернуть оператора и удалить старый
    if ActiveDrones[sid] and IsValid(ActiveDrones[sid]) then
        ActiveDrones[sid]:Remove()
        ActiveDrones[sid] = nil
    end

    local spawnPos = ply:GetPos() + ply:GetForward() * 80 + Vector(0, 0, 30)
    local tr = util.TraceLine({
        start  = spawnPos + Vector(0, 0, 50),
        endpos = spawnPos - Vector(0, 0, 200),
        filter = ply,
        mask   = MASK_SOLID_BRUSHONLY,
    })
    if tr.Hit then
        spawnPos = tr.HitPos + Vector(0, 0, 15)
    end

    -- Создание прокси оператора на земле
    local proxy = CreateOperatorProxy(ply)
    OperatorProxies[sid] = proxy

    local drone = ents.Create(droneClass)
    if not IsValid(drone) then
        ply:ChatPrint("[ОС ЗАРЯ] СБОЙ: не удалось создать модуль БПЛА.")
        return
    end

    drone:SetPos(spawnPos)
    drone:SetAngles(Angle(0, ply:EyeAngles().y, 0))
    drone:Spawn()
    drone:Activate()
    drone:SetCreator(ply)

    drone._AsyncSpawned = true
    drone._AsyncOperator = ply

    -- 5.4 секунды блокировки для старта ESC
    local lockTime = CurTime() + 5.4
    drone:SetNWFloat("Async_ControlLockTime", lockTime)

    ActiveDrones[sid] = drone
    SpawnCooldowns[sid] = now + 4.0

    ply:SetNWEntity("KVN_ActiveDrone", drone)
    drone:SetNWEntity("AsyncOperator", ply)

    -- Посадка в сиденье водителя LVS для активации физики, органов управления и камеры
    timer.Simple(0.1, function()
        if not IsValid(drone) or not IsValid(ply) then return end

        local driverSeat = drone.GetDriverSeat and drone:GetDriverSeat()
        if IsValid(driverSeat) then
            ply:EnterVehicle(driverSeat)
        end
    end)

    -- Воспроизведение звуковой последовательности BLHeli
    ply:EmitSound("zasync/vkluchenie.mp3", 75, 100, 1)

    timer.Simple(0.3, function()
        if IsValid(ply) then
            ply:EmitSound("zasync/esc_startup.mp3", 75, 100, 1)
        end
    end)

    net.Start("Async_DroneStatus")
        net.WriteUInt(1, 2)
        net.WriteEntity(drone)
    net.Send(ply)

    ply:ChatPrint("[ОС ЗАРЯ v3.12] Модуль " .. droneClass:upper() .. " запущен. Выполняется диагностика ESC (5.4 сек)...")
end)
