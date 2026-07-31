if SERVER then return end

local alt_trace_data = {}

function Crocus.RenderOSD2(base, cx, cy, sw, sh)
    local ply = LocalPlayer()
    if not IsValid(base) or base:IsDormant() then return end

    local clr_w       = Crocus2.clr_w
    local M_NOISE     = Crocus2.M_NOISE
    local M_CH_1      = Crocus2.M_CH_1
    local M_AIR       = Crocus2.M_AIR
    local M_GND       = Crocus2.M_GND
    local M_KMH       = Crocus2.M_KMH
    local M_MM        = Crocus2.M_MM
    local M_VERX      = Crocus2.M_VERX
    local M_VNIZ      = Crocus2.M_VNIZ
    local M_WIFI      = Crocus2.M_WIFI
    local M_STRELKA   = Crocus2.M_STRELKA
    local M_VR        = Crocus2.M_VR
    local M_SD_1      = Crocus2.M_SD_1
    local M_SD_2      = Crocus2.M_SD_2
    local M_BAT_LOW   = Crocus2.M_BAT_LOW
    local M_P0        = Crocus2.M_P0
    local M_P1        = Crocus2.M_P1
    local M_P2        = Crocus2.M_P2
    local M_P3        = Crocus2.M_P3
    local M_P4        = Crocus2.M_P4

    local engine_active = base:GetEngineActive()
    local pos = base:GetPos()

    if engine_active and not base.TakeOffPos then
        base.TakeOffPos = pos
    elseif not engine_active then
        base.TakeOffPos = nil
    end

    surface.SetDrawColor(255, 255, 255, 255)
    surface.SetMaterial(M_CH_1)
    surface.DrawTexturedRect(cx - 32, cy - 32, 64, 64)

    local ground_noise_enabled = game.GetWorld():GetNWBool("Crocus_GroundNoise", true)
    local srv_interference = ground_noise_enabled and base:GetNWInt("Crocus_Interference", 0) * 2.5 or 0
    local prox_noise = ground_noise_enabled and (base.CachedProxNoise or 0) or 0
    local target_noise = math.max(prox_noise, srv_interference)

    if not base.SmoothNoise then base.SmoothNoise = 0 end
    base.SmoothNoise = Lerp(FrameTime() * 2, base.SmoothNoise, target_noise)

    if base.SmoothNoise > 1 then
        local ns = 25
        local sx, sy = (CurTime() * ns) % 1, (CurTime() * ns * 1.2) % 1
        surface.SetMaterial(M_NOISE)
        surface.SetDrawColor(255, 255, 255, base.SmoothNoise)
        surface.DrawTexturedRectUV(0, 0, sw, sh, sx, sy, sx + 1, sy + 1)
    end

    local pct = base:GetNWFloat("Crocus_BatteryPct", 1)
    local mah = base:GetNWFloat("Crocus_mAh", 0)

    local b_vel = base:GetVelocity()
    local val_air_spd = math.Round(b_vel:Length() * 0.09144)
    local val_gnd_spd = math.Round(Vector(b_vel.x, b_vel.y, 0):Length() * 0.09144)
    local str_air_spd = Crocus2.GetSpacedString(val_air_spd)
    local str_gnd_spd = Crocus2.GetSpacedString(val_gnd_spd)

    local spd_box_x = 50
    local spd_box_y = sh - 175
    local spd_line_h = 38
    local num_align_x = spd_box_x + 120

    surface.SetDrawColor(255, 255, 255, 255)
    surface.SetMaterial(M_AIR)
    surface.DrawTexturedRect(spd_box_x, spd_box_y, 40, 26)
    draw.SimpleText(str_air_spd, "Crocus2_Num", num_align_x, spd_box_y + 13, clr_w, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    surface.SetMaterial(M_KMH)
    surface.DrawTexturedRect(num_align_x + 5, spd_box_y - 2, 30, 30)

    surface.SetDrawColor(255, 255, 255, 255)
    surface.SetMaterial(M_GND)
    surface.DrawTexturedRect(spd_box_x, spd_box_y + spd_line_h, 40, 26)
    draw.SimpleText(str_gnd_spd, "Crocus2_Num", num_align_x, spd_box_y + spd_line_h + 13, clr_w, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    surface.SetMaterial(M_KMH)
    surface.DrawTexturedRect(num_align_x + 5, spd_box_y + spd_line_h - 2, 30, 30)

    local right_box_x = sw - 120
    local right_box_y = cy - 45
    local r_line_h = 45

    alt_trace_data.start = pos
    alt_trace_data.endpos = pos - Vector(0, 0, 50000)
    alt_trace_data.filter = base
    local trace = util.TraceLine(alt_trace_data)
    local alt = math.max(0, math.Round((pos.z - trace.HitPos.z) / 39.37))

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

    local str_alt = Crocus2.GetSpacedString(alt)
    local str_vz  = Crocus2.GetSpacedString(abs_vz)
    local str_thr = Crocus2.GetSpacedString(thr_pct) .. " %"

    draw.SimpleText(str_alt, "Crocus2_Num", right_box_x, right_box_y, clr_w, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    surface.SetDrawColor(255, 255, 255, 255)
    surface.SetMaterial(M_MM)
    surface.DrawTexturedRect(right_box_x + 10, right_box_y - 15, 30, 30)

    local row2_y = right_box_y + r_line_h
    if vz > 0.1 then
        surface.SetMaterial(M_VERX)
        surface.DrawTexturedRect(right_box_x - 110, row2_y - 15, 30, 30)
    elseif vz < -0.1 then
        surface.SetMaterial(M_VNIZ)
        surface.DrawTexturedRect(right_box_x - 110, row2_y - 15, 30, 30)
    end

    draw.SimpleText(str_vz, "Crocus2_Num", right_box_x, row2_y, clr_w, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

    local ms_x = right_box_x + 15
    draw.SimpleText("m", "Crocus2_Micro", ms_x + 6, row2_y - 8, clr_w, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    draw.SimpleText("s", "Crocus2_Micro", ms_x + 6, row2_y + 8, clr_w, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    surface.SetDrawColor(255, 255, 255, 255)
    surface.DrawLine(ms_x, row2_y, ms_x + 12, row2_y)

    local row3_y = right_box_y + r_line_h * 2
    draw.SimpleText(str_thr, "Crocus2_Num", right_box_x, row3_y, clr_w, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

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

    local wifi_x, wifi_y, wifi_size = 50, 50, 44
    local wifi_noise = math.sin(CurTime() * 1.5) * 3 + math.cos(CurTime() * 0.8) * 2
    local target_rssi = 95 + wifi_noise - (base.SmoothNoise * 0.5)

    if not base.SmoothRSSI then base.SmoothRSSI = 95 end
    base.SmoothRSSI = Lerp(FrameTime() * 2, base.SmoothRSSI, target_rssi)
    local rssi_val = math.Clamp(math.Round(base.SmoothRSSI), 0, 99)

    surface.SetDrawColor(255, 255, 255, 255)
    surface.SetMaterial(M_WIFI)
    surface.DrawTexturedRect(wifi_x, wifi_y, wifi_size, wifi_size)
    draw.SimpleText(tostring(rssi_val), "Crocus2_Num", wifi_x + wifi_size + 15, wifi_y + (wifi_size / 2), clr_w, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

    local flight_mode = ply:KeyDown(IN_SPEED) and "P O S H" or "F B W A"
    draw.SimpleText(flight_mode, "Crocus2_SD", 50, cy - 100, clr_w, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

    local status_text = engine_active and "A R M E D" or "D I S A R M E D"
    draw.SimpleText(status_text, "Crocus2_Status", cx, 40, clr_w, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

    local drone_ang = base:GetAngles()
    local heading = (-drone_ang.y + 90) % 360
    if heading < 0 then heading = heading + 360 end
    draw.SimpleText(string.format("%03d°", math.Round(heading)), "Crocus2_SD", cx, 75, clr_w, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

    local block_x = sw - 340
    local block_y = 60

    surface.SetDrawColor(255, 255, 255, 255)
    surface.SetMaterial(Crocus2.GetBatIcon(pct))
    surface.DrawTexturedRect(block_x, block_y, 30, 60)

    local num_x = block_x + 110
    local unit_x = num_x + 6
    local cur_y = block_y + 24
    local line_spacing = 26

    draw.SimpleText(string.format("%.1f", volts), "Crocus2_Num", num_x, cur_y, clr_w, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
    draw.SimpleText("Volt", "Crocus2_Unit", unit_x, cur_y - 2, clr_w, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
    cur_y = cur_y + line_spacing

    draw.SimpleText(string.format("%.2f", amps), "Crocus2_Num", num_x, cur_y, clr_w, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
    draw.SimpleText("Amp", "Crocus2_Unit", unit_x, cur_y - 2, clr_w, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
    cur_y = cur_y + line_spacing

    draw.SimpleText(string.format("%.0f", mah), "Crocus2_Num", num_x, cur_y, clr_w, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
    draw.SimpleText("mAh", "Crocus2_Unit", unit_x, cur_y - 2, clr_w, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)

    local sd_block_x = sw - 140
    local sd_block_y = 60
    local sd_icon_w, sd_icon_h = 26, 34

    surface.SetDrawColor(255, 255, 255, 255)
    surface.SetMaterial(M_SD_1)
    surface.DrawTexturedRect(sd_block_x, sd_block_y, sd_icon_w, sd_icon_h)
    draw.SimpleText("NO SD", "Crocus2_SD", sd_block_x + sd_icon_w + 10, sd_block_y + (sd_icon_h / 2), clr_w, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

    local sd_y2 = sd_block_y + 45
    surface.SetMaterial(M_SD_2)
    surface.DrawTexturedRect(sd_block_x - 1, sd_y2 - 1, sd_icon_w + 2, sd_icon_h + 2)
    draw.SimpleText("28.46", "Crocus2_SD", sd_block_x + sd_icon_w + 10, sd_y2 + (sd_icon_h / 2), clr_w, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

    local bottom_bar_y = sh - 50
    local bottom_bar_x = 50
    local icon_size = 28

    local radio_volts = 8.2 + math.sin(CurTime() * 0.5) * 0.15 + math.cos(CurTime() * 0.2) * 0.1
    local target_mbps = 18 - (base.SmoothNoise * 0.05) + math.sin(CurTime() * 2) * 0.5
    local target_ms   = 28 + (base.SmoothNoise * 0.1) + math.cos(CurTime() * 1.5) * 2

    local dist_home, raw_dist = 0, 0
    if base.TakeOffPos then
        raw_dist = pos:Distance(base.TakeOffPos)
        dist_home = math.Round(raw_dist / 39.37)
    end

    surface.SetDrawColor(255, 255, 255, 255)
    surface.SetMaterial(M_STRELKA)
    surface.DrawTexturedRect(bottom_bar_x, bottom_bar_y, icon_size, icon_size)
    draw.SimpleText(string.format("%.1fV", radio_volts), "Crocus2_SD", bottom_bar_x + icon_size + 8, bottom_bar_y + icon_size / 2, clr_w, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    bottom_bar_x = bottom_bar_x + 100

    surface.SetMaterial(M_VR)
    surface.DrawTexturedRect(bottom_bar_x, bottom_bar_y, icon_size + 4, icon_size)
    draw.SimpleText(string.format("%.1fV", volts), "Crocus2_SD", bottom_bar_x + icon_size + 12, bottom_bar_y + icon_size / 2, clr_w, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    bottom_bar_x = bottom_bar_x + 110

    draw.SimpleText(string.format("%.0fMbps", target_mbps), "Crocus2_SD", bottom_bar_x, bottom_bar_y + icon_size / 2, clr_w, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    bottom_bar_x = bottom_bar_x + 120

    draw.SimpleText(string.format("%.0fms", target_ms), "Crocus2_SD", bottom_bar_x, bottom_bar_y + icon_size / 2, clr_w, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    bottom_bar_x = bottom_bar_x + 100

    draw.SimpleText(dist_home .. "m", "Crocus2_SD", bottom_bar_x, bottom_bar_y + icon_size / 2, clr_w, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

    local sig_mat = M_P4
    if pct <= 0 or not engine_active or base:GetHP() <= 10 then
        sig_mat = M_P0
    elseif raw_dist >= 5000 then
        sig_mat = (math.sin(CurTime() * 2) > 0) and M_P2 or M_P1
    else
        sig_mat = (math.sin(CurTime() * 1.5) > 0.6) and M_P3 or M_P4
    end

    local sig_w, sig_h = 34, 24
    local sig_x, sig_y = sw - 50, sh - 50

    surface.SetDrawColor(255, 255, 255, 255)
    surface.SetMaterial(sig_mat)
    surface.DrawTexturedRect(sig_x - sig_w, sig_y + 2, sig_w, sig_h)
    draw.SimpleText("CP7", "Crocus2_SD", sig_x - sig_w - 8, sig_y + 14, clr_w, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

    if pct < 0.25 and engine_active and math.sin(CurTime() * 8) > 0.2 then
        surface.SetMaterial(M_BAT_LOW)
        surface.SetDrawColor(255, 255, 255, 255)
        local th = 32
        local tw = (M_BAT_LOW:Height() > 0) and ((M_BAT_LOW:Width() / M_BAT_LOW:Height()) * th) or 128
        surface.DrawTexturedRect(math.floor(cx - (tw / 2)), math.floor(cy + 150), tw, th)
    end
end