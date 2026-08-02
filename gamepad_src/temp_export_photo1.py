
import bpy
import os

bpy.ops.wm.open_mainfile(filepath=r"C:\Users\PMC\Documents\gampad\BESTheldinarms.blend")

# Export full viewmodel (hands + sleeves + gamepad + phone)
arm_obj = None
for o in bpy.data.objects:
    if o.type == 'ARMATURE':
        arm_obj = o
        break

bones = arm_obj.data.bones if arm_obj else []
bone_names = [b.name for b in bones]
bone_to_id = {name: i for i, name in enumerate(bone_names)}

nodes_lines = ["nodes"]
for i, b in enumerate(bones):
    parent_id = bone_to_id[b.parent.name] if b.parent else -1
    nodes_lines.append(f'  {i} "{b.name}" {parent_id}')
nodes_lines.append("end")

skel_lines = ["skeleton", "time 0"]
for i, b in enumerate(bones):
    if b.parent:
        mat_local = b.parent.matrix_local.inverted() @ b.matrix_local
    else:
        mat_local = b.matrix_local
    pos = mat_local.to_translation()
    rot = mat_local.to_euler('XYZ')
    skel_lines.append(f'  {i} {pos.x:.6f} {pos.y:.6f} {pos.z:.6f} {rot.x:.6f} {rot.y:.6f} {rot.z:.6f}')
skel_lines.append("end")

def export_smd_mesh(objs, target_file):
    triangles_lines = ["triangles"]
    for o in objs:
        depsgraph = bpy.context.evaluated_depsgraph_get()
        eval_o = o.evaluated_get(depsgraph)
        mesh = eval_o.to_mesh()
        mesh.calc_loop_triangles()
        world_mat = o.matrix_world
        uv_layer = mesh.uv_layers.active.data if mesh.uv_layers.active else None
        
        mat_name = "Material"
        if mesh.materials and mesh.materials[0]:
            mat_name = mesh.materials[0].name.split('.')[0]
            
        vg_map = {vg.index: vg.name for vg in o.vertex_groups}

        for tri in mesh.loop_triangles:
            triangles_lines.append(mat_name)
            for loop_idx in tri.loops:
                vi = mesh.loops[loop_idx].vertex_index
                vert = mesh.vertices[vi]
                pos = world_mat @ vert.co
                norm = world_mat.to_3x3() @ mesh.loops[loop_idx].normal
                norm.normalize()
                u, v = 0.0, 0.0
                if uv_layer:
                    u, v = uv_layer[loop_idx].uv
                weights = []
                for g in vert.groups:
                    vg_name = vg_map.get(g.group)
                    if vg_name and vg_name in bone_to_id:
                        weights.append((bone_to_id[vg_name], g.weight))
                if not weights:
                    fallback_bone = bone_to_id.get("ValveBiped.Bip01_R_Hand", 0)
                    weights = [(fallback_bone, 1.0)]
                else:
                    weights = sorted(weights, key=lambda x: x[1], reverse=True)[:4]
                    total_w = sum(w for _, w in weights)
                    if total_w > 0:
                        weights = [(b_id, w / total_w) for b_id, w in weights]
                weight_str = f"{len(weights)} " + " ".join(f"{b_id} {w:.4f}" for b_id, w in weights)
                triangles_lines.append(f"  {weight_str} {pos.x:.6f} {pos.y:.6f} {pos.z:.6f} {norm.x:.6f} {norm.y:.6f} {norm.z:.6f} {u:.6f} {v:.6f}")
    triangles_lines.append("end")

    os.makedirs(os.path.dirname(target_file), exist_ok=True)
    smd_content = "version 1\n" + "\n".join(nodes_lines) + "\n" + "\n".join(skel_lines) + "\n" + "\n".join(triangles_lines) + "\n"
    with open(target_file, "w", encoding="utf-8") as f:
        f.write(smd_content)

all_mesh_objs = [o for o in bpy.data.objects if o.type == 'MESH']
export_smd_mesh(all_mesh_objs, r"c:\Users\PMC\Desktop\Zdrone-dev\gamepad_src\anims\v_gamepad.smd")

# Worldmodel (without hands mesh)
gamepad_mesh_objs = [o for o in all_mesh_objs if "8d7a3f28" not in o.name]
export_smd_mesh(gamepad_mesh_objs, r"c:\Users\PMC\Desktop\Zdrone-dev\gamepad_src\anims\w_gamepad.smd")

print("FULL_VIEWMODEL_SMD_EXPORTED_SUCCESSFULLY")
