if SERVER then
    AddCSLuaFile()
    return
end

Crocus = Crocus or {}
Crocus.Entities = Crocus.Entities or {
    ["sw_crocus"]      = true,
    ["sw_crocus_pg7"]  = true,
    ["sw_crocus_tbg7"] = true,
}

CreateClientConVar("crocus_hud_type",    "1", true, false)
CreateClientConVar("crocus_name",        "",  true, false)
CreateClientConVar("crocus_death_noise", "1", true, false)
CreateClientConVar("crocus_death_cam",   "1", true, false)
CreateClientConVar("crocus_vhs_enable",  "1", true, false)
CreateClientConVar("crocus_vhs_comets",  "1", true, false)
CreateClientConVar("crocus_vhs_aberration", "0", true, false)
CreateClientConVar("crocus_vhs_chroma",     "1", true, false)
CreateClientConVar("crocus_vhs_tubedelay",  "0", true, false)
CreateClientConVar("crocus_vhs_desat",      "1", true, false)
CreateClientConVar("crocus_vhs_shake",      "1", true, false)

include("osd1/cl_utils.lua")
include("osd1/cl_baza.lua")
include("osd1/cl_signal.lua")
include("osd1/cl_effects.lua")
include("osd1/cl_osd.lua")
include("osd2/cl_utils2.lua")
include("osd2/cl_osd2.lua")
include("osd3/cl_utils3.lua")
include("osd3/cl_osd3.lua")

net.Receive("Crocus_Net_Explode", function()
    local pos         = net.ReadVector()
    local sNear       = "sw/avia/crocus/exp.wav"
    local sFar        = "sw/avia/crocus/exp_far.wav"
    local sDist       = "sw/avia/crocus/exp_dist.wav"
    ParticleEffect("ins_rpg_explosion", pos, Angle(-90, 0, 0), nil)
    if swv3 and swv3.CreateSound then
        swv3.CreateSound(pos, false, sNear, sFar, sDist)
    else
        sound.Play(sNear, pos, 140, 100, 1)
    end
end)

