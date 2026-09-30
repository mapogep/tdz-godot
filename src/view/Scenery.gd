class_name Scenery
extends Node3D
## Постапокалиптическое окружение за пределами поля: дороги, брошенные машины, руины города и посёлка,
## лагерь выживших у восточных ворот, мёртвый лес, обломки, ворота с кострами.
## Всё из моделей Kenney (единый стиль), расставленных MultiMesh-ами; шейдер wasteland даёт общий вид.
## Только визуал.

var flicker_lights: Array = []          # [{light, base, phase}]
var smoke_sources: Array[Vector3] = []
var _buckets: Dictionary = {}           # "модель|near" -> Array[Transform3D]
var _rng := RandomNumberGenerator.new()
var _mid := 10.0
var _fs := 20
var _nav: NavSim
var _quality := 2
var _soft: GradientTexture2D


func build(nav: NavSim, quality: int, soft: GradientTexture2D) -> void:
	_nav = nav
	_fs = nav.field_size
	_mid = _fs / 2.0
	_quality = quality
	_soft = soft
	_rng.seed = 2077
	_roads()
	_west()
	_east()
	_wilderness()
	_flush()
	_gates()


# ───────────── расстановка ─────────────

func _between(a: float, b: float) -> float:
	return a + _rng.randf() * (b - a)


func _add(model: String, x: float, z: float, rot_y: float, scale_f: float, tilt: float = 0.0, sink: float = 0.0) -> void:
	if not Assets.has(model):
		return
	var near := absf(x - _mid) < 34.0 and absf(z - _mid) < 34.0
	var key := "%s|%d" % [model, 1 if near else 0]
	var basis := Basis.from_euler(Vector3((_rng.randf() - 0.5) * tilt, rot_y, (_rng.randf() - 0.5) * tilt)).scaled(Vector3.ONE * scale_f)
	var xf := Transform3D(basis, Vector3(x, -sink, z))
	if not _buckets.has(key):
		_buckets[key] = []
	_buckets[key].append(xf)


func _on_road(x: float, z: float) -> bool:
	return absf(z - _mid) < 2.4 and (x < 0.0 or x > _fs)


func _in_field(x: float, z: float, pad: float) -> bool:
	return x > -pad and x < _fs + pad and z > -pad and z < _fs + pad


func _free(x: float, z: float, on_road: bool) -> bool:
	return not _in_field(x, z, 2.8) and (on_road or not _on_road(x, z))


## Расставляет n экземпляров случайных моделей из names в прямоугольнике [x0,x1]×[z0,z1].
func _fill(names: Array, n: int, x0: float, x1: float, z0: float, z1: float, scale_range: Vector2, tilt: float = 0.0,
		sink: float = 0.0, quarter: bool = false, on_road: bool = false) -> void:
	var have: Array = []
	for nm in names:
		if Assets.has(nm):
			have.append(nm)
	if have.is_empty():
		return
	var placed := 0
	var tries := 0
	var qn := int(n * [0.35, 0.65, 1.0, 1.25][clampi(_quality, 0, 3)])
	while placed < qn and tries < qn * 40:
		tries += 1
		var x := _between(x0, x1)
		var z := _between(z0, z1)
		if not _free(x, z, on_road):
			continue
		var rot := (_rng.randi() % 4) * (PI / 2.0) if quarter else _rng.randf() * TAU
		_add(have[_rng.randi() % have.size()], x, z, rot, _between(scale_range.x, scale_range.y), tilt, sink)
		placed += 1


