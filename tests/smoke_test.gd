extends SceneTree

func _initialize() -> void:
	call_deferred("_run_smoke_tests")

func _expect(condition: bool, description: String) -> bool:
	if not condition:
		push_error("SMOKE TEST FAILED: " + description)
		quit(1)
		return false
	print("SMOKE TEST PASSED: " + description)
	return true

func _run_smoke_tests() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	if not _expect(packed != null, "main scene loads"):
		return
	var game: Node = packed.instantiate()
	root.add_child(game)
	await process_frame

	if not _expect(game.get("current_page") == "home", "game opens on main menu"):
		return
	game.call("_show_quality")
	if not _expect(game.get("current_page") == "quality", "quality page opens"):
		return
	game.set("quality_index", 2)
	game.call("_apply_quality")
	if not _expect(is_equal_approx((game.get("camera") as Camera3D).far, 160.0), "high quality setting applies"):
		return
	game.call("_toggle_sound")
	if not _expect(game.get("sound_enabled") == false, "master sound toggle switches off"):
		return
	game.call("_toggle_sound")
	if not _expect(game.get("sound_enabled") == true, "master sound toggle switches on"):
		return

	game.call("_show_team_select")
	var team_cards: Array = game.get("team_cards")
	if not _expect(team_cards.size() == 4, "four club selection cards are present"):
		return
	for card in team_cards:
		var has_badge := false
		for child in card.get_children():
			if child is Panel:
				has_badge = true
		if not _expect(has_badge, "club card has a generated crest badge"):
			return
	var expected_teams := ["Persepolis", "Esteghlal", "Real Madrid", "Barcelona"]
	for i in range(expected_teams.size()):
		game.call("_select_team", i)
		if not _expect(game.get("home_team") == expected_teams[i], "team card selection " + expected_teams[i]):
			return
	game.call("_select_team", 1)
	if not _expect(game.get("home_team") == "Esteghlal" and game.get("away_team") == "Barcelona", "team selection updates match teams"):
		return
	var initial_lineup: Array = game.get("lineup_names")
	if not _expect(initial_lineup[0] == "حسین حسینی", "selected club roster populates starting lineup"):
		return

	game.call("_show_formation")
	game.call("_select_lineup", 0)
	game.call("_select_bench", 0)
	var swapped_lineup: Array = game.get("lineup_names")
	var swapped_bench: Array = game.get("bench_names")
	if not _expect(swapped_lineup[0] == "آرش رضاوند" and swapped_bench[0] == "حسین حسینی", "starting player and substitute swap"):
		return

	game.call("_launch_match")
	var players: Array = game.get("players")
	if not _expect(game.get("match_started") == true and players.size() == 10, "match starts with ten players for 5v5"):
		return
	if not _expect(is_instance_valid(game.get("ball")) and is_instance_valid(game.get("active_player")), "match creates ball and controlled player"):
		return
	var active := game.get("active_player") as CharacterBody3D
	if not _expect((active.get_meta("animated_legs", []) as Array).size() == 2 and (active.get_meta("animated_arms", []) as Array).size() == 2, "player model exposes animated limbs"):
		return
	game.call("_play_sfx", 440.0, 0.04)
	var sound_stream := (game.get("audio_player") as AudioStreamPlayer).stream as AudioStreamWAV
	if not _expect(sound_stream != null and sound_stream.data.size() > 0, "procedural match sound effect is generated"):
		return

	var touch := InputEventScreenTouch.new()
	touch.index = 7
	touch.position = Vector2(115, 590)
	touch.pressed = true
	game.call("_input", touch)
	var drag := InputEventScreenDrag.new()
	drag.index = 7
	drag.position = Vector2(180, 590)
	game.call("_input", drag)
	if not _expect((game.get("joystick_vector") as Vector2).x > 0.9, "touch drag controls virtual joystick"):
		return
	var release := InputEventScreenTouch.new()
	release.index = 7
	release.position = Vector2(180, 590)
	release.pressed = false
	game.call("_input", release)
	if not _expect((game.get("joystick_vector") as Vector2) == Vector2.ZERO, "touch release resets virtual joystick"):
		return

	var match_ball := game.get("ball") as RigidBody3D
	match_ball.global_position = Vector3(0, 0.6, -11.0)
	game.call("_check_goal")
	var score: Array = game.get("score")
	if not _expect(score[0] == 1, "goal detection updates home score"):
		return
	game.set("goal_cooldown", 0.0)
	match_ball.global_position = Vector3(18.0, 0.6, 0.0)
	match_ball.linear_velocity = Vector3(3.0, 0.0, 0.0)
	game.call("_check_goal")
	if not _expect(match_ball.global_position.x <= 16.61 and match_ball.linear_velocity.x < 0.0, "ball is recovered after leaving touchline"):
		return

	game.call("_return_to_menu")
	await process_frame
	if not _expect(game.get("match_started") == false and game.get("players").size() == 0, "return to menu cleans up match entities"):
		return
	var hud := game.get("hud") as CanvasLayer
	if not _expect(game.get("menu_root").visible and hud.get_child_count() == 1, "return to menu removes stale HUD controls"):
		return

	print("ALL FOOTBALL PRO 27 SMOKE TESTS PASSED")
	quit(0)
