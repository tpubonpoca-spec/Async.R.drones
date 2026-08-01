--[[
    SWEP Пульта Управления Дронами (Async Gamepad)
    Файл: lua/weapons/weapon_async_gamepad.lua

    Настроен идеальный масштаб (0.50), углы (-25, -180, -180) и
    точная привязка 3D2D экрана прямо на стекло смартфона геймпада!
--]]

if SERVER then
    AddCSLuaFile()
end

SWEP.Base = "weapon_base"

SWEP.PrintName = "НСУ Пульт Дронов"
SWEP.Author = "zAsync"
SWEP.Instructions = "ЛКМ: Спавн/Запуск выбранного дрона с экрана пульта.\nПКМ: Переключение выбранного дрона (KVN-1/2/3) / FLIR.\nR: Проверка статуса связи."
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

    -- Настройки положения модели в руках по умолчанию на основе пользовательских значений
    CreateClientConVar("async_gamepad_scale", "0.50", true, false, "Масштаб модели пульта")
    CreateClientConVar("async_gamepad_pos_x", "20", true, false, "Смещение вперед/назад")
    CreateClientConVar("async_gamepad_pos_y", "3", true, false, "Смещение вправо/влево")
    CreateClientConVar("async_gamepad_pos_z", "-2", true, false, "Смещение вверх/вниз")
    CreateClientConVar("async_gamepad_ang_p", "-25", true, false, "Угол тангажа (Pitch)")
    CreateClientConVar("async_gamepad_ang_y", "-180", true, false, "Угол рыскания (Yaw)")
    CreateClientConVar("async_gamepad_ang_r", "-180", true, false, "Угол крена (Roll)")

    -- Точная подстройка экрана смартфона на модели
    CreateClientConVar("async_gamepad_screen_x", "0", true, false, "Смещение экрана по X")
    CreateClientConVar("async_gamepad_screen_y", "1.2", true, false, "Смещение экрана по Y")
    CreateClientConVar("async_gamepad_screen_z", "5.8", true, false, "Смещение экрана по Z")
    CreateClientConVar("async_gamepad_screen_scale", "0.018", true, false, "Масштаб 3D2D экрана")
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

local DRONES = {
    { class = "lvs_kvn1", name = "KVN-1 (Камикадзе)", color = Color(220, 60, 60) },
    { class = "lvs_kvn2", name = "KVN-2 (Разведка/FLIR)", color = Color(60, 180, 220) },
    { class = "lvs_kvn3", name = "KVN-3 (Тяжёлый)", color = Color(220, 180, 40) },
}

function SWEP:SetupDataTables()
    self:NetworkVar("Int", 0, "SelectedDroneIndex")
end

function SWEP:Initialize()
    self:SetHoldType(self.HoldType)
    if SERVER then
        self:SetSelectedDroneIndex(1)
    end
end

function SWEP:Deploy()
    return true
end

