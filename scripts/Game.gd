extends Node2D

signal board_state_changed


@onready var hud: CanvasLayer = $HUD
@onready var vignette: ColorRect = $UILayer/Vignette
@onready var fruit_container = $FruitContainer
@onready var drop_zone = $DropZone
@onready var drop_beam = $DropZone/DropBeam
@onready var death_line = $DeathLine
@onready var death_screen = $DeathScreen
@onready var camera = $Camera2D
@onready var beam_glow = $DropZone/BeamGlow
@onready var jar_sprite: Sprite2D = $Jar/JarSprite
@onready var select_mode_back: CanvasLayer = $SelectModeBack
@onready var select_mode_front: CanvasLayer = $SelectModeFront
@onready var background: Control = $BackLayer/Background
@onready var ui_layer: CanvasLayer = $UILayer
@onready var ad_popup: CanvasLayer = $AdPopup

var _danger_flicker_active := false
var highest_fruit_tier_this_run: int = 1
var vignette_base_color: Color
var combo_count: int = 0
var combo_timer: float = 0.0
var chain_count: int = 0
const COMBO_WINDOW: float = 2.0
var active_powerup_index: int = -1
var powerup_touch_active: bool = false
var touch_started_on_ui: bool = false
var beam_time: float = 0.0
var shake_amount: float = 0.0
var shake_decay: float = 5.0
var fruit_scene = preload("res://scenes/fruit/Fruit.tscn")

var fruit_data_list: Array = []
var current_fruit = null
var next_fruit_tier: int = 1
var can_drop: bool = false
var death_timer: float = 0.0
var fruits_above_death_line: Array = []
var drop_x: float = 0.0
var is_merging: bool = false
var touch_start_pos: Vector2 = Vector2.ZERO
var touch_dragged: bool = false
var dragging_drop := false
var _ring_tex: Texture2D = preload("res://assets/sprites/ring_poof.png")

# --- AUDIO ---
var _merge_pop_sfx = [
	preload("res://assets/audio/sfx/merge_pop_tier1.ogg"),
	preload("res://assets/audio/sfx/merge_pop_tier2.ogg"),
	preload("res://assets/audio/sfx/merge_pop_tier3.ogg"),
	preload("res://assets/audio/sfx/merge_pop_tier4.ogg"),
	preload("res://assets/audio/sfx/merge_pop_tier5.ogg"),
]

var _powerup_sfx = {
	1: preload("res://assets/audio/sfx/powerup_shake.ogg"),
	2: preload("res://assets/audio/sfx/powerup_pluck.ogg"),
	3: preload("res://assets/audio/sfx/powerup_cure.ogg"),
	4: preload("res://assets/audio/sfx/powerup_purge.ogg"),
	5: preload("res://assets/audio/sfx/powerup_bomb.ogg"),
	6: preload("res://assets/audio/sfx/powerup_refresh.ogg"),
	7: preload("res://assets/audio/sfx/powerup_ripple.ogg"),
}

@onready var sfx_merge_pop: AudioStreamPlayer = $SFX_MergePop
@onready var sfx_fruit_drop: AudioStreamPlayer = $SFX_FruitDrop
@onready var sfx_fruit_land: AudioStreamPlayer = $SFX_FruitLand
@onready var sfx_powerup_click: AudioStreamPlayer = $SFX_PowerupClick
@onready var sfx_powerup_specific: AudioStreamPlayer = $SFX_PowerupSpecific
@onready var sfx_select_merge_pop: AudioStreamPlayer = $SFX_SelectMergePop
@onready var sfx_pluck: AudioStreamPlayer = $SFX_Pluck
@onready var sfx_game_over: AudioStreamPlayer = $SFX_GameOver
@onready var sfx_milestone: AudioStreamPlayer = $SFX_Milestone
@onready var sfx_new_best: AudioStreamPlayer = $SFX_NewBest
@onready var music_player: AudioStreamPlayer = $Music_Game
@onready var sfx_key_earned: AudioStreamPlayer = $SFX_KeyEarned

var _milestone_sfx = preload("res://assets/audio/sfx/milestone.ogg")
var _new_best_sfx = preload("res://assets/audio/sfx/new_best.ogg")
var _tier_unlock_sfx = preload("res://assets/audio/sfx/unlock.ogg")

var reaction_popup_scene = preload(
"res://scenes/ui/ReactionPopup.tscn"
)

var reaction_textures = [
	preload("res://assets/sprites/reactions/sweet.png"),
	preload("res://assets/sprites/reactions/juicy.png"),
	preload("res://assets/sprites/reactions/nice.png"),
	preload("res://assets/sprites/reactions/fantastic.png")

]

var _tier_particle_textures = {
	"leaf": preload("res://assets/sprites/particles/particle_leaf.png"),
	"petal": preload("res://assets/sprites/particles/particle_petal.png"),
	"star_gold": preload("res://assets/sprites/particles/particle_star_gold.png"),
	"orb": preload("res://assets/sprites/particles/particle_orb.png"),
	"rainbow": preload("res://assets/sprites/particles/particle_rainbow_spark.png")
}

const DRAG_THRESHOLD = 10.0
const DEATH_GRACE_PERIOD = 2.0
const JAR_LEFT = -375.0
const JAR_RIGHT = 375.0

func _ready():
	add_to_group("game")
	_load_fruit_data()
	_connect_signals()
	GameManager.start_game()
	_spawn_preview_fruit()
	can_drop = true
	hud.visible = true
	select_mode_front.fruit_selected.connect(_on_fruit_selected)
	select_mode_front.selection_cancelled.connect(_on_selection_cancelled)
	ad_popup.watch_ad_pressed.connect(_on_ad_requested)
	AdsManager.rewarded_earned.connect(_on_rewarded_earned)
	AdsManager.rewarded_failed.connect(_on_rewarded_failed)
	_apply_current_skin()
	GameManager.skin_changed.connect(_apply_current_skin)
	GameManager.milestone_reached.connect(_on_milestone_reached)
	GameManager.new_best_reached.connect(_on_new_best_reached)
	GameManager.tier_unlocked.connect(_on_tier_unlocked)
	vignette.material.set_shader_parameter("vignette_color", Color(1.0, 0.0, 0.0, 1.0))
	vignette_base_color = vignette.color
	highest_fruit_tier_this_run = 1
	music_player.volume_db = -80.0
	music_player.play()
	var music_tween = create_tween()
	music_tween.tween_property(music_player, "volume_db", -6.0, 1.5)
	
func _apply_current_skin(_index = 0):
	var paths = [
	"res://assets/data/skins/skin_kitchen.tres",
	"res://assets/data/skins/skin_rooftop.tres",
	"res://assets/data/skins/skin_bedroom.tres",
	"res://assets/data/skins/skin_forest.tres",
	"res://assets/data/skins/skin_cafe.tres"
]
	var skin = load(paths[GameManager.current_skin])
	if not skin:
		return
	# Apply background
	background.apply_skin()
	# Apply fruit textures to all active fruits
	for fruit in fruit_container.get_children():
		if fruit.has_method("apply_skin"):
			var tier = fruit.fruit_data.tier - 1
			if tier < skin.fruit_textures.size():
				fruit.apply_skin(skin.fruit_textures[tier])
				
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
	print("Loaded: ", fruit_data_list.size(), " fruits")

func _connect_signals():
	death_line.body_entered.connect(_on_body_entered_death_line)
	death_line.body_exited.connect(_on_body_exited_death_line)
	GameManager.game_over.connect(_on_game_over)

func _process(delta):
	
	_check_death_condition(delta)
	if combo_count > 0:
		combo_timer -= delta
		if combo_timer <= 0:
			combo_count = 0
			chain_count = 0
	if current_fruit:
		drop_zone.position.x = drop_x
		current_fruit.global_position = Vector2(drop_x, drop_zone.global_position.y)
		
	_update_camera_shake(delta)
	beam_time += delta
	var pulse = (sin(beam_time * 3.0) + 1.0) / 2.0
	drop_beam.width = 2.0 + pulse * 1.5
	beam_glow.width = 10.0 + pulse * 6.0
	_update_vignette()

