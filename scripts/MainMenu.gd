extends Control

@onready var play_button: Button = $UILayer/PlayButton
@onready var skin_button: Button = $UILayer/SkinButton
@onready var fruit_container = $MenuAnimation/FruitContainer
@onready var left_spawn = $MenuAnimation/LeftSpawn
@onready var right_spawn = $MenuAnimation/RightSpawn
@onready var camera: Camera2D = $Camera2D
@onready var title: TextureRect = $UILayer/TitleLogo
@onready var canvas_mod = $CanvasModulate
@onready var background: Control = $BackLayer/Background

@onready var sfx_menu_merge: AudioStreamPlayer = $SFX_MenuMerge
@onready var sfx_menu_reveal: AudioStreamPlayer = $SFX_MenuReveal
@onready var sfx_btn_click: AudioStreamPlayer = $SFX_BtnClick
@onready var sfx_btn_appear: AudioStreamPlayer = $SFX_BtnAppear
@onready var sfx_fruit_drop: AudioStreamPlayer = $SFX_FruitDrop
@onready var sfx_fruit_land: AudioStreamPlayer = $SFX_FruitLand
@onready var music_player: AudioStreamPlayer = $Music_Menu

var _ring_tex: Texture2D = preload("res://assets/sprites/ring_poof.png")

var fruit_scene = preload("res://scenes/fruit/Fruit.tscn")
var intro_finished := false
var fruit_data_list = []
var shake_strength := 0.0
var idle_time := 0.0
var merged_fruit = null

var _title_base_y: float = 0.0
var _skin_base_x: float = 0.0
var _merged_fruit_landed := false
var _merged_fruit_prev_vel_y := 0.0

func _get_tier_color(tier: int) -> Color:
	match tier:
		1: return Color(0.906, 0.173, 0.278, 1.0)   # Cherry red
		2: return Color(0.898, 0.224, 0.275, 1.0)   # Strawberry pink
		3: return Color(0.416, 0.173, 0.627, 1.0)   # Grape purple
		4: return Color(0.961, 0.486, 0.082, 1.0)   # Orange
		5: return Color(0.635, 0.867, 0.267, 1.0)   # Apple green
		6: return Color(0.804, 0.745, 0.341, 1.0)   # Pear yellow-green
		7: return Color(0.898, 0.525, 0.365, 1.0)   # Peach
		8: return Color(0.961, 0.82, 0.384, 1.0)   # Pineapple yellow
		9: return Color(0.894, 0.694, 0.471, 1.0)   # Melon light green
		10: return Color(0.224, 0.71, 0.29, 1.0)  # Watermelon dark green
		11: return Color(0.471, 0.294, 0.184, 1.0) #Coconut
		12: return Color(0.863, 0.796, 0.259, 1.0) #Durian
		13: return Color(0.659, 0.831, 0.259, 1.0) #Jackfruit
		14: return Color(0.961, 0.518, 0.122, 1.0) #Pumpkin
		15: return Color(0.855, 0.224, 0.471, 1.0) #Dragonfruit
		_: return Color(1.0, 1.0, 1.0)
		
func _process(delta):
	_update_shake(delta)
	_update_idle(delta)

	if intro_finished:
		return
	if fruit_container.get_child_count() < 2:
		return

	var a = fruit_container.get_child(0)
	var b = fruit_container.get_child(1)

	if not is_instance_valid(a) or not is_instance_valid(b):
		return

	var merge_distance = (a.fruit_data.radius + b.fruit_data.radius) * 1.05

	if a.global_position.distance_to(b.global_position) < merge_distance:
		intro_finished = true
		fake_merge(a, b)

func _update_shake(delta):
	if shake_strength > 0:
		shake_strength = lerp(shake_strength, 0.0, 8.0 * delta)
		camera.offset = Vector2(
			randf_range(-shake_strength, shake_strength),
			randf_range(-shake_strength, shake_strength)
		)
	else:
		camera.offset = Vector2.ZERO

