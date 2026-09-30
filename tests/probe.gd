extends SceneTree
func _init() -> void:
	for n in ["fence_barrels","fence_concrete","concrete_block","barrel","turret_flamethrower","turret_artillery","turret_machinegun","girl_green","girl_blue","girl_red","girl_A","girl_B"]:
		var s: Node = load("res://assets/models/%s.glb" % n).instantiate()
		var meshes := s.find_children("*", "MeshInstance3D", true, false)
		var mn := Vector3(1e9,1e9,1e9); var mx := -mn
		var verts := 0; var info := ""
		for m: MeshInstance3D in meshes:
			var a := m.get_aabb()
			var t := m.transform
			for c in 8:
				var p := t * a.get_endpoint(c)
				mn = mn.min(p); mx = mx.max(p)
			var arr := m.mesh.surface_get_arrays(0)
			verts += arr[Mesh.ARRAY_VERTEX].size()
			var mat = m.mesh.surface_get_material(0)
			info += " [surf=%d normals=%s uv=%s col=%s tex=%s bones=%s]" % [m.mesh.get_surface_count(), arr[Mesh.ARRAY_NORMAL] != null, arr[Mesh.ARRAY_TEX_UV] != null, arr[Mesh.ARRAY_COLOR] != null, (mat is BaseMaterial3D and mat.albedo_texture != null), arr[Mesh.ARRAY_BONES] != null]
		print(n, " meshes=", meshes.size(), " verts=", verts, " min=", mn, " size=", mx - mn, " skel=", s.find_children("*","Skeleton3D",true,false).size(), " anim=", s.find_children("*","AnimationPlayer",true,false).size(), info)
	quit()
