extends CanvasLayer

signal fruit_selected(fruit)
signal selection_cancelled

@onready var root = $Root
@onready var cancel_button = $Root/CancelButton
@onready var selection_fx = $Root/SelectionFX
@onready var hint_panel = $Root/HintPanel
@onready var hint_label = $Root/HintPanel/MarginContainer/HBoxContainer/HintLabel
@onready var hint_icon = $Root/HintPanel/MarginContainer/HBoxContainer/Icon

var selecting = false
var selectable_filter = "any"
var back_layer: CanvasLayer = null

const HINT_Y = 500
const HINT_X = 100

func _ready():
	hide()
	back_layer = null
	cancel_button.pressed.connect(_cancel_selection)

func begin_selection(text: String, filter: String = "any", back: CanvasLayer = null):
	selecting = true
	selectable_filter = filter
	hint_label.text = text
	back_layer = back

	match filter:
		"rotten":
			hint_icon.texture = preload("res://assets/sprites/icons/bomb_icon.png")
		"fresh":
			hint_icon.texture = preload("res://assets/sprites/icons/pluck_icon.png")
		"poisoned":
			hint_icon.texture = preload("res://assets/sprites/icons/cure_icon.png")
		"any":
			hint_icon.texture = preload("res://assets/sprites/icons/purge_icon.png")

	# Show and animate hint panel
	hint_panel.position = Vector2(-600, HINT_Y)
	hint_panel.modulate.a = 1.0

	# Show front layer
	show()
	root.modulate.a = 0.0

	# Show back layer
	if back_layer:
		back_layer.show()
		back_layer.get_node("Root/DarkOverlay").modulate.a = 0.0
		back_layer.get_node("Root/BlurOverlay").modulate.a = 0.0

	# Animate hint in
	var hint_tween = create_tween()
	hint_tween.tween_property(hint_panel, "position", Vector2(HINT_X, HINT_Y), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	hint_tween.tween_interval(2.0)
	hint_tween.tween_property(hint_panel, "position:x", -600, 0.30).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)

	# Pulse selectable fruits
	for fruit in get_tree().get_nodes_in_group("fruit"):
		if not fruit.is_placed:
			continue
		if _passes_filter(fruit):
			_start_fruit_pulse(fruit)
			fruit.set_glow(true, 0.5)

	# Fade in front
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(root, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# Fade in back overlays
	if back_layer:
		var dark = back_layer.get_node("Root/DarkOverlay")
		var blur = back_layer.get_node("Root/BlurOverlay")
		tween.tween_property(dark, "modulate:a", 0.55, 0.18)
		tween.tween_property(blur, "modulate:a", 0.75, 0.18)

func end_selection():
	selecting = false

	# Stop fruit pulses
	for fruit in get_tree().get_nodes_in_group("fruit"):
		if fruit.has_meta("selection_tween"):
			var t = fruit.get_meta("selection_tween")
			if t:
				t.kill()
			fruit.remove_meta("selection_tween")
			fruit.remove_meta("selection_pulsing")
			fruit.set_glow(false)
			var sprite = fruit.get_node("Sprite2D")
			sprite.scale = fruit.base_scale

	# Fade out front
	var tween = create_tween()
	tween.tween_property(root, "modulate:a", 0.0, 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)

	# Fade out back
	if back_layer:
		var fade = create_tween()
		fade.set_parallel(true)
		fade.tween_property(back_layer.get_node("Root/DarkOverlay"), "modulate:a", 0.0, 0.15)
		fade.tween_property(back_layer.get_node("Root/BlurOverlay"), "modulate:a", 0.0, 0.15)

	await tween.finished
	hide()
	if back_layer:
		back_layer.hide()
	back_layer = null

func _input(event):
	if not selecting:
		return
	if event is InputEventScreenTouch:
		if not event.pressed:
			return
		_try_select(event.position)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_try_select(event.position)

func _try_select(screen_pos: Vector2) -> void:
	var world_pos = get_viewport().canvas_transform.affine_inverse() * screen_pos
	var params = PhysicsPointQueryParameters2D.new()
	params.position = world_pos
	params.collide_with_areas = false
	params.collide_with_bodies = true
	var space_state = get_viewport().world_2d.direct_space_state
	var result = space_state.intersect_point(params)
	if result.is_empty():
		return
	for hit in result:
		var body = hit.collider
		if not body:
			continue
		if not body.has_method("apply_poison"):
			continue
		if body == get_parent().current_fruit:
			continue
		if not body.is_placed:
			continue
		if not _passes_filter(body):
			continue
		selecting = false
		_play_selection_feedback(body)
		await get_tree().create_timer(0.12).timeout
		_select_effect(body.global_position)
		emit_signal("fruit_selected", body)
		end_selection()
		return

func _passes_filter(fruit) -> bool:
	match selectable_filter:
		"rotten": return fruit.state == fruit.FruitState.ROTTEN
		"fresh": return fruit.state != fruit.FruitState.ROTTEN
		"poisoned": return fruit.is_poisoned
		"any": return true
	return true

func _cancel_selection():
	emit_signal("selection_cancelled")
	end_selection()

func _select_effect(pos: Vector2):
	var flash = ColorRect.new()
	selection_fx.add_child(flash)
	flash.color = Color(1, 1, 1, 0.8)
	flash.size = Vector2(90, 90)
	flash.pivot_offset = flash.size / 2
	flash.global_position = pos - flash.size / 2
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(flash, "scale", Vector2(1.8, 1.8), 0.18)
	tween.tween_property(flash, "modulate:a", 0.0, 0.18)
	tween.tween_callback(flash.queue_free)

func _start_fruit_pulse(fruit):
	if fruit.has_meta("selection_pulsing"):
		return
	fruit.set_meta("selection_pulsing", true)
	var sprite = fruit.get_node("Sprite2D")
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(sprite, "scale", fruit.base_scale * Vector2(1.08, 1.08), 0.45)
	tween.tween_property(sprite, "scale", fruit.base_scale, 0.45)
	fruit.set_meta("selection_tween", tween)

func _play_selection_feedback(fruit):
	var sprite = fruit.get_node("Sprite2D")
	var original_scale = sprite.scale
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "scale", original_scale * Vector2(1.18, 1.18), 0.07)
	tween.tween_property(sprite, "rotation_degrees", randf_range(-8, 8), 0.07)
	await tween.finished
	var tween2 = create_tween()
	tween2.set_parallel(true)
	tween2.tween_property(sprite, "scale", original_scale, 0.08)
	tween2.tween_property(sprite, "rotation_degrees", 0, 0.08)
	await tween2.finished

func _spawn_hint_sparkle():
	if not selecting:
		return
	var star = Sprite2D.new()
	root.add_child(star)
	star.texture = preload("res://assets/sprites/sparkle.png")
	star.scale = Vector2(0.15, 0.15)
	var pos = hint_panel.global_position
	star.global_position = pos + Vector2(randf_range(-20, hint_panel.size.x + 20), randf_range(-10, hint_panel.size.y + 10))
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(star, "scale", Vector2(0.45, 0.45), 0.4)
	tween.tween_property(star, "modulate:a", 0.0, 0.4)
	tween.tween_callback(star.queue_free)
