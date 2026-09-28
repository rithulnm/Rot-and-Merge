@tool
extends Resource
class_name FruitData
@export var normal_texture: Texture2D
@export var tier: int = 1
@export var fruit_name: String = ""
@export var radius: float = 30.0
@export var rot_duration: float = 15.0
@export var score_value: int = 10
@export var poison_spread_count: int = 1
@export var texture: Texture2D
@export var face_eye_type : int = 0
@export var face_mouth_default : int = 0
@export var face_personality : int = 0

@export var face_eye_separation : float = 12.0
@export var face_eye_height : float = -8.0

@export var face_eye_scale : Vector2 = Vector2.ONE
@export var face_pupil_scale : Vector2 = Vector2.ONE

@export var face_mouth_position : Vector2 = Vector2(0, 10)
@export var face_mouth_scale : Vector2 = Vector2.ONE