func _update_idle(delta):
	if not intro_finished:
		return
	idle_time += delta

	# Detect merged fruit landing impact
	if not _merged_fruit_landed and is_instance_valid(merged_fruit):
		var current_vel_y = merged_fruit.linear_velocity.y
		var impact = _merged_fruit_prev_vel_y - current_vel_y
		if impact > 150 and _merged_fruit_prev_vel_y > 0:
			_merged_fruit_landed = true
			sfx_fruit_land.pitch_scale = randf_range(0.9, 1.1)
			sfx_fruit_land.play()
		_merged_fruit_prev_vel_y = current_vel_y
		
func _ready():
	play_button.disabled = true
	skin_button.disabled = true
	canvas_mod.color = Color(0, 0, 0, 1)
	background.hide_all()
	title.modulate.a = 0.0
	play_button.modulate.a = 0.0
	skin_button.modulate.a = 0.0
	_setup_button_hover(play_button)
	_setup_button_hover(skin_button)
	play_button.pressed.connect(_on_play_pressed)
	skin_button.pressed.connect(_on_skin_pressed)
	_load_fruit_data()
	skin_button.position.x = _skin_base_x
	start_menu_animation()
	await get_tree().process_frame
	await get_tree().process_frame
	_center_title()
	_title_base_y = title.position.y
	_skin_base_x = skin_button.position.x
	
func _on_play_pressed():
	sfx_btn_click.pitch_scale = 1.05
	sfx_btn_click.play()
	var t = create_tween()
	t.tween_property(play_button, "scale", Vector2(0.92, 0.92), 0.05)
	t.tween_property(play_button, "scale", Vector2(1.08, 1.08), 0.10)
	t.tween_property(play_button, "scale", Vector2.ONE, 0.15)

	var music_out = create_tween()
	music_out.tween_property(music_player, "volume_db", -80.0, 0.5)

	await t.finished
	SceneTransition.change_scene("res://scenes/game/Game.tscn")
	
func _on_skin_pressed():
	sfx_btn_click.pitch_scale = 1.0
	sfx_btn_click.play()
	SceneTransition.change_scene("res://scenes/ui/SkinSelect.tscn")

func _load_fruit_data():
	var data_path = "res://assets/data/"
	var names = [
	"cherry", "strawberry", "grape", "orange", "apple",
	"pear", "peach", "pineapple", "melon", "watermelon",
	"coconut", "durian", "jackfruit", "pumpkin", "dragonfruit"
]
	for n in names:
		var res = load(data_path + n + ".tres")
		if res:
			fruit_data_list.append(res)

var _animation_started := false

func start_menu_animation():
	if _animation_started:
		return
	_animation_started = true
	_merged_fruit_landed = false
	_merged_fruit_prev_vel_y = 0.0
	await get_tree().create_timer(0.7).timeout
	spawn_intro_pair()

func spawn_intro_pair():
	intro_finished = false  # allow merge detection
	var tier = randi_range(4, 10)
	var left_fruit = fruit_scene.instantiate()
	var right_fruit = fruit_scene.instantiate()
	fruit_container.add_child(left_fruit)
	fruit_container.add_child(right_fruit)
	left_fruit.is_menu_fruit = true
	right_fruit.is_menu_fruit = true
	left_fruit.setup(fruit_data_list[tier - 1])
	right_fruit.setup(fruit_data_list[tier - 1])
	left_fruit.global_position = left_spawn.global_position
	right_fruit.global_position = right_spawn.global_position
	left_fruit.freeze = false
	right_fruit.freeze = false
	left_fruit.set_glow(true, 2.0)
	right_fruit.set_glow(true, 2.0)
	left_fruit.linear_velocity = Vector2(700, -850)
	right_fruit.linear_velocity = Vector2(-700, -850)

	# Whoosh sounds as both fruits fly in
	# Slight pitch difference so they don't sound identical
	sfx_fruit_drop.pitch_scale = 1.05
	sfx_fruit_drop.play()
	await get_tree().create_timer(0.06).timeout
	sfx_fruit_drop.pitch_scale = 0.97
	sfx_fruit_drop.play()
	var new_ang_vel = randi_range(8, 15)
	left_fruit.angular_velocity = new_ang_vel
	right_fruit.angular_velocity = -new_ang_vel
	left_fruit.set_meta("menu_tier", tier)
	right_fruit.set_meta("menu_tier", tier)

