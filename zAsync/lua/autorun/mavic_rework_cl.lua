if SERVER then return end

local BAT_0 = Material("osd/0.png", "mips smooth")
local BAT_1 = Material("osd/1.png", "mips smooth")
local BAT_2 = Material("osd/2.png", "mips smooth")
local BAT_3 = Material("osd/3.png", "mips smooth")
local BAT_4 = Material("osd/4.png", "mips smooth")
local BAT_5 = Material("osd/5.png", "mips smooth")
local BAT_6 = Material("osd/6.png", "mips smooth")

local BAT_LOW_MAT = Material("osd/bat_low.png", "mips noclamp")
local SD_1_MAT = Material("osd/sddick.png", "mips smooth")
local SD_2_MAT = Material("osd/sddick1.png", "mips smooth")

local CROSSHAIR_MAT = Material("osd/crosshair.png", "mips smooth")
local WIFI_MAT = Material("osd/wifi.png", "mips smooth")
local STRELKA_MAT = Material("osd/strelka.png", "mips smooth")
local VR_MAT = Material("osd/vr.png", "mips smooth")

local AIRSPD_MAT = Material("osd/airspd.png", "mips smooth")
local GNDSPD_MAT = Material("osd/gndspd.png", "mips smooth")
local KMH_MAT = Material("osd/kmh.png", "mips smooth")

local MM_MAT = Material("osd/mm.png", "mips smooth")
local VERX_MAT = Material("osd/verx.png", "mips smooth")
local VNIZ_MAT = Material("osd/vniz.png", "mips smooth")

local P0_MAT = Material("osd/0p.png", "mips smooth")
local P1_MAT = Material("osd/1p.png", "mips smooth")
local P2_MAT = Material("osd/2p.png", "mips smooth")
local P3_MAT = Material("osd/3p.png", "mips smooth")
local P4_MAT = Material("osd/4p.png", "mips smooth")

local NOISE_MAT   = Material("effects/fpv_noise")
local DROP_MAT    = Material("models/sw/avia/mavic2/drop", "mips smooth")
local clr_white   = Color(255, 255, 255, 255)

net.Receive("Mavic_Beep", function()
    -- surface.PlaySound("fpv_custom/beep.wav")
end)

hook.Add("PlayerButtonDown", "Mavic_BeepTest", function(ply, btn)
    if btn == KEY_F1 then
        -- surface.PlaySound("fpv_custom/beep.wav")
    end
end)

local explosion_time = -1
local last_base_ent = nil
local last_hp = 100

local next_rand_noise = 0

local mavic_entities = {
    ["sw_mavic_2"] = true,
    ["lvs_mavic_2"] = true,
    ["sw_mavic2"] = true,
    ["lvs_mavic2"] = true,
    ["mavic2"] = true
}

hook.Add("PlayerBindPress", "Mavic_WheelZoom", function(ply, bind, pressed)
    if not pressed then return end
    if not string.find(bind, "invnext") and not string.find(bind, "invprev") then return end

    local veh = ply:GetVehicle()
    if not IsValid(veh) then return end
    local base = veh:GetNWEntity("LVS_Entity")
    if not IsValid(base) then base = veh:GetParent() end
    if not IsValid(base) then return end
    if not mavic_entities[base:GetClass()] then return end
    if not veh.GetThirdPersonMode then return end
    if not veh:GetThirdPersonMode() then return end

    if not base.curZoom then base.curZoom = 60 end
    if not base.curZoomTarget then base.curZoomTarget = 60 end

    if string.find(bind, "invnext") then
        base.curZoomTarget = math.Clamp(base.curZoomTarget + 5, 4, 60)
    else
        base.curZoomTarget = math.Clamp(base.curZoomTarget - 5, 4, 60)
    end
    return true
end)

hook.Add("Think", "Mavic_ZoomSmooth", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    local veh = ply:GetVehicle()
    if not IsValid(veh) then return end
    local base = veh:GetNWEntity("LVS_Entity")
    if not IsValid(base) then base = veh:GetParent() end
    if not IsValid(base) then return end
    if not mavic_entities[base:GetClass()] then return end
    if not base.curZoom then base.curZoom = 60 end
    if not base.curZoomTarget then base.curZoomTarget = 60 end
    base.curZoom = Lerp(FrameTime() * 6, base.curZoom, base.curZoomTarget)
end)

