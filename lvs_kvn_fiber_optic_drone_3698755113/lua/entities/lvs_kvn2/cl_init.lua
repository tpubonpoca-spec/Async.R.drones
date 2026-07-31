include("shared.lua")

KVN_OSD = KVN_OSD or {}

if not KVN_OSD.FontsCreated then
	surface.CreateFont("KVN_Main", {
		font      = "Officermans",
		size      = 36,
		weight    = 400,
		outline   = true,
		antialias = true,
		extended  = true,
	})
	surface.CreateFont("KVN_Small", {
		font      = "Officermans",
		size      = 28,
		weight    = 400,
		outline   = true,
		antialias = true,
		extended  = true,
	})
	surface.CreateFont("KVN_Main_RU", {
		font      = "Courier New",
		size      = 36,
		weight    = 700,
		outline   = true,
		antialias = false,
		extended  = true,
	})
	surface.CreateFont("KVN_Small_RU", {
		font      = "Courier New",
		size      = 29,
		weight    = 700,
		outline   = true,
		antialias = false,
		extended  = true,
	})
	surface.CreateFont("KVN_Tri", {
		font      = "Arial",
		size      = 16,
		weight    = 700,
		outline   = true,
		antialias = false,
		extended  = true,
	})
	surface.CreateFont("KVN_Death", {
		font      = "SF Pro Rounded",
		size      = 80,
		weight    = 600,
		outline   = false,
		antialias = true,
		extended  = true,
	})
	KVN_OSD.FontsCreated = true
end

local CROSSHAIR_MAT  = Material("osd/2crosshair.png", "mips smooth noclamp")
local FLIR_NOISE_MAT = Material("models/sw/shared/noise")
local CROSSHAIR_SIZE = 64
local CROSSHAIR_HALF = 32

local clr_w    = Color(255, 255, 255, 255)
local clr_grn  = Color(0, 255, 0, 255)
local clr_gry  = Color(150, 150, 150, 255)
local clr_red  = Color(255, 80, 80, 255)
local clr_rx_g = Color(0, 255, 0, 255)
local clr_rx_y = Color(255, 240, 0, 255)
local clr_rx_r = Color(255, 50, 50, 255)

local M = 22
local L = 38

local PITCH_SCALE = 5.0
local MAX_OFFSET  = 200
local DOT_COUNT   = 9
local DOT_R       = 3
local DOT_GAP     = 22
local TRI_SIZE    = 5
local MARGIN      = 20

local alt_tr           = {}
local next_alt_trace   = 0
local cached_alt       = 0
local aim_tr           = {}
local next_aim_trace   = 0
local cached_aim_dist  = 999

local cached_volts     = 0
local cached_cell_v    = 0
local cached_amps      = 0
local cached_thr       = 0
local cached_rx        = -20
local cached_tx        = 2.1
local cached_link_str  = "link-ok"
local cached_link_ok   = true
local cached_fuse_str  = "Э. пред.: вкл"
local cached_cheka     = "Чека: нет"
local cached_eng       = false
local next_slow_update = 0

local FLIR_Active  = false
local DefMats      = {}
local DefClrs      = {}
local next_xray_update = 0

local ColorTab = {
	["$pp_colour_addr"]       = -.3,
	["$pp_colour_addg"]       = -.4,
	["$pp_colour_addb"]       = -.4,
	["$pp_colour_brightness"] = .1,
	["$pp_colour_contrast"]   = 1,
	["$pp_colour_colour"]     = 0,
	["$pp_colour_mulr"]       = 0,
	["$pp_colour_mulg"]       = 0,
	["$pp_colour_mulb"]       = 0,
}

