if SERVER then return end

local NOISE_MAT      = Material("effects/fpv_noise")
local FLIR_NOISE_MAT = Material("models/sw/shared/noise")

local DefMats = {}
local DefClrs = {}
local FLIR_Active = false

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

local function CleanupXRay()
    hook.Remove("RenderScene", "Crocus_XRay_ApplyMats")
    hook.Remove("RenderScreenspaceEffects", "Crocus_XRay_RenderModify")
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

local next_xray_update = 0
local XRAY_UPDATE_INTERVAL = 2.0

local function XRayMat()
    local ct = CurTime()
    if ct < next_xray_update then return end
    next_xray_update = ct + XRAY_UPDATE_INTERVAL
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

hook.Add("Think", "Crocus_FLIR_Manager", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then
        if FLIR_Active then CleanupXRay() end
        return
    end
    local base = Crocus.GetDroneBase(ply)
    if IsValid(base) then
        local flir_on = base:GetNWBool("Crocus_FLIR", false)
        if flir_on and not FLIR_Active then
            hook.Add("RenderScene", "Crocus_XRay_ApplyMats", XRayMat)
            hook.Add("RenderScreenspaceEffects", "Crocus_XRay_RenderModify", XRayFX)
            FLIR_Active = true
        elseif not flir_on and FLIR_Active then
            CleanupXRay()
        end
    else
        if FLIR_Active then CleanupXRay() end
    end
end)

function Crocus.DrawFLIROverlay(base, cx, cy, sw, sh)
    if base:GetNWBool("Crocus_FLIR", false) then
        surface.SetDrawColor(255, 255, 255, 255)
        surface.SetMaterial(FLIR_NOISE_MAT)
        surface.DrawTexturedRectRotated(cx, cy, sw, sh * 1.75, 0)
    end
end

function Crocus.DrawNoiseOverlay(smoothNoise, sw, sh)
    if smoothNoise > 1 then
        local ns = 25
        local sx, sy = (CurTime() * ns) % 1, (CurTime() * ns * 1.2) % 1
        surface.SetMaterial(NOISE_MAT)
        surface.SetDrawColor(255, 255, 255, smoothNoise)
        surface.DrawTexturedRectUV(0, 0, sw, sh, sx, sy, sx + 1, sy + 1)
    end
end

function Crocus.DrawDeathNoise(sw, sh, alpha)
    local ns = 20
    local sx, sy = (CurTime() * ns) % 1, (CurTime() * ns * 1.5) % 1
    surface.SetMaterial(NOISE_MAT)
    surface.SetDrawColor(255, 255, 255, alpha)
    surface.DrawTexturedRectUV(0, 0, sw, sh, sx, sy, sx + 1, sy + 1)
end

local vhs_backup = {
    active = false,
    viewtype = 1,
    hook = "RenderScreenspaceEffects",
    date = true,
    vcr = true,
    middle = nil,
    chroma = false,
    luma = false,
    wave = false,
    lines = false,
    comets = false,
    comets_factor = 50000,
    presize = true,
    tubedelay = false,
    colour = 1,
}

local desat_next  = 0
local desat_end   = 0
local desat_value = 1

local vhs_initialized = false

