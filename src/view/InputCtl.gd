class_name InputCtl
extends Node
## Ввод игрока: инструменты строительства, клики по полю, выбор турелей и режим «из башни» (FPS:
## захват мыши, прицел на 360° без рывков, огонь, пауза при потере захвата).

signal state_changed()               # изменились инструмент/выбор — обновить интерфейс

const INPUT_INTERVAL := 1.0 / 30.0
const MAX_MOUSE_STEP := 300.0        # «скачки» курсора отбрасываем

var st: ClientState
var world: WorldView
var cam_rig: CameraRig
var send: Callable = Callable()      # (msg: Dictionary) -> void
var hud                              # Hud (без типа, чтобы не создавать циклическую зависимость)

var enabled := true
var pointer := Vector2.ZERO
var hover: Variant = null
var fps_active := false
var fps_paused := false
var _left_down := false
var _rmb_down := false
var _rmb_moved := false
var _last_acted := ""
var _firing := false
var _last_sent := 0.0
var _want_fps := false

# «Свободный FPS»
var free_active := false
var free_paused := false
var free_weapon := "ak"           # ak | melee
var vm: ViewModel                     # оружие от первого лица (создаёт Main)
var _want_free := 0.0                # сколько ещё ждём подтверждения входа от Host
var _free_fire := false
var _free_sent := 0.0
var _free_phase := 0.0
var _free_step := 0.0
var _free_speed := 0.0
var _free_sprint := false
var _look := Vector2.ZERO
var _melee_kind := "machete"


# ───────────────────────── события ─────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if not enabled or st == null or not st.has_snap():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F1:
			go_strategy()
			return
		if event.keycode == KEY_F2:
			go_free()
			return
		if event.keycode == KEY_F5:
			_send({"t": "startWave"})      # начать волну досрочно (решает Host; вне подготовки — подсказка об ошибке)
			return
	if free_active:
		_free_event(event)
		return
	if fps_active:
		_fps_event(event)
		return
	if event is InputEventMouseMotion:
		var e := event as InputEventMouseMotion
		pointer = e.position
		hover = world.ground_cell(cam_rig.cam, pointer)
		if (e.button_mask & MOUSE_BUTTON_MASK_MIDDLE) != 0:
			cam_rig.rotate_pixels(e.relative.x)     # средняя кнопка — вращение камеры
			_rmb_moved = true
		elif _rmb_down:
			cam_rig.pan_pixels(e.relative.x, e.relative.y)
			_rmb_moved = true
		elif _left_down:
			_paint()
	elif event is InputEventMouseButton:
		var b := event as InputEventMouseButton
		pointer = b.position
		match b.button_index:
			MOUSE_BUTTON_LEFT:
				if b.pressed:
					_left_down = true
					_last_acted = ""
					hover = world.ground_cell(cam_rig.cam, pointer)
					_click()
				else:
					_left_down = false
			MOUSE_BUTTON_RIGHT:
				if b.pressed:
					_rmb_down = true
					_rmb_moved = false
				else:
					_rmb_down = false
					if not _rmb_moved:
						cancel()      # ПКМ без перетаскивания — отмена инструмента
			MOUSE_BUTTON_MIDDLE:
				_rmb_moved = true
			MOUSE_BUTTON_WHEEL_UP:
				if b.pressed: cam_rig.zoom(-1.0)
			MOUSE_BUTTON_WHEEL_DOWN:
				if b.pressed: cam_rig.zoom(1.0)
	elif event is InputEventKey and event.pressed and not event.echo:
		_key(event as InputEventKey)


func _key(e: InputEventKey) -> void:
	if e.keycode == KEY_ESCAPE:
		cancel()
		return
	if e.keycode == KEY_T:
		cycle_turret(-1 if e.shift_pressed else 1)
		return
	if not st.can_build():
		return
	match e.keycode:
		KEY_1: set_tool("select")
		KEY_2: set_tool("wall")
		KEY_3: set_tool("remove")
		KEY_4: set_weapon("gun")
		KEY_5: set_weapon("machinegun")
		KEY_6: set_weapon("rocket")
		KEY_7: set_weapon("flame")


