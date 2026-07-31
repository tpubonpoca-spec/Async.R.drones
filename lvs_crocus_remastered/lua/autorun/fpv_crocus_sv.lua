if CLIENT then return end

util.AddNetworkString("Crocus_Net_Explode")
util.AddNetworkString("Crocus_GroundNoise_Sync")

-- host-only ground noise toggle, synced to all clients via NW on game entity
concommand.Add("crocus_groundnoise_toggle", function(ply)
    if IsValid(ply) and not ply:IsListenServerHost() then return end
    local current = game.GetWorld():GetNWBool("Crocus_GroundNoise", true)
    game.GetWorld():SetNWBool("Crocus_GroundNoise", not current)
end)

AddCSLuaFile("autorun/fpv_crocus_cl.lua")
AddCSLuaFile("autorun/client/cl_crocus_vhs_engine.lua")
AddCSLuaFile("osd1/cl_utils.lua")
AddCSLuaFile("osd1/cl_baza.lua")
AddCSLuaFile("osd1/cl_signal.lua")
AddCSLuaFile("osd1/cl_effects.lua")
AddCSLuaFile("osd1/cl_osd.lua")
AddCSLuaFile("osd2/cl_utils2.lua")
AddCSLuaFile("osd2/cl_osd2.lua")
AddCSLuaFile("osd3/cl_utils3.lua")
AddCSLuaFile("osd3/cl_osd3.lua")

resource.AddFile("sound/fpv_custom/crocus_idle.ogg")
resource.AddFile("sound/sw/misc/switch_on.mp3")
resource.AddFile("sound/sw/misc/nv_on.wav")
resource.AddFile("sound/sw/misc/switch_off.mp3")
resource.AddFile("sound/sw/misc/nv_off.wav")

local crocus_entities = {
    ["sw_crocus"]      = true,
    ["sw_crocus_pg7"]  = true,
    ["sw_crocus_tbg7"] = true,
}
local crocus_classes = {"sw_crocus", "sw_crocus_pg7", "sw_crocus_tbg7"}

local FLIGHT_LIMIT = 180

local crocus_player_last_ground_pos = {}
local crocus_pending_restore        = {}
local cached_players                = {}
local next_player_cache             = 0
local next_ground_track             = 0

hook.Add("Think", "Crocus_TrackGroundPos", function()
    local ct = CurTime()
    if ct < next_ground_track then return end
    next_ground_track = ct + 0.2

    if ct > next_player_cache then
        next_player_cache = ct + 5
        cached_players    = player.GetAll()
    end

    for i = 1, #cached_players do
        local ply = cached_players[i]
        if not IsValid(ply) or not ply:Alive() then continue end
        if not ply:InVehicle() then
            local restore_pos = crocus_pending_restore[ply]
            if restore_pos then
                crocus_pending_restore[ply] = nil
                ply:SetPos(restore_pos)
                ply:SetVelocity(Vector(0, 0, 0))
            else
                crocus_player_last_ground_pos[ply] = ply:GetPos()
            end
        end
    end
end)

hook.Add("EntityRemoved", "Crocus_AntiTeleport_Removed", function(ent)
    if not IsValid(ent) or not crocus_entities[ent:GetClass()] then return end
    for i = 1, #cached_players do
        local ply = cached_players[i]
        if not IsValid(ply) then continue end
        local is_controlling = false
        local driver = ent:GetDriver()
        if IsValid(driver) and driver == ply then is_controlling = true end
        if not is_controlling then
            local controlled = ply:GetNWEntity("LVS_ControlledEnt", nil)
            if IsValid(controlled) and controlled == ent then is_controlling = true end
        end
        if not is_controlling then
            local nw_ent = ply:GetNWEntity("LVS_Entity", nil)
            if IsValid(nw_ent) and nw_ent == ent then is_controlling = true end
        end
        if not is_controlling and ply.CrocusDroneEnt == ent then is_controlling = true end
        if is_controlling then
            local saved_pos = crocus_player_last_ground_pos[ply]
            if saved_pos then crocus_pending_restore[ply] = saved_pos end
            ply.CrocusDroneEnt = nil
        end
    end
end)

hook.Add("PlayerEnteredVehicle", "Crocus_SavePosOnEnter", function(ply, veh)
    if not crocus_player_last_ground_pos[ply] then
        crocus_player_last_ground_pos[ply] = ply:GetPos()
    end
end)

