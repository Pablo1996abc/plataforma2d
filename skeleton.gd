extends CharacterBody2D

enum State { PATROL, CHASE, ATTACK, HURT }

# ── Exportáveis ────────────────────────────────
@export var speed: float = 80.0
@export var chase_speed: float = 140.0
@export var detection_radius: float = 800.0
@export var attack_range: float = 73.0
@export var attack_damage: int = 10
@export var attack_cooldown: float = 1.5
@export var patrol_distance: float = 140.0
@export var max_health: int = 50

# ── Nós ───────────────────────────────────────
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_timer: Timer = $AttackTimer
@onready var damage_timer: Timer = $DamageTimer
@onready var ray: RayCast2D = $RayCast2D

# ── Estado interno ─────────────────────────────
var state: State = State.PATROL
var target: Node2D = null
var patrol_origin: Vector2
var patrol_dir: float = 1.0
var can_attack: bool = true
var _flashing: bool = false
var health: int
var hurt_timer: float = 0.0
const HURT_DURATION: float = 0.5

# ──────────────────────────────────────────────
func _ready() -> void:
	health = max_health
	patrol_origin = global_position

	attack_timer.wait_time = attack_cooldown
	attack_timer.one_shot = true
	attack_timer.timeout.connect(_on_attack_timer_timeout)

	damage_timer.wait_time = 0.3
	damage_timer.one_shot = true
	damage_timer.timeout.connect(_on_damage_timer_timeout)

# ──────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	# Atualiza timer de hurt
	if state == State.HURT:
		hurt_timer -= delta
		if hurt_timer <= 0.0:
			state = State.PATROL
		velocity.x = move_toward(velocity.x, 0, speed)
		move_and_slide()
		_update_animation()
		return  # não processa mais nada enquanto está em hurt

	if not is_on_floor():
		velocity += get_gravity() * delta

	match state:
		State.PATROL:  _do_patrol()
		State.CHASE:   _do_chase()
		State.ATTACK:  _do_attack_state()

	move_and_slide()
	_update_animation()

# ──────────────────────────────────────────────
# PATRULHA
# ──────────────────────────────────────────────
func _do_patrol() -> void:
	var p := _get_player()
	if p != null:
		var dist := global_position.distance_to(p.global_position)
		var vertical_diff: float = abs(global_position.y - p.global_position.y)

		if dist <= detection_radius and vertical_diff < 50.0:
			target = p
			state = State.CHASE
			return

	velocity.x = speed * patrol_dir
	animated_sprite.flip_h = patrol_dir < 0

	var dist_origin := global_position.x - patrol_origin.x
	if dist_origin >= patrol_distance:
		patrol_dir = -1.0
	elif dist_origin <= -patrol_distance:
		patrol_dir = 1.0

	if is_on_wall():
		patrol_dir *= -1.0

# ──────────────────────────────────────────────
# PERSEGUIÇÃO
# ──────────────────────────────────────────────
func _do_chase() -> void:
	var p := _get_player()
	if p == null:
		state = State.PATROL
		return

	var dist := global_position.distance_to(p.global_position)
	var vertical_diff: float = abs(global_position.y - p.global_position.y)

	if dist > detection_radius or vertical_diff >= 50.0:
		target = null
		state = State.PATROL
		return

	if dist <= attack_range:
		target = p
		state = State.ATTACK
		return

	target = p
	var diff := p.global_position.x - global_position.x
	velocity.x = sign(diff) * chase_speed
	animated_sprite.flip_h = diff < 0

# ──────────────────────────────────────────────
# ATAQUE
# ──────────────────────────────────────────────
func _do_attack_state() -> void:
	velocity.x = 0.0

	if not is_instance_valid(target):
		state = State.PATROL
		return

	var dist := global_position.distance_to(target.global_position)

	if dist > attack_range:
		state = State.CHASE
		return

	var diff := target.global_position.x - global_position.x
	animated_sprite.flip_h = diff < 0

	if can_attack:
		can_attack = false
		animated_sprite.play("attack")
		attack_timer.start()
		damage_timer.start()

func _on_damage_timer_timeout() -> void:
	if not is_instance_valid(target):
		return
	var dist := global_position.distance_to(target.global_position)
	if dist <= attack_range:
		if target.has_method("take_damage"):
			target.take_damage(attack_damage)
			_flash(Color.ORANGE)

func _on_attack_timer_timeout() -> void:
	can_attack = true

# ──────────────────────────────────────────────
# DANO / MORTE
# ──────────────────────────────────────────────
func take_damage(amount: int) -> void:
	health = clamp(health - amount, 0, max_health)
	_flash(Color.RED)
	if health == 0:
		_die()
		return
	# Entra no estado HURT
	state = State.HURT
	hurt_timer = HURT_DURATION
	can_attack = true  # reseta o ataque para não travar

func _die() -> void:
	animated_sprite.play("death")
	await animated_sprite.animation_finished
	queue_free()

func _flash(color: Color, duration: float = 0.15) -> void:
	if _flashing:
		return
	_flashing = true
	animated_sprite.modulate = color
	await get_tree().create_timer(duration).timeout
	animated_sprite.modulate = Color.WHITE
	_flashing = false

# ──────────────────────────────────────────────
# ANIMAÇÃO
# ──────────────────────────────────────────────
func _update_animation() -> void:
	if state == State.HURT:
		if animated_sprite.sprite_frames.has_animation("hurt"):
			animated_sprite.play("hurt")
		return

	if state == State.ATTACK:
		return

	if abs(velocity.x) > 1.0:
		if animated_sprite.animation != "walk":
			animated_sprite.play("walk")
	else:
		if animated_sprite.animation != "idle":
			animated_sprite.play("idle")

# ──────────────────────────────────────────────
# UTILITÁRIO
# ──────────────────────────────────────────────
func _get_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return null

	var p := players[0] as Node2D

	ray.target_position = to_local(p.global_position)
	ray.force_raycast_update()

	if ray.is_colliding():
		var collider = ray.get_collider()
		var node = collider
		while node != null:
			if node == p:
				return p
			node = node.get_parent()

	return null
