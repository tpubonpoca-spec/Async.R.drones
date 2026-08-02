--[[
    SWEP Пульта Управления Дронами (Async Gamepad)
    Файл: lua/weapons/weapon_async_gamepad.lua

    Оптимизирован согласно стандартам gmod-dev / AuraKit:
    - Кэширование Vector, Angle, Color вне циклов отрисовки
    - Взаимодействие с TPIK1 базой Z-City
    - Поддержка FPV видеопотока и 3D2D экрана
--]]

if SERVER then
    AddCSLuaFile()
end

SWEP.Base = "weapon_tpik1_base"

SWEP.PrintName = "НСУ Пульт Дронов"
SWEP.Author = "zAsync"
SWEP.Instructions = "ЛКМ: Спавн/Запуск выбранного дрона с экрана пульта.\nПКМ: Переключение выбранного дрона (KVN-1/2/3) / FLIR.\nR: Проверка статуса связи."
SWEP.Category = "ZCity Other"

SWEP.Spawnable = true
SWEP.AdminSpawnable = true
SWEP.AdminOnly = false

SWEP.ViewModel = "models/weapons/v_async_gamepad.mdl"
SWEP.WorldModel = "models/weapons/w_async_gamepad.mdl"
SWEP.HoldType = "slam"

-- TPIK1 привязка к костям рук
SWEP.setrhik = true
SWEP.setlhik = true

SWEP.LHPos = Vector(0, -6.6, 0)
SWEP.LHAng = Angle(0, 0, 180)

SWEP.RHPosOffset = Vector(0, 0, -7.6)
SWEP.RHAngOffset = Angle(0, 15, -90)

SWEP.LHPosOffset = Vector(0, 0, -0.4)
SWEP.LHAngOffset = Angle(5, 0, 15)

SWEP.handPos = Vector(0, 0, 0)
SWEP.handAng = Angle(0, 0, 0)

SWEP.UsePistolHold = false

-- Позиция модели относительно правой руки
SWEP.offsetVec = Vector(5, -7, -1)
SWEP.offsetAng = Angle(0, 90, 195)

SWEP.HeadPosOffset = Vector(15, 1.7, -5)
SWEP.HeadAngOffset = Angle(-90, 0, -90)

SWEP.BaseBone = "ValveBiped.Bip01_Head1"

SWEP.HoldLH = "normal"
SWEP.HoldRH = "normal"

SWEP.WorkWithFake = true
SWEP.visualweight = 1.2

-- Кэшированные ConVar ссылки для gmod-dev производительности
if CLIENT then
    local cv_ox = CreateClientConVar("async_gp_ox", "5", true, false, "Offset Forward")
    local cv_oy = CreateClientConVar("async_gp_oy", "-7", true, false, "Offset Right")
    local cv_oz = CreateClientConVar("async_gp_oz", "-1", true, false, "Offset Up")
    local cv_ap = CreateClientConVar("async_gp_ap", "0", true, false, "Angle Pitch")
    local cv_ay = CreateClientConVar("async_gp_ay", "90", true, false, "Angle Yaw")
    local cv_ar = CreateClientConVar("async_gp_ar", "195", true, false, "Angle Roll")

    function SWEP:Think()
        if self:GetHoldType() ~= self.HoldType then
            self:SetHoldType(self.HoldType)
        end

        self.offsetVec = Vector(cv_ox:GetFloat(), cv_oy:GetFloat(), cv_oz:GetFloat())
        self.offsetAng = Angle(cv_ap:GetFloat(), cv_ay:GetFloat(), cv_ar:GetFloat())

        self:AddThink()
    end
end

SWEP.Weight = 0
SWEP.AutoSwitchTo = false
SWEP.AutoSwitchFrom = false
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = false

SWEP.Slot = 4
SWEP.SlotPos = 5

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

-- Кэшированные цвета и векторы для 3D2D вырисовывания (gmod-dev 최적화)
SWEP.ScreenPosOffset = Vector(3.4, -2.22, 3.57)
SWEP.ScreenAngleOffset = Angle(-5, -18.5, 91)
SWEP.ScreenScale = 0.025

