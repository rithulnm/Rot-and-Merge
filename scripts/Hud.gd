extends CanvasLayer

@onready var score_label: Label = $Control/TopBar/Control/ScoreLabel
@onready var high_score_label: Label = $Control/TopBar/Control/HighScoreLabel
@onready var side_panel: Control = $Control/SidePanel
@onready var tab_button: TextureButton = $Control/SidePanel/Tab
@onready var powerup_list: VBoxContainer = $Control/SidePanel/PowerupList
@onready var coins_label: Label = $Control/TopBar/CoinPanel/Coin/CoinsLabel
@onready var key_label: Label = $Control/TopBar/KeyPanel/Key/KeysLabel
@onready var key_icon: TextureRect = $Control/TopBar/KeyPanel/Key/KeysIcon
@onready var sfx_coin_reward: AudioStreamPlayer = $SFX_ScoreCount

var tab_open_texture = preload("res://assets/sprites/sidebtn_left.png")
var tab_closed_texture = preload("res://assets/sprites/sidebtn_right.png")
var coin_animating := false
var key_animating := false
var powerup_buttons: Array = []
var powerup_types: Array = []  # actual GameManager.PowerupType for each button
var panel_open: bool = false
var panel_closed_x: float = 0.0
var panel_open_x: float = 0.0
var normal_textures = []
var locked_textures = []

func _on_score_changed(new_score):
	_update_score(new_score)

func _ready():
	GameManager.score_changed.connect(_on_score_changed)
	GameManager.score_changed.connect(func(_s): update_powerup_buttons())
	var game = get_tree().get_first_node_in_group("game")
	if game:
		game.board_state_changed.connect(update_powerup_buttons)
	GameManager.keys_changed.connect(_on_keys_changed)
	_build_panel()

	await get_tree().process_frame

	panel_closed_x = side_panel.position.x
	panel_open_x = side_panel.position.x - side_panel.size.x - 35

	tab_button.pressed.connect(_toggle_panel)
	GameManager.coins_changed.connect(_on_coins_changed)
	GameManager.ad_reward_granted.connect(_on_ad_reward_granted)
	coins_label.text = str(GameManager.get_total_coins())
	key_label.text = str(GameManager.keys)
	tab_button.pivot_offset = tab_button.size/2
	_start_button_pulse(tab_button)
	_update_score(0)
	update_powerup_buttons()

func _build_panel():
	normal_textures = [
		preload("res://assets/sprites/icons/shake_icon.png"),
		preload("res://assets/sprites/icons/pluck_icon.png"),
		preload("res://assets/sprites/icons/cure_icon.png"),
		preload("res://assets/sprites/icons/purge_icon.png"),
		preload("res://assets/sprites/icons/bomb_icon.png"),
		preload("res://assets/sprites/icons/refresh_icon.png"),
		preload("res://assets/sprites/icons/ripple_icon.png"),
	]

	locked_textures = [
		preload("res://assets/sprites/icons/Icon_Plus/shake_icon_plus.png"),
		preload("res://assets/sprites/icons/Icon_Plus/pluck_icon_plus.png"),
		preload("res://assets/sprites/icons/Icon_Plus/cure_icon_plus.png"),
		preload("res://assets/sprites/icons/Icon_Plus/purge_icon_plus.png"),
		preload("res://assets/sprites/icons/Icon_Plus/bomb_icon_plus.png"),
		preload("res://assets/sprites/icons/Icon_Plus/refresh_icon_plus.png"),
		preload("res://assets/sprites/icons/Icon_Plus/ripple_icon_plus.png"),
	]

	for i in range(1, 8):
		var btn = powerup_list.get_child(i)
		powerup_buttons.append(btn)
		powerup_types.append(i)

		btn.pressed.connect(_on_powerup_pressed.bind(i))

