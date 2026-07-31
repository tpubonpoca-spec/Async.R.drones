function LVS:CalcView( vehicle, ply, pos, angles, fov, pod )
	local view = {}
	view.origin = pos
	view.angles = angles
	view.fov = fov
	view.drawviewer = false

	if not pod:GetThirdPersonMode() then return view end

	local mn = vehicle:OBBMins()
	local mx = vehicle:OBBMaxs()
	local radius = ( mn - mx ):Length()
	local radius = radius + radius * pod:GetCameraDistance()

	local TargetOrigin = view.origin + ( view.angles:Forward() * -radius ) + view.angles:Up() * radius * pod:GetCameraHeight()
	local WallOffset = 4

	local tr = util.TraceHull( {
		start = view.origin,
		endpos = TargetOrigin,
		filter = function( e )
			local c = e:GetClass()
			local collide = not c:StartWith( "prop_physics" ) and not c:StartWith( "prop_dynamic" ) and not c:StartWith( "prop_ragdoll" ) and not e:IsVehicle() and not c:StartWith( "gmod_" ) and not c:StartWith( "lvs_" ) and not c:StartWith( "player" ) and not e.LVS

			return collide
		end,
		mins = Vector( -WallOffset, -WallOffset, -WallOffset ),
		maxs = Vector( WallOffset, WallOffset, WallOffset ),
	} )

	view.origin = tr.HitPos
	view.drawviewer = true

	if tr.Hit and  not tr.StartSolid then
		view.origin = view.origin + tr.HitNormal * WallOffset
	end

	return view
end

hook.Add( "CalcView", "!!!!LVS_calcview", function(ply, pos, angles, fov)
	if ply:GetViewEntity() ~= ply then return end

	local pod = ply:GetVehicle()
	local vehicle = ply:lvsGetVehicle()

	if not IsValid( pod ) or not IsValid( vehicle ) then return end

	local newfov = vehicle:LVSCalcFov( fov, ply )

	local isDrone = vehicle.LVSUAV or vehicle.IsDrone or vehicle.IsCrocusKamikaze or vehicle.IsKVNDrone or (vehicle:GetClass() and (vehicle:GetClass():lower():find("crocus") or vehicle:GetClass():lower():find("kvn") or vehicle:GetClass():lower():find("drone") or vehicle:GetClass():lower():find("uav")))

	if isDrone and not pod:GetThirdPersonMode() then
		local base = pod:lvsGetWeapon()
		local weapon = IsValid(base) and base:GetActiveWeapon() or vehicle:GetActiveWeapon()

		if weapon and weapon.CalcView then
			local v = weapon.CalcView( vehicle, ply, pos, angles, newfov, pod )
			if istable(v) then
				v.angles = vehicle:GetAngles()
				v.drawviewer = false
				return ply:lvsSetView( v )
			end
		end

		local v = {}
		local camAtt = vehicle:LookupAttachment("camera")
		if camAtt == 0 then camAtt = vehicle:LookupAttachment("eyes") end
		if camAtt == 0 then camAtt = vehicle:LookupAttachment("fpv") end
		
		if camAtt and camAtt > 0 then
			local att = vehicle:GetAttachment(camAtt)
			if att then v.origin = att.Pos end
		end
		if not v.origin then
			v.origin = vehicle:LocalToWorld( Vector(15, 0, 4) )
		end
		v.angles = vehicle:GetAngles()
		v.fov = newfov
		v.drawviewer = false
		return ply:lvsSetView( v )
	end

	local base = pod:lvsGetWeapon()

	if IsValid( base ) then
		local weapon = base:GetActiveWeapon()

		if base:IsAimVectorUnlocked() then
			angles = ply:EyeAngles()
		end

		if weapon and weapon.CalcView then
			return ply:lvsSetView( weapon.CalcView( base, ply, pos, angles, newfov, pod ) )
		else
			return ply:lvsSetView( vehicle:LVSCalcView( ply, pos, angles, newfov, pod ) )
		end
	else
		local weapon = vehicle:GetActiveWeapon()

		if weapon and weapon.CalcView then
			return ply:lvsSetView( weapon.CalcView( vehicle, ply, pos, angles, newfov, pod ) )
		else
			return ply:lvsSetView( vehicle:LVSCalcView( ply, pos, angles, newfov, pod ) )
		end
	end
end )
