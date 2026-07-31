if SERVER then return end

Crocus2 = Crocus2 or {}

Crocus2.clr_w = Color(255, 255, 255, 255)

Crocus2.M_BAT_0   = Material("osd/0.png", "mips smooth")
Crocus2.M_BAT_1   = Material("osd/1.png", "mips smooth")
Crocus2.M_BAT_2   = Material("osd/2.png", "mips smooth")
Crocus2.M_BAT_3   = Material("osd/3.png", "mips smooth")
Crocus2.M_BAT_4   = Material("osd/4.png", "mips smooth")
Crocus2.M_BAT_5   = Material("osd/5.png", "mips smooth")
Crocus2.M_BAT_6   = Material("osd/6.png", "mips smooth")
Crocus2.M_BAT_LOW = Material("osd/bat_low.png", "mips noclamp")
Crocus2.M_SD_1    = Material("osd/sddick.png", "mips smooth")
Crocus2.M_SD_2    = Material("osd/sddick1.png", "mips smooth")
Crocus2.M_CH_1    = Material("osd/crosshair.png", "mips smooth")
Crocus2.M_WIFI    = Material("osd/wifi.png", "mips smooth")
Crocus2.M_STRELKA = Material("osd/strelka.png", "mips smooth")
Crocus2.M_VR      = Material("osd/vr.png", "mips smooth")
Crocus2.M_AIR     = Material("osd/airspd.png", "mips smooth")
Crocus2.M_GND     = Material("osd/gndspd.png", "mips smooth")
Crocus2.M_KMH     = Material("osd/kmh.png", "mips smooth")
Crocus2.M_MM      = Material("osd/mm.png", "mips smooth")
Crocus2.M_VERX    = Material("osd/verx.png", "mips smooth")
Crocus2.M_VNIZ    = Material("osd/vniz.png", "mips smooth")
Crocus2.M_P0      = Material("osd/0p.png", "mips smooth")
Crocus2.M_P1      = Material("osd/1p.png", "mips smooth")
Crocus2.M_P2      = Material("osd/2p.png", "mips smooth")
Crocus2.M_P3      = Material("osd/3p.png", "mips smooth")
Crocus2.M_P4      = Material("osd/4p.png", "mips smooth")
Crocus2.M_NOISE   = Material("effects/fpv_noise")

surface.CreateFont("Crocus2_Num", {
    font = "SF Pro Rounded",
    size = 31,
    weight = 500,
    antialias = true,
    extended = true,
})

surface.CreateFont("Crocus2_Unit", {
    font = "SF Pro Rounded",
    size = 21,
    weight = 500,
    antialias = true,
    extended = true,
})

surface.CreateFont("Crocus2_SD", {
    font = "SF Pro Rounded",
    size = 28,
    weight = 500,
    antialias = true,
    extended = true,
})

surface.CreateFont("Crocus2_Status", {
    font = "SF Pro Rounded",
    size = 32,
    weight = 500,
    antialias = true,
    extended = true,
})

surface.CreateFont("Crocus2_Micro", {
    font = "SF Pro Rounded",
    size = 14,
    weight = 500,
    antialias = true,
    extended = true,
})

local metric_cache = {}
function Crocus2.GetSpacedString(val)
    if metric_cache[val] == nil then
        metric_cache[val] = string.Trim(string.gsub(tostring(val), "(.)", "%1 "))
    end
    return metric_cache[val]
end

function Crocus2.GetBatIcon(pct)
    if pct <= 0.10 then return Crocus2.M_BAT_1 end
    if pct <= 0.30 then return Crocus2.M_BAT_2 end
    if pct <= 0.50 then return Crocus2.M_BAT_3 end
    if pct <= 0.70 then return Crocus2.M_BAT_4 end
    if pct <= 0.90 then return Crocus2.M_BAT_5 end
    return Crocus2.M_BAT_6
end
