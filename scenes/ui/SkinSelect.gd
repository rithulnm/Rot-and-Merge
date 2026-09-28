extends Control

@onready var nectar_label: Label = $Root/NectarPanel/NectarHBox/NectarLabel
@onready var nectar_icon: TextureRect = $Root/NectarPanel/NectarHBox/NectarIcon
@onready var back_button: Button = $Root/BackButton
@onready var preview_image: TextureRect = $Root/VBoxContainer/MainCard/PreviewImage
@onready var name_label: Label = $Root/VBoxContainer/MainCard/PreviewImage/NameBanner/NameLabel
@onready var left_arrow: Button = $Root/LeftArrow
@onready var right_arrow: Button = $Root/RightArrow
@onready var cost_row: HBoxContainer = $Root/VBoxContainer/PanelContainer/CostRow
@onready var cost_label: Label = $Root/VBoxContainer/PanelContainer/CostRow/CostLabel
@onready var action_button: Button = $Root/VBoxContainer/ActionButton
@onready var main_card: PanelContainer = $Root/VBoxContainer/MainCard
@onready var bg: TextureRect = $Root/BgTexture
@onready var panel: PanelContainer = $Root/VBoxContainer/PanelContainer
@onready var gold_glow: TextureRect = $Root/VBoxContainer/MainCard/GoldGlow
@onready var shine: TextureRect = $Root/VBoxContainer/MainCard/PreviewImage/Shine
@onready var root_node: Control = $Root
@onready var nectar_panel: PanelContainer = $Root/NectarPanel
@onready var name_banner = $Root/VBoxContainer/MainCard/PreviewImage/NameBanner
@onready var title_image: Label = $Root/TitleLabel
@onready var bulb_sprite = $Root/BulbSprite

@onready var sfx_btn_click: AudioStreamPlayer = $SFX_BtnClick
@onready var music_player: AudioStreamPlayer = $Music_Skin
@onready var sfx_unlock: AudioStreamPlayer = $SFX_Unlock
@onready var sfx_denied: AudioStreamPlayer = $SFX_Denied

var shine_tween: Tween
var glow_tween: Tween
var arrow_tween_left: Tween
var arrow_tween_right: Tween
var ken_burns_tween: Tween
var ambient_tween: Tween
var is_exiting := false

const SKIN_NAMES = ["Warm Kitchen", "Tea House", "Rainy Cafe", "Witch Room", "Autumn Day"]
const SKIN_COSTS = [0, 3, 5, 15, 30]
const SKIN_PATHS = [
	"res://assets/data/skins/skin_kitchen.tres",
	"res://assets/data/skins/skin_rooftop.tres",
	"res://assets/data/skins/skin_bedroom.tres",
	"res://assets/data/skins/skin_forest.tres",
    "res://assets/data/skins/skin_cafe.tres"
]

var current_index: int = 0
var is_animating: bool = false
var displayed_nectar := 0

const selected = preload("res://assets/sprites/icons/selected_btn.png")
const select = preload("res://assets/sprites/icons/select_btn.png")
const locked = preload("res://assets/sprites/icons/lock_btn.png")

const RibbonScene = preload("res://scenes/decore/Ribbons.tscn")
const ConfettiScene = preload("res://scenes/decore/Confetti.tscn")

const RIBBONS = [
	preload("res://assets/sprites/decore/ribbon1.png"),
	preload("res://assets/sprites/decore/ribbon2.png"),
	preload("res://assets/sprites/decore/ribbon3.png"),
	preload("res://assets/sprites/decore/ribbon4.png")
]

const CONFETTI = [
	preload("res://assets/sprites/decore/confetti1.png"),
	preload("res://assets/sprites/decore/confetti2.png"),
	preload("res://assets/sprites/decore/confetti3.png"),
]

func _ready():
	current_index = GameManager.current_skin
	back_button.pressed.connect(_on_back_pressed)
	left_arrow.pressed.connect(_on_left_pressed)
	right_arrow.pressed.connect(_on_right_pressed)
	action_button.pressed.connect(_on_action_pressed)
	nectar_label.text = str(GameManager.keys)
	GameManager.keys_changed.connect(func(_k): _refresh_nectar())
	displayed_nectar = GameManager.keys
	
	# Start hidden for entrance
	root_node.modulate.a = 0.0
	root_node.scale = Vector2(0.96, 0.96)
	main_card.position.y += 60
	nectar_panel.modulate.a = 0.0
	back_button.modulate.a = 0.0
	left_arrow.modulate.a = 0.0
	right_arrow.modulate.a = 0.0
	title_image.modulate.a = 0.0
	title_image.pivot_offset = title_image.size / 2.0

	_refresh_ui(false)
	_play_entrance()
	
	music_player.volume_db = -80.0
	music_player.play()
	var music_tween = create_tween()
	music_tween.tween_property(music_player, "volume_db", -6.0, 1.5)
	
	_start_arrow_pulse()
	_delayed_start_sparkles()
	_start_bulb_idle()
	
