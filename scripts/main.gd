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

var selected_team_index := 0
var quality_index := 1
var sound_enabled := true
var menu_root: Control
var current_page := "home"
var team_cards: Array[Button] = []
var lineup_names := ["دروازه‌بان","مدافع راست","مدافع چپ","هافبک","مهاجم"]
var bench_names := ["بازیکن ذخیره ۱","بازیکن ذخیره ۲","بازیکن ذخیره ۳"]
var selected_lineup_slot := -1
var selected_bench_slot := -1
var player_name_tags: Array[Label3D] = []

var squad_data := {
	"Persepolis": ["پیام نیازمند","کنعانی‌زادگان","میلاد محمدی","سروش رفیعی","علی علیپور","امید عالیشاه","محمد خدابنده‌لو","اورونوف"],
	"Esteghlal": ["حسین حسینی","روزبه چشمی","عارف غلامی","ابوالفضل جلالی","رامین رضاییان","آرش رضاوند","محمدحسین اسلامی","مهرداد محمدی"],
	"Real Madrid": ["Courtois","Rüdiger","Militão","Valverde","Mbappé","Bellingham","Vinícius Jr.","Rodrygo"],
	"Barcelona": ["Ter Stegen","Araujo","Koundé","Pedri","Lamine Yamal","Gavi","Raphinha","Ferran Torres"]
}

func _ready() -> void:
	_build_world()
	_build_home_menu()

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
	_build_stadium()
	_build_pitch_details()

func _build_pitch_details() -> void:
	# Alternating turf bands and complete boundary/box markings.
	for i in range(8):
		var z := -FIELD_Z / 2.0 + 1.4 + float(i) * 2.8
		var band := _make_box("Mown grass stripe", Vector3(FIELD_X - 0.2, 0.012, 2.8), Vector3(0, 0.145, z), Color("#2c8543") if i % 2 == 0 else Color("#267a3c"))
	for x in [-FIELD_X / 2.0, FIELD_X / 2.0]:
		_make_box("Touch line", Vector3(0.07, 0.025, FIELD_Z), Vector3(x, 0.17, 0), Color.WHITE)
	for z in [-FIELD_Z / 2.0, FIELD_Z / 2.0]:
		_make_box("Goal line", Vector3(FIELD_X, 0.025, 0.07), Vector3(0, 0.17, z), Color.WHITE)
	for z in [-FIELD_Z / 2.0 + 3.2, FIELD_Z / 2.0 - 3.2]:
		_make_box("Penalty area side", Vector3(10, 0.025, 0.07), Vector3(0, 0.17, z), Color.WHITE)
		_make_box("Penalty area edge", Vector3(0.07, 0.025, 3.2), Vector3(-5, 0.17, z + (1.6 if z < 0 else -1.6)), Color.WHITE)
		_make_box("Penalty area edge", Vector3(0.07, 0.025, 3.2), Vector3(5, 0.17, z + (1.6 if z < 0 else -1.6)), Color.WHITE)

func _build_stadium() -> void:
	# Compact stands, advertising boards and floodlights frame the pitch.
	_make_box("Stadium floor", Vector3(48, 0.3, 34), Vector3(0, -0.48, 0), Color("#303b42"))
	for side in [-1.0, 1.0]:
		for row in range(5):
			var stand := _make_box("Stands", Vector3(42, 0.55, 1.1), Vector3(0, 0.25 + float(row) * 0.62, side * (13.2 + float(row) * 0.75)), Color("#45545d") if row % 2 == 0 else Color("#37454e"))
			for seat in range(22):
				var seat_box := _make_box("Stadium seat", Vector3(0.42, 0.28, 0.42), Vector3(-19.5 + float(seat) * 1.85, 0.75 + float(row) * 0.62, side * (13.1 + float(row) * 0.75)), Color("#b52b36") if seat % 3 == 0 else Color("#d0d5d8"))
		_make_box("Advertising board", Vector3(38, 0.75, 0.22), Vector3(0, 0.48, side * 11.35), Color("#123c52"))
	for x in [-22.0, 22.0]:
		for z in [-14.0, 14.0]:
			var pole := _make_box("Floodlight pole", Vector3(0.28, 12, 0.28), Vector3(x, 5.5, z), Color("#aeb8bd"))
			_make_box("Floodlight panel", Vector3(2.2, 0.5, 0.6), Vector3(x, 11.7, z), Color("#f5f1d7"))

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
	var gz: float = z - signf(z) * 0.7
	for x in [-2.1, 2.1]:
		_make_box("Goal post", Vector3(0.16, 2.1, 0.16), Vector3(x, 1.15, gz), Color.WHITE)
	_make_box("Goal crossbar", Vector3(4.3, 0.16, 0.16), Vector3(0, 2.2, gz), Color.WHITE)
	for x in range(-2, 3):
		_make_box("Net", Vector3(0.025, 1.9, 0.025), Vector3(float(x), 1.1, gz - sign(z) * 1.2), Color("#dddddd"))

