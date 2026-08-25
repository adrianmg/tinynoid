class_name StageClearScreen
extends ResultScreenBase

signal replay_requested

const GREEN := Color("#56d46f")


func _ready() -> void:
	var title := (
		"LAB CLEAR"
		if GameSession.is_community_run()
		else "DAILY CLEAR"
		if GameSession.is_daily_run()
		else "CAMPAIGN CLEAR"
		if GameSession.level >= LevelCatalog.STAGE_COUNT
		else "STAGE %02d CLEAR" % GameSession.level
	)
	var action_label := (
		"MAIN MENU"
		if (
			GameSession.is_community_run()
			or GameSession.is_daily_run()
			or GameSession.level >= LevelCatalog.STAGE_COUNT
		)
		else "CONTINUE"
	)
	var outcome := (
		"daily_clear"
		if GameSession.is_daily_run()
		else
		"campaign_clear"
		if GameSession.level >= LevelCatalog.STAGE_COUNT
		else "stage_clear"
	)
	configure_result(
		title,
		GREEN,
		action_label,
		outcome,
		not GameSession.is_community_run()
		and (
			GameSession.is_daily_run()
			or GameSession.level >= LevelCatalog.STAGE_COUNT
		)
	)
	super._ready()


func _request_primary_action() -> void:
	replay_requested.emit()
