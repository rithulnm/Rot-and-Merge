extends Camera2D

var shake_strength := 0.0
var shake_fade := 8.0

func _process(delta):
	if shake_strength > 0:
		offset = Vector2(
			randf_range(-shake_strength, shake_strength),
			randf_range(-shake_strength, shake_strength)
		)

		shake_strength = lerp(shake_strength, 0.0, shake_fade * delta)

		if shake_strength < 0.1:
			shake_strength = 0
			offset = Vector2.ZERO


func shake(amount: float):
	shake_strength = amount
