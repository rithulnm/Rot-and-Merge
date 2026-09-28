extends Control

@onready var bulb_sprite = $Bulb/BulbSprite
@onready var bulb_light = $Bulb/BulbLight
@onready var flies = $Flies
@onready var far_sprite: TextureRect = $Control/FarSprite
@onready var mid_sprite: TextureRect = $Control/MidSprite
@onready var front_sprite: TextureRect = $Control/FrontSprite
@onready var counter: TextureRect = $Control/Counter


const SKIN_PATHS = [

	"res://assets/data/skins/skin_kitchen.tres",

	"res://assets/data/skins/skin_rooftop.tres",

	"res://assets/data/skins/skin_bedroom.tres",

	"res://assets/data/skins/skin_forest.tres",

	"res://assets/data/skins/skin_cafe.tres"

]

var bulb_normal = preload("res://assets/sprites/background/bulb.png")
var bulb_flicker = preload("res://assets/sprites/background/bulb_flicker.png")

var bulb_flickering: bool = false
var bulb_flicker_timer: float = 0.0

var fly_angles: Array = [0.0, 2.0, 4.0]
var fly_radii: Array = [80.0, 100.0, 60.0]
var fly_speeds: Array = [1.2, 0.9, 1.5]
var fly_center: Vector2 = Vector2(0, -500)
var flies_active: bool = false
var rotten_count: int = 0

func _ready():
	apply_skin()
	GameManager.skin_changed.connect(_on_skin_changed)
	for i in $Flies.get_child_count():
		$Flies.get_child(i).visible = false

func _process(delta):
	_update_bulb(delta)
	_update_flies(delta)

func _update_bulb(delta):
	if bulb_flickering:
		bulb_flicker_timer -= delta
		var flicker = sin(Time.get_ticks_msec() * 0.05) > 0.3
		bulb_sprite.texture = bulb_flicker if flicker else bulb_normal
		bulb_light.energy = 0.4 + randf() * 0.3
		if bulb_flicker_timer <= 0:
			bulb_flickering = false
			bulb_sprite.texture = bulb_normal
			bulb_light.energy = 1.2
	else:
		var subtle = sin(Time.get_ticks_msec() * 0.001) * 0.05
		bulb_light.energy = 1.2 + subtle

func start_flicker(duration: float = 2.0):
	bulb_flickering = true
	bulb_flicker_timer = duration

func swing_bulb():
	var tween = create_tween()
	tween.tween_property($Bulb, "rotation_degrees", 8.0, 0.15)
	tween.tween_property($Bulb, "rotation_degrees", -20.0, 0.2)
	tween.tween_property($Bulb, "rotation_degrees", 10.0, 0.15)
	tween.tween_property($Bulb, "rotation_degrees", 0.0, 0.3).set_ease(Tween.EASE_OUT)

func _update_flies(delta):
	if not flies_active:
		return
	for i in $Flies.get_child_count():
		fly_angles[i] += fly_speeds[i] * delta
		var fly = $Flies.get_child(i)
		fly.position = fly_center + Vector2(
			cos(fly_angles[i]) * fly_radii[i],
			sin(fly_angles[i]) * fly_radii[i] * 0.4
		)
		fly.rotation = fly_angles[i] + PI

func set_rotten_count(count: int):
	rotten_count = count
	if count > 0 and not flies_active:
		_show_flies(count)
	elif count == 0 and flies_active:
		_hide_flies()

func _show_flies(count: int):
	flies_active = true
	var show_count = min(count, $Flies.get_child_count())
	for i in $Flies.get_child_count():
		$Flies.get_child(i).visible = i < show_count

func _hide_flies():
	flies_active = false
	for i in $Flies.get_child_count():
		$Flies.get_child(i).visible = false

func apply_skin():

	var skin = load(
		SKIN_PATHS[
			GameManager.current_skin
		]
	)

	if skin == null:
		return


	far_sprite.texture =skin.far_texture

	mid_sprite.texture =skin.mid_texture

	front_sprite.texture =skin.front_texture

	counter.texture = skin.counter_texture

func _on_skin_changed(_index):
	apply_skin()

func pulse_light_bloom(strength: float = 0.5, duration: float = 0.10):
	var original_energy = bulb_light.energy
	var bloom_tween = create_tween()
	bloom_tween.tween_property(bulb_light, "energy", original_energy + strength, duration * 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	bloom_tween.tween_property(bulb_light, "energy", original_energy, duration * 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

func hide_all():
	far_sprite.modulate = Color(0, 0, 0)
	mid_sprite.modulate = Color(0, 0, 0)
	front_sprite.modulate = Color(0, 0, 0)
	counter.modulate = Color(0, 0, 0)
	bulb_light.energy = 0.0

func reveal(canvas_mod: CanvasModulate, duration: float = 1.2):
	var t = create_tween()
	t.set_parallel(true)
	t.tween_property(canvas_mod, "color", Color("#3a3d46"), duration).set_ease(Tween.EASE_OUT)
	t.tween_property(far_sprite, "modulate", Color(1, 1, 1), duration * 0.85).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(mid_sprite, "modulate", Color(1, 1, 1), duration * 0.85).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(front_sprite, "modulate", Color(1, 1, 1), duration * 0.85).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(counter, "modulate", Color(1, 1, 1), duration * 0.85).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(bulb_light, "energy", 1.2, duration * 1.25).set_ease(Tween.EASE_OUT)

func get_bulb() -> Node2D:
	return $Bulb

func set_bulb_energy(energy: float):
	bulb_light.energy = energy