local sw_death   = ScrW()
local sh_death   = ScrH()
local death_rt_1 = GetRenderTarget("KVNDeathCamRT_1", sw_death, sh_death, false)
local death_rt_2 = GetRenderTarget("KVNDeathCamRT_2", sw_death, sh_death, false)
local death_rt_3 = GetRenderTarget("KVNDeathCamRT_3", sw_death, sh_death, false)
local death_mat  = CreateMaterial("KVNDeathCamMat", "UnlitGeneric", {
	["$basetexture"] = "KVNDeathCamRT_1",
	["$vertexcolor"] = 1,
	["$ignorez"]     = 1,
})

local last_rt_copy_time  = 0
local last_rt_written    = 1
local last_base_ent      = nil
local last_hp            = 100
local kvn_explosion_time = -1

local function CleanupXRay()
	hook.Remove("RenderScene", "KVN_XRay_ApplyMats")
	hook.Remove("RenderScreenspaceEffects", "KVN_XRay_RenderModify")
	for ent, mat in pairs(DefMats) do
		if IsValid(ent) then ent:SetMaterial(mat) end
	end
	for ent, clr in pairs(DefClrs) do
		if IsValid(ent) then
			ent:SetRenderMode(RENDERMODE_TRANSALPHA)
			ent:SetColor(Color(clr.r, clr.g, clr.b, clr.a))
		end
	end
	DefMats = {}
	DefClrs = {}
	FLIR_Active = false
end

local function XRayFX()
	DrawColorModify(ColorTab)
	DrawBloom(0, 1, 1, 1, 0, 0, 0, 0, 0)
end

local function XRayMat()
	local ct = CurTime()
	if ct < next_xray_update then return end
	next_xray_update = ct + 2.0
	for k, v in pairs(ents.GetAll()) do
		if string.sub((v:GetModel() or ""), -3) == "mdl" then
			local r, g, b, a = v:GetColor().r, v:GetColor().g, v:GetColor().b, v:GetColor().a
			if a > 0 then
				local entmat = v:GetMaterial()
				if v:IsNPC() or v:IsPlayer() then
					if not (r == 255 and g == 255 and b == 255 and a == 255) then
						DefClrs[v] = Color(r, g, b, a)
						v:SetColor(Color(255, 255, 255, 255))
					end
					if entmat ~= "xray/living" then
						DefMats[v] = entmat
						v:SetMaterial("xray/living")
					end
				else
					if not (r == 255 and g == 255 and b == 255 and a == 255) then
						DefClrs[v] = Color(r, g, b, a)
						v:SetColor(Color(255, 255, 255, 255))
					end
					if entmat ~= "xray/prop" then
						DefMats[v] = entmat
						v:SetMaterial("xray/living")
					end
				end
			end
		end
	end
end

hook.Add("Think", "KVN_FLIR_Manager", function()
	local ply = LocalPlayer()
	if not IsValid(ply) then
		if FLIR_Active then CleanupXRay() end
		return
	end
	local veh = ply:GetVehicle()
	if not IsValid(veh) then
		if FLIR_Active then CleanupXRay() end
		return
	end
	local base = veh:GetNWEntity("LVS_Entity")
	if not IsValid(base) then base = veh:GetParent() end
	local cls = IsValid(base) and base:GetClass() or ""
	if cls ~= "lvs_kvn1" and cls ~= "lvs_kvn2" then
		if FLIR_Active then CleanupXRay() end
		return
	end

	local flir_on = base:GetNWBool("KVN_FLIR", false)
	if flir_on and not FLIR_Active then
		hook.Add("RenderScene", "KVN_XRay_ApplyMats", XRayMat)
		hook.Add("RenderScreenspaceEffects", "KVN_XRay_RenderModify", XRayFX)
		FLIR_Active = true
	elseif not flir_on and FLIR_Active then
		CleanupXRay()
	end
end)

net.Receive("KVN_Net_Explode", function()
	local pos  = net.ReadVector()
	ParticleEffect("ins_rpg_explosion", pos, Angle(-90, 0, 0), nil)
	if swv3 and swv3.CreateSound then
		swv3.CreateSound(pos, false,
			"sw/explosion/exp_tny_1.wav",
			"sw/explosion/exp_sml_dst_1.wav",
			"sw/explosion/exp_sml_far_1.wav")
	else
		sound.Play("sw/explosion/exp_tny_1.wav", pos, 140, 100, 1)
	end
end)

