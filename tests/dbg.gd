extends SceneTree
func _init() -> void:
	var g := GameSim.new(100)
	g.add_player(1)
	g.handle(1, {"t": "fpsEnter"})
	var s5: SimPlayer = g.fps.get_player(1)
	g.state = "WaveRunning"
	g.zombies.spawn(1, "fat")
	var z: SimZombie = g.zombies.zombies.values()[0]
	z.x = s5.x - 0.8; z.z = s5.z
	print("player ", s5.x, ",", s5.z, " active=", s5.active, " zombie ", z.x, ",", z.z)
	print("victim=", g.fps.victim_near(z.x, z.z, 1.4))
	for i in 20: g.tick(0.05)
	print("hp=", s5.hp, " zombies=", g.zombies.count(), " state=", g.state, " z=", z.x)
	quit()