hook.Add("LVS:OnDriverEntered", "Crocus_SavePos_Fix", function(ent, ply)
    if IsValid(ent) and crocus_entities[ent:GetClass()] then
        ply.CrocusDroneEnt = ent
    end
end)

hook.Add("LVS:OnDriverExited", "Crocus_AntiTeleport_Exit", function(ent, ply)
    if IsValid(ent) and crocus_entities[ent:GetClass()] then
        ply.CrocusDroneEnt = nil
    end
end)

hook.Add("PlayerSpawn", "Crocus_ClearPos_Spawn", function(ply)
    ply.CrocusDroneEnt                    = nil
    crocus_pending_restore[ply]           = nil
    crocus_player_last_ground_pos[ply]    = nil
end)

hook.Add("PlayerDisconnected", "Crocus_ClearPos_DC", function(ply)
    crocus_pending_restore[ply]        = nil
    crocus_player_last_ground_pos[ply] = nil
end)

hook.Add("EntityTakeDamage", "Crocus_IncreaseBulletDamage", function(target, dmginfo)
    if IsValid(target) and crocus_entities[target:GetClass()] then
        if dmginfo:IsDamageType(DMG_BULLET) or dmginfo:IsDamageType(DMG_BUCKSHOT) then
            dmginfo:ScaleDamage(40)
        end
    end
end)

hook.Add("EntityTakeDamage", "Crocus_ProtectRemoteOperatorFromExplosion", function(target, dmginfo)
    if not IsValid(target) or not target:IsPlayer() then return end
    
    local isControllingDrone = IsValid(target.CrocusDroneEnt) or target:InVehicle()
    if not isControllingDrone then return end

    local groundPos = target.CrocusGroundPos or crocus_player_last_ground_pos[target]
    if not groundPos then return end

    local explosionPos = dmginfo:GetReportedPosition()
    if not explosionPos or explosionPos == vector_origin then
        explosionPos = dmginfo:GetDamagePosition()
    end
    if not explosionPos or explosionPos == vector_origin then
        if IsValid(target.CrocusDroneEnt) then
            explosionPos = target.CrocusDroneEnt:GetPos()
        else
            explosionPos = target:GetPos()
        end
    end

    if groundPos:Distance(explosionPos) > 200 then
        dmginfo:SetDamage(0)
        dmginfo:ScaleDamage(0)
        return true
    end
end)

hook.Add("KeyPress", "Crocus_Manual_Detonation_Key", function(ply, key)
    if key ~= IN_ATTACK and key ~= IN_ATTACK2 then return end
    local veh = ply:GetVehicle()
    if not IsValid(veh) then return end
    local ent = veh:GetNWEntity("LVS_Entity")
    if not IsValid(ent) then ent = veh:GetParent() end
    if not IsValid(ent) or not crocus_entities[ent:GetClass()] then return end
    if key == IN_ATTACK then
        local cl = ent:GetClass()
        if cl == "sw_crocus_pg7" or cl == "sw_crocus_tbg7" then
            if ent.Explode then ent:Explode() else ent:Remove() end
        end
    elseif key == IN_ATTACK2 then
        local current = ent:GetNWBool("Crocus_FLIR", false)
        ent:SetNWBool("Crocus_FLIR", not current)
        if not current then
            ent:EmitSound("sw/misc/switch_on.mp3")
            ent:EmitSound("sw/misc/nv_on.wav")
        else
            ent:EmitSound("sw/misc/switch_off.mp3")
            ent:EmitSound("sw/misc/nv_off.wav")
        end
    end
end)

local sv_next_cache         = 0
local sv_cached_drones      = {}
local sv_cached_drones_count = 0
local sv_next_loop          = 0

local INTERF_DIST_SQR = 90000
local GROUND_VEC      = Vector(0, 0, -200)
local interf_trace    = {mask = MASK_SOLID_BRUSHONLY}

