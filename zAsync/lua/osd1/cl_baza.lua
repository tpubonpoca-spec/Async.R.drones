if SERVER then AddCSLuaFile() return end
Crocus = Crocus or {}
Crocus.Entities = Crocus.Entities or {
    ["sw_crocus"] = true,
    ["sw_crocus_pg7"] = true,
    ["sw_crocus_tbg7"] = true,
}
Crocus.Classes = Crocus.Classes or {
    "sw_crocus",
    "sw_crocus_pg7",
    "sw_crocus_tbg7",
}
local CUSTOM_SOUND_PATH = "fpv_custom/crocus_idle.ogg"
local BASE_PITCH = 90
local PITCH_MUL = 70
local MIN_VOLUME = 0.35
local MAX_VOLUME = 1.0
local next_audio_think = 0
local next_audio_loop = 0
local cached_drones = {}
local cached_drones_count = 0
local ALTITUDE_TRACE_INTERVAL = 0.1
Crocus.BASE_PITCH = BASE_PITCH
Crocus.PITCH_MUL = PITCH_MUL
Crocus.cached_altitude = 0
Crocus.next_altitude_trace = 0
function Crocus.GetDroneBase(ply)
    local veh = ply:GetVehicle()
    if not IsValid(veh) then return nil end
    local base = veh:GetNWEntity("LVS_Entity")
    if not IsValid(base) then base = veh:GetParent() end
    if IsValid(base) and Crocus.Entities[base:GetClass()] then
        return base
    end
    return nil
end
function Crocus.UpdateAltitude(pos, base)
    local ct = CurTime()
    if ct >= Crocus.next_altitude_trace then
        Crocus.next_altitude_trace = ct + ALTITUDE_TRACE_INTERVAL
        local trace = util.TraceLine({start = pos, endpos = pos - Vector(0, 0, 50000), filter = base})
        Crocus.cached_altitude = (pos.z - trace.HitPos.z) / 39.37
    end
    return Crocus.cached_altitude
