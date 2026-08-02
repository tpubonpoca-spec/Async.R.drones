if CLIENT then return end

AddCSLuaFile("autorun/mavic_rework_cl.lua")

util.AddNetworkString("Mavic_Beep")

local mavic_entities = {
    ["sw_mavic_2"] = true,
    ["lvs_mavic_2"] = true,
    ["sw_mavic2"] = true,
    ["lvs_mavic2"] = true,
    ["mavic2"] = true
}

local mavic_classes = {
    "sw_mavic_2",
    "lvs_mavic_2",
    "sw_mavic2",
    "lvs_mavic2",
    "mavic2"
}

local FLIGHT_LIMIT = 180

-- Вынесено из функции чтобы не создавать таблицу каждый вызов
local MAVIC_HOVER_BLOCKED = {
    ["FORWARD"] = true, ["BACK"] = true, ["MOVELEFT"] = true, ["MOVERIGHT"] = true,
    ["THROTTLE_UP"] = true, ["THROTTLE_DOWN"] = true,
    ["PITCH_FORWARD"] = true, ["PITCH_BACK"] = true,
    ["ROLL_LEFT"] = true, ["ROLL_RIGHT"] = true,
    ["YAW_LEFT"] = true, ["YAW_RIGHT"] = true
}

local player_last_ground_pos = {}
local pending_restore = {} -- [ply] = pos (применяется один раз, не повторяется)

local next_ground_track = 0
hook.Add("Think", "Mavic_TrackGroundPos", function()
    local ct = CurTime()
    -- Обновляем позиции не чаще 10 раз в секунду — нам не нужна точность до кадра
    if ct < next_ground_track then return end
    next_ground_track = ct + 0.1

    for _, ply in ipairs(player.GetAll()) do
        if not IsValid(ply) or not ply:Alive() then continue end

        if not ply:InVehicle() then
            local restore_pos = pending_restore[ply]
            if restore_pos then
                pending_restore[ply] = nil
                ply:SetPos(restore_pos)
                ply:SetVelocity(Vector(0, 0, 0))
            else
                player_last_ground_pos[ply] = ply:GetPos()
            end
        end
    end
end)

hook.Add("EntityRemoved", "Mavic_AntiTeleport_Removed", function(ent)
    if not IsValid(ent) then return end
    if not mavic_entities[ent:GetClass()] then return end

    for _, ply in ipairs(player.GetAll()) do
        if not IsValid(ply) then continue end

        local is_controlling = false

        local driver = ent:GetDriver()
        if IsValid(driver) and driver == ply then is_controlling = true end

        local controlled = ply:GetNWEntity("LVS_ControlledEnt", nil)
        if IsValid(controlled) and controlled == ent then is_controlling = true end

        local nw_ent = ply:GetNWEntity("LVS_Entity", nil)
        if IsValid(nw_ent) and nw_ent == ent then is_controlling = true end

        if ply.MavicDroneEnt == ent then is_controlling = true end

        if is_controlling then
            local saved_pos = player_last_ground_pos[ply]
            if saved_pos then
                pending_restore[ply] = saved_pos
            end
            ply.MavicDroneEnt = nil
        end
    end
end)

hook.Add("PlayerEnteredVehicle", "Mavic_SavePosOnEnter", function(ply, veh)
    if not player_last_ground_pos[ply] then
        player_last_ground_pos[ply] = ply:GetPos()
    end
end)

hook.Add("LVS:OnDriverEntered", "Mavic_SavePos_Fix", function(ent, ply)
    if IsValid(ent) and mavic_entities[ent:GetClass()] then
        ply.MavicDroneEnt = ent

        if not ply.MavicOriginal_lvsKeyDown and ply.lvsKeyDown then
            ply.MavicOriginal_lvsKeyDown = ply.lvsKeyDown
            ply.lvsKeyDown = function(p, key)
                local v = p:GetVehicle()
                if IsValid(v) then
                    local b = v:GetNWEntity("LVS_Entity")
                    if not IsValid(b) then b = v:GetParent() end
                    if IsValid(b) and mavic_entities[b:GetClass()] then
                        if key ~= "SPRINT" and ply.MavicOriginal_lvsKeyDown(p, "SPRINT") then
                            if MAVIC_HOVER_BLOCKED[key] then return false end
                        end
                    end
                end
                return ply.MavicOriginal_lvsKeyDown(p, key)
            end
        end
    end
end)

