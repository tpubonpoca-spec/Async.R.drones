# zAsync — Единый монолитный аддон с FPV-дронами LVS и Async Gamepad

Модифицированная сборка **Z-City** со встроенной полной поддержкой оптоволоконных FPV-дронов LVS и нового интерактивного пульта управления **Async Gamepad**.

---

## 📁 Файлы используемой 3D-модели пульта

### Скомпилированные файлы модели (в проекте `zAsync`):
- 📦 [w_async_gamepad.mdl](file:///c:/Users/PMC/Desktop/Zdrone-dev/zAsync/models/weapons/w_async_gamepad.mdl) — заголовок и геометрия 3D-модели
- 📦 [w_async_gamepad.vvd](file:///c:/Users/PMC/Desktop/Zdrone-dev/zAsync/models/weapons/w_async_gamepad.vvd) — вершинные данные (Vertex Data)
- 📦 [w_async_gamepad.dx90.vtx](file:///c:/Users/PMC/Desktop/Zdrone-dev/zAsync/models/weapons/w_async_gamepad.dx90.vtx) — оптимизированные индексные буферы DirectX 9
- 📦 [w_async_gamepad.phy](file:///c:/Users/PMC/Desktop/Zdrone-dev/zAsync/models/weapons/w_async_gamepad.phy) — физический меш столкновений
- 🖼 [async_gamepad.png](file:///c:/Users/PMC/Desktop/Zdrone-dev/zAsync/materials/entities/async_gamepad.png) — фотореалистичная иконка спавн-меню

### Исходные файлы разработки:
- 🎨 **Blender Проект**: `C:\Users\PMC\Documents\gampad\Без имени.blend`
- 📐 **Оптимизированный SMD**: `C:\Users\PMC\Documents\gampad\gampad_opt.smd`
- ⚙️ **Файл компиляции QC**: `C:\Users\PMC\Documents\gampad\gampad.qc`
- 🖼 **Распакованные текстуры**: `C:\Users\PMC\Documents\gampad\textures\`

---

## 🎮 Функционал пульта Async Gamepad

1. **Спавн и запуск дронов прямо с экрана смартфона**:
   - Держа пульт в руках, нажимайте **ПКМ** для переключения типа дрона (`KVN-1`, `KVN-2`, `KVN-3`) прямо на экране смартфона.
   - Нажмите **ЛКМ** (или клавишу **F6**) для запуска выбранного дрона перед собой.
2. **Живой FPV видеопоток (Render Target)**:
   - В момент полёта на экране смартфона в руках отображается **живое видео с камеры летящего дрона** в реальном времени.
3. **Защита оператора**:
   - При подрыве дрона у цели оператор на земле не получает урон.

---

## 🛠 Подробное руководство по созданию анимаций пульта (Animations & Rigging Guide)

Чтобы сделать модель полностью анимированной (удержание в руках C_Hands, анимация нажатия на кнопки и движения стиков), выполните следующие шаги:

### 1. Создание скелетного рига (Bone Hierarchy) в Blender
В Blender создайте скелет (`Armature`) со следующими костями:
```
root (корневая кость)
 └── bone_body (корпус геймпада)
      ├── bone_stick_left (левый аналоговый стик)
      ├── bone_stick_right (правый аналоговый стик)
      ├── bone_dpad (крестовина)
      ├── bone_trigger_l (левый триггер)
      └── bone_trigger_r (правый триггер)
```

### 2. Подключение стандартных рук C_Hands (ValveBiped)
1. Импортируйте эталонный скелет рук Garry's Mod `c_arms` (кости `ValveBiped.Bip01_L_Hand` и `ValveBiped.Bip01_R_Hand`).
2. Привяжите кисти рук персонажа к корпусу геймпада так, чтобы пальцы лежали на рукоятках и кнопках.

### 3. Создание ключевых кадров анимации (Action Editor)
В окне **Action Editor** создайте клипы анимаций:
- **`idle.smd`** — цикличная анимация покоя (легкое покачивание рук, пульсация индикаторов).
- **`draw.smd`** — анимация доставания пульта снизу вверх.
- **`press_button.smd`** — нажатие большого пальца на кнопку запуска при ЛКМ.
- **`stick_steer.smd`** — отклонение стиков при маневрировании дроном.

### 4. Настройка файла компиляции QC (`v_async_gamepad.qc`)
```qc
$modelname "weapons/v_async_gamepad.mdl"
$body "studio" "gampad_opt.smd"

$cdmaterials "models/weapons/async_gamepad/"
$include "c_arms_definebones.qci"

// Анимации
$sequence "idle" "anims/idle.smd" fps 30 loop
$sequence "draw" "anims/draw.smd" fps 30 ACT_VM_DRAW
$sequence "fire" "anims/press_button.smd" fps 30 ACT_VM_PRIMARYATTACK
```

### 5. Подключение в SWEP коде (`weapon_async_gamepad.lua`)
```lua
SWEP.UseHands = true
SWEP.ViewModel = "models/weapons/v_async_gamepad.mdl"
SWEP.WorldModel = "models/weapons/w_async_gamepad.mdl"
```

---

## ⚙️ Консольные переменные настройки пульта (ConVars)

Для точной подстройки масштаба и позы в руках прямо во время игры используйте команды в консоли `~`:

```bash
async_gamepad_scale 0.50     # Масштаб модели пульта
async_gamepad_pos_x 20       # Смещение вперед/назад
async_gamepad_pos_y 3        # Смещение вправо/влево
async_gamepad_pos_z -2       # Смещение вверх/вниз
async_gamepad_ang_p -25      # Тангаж (Pitch)
async_gamepad_ang_y -180     # Рыскание (Yaw) — антеннами от игрока
async_gamepad_ang_r -180     # Крен (Roll)
```

---

## 📦 Установка

1. Скопируйте папку `zAsync` в директорию `garrysmod/addons/`.
2. Запустите игру. Оружие доступно в спавн-меню во вкладках **`ZCity Other`**, **`zAsync`** и **`[LVS]`**.