func _fps_event(event: InputEvent) -> void:
	if fps_paused:
		if event is InputEventMouseButton and event.pressed:
			resume_fps()
		elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			leave_fps()
		return
	if event is InputEventMouseMotion:
		var m := event as InputEventMouseMotion
		if absf(m.relative.x) > MAX_MOUSE_STEP or absf(m.relative.y) > MAX_MOUSE_STEP:
			return
		var sens := Settings.mouse_sens
		# угол держим в (-π, π]: сколько ни крути мышью, полный оборот проходит плавно
		world.fps_yaw = wrapf(world.fps_yaw - m.relative.x * sens, -PI, PI)
		world.fps_pitch = clampf(world.fps_pitch - m.relative.y * sens, -1.2, 1.2)
	elif event is InputEventMouseButton:
		var b := event as InputEventMouseButton
		if b.button_index == MOUSE_BUTTON_LEFT:
			_firing = b.pressed
			_send_input(true)
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		pause_fps()      # ESC снимает захват мыши и ставит на паузу; второй ESC — выйти


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and fps_active and not fps_paused:
		pause_fps()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT and free_active and not free_paused:
		pause_free()


# ───────────────────────── инструменты ─────────────────────────

func set_tool(t: String) -> void:
	st.tool = t
	st.moving = false
	state_changed.emit()


func set_weapon(w: String) -> void:
	st.tool = "turret"
	st.weapon = w
	st.moving = false
	state_changed.emit()


func start_move() -> void:
	if not st.can_build() or st.selected_turret == 0:
		return
	st.moving = not st.moving
	st.tool = "select"
	state_changed.emit()


func cancel() -> void:
	st.tool = "select"
	st.moving = false
	st.selected_turret = 0
	state_changed.emit()


## Выбор турели без клика по модели (список турелей).
func select_turret(id: int) -> void:
	st.selected_turret = id
	st.moving = false
	if id != 0:
		st.tool = "select"
	state_changed.emit()


## Следующая турель по кругу (клавиша T).
func cycle_turret(dir: int = 1) -> void:
	var list: Array = st.snap.get("turrets", [])
	if list.is_empty():
		return
	var i := -1
	for k in list.size():
		if int(list[k]["id"]) == st.selected_turret:
			i = k
	select_turret(int(list[(i + dir + list.size()) % list.size()]["id"]))


# ───────────────────────── клики по полю ─────────────────────────

func _target_cell() -> Variant:
	if not st.moving and st.tool == "remove":
		var w: Variant = world.pick_wall(cam_rig.cam, pointer)
		return w if w != null else hover
	if not st.moving and st.tool == "select":
		var id := world.pick_turret(cam_rig.cam, pointer)
		if id != 0:
			var t := st.turret_by_id(id)
			return Vector2i(int(t["cx"]), int(t["cy"]))
	return hover


func _click() -> void:
	var c: Variant = _target_cell()
	if c == null:
		return
	var cell: Vector2i = c
	_last_acted = "%d,%d" % [cell.x, cell.y]
	if st.moving and st.selected_turret != 0:
		_send({"t": "moveTurret", "id": st.selected_turret, "x": cell.x, "y": cell.y})
		st.moving = false
		state_changed.emit()
		return
	if not st.can_build() and st.tool != "select":
		return
	match st.tool:
		"wall": _send({"t": "buildWall", "x": cell.x, "y": cell.y})
		"remove": _send({"t": "removeWall", "x": cell.x, "y": cell.y})
		"turret": _send({"t": "buildTurret", "x": cell.x, "y": cell.y, "weapon": st.weapon})
		"select":
			var t := st.turret_at(cell.x, cell.y)
			st.selected_turret = int(t["id"]) if not t.is_empty() else 0
			st.moving = false
	state_changed.emit()


## Рисование стен/сноса перетаскиванием.
func _paint() -> void:
	var c: Variant = _target_cell()
	if c == null or (st.tool != "wall" and st.tool != "remove") or st.moving:
		return
	var cell: Vector2i = c
	if "%d,%d" % [cell.x, cell.y] == _last_acted:
		return
	_click()


func _send(msg: Dictionary) -> void:
	if send.is_valid():
		send.call(msg)


# ───────────────────────── FPS ─────────────────────────