local mavic_cam_yaw   = 0
local mavic_cam_pitch = 89.9
local mavic_cam_active = false

hook.Add("StartCommand", "Mavic_CamMouseDelta", function(ply, cmd)
    local veh = ply:GetVehicle()
    if not IsValid(veh) then mavic_cam_active = false return end
    local base = veh:GetNWEntity("LVS_Entity")
    if not IsValid(base) then base = veh:GetParent() end
    if not IsValid(base) then mavic_cam_active = false return end
    if not mavic_entities[base:GetClass()] then mavic_cam_active = false return end
    if not veh.GetThirdPersonMode or not veh:GetThirdPersonMode() then mavic_cam_active = false return end

    local is_hover = base:GetNWBool("Mavic_Hovering", false)
    if input.IsKeyDown(KEY_LALT) then
        mavic_cam_active = true
        local mx = cmd:GetMouseX()
        local my = cmd:GetMouseY()
        if not mavic_cam_vel_y then mavic_cam_vel_y = 0 end
        if not mavic_cam_vel_p then mavic_cam_vel_p = 0 end
        mavic_cam_vel_y = Lerp(0.05, mavic_cam_vel_y, -mx * 0.03)
        mavic_cam_vel_p = Lerp(0.05, mavic_cam_vel_p, my * 0.03)
        mavic_cam_yaw   = mavic_cam_yaw   + mavic_cam_vel_y
        mavic_cam_pitch = math.Clamp(mavic_cam_pitch + mavic_cam_vel_p, 10, 89.9)
    else
        mavic_cam_active = false
        mavic_cam_vel_y  = 0
        mavic_cam_vel_p  = 0
        mavic_cam_yaw    = base:GetAngles().y
        mavic_cam_pitch  = 89.9
    end
end)

local next_logic_tick = 0

hook.Add("Think", "Mavic_LowPriority_Logic", function()
    local ct = CurTime()
    if ct < next_logic_tick then return end
    next_logic_tick = ct + 0.5

    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    -- Выходим сразу если не в транспорте — нет смысла что-то считать
    local veh = ply:GetVehicle()
    if not IsValid(veh) then return end
    local base = veh:GetNWEntity("LVS_Entity")
    if not IsValid(base) then base = veh:GetParent() end
    if not IsValid(base) then return end
    if not mavic_entities[base:GetClass()] then return end
    if base:IsDormant() then return end

    local engine_active = base:GetEngineActive()
    if engine_active and not base.HomePos then
        base.HomePos = base:GetPos()
    elseif not engine_active then
        base.HomePos = nil
    end

    if base.SetTracking then
        base:SetTracking(false)
    end

    local pos = base:GetPos()
    local f_time_start = ct - (base.OSDStartTime or ct)

    if f_time_start > 5 then
        local temp_noise = 0
        local g_tr = util.TraceLine({start = pos, endpos = pos - Vector(0, 0, 200), filter = base})
        local g_dist = pos:Distance(g_tr.HitPos) / 39.37

        if g_dist < 4 then
            local strength = (1 - (g_dist / 4.0))
            temp_noise = math.max(temp_noise, (strength * strength) * 120)
        end

        base.CachedProxNoise = temp_noise
    else
        base.CachedProxNoise = 0
    end

    if base.WEAPONS and base.WEAPONS[1] then
        for _, w in ipairs(base.WEAPONS[1]) do
            if w.HudPaint and not w._MavicHudFixed then
                w._MavicHudFixed = true
                w.HudPaint = function() end
            end

            if not w.CrocusCamFix then
                w.CrocusCamFix = true
                w.CalcView = function( ent, ply, w_pos, w_angles, fov, pod )
                    local base_veh = ent:GetVehicle()
                    if not IsValid(base_veh) then return {} end
                    local ID = base_veh:LookupAttachment( "view" )
                    local Attachment = base_veh:GetAttachment( ID )
                    local view = {}
                    if not pod:GetThirdPersonMode() then
                        view.origin = base_veh:LocalToWorld(Vector(1,0,1))
                        view.angles = base_veh:GetAngles()
                        view.fov = 60
                        view.drawviewer = false
                    else
                        if not base_veh.curZoom or base_veh.curZoom == 0 then
                            base_veh.curZoom = 60
                        end

                        if not mavic_cam_active then
                            mavic_cam_yaw   = base_veh:GetAngles().y
                            mavic_cam_pitch = 89.9
                        end

                        view.origin = Attachment and Attachment.Pos or base_veh:LocalToWorld(Vector(0,0,-5))
                        view.angles = Angle(mavic_cam_pitch, mavic_cam_yaw, 0)
                        view.fov = base_veh.curZoom
                        view.drawviewer = false
                    end
                    return view
                end
            end
        end
    end
end)