func _build_player(team_color: Color, pos: Vector3, is_home: bool, index: int) -> CharacterBody3D:
	var body := CharacterBody3D.new()
	body.position = pos
	body.name = ("Home_" if is_home else "Away_") + str(index)
	# Distinct jersey, shorts, arms and boots instead of a single capsule placeholder.
	var jersey := MeshInstance3D.new()
	var torso := CapsuleMesh.new()
	torso.radius = 0.34
	torso.height = 0.92
	jersey.mesh = torso
	jersey.position.y = 1.22
	var jersey_mat := StandardMaterial3D.new()
	jersey_mat.albedo_color = team_color
	jersey_mat.roughness = 0.72
	jersey.material_override = jersey_mat
	body.add_child(jersey)
	var shorts := MeshInstance3D.new()
	var shorts_mesh := CylinderMesh.new()
	shorts_mesh.top_radius = 0.29
	shorts_mesh.bottom_radius = 0.31
	shorts_mesh.height = 0.36
	shorts.mesh = shorts_mesh
	shorts.position.y = 0.72
	var shorts_mat := StandardMaterial3D.new()
	shorts_mat.albedo_color = Color("#17202a")
	shorts.material_override = shorts_mat
	body.add_child(shorts)
	for side in [-1.0, 1.0]:
		var arm := MeshInstance3D.new()
		var arm_mesh := CapsuleMesh.new()
		arm_mesh.radius = 0.105
		arm_mesh.height = 0.68
		arm.mesh = arm_mesh
		arm.position = Vector3(side * 0.39, 1.18, 0)
		arm.rotation.z = side * -0.12
		var arm_mat := StandardMaterial3D.new()
		arm_mat.albedo_color = team_color
		arm.material_override = arm_mat
		body.add_child(arm)
		var leg := MeshInstance3D.new()
		var leg_mesh := CylinderMesh.new()
		leg_mesh.top_radius = 0.115
		leg_mesh.bottom_radius = 0.095
		leg_mesh.height = 0.62
		leg.mesh = leg_mesh
		leg.position = Vector3(side * 0.16, 0.34, 0)
		var leg_mat := StandardMaterial3D.new()
		leg_mat.albedo_color = Color("#20252b")
		leg.material_override = leg_mat
		body.add_child(leg)
		var boot := MeshInstance3D.new()
		var boot_mesh := BoxMesh.new()
		boot_mesh.size = Vector3(0.18, 0.12, 0.32)
		boot.mesh = boot_mesh
		boot.position = Vector3(side * 0.16, 0.08, -0.07)
		var boot_mat := StandardMaterial3D.new()
		boot_mat.albedo_color = Color("#111820")
		boot.material_override = boot_mat
		body.add_child(boot)
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
		var tag := Label3D.new()
		tag.text = lineup_names[i]
		tag.font_size = 28
		tag.position = Vector3(0, 2.35, 0)
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		p.add_child(tag)
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

func _build_home_menu() -> void:
	hud = CanvasLayer.new()
	add_child(hud)
	menu_root = Control.new()
	menu_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.add_child(menu_root)
	_show_home()

func _clear_menu() -> void:
	for child in menu_root.get_children():
		child.queue_free()

func _make_panel(parent: Control, pos: Vector2, size: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.position = pos
	panel.size = size
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.075, 0.09, 0.96)
	style.border_color = Color("#d4ad55")
	style.set_border_width_all(2)
	style.set_corner_radius_all(18)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	return panel

func _make_title(parent: Control, text_value: String, pos: Vector2, size: Vector2, font_size := 34) -> void:
	var label := Label.new()
	label.text = text_value
	label.position = pos
	label.size = size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("#f5d98b"))
	parent.add_child(label)

