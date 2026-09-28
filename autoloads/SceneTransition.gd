extends CanvasLayer

@onready var fade_rect: ColorRect = $FadeRect

const FADE_OUT_TIME := 0.25
const FADE_IN_TIME := 0.3
const HOLD_TIME := 0.05  # brief pause on black, hides any residual load hitch

var _busy := false

func _ready() -> void:
	# Sit above absolutely everything, including other CanvasLayers.
	layer = 999
	fade_rect.color = Color(0, 0, 0, 0)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)


func change_scene(path: String) -> void:
	if _busy:
		return
	_busy = true
	await _fade_out()
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	await _fade_in()
	_busy = false


func reload_current_scene() -> void:
	if _busy:
		return
	_busy = true
	await _fade_out()
	get_tree().reload_current_scene()
	await get_tree().process_frame
	await get_tree().process_frame
	await _fade_in()
	_busy = false


func _fade_out() -> void:
	fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP  # block input while fading
	var t = create_tween()
	t.tween_property(fade_rect, "color:a", 1.0, FADE_OUT_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await t.finished
	await get_tree().create_timer(HOLD_TIME).timeout


func _fade_in() -> void:
	var t = create_tween()
	t.tween_property(fade_rect, "color:a", 0.0, FADE_IN_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await t.finished
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
