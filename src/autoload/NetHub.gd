extends Node
## Сеть (Godot high-level multiplayer, ENet). Host — авторитетная симуляция и он же игрок.
## Клиент шлёт только команды (намерения), Host рассылает снапшоты и список стен.
## Одиночная игра — тот же Host без клиентов.

signal command_received(peer_id: int, msg: Dictionary)     # только на Host
signal snapshot_received(s: Dictionary)                      # только на клиенте
signal walls_received(cells: Array)
signal error_received(code: String)
signal peer_joined(peer_id: int)                             # на Host
signal peer_left(peer_id: int)                               # на Host
signal connected_to_host()                                   # на клиенте
signal connection_failed()
signal host_lost()

const DEFAULT_PORT := 7777
const MAX_CLIENTS := 8

var is_host := false
var active := false          # есть сетевой peer (host с портом или клиент)


func _ready() -> void:
	multiplayer.peer_connected.connect(func(id: int) -> void: if is_host: peer_joined.emit(id))
	multiplayer.peer_disconnected.connect(func(id: int) -> void: if is_host: peer_left.emit(id))
	multiplayer.connected_to_server.connect(func() -> void: connected_to_host.emit())
	multiplayer.connection_failed.connect(func() -> void: active = false; connection_failed.emit())
	multiplayer.server_disconnected.connect(func() -> void: active = false; host_lost.emit())


## Идентификатор локального игрока (Host — всегда 1).
func my_id() -> int:
	if not active:
		return 1
	return multiplayer.get_unique_id()


func host_game(port: int = DEFAULT_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_CLIENTS)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	is_host = true
	active = true
	return OK


func host_offline() -> void:
	close()
	is_host = true
	active = false


func join_game(address: String, port: int = DEFAULT_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	is_host = false
	active = true
	return OK


func close() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	is_host = false
	active = false


## Локальные IPv4-адреса для подсказки «адрес для друзей».
func local_addresses() -> PackedStringArray:
	var out := PackedStringArray()
	for a in IP.get_local_addresses():
		if a.count(".") == 3 and not a.begins_with("127.") and not a.begins_with("169.254."):
			out.append(a)
	return out


# ───────────── клиент → Host ─────────────

func send_command(msg: Dictionary) -> void:
	if is_host:
		command_received.emit(1, msg)
	elif active:
		_rpc_command.rpc_id(1, msg)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_command(msg: Dictionary) -> void:
	if not is_host:
		return
	command_received.emit(multiplayer.get_remote_sender_id(), msg)


# ───────────── Host → клиенты ─────────────

func broadcast_snapshot(s: Dictionary) -> void:
	if is_host and active and multiplayer.get_peers().size() > 0:
		_rpc_snapshot.rpc(s)


func send_walls(cells: Array, peer_id: int = 0) -> void:
	if not (is_host and active):
		return
	if peer_id == 0:
		if multiplayer.get_peers().size() > 0:
			_rpc_walls.rpc(cells)
	else:
		_rpc_walls.rpc_id(peer_id, cells)


func send_error(peer_id: int, code: String) -> void:
	if is_host and active and peer_id != 1:
		_rpc_error.rpc_id(peer_id, code)


@rpc("authority", "call_remote", "reliable")
func _rpc_snapshot(s: Dictionary) -> void:
	snapshot_received.emit(s)


@rpc("authority", "call_remote", "reliable")
func _rpc_walls(cells: Array) -> void:
	walls_received.emit(cells)


@rpc("authority", "call_remote", "reliable")
func _rpc_error(code: String) -> void:
	error_received.emit(code)
