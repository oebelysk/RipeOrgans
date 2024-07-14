extends CharacterBody3D

@onready var Camera = $Camera

# Camera variables
var camera_rotation = Vector2(0, 0)
@export var mouse_sensitivity = 0.001

# Movement variables
@export var walk_speed: float = 3
@export var jump_velocity: float = 4.5
@export var fall_acceleration: float = 75
@export var player_deceleration: float = 0.15
@export var player_acceleration: float = 0.3

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _ragdoll(force: Vector3):
	pass

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
	
	if event is InputEventMouseMotion:
		var mouse_event = event.relative * mouse_sensitivity
		camera_look(mouse_event)
		
func camera_look(movement: Vector2):
	camera_rotation += movement
	camera_rotation.y = clamp(camera_rotation.y, -1.5, 1.2)
	
	transform.basis = Basis()
	Camera.transform.basis = Basis()
	
	# rotate y
	rotate_object_local(Vector3(0,1,0), -camera_rotation.x)
	# rotate x
	Camera.rotate_object_local(Vector3(1,0,0), -camera_rotation.y)
func _physics_process(delta):
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = jump_velocity

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	
	if direction:
		var speed: float = 0
		
		speed = walk_speed
		
		# Accelerate towards move direction, but decelerate velocities not towards move direction
		velocity.x = move_toward(velocity.x, direction.x * speed, abs(velocity.x * player_deceleration) + abs(direction.x * player_acceleration))
		velocity.z = move_toward(velocity.z, direction.z * speed, abs(velocity.z * player_deceleration) + abs(direction.z * player_acceleration)) 
		print(velocity.x)
		print(velocity.z)
	else:
		# Decelerate towards 0 velocity at a rate proportional to velocity
		velocity.x = move_toward(velocity.x, 0, abs(velocity.x * player_deceleration))
		velocity.z = move_toward(velocity.z, 0, abs(velocity.z * player_deceleration))
		
# Stop deceleration calculations when velocity is negligible
	if abs(velocity.x) < 0.05:
		velocity.x = 0
	if abs(velocity.z) < 0.05:
		velocity.z = 0
	move_and_slide()
