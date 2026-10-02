extends SceneTree
## Превью запечённой модели (assets/models/baked/<m>.res|.scn) с 4 ракурсов: спереди (-Z), сбоку (+X), сзади, сверху.
##   godot --path . --resolution 1024x1024 --script res://tests/preview_baked.gd -- --m=ak47 [--anim=walk --t=0.25]
var frame := 0
var cam: Camera3D
var holder: Node3D
var out := ""
var views: Array = []
var size := 2.2


func _init() -> void:
	var m := "ak47"
	var anim := ""
	var at := 0.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--m="): m = a.substr(4)
		if a.begins_with("--anim="): anim = a.substr(7)
		if a.begins_with("--t="): at = float(a.substr(4))
	out = "C:/_Projects/MY/_Games/td2/shots/pv_%s%s" % [m, ("_" + anim) if anim != "" else ""]
	holder = Node3D.new()
	get_root().add_child(holder)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.3, 0.32, 0.36)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.55, 0.6)
	holder.add_child(env)
	var l := DirectionalLight3D.new()
	l.rotation_degrees = Vector3(-35, 40, 0)
	holder.add_child(l)
	var node: Node3D
	var path := "res://assets/models/baked/%s" % m
	if ResourceLoader.exists(path + ".scn"):
		node = (load(path + ".scn") as PackedScene).instantiate()
		var body := node.find_child("Body", true, false) as MeshInstance3D
		var tex_name := str(node.get_meta("tex", m))
		if m == "girl": tex_name = "girl_A"
		body.material_override = Assets.model_material(tex_name)
		if anim != "":
			var ap: AnimationPlayer = node.get_node("AnimationPlayer")
			ap.play(anim)
			ap.seek(ap.current_animation_length * at, true)
			ap.pause()
	else:
		var mi := MeshInstance3D.new()
		mi.mesh = load(path + ".res")
		mi.material_override = Assets.model_material(m)
		node = mi
	holder.add_child(node)
	var bb := AABB()
	var first := true
	for mi2: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false) + ([node] if node is MeshInstance3D else []):
		var a2: AABB = mi2.get_aabb()
		bb = a2 if first else bb.merge(a2)
		first = false
	var c := bb.get_center()
	if node.has_meta("rig_height"):
		c = Vector3(0, float(node.get_meta("rig_height")) * 0.5, 0)
	size = maxf(bb.size.x, maxf(bb.size.y, bb.size.z)) * 1.15
	if node.has_meta("height"):          # турель: custom_aabb с запасом — кадрируем по высоте модели
		var hh: float = float(node.get_meta("height"))
		c = Vector3(0, hh * 0.5, 0)
		size = hh * 1.9
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = size
	holder.add_child(cam)
	cam.current = true
	var d := size * 3.0
	views = [[c + Vector3(0, 0, -d), c], [c + Vector3(d, 0, 0), c], [c + Vector3(0, 0, d), c], [c + Vector3(0.001, d, 0), c]]
	cam.look_at_from_position(views[0][0], views[0][1])


func _process(_d: float) -> bool:
	frame += 1
	var i := frame / 4
	if frame % 4 == 3 and i < views.size():
		get_root().get_viewport().get_texture().get_image().save_png("%s_%d.png" % [out, i])
		if i + 1 < views.size():
			cam.look_at_from_position(views[i + 1][0], views[i + 1][1], Vector3.UP if i + 1 < 3 else Vector3(0, 0, -1))
	return i >= views.size()
