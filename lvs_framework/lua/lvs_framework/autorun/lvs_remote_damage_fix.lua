--[[
    LVS Framework - Universal Remote Operator Explosion Damage Protection
--]]

if SERVER then
    hook.Add("EntityTakeDamage", "LVS_ProtectRemoteOperatorFromExplosion", function(target, dmginfo)
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

            -- If explosion happened at the drone location (farther than 200 units from the operator's ground position)
            if groundPos:Distance(explosionPos) > 200 then
                dmginfo:SetDamage(0)
                dmginfo:ScaleDamage(0)
                return true
            end
        end
    end)
end
