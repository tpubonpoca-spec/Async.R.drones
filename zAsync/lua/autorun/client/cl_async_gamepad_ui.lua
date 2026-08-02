--[[
    Интерфейс ОС ЗАРЯ v3.12 (Минобороны РФ / АО ОПК)
    Файл: lua/autorun/client/cl_async_gamepad_ui.lua

    - Русский военный интерфейс ОС Заря по клавише F6.
    - Перехват CalcView для показа FPV камеры оператору, находящемуся в своём теле на земле.
    - Клавиша E — экстренное отключение связи с дроном.
    - Полноэкранный экран самодиагностики BLHeli (5.4с) с физической блокировкой управления.
--]]

if not CLIENT then return end

ASYNC_UI = ASYNC_UI or {}
ASYNC_UI.IsOpen = false
ASYNC_UI.SelectedIdx = 1

local DRONES = {
    {
        class = "lvs_kvn1",
        name = "КВН-1 (Камикадзе)",
        desc = "Ударный FPV-дрон с кумулятивным боеприпасом ПВ-1. Высокая скорость и маневренность.",
        speed = "120 км/ч",
        payload = "ПВ-1 Кумулятив",
        color = Color(240, 60, 60),
    },
    {
        class = "lvs_kvn2",
        name = "КВН-2 (Разведка / FLIR)",
        desc = "Оптико-электронный комплекс разведки с тепловизионным каналом и увеличенной дальностью.",
        speed = "95 км/ч",
        payload = "FLIR Тепловизор",
        color = Color(0, 220, 255),
    },
    {
        class = "lvs_kvn3",
        name = "КВН-3 (Тяжёлый)",
        desc = "Тяжёлый квадрокоптер с усиленной рамой для транспортировки целевой нагрузки.",
        speed = "80 км/ч",
        payload = "Усиленная рама",
        color = Color(255, 180, 0),
    },
}

-- Цветовая палитра ОС ЗАРЯ
local ZARYA_BG = Color(24, 28, 34, 250)
local ZARYA_TITLE = Color(36, 44, 54, 255)
local ZARYA_PANEL = Color(30, 36, 46, 245)
local ZARYA_BORDER = Color(56, 70, 90, 255)
local ZARYA_GREEN = Color(0, 230, 118)
local ZARYA_CYAN = Color(0, 220, 255)
local ZARYA_AMBER = Color(255, 171, 0)
local ZARYA_TEXT = Color(240, 245, 250)
local ZARYA_MUTED = Color(140, 150, 165)

surface.CreateFont("Zarya_Title", { font = "DejaVu Sans Mono", size = 18, weight = 800 })
surface.CreateFont("Zarya_Header", { font = "DejaVu Sans Mono", size = 16, weight = 700 })
surface.CreateFont("Zarya_Text", { font = "DejaVu Sans Mono", size = 14, weight = 500 })
surface.CreateFont("Zarya_Small", { font = "DejaVu Sans Mono", size = 12, weight = 400 })
surface.CreateFont("Zarya_BigTimer", { font = "DejaVu Sans Mono", size = 28, weight = 900 })

