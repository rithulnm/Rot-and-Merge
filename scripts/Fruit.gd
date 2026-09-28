extends RigidBody2D

signal merge_requested(other, self_fruit)
signal fully_rotten(fruit)

enum FruitState {
	FRESH,
	WARNING,
	ROTTEN
}

@onready var sprite = $Sprite2D
@onready var collision = $CollisionShape2D
@onready var rot_timer = $RotTimer
@onready var face = $Face
@onready var light: PointLight2D = $PointLight2D

var is_menu_fruit := false
var spawn_protection := true
var merge_cooldown := true
var is_merging_now := false

var base_scale: Vector2 = Vector2.ONE
var squash_scale: Vector2 = Vector2.ONE
var prev_velocity: Vector2 = Vector2.ZERO

var fruit_data: FruitData
var state: FruitState = FruitState.FRESH
var rot_progress: float = 0.0
var is_poisoned: bool = false
var poison_speed_multiplier: float = 1.0
var can_merge: bool = true
var is_placed: bool = false
var anticipation_target: Vector2 = Vector2.ZERO
var is_anticipating: bool = false
var touching_fruits := {}
var _eye_update_timer: float = 0.0
var _anticipation_scan_timer: float = 0.0
var _last_visual_state: int = -1
var _land_sound_cooldown: float = 0.0

const MERGE_TOUCH_TIME := 0.08
const STICK_FORCE := 120.0
const WARNING_THRESHOLD = 0.6

func _ready():
	add_to_group("fruit")

	if !body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	if !body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)
		
func setup(data: FruitData):
	
	center_of_mass_mode = RigidBody2D.CENTER_OF_MASS_MODE_AUTO
	fruit_data = data
	var new_shape = CircleShape2D.new()
	new_shape.radius = data.radius
	collision.shape = new_shape
	base_scale = Vector2.ONE * (fruit_data.radius / 128.0)
	sprite.scale = base_scale
	sprite.material = null
	mass = data.radius * 0.05
	rot_timer.wait_time = data.rot_duration
	if data.texture:
		sprite.texture = data.texture
	var skin_paths = [
		"res://assets/data/skins/skin_kitchen.tres",
		"res://assets/data/skins/skin_rooftop.tres",
		"res://assets/data/skins/skin_bedroom.tres",
		"res://assets/data/skins/skin_forest.tres",
		"res://assets/data/skins/skin_cafe.tres"
	]
	var current_skin = load(skin_paths[GameManager.current_skin])
	if current_skin:
		var tier_index = data.tier - 1
		if tier_index < current_skin.fruit_textures.size():
			var skin_tex = current_skin.fruit_textures[tier_index]
			if skin_tex:
				sprite.texture = skin_tex
				
	_update_visuals()
	if not is_menu_fruit:
		light.energy = 0.0
	if is_menu_fruit:
		face.set_preview(true)
	var face_base = clamp(
	fruit_data.radius / 40.0,
	0.55,
	1.4
)

	face.scale = Vector2.ONE * face_base * squash_scale
	# Setup unique face per fruit
	face.setup_face(
	data.face_eye_type,
	data.face_mouth_default,
	data.face_eye_separation,
	data.face_eye_height,
	data.face_eye_scale,
	data.face_pupil_scale,
	data.face_mouth_position,
	data.face_mouth_scale
	)
	face.set_personality(data.face_personality)
	
func activate(from_merge: bool = false):
	is_placed = true
	freeze = false
	rot_timer.start()
	can_merge = true

	if from_merge:
		# Clear immediately — chain-merged fruits must be able to merge at once
		spawn_protection = false
		merge_cooldown = false

	await get_tree().physics_frame
	force_merge_scan()

	if not from_merge:
		await get_tree().create_timer(0.10).timeout
		spawn_protection = false
		merge_cooldown = false
		can_merge = true
		force_merge_scan()  # re-scan after protections drop for regular drops

	face.set_preview(false)
	face.play_drop_reaction()
	var game = get_tree().get_first_node_in_group("game")
	if game:
		game.notify_board_changed()
	_check_merge_anticipation(0.0)
	
