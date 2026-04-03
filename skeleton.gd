extends CharacterBody2D

enum State { PATROL, CHASE, ATTACK }

@export var speed: float = 80.0
@export var chase_speed: float = 140.0
@export var detection_radius: float = 200.0
@export var attack_range: float = 50.0
@export var attack_damage: int = 10
@export var attack_cooldown: float = 1.2
@export var patrol_radius: float = 150.0

@export var max_health: int = 100
var health: int = max_health

# Sinal emitido sempre que a vida mudar (útil para atualizar HUD)
signal health_changed(current: int, maximum: int)
signal died

@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
@onready var detection_area: Area2D = $DetectionArea
@onready var attack_area: Area2D = $AttackArea
@onready var attack_timer: Timer = $AttackTimer
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var state: State = State.PATROL
var target: Node2D = null
var patrol_origin: Vector2
var patrol_target: Vector2
var can_attack: bool = true

func _ready() -> void:
	patrol_origin = global_position
	_pick_patrol_point()

	attack_timer.wait_time = attack_cooldown
	attack_timer.one_shot = true
	attack_timer.timeout.connect(_on_attack_timer_timeout)

	# Configura raios das áreas via código (opcional — pode ajustar na cena)
	var det_shape := detection_area.get_node("CollisionShape2D")
	(det_shape.shape as CircleShape2D).radius = detection_radius

	var atk_shape := attack_area.get_node("CollisionShape2D")
	(atk_shape.shape as CircleShape2D).radius = attack_range

	detection_area.body_entered.connect(_on_detection_body_entered)
	detection_area.body_exited.connect(_on_detection_body_exited)

func _physics_process(delta: float) -> void:
	match state:
		State.PATROL:
			_patrol()
		State.CHASE:
			_chase()
		State.ATTACK:
			_try_attack()

	move_and_slide()
	_update_animation()

# ──────────────────────────────────────────────
# ESTADOS
# ──────────────────────────────────────────────

func _patrol() -> void:
	if global_position.distance_to(patrol_target) < 10.0:
		_pick_patrol_point()

	nav_agent.target_position = patrol_target
	var next := nav_agent.get_next_path_position()
	velocity = (next - global_position).normalized() * speed

func _chase() -> void:
	if not is_instance_valid(target):
		_enter_patrol()
		return

	var dist := global_position.distance_to(target.global_position)

	if dist <= attack_range:
		_enter_attack()
		return

	nav_agent.target_position = target.global_position
	var next := nav_agent.get_next_path_position()
	velocity = (next - global_position).normalized() * chase_speed

func _try_attack() -> void:
	if not is_instance_valid(target):
		_enter_patrol()
		return

	var dist := global_position.distance_to(target.global_position)

	if dist > attack_range:
		_enter_chase()
		return

	velocity = Vector2.ZERO

	if can_attack:
		_do_attack()

# ──────────────────────────────────────────────
# AÇÕES
# ──────────────────────────────────────────────

func _do_attack() -> void:
	can_attack = false
	attack_timer.start()

	# Aplica dano se o alvo ainda está na área de ataque
	for body in attack_area.get_overlapping_bodies():
		if body.has_method("take_damage"):
			body.take_damage(attack_damage)

	animated_sprite.play("attack")

func _on_attack_timer_timeout() -> void:
	can_attack = true

# ──────────────────────────────────────────────
# TRANSIÇÕES DE ESTADO
# ──────────────────────────────────────────────

func _enter_patrol() -> void:
	state = State.PATROL
	target = null
	_pick_patrol_point()

func _enter_chase() -> void:
	state = State.CHASE

func _enter_attack() -> void:
	state = State.ATTACK
	velocity = Vector2.ZERO

# ──────────────────────────────────────────────
# DETECÇÃO
# ──────────────────────────────────────────────

func _on_detection_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		target = body
		_enter_chase()

func _on_detection_body_exited(body: Node2D) -> void:
	if body == target:
		_enter_patrol()

# ──────────────────────────────────────────────
# PATRULHA
# ──────────────────────────────────────────────

func _pick_patrol_point() -> void:
	var angle := randf() * TAU
	var dist  := randf_range(40.0, patrol_radius)
	patrol_target = patrol_origin + Vector2(cos(angle), sin(angle)) * dist

# ──────────────────────────────────────────────
# ANIMAÇÃO (adapte aos nomes das suas animações)
# ──────────────────────────────────────────────

func _update_animation() -> void:
	match state:
		State.PATROL, State.CHASE:
			if velocity.length() > 1.0:
				animated_sprite.play("walk")
				animated_sprite.flip_h = velocity.x < 0
			else:
				animated_sprite.play("idle")
		State.ATTACK:
			pass  # atacar já troca a animação em _do_attack()
			
func take_damage(amount: int) -> void:
	health = clamp(health - amount, 0, max_health)
	health_changed.emit(health, max_health)

	# Feedback visual: pisca em vermelho
	_flash(Color.RED)

	if health == 0:
		_die()

func heal(amount: int) -> void:
	health = clamp(health + amount, 0, max_health)
	health_changed.emit(health, max_health)

func _die() -> void:
	died.emit()
	# Substitua pela sua lógica: animação de morte, reload de cena, etc.
	queue_free()

func _flash(color: Color, duration: float = 0.15) -> void:
	var sprite := $AnimatedSprite2D  # ajuste ao nó do seu sprite
	sprite.modulate = color
	await get_tree().create_timer(duration).timeout
	sprite.modulate = Color.WHITE
