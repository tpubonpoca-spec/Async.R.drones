if SERVER then AddCSLuaFile() return end

Crocus3 = Crocus3 or {}

Crocus3.clr_w   = Color(255, 255, 255, 255)
Crocus3.clr_grn = Color(0, 255, 0, 255)
Crocus3.clr_gry = Color(150, 150, 150, 255)

surface.CreateFont("Crocus3_Main", {
    font      = "Officermans",
    size      = 36,
    weight    = 400,
    outline   = true,
    antialias = true,
    extended  = true,
})

surface.CreateFont("Crocus3_Small", {
    font      = "Officermans",
    size      = 28,
    weight    = 400,
    outline   = true,
    antialias = true,
    extended  = true,
})

surface.CreateFont("Crocus3_Main_RU", {
    font      = "Courier New",
    size      = 36,
    weight    = 700,
    outline   = true,
    antialias = false,
    extended  = true,
})

surface.CreateFont("Crocus3_Small_RU", {
    font      = "Courier New",
    size      = 29,
    weight    = 700,
    outline   = true,
    antialias = false,
    extended  = true,
})

surface.CreateFont("Crocus3_Tri", {
    font      = "Arial",
    size      = 16,
    weight    = 700,
    outline   = true,
    antialias = false,
    extended  = true,
})

local function MakeSN()
    local sn = ""
    for i = 1, 8 do sn = sn .. math.random(0, 9) end
    return "SN:" .. sn
end

Crocus3.SN = MakeSN()

local eng_messages = {
    "fix тепл.",
    "link-ok :: RC connected :: armed",
    "motors armed :: throttle idle",
    "recording started :: seg 001",
    "batt ok :: cell avg 3.91V",
    "temp ok :: ESC 41C :: MCU 38C",
    "datalink ok :: uplink -72dBm",
    "system status: nominal",
}

local eng_idx  = 1
local eng_next = 0

function Crocus3.GetEngMsg()
    local ct = CurTime()
    if ct > eng_next then
        eng_next = ct + math.random(6, 14)
        eng_idx  = math.random(1, #eng_messages)
    end
    return eng_messages[eng_idx]
end