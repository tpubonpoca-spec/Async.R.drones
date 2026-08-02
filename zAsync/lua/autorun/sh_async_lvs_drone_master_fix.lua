--[[
    Фикс FPV дронов (zAsync + Crocus Remastered + Mavic 2 Remastered)
    - Гарантированная защита оператора на земле от урона детонации дрона на расстоянии (>150u).
    - Моментальный забор игрока из кресла при получении фатального урона дроном.
--]]

local function GetLVSVehicle(ply)
    if not IsValid(ply) then return nil end

    if ply.lvsGetVehicle then
        local v = ply:lvsGetVehicle()
        if IsValid(v) then return v end
    end

    if IsValid(ply.LVS_Vehicle) then return ply.LVS_Vehicle end

    local nwVeh = ply:GetNWEntity("LVS_Vehicle")
    if IsValid(nwVeh) then return nwVeh end

    local activeDrone = ply:GetNWEntity("KVN_ActiveDrone")
    if IsValid(activeDrone) then return activeDrone end

    if ply:InVehicle() then
        local pod = ply:GetVehicle()
        if IsValid(pod) then
            local veh = pod:GetNWEntity("LVS_Entity") or pod:GetNWEntity("LVSBase") or pod.LVSBase or pod.Base or pod:GetParent()
            if IsValid(veh) and veh ~= pod then return veh end

            for _, e in ipairs(ents.FindByClass("lvs_*")) do
                if e.GetDriverSeat and e:GetDriverSeat() == pod then
                    return e
                end
            end
            return pod
        end
    end

    return nil
end

if SERVER then
    AddCSLuaFile()

    hook.Add("OnEntityCreated", "Async_LVS_ForceTransmitAlwaysForDrones", function(ent)
        timer.Simple(0, function()
            if IsValid(ent) then
                local cls = ent:GetClass():lower()
                local isDrone = ent.LVSUAV or ent.IsDrone or ent.IsCrocusKamikaze or ent.IsKVNDrone or cls:find("crocus") or cls:find("kvn") or cls:find("drone") or cls:find("uav") or cls:find("mavic")
                if isDrone then
                    function ent:UpdateTransmitState()
                        return TRANSMIT_ALWAYS
                    end
                end
            end
        end)
    end)

    -- Абсолютная защита оператора от дистанционного взрыва собственного дрона
    hook.Add("EntityTakeDamage", "Async_LVS_ProtectRemoteOperatorFromExplosion", function(target, dmginfo)
        if not IsValid(target) or not target:IsPlayer() then return end

        local drone = GetLVSVehicle(target)
        if not IsValid(drone) then return end

        local cls = drone:GetClass():lower()
        local isLVSDrone = drone.LVSUAV or drone.IsDrone or drone.IsCrocusKamikaze or drone.IsKVNDrone or cls:find("crocus") or cls:find("kvn") or cls:find("drone") or cls:find("uav") or cls:find("mavic")

        if isLVSDrone then
            local groundPos = target._LVSGroundPos
            local explosionPos = dmginfo:GetReportedPosition()
            if not explosionPos or explosionPos == vector_origin then
                explosionPos = dmginfo:GetDamagePosition()
            end
            if not explosionPos or explosionPos == vector_origin then
                explosionPos = drone:GetPos()
            end

            -- Если оператор стопорится на земле за 150u от детонации — урон отменяется, а игрок возвращается на землю
            if groundPos and groundPos:Distance(explosionPos) > 150 then
                dmginfo:SetDamage(0)
                dmginfo:ScaleDamage(0)
                if target:InVehicle() then
                    target:ExitVehicle()
                    target:SetPos(groundPos)
                end
                return true
            end

            local attacker = dmginfo:GetAttacker()
            local inflictor = dmginfo:GetInflictor()
            if attacker == drone or inflictor == drone or attacker == target or inflictor == target then
                dmginfo:SetDamage(0)
                dmginfo:ScaleDamage(0)
                if target:InVehicle() and groundPos then
                    target:ExitVehicle()
                    target:SetPos(groundPos)
                end
                return true
            end
        end
    end)
end

if CLIENT then
    hook.Add("Think", "Async_LVS_ForceMouseAimForDrones", function()
        local ply = LocalPlayer()
        if not IsValid(ply) then return end

        local veh = GetLVSVehicle(ply)
        if IsValid(veh) then
            local cls = veh:GetClass():lower()
            local isDrone = veh.LVSUAV or veh.IsDrone or veh.IsCrocusKamikaze or veh.IsKVNDrone or cls:find("crocus") or cls:find("kvn") or cls:find("drone") or cls:find("uav") or cls:find("mavic")
            if isDrone then
                ply._lvsMouseAim = true
            end
        end
    end)

    hook.Add("CalcView", "Async_LVS_Drone_Master_CalcView", function(ply, pos, angles, fov)
        if not IsValid(ply) or ply:GetViewEntity() ~= ply then return end

        local veh = GetLVSVehicle(ply)
        if not IsValid(veh) or (veh.GetHP and veh:GetHP() <= 0) or veh._lvsIsDestroyed then return end

        local cls = veh:GetClass():lower()
        local isDrone = veh.LVSUAV or veh.IsDrone or veh.IsCrocusKamikaze or veh.IsKVNDrone or cls:find("crocus") or cls:find("kvn") or cls:find("drone") or cls:find("uav") or cls:find("mavic")

        if isDrone then
            local pod = ply:InVehicle() and ply:GetVehicle() or nil
            local base = IsValid(pod) and (pod.lvsGetWeapon and pod:lvsGetWeapon() or nil) or nil
            local weapon = IsValid(base) and base:GetActiveWeapon() or (veh.GetActiveWeapon and veh:GetActiveWeapon() or nil)

            if weapon and weapon.CalcView then
                local v = weapon.CalcView(veh, ply, pos, angles, fov, pod)
                if istable(v) and isvector(v.origin) then
                    v.angles = veh:GetAngles()
                    v.fov = math.Clamp(v.fov or fov or 75, 30, 110)
                    v.drawviewer = false
                    return v
                end
            end

            local view = {}
            local camAtt = veh:LookupAttachment("camera")
            if camAtt == 0 then camAtt = veh:LookupAttachment("eyes") end
            if camAtt == 0 then camAtt = veh:LookupAttachment("fpv") end

            if camAtt and camAtt > 0 then
                local att = veh:GetAttachment(camAtt)
                if att and att.Pos and att.Pos ~= vector_origin then
                    view.origin = att.Pos
                end
            end

            if not view.origin then
                view.origin = veh:LocalToWorld(Vector(15, 0, 4))
            end

            view.angles = veh:GetAngles()
            view.fov = math.Clamp(fov or 75, 30, 110)
            view.drawviewer = false

            return view
        end
    end)
end
