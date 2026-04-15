extends CharacterBody2D

enum State { PATROL, CHASE, ATTACK }

# ── Exportáveis ────────────────────────────────
@export var speed: float = 80.0
@export var chase_speed: float = 140.0
@export var detection_radius: float = 500.0
@export var attack_range: float = 460.0
@export var attack_damage: int = 10
@export var attack_cooldown: float = 1.2
@export var patrol_distance: float = 120.0  # distância horizontal da patrulha

@export var max_health: int = 50
var health: int

# ── Nós ───────────────────────────────────────
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_timer: Timer = $AttackTimer
@onready var damage_timer: Timer = $DamageTime

# ── Estado interno ─────────────────────────────
var state: State = State.PATROL
var target: Node2D = null

var patrol_origin: Vector2
var patrol_dir: float = 1.0       # 1 = direita, -1 = esquerda

var can_attack: bool = true
var _flashing: bool = false

# ──────────────────────────────────────────────
func _ready() -> void:
	health = max_health
	patrol_origin = global_position

	attack_timer.wait_time = attack_cooldown
	attack_timer.one_shot = true
	attack_timer.timeout.connect(_on_attack_timer_timeout)
	
	damage_timer.wait_time = 0.2  # delay até o golpe conectar
	damage_timer.one_shot = true
	damage_timer.timeout.connect(_on_damage_timer_timeout)
	
	print("Inimigo iniciado em: ", global_position)
	var players := get_tree().get_nodes_in_group("player")
	print("Players encontrados: ", players.size())

# ──────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	# Gravidade
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Detecção direta por distância — sem precisar de Area2D
	_update_target()

	match state:
		State.PATROL:  _patrol()
		State.CHASE:   _chase()
		State.ATTACK:  _try_attack()

	move_and_slide()
	_update_animation()

# ──────────────────────────────────────────────
# DETECÇÃO
# ──────────────────────────────────────────────

func _update_target() -> void:
	
	# Não interrompe durante o ataque
	if state == State.ATTACK:
		return

	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		
		return

	var p := players[0] as Node2D
	var dist := global_position.distance_to(p.global_position)
	
	


	if dist <= attack_range:
		target = p
		_enter_attack()
	elif dist <= detection_radius:
		target = p
		if state != State.CHASE:
			_enter_chase()
	else:
		target = null
		if state != State.PATROL:
			_enter_patrol()

# ──────────────────────────────────────────────
# ESTADOS
# ──────────────────────────────────────────────

func _patrol() -> void:
	velocity.x = speed * patrol_dir
	animated_sprite.flip_h = patrol_dir < 0

	var dist_from_origin := global_position.x - patrol_origin.x
	if dist_from_origin >= patrol_distance:
		patrol_dir = -1.0
	elif dist_from_origin <= -patrol_distance:
		patrol_dir = 1.0

	if is_on_wall():
		patrol_dir *= -1.0

func _chase() -> void:
	if not is_instance_valid(target):
		_enter_patrol()
		return

	var diff := target.global_position.x - global_position.x

	# Pequena margem para não ficar tremendo quando está muito próximo
	if abs(diff) > 5.0:
		velocity.x = sign(diff) * chase_speed
		animated_sprite.flip_h = diff < 0
	else:
		velocity.x = 0.0
		
		
# ──────────────────────────────────────────────
# ATAQUE
# ──────────────────────────────────────────────

func _try_attack() -> void:
	
	
	if not is_instance_valid(target):
		_enter_patrol()
		return

	# Se o player saiu do alcance, volta a perseguir
	var dist := global_position.distance_to(target.global_position)
	
	if dist > attack_range:
		_enter_chase()
		return

	# Para o movimento horizontal mas mantém a gravidade intacta
	velocity.x = 0.0

	# Vira para o player
	var diff := target.global_position.x - global_position.x
	animated_sprite.flip_h = diff < 0

	if can_attack:
		_do_attack()


func _do_attack() -> void:
	
	can_attack = false
	animated_sprite.play("attack")
	attack_timer.start()   # controla o cooldown entre ataques
	damage_timer.start()   # controla quando o dano é aplicado

	# Aplica dano com um pequeno delay (simula o frame do golpe)
	

	# Verifica se o player ainda está no alcance antes de aplicar o dano
	if is_instance_valid(target):
		var dist := global_position.distance_to(target.global_position)
		if dist <= attack_range:
			if target.has_method("take_damage"):
				target.take_damage(attack_damage)

func _on_damage_timer_timeout() -> void:
	# Aplica o dano quando o golpe conecta
	if is_instance_valid(target):
		var dist := global_position.distance_to(target.global_position)
		if dist <= attack_range:
			if target.has_method("take_damage"):
				target.take_damage(attack_damage)

func _on_attack_timer_timeout() -> void:
	can_attack = true
	if animated_sprite.animation == "attack":
		animated_sprite.play("idle")
# ──────────────────────────────────────────────
# DANO / MORTE
# ──────────────────────────────────────────────

func take_damage(amount: int) -> void:
	health = clamp(health - amount, 0, max_health)
	_flash(Color.RED)
	if health == 0:
		_die()

func _die() -> void:
	queue_free()

# ──────────────────────────────────────────────
# ANIMAÇÃO
# ──────────────────────────────────────────────

func _update_animation() -> void:
	match state:
		State.PATROL, State.CHASE:
			if abs(velocity.x) > 1.0:
				if animated_sprite.animation != "walk":
					animated_sprite.play("walk")
				# Remova o flip_h daqui — já é feito no _patrol() e _chase()
			else:
				if animated_sprite.animation != "idle":
					animated_sprite.play("idle")
		State.ATTACK:
			pass

# ──────────────────────────────────────────────
# FLASH DE DANO
# ──────────────────────────────────────────────

func _flash(color: Color, duration: float = 0.15) -> void:
	if _flashing:
		return
	_flashing = true
	animated_sprite.modulate = color
	await get_tree().create_timer(duration).timeout
	animated_sprite.modulate = Color.WHITE
	_flashing = false

# ──────────────────────────────────────────────
# TRANSIÇÕES
# ──────────────────────────────────────────────



func _enter_patrol() -> void:
	state = State.PATROL
	target = null

func _enter_chase() -> void:
	state = State.CHASE
	

func _enter_attack() -> void:
	state = State.ATTACK
	velocity.x = 0.0
