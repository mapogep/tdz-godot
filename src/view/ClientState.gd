class_name ClientState
extends RefCounted
## Клиентская копия мира: последний снапшот, стены, зеркало сетки для подсказок строительства, состояние интерфейса.

var my_id := 1
var snap: Dictionary = {}
var wall_cells: Array = []
var nav := NavSim.new()          # зеркало (стены) — только для подсветки «можно ли поставить»

# интерфейс
var tool := "select"             # select | wall | remove | turret
var weapon := "gun"
var selected_turret := 0
var moving := false


func set_walls(cells: Array) -> void:
	wall_cells = cells.duplicate()
	nav.reset()
	for k in cells:
		nav.set_blocked(int(k) % nav.size, int(k) / nav.size, true)


func set_snapshot(s: Dictionary) -> void:
	snap = s


func has_snap() -> bool:
	return not snap.is_empty()


func me() -> Dictionary:
	for p in snap.get("players", []):
		if int(p["id"]) == my_id:
			return p
	return {}


func is_host() -> bool:
	var m := me()
	return not m.is_empty() and bool(m["is_host"])


func my_turret() -> Dictionary:
	for t in snap.get("turrets", []):
		if int(t["controlled_by"]) == my_id:
			return t
	return {}


func turret_by_id(id: int) -> Dictionary:
	for t in snap.get("turrets", []):
		if int(t["id"]) == id:
			return t
	return {}


func turret_at(cx: int, cy: int) -> Dictionary:
	for t in snap.get("turrets", []):
		if int(t["cx"]) == cx and int(t["cy"]) == cy:
			return t
	return {}


func has_wall(x: int, y: int) -> bool:
	return wall_cells.has(y * nav.size + x)


func can_build() -> bool:
	return is_host() and snap.get("state", "") == "Preparation"


## Предсказание для подсветки: можно ли поставить стену (окончательно решает Host).
func can_place_wall(x: int, y: int) -> bool:
	if not nav.is_interior(x, y) or nav.is_blocked(x, y):
		return false
	nav.set_blocked(x, y, true)
	var ok := nav.all_spawns_connected()
	nav.set_blocked(x, y, false)
	return ok


func can_place_turret(x: int, y: int) -> bool:
	return nav.is_interior(x, y) and turret_at(x, y).is_empty()
