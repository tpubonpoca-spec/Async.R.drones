AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

util.AddNetworkString("KVN_Net_Explode")
util.AddNetworkString("KVN_Net_BatSync")

local KVN_FLIGHT_LIMIT = 180
local kvn_next_think   = 0
local KVN_GroundPos    = {}

local kvn_entities = {
	["lvs_kvn1"] = true,
	["lvs_kvn2"] = true,
        ["lvs_kvn3"] = true,
}

local kvn_active = {}

hook.Add("OnEntityCreated", "KVN_TrackEntities", function(ent)
	timer.Simple(0, function()
		if IsValid(ent) and kvn_entities[ent:GetClass()] then
			kvn_active[ent] = true
		end
	end)
end)

hook.Add("EntityRemoved", "KVN_UntrackEntities", function(ent)
	kvn_active[ent] = nil
end)

hook.Add("EntityTakeDamage", "KVN_IncreaseBulletDamage", function(target, dmginfo)
	if not IsValid(target) or not kvn_entities[target:GetClass()] then return end
	if dmginfo:IsDamageType(DMG_BULLET) or dmginfo:IsDamageType(DMG_BUCKSHOT) then
		dmginfo:ScaleDamage(12)
	end
end)

hook.Add("Think", "KVN_TrackGroundPos", function()
	for _, ply in ipairs(player.GetAll()) do
		if ply:IsOnGround() and not IsValid(ply:GetVehicle()) then
			KVN_GroundPos[ply] = ply:GetPos()
		end
	end
end)

hook.Add("EntityRemoved", "KVN_RestorePilotPos", function(ent)
	if not IsValid(ent) or not kvn_entities[ent:GetClass()] then return end
	local ply = ent:GetDriver()
	if not IsValid(ply) then ply = ent.LastDriver end
	if IsValid(ply) and KVN_GroundPos[ply] then
		local pos = KVN_GroundPos[ply]
		timer.Simple(0, function()
			if IsValid(ply) then
				ply:SetPos(pos)
			end
		end)
	end
end)

function ENT:UpdateTransmitState()
	return TRANSMIT_ALWAYS
end

function ENT:OnSpawn(PObj)
	self:SetlvsLockedStatus(true)
	PObj:SetMass(100)

	kvn_active[self] = true

	local vOut = Vector(-16, 0, 0)

	local DriverSeat = self:AddDriverSeat(Vector(0,0,0), Angle(0,-90,0))
	DriverSeat.HidePlayer = true

	self:AddEngineSound(Vector(0,0,0))

	self.Rotor = self:AddRotor(Vector(0,0,0), Angle(0,0,0), 14, -4000)
	self.Rotor:SetRotorEffects(true)
	self.Rotor:SetHP(5)
	function self.Rotor:OnDestroyed(base)
		base:DestroyEngine()
		self:EmitSound("physics/metal/metal_box_break2.wav")
	end

	self.UAVControl = ents.Create("sw_uav_control")
	if not IsValid(self.UAVControl) then return end
	self.UAVControl:SetPos(self:LocalToWorld(Vector(0,-25,0)))
	self.UAVControl:SetAngles(self:GetAngles())
	self.UAVControl:Spawn()
	self.UAVControl:Activate()
	self.UAVControl:SetNWEntity("UAV", self)
	self:SetNWEntity("UAVControl", self.UAVControl)
	self:DeleteOnRemove(self.UAVControl)

	local Connect = constraint.Rope(self, self.UAVControl, 0, 0, vOut, Vector(0,0,5), 30000, 0, 0.5, 0.1, "cable/cable2")
	if IsValid(Connect) then
		Connect:SetColor(Color(150, 150, 150, 255))
	end
	self:SetNWEntity("Connect", Connect)

	self:SetNWFloat("KVN_BatteryPct", 1)
	self:SetNWFloat("KVN_mAh", 0)
	self:SetNWBool("KVN_FLIR", false)
	self.KVN_Battery     = 1.0
	self.KVN_LastThink   = CurTime()
	self.KVN_NextBatSync = 0
end

function ENT:OnTick()
	local p = self:GetPos()
	if p.z < -32000 or p.z > 32000 or math.abs(p.x) > 32000 or math.abs(p.y) > 32000 then
		self:Remove()
		return
	end

	if self:GetEngineActive() and not IsValid(self:GetNWEntity("Connect")) then
		self:SetEngineActive(false)
	end
end