func _make_menu_button(parent: Control, caption: String, pos: Vector2, size: Vector2, callback: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.position = pos
	button.size = size
	button.add_theme_font_size_override("font_size", 23)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#174c4b")
	style.border_color = Color("#d4ad55")
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	button.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate()
	hover.bg_color = Color("#24736b")
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _show_home() -> void:
	current_page = "home"
	_clear_menu()
	_make_panel(menu_root, Vector2(300, 55), Vector2(680, 610))
	_make_title(menu_root, "FOOTBALL PRO 27", Vector2(340, 95), Vector2(600, 65), 42)
	_make_title(menu_root, "فوتبال پنج‌نفره", Vector2(420, 158), Vector2(440, 40), 22)
	_make_menu_button(menu_root, "شروع بازی", Vector2(485, 230), Vector2(310, 64), _show_team_select)
	_make_menu_button(menu_root, "انتخاب کیفیت تصویر", Vector2(485, 310), Vector2(310, 58), _show_quality)
	_make_menu_button(menu_root, "صدا: " + ("روشن" if sound_enabled else "خاموش"), Vector2(485, 383), Vector2(310, 58), _toggle_sound)
	_make_menu_button(menu_root, "خروج", Vector2(485, 456), Vector2(310, 58), func(): get_tree().quit())
	_make_title(menu_root, "نسخه آزمایشی", Vector2(480, 535), Vector2(320, 35), 16)

func _toggle_sound() -> void:
	sound_enabled = not sound_enabled
	_show_home()

func _show_quality() -> void:
	current_page = "quality"
	_clear_menu()
	_make_panel(menu_root, Vector2(300, 55), Vector2(680, 610))
	_make_title(menu_root, "تنظیمات کیفیت تصویر", Vector2(360, 105), Vector2(560, 70), 34)
	var labels := ["پایین", "متوسط", "بالا"]
	for i in range(3):
		var idx := i
		var mark := "  ✓" if quality_index == i else ""
		_make_menu_button(menu_root, labels[i] + mark, Vector2(455, 220 + i * 82), Vector2(370, 62), func(): quality_index = idx; _apply_quality(); _show_quality())
	_make_menu_button(menu_root, "بازگشت", Vector2(485, 505), Vector2(310, 58), _show_home)

func _show_team_select() -> void:
	current_page = "teams"
	_clear_menu()
	team_cards.clear()
	_make_panel(menu_root, Vector2(105, 35), Vector2(1070, 650))
	_make_title(menu_root, "تیم خودت را انتخاب کن", Vector2(300, 58), Vector2(680, 58), 34)
	var names := ["Persepolis", "Esteghlal", "Real Madrid", "Barcelona"]
	var crests := ["P", "E", "RM", "FCB"]
	var kit_colors := [Color("#d71920"), Color("#1766c2"), Color("#f0f0f0"), Color("#a50044")]
	for i in range(4):
		var idx := i
		var x := 145.0 + float(i) * 260.0
		var card := _make_menu_button(menu_root, crests[i] + "\n" + names[i] + "\nلباس تیم", Vector2(x, 190), Vector2(225, 205), func(): _select_team(idx))
		card.add_theme_font_size_override("font_size", 24)
		var card_style := StyleBoxFlat.new()
		card_style.bg_color = kit_colors[i]
		card_style.border_color = Color("#f5d98b") if selected_team_index == i else Color("#50666a")
		card_style.set_border_width_all(4 if selected_team_index == i else 2)
		card_style.set_corner_radius_all(16)
		card.add_theme_stylebox_override("normal", card_style)
		card.add_theme_color_override("font_color", Color.BLACK if i == 2 else Color.WHITE)
		team_cards.append(card)
	_make_title(menu_root, "برای جابه‌جایی بین تیم‌ها از کنترل جهت‌دار استفاده کن", Vector2(280, 420), Vector2(720, 35), 17)
	_make_menu_button(menu_root, "◀", Vector2(440, 470), Vector2(80, 65), func(): _select_team(posmod(selected_team_index - 1, 4)))
	_make_menu_button(menu_root, "▶", Vector2(760, 470), Vector2(80, 65), func(): _select_team((selected_team_index + 1) % 4))
	_make_menu_button(menu_root, "ادامه", Vector2(515, 555), Vector2(250, 60), _show_formation)
	_make_menu_button(menu_root, "بازگشت", Vector2(150, 555), Vector2(190, 60), _show_home)
	_select_team(selected_team_index)

func _select_team(index: int) -> void:
	selected_team_index = index
	var names := ["Persepolis", "Esteghlal", "Real Madrid", "Barcelona"]
	home_team = names[index]
	away_team = names[(index + 2) % 4]
	var roster: Array = squad_data[home_team]
	lineup_names = [str(roster[0]), str(roster[1]), str(roster[2]), str(roster[3]), str(roster[4])]
	bench_names = [str(roster[5]), str(roster[6]), str(roster[7])]
	for i in range(team_cards.size()):
		var st := StyleBoxFlat.new()
		var cols := [Color("#d71920"), Color("#1766c2"), Color("#f0f0f0"), Color("#a50044")]
		st.bg_color = cols[i]
		st.border_color = Color("#f5d98b") if i == index else Color("#50666a")
		st.set_border_width_all(5 if i == index else 2)
		st.set_corner_radius_all(16)
		team_cards[i].add_theme_stylebox_override("normal", st)

func _show_formation() -> void:
	current_page = "formation"
	_clear_menu()
	_make_panel(menu_root, Vector2(55, 20), Vector2(1170, 680))
	_make_title(menu_root, "ترکیب تیم  |  " + home_team, Vector2(350, 32), Vector2(580, 52), 30)
	_make_title(menu_root, "روی یک بازیکن اصلی و سپس یک بازیکن ذخیره بزن تا جابه‌جا شوند", Vector2(250, 85), Vector2(780, 34), 17)
	# Mini pitch with five chess-piece positions.
	var pitch := ColorRect.new()
	pitch.position = Vector2(100, 145)
	pitch.size = Vector2(700, 420)
	pitch.color = Color("#277844")
	menu_root.add_child(pitch)
	var midline := ColorRect.new()
	midline.position = Vector2(100, 354)
	midline.size = Vector2(700, 3)
	midline.color = Color.WHITE
	menu_root.add_child(midline)
	var roster: Array[String] = squad_data[home_team]
	var positions := [Vector2(430, 495), Vector2(265, 405), Vector2(595, 405), Vector2(430, 305), Vector2(430, 190)]
	for i in range(5):
		var idx := i
		var piece := _make_menu_button(menu_root, "●\n" + lineup_names[i], positions[i] - Vector2(65, 35), Vector2(130, 70), func(): _select_lineup(idx))
		piece.add_theme_font_size_override("font_size", 15)
		if lineup_names[i] == "دروازه‌بان" or lineup_names[i] == "مدافع راست":
			piece.modulate = Color(1,1,1,1)
	_make_title(menu_root, "نیمکت ذخیره", Vector2(850, 145), Vector2(300, 38), 22)
	for i in range(3):
		var idx := i
		_make_menu_button(menu_root, bench_names[i], Vector2(850, 195 + i * 78), Vector2(285, 58), func(): _select_bench(idx))
	_make_menu_button(menu_root, "شروع مسابقه  ▶", Vector2(850, 470), Vector2(285, 70), _launch_match)
	_make_menu_button(menu_root, "بازگشت به انتخاب تیم", Vector2(850, 555), Vector2(285, 55), _show_team_select)

func _select_lineup(index: int) -> void:
	selected_lineup_slot = index
	if selected_bench_slot >= 0:
		_swap_squad()
		_show_formation()

func _select_bench(index: int) -> void:
	selected_bench_slot = index
	if selected_lineup_slot >= 0:
		_swap_squad()
		_show_formation()

func _swap_squad() -> void:
	var temp := lineup_names[selected_lineup_slot]
	lineup_names[selected_lineup_slot] = bench_names[selected_bench_slot]
	bench_names[selected_bench_slot] = temp
	selected_lineup_slot = -1
	selected_bench_slot = -1

func _launch_match() -> void:
	menu_root.visible = false
	_build_ui()
	_start_match()
	_apply_quality()

func _apply_quality() -> void:
	if not is_instance_valid(camera): return
	camera.far = 80.0 if quality_index == 0 else 160.0
	get_viewport().msaa_3d = Viewport.MSAA_DISABLED if quality_index == 0 else (Viewport.MSAA_2X if quality_index == 1 else Viewport.MSAA_4X)
	for n in get_children():
		if n is DirectionalLight3D:
			n.shadow_enabled = quality_index != 0

func _build_ui() -> void:
	for child in hud.get_children():
		if child != menu_root:
			child.queue_free()
	var panel := PanelContainer.new()
	panel.position = Vector2(15, 12)
	panel.size = Vector2(380, 88)
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
	_add_button("PASS", Vector2(1080,600), Vector2(82,62), _pass_ball)
	_add_button("SHOOT", Vector2(1170,520), Vector2(90,70), _shoot_ball)
	_add_button("SWITCH", Vector2(880,540), Vector2(90,55), _switch_player)
	_add_button("↑", Vector2(90,515), Vector2(52,48), func(): joystick_vector = Vector2(0,-1))
	_add_button("↓", Vector2(90,635), Vector2(52,48), func(): joystick_vector = Vector2(0,1))
	_add_button("←", Vector2(35,575), Vector2(52,48), func(): joystick_vector = Vector2(-1,0))
	_add_button("→", Vector2(145,575), Vector2(52,48), func(): joystick_vector = Vector2(1,0))
	_add_button("STOP", Vector2(92,575), Vector2(52,48), func(): joystick_vector = Vector2.ZERO)
	_add_button("MENU", Vector2(1120,20), Vector2(130,48), func(): match_started = false; menu_root.visible = true; _show_home())

func _add_button(caption: String, pos: Vector2, size: Vector2, callback: Callable) -> void:
	var b := Button.new()
	b.text = caption
	b.position = pos
	b.size = size
	b.add_theme_font_size_override("font_size", 17)
	b.pressed.connect(callback)
	hud.add_child(b)

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
