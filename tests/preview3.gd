extends SceneTree
var frame := 0
var cam: Camera3D
var z: Node3D
var tr: Node3D
var plan := []
func _init() -> void:
	var root := Node3D.new(); get_root().add_child(root)
	var env := WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR; env.environment.background_color = Color(0.2,0.2,0.24)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.environment.ambient_light_color = Color(0.05,0.05,0.05)
	root.add_child(env)
	var l := DirectionalLight3D.new(); l.rotation_degrees = Vector3(-40, 30, 0); root.add_child(l)
	z = load("res://assets/models/zombie_rigged.tscn").instantiate(); z.position = Vector3(-0.6, 0, 0); root.add_child(z); z.rotation.y = PI
	tr = load("res://assets/models/turret_rigged.tscn").instantiate(); tr.position = Vector3(0.6, 0, 0); root.add_child(tr); tr.rotation.y = -PI/2
	var st = load("res://assets/models/zombie_tripo.glb").instantiate(); st.position = Vector3(0.0, 0, 0.9); root.add_child(st); st.rotation.y = PI
	var vm := StandardMaterial3D.new(); vm.vertex_color_use_as_albedo = true
	for m: MeshInstance3D in st.find_children("*", "MeshInstance3D", true, false): m.material_override = vm
	for m: MeshInstance3D in z.find_children("*", "MeshInstance3D", true, false): m.material_override = vm
	for m: MeshInstance3D in tr.find_children("*", "MeshInstance3D", true, false): m.material_override = vm
	cam = Camera3D.new(); cam.projection = Camera3D.PROJECTION_ORTHOGONAL; cam.size = 1.3; root.add_child(cam); cam.current = true
	cam.look_at_from_position(Vector3(3, 1.5, 3), Vector3(0,0,0.3))
	# плана кадров: [имя анимации, время, yaw, pitch]
	plan = [["walk", 0.0, 0.0, 0.0], ["walk", 0.25, 0.8, 0.3], ["walk", 0.5, 1.6, 0.5], ["walk", 0.75, 0.0, -0.3], ["attack", 0.0, 0, 0], ["attack", 0.45, 0, 0]]
func _process(_d: float) -> bool:
	frame += 1
	var i := frame / 6
	if frame % 6 == 3 and i < plan.size():
		var p = plan[i]
		var ap: AnimationPlayer = z.get_node("AnimationPlayer")
		ap.play(p[0]); ap.seek(p[1], true); ap.pause()
		var sk: Skeleton3D = tr.get_node("Skeleton3D")
		sk.set_bone_pose_rotation(sk.find_bone("turret"), Quaternion(Vector3.UP, p[2]))
		sk.set_bone_pose_rotation(sk.find_bone("gun"), Quaternion(Vector3(0,0,1), p[3]))
	if frame % 6 == 5 and i < plan.size():
		get_root().get_viewport().get_texture().get_image().save_png("C:/_Projects/MY/_Games/td2/shots/rig_%d.png" % i)
	return i >= plan.size()