func _roads() -> void:
	var asphalt := StandardMaterial3D.new()
	asphalt.albedo_color = Color("2a2724")
	asphalt.roughness = 0.95
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color("c9a227")
	paint.roughness = 0.9
	for seg in [[-70.0, -1.0], [_fs + 1.0, _fs + 90.0]]:
		var x0: float = seg[0]
		var x1: float = seg[1]
		var mi := MeshInstance3D.new()
		var q := PlaneMesh.new()
		q.size = Vector2(x1 - x0, 4.4)
		mi.mesh = q
		mi.material_override = asphalt
		mi.position = Vector3((x0 + x1) / 2.0, 0.012, _mid)
		add_child(mi)
		var x := x0 + 1.0
		while x < x1 - 1.0:
			var dash := MeshInstance3D.new()
			var dm := PlaneMesh.new()
			dm.size = Vector2(1.2, 0.14)
			dash.mesh = dm
			dash.material_override = paint
			dash.position = Vector3(x, 0.02, _mid)
			add_child(dash)
			x += 3.0


func _west() -> void:
	var cars := ["sedan", "suv", "van", "truck", "taxi", "police", "garbage-truck", "delivery"]
	_fill(cars, 9, -44, -4, _mid - 5.5, _mid + 5.5, Vector2(1.35, 1.6), 0.16, 0.06, false, true)
	_fill(["ambulance", "firetruck", "tractor"], 3, -40, -8, _mid - 5, _mid + 5, Vector2(1.4, 1.6), 0.12, 0.05, false, true)
	_fill(["debris-tire", "debris-door", "debris-bumper", "debris-plate-a", "debris-plate-b", "debris-drivetrain",
		"debris-door-window", "wheel-default", "debris", "debris-wood"], 70, -46, -3, _mid - 9, _mid + 9, Vector2(1.6, 2.6), 0.0, 0.0, false, true)
	_fill(["crate", "crate-color", "crate-small"], 14, -30, -4, _mid - 8, _mid + 8, Vector2(2, 3))
	_fill(["building-type-a", "building-type-b", "building-type-c", "building-type-d", "building-type-f", "building-type-h", "building-type-k"],
		12, -60, -12, -18, _fs + 18, Vector2(4.6, 6.0), 0.05, 0.05, true)
	_fill(["low-detail-building-a", "low-detail-building-c", "low-detail-building-e", "low-detail-building-h", "low-detail-building-wide-a"],
		8, -70, -30, -25, _fs + 25, Vector2(5.0, 7.5), 0.04, 0.05, true)


func _east() -> void:
	var low := ["low-detail-building-wide-a", "low-detail-building-wide-b"]
	for c in "abcdefghijkl":
		low.append("low-detail-building-%s" % c)
	_fill(low, 34, _fs + 12, _fs + 62, -22, _fs + 22, Vector2(4.5, 8.0), 0.0, 0.05, true)
	_fill(["building-a", "building-d", "building-g"], 10, _fs + 10, _fs + 42, -16, _fs + 16, Vector2(4.2, 5.4), 0.0, 0.04, true)
	_fill(["building-skyscraper-a", "building-skyscraper-c", "building-skyscraper-e"], 10, _fs + 45, _fs + 95, -30, _fs + 30, Vector2(5.5, 7.5), 0.0, 0.0, true)
	_fill(["building-type-a", "building-type-c", "building-type-f"], 5, _fs + 8, _fs + 20, -10, _fs + 10, Vector2(3.4, 4.2), 0.0, 0.04, true)
	_camp(_fs + 5.5, _mid - 7.5)
	_camp(_fs + 6.5, _mid + 8.0)
	_fill(["sedan", "suv", "van", "ambulance", "police"], 5, _fs + 5, _fs + 34, _mid - 5, _mid + 5, Vector2(1.35, 1.6), 0.1, 0.05, false, true)
	_fill(["debris-tire", "debris-door", "debris-plate-a", "debris"], 28, _fs + 3, _fs + 40, -14, _fs + 14, Vector2(1.6, 2.4), 0.0, 0.0, false, true)