hook.Add("KeyPress", "KVN_Controls", function(ply, key)
	if key ~= IN_ATTACK and key ~= IN_ATTACK2 then return end
	local veh = ply:GetVehicle()
	if not IsValid(veh) then return end
	local ent = veh:GetNWEntity("LVS_Entity")
	if not IsValid(ent) then ent = veh:GetParent() end
	if not IsValid(ent) or not kvn_entities[ent:GetClass()] then return end

	if key == IN_ATTACK then
		net.Start("KVN_Net_Explode")
		net.WriteVector(ent:GetPos())
		net.Broadcast()
		if ent.Explode then ent:Explode() end
	elseif key == IN_ATTACK2 then
		local current = ent:GetNWBool("KVN_FLIR", false)
		ent:SetNWBool("KVN_FLIR", not current)
		if not current then
			ent:EmitSound("sw/misc/switch_on.mp3")
			ent:EmitSound("sw/misc/nv_on.wav")
		else
			ent:EmitSound("sw/misc/switch_off.mp3")
			ent:EmitSound("sw/misc/nv_off.wav")
		end
	end
end)

hook.Add("Think", "KVN_Battery_Think", function()
	local ct = CurTime()
	if ct < kvn_next_think then return end
	kvn_next_think = ct + 0.25

	for ent in pairs(kvn_active) do
		if not IsValid(ent) then
			kvn_active[ent] = nil
			continue
		end

		if not ent:GetEngineActive() then
			ent.KVN_LastThink = ct
			continue
		end

		if not ent.KVN_LastThink then
			ent.KVN_LastThink   = ct
			ent.KVN_Battery     = 1.0
			ent.KVN_NextBatSync = 0
			ent.KVN_mAh         = 0
			ent:SetNWFloat("KVN_BatteryPct", 1)
			ent:SetNWFloat("KVN_mAh", 0)
			continue
		end

		local dt = ct - ent.KVN_LastThink
		ent.KVN_LastThink = ct

		ent.KVN_Battery = math.Clamp(ent.KVN_Battery - dt / KVN_FLIGHT_LIMIT, 0, 1)

		local throttle = ent:GetThrottle() or 0
		ent.KVN_mAh = (ent.KVN_mAh or 0) + (throttle * 30 + 15) * dt

		if ct > ent.KVN_NextBatSync then
			ent.KVN_NextBatSync = ct + 2.0
			ent:SetNWFloat("KVN_BatteryPct", ent.KVN_Battery)
			ent:SetNWFloat("KVN_mAh", ent.KVN_mAh)
		end

		if ent.KVN_Battery <= 0 then
			ent:SetEngineActive(false)
		end
	end
end)

function ENT:Explode()
	if self.ExplodedAlready then return end
	self.ExplodedAlready = true
	local Driver = self:GetDriver()
	if IsValid(Driver) then
		self.LastDriver = Driver
		Driver:ExitVehicle()
	end
	self:OnFinishExplosion()
end

