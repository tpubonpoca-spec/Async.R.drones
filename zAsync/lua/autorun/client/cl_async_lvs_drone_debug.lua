--[[
    Отладочный модуль (Debug HUD & Logger) для LVS Дронов в Z-City
    Файл: lua/autorun/client/cl_async_lvs_drone_debug.lua
--]]

-- Отладка по умолчанию ВЫКЛЮЧЕНА (0). Включить при необходимости: async_drone_debug 1
CreateClientConVar("async_drone_debug", "0", true, false, "Показывать экранную отладку дронов (1 - вкл, 0 - выкл)")

local debug_info = {
    in_vehicle = false,
    pod_valid = false,
    veh_class = "none",
    veh_valid = false,
    cam_origin = Vector(0,0,0),
    cam_angles = Angle(0,0,0),
    cam_fov = 75,
    dist_to_operator = 0,
    last_hook = "none",
    is_drone = false,
    error_msg = "ОК (Ожидание дрона)"
}

local function GetLVSVehicle(ply)
    if not IsValid(ply) then return nil end

    if ply:InVehicle() then
        local pod = ply:GetVehicle()
        if IsValid(pod) then
            local veh = pod:GetNWEntity("LVS_Entity") or pod:GetNWEntity("LVSBase") or pod.LVSBase or pod.Base or pod:GetParent()
            if IsValid(veh) and veh ~= pod then return veh end

            for _, e in ipairs(ents.FindByClass("lvs_*")) do
                if e.GetDriverSeat and e:GetDriverSeat() == pod then
                    return e
                end
            end

            return pod
        end
    end

    if ply.lvsGetVehicle then
        local v = ply:lvsGetVehicle()
        if IsValid(v) then return v end
    end

    if IsValid(ply.LVS_Vehicle) then return ply.LVS_Vehicle end

    local nwVeh = ply:GetNWEntity("LVS_Vehicle")
    if IsValid(nwVeh) then return nwVeh end

    local activeDrone = ply:GetNWEntity("KVN_ActiveDrone")
    if IsValid(activeDrone) then return activeDrone end

    local uav = ply:GetNWEntity("UAV")
    if IsValid(uav) then return uav end

    for _, e in ipairs(ents.FindByClass("lvs_*")) do
        if e.GetDriver and e:GetDriver() == ply then
            return e
        end
        if e.GetOperator and e:GetOperator() == ply then
            return e
        end
    end

    return nil
end

-- 1. Отрисовка отладочного HUD в правом верхнем углу
hook.Add("HUDPaint", "Async_LVS_Drone_Debug_HUD", function()
    if not GetConVar("async_drone_debug"):GetBool() then return end
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local veh = GetLVSVehicle(ply)
    if IsValid(veh) then
        local cls = veh:GetClass()
        local cls_l = cls:lower()
        local isDrone = veh.LVSUAV or veh.IsDrone or veh.IsCrocusKamikaze or veh.IsKVNDrone or cls_l:find("crocus") or cls_l:find("kvn") or cls_l:find("drone") or cls_l:find("uav")

        debug_info.in_vehicle = true
        debug_info.veh_class = cls
        debug_info.is_drone = isDrone
        debug_info.cam_origin = veh:GetPos()
        debug_info.cam_angles = veh:GetAngles()

        local operatorPos = ply.CrocusGroundPos or ply.LVSGroundPos or ply:GetPos()
        debug_info.dist_to_operator = math.Round(operatorPos:Distance(veh:GetPos()) / 39.37)
        debug_info.error_msg = "АКТИВЕН (ОК)"
    else
        debug_info.in_vehicle = false
        debug_info.veh_class = "none"
        debug_info.is_drone = false
        debug_info.dist_to_operator = 0
        debug_info.cam_origin = ply:GetPos()
        debug_info.cam_angles = ply:EyeAngles()
        debug_info.error_msg = "ОК (Ожидание дрона)"
    end

    local w, h = 360, 210
    local x, y = ScrW() - w - 20, 20

    surface.SetDrawColor(0, 0, 0, 220)
    surface.DrawRect(x, y, w, h)
    surface.SetDrawColor(0, 255, 200, 255)
    surface.DrawOutlinedRect(x, y, w, h, 2)

    draw.SimpleText("=== ОТЛАДКА ДРОНА (zAsync) ===", "DermaDefaultBold", x + 10, y + 10, Color(0, 255, 200), TEXT_ALIGN_LEFT)
    draw.SimpleText("Управление дроном: " .. tostring(debug_info.in_vehicle), "DermaDefault", x + 10, y + 30, debug_info.in_vehicle and Color(0, 255, 0) or Color(200, 200, 200), TEXT_ALIGN_LEFT)
    draw.SimpleText("Модель дрона: " .. tostring(debug_info.veh_class), "DermaDefault", x + 10, y + 45, debug_info.is_drone and Color(0, 255, 0) or Color(255, 200, 0), TEXT_ALIGN_LEFT)
    draw.SimpleText("Распознан как FPV дрон: " .. tostring(debug_info.is_drone), "DermaDefault", x + 10, y + 60, debug_info.is_drone and Color(0, 255, 0) or Color(255, 50, 50), TEXT_ALIGN_LEFT)
    draw.SimpleText("Дистанция до пилота: " .. tostring(debug_info.dist_to_operator) .. " м", "DermaDefault", x + 10, y + 75, Color(255, 255, 255), TEXT_ALIGN_LEFT)
    draw.SimpleText("Текущий FOV: " .. tostring(math.Round(debug_info.cam_fov or 75, 1)), "DermaDefault", x + 10, y + 90, Color(255, 255, 255), TEXT_ALIGN_LEFT)
    
    local org = debug_info.cam_origin
    draw.SimpleText(string.format("Дрон Pos: X:%.0f Y:%.0f Z:%.0f", org.x, org.y, org.z), "DermaDefault", x + 10, y + 110, Color(200, 200, 200), TEXT_ALIGN_LEFT)
    
    local ang = debug_info.cam_angles
    draw.SimpleText(string.format("Дрон Ang: P:%.1f Y:%.1f R:%.1f", ang.p, ang.y, ang.r), "DermaDefault", x + 10, y + 125, Color(200, 200, 200), TEXT_ALIGN_LEFT)
    
    draw.SimpleText("Статус: " .. debug_info.error_msg, "DermaDefaultBold", x + 10, y + 150, debug_info.in_vehicle and Color(0, 255, 0) or Color(200, 200, 200), TEXT_ALIGN_LEFT)
    draw.SimpleText("Выключить HUD: async_drone_debug 0", "DermaDefault", x + 10, y + 175, Color(150, 150, 150), TEXT_ALIGN_LEFT)
end)