## Лагерь выживших: палатки, костёр с огнём и светом, ящики.
func _camp(cx: float, cz: float) -> void:
	_add("tent-detailedopen", cx, cz, 0.4, 3.0)
	_add("tent-detailedclosed", cx + 2.6, cz + 0.6, -0.5, 3.0)
	_add("tent-smallclosed", cx - 2.2, cz + 1.3, 1.0, 3.0)
	_add("campfire-logs", cx + 0.6, cz + 2.8, 0.0, 3.4)
	_add("crate", cx + 1.4, cz - 1.6, 0.3, 2.4)
	_add("crate-small", cx - 0.8, cz - 1.9, 1.2, 2.4)
	_fire(Vector3(cx + 0.6, 0.15, cz + 2.8), 1.3, Color("ff9a3c"), 5.0, 9.0)


func _wilderness() -> void:
	var regions := [[-50.0, _fs + 50.0, -46.0, -3.0], [-50.0, _fs + 50.0, _fs + 3.0, _fs + 46.0]]
	var cars := ["sedan", "suv", "van", "truck", "taxi", "police", "garbage-truck", "delivery"]
	for r in regions:
		_fill(["pine-fall", "pine-crooked"], 60, r[0], r[1], r[2], r[3], Vector2(1.4, 2.4), 0.12)
		_fill(["trunk", "stump-old", "stump-oldtall", "log", "log-large", "log-stack"], 26, r[0], r[1], r[2], r[3], Vector2(2, 3.2))
		_fill(["rock-largea", "rock-largeb", "rock-largec", "rock-larged", "rock-largee", "rock-largef"], 16, r[0], r[1], r[2], r[3], Vector2(3, 5))
		_fill(["rock-tallb", "rock-tallc", "rock-talld", "rock-smalla", "rock-smallb", "rock-smallc", "rock-smallflata"], 26, r[0], r[1], r[2], r[3], Vector2(2.4, 4))
		_fill(["plant-bushdetailed", "plant-bushsmall"], 16, r[0], r[1], r[2], r[3], Vector2(2, 3))
		_fill(cars, 4, r[0], r[1], r[2], r[3], Vector2(1.35, 1.6), 0.2, 0.08)
		_fill(["debris-tire", "debris-door", "debris-bumper", "debris-plate-a", "debris-plate-b", "debris-drivetrain", "debris"], 24, r[0], r[1], r[2], r[3], Vector2(1.6, 2.6))
		_fill(["fence-simple", "fence-planks", "fence-bend", "iron-fence", "fence"], 14, r[0], r[1], r[2], r[3], Vector2(2, 3), 0.15)
	_fill(["pine-fall", "pine-crooked", "trunk", "stump-old"], 40, -80, -8, -50, _fs + 50, Vector2(1.4, 2.4), 0.12)
	_fill(["rock-largea", "rock-largeb", "rock-tallb", "rock-smalla", "rock-smallb"], 22, -80, _fs + 90, -50, _fs + 50, Vector2(2.4, 4.4))


func _flush() -> void:
	for key in _buckets.keys():
		var parts_key: String = str(key).split("|")[0]
		var near: bool = str(key).ends_with("|1")
		var list: Array = _buckets[key]
		for part in Assets.parts(parts_key):
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = part["mesh"]
			mm.instance_count = list.size()
			for i in list.size():
				mm.set_instance_transform(i, list[i] * part["xform"])
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			if part["mat"] != null:
				mmi.material_override = part["mat"]
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if (near and _quality >= 1) else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mmi.visibility_range_end = 150.0
			add_child(mmi)
	_buckets.clear()


# ───────────── огонь, свет, ворота ─────────────

