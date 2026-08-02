ENT.Base = "lvs_base_helicopter"

ENT.PrintName = "[LVS] KVN-1"
ENT.Author = "Kortez"
ENT.Information = ""
ENT.Category = "KMI Aircraft"
ENT.IconOverride = "materials/entities/kvn1.png"

ENT.VehicleCategory = ""
ENT.VehicleSubCategory = ""

ENT.Spawnable			= true
ENT.AdminSpawnable		= false

ENT.MDL = "models/sw/avia/kvn/kvn1.mdl"

ENT.AITEAM = 2

ENT.LVSUAV = true

ENT.SpawnNormalOffset = 5
ENT.SpawnOffset = Vector(-100, 0, 0)

ENT.MaxHealth = 100

ENT.MaxVelocity = 2500

ENT.ThrustUp = 1
ENT.ThrustDown = 2
ENT.ThrustRate = 1

ENT.ThrottleRateUp = 1.5
ENT.ThrottleRateDown = 1.5

ENT.TurnRatePitch = 1
ENT.TurnRateYaw = 1
ENT.TurnRateRoll = 1

ENT.ForceLinearDampingMultiplier = 1

ENT.ForceAngleMultiplier = 1
ENT.ForceAngleDampingMultiplier = 1

ENT.EngineSounds = {
	{
		sound = "sw/kvn/kvn_idle.ogg",
		Pitch = 150,
		PitchMin = 0,
		PitchMax = 255,
		PitchMul = 100,
		Volume = 1,
		VolumeMin = 0,
		VolumeMax = 1,
		SoundLevel = 100,
		UseDoppler = true,
	},
}

local ExpSnds = {}
ExpSnds[1] = "sw/explosion/exp_tny_1.wav"
ExpSnds[2] = "sw/explosion/exp_tny_2.wav"
ExpSnds[3] = "sw/explosion/exp_tny_3.wav"

local FarExpSnds = {}
FarExpSnds[1] = "sw/explosion/exp_sml_dst_1.wav"
FarExpSnds[2] = "sw/explosion/exp_sml_dst_2.wav"
FarExpSnds[3] = "sw/explosion/exp_sml_dst_3.wav"
FarExpSnds[4] = "sw/explosion/exp_sml_dst_4.wav"
FarExpSnds[5] = "sw/explosion/exp_sml_dst_5.wav"
FarExpSnds[6] = "sw/explosion/exp_sml_dst_6.wav"
FarExpSnds[7] = "sw/explosion/exp_sml_dst_7.wav"
FarExpSnds[8] = "sw/explosion/exp_sml_dst_8.wav"

local DstExpSnds = {}
DstExpSnds[1] = "sw/explosion/exp_sml_far_1.wav"
DstExpSnds[2] = "sw/explosion/exp_sml_far_2.wav"
DstExpSnds[3] = "sw/explosion/exp_sml_far_3.wav"
DstExpSnds[4] = "sw/explosion/exp_sml_far_4.wav"
DstExpSnds[5] = "sw/explosion/exp_sml_far_5.wav"
DstExpSnds[6] = "sw/explosion/exp_sml_far_6.wav"
DstExpSnds[7] = "sw/explosion/exp_sml_far_7.wav"
DstExpSnds[8] = "sw/explosion/exp_sml_far_8.wav"

local WtrExpSnds = {}
WtrExpSnds[1] = "sw/explosion/exp_trp_1.wav"
WtrExpSnds[2] = "sw/explosion/exp_trp_2.wav"
WtrExpSnds[3] = "sw/explosion/exp_trp_3.wav"

--Visual
ENT.Effect                           =	"ins_rpg_explosion"
ENT.EffectAir                        =	"ins_rpg_explosion"
ENT.EffectWater                      =	"ins_water_explosion"
ENT.Decal							 =	"scorch_50kg"
ENT.AngEffect						 =	true
ENT.ExplosionSound                   =	table.Random(ExpSnds)
ENT.FarExplosionSound				 =	table.Random(FarExpSnds)
ENT.DistExplosionSound				 =	table.Random(DstExpSnds)
ENT.WaterExplosionSound				 =	table.Random(WtrExpSnds)
ENT.WaterFarExplosionSound			 =	table.Random(DstExpSnds)