function ENT:OnFinishExplosion()
	local angle_reg = Angle(0,0,0)
	local angle_dif = Angle(-90,0,0)
	local pos = self:LocalToWorld(self:OBBCenter())

	local ctrl = self.UAVControl
	if IsValid(ctrl) then
		local ctrlPos = ctrl:GetPos()
		local anchorDrone = ents.Create("prop_physics")
		local anchorCtrl  = ents.Create("prop_physics")

		if IsValid(anchorDrone) and IsValid(anchorCtrl) then
			anchorDrone:SetPos(pos)
			anchorDrone:SetModel("models/props_junk/rock001a.mdl")
			anchorDrone:Spawn()
			anchorDrone:SetNoDraw(true)
			anchorDrone:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
			
			anchorCtrl:SetPos(ctrlPos)
			anchorCtrl:SetModel("models/props_junk/rock001a.mdl")
			anchorCtrl:Spawn()
			anchorCtrl:SetNoDraw(true)
			anchorCtrl:SetCollisionGroup(COLLISION_GROUP_DEBRIS)

			local DeadConnect = constraint.Rope(anchorDrone, anchorCtrl, 0, 0, Vector(0,0,0), Vector(0,0,5), 30000, 0, 0.5, 0.1, "cable/cable2")
			if IsValid(DeadConnect) then
				DeadConnect:SetColor(Color(150, 150, 150, 255))
			end

			SafeRemoveEntityDelayed(anchorDrone, 60)
			SafeRemoveEntityDelayed(anchorCtrl, 60)
		end
	end

	if self:WaterLevel() >= 1 then
		local tr = util.TraceLine({start = pos, endpos = pos + Vector(0,0,9000), filter = self})
		local tr2 = util.TraceLine({start = tr.HitPos, endpos = tr.HitPos - Vector(0,0,9000), filter = self, mask = MASK_WATER + CONTENTS_TRANSLUCENT})
		if tr2.Hit then
			ParticleEffect(self.EffectWater, tr2.HitPos, (self.AngEffect and angle_dif or angle_reg), nil)
		end
	else
		local tr = util.TraceLine({start = pos, endpos = pos - Vector(0, 0, self.TraceLength), filter = self})
		if tr.HitWorld then
			ParticleEffect(self.Effect, pos, (self.AngEffect and angle_dif or angle_reg), nil)
		else
			ParticleEffect(self.EffectAir, pos, (self.AngEffect and angle_dif or angle_reg), nil)
		end
	end

	if self.HEAT then
		local heat = {}
		heat.Src      = self:GetPos()
		heat.Dir      = self:GetAngles():Forward()
		heat.Spread   = Vector(0,0,0)
		heat.Force    = self.ArmorPenetration + math.Rand(-self.ArmorPenetration/10, self.ArmorPenetration/10)
		heat.HullSize = self.HEATRadius or 0
		heat.Damage   = self.PenetrationDamage + math.Rand(-self.PenetrationDamage/5, self.PenetrationDamage/5)
		heat.Velocity = 16000
		heat.Attacker = self.Owner
		LVS:FireBullet(heat)
		if self.ExplosionRadius > 0 then
			util.BlastDamage(self, ((IsValid(self:GetCreator()) and self:GetCreator()) or self.Attacker or game.GetWorld()), pos, self.ExplosionRadius, self.ExplosionDamage)
			self:BlastDoors(self, pos, 10)
		end
		if self.FragCount > 0 then
			self:Fragmentation(self, pos, 10000, self.FragDamage, self.FragRadius, ((IsValid(self:GetCreator()) and self:GetCreator()) or self.Attacker or game.GetWorld()))
		end
	else
		if self.ExplosionRadius > 0 then
			for k, v in pairs(ents.FindInSphere(pos, self.ExplosionRadius)) do
				if v:IsValid() and not v.SWBombV3 then
					local dmg = DamageInfo()
					dmg:SetInflictor(self)
					dmg:SetDamage(self.ExplosionDamage)
					dmg:SetDamageType(self.DamageType)
					dmg:SetAttacker((IsValid(self:GetCreator()) and self:GetCreator()) or self.Attacker or game.GetWorld())
					v:TakeDamageInfo(dmg)
				end
			end
		end
		if self.BlastRadius > 0 then
			util.BlastDamage(self, ((IsValid(self:GetCreator()) and self:GetCreator()) or self.Attacker or game.GetWorld()), pos, self.BlastRadius, self.ExplosionDamage/2)
			self:BlastDoors(self, pos, 10)
		end
		if self.FragCount > 0 then
			self:Fragmentation(self, pos, 10000, self.FragDamage, self.FragRadius, ((IsValid(self:GetCreator()) and self:GetCreator()) or self.Attacker or game.GetWorld()))
		end
	end

	if swv3 and swv3.CreateSound then
		swv3.CreateSound(pos, false, self.ExplosionSound, self.FarExplosionSound, self.DistExplosionSound)
	else
		sound.Play(self.ExplosionSound, pos, 140, 100, 1)
	end

	timer.Simple(0, function()
		if not IsValid(self) then return end
		self:Remove()
	end)
end

function ENT:IsDoor(ent)
	local Class = ent:GetClass()
	return (Class == "prop_door") or (Class == "prop_door_rotating") or (Class == "func_door") or (Class == "func_door_rotating")
end

function ENT:BlastDoors(blaster, pos, power, range, ignoreVisChecks)
	for k, door in pairs(ents.FindInSphere(pos, 40 * power * (range or 1))) do
		if self:IsDoor(door) then
			local proceed = ignoreVisChecks
			if not proceed then
				local tr = util.QuickTrace(pos, door:LocalToWorld(door:OBBCenter()) - pos, blaster)
				proceed = IsValid(tr.Entity) and (tr.Entity == door)
			end
			if proceed then
				self:BlastDoor(door, (door:LocalToWorld(door:OBBCenter()) - pos):GetNormalized() * 1000)
			end
		end
		if door:GetClass() == "func_breakable_surf" then door:Fire("Break") end
	end
end

