extends CharacterBody2D

const SPEED = 150.0
const RUN_SPEED = 300.0
const JUMP_VELOCITY = -450.0
var GRAVITY = ProjectSettings.get_setting("physics/2d/default_gravity")

@onready var sprite = $AnimatedSprite2D

var last_key_pressed = ""
var tap_time_threshold = 0.3 
var last_tap_time = 0.0
var is_running = false

func _physics_process(delta):
	# 1. Gravidade
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	# 2. Pulo
	if Input.is_action_just_pressed("ui_up") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# 3. Double Tap
	check_double_tap()

	# 4. Movimentação Horizontal
	var direction: float = Input.get_axis("ui_left", "ui_right")
	
	# Logica de agachar ou mover
	if Input.is_action_pressed("ui_down") and is_on_floor():
		velocity.x = move_toward(velocity.x, 0, SPEED)
	elif direction != 0:
		var current_speed = RUN_SPEED if is_running else SPEED
		velocity.x = direction * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		is_running = false

	# 5. Animação (Chamada única com o valor numérico correto)
	update_animation(direction)
	
	move_and_slide()

func check_double_tap():
	if Input.is_action_just_pressed("ui_right"):
		handle_tap("right")
	if Input.is_action_just_pressed("ui_left"):
		handle_tap("left")
	if not Input.is_action_pressed("ui_right") and not Input.is_action_pressed("ui_left"):
		is_running = false

func handle_tap(dir_name: String):
	var current_time = Time.get_unix_time_from_system()
	if last_key_pressed == dir_name:
		if current_time - last_tap_time < tap_time_threshold:
			is_running = true
	last_key_pressed = dir_name
	last_tap_time = current_time

func update_animation(direction_val: float):
	if Input.is_action_pressed("attack") and sprite.sprite_frames.has_animation("attack"):
		sprite.play("attack")
		return

	if not is_on_floor():
		sprite.play("jump")
	elif Input.is_action_pressed("ui_down"):
		sprite.play("crouch")
	elif abs(direction_val) > 0.1:
		sprite.flip_h = direction_val < 0
		sprite.play("run")
	else:
		sprite.play("idle")
