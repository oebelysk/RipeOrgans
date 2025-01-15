extends CharacterBody3D

@onready var head = $Head
@onready var camera = $Head/Camera
@onready var body = $CollisionShape3D
@onready var animation_player = $AnimationPlayer
@onready var weapon_container = $Head/Camera/WeaponContainer
@onready var raycast = $Head/Camera/RayCast3D
@onready var ahead_raycast = $StairsAboveRayCast3D
@onready var below_raycast = $StairsBelowRayCast3D

@export var pickup_distance: float = 2.5

@export var deceleration_coefficient: float = 10
@export var fast_fall_coefficient: float = 2.8
@export var jump_force: float = 10
@export var jump_boost: float = 2
@export var air_control: float = 5
@export var air_acceleration: float = 5.0
@export var max_air_control_speed: float = 6

var speed: float
var equipped_item: Item
const WALK_SPEED = 5.0
const SPRINT_SPEED = 7.5
const SENSITIVITY = 0.0025
const MAX_STEP_HEIGHT = 0.5

var _snapped_to_stairs_last_frame: bool = false
var _last_frame_on_floor = -INF


# Bob variables
const BOB_FREQ = 2
const BOB_AMP = 0.04
var t_bob: float = 0.0

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity: float = 9.8


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
	if is_on_floor():
		_last_frame_on_floor = Engine.get_physics_frames()

	# Get the input direction and handle the movement/deceleration.
	var input_dir = Input.get_vector("left", "right", "forward", "back")
	var direction = (head.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var drag = 1 - (delta * deceleration_coefficient)

	# Handle jump.
	if Input.is_action_just_pressed("jump") and (is_on_floor() or _snapped_to_stairs_last_frame):
		velocity.y = jump_force

		if direction != Vector3.ZERO:
			velocity += direction.normalized() * jump_boost

	if Input.is_action_pressed("sprint"):
		speed = SPRINT_SPEED
	else:
		speed = WALK_SPEED
		
	if is_on_floor() or _snapped_to_stairs_last_frame:
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
	
	if not _snap_up_stairs_check(delta):
		move_and_slide()
		_snap_down_stairs_check()

func _headbob(time) -> Vector3:
	var pos = Vector3.ZERO
	pos.y = sin(time * BOB_FREQ) * BOB_AMP
	pos.x = cos(time * BOB_FREQ / 2) * BOB_AMP
	return pos

func _equip(item: Item) -> void:
	item.get_parent().remove_child(item)
	weapon_container.add_child(item)
	item.equip()
	item.user = self
	item.position = Vector3(0,0,0)
	item.rotation_degrees = Vector3(0, 0, 0)
	item.animation_player.play("equip")

func anim_ended(anim_name: StringName):
	if anim_name == "equip" or anim_name == "attack_topleft_bottomright":
		equipped_item.animation_player.play("idle")

func _pickup() -> void:
	pass

func _snap_up_stairs_check(delta) -> bool:
	if not is_on_floor() and not _snapped_to_stairs_last_frame:
		return false
	var expected_move_motion = self.velocity * Vector3(1, 0, 1) * delta
	var step_pos_with_clearance = self.global_transform.translated(expected_move_motion + Vector3(0, MAX_STEP_HEIGHT * 2, 0))
	var down_check_result = PhysicsTestMotionResult3D.new()
	if (_run_body_test_motion(step_pos_with_clearance, Vector3(0, -MAX_STEP_HEIGHT*2, 0), down_check_result)
	and (down_check_result.get_collider().is_class("StaticBody3D") or down_check_result.get_collider().is_class("CSGShape3D"))):
		var step_height = ((step_pos_with_clearance.origin + down_check_result.get_travel()) - self.global_position).y
		if step_height > MAX_STEP_HEIGHT or step_height <= 0.01 or (down_check_result.get_collision_point() - self.global_position).y > MAX_STEP_HEIGHT:
			return false
		ahead_raycast.global_position = down_check_result.get_collision_point() + Vector3(0, MAX_STEP_HEIGHT, 0) + expected_move_motion.normalized() * 0.1
		ahead_raycast.force_raycast_update()
		if ahead_raycast.is_colliding() and not _is_surface_too_steep(ahead_raycast.get_collision_normal()):
			self.global_position = step_pos_with_clearance.origin + down_check_result.get_travel()
			apply_floor_snap()
			_snapped_to_stairs_last_frame = true
			return true
	return false

func _snap_down_stairs_check() -> void:
	var did_snap: bool = false
	var floor_below: bool = below_raycast.is_colliding() and not _is_surface_too_steep(below_raycast.get_collision_normal())
	var was_on_floor_last_frame = Engine.get_physics_frames() - _last_frame_on_floor == 1
	if not is_on_floor() and velocity.y <= 0 and (was_on_floor_last_frame or _snapped_to_stairs_last_frame) and floor_below:
		var body_test_result = PhysicsTestMotionResult3D.new()
		if _run_body_test_motion(self.global_transform, Vector3(0, -MAX_STEP_HEIGHT, 0), body_test_result):
			var translate_y = body_test_result.get_travel().y
			self.position.y += translate_y
			apply_floor_snap()
			did_snap = true
	_snapped_to_stairs_last_frame = did_snap

func _is_surface_too_steep(normal: Vector3) -> bool:
	return normal.angle_to(Vector3.UP) > self.floor_max_angle

func _run_body_test_motion(from: Transform3D, motion: Vector3, result = null) -> bool:
	if not result: result = PhysicsTestMotionParameters3D.new()
	var params = PhysicsTestMotionParameters3D.new()
	params.from = from
	params.motion = motion
	return PhysicsServer3D.body_test_motion(self.get_rid(), params, result)
