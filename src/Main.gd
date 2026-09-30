extends Node
## Корневой узел: меню ↔ игра. Host держит авторитетную симуляцию (GameSim) и рассылает снапшоты;
## клиент лишь показывает снапшоты и шлёт команды. Локальный игрок-Host применяет свои снапшоты напрямую.
##
## Параметры командной строки для проверок (после `--`):
##   --scenario=имя  --shot=путь.png@кадр[,путь2.png@кадр2]  --quality=0..3  --menu-shot=путь.png

const SAVE_PATH := "user://save.json"

var sim: GameSim
var st := ClientState.new()
var world: WorldView
var cam_rig: CameraRig
var hud: Hud
var input_ctl: InputCtl
var vm: ViewModel
var postfx: PostFx
var menu: MainMenu

var in_game := false
var is_client := false
var _acc := 0.0
var _walls_rev := -1
var _prev_snap: Dictionary = {}
var _frame := 0
var _args: Dictionary = {}
var _scenario_steps: Array = []
var _shots: Array = []


func _ready() -> void:
	_args = _parse_args()
	NetHub.command_received.connect(_on_command)
	NetHub.snapshot_received.connect(_on_remote_snapshot)
	NetHub.walls_received.connect(_apply_walls)
	NetHub.error_received.connect(func(code: String) -> void: _show_error(code))
	NetHub.peer_joined.connect(_on_peer_joined)
	NetHub.peer_left.connect(_on_peer_left)
	NetHub.host_lost.connect(func() -> void: _end_game("disconnected"))
	NetHub.connection_failed.connect(func() -> void: _end_game("join_failed"))
	_open_menu()
	if _args.has("quality"):
		Settings.quality = Settings.QUALITIES[clampi(int(_args["quality"]), 0, 3)]
	if _args.has("scenario"):
		_start_game("single", "", 0, false)
		_setup_scenario(str(_args["scenario"]))
	elif _args.has("auto"):
		_start_game(str(_args["auto"]), "127.0.0.1", 7791, false)
	elif _args.has("menu-shot"):
		_shots = [{"path": str(_args["menu-shot"]), "frame": 30}]


func _parse_args() -> Dictionary:
	var out := {}
	for a in OS.get_cmdline_user_args():
		var s := str(a)
		if s.begins_with("--"):
			var kv := s.substr(2).split("=", true, 1)
			out[kv[0]] = kv[1] if kv.size() > 1 else "1"
	if out.has("shot"):
		for part in str(out["shot"]).split(","):
			var pf := part.split("@")
			_shots.append({"path": pf[0], "frame": int(pf[1]) if pf.size() > 1 else 60})
	return out


# ───────────────────────── меню и запуск ─────────────────────────

func _open_menu() -> void:
	if menu != null:
		return
	menu = MainMenu.new()
	add_child(menu)
	menu.build()
	menu.refresh_save(FileAccess.file_exists(SAVE_PATH))
	menu.start_requested.connect(_start_game)
	menu.quit_requested.connect(func() -> void: get_tree().quit())
	Sfx.start_ambient()


func _start_game(mode: String, address: String, port: int, use_save: bool) -> void:
	if in_game:
		return
	is_client = mode == "join"
	st = ClientState.new()
	if mode == "single":
		NetHub.host_offline()
	elif mode == "host":
		var err := NetHub.host_game(port)
		if err != OK:
			menu.set_status("%s (%s)" % [I18n.t("join_failed"), error_string(err)])
			return
	else:
		var err2 := NetHub.join_game(address, port)
		if err2 != OK:
			menu.set_status("%s (%s)" % [I18n.t("join_failed"), error_string(err2)])
			return
		menu.set_status(I18n.t("connecting"))

	if not is_client:
		sim = GameSim.new(int(_args.get("money", Cfg.START_MONEY)))
		if _args.has("wave"):
			sim.wave = int(_args["wave"])
		sim.on_preparation = _autosave
		sim.on_game_over = func() -> void: DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
		if use_save and FileAccess.file_exists(SAVE_PATH):
			var d = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
			if d is Dictionary:
				sim.from_save(d)
		st.my_id = 1
		sim.add_player(1)
		_build_game()
		if mode == "host":
			var ips := NetHub.local_addresses()
			hud.toast("%s %s:%d" % [I18n.t("hosting"), ips[0] if ips.size() > 0 else "localhost", port])
	else:
		# клиент: ждём подключения, мир строим сразу (наполнится снапшотами)
		st.my_id = 0
		if not NetHub.connected_to_host.is_connected(_on_connected):
			NetHub.connected_to_host.connect(_on_connected)