hook.Add("Think", "CrocusBatteryServer_Final", function()
    local ct = CurTime()

    if ct > sv_next_cache then
        sv_next_cache        = ct + 2.0
        sv_cached_drones_count = 0
        for _, cls in ipairs(crocus_classes) do
            local found = ents.FindByClass(cls)
            for i = 1, #found do
                sv_cached_drones_count = sv_cached_drones_count + 1
                sv_cached_drones[sv_cached_drones_count] = found[i]
            end
        end
        for i = sv_cached_drones_count + 1, #sv_cached_drones do
            sv_cached_drones[i] = nil
        end
    end

    if ct < sv_next_loop then return end
    sv_next_loop = ct + 0.05

    for i = 1, sv_cached_drones_count do
        local ent = sv_cached_drones[i]
        if not IsValid(ent) then continue end

        if not ent.CrocusInit then
            ent:SetNWFloat("Crocus_BatteryPct",    1)
            ent:SetNWFloat("Crocus_mAh",           0)
            ent:SetNWBool("Crocus_DeadBattery",    false)
            ent:SetNWInt("Crocus_Interference",    0)
            ent:SetNWBool("Crocus_FLIR",           false)
            ent.InternalBattery       = 1.0
            ent.CrocusInit            = true
            ent.CrocusLastThink       = ct
            ent.SpawnTime             = ct
            ent.NextInterfCheck       = ct + (ent:EntIndex() % 10) * 0.1
            ent.LastSentInterference  = -1
            ent.NextBatSync           = 0
        end

        local dt = ct - ent.CrocusLastThink
        if dt < 0.1 then continue end
        ent.CrocusLastThink = ct

        if ct > (ent.SpawnTime or 0) + 5 and ct > ent.NextInterfCheck then
            ent.NextInterfCheck = ct + 0.5
            local pos           = ent:GetPos()
            local interference  = 0

            interf_trace.start  = pos
            interf_trace.endpos = pos + GROUND_VEC
            interf_trace.filter = ent
            local tr = util.TraceLine(interf_trace)

            if tr.HitWorld then
                interference = (1 - tr.Fraction) * 25
            end

            if interference > 0 then
                local nearby = ents.FindInSphere(pos, 300)
                for j = 1, #nearby do
                    local target = nearby[j]
                    if target == ent then continue end
                    if target:GetParent() == ent or ent:GetParent() == target then continue end
                    local is_v = false
                    if target:IsPlayer() then
                        local v = target:GetVehicle()
                        if IsValid(v) and (v == ent or v:GetNWEntity("LVS_Entity") == ent) then continue end
                    else
                        local cl = target:GetClass()
                        is_v = target:IsVehicle() or cl:find("wac",1,true) or cl:find("lfs",1,true) or cl:find("simfphys",1,true) or cl:find("gred",1,true) or cl:find("prop_vehicle",1,true)
                    end
                    if target:IsPlayer() or target:IsNPC() or is_v then
                        if target:GetPos():DistToSqr(pos) <= INTERF_DIST_SQR then
                            interference = interference + 25
                            if interference >= 100 then break end
                        end
                    end
                end
            end

            local final_interf = math.Clamp(interference, 0, 100)
            if ent.LastSentInterference ~= final_interf then
                ent:SetNWInt("Crocus_Interference", final_interf)
                ent.LastSentInterference = final_interf
            end
        elseif ct <= (ent.SpawnTime or 0) + 5 and ent.LastSentInterference ~= 0 then
            ent:SetNWInt("Crocus_Interference", 0)
            ent.LastSentInterference = 0
        end

        if not ent:GetEngineActive() or ent:GetNWBool("Crocus_DeadBattery") then
            if ent:GetNWBool("Crocus_DeadBattery") then ent:SetEngineActive(false) end
            continue
        end

        if not ent.InternalBattery then
            ent.InternalBattery = ent:GetNWFloat("Crocus_BatteryPct", 1)
        end
        ent.InternalBattery = math.Clamp(ent.InternalBattery - dt / FLIGHT_LIMIT, 0, 1)

        if ct > ent.NextBatSync then
            ent.NextBatSync = ct + 1.0
            ent:SetNWFloat("Crocus_BatteryPct", ent.InternalBattery)
        end

        local throttle = (ent.GetThrottle and ent:GetThrottle()) or 0
        ent:SetNWFloat("Crocus_mAh", ent:GetNWFloat("Crocus_mAh", 0) + (throttle * 30 + 15) * dt)

        if ent.InternalBattery <= 0 then
            ent:SetNWBool("Crocus_DeadBattery", true)
            ent:SetEngineActive(false)
        end
    end
end)