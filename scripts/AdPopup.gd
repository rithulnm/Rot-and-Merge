extends CanvasLayer

signal watch_ad_pressed(powerup_type)
signal popup_cancelled

@onready var title_label = $Root/Panel/TitleLabel
@onready var description_label = $Root/Panel/DescriptionLabel
@onready var watch_button: Button = $Root/Panel/HBoxContainer/WatchAdButton
@onready var cancel_button: Button = $Root/Panel/HBoxContainer/CancelButton

var powerup_type := -1

func _ready():
	hide()
	watch_button.pressed.connect(
		_on_watch_pressed
	)
	cancel_button.pressed.connect(
		_on_cancel_pressed
	)

func show_popup(type: int, powerup_name: String):
	powerup_type = type
	title_label.text = "Not Enough Coins"
	description_label.text = "Watch an ad to get a FREE " + powerup_name + "?"
	show()
	var game = get_tree().get_first_node_in_group("game")
	if game:
		game.can_drop = false
		var hud = game.get_node("HUD")
		if hud:
			hud.close_panel()

func _on_cancel_pressed():
	hide()
	var game = get_tree().get_first_node_in_group("game")
	if game:
		game.can_drop = true
	emit_signal("popup_cancelled")

func _on_watch_pressed():
	hide()
	var game = get_tree().get_first_node_in_group("game")
	if game:
		game.can_drop = true
	emit_signal("watch_ad_pressed", powerup_type)
