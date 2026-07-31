--[[
    Отладочный модуль (Debug HUD & Logger) для LVS Дронов в Z-City
    Файл: lua/autorun/client/cl_async_lvs_drone_debug.lua
--]]

CreateClientConVar("async_drone_debug", "1", true, false, "Показывать экранную отладку дронов (1 - вкл, 0 - выкл)")

local debug_info = {
    in_vehicle = false,
    pod_valid = false,
    veh_class = "none",
    veh_valid = false,
    cam_origin = Vector(0,0,0),
    cam_angles = Angle(0,0,0),
    cam_fov = 0,
    dist_to_operator = 0,
    last_hook = "none",
    is_drone = false,
    error_msg = "ОК"
}

local function GetLVSVehicle(ply)
    if not IsValid(ply) then return nil end

    if ply.lvsGetVehicle then
        local v = ply:lvsGetVehicle()
        if IsValid(v) then return v end
    end

    if ply:InVehicle() then
        local pod = ply:GetVehicle()
        if IsValid(pod) then
            local veh = pod.LVSBase or pod.Base or pod:GetNWEntity("LVSBase") or pod:GetNWEntity("LVS_Entity") or pod:GetParent()
            if IsValid(veh) then return veh end
            return pod
        end
    end

    return nil
end

-- 1. Перехват параметров камеры для отладки
hook.Add("CalcView", "Async_LVS_Drone_Debug_CalcView", function(ply, pos, angles, fov)
    if not IsValid(ply) then return end

    local veh = GetLVSVehicle(ply)
    if not IsValid(veh) then
        debug_info.in_vehicle = false
        return
    end

    debug_info.in_vehicle = true
    debug_info.veh_valid = true
    debug_info.veh_class = veh:GetClass()

    local cls = debug_info.veh_class:lower()
    debug_info.is_drone = veh.LVSUAV or veh.IsDrone or veh.IsCrocusKamikaze or veh.IsKVNDrone or cls:find("crocus") or cls:find("kvn") or cls:find("drone") or cls:find("uav")

    local groundPos = ply.CrocusGroundPos or ply.LVSGroundPos or ply:GetPos()
    debug_info.dist_to_operator = math.Round(groundPos:Distance(veh:GetPos()) / 39.37)

    debug_info.cam_origin = pos
    debug_info.cam_angles = angles
    debug_info.cam_fov = fov
    debug_info.last_hook = "Async_LVS_Drone_Debug_CalcView"

    -- Проверка аномалий (улет за карту, кривой FOV)
    if fov and (fov > 120 or fov < 10) then
        debug_info.error_msg = "ВНИМАНИЕ: Аномальный FOV! (" .. tostring(fov) .. ")"
        print("[DRONE DEBUG ERROR] Аномальный FOV:", fov)
    elseif pos and pos:Length() > 100000 then
        debug_info.error_msg = "ОШИБКА: Камера улетела за пределы карты!"
        print("[DRONE DEBUG ERROR] Камера за картой:", pos)
    else
        debug_info.error_msg = "ОК"
    end
end)

-- 2. Отрисовка отладочного HUD на экране (в правом верхнем углу, чтобы не перекрывать OSD)
hook.Add("HUDPaint", "Async_LVS_Drone_Debug_HUD", function()
    if not GetConVar("async_drone_debug"):GetBool() then return end
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local veh = GetLVSVehicle(ply)
    if not IsValid(veh) then return end

    local w, h = 360, 210
    local x, y = ScrW() - w - 20, 20

    surface.SetDrawColor(0, 0, 0, 220)
    surface.DrawRect(x, y, w, h)
    surface.SetDrawColor(0, 255, 200, 255)
    surface.DrawOutlinedRect(x, y, w, h, 2)

    draw.SimpleText("=== ОТЛАДКА ДРОНА (Async.reality) ===", "DermaDefaultBold", x + 10, y + 10, Color(0, 255, 200), TEXT_ALIGN_LEFT)
    draw.SimpleText("Управление дроном: " .. tostring(debug_info.in_vehicle), "DermaDefault", x + 10, y + 30, Color(255, 255, 255), TEXT_ALIGN_LEFT)
    draw.SimpleText("Модель дрона: " .. tostring(debug_info.veh_class), "DermaDefault", x + 10, y + 45, debug_info.is_drone and Color(0, 255, 0) or Color(255, 200, 0), TEXT_ALIGN_LEFT)
    draw.SimpleText("Распознан как FPV дрон: " .. tostring(debug_info.is_drone), "DermaDefault", x + 10, y + 60, debug_info.is_drone and Color(0, 255, 0) or Color(255, 50, 50), TEXT_ALIGN_LEFT)
    draw.SimpleText("Дистанция до пилота: " .. tostring(debug_info.dist_to_operator) .. " м", "DermaDefault", x + 10, y + 75, Color(255, 255, 255), TEXT_ALIGN_LEFT)
    draw.SimpleText("Текущий FOV: " .. tostring(math.Round(debug_info.cam_fov or 0, 1)), "DermaDefault", x + 10, y + 90, (debug_info.cam_fov > 120 or debug_info.cam_fov < 10) and Color(255, 50, 50) or Color(255, 255, 255), TEXT_ALIGN_LEFT)
    
    local org = debug_info.cam_origin
    draw.SimpleText(string.format("Камера Pos: X:%.0f Y:%.0f Z:%.0f", org.x, org.y, org.z), "DermaDefault", x + 10, y + 110, Color(200, 200, 200), TEXT_ALIGN_LEFT)
    
    local ang = debug_info.cam_angles
    draw.SimpleText(string.format("Камера Ang: P:%.1f Y:%.1f R:%.1f", ang.p, ang.y, ang.r), "DermaDefault", x + 10, y + 125, Color(200, 200, 200), TEXT_ALIGN_LEFT)
    
    draw.SimpleText("Статус: " .. debug_info.error_msg, "DermaDefaultBold", x + 10, y + 150, debug_info.error_msg == "ОК" and Color(0, 255, 0) or Color(255, 50, 50), TEXT_ALIGN_LEFT)
    draw.SimpleText("Выключить HUD: async_drone_debug 0", "DermaDefault", x + 10, y + 175, Color(150, 150, 150), TEXT_ALIGN_LEFT)
end)