if CLIENT then
    local COLOR_BG = Color(15, 18, 24, 255)
    local COLOR_GREEN = Color(0, 255, 120, 180)
    local COLOR_WHITE = Color(255, 255, 255, 255)
    local COLOR_BLUE = Color(0, 180, 255, 200)
    local COLOR_CYAN = Color(0, 220, 255)
    local COLOR_TOPBAR = Color(25, 30, 40, 230)
    local COLOR_BOTBAR = Color(40, 45, 55, 230)
    local COLOR_TEXT_MUTED = Color(140, 145, 160)
    local COLOR_TEXT_LABEL = Color(180, 190, 210)
    local COLOR_TEXT_STATUS = Color(200, 200, 210)
    local COLOR_BTN_BG = Color(40, 160, 80, 255)
    local COLOR_BTN_BORDER = Color(80, 220, 120, 255)
    local CAM_OFFSET_DEFAULT = Vector(15, 0, 4)

    local RT_W, RT_H = 512, 256
    local drone_rt = GetRenderTarget("AsyncGamepad_FPV_RT4", RT_W, RT_H, false)
    local drone_mat = CreateMaterial("AsyncGamepad_FPV_Mat4", "UnlitGeneric", {
        ["$basetexture"] = "AsyncGamepad_FPV_RT4",
        ["$vertexcolor"] = 1,
        ["$ignorez"]     = 0,
    })

    local last_cam_render = 0

    local function UpdateDroneCameraFeed(drone)
        if not IsValid(drone) then return end

        local ct = RealTime()
        if ct - last_cam_render < 0.033 then return end
        last_cam_render = ct

        local camPos = drone:LocalToWorld(CAM_OFFSET_DEFAULT)
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
            surface.SetDrawColor(COLOR_BG)
            surface.DrawRect(-150, -90, 300, 180)

            if IsValid(drone) then
                UpdateDroneCameraFeed(drone)

                surface.SetDrawColor(COLOR_WHITE)
                surface.SetMaterial(drone_mat)
                surface.DrawTexturedRect(-148, -62, 296, 124)

                surface.SetDrawColor(COLOR_GREEN)
                surface.DrawOutlinedRect(-20, -15, 40, 30, 1)
                surface.DrawLine(-5, 0, 5, 0)
                surface.DrawLine(0, -5, 0, 5)
            else
                local selIdx = IsValid(swep) and swep:GetSelectedDroneIndex() or 1
                selIdx = math.Clamp(selIdx, 1, #DRONES)
                local currentDroneInfo = DRONES[selIdx]

                surface.SetDrawColor(currentDroneInfo.color.r, currentDroneInfo.color.g, currentDroneInfo.color.b, 50)
                surface.DrawRect(-140, -60, 280, 115)

                surface.SetDrawColor(currentDroneInfo.color)
                surface.DrawOutlinedRect(-140, -60, 280, 115, 2)

                draw.SimpleText("ВЫБРАННЫЙ ДРОН:", "TargetIDSmall", 0, -48, COLOR_TEXT_LABEL, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                draw.SimpleText("◄ " .. currentDroneInfo.name .. " ►", "TargetID", 0, -22, COLOR_WHITE, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

                surface.SetDrawColor(COLOR_BTN_BG)
                surface.DrawRect(-90, 5, 180, 32)
                surface.SetDrawColor(COLOR_BTN_BORDER)
                surface.DrawOutlinedRect(-90, 5, 180, 32, 1)
                draw.SimpleText("[ ЛКМ — ЗАПУСТИТЬ ]", "TargetIDSmall", 0, 21, COLOR_WHITE, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

                draw.SimpleText("ПКМ — Выбрать другой дрон", "TargetIDSmall", 0, 45, COLOR_TEXT_MUTED, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end

            surface.SetDrawColor(COLOR_BLUE)
            surface.DrawOutlinedRect(-150, -90, 300, 180, 2)

            surface.SetDrawColor(COLOR_TOPBAR)
            surface.DrawRect(-150, -90, 300, 26)
            draw.SimpleText("zAsync FPV FEED", "TargetIDSmall", -140, -85, COLOR_CYAN, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

            local pct = IsValid(drone) and math.Round(drone:GetNWFloat("KVN_BatteryPct", 1) * 100) or 100
            draw.SimpleText("BAT: " .. pct .. "%", "TargetIDSmall", 140, -85, COLOR_GREEN, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)

            surface.SetDrawColor(COLOR_BOTBAR)
            surface.DrawRect(-150, 64, 300, 26)
            local statusStr = IsValid(drone) and ("LINK: ACTIVE | " .. drone:GetClass():upper()) or "SYSTEM: READY FOR LAUNCH"
            draw.SimpleText(statusStr, "TargetIDSmall", 0, 68, COLOR_TEXT_STATUS, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
        cam.End3D2D()
    end

    function SWEP:ViewModelDrawn(vm)
        if not IsValid(vm) then return end

        local owner = self:GetOwner()
        if not IsValid(owner) then return end

        local activeDrone = owner:GetNWEntity("KVN_ActiveDrone")

        local boneid = vm:LookupBone("ValveBiped.Bip01_R_Hand")
        local pos, ang = vm:GetPos(), vm:GetAngles()
        if boneid then
            local matrix = vm:GetBoneMatrix(boneid)
            if matrix then
                pos = matrix:GetTranslation()
                ang = matrix:GetAngles()
            end
        end

        local screenPos, screenAng = LocalToWorld(self.ScreenPosOffset, self.ScreenAngleOffset, pos, ang)
        DrawSmartphoneScreen(screenPos, screenAng, self.ScreenScale, activeDrone, self)
    end

    function SWEP:AddDrawModel(WorldModel)
        if not IsValid(WorldModel) then return end

        local owner = self:GetOwner()
        if not IsValid(owner) then return end

        local activeDrone = owner:GetNWEntity("KVN_ActiveDrone")

        local boneid = owner:LookupBone("ValveBiped.Bip01_R_Hand")
        if not boneid then return end

        local matrix = owner:GetBoneMatrix(boneid)
        if not matrix then return end

        local screenPos, screenAng = LocalToWorld(self.ScreenPosOffset, self.ScreenAngleOffset, matrix:GetTranslation(), matrix:GetAngles())
        DrawSmartphoneScreen(screenPos, screenAng, self.ScreenScale, activeDrone, self)
    end
end
