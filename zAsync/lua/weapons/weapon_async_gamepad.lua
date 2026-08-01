--[[
    SWEP Пульта Управления Дронами (Async Gamepad)
    Файл: lua/weapons/weapon_async_gamepad.lua

    Портативный пульт управления с экраном смартфона.
    На экране смартфона отображается ЖИВАЯ трансляция с FPV-камеры подсоединённого дрона (Render Target)!
--]]

if SERVER then
    AddCSLuaFile()
end

SWEP.Base = "weapon_base"

SWEP.PrintName = "НСУ Пульт Дронов"
SWEP.Author = "zAsync"
SWEP.Instructions = "ЛКМ или F6: Открыть экран выбора дронов.\nПКМ: Переключение тепловизора FLIR.\nR: Проверка статуса связи."
SWEP.Category = "ZCity Other"

SWEP.Spawnable = true
SWEP.AdminSpawnable = true
SWEP.AdminOnly = false

SWEP.ViewModel = "models/weapons/w_async_gamepad.mdl"
SWEP.WorldModel = "models/weapons/w_async_gamepad.mdl"

if CLIENT then
    SWEP.WepSelectIcon = Material("entities/async_gamepad.png")
    SWEP.WepSelectIcon2 = Material("entities/async_gamepad.png")
    SWEP.IconOverride = "entities/async_gamepad.png"
    SWEP.BounceWeaponIcon = false

    -- Консольные переменные для подстройки размеров и расположения в руках
    CreateClientConVar("async_gamepad_scale", "0.04", true, false, "Масштаб модели пульта")
    CreateClientConVar("async_gamepad_pos_x", "4", true, false, "Смещение вперед/назад")
    CreateClientConVar("async_gamepad_pos_y", "3", true, false, "Смещение вправо/влево")
    CreateClientConVar("async_gamepad_pos_z", "-2", true, false, "Смещение вверх/вниз")
    CreateClientConVar("async_gamepad_ang_p", "15", true, false, "Угол тангажа (Pitch)")
    CreateClientConVar("async_gamepad_ang_y", "0", true, false, "Угол рыскания (Yaw) — антеннами от игрока")
    CreateClientConVar("async_gamepad_ang_r", "0", true, false, "Угол крена (Roll)")
end

SWEP.Weight = 0
SWEP.AutoSwitchTo = false
SWEP.AutoSwitchFrom = false

SWEP.Slot = 4
SWEP.SlotPos = 5
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = false
SWEP.HoldType = "slam"

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

function SWEP:Initialize()
    self:SetHoldType(self.HoldType)
end

function SWEP:Deploy()
    return true
end

function SWEP:PrimaryAttack()
    self:SetNextPrimaryFire(CurTime() + 0.5)

    if CLIENT then
        if ASYNC_UI then
            ASYNC_UI.IsOpen = not ASYNC_UI.IsOpen
            gui.EnableScreenClicker(ASYNC_UI.IsOpen)
        end
    end
end

function SWEP:SecondaryAttack()
    self:SetNextSecondaryFire(CurTime() + 0.5)

    if CLIENT then
        local ply = LocalPlayer()
        if IsValid(ply) then
            local veh = ply:GetVehicle()
            if IsValid(veh) then
                local base = veh:GetNWEntity("LVS_Entity")
                if not IsValid(base) then base = veh:GetParent() end
                if IsValid(base) and base.GetNWBool then
                    local current = base:GetNWBool("KVN_FLIR", false)
                    base:SetNWBool("KVN_FLIR", not current)
                end
            end
        end
    end
end

function SWEP:Reload()
    self:SetNextPrimaryFire(CurTime() + 1.0)

    if SERVER then
        local owner = self:GetOwner()
        if IsValid(owner) then
            local activeDrone = owner:GetNWEntity("KVN_ActiveDrone")
            if IsValid(activeDrone) then
                owner:ChatPrint("[zAsync] Статус связи: Дрон активен (" .. activeDrone:GetClass() .. ")")
            else
                owner:ChatPrint("[zAsync] Статус связи: Дрон не подключён.")
            end
        end
    end
end

