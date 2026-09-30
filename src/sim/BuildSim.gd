class_name BuildSim
extends RefCounted
## Строительство: стены, размещение/перенос/продажа турелей.
## Всё, что меняет проходимость (стены), проходит через NavSim.try_apply — путь Spawn → East Gate
## обязан сохраниться. Турели путь не блокируют: на земле они на пути зомби (их обходят/ломают), на стене — вне пути.
## Фазу игры и права (Host) проверяет вызывающий (GameSim.handle).

var sim
var walls: Dictionary = {}     # ключ y*size+x -> true
var revision := 0              # растёт при изменении стен — сеть по нему рассылает список стен


func _init(p_sim) -> void:
	sim = p_sim


func _key(x: int, y: int) -> int:
	return y * sim.nav.size + x


func wall_cells() -> Array:
	return walls.keys()


func has_wall(x: int, y: int) -> bool:
	return walls.has(_key(x, y))


func reset() -> void:
	walls.clear()
	sim.nav.reset()
	revision += 1


## Восстановление из сохранения: расставить стены без проверок стоимости.
func restore_walls(cells: Array) -> void:
	walls.clear()
	sim.nav.reset()
	var n: int = sim.nav.size
	for k in cells:
		var x: int = int(k) % n
		var y: int = int(k) / n
		if sim.nav.is_interior(x, y):
			walls[int(k)] = true
			sim.nav.set_blocked(x, y, true)
	revision += 1


## Пересчитывает, какие турели стоят на стенах (выше и вне маршрута зомби).
func refresh_elevation() -> void:
	for t: SimTurret in sim.turrets.turrets.values():
		t.elevated = has_wall(t.cx, t.cy)


func place_wall(x: int, y: int) -> Dictionary:
	if not sim.nav.is_interior(x, y):
		return GameSim.fail("invalidCell")
	if has_wall(x, y):
		return GameSim.fail("occupied")
	if not sim.eco_can_take_wall():
		return GameSim.fail("noResources")
	# стену можно поставить и под уже стоящую турель — она окажется на стене
	if not sim.nav.try_apply([{"x": x, "y": y, "blocked": true}]):
		return GameSim.fail("pathBlocked")
	sim.eco_take_wall()
	walls[_key(x, y)] = true
	refresh_elevation()
	revision += 1
	return GameSim.ok()


func remove_wall(x: int, y: int) -> Dictionary:
	if not sim.nav.is_interior(x, y):
		return GameSim.fail("invalidCell")
	var k := _key(x, y)
	if not walls.has(k):
		return GameSim.fail("noSuchObject")
	if sim.turrets.at_cell(x, y) != null:
		return GameSim.fail("occupied")     # сначала уберите турель со стены
	sim.nav.try_apply([{"x": x, "y": y, "blocked": false}])
	walls.erase(k)
	sim.eco_return_wall()
	refresh_elevation()
	revision += 1
	return GameSim.ok()


func place_turret(x: int, y: int, weapon: String) -> Dictionary:
	if not sim.nav.is_interior(x, y):
		return GameSim.fail("invalidCell")
	if sim.turrets.at_cell(x, y) != null:
		return GameSim.fail("occupied")
	if not sim.eco_can_take_turret(weapon):
		return GameSim.fail("noResources")
	sim.eco_take_turret(weapon)
	sim.turrets.create(x, y, weapon)
	refresh_elevation()
	return GameSim.ok()


func move_turret(id: int, x: int, y: int) -> Dictionary:
	var t: SimTurret = sim.turrets.turrets.get(id)
	if t == null:
		return GameSim.fail("noSuchObject")
	if t.cx == x and t.cy == y:
		return GameSim.ok()
	if not sim.nav.is_interior(x, y):
		return GameSim.fail("invalidCell")
	if sim.turrets.at_cell(x, y) != null:
		return GameSim.fail("occupied")
	t.cx = x
	t.cy = y
	refresh_elevation()
	return GameSim.ok()


## Продажа: возврат sell_mul × вложенного (база + улучшения).
func sell_turret(id: int) -> Dictionary:
	var t: SimTurret = sim.turrets.turrets.get(id)
	if t == null:
		return GameSim.fail("noSuchObject")
	sim.eco_add_money(Cfg.sell_value(t.invested))
	sim.turrets.remove(id)
	return GameSim.ok()
