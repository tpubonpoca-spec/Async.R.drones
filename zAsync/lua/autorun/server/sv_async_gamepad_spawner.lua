--[[
    Серверный модуль дистанционного управления FPV-дронами (zAsync)
    Стиль: ОС "ЗАРЯ" v3.12 (Минобороны РФ / Ростех)

    - Настоящий игрок СТОИТ НА ЗЕМЛЕ в своём физическом теле.
    - Никаких прокси, подмен, NPC или входов в транспортные кресла.
    - Передача управления в LVS систему через drone:SetDriver(ply).
    - Клавиша E (+use) — экстренное отключение связи.
    - Стартовые звуки (vkluchenie.mp3 -> 0.3s -> esc_startup.mp3) + блокировка 5.4с.
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

-- При получении урона игроком на земле — прерывание связи
hook.Add("PlayerHurt", "Async_OperatorHurtDisconnect", function(ply, attacker, healthRemaining, damageTaken)
    if not IsValid(ply) or not ply:Alive() then return end

    local activeDrone = ply:GetNWEntity("KVN_ActiveDrone")
    if IsValid(activeDrone) then
        if activeDrone.SetDriver then activeDrone:SetDriver(NULL) end
        ply:SetNWEntity("KVN_ActiveDrone", NULL)
        ply:SetNWEntity("LVS_Vehicle", NULL)
        ply:EmitSound("buttons/button10.wav", 75, 90)
        ply:ChatPrint("[ОС ЗАРЯ] ВНИМАНИЕ: Потеря сигнала связи из-за получения урона оператором на земле!")
    end
end)

hook.Add("PlayerDeath", "Async_OperatorDeathCleanup", function(ply)
    local sid = ply:SteamID()
    if ActiveDrones[sid] and IsValid(ActiveDrones[sid]) then
        ActiveDrones[sid]:Remove()
    end
    ActiveDrones[sid] = nil
    ply:SetNWEntity("KVN_ActiveDrone", NULL)
    ply:SetNWEntity("LVS_Vehicle", NULL)
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
                owner:SetNWEntity("LVS_Vehicle", NULL)
                net.Start("Async_DroneStatus")
                    net.WriteUInt(0, 2)
                net.Send(owner)
            end
            break
        end
    end
end)

-- Отключение по клавише E или кнопке в меню
net.Receive("Async_DisconnectDrone", function(len, ply)
    if not IsValid(ply) then return end

    local activeDrone = ply:GetNWEntity("KVN_ActiveDrone")
    if IsValid(activeDrone) then
        if activeDrone.SetDriver then activeDrone:SetDriver(NULL) end
        ply:SetNWEntity("KVN_ActiveDrone", NULL)
        ply:SetNWEntity("LVS_Vehicle", NULL)
        ply:EmitSound("buttons/button10.wav", 75, 100)
        ply:ChatPrint("[ОС ЗАРЯ] Оператор отключился от канала связи БПЛА.")
    end
end)

-- Резервный физический контроллер управления для корректного полета дронов в LVS
hook.Add("StartCommand", "Async_DroneRemoteFlightController", function(ply, cmd)
    if not IsValid(ply) or not ply:Alive() then return end

    local drone = ply:GetNWEntity("KVN_ActiveDrone")
    if not IsValid(drone) then return end

    -- Клавиша E (IN_USE) — отключение от дрона
    if cmd:KeyDown(IN_USE) then
        if drone.SetDriver then drone:SetDriver(NULL) end
        ply:SetNWEntity("KVN_ActiveDrone", NULL)
        ply:SetNWEntity("LVS_Vehicle", NULL)
        ply:EmitSound("buttons/button10.wav", 75, 100)
        ply:ChatPrint("[ОС ЗАРЯ] Связь разорвана по нажатию E.")
        return
    end

    local lockTime = drone:GetNWFloat("Async_ControlLockTime", 0)
    if CurTime() < lockTime then return end

    local phys = drone:GetPhysicsObject()
    if not IsValid(phys) then return end

    -- Чтение клавиш управления
    local fwd = 0
    if cmd:KeyDown(IN_FORWARD) then fwd = fwd + 1 end
    if cmd:KeyDown(IN_BACK) then fwd = fwd - 1 end

    local side = 0
    if cmd:KeyDown(IN_MOVERIGHT) then side = side + 1 end
    if cmd:KeyDown(IN_MOVELEFT) then side = side - 1 end

    local up = 0
    if cmd:KeyDown(IN_JUMP) then up = up + 1 end
    if cmd:KeyDown(IN_SPEED) or cmd:KeyDown(IN_DUCK) then up = up - 1 end

    local eyeAng = ply:EyeAngles()
    local targetAng = Angle(eyeAng.p, eyeAng.y, side * -20)
    phys:SetAngles(LerpAngle(0.15, phys:GetAngles(), targetAng))

    local moveVec = drone:GetForward() * fwd * 1400 + drone:GetRight() * side * 700 + Vector(0, 0, up * 900)
    phys:AddVelocity(moveVec * FrameTime())

    -- ЛКМ — подрыв камикадзе
    if cmd:KeyDown(IN_ATTACK) and drone:GetClass() == "lvs_kvn1" then
        if drone.Detonate then
            drone:Detonate()
        else
            util.BlastDamage(drone, ply, drone:GetPos(), 250, 400)
            local ed = EffectData()
            ed:SetOrigin(drone:GetPos())
            util.Effect("Explosion", ed)
            drone:Remove()
        end
    end
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

    -- НАСТОЯЩИЙ ИГРОК ОСТАЁТСЯ СТОЯТЬ НА ЗЕМЛЕ (без входа в кресло!)
    ply:SetNWEntity("KVN_ActiveDrone", drone)
    ply:SetNWEntity("LVS_Vehicle", drone)
    drone:SetNWEntity("AsyncOperator", ply)

    -- Назначение водителя LVS удаленно без EnterVehicle
    if drone.SetDriver then drone:SetDriver(ply) end
    if drone.SetEngineUser then drone:SetEngineUser(ply) end

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

    ply:ChatPrint("[ОС ЗАРЯ v3.12] Модуль " .. droneClass:upper() .. " запущен. Вы остаётесь на земле. Инициализация ESC (5.4 сек)...")
end)
