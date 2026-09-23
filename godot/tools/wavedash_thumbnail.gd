extends Node

## Renders the Wavedash store thumbnail video from real gameplay, steering the
## paddle automatically. Movie Maker needs a window, so run it without --headless:
##   godot --path godot --write-movie /tmp/tinynoid-thumbnail/frame.png \
##     --fixed-fps 30 --quit-after 390 res://tools/wavedash_thumbnail.tscn
## Then scale the 256x240 frames 3x and pad them to 16:9:
##   ffmpeg -framerate 30 -i /tmp/tinynoid-thumbnail/frame%08d.png \
##     -vf "scale=768:720:flags=neighbor,pad=1280:720:256:0:color=0x050611" \
##     -c:v libx264 -crf 16 -pix_fmt yuv420p -an docs/wavedash/thumbnail.mp4

const GAMEPLAY_SCENE: PackedScene = preload("res://scenes/gameplay.tscn")
const STAGE := 1
const RUN_SEED := 8080
const ARENA_LEFT := 20.0
const ARENA_RIGHT := 236.0
const LAUNCH_INTERVAL := 0.3

var _gameplay: Gameplay
var _launch_cooldown := 0.0


func _ready() -> void:
	GameSession.new_game(STAGE, RUN_SEED)
	MusicController.play_stage(STAGE)
	_gameplay = GAMEPLAY_SCENE.instantiate()
	add_child(_gameplay)


func _physics_process(delta: float) -> void:
	var paddle := _gameplay.paddle
	var target_x := _target_x(paddle.global_position.y)
	paddle._pointer_target_x = move_toward(
		paddle.global_position.x,
		target_x,
		paddle.speed * 1.5 * delta
	)
	paddle._pointer_moved = true

	_launch_cooldown -= delta
	if _launch_cooldown <= 0.0 and (
		_has_held_ball()
		or _gameplay.has_active_power_up(PowerUp.PowerType.LASER)
	):
		_launch_cooldown = LAUNCH_INTERVAL
		_tap_launch()


func _target_x(paddle_y: float) -> float:
	var incoming: BreakerBall = null
	for candidate in _gameplay.balls.get_children():
		var active_ball := candidate as BreakerBall
		if (
			active_ball
			and active_ball.is_active()
			and active_ball._direction.y > 0.0
			and (
				incoming == null
				or active_ball.global_position.y > incoming.global_position.y
			)
		):
			incoming = active_ball
	if incoming:
		var direction := incoming._direction
		var intercept := incoming.global_position.x + (
			direction.x / maxf(direction.y, 0.2)
			* (paddle_y - incoming.global_position.y)
		)
		# Fold wall bounces back into the arena, then aim off-center for variety.
		intercept = ARENA_LEFT + pingpong(
			intercept - ARENA_LEFT,
			ARENA_RIGHT - ARENA_LEFT
		)
		return intercept + sin(incoming.global_position.x * 0.13) * 9.0

	var lowest_capsule: Node2D = null
	for capsule in _gameplay.power_ups.get_children():
		if (
			capsule is Node2D
			and (
				lowest_capsule == null
				or capsule.global_position.y > lowest_capsule.global_position.y
			)
		):
			lowest_capsule = capsule
	if lowest_capsule:
		return lowest_capsule.global_position.x
	return _gameplay.ball.global_position.x


func _has_held_ball() -> bool:
	for candidate in _gameplay.balls.get_children():
		var held_ball := candidate as BreakerBall
		if held_ball and not held_ball.is_active():
			return true
	return false


func _tap_launch() -> void:
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = &"launch"
		event.pressed = pressed
		Input.parse_input_event(event)
