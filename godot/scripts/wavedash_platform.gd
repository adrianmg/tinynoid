class_name WavedashPlatform
extends RefCounted

## The leaderboard key configured in the Wavedash Developer Portal.
const LEADERBOARD_NAME := "leaderboard"


static func is_available() -> bool:
	return OS.has_feature("web") and bool(
		JavaScriptBridge.eval("Boolean(window.Wavedash?.initialized)", true)
	)


## Mirrors the global Top 100 rule: only campaigns started at Stage 1 rank.
static func submit_campaign_score(run_result: Dictionary) -> bool:
	if not is_eligible_score(run_result) or not is_available():
		return false
	JavaScriptBridge.eval(score_upload_script(run_result), true)
	return true


static func is_eligible_score(run_result: Dictionary) -> bool:
	return (
		bool(run_result.get("eligible", false))
		and String(run_result.get("run_kind", "")) == "campaign"
		and int(run_result.get("score", 0)) > 0
	)


static func score_upload_script(run_result: Dictionary) -> String:
	return """
void (async () => {
  const wavedash = window.Wavedash;
  const board = await wavedash.getLeaderboard(%s);
  if (!board.success) throw new Error(board.message);
  const entry = await wavedash.uploadLeaderboardScore(
    board.data.id, %d, true, undefined, { stage: %d }
  );
  if (!entry.success) throw new Error(entry.message);
})().catch((error) => console.warn("Wavedash score upload failed:", error));
""" % [
		JSON.stringify(LEADERBOARD_NAME),
		int(run_result.get("score", 0)),
		int(run_result.get("completed_stage", 1)),
	]