end
hook.Add("Think", "Crocus_Audio_Engine_Final", function()
    local ct = CurTime()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    if ct > next_audio_think then
        next_audio_think = ct + 1
        cached_drones_count = 0
        for _, cls in ipairs(Crocus.Classes) do
            local found = ents.FindByClass(cls)
            for i = 1, #found do
                cached_drones_count = cached_drones_count + 1
                cached_drones[cached_drones_count] = found[i]
            end
        end
        for i = cached_drones_count + 1, #cached_drones do
            cached_drones[i] = nil
        end
    end
    if ct < next_audio_loop then return end
    next_audio_loop = ct + 0.05
    local eyePos = EyePos()
    local plyVeh = ply:GetVehicle()
    for i = 1, cached_drones_count do
        local ent = cached_drones[i]
        if not IsValid(ent) then continue end
        if ent:IsDormant() then
            if ent.MyCustomLoop and ent.MyCustomLoop:IsPlaying() then
                ent.MyCustomLoop:Stop()
            end
            continue
        end
        if ent.EngineSound and ent.EngineSound:IsPlaying() then
            ent.EngineSound:ChangeVolume(0, 0.1)
        end
        if ent.DistantSound and ent.DistantSound:IsPlaying() then
            ent.DistantSound:ChangeVolume(0, 0.1)
        end
        local is_operator = false
        if IsValid(plyVeh) then
            local base = plyVeh:GetNWEntity("LVS_Entity")
            if not IsValid(base) then base = plyVeh:GetParent() end
            if IsValid(base) and base == ent then is_operator = true end
        end
        local entPos = ent:GetPos()
        local distSqr = entPos:DistToSqr(eyePos)
        if is_operator then
            if not ent.MyCustomLoop then
                ent.MyCustomLoop = CreateSound(ent, CUSTOM_SOUND_PATH)
                ent.MyCustomLoop:SetSoundLevel(90)
            end
            if ent:GetEngineActive() then
                if not ent.MyCustomLoop:IsPlaying() then
                    ent.MyCustomLoop:Play()
                end
                if not ent.NextAudioUpdate then ent.NextAudioUpdate = 0 end
                if ct > ent.NextAudioUpdate then
                    ent.NextAudioUpdate = ct + 0.25
                    local throttle = ent.GetThrottle and ent:GetThrottle() or 0
                    local vel = ent:GetVelocity()
                    local z_factor = vel.z / 500
                    local xy_sqr = (vel.x * vel.x) + (vel.y * vel.y)
                    local xy_factor = (xy_sqr > 100) and (math.sqrt(xy_sqr) / 1500) or 0
                    local active_load = math.Clamp((throttle * 0.5) + z_factor + (xy_factor * 0.5), 0.0, 1.5)
                    local target_pitch = math.Clamp(BASE_PITCH + (active_load * PITCH_MUL), 40, 255)
                    local target_volume = math.Clamp(MIN_VOLUME + (active_load * (MAX_VOLUME - MIN_VOLUME)), 0.2, 1)
                    if math.abs((ent.LastPitch or 0) - target_pitch) > 5.0 then
                        ent.MyCustomLoop:ChangePitch(target_pitch, 0.2)
                        ent.LastPitch = target_pitch
                    end
                    if math.abs((ent.LastVol or 0) - target_volume) > 0.1 then
                        ent.MyCustomLoop:ChangeVolume(target_volume, 0.2)
                        ent.LastVol = target_volume
                    end
                end
            else
                if ent.MyCustomLoop:IsPlaying() then
                    ent.MyCustomLoop:Stop()
                end
            end
        else
            local HEAR_DIST_SQR = 3000 * 3000
            if not ent:GetEngineActive() then
                if ent.MyCustomLoop then
                    ent.MyCustomLoop:Stop()
                    ent.MyCustomLoop = nil
                end
                continue
            end
            if not ent.MyCustomLoop then
                ent.MyCustomLoop = CreateSound(ent, CUSTOM_SOUND_PATH)
                ent.MyCustomLoop:SetSoundLevel(75)
                ent.MyCustomLoop:Play()
                ent.LastObsPitch = BASE_PITCH
                ent.LastObsVol   = 0
            end
            if not ent.MyCustomLoop:IsPlaying() then
                ent.MyCustomLoop:Play()
            end
            if not ent.NextObserverUpdate then ent.NextObserverUpdate = 0 end
            if ct > ent.NextObserverUpdate then
                ent.NextObserverUpdate = ct + 0.5
                if distSqr > HEAR_DIST_SQR then
                    if (ent.LastObsVol or 0) > 0.01 then
                        ent.MyCustomLoop:ChangeVolume(0, 0.5)
                        ent.LastObsVol = 0
                    end
                else
                    local dist       = math.sqrt(distSqr)
                    local vol        = math.Clamp(1 - (dist / 3000), 0.02, 0.85)
                    local throttle   = ent.GetThrottle and ent:GetThrottle() or 0
                    local vel        = ent:GetVelocity()
                    local z_factor   = vel.z / 500
                    local xy_sqr2    = vel.x * vel.x + vel.y * vel.y
                    local xy_factor  = (xy_sqr2 > 100) and (math.sqrt(xy_sqr2) / 1500) or 0
                    local load       = math.Clamp((throttle * 0.5) + z_factor + (xy_factor * 0.5), 0.0, 1.5)
                    local target_pitch = math.Clamp(BASE_PITCH + load * PITCH_MUL, 40, 255)
                    if math.abs((ent.LastObsVol or 0) - vol) > 0.02 then
                        ent.MyCustomLoop:ChangeVolume(vol, 0.4)
                        ent.LastObsVol = vol
                    end
                    if math.abs((ent.LastObsPitch or 0) - target_pitch) > 5 then
                        ent.MyCustomLoop:ChangePitch(target_pitch, 0.3)
                        ent.LastObsPitch = target_pitch
                    end
                end
            end
        end
    end
end)
hook.Add("EntityRemoved", "Crocus_Cleanup_Audio", function(ent)
    if ent.MyCustomLoop then
        ent.MyCustomLoop:Stop()
        ent.MyCustomLoop = nil
    end
end)