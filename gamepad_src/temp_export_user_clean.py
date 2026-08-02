
import bpy
from mathutils import Vector

bpy.ops.wm.open_mainfile(filepath=r"C:\Users\PMC\Documents\gampad\BESTheldinarmswithoutmeshhands.blend")
mesh_objs = [o for o in bpy.data.objects if o.type == 'MESH']
print("Mesh Objects Count:", len(mesh_objs))
for o in mesh_objs:
    print(" - Mesh Object:", o.name)

for o in bpy.context.view_layer.objects:
    try:
        o.select_set(False)
    except Exception:
        pass

for o in mesh_objs:
    try:
        o.select_set(True)
    except Exception:
        pass

all_verts = []
for o in mesh_objs:
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
    print(f"User Model Center: ({center.x:.2f}, {center.y:.2f}, {center.z:.2f})")
    
    for o in mesh_objs:
        for v in o.data.vertices:
            v.co -= center

bpy.ops.wm.obj_export(filepath=r"c:\Users\PMC\Desktop\Zdrone-dev\gamepad_src\gampad_opt.obj")
print("USER_CLEAN_BLEND_EXPORTED_SUCCESSFULLY")
