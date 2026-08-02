
import bpy
bpy.ops.wm.open_mainfile(filepath=r"C:\Users\PMC\Documents\gampad\BESTheldinarms.blend")
for o in bpy.context.view_layer.objects:
    if o.type == 'MESH':
        try:
            o.select_set(True)
        except Exception:
            pass

bpy.ops.wm.obj_export(filepath=r"c:\Users\PMC\Desktop\Zdrone-dev\gamepad_src\gampad_opt.obj")
print("BESTHELDINARMS_EXPORTED_SUCCESSFULLY")
