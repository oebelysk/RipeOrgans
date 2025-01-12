extends CharacterBody3D

var speed
var equipped_item: Item
const WALK_SPEED = 5.0
const SPRINT_SPEED = 7.5
const SENSITIVITY = 0.0025

# Bob variables
const BOB_FREQ = 2
const BOB_AMP = 0.04
var t_bob = 0.0

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = 9.8

@onready var head = $Head
@onready var camera = $Head/Camera
@onready var body = $CollisionShape3D
@onready var animation_player = $AnimationPlayer
@onready var weapon_container = $Head/Camera/WeaponContainer
@onready var raycast = $Head/Camera/RayCast3D

@export var pickup_distance: float = 2.5

@export var deceleration_coefficient: float = 10

@export var fast_fall_coefficient: float = 2.8
@export var jump_force: float = 10
@export var jump_boost: float = 2
@export var air_control: float = 5
@export var air_acceleration: float = 5.0
@export var max_air_control_speed: float = 6


func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	print("test")

	raycast.target_position = Vector3(0, 0, -pickup_distance)
	raycast.enabled = true
	
func _input(event):
	if event.is_action_pressed("quit"):
		get_tree().quit()

		
	if event is InputEventMouseMotion:
		head.rotate_y(-event.relative.x * SENSITIVITY)
		body.rotate_y(-event.relative.x * SENSITIVITY)
		camera.rotate_x(-event.relative.y * SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-85), deg_to_rad(85))

	if event.is_action_pressed("primary_attack") and equipped_item:
		equipped_item.animation_player.play("attack_topleft_bottomright")
	
	if event.is_action_pressed("primary_attack") and not equipped_item:
		if raycast.is_colliding():
			var item = raycast.get_collider()

			while item and not "equippable" in item:
				item = item.get_parent()

			if item and item.equippable:
				equipped_item = item
				_equip(item)
	


func _unhandled_input(event):
	pass

func _physics_process(delta):
		# Get the input direction and handle the movement/deceleration.
	var input_dir = Input.get_vector("left", "right", "forward", "back")
	var direction = (head.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var drag = 1 - (delta * deceleration_coefficient)

	# Handle jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_force

		if direction != Vector3.ZERO:
			velocity += direction.normalized() * jump_boost

	if Input.is_action_pressed("sprint"):
		speed = SPRINT_SPEED
	else:
		speed = WALK_SPEED
		


	if is_on_floor():
		if direction:
			var target_velocity = direction.normalized() * speed
			velocity = velocity.move_toward(target_velocity, 1)
		else:
			velocity *= drag
	else:
		var velocity_flat = Vector3(velocity.x, 0, velocity.z)
		var direction_flat = Vector3(direction.x, 0, direction.z).normalized()

		var angle = velocity_flat.normalized().dot(direction_flat)

		var strafe_force = direction_flat * air_control * air_acceleration * delta * (1.0 - abs(angle))

		var target_velocity = velocity_flat + strafe_force

		velocity.x = target_velocity.x
		velocity.z = target_velocity.z

		velocity.y -= gravity * fast_fall_coefficient * delta

		
	# Head bob
	# t_bob += delta * velocity.length() * float(is_on_floor())
	# camera.transform.origin = _headbob(t_bob)
	
	move_and_slide()
	
func _handle_step_up():
	print("stepping")

func _headbob(time) -> Vector3:
	var pos = Vector3.ZERO
	pos.y = sin(time * BOB_FREQ) * BOB_AMP
	pos.x = cos(time * BOB_FREQ / 2) * BOB_AMP
	return pos

func _equip(item: Item):
	item.get_parent().remove_child(item)
	weapon_container.add_child(item)
	item.equip()
	item.user = self
	item.position = Vector3(0,0,0)
	item.rotation_degrees = Vector3(0, 0, 0)
	item.animation_player.play("equip")

func _pickup():
	pass

func anim_ended(anim_name: StringName):
	if anim_name == "equip" or anim_name == "attack_topleft_bottomright":
		equipped_item.animation_player.play("idle")

func _on_step_detector_body_entered(item_body):
	_handle_step_up()
