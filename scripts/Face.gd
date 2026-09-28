extends Node2D

enum Personality {
	LAZY,
	HYPER,
	CURIOUS,
	HAPPY,
	SLEEPY
}

enum EyeType {
	ROUND,
	OVAL,
	WIDE,
	DROOPY,
	SHARP
}

enum MouthType {
	NEUTRAL,
	SMILE,
	OPEN,
	SMIRK,
	O,
	GRIN
}

@onready var left_eye: Node2D = $LeftEye
@onready var right_eye: Node2D = $RightEye
@onready var left_eye_white: Sprite2D = $LeftEye/EyeWhite
@onready var right_eye_white: Sprite2D = $RightEye/EyeWhite
@onready var left_pupil: Sprite2D = $LeftEye/Pupil
@onready var right_pupil: Sprite2D = $RightEye/Pupil
@onready var mouth: Sprite2D = $Mouth

var left_eye_base_scale: Vector2 = Vector2.ONE
var right_eye_base_scale: Vector2 = Vector2.ONE
var eye_textures: Dictionary = {}
var eye_closed_texture: Texture2D = null
var pupil_texture: Texture2D = null
var mouth_textures: Dictionary = {}
var _reacting: bool = false
var personality: int = Personality.HAPPY
var current_state: int = 0
var blinking: bool = false
var blink_timer: float = 0.0
var idle_timer: float = 0.0
var mouth_timer: float = 0.0
var bounce_time: float = 0.0
var preview_mode: bool = false
var base_position: Vector2 = Vector2.ZERO
var base_scale: Vector2 = Vector2.ONE
var idle_target: Vector2 = Vector2.ZERO
var max_pupil_offset: float = 6.0
var is_tracking: bool = false
var track_target: Vector2 = Vector2.ZERO

# Store original eye white texture for restoring after blink
var _stored_eye_texture: Texture2D = null
var _default_mouth_type: int = MouthType.NEUTRAL

func _ready():
	blink_timer = randf_range(2.0, 5.0)
	base_position = position
	base_scale = scale

	eye_textures = {
		EyeType.ROUND:  preload("res://assets/sprites/face/eyes/eye_round.png"),
		EyeType.OVAL:   preload("res://assets/sprites/face/eyes/eye_oval.png"),
		EyeType.WIDE:   preload("res://assets/sprites/face/eyes/eye_wide.png"),
		EyeType.DROOPY: preload("res://assets/sprites/face/eyes/eye_droopy.png"),
		EyeType.SHARP:  preload("res://assets/sprites/face/eyes/eye_sharp.png"),
	}

	eye_closed_texture = preload("res://assets/sprites/face/eyes/eye_closed.png")
	pupil_texture = preload("res://assets/sprites/face/eyes/pupil.png")

	mouth_textures = {
		MouthType.NEUTRAL: preload("res://assets/sprites/face/mouth/mouth_neutral.png"),
		MouthType.SMILE:   preload("res://assets/sprites/face/mouth/mouth_smile.png"),
		MouthType.OPEN:    preload("res://assets/sprites/face/mouth/mouth_open.png"),
		MouthType.SMIRK:   preload("res://assets/sprites/face/mouth/mouth_smirk.png"),
		MouthType.O:       preload("res://assets/sprites/face/mouth/mouth_o.png"),
		MouthType.GRIN:    preload("res://assets/sprites/face/mouth/mouth_grin.png"),
	}

	left_pupil.texture = pupil_texture
	right_pupil.texture = pupil_texture
	mouth.texture = mouth_textures[MouthType.NEUTRAL]

	_pick_idle_target()

func setup_face(
	eye_type: int,
	mouth_default: int,
	eye_sep: float,
	eye_h: float,
	eye_sc: Vector2,
	pupil_sc: Vector2,
	mouth_pos: Vector2,
	mouth_sc: Vector2
):
	_default_mouth_type = mouth_default
	_stored_eye_texture = eye_textures.get(eye_type)

	if _stored_eye_texture:
		left_eye_white.texture = _stored_eye_texture
		right_eye_white.texture = _stored_eye_texture

	left_pupil.texture = pupil_texture
	right_pupil.texture = pupil_texture

	left_eye.position = Vector2(-eye_sep, eye_h)
	right_eye.position = Vector2(eye_sep, eye_h)

	left_eye_white.scale = eye_sc
	right_eye_white.scale = eye_sc
	left_eye_base_scale = eye_sc
	right_eye_base_scale = eye_sc
	left_pupil.scale = pupil_sc
	right_pupil.scale = pupil_sc
	
	mouth.position = mouth_pos
	mouth.scale = mouth_sc
	mouth.texture = mouth_textures.get(mouth_default, mouth_textures[MouthType.NEUTRAL])

