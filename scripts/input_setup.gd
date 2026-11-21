extends Node
## Déclare les contrôles au lancement (autoload « InputSetup »).
## Les touches sont des touches PHYSIQUES : la position QWERTY W/A/S/D
## correspond à Z/Q/S/D sur un clavier AZERTY. Manette prise en charge.
##
## Clavier (main droite sur les flèches, main gauche sur Espace/Maj/E/G…)   Manette
##   Flèches (ou ZQSD)  se déplacer            stick gauche
##   souris (option)    caméra (elle suit seule) stick droit
##   Espace saut / ollie / grimper             A (croix)
##   Maj    courir / pousser                   gâchette droite
##   E      planche / monter / descendre       Y (triangle)
##   X      kickflip  (ou J)                   X (carré)
##   C      shove-it  (ou K)                   B (rond)
##   B      grind (maintenir, ou L)            bouton épaule droite
##   V      monter dans un véhicule            croix droite
##   G      graffiti : ouvre le choix          bouton épaule gauche
##   F      fouiller (snack, conteneur)        croix bas
##   R      revenir au départ    Select
##   F2     rendu BD / d'origine (comparaison)   —
##   Échap  libérer la souris


func _ready() -> void:
	_key("move_forward", KEY_W)
	_key("move_back", KEY_S)
	_key("move_left", KEY_A)
	_key("move_right", KEY_D)
	_key("move_forward", KEY_UP)
	_key("move_back", KEY_DOWN)
	_key("move_left", KEY_LEFT)
	_key("move_right", KEY_RIGHT)
	_axis("move_forward", JOY_AXIS_LEFT_Y, -1.0)
	_axis("move_back", JOY_AXIS_LEFT_Y, 1.0)
	_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_axis("move_right", JOY_AXIS_LEFT_X, 1.0)

	_axis("cam_left", JOY_AXIS_RIGHT_X, -1.0)
	_axis("cam_right", JOY_AXIS_RIGHT_X, 1.0)
	_axis("cam_up", JOY_AXIS_RIGHT_Y, -1.0)
	_axis("cam_down", JOY_AXIS_RIGHT_Y, 1.0)

	_key("jump", KEY_SPACE)
	_button("jump", JOY_BUTTON_A)
	_key("push", KEY_SHIFT)
	_axis("push", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_key("toggle_board", KEY_E)
	_button("toggle_board", JOY_BUTTON_Y)
	_key("kickflip", KEY_J)
	_key("kickflip", KEY_X)
	_button("kickflip", JOY_BUTTON_X)
	_key("shove_it", KEY_K)
	_key("shove_it", KEY_C)
	_button("shove_it", JOY_BUTTON_B)
	_key("grind", KEY_L)
	_key("grind", KEY_B)
	_button("grind", JOY_BUTTON_RIGHT_SHOULDER)
	_key("graff", KEY_G)
	_button("graff", JOY_BUTTON_LEFT_SHOULDER)
	_key("graff_color", KEY_TAB)   # changer de bombe (aussi dans le choix du graffiti)
	_button("graff_color", JOY_BUTTON_DPAD_UP)
	_key("fouiller", KEY_F)
	_button("fouiller", JOY_BUTTON_DPAD_DOWN)
	_key("reset", KEY_R)
	_button("reset", JOY_BUTTON_BACK)
	_key("style_bd", KEY_F2)   # rendu BD / d'origine (outil de comparaison)
	# Choix direct du graffiti face à un mur : 1 tag, 2 flop, 3 pièce, 4 perche, 5 rouleau.
	for i in 5:
		_key("graff_%d" % (i + 1), KEY_1 + i)
	_key("graff_mode", KEY_M)   # graffiti : mode simple / expert


func _ensure(action: StringName) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)


func _key(action: StringName, keycode: Key) -> void:
	_ensure(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	InputMap.action_add_event(action, ev)


func _button(action: StringName, button: JoyButton) -> void:
	_ensure(action)
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)


func _axis(action: StringName, axis: JoyAxis, value: float) -> void:
	_ensure(action)
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	InputMap.action_add_event(action, ev)
