@icon("res://addons/boujie_water_shader/icons/Wave.svg")
class_name GerstnerWave
extends Resource

@export var steepness := 1.0
@export var amplitude := 1.0
@export_range(0, 360) var direction_degrees := 0.0
@export var frequency := 0.1
@export var speed := 1.0
@export_range(0, 360) var phase_degrees := 0.0

func height(x: float, z: float, t: float) -> float:
	var direction = Vector2( sin(direction_degrees * TAU / 360.0), cos(direction_degrees * TAU / 360.0))
	var p = phase_degrees * TAU / 360.0
	var y = steepness * sin(TAU * (frequency * direction).dot(Vector2(x,z)) + (speed * (t+p)) )
	return y
