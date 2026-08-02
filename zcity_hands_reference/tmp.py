
import bpy

bpy.ops.wm.read_factory_settings(use_empty=True)

arm_data = bpy.data.armatures.new("ValveBiped_ZCity_Hands")
arm_obj = bpy.data.objects.new("ValveBiped_ZCity_Hands", arm_data)
bpy.context.scene.collection.objects.link(arm_obj)
bpy.context.view_layer.objects.active = arm_obj

bpy.ops.object.mode_set(mode='EDIT')
ebones = arm_data.edit_bones

spine = ebones.new("ValveBiped.Bip01_Spine4")
spine.head = (0, 0, 0)
spine.tail = (0, 0, 0.2)

r_clavicle = ebones.new("ValveBiped.Bip01_R_Clavicle")
r_clavicle.parent = spine
r_clavicle.head = (-0.15, 0, 0.18)
r_clavicle.tail = (-0.22, 0, 0.18)

r_upperarm = ebones.new("ValveBiped.Bip01_R_UpperArm")
r_upperarm.parent = r_clavicle
r_upperarm.head = (-0.22, 0, 0.18)
r_upperarm.tail = (-0.45, 0, 0.05)

r_forearm = ebones.new("ValveBiped.Bip01_R_Forearm")
r_forearm.parent = r_upperarm
r_forearm.head = (-0.45, 0, 0.05)
r_forearm.tail = (-0.40, 0.25, -0.05)

r_hand = ebones.new("ValveBiped.Bip01_R_Hand")
r_hand.parent = r_forearm
r_hand.head = (-0.40, 0.25, -0.05)
r_hand.tail = (-0.38, 0.35, -0.08)

r_thumb = ebones.new("ValveBiped.Bip01_R_Finger0")
r_thumb.parent = r_hand
r_thumb.head = (-0.38, 0.35, -0.08)
r_thumb.tail = (-0.36, 0.38, -0.06)

r_index = ebones.new("ValveBiped.Bip01_R_Finger1")
r_index.parent = r_hand
r_index.head = (-0.38, 0.35, -0.08)
r_index.tail = (-0.37, 0.40, -0.10)

l_clavicle = ebones.new("ValveBiped.Bip01_L_Clavicle")
l_clavicle.parent = spine
l_clavicle.head = (0.15, 0, 0.18)
l_clavicle.tail = (0.22, 0, 0.18)

l_upperarm = ebones.new("ValveBiped.Bip01_L_UpperArm")
l_upperarm.parent = l_clavicle
l_upperarm.head = (0.22, 0, 0.18)
l_upperarm.tail = (0.45, 0, 0.05)

l_forearm = ebones.new("ValveBiped.Bip01_L_Forearm")
l_forearm.parent = l_upperarm
l_forearm.head = (0.45, 0, 0.05)
l_forearm.tail = (0.40, 0.25, -0.05)

l_hand = ebones.new("ValveBiped.Bip01_L_Hand")
l_hand.parent = l_forearm
l_hand.head = (0.40, 0.25, -0.05)
l_hand.tail = (0.38, 0.35, -0.08)

bpy.ops.object.mode_set(mode='OBJECT')
arm_obj.show_in_front = True

bpy.ops.wm.save_as_mainfile(filepath=r"c:\Users\PMC\Desktop\Zdrone-dev\zcity_hands_reference\zcity_hands_only.blend")
print("BLEND_CREATED")
