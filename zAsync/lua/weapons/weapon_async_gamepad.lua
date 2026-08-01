--[[
    SWEP Пульта Управления Дронами (Async Gamepad)
    Файл: lua/weapons/weapon_async_gamepad.lua

    Портативный пульт управления с экраном смартфона.
    Позволяет вызывать экран выбора и запуска дронов KVN (ЛКМ / F6).
--]]

if SERVER then
    AddCSLuaFile()
end

SWEP.Base = "weapon_base"

SWEP.PrintName = "НСУ Пульт Дронов"
SWEP.Author = "zAsync"
SWEP.Instructions = "ЛКМ или F6: Открыть экран выбора и запуска дронов.\nПКМ: Переключение тепловизора FLIR.\nR: Проверка статуса связи с дроном."
SWEP.Category = "ZCity Other"

SWEP.Spawnable = true
SWEP.AdminSpawnable = true
SWEP.AdminOnly = false

SWEP.ViewModel = ""
SWEP.WorldModel = "models/weapons/w_async_gamepad.mdl"

if CLIENT then
    SWEP.WepSelectIcon = Material("entities/async_gamepad.png")
    SWEP.WepSelectIcon2 = Material("entities/async_gamepad.png")
    SWEP.IconOverride = "entities/async_gamepad.png"
    SWEP.BounceWeaponIcon = false
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
