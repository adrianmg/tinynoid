class_name ResultScreenBase
extends Control

const PANEL := Color("#111329")
const RAIL_DARK := Color("#12345b")
const BLUE := Color("#287fc4")
const CYAN := Color("#74ddff")
const WHITE := Color("#f7f4ff")
const YELLOW := Color("#ffd84a")
const OPTION_Y := [151, 166, 181]

var result_title := ""
var result_color := WHITE
var primary_label := ""
var share_outcome := "game_over"
var share_enabled := true
var _selected_index := 0
var _share_png := PackedByteArray()
var _share_status := ""
var _score_status := ""


func configure_result(
	title: String,
	color: Color,
	action_label: String,
	outcome: String,
	can_share: bool = true
) -> void:
	result_title = title
	result_color = color
	primary_label = action_label
	share_outcome = outcome
	share_enabled = can_share


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	AvatarCache.avatar_updated.connect(_on_avatar_updated)
	if share_enabled:
		Leaderboard.score_submitted.connect(_on_score_submitted)
		Leaderboard.submission_failed.connect(_on_submission_failed)
		_update_score_status()
	queue_redraw()
	call_deferred("_prepare_share_image")


func _draw() -> void:
	draw_rect(Rect2(28, 58, 200, 136), PANEL)
	draw_rect(Rect2(28, 58, 200, 2), result_color)
	draw_rect(Rect2(28, 192, 200, 2), BLUE)
	PixelFont.draw_centered(self, "TINYNOID", 10, CYAN)
	PixelFont.draw_centered(self, result_title, 76, result_color, 2)

	var player_name := PlayerProfile.get_display_name()
	if PlayerProfile.has_player_name():
		_draw_identity_row(player_name)
	else:
		PixelFont.draw_centered(self, player_name, 105, WHITE)
	PixelFont.draw_centered(self, "SCORE", 118, WHITE)
	PixelFont.draw_centered(self, "%06d" % GameSession.score, 128, YELLOW)
	if share_enabled and not _score_status.is_empty():
		PixelFont.draw_centered(self, _score_status, 139, CYAN)

	for option_index in range(_option_count()):
		var option_rect := _get_option_rect(option_index)
		if option_index == _selected_index:
			draw_rect(option_rect, RAIL_DARK)
			draw_rect(
				Rect2(option_rect.position, Vector2(1, option_rect.size.y)),
				CYAN
			)
		PixelFont.draw_centered(
			self,
			_get_option_label(option_index),
			OPTION_Y[option_index],
			YELLOW if option_index == _selected_index else WHITE
		)

	if not _share_status.is_empty():
		PixelFont.draw_centered(self, _share_status, 207, CYAN)


func _unhandled_input(event: InputEvent) -> void:
	var viewport := get_viewport()
	if event.is_action_pressed("ui_up"):
		_select_relative(-1)
	elif event.is_action_pressed("ui_down"):
		_select_relative(1)
	elif event.is_action_pressed("restart"):
		_request_primary_action()
	elif event.is_action_pressed("launch") or event.is_action_pressed("ui_accept"):
		_activate_selected()
	else:
		return

	if is_instance_valid(viewport):
		viewport.set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var hovered := _get_option_at(event.position)
		if hovered >= 0 and hovered != _selected_index:
			_selected_index = hovered
			UiAudio.play_move()
			queue_redraw()
	elif (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed
	):
		var clicked := _get_option_at(event.position)
		if clicked >= 0:
			_selected_index = clicked
			accept_event()
			_activate_selected()


func get_selected_index() -> int:
	return _selected_index


func _select_relative(direction: int) -> void:
	_selected_index = posmod(_selected_index + direction, _option_count())
	UiAudio.play_move()
	queue_redraw()


func _activate_selected() -> void:
	UiAudio.play_confirm()
	if _selected_index == 0:
		_request_primary_action()
		return

	if _selected_index == 1:
		var twitter_opened := ScoreShare.share_on_twitter(
			PlayerProfile.get_display_name(),
			GameSession.score,
			share_outcome
		)
		_share_status = (
			"TWITTER OPENED"
			if twitter_opened
			else "TWITTER UNAVAILABLE"
		)
		queue_redraw()
		return

	if _share_png.is_empty():
		_share_status = "PREPARING SCORE CARD"
		queue_redraw()
		return
	var shared := ScoreShare.share(
		PlayerProfile.get_display_name(),
		GameSession.score,
		share_outcome,
		_share_png
	)
	_share_status = "SHARE OPENED" if shared else "SHARE UNAVAILABLE"
	queue_redraw()


func _request_primary_action() -> void:
	push_error("Result screen primary action is not implemented.")


func _prepare_share_image() -> void:
	await RenderingServer.frame_post_draw
	if not is_inside_tree():
		return
	var image := get_viewport().get_texture().get_image()
	_share_png = image.save_png_to_buffer()


func _update_score_status() -> void:
	if Leaderboard.has_pending_submission(GameSession.run_id):
		_score_status = "SENDING TO HIGH SCORES"
	elif (
		GameSession.run_start_stage == 1
		and PlayerProfile.has_player_name()
	):
		_score_status = "ADDED TO HIGH SCORES"
	else:
		_score_status = "SAVED ON THIS DEVICE"


func _on_score_submitted(run_id: String, _created: bool) -> void:
	if run_id != GameSession.run_id:
		return
	_score_status = "ADDED TO HIGH SCORES"
	queue_redraw()
	call_deferred("_prepare_share_image")


func _on_submission_failed(run_id: String, _message: String) -> void:
	if run_id != GameSession.run_id:
		return
	_score_status = (
		"SAVED HERE - WILL RETRY"
		if Leaderboard.has_pending_submission(run_id)
		else "SAVED ON THIS DEVICE"
	)
	queue_redraw()
	call_deferred("_prepare_share_image")


func _on_avatar_updated(_handle: String) -> void:
	queue_redraw()
	call_deferred("_prepare_share_image")


func _get_option_rect(option_index: int) -> Rect2:
	return Rect2(52, OPTION_Y[option_index] - 3, 152, 11)


func _get_option_at(position: Vector2) -> int:
	for option_index in range(_option_count()):
		if _get_option_rect(option_index).has_point(position):
			return option_index
	return -1


func _option_count() -> int:
	return 3 if share_enabled else 1


func _get_option_label(option_index: int) -> String:
	match option_index:
		0:
			return primary_label
		1:
			return "SHARE ON TWITTER"
		2:
			return "SHARE"
	return ""


func _draw_identity_row(player_name: String) -> void:
	var text_size := PixelFont.measure(player_name)
	var group_width := 8.0 + 2.0 + text_size.x
	var group_x := floorf((256.0 - group_width) / 2.0)
	PixelAvatar.draw(self, player_name, Vector2(group_x, 103))
	PixelFont.draw_text(
		self,
		player_name,
		Vector2(group_x + 10.0, 105),
		WHITE
	)