-- Клавиша F6 переключает окно ОС ЗАРЯ
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

    local ply = LocalPlayer()
    local activeDrone = ply:GetNWEntity("KVN_ActiveDrone")

    local frame = vgui.Create("DFrame")
    ASYNC_UI.Frame = frame
    frame:SetSize(740, 490)
    frame:Center()
    frame:SetTitle("")
    frame:SetDraggable(true)
    frame:ShowCloseButton(false)
    frame:MakePopup()

    frame.Paint = function(s, w, h)
        draw.RoundedBox(0, 0, 0, w, h, ZARYA_BG)
        surface.SetDrawColor(ZARYA_BORDER)
        surface.DrawOutlinedRect(0, 0, w, h, 2)

        surface.SetDrawColor(ZARYA_TITLE)
        surface.DrawRect(2, 2, w - 4, 34)
        surface.SetDrawColor(ZARYA_GREEN)
        surface.DrawRect(2, 34, w - 4, 2)

        draw.SimpleText("ОС ЗАРЯ v3.12 | МИНОБОРОНЫ РФ | АО ОПК", "Zarya_Title", 12, 8, ZARYA_GREEN, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText("ТЕРМИНАЛ НСУ-433 [F6]", "Zarya_Small", w - 45, 10, ZARYA_CYAN, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
    end

    local closeBtn = vgui.Create("DButton", frame)
    closeBtn:SetSize(28, 22)
    closeBtn:SetPos(740 - 32, 6)
    closeBtn:SetText("X")
    closeBtn:SetFont("Zarya_Header")
    closeBtn:SetTextColor(Color(255, 100, 100))
    closeBtn.Paint = function(s, w, h)
        if s:IsHovered() then
            draw.RoundedBox(0, 0, 0, w, h, Color(180, 40, 40))
            s:SetTextColor(Color(255, 255, 255))
        else
            draw.RoundedBox(0, 0, 0, w, h, Color(45, 55, 70))
        end
    end
    closeBtn.DoClick = function()
        frame:Close()
        ASYNC_UI.IsOpen = false
    end

    local scroll = vgui.Create("DScrollPanel", frame)
    scroll:SetPos(14, 48)
    scroll:SetSize(330, 426)

    for i, droneInfo in ipairs(DRONES) do
        local btn = scroll:Add("DButton")
        btn:SetSize(320, 85)
        btn:Dock(TOP)
        btn:DockMargin(0, 0, 0, 8)
        btn:SetText("")

        btn.Paint = function(s, w, h)
            local isSel = (ASYNC_UI.SelectedIdx == i)
            local bgCol = isSel and Color(36, 46, 60) or ZARYA_PANEL
            draw.RoundedBox(0, 0, 0, w, h, bgCol)

            local borderCol = isSel and droneInfo.color or ZARYA_BORDER
            surface.SetDrawColor(borderCol)
            surface.DrawOutlinedRect(0, 0, w, h, isSel and 2 or 1)

            surface.SetDrawColor(droneInfo.color)
            surface.DrawRect(4, 6, 4, h - 12)

            draw.SimpleText(droneInfo.name, "Zarya_Header", 16, 10, ZARYA_TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            draw.SimpleText("Скорость: " .. droneInfo.speed, "Zarya_Small", 16, 32, ZARYA_CYAN, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            draw.SimpleText("Нагрузка: " .. droneInfo.payload, "Zarya_Small", 16, 50, ZARYA_MUTED, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        end

        btn.DoClick = function()
            ASYNC_UI.SelectedIdx = i
        end
    end

    local rightPanel = vgui.Create("DPanel", frame)
    rightPanel:SetPos(356, 48)
    rightPanel:SetSize(370, 426)
    rightPanel.Paint = function(s, w, h)
        draw.RoundedBox(0, 0, 0, w, h, ZARYA_PANEL)
        surface.SetDrawColor(ZARYA_BORDER)
        surface.DrawOutlinedRect(0, 0, w, h, 1)

        local info = DRONES[ASYNC_UI.SelectedIdx]
        if not info then return end

        draw.SimpleText("=== СПЕЦИФИКАЦИЯ БПЛА ===", "Zarya_Header", 14, 14, info.color, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText("НАИМЕНОВАНИЕ: " .. info.name, "Zarya_Text", 14, 42, ZARYA_TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText("ТАКТИЧЕСКОЕ НАЗНАЧЕНИЕ:", "Zarya_Small", 14, 66, ZARYA_MUTED, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText(info.desc, "Zarya_Small", 14, 84, ZARYA_TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

        surface.SetDrawColor(ZARYA_BORDER)
        surface.DrawLine(14, 130, w - 14, 130)

        draw.SimpleText("ПАРАМЕТРЫ СИСТЕМЫ:", "Zarya_Header", 14, 142, ZARYA_CYAN, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText("• МАКСИМАЛЬНАЯ СКОРОСТЬ: " .. info.speed, "Zarya_Text", 14, 166, ZARYA_TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText("• ПОЛЕЗНАЯ НАГРУЗКА:     " .. info.payload, "Zarya_Text", 14, 188, ZARYA_TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText("• ПОЛЁТНЫЙ КОНТРОЛЛЕР:   BLHeli ESC (5.4с)", "Zarya_Text", 14, 210, ZARYA_AMBER, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText("• БЕЗОПАСНОСТЬ ОПЕРАТОРА: НАСТОЯЩИЙ ИГРОК НА ЗЕМЛЕ", "Zarya_Text", 14, 232, ZARYA_GREEN, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end

    local spawnBtn = vgui.Create("DButton", rightPanel)
    spawnBtn:SetSize(342, 44)
    spawnBtn:SetPos(14, 300)
    spawnBtn:SetFont("Zarya_Header")
    spawnBtn:SetText("[ ИНИЦИАЛИЗИРОВАТЬ И ЗАПУСТИТЬ ]")
    spawnBtn:SetTextColor(ZARYA_TEXT)
    spawnBtn.Paint = function(s, w, h)
        local bgCol = s:IsHovered() and Color(0, 180, 90) or Color(0, 130, 65)
        draw.RoundedBox(0, 0, 0, w, h, bgCol)
        surface.SetDrawColor(ZARYA_GREEN)
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
    disconnectBtn:SetSize(342, 36)
    disconnectBtn:SetPos(14, 356)
    disconnectBtn:SetFont("Zarya_Text")
    disconnectBtn:SetText("[ E ] ОТКЛЮЧИТЬ КАНАЛ СВЯЗИ")
    disconnectBtn:SetTextColor(Color(255, 180, 180))
    disconnectBtn.Paint = function(s, w, h)
        local bgCol = s:IsHovered() and Color(160, 40, 40) or Color(90, 30, 30)
        draw.RoundedBox(0, 0, 0, w, h, bgCol)
        surface.SetDrawColor(Color(255, 80, 80))
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end
    disconnectBtn.DoClick = function()
        net.Start("Async_DisconnectDrone")
        net.SendToServer()
        frame:Close()
        ASYNC_UI.IsOpen = false
    end
end

-- Перехват CalcView для показа FPV камеры настоящему игроку на земле
hook.Add("CalcView", "Async_FPVOperatorView", function(ply, pos, angles, fov)
    if not IsValid(ply) or not ply:Alive() then return end

    local activeDrone = ply:GetNWEntity("KVN_ActiveDrone")
    if not IsValid(activeDrone) then return end

    local camPos = activeDrone:LocalToWorld(Vector(12, 0, 3))
    local camAng = ply:EyeAngles()

    local camAtt = activeDrone:LookupAttachment("camera")
    if camAtt and camAtt > 0 then
        local att = activeDrone:GetAttachment(camAtt)
        if att and att.Pos and att.Pos ~= vector_origin then
            camPos = att.Pos
        end
    end

    return {
        origin = camPos,
        angles = camAng,
        fov = 85,
        drawviewer = true,
    }
end)

-- Клавиша E отключает связь с дроном
hook.Add("PlayerButtonDown", "Async_EKeyDisconnect", function(ply, button)
    if button == KEY_E and not vgui.CursorVisible() then
        local activeDrone = ply:GetNWEntity("KVN_ActiveDrone")
        if IsValid(activeDrone) then
            net.Start("Async_DisconnectDrone")
            net.SendToServer()
        end
    end
end)

-- Отрисовка FPV HUD в стиле ОС ЗАРЯ v3.12
hook.Add("HUDPaint", "Async_FPVOperatorHUD", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local activeDrone = ply:GetNWEntity("KVN_ActiveDrone")
    if not IsValid(activeDrone) then return end

    local w, h = ScrW(), ScrH()
    local ct = CurTime()

    local lockUntil = activeDrone:GetNWFloat("Async_ControlLockTime", 0)
    local isLocked = ct < lockUntil

    if isLocked then
        local remTime = math.Round(lockUntil - ct, 1)

        surface.SetDrawColor(18, 22, 28, 235)
        surface.DrawRect(w * 0.15, h * 0.25, w * 0.7, h * 0.5)

        surface.SetDrawColor(ZARYA_BORDER)
        surface.DrawOutlinedRect(w * 0.15, h * 0.25, w * 0.7, h * 0.5, 2)

        surface.SetDrawColor(ZARYA_TITLE)
        surface.DrawRect(w * 0.15 + 2, h * 0.25 + 2, w * 0.7 - 4, 32)
        draw.SimpleText("ОС ЗАРЯ v3.12 — СИСТЕМА САМОДИАГНОСТИКИ И ЗАПУСКА", "Zarya_Header", w * 0.17, h * 0.265, ZARYA_GREEN, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

        draw.SimpleText("[+] ПОЛЁТНЫЙ КОНТРОЛЛЕР: BLHeli ESC INITIALIZING...", "Zarya_Text", w * 0.18, h * 0.35, ZARYA_CYAN, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText("[+] КАНАЛ СВЯЗИ: НСУ-433 (КВАРЦ) — ПОДКЛЮЧЕНО", "Zarya_Text", w * 0.18, h * 0.39, ZARYA_GREEN, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText("[!] ВЫ ФИЗИЧЕСКИ НАХОДИТЕСЬ НА ЗЕМЛЕ И УЯЗВИМЫ ДЛЯ УРОНА", "Zarya_Text", w * 0.18, h * 0.43, ZARYA_AMBER, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

        draw.SimpleText("БЛОКИРОВКА УПРАВЛЕНИЯ: " .. string.format("%.1f", remTime) .. " СЕК", "Zarya_BigTimer", w * 0.5, h * 0.54, ZARYA_AMBER, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("Воспроизведение последовательности звуковых сигналов BLHeli...", "Zarya_Small", w * 0.5, h * 0.65, ZARYA_MUTED, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    else
        surface.SetDrawColor(0, 230, 118, 200)
        surface.DrawOutlinedRect(w * 0.5 - 12, h * 0.5 - 12, 24, 24, 1)
        surface.DrawLine(w * 0.5 - 4, h * 0.5, w * 0.5 + 4, h * 0.5)
        surface.DrawLine(w * 0.5, h * 0.5 - 4, w * 0.5, h * 0.5 + 4)
    end

    surface.SetDrawColor(20, 25, 32, 220)
    surface.DrawRect(16, 16, 320, 75)
    surface.SetDrawColor(ZARYA_BORDER)
    surface.DrawOutlinedRect(16, 16, 320, 75, 1)

    draw.SimpleText("ОС ЗАРЯ v3.12 | " .. activeDrone:GetClass():upper(), "Zarya_Header", 26, 24, ZARYA_GREEN, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    draw.SimpleText("СВЯЗЬ: 100% | НАСТОЯЩИЙ ИГРОК НА ЗЕМЛЕ", "Zarya_Small", 26, 44, ZARYA_CYAN, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    draw.SimpleText("[E] — Отключить канал | [F6] — Терминал", "Zarya_Small", 26, 62, ZARYA_MUTED, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
end)
