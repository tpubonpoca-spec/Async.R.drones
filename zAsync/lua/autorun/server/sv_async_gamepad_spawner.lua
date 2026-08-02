--[[
    Стабильный серверный модуль FPV-дронов (zAsync)
    - Использование нативной системы LVS для управления, физики, звуков и камеры.
    - Выход по клавише E (+use).
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
                if owner:InVehicle() then owner:ExitVehicle() end
                owner:SetNWEntity("KVN_ActiveDrone", NULL)
                net.Start("Async_DroneStatus")
                    net.WriteUInt(0, 2)
                net.Send(owner)
            end
            break
        end
    end
end)

net.Receive("Async_DisconnectDrone", function(len, ply)
    if not IsValid(ply) then return end

    if ply:InVehicle() then
        ply:ExitVehicle()
    end

    local activeDrone = ply:GetNWEntity("KVN_ActiveDrone")
    if IsValid(activeDrone) then
        activeDrone:Remove()
    end

    ply:SetNWEntity("KVN_ActiveDrone", NULL)
    ply:EmitSound("buttons/button10.wav", 75, 100)
end)

net.Receive("Async_SpawnDrone", function(len, ply)
    if not IsValid(ply) or not ply:Alive() then return end

    local droneClass = net.ReadString()
    local sid = ply:SteamID()

    if not ASYNC_DRONE_CLASSES[droneClass] then return end

    local now = CurTime()
    if SpawnCooldowns[sid] and now < SpawnCooldowns[sid] then return end

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
    if not IsValid(drone) then return end

    drone:SetPos(spawnPos)
    drone:SetAngles(Angle(0, ply:EyeAngles().y, 0))
    drone:Spawn()
    drone:Activate()
    drone:SetCreator(ply)

    drone._AsyncSpawned = true
    drone._AsyncOperator = ply

    local lockTime = CurTime() + 5.4
    drone:SetNWFloat("Async_ControlLockTime", lockTime)

    ActiveDrones[sid] = drone
    SpawnCooldowns[sid] = now + 4.0

    ply:SetNWEntity("KVN_ActiveDrone", drone)

    -- Нативная посадка водителя LVS для 100% управления и стабильной камеры
    timer.Simple(0.1, function()
        if not IsValid(drone) or not IsValid(ply) then return end
        local driverSeat = drone.GetDriverSeat and drone:GetDriverSeat()
        if IsValid(driverSeat) then
            ply:EnterVehicle(driverSeat)
        end
    end)

    -- Стартовая звуковая последовательность BLHeli
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
end)