func _input(event):
	
	if select_mode_front.selecting:
		hud.visible = false
		return
	else:
		hud.visible = true
	# Ignore input if mouse/touch is over UI
	if get_viewport().gui_get_hovered_control():
		return

	# ---------------- TOUCH ----------------

	if event is InputEventScreenTouch:

		if event.pressed:

			dragging_drop = true

			touch_start_pos = event.position

			drop_x = clamp(
				event.position.x - get_viewport_rect().size.x / 2.0,
				JAR_LEFT,
				JAR_RIGHT
			)

		else:

			# RELEASE = DROP
			if dragging_drop and can_drop:
				_drop_fruit()

			dragging_drop = false

	# ---------------- TOUCH DRAG ----------------

	elif event is InputEventScreenDrag:

		if dragging_drop:

			drop_x = clamp(
				event.position.x - get_viewport_rect().size.x / 2.0,
				JAR_LEFT,
				JAR_RIGHT
			)

	# ---------------- MOUSE ----------------

	elif event is InputEventMouseButton:

		if event.button_index == MOUSE_BUTTON_LEFT:

			if event.pressed:

				dragging_drop = true

			else:

				if dragging_drop and can_drop:
					_drop_fruit()

				dragging_drop = false

	# ---------------- MOUSE DRAG ----------------

	elif event is InputEventMouseMotion:

		if dragging_drop:

			drop_x = clamp(
				event.position.x - get_viewport_rect().size.x / 2.0,
				JAR_LEFT,
				JAR_RIGHT
			)
		
func _drop_fruit():
	if not current_fruit:
		return
	if not can_drop:
		return

	can_drop = false
	var fruit = current_fruit
	current_fruit = null

	fruit.freeze = false
	fruit.activate()
	sfx_fruit_drop.pitch_scale = randf_range(0.95, 1.05)
	sfx_fruit_drop.play()
	_connect_fruit(fruit)

	notify_board_changed()
	$DropCooldown.start()
	
func _on_drop_cooldown_timeout():
	if GameManager.state == GameManager.GameState.GAME_OVER:
		return
	_spawn_preview_fruit()
	can_drop = true

func _spawn_preview_fruit():
	if GameManager.state == GameManager.GameState.GAME_OVER:
		return
	if current_fruit and is_instance_valid(current_fruit):
		return
	var max_tier = min(
	GameManager.get_current_max_tier(),
	fruit_data_list.size())
	if max_tier < 1:
		return
	var roll = randf()
	if roll > 0.995 and max_tier >= 15:
		next_fruit_tier = 15
	else:
		next_fruit_tier = randi_range(1, max_tier)
	#next_fruit_tier = 15
	
	var fruit = fruit_scene.instantiate()
	fruit_container.add_child(fruit)
	fruit.setup(fruit_data_list[next_fruit_tier - 1])
	fruit.position = Vector2(drop_x, drop_zone.position.y)
	fruit.freeze = true
	current_fruit = fruit
	fruit.face.set_preview(true)

func _on_merge_requested(other_fruit, requesting_fruit):
	if is_merging:
		if is_instance_valid(requesting_fruit):
			requesting_fruit.is_merging_now = false
			requesting_fruit.can_merge = true
		if is_instance_valid(other_fruit):
			other_fruit.is_merging_now = false
			other_fruit.can_merge = true
		return
	if not is_instance_valid(requesting_fruit) or not is_instance_valid(other_fruit):
		return
	is_merging = true
	var tier = requesting_fruit.fruit_data.tier
	Engine.time_scale = 0.06

	await get_tree().create_timer(
		0.03,
		true,
		false,
		true
	).timeout

	Engine.time_scale = 1.0
	var merge_pos = (requesting_fruit.global_position + other_fruit.global_position) / 2.0

	# --- SQUASH: fruits squish toward each other before popping ---
	if is_instance_valid(requesting_fruit) and is_instance_valid(other_fruit):
		var dir_to_other = (other_fruit.global_position - requesting_fruit.global_position).normalized()
		var squash_tween = create_tween()
		squash_tween.set_parallel(true)
		squash_tween.tween_property(
			requesting_fruit.get_node("Sprite2D"),
			"scale",
			requesting_fruit.base_scale * Vector2(1.15, 0.85),
			0.06
		).set_trans(Tween.TRANS_SINE)
		squash_tween.tween_property(
			other_fruit.get_node("Sprite2D"),
			"scale",
			other_fruit.base_scale * Vector2(1.15, 0.85),
			0.06
		).set_trans(Tween.TRANS_SINE)
		squash_tween.tween_property(
			requesting_fruit,
			"global_position",
			requesting_fruit.global_position + dir_to_other * 4.0,
			0.06
		).set_trans(Tween.TRANS_SINE)
		squash_tween.tween_property(
			other_fruit,
			"global_position",
			other_fruit.global_position - dir_to_other * 4.0,
			0.06
		).set_trans(Tween.TRANS_SINE)
		await squash_tween.finished

	requesting_fruit.queue_free()
	other_fruit.queue_free()
	
	for fruit in fruit_container.get_children():
		if fruit.has_method("apply_poison") and is_instance_valid(fruit):
			if fruit.global_position.distance_to(merge_pos) < 200:
				if randf() < 0.4:
					fruit.face.react_to_nearby_merge()

	# --- POP: immediate soft light burst at merge point ---
	_spawn_merge_flash(merge_pos, tier + 1)
	_spawn_glow_wave(merge_pos, tier + 1)
	
	await get_tree().process_frame
	if not is_inside_tree():
		is_merging = false
		return
	await get_tree().process_frame
	# ← Moved here: old fruits are freed, safe to allow new merges now.
	# is_merging_now on the new fruit prevents any double-trigger.
	is_merging = false
	# Play merge pop sound
	_play_merge_pop(tier)
	combo_count += 1
	combo_timer = COMBO_WINDOW
	var combo_multiplier = 1.0 + (combo_count - 1) * 0.5
	var chain_multiplier = 1.0 + chain_count * 0.5
	var base_value = fruit_data_list[tier - 1].score_value
	var final_score = int(base_value * combo_multiplier * chain_multiplier)
	GameManager.add_score(final_score)
	_spawn_score_popup(merge_pos, final_score, combo_count, chain_count)
	if combo_count >= 2:
		_spawn_reaction_popup(
			merge_pos,
			combo_count
		)
	if tier >= 10:
		var keys_earned = tier - 9
		GameManager.add_keys(keys_earned)
		sfx_key_earned.pitch_scale = randf_range(0.97, 1.03)
		sfx_key_earned.play()
		_spawn_key_effect(merge_pos, keys_earned)

	if tier < fruit_data_list.size():
		var new_fruit = fruit_scene.instantiate()
		fruit_container.add_child(new_fruit)
		new_fruit.setup(fruit_data_list[tier])
		new_fruit.global_position = merge_pos
		if tier >= 9:
			new_fruit.scale = Vector2(0.45,0.45)
		else:
			new_fruit.scale = Vector2(0.65,0.65)

		var pop = create_tween()

		pop.tween_property(
			new_fruit,
			"scale",
			Vector2(1.5,1.5),
			0.12
		).set_trans(Tween.TRANS_BACK)

		pop.tween_property(
			new_fruit,
			"scale",
			Vector2.ONE,
			0.08
		)
		new_fruit.activate(true)
		# No manual force_merge_scan here — activate(true) handles it after its physics frame.
		# _connect_fruit must come before that physics frame so the signal is wired up in time.
		if tier < 5:
			trigger_shake(4)
			background.pulse_light_bloom(0.25, 0.10)

		elif tier < 8:
			trigger_shake(7)
			background.pulse_light_bloom(0.4, 0.10)

		elif tier < 11:
			trigger_shake(10)
			trigger_camera_pulse(0.04, 0.15)
			background.pulse_light_bloom(0.7, 0.10)

		else:
			trigger_shake(14)
			trigger_camera_pulse(0.06, 0.15)
			background.pulse_light_bloom(1.0, 0.10)
		_connect_fruit(new_fruit)
		highest_fruit_tier_this_run = max(highest_fruit_tier_this_run, tier + 1)
		
	if tier + 1 > GameManager.unlocked_max_tier:
		GameManager.unlock_tier(tier + 1)

	_spawn_merge_particles(merge_pos, tier + 1)
	#_spawn_merge_flash(merge_pos, tier + 1)
	await get_tree().create_timer(0.08).timeout
	_spawn_merge_sparkle(merge_pos)
	await get_tree().create_timer(0.04).timeout
	_spawn_merge_sparkle(merge_pos)
	await get_tree().create_timer(0.06).timeout
	_spawn_merge_sparkle(merge_pos)
	await get_tree().process_frame
	notify_board_changed()
	
func _on_fruit_fully_rotten(_fruit):
	trigger_shake(8.0)
	var rotten = fruit_container.get_children().filter(func(f): return f.has_method("apply_poison") and f.state == f.FruitState.ROTTEN)
	background.set_rotten_count(rotten.size())
	notify_board_changed()
	
