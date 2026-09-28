extends Node2D

@onready var sticker = $Sticker

var is_rare := false

func setup(tex: Texture2D, rare := false):
	is_rare = rare
	sticker.texture = tex
	scale = Vector2.ZERO
	modulate.a = 1.0
	sticker.rotation_degrees = randf_range(-12.0,12.0)
	if is_rare:
		sticker.scale *= 1.2

func animate():
	# POP IN — overshoot then settle
	var pop = create_tween()
	pop.tween_property(self, "scale", Vector2(1.3, 1.3), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(self, "scale", Vector2(0.95, 0.95), 0.07)
	pop.tween_property(self, "scale", Vector2(1.1, 1.1), 0.05)
	pop.tween_property(self, "scale", Vector2(1.0, 1.0), 0.04)

	# WOBBLE ROTATION — settle from tilt
	var wobble = create_tween()
	wobble.tween_property(sticker, "rotation_degrees", 0.0, 0.28).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	# HOLD then FLOAT UP and FADE
	await get_tree().create_timer(
		randf_range(0.3, 0.5)
	).timeout

	var exit = create_tween()
	exit.set_parallel(true)
	exit.tween_property(
		self,
		"global_position",
		global_position + Vector2(randf_range(-15, 15), -130),
		0.6
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	exit.tween_property(
		self,
		"scale",
		Vector2(0.8, 0.8),
		0.6
	).set_ease(Tween.EASE_IN)
	exit.tween_property(
		self,
		"modulate:a",
		0.0,
		0.5
	).set_delay(0.1).set_ease(Tween.EASE_IN)
	exit.finished.connect(queue_free)
