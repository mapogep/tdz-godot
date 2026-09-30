class_name CameraRig
extends Node3D
## Камера: стратегическая (над полем под углом, WASD/ПКМ-перетаскивание, колесо) и «из башни» (FPS).
## Плавное движение и зум, тряска экрана от взрывов, отдача при выстрелах.

var cam: Camera3D
var world: WorldView
var fps := false

var focus := Vector3(10, 0, 10)
var focus_target := Vector3(10, 0, 10)
var dist := 26.0
var dist_target := 26.0
var pitch := deg_to_rad(52.0)

var trauma := 0.0
var kick := 0.0
var _noise := FastNoiseLite.new()
var _t := 0.0


func _ready() -> void:
	cam = Camera3D.new()
	cam.current = true
	cam.far = 400.0
	cam.near = 0.08
	add_child(cam)
	_noise.seed = 77
	_noise.frequency = 1.8


func setup(p_world: WorldView, field_size: int) -> void:
	world = p_world
	focus = Vector3(field_size / 2.0, 0, field_size / 2.0)
	focus_target = focus


func add_shake(amount: float) -> void:
	trauma = minf(1.0, trauma + amount)


func add_kick(k: float) -> void:
	kick += k


func pan_pixels(dx: float, dy: float) -> void:
	var k := dist * 0.0017
	focus_target.x -= dx * k
	focus_target.z -= dy * k / sin(pitch)


func zoom(sign_dir: float) -> void:
	dist_target = clampf(dist_target * (1.0 + sign_dir * 0.1), 8.0, 60.0)


func _process(delta: float) -> void:
	_t += delta
	var vp := get_viewport().get_visible_rect().size
	var aspect := vp.x / maxf(vp.y, 1.0)
	trauma = maxf(0.0, trauma - delta * 1.6)
	kick *= exp(-delta * 9.0)
	var shake := trauma * trauma
	var sx := _noise.get_noise_2d(_t * 40.0, 0.0) * shake * 0.05
	var sy := _noise.get_noise_2d(0.0, _t * 40.0) * shake * 0.05

	if fps and world != null and world.fps_turret_id != 0:
		cam.fov = 72.0
		cam.global_position = world.fps_camera_position()
		cam.rotation = Vector3(world.fps_pitch + kick + sy, world.fps_yaw + PI + sx, 0.0)
		return

	# стратегическая камера
	cam.fov = 50.0 if aspect >= 1.4 else minf(75.0, rad_to_deg(2.0 * atan(tan(deg_to_rad(35.0)) / aspect)))
	var speed := dist * 0.9 * delta
	var mv := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): mv.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): mv.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): mv.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): mv.x += 1.0
	focus_target += Vector3(mv.x, 0, mv.y) * speed
	var fs := float(Cfg.FIELD_SIZE)
	focus_target.x = clampf(focus_target.x, -4.0, fs + 4.0)
	focus_target.z = clampf(focus_target.z, -4.0, fs + 4.0)
	focus = focus.lerp(focus_target, 1.0 - exp(-delta * 12.0))
	dist = lerpf(dist, dist_target, 1.0 - exp(-delta * 10.0))
	# в узком окне отодвигаем камеру, чтобы поле влезало по ширине
	var d := dist * minf(2.4, maxf(1.0, 1.15 / aspect))
	cam.global_position = focus + Vector3(0, d * sin(pitch), d * cos(pitch))
	cam.look_at(focus, Vector3.UP)
	cam.rotation += Vector3(sy, sx, 0.0)
