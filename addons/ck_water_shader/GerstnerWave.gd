@icon("res://addons/ck_water_shader/icons/Wave.svg")
extends Resource
class_name GerstnerWave

@export var steepness: float = 1.0
@export var amplitude: float = 1.0
@export_range(0, 360) var direction_degrees: float = 0.0
@export var frequency: float = 0.1
@export var speed: float = 1.0
@export_range(0, 360) var phase_degrees: float = 0.0