func _on_connected() -> void:
	st.my_id = NetHub.my_id()
	if not in_game:
		_build_game()
		hud.set_conn(I18n.t("connected"))


func _build_game() -> void:
	in_game = true
	if menu != null:
		menu.queue_free()
		menu = null
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var q := Settings.q_index()
	world = WorldView.new()
	add_child(world)
	world.setup(st.nav, q)
	world.my_id = st.my_id
	world.shake_requested.connect(func(a: float, p: Vector3) -> void:
		var d := p.distance_to(cam_rig.cam.global_position)
		cam_rig.add_shake(a * clampf(1.6 - d / 30.0, 0.15, 1.0)))
	world.hit_confirmed.connect(func() -> void: hud.hit_marker())
	world.own_shot.connect(func(w: String) -> void:
		cam_rig.add_kick({"gun": 0.035, "machinegun": 0.012, "rocket": 0.09, "flame": 0.0, "ak": 0.018, "melee": 0.03}.get(w, 0.02)))
	cam_rig = CameraRig.new()
	add_child(cam_rig)
	cam_rig.setup(world, Cfg.FIELD_SIZE)
	vm = ViewModel.new()          # оружие от первого лица крепится к камере
	cam_rig.cam.add_child(vm)
	vm.visible = false
	postfx = PostFx.new()
	add_child(postfx)
	postfx.set_quality(q)
	hud = Hud.new()
	add_child(hud)
	hud.build(st)
	hud.action.connect(_on_hud_action)
	input_ctl = InputCtl.new()
	add_child(input_ctl)
	input_ctl.st = st
	input_ctl.world = world
	input_ctl.cam_rig = cam_rig
	input_ctl.hud = hud
	input_ctl.vm = vm
	world.free_fired.connect(func() -> void: vm.fire())
	world.free_swung.connect(func(m: String) -> void: vm.swing(float(Cfg.PWEAPONS[m]["cooldown"]) * 0.95))
	world.free_reloading.connect(func() -> void: vm.reload(float(Cfg.PWEAPONS["ak"]["reload"])))
	world.free_hurt.connect(func(a: float) -> void:
		hud.damage_flash(a)
		cam_rig.add_shake(0.22)
		Sfx.play("pain", null, -8.0))
	world.free_died.connect(func() -> void:
		hud.banner(I18n.t("dead_banner"))
		postfx.flash(0.9))
	world.free_revived.connect(func() -> void: hud.banner(I18n.t("revived")))
	input_ctl.send = _send_cmd
	input_ctl.state_changed.connect(hud.refresh)
	Settings.changed.connect(_on_settings_changed)
	Sfx.start_ambient()
	if not is_client:
		_apply_walls(sim.build.wall_cells())
		_walls_rev = sim.build.revision


func _on_settings_changed() -> void:
	if world == null:
		return
	var q := Settings.q_index()
	world.apply_quality(q)
	postfx.set_quality(q)


func _end_game(reason: String = "") -> void:
	if not in_game and reason == "":
		return
	in_game = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for n in [world, cam_rig, postfx, hud, input_ctl]:
		if n != null and is_instance_valid(n):
			n.queue_free()
	world = null
	cam_rig = null
	postfx = null
	hud = null
	input_ctl = null
	if Settings.changed.is_connected(_on_settings_changed):
		Settings.changed.disconnect(_on_settings_changed)
	NetHub.close()
	sim = null
	_prev_snap = {}
	_walls_rev = -1
	_open_menu()
	if reason != "":
		menu.set_status(I18n.t(reason))


# ───────────────────────── команды и снапшоты ─────────────────────────

