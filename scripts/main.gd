extends Node3D

const FIELD_X := 34.0
const FIELD_Z := 22.0
const PLAYER_SPEED := 6.2
const SPRINT_SPEED := 9.0
var teams := {"Persepolis": Color("#d71920"), "Esteghlal": Color("#1766c2"), "Real Madrid": Color("#eeeeee"), "Barcelona": Color("#a50044")}
var home_team := "Persepolis"
var away_team := "Real Madrid"
var players: Array[CharacterBody3D] = []
var player_data: Array[Dictionary] = []
var active_player: CharacterBody3D
var ball: RigidBody3D
var score := [0, 0]
var seconds_left := 180
var match_started := false
var joystick_vector := Vector2.ZERO
var joystick_touch := -1
var hud: CanvasLayer
var score_label: Label
var timer_label: Label
var message_label: Label
var camera: Camera3D
var goal_cooldown := 0.0
var home_select: OptionButton
var away_select: OptionButton
var quality_select: OptionButton

func _ready() -> void:
	_build_world()
	_build_ui()
	_start_match()

func _build_world() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -28, 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	add_child(sun)
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = Sky.new()
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.55, 0.62, 0.7)
	environment.ambient_light_energy = 0.7
	env.environment = environment
	add_child(env)
	camera = Camera3D.new()
	camera.position = Vector3(0, 22, 25)
	camera.rotation_degrees = Vector3(-42, 0, 0)
	camera.current = true
	camera.fov = 55
	add_child(camera)
	_make_box("Pitch", Vector3(FIELD_X, 0.25, FIELD_Z), Vector3.ZERO, Color("#267a3c"))
	_make_box("Pitch border", Vector3(FIELD_X + 0.5, 0.12, FIELD_Z + 0.5), Vector3(0, -0.18, 0), Color("#eeeeee"))
	_make_box("Centre line", Vector3(0.08, 0.025, FIELD_Z), Vector3(0, 0.15, 0), Color.WHITE)
	_make_ring(Vector3(0, 0.16, 0), 3.0, Color.WHITE)
	for z in [-FIELD_Z / 2, FIELD_Z / 2]:
		_make_box("Penalty box", Vector3(10, 0.025, 3.2), Vector3(0, 0.16, z - sign(z) * 1.6), Color.WHITE)
		_make_goal(z)

