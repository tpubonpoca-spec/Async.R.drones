if SERVER then AddCSLuaFile() return end

Crocus = Crocus or {}

local CROSSHAIR_MAT  = Material("osd/2crosshair.png", "mips smooth noclamp")
local CROSSHAIR_SIZE = 64
local CROSSHAIR_HALF = 32

local alt_tr         = {}
local next_alt_trace = 0
local cached_alt     = 0

local aim_tr         = {}
local next_aim_trace = 0
local cached_aim_dist = 999

local M = 22
local L = 38

local clr_red  = Color(255, 80,  80,  255)
local clr_rx_g = Color(0,   255, 0,   255)
local clr_rx_y = Color(255, 240, 0, 255)
local clr_rx_r = Color(255, 50,  50,  255)

local cached_volts    = 0
local cached_cell_v   = 0
local cached_amps     = 0
local cached_thr      = 0
local cached_rx       = -20
local cached_tx       = 2.1
local cached_link_str = "link-ok"
local cached_link_ok  = true
local cached_fuse_str = "Э. пред.: вкл"
local cached_cheka    = "Чека: нет"
local cached_eng      = false
local next_slow_update = 0

local PITCH_SCALE = 5.0
local MAX_OFFSET  = 200
local DOT_COUNT   = 9
local DOT_R       = 3
local DOT_GAP     = 16
local TRI_SIZE    = 5
local MARGIN      = 20