func set_personality(type: int):
	personality = type
	match personality:
		Personality.LAZY:
			idle_timer = randf_range(3.0, 5.0)
			blink_timer = randf_range(8.0, 13.0)
		Personality.HYPER:
			idle_timer = randf_range(0.5, 1.0)
			blink_timer = randf_range(3.5, 6.0)
		Personality.CURIOUS:
			idle_timer = randf_range(0.8, 1.8)
			blink_timer = randf_range(4.5, 7.5)
		Personality.HAPPY:
			idle_timer = randf_range(1.0, 2.0)
			blink_timer = randf_range(5.0, 8.5)
		Personality.SLEEPY:
			idle_timer = randf_range(4.0, 6.0)
			blink_timer = randf_range(6.0, 11.0)

func set_preview(enabled: bool):
	preview_mode = enabled

func set_track_target(world_pos: Vector2):
	is_tracking = true
	track_target = world_pos

func stop_tracking():
	is_tracking = false
	idle_target = Vector2.ZERO

func _process(delta):
	bounce_time += delta
	idle_timer -= delta
	mouth_timer -= delta
	blink_timer -= delta

	# Preview bounce
	if preview_mode:
		position.y = base_position.y + sin(bounce_time * 3.5) * 3.0
		scale = base_scale * (1.0 + sin(bounce_time * 4.0) * 0.03)
	else:
		position = base_position
		scale = base_scale

	# Idle target wander — personality drives how restless
	if idle_timer <= 0:
		_pick_idle_target()
		match personality:
			Personality.LAZY:   idle_timer = randf_range(2.5, 4.5)
			Personality.HYPER:  idle_timer = randf_range(0.2, 0.6)
			Personality.CURIOUS: idle_timer = randf_range(0.5, 1.2)
			Personality.HAPPY:  idle_timer = randf_range(0.8, 1.8)
			Personality.SLEEPY: idle_timer = randf_range(3.5, 6.0)

	# Mouth animation — more frequent for lively personalities
	if mouth_timer <= 0.0 and current_state == 0:
		_animate_mouth()
		match personality:
			Personality.HYPER:  mouth_timer = randf_range(0.4, 1.0)
			Personality.HAPPY:  mouth_timer = randf_range(0.8, 2.0)
			Personality.CURIOUS: mouth_timer = randf_range(1.0, 2.5)
			Personality.LAZY:   mouth_timer = randf_range(2.0, 4.0)
			Personality.SLEEPY: mouth_timer = randf_range(3.0, 6.0)

	_update_eyes(delta)

	# Blink
	if blink_timer <= 0 and not blinking:
		_blink()
		match personality:
			Personality.LAZY:   blink_timer = randf_range(8.0, 13.0)
			Personality.HYPER:  blink_timer = randf_range(3.5, 6.0)
			Personality.CURIOUS: blink_timer = randf_range(4.5, 7.5)
			Personality.HAPPY:  blink_timer = randf_range(5.0, 8.5)
			Personality.SLEEPY: blink_timer = randf_range(6.0, 11.0)

	# Hyper fruits do random double blink
	if personality == Personality.HYPER and current_state == 0 and not blinking:
		if randf() < 0.0002:   # was 0.001 — ~5x less frequent
			_double_blink()

	# Sleepy fruits occasionally droop eyes mid-game
	if personality == Personality.SLEEPY and current_state == 0 and not blinking:
		if randf() < 0.00008:   # was 0.0005 — ~6x less frequent
			_sleepy_droop()
			
