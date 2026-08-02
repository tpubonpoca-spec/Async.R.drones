--[[
    Клиентский модуль управления и F6 меню FPV-дронов (zAsync)
    Файл: lua/autorun/client/cl_async_gamepad_ui.lua

    - Русский строгий военный (cyber-hacker) стиль меню по клавише F6.
    - Отрисовка FPV камеры прямо на экран оператора, стоящего на земле.
    - Динамический HUD с отображением инициализации ESC (5.4с), заряда, уровня сигнала и тепловизора.
--]]

if not CLIENT then return end

ASYNC_UI = ASYNC_UI or {}
ASYNC_UI.IsOpen = false
ASYNC_UI.SelectedIdx = 1

local DRONES = {
    {
        class = "lvs_kvn1",
        name = "KVN-1 (Камикадзе)",
        desc = "Ударный FPV-дрон с кумулятивным зарядом ПВ-1. Высокая скорость и маневренность.",
        speed = "120 км/ч",
        payload = "Кумулятивный ВУ",
        color = Color(220, 60, 60),
    },
    {
        class = "lvs_kvn2",
        name = "KVN-2 (Разведка / FLIR)",
        desc = "Оптико-электронный разведчик с тепловизионным каналом и увеличенной дальностью связи.",
        speed = "95 км/ч",
        payload = "FLIR Тепловизор",
        color = Color(0, 200, 255),
    },
    {
        class = "lvs_kvn3",
        name = "KVN-3 (Тяжёлый)",
        desc = "Усиленный квадрокоптер для транспортировки тяжёлого снаряжения и разминирования.",
        speed = "80 км/ч",
        payload = "Усиленный планер",
        color = Color(240, 190, 40),
    },
}

-- Создание шрифтов
surface.CreateFont("Async_Title", { font = "Roboto", size = 22, weight = 800 })
surface.CreateFont("Async_Header", { font = "Roboto", size = 18, weight = 700 })
surface.CreateFont("Async_Text", { font = "Roboto", size = 15, weight = 500 })
surface.CreateFont("Async_Small", { font = "Roboto", size = 13, weight = 400 })
surface.CreateFont("Async_HUD_Big", { font = "Roboto", size = 32, weight = 900 })

