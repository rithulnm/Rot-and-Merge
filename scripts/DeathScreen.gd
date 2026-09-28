extends CanvasLayer

@onready var card_panel: Control = $Root/CardPanel
@onready var paper_bg: TextureRect = $Root/CardPanel/PaperBg
@onready var paper_ball: TextureRect = $Root/PaperBall
@onready var highest_fruit_display: TextureRect = $Root/CardPanel/ContentContainer/HighestFruitDisplay
@onready var jar_label: TextureRect = $Root/CardPanel/ContentContainer/TitleRow/JarLabel
@onready var full_label: TextureRect = $Root/CardPanel/ContentContainer/TitleRow/FullLabel
@onready var pencil_line1: TextureRect = $Root/CardPanel/ContentContainer/PencilLine1
@onready var pencil_line2: TextureRect = $Root/CardPanel/ContentContainer/PencilLine2

@onready var coins_icon: TextureRect = $Root/CardPanel/ContentContainer/CoinRow/CoinsIcon
@onready var coins_label: Label = $Root/CardPanel/ContentContainer/CoinRow/CoinsLabel
@onready var score_title: Label = $Root/CardPanel/ContentContainer/ScoreRow/ScoreTitle
@onready var score_label: Label = $Root/CardPanel/ContentContainer/ScoreRow/ScoreLabel
@onready var best_title: Label = $Root/CardPanel/ContentContainer/BestRow/BestTitle
@onready var high_score_label: Label = $Root/CardPanel/ContentContainer/BestRow/HighScoreLabel

@onready var restart_button: Button = $Root/CardPanel/ContentContainer/HBoxContainer/RestartButton
@onready var menu_button: Button = $Root/CardPanel/ContentContainer/HBoxContainer/MenuButton

@onready var title_row: HBoxContainer = $Root/CardPanel/ContentContainer/TitleRow

@onready var sfx_btn_click: AudioStreamPlayer = $SFX_BtnClick
@onready var sfx_paper_crumple: AudioStreamPlayer = $SFX_PaperCrumple
@onready var sfx_paper_unfold: AudioStreamPlayer = $SFX_PaperUnfold
@onready var sfx_title_slide: AudioStreamPlayer = $SFX_TitleSlide
@onready var sfx_pencil_draw: AudioStreamPlayer = $SFX_PencilDraw
@onready var sfx_coin_count: AudioStreamPlayer = $SFX_ScoreCount
@onready var sfx_score_pop: AudioStreamPlayer = $SFX_ScorePop
@onready var sfx_coin_pop: AudioStreamPlayer = $SFX_CoinPop
@onready var sfx_btn_appear: AudioStreamPlayer = $SFX_BtnAppear
@onready var sfx_glitter: AudioStreamPlayer = $SFX_Glitter

var _jar_base_x: float = 0.0
var _full_base_x: float = 0.0

