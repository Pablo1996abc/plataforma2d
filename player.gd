extends CharacterBody2D

const SPEED = 200
const DASH_SPEED = 600
const JUMP_VELOCITY = -400
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

@onready var sprite = $AnimatedSprite2D

# Controle de tempo para o dash
var dash_time = 0.0
var last_direction = 0

var is_dashing = false

func _ready():
	# Inicializa o timer de dash
	dash_time = 0.0
	last_direction = 0
	

func _physics_process(delta):
	var input_direction = Input.get_axis("ui_left", "ui_right")
	
	
	if input_direction != 0 :
		velocity.x = input_direction * SPEED
	else:
		velocity.x = 0
	#detecta duplo click
	if input_direction != last_direction:
		dash_time = 0.0 #reseta tempo double click ao mudar direcao
	if input_direction != 0:
		dash_time += delta #aumenta tempo enqt botão pressionado
	if dash_time <= 0.2 and input_direction == last_direction:
		is_dashing = true
		velocity.x = DASH_SPEED * input_direction #aplica dash
		
	last_direction = input_direction
	if not is_on_floor():
		
		velocity.y += gravity * delta
		
		
	if is_on_floor() and Input.is_action_just_pressed("ui_accept"):
		velocity.y = JUMP_VELOCITY

	move_and_slide()

	update_animation(input_direction)

func update_animation(direction):
	# Atacando primeiro (prioridade alta)
	if Input.is_action_pressed("attack"):
		sprite.play("attack")
	
	# Pulando (no ar)
	elif not is_on_floor():
		sprite.play("jump")
	# Correndo
	elif direction != 0:
		sprite.play("run")
		sprite.flip_h = direction < 0  # vira o sprite se for pra esquerda
	# Parado
	else:
		sprite.play("idle")
