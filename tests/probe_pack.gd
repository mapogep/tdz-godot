extends SceneTree
## Отладка переноса (tools/retarget.gd): позиции суставов туловища исходника и канонические имена костей пака.
const RT := preload("res://tools/retarget.gd")
var done := false


func _process(_d: float) -> bool:
	if done:
		return true
	done = true
	var rt := RT.new()
	rt.load_pack(get_root())
	for k in [7, 1]:
		for f in [0, 20, 40]:
			var j: Dictionary = rt.samples[k][f]
			var line := "z%d f%d" % [k, f]
			for nm in ["bip", "Pelvis", "Spine", "Spine1", "Neck", "Head", "HeadNub", "L Thigh", "R Thigh", "L UpperArm", "R UpperArm", "L Clavicle"]:
				if j.has(nm):
					line += "  %s=%s" % [nm, (j[nm] as Vector3).snapped(Vector3.ONE * 0.01)]
				else:
					line += "  %s=?" % nm
			print(line)
	for k in [0, 7]:
		var sk: Skeleton3D = rt.skels[k]
		var names: Array = []
		for i in sk.get_bone_count():
			names.append(sk.get_bone_name(i))
		print("raw z%d: " % k, names)
	rt.free_pack()
	return true