func _on_body_entered(body):
	if not body.has_method("attempt_merge"):
		return
	attempt_merge(body)


func _on_body_exited(body):
	if touching_fruits.has(body):
		touching_fruits.erase(body)
		
func _physics_process(delta):
	_land_sound_cooldown -= delta
	_check_merge_anticipation(delta)
	if is_anticipating:
		var wobble = sin(Time.get_ticks_msec() * 0.01) * 2.0
		apply_central_force(anticipation_target * wobble * 15.0)
	if not is_placed:
		return
	if state == FruitState.ROTTEN:
		return
	var impact = prev_velocity.y - linear_velocity.y
	if impact > 200:
		var squash = clamp(impact / 1000.0, 0.0, 0.15)
		squash_scale = Vector2(1.0 + squash * 0.5, 1.0 - squash * 0.2)

		# Play land sound if cooldown allows
		if _land_sound_cooldown <= 0.0 and is_placed:
				var game = get_tree().get_first_node_in_group("game")
				if game:
					# Higher tier = lower pitch (heavier thud) + louder
					var tier_weight = clamp(float(fruit_data.tier) / 15.0, 0.0, 1.0)
					game.sfx_fruit_land.pitch_scale = randf_range(0.88, 1.12) - tier_weight * 0.3
					game.sfx_fruit_land.volume_db = lerp(-8.0, 2.0, clamp(impact / 800.0, 0.0, 1.0)) + tier_weight * 3.0
					game.sfx_fruit_land.play()
				_land_sound_cooldown = 0.4
	elif linear_velocity.y > 100:
		var stretch = clamp(linear_velocity.y / 1000.0, 0.0, 0.15)
		squash_scale = Vector2(1.0 - stretch * 0.15, 1.0 + stretch * 0.2)
	else:
		squash_scale = squash_scale.lerp(Vector2.ONE, 0.2)
	prev_velocity = linear_velocity
	sprite.scale = base_scale * squash_scale
	var face_base = clamp(
	fruit_data.radius / 40.0,
	0.55,
	1.4
)

	face.scale = Vector2.ONE * face_base * squash_scale
	
func _process(delta):
	if not is_placed:
		return
	if is_menu_fruit:
		return
	var elapsed = fruit_data.rot_duration - rot_timer.time_left
	rot_progress = clamp(elapsed / fruit_data.rot_duration * poison_speed_multiplier, 0.0, 1.0)
	if rot_progress >= WARNING_THRESHOLD and state == FruitState.FRESH:
		state = FruitState.WARNING
	_update_visuals()
	_eye_update_timer -= delta
	if _eye_update_timer <= 0.0:
		_eye_update_timer = 0.1
		_update_social_eyes()
																																							
func _update_visuals():
	match state:
		FruitState.FRESH:
			sprite.modulate = Color.WHITE
			if _last_visual_state != state:
				face.set_expression(0)
		FruitState.WARNING:
			var brown_mix = (rot_progress - WARNING_THRESHOLD) / (1.0 - WARNING_THRESHOLD)
			sprite.modulate = Color(1.0, 1.0 - brown_mix * 0.4, 1.0 - brown_mix * 0.6, 1.0)
			if _last_visual_state != state:
				face.set_expression(1)
		FruitState.ROTTEN:
			sprite.modulate = Color(0.25, 0.15, 0.05, 1.0)
			if _last_visual_state != state:
				face.set_expression(2)
	_last_visual_state = state

func apply_poison(multiplier: float):
	if state == FruitState.ROTTEN:
		return
	is_poisoned = true
	poison_speed_multiplier = max(poison_speed_multiplier, multiplier)

func _on_rot_timer_timeout():
	if state == FruitState.ROTTEN:
		return
	state = FruitState.ROTTEN
	can_merge = false
	emit_signal("fully_rotten", self)
	_spread_poison()
	_update_visuals()
	face.react_to_rot()
	
