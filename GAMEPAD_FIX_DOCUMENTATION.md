# 🛠️ Руководство по полной самостоятельной настройке и фиксу пульта для Garry's Mod (Z-City / TPIK1)

В этом документе разобраны **все 3 ошибки из вашего лога консоли**, с подробным объяснением причин и пошаговыми инструкциями для решения в Blender, VTFEdit и GLua.

---

## 📌 Оглавление
1. [Ошибка 1: Error reading texture header (VTF Заголовок)](#1-ошибка-1-error-reading-texture-header)
2. [Ошибка 2: Bad pstudiohdr in GetSequenceLinearMotion()](#2-ошибка-2-bad-pstudiohdr-in-getsequencelinearmotion)
3. [Ошибка 3: Пустота в руках / Модель улетает (TPIK1 Z-City)](#3-ошибка-3-пустота-в-руках--привязка-в-z-city)
4. [Пошаговый чеклист компиляции и экспорта из Blender](#4-пошаговый-чеклист-экспорта-и-компиляции)

---

## 1. 🔴 Ошибка 1: `Error reading texture header`

### 💡 Причина:
Движок Source Engine требует строгого бинарного формата файлов `.vtf`:
- Заголовок точно **64 байта**.
- Поддерживаемые версии VTF: **7.2** или **7.4**.
- Размеры текстуры должны быть краш-безопасными степенями двойки (**128x128**, **256x256**, **512x512**, **1024x1024**, **2048x2048**).
- Флаги `TEXTUREFLAGS_NOMIP` (0x0200) и `TEXTUREFLAGS_NOLOD` (0x02000).

Если заголовок повредился или конвертирован со смещением байтов, движок выбивает `Error reading texture header` и отказывается отрисовывать объект (модель становится невидимой или показывает розовую шахматку).

### 🛠️ Как исправить через VTFEdit / VTFCmd:
1. Откройте **VTFEdit** (или утилиту `VTFCmd.exe`).
2. Нажмите **File ➔ Import** и выберите PNG текстуры вашего геймпада из папки `C:\Users\PMC\Documents\gampad\textures\`.
3. В окне импорта установите настройки:
   - **Normal Format**: `DXT1` (для текстур без прозрачности) или `DXT5` (если есть прозрачность).
   - **Resize**: `Nearest Power of 2`.
   - **Generate Mipmaps**: `Checked`.
4. Нажмите **File ➔ Save As** и сохраните файлы в папку аддона:  
   `garrysmod/addons/zAsync/materials/models/weapons/async_gamepad/`
5. Создайте `.vmt` файл с тем же именем (например `material.vmt`):
   ```vmt
   "VertexLitGeneric"
   {
       "$basetexture" "models/weapons/async_gamepad/material"
       "$surfaceprop" "plastic"
       "$model" "1"
   }
   ```

---

## 2. 🔴 Ошибка 2: `Bad pstudiohdr in GetSequenceLinearMotion()`

### 💡 Причина:
Эта ошибка возникает, когда в Garry's Mod бинарные файлы модели рассинхронизированы:
- `v_async_gamepad.mdl` и `w_async_gamepad.mdl` имеют **разные чексуммы** (Checksum) или разное количество анимационных секвенций.
- Когда скрипт SWEP переключается между видом от 1-го лица (ViewModel) и 3-го лица (WorldModel), движок видит расхождение в структуре костей/секвенций и выдаёт `Bad pstudiohdr`.

### 🛠️ Как исправить:
Обе модели (`v_async_gamepad` и `w_async_gamepad`) должны компилироваться из одного файла `.qc` или иметь 100% одинаковые файлы `.mdl`, `.vvd`, `.dx90.vtx`.

1. В вашей папке исхода (`gamepad_src`) создайте единый `gampad.qc`:
   ```qc
   $modelname "weapons/w_async_gamepad.mdl"
   $body "body" "anims/gampad_opt.smd"
   $cdmaterials "models/weapons/async_gamepad/"
   $surfaceprop "weapon"
   $scale 1.0
   $sequence "idle" {
       "anims/gampad_opt.smd"
       fps 30
   }
   $collisionmodel "anims/gampad_opt.smd" {
       $mass 1.5
   }
   ```
2. Скомпилируйте модель через `studiomdl.exe`:
   ```powershell
   & "C:\Program Files (x86)\Steam\steamapps\common\GarrysMod\bin\studiomdl.exe" -game "C:\Program Files (x86)\Steam\steamapps\common\GarrysMod\garrysmod" "c:\Users\PMC\Desktop\Zdrone-dev\gamepad_src\gampad.qc"
   ```
3. Скопируйте скомпилированные файлы `w_async_gamepad.*` поверх `v_async_gamepad.*`, чтобы гарантировать идентичные чексуммы:
   ```powershell
   Copy-Item "w_async_gamepad.mdl" "v_async_gamepad.mdl" -Force
   Copy-Item "w_async_gamepad.vvd" "v_async_gamepad.vvd" -Force
   Copy-Item "w_async_gamepad.dx90.vtx" "v_async_gamepad.dx90.vtx" -Force
   ```

---

## 3. 🔴 Ошибка 3: Настройка рук в Z-City (TPIK1)

### 💡 Как работает система TPIK в Z-City:
В модификации Z-City оружие **не использует стандартные c_arms или старый ViewModel**.  
Все устройства (планшет `weapon_spawnmenu_pda`, рация `weapon_walkie_talkie`) работают на базе **TPIK1** (`weapon_tpik1_base`):
- `SWEP.Base = "weapon_tpik1_base"` — отвечает за IK-привязку кистей рук персонажа.
- `SWEP.WorldModel = "models/weapons/w_async_gamepad.mdl"` — основная модель.
- `SWEP.ViewModel = "models/weapons/v_async_gamepad.mdl"` — модель от 1-го лица.
- `SWEP.offsetVec = Vector(X, Y, Z)` — смещение модели относительно кисти правой руки (`ValveBiped.Bip01_R_Hand`).
- `SWEP.offsetAng = Angle(P, Y, R)` — повороты модели (Pitch, Yaw, Roll).

### 🛠️ Настройка файла `lua/weapons/weapon_async_gamepad.lua`:
```lua
if SERVER then AddCSLuaFile() end

SWEP.Base = "weapon_tpik1_base"
SWEP.PrintName = "НСУ Пульт Дронов"
SWEP.Author = "zAsync"
SWEP.Category = "ZCity Other"

SWEP.Spawnable = true
SWEP.AdminSpawnable = true

SWEP.ViewModel = "models/weapons/v_async_gamepad.mdl"
SWEP.WorldModel = "models/weapons/w_async_gamepad.mdl"
SWEP.HoldType = "slam"

-- TPIK включение IK-рук для левой и правой кисти
SWEP.setrhik = true
SWEP.setlhik = true

-- Позиционирование рук Z-City
SWEP.LHPos = Vector(0, -6.6, 0)
SWEP.LHAng = Angle(0, 0, 180)

SWEP.RHPosOffset = Vector(0, 0, -7.6)
SWEP.RHAngOffset = Angle(0, 15, -90)

SWEP.LHPosOffset = Vector(0, 0, -0.4)
SWEP.LHAngOffset = Angle(5, 0, 15)

-- Точное смещение пульта относительно руки (можно регулировать)
SWEP.offsetVec = Vector(5, -7, -1)
SWEP.offsetAng = Angle(0, 90, 195)

-- ConVars для подстройки в реальном времени через консоль
if CLIENT then
    CreateClientConVar("async_gp_ox", "5", true, false, "Offset Forward")
    CreateClientConVar("async_gp_oy", "-7", true, false, "Offset Right")
    CreateClientConVar("async_gp_oz", "-1", true, false, "Offset Up")
    CreateClientConVar("async_gp_ap", "0", true, false, "Angle Pitch")
    CreateClientConVar("async_gp_ay", "90", true, false, "Angle Yaw")
    CreateClientConVar("async_gp_ar", "195", true, false, "Angle Roll")
end

function SWEP:Think()
    if self:GetHoldType() ~= self.HoldType then
        self:SetHoldType(self.HoldType)
    end

    if CLIENT then
        self.offsetVec = Vector(
            GetConVar("async_gp_ox"):GetFloat(),
            GetConVar("async_gp_oy"):GetFloat(),
            GetConVar("async_gp_oz"):GetFloat()
        )
        self.offsetAng = Angle(
            GetConVar("async_gp_ap"):GetFloat(),
            GetConVar("async_gp_ay"):GetFloat(),
            GetConVar("async_gp_ar"):GetFloat()
        )
    end

    self:AddThink()
end

if CLIENT then
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

        local screenPos, screenAng = LocalToWorld(Vector(3.4, -2.22, 3.57), Angle(-5, -18.5, 91), pos, ang)
        DrawSmartphoneScreen(screenPos, screenAng, 0.025, activeDrone, self)
    end
end
```

---

## 4. ⚙️ Чеклист экспорта из Blender (Blender Source Tools)

Если вы экспортируете модель из Blender вручную:

1. Установите аддон **Blender Source Tools** (или `io_scene_valvesource`).
2. В окне **Scene Properties ➔ Source Engine Export**:
   - **Export Format**: `SMD`.
   - **Target Engine**: `Branch Source (Garry's Mod / HL2)`.
3. Убедитесь, что Арматура называется `8d7a3f28ba34eb5_skeleton` или `ValveBiped`, и меш геймпада привязан к костям через `Vertex Groups`.
4. Нажмите **Export ➔ SMD File**.
5. Запустите `studiomdl.exe` и скопируйте скомпилированные `.mdl` файлы в `garrysmod/addons/zAsync/models/weapons/`.

---

### 💡 Резюме доступных команд подстройки в консоли игры:
- `async_gp_ox [значение]` — сместить геймпад вперёд/назад.
- `async_gp_oy [значение]` — сместить геймпад вправо/влево.
- `async_gp_oz [значение]` — сместить геймпад вверх/вниз.
- `async_gp_ap [значение]` — наклон Pitch.
- `async_gp_ay [значение]` — поворот Yaw.
- `async_gp_ar [значение]` — крен Roll.
