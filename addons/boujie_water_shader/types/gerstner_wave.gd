@icon("res://addons/boujie_water_shader/icons/Wave.svg")
class_name GerstnerWave
extends Resource

@export var steepness := 1.0
@export var amplitude := 1.0
@export_range(0, 360) var direction_degrees := 0.0
@export var frequency := 0.1
@export var speed := 1.0
@export_range(0, 360) var phase_degrees := 0.0
