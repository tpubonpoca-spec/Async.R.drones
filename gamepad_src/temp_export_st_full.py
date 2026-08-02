
import bpy
import os

bpy.ops.wm.open_mainfile(filepath=r"C:\Users\PMC\Documents\gampad\dabest.blend")

# Set scene export format to SMD
scene = bpy.context.scene
scene.vs.export_format = 'SMD'
scene.vs.export_path = r"c:\Users\PMC\Desktop\Zdrone-dev\gamepad_src"

# Select armature and enable export
for o in bpy.data.objects:
    if o.type in ['ARMATURE', 'MESH']:
        o.select_set(True)
        if hasattr(o, "vs"):
            o.vs.export = True

try:
    bpy.ops.export_scene.smd(export_delay=False)
    print("SOURCE_TOOLS_SUCCESSFUL_EXPORT")
except Exception as e:
    print(f"Export result: {e}")
