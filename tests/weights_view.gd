extends SceneTree
## Карта весов кожи: вершины окрашены по главной кости (руки — красный/синий, предплечья — светлее, ноги — зелёный,
## корпус — серый), 4 ракурса в shots/wv_<m>.png.
##   godot --path . --resolution 400x500 --script res://tests/weights_view.gd -- --m=z_brute
var frame := 0
var cam: Camera3D
var views: Array = []
var imgs: Array = []
var m := "z_brute"


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--m="): m = a.substr(4)
	var node: Node3D = (load("res://assets/models/baked/%s.scn" % m) as PackedScene).instantiate()
	var src := node.find_child("Body", true, false) as MeshInstance3D
	var arr := src.mesh.surface_get_arrays(0)
	var names: Array = []
	for b in src.skin.get_bind_count():
		names.append(src.skin.get_bind_name(b))
	var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
	var w: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
	var cols := PackedColorArray()
	for i in (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size():
		var best := 0
		for k in range(1, 4):
			if w[i * 4 + k] > w[i * 4 + best]:
				best = k
		var nm: String = names[bones[i * 4 + best]]
		var c := Color(0.6, 0.6, 0.6)
		if nm == "upperarm_L": c = Color(0.8, 0.1, 0.1)
		elif nm == "forearm_L": c = Color(1.0, 0.6, 0.5)
		elif nm == "upperarm_R": c = Color(0.1, 0.2, 0.9)
		elif nm == "forearm_R": c = Color(0.5, 0.7, 1.0)
		elif nm.begins_with("thigh") or nm.begins_with("shin") or nm.begins_with("foot"): c = Color(0.2, 0.7, 0.2)
		elif nm == "hips": c = Color(0.9, 0.8, 0.2)
		elif nm == "head" or nm == "neck": c = Color(0.9, 0.9, 0.9)
		cols.append(c)
	var a2 := []
	a2.resize(Mesh.ARRAY_MAX)
	a2[Mesh.ARRAY_VERTEX] = arr[Mesh.ARRAY_VERTEX]
	a2[Mesh.ARRAY_NORMAL] = arr[Mesh.ARRAY_NORMAL]
	a2[Mesh.ARRAY_COLOR] = cols
	a2[Mesh.ARRAY_INDEX] = arr[Mesh.ARRAY_INDEX]
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a2)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	get_root().add_child(mi)
	node.free()
	var bb := mesh.get_aabb()
	var c0 := bb.get_center()
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = bb.size.y * 1.1
	get_root().add_child(cam)
	cam.current = true
	var d := 6.0
	views = [c0 + Vector3(0, 0, -d), c0 + Vector3(d, 0, 0), c0 + Vector3(0, 0, d), c0 + Vector3(-d, 0, 0)]
	cam.look_at_from_position(views[0], c0)
	set_meta("c", c0)


func _process(_d: float) -> bool:
	frame += 1
	var i := frame / 3
	if frame % 3 == 2 and i < views.size():
		imgs.append(get_root().get_viewport().get_texture().get_image())
		if i + 1 < views.size():
			cam.look_at_from_position(views[i + 1], get_meta("c"))
	if imgs.size() == views.size():
		var w: int = imgs[0].get_width()
		var h: int = imgs[0].get_height()
		var out := Image.create(w * 4, h, false, imgs[0].get_format())
		for k in 4:
			out.blit_rect(imgs[k], Rect2i(0, 0, w, h), Vector2i(w * k, 0))
		out.save_png(ProjectSettings.globalize_path("res://shots/wv_%s.png" % m))
		return true
	return false