func _update_eyes(delta):
	var left_target := Vector2.ZERO
	var right_target := Vector2.ZERO

	if is_tracking and track_target != Vector2.ZERO:
		var left_dir = (track_target - global_position - left_eye.position).normalized() * max_pupil_offset
		var right_dir = (track_target - global_position - right_eye.position).normalized() * max_pupil_offset
		left_target = left_dir
		right_target = right_dir

		# Tracking = faster eye movement, snappier
		var speed = 12.0 if personality == Personality.HYPER else 8.0
		left_pupil.position = left_pupil.position.lerp(left_target, delta * speed)
		right_pupil.position = right_pupil.position.lerp(right_target, delta * speed)
	else:
		left_target = idle_target
		right_target = idle_target

		# Idle = slow dreamy movement
		var speed = 4.0 if personality == Personality.HYPER else 2.5
		if personality == Personality.SLEEPY:
			speed = 1.0
		left_pupil.position = left_pupil.position.lerp(left_target, delta * speed)
		right_pupil.position = right_pupil.position.lerp(right_target, delta * speed)

	# Subtle head lean toward gaze direction
	var avg_pupil = (left_pupil.position + right_pupil.position) / 2.0
	rotation = lerp(rotation, clamp(avg_pupil.x * 0.012, -0.1, 0.1), delta * 3.0)
	
func _pick_idle_target():
	match personality:
		Personality.LAZY:
			# Barely moves — just a tiny drift
			idle_target = Vector2(randf_range(-1.5, 1.5), randf_range(0.0, 2.0))
		Personality.HYPER:
			# Darts around constantly
			idle_target = Vector2(
				randf_range(-max_pupil_offset, max_pupil_offset),
				randf_range(-max_pupil_offset, max_pupil_offset)
			)
		Personality.CURIOUS:
			# Looks side to side more than up/down
			idle_target = Vector2(
				randf_range(-max_pupil_offset, max_pupil_offset),
				randf_range(-max_pupil_offset * 0.3, max_pupil_offset * 0.3)
			)
		Personality.HAPPY:
			# Looks around warmly, slight upward bias
			idle_target = Vector2(
				randf_range(-max_pupil_offset * 0.7, max_pupil_offset * 0.7),
				randf_range(-max_pupil_offset * 0.5, max_pupil_offset * 0.3)
			)
		Personality.SLEEPY:
			# Eyes drift downward, barely side to side
			idle_target = Vector2(
				randf_range(-1.0, 1.0),
				randf_range(2.0, max_pupil_offset)
			)
			
func _animate_mouth():
	if blinking:
		return
	match personality:
		Personality.HAPPY:
			var options = [MouthType.SMILE, MouthType.GRIN, MouthType.SMILE]
			mouth.texture = mouth_textures[options[randi() % options.size()]]
		Personality.SLEEPY:
			mouth.texture = mouth_textures[MouthType.NEUTRAL]
		Personality.HYPER:
			var options = [MouthType.GRIN, MouthType.OPEN, MouthType.SMILE]
			mouth.texture = mouth_textures[options[randi() % options.size()]]
		Personality.CURIOUS:
			var options = [MouthType.SMIRK, MouthType.NEUTRAL, MouthType.O]
			mouth.texture = mouth_textures[options[randi() % options.size()]]
		Personality.LAZY:
			var options = [MouthType.NEUTRAL, MouthType.SMIRK]
			mouth.texture = mouth_textures[options[randi() % options.size()]]

func set_expression(state: int):
	current_state = state
	match state:
		0: # FRESH — restore normal
			if _stored_eye_texture:
				left_eye_white.texture = _stored_eye_texture
				right_eye_white.texture = _stored_eye_texture
			left_eye_white.scale = left_eye_base_scale
			right_eye_white.scale = right_eye_base_scale
			left_pupil.visible = true
			right_pupil.visible = true
			mouth.texture = mouth_textures.get(_default_mouth_type, mouth_textures[MouthType.NEUTRAL])
			
		1: # WARNING — eyes wide, pupils shrink
			left_eye_white.texture = eye_closed_texture
			right_eye_white.texture = eye_closed_texture
			left_pupil.visible = false
			right_pupil.visible = false
			mouth.texture = mouth_textures[MouthType.O]

		2: # ROTTEN — eyes closed, droopy mouth
			left_eye_white.texture = eye_closed_texture
			right_eye_white.texture = eye_closed_texture
			left_pupil.visible = false
			right_pupil.visible = false
			mouth.texture = mouth_textures[MouthType.NEUTRAL]

