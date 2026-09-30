class_name Fx
extends Node3D
## Визуальные эффекты: GPU-частицы (огонь, дым, искры, кровь), вспышки света, трассеры, декали (кровь, копоть),
## взрывы с ударной волной, всплывающий текст. Чистая косметика: ничего не влияет на игровую логику.

signal shake_requested(amount: float, pos: Vector3)

const MAX_DECALS := 60

var _soft: GradientTexture2D
var _decals: Array[Decal] = []
var _splat_tex: Array[ImageTexture] = []
var _scorch_tex: ImageTexture
var _mat_cache: Dictionary = {}
var quality := 2         # 0..3, влияет на число частиц и декалей


func _init() -> void:
	name = "Fx"
	_soft = GradientTexture2D.new()
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	_soft.gradient = g
	_soft.fill = GradientTexture2D.FILL_RADIAL
	_soft.fill_from = Vector2(0.5, 0.5)
	_soft.fill_to = Vector2(1.0, 0.5)
	_soft.width = 64
	_soft.height = 64
	for i in 3:
		_splat_tex.append(_make_splat(i + 1))
	_scorch_tex = _make_scorch()


func set_quality(q: int) -> void:
	quality = q


func _amt(n: int) -> int:
	return maxi(1, int(round(n * [0.4, 0.7, 1.0, 1.4][clampi(quality, 0, 3)])))


# ───────────── материалы и текстуры ─────────────

func _particle_material(additive: bool, unshaded: bool = true) -> StandardMaterial3D:
	var key := "%s%s" % [additive, unshaded]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_texture = _soft
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if unshaded else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.disable_receive_shadows = true
	m.no_depth_test = false
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_mat_cache[key] = m
	return m


func _make_splat(seed_v: int) -> ImageTexture:
	var S := 128
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	var n := FastNoiseLite.new()
	n.seed = seed_v * 977
	n.frequency = 0.06
	for y in S:
		for x in S:
			var d := Vector2(x - S / 2.0, y - S / 2.0).length() / (S / 2.0)
			var v := n.get_noise_2d(x, y) * 0.5 + 0.5
			var a := clampf((1.0 - d) * 1.6 - (1.0 - v) * 0.9, 0.0, 1.0)
			a = smoothstep(0.1, 0.5, a)
			img.set_pixel(x, y, Color(0.35, 0.03, 0.03, a * 0.9))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _make_scorch() -> ImageTexture:
	var S := 128
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	var n := FastNoiseLite.new()
	n.seed = 4242
	n.frequency = 0.05
	for y in S:
		for x in S:
			var d := Vector2(x - S / 2.0, y - S / 2.0).length() / (S / 2.0)
			var v := n.get_noise_2d(x, y) * 0.5 + 0.5
			var a := clampf(1.0 - d * (0.85 + v * 0.3), 0.0, 1.0)
			img.set_pixel(x, y, Color(0.02, 0.018, 0.015, a * a * 0.85))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _free_later(n: Node, secs: float) -> void:
	get_tree().create_timer(secs).timeout.connect(func() -> void:
		if is_instance_valid(n):
			n.queue_free())


# ───────────── частицы ─────────────

## Универсальный «взрыв» частиц. cfg: amount, life, color, size, vel (min,max), gravity, spread (градусы),
## dir (Vector3), additive, damping, radius (сфера эмиссии), fade_color.
func emit(pos: Vector3, cfg: Dictionary) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = _amt(int(cfg.get("amount", 12)))
	p.lifetime = float(cfg.get("life", 0.6))
	p.one_shot = true
	p.explosiveness = float(cfg.get("explosive", 0.95))
	p.local_coords = false
	p.emitting = true
	p.fixed_fps = 0
	p.visibility_aabb = AABB(Vector3(-6, -3, -6), Vector3(12, 8, 12))
	var pm := ParticleProcessMaterial.new()
	pm.direction = cfg.get("dir", Vector3.UP)
	pm.spread = float(cfg.get("spread", 180.0))
	var v: Vector2 = cfg.get("vel", Vector2(1.0, 3.0))
	pm.initial_velocity_min = v.x
	pm.initial_velocity_max = v.y
	pm.gravity = Vector3(0, -float(cfg.get("gravity", 0.0)), 0)
	pm.damping_min = float(cfg.get("damping", 0.0))
	pm.damping_max = float(cfg.get("damping", 0.0)) * 1.5
	var sz: Vector2 = cfg.get("size", Vector2(0.2, 0.4))
	pm.scale_min = sz.x
	pm.scale_max = sz.y
	var rad := float(cfg.get("radius", 0.0))
	if rad > 0.0:
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pm.emission_sphere_radius = rad
	var col: Color = cfg.get("color", Color.WHITE)
	var ramp := Gradient.new()
	ramp.set_color(0, col)
	ramp.set_color(1, Color(col.r, col.g, col.b, 0.0))
	if cfg.has("mid_color"):
		ramp.add_point(0.35, cfg["mid_color"])
	var gt := GradientTexture1D.new()
	gt.gradient = ramp
	pm.color_ramp = gt
	if cfg.has("grow"):
		var curve := Curve.new()
		curve.add_point(Vector2(0, 0.6))
		curve.add_point(Vector2(1, float(cfg["grow"])))
		var ct := CurveTexture.new()
		ct.curve = curve
		pm.scale_curve = ct
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(1, 1)
	quad.material = _particle_material(bool(cfg.get("additive", true)))
	p.draw_pass_1 = quad
	p.position = pos
	add_child(p)
	_free_later(p, p.lifetime + 0.6)
	return p