## Клик по кнопке «FPS»: просим у Host турель и захватываем мышь (нужен жест пользователя).
func enter_fps(id: int) -> void:
	_want_fps = true
	_send({"t": "enterTurret", "id": id})


func _activate_fps(t: Dictionary) -> void:
	fps_active = true
	fps_paused = false
	_want_fps = false
	world.set_fps_turret(int(t["id"]), float(t["yaw"]), float(t["pitch"]))
	cam_rig.fps = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Sfx.play("enter")
	hud.set_pause(false)
	state_changed.emit()


func _deactivate_fps() -> void:
	fps_active = false
	fps_paused = false
	_firing = false
	world.set_fps_turret(0)
	cam_rig.fps = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.set_pause(false)
	state_changed.emit()


func pause_fps() -> void:
	fps_paused = true
	if _firing:
		_firing = false
		_send_input(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.set_pause(true)


## Клик по паузе: снова захватываем мышь.
func resume_fps() -> void:
	if free_active:
		resume_free()
		return
	fps_paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hud.set_pause(false)


## Выйти из турели (кнопка на паузе или второй ESC).
func leave_fps() -> void:
	if free_active:
		go_strategy()
		return
	_send({"t": "exitTurret"})
	_deactivate_fps()


func _send_input(force: bool) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if not force and now - _last_sent < INPUT_INTERVAL:
		return
	_last_sent = now
	_send({"t": "input", "yaw": world.fps_yaw, "pitch": world.fps_pitch, "firing": _firing})


# ───────────────────────── каждый кадр ─────────────────────────

func process_frame(_delta: float) -> void:
	if st == null or not st.has_snap():
		return
	if _free_update(_delta):
		return
	# вход/выход из FPS по данным Host
	var mine := st.my_turret()
	if not mine.is_empty() and not fps_active and _want_fps:
		_activate_fps(mine)
	elif mine.is_empty() and fps_active:
		_deactivate_fps()     # турель продана/разрушена или конец игры
	elif not mine.is_empty() and not fps_active and not _want_fps:
		_activate_fps(mine)
		pause_fps()           # вошли не кликом (другой путь) — ждём клика для захвата мыши

	if fps_active:
		if not fps_paused:
			_send_input(false)
		world.set_ghost(null, false, false, 0.0, 0.0)
		return

	# выбор и подсветка
	world.clear_selection_visuals()
	if st.selected_turret != 0:
		if st.turret_by_id(st.selected_turret).is_empty():
			st.selected_turret = 0
			st.moving = false
		else:
			world.set_selection(st.selected_turret)
	_update_ghost()


func _update_ghost() -> void:
	if hover == null or not st.can_build() or (st.tool == "select" and not st.moving):
		world.set_ghost(null, false, false, 0.0, 0.0)
		return
	var c: Vector2i = hover
	var s := st.snap
	if st.moving and st.selected_turret != 0:
		var t := st.turret_by_id(st.selected_turret)
		var rng_m := float(Cfg.turret_stats(int(t["level"]), str(t["weapon"]))["range"]) if not t.is_empty() else 0.0
		world.set_ghost(c, st.can_place_turret(c.x, c.y), true, rng_m, Cfg.WALL_HEIGHT if st.has_wall(c.x, c.y) else 0.0)
		return
	match st.tool:
		"wall":
			var ok := st.can_place_wall(c.x, c.y) and (int(s["walls_left"]) > 0 or int(s["money"]) >= Cfg.WALL_COST)
			world.set_ghost(c, ok, true, 0.0, 0.0)
		"remove":
			var w: Variant = world.pick_wall(cam_rig.cam, pointer)
			var wc: Vector2i = w if w != null else c
			world.set_ghost(wc, st.has_wall(wc.x, wc.y) and st.turret_at(wc.x, wc.y).is_empty(), false, 0.0, 0.0)
		"turret":
			var wp := st.weapon
			var afford := (wp == "gun" and int(s["turrets_left"]) > 0) or int(s["money"]) >= Cfg.turret_cost(wp)
			world.set_ghost(c, st.can_place_turret(c.x, c.y) and afford, true,
				float(Cfg.turret_stats(1, wp)["range"]), Cfg.WALL_HEIGHT if st.has_wall(c.x, c.y) else 0.0)


# ───────────────────────── «Свободный FPS» ─────────────────────────

const FREE_SEND_INTERVAL := 1.0 / 30.0


## F1 — режим стратегии: выходим из турели и из свободного FPS.
func go_strategy() -> void:
	if fps_active:
		_send({"t": "exitTurret"})
		_deactivate_fps()
	if free_active or st.in_free_fps():
		_send({"t": "fpsExit"})
		_deactivate_free()
	_want_free = 0.0


## F2 — режим свободного FPS: игрок появляется у восточных ворот.
func go_free() -> void:
	if st.is_dead():
		if hud != null:
			hud.toast(I18n.t("err_dead"))
		Sfx.play("error")
		return
	if str(st.snap.get("state", "")) == "GameOver" or free_active:
		return
	if fps_active:
		_send({"t": "exitTurret"})
		_deactivate_fps()
	_want_free = 1.5
	_send({"t": "fpsEnter"})


func _activate_free(f: Dictionary) -> void:
	free_active = true
	free_paused = false
	_want_free = 0.0
	_free_fire = false
	free_weapon = "ak"
	_melee_kind = str(f["melee"])
	world.free_active = true
	world.free_pos = Vector3(f["x"], 0.0, f["z"])
	world.free_yaw = float(f["yaw"])
	world.free_pitch = 0.0
	cam_rig.free = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if vm != null:
		vm.visible = true
		vm.set_weapon_now("ak")
	hud.set_pause(false)
	Sfx.play("enter")
	state_changed.emit()


func _deactivate_free() -> void:
	free_active = false
	free_paused = false
	_free_fire = false
	world.free_active = false
	cam_rig.free = false
	cam_rig.free_bob = 0.0
	cam_rig.free_roll = 0.0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if vm != null:
		vm.visible = false
	hud.set_pause(false)
	state_changed.emit()


func pause_free() -> void:
	free_paused = true
	if _free_fire:
		_free_fire = false
		_send_free(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.set_pause(true)


func resume_free() -> void:
	free_paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hud.set_pause(false)


func _free_event(event: InputEvent) -> void:
	if free_paused:
		if event is InputEventMouseButton and event.pressed:
			resume_free()
		elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			go_strategy()
		return
	if event is InputEventMouseMotion:
		var m := event as InputEventMouseMotion
		if absf(m.relative.x) > MAX_MOUSE_STEP or absf(m.relative.y) > MAX_MOUSE_STEP:
			return
		var sens := Settings.mouse_sens
		world.free_yaw = wrapf(world.free_yaw - m.relative.x * sens, -PI, PI)
		world.free_pitch = clampf(world.free_pitch - m.relative.y * sens, -1.35, 1.35)
		_look += Vector2(m.relative.x, m.relative.y) * sens
	elif event is InputEventMouseButton:
		var b := event as InputEventMouseButton
		match b.button_index:
			MOUSE_BUTTON_LEFT:
				_free_fire = b.pressed
				if b.pressed:
					var f := st.my_fps()
					if free_weapon == "ak" and int(f.get("ammo", 0)) == 0 and int(f.get("mags", 0)) == 0:
						Sfx.play("empty")
				_send_free(true)
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
				if b.pressed:
					_set_free_weapon("melee" if free_weapon == "ak" else "ak")
	elif event is InputEventKey and event.pressed and not event.echo:
		match (event as InputEventKey).keycode:
			KEY_ESCAPE: pause_free()
			KEY_R:
				if free_weapon == "ak":
					_send({"t": "fpsReload"})
			KEY_1: _set_free_weapon("ak")
			KEY_2: _set_free_weapon("melee")
			KEY_V: _set_free_weapon("melee")


func _set_free_weapon(w: String) -> void:
	if w == free_weapon:
		return
	free_weapon = w
	if vm != null:
		vm.switch_to("ak" if w == "ak" else _melee_kind)
	Sfx.play("click", null, -8.0)
	_send_free(true)


func _cell_blocked(px: float, pz: float) -> bool:
	var cx := int(floor(px)) + 1
	var cy := int(floor(pz)) + 1
	if not st.nav.in_bounds(cx, cy):
		return false
	if st.nav.is_blocked(cx, cy):
		return true
	return not st.turret_at(cx, cy).is_empty()


func _free_ok(px: float, pz: float) -> bool:
	var r := float(Cfg.PLAYER["radius"])
	return not (_cell_blocked(px - r, pz - r) or _cell_blocked(px + r, pz - r) or _cell_blocked(px - r, pz + r) or _cell_blocked(px + r, pz + r))


func _send_free(force: bool) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if not force and now - _free_sent < FREE_SEND_INTERVAL:
		return
	_free_sent = now
	_send({"t": "fpsMove", "x": world.free_pos.x, "z": world.free_pos.z, "yaw": world.free_yaw,
		"pitch": world.free_pitch, "fire": _free_fire and not free_paused, "weapon": free_weapon, "sprint": _free_sprint})


## Каждый кадр в режиме свободного FPS; возвращает true, если этот режим сейчас активен (стратегические подсказки не нужны).
func _free_update(delta: float) -> bool:
	if _want_free > 0.0:
		_want_free -= delta
	var f := st.my_fps()
	var host_free := st.in_free_fps()
	if host_free and not free_active and _want_free > 0.0:
		_activate_free(f)
	elif not host_free and free_active:
		_deactivate_free()
	if not free_active:
		return false
	world.set_ghost(null, false, false, 0.0, 0.0)
	world.clear_selection_visuals()
	if free_paused:
		return true

	# движение: WASD относительно взгляда, Shift — бег; столкновения проверяются так же, как на Host
	var yaw := world.free_yaw
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_W): dir.y += 1.0
	if Input.is_key_pressed(KEY_S): dir.y -= 1.0
	if Input.is_key_pressed(KEY_A): dir.x -= 1.0
	if Input.is_key_pressed(KEY_D): dir.x += 1.0
	var fwd := Vector2(sin(yaw), cos(yaw))
	var right := Vector2(-cos(yaw), sin(yaw))
	var wish := fwd * dir.y + right * dir.x
	if wish.length() > 1.0:
		wish = wish.normalized()
	_free_sprint = Input.is_key_pressed(KEY_SHIFT) and dir.y > 0.0
	var speed := float(Cfg.PLAYER["speed"]) * (float(Cfg.PLAYER["sprint_mul"]) if _free_sprint else 1.0)
	var step := wish * speed * delta
	var pos := world.free_pos
	var lo := float(Cfg.PLAYER["bounds_min"])
	var hi := float(Cfg.PLAYER["bounds_max"])
	var tx := clampf(pos.x + step.x, lo, hi)
	var tz := clampf(pos.z + step.y, lo, hi)
	if _free_ok(tx, tz):
		pos.x = tx
		pos.z = tz
	elif _free_ok(tx, pos.z):
		pos.x = tx
	elif _free_ok(pos.x, tz):
		pos.z = tz
	var moved := Vector2(pos.x - world.free_pos.x, pos.z - world.free_pos.z).length()
	world.free_pos = pos
	_free_speed = lerpf(_free_speed, moved / maxf(delta, 0.0001), 1.0 - exp(-delta * 12.0))
	var move_frac := clampf(_free_speed / float(Cfg.PLAYER["speed"]), 0.0, 1.6)
	_free_phase += delta * (7.5 + 3.5 * float(_free_sprint)) * minf(move_frac, 1.0)
	cam_rig.free_bob = sin(_free_phase) * 0.028 * minf(move_frac, 1.0) + sin(_free_phase * 0.5) * 0.006
	cam_rig.free_roll = lerpf(cam_rig.free_roll, -dir.x * 0.018 * minf(move_frac, 1.0), 1.0 - exp(-delta * 8.0))
	_free_step += moved
	if _free_step > (2.5 if _free_sprint else 1.9):
		_free_step = 0.0
		Sfx.play("step", null, -16.0)

	# Host — авторитет: сильное расхождение (упёрлись в проверку скорости/стену) → возвращаемся к его позиции
	if not f.is_empty():
		var hp := Vector2(float(f["x"]) - pos.x, float(f["z"]) - pos.z)
		if hp.length() > 1.6:
			world.free_pos = Vector3(f["x"], 0.0, f["z"])

	_send_free(false)
	if vm != null:
		vm.update(delta, minf(move_frac, 1.0), _look, _free_sprint)
	_look = Vector2.ZERO
	return true