## Постоянный огонь (костёр, жаровня): частицы пламени и искр + мерцающий свет + столб дыма.
func _fire(pos: Vector3, size: float, color: Color, light_energy: float, light_range: float) -> void:
	var fire := GPUParticles3D.new()
	fire.amount = 28 if _quality >= 2 else 14
	fire.lifetime = 0.9
	fire.local_coords = false
	fire.visibility_aabb = AABB(Vector3(-4, -1, -4), Vector3(8, 8, 8))
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 14.0
	pm.initial_velocity_min = 0.6 * size
	pm.initial_velocity_max = 1.6 * size
	pm.gravity = Vector3(0, 0.6, 0)
	pm.scale_min = 0.25 * size
	pm.scale_max = 0.6 * size
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.18 * size
	var ramp := Gradient.new()
	ramp.set_color(0, Color("ffe08a"))
	ramp.set_color(1, Color(1.0, 0.25, 0.05, 0.0))
	ramp.add_point(0.4, Color("ff7a1a"))
	var gt := GradientTexture1D.new()
	gt.gradient = ramp
	pm.color_ramp = gt
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.7))
	curve.add_point(Vector2(0.4, 1.0))
	curve.add_point(Vector2(1, 0.1))
	var ct := CurveTexture.new()
	ct.curve = curve
	pm.scale_curve = ct
	fire.process_material = pm
	var quad := QuadMesh.new()
	var qm := StandardMaterial3D.new()
	qm.albedo_texture = _soft
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.vertex_color_use_as_albedo = true
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	qm.billboard_keep_scale = true
	qm.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	quad.material = qm
	fire.draw_pass_1 = quad
	fire.position = pos
	add_child(fire)

	var smoke := GPUParticles3D.new()
	smoke.amount = 14 if _quality >= 2 else 6
	smoke.lifetime = 4.0
	smoke.local_coords = false
	smoke.visibility_aabb = AABB(Vector3(-6, -1, -6), Vector3(12, 14, 12))
	var sm := ParticleProcessMaterial.new()
	sm.direction = Vector3.UP
	sm.spread = 12.0
	sm.initial_velocity_min = 0.9
	sm.initial_velocity_max = 1.6
	sm.gravity = Vector3(0.25, 0.1, 0.1)
	sm.scale_min = 0.5 * size
	sm.scale_max = 0.9 * size
	var sramp := Gradient.new()
	sramp.set_color(0, Color(0.16, 0.15, 0.14, 0.55))
	sramp.set_color(1, Color(0.3, 0.28, 0.26, 0.0))
	var sgt := GradientTexture1D.new()
	sgt.gradient = sramp
	sm.color_ramp = sgt
	var scurve := Curve.new()
	scurve.add_point(Vector2(0, 0.5))
	scurve.add_point(Vector2(1, 3.5))
	var sct := CurveTexture.new()
	sct.curve = scurve
	sm.scale_curve = sct
	smoke.process_material = sm
	var squad := QuadMesh.new()
	var smat := StandardMaterial3D.new()
	smat.albedo_texture = _soft
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.vertex_color_use_as_albedo = true
	smat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	smat.billboard_keep_scale = true
	smat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	squad.material = smat
	smoke.draw_pass_1 = squad
	smoke.position = pos + Vector3(0, 0.6, 0)
	add_child(smoke)

	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = light_energy
	l.omni_range = light_range
	l.shadow_enabled = false
	l.position = pos + Vector3(0, 0.7, 0)
	add_child(l)
	flicker_lights.append({"light": l, "base": light_energy, "phase": _rng.randf() * 10.0})


