--[[
    Клиентский интерфейс выбора и управления дронами (Async Gamepad)
    Файл: lua/autorun/client/cl_async_gamepad_ui.lua

    Рисует экран выбора дрона поверх HUD и обрабатывает
    обратную связь от сервера о состоянии запущенного дрона.
--]]

if not CLIENT then return end

-- Состояния интерфейса
local ASYNC_UI = ASYNC_UI or {}
ASYNC_UI.IsOpen = false
ASYNC_UI.SelectedIndex = 1
ASYNC_UI.ActiveDrone = nil
ASYNC_UI.StatusText = ""
ASYNC_UI.StatusTime = 0

-- Шрифты
if not ASYNC_UI.FontsCreated then
    surface.CreateFont("AsyncGP_Title", {
        font      = "Roboto",
        size      = 32,
        weight    = 700,
        antialias = true,
        extended  = true,
    })
    surface.CreateFont("AsyncGP_Button", {
        font      = "Roboto",
        size      = 24,
        weight    = 600,
        antialias = true,
        extended  = true,
    })
    surface.CreateFont("AsyncGP_Desc", {
        font      = "Roboto",
        size      = 18,
        weight    = 400,
        antialias = true,
        extended  = true,
    })
    surface.CreateFont("AsyncGP_Status", {
        font      = "Roboto",
        size      = 20,
        weight    = 500,
        antialias = true,
        extended  = true,
    })
    ASYNC_UI.FontsCreated = true
end

-- Данные дронов
local DRONE_LIST = {
    {
        class  = "lvs_kvn1",
        name   = "KVN-1",
        desc   = "Лёгкий ударный дрон-камикадзе.\nОптоволокно, 300г ВВ, HEAT-заряд.",
        hp     = 100,
        speed  = "~90 км/ч",
        time   = "~3 мин",
        color  = Color(220, 60, 60),
    },
    {
        class  = "lvs_kvn2",
        name   = "KVN-2",
        desc   = "Разведывательный дрон с тепловизором.\nFLIR-камера, оптоволокно.",
        hp     = 100,
        speed  = "~90 км/ч",
        time   = "~3 мин",
        color  = Color(60, 180, 220),
    },
    {
        class  = "lvs_kvn3",
        name   = "KVN-3",
        desc   = "Тяжёлый ударный дрон.\nУсиленный заряд, фрагментация.",
        hp     = 100,
        speed  = "~80 км/ч",
        time   = "~3 мин",
        color  = Color(220, 180, 40),
    },
}

-- Цвета UI
local CLR_BG       = Color(15, 15, 20, 230)
local CLR_CARD     = Color(30, 32, 38, 255)
local CLR_CARD_SEL = Color(45, 48, 58, 255)
local CLR_BORDER   = Color(70, 75, 90, 200)
local CLR_WHITE    = Color(230, 230, 235)
local CLR_GRAY     = Color(140, 145, 160)
local CLR_GREEN    = Color(80, 220, 120)
local CLR_RED      = Color(220, 70, 70)
local CLR_BTN      = Color(50, 140, 80, 255)
local CLR_BTN_HOV  = Color(60, 170, 95, 255)

-- Статусная строка (временное сообщение внизу)
local function ShowStatus(text, duration)
    ASYNC_UI.StatusText = text
    ASYNC_UI.StatusTime = CurTime() + (duration or 3)
end

-- Обратная связь от сервера
net.Receive("Async_DroneStatus", function()
    local code = net.ReadUInt(2)
    if code == 1 then
        -- Дрон запущен, закрываем меню
        ASYNC_UI.ActiveDrone = net.ReadEntity()
        ASYNC_UI.IsOpen = false
        gui.EnableScreenClicker(false)
        ShowStatus("Дрон активен. Управление передано.", 4)
    elseif code == 0 then
        -- Дрон уничтожен
        ASYNC_UI.ActiveDrone = nil
        ShowStatus("Связь потеряна.", 4)
    end
end)

-- Открытие/закрытие меню по клавише (F6)
hook.Add("PlayerButtonDown", "Async_Gamepad_ToggleUI", function(ply, button)
    if button ~= KEY_F6 then return end
    if not IsValid(ply) then return end

    -- Если игрок управляет дроном — не открывать
    if IsValid(ply:GetVehicle()) then return end

    ASYNC_UI.IsOpen = not ASYNC_UI.IsOpen
    gui.EnableScreenClicker(ASYNC_UI.IsOpen)
end)

-- Запрос спавна дрона
local function RequestSpawnDrone(droneClass)
    net.Start("Async_SpawnDrone")
        net.WriteString(droneClass)
    net.SendToServer()
    ShowStatus("Запуск " .. droneClass .. "...", 3)
end

