--[[
    Минималистичный терминал BIOS / BSOD для FPV-дронов (zAsync)
    Файл: lua/autorun/client/cl_async_gamepad_ui.lua

    - Строгий терминальный стиль BIOS / BSOD по клавише F6.
    - Блокировка ввода во время стартовой звуковой последовательности (5.4с).
    - Очищенный минималистичный HUD без лишних элементов.
--]]

if not CLIENT then return end

ASYNC_UI = ASYNC_UI or {}
ASYNC_UI.IsOpen = false
ASYNC_UI.SelectedIdx = 1

local DRONES = {
    {
        class = "lvs_kvn1",
        name = "1. KVN-1 KAMIKAZE",
        desc = "STRIKE FPV UNIT / HIGH SPEED / PV-1 CHARGE",
        speed = "120 KM/H",
        payload = "PV-1 DEMOLITION",
        color = Color(220, 60, 60),
    },
    {
        class = "lvs_kvn2",
        name = "2. KVN-2 RECONNAISSANCE",
        desc = "RECON FPV UNIT / THERMAL OPTICS / LONG RANGE",
        speed = "95 KM/H",
        payload = "FLIR OPTICS",
        color = Color(0, 200, 255),
    },
    {
        class = "lvs_kvn3",
        name = "3. KVN-3 HEAVY TACTICAL",
        desc = "HEAVY FPV UNIT / ENFORCED FRAME / CARGO",
        speed = "80 KM/H",
        payload = "HEAVY FRAME",
        color = Color(240, 180, 0),
    },
}

-- BIOS / BSOD Палитра
local BIOS_BG = Color(0, 0, 128, 245)      -- Классический синий BIOS / BSOD
local BIOS_PANEL = Color(0, 0, 96, 250)
local BIOS_BORDER = Color(255, 255, 255, 255)
local BIOS_WHITE = Color(255, 255, 255, 255)
local BIOS_YELLOW = Color(255, 255, 0, 255)
local BIOS_CYAN = Color(0, 255, 255, 255)
local BIOS_MUTED = Color(180, 190, 210, 255)

surface.CreateFont("BIOS_Font", { font = "Courier New", size = 16, weight = 700 })
surface.CreateFont("BIOS_Header", { font = "Courier New", size = 18, weight = 800 })
surface.CreateFont("BIOS_Timer", { font = "Courier New", size = 26, weight = 900 })

hook.Add("PlayerButtonDown", "Async_F6MenuToggle", function(ply, button)
    if button == KEY_F6 then
        ASYNC_UI.ToggleMenu()
    end
end)

function ASYNC_UI.ToggleMenu()
    ASYNC_UI.IsOpen = not ASYNC_UI.IsOpen
    if ASYNC_UI.IsOpen then
        ASYNC_UI.OpenMenu()
    else
        if IsValid(ASYNC_UI.Frame) then
            ASYNC_UI.Frame:Close()
        end
    end
end

