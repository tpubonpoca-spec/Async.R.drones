if SERVER then AddCSLuaFile() return end

Crocus = Crocus or {}
Crocus.Entities = Crocus.Entities or {
    ["sw_crocus"] = true,
    ["sw_crocus_pg7"] = true,
    ["sw_crocus_tbg7"] = true,
}
Crocus.Classes = Crocus.Classes or {
    "sw_crocus",
    "sw_crocus_pg7",
    "sw_crocus_tbg7",
}
Crocus.clr_gray = Color(180, 180, 180, 255)

surface.CreateFont("Crocus_Beta_Main", {
    font      = "VCR OSD Mono Cyr",
    size      = 24,
    weight    = 400,
    outline   = true,
    antialias = false,
    extended  = true,
})

surface.CreateFont("Crocus_Beta_Death", {
    font      = "SF Pro Rounded",
    size      = 80,
    weight    = 600,
    outline   = false,
    antialias = true,
    extended  = true,
})

local _pts = {{},{},{},{},{}}

local _black = Color(0, 0, 0, 255)
local _gray  = Color(180, 180, 180, 255)

function Crocus.DrawBox(x, y, w, h)
    x = math.floor(x); y = math.floor(y)
    w = math.floor(w); h = math.floor(h)
    surface.SetDrawColor(0, 0, 0, 255)
    surface.DrawRect(x - 1, y - 1, w + 2, h + 2)
    surface.SetDrawColor(180, 180, 180, 255)
    surface.DrawRect(x, y, w, h)
end

function Crocus.DrawOutlinedLine(x1, y1, x2, y2)
    x1 = math.floor(x1); y1 = math.floor(y1)
    x2 = math.floor(x2); y2 = math.floor(y2)
    surface.SetDrawColor(0, 0, 0, 255)
    surface.DrawLine(x1 - 1, y1, x2 - 1, y2)
    surface.DrawLine(x1 + 1, y1, x2 + 1, y2)
    surface.DrawLine(x1, y1 - 1, x2, y2 - 1)
    surface.DrawLine(x1, y1 + 1, x2, y2 + 1)
    surface.SetDrawColor(180, 180, 180, 255)
    surface.DrawLine(x1, y1, x2, y2)
end

function Crocus.DrawHollowPointer(x, y, side, text)
    local w = 70
    if side == "left" then
        _pts[1].x=x;      _pts[1].y=y
        _pts[2].x=x+15;   _pts[2].y=y-18
        _pts[3].x=x+w;    _pts[3].y=y-18
        _pts[4].x=x+w;    _pts[4].y=y+18
        _pts[5].x=x+15;   _pts[5].y=y+18
    else
        _pts[1].x=x;      _pts[1].y=y
        _pts[2].x=x-15;   _pts[2].y=y-18
        _pts[3].x=x-w;    _pts[3].y=y-18
        _pts[4].x=x-w;    _pts[4].y=y+18
        _pts[5].x=x-15;   _pts[5].y=y+18
    end
    surface.SetDrawColor(0, 0, 0, 255)
    for i = 1, 5 do
        local np = _pts[i + 1] or _pts[1]
        surface.DrawLine(_pts[i].x-1,_pts[i].y,np.x-1,np.y)
        surface.DrawLine(_pts[i].x+1,_pts[i].y,np.x+1,np.y)
        surface.DrawLine(_pts[i].x,_pts[i].y-1,np.x,np.y-1)
        surface.DrawLine(_pts[i].x,_pts[i].y+1,np.x,np.y+1)
    end
    surface.SetDrawColor(180, 180, 180, 255)
    for i = 1, 5 do
        local np = _pts[i + 1] or _pts[1]
        surface.DrawLine(_pts[i].x,_pts[i].y,np.x,np.y)
    end
    local tx = (side == "left") and (x + 42) or (x - 42)
    draw.SimpleText(text, "Crocus_Beta_Main", math.floor(tx), math.floor(y), Crocus.clr_gray, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

local LetterCache = {}

function Crocus.DrawBitmapText(text, centerX, y, size)
    if not text or text == "" then return end
    text = string.upper(text)
    local spacing    = size * 0.85
    local totalWidth = #text * spacing
    local currentX   = centerX - totalWidth * 0.5
    surface.SetDrawColor(180, 180, 180, 255)
    for i = 1, #text do
        local char = string.sub(text, i, i)
        if char == " " then
            currentX = currentX + spacing
        else
            if LetterCache[char] == nil then
                local mat = Material("iconpack/" .. char .. ".png", "noclamp smooth")
                LetterCache[char] = (not mat:IsError()) and mat or false
            end
            if LetterCache[char] then
                surface.SetMaterial(LetterCache[char])
                surface.DrawTexturedRect(currentX, y, size, size)
            end
            currentX = currentX + spacing
        end
    end
end