--Explosion
ENT.TraceLength                      =	150
ENT.ExplosionDamage                  =	300
ENT.ExplosionRadius                  =	75
ENT.BlastRadius                 	 =	0
ENT.FragDamage						 =	25
ENT.FragRadius						 =	300
ENT.FragCount						 =	100

ENT.HEAT							 =	true
ENT.HEATRadius						 =	2
ENT.ArmorPenetration				 = 	50000
ENT.PenetrationDamage				 =	2500

function ENT:OnSetupDataTables()
	self:AddDT( "Bool", "Hover")
end

function ENT:InitWeapons()
	local track = {}
	track.Icon = Material("icons/tracking.png")
	track.Ammo = -1
	track.Delay = 0
	track.HeatRateUp = 0
	track.HeatRateDown = 0
	track.UseableByAI = false
	track.CalcView = function( ent, ply, pos, angles, fov, pod )
		local view = {}

		view.origin = ent:LocalToWorld( Vector(6.30, 0.25, 4.75) ) -- X вперед, Y вправо, Z вверх
		view.angles = ent:LocalToWorldAngles( Angle(0, 0, 0) ) 
		view.fov = 54
		view.drawviewer = false
		return view
	end
	self:AddWeapon( track )
end

function ENT:PlayerDirectInput( ply, cmd )
	local Pod = self:GetDriverSeat()

	local Delta = FrameTime()

	local KeyLeft = ply:lvsKeyDown( "-ROLL_HELI" )
	local KeyRight = ply:lvsKeyDown( "+ROLL_HELI" )
	local KeyPitchUp = ply:lvsKeyDown( "+PITCH_HELI" )
	local KeyPitchDown = ply:lvsKeyDown( "-PITCH_HELI" )
	local KeyRollRight = ply:lvsKeyDown( "+YAW_HELI" )
	local KeyRollLeft = ply:lvsKeyDown( "-YAW_HELI" )

	local MouseX = cmd:GetMouseX()
	local MouseY = cmd:GetMouseY()

	if ply:lvsKeyDown( "FREELOOK" ) and not Pod:GetThirdPersonMode() then
		MouseX = 0
		MouseY = 0
	else
		ply:SetEyeAngles( Angle(0,90,0) )
	end

	local SensX, SensY, ReturnDelta = ply:lvsMouseSensitivity()

	if KeyPitchDown then MouseY = (10 / SensY) * ReturnDelta end
	if KeyPitchUp then MouseY = -(10 / SensY) * ReturnDelta end
	if KeyRollRight or KeyRollLeft then
		local NewX = (KeyRollRight and 10 or 0) - (KeyRollLeft and 10 or 0)

		MouseX = (NewX / SensX) * ReturnDelta
	end

	local Input = Vector( MouseX * 0.4 * SensX, MouseY * SensY, 0 )

	local Cur = self:GetSteer()

	local Rate = Delta * 3 * ReturnDelta

	local New = Vector(Cur.x, Cur.y, 0) - Vector( math.Clamp(Cur.x * Delta * 5 * ReturnDelta,-Rate,Rate), math.Clamp(Cur.y * Delta * 5 * ReturnDelta,-Rate,Rate), 0)

	local Target = New + Input * Delta * 0.8

	local Fx = math.Clamp( Target.x, -1, 1 )
	local Fy = math.Clamp( Target.y, -1, 1 )

	local TargetFz = (KeyLeft and 1 or 0) - (KeyRight and 1 or 0)
	local Fz = Cur.z + math.Clamp(TargetFz - Cur.z,-Rate * 3,Rate * 3)

	local F = Cur + (Vector( Fx, Fy, Fz ) - Cur) * math.min(Delta * 100,1)

	self:SetSteer( F )

	if CLIENT then return end

	local Hover = self:GetHover()
	HoverSwitch = self:GetDriver():lvsKeyDown("HELI_HOVER")
	if self.OldHoverSwitch ~= HoverSwitch then
		if HoverSwitch and Hover == false then
			self:SetHover(true)
		elseif HoverSwitch and Hover == true then
			self:SetHover(false)
		end
		self.OldHoverSwitch = HoverSwitch
	end

	if self:GetHover() then
		self:CalcHover( ply:lvsKeyDown( "-YAW_HELI" ), ply:lvsKeyDown( "+YAW_HELI" ), KeyPitchUp, KeyPitchDown, ply:lvsKeyDown( "+THRUST_HELI" ), ply:lvsKeyDown( "-THRUST_HELI" ) )

		self.ResetSteer = true
	else
		if self.ResetSteer then
			self.ResetSteer = nil

			self:SetSteer( Vector(0,0,0) )
		end

		self:CalcThrust( ply:lvsKeyDown( "+THRUST_HELI" ), ply:lvsKeyDown( "-THRUST_HELI" ) )
	end