-- Отрисовка 3D2D экрана смартфона с ЖИВОЙ FPV трансляцией (Render Target)
if CLIENT then
    -- Инициализация Render Target камеры FPV
    local RT_W, RT_H = 512, 256
    local drone_rt = GetRenderTarget("AsyncGamepad_FPV_RT", RT_W, RT_H, false)
    local drone_mat = CreateMaterial("AsyncGamepad_FPV_Mat", "UnlitGeneric", {
        ["$basetexture"] = "AsyncGamepad_FPV_RT",
        ["$vertexcolor"] = 1,
        ["$ignorez"]     = 0,
    })

    local last_cam_render = 0

    -- Функция захвата изображения с камеры дрона
    local function UpdateDroneCameraFeed(drone)
        if not IsValid(drone) then return end

        local ct = RealTime()
        if ct - last_cam_render < 0.033 then return end -- Ограничение ~30 FPS для оптимизации
        last_cam_render = ct

        -- Позиция объектива дрона
        local camPos = drone:LocalToWorld(Vector(15, 0, 4))
        local camAtt = drone:LookupAttachment("camera")
        if camAtt and camAtt > 0 then
            local att = drone:GetAttachment(camAtt)
            if att and att.Pos and att.Pos ~= vector_origin then
                camPos = att.Pos
            end
        end

        local viewData = {
            x = 0,
            y = 0,
            w = RT_W,
            h = RT_H,
            origin = camPos,
            angles = drone:GetAngles(),
            fov = 75,
            drawhud = false,
            drawviewmodel = false,
            aspectratio = 2.0,
        }

        local oldRT = render.GetRenderTarget()
        render.SetRenderTarget(drone_rt)
        render.Clear(10, 12, 16, 255, true, true)
        render.RenderView(viewData)
        render.SetRenderTarget(oldRT)
    end

    local function DrawSmartphoneScreen(pos, ang, scale, drone)
        cam.Start3D2D(pos, ang, scale)
            -- Задний фон смартфона
            surface.SetDrawColor(15, 18, 24, 255)
            surface.DrawRect(-150, -90, 300, 180)

            if IsValid(drone) then
                -- Отрисовка живого видеопотока с FPV-камеры дрона
                UpdateDroneCameraFeed(drone)

                surface.SetDrawColor(255, 255, 255, 255)
                surface.SetMaterial(drone_mat)
                surface.DrawTexturedRect(-148, -62, 296, 124)

                -- Сетка прицела FPV на экране
                surface.SetDrawColor(0, 255, 120, 180)
                surface.DrawOutlinedRect(-20, -15, 40, 30, 1)
                surface.DrawLine(-5, 0, 5, 0)
                surface.DrawLine(0, -5, 0, 5)
            else
                -- Экран в режиме ожидания подключения
                draw.SimpleText("READY TO CONNECT", "TargetID", 0, -25, Color(220, 220, 230), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                draw.SimpleText("PRESS ATTACK / F6 TO LAUNCH", "TargetIDSmall", 0, 15, Color(0, 200, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end

            -- Рамка экрана
            surface.SetDrawColor(0, 180, 255, 200)
            surface.DrawOutlinedRect(-150, -90, 300, 180, 2)

            -- Верхняя информационная плашка
            surface.SetDrawColor(25, 30, 40, 220)
            surface.DrawRect(-150, -90, 300, 26)

            draw.SimpleText("zAsync FPV FEED", "TargetIDSmall", -140, -85, Color(0, 220, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            
            local pct = IsValid(drone) and math.Round(drone:GetNWFloat("KVN_BatteryPct", 1) * 100) or 100
            draw.SimpleText("BAT: " .. pct .. "%", "TargetIDSmall", 140, -85, Color(80, 220, 120), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)

            -- Нижний статус бар
            surface.SetDrawColor(40, 45, 55, 220)
            surface.DrawRect(-150, 64, 300, 26)
            
            local statusStr = IsValid(drone) and ("LINK: OK | " .. drone:GetClass():upper()) or "SIGNAL: STANDBY | CH: 5.8GHz"
            draw.SimpleText(statusStr, "TargetIDSmall", 0, 68, Color(200, 200, 210), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
        cam.End3D2D()
    end

    function SWEP:DrawWorldModel()
        local owner = self:GetOwner()
        
        local scale = GetConVar("async_gamepad_scale"):GetFloat()
        local offX = GetConVar("async_gamepad_pos_x"):GetFloat()
        local offY = GetConVar("async_gamepad_pos_y"):GetFloat()
        local offZ = GetConVar("async_gamepad_pos_z"):GetFloat()
        local angP = GetConVar("async_gamepad_ang_p"):GetFloat()
        local angY = GetConVar("async_gamepad_ang_y"):GetFloat()
        local angR = GetConVar("async_gamepad_ang_r"):GetFloat()

        local pos, ang

        if IsValid(owner) then
            local boneHand = owner:LookupBone("ValveBiped.Bip01_R_Hand")
            if boneHand then
                pos, ang = owner:GetBonePosition(boneHand)
            else
                pos = owner:GetPos()
                ang = owner:GetAngles()
            end

            pos = pos + ang:Forward() * offX + ang:Right() * offY + ang:Up() * offZ
            ang:RotateAroundAxis(ang:Up(), angY)
            ang:RotateAroundAxis(ang:Right(), angP)
            ang:RotateAroundAxis(ang:Forward(), angR)
        else
            pos = self:GetPos()
            ang = self:GetAngles()
        end

        self:SetModelScale(scale, 0)
        self:SetRenderOrigin(pos)
        self:SetRenderAngles(ang)
        self:DrawModel()

        -- Поиск подключённого активного дрона у игрока
        local activeDrone = IsValid(owner) and owner:GetNWEntity("KVN_ActiveDrone") or nil

        -- Отрисовка 3D2D экрана смартфона прямо на дисплее модели
        local screenPos = pos + ang:Forward() * (0.5 * scale * 25) + ang:Up() * (2.2 * scale * 25)
        local screenAng = Angle(ang.p, ang.y, ang.r)
        screenAng:RotateAroundAxis(screenAng:Up(), 90)
        screenAng:RotateAroundAxis(screenAng:Forward(), 75)

        DrawSmartphoneScreen(screenPos, screenAng, 0.015 * (scale / 0.04), activeDrone)
    end
end