function ENT:BlastDoor(ent, vel)
	local Moddel, Pozishun, Ayngul, Muteeriul, Skin = ent:GetModel(), ent:GetPos(), ent:GetAngles(), ent:GetMaterial(), ent:GetSkin()
	sound.Play("Wood_Crate.Break", Pozishun, 60, 100)
	sound.Play("Wood_Furniture.Break", Pozishun, 60, 100)
	ent:Fire("unlock", "", 0)
	ent:Fire("open", "", 0)
	ent:SetNoDraw(true)
	ent:SetNotSolid(true)
	if Moddel and Pozishun and Ayngul then
		local Replacement = ents.Create("prop_physics")
		Replacement:SetModel(Moddel)
		Replacement:SetPos(Pozishun + Vector(0, 0, 1))
		Replacement:SetAngles(Ayngul)
		if Muteeriul then Replacement:SetMaterial(Muteeriul) end
		if Skin then Replacement:SetSkin(Skin) end
		Replacement:SetModelScale(.9, 0)
		Replacement:Spawn()
		Replacement:Activate()
		if vel then
			Replacement:GetPhysicsObject():SetVelocity(vel)
			timer.Simple(0, function()
				if IsValid(Replacement) then
					Replacement:GetPhysicsObject():ApplyForceCenter(vel * 100)
				end
			end)
		end
		timer.Simple(3, function()
			if IsValid(Replacement) then Replacement:SetCollisionGroup(COLLISION_GROUP_WEAPON) end
		end)
		timer.Simple(30, function()
			if IsValid(ent) then
				ent:SetNotSolid(false)
				ent:SetNoDraw(false)
			end
			if IsValid(Replacement) then Replacement:Remove() end
		end)
	end
end

function ENT:Fragmentation(shooter, origin, fragNum, fragDmg, fragMaxDist, attacker, direction, spread, zReduction)
	shooter    = shooter or game.GetWorld()
	zReduction = zReduction or 2
	local Spred = Vector(0, 0, 0)
	local BulletsFired, MaxBullets, disperseTime = 0, self.FragCount, .5
	if fragNum >= 12000 then disperseTime = 2
	elseif fragNum >= 6000 then disperseTime = 1 end
	for i = 1, fragNum do
		timer.Simple((i / fragNum) * disperseTime, function()
			local Dir
			if direction and spread then
				Dir = Vector(direction.x, direction.y, direction.z)
				Dir = Dir + VectorRand() * math.Rand(0, spread)
				Dir:Normalize()
			else
				Dir = VectorRand()
			end
			if zReduction then
				Dir.z = Dir.z / zReduction
				Dir:Normalize()
			end
			local Tr = util.QuickTrace(origin, Dir * fragMaxDist, shooter)
			if Tr.Hit and not Tr.HitSky and not Tr.HitWorld and (BulletsFired < MaxBullets) then
				local LowFrag = (Tr.Entity.IsVehicle and Tr.Entity:IsVehicle()) or Tr.Entity.LFS or Tr.Entity.LVS or Tr.Entity.EZlowFragPlease
				if (not LowFrag) or (LowFrag and math.random(1, 4) == 2) then
					local firer = (IsValid(shooter) and shooter) or game.GetWorld()
					firer:FireBullets({
						Attacker = attacker,
						Damage   = fragDmg,
						Force    = fragDmg / 8,
						Num      = 1,
						Src      = origin,
						Tracer   = 0,
						Dir      = Dir,
						Spread   = Spred,
						AmmoType = "Buckshot"
					})
					BulletsFired = BulletsFired + 1
				end
			end
		end)
	end
end

function ENT:PhysicsCollide(data, physobj)
	local HitEnt = data.HitEntity
	if not IsValid(HitEnt) and util.GetSurfacePropName(data.TheirSurfaceProps) == "default_silent" then
		if self:OnSkyCollide(data, physobj) then return end
	end
	if self:IsDestroyed() then self.MarkForDestruction = true end
	if self:OnCollision(data, physobj) then return end
	self:PhysicsStartScrape(self:WorldToLocal(data.HitPos), data.HitNormal)
	if IsValid(HitEnt) then
		if HitEnt:IsPlayer() or HitEnt:IsNPC() then return end
	end
	if self:GetAI() and not self:IsPlayerHolding() then
		if self:WaterLevel() >= self.WaterLevelDestroyAI then
			self:SetDestroyed(true)
			self.MarkForDestruction = true
			return
		end
		self:TakeCollisionDamage(data.OurOldVelocity:Length() - data.OurNewVelocity:Length(), HitEnt)
		return
	end
	if data.Speed > 150 and data.DeltaTime > 0.2 then
		local VelDif = data.OurOldVelocity:Length() - data.OurNewVelocity:Length()
		self:CalcPDS(data)
		local effectdata = EffectData()
		effectdata:SetOrigin(data.HitPos)
		util.Effect("lvs_physics_impact", effectdata, true, true)
		self:EmitSound("lvs/physics/impact_hard.wav", 75, 95 + math.min(VelDif / 1000, 1) * 10, math.min(VelDif / 800, 1))
		self:TakeCollisionDamage(VelDif, HitEnt)
	end
end