func _blink():
	if current_state != 0 or blinking:
		return
	await _do_single_blink()

func play_drop_reaction():
	if current_state == 2:
		return
	mouth.texture = mouth_textures[MouthType.O]
	var original_scale = scale
	var t = create_tween()
	t.tween_property(self, "scale", original_scale * 1.2, 0.08).set_trans(Tween.TRANS_BACK)
	t.tween_property(self, "scale", original_scale, 0.12).set_trans(Tween.TRANS_ELASTIC)
	await get_tree().create_timer(0.4).timeout
	if current_state == 0:
		mouth.texture = mouth_textures.get(_default_mouth_type, mouth_textures[MouthType.NEUTRAL])

func _double_blink():
	if blinking or current_state != 0:
		return
	await _do_single_blink()
	await get_tree().create_timer(0.08).timeout
	await _do_single_blink()

func _do_single_blink() -> void:
	if _reacting:
		return
	blinking = true
	_reacting = true

	var close_t = create_tween()
	close_t.set_parallel(true)
	close_t.tween_property(left_eye_white, "scale:y", left_eye_base_scale.y * 0.05, 0.09).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	close_t.tween_property(right_eye_white, "scale:y", right_eye_base_scale.y * 0.05, 0.09).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	left_pupil.visible = false
	right_pupil.visible = false
	await close_t.finished

	await get_tree().create_timer(0.16).timeout

	if current_state == 0:
		var open_t = create_tween()
		open_t.set_parallel(true)
		open_t.tween_property(left_eye_white, "scale:y", left_eye_base_scale.y, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		open_t.tween_property(right_eye_white, "scale:y", right_eye_base_scale.y, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		await open_t.finished
		left_pupil.visible = true
		right_pupil.visible = true

	blinking = false
	_reacting = false

func _sleepy_droop():
	if blinking or current_state != 0 or _reacting:
		return
	_reacting = true
	var t = create_tween()
	t.set_parallel(true)
	t.tween_property(left_eye_white, "scale:y", left_eye_base_scale.y * 0.35, 0.5).set_trans(Tween.TRANS_SINE)
	t.tween_property(right_eye_white, "scale:y", right_eye_base_scale.y * 0.35, 0.5).set_trans(Tween.TRANS_SINE)
	await t.finished
	await get_tree().create_timer(0.3).timeout
	var t2 = create_tween()
	t2.set_parallel(true)
	t2.tween_property(left_eye_white, "scale:y", left_eye_base_scale.y, 0.5).set_trans(Tween.TRANS_SINE)
	t2.tween_property(right_eye_white, "scale:y", right_eye_base_scale.y, 0.5).set_trans(Tween.TRANS_SINE)
	await t2.finished
	_reacting = false
	
func react_to_nearby_merge():
	if current_state == 2 or _reacting:
		return
	_reacting = true
	var prev_target = idle_target
	var prev_mouth = mouth.texture
	idle_target = Vector2(randf_range(-3, 3), -max_pupil_offset)
	if current_state == 0:
		mouth.texture = mouth_textures.get(MouthType.O, mouth.texture)
	await get_tree().create_timer(0.35).timeout
	if current_state == 0:
		idle_target = prev_target
		mouth.texture = prev_mouth
	_reacting = false
	
func react_to_rot():
	if current_state == 2:
		return
	# Eyes dart side to side nervously
	var t = create_tween()
	t.tween_property(left_pupil, "position:x", -max_pupil_offset, 0.1)
	t.tween_property(left_pupil, "position:x", max_pupil_offset, 0.1)
	t.tween_property(left_pupil, "position:x", 0.0, 0.1)
	var t2 = create_tween()
	t2.tween_property(right_pupil, "position:x", -max_pupil_offset, 0.1)
	t2.tween_property(right_pupil, "position:x", max_pupil_offset, 0.1)
	t2.tween_property(right_pupil, "position:x", 0.0, 0.1)