func _ready():
	_setup_button_hover(restart_button)
	_setup_button_hover(menu_button)
	restart_button.pressed.connect(_on_restart_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
	hide()
	_reset_all()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	_jar_base_x = jar_label.position.x
	_full_base_x = full_label.position.x
func _reset_all():
	# Hide everything at start
	card_panel.modulate.a = 0.0
	card_panel.scale = Vector2.ZERO
	paper_ball.modulate.a = 0.0
	paper_ball.scale = Vector2.ZERO
	jar_label.modulate.a = 0.0
	full_label.modulate.a = 0.0
	jar_label.position.x = _jar_base_x - 600.0
	full_label.position.x = _full_base_x + 600.0
	pencil_line1.modulate.a = 0.0
	pencil_line1.scale.x = 0.0
	pencil_line2.modulate.a = 0.0
	pencil_line2.scale.x = 0.0
	highest_fruit_display.modulate.a = 0.0
	highest_fruit_display.scale = Vector2(0.5, 0.5)
	score_label.modulate.a = 0.0
	score_title.modulate.a = 0.0
	coins_icon.modulate.a = 0.0
	best_title.modulate.a = 0.0
	high_score_label.modulate.a = 0.0
	coins_label.modulate.a = 0.0
	restart_button.modulate.a = 0.0
	menu_button.modulate.a = 0.0
	restart_button.disabled = true
	menu_button.disabled = true
	# Reset any position offsets from previous run
	restart_button.position.y = 0.0
	menu_button.position.y = 0.0
	highest_fruit_display.position.y = 0.0

func show_death_screen(
	final_score: int,
	high_score: int,
	highest_fruit_texture: Texture2D = null
):
	score_title.text = "SCORE"
	score_label.text = str(final_score)
	best_title.text = "BEST"
	high_score_label.text = str(high_score)
	coins_label.text = "0"

	if highest_fruit_texture:
		highest_fruit_display.texture = highest_fruit_texture
		highest_fruit_display.visible = true
	else:
		highest_fruit_display.visible = false

	_reset_all()
	show()

	await _animate_sequence(final_score)

func _animate_sequence(_final_score: int):

	# ── STEP 1: Paper ball appears in center ──
	paper_ball.pivot_offset = paper_ball.size / 2.0
	sfx_paper_crumple.play()
	Input.vibrate_handheld(60)
	var ball_appear = create_tween()
	ball_appear.set_parallel(true)
	ball_appear.tween_property(paper_ball, "modulate:a", 1.0, 0.15)
	ball_appear.tween_property(paper_ball, "scale", Vector2(1.0, 1.0), 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await ball_appear.finished

	# ── STEP 2: Ball wobbles ──
	var wobble = create_tween()
	wobble.tween_property(paper_ball, "rotation_degrees", -8.0, 0.14)
	wobble.tween_property(paper_ball, "rotation_degrees", 8.0, 0.18)
	wobble.tween_property(paper_ball, "rotation_degrees", -5.0, 0.15)
	wobble.tween_property(paper_ball, "rotation_degrees", 0.0, 0.18)
	await wobble.finished

	await get_tree().create_timer(0.25).timeout

	# ── STEP 3: Ball unfolds → paper panel expands ──
	card_panel.pivot_offset = card_panel.size / 2.0
	sfx_paper_unfold.play()
	var unfold = create_tween()
	unfold.set_parallel(true)
	# Ball shrinks and fades as paper expands
	unfold.tween_property(paper_ball, "scale", Vector2(0.1, 0.1), 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	unfold.tween_property(paper_ball, "modulate:a", 0.0, 0.45)
	# Paper panel grows from center
	unfold.tween_property(card_panel, "scale", Vector2(1.0, 1.0), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.1)
	unfold.tween_property(card_panel, "modulate:a", 1.0, 0.3).set_delay(0.1)
	await unfold.finished

	await get_tree().create_timer(0.15).timeout

	# ── STEP 4: JAR slides in from left ──
	jar_label.pivot_offset = jar_label.size / 2.0
	sfx_title_slide.pitch_scale = 1.0
	sfx_title_slide.play()
	var jar_slide = create_tween()
	jar_slide.set_parallel(true)
	jar_slide.tween_property(jar_label, "position:x", 0.0, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	jar_slide.tween_property(jar_label, "modulate:a", 1.0, 0.3)
	await jar_slide.finished
	await get_tree().create_timer(0.25).timeout
	
	# ── STEP 5: FULL slides in from right (slight overlap with JAR landing) ──
	full_label.pivot_offset = full_label.size / 2.0
	sfx_title_slide.pitch_scale = 1.08
	sfx_title_slide.play()
	var full_slide = create_tween()
	full_slide.set_parallel(true)
	full_slide.tween_property(full_label, "position:x", 480.0, 0.30).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	full_slide.tween_property(full_label, "modulate:a", 1.0, 0.3)
	await full_slide.finished

	await get_tree().create_timer(0.2).timeout
	
	# ── STEP 7: Highest fruit grand reveal ──
	if highest_fruit_display.visible:
		# Start tiny and offscreen top
		highest_fruit_display.pivot_offset = highest_fruit_display.size / 2.0
		highest_fruit_display.scale = Vector2(0.2, 0.2)
		highest_fruit_display.modulate.a = 0.0
		highest_fruit_display.position.y = highest_fruit_display.position.y - 60.0

		# Drop in from above with elastic overshoot
		var fruit_drop = create_tween()
		fruit_drop.set_parallel(true)
		fruit_drop.tween_property(highest_fruit_display, "position:y",
			highest_fruit_display.position.y + 60.0, 0.4
		).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		fruit_drop.tween_property(highest_fruit_display, "scale",
			Vector2(1.3, 1.3), 0.35
		).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		fruit_drop.tween_property(highest_fruit_display, "modulate:a",
			1.0, 0.25
		)
		await fruit_drop.finished

		# Squash on landing
		var squash = create_tween()
		squash.tween_property(highest_fruit_display, "scale",
			Vector2(1.15, 0.88), 0.08
		).set_trans(Tween.TRANS_SINE)
		squash.tween_property(highest_fruit_display, "scale",
			Vector2(1.0, 1.0), 0.25
		).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		await squash.finished

		# Sparkle burst around it
		sfx_glitter.play()
		_spawn_fruit_sparkles(highest_fruit_display.global_position + highest_fruit_display.size / 2.0)

		await get_tree().create_timer(0.3).timeout
		_start_fruit_idle_animation()
		await get_tree().create_timer(0.1).timeout

	# ── STEP 6: Pencil line 1 draws in left to right ──
	sfx_pencil_draw.pitch_scale = 1.0
	sfx_pencil_draw.play()
	await _draw_pencil_line(pencil_line1, 0.7)
	await get_tree().create_timer(0.15).timeout

	
	# ── STEP 8: Score counts up ──
	var score_in = create_tween()
	score_in.set_parallel(true)
	score_in.tween_property(score_title, "modulate:a", 1.0, 0.2)
	score_in.tween_property(score_label, "modulate:a", 1.0, 0.2)
	await score_in.finished

	var base_score = GameManager.score
	# No tick sound for score — just count up silently
	var count_tween = create_tween()
	count_tween.tween_method(
		func(v): score_label.text = str(int(v)),
		0.0, float(base_score), 1.1
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await count_tween.finished
	# Pop sound when score lands
	sfx_score_pop.pitch_scale = randf_range(0.97, 1.03)
	sfx_score_pop.play()
	Input.vibrate_handheld(40)

	# Score pop on finish
	score_label.pivot_offset = score_label.size / 2.0
	var score_pop_t = create_tween()
	score_pop_t.tween_property(score_label, "scale", Vector2(1.3, 1.3), 0.1).set_trans(Tween.TRANS_BACK)
	score_pop_t.tween_property(score_label, "scale", Vector2.ONE, 0.15)
	await score_pop_t.finished

	await get_tree().create_timer(0.08).timeout

	# ── STEP 9: Best score fades in ──
	# ── STEP 9: Best score fades in ──
	var is_new_best = GameManager.new_best_announced_this_run

	var best_title_in = create_tween()
	best_title_in.set_parallel(true)
	best_title_in.tween_property(best_title, "modulate:a", 1.0, 0.25)
	await best_title_in.finished
	
	if is_new_best:
		best_title.text = "NEW BEST!"
		best_title.add_theme_color_override("font_color", Color(0.976, 0.819, 0.0, 1.0))
		high_score_label.add_theme_color_override("font_color", Color(1.0, 0.901, 0.528, 1.0))

	var best_in = create_tween()
	best_in.set_parallel(true)
	best_in.tween_property(high_score_label, "modulate:a", 1.0, 0.25)
	await best_in.finished

	if is_new_best:
		sfx_glitter.play()
		Input.vibrate_handheld(100)
		high_score_label.pivot_offset = high_score_label.size / 2.0
		var best_pop = create_tween()
		best_pop.tween_property(high_score_label, "scale", Vector2(1.35, 1.35), 0.12).set_trans(Tween.TRANS_BACK)
		best_pop.tween_property(high_score_label, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_ELASTIC)
		_spawn_fruit_sparkles(high_score_label.global_position + high_score_label.size / 2.0)

	await get_tree().create_timer(0.08).timeout
	
	var coin_in = create_tween()
	coin_in.set_parallel(true)
	coin_in.tween_property(coins_icon, "modulate:a", 1.0, 0.25)
	await coin_in.finished
	
	# ── STEP 11: Coins count up ──
	coins_label.modulate.a = 1.0
	var earned = GameManager.last_run_earned_coins

	if earned <= 0:
		coins_label.text = "+0"
	else:
		var total_ticks = clampi(earned, 1, 12)
		var displayed := 0

		for i in range(total_ticks):
			var progress = float(i + 1) / float(total_ticks)
			var eased = 1.0 - pow(1.0 - progress, 2.0)  # decel value growth
			var target = int(round(float(earned) * eased))

			# step spacing itself decelerates — ticks get slightly farther apart
			var t_progress = float(i) / float(max(total_ticks - 1, 1))
			var step_time = lerp(0.05, 0.11, t_progress)

			var step_tween = create_tween()
			step_tween.tween_method(
				func(v): coins_label.text = "+" + str(int(v)),
				float(displayed), float(target), step_time * 0.6
			).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			await step_tween.finished
			displayed = target

			# pitch trill: rising baseline + small alternating wobble, not a flat ramp
			var base_pitch = 1.0 + (float(i) / total_ticks) * 0.18
			var wobble2 = 0.03 if i % 2 == 0 else -0.02
			sfx_coin_count.pitch_scale = base_pitch + wobble2 + randf_range(-0.01, 0.01)
			sfx_coin_count.play()

			# tiny punch on the label each tick
			coins_label.pivot_offset = coins_label.size / 2.0
			var punch = create_tween()
			var punch_scale = 1.12 if i == total_ticks - 1 else 1.06
			punch.tween_property(coins_label, "scale", Vector2(punch_scale, punch_scale), step_time * 0.3)
			punch.tween_property(coins_label, "scale", Vector2.ONE, step_time * 0.4)

			await get_tree().create_timer(step_time * 0.4).timeout

	coins_label.text = "+" + str(earned)

	sfx_coin_pop.pitch_scale = randf_range(0.97, 1.03)
	sfx_coin_pop.play()
	
	# Tiny screen nudge when score lands
	var nudge = create_tween()
	nudge.tween_property(card_panel, "position:y", card_panel.position.y - 6.0, 0.06)
	nudge.tween_property(card_panel, "position:y", card_panel.position.y, 0.12).set_trans(Tween.TRANS_ELASTIC)
	# Coin pop
	coins_label.pivot_offset = coins_label.size / 2.0
	var coin_pop_t = create_tween()
	coin_pop_t.tween_property(coins_label, "scale", Vector2(1.25, 1.25), 0.1).set_trans(Tween.TRANS_BACK)
	coin_pop_t.tween_property(coins_label, "scale", Vector2.ONE, 0.15)
	await coin_pop_t.finished

	await get_tree().create_timer(0.35).timeout
	
	# ── STEP 10: Pencil line 2 draws in ──
	sfx_pencil_draw.pitch_scale = 0.95
	sfx_pencil_draw.play()
	await _draw_pencil_line(pencil_line2, 0.6)

	# ── STEP 12: Buttons slide up and fade in ──
	sfx_btn_appear.pitch_scale = 1.0
	sfx_btn_appear.play()
	await get_tree().create_timer(0.08).timeout
	sfx_btn_appear.pitch_scale = 1.05
	sfx_btn_appear.play()
	restart_button.disabled = false
	menu_button.disabled = false
	
	restart_button.position.y += 20.0
	menu_button.position.y += 20.0
	restart_button.disabled = false
	menu_button.disabled = false
	var btn_tween = create_tween()
	btn_tween.set_parallel(true)
	btn_tween.tween_property(restart_button, "modulate:a", 1.0, 0.2)
	btn_tween.tween_property(restart_button, "position:y", restart_button.position.y - 20.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	btn_tween.tween_property(menu_button, "modulate:a", 1.0, 0.2).set_delay(0.08)
	btn_tween.tween_property(menu_button, "position:y", menu_button.position.y - 20.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.08)
	await btn_tween.finished
	
func _start_fruit_idle_animation():
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(highest_fruit_display, "scale", Vector2(1.04, 1.04), 1.2)
	tween.tween_property(highest_fruit_display, "scale", Vector2.ONE, 1.2)

func _on_restart_pressed():
	AdsManager.request_interstitial_on_restart(_do_restart)
	
func _do_restart():
	sfx_btn_click.pitch_scale = 1.1
	sfx_btn_click.play()
	await get_tree().create_timer(0.1).timeout
	hide()
	SceneTransition.reload_current_scene()

func _on_menu_pressed():
	sfx_btn_click.pitch_scale = 1.0
	sfx_btn_click.play()
	await get_tree().create_timer(0.1).timeout
	hide()
	SceneTransition.change_scene("res://scenes/ui/MainMenu.tscn")
	
func _setup_button_hover(btn: Button):
	btn.mouse_entered.connect(func():
		btn.pivot_offset = btn.size / 2.0
		var t = create_tween()
		t.tween_property(btn, "scale", Vector2(1.12, 1.12), 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	)
	btn.mouse_exited.connect(func():
		var t = create_tween()
		t.tween_property(btn, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	)
	
func _draw_pencil_line(line: TextureRect, duration: float):
	line.pivot_offset = Vector2(0, line.size.y / 2.0)
	line.modulate.a = 1.0
	line.scale.x = 0.0

	# Lead dot — small circle that runs ahead of the line
	var dot = ColorRect.new()
	dot.color = Color(0.36, 0.24, 0.12, 0.9)
	dot.size = Vector2(18, 18)
	dot.z_index = 1001
	add_child(dot)
	dot.global_position = line.global_position + Vector2(0, line.size.y * 0.5 - 9)

	var t = create_tween()
	t.set_parallel(true)

	# Line draws across
	t.tween_property(line, "scale:x", 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# Dot moves with line tip
	var end_x = line.global_position.x + line.size.x
	t.tween_property(dot, "global_position:x", end_x, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# Dot fades out slightly after line finishes
	t.tween_property(dot, "modulate:a", 0.0, 0.15).set_delay(duration)
	t.tween_callback(dot.queue_free).set_delay(duration + 0.2)

	await t.finished
	await get_tree().create_timer(0.15).timeout

func _spawn_fruit_sparkles(pos: Vector2):
	var sparkle_tex = load("res://assets/sprites/sparkle.png")
	var colors = [
		Color(1.0, 0.85, 0.2, 1.0),   # gold
		Color(1.0, 0.4, 0.2, 1.0),    # orange-red
		Color(0.4, 0.9, 0.3, 1.0),    # green
		Color(1.0, 0.9, 0.3, 1.0),    # yellow
		Color(1.0, 0.5, 0.8, 1.0),    # pink
		Color(0.5, 0.8, 1.0, 1.0),    # light blue
		Color(1.0, 0.85, 0.2, 1.0),   # gold again
		Color(1.0, 0.4, 0.2, 1.0),    # orange-red again
	]

	# Inner ring — 8 sparkles, medium distance
	for i in 8:
		var spark = Sprite2D.new()
		spark.texture = sparkle_tex
		spark.z_index = 200
		add_child(spark)
		spark.global_position = pos
		spark.modulate = colors[i % colors.size()]
		spark.scale = Vector2(0.6, 0.6)

		var angle = (TAU / 8.0) * i + randf() * 0.3
		var dist = randf_range(120.0, 180.0)
		var target = pos + Vector2(cos(angle), sin(angle)) * dist

		var t = create_tween()
		t.set_parallel(true)
		t.tween_property(spark, "global_position", target, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t.tween_property(spark, "scale", Vector2(1.4, 1.4), 0.2)
		t.tween_property(spark, "scale", Vector2(0.0, 0.0), 0.3).set_delay(0.2)
		t.tween_property(spark, "modulate:a", 0.0, 0.3).set_delay(0.22)
		t.tween_callback(spark.queue_free).set_delay(0.55)

	# Outer ring — 5 bigger sparkles, more distance, slightly delayed
	for i in 10:
		var spark = Sprite2D.new()
		spark.texture = sparkle_tex
		spark.z_index = 200
		add_child(spark)
		spark.global_position = pos
		spark.modulate = colors[(i + 2) % colors.size()]
		spark.scale = Vector2(1.0, 1.0)

		var angle = (TAU / 5.0) * i + 0.4
		var dist = randf_range(200.0, 280.0)
		var target = pos + Vector2(cos(angle), sin(angle)) * dist

		var t = create_tween()
		t.set_parallel(true)
		t.tween_property(spark, "global_position", target, 0.65).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t.tween_property(spark, "scale", Vector2(1.8, 1.8), 0.25)
		t.tween_property(spark, "scale", Vector2(0.0, 0.0), 0.4).set_delay(0.25)
		t.tween_property(spark, "modulate:a", 0.0, 0.4).set_delay(0.28)
		t.tween_callback(spark.queue_free).set_delay(0.7)

	# Central flash ring — expands quickly then fades
	var ring = Sprite2D.new()
	ring.texture = load("res://assets/sprites/ring_poof.png")
	ring.z_index = 199
	add_child(ring)
	ring.global_position = pos
	ring.modulate = Color(1.0, 0.85, 0.2, 0.8)
	ring.scale = Vector2(0.2, 0.2)

	var ring_t = create_tween()
	ring_t.set_parallel(true)
	ring_t.tween_property(ring, "scale", Vector2(4.0, 4.0), 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	ring_t.tween_property(ring, "modulate:a", 0.0, 0.4).set_ease(Tween.EASE_IN)
	ring_t.tween_callback(ring.queue_free).set_delay(0.5)
