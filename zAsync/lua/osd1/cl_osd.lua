if SERVER then AddCSLuaFile() return end

Crocus = Crocus or {}
Crocus.Entities = Crocus.Entities or {
    ["sw_crocus"] = true,
    ["sw_crocus_pg7"] = true,
    ["sw_crocus_tbg7"] = true,
}

local BAT_0       = Material("osd/bat_0.png",  "mips smooth")
local BAT_1       = Material("osd/bat_1.png",  "mips smooth")
local BAT_2       = Material("osd/bat_2.png",  "mips smooth")
local BAT_3       = Material("osd/bat_3.png",  "mips smooth")
local BAT_4       = Material("osd/bat_4.png",  "mips smooth")
local BAT_5       = Material("osd/bat_5.png",  "mips smooth")
local BAT_6       = Material("osd/bat_6.png",  "mips smooth")
local FLYMN_MAT   = Material("osd/flymn.png",  "mips smooth")
local BAT_LOW_MAT = Material("osd/bat_low.png","mips noclamp")

local sw_cached, sh_cached = ScrW(), ScrH()
local death_rt_1 = GetRenderTarget("CrocusDeathCamRT_1", sw_cached, sh_cached, false)
local death_rt_2 = GetRenderTarget("CrocusDeathCamRT_2", sw_cached, sh_cached, false)
local death_rt_3 = GetRenderTarget("CrocusDeathCamRT_3", sw_cached, sh_cached, false)
local death_mat  = CreateMaterial("CrocusDeathCamMat_Opaque", "UnlitGeneric", {
    ["$basetexture"] = "CrocusDeathCamRT_1",
    ["$vertexcolor"] = 1,
    ["$ignorez"]     = 1,
})

local last_rt_copy_time = 0
local last_rt_written   = 1
local last_base_ent     = nil
local last_hp           = 100

Crocus.explosion_time = -1

local bat_upper_thresholds = {0.05, 0.15, 0.30, 0.55, 0.80, 0.95}
local bat_upper_mats       = {BAT_6, BAT_5, BAT_4, BAT_3, BAT_2, BAT_1, BAT_0}
local bat_lower_thresholds = {0.15, 0.30, 0.55, 0.80, 0.95}
local bat_lower_mats       = {BAT_5, BAT_4, BAT_3, BAT_2, BAT_1, BAT_0}

local function GetUpperBat(pct)
    for i, t in ipairs(bat_upper_thresholds) do
        if pct <= t then return bat_upper_mats[i] end
    end
    return BAT_0
end

local function GetLowerBat(pct)
    for i, t in ipairs(bat_lower_thresholds) do
        if pct <= t then return bat_lower_mats[i] end
    end
    return BAT_0
end

local COMPASS_CARDINALS = {[0]="N",[45]="NE",[90]="E",[135]="SE",[180]="S",[225]="SW",[270]="W",[315]="NW",[360]="N"}

