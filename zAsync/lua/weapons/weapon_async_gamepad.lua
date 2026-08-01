--[[
    SWEP Пульта Управления Дронами (Async Gamepad)
    Файл: lua/weapons/weapon_async_gamepad.lua

    Позволяет игроку держать портативный НСУ-пульт в руках,
    вызывать экран выбора и запуска дронов (F6 / ЛКМ) и
    управлять подключёнными FPV-дронами KVN.
--]]

if SERVER then
    AddCSLuaFile()
end

SWEP.Base = "homigrad_base"

SWEP.PrintName = "НСУ Пульт Дронов"
SWEP.Author = "zAsync"
SWEP.Instructions = "ЛКМ: Открыть экран выбора и запуска дронов.\nПКМ: Переключение режимов.\nR: Проверка связи с дроном."
SWEP.Category = "Weapons - Equipment"

SWEP.Spawnable = true
SWEP.AdminOnly = false

SWEP.ViewModel = ""
SWEP.WorldModel = "models/weapons/w_async_gamepad.mdl"

SWEP.WepSelectIcon2 = Material("entities/async_gamepad.png")
SWEP.IconOverride = "entities/async_gamepad.png"

SWEP.weight = 1.2
SWEP.weaponInvCategory = 5
SWEP.ScrappersSlot = "Equipment"

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

SWEP.Slot = 4
SWEP.SlotPos = 5
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = false
SWEP.HoldType = "slam"

SWEP.ZoomPos = Vector(-2, 2, 2)
SWEP.RHandPos = Vector(-4, -2, 1)
SWEP.LHandPos = Vector(-4, 2, 1)

SWEP.DeploySnd = {"homigrad/weapons/draw_pistol.mp3", 55, 100, 110}
SWEP.HolsterSnd = {"homigrad/weapons/holster_pistol.mp3", 55, 100, 110}

function SWEP:Initialize()
    self:SetHoldType(self.HoldType)
end

function SWEP:PrimaryAttack()
    self:SetNextPrimaryFire(CurTime() + 0.5)

    if CLIENT then
        -- Открытие экрана выбора дрона
        if ASYNC_UI then
            ASYNC_UI.IsOpen = not ASYNC_UI.IsOpen
            gui.EnableScreenClicker(ASYNC_UI.IsOpen)
        end
    end
end

function SWEP:SecondaryAttack()
    self:SetNextSecondaryFire(CurTime() + 0.5)

    if CLIENT then
        -- Переключение тепловизора на активном дроне, если есть
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
