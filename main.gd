extends Node3D

const PORT := 24560
const MAX_PLAYERS := 4
const SAVE_PATH := "user://garage.cfg"
const CarModelScript = preload("res://scripts/car_model.gd")

const CAR_CATALOG: Array[Dictionary] = [
	{"name": "VORTEX S1", "top_speed": 34.0, "handling": 1.08, "nitro": 1.0, "body_style": 0, "description": "Balanced street supercar"},
	{"name": "APEX GT", "top_speed": 37.0, "handling": 0.96, "nitro": 1.05, "body_style": 1, "description": "Long-wheelbase grand tourer"},
	{"name": "COMET R", "top_speed": 32.0, "handling": 1.20, "nitro": 1.15, "body_style": 2, "description": "Lightweight track specialist"},
	{"name": "TITAN X", "top_speed": 40.0, "handling": 0.88, "nitro": 1.10, "body_style": 3, "description": "Wide-body hypercar prototype"}
]

const PAINTS: Array[Color] = [
	Color(0.04, 0.32, 0.95),
	Color(0.88, 0.06, 0.045),
	Color(0.95, 0.58, 0.035),
	Color(0.08, 0.78, 0.42),
	Color(0.78, 0.12, 0.82),
	Color(0.88, 0.90, 0.94)
]

var player: CharacterBody3D
var camera: Camera3D
var speed_label: Label
var status_label: Label
var race_hud: Control
var ui_layer: CanvasLayer
var garage_panel: Panel
var garage_car_name: Label
var garage_info: Label
var spoiler_button: Button
var wheel_button: Button
var host_ip_input: LineEdit
var upgrade_buttons: Dictionary = {}
var preview_root: Node3D
var preview_car: Node3D
var selected_car := 0
var selected_paint := 0
var spoiler_enabled := true
var wheel_style := 0
var upgrade_levels: Dictionary = {"engine": 0, "handling": 0, "nitro": 0}
var upgrade_labels: Dictionary = {}
var steer_value := 0.0
var accel_pressed := false
var brake_pressed := false
var nitro_pressed := false
var remote_cars: Dictionary = {}
var ai_cars: Array[Dictionary] = []

func _ready() -> void:
	_load_garage()
	_build_world()
	_build_player()
	_build_race_ui()
	_build_garage_ui()
	_spawn_ai(Vector3(0, 0, -35), Color(0.95, 0.22, 0.08))
	_spawn_ai(Vector3(4, 0, -55), Color(0.1, 0.65, 1.0))
	player.visible = false

func _process(delta: float) -> void:
	if preview_car != null and garage_panel != null and garage_panel.visible:
		preview_car.rotate_y(delta * 0.42)
	if race_hud != null and race_hud.visible and player != null:
		for entry in ai_cars:
			var traffic_car: Node3D = entry["node"]
			traffic_car.position.z -= float(entry["speed"]) * delta
			if traffic_car.position.z < player.position.z - 90.0:
				traffic_car.position.z = player.position.z + float(entry["respawn_distance"])

func _build_world() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	e.sky = Sky.new()
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.62, 0.72)
	e.ambient_light_energy = 0.8
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -25, 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = false
	add_child(sun)

	add_child(_box("Ground", Vector3(0, -0.7, 0), Vector3(180, 1, 500), Color(0.12, 0.34, 0.18)))
	add_child(_box("Race track", Vector3(0, -0.12, 0), Vector3(18, 0.25, 500), Color(0.095, 0.105, 0.12)))
	for z in range(-240, 250, 12):
		add_child(_box("Lane dash", Vector3(0, 0.02, z), Vector3(0.22, 0.035, 5), Color(0.92, 0.92, 0.82)))
	for side in [-1, 1]:
		add_child(_box("Road edge", Vector3(side * 8.8, 0.04, 0), Vector3(0.35, 0.12, 500), Color(0.85, 0.12, 0.08)))
		for z in range(-220, 240, 24):
			var height := 4.0 + float(abs(z) % 5) * 1.5
			var building_color := Color(0.25 + float(abs(z) % 3) * 0.04, 0.29, 0.34)
			add_child(_box("City block", Vector3(side * (14.0 + float((z + 240) % 3) * 2.0), height * 0.5, z), Vector3(7, height, 10), building_color))
		add_child(_box("Barrier", Vector3(side * 10.0, 0.6, 0), Vector3(0.45, 1.2, 500), Color(0.75, 0.78, 0.82)))

