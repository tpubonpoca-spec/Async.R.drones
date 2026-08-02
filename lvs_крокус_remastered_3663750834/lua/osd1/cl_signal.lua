if SERVER then AddCSLuaFile() return end

Crocus = Crocus or {}
Crocus.Entities = Crocus.Entities or {
    ["sw_crocus"] = true,
    ["sw_crocus_pg7"] = true,
    ["sw_crocus_tbg7"] = true,
}

Crocus.next_rand_noise = 0
Crocus.end_rand_noise  = 0

local next_logic_tick = 0
local GROUND_CHECK_DIST = Vector(0, 0, -200)

hook.Add("Think", "Crocus_LowPriority_Logic", function()
    local ct = CurTime()
    if ct < next_logic_tick then return end
    next_logic_tick = ct + 0.5

    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local base = Crocus.GetDroneBase and Crocus.GetDroneBase(ply) or nil
    if not IsValid(base) or base:IsDormant() then return end

    local pos = base:GetPos()
    if ct - (base.OSDStartTime or ct) <= 5 then
        base.CachedProxNoise = 0
        return
    end

    local g_tr = util.TraceLine({start = pos, endpos = pos + GROUND_CHECK_DIST, filter = base})
    local g_dist = pos:Distance(g_tr.HitPos) / 39.37
    if g_dist < 4 then
        local s = 1 - (g_dist / 4.0)
        base.CachedProxNoise = s * s * 120
    else
        base.CachedProxNoise = 0
    end
end)

local _rand_cache = 0
local _rand_next  = 0

function Crocus.UpdateNoise(base)
    local ct = CurTime()

    if not base.CachedProxNoise then base.CachedProxNoise = 0 end
    if not base.SmoothNoise     then base.SmoothNoise = 0 end

    if Crocus.next_rand_noise < ct then
        if Crocus.next_rand_noise == 0 then
            Crocus.next_rand_noise = ct + math.random(15, 30)
            _rand_cache = 0
        else
            Crocus.end_rand_noise  = ct + math.random(1, 2)
            Crocus.next_rand_noise = ct + math.random(15, 30)
        end
    end

    if ct < Crocus.end_rand_noise then
        if ct > _rand_next then
            _rand_next  = ct + 0.05
            _rand_cache = math.random(20, 50)
        end
        Crocus.RandNoiseActive = true
    else
        _rand_cache = 0
        Crocus.RandNoiseActive = false
    end

    local ground_noise_enabled = game.GetWorld():GetNWBool("Crocus_GroundNoise", true)

    local target = math.max(
        ground_noise_enabled and base.CachedProxNoise or 0,
        _rand_cache,
        ground_noise_enabled and base:GetNWInt("Crocus_Interference", 0) * 2.5 or 0
    )

    base.SmoothNoise = Lerp(FrameTime() * 2, base.SmoothNoise, target)
    return base.SmoothNoise
end