func _spawn_merge_particles(pos: Vector2, tier: int = 1):
	var fruit_color = _get_tier_color(tier)
	
	# Poof ring 1
	_spawn_poof_ring(pos, fruit_color, 0.0)
	# Poof ring 2 slightly delayed
	await get_tree().create_timer(0.05).timeout
	_spawn_poof_ring(pos, fruit_color, 0.05)
	
	# Particles burst
	var particles = CPUParticles2D.new()
	particles.texture = load("res://assets/sprites/poof.png")
	fruit_container.add_child(particles)
	particles.global_position = pos
	particles.emitting = true
	particles.amount = 20
	particles.lifetime = 0.7
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.direction = Vector2(0, -1)
	particles.spread = 180.0
	particles.initial_velocity_min = 150.0
	particles.initial_velocity_max = 320.0
	particles.scale_amount_min = 0.1
	particles.scale_amount_max = 0.3
	particles.color = fruit_color
	#particles.gravity = Vector2(0, 200)
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([
	Color(fruit_color.r, fruit_color.g, fruit_color.b, 1.0),
	Color(fruit_color.r, fruit_color.g, fruit_color.b, 0.0)])
	
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	particles.color_ramp = ramp
	particles.finished.connect(particles.queue_free)

	# Tier-themed particle burst (leaf/petal/star/orb/rainbow)
	_spawn_tier_themed_burst(pos, tier)
func _get_tier_particle_style(tier: int) -> String:
	if tier <= 3:
		return "leaf"
	elif tier <= 6:
		return "petal"
	elif tier <= 9:
		return "star_gold"
	elif tier <= 12:
		return "orb"
	else:
		return "rainbow"
		
func _spawn_tier_themed_burst(pos: Vector2, tier: int):
	var style = _get_tier_particle_style(tier)
	var tex = _tier_particle_textures[style]

	var burst = CPUParticles2D.new()
	burst.texture = tex
	fruit_container.add_child(burst)
	burst.z_index = 0
	burst.global_position = pos
	burst.emitting = true
	burst.one_shot = true
	burst.explosiveness = 0.85
	burst.direction = Vector2(0, 0)
	burst.spread = 180.0
	burst.gravity = Vector2(0, 0)
	
	
	match style:
		"leaf":
			burst.amount = 10 + tier * 1
			burst.lifetime = 0.9
			burst.initial_velocity_min = 100.0
			burst.initial_velocity_max = 200.0
			burst.damping_min = 40.0
			burst.damping_max = 80.0
			burst.scale_amount_min = 0.5
			burst.scale_amount_max =1.0
			var scale_curve = Curve.new()
			scale_curve.add_point(Vector2(0.0, 0.0))
			scale_curve.add_point(Vector2(0.15, 1.0))
			scale_curve.add_point(Vector2(1.0, 0.6))
			burst.scale_amount_curve = scale_curve
			burst.angular_velocity_min = -90.0
			burst.angular_velocity_max = 90.0
			burst.color = Color(1, 1, 1, 1)
			var fade_gradient := Gradient.new()
			fade_gradient.colors = PackedColorArray([
				burst.color,
				Color(burst.color.r, burst.color.g, burst.color.b, 0.0)
			])

			var fade_ramp := GradientTexture1D.new()
			fade_ramp.gradient = fade_gradient
			burst.color_ramp = fade_ramp
		"petal":
			burst.amount = 20 + tier * 1
			burst.lifetime =1.0
			burst.initial_velocity_min = 100.0
			burst.initial_velocity_max = 200.0
			burst.damping_min = 40.0
			burst.damping_max = 80.0
			burst.scale_amount_min = 0.55
			burst.scale_amount_max = 1.10
			var scale_curve = Curve.new()
			scale_curve.add_point(Vector2(0.0, 0.0))
			scale_curve.add_point(Vector2(0.15, 1.0))
			scale_curve.add_point(Vector2(1.0, 0.6))
			burst.scale_amount_curve = scale_curve
			burst.angular_velocity_min = -120.0
			burst.angular_velocity_max = 120.0
			burst.color = Color(1, 1, 1, 1)
			var fade_gradient := Gradient.new()
			fade_gradient.colors = PackedColorArray([
				burst.color,
				Color(burst.color.r, burst.color.g, burst.color.b, 0.0)
			])

			var fade_ramp := GradientTexture1D.new()
			fade_ramp.gradient = fade_gradient
			burst.color_ramp = fade_ramp
		"star_gold":
			burst.amount = 20 + tier * 1
			burst.lifetime = 1.0
			burst.initial_velocity_min = 140.0
			burst.initial_velocity_max = 280.0
			burst.damping_min = 40.0
			burst.damping_max = 80.0
			burst.scale_amount_min = 1.0
			burst.scale_amount_max = 1.5
			var scale_curve = Curve.new()
			scale_curve.add_point(Vector2(0.0, 0.0))
			scale_curve.add_point(Vector2(0.15, 1.0))
			scale_curve.add_point(Vector2(1.0, 0.6))
			burst.scale_amount_curve = scale_curve
			burst.gravity = Vector2(0, 20)
			burst.color = Color(1.0, 0.85, 0.3, 1.0)
			var fade_gradient := Gradient.new()
			fade_gradient.colors = PackedColorArray([
				burst.color,
				Color(burst.color.r, burst.color.g, burst.color.b, 0.0)
			])

			var fade_ramp := GradientTexture1D.new()
			fade_ramp.gradient = fade_gradient
			burst.color_ramp = fade_ramp
		"orb":
			burst.amount = 20 + tier * 1
			burst.lifetime = 1.0
			burst.initial_velocity_min = 200.0
			burst.initial_velocity_max = 300.0
			burst.damping_min = 40.0
			burst.damping_max = 80.0
			burst.scale_amount_min = 1.2
			burst.scale_amount_max = 1.75
			var scale_curve = Curve.new()
			scale_curve.add_point(Vector2(0.0, 0.0))
			scale_curve.add_point(Vector2(0.15, 1.0))
			scale_curve.add_point(Vector2(1.0, 0.6))
			burst.scale_amount_curve = scale_curve
			burst.gravity = Vector2(0, -10)
			burst.color = Color(0.5, 1.0, 0.95, 0.9)
			var fade_gradient := Gradient.new()
			fade_gradient.colors = PackedColorArray([
				burst.color,
				Color(burst.color.r, burst.color.g, burst.color.b, 0.0)
			])

			var fade_ramp := GradientTexture1D.new()
			fade_ramp.gradient = fade_gradient
			burst.color_ramp = fade_ramp
		"rainbow":
			burst.amount = 20 + tier * 1
			burst.lifetime = 0.9
			burst.initial_velocity_min = 300.0
			burst.initial_velocity_max = 400.0
			burst.damping_min = 40.0
			burst.damping_max = 80.0
			burst.scale_amount_min = 1.75
			burst.scale_amount_max = 2.5
			var scale_curve = Curve.new()
			scale_curve.add_point(Vector2(0.0, 0.0))
			scale_curve.add_point(Vector2(0.15, 1.0))
			scale_curve.add_point(Vector2(1.0, 0.6))
			burst.scale_amount_curve = scale_curve
			burst.gravity = Vector2(0, 10)
			burst.color = Color(1, 1, 1, 1)
			# Rainbow tint via a gradient ramp across the particle's lifetime
			var gradient = Gradient.new()
			gradient.colors = PackedColorArray([
				Color(1.0, 0.3, 0.4),
				Color(1.0, 0.8, 0.2),
				Color(0.4, 1.0, 0.5),
				Color(0.3, 0.6, 1.0),
				Color(0.8, 0.3, 1.0)
			])
			var ramp = GradientTexture1D.new()
			ramp.gradient = gradient
			burst.color_ramp = ramp
	
	if style == "rainbow":
		for i in 3:
			await get_tree().create_timer(0.06).timeout
			_spawn_merge_sparkle(pos)
	burst.finished.connect(burst.queue_free)
	

func _spawn_explosion_ring(pos: Vector2):
	var ring = Sprite2D.new()
	add_child(ring)
	ring.global_position = pos
	ring.texture = _ring_tex
	ring.modulate = Color(1, 1, 1, 1)
	ring.scale = Vector2(0.05, 0.05)

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector2(2.0,2.0), 0.3).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "modulate:a", 0.0, 0.25).set_ease(Tween.EASE_IN)
	tween.tween_callback(ring.queue_free).set_delay(0.3)

func _spawn_poof_ring(pos: Vector2, color: Color, _delay: float):
	var ring = Sprite2D.new()
	ring.z_index = 1000
	fruit_container.add_child(ring)
	ring.global_position = pos
	ring.texture = _ring_tex
	ring.modulate = color
	ring.scale = Vector2(0.15, 0.15)
	ring.modulate.a = 1.0

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector2(2.5, 2.5), 0.7).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(ring, "modulate:a", 0.0, 0.7).set_ease(Tween.EASE_IN)
	tween.tween_callback(ring.queue_free).set_delay(0.7)
	
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

