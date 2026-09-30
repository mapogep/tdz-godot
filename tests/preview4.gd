extends SceneTree
var frame := 0
var names := ["fence_barrels","fence_concrete","concrete_block","barrel","turret_flamethrower","turret_artillery","turret_machinegun","girl_green","girl_blue","girl_red","girl_A","girl_B"]
var cam: Camera3D
var cur: Node3D
var holder: Node3D
func _init() -> void:
	holder = Node3D.new(); get_root().add_child(holder)
	var env := WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR; env.environment.background_color = Color(0.25,0.25,0.3)
	holder.add_child(env)
	cam = Camera3D.new(); cam.projection = Camera3D.PROJECTION_ORTHOGONAL; cam.size = 3.0; holder.add_child(cam)
	cam.look_at_from_position(Vector3(3, 2, 3), Vector3.ZERO)
func _process(_d: float) -> bool:
	frame += 1
	var i := frame / 4
	if frame % 4 == 1 and i < names.size():
		if cur: cur.queue_free()
		cur = load("res://assets/models/%s.glb" % names[i]).instantiate(); holder.add_child(cur)
		for m: MeshInstance3D in cur.find_children("*", "MeshInstance3D", true, false):
			var mat = m.mesh.surface_get_material(0).duplicate()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.material_override = mat
	if frame % 4 == 3 and i < names.size():
		get_root().get_viewport().get_texture().get_image().save_png("C:/_Projects/MY/_Games/td2/shots/m_%d.png" % i)
	return i >= names.size()