function ASYNC_UI.OpenMenu()
    if IsValid(ASYNC_UI.Frame) then ASYNC_UI.Frame:Remove() end

    local frame = vgui.Create("DFrame")
    ASYNC_UI.Frame = frame
    frame:SetSize(680, 440)
    frame:Center()
    frame:SetTitle("")
    frame:SetDraggable(true)
    frame:ShowCloseButton(false)
    frame:MakePopup()

    frame.Paint = function(s, w, h)
        draw.RoundedBox(0, 0, 0, w, h, BIOS_BG)
        surface.SetDrawColor(BIOS_BORDER)
        surface.DrawOutlinedRect(0, 0, w, h, 2)

        surface.SetDrawColor(BIOS_BORDER)
        surface.DrawRect(2, 2, w - 4, 30)

        draw.SimpleText("[ SYSTEM BIOS v1.04 — FPV TERMINAL ]", "BIOS_Header", 10, 6, BIOS_BG, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText("[F6]", "BIOS_Header", w - 40, 6, BIOS_BG, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end

    local closeBtn = vgui.Create("DButton", frame)
    closeBtn:SetSize(24, 20)
    closeBtn:SetPos(680 - 28, 5)
    closeBtn:SetText("X")
    closeBtn:SetFont("BIOS_Header")
    closeBtn:SetTextColor(Color(255, 80, 80))
    closeBtn.Paint = function(s, w, h)
        if s:IsHovered() then
            draw.RoundedBox(0, 0, 0, w, h, Color(200, 0, 0))
            s:SetTextColor(BIOS_WHITE)
        else
            draw.RoundedBox(0, 0, 0, w, h, BIOS_BG)
        end
    end
    closeBtn.DoClick = function()
        frame:Close()
        ASYNC_UI.IsOpen = false
    end

    local scroll = vgui.Create("DScrollPanel", frame)
    scroll:SetPos(12, 42)
    scroll:SetSize(310, 380)

    for i, droneInfo in ipairs(DRONES) do
        local btn = scroll:Add("DButton")
        btn:SetSize(300, 75)
        btn:Dock(TOP)
        btn:DockMargin(0, 0, 0, 8)
        btn:SetText("")

        btn.Paint = function(s, w, h)
            local isSel = (ASYNC_UI.SelectedIdx == i)
            local bgCol = isSel and Color(0, 0, 200) or BIOS_PANEL
            draw.RoundedBox(0, 0, 0, w, h, bgCol)

            surface.SetDrawColor(isSel and BIOS_YELLOW or BIOS_BORDER)
            surface.DrawOutlinedRect(0, 0, w, h, isSel and 2 or 1)

            draw.SimpleText(droneInfo.name, "BIOS_Font", 12, 10, isSel and BIOS_YELLOW or BIOS_WHITE, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            draw.SimpleText("SPEED: " .. droneInfo.speed, "BIOS_Font", 12, 30, BIOS_CYAN, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            draw.SimpleText("LOAD:  " .. droneInfo.payload, "BIOS_Font", 12, 48, BIOS_MUTED, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        end

        btn.DoClick = function()
            ASYNC_UI.SelectedIdx = i
        end
    end

    local rightPanel = vgui.Create("DPanel", frame)
    rightPanel:SetPos(334, 42)
    rightPanel:SetSize(334, 380)
    rightPanel.Paint = function(s, w, h)
        draw.RoundedBox(0, 0, 0, w, h, BIOS_PANEL)
        surface.SetDrawColor(BIOS_BORDER)
        surface.DrawOutlinedRect(0, 0, w, h, 1)

        local info = DRONES[ASYNC_UI.SelectedIdx]
        if not info then return end

        draw.SimpleText("+--- SPECIFICATION ---+", "BIOS_Header", 10, 10, BIOS_YELLOW, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText("UNIT: " .. info.name, "BIOS_Font", 10, 36, BIOS_WHITE, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText(info.desc, "BIOS_Font", 10, 58, BIOS_MUTED, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

        surface.SetDrawColor(BIOS_BORDER)
        surface.DrawLine(10, 110, w - 10, 110)

        draw.SimpleText("SYSTEM POST CHECK:", "BIOS_Font", 10, 122, BIOS_CYAN, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText("• MAX SPEED: " .. info.speed, "BIOS_Font", 10, 144, BIOS_WHITE, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText("• PAYLOAD:   " .. info.payload, "BIOS_Font", 10, 166, BIOS_WHITE, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText("• ESC POST:  5.4 SECONDS", "BIOS_Font", 10, 188, BIOS_YELLOW, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end

    local spawnBtn = vgui.Create("DButton", rightPanel)
    spawnBtn:SetSize(314, 40)
    spawnBtn:SetPos(10, 260)
    spawnBtn:SetFont("BIOS_Header")
    spawnBtn:SetText("[ LAUNCH DRONE ]")
    spawnBtn:SetTextColor(BIOS_WHITE)
    spawnBtn.Paint = function(s, w, h)
        local bgCol = s:IsHovered() and Color(0, 160, 0) or Color(0, 100, 0)
        draw.RoundedBox(0, 0, 0, w, h, bgCol)
        surface.SetDrawColor(BIOS_BORDER)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end
    spawnBtn.DoClick = function()
        local info = DRONES[ASYNC_UI.SelectedIdx]
        if info then
            net.Start("Async_SpawnDrone")
                net.WriteString(info.class)
            net.SendToServer()
        end
        frame:Close()
        ASYNC_UI.IsOpen = false
    end

    local disconnectBtn = vgui.Create("DButton", rightPanel)
    disconnectBtn:SetSize(314, 34)
    disconnectBtn:SetPos(10, 312)
    disconnectBtn:SetFont("BIOS_Font")
    disconnectBtn:SetText("[ DISCONNECT / EXIT ]")
    disconnectBtn:SetTextColor(Color(255, 180, 180))
    disconnectBtn.Paint = function(s, w, h)
        local bgCol = s:IsHovered() and Color(160, 0, 0) or Color(100, 0, 0)
        draw.RoundedBox(0, 0, 0, w, h, bgCol)
        surface.SetDrawColor(BIOS_BORDER)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end
    disconnectBtn.DoClick = function()
        net.Start("Async_DisconnectDrone")
        net.SendToServer()
        frame:Close()
        ASYNC_UI.IsOpen = false
    end
end

-- Блокировка ввода во время 5.4-секундной стартовой звуковой последовательности
hook.Add("CreateMove", "Async_BIOS_BlockInputsDuringBoot", function(cmd)
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local veh = ply:GetVehicle()
    if not IsValid(veh) then return end

    local base = veh.LVSBaseEnt or veh:GetParent()
    if not IsValid(base) then return end

    local lockUntil = base:GetNWFloat("Async_ControlLockTime", 0)
    if CurTime() < lockUntil then
        cmd:ClearButtons()
        cmd:ClearMovement()
    end
end)

-- Минималистичный BIOS HUD
hook.Add("HUDPaint", "Async_FPV_BIOS_HUD", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local veh = ply:GetVehicle()
    if not IsValid(veh) then return end

    local base = veh.LVSBaseEnt or veh:GetParent()
    if not IsValid(base) then return end

    local w, h = ScrW(), ScrH()
    local ct = CurTime()

    local lockUntil = base:GetNWFloat("Async_ControlLockTime", 0)
    local isLocked = ct < lockUntil

    if isLocked then
        local remTime = math.Round(lockUntil - ct, 1)

        surface.SetDrawColor(0, 0, 128, 230)
        surface.DrawRect(w * 0.2, h * 0.3, w * 0.6, h * 0.4)
        surface.SetDrawColor(BIOS_BORDER)
        surface.DrawOutlinedRect(w * 0.2, h * 0.3, w * 0.6, h * 0.4, 2)

        draw.SimpleText("BIOS POST INITIALIZATION", "BIOS_Header", w * 0.5, h * 0.35, BIOS_YELLOW, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("BLHeli ESC TESTING...", "BIOS_Font", w * 0.5, h * 0.43, BIOS_CYAN, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("LOCKOUT: " .. string.format("%.1f", remTime) .. "S", "BIOS_Timer", w * 0.5, h * 0.53, BIOS_WHITE, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    else
        -- Прицел
        surface.SetDrawColor(0, 255, 0, 200)
        surface.DrawOutlinedRect(w * 0.5 - 10, h * 0.5 - 10, 20, 20, 1)
        surface.DrawLine(w * 0.5 - 4, h * 0.5, w * 0.5 + 4, h * 0.5)
        surface.DrawLine(w * 0.5, h * 0.5 - 4, w * 0.5, h * 0.5 + 4)
    end

    -- Статусная строка BIOS
    surface.SetDrawColor(0, 0, 96, 220)
    surface.DrawRect(10, 10, 280, 40)
    surface.SetDrawColor(BIOS_BORDER)
    surface.DrawOutlinedRect(10, 10, 280, 40, 1)

    draw.SimpleText("FPV LINK | " .. base:GetClass():upper(), "BIOS_Font", 18, 14, BIOS_YELLOW, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    draw.SimpleText("PRESS [E] TO EXIT", "BIOS_Font", 18, 30, BIOS_WHITE, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
end)