func _spread_poison():
	var space = get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	var shape = CircleShape2D.new()
	shape.radius = fruit_data.radius * 2.5
	query.shape = shape
	query.transform = global_transform
	query.collision_mask = 1
	var results = space.intersect_shape(query, 16)
	var spread_count = 0
	for result in results:
		if spread_count >= fruit_data.poison_spread_count:
			break
		var body = result.collider
		if body == self:
			continue
		if body.has_method("apply_poison"):
			body.apply_poison(1.5)
			spread_count += 1

func attempt_merge(other):
	if is_menu_fruit:
		return
	if is_merging_now:
		return
	if other.is_merging_now:
		return
	if spawn_protection:
		return
	if other.spawn_protection:
		return
	if merge_cooldown:
		return
	if other.merge_cooldown:
		return
	if not can_merge:
		return
	if not other.can_merge:
		return
	if state == FruitState.ROTTEN:
		return
	if other.state == FruitState.ROTTEN:
		return
	if fruit_data.tier != other.fruit_data.tier:
		return
	if fruit_data.tier > 15:
		return
	is_merging_now = true
	other.is_merging_now = true
	can_merge = false
	other.can_merge = false
	emit_signal("merge_requested", other, self)

func set_eye_target(world_pos: Vector2):
	if face:
		face.set_track_target(world_pos)

func clear_eye_target():
	if face:
		face.stop_tracking()

func _check_merge_anticipation(delta: float):
	# Clean stale refs
	for fruit in touching_fruits.keys():
		if not is_instance_valid(fruit):
			touching_fruits.erase(fruit)

	if not is_placed or not can_merge or spawn_protection or state == FruitState.ROTTEN:
		is_anticipating = false
		return

	_anticipation_scan_timer -= delta
	if _anticipation_scan_timer <= 0.0:
		_anticipation_scan_timer = 0.1
		_rescan_anticipation_target()

	if is_anticipating:
		apply_central_force(anticipation_target * STICK_FORCE)

func _rescan_anticipation_target():
	var space = get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	var shape = CircleShape2D.new()
	shape.radius = fruit_data.radius * 1.5
	query.shape = shape
	query.transform = global_transform
	query.collision_mask = 1
	var results = space.intersect_shape(query, 12)

	is_anticipating = false

	for result in results:
		var body = result.collider
		if body == self: continue
		if not body.has_method("attempt_merge"): continue
		if not body.can_merge: continue
		if body.spawn_protection: continue
		if body.state == FruitState.ROTTEN: continue
		if body.fruit_data.tier != fruit_data.tier: continue

		is_anticipating = true
		anticipation_target = (body.global_position - global_position).normalized()
		return
				
func set_glow(enabled: bool, energy: float = 1.0):
	light.energy = energy if enabled else 0.0

func apply_skin(tex: Texture2D):
	if tex:
		sprite.texture = tex

func _update_social_eyes():

	if not is_placed:
		return

	if state == FruitState.ROTTEN:
		return

	# Dropping fruit takes priority over neighbor-watching
	var game = get_tree().get_first_node_in_group("game")
	if game and game.current_fruit and is_instance_valid(game.current_fruit):
		face.set_track_target(game.current_fruit.global_position)
		return

	var nearest = null
	var nearest_dist = 99999

	for fruit in get_tree().get_nodes_in_group("fruit"):

		if fruit == self:
			continue

		var d = global_position.distance_to(
			fruit.global_position
		)

		if d < nearest_dist:

			nearest_dist = d
			nearest = fruit

	if nearest and nearest_dist < 180:

		face.set_track_target(
			nearest.global_position
		)

	else:

		face.stop_tracking()

func force_merge_scan():
	if not can_merge:
		return

	var space = get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	var shape = CircleShape2D.new()
	shape.radius = fruit_data.radius * 1.1  # tighter radius, only actual overlap
	query.shape = shape
	query.transform = global_transform
	query.collision_mask = 1
	var results = space.intersect_shape(query, 16)

	for result in results:
		var body = result.collider
		if body == self: continue
		if not body.has_method("attempt_merge"): continue
		if body.fruit_data.tier != fruit_data.tier: continue
		if not body.can_merge: continue
		if body.is_merging_now: continue
		if body.spawn_protection: continue
		if body.merge_cooldown: continue
		attempt_merge(body)
		return