func _box(label: String, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = label
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.72
	mesh_instance.material_override = material
	mesh_instance.position = pos
	return mesh_instance

func _build_car(parent: Node, color: Color, add_spoiler: bool = true, rim_style: int = 0, body_style: int = -1) -> Node3D:
	var car: Node3D = CarModelScript.new()
	car.name = "CarVisual"
	parent.add_child(car)
	var resolved_style := selected_car if body_style < 0 else body_style
	car.call("configure", color, resolved_style, add_spoiler, rim_style)
	return car

func _build_player() -> void:
	player = CharacterBody3D.new()
	player.name = "PlayerCar"
	add_child(player)
	_build_car(player, _selected_color(), spoiler_enabled, wheel_style, int(CAR_CATALOG[selected_car]["body_style"]))
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.0, 1.2, 4.0)
	collision.shape = shape
	collision.position.y = 0.65
	player.add_child(collision)
	player.position = Vector3(0, 0.1, 25)

	camera = Camera3D.new()
	camera.position = Vector3(0, 6, 12)
	camera.rotation_degrees = Vector3(-17, 0, 0)
	camera.current = true
	player.add_child(camera)

func _spawn_ai(pos: Vector3, color: Color) -> void:
	var ai := Node3D.new()
	ai.position = pos
	add_child(ai)
	var style_index := 1 if ai_cars.is_empty() else 2
	_build_car(ai, color, style_index == 2, 0, style_index)
	ai_cars.append({"node": ai, "speed": 15.0 + float(ai_cars.size()) * 2.0, "respawn_distance": 72.0 + float(ai_cars.size()) * 12.0})

func _build_race_ui() -> void:
	var layer := CanvasLayer.new()
	ui_layer = layer
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)
	race_hud = root
	race_hud.visible = false

	speed_label = Label.new()
	speed_label.position = Vector2(25, 20)
	speed_label.add_theme_font_size_override("font_size", 30)
	speed_label.text = "0 KM/H"
	root.add_child(speed_label)

	status_label = Label.new()
	status_label.position = Vector2(25, 62)
	status_label.add_theme_font_size_override("font_size", 17)
	status_label.text = "CAREER RACE | CITY CIRCUIT"
	root.add_child(status_label)

	_add_hold_button(root, "◀", Vector2(25, -115), Vector2(95, 85), "left")
	_add_hold_button(root, "▶", Vector2(130, -115), Vector2(95, 85), "right")
	_add_hold_button(root, "BRAKE", Vector2(-235, -105), Vector2(100, 75), "brake")
	_add_hold_button(root, "GAS", Vector2(-125, -105), Vector2(100, 75), "gas")
	_add_hold_button(root, "NITRO", Vector2(-125, -195), Vector2(100, 65), "nitro")

	var host := Button.new()
	host.text = "HOST LAN"
	host.position = Vector2(25, 112)
	host.size = Vector2(125, 46)
	host.pressed.connect(_host_game)
	root.add_child(host)

	var join := Button.new()
	join.text = "JOIN LAN"
	join.position = Vector2(160, 112)
	join.size = Vector2(125, 46)
	join.pressed.connect(_join_game)
	root.add_child(join)

	var garage_button := Button.new()
	garage_button.text = "GARAGE"
	garage_button.position = Vector2(25, 166)
	garage_button.size = Vector2(125, 46)
	garage_button.pressed.connect(_open_garage)
	root.add_child(garage_button)

	var hint := Label.new()
	hint.text = "LAN prototype: both phones must use the same Wi-Fi"
	hint.position = Vector2(25, 220)
	hint.add_theme_font_size_override("font_size", 14)
	root.add_child(hint)

	host_ip_input = LineEdit.new()
	host_ip_input.text = "192.168.1.100"
	host_ip_input.placeholder_text = "Host phone Wi-Fi IP"
	host_ip_input.position = Vector2(25, 252)
	host_ip_input.size = Vector2(210, 42)
	root.add_child(host_ip_input)