local function DrawVerticalTape(val, x_pos, side, bottom_text)
    local cy   = sh_cached / 2
    local pxd  = 6
    local range = 25
    render.SetScissorRect(x_pos - 100, cy - 150, x_pos + 100, cy + 150, true)
    local v_floor = math.floor(val - range)
    local v_ceil  = math.ceil(val + range)
    for i = v_floor, v_ceil do
        local y = cy + (val - i) * pxd
        if i >= 0 then
            if i % 10 == 0 then
                local tx  = (side == "left") and (x_pos + 12) or (x_pos - 12)
                if Crocus.DrawOutlinedLine then Crocus.DrawOutlinedLine(x_pos, y, tx, y) end
                local txt_x = (side == "left") and (x_pos - 5) or (x_pos + 5)
                draw.SimpleText(string.format("%03d", i), "Crocus_Beta_Main", txt_x, y, Crocus.clr_gray, (side == "left" and 1 or 0), 1)
            elseif i % 2 == 0 then
                local tx = (side == "left") and (x_pos + 7) or (x_pos - 7)
                if Crocus.DrawOutlinedLine then Crocus.DrawOutlinedLine(x_pos, y, tx, y) end
            end
        end
    end
    render.SetScissorRect(0, 0, 0, 0, false)
    if Crocus.DrawHollowPointer then
        Crocus.DrawHollowPointer((side == "left" and x_pos + 12 or x_pos - 12), cy, side, string.format(side == "right" and "%04d" or "%03d", math.Round(val)))
    end
    if bottom_text then
        draw.SimpleText(bottom_text, "Crocus_Beta_Main", x_pos, cy + 170, Crocus.clr_gray, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
end

local function DrawBetaCompass(heading, cx, cy)
    local strip_y = 70
    local strip_w = 420
    local pxd     = 5
    local hw      = strip_w / 2
    render.SetScissorRect(cx - hw, 0, cx + hw, strip_y + 60, true)
    surface.SetDrawColor(0, 0, 0, 255)
    surface.DrawRect(cx - hw, strip_y - 1, strip_w, 3)
    surface.SetDrawColor(180, 180, 180, 255)
    surface.DrawRect(cx - hw, strip_y, strip_w, 1)
    local s_deg = math.floor(heading - hw / pxd)
    local e_deg = math.ceil(heading + hw / pxd)
    for i = s_deg, e_deg do
        local x  = math.floor(cx + (i - heading) * pxd)
        local nd = i % 360
        if nd < 0 then nd = nd + 360 end
        local is_major  = (i % 15 == 0)
        local is_medium = (i % 5  == 0)
        local th = is_major and 12 or (is_medium and 7 or 4)
        surface.SetDrawColor(0, 0, 0, 255)
        surface.DrawRect(x - 1, strip_y - th - 1, 3, th + 2)
        surface.SetDrawColor(180, 180, 180, 255)
        surface.DrawRect(x, strip_y - th, 1, th)
        if COMPASS_CARDINALS[nd] and i % 45 == 0 then
            draw.SimpleText(COMPASS_CARDINALS[nd], "Crocus_Beta_Main", x, strip_y - 14, Crocus.clr_gray, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
        end
    end
    render.SetScissorRect(0, 0, 0, 0, false)
    draw.SimpleText(string.format("%03d", math.Round(heading)), "Crocus_Beta_Main", cx, strip_y + 5, Crocus.clr_gray, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
end

local cached_hud_type    = 1
local next_convar_check  = 0
local cached_vhs_enable  = false
local cached_death_cam   = false
local cached_death_noise = false
local cached_custom_txt  = ""

local ring = {{2,4},{4,2},{4,-2},{2,-4},{-2,-4},{-4,-2},{-4,2},{-2,4}}

hook.Add("HUDPaint", "CrocusFPV_OSD_Final", function()
    local ply = LocalPlayer()
    local ct  = CurTime()

    if ct > next_convar_check then
        next_convar_check  = ct + 0.5
        cached_hud_type    = GetConVar("crocus_hud_type"):GetInt()
        cached_vhs_enable  = GetConVar("crocus_vhs_enable"):GetBool()
        cached_death_cam   = GetConVar("crocus_death_cam"):GetBool()
        cached_death_noise = GetConVar("crocus_death_noise"):GetBool()
        cached_custom_txt  = GetConVar("crocus_name"):GetString()
        sw_cached, sh_cached = ScrW(), ScrH()
    end

    local sw, sh = sw_cached, sh_cached
    local cx, cy = sw * 0.5, sh * 0.5
    local base   = Crocus.GetDroneBase and Crocus.GetDroneBase(ply) or nil
    local is_valid_drone = IsValid(base)
    local drone_hp = is_valid_drone and base:GetHP() or 0

    if is_valid_drone and drone_hp > 0 then
        local vel_len = base:GetVelocity():LengthSqr()
        local adaptive_interval = math.Clamp(0.15 - (vel_len / 4000000) * 0.12, 0.033, 0.15)
        if ct - last_rt_copy_time >= adaptive_interval then
            last_rt_copy_time = ct
            if last_rt_written == 1 then
                render.CopyRenderTargetToTexture(death_rt_2)
                last_rt_written = 2
            elseif last_rt_written == 2 then
                render.CopyRenderTargetToTexture(death_rt_3)
                last_rt_written = 3
            else
                render.CopyRenderTargetToTexture(death_rt_1)
                last_rt_written = 1
            end
        end
        last_base_ent = base
        last_hp = drone_hp
        Crocus.explosion_time = -1
    else
        if last_base_ent ~= nil and Crocus.explosion_time == -1 then
            local skip_noise = input.IsKeyDown(KEY_E) or input.IsKeyDown(KEY_Z)
            if not skip_noise or last_hp <= 10 then
                Crocus.explosion_time = ct
                local rt = (last_rt_written == 1) and death_rt_1 or (last_rt_written == 2 and death_rt_2 or death_rt_3)
                death_mat:SetTexture("$basetexture", rt)
            else
                last_base_ent = nil
            end
        end
        Crocus.next_rand_noise = 0
    end

    if Crocus.explosion_time ~= -1 then
        local time_passed = ct - Crocus.explosion_time
        local cam_dur   = cached_death_cam   and 2.0 or 0.0
        local noise_dur = cached_death_noise and 1.5 or 0.0
        local total_dur = cam_dur + noise_dur
        if total_dur == 0 or time_passed >= total_dur then
            Crocus.explosion_time = -1
            last_base_ent = nil
            return
        end
        if time_passed < cam_dur then
            if cached_death_cam then
                surface.SetDrawColor(255, 255, 255, 255)
                surface.SetMaterial(death_mat)
                surface.DrawTexturedRect(0, 0, sw, sh)
            else
                surface.SetDrawColor(0, 0, 0, 255)
                surface.DrawRect(0, 0, sw, sh)
            end
            if cached_death_noise and Crocus.DrawDeathNoise then Crocus.DrawDeathNoise(sw, sh, 120) end
            surface.SetAlphaMultiplier(0.4)
            draw.SimpleTextOutlined("NO IMAGE", "Crocus_Beta_Death", cx, cy, Color(200, 200, 200, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, 255))
            surface.SetAlphaMultiplier(1)
        else
            if cached_death_noise and Crocus.DrawDeathNoise then
                Crocus.DrawDeathNoise(sw, sh, 255)
            else
                surface.SetDrawColor(0, 0, 0, 255)
                surface.DrawRect(0, 0, sw, sh)
            end
        end
        return
    end

    if not is_valid_drone then return end
    if base:IsDormant() then return end

    if cached_hud_type == 2 then
        if Crocus.RenderOSD2 then Crocus.RenderOSD2(base, cx, cy, sw, sh) end
        if cached_custom_txt ~= "" and Crocus.DrawBitmapText then
            Crocus.DrawBitmapText(cached_custom_txt, cx, cy + 145, 24)
        end
        return
    elseif cached_hud_type == 3 then
        if Crocus.RenderOSD3 then Crocus.RenderOSD3(base, cx, cy, sw, sh) end
        if cached_custom_txt ~= "" and Crocus.DrawBitmapText then
            Crocus.DrawBitmapText(cached_custom_txt, cx, cy + 145, 24)
        end
        return
    end

    local pos         = base:GetPos()
    local f_time_start = ct - (base.OSDStartTime or ct)
    local smooth_noise = Crocus.UpdateNoise and Crocus.UpdateNoise(base) or 0

    if Crocus.DrawFLIROverlay  then Crocus.DrawFLIROverlay(base, cx, cy, sw, sh) end
    if Crocus.DrawNoiseOverlay then Crocus.DrawNoiseOverlay(smooth_noise, sw, sh) end

    local ang = base:GetAngles()
    if not base.TakeOffPos then base.TakeOffPos = pos end

    local r_sens       = 4.0
    local gap_center   = 100
    local dash_w       = 8
    local dash_space   = 20
    local current_roll = math.Clamp(ang.r, -60, 60)
    for side = -1, 1, 2 do
        for d = 1, 5 do
            local pX = cx + (side * (gap_center + (d - 1) * (dash_w + dash_space)))
            if side == -1 then pX = pX - dash_w end
            local pY = math.Clamp(cy + (side * ((d / 5) * (current_roll * r_sens))), 150, sh - 150)
            if Crocus.DrawBox then Crocus.DrawBox(pX, pY, dash_w, 2) end
        end
    end

    local altitude  = Crocus.UpdateAltitude and Crocus.UpdateAltitude(pos, base) or 0
    local speed_kmh = base:GetVelocity():Length() * 0.09144

    DrawVerticalTape(speed_kmh, cx - 350, "left",  "KM/H")
    DrawVerticalTape(altitude,  cx + 350, "right", "M")
    DrawBetaCompass((-ang.y + 90) % 360, cx, cy)

    if Crocus.DrawBox then
        Crocus.DrawBox(cx - 1, cy - 1, 2, 2)
        for _, p in ipairs(ring) do Crocus.DrawBox(cx + p[1] - 1, cy + p[2] - 1, 2, 2) end
        for i = 1, 2 do
            local gap = 14 + (i - 1) * 10
            Crocus.DrawBox(cx + gap,         cy - 1, 5, 2)
            Crocus.DrawBox(cx - gap - 5,     cy - 1, 5, 2)
            Crocus.DrawBox(cx - 1, cy + gap,         2, 5)
            Crocus.DrawBox(cx - 1, cy - gap - 5,     2, 5)
        end
    end

    local distToHome = math.Round(pos:Distance(base.TakeOffPos) / 39.37)
    draw.SimpleText(string.format("%03dM", distToHome), "Crocus_Beta_Main", 50, 50, Crocus.clr_gray, 0)

    local acro_y    = sh - 110
    local real_fps  = math.Round(1 / FrameTime())
    local disp_fps  = math.min(real_fps, 30)
    draw.SimpleText("ACRO",          "Crocus_Beta_Main", cx - 45, acro_y,      Crocus.clr_gray, TEXT_ALIGN_CENTER)
    draw.SimpleText("FPS " .. disp_fps, "Crocus_Beta_Main", cx - 45, acro_y + 25, Crocus.clr_gray, TEXT_ALIGN_CENTER)

    local signalBars = (distToHome < 300) and 3 or (distToHome < 600 and 2 or 1)
    for i = 1, 3 do
        local h   = 16 - (i - 1) * 5
        local sx2 = cx + 8 + i * 9
        local by2 = acro_y + 24 - h
        surface.SetDrawColor(0, 0, 0, 255)
        surface.DrawRect(sx2 - 1, by2 - 1, 5, h + 2)
        local barVal = (i <= signalBars) and 180 or 30
        surface.SetDrawColor(barVal, barVal, barVal, 255)
        surface.DrawRect(sx2, by2, 3, h)
    end

    local pct   = base:GetNWFloat("Crocus_BatteryPct", 1)
    local volts = math.max(0, (13.5 + 3.0 * pct) - ((base.GetThrottle and base:GetThrottle() or 0) * 1.5))
    local bx, by = 60, sh - 280

    surface.SetDrawColor(255, 255, 255, 255)
    surface.SetMaterial(GetUpperBat(pct))
    surface.DrawTexturedRect(bx, by, 40, 70)
    draw.SimpleText(string.format("%.2fV", volts / 4), "Crocus_Beta_Main", bx + 55, by + 18, Crocus.clr_gray)

    surface.SetDrawColor(255, 255, 255, 255)
    surface.SetMaterial(GetLowerBat(pct))
    surface.DrawTexturedRect(bx, by + 90, 40, 70)
    draw.SimpleText(string.format("%.1fV", volts), "Crocus_Beta_Main", bx + 55, by + 108, Crocus.clr_gray)

    draw.SimpleText(string.format("%.0f MAH", base:GetNWFloat("Crocus_mAh", 0)), "Crocus_Beta_Main", bx, by + 175, Crocus.clr_gray)

    local tr_x = sw - 50
    draw.SimpleText(string.format("%+d P", math.Round(ang.p)), "Crocus_Beta_Main", tr_x, 50, Crocus.clr_gray, 2)
    draw.SimpleText(string.format("%+d R", math.Round(ang.r)), "Crocus_Beta_Main", tr_x, 80, Crocus.clr_gray, 2)

    local br_x = sw - 50
    local br_y = sh - 150
    draw.SimpleText(string.format("%+d M/S", math.Round(base:GetVelocity().z / 39.37)), "Crocus_Beta_Main", br_x, br_y,      Crocus.clr_gray, 2)
    draw.SimpleText(string.format("U %.1fV", volts),                                     "Crocus_Beta_Main", br_x, br_y + 35, Crocus.clr_gray, 2)
    draw.SimpleText(string.format("%d:%02d", math.floor(f_time_start / 60), math.floor(f_time_start % 60)), "Crocus_Beta_Main", br_x, br_y + 70, Crocus.clr_gray, 2)

    surface.SetMaterial(FLYMN_MAT)
    surface.SetDrawColor(180, 180, 180, 255)
    surface.DrawTexturedRect(br_x - 65, br_y + 68, 26, 26)

    if pct < 0.33 and math.sin(ct * 10) > 0 then
        surface.SetMaterial(BAT_LOW_MAT)
        surface.SetDrawColor(180, 180, 180, 255)
        local targetH = 32
        local targetW = (BAT_LOW_MAT:Width() / BAT_LOW_MAT:Height()) * targetH
        surface.DrawTexturedRect(math.floor(cx - targetW * 0.5), math.floor(cy + 85), targetW, targetH)
    end

    if base:GetNWBool("Crocus_LOS_Block", false) and math.sin(ct * 10) > 0 then
        draw.SimpleText("TERRAIN", "Crocus_Beta_Main", cx, sh - 140, Color(255, 0, 0, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    if cached_custom_txt ~= "" and Crocus.DrawBitmapText then
        Crocus.DrawBitmapText(cached_custom_txt, cx, cy + 145, 24)
    end
end)