extends SceneTree
var frame := 0
var views := []
var model: Node3D
var cam: Camera3D
func _init() -> void:
	var name := "zombie_tripo"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--m="): name = a.substr(4)
	var root := Node3D.new(); get_root().add_child(root)
	var env := WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR; env.environment.background_color = Color(0.2,0.2,0.24)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.environment.ambient_light_color = Color(1,1,1)
	root.add_child(env)
	model = load("res://assets/models/%s.glb" % name).instantiate(); root.add_child(model)
	for m: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var mat = m.mesh.surface_get_material(0).duplicate()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.material_override = mat
	cam = Camera3D.new(); cam.projection = Camera3D.PROJECTION_ORTHOGONAL; cam.size = 2.4; root.add_child(cam); cam.current = true
	views = [["front", Vector3(0,0,3), Vector3.UP], ["side", Vector3(3,0,0), Vector3.UP], ["top", Vector3(0,3,0), Vector3(0,0,-1)]]
	get_root().set_meta("n", name)
func _process(_d: float) -> bool:
	frame += 1
	var i := frame / 4
	if frame % 4 == 0:
		if i >= 1 and i <= views.size():
			var v = views[i-1]
			var img := get_root().get_viewport().get_texture().get_image()
			# сетка через 0.1 м
			for k in range(-6, 7):
				var p := int(round(img.get_width() * 0.5 + k * 0.2 * img.get_width() / 2.4))
				for t in img.get_height():
					if p >= 0 and p < img.get_width(): img.set_pixel(p, t, Color(1,0,0) if k == 0 else Color(0.3,0.3,0.3))
					if p >= 0 and p < img.get_height(): img.set_pixel(t, p, Color(1,0,0) if k == 0 else Color(0.3,0.3,0.3))
			img.save_png("C:/_Projects/MY/_Games/td2/shots/%s_%s.png" % [get_root().get_meta("n"), v[0]])
		if i < views.size():
			var nv = views[i]
			cam.position = nv[1]; cam.look_at(Vector3.ZERO, nv[2])
		else:
			return true
	return false