func _send_cmd(msg: Dictionary) -> void:
	NetHub.send_command(msg)


func _on_command(pid: int, msg: Dictionary) -> void:
	if sim == null:
		return
	var res := sim.handle(pid, msg)
	if not res["ok"]:
		if pid == 1:
			_show_error(str(res["error"]))
		else:
			NetHub.send_error(pid, str(res["error"]))


func _show_error(code: String) -> void:
	if hud != null:
		hud.toast(I18n.t("err_" + code))
	Sfx.play("error")


func _on_peer_joined(id: int) -> void:
	if sim == null:
		return
	sim.add_player(id)
	NetHub.send_walls(sim.build.wall_cells(), id)


func _on_peer_left(id: int) -> void:
	if sim != null:
		sim.remove_player(id)


func _apply_walls(cells: Array) -> void:
	st.set_walls(cells)
	if world != null:
		world.set_walls(cells)


func _on_remote_snapshot(s: Dictionary) -> void:
	if in_game:
		_on_snapshot(s)


func _on_snapshot(s: Dictionary) -> void:
	_react_to_changes(_prev_snap, s)
	st.set_snapshot(s)
	world.apply_snapshot(s)
	hud.refresh()
	_prev_snap = s


## Звуки и баннеры по разнице между двумя снапшотами.
func _react_to_changes(old: Dictionary, cur: Dictionary) -> void:
	if old.is_empty():
		return
	if old["state"] != "WaveRunning" and cur["state"] == "WaveRunning":
		Sfx.play("wave_start")
		hud.banner("%s %d" % [I18n.t("wave"), int(cur["wave"])])
	if old["state"] != "GameOver" and cur["state"] == "GameOver":
		Sfx.play("game_over")
		postfx.flash(0.8)
	var ot: Array = old["turrets"]
	var ct: Array = cur["turrets"]
	if ct.size() > ot.size():
		Sfx.play("build")
	elif ct.size() < ot.size():
		var destroyed: Array = cur["destroyed"]
		if destroyed.is_empty():
			Sfx.play("sell")
	var lv := {}
	for t in ot:
		lv[int(t["id"])] = int(t["level"])
	for t in ct:
		if int(lv.get(int(t["id"]), t["level"])) < int(t["level"]):
			Sfx.play("upgrade")
			break
	if not cur["destroyed"].is_empty():
		postfx.flash(0.35)
	# редкие стоны зомби на поле
	if cur["zombies"].size() > 0 and randf() < 0.012:
		var z: Dictionary = cur["zombies"][randi() % cur["zombies"].size()]
		Sfx.play("groan", Vector3(z["x"], 1.5, z["z"]), -4.0)


func _on_hud_action(name: String, arg: Variant) -> void:
	match name:
		"startWave": _send_cmd({"t": "startWave"})
		"restart": _send_cmd({"t": "restart"})
		"tool": input_ctl.set_tool(str(arg))
		"weapon": input_ctl.set_weapon(str(arg))
		"selectTurret": input_ctl.select_turret(int(arg))
		"upgrade": _send_cmd({"t": "upgradeTurret", "id": int(arg)})
		"sell": _send_cmd({"t": "sellTurret", "id": int(arg)})
		"move": input_ctl.start_move()
		"enterFps": input_ctl.enter_fps(int(arg))
		"leaveFps": input_ctl.leave_fps()
		"resumeFps": input_ctl.resume_fps()
		"menu":
			hud.show_menu(true)
			input_ctl.enabled = false
		"closeMenu":
			hud.show_menu(false)
			input_ctl.enabled = true
		"toMenu": _end_game()


# ───────────────────────── автосохранение ─────────────────────────

func _autosave() -> void:
	if sim == null or is_client:
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(sim.to_save()))


# ───────────────────────── главный цикл ─────────────────────────