-- Клавиша F6 открывает / закрывает меню
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
    frame:SetSize(720, 480)
    frame:Center()
    frame:SetTitle("")
    frame:SetDraggable(true)
    frame:ShowCloseButton(false)
    frame:MakePopup()

    local COLOR_BG = Color(14, 17, 23, 250)
    local COLOR_PANEL = Color(22, 27, 36, 240)
    local COLOR_BORDER = Color(0, 220, 255, 180)
    local COLOR_ACCENT = Color(0, 255, 140, 255)
    local COLOR_TEXT = Color(230, 235, 245)
    local COLOR_MUTED = Color(130, 140, 160)

    frame.Paint = function(s, w, h)
        draw.RoundedBox(6, 0, 0, w, h, COLOR_BG)
        surface.SetDrawColor(COLOR_BORDER)
        surface.DrawOutlinedRect(0, 0, w, h, 2)

        -- Шапка меню в стиле военного терминала
        surface.SetDrawColor(28, 35, 48, 255)
        surface.DrawRect(2, 2, w - 4, 38)
        surface.SetDrawColor(COLOR_ACCENT)
        surface.DrawRect(2, 38, w - 4, 2)

        draw.SimpleText("ОПЕРАТОРСКИЙ ТЕРМИНАЛ НСУ БПЛА [F6]", "Async_Title", 16, 10, COLOR_ACCENT, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText(IsValid(activeDrone) and " СВЯЗЬ: АКТИВНА" or " СТАТУС: ОЖИДАНИЕ", "Async_Small", w - 40, 14, IsValid(activeDrone) and Color(0, 255, 120) or COLOR_MUTED, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
    end

    -- Кнопка закрытия
    local closeBtn = vgui.Create("DButton", frame)
    closeBtn:SetSize(28, 24)
    closeBtn:SetPos(720 - 34, 8)
    closeBtn:SetText("X")
    closeBtn:SetFont("Async_Header")
    closeBtn:SetTextColor(Color(255, 80, 80))
    closeBtn.Paint = function(s, w, h)
        if s:IsHovered() then
            draw.RoundedBox(4, 0, 0, w, h, Color(180, 40, 40, 200))
            s:SetTextColor(Color(255, 255, 255))
        else
            draw.RoundedBox(4, 0, 0, w, h, Color(40, 45, 55, 150))
            s:SetTextColor(Color(255, 100, 100))
        end
    end
    closeBtn.DoClick = function()
        frame:Close()
        ASYNC_UI.IsOpen = false
    end

    -- Левая панель: выбор дрона
    local scroll = vgui.Create("DScrollPanel", frame)
    scroll:SetPos(16, 54)
    scroll:SetSize(320, 408)

    for i, droneInfo in ipairs(DRONES) do
        local btn = scroll:Add("DButton")
        btn:SetSize(310, 85)
        btn:Dock(TOP)
        btn:DockMargin(0, 0, 0, 10)
        btn:SetText("")

        btn.Paint = function(s, w, h)
            local isSel = (ASYNC_UI.SelectedIdx == i)
            local bgCol = isSel and Color(30, 42, 58, 250) or COLOR_PANEL
            draw.RoundedBox(4, 0, 0, w, h, bgCol)

            local borderCol = isSel and droneInfo.color or Color(50, 60, 75)
            surface.SetDrawColor(borderCol)
            surface.DrawOutlinedRect(0, 0, w, h, isSel and 2 or 1)

            surface.SetDrawColor(droneInfo.color)
            surface.DrawRect(4, 8, 4, h - 16)

            draw.SimpleText(droneInfo.name, "Async_Header", 18, 10, COLOR_TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            draw.SimpleText("Скорость: " .. droneInfo.speed .. " | " .. droneInfo.payload, "Async_Small", 18, 34, COLOR_MUTED, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        end

        btn.DoClick = function()
            ASYNC_UI.SelectedIdx = i
        end
    end

    -- Правая панель: подробная спецификация и кнопки действий
    local rightPanel = vgui.Create("DPanel", frame)
    rightPanel:SetPos(352, 54)
    rightPanel:SetSize(352, 408)
    rightPanel.Paint = function(s, w, h)
        draw.RoundedBox(4, 0, 0, w, h, COLOR_PANEL)
        surface.SetDrawColor(COLOR_BORDER)
        surface.DrawOutlinedRect(0, 0, w, h, 1)

        local info = DRONES[ASYNC_UI.SelectedIdx]
        if not info then return end

        draw.SimpleText(info.name:upper(), "Async_Header", 16, 16, info.color, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

        -- Описание
        local words = string.Explode(" ", info.desc)
        local line1, line2 = "", ""
        for _, word in ipairs(words) do
            if #line1 < 32 then
                line1 = line1 .. word .. " "
            else
                line2 = line2 .. word .. " "
            end
        end

        draw.SimpleText(line1, "Async_Text", 16, 48, COLOR_TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText(line2, "Async_Text", 16, 68, COLOR_TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

        surface.SetDrawColor(40, 50, 65)
        surface.DrawLine(16, 100, w - 16, 100)

        draw.SimpleText("ТАКТИКО-ТЕХНИЧЕСКИЕ ХАРАКТЕРИСТИКИ:", "Async_Small", 16, 112, COLOR_MUTED, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText("• МАКС. СКОРОСТЬ: " .. info.speed, "Async_Text", 16, 134, COLOR_TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText("•ПОЛЕЗНАЯ НАГРУЗКА: " .. info.payload, "Async_Text", 16, 156, COLOR_TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText("• КАНАЛ СВЯЗИ: НСУ-433 (Кварц)", "Async_Text", 16, 178, COLOR_TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText("• ВРЕМЯ ИНИЦИАЛИЗАЦИИ: 5.4 СЕК", "Async_Text", 16, 200, COLOR_TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end

    -- Кнопка ЗАПУСК / ЗАМЕНА
    local spawnBtn = vgui.Create("DButton", rightPanel)
    spawnBtn:SetSize(320, 48)
    spawnBtn:SetPos(16, 280)
    spawnBtn:SetFont("Async_Header")
    spawnBtn:SetText("ЗАПУСТИТЬ FPV ДРОН")
    spawnBtn:SetTextColor(Color(255, 255, 255))
    spawnBtn.Paint = function(s, w, h)
        local bgCol = s:IsHovered() and Color(0, 200, 100) or Color(0, 160, 80)
        draw.RoundedBox(4, 0, 0, w, h, bgCol)
        surface.SetDrawColor(0, 255, 140)
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

    -- Кнопка ОТКЛЮЧИТЬ СВЯЗЬ
    local disconnectBtn = vgui.Create("DButton", rightPanel)
    disconnectBtn:SetSize(320, 36)
    disconnectBtn:SetPos(16, 340)
    disconnectBtn:SetFont("Async_Text")
    disconnectBtn:SetText("ОТКЛЮЧИТЬ АКТИВНЫЙ ДРОН [R]")
    disconnectBtn:SetTextColor(Color(255, 180, 180))
    disconnectBtn.Paint = function(s, w, h)
        local bgCol = s:IsHovered() and Color(160, 40, 40) or Color(80, 30, 30)
        draw.RoundedBox(4, 0, 0, w, h, bgCol)
        surface.SetDrawColor(255, 80, 80)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end
    disconnectBtn.DoClick = function()
        net.Start("Async_DisconnectDrone")
        net.SendToServer()
        frame:Close()
        ASYNC_UI.IsOpen = false
    end
end

-- Перехват CalcView для показа FPV камеры оператору, стоящему на земле
hook.Add("CalcView", "Async_FPVOperatorView", function(ply, pos, angles, fov)
    if not IsValid(ply) or not ply:Alive() then return end

    local activeDrone = ply:GetNWEntity("KVN_ActiveDrone")
    if not IsValid(activeDrone) then return end

    -- Позиция камеры на дроне
    local camPos = activeDrone:LocalToWorld(Vector(12, 0, 3))
    local camAng = activeDrone:GetAngles()

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
        drawviewer = false,
    }
end)

-- Клавиша R отключает связь с дроном
hook.Add("PlayerButtonDown", "Async_RKeyDisconnect", function(ply, button)
    if button == KEY_R and not vgui.CursorVisible() then
        local activeDrone = ply:GetNWEntity("KVN_ActiveDrone")
        if IsValid(activeDrone) then
            net.Start("Async_DisconnectDrone")
            net.SendToServer()
        end
    end
end)

-- Отрисовка FPV HUD во время управления дроном
hook.Add("HUDPaint", "Async_FPVOperatorHUD", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local activeDrone = ply:GetNWEntity("KVN_ActiveDrone")
    if not IsValid(activeDrone) then return end

    local w, h = ScrW(), ScrH()
    local ct = CurTime()

    local lockUntil = activeDrone:GetNWFloat("Async_ControlLockTime", 0)
    local isLocked = ct < lockUntil

    -- 1. Экраны блокировки во время стартовой звуковой последовательности (5.4 секунды)
    if isLocked then
        local remTime = math.Round(lockUntil - ct, 1)

        -- Полупрозрачная черная сетка инициализации
        surface.SetDrawColor(0, 0, 0, 180)
        surface.DrawRect(0, 0, w, h)

        surface.SetDrawColor(0, 220, 255, 255)
        surface.DrawOutlinedRect(w * 0.2, h * 0.3, w * 0.6, h * 0.4, 2)

        draw.SimpleText("ИНИЦИАЛИЗАЦИЯ ESC И СИСТЕМЫ ПИТАНИЯ", "Async_Title", w * 0.5, h * 0.35, Color(0, 255, 140), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("БЛОКИРОВКА УПРАВЛЕНИЯ: " .. string.format("%.1f", remTime) .. " СЕК", "Async_HUD_Big", w * 0.5, h * 0.46, Color(255, 200, 40), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("Воспроизведение стартового звукового сигнала BLHeli...", "Async_Text", w * 0.5, h * 0.58, Color(180, 190, 210), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    else
        -- Прицел FPV
        surface.SetDrawColor(0, 255, 120, 200)
        surface.DrawOutlinedRect(w * 0.5 - 15, h * 0.5 - 15, 30, 30, 1)
        surface.DrawLine(w * 0.5 - 5, h * 0.5, w * 0.5 + 5, h * 0.5)
        surface.DrawLine(w * 0.5, h * 0.5 - 5, w * 0.5, h * 0.5 + 5)
    end

    -- Информационные плашки FPV
    surface.SetDrawColor(15, 20, 28, 200)
    surface.DrawRect(20, 20, 280, 80)
    surface.SetDrawColor(0, 200, 255, 255)
    surface.DrawOutlinedRect(20, 20, 280, 80, 1)

    draw.SimpleText("КАНАЛ: FPV_LIVE (" .. activeDrone:GetClass():upper() .. ")", "Async_Small", 30, 28, Color(0, 220, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    draw.SimpleText("СИГНАЛ: 100% | ОПЕРАТОР НА ЗЕМЛЕ", "Async_Text", 30, 48, Color(0, 255, 140), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    draw.SimpleText("[R] — Отключиться | [F6] — Меню", "Async_Small", 30, 72, Color(200, 200, 200), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
end)
