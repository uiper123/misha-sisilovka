extends Area3D
class_name HitboxComponent

@export var damage_multiplier: float = 1.0
@export var health_component: HealthComponent

func damage(amount: float) -> void:
	if health_component:
		health_component.damage(amount * damage_multiplier)
