extends SceneTree
var frame := 0
func _init() -> void:
	var root := Node3D.new()
	get_root().add_child(root)
	var env := WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR; env.environment.background_color = Color(0.25,0.25,0.28)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.environment.ambient_light_color = Color(0.6,0.6,0.6)
	root.add_child(env)
	var l := DirectionalLight3D.new(); l.rotation_degrees = Vector3(-40, 30, 0); root.add_child(l)
	var z: Node3D = load("res://assets/models/zombie_tripo.glb").instantiate(); z.position = Vector3(-1.2, 0, 0); root.add_child(z)
	var t: Node3D = load("res://assets/models/turret_tripo.glb").instantiate(); t.position = Vector3(0.6, 0, 0); root.add_child(t)
	var vm := StandardMaterial3D.new(); vm.vertex_color_use_as_albedo = true; vm.roughness = 0.85
	for n in [z, t]:
		for m: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false): m.material_override = vm
	# оси-маркеры: красный +X, синий +Z
	for a in [[Vector3(1,0,0), Color.RED], [Vector3(0,0,1), Color.BLUE]]:
		var m := MeshInstance3D.new(); var b := BoxMesh.new(); b.size = Vector3(0.05,0.05,0.05); m.mesh = b
		var mat := StandardMaterial3D.new(); mat.albedo_color = a[1]; m.material_override = mat
		m.position = a[0] * 2.0 - Vector3(0.0, 0.4, 0); root.add_child(m)
	var cam := Camera3D.new(); root.add_child(cam)
	cam.position = Vector3(-0.3, 0.7, 2.6); cam.look_at(Vector3(-0.3, 0.1, 0))
	cam.current = true
	# сохраним ссылку в мета
	get_root().set_meta("cam", cam)
func _process(_d: float) -> bool:
	frame += 1
	var cam: Camera3D = get_root().get_meta("cam")
	if frame == 5:
		get_root().get_viewport().get_texture().get_image().save_png("C:/_Projects/MY/_Games/td2/shots/prev_front.png")
		cam.position = Vector3(-4.0, 0.9, 0.0); cam.look_at(Vector3(-0.3, 0.1, 0))
	if frame == 10:
		get_root().get_viewport().get_texture().get_image().save_png("C:/_Projects/MY/_Games/td2/shots/prev_side.png")
		return true
	return false

