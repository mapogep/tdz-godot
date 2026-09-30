extends SceneTree
func _init() -> void:
	for n in ["zombie_tripo", "turret_tripo"]:
		var s: Node = load("res://assets/models/%s.glb" % n).instantiate()
		for m: MeshInstance3D in s.find_children("*", "MeshInstance3D", true, false):
			var mat = m.mesh.surface_get_material(0)
			print(n, " ", m.name, " xform=", m.transform, " mat=", mat)
			if mat is BaseMaterial3D:
				print("  albedo=", mat.albedo_color, " tex=", mat.albedo_texture, " vc=", mat.vertex_color_use_as_albedo, " metal=", mat.metallic, " rough=", mat.roughness)
			var arr := m.mesh.surface_get_arrays(0)
			print("  has colors=", arr[Mesh.ARRAY_COLOR] != null, " uv=", arr[Mesh.ARRAY_TEX_UV] != null)
	quit()
