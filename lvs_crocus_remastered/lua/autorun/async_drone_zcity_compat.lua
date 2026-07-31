--[[
    Async.R.drones - Z-City <-> LVS Drones Compatibility Module (Universal Drone Support)
    
    Supported Drones:
    - Crocus FPV Drones (sw_crocus, sw_crocus_pg7, sw_crocus_tbg7)
    - KVN Fiber Optic Drones (lvs_kvn1, lvs_kvn2, lvs_kvn3)
    - Any LVS Drone Entity

    Fixed mechanics:
    1. Operator's real body stays at ground station position during flight (no dragging).
    2. Drone camera view and HUD remain 100% original FPV.
    3. Operator ONLY receives explosion damage if physically within the real blast radius of the explosion.
--]]

if SERVER then
    local drone_entities = {
        ["sw_crocus"]      = true,
        ["sw_crocus_pg7"]  = true,
        ["sw_crocus_tbg7"] = true,
        ["lvs_kvn1"]        = true,
        ["lvs_kvn2"]        = true,
        ["lvs_kvn3"]        = true,
    }

    local function IsDroneEntity(ent)
        if not IsValid(ent) then return false end
        local cls = ent:GetClass()
        if drone_entities[cls] or string.find(cls, "crocus") or string.find(cls, "kvn") or ent.IsCrocusKamikaze or ent.IsDrone or ent.IsKVNDrone then
            return true
        end
        return false
    end

    local function GetDroneFromPlayer(ply)
        if not IsValid(ply) then return nil end
        if IsValid(ply.CrocusDroneEnt) then return ply.CrocusDroneEnt end

        if ply:InVehicle() then
            local veh = ply:GetVehicle()
            if IsValid(veh) then
                local parent = veh:GetParent()
                if IsValid(parent) and IsDroneEntity(parent) then
                    return parent
                end
                if IsDroneEntity(veh) then
                    return veh
                end
            end
        end

        return nil
    end

    -- 1. Track operator ground station position on entering drone
    hook.Add("PlayerEnteredVehicle", "Async_Drone_ZCity_SaveGroundPos", function(ply, veh)
        if not IsValid(ply) or not IsValid(veh) then return end
        local parent = veh:GetParent()
        local drone = IsValid(parent) and parent or veh
        if IsValid(drone) and IsDroneEntity(drone) then
            ply.CrocusGroundPos = ply:GetPos()
            ply.CrocusDroneEnt = drone
        end
    end)

    -- 2. Selective Damage Protection (Ground-position based radius check)
    hook.Add("EntityTakeDamage", "Async_Drone_ZCity_ProtectRemoteOperator", function(target, dmginfo)
        if not IsValid(target) or not target:IsPlayer() then return end

        local drone = GetDroneFromPlayer(target)
        if not IsValid(drone) then return end

        local attacker  = dmginfo:GetAttacker()
        local inflictor = dmginfo:GetInflictor()

        local isDroneDamage = (IsValid(attacker) and IsDroneEntity(attacker)) or
                              (IsValid(inflictor) and IsDroneEntity(inflictor))

        if isDroneDamage or dmginfo:IsDamageType(DMG_BLAST) or dmginfo:IsDamageType(DMG_BURN) then
            local realBodyPos = target.CrocusGroundPos or target:GetPos()
            local explosionPos = dmginfo:GetReportedPosition()
            if not explosionPos or explosionPos == vector_origin then
                explosionPos = drone:GetPos()
            end

            local blastRadius = 450
            local distanceToRealBody = realBodyPos:Distance(explosionPos)

            -- If operator is physically outside the explosion blast radius, cancel remote splash damage
            if distanceToRealBody > blastRadius then
                dmginfo:SetDamage(0)
                dmginfo:ScaleDamage(0)
                return true
            end
        end
    end)

    -- 3. Eject operator safely to ground station position upon drone removal
    hook.Add("EntityRemoved", "Async_Drone_ZCity_SafeEjectOnRemove", function(ent)
        if not IsValid(ent) or not IsDroneEntity(ent) then return end

        local driver = nil
        if ent.GetDriver then driver = ent:GetDriver() end
        if not IsValid(driver) and ent.GetPassenger then driver = ent:GetPassenger(0) end

        if IsValid(driver) and driver:IsPlayer() then
            local groundPos = driver.CrocusGroundPos or driver:GetPos()
            if driver:InVehicle() then
                driver:ExitVehicle()
            end
            driver:SetPos(groundPos)
            driver:SetVelocity(Vector(0, 0, 0))
            driver.CrocusDroneEnt = nil
            driver.CrocusGroundPos = nil
        end
    end)
end

if CLIENT then
    -- Retain 100% original FPV camera & OSD without Homigrad camera interference
    hook.Add("CalcView", "Async_Drone_ZCity_OverrideCalcView", function(ply, pos, angles, fov)
        if IsValid(ply) and ply:InVehicle() then
            local veh = ply:GetVehicle()
            if IsValid(veh) then
                local parent = veh:GetParent()
                local drone = IsValid(parent) and parent or veh
                if IsValid(drone) and (drone:GetClass():find("crocus") or drone:GetClass():find("kvn") or drone.IsCrocusKamikaze or drone.IsDrone or drone.IsKVNDrone) then
                    local view = {}
                    view.origin = pos
                    view.angles = angles
                    view.fov = fov
                    view.drawviewer = false
                    return view
                end
            end
        end
    end)
end
