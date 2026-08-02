--[[
    Серверный модуль FPV-дронов (zAsync)
    - Исправлена синтаксическая ошибка GLua в ветвлении классов.
    - Регистрируются все сетевые сообщения для клиента.
--]]

if not SERVER then return end

util.AddNetworkString("Async_SpawnDrone")
util.AddNetworkString("Async_DroneStatus")
util.AddNetworkString("Async_DisconnectDrone")

local ASYNC_DRONE_CLASSES = {
    ["lvs_kvn1"]        = true,
    ["lvs_kvn2"]        = true,
    ["lvs_kvn3"]        = true,
    ["sw_crocus"]       = true,
    ["sw_crocus_pg7"]   = true,
    ["sw_crocus_tbg7"]  = true,
    ["sw_mavic_2"]      = true,
    ["sw_mavic2"]       = true,
    ["lvs_mavic2"]      = true,
    ["mavic2"]          = true,
}

local ActiveDrones = {}
local SpawnCooldowns = {}

local function SafeReturnOperatorToGround(ply, drone)
    if not IsValid(ply) then return end

    local groundPos = ply._LVSGroundPos
    if ply:InVehicle() then
        ply:ExitVehicle()
    end

    if groundPos then
        ply:SetPos(groundPos)
    end

    ply:SetNWEntity("KVN_ActiveDrone", NULL)
    ply:SetNWEntity("LVS_Vehicle", NULL)
end

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

hook.Add("EntityTakeDamage", "Async_EjectOperatorBeforeDroneExplodes", function(ent, dmginfo)
    if not IsValid(ent) then return end
    local cls = ent:GetClass():lower()
    local isDrone = ASYNC_DRONE_CLASSES[cls] or ent.LVSUAV or cls:find("crocus") or cls:find("mavic") or cls:find("kvn")
    if not isDrone then return end

    local owner = ent._AsyncOperator
    if IsValid(owner) and (ent:GetHP() <= dmginfo:GetDamage() or dmginfo:IsExplosiveDamage()) then
        SafeReturnOperatorToGround(owner, ent)
    end
end)

hook.Add("EntityRemoved", "Async_CleanupDrone", function(ent)
    if not IsValid(ent) then return end
    local cls = ent:GetClass():lower()
    local isDrone = ASYNC_DRONE_CLASSES[cls] or ent.LVSUAV or cls:find("crocus") or cls:find("mavic") or cls:find("kvn")
    if not isDrone then return end

    for sid, drone in pairs(ActiveDrones) do
        if drone == ent then
            ActiveDrones[sid] = nil
            local owner = ent._AsyncOperator
            if IsValid(owner) then
                SafeReturnOperatorToGround(owner, ent)
                net.Start("Async_DroneStatus")
                    net.WriteUInt(0, 2)
                net.Send(owner)
            end
            break
        end
    end
end)

hook.Add("LVS:CanToggleEngine", "Async_ProhibitManualEngineToggle", function(drone, ply)
    if IsValid(drone) and (drone._AsyncSpawned or ASYNC_DRONE_CLASSES[drone:GetClass():lower()]) then
        return false
    end
end)

net.Receive("Async_DisconnectDrone", function(len, ply)
    if not IsValid(ply) then return end

    local activeDrone = ply:GetNWEntity("KVN_ActiveDrone")
    SafeReturnOperatorToGround(ply, activeDrone)
end)

net.Receive("Async_SpawnDrone", function(len, ply)
    if not IsValid(ply) or not ply:Alive() then return end

    local droneClass = net.ReadString()
    local sid = ply:SteamID()

    local clsLower = droneClass:lower()
    if not ASYNC_DRONE_CLASSES[clsLower] then
        if clsLower:find("crocus") then
            droneClass = "sw_crocus_pg7"
        elseif clsLower:find("mavic") then
            droneClass = "sw_mavic_2"
        else
            droneClass = "lvs_kvn1"
        end
        clsLower = droneClass:lower()
    end

    local now = CurTime()
    if SpawnCooldowns[sid] and now < SpawnCooldowns[sid] then return end

    if ActiveDrones[sid] and IsValid(ActiveDrones[sid]) then
        ActiveDrones[sid]:Remove()
        ActiveDrones[sid] = nil
    end

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

    drone:EmitSound("zasync/vkluchenie.mp3", 75, 100)

    timer.Simple(0.3, function()
        if IsValid(drone) then
            drone:EmitSound("zasync/esc_startup.mp3", 75, 100)
        end
    end)

    timer.Simple(5.4, function()
        if IsValid(drone) and IsValid(ply) then
            if drone.SetEngineUser then drone:SetEngineUser(ply) end
            if drone.SetEngineActive then drone:SetEngineActive(true) end
            if drone.StartEngine then drone:StartEngine() end
        end
    end)

    net.Start("Async_DroneStatus")
        net.WriteUInt(1, 2)
        net.WriteEntity(drone)
    net.Send(ply)
end)