func _delayed_start_sparkles():
	await get_tree().create_timer(0.5).timeout
	_start_ambient_sparkles()

# ─────────────────────────────────────────────
# ENTRANCE
# ─────────────────────────────────────────────

func _play_entrance():
	await get_tree().process_frame
	_center_title()

	# Background fade
	var bg_t = create_tween()
	bg_t.tween_property(root_node, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	bg_t.parallel().tween_property(root_node, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Title drops in first, sets the "screen has a name" beat before anything else
	title_image.scale = Vector2(0.7, 0.7)
	var title_start_y = title_image.position.y - 40.0
	title_image.position.y = title_start_y
	var title_t = create_tween()
	title_t.set_parallel(true)
	title_t.tween_property(title_image, "modulate:a", 1.0, 0.25)
	title_t.tween_property(title_image, "position:y", title_start_y + 40.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	title_t.tween_property(title_image, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Card slides up
	await get_tree().create_timer(0.1).timeout
	var card_t = create_tween()
	card_t.tween_property(main_card, "position:y", main_card.position.y - 60, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# UI elements stagger in
	await get_tree().create_timer(0.15).timeout
	var ui_t = create_tween()
	ui_t.set_parallel(true)
	ui_t.tween_property(nectar_panel, "modulate:a", 1.0, 0.3)
	ui_t.tween_property(back_button, "modulate:a", 1.0, 0.3).set_delay(0.05)
	ui_t.tween_property(left_arrow, "modulate:a", 1.0, 0.3).set_delay(0.1)
	ui_t.tween_property(right_arrow, "modulate:a", 1.0, 0.3).set_delay(0.1)

# ─────────────────────────────────────────────
# EXIT
# ─────────────────────────────────────────────

func _play_exit(target_scene: String):
	if is_exiting:
		return
	is_exiting = true

	var overlay = ColorRect.new()
	add_child(overlay)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.1, 0.08, 0.05, 0.0)
	overlay.z_index = 9999
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var t = create_tween()
	t.tween_property(overlay, "color:a", 1.0, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await t.finished
	SceneTransition.change_scene(target_scene)
	
# ─────────────────────────────────────────────
# NAVIGATION
# ─────────────────────────────────────────────

func _on_left_pressed():
	sfx_btn_click.pitch_scale = 1.0
	sfx_btn_click.play()
	bounce_button(left_arrow)
	if is_animating or current_index <= 0:
		return
	current_index -= 1
	_slide_preview(-1)

func _on_right_pressed():
	sfx_btn_click.pitch_scale = 1.0
	sfx_btn_click.play()
	bounce_button(right_arrow)
	if is_animating or current_index >= SKIN_NAMES.size() - 1:
		return
	current_index += 1
	_slide_preview(1)

func _slide_preview(direction: int):
	is_animating = true
	var original_x = main_card.position.x

	# Slight tilt while sliding out
	var out_t = create_tween()
	out_t.set_parallel(true)
	out_t.tween_property(main_card, "position:x", original_x - direction * 700, 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	out_t.tween_property(main_card, "modulate:a", 0.0, 0.16)
	out_t.tween_property(main_card, "rotation_degrees", direction * -5.0, 0.16)
	await out_t.finished

	_refresh_ui(false)

	main_card.position.x = original_x + direction * 700
	main_card.modulate.a = 0.0
	main_card.rotation_degrees = direction * 5.0

	var in_t = create_tween()
	in_t.set_parallel(true)
	in_t.tween_property(main_card, "position:x", original_x, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	in_t.tween_property(main_card, "modulate:a", 1.0, 0.22)
	in_t.tween_property(main_card, "rotation_degrees", 0.0, 0.22).set_trans(Tween.TRANS_ELASTIC)
	await in_t.finished

	# Name label pop after card arrives
	_pop_name_label()

	is_animating = false

# ─────────────────────────────────────────────
# UI REFRESH
# ─────────────────────────────────────────────

func _refresh_ui(_animate_in: bool):
	_refresh_nectar()

	var skin_res = load(SKIN_PATHS[current_index])
	if skin_res:
		preview_image.texture = skin_res.preview_texture
	else:
		preview_image.texture = null

	name_label.text = SKIN_NAMES[current_index]

	var cost = SKIN_COSTS[current_index]
	var is_unlocked = GameManager.unlocked_skins[current_index]
	var is_selected = GameManager.current_skin == current_index
	var can_afford = GameManager.keys >= cost

	if is_unlocked:
		cost_row.visible = false
	else:
		cost_row.visible = true
		cost_label.text = "Cost : " + str(cost)

	action_button.text = ""
	action_button.icon = null

	if is_selected:
		start_shine()
		start_selected_glow()
		_start_ken_burns()
		panel.visible = false
		action_button.icon = selected
		action_button.disabled = true
		action_button.modulate = Color.WHITE
	elif is_unlocked:
		start_shine()
		stop_selected_glow()
		_start_ken_burns()
		panel.visible = false
		action_button.icon = select
		action_button.disabled = false
		action_button.modulate = Color.WHITE
	elif can_afford:
		stop_shine()
		stop_selected_glow()
		_stop_ken_burns()
		panel.visible = true
		action_button.icon = locked
		action_button.disabled = false
		action_button.modulate = Color.WHITE
	else:
		stop_shine()
		stop_selected_glow()
		_stop_ken_burns()
		panel.visible = true
		action_button.icon = locked
		action_button.disabled = true
		action_button.modulate = Color(0.5, 0.5, 0.5)

	left_arrow.visible = current_index > 0
	right_arrow.visible = current_index < SKIN_NAMES.size() - 1

# ─────────────────────────────────────────────
# NAME LABEL POP
# ─────────────────────────────────────────────

func _pop_name_label():
	name_label.scale = Vector2(0.8, 0.8)
	name_label.modulate.a = 0.0
	var t = create_tween()
	t.set_parallel(true)
	t.tween_property(name_label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(name_label, "modulate:a", 1.0, 0.2)

func _center_title():
	var viewport_size = get_viewport_rect().size
	title_image.position.x = (viewport_size.x - title_image.size.x) / 2.0
# ─────────────────────────────────────────────
# KEN BURNS (subtle preview zoom)
# ─────────────────────────────────────────────

func _start_ken_burns():
	if ken_burns_tween:
		ken_burns_tween.kill()
	preview_image.scale = Vector2.ONE
	ken_burns_tween = create_tween()
	ken_burns_tween.set_loops()
	ken_burns_tween.tween_property(preview_image, "scale", Vector2(1.06, 1.06), 6.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	ken_burns_tween.tween_property(preview_image, "scale", Vector2.ONE, 6.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _stop_ken_burns():
	if ken_burns_tween:
		ken_burns_tween.kill()
	preview_image.scale = Vector2.ONE

# ─────────────────────────────────────────────
# AMBIENT SPARKLES
# ─────────────────────────────────────────────

func _start_ambient_sparkles():
	while not is_exiting:
		await get_tree().create_timer(randf_range(0.6, 1.4)).timeout
		if not is_inside_tree():
			break
		_spawn_ambient_sparkle()

func _spawn_ambient_sparkle():
	var sparkle = Sprite2D.new()
	root_node.add_child(sparkle)
	sparkle.texture = preload("res://assets/sprites/sparkle.png")

	var card_pos = main_card.global_position
	sparkle.global_position = card_pos + Vector2(
		randf_range(0, main_card.size.x),
		randf_range(0, main_card.size.y)
	)

	var size = randf_range(0.06, 0.18)
	sparkle.scale = Vector2(size, size)
	sparkle.modulate.a = 0.0
	sparkle.z_index = 10

	var t = create_tween()
	t.set_parallel(true)
	t.tween_property(sparkle, "modulate:a", 0.9, 0.25)
	t.tween_property(sparkle, "global_position", sparkle.global_position + Vector2(randf_range(-30, 30), randf_range(-60, -20)), 0.7).set_trans(Tween.TRANS_SINE)
	t.tween_property(sparkle, "scale", Vector2(size * 1.5, size * 1.5), 0.35)
	await get_tree().create_timer(0.3).timeout
	var t2 = create_tween()
	t2.set_parallel(true)
	t2.tween_property(sparkle, "modulate:a", 0.0, 0.35)
	t2.tween_property(sparkle, "scale", Vector2.ZERO, 0.35)
	t2.tween_callback(sparkle.queue_free).set_delay(0.35)

# ─────────────────────────────────────────────
# ARROW PULSE
# ─────────────────────────────────────────────

func _start_arrow_pulse():
	if arrow_tween_left:
		arrow_tween_left.kill()
	if arrow_tween_right:
		arrow_tween_right.kill()

	arrow_tween_left = create_tween()
	arrow_tween_left.set_loops()
	arrow_tween_left.tween_property(left_arrow, "scale", Vector2(1.1, 1.1), 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	arrow_tween_left.tween_property(left_arrow, "scale", Vector2.ONE, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	arrow_tween_right = create_tween()
	arrow_tween_right.set_loops()
	# Offset so they don't pulse in sync
	arrow_tween_right.tween_interval(0.4)
	arrow_tween_right.tween_property(right_arrow, "scale", Vector2(1.1, 1.1), 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	arrow_tween_right.tween_property(right_arrow, "scale", Vector2.ONE, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Fix pivot
	left_arrow.pivot_offset = left_arrow.size / 2.0
	right_arrow.pivot_offset = right_arrow.size / 2.0
	main_card.pivot_offset = main_card.size / 2.0
	preview_image.pivot_offset = preview_image.size / 2.0

func _start_bulb_idle():
	if not bulb_sprite:
		return
	var bulb_idle = create_tween()
	bulb_idle.set_loops()
	bulb_idle.tween_property(bulb_sprite, "rotation_degrees", 4.0, 2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bulb_idle.tween_property(bulb_sprite, "rotation_degrees", -4.0, 2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
# ─────────────────────────────────────────────
# NECTAR
# ─────────────────────────────────────────────

func _refresh_nectar():
	var target = GameManager.keys
	if displayed_nectar != target:
		animate_nectar(target)

func animate_nectar(target: int):
	while displayed_nectar != target:
		if displayed_nectar < target:
			displayed_nectar += 1
		else:
			displayed_nectar -= 1
		nectar_label.text = str(displayed_nectar)
		# Bounce nectar icon each tick
		nectar_icon.pivot_offset = nectar_icon.size / 2.0
		var t = create_tween()
		t.tween_property(nectar_icon, "scale", Vector2(1.3, 1.3), 0.05)
		t.tween_property(nectar_icon, "scale", Vector2.ONE, 0.08).set_trans(Tween.TRANS_ELASTIC)
		await get_tree().create_timer(0.03).timeout

# ─────────────────────────────────────────────
# ACTION
# ─────────────────────────────────────────────

func _on_action_pressed():
	bounce_button(action_button)
	var is_unlocked = GameManager.unlocked_skins[current_index]
	if is_unlocked:
		sfx_btn_click.pitch_scale = 1.0
		sfx_btn_click.play()
		GameManager.select_skin(current_index)
		_refresh_ui(false)
		_play_select_pop()

		# Give the player a beat to see the selection pop/animation,
		# then redirect back into the game with the new skin applied.
		await get_tree().create_timer(0.4).timeout
		var music_out = create_tween()
		music_out.tween_property(music_player, "volume_db", -80.0, 0.5)
		_play_exit("res://scenes/game/Game.tscn")
	else:
		if GameManager.unlock_skin(current_index):
			sfx_unlock.pitch_scale = 1.0
			sfx_unlock.play()
			Input.vibrate_handheld(120)
			_play_unlock_flash()
			await get_tree().create_timer(0.2).timeout
			_refresh_ui(false)
		else:
			sfx_denied.pitch_scale = 1.0
			sfx_denied.play()
			_play_cant_afford()

func _play_select_pop():
	var t = create_tween()
	t.tween_property(main_card, "scale", Vector2(1.05, 1.05), 0.08).set_trans(Tween.TRANS_CUBIC)
	t.tween_property(main_card, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_ELASTIC)
	# Name pop too
	_pop_name_label()

func _play_unlock_flash():
	Engine.time_scale = 0.15
	await get_tree().create_timer(0.05, true).timeout
	Engine.time_scale = 1.0

	_spawn_screen_flash()

	var t = create_tween()
	t.tween_property(main_card, "modulate", Color(2, 2, 1.5), 0.08)
	t.tween_property(main_card, "modulate", Color.WHITE, 0.25)
	
	var pop = create_tween()
	pop.tween_property(main_card, "scale", Vector2(1.08, 1.08), 0.10)
	pop.tween_property(main_card, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_ELASTIC)

	spawn_ribbon_burst()
	spawn_confetti()
	await get_tree().create_timer(0.08).timeout
	spawn_ribbon_burst()
	spawn_confetti()

func _play_cant_afford():
	# Shake action button horizontally
	var original_x = action_button.position.x
	var t = create_tween()
	t.tween_property(action_button, "position:x", original_x + 12, 0.05)
	t.tween_property(action_button, "position:x", original_x - 12, 0.05)
	t.tween_property(action_button, "position:x", original_x + 8, 0.04)
	t.tween_property(action_button, "position:x", original_x - 8, 0.04)
	t.tween_property(action_button, "position:x", original_x, 0.04)
	# Flash red
	var t2 = create_tween()
	t2.tween_property(action_button, "modulate", Color(1, 0.2, 0.2), 0.08)
	t2.tween_property(action_button, "modulate", Color(0.5, 0.5, 0.5), 0.25)
	# Shake cost label too
	if cost_label.visible:
		var original_cost_x = cost_label.position.x
		var t3 = create_tween()
		t3.tween_property(cost_label, "position:x", original_cost_x + 8, 0.04)
		t3.tween_property(cost_label, "position:x", original_cost_x - 8, 0.04)
		t3.tween_property(cost_label, "position:x", original_cost_x, 0.04)

# ─────────────────────────────────────────────
# BACK
# ─────────────────────────────────────────────

func _on_back_pressed():
	sfx_btn_click.pitch_scale = 1.0
	sfx_btn_click.play()
	
	bounce_button(back_button)
	var music_out = create_tween()
	music_out.tween_property(music_player, "volume_db", -80.0, 0.5)
	_play_exit("res://scenes/game/Game.tscn")

# ─────────────────────────────────────────────
# HELPERS
# ─────────────────────────────────────────────

func bounce_button(btn: Button):
	btn.pivot_offset = btn.size / 2.0
	var t = create_tween()
	t.tween_property(btn, "scale", Vector2(0.82, 0.82), 0.06).set_trans(Tween.TRANS_CUBIC)
	t.tween_property(btn, "scale", Vector2(1.12, 1.12), 0.08).set_trans(Tween.TRANS_BACK)
	t.tween_property(btn, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_ELASTIC)

func start_selected_glow():
	if glow_tween:
		glow_tween.kill()
	gold_glow.visible = true
	gold_glow.modulate.a = 0.7
	glow_tween = create_tween()
	glow_tween.set_loops()
	glow_tween.tween_property(gold_glow, "modulate:a", 1.0, 1.0)
	glow_tween.tween_property(gold_glow, "modulate:a", 0.6, 1.0)

func stop_selected_glow():
	if glow_tween:
		glow_tween.kill()
	gold_glow.visible = false

func spawn_ribbon_burst():
	for i in 30:
		var ribbon = RibbonScene.instantiate()
		$Root/VBoxContainer/MainCard/UnlockFX.add_child(ribbon)
		ribbon.position = Vector2(main_card.size.x / 2, main_card.size.y / 2)
		var angle = randf_range(190, 350)
		var speed = randf_range(650, 1050)
		var velocity = Vector2.RIGHT.rotated(deg_to_rad(angle)) * speed
		ribbon.setup(RIBBONS.pick_random(), velocity)

func _spawn_screen_flash():
	var flash = ColorRect.new()
	root_node.add_child(flash)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(1, 1, 1, 0.55)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.z_index = 500
	var t = create_tween()
	t.tween_property(flash, "modulate:a", 0.0, 0.3).set_trans(Tween.TRANS_CUBIC)
	t.tween_callback(flash.queue_free)
	
func spawn_confetti():
	for i in 80:
		var piece = ConfettiScene.instantiate()
		$Root/VBoxContainer/MainCard/UnlockFX.add_child(piece)
		piece.position = Vector2(main_card.size.x / 2, main_card.size.y / 2)
		var angle = randf_range(0, 360)
		var speed = randf_range(250, 600)
		var velocity = Vector2.RIGHT.rotated(deg_to_rad(angle)) * speed
		piece.setup(CONFETTI.pick_random(), velocity)

func start_shine():
	if shine_tween:
		shine_tween.kill()
	shine.visible = true
	shine.position.x = -500
	shine.modulate.a = 0.0
	shine_tween = create_tween()
	shine_tween.set_loops()
	shine_tween.tween_interval(2.8)
	shine_tween.tween_property(shine, "modulate:a", 0.65, 0.15)
	shine_tween.parallel().tween_property(shine, "position:x", 700, 0.8)
	shine_tween.parallel().tween_property(shine, "modulate:a", 0.0, 0.4)
	shine_tween.tween_callback(func(): shine.position.x = -500)

func stop_shine():
	if shine_tween:
		shine_tween.kill()
	shine.visible = false