func _process(delta: float) -> void:
	_frame += 1
	if in_game and not is_client and sim != null:
		# фиксированный шаг симуляции; снапшот после каждого шага (события не теряются)
		_acc += minf(delta, 0.25)
		var dt := 1.0 / Cfg.TICK_RATE
		var steps := 0
		while _acc >= dt and steps < 4:
			_acc -= dt
			steps += 1
			sim.tick(dt)
			if sim.build.revision != _walls_rev:
				_walls_rev = sim.build.revision
				var cells := sim.build.wall_cells()
				_apply_walls(cells)
				NetHub.send_walls(cells)
			var snap := sim.snapshot()
			_on_snapshot(snap)
			NetHub.broadcast_snapshot(snap)
	if in_game and input_ctl != null:
		input_ctl.process_frame(delta)
	_run_scenario()
	_take_shots()


# ───────────────────────── сценарии для проверок ─────────────────────────

func _setup_scenario(name: String) -> void:
	# шаги: [кадр, Callable]; команды — только для Host (single)
	var build := func() -> void:
		for y in range(1, 19):
			_on_command(1, {"t": "buildWall", "x": 8, "y": y})
		_on_command(1, {"t": "buildTurret", "x": 8, "y": 17, "weapon": "gun"})
		_on_command(1, {"t": "buildTurret", "x": 8, "y": 15, "weapon": "machinegun"})
		_on_command(1, {"t": "buildTurret", "x": 8, "y": 13, "weapon": "rocket"})
		_on_command(1, {"t": "buildTurret", "x": 8, "y": 11, "weapon": "flame"})
	match name:
		"field":
			_scenario_steps = [[5, func() -> void: cam_rig.dist_target = 24.0]]
		"battle":
			_scenario_steps = [[3, func() -> void: sim.money = 6000; sim.wave = 8; sim.turret_stock = 8],
				[5, build], [10, func() -> void: _on_command(1, {"t": "startWave"})],
				[12, func() -> void: cam_rig.focus_target = Vector3(9, 0, 15); cam_rig.dist_target = 9.0]]
		"free", "free_melee":
			_scenario_steps = [[3, func() -> void: sim.money = 6000; sim.wave = 8; sim.turret_stock = 8],
				[5, build], [10, func() -> void: _on_command(1, {"t": "startWave"})],
				[20, func() -> void: input_ctl.go_free()],
				[40, func() -> void:
					for i in 6:
						sim.zombies.spawn(8, ["normal", "fat", "fast"][i % 3])
						var zz: SimZombie = sim.zombies.zombies.values()[sim.zombies.zombies.size() - 1]
						zz.x = 12.5 + i * 0.6
						zz.z = 8.6 + i * 0.4],
				[60, func() -> void:
					if name == "free_melee":
						input_ctl._set_free_weapon("melee")
					world.free_yaw = -PI / 2.0 + 0.1
					input_ctl._free_fire = true
					input_ctl._send_free(true)]]
		"rotate":
			_scenario_steps = [[5, func() -> void: cam_rig.dist_target = 22.0; cam_rig.yaw_target = 0.9]]
		"dead":
			_scenario_steps = [[3, func() -> void: sim.money = 6000; sim.wave = 8],
				[10, func() -> void: input_ctl.go_free()],
				[30, func() -> void: sim.fps.hurt(sim.fps.get_player(1), 500.0)]]
		"fps_mg", "fps_flame", "fps_rocket", "fps_gun":
			var w := name.substr(4)
			_scenario_steps = [[3, func() -> void: sim.money = 6000; sim.wave = 8; sim.turret_stock = 8],
				[5, build], [10, func() -> void: _on_command(1, {"t": "startWave"})],
				[40, func() -> void:
					for t: SimTurret in sim.turrets.turrets.values():
						if t.weapon == ("machinegun" if w == "mg" else w):
							input_ctl.enter_fps(t.id)
							break]]


func _run_scenario() -> void:
	for step in _scenario_steps:
		if step[0] == _frame:
			step[1].call()


func _take_shots() -> void:
	for s in _shots:
		if s["frame"] == _frame:
			var img := get_viewport().get_texture().get_image()
			DirAccess.make_dir_recursive_absolute(str(s["path"]).get_base_dir())
			img.save_png(s["path"])
			print("shot saved: ", s["path"], " ", img.get_size())
	if not _shots.is_empty() and _frame > int(_shots[-1]["frame"]) + 2:
		get_tree().quit()