local function MakeSectionHeader(panel, text)
    local header = vgui.Create("DPanel", panel)
    header:SetTall(26)
    header.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(30, 30, 35, 240))
        surface.SetDrawColor(80, 120, 200, 180)
        surface.DrawRect(0, h - 1, w, 1)
        draw.SimpleText(text, "DermaDefaultBold", 10, h * 0.5, Color(180, 200, 255, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
    panel:AddItem(header)
end

local function MakeSpacer(panel, height)
    local sp = vgui.Create("DPanel", panel)
    sp:SetTall(height or 6)
    sp.Paint = function() end
    panel:AddItem(sp)
end

local function MakeInfoButton(parent, tooltip, x, y)
    local btn = vgui.Create("DButton", parent)
    btn:SetSize(16, 16)
    btn:SetPos(x, y)
    btn:SetText("")
    btn.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(60, 100, 180, 220))
        draw.SimpleText("i", "DermaDefaultBold", w * 0.5, h * 0.5, Color(255, 255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    btn:SetTooltip(tooltip)
    btn.DoClick = function() end
    return btn
end

local function MakeStyledCheckbox(panel, label, convar, tooltip)
    local row = vgui.Create("DPanel", panel)
    row:SetTall(24)
    row.Paint = function(self, w, h)
        draw.RoundedBox(3, 0, 0, w, h, Color(25, 25, 30, 160))
    end
    local cb = vgui.Create("DCheckBoxLabel", row)
    cb:SetConVar(convar)
    cb:SetText("  " .. label)
    cb:SetFont("DermaDefaultBold")
    cb:SetTextColor(Color(255, 255, 255, 255))
    cb:SetDark(false)
    cb:SetPos(4, 4)
    cb:SizeToContents()
    if tooltip then
        MakeInfoButton(row, tooltip, cb:GetX() + cb:GetWide() + 4, 4)
    end
    panel:AddItem(row)
end

local function MakeColorNoiseCheckbox(panel)
    local row = vgui.Create("DPanel", panel)
    row:SetTall(24)
    row.Paint = function(self, w, h)
        draw.RoundedBox(3, 0, 0, w, h, Color(25, 25, 30, 160))
    end
    local cb = vgui.Create("DCheckBoxLabel", row)
    cb:SetConVar("crocus_vhs_aberration")
    cb:SetText("  Enable Color Noise")
    cb:SetFont("DermaDefaultBold")
    cb:SetTextColor(Color(255, 255, 255, 255))
    cb:SetDark(false)
    cb:SetPos(4, 4)
    cb:SizeToContents()
    local warn = vgui.Create("DLabel", row)
    warn:SetText("  (! High FPS cost)")
    warn:SetFont("DermaDefaultBold")
    warn:SetTextColor(Color(220, 60, 60, 255))
    warn:SizeToContents()
    warn:SetPos(cb:GetX() + cb:GetWide(), 4)
    MakeInfoButton(row, "EN: Colored flickering pixel noise over the image. High FPS cost!\nRU: Цветной мерцающий шум поверх картинки. Снижает FPS!", cb:GetX() + cb:GetWide() + warn:GetWide() + 4, 4)
    panel:AddItem(row)
end

local function MakeGroundNoiseButton(panel)
    local btn = vgui.Create("DButton", panel)
    btn:SetTall(30)
    btn:SetText("")
    local state = game.GetWorld():GetNWBool("Crocus_GroundNoise", true)
    btn._state = state
    btn.Paint = function(self, w, h)
        local bg = self._state and Color(35, 80, 35, 220) or Color(80, 35, 35, 220)
        local border = self._state and Color(60, 160, 60, 200) or Color(160, 60, 60, 200)
        draw.RoundedBox(5, 0, 0, w, h, bg)
        surface.SetDrawColor(border)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        local dot = self._state and "●" or "●"
        local dotclr = self._state and Color(80, 220, 80, 255) or Color(220, 80, 80, 255)
        draw.SimpleText(dot, "DermaDefaultBold", 12, h * 0.5, dotclr, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        local label = "Proximity Noise:  " .. (self._state and "ENABLED" or "DISABLED")
        draw.SimpleText(label, "DermaDefaultBold", w * 0.5, h * 0.5, Color(220, 220, 220, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    btn.DoClick = function(self)
        RunConsoleCommand("crocus_groundnoise_toggle")
        timer.Simple(0.15, function()
            if IsValid(self) then
                self._state = game.GetWorld():GetNWBool("Crocus_GroundNoise", true)
            end
        end)
    end
    panel:AddItem(btn)
end

hook.Add("PopulateToolMenu", "Crocus_QMenu_Settings", function()
    spawnmenu.AddToolMenuOption("Utilities", "Crocus Settings", "Crocus_Graphics", "Graphics Settings", "", "", function(panel)
        panel:ClearControls()

        MakeSectionHeader(panel, "▸  VHS Effect")
        MakeStyledCheckbox(panel, "Enable VHS Effect",           "crocus_vhs_enable",
            "EN: Enables VHS filter (distortion, scanlines, wave)\nRU: Включает VHS фильтр (искажения, развёртка, волны)")
        MakeStyledCheckbox(panel, "Enable VHS Comets",           "crocus_vhs_comets",
            "EN: Light streak artifacts, increase with signal loss\nRU: Световые полосы, усиливаются при потере сигнала")
        MakeStyledCheckbox(panel, "Enable Chromatic Aberration", "crocus_vhs_chroma",
            "EN: RGB channel split on image edges\nRU: Смещение цветовых каналов по краям картинки")
        MakeStyledCheckbox(panel, "Enable Tube Delay",           "crocus_vhs_tubedelay",
            "EN: CRT phosphor trail effect on fast movement\nRU: Инерция кинескопа, след за объектами при движении")
        MakeStyledCheckbox(panel, "Enable Color Loss",           "crocus_vhs_desat",
            "EN: Random color desaturation, image goes B&W briefly\nRU: Случайная потеря цвета, картинка становится ч/б")
        MakeStyledCheckbox(panel, "Enable Screen Shake",         "crocus_vhs_shake",
            "EN: Slight screen shake during random interference\nRU: Лёгкая тряска экрана во время случайных помех")
        MakeColorNoiseCheckbox(panel)

        MakeSpacer(panel, 8)
        MakeSectionHeader(panel, "▸  Death Camera")
        MakeStyledCheckbox(panel, "Enable Death Cam Photo",    "crocus_death_cam",
            "EN: Shows last camera frame on drone death\nRU: Показывает последний кадр при уничтожении дрона")
        MakeStyledCheckbox(panel, "Enable Death Static Noise", "crocus_death_noise",
            "EN: Static noise screen on drone death\nRU: Экран со статическим шумом при уничтожении дрона")
    end)

    spawnmenu.AddToolMenuOption("Utilities", "Crocus Settings", "Crocus_OSD", "OSD Settings", "", "", function(panel)
        panel:ClearControls()

        MakeSectionHeader(panel, "▸  HUD Style")
        MakeSpacer(panel, 4)
        local combo = panel:ComboBox("Style", "crocus_hud_type")
        combo:AddChoice("Style 1 (Betaflight)",  "1")
        combo:AddChoice("Style 2 (Digital FPV)", "2")
        combo:AddChoice("Style 3 (KVN Drone)",   "3")

        MakeSpacer(panel, 8)
        MakeSectionHeader(panel, "▸  Custom Text")
        MakeSpacer(panel, 4)
        panel:TextEntry("Text on screen", "crocus_name")
        local btn = panel:Button("✕  Clear Text")
        btn.DoClick = function() RunConsoleCommand("crocus_name", "") end
    end)

    spawnmenu.AddToolMenuOption("Utilities", "Crocus Settings", "Crocus_Host", "Host Settings", "", "", function(panel)
        panel:ClearControls()

        if game.SinglePlayer() or LocalPlayer():IsListenServerHost() then
            MakeSectionHeader(panel, "▸  Interference")
            MakeSpacer(panel, 6)
            MakeGroundNoiseButton(panel)
        else
            MakeSpacer(panel, 8)
            local lbl = vgui.Create("DLabel", panel)
            lbl:SetText("  ⚠  Only available for the host.")
            lbl:SetFont("DermaDefaultBold")
            lbl:SetTextColor(Color(180, 130, 50, 255))
            lbl:SetContentAlignment(4)
            lbl:SetTall(24)
            panel:AddItem(lbl)
        end
    end)
end)

local last_hud_base = nil

hook.Add("HUDShouldDraw", "CrocusHideDefaultLVS", function(name)
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    local veh = ply:GetVehicle()
    if not IsValid(veh) then
        last_hud_base = nil
        return
    end
    local base = last_hud_base
    if not IsValid(base) then
        base = veh:GetNWEntity("LVS_Entity")
        if not IsValid(base) then base = veh:GetParent() end
        last_hud_base = IsValid(base) and Crocus.Entities[base:GetClass()] and base or nil
        base = last_hud_base
    end
    if IsValid(base) then
        if not base.HudDisabled then
            base.LVSHudPaint  = function() end
            base.HudDisabled  = true
            base.OSDStartTime = CurTime()
        end
        if name == "LVS_HUD" or name == "LVS_PROPERTIES" then return false end
    end
end)