surface.CreateFont("Mavic_OSD_Number", {
    font = "SF Pro Rounded",
    size = 31,
    weight = 500,
    antialias = true,
    extended = true
})

surface.CreateFont("Mavic_OSD_Unit", {
    font = "SF Pro Rounded",
    size = 21,
    weight = 500,
    antialias = true,
    extended = true
})

surface.CreateFont("Mavic_OSD_SD", {
    font = "SF Pro Rounded",
    size = 28,
    weight = 500,
    antialias = true,
    extended = true
})

surface.CreateFont("Mavic_OSD_Status", {
    font = "SF Pro Rounded",
    size = 32,
    weight = 500,
    antialias = true,
    extended = true
})

surface.CreateFont("Mavic_OSD_Micro", {
    font = "SF Pro Rounded",
    size = 14,
    weight = 500,
    antialias = true,
    extended = true
})

local function GetBatteryIcon(pct)
    if pct <= 0.10 then return BAT_1 end
    if pct <= 0.30 then return BAT_2 end
    if pct <= 0.50 then return BAT_3 end
    if pct <= 0.70 then return BAT_4 end
    if pct <= 0.90 then return BAT_5 end
    return BAT_6
end

hook.Add("HUDShouldDraw", "MavicHideDefaultLVS", function(name)
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    local veh = ply:GetVehicle()
    if not IsValid(veh) then return end
    local base = veh:GetNWEntity("LVS_Entity")
    if not IsValid(base) then base = veh:GetParent() end
    if IsValid(base) and mavic_entities[base:GetClass()] then
        local hidden = {
            ["LVS_HUD"] = true,
            ["LVS_PROPERTIES"] = true,
            ["CHudAmmo"] = true,
            ["CHudSecondaryAmmo"] = true,
            ["CHudWeaponSelection"] = true,
        }
        if hidden[name] then return false end
    end
end)

