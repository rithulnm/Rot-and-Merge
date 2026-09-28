extends Node2D

@onready var sprite = $Sprite2D

var velocity := Vector2.ZERO
var gravity := 900.0
var rotation_speed := 0.0

func setup(tex:Texture2D,start_velocity:Vector2):

	sprite.texture = tex

	velocity = start_velocity

	rotation_speed = randf_range(-900.0,900.0)

	scale = Vector2.ONE * randf_range(0.5,0.9)


func _process(delta):

	velocity.y += gravity * delta

	position += velocity * delta

	rotation_degrees += rotation_speed * delta

	modulate.a -= delta

	if modulate.a <= 0:
		queue_free()