func fake_merge(a, b):
	var merge_pos = (a.global_position + b.global_position) / 2.0
	var tier = a.get_meta("menu_tier")

	Engine.time_scale = 0.04
	await get_tree().create_timer(0.06, true, false, true).timeout
	Engine.time_scale = 1.0
	sfx_menu_merge.pitch_scale = randf_range(0.97, 1.03)
	sfx_menu_merge.play()
	shake_strength = 25.0
	Input.vibrate_handheld(150)

	# White flash
	var flash = ColorRect.new()
	add_child(flash)
	flash.z_index = 100
	flash.color = Color(1, 1, 1, 0.9)
	flash.size = Vector2(10800, 19200)
	flash.position = Vector2(-5400, -9600)
	var flash_tween = create_tween()
	flash_tween.tween_property(flash, "modulate:a", 0.0, 0.2)
	flash_tween.tween_callback(flash.queue_free)

	# Reveal world via background
	sfx_menu_reveal.play()
	background.reveal(canvas_mod, 1.2)
	
	# Start menu ambience, fading in under the reveal
	music_player.volume_db = -80.0
	music_player.play()
	var music_tween = create_tween()
	music_tween.tween_property(music_player, "volume_db", -6.0, 1.5)

	# Particles
	_spawn_merge_burst(merge_pos, tier)

	# Bulb swing via background
	background.swing_bulb()

	a.queue_free()
	b.queue_free()

	# Spawn merged fruit
	var next_tier = min(tier + 1, fruit_data_list.size())
	var new_fruit = fruit_scene.instantiate()
	new_fruit.freeze = false
	new_fruit.sleeping = false
	fruit_container.add_child(new_fruit)
	new_fruit.is_menu_fruit = true
	new_fruit.setup(fruit_data_list[next_tier - 1])
	new_fruit.global_position = merge_pos
	new_fruit.set_glow(true, 0.3)
	var lin_vel = randi_range(200, 500)
	new_fruit.linear_velocity = Vector2(0, -lin_vel)
	new_fruit.angular_velocity = randi_range(5, 15)
	merged_fruit = new_fruit
	_watch_fruit_settle(new_fruit)  # fire-and-forget: runs alongside the UI reveal, not before it

	title.pivot_offset = title.size / 2.0
	title.scale = Vector2(1.15, 0.9)
	var title_tween = create_tween()
	title_tween.tween_property(title, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_ELASTIC)

	await get_tree().create_timer(0.3).timeout
	_reveal_ui()
	_start_button_pulse()
	_start_idle_animations()

