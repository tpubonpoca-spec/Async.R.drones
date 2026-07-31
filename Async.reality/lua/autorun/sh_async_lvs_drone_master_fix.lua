--[[
    Фикс FPV дронов для Z-City (Async.reality)
    Файл: lua/autorun/sh_async_lvs_drone_master_fix.lua
--]]

if SERVER then
    AddCSLuaFile()

    -- 1. Принудительная передача данных дрона на клиент (TRANSMIT_ALWAYS)
    hook.Add("OnEntityCreated", "Async_LVS_ForceTransmitAlwaysForDrones", function(ent)
        timer.Simple(0, function()
            if IsValid(ent) then
                local cls = ent:GetClass():lower()
                local isDrone = ent.LVSUAV or ent.IsDrone or ent.IsCrocusKamikaze or ent.IsKVNDrone or cls:find("crocus") or cls:find("kvn") or cls:find("drone") or cls:find("uav")
                if isDrone then
                    function ent:UpdateTransmitState()
                        return TRANSMIT_ALWAYS
                    end
                end
            end
        end)
    end)

    -- 2. Защита оператора от взрыва своего дрона на расстоянии
    hook.Add("EntityTakeDamage", "Async_LVS_ProtectRemoteOperatorFromExplosion", function(target, dmginfo)
        if not IsValid(target) or not target:IsPlayer() then return end

        local veh = target:GetVehicle()
        if not IsValid(veh) then return end

        local parent = veh:GetParent()
        local drone = IsValid(parent) and parent or veh
        if not IsValid(drone) then return end

        local isLVSDrone = drone.LVSUAV or drone.IsDrone or drone.IsCrocusKamikaze or drone.IsKVNDrone or (drone:GetClass() and (drone:GetClass():lower():find("crocus") or drone:GetClass():lower():find("kvn") or drone:GetClass():lower():find("drone") or drone:GetClass():lower():find("uav")))

        if isLVSDrone then
            local groundPos = target.CrocusGroundPos or target.LVSGroundPos or target:GetPos()
            local explosionPos = dmginfo:GetReportedPosition()
            if not explosionPos or explosionPos == vector_origin then
                explosionPos = dmginfo:GetDamagePosition()
            end
            if not explosionPos or explosionPos == vector_origin then
                explosionPos = drone:GetPos()
            end

            -- Если взрыв дальше 200 юнитов от оператора на земле, блокируем урон
            if groundPos:Distance(explosionPos) > 200 then
                dmginfo:SetDamage(0)
                dmginfo:ScaleDamage(0)
                return true
            end
        end
    end)
end

if CLIENT then
    local function GetLVSVehicle(ply)
        if not IsValid(ply) or not ply:InVehicle() then return nil end

        local pod = ply:GetVehicle()
        if not IsValid(pod) then return nil end

        local veh = ply.lvsGetVehicle and ply:lvsGetVehicle() or nil
        if not IsValid(veh) then
            veh = pod.LVSBase or pod.Base or pod:GetNWEntity("LVSBase") or pod:GetNWEntity("LVS_Entity") or pod:GetParent()
        end

        if not IsValid(veh) then
            for _, e in ipairs(ents.FindByClass("lvs_*")) do
                if e.GetDriverSeat and e:GetDriverSeat() == pod then
                    veh = e
                    break
                end
            end
        end

        return IsValid(veh) and veh or pod
    end

    -- 3. Включение управления мышкой для дронов
    hook.Add("Think", "Async_LVS_ForceMouseAimForDrones", function()
        local ply = LocalPlayer()
        if not IsValid(ply) then return end

        local veh = GetLVSVehicle(ply)
        if IsValid(veh) then
            local cls = veh:GetClass():lower()
            local isDrone = veh.LVSUAV or veh.IsDrone or veh.IsCrocusKamikaze or veh.IsKVNDrone or cls:find("crocus") or cls:find("kvn") or cls:find("drone") or cls:find("uav")
            if isDrone then
                ply._lvsMouseAim = true
            end
        end
    end)

    -- 4. Камера от 1 лица на носу дрона с фиксацией 1 к 1 по корпусу
    hook.Add("CalcView", "Async_LVS_Drone_Master_CalcView", function(ply, pos, angles, fov)
        if not IsValid(ply) or ply:GetViewEntity() ~= ply then return end

        local pod = ply:GetVehicle()
        if not IsValid(pod) then return end

        local veh = GetLVSVehicle(ply)
        if not IsValid(veh) or (veh.GetHP and veh:GetHP() <= 0) or veh._lvsIsDestroyed then return end

        local cls = veh:GetClass():lower()
        local isDrone = veh.LVSUAV or veh.IsDrone or veh.IsCrocusKamikaze or veh.IsKVNDrone or cls:find("crocus") or cls:find("kvn") or cls:find("drone") or cls:find("uav")

        if isDrone then
            local base = pod.lvsGetWeapon and pod:lvsGetWeapon() or nil
            local weapon = IsValid(base) and base:GetActiveWeapon() or (veh.GetActiveWeapon and veh:GetActiveWeapon() or nil)

            -- Если у оружия дрона есть своя камера (например, KVN)
            if weapon and weapon.CalcView then
                local v = weapon.CalcView(veh, ply, pos, angles, fov, pod)
                if istable(v) and isvector(v.origin) then
                    v.angles = veh:GetAngles()
                    v.fov = math.Clamp(v.fov or fov or 75, 30, 110)
                    v.drawviewer = false
                    return v
                end
            end

            -- Вынос камеры на передний объектив
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