end

function ENT:PlayerMouseAim( ply, phys, deltatime )
	local Pod = self:GetDriverSeat()

	local PitchUp = ply:lvsKeyDown( "+PITCH_HELI" )
	local PitchDown = ply:lvsKeyDown( "-PITCH_HELI" )
	local YawRight = ply:lvsKeyDown( "+YAW_HELI" )
	local YawLeft = ply:lvsKeyDown( "-YAW_HELI" )
	local RollRight = ply:lvsKeyDown( "+ROLL_HELI" )
	local RollLeft = ply:lvsKeyDown( "-ROLL_HELI" )

	local FreeLook = ply:lvsKeyDown( "FREELOOK" )

	local EyeAngles = Pod:WorldToLocalAngles( ply:EyeAngles() )

	if FreeLook then
		if isangle( self.StoredEyeAngles ) then
			EyeAngles = self.StoredEyeAngles
		end
	else
		self.StoredEyeAngles = EyeAngles
	end

	local OverridePitch = 0
	local OverrideYaw = 0
	local OverrideRoll = (RollRight and 1 or 0) - (RollLeft and 1 or 0)

	if PitchUp or PitchDown then
		EyeAngles = self:GetAngles()

		self.StoredEyeAngles = Angle(EyeAngles.p,EyeAngles.y,0)

		OverridePitch = (PitchUp and 1 or 0) - (PitchDown and 1 or 0)
	end

	if YawRight or YawLeft then
		EyeAngles = self:GetAngles()

		self.StoredEyeAngles = Angle(EyeAngles.p,EyeAngles.y,0)

		OverrideYaw = (YawRight and 1 or 0) - (YawLeft and 1 or 0) 
	end

	self:ApproachTargetAngle( EyeAngles, OverridePitch, OverrideYaw, OverrideRoll, FreeLook, phys, deltatime )

	local Hover = self:GetHover()
	HoverSwitch = self:GetDriver():lvsKeyDown("HELI_HOVER")
	if self.OldHoverSwitch ~= HoverSwitch then
		if HoverSwitch and Hover == false then
			self:SetHover(true)
		elseif HoverSwitch and Hover == true then
			self:SetHover(false)
		end
		self.OldHoverSwitch = HoverSwitch
	end

	if self:GetHover() then
		self:CalcHover( RollLeft, RollRight, PitchUp, PitchDown, ply:lvsKeyDown( "+THRUST_HELI" ), ply:lvsKeyDown( "-THRUST_HELI" ), phys, deltatime )

		self.ResetSteer = true
	else
		if self.ResetSteer then
			self.ResetSteer = nilё
			self:SetSteer( Vector(0,0,0) )
		end

		self:CalcThrust( ply:lvsKeyDown( "+THRUST_HELI" ), ply:lvsKeyDown( "-THRUST_HELI" ), deltatime )
	end
end