func _watch_fruit_settle(fruit):
	while is_instance_valid(fruit):
		if fruit.sleeping:
			break
		await get_tree().create_timer(0.05).timeout

	if !is_instance_valid(fruit):
		return

	var fruit_y = fruit.global_position.y

	var idle = create_tween()
	idle.set_loops()
	idle.tween_property(
		fruit,
		"global_position:y",
		fruit_y - 15,
		1.6
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	idle.tween_property(
		fruit,
		"global_position:y",
		fruit_y,
		1.6
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
		
func _spawn_merge_burst(pos: Vector2, tier: int):
	for i in 3:
		var ring = Sprite2D.new()
		add_child(ring)
		ring.global_position = pos
		ring.texture = _ring_tex
		ring.modulate = _get_tier_color(tier)
		ring.scale = Vector2(0.2, 0.2)

		var delay = i * 0.09
		var rt = create_tween()
		rt.set_parallel(true)
		rt.tween_property(ring, "scale", Vector2(3.0,3.0), 0.55).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		rt.tween_property(ring, "modulate:a", 0.0, 0.5).set_delay(delay).set_ease(Tween.EASE_IN)
		rt.tween_callback(ring.queue_free).set_delay(delay + 0.6)

	# Sparkle burst — 10 sparkles radiating outward
	var sparkle_tex = preload("res://assets/sprites/sparkle.png")
	var spark_colors = [
		Color(1.0, 0.85, 0.2),
		Color(1.0, 0.4, 0.2),
		Color(0.4, 0.9, 0.3),
		Color(1.0, 0.5, 0.8),
		Color(0.5, 0.8, 1.0),
	]
	for i in 10:
		var spark = Sprite2D.new()
		add_child(spark)
		spark.texture = sparkle_tex
		spark.z_index = 55
		spark.global_position = pos
		spark.modulate = spark_colors[i % spark_colors.size()]
		spark.scale = Vector2(0.8, 0.8)

		var angle = (TAU / 10.0) * i + randf() * 0.4
		var dist = randf_range(140.0, 260.0)
		var target = pos + Vector2(cos(angle), sin(angle)) * dist

		var st = create_tween()
		st.set_parallel(true)
		st.tween_property(spark, "global_position", target, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		st.tween_property(spark, "scale", Vector2(1.6, 1.6), 0.2)
		st.tween_property(spark, "scale", Vector2(0.0, 0.0), 0.35).set_delay(0.2)
		st.tween_property(spark, "modulate:a", 0.0, 0.35).set_delay(0.25)
		st.tween_callback(spark.queue_free).set_delay(0.65)

	# Tier-colored poof particles
	var particles = CPUParticles2D.new()
	add_child(particles)
	particles.global_position = pos
	particles.z_index = 50
	#particles.texture = preload("res://assets/sprites/poof.png")
	particles.emitting = true
	particles.amount = 24
	particles.lifetime = 0.9
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.spread = 180.0
	particles.direction = Vector2(0, -1)
	particles.initial_velocity_min = 200.0
	particles.initial_velocity_max = 480.0
	particles.scale_amount_min = 3.0
	particles.scale_amount_max = 7.0
	particles.gravity = Vector2(0, 300)
	particles.color = Color(1.0, 0.85, 0.2, 1.0)
	particles.finished.connect(particles.queue_free)
	
func _reveal_ui():
	await get_tree().process_frame
	play_button.pivot_offset = play_button.size / 2.0
	skin_button.pivot_offset = skin_button.size / 2.0
	title.pivot_offset = title.size / 2.0

	# Reset all to hidden
	title.modulate.a = 0.0
	play_button.modulate.a = 0.0
	skin_button.modulate.a = 0.0

	# Re-center horizontally right before the reveal — guarantees correct
	# position regardless of the device's screen width/aspect ratio
	_center_title()

	# Title drops in from above
	var title_start_y = title.position.y - 80.0
	title.position.y = title_start_y
	title.scale = Vector2(0.7, 0.7)
	
	sfx_btn_appear.pitch_scale = 0.9
	sfx_btn_appear.play()
	var title_in = create_tween()
	title_in.set_parallel(true)
	title_in.tween_property(title, "modulate:a", 1.0, 0.3).set_ease(Tween.EASE_OUT)
	title_in.tween_property(title, "position:y", title_start_y + 80.0, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	title_in.tween_property(title, "scale", Vector2(1.1, 1.1), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await title_in.finished

	# Settle to natural scale
	var title_settle = create_tween()
	title_settle.tween_property(title, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	await title_settle.finished

	# Spawn title arrival sparkles
	_spawn_title_sparkles()

	await get_tree().create_timer(0.15).timeout

	# Play button bounces in
	sfx_btn_appear.pitch_scale = 1.0
	sfx_btn_appear.play()
	play_button.scale = Vector2(0.0, 0.0)
	var pb_in = create_tween()
	pb_in.set_parallel(true)
	pb_in.tween_property(play_button, "modulate:a", 1.0, 0.2)
	pb_in.tween_property(play_button, "scale", Vector2(1.15, 1.15), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await pb_in.finished
	var pb_settle = create_tween()
	pb_settle.tween_property(play_button, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	await pb_settle.finished

	await get_tree().create_timer(0.08).timeout

	# Skin button slides in from right
	sfx_btn_appear.pitch_scale = 1.05
	sfx_btn_appear.play()
	var skin_target_x = skin_button.position.x
	skin_button.position.x = skin_target_x + 60.0
	var sb_in = create_tween()
	sb_in.set_parallel(true)
	sb_in.tween_property(skin_button, "modulate:a", 1.0, 0.25)
	sb_in.tween_property(skin_button, "position:x", skin_target_x, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await sb_in.finished

	play_button.disabled = false
	skin_button.disabled = false

func _start_idle_animations():
	var bulb = background.get_bulb()
	var bulb_idle = create_tween()
	bulb_idle.set_loops()
	bulb_idle.tween_property(bulb, "rotation_degrees", 5.0, 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bulb_idle.tween_property(bulb, "rotation_degrees", -5.0, 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Snapshot settled position AFTER reveal animations finish
	var settled_y = title.position.y
	var title_idle = create_tween()
	title_idle.set_loops()
	title_idle.tween_property(title, "position:y", settled_y - 10.0, 2.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	title_idle.tween_property(title, "position:y", settled_y, 2.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Skin button gentle breathe (play button has its own random pulse already)
	var skin_breathe = create_tween()
	skin_breathe.set_loops()
	skin_breathe.tween_property(skin_button, "scale", Vector2(1.05, 1.05), 2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	skin_breathe.tween_property(skin_button, "scale", Vector2.ONE, 2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
func _start_button_pulse():
	while true:
		await get_tree().create_timer(randf_range(2.0, 5.0)).timeout
		if not is_instance_valid(play_button):
			break
		var t = create_tween()
		t.set_parallel(true)
		t.tween_property(play_button, "scale", Vector2(1.2, 1.2), 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t.tween_property(play_button, "scale", Vector2.ONE, 0.3).set_delay(0.15).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func _setup_button_hover(btn: Button):
	btn.mouse_entered.connect(func():
		var t = create_tween()
		t.tween_property(btn, "scale", Vector2(1.12, 1.12), 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		btn.pivot_offset = btn.size / 2.0
	)
	btn.mouse_exited.connect(func():
		var t = create_tween()
		t.tween_property(btn, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	)
	
func _spawn_title_sparkles():
	var sparkle_tex = preload("res://assets/sprites/sparkle.png")
	var title_center = title.global_position + title.size / 2.0
	var colors = [
		Color(1.0, 0.85, 0.2),
		Color(1.0, 0.4, 0.2),
		Color(0.4, 0.9, 0.3),
		Color(1.0, 0.5, 0.8),
		Color(0.5, 0.8, 1.0),
	]

	for i in 8:
		var spark = Sprite2D.new()
		add_child(spark)
		spark.texture = sparkle_tex
		spark.z_index = 200
		# Distribute along the width of the title
		var spread_x = randf_range(-title.size.x * 0.4, title.size.x * 0.4)
		spark.global_position = title_center + Vector2(spread_x, randf_range(-20, 20))
		spark.modulate = colors[i % colors.size()]
		spark.scale = Vector2(0.5, 0.5)

		var angle = randf() * TAU
		var dist = randf_range(60.0, 140.0)
		var target = spark.global_position + Vector2(cos(angle), sin(angle)) * dist

		var t = create_tween()
		t.set_parallel(true)
		t.tween_property(spark, "global_position", target, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t.tween_property(spark, "scale", Vector2(1.2, 1.2), 0.2)
		t.tween_property(spark, "scale", Vector2(0.0, 0.0), 0.3).set_delay(0.2)
		t.tween_property(spark, "modulate:a", 0.0, 0.3).set_delay(0.25)
		t.tween_callback(spark.queue_free).set_delay(0.6)

func _center_title():
	var viewport_size = get_viewport_rect().size
	title.position.x = (viewport_size.x - title.size.x) / 2.0
