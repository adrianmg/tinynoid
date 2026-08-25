class_name ScoreShare
extends RefCounted

const GAME_URL := "https://tinynoid.vercel.app/"


static func share_on_twitter(
	score: int,
	outcome: String,
	png_data: PackedByteArray
) -> bool:
	var text := _share_text(score, outcome)
	if OS.has_feature("web"):
		return _share_on_web(text, png_data)
	return OS.shell_open(_x_intent_url(text)) == OK


static func share_daily(
	score: int,
	daily_id: String,
	rank: int,
	png_data: PackedByteArray
) -> bool:
	var text := _daily_share_text(score, daily_id, rank)
	if OS.has_feature("web"):
		return _share_on_web(text, png_data)
	return OS.shell_open(_x_intent_url(text)) == OK


static func _share_text(
	score: int,
	outcome: String
) -> String:
	var text := "I scored %d points in TINYNOID!" % score
	if outcome == "campaign_clear":
		text = "I cleared TINYNOID with %d points!" % score
	return "%s\n%s" % [text, GAME_URL]


static func _daily_share_text(
	score: int,
	daily_id: String,
	rank: int
) -> String:
	var text := "I scored %d in TINYNOID DAILY %s UTC!" % [
		score,
		daily_id,
	]
	if rank > 0:
		text += " WORLD RANK #%d." % rank
	var url := "%s?daily=%s" % [GAME_URL, daily_id.uri_encode()]
	return "%s\n%s" % [text, url]


static func _share_on_web(
	text: String,
	png_data: PackedByteArray
) -> bool:
	var script := """
(() => {
  const text = %s;
  const fallbackUrl =
    "https://x.com/intent/post?text=" + encodeURIComponent(text);
  const fallback = () => (
    window.open(fallbackUrl, "_blank", "noopener,noreferrer") !== null
  );
  try {
    const raw = atob(%s);
    const bytes = Uint8Array.from(raw, (character) => character.charCodeAt(0));
    const file = new File([bytes], "tinynoid-score.png", { type: "image/png" });
    const shareData = {
      title: "TINYNOID SCORE",
      text,
      files: [file],
    };
    if (
      navigator.share
      && navigator.canShare
      && navigator.canShare(shareData)
    ) {
      navigator.share(shareData).catch(() => {});
      return true;
    }
    return fallback();
  } catch (_error) {
    return fallback();
  }
})();
""" % [
		JSON.stringify(text),
		JSON.stringify(Marshalls.raw_to_base64(png_data)),
	]
	return bool(JavaScriptBridge.eval(script, true))


static func _x_intent_url(text: String) -> String:
	return "https://x.com/intent/post?text=%s" % text.uri_encode()