func _add_hold_button(root: Control, caption: String, offset: Vector2, button_size: Vector2, action: String) -> void:
	var button := Button.new()
	button.text = caption
	button.size = button_size
	button.add_theme_font_size_override("font_size", 22)
	if offset.x < 0:
		button.anchor_left = 1.0
		button.anchor_right = 1.0
	if offset.y < 0:
		button.anchor_top = 1.0
		button.anchor_bottom = 1.0
	button.position = offset
	button.button_down.connect(func(): _set_action(action, true))
	button.button_up.connect(func(): _set_action(action, false))
	root.add_child(button)

func _set_action(action: String, pressed: bool) -> void:
	match action:
		"left":
			steer_value = -1.0 if pressed else 0.0
		"right":
			steer_value = 1.0 if pressed else 0.0
		"gas":
			accel_pressed = pressed
		"brake":
			brake_pressed = pressed
		"nitro":
			nitro_pressed = pressed

func _build_garage_ui() -> void:
	garage_panel = Panel.new()
	garage_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.025, 0.04, 0.065, 0.98)
	garage_panel.add_theme_stylebox_override("panel", panel_style)
	ui_layer.add_child(garage_panel)

	var title := _make_label(garage_panel, "EXTREME RACING 3D  |  SUPERCAR GARAGE", Vector2(30, 18), Vector2(850, 52), 30)
	title.add_theme_color_override("font_color", Color(0.45, 0.82, 1.0))
	_make_label(garage_panel, "Choose your machine. Tune it. Own the road.", Vector2(34, 68), Vector2(620, 30), 17)

	var preview_container := SubViewportContainer.new()
	preview_container.position = Vector2(30, 120)
	preview_container.size = Vector2(650, 440)
	preview_container.stretch = true
	garage_panel.add_child(preview_container)

	var viewport := SubViewport.new()
	viewport.size = Vector2i(900, 600)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	viewport.own_world_3d = true
	preview_container.add_child(viewport)

	var preview_environment := WorldEnvironment.new()
	var preview_env := Environment.new()
	preview_env.background_mode = Environment.BG_COLOR
	preview_env.background_color = Color(0.045, 0.07, 0.105)
	preview_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	preview_env.ambient_light_color = Color(0.72, 0.78, 0.88)
	preview_env.ambient_light_energy = 0.9
	preview_environment.environment = preview_env
	viewport.add_child(preview_environment)

	var preview_light := DirectionalLight3D.new()
	preview_light.rotation_degrees = Vector3(-48, -28, 0)
	preview_light.light_energy = 1.55
	preview_light.shadow_enabled = false
	viewport.add_child(preview_light)

	var preview_floor := MeshInstance3D.new()
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(18, 18)
	preview_floor.mesh = floor_mesh
	preview_floor.position.y = -0.08
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.075, 0.095, 0.12)
	floor_material.roughness = 0.85
	preview_floor.material_override = floor_material
	viewport.add_child(preview_floor)

	var display_plinth := MeshInstance3D.new()
	display_plinth.name = "GarageDisplayPlinth"
	var plinth_mesh := CylinderMesh.new()
	plinth_mesh.top_radius = 3.8
	plinth_mesh.bottom_radius = 3.8
	plinth_mesh.height = 0.06
	plinth_mesh.radial_segments = 40
	display_plinth.mesh = plinth_mesh
	display_plinth.position.y = -0.03
	var plinth_material := StandardMaterial3D.new()
	plinth_material.albedo_color = Color(0.12, 0.16, 0.21)
	plinth_material.metallic = 0.48
	plinth_material.roughness = 0.42
	display_plinth.material_override = plinth_material
	viewport.add_child(display_plinth)

	var preview_camera := Camera3D.new()
	preview_camera.position = Vector3(5.5, 3.15, -7.2)
	preview_camera.fov = 42.0
	viewport.add_child(preview_camera)
	preview_camera.look_at(Vector3(0, 0.72, 0), Vector3.UP)
	preview_camera.current = true

	preview_root = Node3D.new()
	viewport.add_child(preview_root)
	_make_label(garage_panel, "3D PREVIEW  •  AUTO ROTATION", Vector2(40, 570), Vector2(620, 28), 15)

	garage_car_name = _make_label(garage_panel, "VORTEX S1", Vector2(720, 112), Vector2(500, 45), 27)
	_make_button(garage_panel, "◀ PREVIOUS", Rect2(720, 164, 145, 44), func(): _change_car(-1))
	_make_button(garage_panel, "NEXT ▶", Rect2(875, 164, 125, 44), func(): _change_car(1))

	_make_label(garage_panel, "PAINT COLOUR", Vector2(720, 225), Vector2(250, 28), 17)
	for i in range(PAINTS.size()):
		var swatch := Button.new()
		swatch.text = "●"
		swatch.position = Vector2(720 + i * 55, 258)
		swatch.size = Vector2(48, 44)
		swatch.add_theme_font_size_override("font_size", 27)
		swatch.add_theme_color_override("font_color", PAINTS[i])
		swatch.pressed.connect(func(): _select_paint(i))
		garage_panel.add_child(swatch)

	spoiler_button = _make_button(garage_panel, "SPOILER: ON", Rect2(720, 318, 150, 42), _toggle_spoiler)
	wheel_button = _make_button(garage_panel, "WHEELS: SILVER", Rect2(882, 318, 165, 42), _cycle_wheels)
	_make_label(garage_panel, "PERFORMANCE UPGRADES  •  5 LEVELS EACH", Vector2(720, 376), Vector2(510, 28), 17)

	upgrade_labels["engine"] = _make_label(garage_panel, "ENGINE  LV 0/5", Vector2(720, 414), Vector2(300, 34), 18)
	upgrade_buttons["engine"] = _make_button(garage_panel, "+ UPGRADE", Rect2(1055, 410, 135, 40), func(): _upgrade("engine"))
	upgrade_labels["handling"] = _make_label(garage_panel, "HANDLING  LV 0/5", Vector2(720, 462), Vector2(300, 34), 18)
	upgrade_buttons["handling"] = _make_button(garage_panel, "+ UPGRADE", Rect2(1055, 458, 135, 40), func(): _upgrade("handling"))
	upgrade_labels["nitro"] = _make_label(garage_panel, "NITRO  LV 0/5", Vector2(720, 510), Vector2(300, 34), 18)
	upgrade_buttons["nitro"] = _make_button(garage_panel, "+ UPGRADE", Rect2(1055, 506, 135, 40), func(): _upgrade("nitro"))

	garage_info = _make_label(garage_panel, "", Vector2(720, 555), Vector2(500, 55), 15)
	_make_button(garage_panel, "RESET TUNING", Rect2(720, 630, 175, 52), _reset_upgrades)
	_make_button(garage_panel, "START RACE  ▶", Rect2(1010, 630, 220, 60), _start_race)
	_make_label(garage_panel, "Prototype tuning is free. Settings save on this device.", Vector2(35, 635), Vector2(650, 30), 14)
	_refresh_garage()

