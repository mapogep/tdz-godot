class_name SimMath
extends RefCounted
## Геометрия боя. Конвенция направлений как в исходной версии:
## forward = (sin yaw·cos pitch, sin pitch, cos yaw·cos pitch); yaw=0 смотрит в +Z.


static func aim_direction(yaw: float, pitch: float) -> Vector3:
	var cp := cos(pitch)
	return Vector3(sin(yaw) * cp, sin(pitch), cos(yaw) * cp)


## Нормализация угла в (-π, π].
static func wrap_angle(a: float) -> float:
	return wrapf(a, -PI, PI)


## Поворот угла cur к target не более чем на max_step.
static func step_angle(cur: float, target: float, max_step: float) -> float:
	var d := wrap_angle(target - cur)
	if absf(d) <= max_step:
		return target
	return wrap_angle(cur + signf(d) * max_step)


## Пересечение луча (dir единичный) с вертикальным цилиндром [центр cx,cz; радиус r; y от 0 до h].
## Возвращает расстояние вдоль луча или -1.0, если нет попадания.
static func ray_vs_cylinder(origin: Vector3, dir: Vector3, cx: float, cz: float, r: float, h: float) -> float:
	var a := dir.x * dir.x + dir.z * dir.z
	if a < 1e-9:
		return -1.0
	var ox := origin.x - cx
	var oz := origin.z - cz
	var b := 2.0 * (ox * dir.x + oz * dir.z)
	var c := ox * ox + oz * oz - r * r
	var disc := b * b - 4.0 * a * c
	if disc < 0.0:
		return -1.0
	var sq := sqrt(disc)
	for t: float in [(-b - sq) / (2.0 * a), (-b + sq) / (2.0 * a)]:
		if t < 0.0:
			continue
		var y: float = origin.y + dir.y * t
		if y >= 0.0 and y <= h:
			return t
	return -1.0
