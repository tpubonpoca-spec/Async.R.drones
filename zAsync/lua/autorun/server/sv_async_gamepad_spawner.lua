--[[
    Серверный спавнер дронов (zAsync + Crocus Remastered + Mavic 2 Remastered)
--]]

if not SERVER then return end

util.AddNetworkString("Async_SpawnDrone")
util.AddNetworkString("Async_DroneStatus")
util.AddNetworkString("Async_DisconnectDrone")

local ASYNC_DRONE_CLASSES = {
    ["lvs_kvn1"] = true,
    ["lvs_kvn2"] = true,
    ["lvs_kvn3"] = true,
    ["lvs_crocus"] = true,
    ["lvs_crocus_remastered"] = true,
    ["mavic_2_remastered"] = true,
    ["lvs_mavic2"] = true,
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
    local cls = ent:GetClass():lower()
    local isDrone = ASYNC_DRONE_CLASSES[cls] or ent.LVSUAV or cls:find("crocus") or cls:find("mavic")
    if not isDrone then return end

    for sid, drone in pairs(ActiveDrones) do
        if drone == ent then
            ActiveDrones[sid] = nil
            local owner = ent._AsyncOperator
            if IsValid(owner) then
                if owner:InVehicle() and owner._LVSGroundPos then
                    owner:ExitVehicle()
                    owner:SetPos(owner._LVSGroundPos)
                end
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

    local groundPos = ply._LVSGroundPos
    if ply:InVehicle() then
        ply:ExitVehicle()
        if groundPos then ply:SetPos(groundPos) end
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

    local clsLower = droneClass:lower()
    if not (ASYNC_DRONE_CLASSES[clsLower] or clsLower:find("crocus") or clsLower:find("mavic") or clsLower:find("kvn")) then
        return
    end

    local now = CurTime()
    if SpawnCooldowns[sid] and now < SpawnCooldowns[sid] then return end

    if ActiveDrones[sid] and IsValid(ActiveDrones[sid]) then
        ActiveDrones[sid]:Remove()
        ActiveDrones[sid] = nil
    end

    -- Запоминаем наземную позицию оператора перед входом для защиты и возврата
    ply._LVSGroundPos = ply:GetPos()

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
        -- Единый фоллбэк если специфический класс не установлен
        drone = ents.Create("lvs_kvn1")
    end

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

    timer.Simple(0.1, function()
        if not IsValid(drone) or not IsValid(ply) then return end
        local driverSeat = drone.GetDriverSeat and drone:GetDriverSeat()
        if IsValid(driverSeat) then
            ply:EnterVehicle(driverSeat)
        end
    end)

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