-- Отрисовка экрана выбора дрона
hook.Add("HUDPaint", "Async_Gamepad_DrawMenu", function()
    -- Статусная строка (рисуется всегда, если есть текст)
    if ASYNC_UI.StatusText ~= "" and CurTime() < ASYNC_UI.StatusTime then
        local sw, sh = ScrW(), ScrH()
        local alpha = math.Clamp((ASYNC_UI.StatusTime - CurTime()) * 255, 0, 255)
        draw.SimpleText(ASYNC_UI.StatusText, "AsyncGP_Status", sw * 0.5, sh - 60, Color(CLR_WHITE.r, CLR_WHITE.g, CLR_WHITE.b, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    if not ASYNC_UI.IsOpen then return end

    local sw, sh = ScrW(), ScrH()
    local panelW = 420
    local panelH = 480
    local px = (sw - panelW) * 0.5
    local py = (sh - panelH) * 0.5

    -- Фон
    draw.RoundedBox(8, px, py, panelW, panelH, CLR_BG)
    draw.RoundedBox(8, px + 1, py + 1, panelW - 2, panelH - 2, Color(0, 0, 0, 0))
    surface.SetDrawColor(CLR_BORDER)
    surface.DrawOutlinedRect(px, py, panelW, panelH, 1)

    -- Заголовок
    draw.SimpleText("ПУЛЬТ УПРАВЛЕНИЯ", "AsyncGP_Title", px + panelW * 0.5, py + 20, CLR_WHITE, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

    -- Линия под заголовком
    surface.SetDrawColor(CLR_BORDER)
    surface.DrawRect(px + 20, py + 58, panelW - 40, 1)

    -- Карточки дронов
    local cardH = 100
    local cardMargin = 10
    local startY = py + 70
    local mx, my = gui.MousePos()

    for i, drone in ipairs(DRONE_LIST) do
        local cy = startY + (i - 1) * (cardH + cardMargin)
        local isHovered = mx >= px + 15 and mx <= px + panelW - 15 and my >= cy and my <= cy + cardH
        local cardColor = isHovered and CLR_CARD_SEL or CLR_CARD

        -- Карточка
        draw.RoundedBox(6, px + 15, cy, panelW - 30, cardH, cardColor)

        -- Полоска цвета типа дрона
        draw.RoundedBoxEx(6, px + 15, cy, 5, cardH, drone.color, true, false, true, false)

        -- Название
        draw.SimpleText(drone.name, "AsyncGP_Button", px + 35, cy + 10, CLR_WHITE, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

        -- Описание (первая строка)
        local descLines = string.Explode("\n", drone.desc)
        for li, line in ipairs(descLines) do
            draw.SimpleText(line, "AsyncGP_Desc", px + 35, cy + 34 + (li - 1) * 18, CLR_GRAY, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        end

        -- Параметры справа
        draw.SimpleText(drone.speed, "AsyncGP_Desc", px + panelW - 30, cy + 15, CLR_GRAY, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
        draw.SimpleText(drone.time, "AsyncGP_Desc", px + panelW - 30, cy + 35, CLR_GRAY, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
        draw.SimpleText("HP: " .. drone.hp, "AsyncGP_Desc", px + panelW - 30, cy + 55, CLR_GRAY, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)

        -- Кнопка "Запуск"
        local btnW, btnH = 90, 28
        local btnX = px + panelW - 30 - btnW
        local btnY = cy + cardH - btnH - 8
        local btnHover = mx >= btnX and mx <= btnX + btnW and my >= btnY and my <= btnY + btnH
        draw.RoundedBox(4, btnX, btnY, btnW, btnH, btnHover and CLR_BTN_HOV or CLR_BTN)
        draw.SimpleText("ЗАПУСК", "AsyncGP_Desc", btnX + btnW * 0.5, btnY + btnH * 0.5, CLR_WHITE, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        -- Обработка клика
        if btnHover and input.IsMouseDown(MOUSE_LEFT) then
            if not ASYNC_UI._lastClick or CurTime() - ASYNC_UI._lastClick > 0.5 then
                ASYNC_UI._lastClick = CurTime()
                RequestSpawnDrone(drone.class)
            end
        end
    end

    -- Нижняя панель
    local footerY = py + panelH - 40
    surface.SetDrawColor(CLR_BORDER)
    surface.DrawRect(px + 20, footerY, panelW - 40, 1)
    draw.SimpleText("F6 — закрыть", "AsyncGP_Desc", px + panelW * 0.5, footerY + 12, CLR_GRAY, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
end)

-- Скрытие стандартного HUD когда меню открыто
hook.Add("HUDShouldDraw", "Async_Gamepad_HideHUD", function(name)
    if ASYNC_UI.IsOpen then
        if name == "CHudWeaponSelection" then return false end
    end
end)
