extends CharacterBody2D

const SPEED = 150.0
const RUN_SPEED = 300.0
const JUMP_VELOCITY = -450.0
var GRAVITY = ProjectSettings.get_setting("physics/2d/default_gravity")
var is_hurt: bool = false
var hurt_timer: float = 0.0
const HURT_DURATION: float = 0.5  # tempo da animação de hit
var health: int = 100
var _flashing: bool = false
var is_attacking: bool = false
var combo_queued: bool = false  # jogador segurou o botão durante o ataque

@onready var sprite = $AnimatedSprite2D
@onready var attack_hitbox = $AttackHitbox


var last_key_pressed = ""
var tap_time_threshold = 0.3 
var last_tap_time = 0.0
var is_running = false


func _flash(color: Color, duration: float = 0.15) -> void:
	if _flashing:
		return
	_flashing = true
	sprite.modulate = color
	await get_tree().create_timer(duration).timeout
	sprite.modulate = Color.WHITE
	_flashing = false

func _physics_process(delta):
	if is_hurt:
		hurt_timer -= delta
		if hurt_timer <= 0.0:
			is_hurt = false
			
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
	
func _ready():  # ← nome aqui
	$Hitbox.area_entered.connect(_on_hitbox_area_entered)
	attack_hitbox.monitoring = false  # começa desativado
	sprite.animation_finished.connect(_on_animation_finished)
	
	attack_hitbox.area_entered.connect(_on_attack_hitbox_area_entered)

func _on_attack_hitbox_area_entered(area):
	if area.get_parent() == self:
		return
	if area == $Hitbox:
		return
		
	var parent = area.get_parent()
	if parent.has_method("take_damage"):
		parent.take_damage(10)  # dano do player
	
func _on_animation_finished():
	if sprite.animation == "attack":
		attack_hitbox.monitoring = false
		# Se segurou o botão durante o ataque, faz o combo
		if combo_queued and sprite.sprite_frames.has_animation("attack combo"):
			combo_queued = false
			sprite.play("attack combo")
			attack_hitbox.monitoring = true
			attack_hitbox.scale.x = -1.0 if sprite.flip_h else 1.0
		else:
			combo_queued = false
			is_attacking = false

	elif sprite.animation == "attack combo":
		attack_hitbox.monitoring = false
		is_attacking = false
		combo_queued = false


func _on_hitbox_area_entered(area):
	# Ignora a própria hitbox de ataque
	if area == attack_hitbox:
		return
	if area.get_parent() == self:
		return
		
	is_hurt = true
	hurt_timer = HURT_DURATION
	_flash(Color.YELLOW)
	
	
func take_damage(amount: int) -> void:
	is_hurt = true
	hurt_timer = HURT_DURATION
	health -= amount
	_flash(Color.YELLOW)  # ← pisca amarelo
	
func update_animation(direction_val: float):
	if is_hurt and sprite.sprite_frames.has_animation("hit"):
		sprite.play("hit")
		attack_hitbox.monitoring = false
		is_attacking = false
		combo_queued = false
		return

	# Se está no meio de um ataque
	if is_attacking:
		# Registra o combo se segurar o botão
		if Input.is_action_pressed("attack"):
			combo_queued = true
		return

	# Novo ataque
	if Input.is_action_just_pressed("attack") and sprite.sprite_frames.has_animation("attack"):
		is_attacking = true
		combo_queued = false
		sprite.play("attack")
		attack_hitbox.monitoring = true
		attack_hitbox.scale.x = -1.0 if sprite.flip_h else 1.0
		return

	attack_hitbox.monitoring = false

	if not is_on_floor():
		sprite.play("jump")
	elif Input.is_action_pressed("ui_down"):
		sprite.play("crouch")
	elif abs(direction_val) > 0.1:
		sprite.flip_h = direction_val < 0
		sprite.play("run")
	else:
		sprite.play("idle")
