--[[
    Серверный менеджер спавна дронов через пульт Async Gamepad
    Файл: lua/autorun/server/sv_async_gamepad_spawner.lua

    Обрабатывает запрос клиента на спавн выбранного дрона,
    создаёт его рядом с оператором, привязывает провод и
    автоматически сажает игрока в кабину.
--]]

if not SERVER then return end

util.AddNetworkString("Async_SpawnDrone")
util.AddNetworkString("Async_DroneStatus")

-- Допустимые классы дронов
local ASYNC_DRONE_CLASSES = {
    ["lvs_kvn1"] = true,
    ["lvs_kvn2"] = true,
    ["lvs_kvn3"] = true,
}

-- Активные дроны по игрокам (SteamID -> Entity)
local ActiveDrones = {}

-- Кулдаун между спавнами (секунды)
local SPAWN_COOLDOWN = 3
local SpawnCooldowns = {}

-- Очистка при отключении игрока
hook.Add("PlayerDisconnected", "Async_Gamepad_CleanupOnDisconnect", function(ply)
    local sid = ply:SteamID()
    if ActiveDrones[sid] and IsValid(ActiveDrones[sid]) then
        ActiveDrones[sid]:Remove()
    end
    ActiveDrones[sid] = nil
    SpawnCooldowns[sid] = nil
end)

-- Очистка при удалении дрона
hook.Add("EntityRemoved", "Async_Gamepad_CleanupDrone", function(ent)
    if not IsValid(ent) then return end
    local cls = ent:GetClass()
    if not ASYNC_DRONE_CLASSES[cls] then return end

    for sid, drone in pairs(ActiveDrones) do
        if drone == ent then
            ActiveDrones[sid] = nil

            -- Уведомление клиента: дрон уничтожен
            local owner = ent._AsyncOperator
            if IsValid(owner) then
                net.Start("Async_DroneStatus")
                    net.WriteUInt(0, 2) -- 0 = дрон уничтожен
                net.Send(owner)
            end
            break
        end
    end
end)

-- Приём запроса на спавн
net.Receive("Async_SpawnDrone", function(len, ply)
    if not IsValid(ply) then return end

    local droneClass = net.ReadString()
    local sid = ply:SteamID()

    -- Проверка класса
    if not ASYNC_DRONE_CLASSES[droneClass] then
        ply:ChatPrint("[zAsync] Неизвестный тип дрона.")
        return
    end

    -- Проверка кулдауна
    local now = CurTime()
    if SpawnCooldowns[sid] and now < SpawnCooldowns[sid] then
        ply:ChatPrint("[zAsync] Подождите перед повторным запуском.")
        return
    end

    -- Если есть активный дрон — удалить старый
    if ActiveDrones[sid] and IsValid(ActiveDrones[sid]) then
        ActiveDrones[sid]:Remove()
        ActiveDrones[sid] = nil
    end

    -- Определение позиции спавна: перед игроком на уровне земли
    local spawnPos = ply:GetPos() + ply:GetForward() * 80 + Vector(0, 0, 30)

    -- Трейс вниз, чтобы не заспавнить в воздухе
    local tr = util.TraceLine({
        start  = spawnPos + Vector(0, 0, 50),
        endpos = spawnPos - Vector(0, 0, 200),
        filter = ply,
        mask   = MASK_SOLID_BRUSHONLY,
    })

    if tr.Hit then
        spawnPos = tr.HitPos + Vector(0, 0, 15)
    end

    -- Создание дрона
    local drone = ents.Create(droneClass)
    if not IsValid(drone) then
        ply:ChatPrint("[zAsync] Ошибка создания дрона.")
        return
    end

    drone:SetPos(spawnPos)
    drone:SetAngles(Angle(0, ply:EyeAngles().y, 0))
    drone:Spawn()
    drone:Activate()
    drone:SetCreator(ply)

    -- Пометить дрон как заспавненный через геймпад
    drone._AsyncSpawned = true
    drone._AsyncOperator = ply

    -- Сохранить наземную позицию оператора для телепортации обратно после уничтожения
    drone._AsyncOperatorGroundPos = ply:GetPos()

    -- Регистрация
    ActiveDrones[sid] = drone
    SpawnCooldowns[sid] = now + SPAWN_COOLDOWN

    -- Привязка NW-сущностей
    ply:SetNWEntity("KVN_ActiveDrone", drone)
    drone:SetNWEntity("AsyncOperator", ply)

    -- Создание визуального кабеля от оператора к дрону
    local vOut = Vector(-16, 0, 0) -- точка выхода кабеля на дроне
    if droneClass == "lvs_kvn3" then
        vOut = Vector(-13, 0, 0)
    end

    timer.Simple(0.2, function()
        if not IsValid(drone) or not IsValid(ply) then return end

        -- Находим pod дрона и сажаем туда игрока
        local driverSeat = drone.GetDriverSeat and drone:GetDriverSeat()
        if IsValid(driverSeat) then
            ply:EnterVehicle(driverSeat)
        end

        -- Уведомление клиента: дрон готов к управлению
        net.Start("Async_DroneStatus")
            net.WriteUInt(1, 2) -- 1 = дрон активен
            net.WriteEntity(drone)
        net.Send(ply)
    end)

    ply:ChatPrint("[zAsync] Дрон " .. droneClass .. " запущен.")
end)
