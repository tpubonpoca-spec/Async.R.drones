--[[
    Серверный менеджер спавна и управления FPV-дронами (zAsync)
    Файл: lua/autorun/server/sv_async_gamepad_spawner.lua

    - Оператор остаётся стоя на земле в своей естественной позиции.
    - Никаких невидимых кресел или иммунитета от урона.
    - При получении урона оператором или гибели — связь раскрывается.
    - Стартовые звуки (vkluchenie.mp3 -> 0.3s -> esc_startup.mp3) + блокировка управления на 5.4 секунды.
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
local SpawnCooldowns = {}

-- Отключение дрона при получении урона или смерти оператора
hook.Add("PlayerHurt", "Async_OperatorHurtDisconnect", function(ply, attacker, healthRemaining, damageTaken)
    if not IsValid(ply) or not ply:Alive() then return end

    local activeDrone = ply:GetNWEntity("KVN_ActiveDrone")
    if IsValid(activeDrone) then
        ply:SetNWEntity("KVN_ActiveDrone", NULL)
        ply:EmitSound("buttons/button10.wav", 75, 90)
        ply:ChatPrint("[zAsync] ВНИМАНИЕ: Потеря сигнала связи из-за получения урона оператором!")
    end
end)

hook.Add("PlayerDeath", "Async_OperatorDeathCleanup", function(ply)
    local sid = ply:SteamID()
    if ActiveDrones[sid] and IsValid(ActiveDrones[sid]) then
        ActiveDrones[sid]:Remove()
    end
    ActiveDrones[sid] = nil
    ply:SetNWEntity("KVN_ActiveDrone", NULL)
end)

hook.Add("PlayerDisconnected", "Async_CleanupOnDisconnect", function(ply)
    local sid = ply:SteamID()
    if ActiveDrones[sid] and IsValid(ActiveDrones[sid]) then
        ActiveDrones[sid]:Remove()
    end
    ActiveDrones[sid] = nil
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
                owner:SetNWEntity("KVN_ActiveDrone", NULL)
                net.Start("Async_DroneStatus")
                    net.WriteUInt(0, 2)
                net.Send(owner)
            end
            break
        end
    end
end)

-- Ручное отключение от дрона (клавиша R / F6)
net.Receive("Async_DisconnectDrone", function(len, ply)
    if not IsValid(ply) then return end
    local activeDrone = ply:GetNWEntity("KVN_ActiveDrone")
    if IsValid(activeDrone) then
        ply:SetNWEntity("KVN_ActiveDrone", NULL)
        ply:EmitSound("buttons/button10.wav", 75, 100)
        ply:ChatPrint("[zAsync] Оператор отключился от связи с дроном.")
    end
end)

-- Запрос на спавн/запуск дрона
net.Receive("Async_SpawnDrone", function(len, ply)
    if not IsValid(ply) or not ply:Alive() then return end

    local droneClass = net.ReadString()
    local sid = ply:SteamID()

    if not ASYNC_DRONE_CLASSES[droneClass] then
        ply:ChatPrint("[zAsync] Ошибка: неизвестный класс дрона.")
        return
    end

    local now = CurTime()
    if SpawnCooldowns[sid] and now < SpawnCooldowns[sid] then
        ply:ChatPrint("[zAsync] ВНИМАНИЕ: Перезарядка пускового блока.")
        return
    end

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

    local drone = ents.Create(droneClass)
    if not IsValid(drone) then
        ply:ChatPrint("[zAsync] Ошибка инициализации дрона.")
        return
    end

    drone:SetPos(spawnPos)
    drone:SetAngles(Angle(0, ply:EyeAngles().y, 0))
    drone:Spawn()
    drone:Activate()
    drone:SetCreator(ply)

    drone._AsyncSpawned = true
    drone._AsyncOperator = ply

    -- Блокировка управления на 5.4 секунды для звуков инициализации
    local lockTime = CurTime() + 5.4
    drone:SetNWFloat("Async_ControlLockTime", lockTime)

    ActiveDrones[sid] = drone
    SpawnCooldowns[sid] = now + 4.0

    -- Связываем оператора с дроном НАЗЕМНО (без входа в кресло!)
    ply:SetNWEntity("KVN_ActiveDrone", drone)
    drone:SetNWEntity("AsyncOperator", ply)

    -- Воспроизведение звуковой последовательности включения:
    -- 1. vkluchenie.mp3 сразу
    -- 2. esc_startup.mp3 через 0.3 секунды
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

    ply:ChatPrint("[zAsync] FPV Дрон (" .. droneClass:upper() .. ") запущен. Инициализация ESC (5.4 сек)...")
end)