hook.Add("LVS:OnDriverExited", "Mavic_AntiTeleport_Exit", function(ent, ply)
    if IsValid(ent) and mavic_entities[ent:GetClass()] then
        ply.MavicDroneEnt = nil
    end
end)

hook.Add("PlayerSpawn", "Mavic_ClearPos_Spawn", function(ply)
    ply.MavicDroneEnt = nil
    pending_restore[ply] = nil
    player_last_ground_pos[ply] = nil
end)

hook.Add("PlayerDisconnected", "Mavic_ClearPos_DC", function(ply)
    pending_restore[ply] = nil
    player_last_ground_pos[ply] = nil
end)

local sv_next_cache = 0
local sv_cached_drones = {}

hook.Add("Think", "MavicBatteryServer_Final", function()
    local ct = CurTime()
    
    if ct > sv_next_cache then
        sv_next_cache = ct + 2.0
        sv_cached_drones = {}
        for _, cls in ipairs(mavic_classes) do
            local found = ents.FindByClass(cls)
            if #found > 0 then table.Add(sv_cached_drones, found) end
        end
    end

    for _, ent in ipairs(sv_cached_drones) do
        if not IsValid(ent) then continue end

        if ent.SetTracking then
            ent:SetTracking(false)
        end

        if ent:GetNWBool("Drop", false) then
            if not ent.DropClearTimer then
                local pilot = ent:GetDriver()
                if IsValid(pilot) then
                    net.Start("Mavic_Beep")
                    net.Send(pilot)
                end
                ent.DropClearTimer = ct + 1.2
            elseif ct > ent.DropClearTimer then
                ent:SetNWBool("Drop", false)
                ent.DropClearTimer = nil
            end
        else
            ent.DropClearTimer = nil
        end

        if ent:GetNWInt("Loadout") ~= 2 then
            if ent.SetLoadout then ent:SetLoadout(2) end
            ent:SetNWInt("Loadout", 2)
            ent.OldLoadout = 2
            if ent.RemoveWeapon then ent:RemoveWeapon(1) end
            if ent.AddLoadouts then ent:AddLoadouts(1) end
            if ent.InitWeapons then ent:InitWeapons() end
        end

        if ent.WEAPONS and ent.WEAPONS[1] then
            local cleaned = false
            local new_weps = {}
            for _, w in ipairs(ent.WEAPONS[1]) do
                if w.Ammo == -1 then
                    cleaned = true
                else
                    table.insert(new_weps, w)
                end
            end
            if cleaned then
                ent.WEAPONS[1] = new_weps
                if ent.SetActiveWeapon then
                    ent:SetActiveWeapon(1)
                end
            end
        end

        if not ent.MavicInit then
            ent:SetNWFloat("Mavic_BatteryPct", 1)
            ent:SetNWFloat("Mavic_mAh", 0)
            ent:SetNWBool("Mavic_DeadBattery", false)
            ent:SetNWInt("Mavic_Interference", 0)
            ent.InternalBattery = 1.0
            ent.MavicInit = true
            ent.MavicLastThink = ct
            ent.SpawnTime = ct
            ent.NextInterfCheck = ct + (ent:EntIndex() % 10) * 0.1
            ent.LastSentInterference = -1
            ent.NextBatSync = 0
        end

        if not ent.MavicPhysHooked then
            ent.MavicPhysHooked = true
            
            local old_phys = ent.PhysicsSimulate
            ent.PhysicsSimulate = function(self, phys, dt)
                local r1, r2, r3
                if old_phys then
                    r1, r2, r3 = old_phys(self, phys, dt)
                end
                
                local ply = self:GetDriver()
                local is_hover = false
                
                if IsValid(ply) and self:GetEngineActive() then
                    if ply.MavicOriginal_lvsKeyDown then
                        is_hover = ply.MavicOriginal_lvsKeyDown(ply, "SPRINT")
                    elseif ply.lvsKeyDown then
                        is_hover = ply:lvsKeyDown("SPRINT")
                    else
                        is_hover = ply:KeyDown(IN_SPEED)
                    end
                end
                
                if is_hover then
                    if not self.MavicHoverYaw then
                        self.MavicHoverYaw = self:GetAngles().y
                    end
                    self:SetNWBool("Mavic_Hovering", true)
                    
                    local fwd = (ply:KeyDown(IN_FORWARD) and 1 or 0) - (ply:KeyDown(IN_BACK) and 1 or 0)
                    local rgt = (ply:KeyDown(IN_MOVERIGHT) and 1 or 0) - (ply:KeyDown(IN_MOVELEFT) and 1 or 0)
                    
                    local yaw = self.MavicHoverYaw
                    local dir = Angle(0, yaw, 0):Forward() * fwd + Angle(0, yaw, 0):Right() * rgt
                    if dir:LengthSqr() > 0 then dir:Normalize() end
                    
                    local target_spd = 550
                    local wish_vel = dir * target_spd
                    local cur_vel = phys:GetVelocity()
                    
                    local new_x = math.Approach(cur_vel.x, wish_vel.x, 3000 * dt)
                    local new_y = math.Approach(cur_vel.y, wish_vel.y, 3000 * dt)
                    
                    phys:SetVelocity(Vector(new_x, new_y, cur_vel.z))
                    
                    local ang = phys:GetAngles()
                    ang.p = math.ApproachAngle(ang.p, fwd * 20, 150 * dt)
                    ang.r = math.ApproachAngle(ang.r, rgt * 20, 150 * dt)
                    ang.y = yaw
                    phys:SetAngles(ang)
                    
                    phys:Wake()
                else
                    self.MavicHoverYaw = nil
                    self:SetNWBool("Mavic_Hovering", false)
                end
                
                return r1, r2, r3
            end
        end

        local dt = ct - ent.MavicLastThink
        if dt < 0.1 then continue end
        ent.MavicLastThink = ct

        -- Интерференция считается только когда есть пилот — иначе лишняя нагрузка
        local has_driver = IsValid(ent:GetDriver())
        if ct > (ent.SpawnTime or 0) + 5 and has_driver then
            if ct > ent.NextInterfCheck then
                ent.NextInterfCheck = ct + 1.0  -- увеличено с 0.5 до 1.0 сек
                local pos = ent:GetPos()
                local interference = 0

                local tr = util.TraceLine({
                    start = pos,
                    endpos = pos - Vector(0, 0, 200),
                    filter = ent,
                    mask = MASK_SOLID_BRUSHONLY
                })

                if tr.HitWorld then
                    local dist_factor = 1 - tr.Fraction
                    interference = interference + (dist_factor * 25)
                end

                if tr.Hit or interference > 0 then
                    local nearby = ents.FindInSphere(pos, 300)
                    for _, target in ipairs(nearby) do
                        if target == ent then continue end
                        if target:GetParent() == ent or ent:GetParent() == target then continue end
                        if target:IsPlayer() then
                            local v = target:GetVehicle()
                            if IsValid(v) and (v == ent or v:GetNWEntity("LVS_Entity") == ent) then continue end
                        end
                        local cl = target:GetClass():lower()
                        local is_v = target:IsVehicle() or cl:find("wac") or cl:find("lfs") or cl:find("simfphys") or cl:find("gred") or cl:find("prop_vehicle")
                        if target:IsPlayer() or target:IsNPC() or is_v then
                            if target:GetPos():DistToSqr(pos) <= 90000 then
                                interference = interference + 25
                            end
                        end
                    end
                end

                local final_interf = math.Clamp(interference, 0, 100)
                if ent.LastSentInterference ~= final_interf then
                    ent:SetNWInt("Mavic_Interference", final_interf)
                    ent.LastSentInterference = final_interf
                end
            end
        elseif not has_driver then
            if ent.LastSentInterference ~= 0 then
                ent:SetNWInt("Mavic_Interference", 0)
                ent.LastSentInterference = 0
            end
        end

        if not ent:GetEngineActive() or ent:GetNWBool("Mavic_DeadBattery") then
            if ent:GetNWBool("Mavic_DeadBattery") then ent:SetEngineActive(false) end
            continue
        end

        if not ent.InternalBattery then ent.InternalBattery = ent:GetNWFloat("Mavic_BatteryPct", 1) end
        ent.InternalBattery = math.Clamp(ent.InternalBattery - (dt / FLIGHT_LIMIT), 0, 1)

        if ct > ent.NextBatSync then
            ent.NextBatSync = ct + 1.0
            ent:SetNWFloat("Mavic_BatteryPct", ent.InternalBattery)
        end

        local throttle = (ent.GetThrottle and ent:GetThrottle()) or 0
        local c_mah = ent:GetNWFloat("Mavic_mAh", 0)
        ent:SetNWFloat("Mavic_mAh", c_mah + (throttle * 30 + 15) * dt)

        if ent.InternalBattery <= 0 then
            ent:SetNWBool("Mavic_DeadBattery", true)
            ent:SetEngineActive(false)
        end
    end
end)