func flash_light(pos: Vector3, color: Color, energy: float, rng_m: float, dur: float) -> void:
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = rng_m
	l.shadow_enabled = false
	l.position = pos
	add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "light_energy", 0.0, dur).set_ease(Tween.EASE_OUT)
	tw.tween_callback(l.queue_free)


func muzzle_flash(pos: Vector3, scale_f: float = 1.0) -> void:
	flash_light(pos, Color("ffb45a"), 4.0 * scale_f, 4.0, 0.09)
	emit(pos, {"amount": 5, "life": 0.09, "color": Color("ffd27a"), "size": Vector2(0.35, 0.6) * scale_f,
		"vel": Vector2(0.0, 0.6), "additive": true, "grow": 1.6})


func sparks(pos: Vector3, color: Color = Color("ffe08a"), n: int = 6) -> void:
	emit(pos, {"amount": n, "life": 0.35, "color": color, "size": Vector2(0.05, 0.11), "vel": Vector2(1.5, 4.5),
		"gravity": 9.0, "additive": true})


func smoke_puff(pos: Vector3, n: int = 3) -> void:
	emit(pos, {"amount": n, "life": 1.0, "color": Color(0.5, 0.48, 0.45, 0.55), "size": Vector2(0.3, 0.55),
		"vel": Vector2(0.2, 0.7), "dir": Vector3.UP, "spread": 40.0, "additive": false, "grow": 3.0, "explosive": 0.6})


func burn_puff(pos: Vector3) -> void:
	emit(pos, {"amount": 2, "life": 0.5, "color": Color("ffb03a"), "mid_color": Color("ff5a1a"), "size": Vector2(0.15, 0.3),
		"vel": Vector2(0.8, 1.6), "dir": Vector3.UP, "spread": 25.0, "additive": true, "grow": 0.4, "explosive": 0.3})
	if randf() < 0.3:
		emit(pos + Vector3(0, 0.4, 0), {"amount": 1, "life": 0.9, "color": Color(0.15, 0.14, 0.13, 0.6), "size": Vector2(0.3, 0.5),
			"vel": Vector2(0.6, 1.0), "dir": Vector3.UP, "spread": 15.0, "additive": false, "grow": 2.5})


## Струя огнемёта от from к to.
func flame_stream(from: Vector3, to: Vector3, own: bool = false) -> void:
	var dir := to - from
	var length := dir.length()
	if length < 0.01:
		return
	var d := dir / length
	emit(from, {"amount": 10 if not own else 6, "life": 0.45, "color": Color("ffd23a"), "mid_color": Color("ff6a14"),
		"size": Vector2(0.28, 0.5) * (0.35 if own else 1.0), "vel": Vector2(length / 0.42, length / 0.3), "dir": d,
		"spread": 9.0, "gravity": -1.4, "additive": true, "grow": 2.2, "explosive": 0.5})
	if not own:
		flash_light(from + d * length * 0.5, Color("ff8a2a"), 2.2, 4.5, 0.12)
		if randf() < 0.4:
			emit(from + d * length * 0.7, {"amount": 2, "life": 0.9, "color": Color(0.2, 0.18, 0.16, 0.5), "size": Vector2(0.45, 0.8),
				"vel": Vector2(0.5, 1.2), "dir": Vector3.UP, "spread": 30.0, "additive": false, "grow": 2.4})


