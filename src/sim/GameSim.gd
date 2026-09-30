class_name GameSim
extends RefCounted
## Авторитетная симуляция игры (host). Собирает все системы, применяет команды игроков
## (проверяя права Host и фазу), ведёт состояние игры и волны. Не зависит от сцены и сети.
##
## Состояния: Preparation → WaveRunning → WaveCompleted → Preparation … GameOver.

var start_money: int = Cfg.START_MONEY

var nav: NavSim
var zombies: ZombieSim
var turrets: TurretSim
var build: BuildSim

# экономика
var money: int = 0
var wall_stock: int = 0
var turret_stock: int = 0
var money_earned: int = 0
var zombies_killed: int = 0

# игроки: peer_id -> {"name": String}
var players: Dictionary = {}
var host_id: int = 0

# состояние игры и волны
var state: String = "Preparation"
var wave: int = 1
var prep_left: float = Cfg.PREP_TIME
var _queue: Array = []
var _spawn_cd: float = 0.0
var _wave_spawn_wave: int = 1

# события одного тика (выстрелы, смерти, взрывы) — уходят клиентам в снапшоте
var events: Dictionary = {}

# хуки (Callable): вход в подготовку (автосохранение) и поражение
var on_preparation: Callable = Callable()
var on_game_over: Callable = Callable()


static func ok() -> Dictionary:
	return {"ok": true}


static func fail(code: String) -> Dictionary:
	return {"ok": false, "error": code}


func _init(p_start_money: int = Cfg.START_MONEY) -> void:
	start_money = p_start_money
	_reset_events()
	nav = NavSim.new()
	zombies = ZombieSim.new(self)
	turrets = TurretSim.new(self)
	build = BuildSim.new(self)
	eco_reset()


func _reset_events() -> void:
	events = {"shots": [], "deaths": [], "destroyed": [], "explosions": []}


# ───────────── экономика ─────────────

func eco_reset() -> void:
	money = start_money
	wall_stock = Cfg.START_WALLS
	turret_stock = Cfg.START_TURRETS
	money_earned = 0
	zombies_killed = 0


func eco_reward(amount: int) -> void:
	money += amount
	money_earned += amount
	zombies_killed += 1


func eco_spend(cost: int) -> bool:
	if money < cost:
		return false
	money -= cost
	return true


func eco_add_money(amount: int) -> void:
	money += amount


func eco_can_take_wall() -> bool:
	return wall_stock > 0 or money >= Cfg.WALL_COST


func eco_take_wall() -> bool:
	if wall_stock > 0:
		wall_stock -= 1
		return true
	return eco_spend(Cfg.WALL_COST)


func eco_return_wall() -> void:
	wall_stock += 1


func _uses_free_stock(weapon: String) -> bool:
	return weapon == "gun" and turret_stock > 0


func eco_can_take_turret(weapon: String) -> bool:
	return _uses_free_stock(weapon) or money >= Cfg.turret_cost(weapon)


func eco_take_turret(weapon: String) -> bool:
	if _uses_free_stock(weapon):
		turret_stock -= 1
		return true
	return eco_spend(Cfg.turret_cost(weapon))


# ───────────── игроки ─────────────

func add_player(id: int) -> String:
	var name := "Player %d" % id
	players[id] = {"name": name}
	if host_id == 0:
		host_id = id
	return name


func remove_player(id: int) -> void:
	players.erase(id)
	turrets.release_player(id)
	if host_id == id:
		host_id = 0
		for k in players.keys():
			host_id = k
			break


func is_host(id: int) -> bool:
	return host_id == id


# ───────────── состояние игры ─────────────

func is_preparation() -> bool:
	return state == "Preparation"


func start_wave() -> bool:
	if state != "Preparation":
		return false
	state = "WaveRunning"
	_wave_spawn_wave = wave
	_queue = Cfg.wave_composition(wave)
	_spawn_cd = 0.0
	return true


func restart() -> bool:
	if state != "GameOver":
		return false
	zombies.clear()
	_queue.clear()
	turrets.release_all()
	eco_reset()
	turrets.reset()
	build.reset()
	wave = 1
	_enter_preparation()
	return true


## Восстановление из сохранения.
func restore_wave(w: int) -> void:
	wave = w
	_enter_preparation()


func _enter_preparation() -> void:
	state = "Preparation"
	prep_left = Cfg.PREP_TIME
	turrets.repair_all()      # между волнами турели чинятся бесплатно
	if on_preparation.is_valid():
		on_preparation.call()


func _wave_update(dt: float) -> void:
	if _queue.is_empty():
		return
	_spawn_cd -= dt
	if _spawn_cd <= 0.0:
		if zombies.spawn(_wave_spawn_wave, _queue[0]):
			_queue.pop_front()
		_spawn_cd = float(Cfg.WAVE["spawn_interval"])


func _wave_finished() -> bool:
	return _queue.is_empty() and zombies.count() == 0


