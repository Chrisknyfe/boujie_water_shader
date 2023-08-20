# Copyright © 2017 Hugo Locurcio and contributors - MIT license
# See LICENSE.md included in the source distribution for more information.

extends Camera3D

const MOVE_SPEED = 2
const MOUSE_SENSITIVITY = 0.002
@onready var speed = 1
@onready var velocity = Vector3()
@onready var initial_rotation = PI/2

var rot_target = Vector3(0,0,0)

func _enter_tree():
	# Capture the mouse (can be toggled by pressing F10)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
func _ready():
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	pass

func slerp_euler_no_z(initial_rot, target_rot, weight):
	var i_b = Basis.from_euler(initial_rot)
	var t_b = Basis.from_euler(target_rot)
	var init_trans = Transform3D(i_b, Vector3(0,0,0))
	var target_trans = Transform3D(t_b, Vector3(0,0,0))
	
	var final_trans = init_trans.interpolate_with(target_trans, weight)
	var final_rot = final_trans.basis.get_euler()
	final_rot.z = 0
	return final_rot

func _input(event):
	# Horizontal mouse look
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rot_target.y -= event.relative.x*MOUSE_SENSITIVITY
		
		# wrap horizontal mouselook
		if rot_target.y > PI:
			rot_target.y -= 2*PI
		if rot_target.y < -PI:
			rot_target.y += 2*PI

	# Vertical mouse look, clamped to -90..90 degrees
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rot_target.x = clamp(rot_target.x - event.relative.y*MOUSE_SENSITIVITY, deg_to_rad(-90), deg_to_rad(90))
		

	# Toggle HUD
	if event.is_action_pressed("toggle_hud"):
		$"../HUD".visible = !$"../HUD".visible

	# Toggle mouse capture
	if event.is_action_pressed("toggle_mouse_capture"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			
	if Input.is_action_just_pressed("reset"):
		get_tree().reload_current_scene()
	if Input.is_action_just_pressed("quit"):
		get_tree().quit()
		
	if Input.is_action_just_pressed("toggle_fullscreen"):
		if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			pass
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			pass
		

func _physics_process(delta):
	# Apply rotation
	rotation = slerp_euler_no_z(rotation, rot_target, 20 * delta)
	
	# Speed modifier
	if Input.is_action_pressed("move_speed"):
		speed = 4
	else:
		speed = 1

	# Movement

	if Input.is_action_pressed("move_forward"):
		velocity.x -= MOVE_SPEED*speed*delta

	if Input.is_action_pressed("move_backward"):
		velocity.x += MOVE_SPEED*speed*delta

	if Input.is_action_pressed("move_left"):
		velocity.z += MOVE_SPEED*speed*delta

	if Input.is_action_pressed("move_right"):
		velocity.z -= MOVE_SPEED*speed*delta

	if Input.is_action_pressed("move_up"):
		velocity.y += MOVE_SPEED*speed*delta

	if Input.is_action_pressed("move_down"):
		velocity.y -= MOVE_SPEED*speed*delta

	# Friction
	velocity *= 0.875

	# Apply velocity
	position += velocity \
	.rotated(Vector3(0, 1, 0), rotation.y - initial_rotation) \
	.rotated(Vector3(1, 0, 0), cos(rotation.y)*rotation.x) \
	.rotated(Vector3(0, 0, 1), -sin(rotation.y)*rotation.x)

func _exit_tree():
	# Restore the mouse cursor upon quitting
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