local KVN_SN = "SN:"
for i = 1, 8 do KVN_SN = KVN_SN .. math.random(0, 9) end

local function TL(x, y, text, font, color)
	draw.SimpleText(text, font or "KVN_Main", x, y, color or clr_w, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
end

local function TR(x, y, text, font, color)
	draw.SimpleText(text, font or "KVN_Main", x, y, color or clr_w, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
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
		local pos     = base:GetPos()
		local dir     = base:GetForward()
		aim_tr.start  = pos
		aim_tr.endpos = pos + dir * 50000
		aim_tr.filter = base
		local tr      = util.TraceLine(aim_tr)
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
	if not base.osd_Gas then base.osd_Gas = 0 end
	base.osd_Gas = Lerp(FrameTime() * 5, base.osd_Gas, target_gas)
	return math.Round(base.osd_Gas)
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
	draw.SimpleText(sym, "KVN_Tri", x, y, Color(0, 0, 0, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	draw.SimpleText(sym, "KVN_Tri", x, y, Color(255, 255, 255, 230), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

local function DrawHorizon(cx, cy, roll_deg, pitch_deg, sw, sh)
	local pitch_offset = math.Clamp(-pitch_deg * PITCH_SCALE, -MAX_OFFSET, MAX_OFFSET)
	local roll_rad = math.rad(-roll_deg)
	local cos_r    = math.cos(roll_rad)
	local sin_r    = math.sin(roll_rad)
	local base_x   = cx + (-sin_r * pitch_offset)
	local base_y   = cy + (cos_r * pitch_offset)
	local nx = cos_r
	local ny = sin_r
	local start_offset = CROSSHAIR_HALF + DOT_R + 6
	for i = 1, DOT_COUNT do
		local dist = start_offset + (i - 1) * DOT_GAP + DOT_R
		DrawFilledCircleWithBorder(math.Clamp(base_x - nx * dist, MARGIN, sw - MARGIN), math.Clamp(base_y - ny * dist, MARGIN, sh - MARGIN), DOT_R)
		DrawFilledCircleWithBorder(math.Clamp(base_x + nx * dist, MARGIN, sw - MARGIN), math.Clamp(base_y + ny * dist, MARGIN, sh - MARGIN), DOT_R)
	end
	local tri_dist = start_offset + DOT_COUNT * DOT_GAP + DOT_R + 8
	DrawTrianglePoly(math.floor(math.Clamp(base_x - nx * tri_dist, MARGIN, sw - MARGIN)), math.floor(math.Clamp(base_y - ny * tri_dist, MARGIN, sh - MARGIN)), TRI_SIZE, true)
	DrawTrianglePoly(math.floor(math.Clamp(base_x + nx * tri_dist, MARGIN, sw - MARGIN)), math.floor(math.Clamp(base_y + ny * tri_dist, MARGIN, sh - MARGIN)), TRI_SIZE, false)
end

local function DrawFLIROverlay(base, cx, cy, sw, sh)
	if base:GetNWBool("KVN_FLIR", false) then
		surface.SetDrawColor(255, 255, 255, 255)
		surface.SetMaterial(FLIR_NOISE_MAT)
		surface.DrawTexturedRectRotated(cx, cy, sw, sh * 1.75, 0)
	end
end

if not KVN_OSD.HookAdded then
	hook.Add("HUDPaint", "KVN_OSD_Paint", function()
		local ply = LocalPlayer()
		if not IsValid(ply) then return end

		local ct = CurTime()
		local sw, sh = ScrW(), ScrH()
		local cx, cy = sw * 0.5, sh * 0.5

		local veh  = ply:GetVehicle()
		local base = nil
		local drone_hp       = 0
		local is_valid_drone = false

		if IsValid(veh) then
			base = veh:GetNWEntity("LVS_Entity")
			if not IsValid(base) then base = veh:GetParent() end
			if IsValid(base) then
				local cls = base:GetClass()
				if cls == "lvs_kvn1" or cls == "lvs_kvn2" then
					is_valid_drone = true
					drone_hp = base:GetHP()
				end
			end
		end

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
			kvn_explosion_time = -1
		else
			if last_base_ent ~= nil and kvn_explosion_time == -1 then
				local skip = input.IsKeyDown(KEY_E) or input.IsKeyDown(KEY_Z)
				if not skip or last_hp <= 10 then
					kvn_explosion_time = ct
					local rt = (last_rt_written == 1) and death_rt_1 or (last_rt_written == 2 and death_rt_2 or death_rt_3)
					death_mat:SetTexture("$basetexture", rt)
				else
					last_base_ent = nil
				end
			end
		end

		if kvn_explosion_time ~= -1 then
			local time_passed = ct - kvn_explosion_time
			if time_passed >= 2.0 then
				kvn_explosion_time = -1
				last_base_ent = nil
				return
			end
			surface.SetDrawColor(255, 255, 255, 255)
			surface.SetMaterial(death_mat)
			surface.DrawTexturedRect(0, 0, sw, sh)
			surface.SetAlphaMultiplier(0.4)
			draw.SimpleTextOutlined("NO IMAGE", "KVN_Death", cx, cy, Color(200, 200, 200, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, 255))
			surface.SetAlphaMultiplier(1)
			return
		end

		if not is_valid_drone then return end
		if base:IsDormant() then return end

		local pos    = base:GetPos()
		local ang    = base:GetAngles()
		local b_vel  = base:GetVelocity()
		local pct    = base:GetNWFloat("KVN_BatteryPct", 1)
		local mah    = base:GetNWFloat("KVN_mAh", 0)

		if not base.OSDStartTime then base.OSDStartTime = ct end
		local f_time = ct - base.OSDStartTime

		if ct > next_slow_update then
			next_slow_update = ct + 0.1
			cached_eng       = base:GetEngineActive()
			local v_thr      = cached_thr / 100
			cached_volts     = math.max(12.0, (14.0 + 2.8 * pct) - (v_thr * 2.2))
			cached_cell_v    = cached_volts / 4
			cached_amps      = math.Clamp(12.3 + v_thr * 2.4 + math.sin(ct * 5) * 0.3, 0, 40)
			cached_fuse_str  = cached_eng and "Э. пред.: вкл" or "Э. пред.: выкл"
			cached_cheka     = (pct > 0.05) and "Чека: нет" or "Чека: есть"
			cached_link_str  = "link-ok"
			cached_link_ok   = true
			cached_rx        = -20.0 + (ang.r / 90.0 * -1.5) + (ang.p / 90.0 * -0.8) + math.sin(ct * 0.7) * 0.3
			cached_tx        = 2.1 + math.sin(ct * 0.3) * 0.05 + math.sin(ct * 1.1) * 0.03
		end

		cached_thr     = GetGasDisplay(base, b_vel)
		local alt      = GetAlt(pos, base)
		local aim_dist = GetAimDistance(base)
		local roll     = ang.r
		local pitch    = ang.p

		DrawFLIROverlay(base, cx, cy, sw, sh)

		DrawHorizon(cx, cy, roll, pitch, sw, sh)

		local cross_clr = clr_w
		if aim_dist <= 8 then cross_clr = clr_rx_r
		elseif aim_dist <= 13 then cross_clr = clr_rx_y
		elseif aim_dist <= 18 then cross_clr = clr_rx_g end

		surface.SetDrawColor(cross_clr.r, cross_clr.g, cross_clr.b, 220)
		surface.SetMaterial(CROSSHAIR_MAT)
		surface.DrawTexturedRect(cx - CROSSHAIR_HALF, cy - CROSSHAIR_HALF, CROSSHAIR_SIZE, CROSSHAIR_SIZE)

		local link_clr = cached_link_ok and clr_w or clr_red
		local rx_clr   = GetRxColor(cached_rx)
		local minutes  = math.floor(f_time / 60)
		local seconds  = math.floor(f_time % 60)

		TL(M, M,       "ACRO*")
		TL(M, M + L,   string.format("%d:%02d", minutes, seconds))
		TL(M, M + L*2, string.format("%.1f alt m", alt))

		TR(cx - 14, M, string.format("%.1fV", cached_volts))
		TL(cx + 14, M, string.format("%.2fV", cached_cell_v))

		local sy = cy
		TL(M, sy,         cached_eng and "1" or "0",            "KVN_Main",    clr_gry)
		TL(M, sy + L,     cached_fuse_str,                      "KVN_Main_RU", clr_gry)
		TL(M, sy + L * 2, cached_cheka,                         "KVN_Main_RU", clr_gry)
		TL(M, sy + L * 3, cached_link_str,                      "KVN_Main",    link_clr)
		TL(M, sy + L * 5, string.format("rx: %.3f", cached_rx), "KVN_Main",    rx_clr)
		TL(M, sy + L * 6, string.format("tx: %.3f", cached_tx), "KVN_Main",    clr_w)

		local rx_x = sw - M
		local ry   = cy
		TR(rx_x,      ry,         string.format("%.1f A",  cached_amps))
		TR(rx_x,      ry + L,     string.format("%d mAh",  math.Round(mah)))
		TR(rx_x,      ry + L * 2, string.format("%d %%",   math.Round(pct * 100)))
		TR(rx_x,      ry + L * 4, string.format("%d %%",   cached_thr))
		TR(rx_x - 75, ry + L * 4, "газ:",                  "KVN_Main_RU")
		TR(rx_x,      ry + L * 5, string.format("roll: %.1f",  roll))
		TR(rx_x,      ry + L * 6, string.format("pitch: %.1f", pitch))

		local sh_m   = sh - M
		local sh_m_l = sh - M - L
		draw.SimpleText(string.format("FW: %.1f", cached_volts),    "KVN_Main",    M,      sh_m_l, clr_w,   TEXT_ALIGN_LEFT,   TEXT_ALIGN_BOTTOM)
		draw.SimpleText("БПЛА Пульт НСУ Запись Запись (по частям)", "KVN_Small_RU", M,     sh_m,   clr_grn, TEXT_ALIGN_LEFT,   TEXT_ALIGN_BOTTOM)
		draw.SimpleText(string.format("FPS: %d", math.min(math.Round(1 / FrameTime()), 31)), "KVN_Main", cx, sh_m_l, clr_w, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
		draw.SimpleText("fix тепл.",                                "KVN_Small",   cx,     sh_m,   clr_gry, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
		draw.SimpleText(KVN_SN,                                     "KVN_Main",    sw - M, sh_m,   clr_w,   TEXT_ALIGN_RIGHT,  TEXT_ALIGN_BOTTOM)
	end)
	KVN_OSD.HookAdded = true
end

function ENT:OnFrame()
	self:AnimRotor()
end

function ENT:AnimRotor()
	local RPM = self:GetThrottle() * 2500
	self.RPM = self.RPM and (self.RPM + RPM * RealFrameTime() * 2) or 0
	if self.RPM > 360 then self.RPM = self.RPM - 360 end
	self:ManipulateBoneAngles(1, Angle(self.RPM, 0, 0))
	self:ManipulateBoneAngles(2, Angle(self.RPM, 0, 0))
	self:ManipulateBoneAngles(3, Angle(self.RPM, 0, 0))
	self:ManipulateBoneAngles(4, Angle(self.RPM, 0, 0))
	self:InvalidateBoneCache()
end

function ENT:LVSHudPaint(X, Y, ply)
end