## Взрыв ракеты: вспышка, огненный шар, дым, осколки, ударная волна, копоть на земле, тряска камеры.
func blast(pos: Vector3, radius: float) -> void:
	flash_light(pos + Vector3(0, 0.5, 0), Color("ffb060"), 14.0, radius * 5.0, 0.35)
	emit(pos, {"amount": 22, "life": 0.7, "color": Color("fff0b0"), "mid_color": Color("ff7a1a"), "size": Vector2(0.7, 1.4) * radius,
		"vel": Vector2(0.5, radius * 2.5), "gravity": -0.5, "additive": true, "grow": 1.8, "radius": 0.2})
	emit(pos, {"amount": 16, "life": 1.6, "color": Color(0.22, 0.2, 0.18, 0.75), "size": Vector2(0.8, 1.5) * radius,
		"vel": Vector2(0.8, radius * 2.0), "dir": Vector3.UP, "spread": 60.0, "gravity": -0.3, "additive": false, "grow": 2.6, "explosive": 0.7})
	emit(pos, {"amount": 18, "life": 0.8, "color": Color("ffcf70"), "size": Vector2(0.06, 0.14), "vel": Vector2(4.0, 10.0),
		"dir": Vector3.UP, "spread": 70.0, "gravity": 14.0, "additive": true})
	# ударная волна
	var ring := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 0.92
	tor.outer_radius = 1.0
	tor.rings = 40
	tor.ring_segments = 6
	ring.mesh = tor
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	rm.albedo_color = Color(1.0, 0.75, 0.4, 0.55)
	ring.material_override = rm
	ring.position = pos + Vector3(0, 0.1, 0)
	ring.scale = Vector3(0.3, 0.05, 0.3)
	add_child(ring)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector3(radius * 1.8, 0.05, radius * 1.8), 0.35).set_ease(Tween.EASE_OUT)
	tw.tween_property(rm, "albedo_color:a", 0.0, 0.35)
	tw.chain().tween_callback(ring.queue_free)
	scorch_decal(pos, radius * 2.0)
	shake_requested.emit(clampf(radius * 0.35, 0.2, 0.8), pos)


func turret_explosion(pos: Vector3) -> void:
	blast(pos, 1.3)
	emit(pos, {"amount": 14, "life": 1.0, "color": Color("666666"), "size": Vector2(0.06, 0.16), "vel": Vector2(3.0, 7.0),
		"dir": Vector3.UP, "spread": 60.0, "gravity": 12.0, "additive": false})


func death_burst(pos: Vector3, big: bool = false) -> void:
	emit(pos + Vector3(0, 0.9, 0), {"amount": 16 if not big else 26, "life": 0.7, "color": Color(0.45, 0.6, 0.25, 0.9),
		"size": Vector2(0.2, 0.42), "vel": Vector2(1.2, 3.4), "gravity": 6.0, "additive": false, "grow": 0.5, "radius": 0.2})
	emit(pos + Vector3(0, 0.8, 0), {"amount": 8, "life": 0.6, "color": Color(0.5, 0.05, 0.04, 0.95), "size": Vector2(0.08, 0.2),
		"vel": Vector2(2.0, 5.0), "gravity": 12.0, "additive": false})
	blood_decal(pos)


# ───────────── декали ─────────────

func _add_decal(d: Decal) -> void:
	add_child(d)
	_decals.append(d)
	var limit := int([20, 36, MAX_DECALS, MAX_DECALS + 20][clampi(quality, 0, 3)])
	while _decals.size() > limit:
		var old: Decal = _decals.pop_front()
		if is_instance_valid(old):
			old.queue_free()


func blood_decal(pos: Vector3) -> void:
	var d := Decal.new()
	d.texture_albedo = _splat_tex[randi() % _splat_tex.size()]
	var s := randf_range(1.0, 1.7)
	d.size = Vector3(s, 1.2, s)
	d.position = Vector3(pos.x, 0.3, pos.z)
	d.rotation.y = randf() * TAU
	d.modulate = Color(1, 1, 1, 0.85)
	d.cull_mask = 1
	d.upper_fade = 0.3
	d.lower_fade = 0.3
	_add_decal(d)


func scorch_decal(pos: Vector3, diameter: float) -> void:
	var d := Decal.new()
	d.texture_albedo = _scorch_tex
	d.size = Vector3(diameter, 1.4, diameter)
	d.position = Vector3(pos.x, 0.3, pos.z)
	d.rotation.y = randf() * TAU
	d.modulate = Color(1, 1, 1, 0.9)
	_add_decal(d)


# ───────────── трассеры и текст ─────────────

func tracer(a: Vector3, b: Vector3, color: Color, width: float = 0.014) -> void:
	var len := a.distance_to(b)
	if len < 0.05:
		return
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = width
	cyl.bottom_radius = width
	cyl.height = len
	cyl.radial_segments = 4
	cyl.rings = 1
	mi.mesh = cyl
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.global_position = (a + b) * 0.5
	var up := Vector3.UP if absf((b - a).normalized().y) < 0.99 else Vector3.RIGHT
	mi.look_at(b, up)
	mi.rotate_object_local(Vector3.RIGHT, PI / 2.0)
	var tw := create_tween()
	tw.tween_property(m, "albedo_color:a", 0.0, 0.11)
	tw.tween_callback(mi.queue_free)


func float_text(text: String, pos: Vector3, color: Color = Color("ffe14d"), size: int = 56) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.0052
	l.modulate = color
	l.outline_size = 14
	l.outline_modulate = Color(0, 0, 0, 0.9)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = false
	l.position = pos
	add_child(l)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", pos.y + 1.3, 1.0).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 1.0).set_delay(0.35)
	tw.chain().tween_callback(l.queue_free)
