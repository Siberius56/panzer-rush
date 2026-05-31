GrassObjectField3D, Godot 4.6

Installation:
- Put this folder at: res://GrassObjectField3D/
- Instance: res://GrassObjectField3D/GrassObjectField3D.tscn

Main workflow:
1. Select the GrassObjectField3D node.
2. Drag your grass .obj mesh into Source Object > source_mesh.
   Alternative: drag a scene containing a MeshInstance3D into source_scene.
3. Keep align_mesh_base_to_origin enabled if your object pivot is not already at the base.
4. Set zone_size and object_count.
5. Click Setup / Regenerate Objects.

Important mesh rule:
- Best result: the grass object pivot is at the base, on the ground.
- The shader rotates the object around local origin, so a bad pivot gives bad bending.
- align_mesh_base_to_origin can fix most imported ArrayMesh objects.

Interaction:
- Add players to group: grass_player
- Add vehicles to group: grass_vehicle

Example:
func _ready() -> void:
    add_to_group("grass_player")

Bending behavior:
- The object rotates around its base toward the ground.
- It does not stretch like the old blade shader.
- When the player leaves, it waits recover_delay_seconds before rising again.

Exclusion:
- Use Create Exclusion Box from the inspector.
- Or create any node named GrassExclusion... with a CollisionShape3D under it.
- Or add any node with a CollisionShape3D to group grass_exclusion.
- Regenerate after moving exclusions.