local function TL(x, y, text, font, color)
    draw.SimpleText(text, font or "Crocus3_Main", x, y, color or Crocus3.clr_w, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
end

local function TR(x, y, text, font, color)
    draw.SimpleText(text, font or "Crocus3_Main", x, y, color or Crocus3.clr_w, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
end

local function GetAlt(pos, base)
    local ct = CurTime()
    if ct >= next_alt_trace then
        next_alt_trace = ct + 0.1
        alt_tr.start   = pos
        alt_tr.endpos  = pos - Vector(0, 0, 50000)
        alt_tr.filter  = base
        local tr       = util.TraceLine(alt_tr)
        cached_alt     = (pos.z - tr.HitPos.z) / 39.37
    end
    return cached_alt
end

local function GetAimDistance(base)
    local ct = CurTime()
    if ct >= next_aim_trace then
        next_aim_trace = ct + 0.05
        local pos = base:GetPos()
        local dir = base:GetForward()
        aim_tr.start = pos
        aim_tr.endpos = pos + dir * 50000
        aim_tr.filter = base
        local tr = util.TraceLine(aim_tr)
        cached_aim_dist = pos:Distance(tr.HitPos) / 39.37
    end
    return cached_aim_dist
end

local function GetGasDisplay(base, b_vel)
    local target_gas = 0
    if cached_eng then
        local vx, vy = b_vel.x, b_vel.y
        local vel_xy = math.sqrt(vx * vx + vy * vy)
        target_gas   = math.Clamp(45 + (b_vel.z / 300) * 45 + (vel_xy / 600) * 10, 0, 99)
        target_gas   = target_gas + math.sin(CurTime() * 15) * 1.5
    end
    if not base.osd3_Gas then base.osd3_Gas = 0 end
    base.osd3_Gas = Lerp(FrameTime() * 5, base.osd3_Gas, target_gas)
    return math.Round(base.osd3_Gas)
end

local function GetRxColor(val)
    if val <= -10 then return clr_rx_g end
    if val <= -6  then return clr_rx_y end
    return clr_rx_r
end

local function DrawFilledCircleWithBorder(x, y, r)
    x = math.floor(x)
    y = math.floor(y)
    surface.SetDrawColor(0, 0, 0, 255)
    for dy = -r - 1, r + 1 do
        for dx = -r - 1, r + 1 do
            local dist = math.sqrt(dx * dx + dy * dy)
            if dist <= r + 1 and dist > r - 0.5 then
                surface.DrawRect(x + dx, y + dy, 1, 1)
            end
        end
    end
    surface.SetDrawColor(255, 255, 255, 230)
    for dy = -r, r do
        for dx = -r, r do
            if dx * dx + dy * dy <= r * r then
                surface.DrawRect(x + dx, y + dy, 1, 1)
            end
        end
    end
end

local function DrawTrianglePoly(x, y, size, point_right)
    x = math.floor(x)
    y = math.floor(y)
    local sym = point_right and "►" or "◄"
    draw.SimpleText(sym, "Crocus3_Tri", x, y, Color(0, 0, 0, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    draw.SimpleText(sym, "Crocus3_Tri", x, y, Color(255, 255, 255, 230), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

local function DrawHorizon(cx, cy, roll_deg, pitch_deg, sw, sh)
    local pitch_offset = math.Clamp(-pitch_deg * PITCH_SCALE, -MAX_OFFSET, MAX_OFFSET)

    local roll_rad = math.rad(-roll_deg)
    local cos_r    = math.cos(roll_rad)
    local sin_r    = math.sin(roll_rad)

    local ofs_x  = -sin_r * pitch_offset
    local ofs_y  =  cos_r * pitch_offset
    local base_x = cx + ofs_x
    local base_y = cy + ofs_y

    local nx = cos_r
    local ny = sin_r

    local start_offset = CROSSHAIR_HALF + DOT_R + 6

    for i = 1, DOT_COUNT do
        local dist = start_offset + (i - 1) * DOT_GAP + DOT_R

        local lx = math.Clamp(base_x - nx * dist, MARGIN, sw - MARGIN)
        local ly = math.Clamp(base_y - ny * dist, MARGIN, sh - MARGIN)
        local rx = math.Clamp(base_x + nx * dist, MARGIN, sw - MARGIN)
        local ry = math.Clamp(base_y + ny * dist, MARGIN, sh - MARGIN)

        DrawFilledCircleWithBorder(lx, ly, DOT_R)
        DrawFilledCircleWithBorder(rx, ry, DOT_R)
    end

    local tri_dist = start_offset + DOT_COUNT * DOT_GAP + DOT_R + 8

    local tri_lx = math.Clamp(base_x - nx * tri_dist, MARGIN, sw - MARGIN)
    local tri_ly = math.Clamp(base_y - ny * tri_dist, MARGIN, sh - MARGIN)
    local tri_rx = math.Clamp(base_x + nx * tri_dist, MARGIN, sw - MARGIN)
    local tri_ry = math.Clamp(base_y + ny * tri_dist, MARGIN, sh - MARGIN)

    DrawTrianglePoly(math.floor(tri_lx), math.floor(tri_ly), TRI_SIZE, true)
    DrawTrianglePoly(math.floor(tri_rx), math.floor(tri_ry), TRI_SIZE, false)
end

function Crocus.RenderOSD3(base, cx, cy, sw, sh)
    if not Crocus3 then return end
    if not IsValid(base) or base:IsDormant() then return end

    local ct      = CurTime()
    local clr_w   = Crocus3.clr_w
    local clr_g   = Crocus3.clr_grn
    local clr_gr  = Crocus3.clr_gry
    local pos     = base:GetPos()
    local ang     = base:GetAngles()
    local b_vel   = base:GetVelocity()
    local pct     = base:GetNWFloat("Crocus_BatteryPct", 1)
    local mah     = base:GetNWFloat("Crocus_mAh", 0)
    local f_time  = ct - (base.OSDStartTime or ct)
    local smooth_noise = Crocus.UpdateNoise and Crocus.UpdateNoise(base) or (base.SmoothNoise or 0)

    if Crocus.DrawNoiseOverlay then Crocus.DrawNoiseOverlay(smooth_noise, sw, sh) end

    if ct > next_slow_update then
        next_slow_update = ct + 0.1
        cached_eng       = base:GetEngineActive()
        local v_thr      = cached_thr / 100
        cached_volts     = math.max(12.0, (14.0 + 2.8 * pct) - (v_thr * 2.2))
        cached_cell_v    = cached_volts / 4
        cached_amps      = math.Clamp(12.3 + v_thr * 2.4 + math.sin(ct * 5) * 0.3, 0, 40)
        cached_fuse_str  = cached_eng and "Э. пред.: вкл" or "Э. пред.: выкл"
        cached_cheka     = (pct > 0.05) and "Чека: нет" or "Чека: есть"

        if smooth_noise > 60 then
            cached_link_str = "link-lost"; cached_link_ok = false
        elseif smooth_noise > 25 then
            cached_link_str = "link-weak"; cached_link_ok = false
        else
            cached_link_str = "link-ok"; cached_link_ok = true
        end

        cached_rx = -20.0
            + (ang.r / 90.0 * -1.5)
            + (ang.p / 90.0 * -0.8)
            + (smooth_noise  * 0.15)
            + math.sin(ct * 0.7) * 0.3

        cached_tx = 2.1
            + math.sin(ct * 0.3) * 0.05
            + math.sin(ct * 1.1) * 0.03
    end

    cached_thr = GetGasDisplay(base, b_vel)
    local alt   = GetAlt(pos, base)
    local aim_dist = GetAimDistance(base)
    local roll  = ang.r
    local pitch = ang.p

    DrawHorizon(cx, cy, roll, pitch, sw, sh)

    local cross_clr = clr_w
    if aim_dist <= 8 then
        cross_clr = clr_rx_r
    elseif aim_dist <= 13 then
        cross_clr = clr_rx_y
    elseif aim_dist <= 18 then
        cross_clr = clr_rx_g
    end

    surface.SetDrawColor(cross_clr.r, cross_clr.g, cross_clr.b, 220)
    surface.SetMaterial(CROSSHAIR_MAT)
    surface.DrawTexturedRect(cx - CROSSHAIR_HALF, cy - CROSSHAIR_HALF, CROSSHAIR_SIZE, CROSSHAIR_SIZE)

    local link_clr = cached_link_ok and clr_w or clr_red
    local rx_clr   = GetRxColor(cached_rx)
    local minutes  = math.floor(f_time / 60)
    local seconds  = math.floor(f_time % 60)

    TL(M, M, "ACRO*", "Crocus3_Main", clr_w)
    TL(M, M + L, string.format("%d:%02d", minutes, seconds), "Crocus3_Main", clr_w)
    TL(M, M + L*2, string.format("%.1f alt m", alt), "Crocus3_Main", clr_w)

    TR(cx - 14, M, string.format("%.1fV",  cached_volts),  "Crocus3_Main", clr_w)
    TL(cx + 14, M, string.format("%.2fV",  cached_cell_v), "Crocus3_Main", clr_w)

    local sy = cy
    TL(M, sy, cached_eng and "1" or "0", "Crocus3_Main", clr_gr)
    TL(M, sy + L, cached_fuse_str, "Crocus3_Main_RU", clr_gr)
    TL(M, sy + L * 2, cached_cheka, "Crocus3_Main_RU", clr_gr)
    TL(M, sy + L * 3, cached_link_str, "Crocus3_Main", link_clr)
    TL(M, sy + L * 5, string.format("rx: %.3f", cached_rx), "Crocus3_Main", rx_clr)
    TL(M, sy + L * 6, string.format("tx: %.3f", cached_tx), "Crocus3_Main", clr_w)

    local rx_x = sw - M
    local ry   = cy
    TR(rx_x, ry, string.format("%.1f A", cached_amps), "Crocus3_Main", clr_w)
    TR(rx_x, ry + L, string.format("%d mAh", math.Round(mah)), "Crocus3_Main", clr_w)
    TR(rx_x, ry + L * 2, string.format("%d %%", math.Round(pct * 100)), "Crocus3_Main", clr_w)
    TR(rx_x, ry + L * 4, string.format("%d %%", cached_thr), "Crocus3_Main", clr_w)
    TR(rx_x - 75, ry + L * 4, "газ:", "Crocus3_Main_RU", clr_w)
    TR(rx_x, ry + L * 5, string.format("roll: %.1f", roll), "Crocus3_Main", clr_w)
    TR(rx_x, ry + L * 6, string.format("pitch: %.1f", pitch), "Crocus3_Main", clr_w)

    local sh_m   = sh - M
    local sh_m_l = sh - M - L

    draw.SimpleText(string.format("FW: %.1f", cached_volts), "Crocus3_Main", M, sh_m_l, clr_w, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
    draw.SimpleText("БПЛА Пульт НСУ Запись Запись (по частям)", "Crocus3_Small_RU", M, sh_m, clr_g, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
    draw.SimpleText(string.format("FPS: %d", math.min(math.Round(1 / FrameTime()), 31)), "Crocus3_Main", cx, sh_m_l, clr_w, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
    draw.SimpleText("fix тепл.", "Crocus3_Small", cx, sh_m, clr_gr, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
    draw.SimpleText(Crocus3.SN, "Crocus3_Main", sw - M, sh_m, clr_w, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
end