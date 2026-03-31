extends CharacterBody2D

# Configurações de combate e movimento
@export var speed = 80.0
@export var chase_speed = 120.0
@export var health = 3
const GRAVITY = 980.0

# Referências
@onready var sprite = $AnimatedSprite2D
@onready var floor_detector = $RayCast2D # Para não cair de buracos
@onready var player_detector = $PlayerDetector # Area2D para ver o player

# Estados
var direction = 1 # 1 para direita, -1 para esquerda
var player_to_chase = null
var is_dead = false

func _physics_process(delta):
	if is_dead:
		return

	# 1. Aplicar Gravidade
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	# 2. Lógica de IA: Perseguir ou Patrulhar
	if player_to_chase:
		chase_player()
	else:
		patrol()

	move_and_slide()
	update_animation()

func patrol():
	velocity.x = direction * speed
	
	# Inverter direção ao bater em paredes ou chegar em um buraco
	if is_on_wall() or not floor_detector.is_colliding():
		direction *= -1
		scale.x = -scale.x # Vira o esqueleto (e o RayCast junto)

func chase_player():
	# Calcula a direção até o player
	var dir_to_player = sign(player_to_chase.global_position.x - global_position.x)
	velocity.x = dir_to_player * chase_speed
	
	# Ajusta o lado que o sprite olha
	if dir_to_player != 0:
		sprite.flip_h = dir_to_player < 0

func update_animation():
	if velocity.x != 0:
		sprite.play("walk")
	else:
		sprite.play("idle")
	
	# Inverter sprite na patrulha (opcional, dependendo de como o scale funciona)
	if not player_to_chase:
		sprite.flip_h = direction < 0

# --- SINAIS DO PLAYER DETECTOR (Area2D) ---

func _on_player_detector_body_entered(body):
#	if body.name == "Player": # Certifique-se que o nome do nó do seu personagem é "Player"
#		player_to_chase = body

func _on_player_detector_body_exited(body):
#	if body == player_to_chase:
#		player_to_chase = null

# Função para quando ele levar dano (chamada pelo seu personagem)
func take_damage(amount):
	health -= amount
	if health <= 0:
		die()

func die():
	is_dead = true
	velocity.x = 0
	sprite.play("death")
	# Espera a animação acabar ou um tempo para sumir
	await get_tree().create_timer(1.0).timeout
	queue_free()
