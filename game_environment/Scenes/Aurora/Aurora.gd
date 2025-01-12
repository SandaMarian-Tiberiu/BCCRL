extends CharacterBody2D 
class_name Aurora

@export var camera_left_limit: int
@export var camera_right_limit: int
@export var camera_top_limit: int
@export var camera_bottom_limit: int
@export var max_speed: float = 300.0
@export var start_x: int = 0
@export var start_y: int = 0

var speed = 0
const JUMP_VELOCITY: float = -400.0
var attacking: bool = false
var cooldown_stun_attack: bool = false
var cooldown_base_attack: bool = false

var previous_distance = 0
var best_distance = INF
var current_game = 0
var best_time = INF
var total_time: float = 0.0
var done_cnt = 0
var dead_cnt = 0
var out_of_time = 0

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")


@onready var animation = get_node("AnimationPlayer")
@onready var game_over = preload("res://Scenes/GameOver/GameOver.tscn").instantiate()
@onready var camera = $Camera2D
@onready var ai_controller = $"../AIController2D"
@onready var finish = $"../NextLevelPortal/CollisionShape2D".global_position


@onready var tilemap = $"../TileMap"
var matrix = null
@onready var raycast = $RaycastSensor2D

func _ready() -> void:
	camera.limit_left = camera_left_limit
	camera.limit_right = camera_right_limit
	camera.limit_top = camera_top_limit
	camera.limit_bottom = camera_bottom_limit
	
	# Connect the signal_event signal from the Dialogisc singleton to the dialogic_signal function.
	Dialogic.signal_event.connect(dialogic_signal)
	ai_controller.init(self)
	matrix = tilemap.export_tilemap(tilemap)


func _physics_process(delta: float) -> void:
	#ai_controller.reward += get_reward()
	#ai_controller.reward += -0.1 
	#print(get_reward())
	# Add the gravity.
	if not is_on_floor():
		velocity.y += gravity * delta
	
	# Deletes the player when it dies.
	if Player.is_dead():
		dead_cnt += 1
		print("DEAD")
		reset()
	
	# Handle cutscenes.
	if Game.is_in_cutscene():
		velocity.x = speed
		update_animation()
		move_and_slide()
		return
	
	# Handle base attack.
	if Input.is_action_just_pressed("base_attack") or ai_controller.basic_attack:
		attack()
		
	# Handle jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		
	# Handle ability.
	if Input.is_action_just_pressed("stun") or ai_controller.stun_attack:
		stun()
	
	# Get the input direction and handle the movement/deceleration.
	var direction = Input.get_axis("move_left", "move_right")
	var direction2 = round(ai_controller.move_action)
	if ai_controller.jump_action and is_on_floor():
		velocity.y = JUMP_VELOCITY
	#print(direction2)
	if direction2 < 0: 
		get_node("Sprite").flip_h = true;
		if $Attack/BaseAttack.position.x > 0:
			$Attack/BaseAttack.position.x *= -1
	elif direction2:
		get_node("Sprite").flip_h = false;
		if $Attack/BaseAttack.position.x < 0:
			$Attack/BaseAttack.position.x *= -1
	
	if direction2:
		velocity.x = direction2 * max_speed
	else:
		velocity.x = move_toward(velocity.x, 0, max_speed)
	update_animation()
	move_and_slide()
	

func attack():
	# Can only attack when ability is not in cooldown
	if not cooldown_base_attack:
		cooldown_base_attack = true
		attacking = true
		animation.play("Attack" + Player.get_skin())
		base_attack()

	
func stun():
	# Can only stun when ability is not in cooldown
	if not cooldown_stun_attack:
		attacking = true
		animation.play("Stun" + Player.get_skin())
		stun_ability()
		$WinkSFX.play()
	else:
		ai_controller.reward -= 0.1


# Function for updating the animation based on the character's state.
func update_animation() -> void:
	if attacking:
		return
	if velocity.x != 0:
		animation.play("Run" + Player.get_skin())	
	else:
		animation.play("Idle" + Player.get_skin())
		
	if velocity.y < 0:
		animation.play("Up" + Player.get_skin())
	if velocity.y > 0:
		animation.play("Down" + Player.get_skin())
	