func _make_label(parent: Control, caption: String, pos: Vector2, label_size: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.text = caption
	label.position = pos
	label.size = label_size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.91, 0.94, 0.98))
	parent.add_child(label)
	return label

func _make_button(parent: Control, caption: String, rect: Rect2, callback: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.position = rect.position
	button.size = rect.size
	button.add_theme_font_size_override("font_size", 16)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _selected_color() -> Color:
	return PAINTS[selected_paint]

func _change_car(direction: int) -> void:
	selected_car = posmod(selected_car + direction, CAR_CATALOG.size())
	_save_garage()
	_refresh_garage()

func _select_paint(index: int) -> void:
	selected_paint = clampi(index, 0, PAINTS.size() - 1)
	_save_garage()
	_refresh_garage()

func _toggle_spoiler() -> void:
	spoiler_enabled = not spoiler_enabled
	_save_garage()
	_refresh_garage()

func _cycle_wheels() -> void:
	wheel_style = (wheel_style + 1) % 3
	_save_garage()
	_refresh_garage()

func _upgrade(kind: String) -> void:
	if not upgrade_levels.has(kind):
		return
	upgrade_levels[kind] = mini(int(upgrade_levels[kind]) + 1, 5)
	_save_garage()
	_refresh_garage()

func _reset_upgrades() -> void:
	for kind in ["engine", "handling", "nitro"]:
		upgrade_levels[kind] = 0
	_save_garage()
	_refresh_garage()

func _refresh_garage() -> void:
	if garage_car_name == null:
		return
	var car_data: Dictionary = CAR_CATALOG[selected_car]
	garage_car_name.text = str(car_data["name"])
	spoiler_button.text = "SPOILER: ON" if spoiler_enabled else "SPOILER: OFF"
	var wheel_names := ["SILVER", "GOLD", "DARK"]
	wheel_button.text = "WHEELS: " + wheel_names[wheel_style]
	for kind in ["engine", "handling", "nitro"]:
		var level := int(upgrade_levels[kind])
		var label: Label = upgrade_labels[kind]
		label.text = kind.to_upper() + "  LV " + str(level) + "/5"
		var upgrade_button: Button = upgrade_buttons[kind]
		upgrade_button.disabled = level >= 5
		upgrade_button.text = "MAXED" if level >= 5 else "+ UPGRADE"
	var top_speed := float(car_data["top_speed"]) + float(upgrade_levels["engine"]) * 1.8
	var handling := float(car_data["handling"]) + float(upgrade_levels["handling"]) * 0.08
	var nitro_power := float(car_data["nitro"]) + float(upgrade_levels["nitro"]) * 0.12
	garage_info.text = "TOP SPEED: %d km/h   •   HANDLING: %.2f   •   NITRO: %.2f\n%s" % [int(top_speed * 3.6), handling, nitro_power, str(car_data["description"])]
	_update_preview()
	_update_player_visual()

func _update_preview() -> void:
	if preview_root == null:
		return
	if preview_car != null:
		preview_root.remove_child(preview_car)
		preview_car.queue_free()
	preview_car = _build_car(preview_root, _selected_color(), spoiler_enabled, wheel_style, int(CAR_CATALOG[selected_car]["body_style"]))

func _update_player_visual() -> void:
	if player == null:
		return
	var old_visual := player.get_node_or_null("CarVisual")
	if old_visual != null:
		player.remove_child(old_visual)
		old_visual.queue_free()
	_build_car(player, _selected_color(), spoiler_enabled, wheel_style, int(CAR_CATALOG[selected_car]["body_style"]))

func _start_race() -> void:
	garage_panel.hide()
	race_hud.show()
	player.visible = true
	player.position = Vector3(0, 0.1, 25)
	player.velocity = Vector3.ZERO
	status_label.text = "CAREER RACE  |  " + str(CAR_CATALOG[selected_car]["name"])

func _open_garage() -> void:
	player.velocity = Vector3.ZERO
	player.visible = false
	race_hud.hide()
	garage_panel.show()

func _physics_process(delta: float) -> void:
	if player == null or (garage_panel != null and garage_panel.visible):
		return
	var accelerating := accel_pressed or Input.is_action_pressed("accelerate")
	var braking := brake_pressed or Input.is_action_pressed("brake")
	var using_nitro := nitro_pressed or Input.is_action_pressed("nitro")
	var steering := steer_value
	if Input.is_action_pressed("steer_left"):
		steering = -1.0
	elif Input.is_action_pressed("steer_right"):
		steering = 1.0

	var car_data: Dictionary = CAR_CATALOG[selected_car]
	var engine_bonus := float(upgrade_levels["engine"]) * 1.8
	var nitro_bonus := float(upgrade_levels["nitro"]) * 1.2
	var target_speed := float(car_data["top_speed"]) + engine_bonus
	if using_nitro:
		target_speed += 12.0 + nitro_bonus

	if accelerating:
		player.velocity.z = move_toward(player.velocity.z, -target_speed, 25.0 * delta)
	elif braking:
		player.velocity.z = move_toward(player.velocity.z, 0.0, 42.0 * delta)
	else:
		player.velocity.z = move_toward(player.velocity.z, 0.0, 5.0 * delta)

	var handling := float(car_data["handling"]) + float(upgrade_levels["handling"]) * 0.08
	player.velocity.x = -steering * clamp(abs(player.velocity.z) / 22.0, 0.0, 1.0) * 12.0 * handling
	player.velocity.y = 0.0
	player.move_and_slide()
	player.position.x = clamp(player.position.x, -7.0, 7.0)
	player.rotation.y = lerp_angle(player.rotation.y, steering * 0.16, delta * 4.0)
	if camera != null:
		camera.position = camera.position.lerp(Vector3(0, 6.0, 12.0), delta * 2.0)
	speed_label.text = str(int(abs(player.velocity.z) * 3.6)) + " KM/H" + ("  NITRO" if using_nitro else "")
	if multiplayer.multiplayer_peer != null and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		_send_position.rpc(player.position, player.rotation.y)

func _host_game() -> void:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, MAX_PLAYERS)
	if err == OK:
		multiplayer.multiplayer_peer = peer
		if not multiplayer.peer_connected.is_connected(_on_peer_connected):
			multiplayer.peer_connected.connect(_on_peer_connected)
		if not multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
			multiplayer.peer_disconnected.connect(_on_peer_disconnected)
		status_label.text = "LAN HOST READY  |  PORT " + str(PORT)
	else:
		status_label.text = "HOST ERROR: " + str(err)