hook.Add("HUDPaint", "MavicFPV_OSD_Final", function()
    local ply = LocalPlayer()
    local sw, sh = ScrW(), ScrH()
    local cx, cy = sw / 2, sh / 2
    local veh = ply:GetVehicle()
    local base = nil
    
    if IsValid(veh) then
        base = veh:GetNWEntity("LVS_Entity")
        if not IsValid(base) then base = veh:GetParent() end
    end

    local is_valid_drone = IsValid(base) and mavic_entities[base:GetClass()]
    
    if is_valid_drone then
        last_base_ent = base
        last_hp = base:GetHP()
        explosion_time = -1
    else
        if last_base_ent ~= nil and explosion_time == -1 then
            local skip_noise = input.IsKeyDown(KEY_E) or input.IsKeyDown(KEY_Z)
            if not skip_noise or last_hp <= 10 then
                explosion_time = CurTime()
            else
                last_base_ent = nil
            end
        end
        next_rand_noise = 0
    end

    if explosion_time ~= -1 then
        local time_passed = CurTime() - explosion_time
        if time_passed < 1.5 then
            local ns = 20
            local sx, sy = (CurTime() * ns) % 1, (CurTime() * ns * 1.5) % 1
            surface.SetMaterial(NOISE_MAT)
            surface.SetDrawColor(255, 255, 255, 255)
            surface.DrawTexturedRectUV(0, 0, sw, sh, sx, sy, sx + 1, sy + 1)
        elseif time_passed < 3.0 then
            surface.SetDrawColor(0, 0, 0, 255)
            surface.DrawRect(0, 0, sw, sh)
            draw.SimpleText("NO IMAGE", "Mavic_OSD_Number", cx, cy, clr_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        else
            explosion_time = -1
            last_base_ent = nil
        end
        return
    end

    if not is_valid_drone then return end
    if base:IsDormant() then return end

    if not base.HudDisabled then
        base.LVSHudPaint = function() end
        base.LVSHudPaintWeapon = function() end
        base.LVSHudPaintInfo = function() end
        base.LVSPreHudPaint = function() return false end
        base.HudDisabled = true
        base.OSDStartTime = CurTime()
    end

    local ch_size = 64
    surface.SetDrawColor(255, 255, 255, 255)
    surface.SetMaterial(CROSSHAIR_MAT)
    surface.DrawTexturedRect(cx - (ch_size / 2), cy - (ch_size / 2), ch_size, ch_size)

    local is_third_person = IsValid(veh) and veh.GetThirdPersonMode and veh:GetThirdPersonMode()

    if is_third_person then
        if not base.curZoom then base.curZoom = 60 end

        if base:GetNWBool("Drop", false) == true then
            surface.SetDrawColor(255, 255, 255, 255)
            surface.SetMaterial(DROP_MAT) 
            surface.DrawTexturedRectRotated(sw * 0.5, sh * 0.75, sw * 0.15, sh * 0.15, 0)
        end
        return 
    end

    if not base.NextHUDProxCheck then base.NextHUDProxCheck = 0 end
    if not base.CachedProxNoise then base.CachedProxNoise = 0 end
    if not base.SmoothNoise then base.SmoothNoise = 0 end

    local srv_interference = base:GetNWInt("Mavic_Interference", 0) * 2.5
    local target_noise = math.max(base.CachedProxNoise or 0, srv_interference)
    
    base.SmoothNoise = Lerp(FrameTime() * 2, base.SmoothNoise, target_noise)

    if base.SmoothNoise > 1 then
        local ns = 25
        local sx, sy = (CurTime() * ns) % 1, (CurTime() * ns * 1.2) % 1
        surface.SetMaterial(NOISE_MAT)
        surface.SetDrawColor(255, 255, 255, base.SmoothNoise)
        surface.DrawTexturedRectUV(0, 0, sw, sh, sx, sy, sx + 1, sy + 1)
    end
    
    local engine_active = base:GetEngineActive()
    local raw_throttle = engine_active and (base.GetThrottle and base:GetThrottle() or 0) or 0
    local abs_throttle = math.abs(raw_throttle)
    local pct = base:GetNWFloat("Mavic_BatteryPct", 1)
    local mah = base:GetNWFloat("Mavic_mAh", 0)
    
    local b_vel = base:GetVelocity()
    local val_air_spd = math.Round(b_vel:Length() * 0.09144)
    local val_gnd_spd = math.Round(Vector(b_vel.x, b_vel.y, 0):Length() * 0.09144)

    local str_air_spd = string.Trim(string.gsub(tostring(val_air_spd), ".", "%1 "))
    local str_gnd_spd = string.Trim(string.gsub(tostring(val_gnd_spd), ".", "%1 "))

    local spd_box_x = 50
    local spd_box_y = sh - 175
    local spd_line_h = 38
    local num_align_x = spd_box_x + 120

    surface.SetDrawColor(255, 255, 255, 255)
    surface.SetMaterial(AIRSPD_MAT)
    surface.DrawTexturedRect(spd_box_x, spd_box_y, 40, 26)
    draw.SimpleText(str_air_spd, "Mavic_OSD_Number", num_align_x, spd_box_y + 13, clr_white, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    surface.SetMaterial(KMH_MAT)
    surface.DrawTexturedRect(num_align_x + 5, spd_box_y - 2, 30, 30)

    surface.SetDrawColor(255, 255, 255, 255)
    surface.SetMaterial(GNDSPD_MAT)
    surface.DrawTexturedRect(spd_box_x, spd_box_y + spd_line_h, 40, 26)
    draw.SimpleText(str_gnd_spd, "Mavic_OSD_Number", num_align_x, spd_box_y + spd_line_h + 13, clr_white, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    surface.SetMaterial(KMH_MAT)
    surface.DrawTexturedRect(num_align_x + 5, spd_box_y + spd_line_h - 2, 30, 30)

    local right_box_x = sw - 120
    local right_box_y = cy - 45
    local r_line_h = 45

    local alt = 0
    local ct_alt = CurTime()
    if not base.NextAltTrace then base.NextAltTrace = 0 end
    if ct_alt >= base.NextAltTrace then
        base.NextAltTrace = ct_alt + 0.1
        local pos = base:GetPos()
        local tr = util.TraceLine({
            start  = pos,
            endpos = pos - Vector(0, 0, 50000),
            filter = base,
            mask   = MASK_SOLID_BRUSHONLY
        })
        base.CachedAlt = math.max(0, math.Round((pos.z - tr.HitPos.z) * 0.0254))
    end
    alt = base.CachedAlt or 0

    local vz = math.Round(b_vel.z * 0.0254, 1)
    local abs_vz = math.abs(vz)

    local target_gas = 0
    if engine_active then
        local vel_xy = Vector(b_vel.x, b_vel.y, 0):Length()
        target_gas = 45 + (b_vel.z / 300) * 45 + (vel_xy / 600) * 10
        target_gas = math.Clamp(target_gas, 0, 99)
        target_gas = target_gas + math.sin(CurTime() * 15) * 1.5
    end
    
    if not base.sm_DroneGas then base.sm_DroneGas = 0 end
    base.sm_DroneGas = Lerp(FrameTime() * 5, base.sm_DroneGas, target_gas)
    local thr_pct = math.Round(base.sm_DroneGas)

    local str_alt = string.Trim(string.gsub(tostring(alt), ".", "%1 "))
    local str_vz = string.Trim(string.gsub(string.format("%.1f", abs_vz), ".", "%1 "))
    local str_thr = string.Trim(string.gsub(tostring(thr_pct), ".", "%1 ")) .. " %"

    draw.SimpleText(str_alt, "Mavic_OSD_Number", right_box_x, right_box_y, clr_white, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    surface.SetDrawColor(255, 255, 255, 255)
    surface.SetMaterial(MM_MAT)
    surface.DrawTexturedRect(right_box_x + 10, right_box_y - 15, 30, 30)

    local row2_y = right_box_y + r_line_h
    if vz > 0.1 then
        surface.SetMaterial(VERX_MAT)
        surface.DrawTexturedRect(right_box_x - 110, row2_y - 15, 30, 30)
    elseif vz < -0.1 then
        surface.SetMaterial(VNIZ_MAT)
        surface.DrawTexturedRect(right_box_x - 110, row2_y - 15, 30, 30)
    end
    
    draw.SimpleText(str_vz, "Mavic_OSD_Number", right_box_x, row2_y, clr_white, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    
    local ms_x = right_box_x + 15
    draw.SimpleText("m", "Mavic_OSD_Micro", ms_x + 6, row2_y - 8, clr_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    draw.SimpleText("s", "Mavic_OSD_Micro", ms_x + 6, row2_y + 8, clr_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    surface.SetDrawColor(255, 255, 255, 255)
    surface.DrawLine(ms_x, row2_y, ms_x + 12, row2_y)

    local row3_y = right_box_y + r_line_h * 2
    draw.SimpleText(str_thr, "Mavic_OSD_Number", right_box_x, row3_y, clr_white, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

    local volts = 0.0
    local target_amps = 0.0
    local v_throttle = thr_pct / 100
    
    if engine_active then
        volts = math.max(12.0, (14.0 + 2.8 * pct) - (v_throttle * 2.2)) 
        
        local noise = math.sin(CurTime() * 5) * 0.15
        target_amps = math.Clamp(12.3 + (v_throttle * 2.4) + noise, 12.3, 14.85)
    end
    
    if not base.SmoothAmps then base.SmoothAmps = 0 end
    base.SmoothAmps = Lerp(FrameTime() * 3, base.SmoothAmps, target_amps)
    local amps = base.SmoothAmps

    local wifi_x = 50
    local wifi_y = 50
    local wifi_size = 44
    
    local wifi_noise = math.sin(CurTime() * 1.5) * 3 + math.cos(CurTime() * 0.8) * 2
    local target_rssi = 95 + wifi_noise - (base.SmoothNoise * 0.5)
    
    if not base.SmoothRSSI then base.SmoothRSSI = 95 end
    base.SmoothRSSI = Lerp(FrameTime() * 2, base.SmoothRSSI, target_rssi)
    local rssi_val = math.Clamp(math.Round(base.SmoothRSSI), 0, 99)
    
    surface.SetDrawColor(255, 255, 255, 255)
    surface.SetMaterial(WIFI_MAT)
    surface.DrawTexturedRect(wifi_x, wifi_y, wifi_size, wifi_size)
    draw.SimpleText(tostring(rssi_val), "Mavic_OSD_Number", wifi_x + wifi_size + 15, wifi_y + (wifi_size / 2), clr_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

    local is_poshold = ply:lvsKeyDown("HELI_HOVER")
    
    local flight_mode = is_poshold and "P O S H" or "F B W A"
    draw.SimpleText(flight_mode, "Mavic_OSD_SD", 50, cy - 100, clr_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

    local status_text = engine_active and "A R M E D" or "D I S A R M E D"
    draw.SimpleText(status_text, "Mavic_OSD_Status", cx, 40, clr_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

    local drone_ang = base:GetAngles()
    local heading = (-drone_ang.y + 90) % 360
    if heading < 0 then heading = heading + 360 end
    draw.SimpleText(string.format("%03d°", math.Round(heading)), "Mavic_OSD_SD", cx, 75, clr_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

    local block_x = sw - 340
    local block_y = 60
    local icon_w, icon_h = 30, 60
    
    surface.SetDrawColor(255, 255, 255, 255)
    surface.SetMaterial(GetBatteryIcon(pct))
    surface.DrawTexturedRect(block_x, block_y, icon_w, icon_h)

    local num_x = block_x + 110 
    local unit_x = num_x + 6    
    
    local cur_y = block_y + 24
    local line_spacing = 26
    
    draw.SimpleText(string.format("%.1f", volts), "Mavic_OSD_Number", num_x, cur_y, clr_white, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
    draw.SimpleText("Volt", "Mavic_OSD_Unit", unit_x, cur_y - 2, clr_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
    cur_y = cur_y + line_spacing
    
    draw.SimpleText(string.format("%.2f", amps), "Mavic_OSD_Number", num_x, cur_y, clr_white, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
    draw.SimpleText("Amp", "Mavic_OSD_Unit", unit_x, cur_y - 2, clr_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
    cur_y = cur_y + line_spacing
    
    draw.SimpleText(string.format("%.0f", mah), "Mavic_OSD_Number", num_x, cur_y, clr_white, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
    draw.SimpleText("mAh", "Mavic_OSD_Unit", unit_x, cur_y - 2, clr_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)

    local sd_block_x = sw - 140
    local sd_block_y = 60
    local sd_icon_w = 26
    local sd_icon_h = 34

    surface.SetDrawColor(255, 255, 255, 255)
    surface.SetMaterial(SD_1_MAT)
    surface.DrawTexturedRect(sd_block_x, sd_block_y, sd_icon_w, sd_icon_h)
    draw.SimpleText("NO SD", "Mavic_OSD_SD", sd_block_x + sd_icon_w + 10, sd_block_y + (sd_icon_h / 2), clr_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

    local sd_y2 = sd_block_y + 45
    surface.SetMaterial(SD_2_MAT)
    surface.DrawTexturedRect(sd_block_x - 1, sd_y2 - 1, sd_icon_w + 2, sd_icon_h + 2)
    draw.SimpleText("28.46", "Mavic_OSD_SD", sd_block_x + sd_icon_w + 10, sd_y2 + (sd_icon_h / 2), clr_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

    local bottom_bar_y = sh - 50
    local bottom_bar_x = 50
    local icon_size = 28
    
    local radio_volts = 8.2 + math.sin(CurTime() * 0.5) * 0.15 + math.cos(CurTime() * 0.2) * 0.1
    local target_mbps = 18 - (base.SmoothNoise * 0.05) + math.sin(CurTime() * 2) * 0.5
    local target_ms = 28 + (base.SmoothNoise * 0.1) + math.cos(CurTime() * 1.5) * 2

    local dist_home = 0
    local raw_dist = 0
    if base.HomePos then
        raw_dist = base:GetPos():Distance(base.HomePos)
        dist_home = math.Round(raw_dist * 0.0254)
    end

    surface.SetDrawColor(255, 255, 255, 255)
    surface.SetMaterial(STRELKA_MAT)
    surface.DrawTexturedRect(bottom_bar_x, bottom_bar_y, icon_size, icon_size)
    draw.SimpleText(string.format("%.1fV", radio_volts), "Mavic_OSD_SD", bottom_bar_x + icon_size + 8, bottom_bar_y + icon_size/2, clr_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    bottom_bar_x = bottom_bar_x + 100

    surface.SetMaterial(VR_MAT)
    surface.DrawTexturedRect(bottom_bar_x, bottom_bar_y, icon_size + 4, icon_size)
    draw.SimpleText(string.format("%.1fV", volts), "Mavic_OSD_SD", bottom_bar_x + icon_size + 12, bottom_bar_y + icon_size/2, clr_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    bottom_bar_x = bottom_bar_x + 110

    draw.SimpleText(string.format("%.0fMbps", target_mbps), "Mavic_OSD_SD", bottom_bar_x, bottom_bar_y + icon_size/2, clr_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    bottom_bar_x = bottom_bar_x + 120

    draw.SimpleText(string.format("%.0fms", target_ms), "Mavic_OSD_SD", bottom_bar_x, bottom_bar_y + icon_size/2, clr_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    bottom_bar_x = bottom_bar_x + 100

    draw.SimpleText(dist_home .. "m", "Mavic_OSD_SD", bottom_bar_x, bottom_bar_y + icon_size/2, clr_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

    local sig_mat = P4_MAT
    if pct <= 0 or not engine_active or base:GetHP() <= 10 then
        sig_mat = P0_MAT
    elseif raw_dist >= 5000 then
        if math.sin(CurTime() * 2) > 0 then
            sig_mat = P2_MAT
        else
            sig_mat = P1_MAT
        end
    else
        if math.sin(CurTime() * 1.5) > 0.6 then
            sig_mat = P3_MAT
        else
            sig_mat = P4_MAT
        end
    end
    
    local sig_w = 34
    local sig_h = 24
    local sig_x = sw - 50
    local sig_y = sh - 50
    
    surface.SetDrawColor(255, 255, 255, 255)
    surface.SetMaterial(sig_mat)
    surface.DrawTexturedRect(sig_x - sig_w, sig_y + 2, sig_w, sig_h)
    draw.SimpleText("CP7", "Mavic_OSD_SD", sig_x - sig_w - 8, sig_y + 14, clr_white, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

    if pct < 0.25 and engine_active and math.sin(CurTime() * 8) > 0.2 then
        surface.SetMaterial(BAT_LOW_MAT)
        surface.SetDrawColor(255, 255, 255, 255)
        local th = 32
        local tw = 128
        if BAT_LOW_MAT:Height() > 0 then
            tw = (BAT_LOW_MAT:Width() / BAT_LOW_MAT:Height()) * th
        end
        surface.DrawTexturedRect(math.floor(cx - (tw / 2)), math.floor(cy + 150), tw, th)
    end

    local drop_now = base:GetNWBool("Drop", false)
    base._MavicDropWas = drop_now

    if drop_now then
        surface.SetDrawColor(255, 255, 255, 255)
        surface.SetMaterial(DROP_MAT)
        surface.DrawTexturedRectRotated(sw * 0.5, sh * 0.75, sw * 0.15, sh * 0.15, 0)
    end
end)