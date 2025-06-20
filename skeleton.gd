extends CharacterBody2D

var hp = 3  # O inimigo começa com 3 de HP

@onready var sprite = $Sprite
@onready var collision = $CollisionShape2D

func _ready():
	# A lógica inicial do inimigo
	pass

func take_damage(damage: int):
	# Quando o inimigo recebe dano
	hp -= damage
	if hp <= 0:
		die()

func die():
	# Quando o inimigo morre
	queue_free()  # Remove o inimigo da cena