func _hazard_texture() -> ImageTexture:
	var img := Image.create(128, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color("d9a91c"))
	for i in range(-2, 10):
		for y in 32:
			for x in 12:
				var px := i * 20 + x + int(float(32 - y) / 32.0 * 20.0)
				if px >= 0 and px < 128:
					img.set_pixel(px, y, Color("1b1712"))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _gates() -> void:
	var concrete := Assets.surface_material("res://assets/tex/concrete.jpg", 2.2, 0.75, 0.95, 0.9, 1.2, 0.0, 0.3)
	var hz := StandardMaterial3D.new()
	hz.albedo_texture = _hazard_texture()
	hz.roughness = 0.8
	hz.uv1_scale = Vector3(2, 1, 1)
	for gx in [_nav.west_gate_x(), _nav.east_gate_x()]:
		var glow := Color("ff3d2a") if gx == 0 else Color("ffb347")
		var rows: Array = _nav.gate_rows
		var z_top: float = NavSim.cell_to_world(Vector2i(gx, rows[0])).y - 0.5
		var z_bot: float = NavSim.cell_to_world(Vector2i(gx, rows[-1])).y + 0.5
		var cx: float = NavSim.cell_to_world(Vector2i(gx, rows[0])).x
		for z in [z_top - 0.3, z_bot + 0.3]:
			var pillar := MeshInstance3D.new()
			var pm := BoxMesh.new()
			pm.size = Vector3(0.8, 3.4, 0.8)
			pillar.mesh = pm
			pillar.material_override = concrete
			pillar.position = Vector3(cx, 1.7, z)
			add_child(pillar)
			var stripe := MeshInstance3D.new()
			var sm := BoxMesh.new()
			sm.size = Vector3(0.84, 0.5, 0.84)
			stripe.mesh = sm
			stripe.material_override = hz
			stripe.position = Vector3(cx, 0.55, z)
			add_child(stripe)
			var lamp := MeshInstance3D.new()
			var lm := SphereMesh.new()
			lm.radius = 0.17
			lm.height = 0.34
			lamp.mesh = lm
			var lmat := StandardMaterial3D.new()
			lmat.albedo_color = glow
			lmat.emission_enabled = true
			lmat.emission = glow
			lmat.emission_energy_multiplier = 3.0
			lamp.material_override = lmat
			lamp.position = Vector3(cx, 3.7, z)
			add_child(lamp)
			var ol := OmniLight3D.new()
			ol.light_color = glow
			ol.light_energy = 2.2
			ol.omni_range = 7.0
			ol.position = Vector3(cx, 3.6, z)
			add_child(ol)
			flicker_lights.append({"light": ol, "base": 2.2, "phase": _rng.randf() * 10.0})
		var lintel := MeshInstance3D.new()
		var lim := BoxMesh.new()
		lim.size = Vector3(0.9, 0.5, z_bot - z_top + 1.0)
		lintel.mesh = lim
		lintel.material_override = hz
		lintel.position = Vector3(cx, 3.2, (z_top + z_bot) / 2.0)
		add_child(lintel)
		# жаровни по бокам ворот
		for z in [z_top - 1.6, z_bot + 1.6]:
			var bx := cx + (-0.6 if gx == 0 else 0.6)
			var inst := Assets.instance("fire-basket")
			if inst != null:
				inst.position = Vector3(bx, 0, z)
				inst.scale = Vector3.ONE * 2.8
				Assets.grade_node(inst, 0.7, 0.95, 0.0)
				add_child(inst)
			_fire(Vector3(bx, 0.95, z), 1.0, Color("ff8a2a"), 4.0, 8.0)
	# фонари у восточной дороги
	var lamp_model := Assets.instance("lightpost-single")
	if lamp_model != null:
		lamp_model.queue_free()
		for dz in [-5.5, 5.5]:
			var lp := Assets.instance("lightpost-single")
			lp.position = Vector3(_fs + 3.6, 0, _mid + dz)
			lp.rotation.y = PI
			lp.scale = Vector3.ONE * 2.1
			Assets.grade_node(lp, 0.7, 0.95, 0.0)
			add_child(lp)
			var l := OmniLight3D.new()
			l.light_color = Color("ffc36a")
			l.light_energy = 4.0
			l.omni_range = 9.0
			l.position = Vector3(_fs + 3.6, 3.4, _mid + dz)
			add_child(l)
			flicker_lights.append({"light": l, "base": 4.0, "phase": _rng.randf() * 10.0})


## Мерцание костров и фонарей — вызывать каждый кадр.
func animate_lights(t: float) -> void:
	for f in flicker_lights:
		var l: OmniLight3D = f["light"]
		var ph: float = f["phase"]
		var base: float = f["base"]
		l.light_energy = base * (0.82 + 0.18 * sin(t * 11.0 + ph) * sin(t * 5.3 + ph * 2.0) + 0.06 * sin(t * 27.0 + ph))
