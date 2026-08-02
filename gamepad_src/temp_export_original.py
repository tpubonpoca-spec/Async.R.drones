
import bpy

bpy.ops.wm.open_mainfile(filepath=r"C:\Users\PMC\Documents\gampad\BESTheldinarmswithoutmeshhands.blend")
mesh_objs = [o for o in bpy.data.objects if o.type == 'MESH']
print("Total Mesh Objects:", len(mesh_objs))
for o in mesh_objs:
    print(" -", o.name, "| verts:", len(o.data.vertices))

# Выбираем ВСЕ меши без какого-либо отсеивания
for o in bpy.context.view_layer.objects:
    try:
        o.select_set(o.type == 'MESH')
    except Exception:
        pass

# Экспортируем OBJ КАК ЕСТЬ — без центрирования, без перемещения вершин!
bpy.ops.wm.obj_export(filepath=r"c:\Users\PMC\Desktop\Zdrone-dev\gamepad_src\gampad_opt.obj")
print("ORIGINAL_BEST_BLEND_EXPORTED_AS_IS")
