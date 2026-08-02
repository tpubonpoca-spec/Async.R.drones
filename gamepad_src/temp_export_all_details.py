
import bpy
from mathutils import Vector

bpy.ops.wm.open_mainfile(filepath=r"C:\Users\PMC\Documents\gampad\BESTheldinarms.blend")

# Exclude ONLY the placeholder arm meshes ('plosk', 'cube', 'smd_bone_vis')
# Keep ALL phone back covers, antenna blocks, cables, cameras, and controller parts!
arm_keywords = ['plosk', 'cube', 'smd_bone_vis', '8d7a3f28ba34eb5']
gamepad_objs = []

for o in bpy.data.objects:
    if o.type == 'MESH':
        is_arm = False
        for kw in arm_keywords:
            if kw in o.name.lower():
                is_arm = True
                break
        if not is_arm:
            gamepad_objs.append(o)

print("Preserved Objects Count (Phone + Antennas + Gamepad):", len(gamepad_objs))
for o in gamepad_objs:
    print(" - Preserved:", o.name)

for o in bpy.context.view_layer.objects:
    try:
        o.select_set(False)
    except Exception:
        pass

for o in gamepad_objs:
    try:
        o.select_set(True)
    except Exception:
        pass

all_verts = []
for o in gamepad_objs:
    matrix = o.matrix_world
    for v in o.data.vertices:
        all_verts.append(matrix @ v.co)

if all_verts:
    min_x = min(v.x for v in all_verts)
    max_x = max(v.x for v in all_verts)
    min_y = min(v.y for v in all_verts)
    max_y = max(v.y for v in all_verts)
    min_z = min(v.z for v in all_verts)
    max_z = max(v.z for v in all_verts)
    center = Vector(((min_x + max_x) / 2.0, (min_y + max_y) / 2.0, (min_z + max_z) / 2.0))
    print(f"Combined Center: ({center.x:.2f}, {center.y:.2f}, {center.z:.2f})")
    
    for o in gamepad_objs:
        for v in o.data.vertices:
            v.co -= center

bpy.ops.wm.obj_export(filepath=r"c:\Users\PMC\Desktop\Zdrone-dev\gamepad_src\gampad_opt.obj")
print("ALL_DETAILS_EXPORTED_SUCCESSFULLY")
