extends SceneTree

var failures := 0

func check(ok: bool, label: String) -> void:
	print("PASS: " if ok else "FAIL: ", label)
	if not ok:
		failures += 1

func frames(count: int) -> void:
	for i in count:
		await physics_frame

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var level = load("res://scenes/ilot_grey.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await frames(30)
	var player = level.get_node("Player")
	var skate = player.skate
	check(player.is_on_floor(), "Player settles on ground")
	var kicker = level.get_node("Obstacles/Kicker")
	var front = kicker.to_global(Vector3(0, 0.3, 1.7))
	var back = kicker.to_global(Vector3(0, 0.3, -1.7))
	print("Kicker front/back: ", front, " / ", back)
	check(front.y < back.y, "Kicker rises away from spawn (+Z toward -Z)")
	for name in ["Rail", "Ledge"]:
		var rail = level.get_node("Obstacles/" + name)
		print(name, " endpoints: ", rail.top_start(), " / ", rail.top_end())
		check(rail.top_end().z < rail.top_start().z, name + " extends away from spawn")
	Input.action_press("move_forward")
	await frames(30)
	Input.action_release("move_forward")
	check(player.position.z < 12.5, "Walking forward")
	await frames(20)
	Input.action_press("toggle_board")
	await frames(2)
	Input.action_release("toggle_board")
	check(player.mode == player.Mode.SKATE and player.board.visible, "Mount board")
	Input.action_press("push")
	await frames(50)
	Input.action_release("push")
	check(skate.speed > 2.0, "Push accelerates")
	Input.action_press("jump")
	await frames(2)
	Input.action_release("jump")
	check(skate.in_air and player.velocity.y > 0.0, "Ollie takes off")
	Input.action_press("kickflip")
	await frames(2)
	Input.action_release("kickflip")
	check(skate.trick == "Kickflip", "Kickflip starts in air")
	await frames(85)
	check(not skate.in_air and skate.last_event == "Kickflip", "Completed kickflip lands cleanly")
	player._respawn()
	await frames(10)
	check(player.mode == player.Mode.WALK and player.position.distance_to(player.spawn_position) < 0.15, "Reset returns to spawn on foot")
	player._set_mode(player.Mode.SKATE)
	Input.action_press("jump")
	await frames(2)
	Input.action_release("jump")
	Input.action_press("shove_it")
	await frames(2)
	Input.action_release("shove_it")
	check(skate.trick == "Shove-it", "Shove-it starts in air")
	await frames(85)
	check(skate.last_event == "Shove-it", "Completed shove-it lands cleanly")
	for name in ["Rail", "Ledge"]:
		var rail = level.get_node("Obstacles/" + name)
		player.global_position = rail.top_start() + Vector3(0.1, 0.2, -0.5)
		player.velocity = Vector3(0, -1, -5)
		skate.speed = 5.0
		skate.heading = 0.0
		skate.in_air = true
		skate.trick_t = 1.0
		Input.action_press("grind")
		await frames(5)
		check(skate.grinding and skate.last_event == "50-50", name + " catches 50-50")
		var grind_start = player.global_position
		await frames(20)
		check(player.global_position.z < grind_start.z - 0.5, name + " grind advances along obstacle")
		Input.action_release("grind")
		await frames(2)
		check(not skate.grinding, name + " grind releases")
	player._respawn()
	await frames(10)
	player._set_mode(player.Mode.SKATE)
	player.global_position.y = 0.08
	player.velocity = Vector3(0, -2, 0)
	Input.action_press("jump")
	await frames(2)
	Input.action_release("jump")
	# A flip started immediately before contact must fail to land cleanly.
	player.global_position.y = 0.08
	player.velocity.y = -2.0
	skate.in_air = true
	skate.trick = "Kickflip"
	skate.trick_t = 0.0
	await frames(15)
	check(skate.last_event.begins_with("Chute"), "Unfinished flip causes bail")
	print("Failures: ", failures)
	quit(0 if failures == 0 else 1)