# Function for handling damage taken by the character.
func take_damage(damage: int) -> void:
	if not Game.in_god_mode():
		Player.take_damage(damage)
	
	ai_controller.reward -= damage / 100 * 1.5
	# Flash the sprite red when taking damage.
	$Sprite.modulate = Color.RED
	await get_tree().create_timer(0.1).timeout
	$Sprite.modulate = Color.WHITE	
	$GettingHitSFX.play()
	

# Function for handling the stun ability.
func stun_ability() -> void:
	# Enables collision for 0.1 secs to register if hit
	var collision = get_node("Stun/Stun")
	collision.disabled = false
	
	cooldown_stun_attack = true 
	$StunTimer.start()
	await get_tree().create_timer(0.1).timeout
	
	# Disables collision afterwards
	collision.disabled = true


# Function for handling the base attack.
func base_attack() -> void:
	# Enables collision for 0.1 secs to register if hit
	var collision = get_node("Attack/BaseAttack")
	collision.disabled = false
	
	# Sound for attack
	$SwingSFX.play()
	
	cooldown_base_attack = true
	$BasicAttackTimer.start()
	await get_tree().create_timer(0.1).timeout
	
	# Disables collision afterwards
	collision.disabled = true
	

# Callback for when an animation finishes playing.
func _on_animation_player_animation_finished(anim_name: String) -> void:
	if anim_name == "Attack" + Player.get_skin() or anim_name == "Stun" + Player.get_skin():
		attacking = false


# Callback for when the base attack cooldown timer times out.
func _on_timer_timeout() -> void:
	cooldown_base_attack = false;


# Callback for when the stun attack cooldown timer times out.
func _on_stun_timer_timeout() -> void:
	cooldown_stun_attack = false;

#
func dialogic_signal(signal_name: String) -> void:
	if signal_name.contains("run"):
		speed = 10
		await get_tree().create_timer(float(signal_name.split(".")[1])).timeout
		speed = 0


func get_local_matrix(grid_pos: Vector2, radius: int) -> Array:
	var cropped = []
	var finish_var = Vector2(
		int(finish.x / 16),
		int(finish.y / 16)
	)
	for y in range(grid_pos.y - radius, grid_pos.y + radius + 1):
		var row = []
		for x in range(grid_pos.x - radius, grid_pos.x + radius + 1):
			if y >= 0 and y < matrix.size() and x >= 0 and x < matrix[y].size():
				if finish_var.y == y and finish_var.x == x:
					row.append(2)
				else:
					row.append(matrix[y][x])
			else:
				row.append(1)
		cropped.append(row)
	
	return cropped
			

func reset():
	$"..".reset()
	Player.reset()
	Game.reset()
	global_position = Vector2(start_x, start_y)
	current_game += 1
	print("Done rate: " + str(done_cnt / float(current_game) * 100))
	print("Dead rate: " + str(dead_cnt / float(current_game) * 100))
	print("Out of time rate: " + str(out_of_time / float(current_game) * 100))
	print("Average completion time: " + str(total_time / float(done_cnt)))
	print("Current time: " + str(600 - $"../Timer".get_time_left()))
	print("Best time: " + str(best_time))
	print()
	print("Iteration: " + str(current_game))
	$"../Timer".start()
	ai_controller.reset()
	best_distance = INF
	
	
func _on_timer_timeout2():
	ai_controller.reward -= 1.0
	out_of_time += 1
	print("run out of time")
	reset()



func get_reward() -> float:
	var current_distance = finish.distance_to(global_position)
	#current_distance = abs(finish.x - global_position.x)
	#var max_distance = 70 * 16 + 30 * 16
	#return -(1 - current_distance / max_distance)
	#
	if current_distance < best_distance:
		best_distance = current_distance
		#print("best")
		previous_distance = current_distance
		return 0.3

	if current_distance < previous_distance:
		#print("closer")
		previous_distance = current_distance
		
		return 0.1
	
	#print("further")
	previous_distance = current_distance
	return 0
	
	var rew = (previous_distance - current_distance) / 100
	previous_distance = current_distance
	return rew
	
