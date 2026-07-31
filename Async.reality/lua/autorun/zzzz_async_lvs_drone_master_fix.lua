--[[
    Master LVS FPV Drone Compatibility & Camera Fix for Z-City / Homigrad
    Filename: zzzz_async_lvs_drone_master_fix.lua
--]]

if SERVER then
    -- 1. Universal Remote Operator Explosion Damage Protection
    hook.Add("EntityTakeDamage", "ZZZZ_LVS_ProtectRemoteOperatorFromExplosion", function(target, dmginfo)
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

            -- If explosion is farther than 200 units from the operator's ground position, cancel remote splash damage
            if groundPos:Distance(explosionPos) > 200 then
                dmginfo:SetDamage(0)
                dmginfo:ScaleDamage(0)
                return true
            end
        end
    end)
end

if CLIENT then
    -- 2. Force Mouse Aim Steering for LVS Drones
    hook.Add("Think", "ZZZZ_LVS_ForceMouseAimForDrones", function()
        local ply = LocalPlayer()
        if not IsValid(ply) then return end

        local veh = ply.lvsGetVehicle and ply:lvsGetVehicle() or nil
        if not IsValid(veh) and ply:InVehicle() then
            local pod = ply:GetVehicle()
            if IsValid(pod) then
                local parent = pod:GetParent()
                veh = IsValid(parent) and parent or pod
            end
        end

        if IsValid(veh) then
            local cls = veh:GetClass():lower()
            local isDrone = veh.LVSUAV or veh.IsDrone or veh.IsCrocusKamikaze or veh.IsKVNDrone or cls:find("crocus") or cls:find("kvn") or cls:find("drone") or cls:find("uav")
            if isDrone then
                ply._lvsMouseAim = true
            end
        end
    end)

    -- 3. Master FPV Camera Fix: Locks 1:1 to drone frame and positions view on the front nose lens
    hook.Add("CalcView", "zzzz_LVS_Drone_Master_CalcView", function(ply, pos, angles, fov)
        if not IsValid(ply) or ply:GetViewEntity() ~= ply then return end

        local pod = ply:GetVehicle()
        if not IsValid(pod) then return end

        local veh = ply.lvsGetVehicle and ply:lvsGetVehicle() or nil
        if not IsValid(veh) then
            local parent = pod:GetParent()
            veh = IsValid(parent) and parent or pod
        end

        if not IsValid(veh) then return end

        local cls = veh:GetClass():lower()
        local isDrone = veh.LVSUAV or veh.IsDrone or veh.IsCrocusKamikaze or veh.IsKVNDrone or cls:find("crocus") or cls:find("kvn") or cls:find("drone") or cls:find("uav")

        if isDrone then
            local view = {}

            -- Determine FPV Camera Origin at the Front Nose Lens
            local camAtt = veh:LookupAttachment("camera")
            if camAtt == 0 then camAtt = veh:LookupAttachment("eyes") end
            if camAtt == 0 then camAtt = veh:LookupAttachment("fpv") end

            if camAtt and camAtt > 0 then
                local att = veh:GetAttachment(camAtt)
                if att then view.origin = att.Pos end
            end

            if not view.origin then
                -- Position at front nose lens of the drone
                view.origin = veh:LocalToWorld(Vector(15, 0, 4))
            end

            -- Lock camera angles 1:1 rigidly to the drone frame
            view.angles = veh:GetAngles()
            view.fov = fov or 75
            view.drawviewer = false

            return view
        end
    end)
end