func _toggle_panel():
	panel_open = not panel_open
	var target_x = panel_open_x if panel_open else panel_closed_x
	var tween = create_tween()
	tween.tween_property(side_panel, "position:x", target_x, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	if panel_open:
		tab_button.texture_normal = tab_open_texture
	else:
		tab_button.texture_normal = tab_closed_texture

func close_panel():
	if not panel_open:
		return
	panel_open = false
	var tween = create_tween()
	tween.tween_property(side_panel, "position:x", panel_closed_x, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tab_button.texture_normal = tab_closed_texture
	
func _on_powerup_pressed(index: int):
	# Play click sound via game node
	var game_node = get_tree().get_first_node_in_group("game")
	if game_node:
		game_node.sfx_powerup_click.pitch_scale = randf_range(0.95, 1.05)
		game_node.sfx_powerup_click.play()
		
	var type = index as GameManager.PowerupType
	var affordable = GameManager.can_use_powerup(type)
	var usable = _game_can_use_powerup(type)
	if not usable:
		_show_no_targets(index)
		return
	if not affordable:
		var game = get_tree().get_first_node_in_group("game")
		if game:
			game.show_ad_popup(type)
		return
	var selection_powerups = [2, 3, 4, 5]
	if index in selection_powerups:
		_notify_game_selected(index)
		_toggle_panel()
		return
	GameManager.use_powerup(type)
	_notify_game_selected(index)
	_toggle_panel()

func _update_score(new_score):
	score_label.text = str(new_score)
	high_score_label.text = "Best: " + str(GameManager.high_score)

func _on_coins_changed(new_coins):
	coins_label.text = str(new_coins)
	update_powerup_buttons()
	_play_coin_animation()

func _on_ad_reward_granted(amount: int):
	# Sound
	sfx_coin_reward.pitch_scale = randf_range(0.97, 1.03)
	sfx_coin_reward.play()

	var pos = coins_label.global_position + coins_label.size / 2.0

	# Extra emphasis punch on the coin number, bigger than the normal tick bounce
	coins_label.pivot_offset = coins_label.size / 2.0
	var punch = create_tween()
	punch.tween_property(coins_label, "scale", Vector2(1.35, 1.35), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	punch.tween_property(coins_label, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_ELASTIC)

	_spawn_coin_sparkles(pos)
	_spawn_floating_coin_label(amount, pos)

func _spawn_coin_sparkles(pos: Vector2):
	var sparkle_tex = preload("res://assets/sprites/sparkle.png")
	var colors = [
		Color(1.0, 0.85, 0.2, 1.0),
		Color(1.0, 0.95, 0.6, 1.0),
		Color(1.0, 0.8, 0.0, 1.0),
	]
	for i in 8:
		var spark = TextureRect.new()
		spark.texture = sparkle_tex
		spark.z_index = 500
		spark.size = Vector2(16, 16)
		spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		$Control.add_child(spark)
		spark.global_position = pos
		spark.modulate = colors[i % colors.size()]
		spark.pivot_offset = spark.size / 2.0
		spark.scale = Vector2(0.6, 0.6)

		var angle = (TAU / 8.0) * i
		var dist = randf_range(30.0, 60.0)
		var target = pos + Vector2(cos(angle), sin(angle)) * dist

		var t = create_tween()
		t.set_parallel(true)
		t.tween_property(spark, "global_position", target, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t.tween_property(spark, "scale", Vector2(1.2, 1.2), 0.2)
		t.tween_property(spark, "scale", Vector2.ZERO, 0.3).set_delay(0.2)
		t.tween_property(spark, "modulate:a", 0.0, 0.3).set_delay(0.25)
		t.tween_callback(spark.queue_free).set_delay(0.55)

func _spawn_floating_coin_label(amount: int, pos: Vector2):
	var label = Label.new()
	$Control.add_child(label)
	var font = load("res://assets/fonts/ArchivoBlack-Regular.ttf")
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", 40)
	label.add_theme_color_override("font_color", Color(1.0, 0.939, 0.708, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.204, 0.131, 0.0, 1.0))
	label.add_theme_constant_override("outline_size", 3)
	label.text = "+" + str(amount)
	label.z_index = 500
	label.global_position = pos
	label.pivot_offset = Vector2(20, 10)
	label.scale = Vector2.ZERO

	var punch = create_tween()
	punch.tween_property(label, "scale", Vector2(1.3, 1.3), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	punch.tween_property(label, "scale", Vector2.ONE, 0.1)

	var float_tween = create_tween()
	float_tween.set_parallel(true)
	float_tween.tween_property(label, "global_position", pos + Vector2(0, -50), 1.0).set_ease(Tween.EASE_OUT)
	float_tween.tween_property(label, "modulate:a", 0.0, 1.0).set_ease(Tween.EASE_IN)
	float_tween.tween_callback(label.queue_free).set_delay(1.0)
	
func _notify_game_selected(index: int):
	var game = get_tree().get_first_node_in_group("game")
	if not game:
		return
	game.activate_powerup(index)

func _on_keys_changed(new_keys: int):
	key_label.text = str(new_keys)
	_play_key_animation()

func _play_key_animation():
	if key_animating:
		return
	key_animating = true

	key_label.pivot_offset = key_label.size / 2.0
	if key_icon:
		key_icon.pivot_offset = key_icon.size / 2.0

	# Punch scale on both label and icon
	var t = create_tween()
	t.set_parallel(true)
	t.tween_property(key_label, "scale", Vector2(1.3, 1.3), 0.08)
	if key_icon:
		t.tween_property(key_icon, "scale", Vector2(1.25, 1.25), 0.08)
	await t.finished

	var t2 = create_tween()
	t2.set_parallel(true)
	t2.tween_property(key_label, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_ELASTIC)
	if key_icon:
		t2.tween_property(key_icon, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_ELASTIC)

	# Brief gold flash on the label color so it reads as a "reward," not just a counter tick
	var original_color = key_label.get_theme_color("font_color") if key_label.has_theme_color_override("font_color") else Color.WHITE
	key_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1.0))
	var flash_back = create_tween()
	flash_back.tween_property(key_label, "modulate", Color.WHITE, 0.01)
	await get_tree().create_timer(0.3).timeout
	key_label.add_theme_color_override("font_color", original_color)

	await t2.finished
	key_animating = false
	
func _play_coin_animation():
	if coin_animating:
		return
	coin_animating = true
	var original_scale = coins_label.scale
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(coins_label, "scale", Vector2(1.12, 1.12), 0.06)
	await tween.finished
	var tween2 = create_tween()
	tween2.tween_property(coins_label, "scale", original_scale, 0.12).set_trans(Tween.TRANS_ELASTIC)
	await tween2.finished
	coin_animating = false

func _game_can_use_powerup(type: int) -> bool:
	var game = get_tree().get_first_node_in_group("game")
	if not game:
		return false
	return game.can_activate_powerup(type)

func update_powerup_buttons():
	for i in powerup_buttons.size():
		var btn = powerup_buttons[i]
		var type = powerup_types[i] as GameManager.PowerupType
		var affordable = GameManager.can_use_powerup(type)
		var usable = _game_can_use_powerup(type)

		if not usable:
			btn.disabled = true
			btn.modulate = Color(0.4, 0.4, 0.4, 0.7)
			continue

		btn.disabled = false
		btn.modulate = Color(1, 1, 1, 1)

		if not affordable:
			btn.texture_normal = locked_textures[i]
		else:
			btn.texture_normal = normal_textures[i]

func _show_no_targets(index: int):
	var btn = powerup_buttons[powerup_types.find(index)]
	var t = create_tween()
	t.tween_property(btn, "modulate", Color(0.5, 0.5, 1.0, 1.0), 0.1)
	t.tween_property(btn, "modulate", Color(0.4, 0.4, 0.4, 0.7), 0.2)

func _start_button_pulse(button):
	while true:
		await get_tree().create_timer(randf_range(2.0, 5.0)).timeout
		var t = create_tween()
		t.set_parallel(true)
		t.tween_property(button, "scale", Vector2(1.2, 1.2), 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t.tween_property(button, "scale", Vector2.ONE, 0.3).set_delay(0.15).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func get_score_world_position() -> Vector2:
	if not is_instance_valid(score_label):
		return Vector2.ZERO
	return score_label.global_position + score_label.size / 2.0