func _join_game() -> void:
	var peer := ENetMultiplayerPeer.new()
	var host_ip := "192.168.1.100"
	if host_ip_input != null and not host_ip_input.text.strip_edges().is_empty():
		host_ip = host_ip_input.text.strip_edges()
	var err := peer.create_client(host_ip, PORT)
	if err == OK:
		multiplayer.multiplayer_peer = peer
		if not multiplayer.connected_to_server.is_connected(_on_connected_to_server):
			multiplayer.connected_to_server.connect(_on_connected_to_server)
		if not multiplayer.connection_failed.is_connected(_on_connection_failed):
			multiplayer.connection_failed.connect(_on_connection_failed)
		if not multiplayer.server_disconnected.is_connected(_on_server_disconnected):
			multiplayer.server_disconnected.connect(_on_server_disconnected)
		status_label.text = "CONNECTING TO " + host_ip
	else:
		status_label.text = "JOIN ERROR: " + str(err)

func _on_peer_connected(id: int) -> void:
	status_label.text = "PLAYER CONNECTED: " + str(id)

func _on_peer_disconnected(id: int) -> void:
	if remote_cars.has(id):
		var remote_car: Node3D = remote_cars[id]
		remote_car.queue_free()
		remote_cars.erase(id)
	status_label.text = "PLAYER LEFT: " + str(id)