## Один тик симуляции (dt — секунды).
func tick(dt: float) -> void:
	match state:
		"Preparation":
			prep_left -= dt
			turrets.update(dt)   # занятые игроками турели вращаются и между волнами
			if prep_left <= 0.0:
				start_wave()
		"WaveRunning":
			_wave_update(dt)
			turrets.update(dt)
			if zombies.update(dt):
				state = "GameOver"   # зомби остаются замороженными на месте
				turrets.release_all()
				if on_game_over.is_valid():
					on_game_over.call()
			elif _wave_finished():
				state = "WaveCompleted"
		"WaveCompleted":
			wave += 1
			_enter_preparation()


# ───────────── команды игроков ─────────────

## Применяет команду. Клиент присылает только намерение; результат решает симуляция.
func handle(pid: int, msg: Dictionary) -> Dictionary:
	var host := is_host(pid)
	var prep := is_preparation()
	var t: String = str(msg.get("t", ""))
	match t:
		"startWave":
			if not host: return fail("notHost")
			return ok() if start_wave() else fail("wrongPhase")
		"restart":
			if not host: return fail("notHost")
			return ok() if restart() else fail("wrongPhase")
		"buildWall", "removeWall", "buildTurret", "moveTurret", "sellTurret", "upgradeTurret":
			if not host: return fail("notHost")
			if not prep: return fail("wrongPhase")
			return _handle_build(t, msg)
		"enterTurret":
			if not msg.has("id"): return fail("invalid")
			if state == "GameOver": return fail("wrongPhase")
			return turrets.enter(int(msg["id"]), pid)
		"exitTurret":
			turrets.release_player(pid)
			return ok()
		"input":
			if not (msg.has("yaw") and msg.has("pitch")): return fail("invalid")
			turrets.set_input(pid, float(msg["yaw"]), float(msg["pitch"]), bool(msg.get("firing", false)))
			return ok()
	return fail("invalid")


func _handle_build(t: String, msg: Dictionary) -> Dictionary:
	match t:
		"buildWall", "removeWall":
			if not (msg.has("x") and msg.has("y")): return fail("invalid")
			var x := int(msg["x"])
			var y := int(msg["y"])
			return build.place_wall(x, y) if t == "buildWall" else build.remove_wall(x, y)
		"buildTurret":
			if not (msg.has("x") and msg.has("y") and msg.has("weapon")): return fail("invalid")
			var weapon := str(msg["weapon"])
			if not Cfg.WEAPON_TYPES.has(weapon): return fail("invalid")
			return build.place_turret(int(msg["x"]), int(msg["y"]), weapon)
		"moveTurret":
			if not (msg.has("id") and msg.has("x") and msg.has("y")): return fail("invalid")
			return build.move_turret(int(msg["id"]), int(msg["x"]), int(msg["y"]))
		"sellTurret":
			if not msg.has("id"): return fail("invalid")
			var sold: SimTurret = turrets.turrets.get(int(msg["id"]))
			if sold != null:
				sold.controlled_by = 0     # игрока в проданной турели выбрасываем
			return build.sell_turret(int(msg["id"]))
		"upgradeTurret":
			if not msg.has("id"): return fail("invalid")
			return turrets.upgrade(int(msg["id"]))
	return fail("invalid")


# ───────────── снапшот и сохранение ─────────────

func snapshot() -> Dictionary:
	var pl: Array = []
	for id in players.keys():
		var tur := turrets.turret_of(int(id))
		pl.append({"id": id, "name": players[id]["name"], "is_host": int(id) == host_id,
			"turret_id": tur.id if tur != null else 0})
	var s := {
		"state": state, "wave": wave, "prep_left": int(ceil(maxf(0.0, prep_left))),
		"money": money, "walls_left": wall_stock, "turrets_left": turret_stock,
		"zombies": zombies.snapshot(), "turrets": turrets.snapshot(), "players": pl,
		"rockets": turrets.rockets_snapshot(),
		"shots": events["shots"], "deaths": events["deaths"], "destroyed": events["destroyed"],
		"explosions": events["explosions"],
		"killed": zombies_killed, "earned": money_earned,
	}
	_reset_events()
	return s


func to_save() -> Dictionary:
	var ts: Array = []
	for t: SimTurret in turrets.turrets.values():
		ts.append({"cx": t.cx, "cy": t.cy, "level": t.level, "invested": t.invested, "weapon": t.weapon})
	return {"v": 1, "wave": wave, "money": money, "wall_stock": wall_stock, "turret_stock": turret_stock,
		"earned": money_earned, "killed": zombies_killed, "walls": build.wall_cells(), "turrets": ts}


func from_save(d: Dictionary) -> bool:
	if int(d.get("v", 0)) != 1 or int(d.get("wave", 0)) < 1:
		return false
	money = int(d["money"])
	wall_stock = int(d["wall_stock"])
	turret_stock = int(d["turret_stock"])
	money_earned = int(d["earned"])
	zombies_killed = int(d["killed"])
	build.restore_walls(d["walls"])
	for s in d["turrets"]:
		var cx := int(s["cx"])
		var cy := int(s["cy"])
		if not nav.is_interior(cx, cy) or turrets.at_cell(cx, cy) != null:
			continue
		var t := turrets.create(cx, cy, str(s.get("weapon", "gun")))
		t.level = int(s["level"])
		t.invested = int(s["invested"])
		var st := t.stats()
		t.ammo = int(st["mag"])
		t.hp = float(st["hp"])
	build.refresh_elevation()
	restore_wave(int(d["wave"]))
	return true
