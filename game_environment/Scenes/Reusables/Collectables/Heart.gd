extends Node2D

@export var cooldown_duration: int = 10
@export var amount: int = 10

var in_cooldown: bool = false

func _on_enter_box_body_entered(body) -> void:
	if body.name == "Aurora" and not in_cooldown:
		in_cooldown = true
		$"../Aurora".ai_controller.reward += 0.5 * (1 - Player.get_hp() / Player.get_max_hp())
		Player.add_hp(amount)
		$AnimatedSprite2D.hide()
		await get_tree().create_timer(cooldown_duration).timeout
		in_cooldown = false
		$AnimatedSprite2D.show()
		