func _on_connected_to_server() -> void:
	status_label.text = "LAN CONNECTED"

func _on_connection_failed() -> void:
	status_label.text = "LAN CONNECTION FAILED"

func _on_server_disconnected() -> void:
	status_label.text = "LAN HOST DISCONNECTED"

@rpc("any_peer", "unreliable")
func _send_position(pos: Vector3, yaw: float) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0:
		return
	if not remote_cars.has(sender):
		var remote := Node3D.new()
		remote.name = "Remote_" + str(sender)
		add_child(remote)
		_build_car(remote, Color(1.0, 0.72, 0.05), false, 0)
		remote_cars[sender] = remote
	var remote_car: Node3D = remote_cars[sender]
	remote_car.position = pos
	remote_car.rotation.y = yaw

func _load_garage() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	selected_car = clampi(int(config.get_value("garage", "selected_car", 0)), 0, CAR_CATALOG.size() - 1)
	selected_paint = clampi(int(config.get_value("garage", "selected_paint", 0)), 0, PAINTS.size() - 1)
	spoiler_enabled = bool(config.get_value("garage", "spoiler_enabled", true))
	wheel_style = clampi(int(config.get_value("garage", "wheel_style", 0)), 0, 2)
	for kind in ["engine", "handling", "nitro"]:
		upgrade_levels[kind] = clampi(int(config.get_value("upgrades", kind, 0)), 0, 5)

func _save_garage() -> void:
	var config := ConfigFile.new()
	config.set_value("garage", "selected_car", selected_car)
	config.set_value("garage", "selected_paint", selected_paint)
	config.set_value("garage", "spoiler_enabled", spoiler_enabled)
	config.set_value("garage", "wheel_style", wheel_style)
	for kind in ["engine", "handling", "nitro"]:
		config.set_value("upgrades", kind, upgrade_levels[kind])
	config.save(SAVE_PATH)