func _make_box(label: String, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.name = label
	node.mesh = mesh
	node.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	node.material_override = mat
	add_child(node)
	if label == "Pitch":
		var ground_body := StaticBody3D.new()
		ground_body.position = pos
		var ground_shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = size
		ground_shape.shape = box_shape
		ground_body.add_child(ground_shape)
		add_child(ground_body)
	return node

func _make_ring(pos: Vector3, radius: float, color: Color) -> void:
	for i in range(48):
		var a := TAU * float(i) / 48.0
		var b := TAU * float(i + 1) / 48.0
		var seg := _make_box("Centre circle", Vector3(0.06, 0.025, radius * TAU / 48.0), Vector3((cos(a)+cos(b))*radius/2, 0.16, (sin(a)+sin(b))*radius/2), color)
		seg.rotation.y = -atan2(sin(b)-sin(a), cos(b)-cos(a))

func _make_goal(z: float) -> void:
	var gz := z - sign(z) * 0.7
	for x in [-2.1, 2.1]:
		_make_box("Goal post", Vector3(0.16, 2.1, 0.16), Vector3(x, 1.15, gz), Color.WHITE)
	_make_box("Goal crossbar", Vector3(4.3, 0.16, 0.16), Vector3(0, 2.2, gz), Color.WHITE)
	for x in range(-2, 3):
		_make_box("Net", Vector3(0.025, 1.9, 0.025), Vector3(float(x), 1.1, gz - sign(z) * 1.2), Color("#dddddd"))

func _build_player(team_color: Color, pos: Vector3, is_home: bool, index: int) -> CharacterBody3D:
	var body := CharacterBody3D.new()
	body.position = pos
	body.name = ("Home_" if is_home else "Away_") + str(index)
	var visual := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.42
	capsule.height = 1.65
	visual.mesh = capsule
	visual.position.y = 0.95
	var mat := StandardMaterial3D.new()
	mat.albedo_color = team_color
	visual.material_override = mat
	body.add_child(visual)
	var player_collider := CollisionShape3D.new()
	var player_shape := CapsuleShape3D.new()
	player_shape.radius = 0.4
	player_shape.height = 1.65
	player_collider.shape = player_shape
	player_collider.position.y = 0.85
	body.add_child(player_collider)
	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.25
	head_mesh.height = 0.5
	head.mesh = head_mesh
	head.position.y = 1.85
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color("#c98f69")
	head.material_override = skin
	body.add_child(head)
	add_child(body)
	return body

func _start_match() -> void:
	for p in players:
		p.queue_free()
	players.clear()
	player_data.clear()
	var hp := [Vector3(-4,0,6), Vector3(-10,0,2), Vector3(-10,0,9), Vector3(-14,0,5), Vector3(-1,0,2)]
	var ap := [Vector3(4,0,-6), Vector3(10,0,-2), Vector3(10,0,-9), Vector3(14,0,-5), Vector3(1,0,-2)]
	for i in range(5):
		var p := _build_player(teams[home_team], hp[i], true, i)
		players.append(p)
		player_data.append({"home": true, "slot": i})
		if i == 0:
			active_player = p
	for i in range(5):
		var p := _build_player(teams[away_team], ap[i], false, i)
		players.append(p)
		player_data.append({"home": false, "slot": i})
	if is_instance_valid(ball):
		ball.queue_free()
	ball = RigidBody3D.new()
	ball.name = "Football"
	ball.position = Vector3(0, 0.55, 0)
	ball.mass = 0.43
	ball.linear_damp = 0.55
	ball.angular_damp = 0.6
	var visual := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.38
	sphere.height = 0.76
	visual.mesh = sphere
	ball.add_child(visual)
	var collider := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.38
	collider.shape = shape
	ball.add_child(collider)
	add_child(ball)
	score = [0, 0]
	seconds_left = 180
	match_started = true
	_update_hud()

func _build_ui() -> void:
	hud = CanvasLayer.new()
	add_child(hud)
	var panel := PanelContainer.new()
	panel.position = Vector2(15, 12)
	panel.size = Vector2(370, 86)
	hud.add_child(panel)
	var vb := VBoxContainer.new()
	panel.add_child(vb)
	score_label = Label.new()
	score_label.add_theme_font_size_override("font_size", 23)
	vb.add_child(score_label)
	timer_label = Label.new()
	timer_label.add_theme_font_size_override("font_size", 18)
	vb.add_child(timer_label)
	message_label = Label.new()
	message_label.position = Vector2(440, 18)
	message_label.size = Vector2(400, 40)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.add_theme_font_size_override("font_size", 22)
	hud.add_child(message_label)
	var panel2 := PanelContainer.new()
	panel2.position = Vector2(900, 12)
	panel2.size = Vector2(360, 130)
	hud.add_child(panel2)
	var vb2 := VBoxContainer.new()
	panel2.add_child(vb2)
	var title := Label.new()
	title.text = "TEAM SELECT | GRAPHICS"
	vb2.add_child(title)
	home_select = OptionButton.new()
	for t in teams.keys(): home_select.add_item(t)
	home_select.select(0)
	home_select.item_selected.connect(_on_home_selected)
	vb2.add_child(home_select)
	away_select = OptionButton.new()
	for t in teams.keys(): away_select.add_item(t)
	away_select.select(2)
	away_select.item_selected.connect(_on_away_selected)
	vb2.add_child(away_select)
	quality_select = OptionButton.new()
	quality_select.add_item("Graphics: Low")
	quality_select.add_item("Graphics: Medium")
	quality_select.add_item("Graphics: High")
	quality_select.select(1)
	quality_select.item_selected.connect(_on_quality_selected)
	vb2.add_child(quality_select)
	_add_button("PASS", Vector2(1080,600), Vector2(82,62), _pass_ball)
	_add_button("SHOOT", Vector2(1170,520), Vector2(90,70), _shoot_ball)
	_add_button("SWITCH", Vector2(880,540), Vector2(90,55), _switch_player)
	_add_button("↑", Vector2(90,515), Vector2(52,48), func(): joystick_vector = Vector2(0,-1))
	_add_button("↓", Vector2(90,635), Vector2(52,48), func(): joystick_vector = Vector2(0,1))
	_add_button("←", Vector2(35,575), Vector2(52,48), func(): joystick_vector = Vector2(-1,0))
	_add_button("→", Vector2(145,575), Vector2(52,48), func(): joystick_vector = Vector2(1,0))
	_add_button("STOP", Vector2(92,575), Vector2(52,48), func(): joystick_vector = Vector2.ZERO)

func _add_button(caption: String, pos: Vector2, size: Vector2, callback: Callable) -> void:
	var b := Button.new()
	b.text = caption
	b.position = pos
	b.size = size
	b.add_theme_font_size_override("font_size", 17)
	b.pressed.connect(callback)
	hud.add_child(b)

func _on_home_selected(index: int) -> void:
	home_team = home_select.get_item_text(index)
	if home_team == away_team:
		away_team = "Barcelona" if home_team != "Barcelona" else "Real Madrid"
		away_select.select(teams.keys().find(away_team))
	_start_match()

func _on_away_selected(index: int) -> void:
	away_team = away_select.get_item_text(index)
	if home_team == away_team:
		away_team = "Barcelona" if home_team != "Barcelona" else "Real Madrid"
		away_select.select(teams.keys().find(away_team))
	_start_match()

func _on_quality_selected(index: int) -> void:
	camera.far = 80.0 if index == 0 else 160.0
	get_viewport().msaa_3d = Viewport.MSAA_DISABLED if index == 0 else (Viewport.MSAA_2X if index == 1 else Viewport.MSAA_4X)
	for n in get_children():
		if n is DirectionalLight3D: n.shadow_enabled = index != 0
	message_label.text = ["Low graphics","Medium graphics","High graphics"][index]

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and not event.pressed:
		joystick_touch = -1
		joystick_vector = Vector2.ZERO
	elif event is InputEventScreenDrag and event.position.x < 230 and event.position.y > 470:
		joystick_vector = ((event.position - Vector2(115,590)) / 65.0).limit_length(1.0)

func _physics_process(delta: float) -> void:
	if not match_started: return
	if seconds_left > 0:
		goal_cooldown = maxf(0.0, goal_cooldown - delta)
		if Engine.get_physics_frames() % 60 == 0:
			seconds_left -= 1
			_update_hud()
	else:
		match_started = false
		message_label.text = "FULL TIME"
		return
	_move_human()
	_move_ai(delta)
	_follow_camera(delta)
	_check_goal()

func _move_human() -> void:
	if not is_instance_valid(active_player): return
	var axis := joystick_vector
	axis.y += Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	axis.x += Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	axis = axis.limit_length(1.0)
	var speed := SPRINT_SPEED if Input.is_key_pressed(KEY_SHIFT) else PLAYER_SPEED
	active_player.velocity = Vector3(axis.x,0,axis.y) * speed
	active_player.move_and_slide()
	if axis.length() > 0.1: active_player.rotation.y = atan2(axis.x,axis.y)

func _move_ai(delta: float) -> void:
	for i in range(players.size()):
		var p := players[i]
		if p == active_player: continue
		var home: bool = player_data[i]["home"]
		var target := ball.global_position + Vector3(0,0,1)
		if home:
			target = Vector3(clampf(ball.global_position.x*0.35-4,-13,-2),0,clampf(ball.global_position.z*0.5+(i%5-2)*2.4,-8,9))
		var dir := target-p.global_position
		dir.y = 0
		if dir.length() > 0.5:
			p.velocity = dir.normalized() * (3.5 if home else 4.1)
			p.move_and_slide()
			p.rotation.y = atan2(dir.x,dir.z)
		var to_ball := ball.global_position-p.global_position
		if not home and to_ball.length() < 1.25:
			ball.apply_central_impulse(Vector3(-to_ball.x,0.15,-to_ball.z).normalized()*1.5*delta*60)

func _pass_ball() -> void:
	if active_player.global_position.distance_to(ball.global_position) > 3.0:
		message_label.text = "Move closer to the ball"
		return
	var teammate: CharacterBody3D = players[1]
	var best := INF
	for i in range(5):
		var p := players[i]
		if p == active_player: continue
		var d := p.global_position.distance_to(active_player.global_position)
		if d < best: best=d; teammate=p
	var dir := teammate.global_position-ball.global_position
	dir.y=0.12
	ball.apply_central_impulse(dir.normalized()*8.5)
	message_label.text="PASS"

func _shoot_ball() -> void:
	if active_player.global_position.distance_to(ball.global_position) > 3.0:
		message_label.text="Move closer to the ball"
		return
	var dir := Vector3(0,0,-1 if active_player.global_position.z > 0 else 1)
	dir.x = -active_player.global_position.x*0.035
	dir.y=0.23
	ball.apply_central_impulse(dir.normalized()*15.0)
	message_label.text="SHOT!"

func _switch_player() -> void:
	var best: CharacterBody3D
	var distance := INF
	for i in range(5):
		var d := players[i].global_position.distance_to(ball.global_position)
		if d < distance: distance=d; best=players[i]
	active_player=best
	message_label.text="PLAYER "+str(players.find(active_player)+1)

func _follow_camera(delta: float) -> void:
	camera.position = camera.position.lerp(active_player.global_position+Vector3(0,20,22),minf(delta*2.2,1.0))
	camera.look_at(active_player.global_position+Vector3(0,0,-2),Vector3.UP)

func _check_goal() -> void:
	if goal_cooldown > 0: return
	if absf(ball.global_position.z) > FIELD_Z/2-0.3 and absf(ball.global_position.x)<2.1:
		if ball.global_position.z<0: score[0]+=1
		else: score[1]+=1
		goal_cooldown=2.0
		message_label.text="GOAL!"
		ball.linear_velocity=Vector3.ZERO
		ball.angular_velocity=Vector3.ZERO
		ball.global_position=Vector3(0,0.6,0)
		_update_hud()

func _update_hud() -> void:
	if is_instance_valid(score_label): score_label.text="%s  %d - %d  %s" % [home_team.to_upper(),score[0],score[1],away_team.to_upper()]
	if is_instance_valid(timer_label): timer_label.text="%02d:%02d" % [seconds_left/60,seconds_left%60]

# Android build workflow trigger: SDK setup updated.