func _check_death_condition(delta):
	if GameManager.state == GameManager.GameState.GAME_OVER:
		return
	if fruits_above_death_line.size() > 0:
		death_timer += delta
		if death_timer >= DEATH_GRACE_PERIOD:
			GameManager.trigger_game_over()
	else:
		death_timer = 0.0

func _on_body_entered_death_line(body):
	if not body.has_method("activate"):
		return
	if not body.is_placed:
		return
	if body == current_fruit:
		return
	if abs(body.linear_velocity.y) > 200:
		return
	if not body in fruits_above_death_line:
		fruits_above_death_line.append(body)

func _on_body_exited_death_line(body):
	fruits_above_death_line.erase(body)

func _on_game_over():
	can_drop = false
	trigger_shake(20.0)
	sfx_game_over.play()
	if current_fruit:
		current_fruit.queue_free()
		current_fruit = null
	$HUD.visible = false
	var highest_tex: Texture2D = null
	if highest_fruit_tier_this_run > 0 and highest_fruit_tier_this_run <= fruit_data_list.size():
		highest_tex = fruit_data_list[highest_fruit_tier_this_run - 1].texture
		
	death_screen.show_death_screen(
		GameManager.score,
		GameManager.high_score,
		highest_tex
	)
	
func _connect_fruit(fruit):
	if not fruit.merge_requested.is_connected(_on_merge_requested):
		fruit.merge_requested.connect(_on_merge_requested)
	if not fruit.fully_rotten.is_connected(_on_fruit_fully_rotten):
		fruit.fully_rotten.connect(_on_fruit_fully_rotten)
		
func _update_camera_shake(delta):
	if shake_amount > 0:
		shake_amount = lerp(shake_amount, 0.0, shake_decay * delta)
		camera.offset = camera.offset.lerp(
		Vector2(
			randf_range(-shake_amount, shake_amount),
			randf_range(-shake_amount, shake_amount)
		),
		0.35
)
	else:
		camera.offset = Vector2.ZERO

func trigger_shake(amount: float):
	shake_amount = max(shake_amount, amount)
	if amount > 15.0:
		background.swing_bulb()
				
func _spawn_merge_flash(pos: Vector2, tier: int):
	var flash = PointLight2D.new()
	fruit_container.add_child(flash)
	flash.global_position = pos
	flash.color = Color(0.876, 1.0, 0.901, 1.0)
	flash.energy = 2.0 + tier * 0.5
	flash.height = 80.0 + tier * 20.0
	flash.shadow_filter = PointLight2D.SHADOW_FILTER_NONE
	var tween = create_tween()
	tween.tween_property(flash, "energy", 0.0, 0.3)
	tween.tween_callback(flash.queue_free)
	
func _spawn_score_popup(pos: Vector2, value: int, combo: int = 1, chain: int = 0):
	var label = Label.new()
	add_child(label)
	var font = load("res://assets/fonts/MPLUSRounded1c-Black.ttf")
	
	var text = "+" + str(value)
	
	if combo > 1:
		text += "  x" + str(combo) + " COMBO"
	if chain > 0:
		text += "  CHAIN " + str(chain)
	label.text = text
	label.global_position = pos
	label.z_index = 10
	var font_size = 32 + min(combo * 4, 20)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_font_override("font", font)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	label.add_theme_constant_override("outline_size", 2)
	var color = Color(1.0, 1.0, 1.0, 1.0)
	if combo > 2:
		color = Color(1.0, 0.901, 0.846, 1.0)
	if combo > 4:
		color = Color(1.0, 0.882, 0.775, 1.0)
	label.add_theme_color_override("font_color", color)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position", pos + Vector2(0, -150), 1.0).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 1.0).set_ease(Tween.EASE_IN)
	tween.tween_callback(label.queue_free).set_delay(1.0)
	label.scale = Vector2.ZERO
	var pop = create_tween()
	pop.tween_property(
		label,
		"scale",
		Vector2(1.25,1.25),
		0.14
	).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	pop.tween_property(
		label,
		"scale",
		Vector2.ONE,
		0.08
	)
func _update_vignette():
	if fruits_above_death_line.size() > 0:
		var intensity = clamp(death_timer / DEATH_GRACE_PERIOD, 0.0, 1.0)
		# Force red every frame — guarantees no leftover gold from a
		# milestone/new-best flash can bleed into the death warning
		vignette.material.set_shader_parameter("vignette_color", Color(1.0, 0.0, 0.0, 1.0))
		vignette.material.set_shader_parameter("intensity", intensity)
		if not _danger_flicker_active:
			_danger_flicker_active = true
			background.start_flicker(0.5)
	else:
		_danger_flicker_active = false
		var current = vignette.material.get_shader_parameter("intensity")
		vignette.material.set_shader_parameter("intensity", lerp(current, 0.0, 0.1))
		