function SWEP:PrimaryAttack()
    self:SetNextPrimaryFire(CurTime() + 0.6)

    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    local activeDrone = owner:GetNWEntity("KVN_ActiveDrone")

    if not IsValid(activeDrone) then
        local idx = math.Clamp(self:GetSelectedDroneIndex() or 1, 1, #DRONES)
        local selectedDrone = DRONES[idx]

        if SERVER then
            net.Start("Async_SpawnDrone")
                net.WriteString(selectedDrone.class)
            net.Send(owner)
        end
    else
        if CLIENT and ASYNC_UI then
            ASYNC_UI.IsOpen = not ASYNC_UI.IsOpen
            gui.EnableScreenClicker(ASYNC_UI.IsOpen)
        end
    end
end

function SWEP:SecondaryAttack()
    self:SetNextSecondaryFire(CurTime() + 0.4)

    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    local activeDrone = owner:GetNWEntity("KVN_ActiveDrone")

    if not IsValid(activeDrone) then
        if SERVER then
            local current = self:GetSelectedDroneIndex() or 1
            local nextIdx = (current % #DRONES) + 1
            self:SetSelectedDroneIndex(nextIdx)
        end
        if CLIENT then
            surface.PlaySound("buttons/button14.wav")
        end
    else
        if CLIENT then
            local veh = owner:GetVehicle()
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
                owner:ChatPrint("[zAsync] Статус связи: Готов к запуску.")
            end
        end
    end
end

if CLIENT then
    local RT_W, RT_H = 512, 256
    local drone_rt = GetRenderTarget("AsyncGamepad_FPV_RT3", RT_W, RT_H, false)
    local drone_mat = CreateMaterial("AsyncGamepad_FPV_Mat3", "UnlitGeneric", {
        ["$basetexture"] = "AsyncGamepad_FPV_RT3",
        ["$vertexcolor"] = 1,
        ["$ignorez"]     = 0,
    })

    local last_cam_render = 0

    local function UpdateDroneCameraFeed(drone)
        if not IsValid(drone) then return end

        local ct = RealTime()
        if ct - last_cam_render < 0.033 then return end
        last_cam_render = ct

        local camPos = drone:LocalToWorld(Vector(15, 0, 4))
        local camAtt = drone:LookupAttachment("camera")
        if camAtt and camAtt > 0 then
            local att = drone:GetAttachment(camAtt)
            if att and att.Pos and att.Pos ~= vector_origin then
                camPos = att.Pos
            end
        end

        local viewData = {
            x = 0, y = 0, w = RT_W, h = RT_H,
            origin = camPos, angles = drone:GetAngles(), fov = 75,
            drawhud = false, drawviewmodel = false, aspectratio = 2.0,
        }

        local oldRT = render.GetRenderTarget()
        render.SetRenderTarget(drone_rt)
        render.Clear(10, 12, 16, 255, true, true)
        render.RenderView(viewData)
        render.SetRenderTarget(oldRT)
    end

    local function DrawSmartphoneScreen(pos, ang, scale, drone, swep)
        cam.Start3D2D(pos, ang, scale)
            -- Заднее стекло смартфона
            surface.SetDrawColor(15, 18, 24, 255)
            surface.DrawRect(-150, -90, 300, 180)

            if IsValid(drone) then
                -- Видеопоток FPV при полете
                UpdateDroneCameraFeed(drone)

                surface.SetDrawColor(255, 255, 255, 255)
                surface.SetMaterial(drone_mat)
                surface.DrawTexturedRect(-148, -62, 296, 124)

                surface.SetDrawColor(0, 255, 120, 180)
                surface.DrawOutlinedRect(-20, -15, 40, 30, 1)
                surface.DrawLine(-5, 0, 5, 0)
                surface.DrawLine(0, -5, 0, 5)
            else
                -- Экран выбора и спавна дронов
                local selIdx = IsValid(swep) and swep:GetSelectedDroneIndex() or 1
                selIdx = math.Clamp(selIdx, 1, #DRONES)
                local currentDroneInfo = DRONES[selIdx]

                surface.SetDrawColor(currentDroneInfo.color.r, currentDroneInfo.color.g, currentDroneInfo.color.b, 50)
                surface.DrawRect(-140, -60, 280, 115)

                surface.SetDrawColor(currentDroneInfo.color)
                surface.DrawOutlinedRect(-140, -60, 280, 115, 2)

                draw.SimpleText("ВЫБРАННЫЙ ДРОН:", "TargetIDSmall", 0, -48, Color(180, 190, 210), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                draw.SimpleText("◄ " .. currentDroneInfo.name .. " ►", "TargetID", 0, -22, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

                surface.SetDrawColor(40, 160, 80, 255)
                surface.DrawRect(-90, 5, 180, 32)
                surface.SetDrawColor(80, 220, 120, 255)
                surface.DrawOutlinedRect(-90, 5, 180, 32, 1)
                draw.SimpleText("[ ЛКМ — ЗАПУСТИТЬ ]", "TargetIDSmall", 0, 21, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

                draw.SimpleText("ПКМ — Выбрать другой дрон", "TargetIDSmall", 0, 45, Color(140, 145, 160), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end

            -- Внешняя рамка
            surface.SetDrawColor(0, 180, 255, 200)
            surface.DrawOutlinedRect(-150, -90, 300, 180, 2)

            -- Верхний статус бар
            surface.SetDrawColor(25, 30, 40, 230)
            surface.DrawRect(-150, -90, 300, 26)
            draw.SimpleText("zAsync FPV FEED", "TargetIDSmall", -140, -85, Color(0, 220, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

            local pct = IsValid(drone) and math.Round(drone:GetNWFloat("KVN_BatteryPct", 1) * 100) or 100
            draw.SimpleText("BAT: " .. pct .. "%", "TargetIDSmall", 140, -85, Color(80, 220, 120), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)

            -- Нижний статус бар
            surface.SetDrawColor(40, 45, 55, 230)
            surface.DrawRect(-150, 64, 300, 26)
            local statusStr = IsValid(drone) and ("LINK: ACTIVE | " .. drone:GetClass():upper()) or "SYSTEM: READY FOR LAUNCH"
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

        local scrX = GetConVar("async_gamepad_screen_x"):GetFloat()
        local scrY = GetConVar("async_gamepad_screen_y"):GetFloat()
        local scrZ = GetConVar("async_gamepad_screen_z"):GetFloat()
        local scrScale = GetConVar("async_gamepad_screen_scale"):GetFloat()

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

        local activeDrone = IsValid(owner) and owner:GetNWEntity("KVN_ActiveDrone") or nil

        -- Вычисление позиционирования 3D2D экрана строго на дисплее смартфона
        local screenPos = pos + ang:Forward() * scrX + ang:Right() * scrY + ang:Up() * scrZ
        local screenAng = Angle(ang.p, ang.y, ang.r)
        screenAng:RotateAroundAxis(screenAng:Up(), 90)
        screenAng:RotateAroundAxis(screenAng:Forward(), 75)

        DrawSmartphoneScreen(screenPos, screenAng, scrScale, activeDrone, self)
    end
end
