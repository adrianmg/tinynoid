class_name CapsuleDropDirector
extends RefCounted

signal starter_pool_consumed

const NO_DROP := -1
const MAX_FALLING_CAPSULES := 2
const TIMING_SEED_SALT := 0x13579BDF
const TYPE_SEED_SALT := 0x2468ACE0


class DropSnapshot:
	extends RefCounted

	var remaining_bricks: int
	var falling_capsules: int
	var active_power_up: int
	var balls_remaining: int
	var active_ball_count: int

	func _init(
		remaining_bricks_value: int,
		falling_capsules_value: int,
		active_power_up_value: int,
		balls_remaining_value: int,
		active_ball_count_value: int
	) -> void:
		remaining_bricks = remaining_bricks_value
		falling_capsules = falling_capsules_value
		active_power_up = active_power_up_value
		balls_remaining = balls_remaining_value
		active_ball_count = active_ball_count_value


var _timing_rng := RandomNumberGenerator.new()
var _type_rng := RandomNumberGenerator.new()
var _initial_brick_count: int
var _drop_budget: int
var _drops_spawned := 0
var _eligible_breaks_since_spawn := 0
var _last_spawned_type := NO_DROP
var _starter_pool_pending: bool


func _init(
	run_seed: int,
	stage_number: int,
	destructible_brick_count: int,
	starter_pool_pending: bool
) -> void:
	assert(run_seed >= 0, "The capsule run seed cannot be negative.")
	assert(stage_number > 0, "The capsule stage number must be positive.")
	assert(destructible_brick_count > 0, "A capsule stage requires destructible bricks.")

	_initial_brick_count = destructible_brick_count
	_drop_budget = calculate_budget(destructible_brick_count)
	_starter_pool_pending = starter_pool_pending
	_timing_rng.seed = _mix_seed(run_seed, stage_number, TIMING_SEED_SALT)
	_type_rng.seed = _mix_seed(run_seed, stage_number, TYPE_SEED_SALT)


static func calculate_budget(destructible_brick_count: int) -> int:
	assert(destructible_brick_count > 0, "A capsule budget requires destructible bricks.")
	return clampi(floori(float(destructible_brick_count + 4) / 8.0), 2, 8)


func on_brick_destroyed(snapshot: DropSnapshot) -> int:
	assert(snapshot != null, "Capsule drop decisions require a gameplay snapshot.")
	assert(
		snapshot.remaining_bricks >= 0
		and snapshot.remaining_bricks < _initial_brick_count,
		"Remaining bricks must reflect the destruction that triggered this decision."
	)
	if (
		snapshot.remaining_bricks == 0
		or _drops_spawned >= _drop_budget
		or snapshot.falling_capsules >= MAX_FALLING_CAPSULES
	):
		return NO_DROP

	_eligible_breaks_since_spawn += 1
	var chance := _get_drop_chance()
	if chance <= 0.0:
		return NO_DROP
	if chance < 1.0 and _timing_rng.randf() >= chance:
		return NO_DROP

	var power_type := _select_power_type(snapshot)
	_drops_spawned += 1
	_eligible_breaks_since_spawn = 0
	_last_spawned_type = power_type
	if _starter_pool_pending:
		_starter_pool_pending = false
		starter_pool_consumed.emit()

	return power_type


func _get_drop_chance() -> float:
	if _drops_spawned == 0:
		match _eligible_breaks_since_spawn:
			3:
				return 0.25
			4:
				return 0.45
			5:
				return 0.70
			6:
				return 1.0
			_:
				return 0.0

	match _eligible_breaks_since_spawn:
		3, 4, 5:
			return 0.05
		6:
			return 0.10
		7:
			return 0.20
		8:
			return 0.35
		9:
			return 0.60
		10:
			return 1.0

	return 0.0


func _select_power_type(snapshot: DropSnapshot) -> int:
	if _starter_pool_pending:
		return _weighted_choice({
			PowerUp.PowerType.WIDE: 45.0,
			PowerUp.PowerType.SLOW: 35.0,
			PowerUp.PowerType.MULTI: 20.0,
		})

	var weights: Dictionary[int, float] = {
		PowerUp.PowerType.WIDE: 22.0,
		PowerUp.PowerType.SLOW: 18.0,
		PowerUp.PowerType.MULTI: 16.0,
		PowerUp.PowerType.CATCH: 14.0,
		PowerUp.PowerType.LASER: 12.0,
		PowerUp.PowerType.THRU: 10.0,
		PowerUp.PowerType.EXTRA_BALL: 6.0,
		PowerUp.PowerType.BREAK: 2.0,
	}
	if _last_spawned_type >= 0:
		weights[_last_spawned_type] = 0.0
	if snapshot.active_power_up >= 0:
		weights[snapshot.active_power_up] = 0.0

	if snapshot.balls_remaining <= 1:
		weights[PowerUp.PowerType.EXTRA_BALL] *= 1.5
	elif snapshot.balls_remaining >= 4:
		weights[PowerUp.PowerType.EXTRA_BALL] *= 0.5

	if snapshot.active_ball_count <= 1:
		weights[PowerUp.PowerType.MULTI] *= 1.25
	else:
		weights[PowerUp.PowerType.MULTI] *= 0.5

	if snapshot.remaining_bricks <= 8:
		weights[PowerUp.PowerType.LASER] *= 0.75
		weights[PowerUp.PowerType.THRU] *= 0.75

	var destroyed_bricks := _initial_brick_count - snapshot.remaining_bricks
	if destroyed_bricks * 2 < _initial_brick_count or snapshot.remaining_bricks < 6:
		weights[PowerUp.PowerType.BREAK] = 0.0

	return _weighted_choice(weights)


func _weighted_choice(weights: Dictionary[int, float]) -> int:
	var total_weight := 0.0
	for power_type in weights:
		total_weight += weights[power_type]
	assert(total_weight > 0.0, "At least one capsule type must remain selectable.")

	var roll := _type_rng.randf() * total_weight
	var fallback := NO_DROP
	for power_type in weights:
		var weight := weights[power_type]
		if weight <= 0.0:
			continue
		fallback = power_type
		roll -= weight
		if roll <= 0.0:
			return power_type

	return fallback


static func _mix_seed(run_seed: int, stage_number: int, salt: int) -> int:
	var mixed := (run_seed ^ salt) & 0x7fffffff
	mixed = (
		mixed * 1103515245
		+ stage_number * 12345
		+ 12345
	) & 0x7fffffff
	return mixed
