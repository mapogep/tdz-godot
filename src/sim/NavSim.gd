class_name NavSim
extends RefCounted
## Навигационная сетка и маршруты зомби. Сетка включает кольцо внешней стены: размер (поле + 2)².
## Клетка (x,y): игровое поле занимает 1..FIELD_SIZE; мир: world = cell - 1.
## Ворота — проёмы в кольце: запад x=0, восток x=size-1. Поиск пути — встроенный AStarGrid2D.

const TURRET_CROSSING_COST := 25.0   # штраф за клетку с турелью в запасном маршруте

var size: int
var field_size: int
var gate_rows: Array = []
var _blocked: PackedByteArray
var _astar: AStarGrid2D


func _init(p_field: int = Cfg.FIELD_SIZE, p_gate: int = Cfg.GATE_WIDTH) -> void:
	field_size = p_field
	size = p_field + 2
	_blocked = PackedByteArray()
	_blocked.resize(size * size)
	var first := 1 + (p_field - p_gate) / 2
	gate_rows = []
	for i in p_gate:
		gate_rows.append(first + i)
	_astar = AStarGrid2D.new()
	_astar.region = Rect2i(0, 0, size, size)
	_astar.cell_size = Vector2.ONE
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES   # без срезания углов
	_astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_astar.update()
	for i in size:
		_set_raw(i, 0, true)
		_set_raw(i, size - 1, true)
		_set_raw(0, i, true)
		_set_raw(size - 1, i, true)
	for row in gate_rows:
		_set_raw(0, row, false)
		_set_raw(size - 1, row, false)


func _set_raw(x: int, y: int, v: bool) -> void:
	_blocked[y * size + x] = 1 if v else 0
	_astar.set_point_solid(Vector2i(x, y), v)


func west_gate_x() -> int:
	return 0


func east_gate_x() -> int:
	return size - 1


func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < size and y < size


func is_blocked(x: int, y: int) -> bool:
	return not in_bounds(x, y) or _blocked[y * size + x] == 1


func set_blocked(x: int, y: int, v: bool) -> void:
	_set_raw(x, y, v)


func is_interior(x: int, y: int) -> bool:
	return x >= 1 and y >= 1 and x <= field_size and y <= field_size


func is_east_gate(x: int, y: int) -> bool:
	return x == east_gate_x() and gate_rows.has(y)


func spawn_cells() -> Array:
	var out: Array = []
	for row in gate_rows:
		out.append(Vector2i(0, row))
	return out


## Клетка → мировые координаты центра (x, z).
static func cell_to_world(c: Vector2i) -> Vector2:
	return Vector2(c.x - 1 + 0.5, c.y - 1 + 0.5)


## Сбрасывает поле к пустому (остаётся только внешняя стена).
func reset() -> void:
	for y in range(1, field_size + 1):
		for x in range(1, field_size + 1):
			_set_raw(x, y, false)
	_astar.fill_weight_scale_region(Rect2i(0, 0, size, size), 1.0)


## Кратчайший путь от start до ближайшей восточной клетки-цели; пустой массив — пути нет.
func _shortest(start: Vector2i) -> Array:
	if is_blocked(start.x, start.y):
		return []
	var best: Array = []
	for row in gate_rows:
		var p: Array = _astar.get_id_path(start, Vector2i(east_gate_x(), row))
		if p.size() > 0 and (best.is_empty() or p.size() < best.size()):
			best = p
	return best


## Маршрут от одной клетки спавна; путь считается по стенам.
func path_from_walls(spawn: Vector2i) -> Array:
	return _shortest(spawn)


## Есть ли путь от КАЖДОЙ клетки спавна до восточных ворот.
func all_spawns_connected() -> bool:
	for s in spawn_cells():
		if _shortest(s).is_empty():
			return false
	return true


## Атомарно применяет изменения [{x,y,blocked}], если путь Spawn → East Gate сохраняется; иначе откат.
func try_apply(changes: Array) -> bool:
	var prev: Array = []
	for c in changes:
		prev.append(is_blocked(c["x"], c["y"]))
	for c in changes:
		_set_raw(c["x"], c["y"], c["blocked"])
	if all_spawns_connected():
		return true
	for i in changes.size():
		_set_raw(changes[i]["x"], changes[i]["y"], prev[i])
	return false


## Маршрут зомби. Клетки турелей на земле (turret_cells) зомби стараются ОБОЙТИ: сначала ищем путь,
## считая их непроходимыми; если обхода нет — идём сквозь турели, минимизируя их число (ломают только их).
func path_from(spawn: Vector2i, turret_cells: Array = []) -> Array:
	if turret_cells.is_empty():
		return _shortest(spawn)
	var temp: Array = []
	for c in turret_cells:
		if not is_blocked(c.x, c.y):
			temp.append(c)
			_astar.set_point_solid(c, true)
	var around := _shortest(spawn)
	for c in temp:
		_astar.set_point_solid(c, false)
	if not around.is_empty():
		return around
	for c in turret_cells:
		_astar.set_point_weight_scale(c, TURRET_CROSSING_COST)
	var through := _shortest(spawn)
	for c in turret_cells:
		_astar.set_point_weight_scale(c, 1.0)
	return through