hook.Add("Think", "Crocus_VHS_Integration_Manager", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    if not REALISTICVHSEFFECT2_CFG then return end

    if not vhs_initialized then
        RunConsoleCommand("realisticvhseffect2_enabled", "0")
        if REALISTICVHSEFFECT2_CFG.viewtype == 0 then
            REALISTICVHSEFFECT2_CFG.viewtype = 1
        end
        vhs_initialized = true
    end

    local veh = ply:GetVehicle()
    local in_drone = false
    local drone_base = nil

    if IsValid(veh) then
        drone_base = veh:GetNWEntity("LVS_Entity")
        if not IsValid(drone_base) then drone_base = veh:GetParent() end
        if IsValid(drone_base) and Crocus.Entities[drone_base:GetClass()] then
            in_drone = true
        end
    end

    local use_vhs = GetConVar("crocus_vhs_enable"):GetBool()

    if in_drone and use_vhs and not vhs_backup.active then
        vhs_backup.active = true
        vhs_backup.viewtype = REALISTICVHSEFFECT2_CFG.viewtype
        vhs_backup.hook = REALISTICVHSEFFECT2_CFG.currenthookclass
        vhs_backup.date = REALISTICVHSEFFECT2_CFG.osd.dateenabled
        vhs_backup.vcr = REALISTICVHSEFFECT2_CFG.osd.vcr_text_enabled
        vhs_backup.middle = REALISTICVHSEFFECT2_CFG.osd.middletext
        vhs_backup.chroma = REALISTICVHSEFFECT2_CFG.channelssettings.chroma_noise_enabled
        vhs_backup.luma = REALISTICVHSEFFECT2_CFG.channelssettings.luma_noise_enabled
        vhs_backup.wave = REALISTICVHSEFFECT2_CFG.wave.enabled
        vhs_backup.lines = REALISTICVHSEFFECT2_CFG.lines.enabled
        vhs_backup.comets = REALISTICVHSEFFECT2_CFG.comets.enabled
        vhs_backup.comets_factor = REALISTICVHSEFFECT2_CFG.comets.factor
        vhs_backup.presize = REALISTICVHSEFFECT2_CFG.presize
        vhs_backup.tubedelay = REALISTICVHSEFFECT2_CFG.tubedelay.enabled
        vhs_backup.colour    = REALISTICVHSEFFECT2_CFG.postclrmod["pp_colour_colour"]
        desat_next  = 0
        desat_end   = 0
        desat_value = 1
        RunConsoleCommand("realisticvhseffect2_enabled", "1")
        REALISTICVHSEFFECT2_CFG.channelssettings.chroma_noise_enabled = false
        REALISTICVHSEFFECT2_CFG.channelssettings.luma_noise_enabled = false
        REALISTICVHSEFFECT2_CFG.wave.enabled = false
        REALISTICVHSEFFECT2_CFG.lines.enabled = false
        REALISTICVHSEFFECT2_CFG.tubedelay.enabled = false
        REALISTICVHSEFFECT2_CFG.presize = true
        REALISTICVHSEFFECT2_CFG.viewtype = 0
        REALISTICVHSEFFECT2_CFG.osd.dateenabled = false
        REALISTICVHSEFFECT2_CFG.osd.vcr_text_enabled = false
        REALISTICVHSEFFECT2_CFG.osd.middletext = nil
        if REALISTICVHSEFFECT2_CFG.currenthookclass ~= "RenderScreenspaceEffects" then
            RunConsoleCommand("realisticvhseffect2_changehook", "RenderScreenspaceEffects")
        end
    elseif (not in_drone or not use_vhs) and vhs_backup.active then
        vhs_backup.active = false
        RunConsoleCommand("realisticvhseffect2_enabled", "0")
        if vhs_backup.viewtype == 0 then vhs_backup.viewtype = 1 end
        REALISTICVHSEFFECT2_CFG.viewtype = vhs_backup.viewtype
        REALISTICVHSEFFECT2_CFG.osd.dateenabled = vhs_backup.date
        REALISTICVHSEFFECT2_CFG.osd.vcr_text_enabled = vhs_backup.vcr
        REALISTICVHSEFFECT2_CFG.osd.middletext = vhs_backup.middle
        REALISTICVHSEFFECT2_CFG.channelssettings.chroma_noise_enabled = vhs_backup.chroma
        REALISTICVHSEFFECT2_CFG.channelssettings.luma_noise_enabled = vhs_backup.luma
        REALISTICVHSEFFECT2_CFG.wave.enabled = vhs_backup.wave
        REALISTICVHSEFFECT2_CFG.lines.enabled = vhs_backup.lines
        REALISTICVHSEFFECT2_CFG.comets.enabled = vhs_backup.comets
        REALISTICVHSEFFECT2_CFG.comets.factor = vhs_backup.comets_factor
        REALISTICVHSEFFECT2_CFG.presize = vhs_backup.presize
        REALISTICVHSEFFECT2_CFG.tubedelay.enabled = vhs_backup.tubedelay
        REALISTICVHSEFFECT2_CFG.postclrmod["pp_colour_colour"] = vhs_backup.colour
        desat_value = 1
        if vhs_backup.hook and vhs_backup.hook ~= "RenderScreenspaceEffects" then
            RunConsoleCommand("realisticvhseffect2_changehook", vhs_backup.hook)
        end
    elseif not in_drone then
        if GetConVar("realisticvhseffect2_enabled"):GetInt() == 1 then
            RunConsoleCommand("realisticvhseffect2_enabled", "0")
        end
    elseif in_drone and use_vhs and vhs_backup.active then
        REALISTICVHSEFFECT2_CFG.comets.enabled = GetConVar("crocus_vhs_comets"):GetBool()
        local use_aberration = GetConVar("crocus_vhs_aberration"):GetBool()
        REALISTICVHSEFFECT2_CFG.channelssettings.chroma_noise_enabled = use_aberration
        local use_chroma = GetConVar("crocus_vhs_chroma"):GetBool()
        if use_chroma then
            REALISTICVHSEFFECT2_CFG.cameraclrdist.r = 4
            REALISTICVHSEFFECT2_CFG.cameraclrdist.g = 0
            REALISTICVHSEFFECT2_CFG.cameraclrdist.b = -4
        else
            REALISTICVHSEFFECT2_CFG.cameraclrdist.r = 0
            REALISTICVHSEFFECT2_CFG.cameraclrdist.g = 0
            REALISTICVHSEFFECT2_CFG.cameraclrdist.b = 0
        end
        REALISTICVHSEFFECT2_CFG.tubedelay.enabled = GetConVar("crocus_vhs_tubedelay"):GetBool()

        if GetConVar("crocus_vhs_desat"):GetBool() then
            local ct = CurTime()
            if ct > desat_next then
                desat_end  = ct + math.Rand(0.5, 1.0)
                desat_next = ct + math.Rand(8, 25)
            end
            local target = (ct < desat_end) and 0 or 1
            desat_value = Lerp(FrameTime() * 3, desat_value, target)
            REALISTICVHSEFFECT2_CFG.postclrmod["pp_colour_colour"] = desat_value
        else
            REALISTICVHSEFFECT2_CFG.postclrmod["pp_colour_colour"] = 1
        end
        if IsValid(drone_base) then
            local current_noise = drone_base.SmoothNoise or 0
            if current_noise > 2 then
                REALISTICVHSEFFECT2_CFG.comets.factor = math.Clamp(50000 - (current_noise * 450), 500, 50000)
            else
                REALISTICVHSEFFECT2_CFG.comets.factor = 50000
            end
        end
    end
end)

hook.Add("DrawOverlay", "Crocus_VHS_BlackBorders_Fix", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    local veh = ply:GetVehicle()
    if not IsValid(veh) then return end
    local base = veh:GetNWEntity("LVS_Entity")
    if not IsValid(base) then base = veh:GetParent() end
    if IsValid(base) and Crocus.Entities[base:GetClass()] then
        if GetConVar("crocus_vhs_enable"):GetBool() and Crocus.explosion_time == -1 then
            local sw, sh = ScrW(), ScrH()
            surface.SetDrawColor(0, 0, 0, 255)
            surface.DrawRect(0, 0, 10, sh)
            surface.DrawRect(sw - 10, 0, 10, sh)
            surface.DrawRect(0, 0, sw, 10)
            surface.DrawRect(0, sh - 10, sw, 10)
        end
    end
end)