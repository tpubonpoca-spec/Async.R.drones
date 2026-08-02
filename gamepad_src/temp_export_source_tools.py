
import bpy
import os

bpy.ops.wm.open_mainfile(filepath=r"C:\Users\PMC\Documents\gampad\dabest.blend")

# Set scene export format to SMD
bpy.context.scene.vs.export_format = 'SMD'
bpy.context.scene.vs.export_path = r"c:\Users\PMC\Desktop\Zdrone-dev\gamepad_src"

try:
    bpy.ops.export_scene.smd()
    print("SOURCE_TOOLS_EXPORT_SUCCESS")
except Exception as e:
    print(f"Source tools error: {e}")