func powerup_shake():
	can_drop=false
	
	var original_rotation=jar_sprite.rotation_degrees
	var original_position=jar_sprite.position
	var original_camera_offset=camera.offset
	var original_camera_zoom=camera.zoom
	
	Input.vibrate_handheld(120)
	Engine.time_scale = 0.12
	await get_tree().create_timer(
		0.04,
		true,
		false,
		true
	).timeout
	Engine.time_scale = 0.97
	
	var intro_zoom=create_tween()
	
	intro_zoom.tween_property(
		camera,
		"zoom",
		original_camera_zoom*0.8,
		0.24
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	for fruit in fruit_container.get_children():
		if fruit is RigidBody2D:
			fruit.linear_damp=0.28
			fruit.angular_damp=0.12
	
	for i in 6:
		
		var dir=-1 if i%2==0 else 1
		var buildup=0.8+(i/6.0)*0.6
		
		var tween=create_tween()
		tween.set_parallel(true)
		
		tween.tween_property(
			jar_sprite,
			"rotation_degrees",
			dir*5.5*buildup,
			0.11
		).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		
		tween.tween_property(
			jar_sprite,
			"position:x",
			original_position.x+dir*12.0*buildup,
			0.11
		).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		
		tween.tween_property(
			camera,
			"offset",
			Vector2(
				dir*10.0*buildup,
				randf_range(-10.0,10.0)
			),
			0.11
		).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		
		for fruit in fruit_container.get_children():
			camera.rotation_degrees = randf_range(-1.6,1.6)
			
			if fruit is RigidBody2D:
				
				var horizontal=dir*randf_range(
					360.0,
					560.0
				)*buildup
				
				var vertical=randf_range(
					-210.0,
					-120.0
				)*buildup
				
				fruit.apply_central_impulse(
					Vector2(horizontal,vertical)
				)
				
				fruit.apply_torque_impulse(
					randf_range(
						-12000.0,
						12000.0
					)*buildup
				)
	
				if fruit.has_node("Sprite2D"):
					
					var sprite=fruit.get_node("Sprite2D")
					sprite.rotation_degrees = randf_range(-10,10)
					var squash=create_tween()
					squash.set_parallel(true)
					
					squash.tween_property(
						sprite,
						"scale",
						fruit.base_scale*Vector2(
							1.05,
							0.92
						),
						0.04
					)
					
					squash.tween_property(
						sprite,
						"scale",
						fruit.base_scale,
						0.1
					).set_delay(0.04)
			camera.rotation_degrees = 0
		trigger_shake(34.0*buildup)
		_spawn_white_flash(0.14,0.05)
		# Play impact sound on each shake hit — pitch rises with buildup
		sfx_fruit_land.pitch_scale = randf_range(0.7, 0.9) + buildup * 0.2
		sfx_fruit_land.volume_db = lerp(-6.0, 2.0, buildup - 0.8)
		sfx_fruit_land.play()
		if i==4:
			Engine.time_scale=0.06
			
			await get_tree().create_timer(
				0.025,
				true,
				false,
				true
			).timeout
			
			Engine.time_scale=0.97
		
		await get_tree().create_timer(0.12).timeout
	
	Engine.time_scale=1.0
	_spawn_white_flash(0.28,0.12)
	var reset=create_tween()
	reset.set_parallel(true)
	
	reset.tween_property(
		jar_sprite,
		"rotation_degrees",
		original_rotation,
		0.2
	).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	
	reset.tween_property(
		jar_sprite,
		"position",
		original_position,
		0.2
	).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	
	reset.tween_property(
		camera,
		"offset",
		original_camera_offset,
		0.28
	).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	
	reset.tween_property(
		camera,
		"zoom",
		original_camera_zoom,
		0.55
	).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	await reset.finished
	for fruit in fruit_container.get_children():
		if fruit is RigidBody2D:
			fruit.linear_damp=0.0
			fruit.angular_damp=0.0
	can_drop=true

func _spawn_white_flash(strength := 0.2, duration := 0.08):
	var flash = ColorRect.new()
	ui_layer.add_child(flash)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(1,1,1,strength)
	flash.modulate.a = strength
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.z_index = 100
	var tween = create_tween()
	tween.tween_property(
		flash,
		"modulate:a",
		0.0,
		duration
	)
	tween.tween_callback(flash.queue_free)

func _spawn_dark_flash(strength := 0.45, duration := 0.08):
	var dark = ColorRect.new()
	ui_layer.add_child(dark)
	dark.set_anchors_preset(Control.PRESET_FULL_RECT)
	dark.color = Color(0,0,0,strength)
	dark.modulate.a = strength
	dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	#dark.z_index = 9998
	var tween = create_tween()
	tween.tween_property(
		dark,
		"modulate:a",
		0.0,
		duration
	)
	tween.tween_callback(dark.queue_free)

func powerup_pluck():
	can_drop = false
	active_powerup_index = 2
	pending_powerup_type = 2
	select_mode_front.begin_selection("Snip", "fresh",select_mode_back)

func powerup_cure():
	can_drop = false
	active_powerup_index = 3
	pending_powerup_type = 3
	select_mode_front.begin_selection("Cure the ROT", "rotten",select_mode_back)

func powerup_bomb():
	can_drop = false
	active_powerup_index = 5
	pending_powerup_type = 5
	select_mode_front.begin_selection("Pick Target", "any",select_mode_back)

func powerup_purge():
	can_drop = false
	active_powerup_index = 4
	pending_powerup_type = 4
	select_mode_front.begin_selection("PURGE", "rotten",select_mode_back)
	
func powerup_refresh():
	can_drop = false

	# --- GLOBAL EFFECT START ---
	_play_refresh_vignette()
	_spawn_white_flash(0.2, 0.12)
	trigger_shake(6.0)

	var original_zoom = camera.zoom
	camera.zoom *= 0.97

	var tween = create_tween()
	tween.tween_property(camera, "zoom", original_zoom, 0.25).set_trans(Tween.TRANS_CUBIC)

	# --- collect valid fruits ---
	var targets := []
	for fruit in fruit_container.get_children():
		if not fruit.has_method("apply_poison"):
			continue
		if fruit.state == fruit.FruitState.ROTTEN:
			continue
		targets.append(fruit)

	# sort so effect feels like wave (left → right)
	targets.sort_custom(func(a, b):
		return a.global_position.x < b.global_position.x
	)

	# --- SEQUENTIAL CLEANSE WAVE ---
	var delay := 0.0
	for fruit in targets:
		await get_tree().create_timer(delay).timeout
		delay = 0.03  # wave speed

		if not is_instance_valid(fruit):
			continue

		# reset state cleanly
		fruit.is_poisoned = false
		fruit.poison_speed_multiplier = 1.0
		fruit.state = fruit.FruitState.FRESH
		fruit.can_merge = true

		if fruit.rot_timer:
			fruit.rot_timer.stop()
			fruit.rot_timer.start()

		# stronger visual identity burst
		_spawn_refresh_burst(fruit.global_position)

		# micro camera response per hit (VERY subtle)
		camera.offset = Vector2(randf_range(-2,2), randf_range(-2,2))

	# reset camera offset smoothly
	var reset = create_tween()
	reset.tween_property(camera, "offset", Vector2.ZERO, 0.2)
	
	notify_board_changed()

	can_drop = true

func _spawn_refresh_burst(pos: Vector2):
	var particles = CPUParticles2D.new()
	add_child(particles)
	particles.global_position = pos
	particles.emitting = true
	particles.modulate.a = 0.05
	particles.texture = load("res://assets/sprites/poof_inner.png")
	particles.amount = 28
	particles.lifetime = 1
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.direction = Vector2(0, -1)
	particles.spread = 180.0
	particles.gravity = Vector2()
	particles.initial_velocity_min = 80.0
	particles.initial_velocity_max = 150.0
	particles.scale_amount_min = 1
	particles.scale_amount_max = 1.5
	particles.color = Color(0.3, 1.0, 0.5)
	particles.finished.connect(particles.queue_free)
	var rotten = []
	for fruit in fruit_container.get_children():
		if fruit.has_method("apply_poison") and fruit.state == fruit.FruitState.ROTTEN:
			rotten.append(fruit)
	if rotten.size() > 0:
		var target = rotten[randi() % rotten.size()]
		target.set_meta("refreshed", true)
		await get_tree().create_timer(8.0).timeout
		if is_instance_valid(target):
			target.remove_meta("refreshed")

func powerup_ripple():
	var tier_groups = {}
	for fruit in fruit_container.get_children():
		if fruit == current_fruit:
			continue
		if not fruit.has_method("apply_poison"):
			continue
		if not fruit.is_placed:
			continue
		if not fruit.can_merge:
			continue
		if fruit.is_merging_now:
			continue
		if fruit.state == fruit.FruitState.ROTTEN:
			continue
		var tier = fruit.fruit_data.tier
		if not tier_groups.has(tier):
			tier_groups[tier] = []
		tier_groups[tier].append(fruit)

	# find first valid group
	var found_tier = -1
	var found_group = []
	for tier in tier_groups:
		if tier_groups[tier].size() >= 2:
			found_tier = tier
			found_group = tier_groups[tier]
			break

	if found_tier == -1:
		return

	var merge_count = found_group.size() / 2
	var center = Vector2.ZERO
	for fruit in found_group:
		center += fruit.global_position
	center /= found_group.size()

	_spawn_ripple_label(center, found_group.size())

	var positions = []
	for i in merge_count:
		positions.append(
			found_group[i * 2].global_position.lerp(
				found_group[i * 2 + 1].global_position, 0.5
			)
		)

	# --- NEW: radius of the fruit that will actually be spawned (next tier up) ---
	var new_radius := 40.0
	if found_tier < fruit_data_list.size():
		new_radius = fruit_data_list[found_tier].radius

	# --- NEW: clamp each spawn position inside the jar, accounting for the new fruit's size ---
	for i in positions.size():
		positions[i].x = clamp(positions[i].x, JAR_LEFT + new_radius, JAR_RIGHT - new_radius)

	# --- NEW: push apart any spawn points that would overlap each other ---
	var min_dist = new_radius * 2.0 + 4.0
	for iteration in 6:
		var moved = false
		for i in positions.size():
			for j in range(i + 1, positions.size()):
				var diff = positions[j] - positions[i]
				var dist = diff.length()
				if dist < min_dist:
					moved = true
					var push = (min_dist - dist) * 0.5
					var dir = diff.normalized() if dist > 0.001 else Vector2(1, 0)
					positions[i] -= dir * push
					positions[j] += dir * push
					positions[i].x = clamp(positions[i].x, JAR_LEFT + new_radius, JAR_RIGHT - new_radius)
					positions[j].x = clamp(positions[j].x, JAR_LEFT + new_radius, JAR_RIGHT - new_radius)
		if not moved:
			break

	# Only free consumed pairs, not any leftover odd fruit
	for i in merge_count * 2:
		if is_instance_valid(found_group[i]):
			found_group[i].queue_free()

	await get_tree().process_frame

	var spawned_fruits = []
	for pos in positions:
		if found_tier < fruit_data_list.size():
			var new_fruit = fruit_scene.instantiate()
			fruit_container.add_child(new_fruit)
			new_fruit.setup(fruit_data_list[found_tier])
			new_fruit.global_position = pos
			new_fruit.freeze = true   # NEW: hold still until we activate it deliberately
			_connect_fruit(new_fruit)
			spawned_fruits.append(new_fruit)

	await get_tree().physics_frame
	await get_tree().physics_frame

	var ripple_keys_earned := 0
	for new_fruit in spawned_fruits:
		if is_instance_valid(new_fruit):
			new_fruit.freeze = false   # NEW: release right before activation
			new_fruit.activate(false)
			highest_fruit_tier_this_run = max(highest_fruit_tier_this_run, found_tier + 1)
			_spawn_merge_particles(new_fruit.global_position, found_tier)
			_spawn_merge_flash(new_fruit.global_position, found_tier)
			trigger_shake(5 + found_tier)
			GameManager.add_score(fruit_data_list[found_tier].score_value)
			if found_tier + 1 > GameManager.unlocked_max_tier:
				GameManager.unlock_tier(found_tier + 1)
			if found_tier >= 10:
				var keys_from_this_pair = found_tier - 9
				GameManager.add_keys(keys_from_this_pair)
				ripple_keys_earned += keys_from_this_pair
				_spawn_key_effect(new_fruit.global_position, keys_from_this_pair)
	if ripple_keys_earned > 0:
		sfx_key_earned.pitch_scale = randf_range(0.97, 1.03)
		sfx_key_earned.play()
	await get_tree().process_frame
	notify_board_changed()
	
	
func _spawn_ripple_label(pos: Vector2, count: int):
	
	var label = Label.new()
	add_child(label)
	var combo_font = preload("res://assets/fonts/MPLUSRounded1c-Black.ttf")
	label.add_theme_font_override("font", combo_font)
	label.text = "x" + str(count) + " RIPPLE!"
	label.global_position = pos
	label.z_index = 10
	label.add_theme_font_size_override("font_size", 48)
	label.add_theme_color_override("font_color", Color(0.7, 0.3, 1.0))
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position", pos + Vector2(0, -200), 1.0).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 1.0).set_ease(Tween.EASE_IN)
	tween.tween_callback(label.queue_free).set_delay(1.0)		
				
func activate_powerup(index: int):
	_play_powerup_sound(index)
	match index:
		1: powerup_shake()
		2: powerup_pluck()
		3: powerup_cure()
		4: powerup_purge()
		5: powerup_bomb()
		6: powerup_refresh()
		7: powerup_ripple()
		
func _on_fruit_selected(fruit):
	pending_powerup_type = -1
	if not is_instance_valid(fruit):
		can_drop = true
		active_powerup_index = -1
		return
	await _play_selection_pop(fruit)
	# Play tier-appropriate merge pop on fruit selection
	_play_select_merge_pop(fruit.fruit_data.tier)
	# Deduct coins NOW — action is confirmed
	var type = active_powerup_index as GameManager.PowerupType
	GameManager.use_powerup(type)
		
	match active_powerup_index:
		2: # Pluck
			sfx_pluck.pitch_scale = randf_range(0.9, 1.1)
			sfx_pluck.play()
			_spawn_merge_particles(fruit.global_position, fruit.fruit_data.tier)
			_spawn_merge_flash(fruit.global_position, fruit.fruit_data.tier)
			fruit.queue_free()
			notify_board_changed()
		3: # Cure
			sfx_powerup_specific.stream = _powerup_sfx[3]
			sfx_powerup_specific.pitch_scale = 1.0
			sfx_powerup_specific.play()
			fruit.is_poisoned = false
			fruit.poison_speed_multiplier = 1.0
			fruit.state = fruit.FruitState.FRESH
			fruit.can_merge = true
			fruit.freeze = false
			fruit.rot_timer.stop()
			fruit.rot_timer.start()
			notify_board_changed()
		4: # Purge
			var tier = fruit.fruit_data.tier
			var to_remove = []
			for f in fruit_container.get_children():
				if f.has_method("apply_poison") and f.state == f.FruitState.ROTTEN:
					if f.fruit_data.tier == tier:
						to_remove.append(f)
			var purge_delay := 0.0
			for f in to_remove:
				if is_instance_valid(f):
					_spawn_merge_particles(f.global_position, tier)
					# Stagger the pop sounds so multiple purges
					# don't all fire at once creating a wall of noise
					await get_tree().create_timer(purge_delay).timeout
					_play_merge_pop(tier)
					purge_delay += 0.06
					f.queue_free()
			notify_board_changed()
		5: # Bomb
			sfx_powerup_specific.stream = _powerup_sfx[5]
			sfx_powerup_specific.pitch_scale = 1.0
			sfx_powerup_specific.play()
			
			_explode_fruit(fruit)
			notify_board_changed()
	active_powerup_index = -1
	can_drop = true
	

var pending_powerup_type: int = -1

func _on_selection_cancelled():
	pending_powerup_type = -1
	active_powerup_index = -1
	can_drop = true
	
func _explode_fruit(target):
	if not is_instance_valid(target):
		return
	var original_zoom = camera.zoom
	var original_offset = camera.offset
	var explosion_pos=target.global_position
	var radius=170.0
	
	Input.vibrate_handheld(140)
	_spawn_dark_flash(0.55,0.12)
	camera.zoom *= 0.92
	Engine.time_scale = 0.03
	
	await get_tree().create_timer(
		0.03,
		true,
		false,
		true
	).timeout
	
	Engine.time_scale=1.0
	
	trigger_shake(50.0)
	camera.position += Vector2(
		randf_range(-18,18),
		randf_range(-14,14)
	)
	_spawn_merge_flash(explosion_pos,6)
	_spawn_merge_particles(explosion_pos,6)
	_spawn_explosion_ring(explosion_pos)
	for i in 14:
		var streak = Line2D.new()
		add_child(streak)
		streak.width = randf_range(3.0,7.0)
		streak.default_color = Color(1,0.9,0.5)
		streak.global_position = explosion_pos
		var dir = Vector2.RIGHT.rotated(
			randf()*TAU
		)
		streak.add_point(Vector2.ZERO)
		streak.add_point(dir * randf_range(80,160))
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(
			streak,
			"scale",
			Vector2(2.2,2.2),
			0.18
		)
		tween.tween_property(
			streak,
			"modulate:a",
			0.0,
			0.18
		)
		tween.tween_callback(streak.queue_free)
	
	var affected=[]
	
	for fruit in fruit_container.get_children():
		
		if not (fruit is RigidBody2D):
			continue
		
		var dist=fruit.global_position.distance_to(explosion_pos)
		
		if dist>radius:
			continue
		
		affected.append(fruit)
	
	for fruit in affected:
		
		if not is_instance_valid(fruit):
			continue
		
		var dir=(
			fruit.global_position-explosion_pos
		).normalized()
		
		var strength=1.0-(
			fruit.global_position.distance_to(explosion_pos)/radius
		)
		
		fruit.apply_central_impulse(
			dir*2200.0*strength
		)
		
		fruit.apply_torque_impulse(
			randf_range(
				-24000.0,
				24000.0
			)*strength
		)
		
		if fruit==target:
			
			await get_tree().process_frame
			
			if is_instance_valid(fruit):
				fruit.queue_free()

	var blast=create_tween()

	blast.set_parallel(true)

	blast.tween_property(
		camera,
		"zoom",
		original_zoom*0.6,
		0.3
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	blast.tween_property(
		camera,
		"offset",
		Vector2(
			randf_range(-26,26),
			randf_range(-20,20)
		),
		0.3
	)

	await blast.finished

	var reset=create_tween()

	reset.set_parallel(true)

	reset.tween_property(
		camera,
		"zoom",
		original_zoom,
		0.5
	).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	reset.tween_property(
		camera,
		"offset",
		original_offset,
		0.5
	).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _spawn_key_effect(pos: Vector2, amount: int):
	trigger_shake(40.0)
	Input.vibrate_handheld(90)
	_spawn_merge_particles(pos, 10)
	_spawn_merge_flash(pos, 10)
	_spawn_celebration_burst(pos, Color(1.0, 0.85, 0.2, 1.0))

	var label = Label.new()
	add_child(label)
	var combo_font = preload("res://assets/fonts/MPLUSRounded1c-Black.ttf")
	label.add_theme_font_override("font", combo_font)
	label.add_theme_color_override(
	"font_outline_color",
	Color(0.3, 0.15, 0.0, 1.0)
	)
	label.add_theme_constant_override("outline_size", 6)

	label.text = str(amount) + " KEYS" #🗝
	label.global_position = pos
	label.z_index = 10
	label.add_theme_font_size_override("font_size", 56)
	label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	label.pivot_offset = Vector2(label.size.x / 2.0, label.size.y / 2.0)
	label.scale = Vector2.ZERO

	# Punch-in entrance before the existing float-up-and-fade
	var punch = create_tween()
	punch.tween_property(label, "scale", Vector2(1.3, 1.3), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	punch.tween_property(label, "scale", Vector2.ONE, 0.1)

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position", pos + Vector2(0, -250), 1.5).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 1.5).set_ease(Tween.EASE_IN)
	tween.tween_callback(label.queue_free).set_delay(1.5)

func _spawn_merge_puff(pos: Vector2, tier: int):

	var puff = Sprite2D.new()
	fruit_container.add_child(puff)

	puff.texture = load("res://assets/sprites/poof.png")
	puff.global_position = pos

	puff.modulate = _get_tier_color(tier)

	puff.scale = Vector2(0.6, 0.6)

	var tween = create_tween()
	tween.set_parallel(true)

	tween.tween_property(
		puff,
		"scale",
		Vector2(1.8, 1.8),
		0.30
	).set_ease(Tween.EASE_OUT)

	tween.tween_property(
		puff,
		"modulate:a",
		0.0,
		0.30
	)

	tween.tween_callback(puff.queue_free)
	var mist = Sprite2D.new()
	fruit_container.add_child(mist)

	mist.texture = load("res://assets/sprites/poof_inner.png")
	mist.global_position = pos

	mist.modulate = _get_tier_color(tier)

	mist.scale = Vector2(0.4, 0.4)

	var mist_tween = create_tween()
	mist_tween.set_parallel(true)

	mist_tween.tween_property(
		mist,
		"scale",
		Vector2(2.3, 2.3),
		0.40
	)

	mist_tween.tween_property(
		mist,
		"modulate:a",
		0.0,
		0.40
	)

	mist_tween.tween_callback(mist.queue_free)
	
func _spawn_merge_sparkle(pos: Vector2):
	var sparkle_tex = preload("res://assets/sprites/sparkle.png")
	var colors = [
		Color(1.0, 0.85, 0.2, 0.5),
		Color(1.0, 0.4, 0.2, 0.5),
		Color(0.4, 0.9, 0.3, 0.5),
		Color(1.0, 0.5, 0.8, 0.5),
		Color(0.5, 0.8, 1.0, 0.5),
	]

	for i in 4:
		var spark = Sprite2D.new()
		add_child(spark)
		spark.texture = sparkle_tex
		spark.z_index = 200
		# Distribute along the width of the title
		spark.global_position = pos
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
	
func can_activate_powerup(type: int) -> bool:
	match type:
		GameManager.PowerupType.RIPPLE:
			var tier_counts = {}
			for fruit in fruit_container.get_children():
				if not fruit.has_method("apply_poison"):
					continue
				if fruit == current_fruit:
					continue
				if not fruit.is_placed:
					continue
				if not fruit.can_merge:
					continue
				if fruit.is_merging_now:
					continue
				if fruit.state == fruit.FruitState.ROTTEN:
					continue
				var tier = fruit.fruit_data.tier
				tier_counts[tier] = tier_counts.get(tier, 0) + 1
			for tier in tier_counts:
				if tier_counts[tier] >= 2:
					return true
			return false
			
		GameManager.PowerupType.PURGE:
			for fruit in fruit_container.get_children():
				if fruit.has_method("apply_poison") \
				and fruit.state == fruit.FruitState.ROTTEN:
					return true
			return false
		GameManager.PowerupType.CURE:
			for fruit in fruit_container.get_children():
				if fruit.has_method("apply_poison") \
				and (fruit.state == fruit.FruitState.WARNING or fruit.state == fruit.FruitState.ROTTEN):
					return true
			return false
		GameManager.PowerupType.PLUCK:
			for fruit in fruit_container.get_children():
				if fruit.has_method("apply_poison"):
					return true
			return false
		GameManager.PowerupType.BOMB:
			for fruit in fruit_container.get_children():
				if fruit.has_method("apply_poison"):
					return true
			return false
	return true
	
func _game_can_use_powerup(type: int) -> bool:
	var game = get_tree().get_first_node_in_group("game")
	if not game:
		return false
	return game.can_activate_powerup(type)
	
func try_activate_powerup(type: int) -> bool:
	if !can_activate_powerup(type):
		return false
	if !GameManager.use_powerup(type):
		return false
	activate_powerup(type)
	return true

func _on_ad_requested(type):
	AdsManager.show_rewarded_ad(type)

func _on_rewarded_earned(type):
	await get_tree().create_timer(0.5).timeout
	GameManager.add_coins_from_ad(type)

func _on_rewarded_failed(type):
	print("Ad not ready yet — try again in a moment")
	can_drop = true
# ─────────────────────────────────────────────
# CELEBRATIONS
# ─────────────────────────────────────────────

func _on_milestone_reached(tier: int, score_value: int):
	if GameManager.state == GameManager.GameState.GAME_OVER:
		return
	sfx_milestone.stream = _milestone_sfx
	sfx_milestone.pitch_scale = 1.0 + (tier - 1) * 0.03
	sfx_milestone.play()
	trigger_camera_pulse(0.03, 0.25)
	_flash_vignette_gold()
	var score_world_pos = hud.get_score_world_position()
	if score_world_pos != Vector2.ZERO:
		_spawn_celebration_burst(score_world_pos, Color(1.0, 0.85, 0.2, 1.0))
	if score_value < 3000:
		_spawn_banner_label(str(score_value) + " POINTS!", Color(0.959, 0.805, 0.0, 1.0), 0.30)
	elif score_value < 10000:
		_spawn_banner_label(str(score_value) + " POINTS!", Color(1.0, 0.931, 0.673, 1.0), 0.30)
	else:
		_spawn_banner_label(str(score_value) + " POINTS!", Color(0.888, 0.974, 0.87, 1.0), 0.30)

func _on_new_best_reached(_score: int):
	if GameManager.state == GameManager.GameState.GAME_OVER:
		return
	sfx_new_best.stream = _new_best_sfx
	sfx_new_best.pitch_scale = 1.0
	sfx_new_best.play()
	trigger_camera_pulse(0.06, 0.35)
	_flash_vignette_gold(true)
	_spawn_banner_label("NEW BEST!", Color(1.0, 0.982, 0.698, 1.0), 0.42, true)
	background.swing_bulb()

func _on_tier_unlocked(tier: int):
	if GameManager.state == GameManager.GameState.GAME_OVER:
		return
	if tier < 1 or tier > fruit_data_list.size():
		return
	sfx_milestone.stream = _tier_unlock_sfx
	sfx_milestone.pitch_scale = 0.95
	sfx_milestone.play()
	trigger_camera_pulse(0.03, 0.2)
	_spawn_fruit_unlock_banner(fruit_data_list[tier - 1].texture)

func _flash_vignette_gold(strong: bool = false):
	var mat = vignette.material
	var original_color = mat.get_shader_parameter("vignette_color")
	var original_intensity = mat.get_shader_parameter("intensity")
	var gold = Color(1.0, 0.82, 0.2, 1.0)
	var peak_intensity = 0.55 if strong else 0.35

	mat.set_shader_parameter("vignette_color", gold)

	var flash_in = create_tween()
	flash_in.tween_method(
		func(v): mat.set_shader_parameter("intensity", v),
		original_intensity, peak_intensity, 0.15
	).set_trans(Tween.TRANS_SINE)

	await flash_in.finished
	await get_tree().create_timer(0.2 if strong else 0.1).timeout

	var flash_out = create_tween()
	flash_out.set_parallel(true)
	flash_out.tween_method(
		func(v): mat.set_shader_parameter("vignette_color", v),
		gold, original_color, 0.5
	).set_trans(Tween.TRANS_CUBIC)
	flash_out.tween_method(
		func(v): mat.set_shader_parameter("intensity", v),
		peak_intensity, original_intensity, 0.5
	).set_trans(Tween.TRANS_CUBIC)

func _spawn_celebration_burst(pos: Vector2, color: Color):
	var sparkle_tex = preload("res://assets/sprites/sparkle.png")
	for i in 12:
		var spark = Sprite2D.new()
		ui_layer.add_child(spark)
		spark.texture = sparkle_tex
		spark.z_index = 300
		spark.global_position = pos
		spark.modulate = color if i % 2 == 0 else Color(0.9, 0.9, 1.0, 1.0)
		spark.scale = Vector2(0.7, 0.7)
		var angle = (TAU / 12.0) * i
		var dist = randf_range(80.0, 170.0)
		var target = pos + Vector2(cos(angle), sin(angle)) * dist
		var t = create_tween()
		t.set_parallel(true)
		t.tween_property(spark, "global_position", target, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t.tween_property(spark, "scale", Vector2(1.4, 1.4), 0.15)
		t.tween_property(spark, "scale", Vector2.ZERO, 0.3).set_delay(0.2)
		t.tween_property(spark, "modulate:a", 0.0, 0.3).set_delay(0.2)
		t.tween_callback(spark.queue_free).set_delay(0.55)

	var ring = Sprite2D.new()
	ui_layer.add_child(ring)
	ring.texture = _ring_tex
	ring.global_position = pos
	ring.z_index = 299
	ring.modulate = Color(color.r, color.g, color.b, 0.7)
	ring.scale = Vector2(0.1, 0.1)
	var rt = create_tween()
	rt.set_parallel(true)
	rt.tween_property(ring, "scale", Vector2(5.0, 5.0), 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	rt.tween_property(ring, "modulate:a", 0.0, 0.35).set_ease(Tween.EASE_IN)
	rt.tween_callback(ring.queue_free).set_delay(0.45)

func _spawn_banner_label(text: String, color: Color, y_ratio: float, big: bool = false):
	var label = Label.new()
	ui_layer.add_child(label)
	var font = load("res://assets/fonts/ArchivoBlack-Regular.ttf")
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", 50 if big else 40)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.0))
	label.add_theme_constant_override("outline_size", 5 if big else 3)
	label.text = text
	label.z_index = 300

	await get_tree().process_frame

	var viewport_size = get_viewport_rect().size
	label.pivot_offset = label.size / 2.0
	label.global_position = Vector2(
		(viewport_size.x - label.size.x) / 2.0,
		viewport_size.y * y_ratio
	)
	label.modulate.a = 0.0
	label.scale = Vector2(0.3, 0.3) if big else Vector2(0.5, 0.5)

	var t = create_tween()
	t.set_parallel(true)
	t.tween_property(label, "modulate:a", 1.0, 0.15 if big else 0.2)
	t.tween_property(label, "scale", Vector2(2.0, 2.0) if big else Vector2(1.5, 1.5), 0.3 if big else 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await t.finished

	var settle = create_tween()
	settle.tween_property(label, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	await settle.finished

	await get_tree().create_timer(1.0 if big else 0.8).timeout

	var fade = create_tween()
	fade.set_parallel(true)
	fade.tween_property(label, "modulate:a", 0.0, 0.4)
	fade.tween_property(label, "global_position:y", label.global_position.y - 60.0, 0.4).set_trans(Tween.TRANS_SINE)
	fade.tween_callback(label.queue_free).set_delay(0.45)

func _spawn_fruit_unlock_banner(tex: Texture2D):
	var container = HBoxContainer.new()
	ui_layer.add_child(container)
	container.z_index = 300
	container.modulate.a = 0.0
	container.add_theme_constant_override("separation", 10)

	var icon = TextureRect.new()
	icon.texture = tex
	icon.custom_minimum_size = Vector2(48, 48)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	container.add_child(icon)

	var label = Label.new()
	var font = load("res://assets/fonts/SubtitleStuff.ttf")
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", Color(0.983, 0.974, 0.561, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.002, 0.017, 0.0, 1.0))
	label.add_theme_constant_override("outline_size", 3)
	label.text = "NEW FRUIT UNLOCKED!"
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	container.add_child(label)

	await get_tree().process_frame

	var viewport_size = get_viewport_rect().size
	container.pivot_offset = container.size / 2.0
	container.global_position = Vector2(
		(viewport_size.x - container.size.x) / 2.0,
		viewport_size.y * 0.16
	)
	container.scale = Vector2(0.6, 0.6)

	var t = create_tween()
	t.set_parallel(true)
	t.tween_property(container, "modulate:a", 1.0, 0.2)
	t.tween_property(container, "scale", Vector2(1.08, 1.08), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await t.finished

	var settle = create_tween()
	settle.tween_property(container, "scale", Vector2.ONE, 0.15)
	await settle.finished

	_spawn_celebration_burst(container.global_position + container.size / 2.0, Color(0.6, 1.0, 0.5, 1.0))

	await get_tree().create_timer(1.0).timeout

	var fade = create_tween()
	fade.set_parallel(true)
	fade.tween_property(container, "modulate:a", 0.0, 0.4)
	fade.tween_property(container, "global_position:y", container.global_position.y - 40.0, 0.4).set_trans(Tween.TRANS_SINE)
	fade.tween_callback(container.queue_free).set_delay(0.45)
	
func notify_board_changed():
	emit_signal("board_state_changed")

func _play_merge_pop(tier: int):
	# Pick the right tier sound
	# tier 1-3 → pop1, 4-6 → pop2, 7-9 → pop3, 10-12 → pop4, 13-15 → pop5
	var band = 0
	if tier <= 3:
		band = 0
	elif tier <= 6:
		band = 1
	elif tier <= 9:
		band = 2
	elif tier <= 12:
		band = 3
	else:
		band = 4
	sfx_merge_pop.stream = _merge_pop_sfx[band]
	# Slight pitch randomization so repeated merges don't sound identical
	sfx_merge_pop.pitch_scale = randf_range(0.92, 1.08)
	# Higher tiers are slightly louder
	sfx_merge_pop.volume_db = lerp(-4.0, 2.0, float(tier) / 15.0)
	sfx_merge_pop.play()

func _play_powerup_sound(index: int):
	# Always play click immediately
	sfx_powerup_click.pitch_scale = randf_range(0.95, 1.05)
	sfx_powerup_click.play()

	# Cure (3) and Bomb (5) defer their specific sound to fruit selection
	# Pluck (2) and Purge (4) handle their own sounds in _on_fruit_selected
	# Shake (1) and Ripple (7) have no specific sound
	var defer_to_selection = [2, 3, 4, 5]
	if defer_to_selection.has(index):
		return

	# Non-selectmode powerups: play specific sound after short delay
	if _powerup_sfx.has(index):
		await get_tree().create_timer(0.08).timeout
		sfx_powerup_specific.stream = _powerup_sfx[index]
		sfx_powerup_specific.pitch_scale = 1.0
		sfx_powerup_specific.play()

func _play_select_merge_pop(tier: int):
	# Same band logic as normal merges but played
	# on the separate select player so it doesn't
	# interrupt any ongoing merge chain sounds
	var band = 0
	if tier <= 3:
		band = 0
	elif tier <= 6:
		band = 1
	elif tier <= 9:
		band = 2
	elif tier <= 12:
		band = 3
	else:
		band = 4

	sfx_select_merge_pop.stream = _merge_pop_sfx[band]
	# Slightly higher pitch for SelectMode — feels like
	# a targeted action rather than a physics merge
	sfx_select_merge_pop.pitch_scale = randf_range(1.05, 1.15)
	sfx_select_merge_pop.volume_db = -2.0
	sfx_select_merge_pop.play()
	
func _play_refresh_vignette():
	var mat = vignette.material
	var original_intensity = mat.get_shader_parameter("intensity")
	var red = Color(1.0, 0.0, 0.0, 1.0)
	var green = Color(0.2, 1.0, 0.4, 1.0)

	# Snap to green
	mat.set_shader_parameter("vignette_color", green)

	# Pulse intensity up slowly
	var tween = create_tween()
	tween.tween_method(
		func(v): mat.set_shader_parameter("intensity", v),
		original_intensity,
		0.7,
		0.4
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	await get_tree().create_timer(0.8).timeout

	# Fade back to red and lower intensity
	var reset = create_tween()
	reset.set_parallel(true)
	reset.tween_method(
		func(v): mat.set_shader_parameter("vignette_color", v),
		green,
		red,
		0.6
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	reset.tween_method(
		func(v): mat.set_shader_parameter("intensity", v),
		0.7,
		original_intensity,
		0.6
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

func _play_selection_pop(fruit):

	if not is_instance_valid(fruit):
		return

	var start_pos = fruit.global_position
	var sprite = fruit.get_node("Sprite2D")

	var tween = create_tween()
	tween.set_parallel(true)

	tween.tween_property(
		fruit,
		"global_position",
		start_pos + Vector2(0,-25),
		0.08
	)

	tween.tween_property(
		sprite,
		"scale",
		fruit.base_scale * Vector2(1.4,1.4),
		0.08
	)

	await tween.finished

	var settle = create_tween()
	settle.tween_property(
		sprite,
		"scale",
		fruit.base_scale * Vector2(1.15,1.15),
		0.06
	)

	await settle.finished


func _spawn_reaction_popup(
	pos: Vector2,
	combo: int
):

	var tex

	match combo:

		1:
			tex = reaction_textures[0]

		2:
			tex = reaction_textures[1]

		3:
			tex = reaction_textures[2]

		_:
			tex = reaction_textures[3]


	var popup = reaction_popup_scene.instantiate()

	fruit_container.add_child(popup)

	popup.global_position = pos + Vector2(
		0,
		-50
	)

	popup.setup(tex)

	popup.animate()

func show_ad_popup(type: int):
	var names = {
		GameManager.PowerupType.FREEZE: "Freeze",
		GameManager.PowerupType.SHAKE: "Shake",
		GameManager.PowerupType.PLUCK: "Pluck",
		GameManager.PowerupType.CURE: "Cure",
		GameManager.PowerupType.PURGE: "Purge",
		GameManager.PowerupType.BOMB: "Bomb",
		GameManager.PowerupType.REFRESH: "Refresh",
		GameManager.PowerupType.RIPPLE: "Ripple"
	}
	ad_popup.show_popup(type, names[type])

func _spawn_glow_wave(pos: Vector2, tier: int):
	var glow = Sprite2D.new()
	fruit_container.add_child(glow)
	glow.z_index = 999
	glow.global_position = pos
	glow.texture = _ring_tex
	glow.modulate = _get_tier_color(tier)
	glow.modulate.a = 0.5
	glow.scale = Vector2(0.03, 0.03)

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(glow, "scale", Vector2(2.5, 2.5), 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(glow, "modulate:a", 0.0, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(glow.queue_free).set_delay(0.12)

func trigger_camera_pulse(strength: float = 0.04, duration: float = 0.15):
	var original_zoom = camera.zoom
	var pulse_tween = create_tween()
	pulse_tween.tween_property(camera, "zoom", original_zoom * (1.0 + strength), duration * 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	pulse_tween.tween_property(camera, "zoom", original_zoom, duration * 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
