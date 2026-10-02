extends SceneTree
## Поиск растянутых треугольников: CPU-скиннинг модели в кадре анимации, сравнение длин рёбер с позой покоя.
##   godot --headless --path . --script res://tests/probe_skin.gd -- --m=z_walker --anim=walk_a
var done := false


func _process(_d: float) -> bool:
	if done:
		return true
	done = true
	var m := "z_walker"
	var anim := "walk_a"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--m="): m = a.substr(4)
		if a.begins_with("--anim="): anim = a.substr(7)
	var node: Node3D = (load("res://assets/models/baked/%s.scn" % m) as PackedScene).instantiate()
	get_root().add_child(node)
	var sk: Skeleton3D = node.get_node("Skeleton3D")
	var mi := node.find_child("Body", true, false) as MeshInstance3D
	var ap: AnimationPlayer = node.get_node("AnimationPlayer")
	ap.play(anim)
	ap.seek(0.3, true)
	ap.pause()
	var arr := mi.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
	var w: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var skin := mi.skin
	var mats: Array = []
	for b in skin.get_bind_count():
		var bone := sk.find_bone(skin.get_bind_name(b))
		mats.append(sk.get_bone_global_pose(bone) * skin.get_bind_pose(b))
	print("binds ", skin.get_bind_count(), " bones ", sk.get_bone_count(), " bind0 name ", skin.get_bind_name(0), " bind_bone0 ", skin.get_bind_bone(0))
	var posed := PackedVector3Array()
	posed.resize(verts.size())
	for i in verts.size():
		var p := Vector3.ZERO
		for k in 4:
			var ww := w[i * 4 + k]
			if ww > 0.0:
				p += (mats[bones[i * 4 + k]] as Transform3D) * verts[i] * ww
		posed[i] = p
	var worst: Array = []
	for t in range(0, idx.size(), 3):
		for e in 3:
			var a := idx[t + e]
			var b := idx[t + (e + 1) % 3]
			var r := verts[a].distance_to(verts[b])
			var q := posed[a].distance_to(posed[b])
			if q > r * 3.0 and q > 0.1:
				worst.append([q / maxf(r, 0.001), a, b])
	worst.sort_custom(func(x, y) -> bool: return x[0] > y[0])
	print("stretched edges: ", worst.size())
	var names: Array = []
	for b in skin.get_bind_count():
		names.append(skin.get_bind_name(b))
	for k in mini(8, worst.size()):
		var a: int = worst[k][1]
		var b: int = worst[k][2]
		var desc := func(i: int) -> String:
			var s := "%s [" % verts[i].snapped(Vector3.ONE * 0.01)
			for j in 4:
				if w[i * 4 + j] > 0.0:
					s += "%s %.2f " % [names[bones[i * 4 + j]], w[i * 4 + j]]
			return s + "]"
		print("  x%.1f  %s  ->  %s" % [worst[k][0], desc.call(a), desc.call(b)])
	return true
