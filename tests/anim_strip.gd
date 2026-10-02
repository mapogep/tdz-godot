extends SceneTree
## Раскадровка анимации запечённой модели: N кадров сбоку (и спереди) в одну картинку shots/strip_<m>_<anim>.png.
##   godot --path . --resolution 300x450 --script res://tests/anim_strip.gd -- --m=z_walker --anim=walk_a --n=8 [--front]
var frame := 0
var cam: Camera3D
var node: Node3D
var ap: AnimationPlayer
var n := 8
var i := 0
var imgs: Array = []
var m := "z_walker"
var anim := "walk_a"
var front := false


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--m="): m = a.substr(4)
		if a.begins_with("--anim="): anim = a.substr(7)
		if a.begins_with("--n="): n = int(a.substr(4))
		if a == "--front": front = true
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.3, 0.32, 0.36)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.62)
	get_root().add_child(env)
	var l := DirectionalLight3D.new()
	l.rotation_degrees = Vector3(-35, 40, 0)
	get_root().add_child(l)
	node = (load("res://assets/models/baked/%s.scn" % m) as PackedScene).instantiate()
	get_root().add_child(node)
	var body := node.find_child("Body", true, false) as MeshInstance3D
	body.material_override = Assets.model_material("girl_A" if m == "girl" else m)
	ap = node.get_node("AnimationPlayer")
	ap.play(anim)
	ap.pause()
	# пол
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(6, 6)
	floor_mi.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.22, 0.2, 0.18)
	floor_mi.material_override = fm
	get_root().add_child(floor_mi)
	var h: float = float(node.get_meta("rig_height", 2.0))
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = h * 1.25
	get_root().add_child(cam)
	cam.current = true
	var c := Vector3(0, h * 0.5, 0)
	if front:
		cam.look_at_from_position(c + Vector3(0, 0, -6), c)
	else:
		cam.look_at_from_position(c + Vector3(6, 0, 0), c)


func _process(_d: float) -> bool:
	frame += 1
	if frame % 3 == 1:
		ap.seek(ap.current_animation_length * float(i) / n, true)
	elif frame % 3 == 0:
		imgs.append(get_root().get_viewport().get_texture().get_image())
		i += 1
		if i >= n:
			var w: int = imgs[0].get_width()
			var hh: int = imgs[0].get_height()
			var out := Image.create(w * n, hh, false, imgs[0].get_format())
			for k in n:
				out.blit_rect(imgs[k], Rect2i(0, 0, w, hh), Vector2i(w * k, 0))
			out.save_png(ProjectSettings.globalize_path("res://shots/strip_%s_%s%s.png" % [m, anim, "_front" if front else ""]))
			return true
	return false
